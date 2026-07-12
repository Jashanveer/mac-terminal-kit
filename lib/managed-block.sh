#!/usr/bin/env bash

MANAGED_START="# >>> mac-terminal-kit managed >>>"
MANAGED_END="# <<< mac-terminal-kit managed <<<"
MANAGED_PAYLOAD='source "${XDG_CONFIG_HOME:-$HOME/.config}/mac-terminal-kit/macterm.zsh"'

managed_block_counts() {
  local file="$1"
  if [[ ! -e "$file" ]]; then
    printf '0 0\n'
    return
  fi
  awk -v start="$MANAGED_START" -v end="$MANAGED_END" '
    $0 == start { starts++ }
    $0 == end { ends++ }
    END { print starts + 0, ends + 0 }
  ' "$file"
}

validate_managed_block() {
  local file="$1"
  [[ -e "$file" ]] || return 0
  awk -v start="$MANAGED_START" -v end="$MANAGED_END" '
    $0 == start {
      if (inside || seen_start) exit 2
      inside = 1
      seen_start = 1
      next
    }
    $0 == end {
      if (!inside || seen_end) exit 2
      inside = 0
      seen_end = 1
      next
    }
    END {
      if (inside || seen_start != seen_end) exit 2
    }
  ' "$file" || die "Malformed, reversed, or duplicate managed block in $file"
}

add_managed_block() {
  local file="$1" line="$2" tmp counts mode=600
  ensure_parent "$file"
  validate_managed_block "$file"
  counts="$(managed_block_counts "$file")"
  tmp="$(mktemp "${file}.tmp.XXXXXX")"
  if [[ -e "$file" ]]; then
    mode="$(stat -f '%Lp' "$file")"
    if [[ "${counts%% *}" == "1" ]]; then
      awk -v start="$MANAGED_START" -v end="$MANAGED_END" -v payload="$line" '
        $0 == start {
          print start
          print payload
          print end
          managed = 1
          next
        }
        $0 == end { managed = 0; next }
        !managed { print }
      ' "$file" > "$tmp"
    else
      cat "$file" > "$tmp"
    fi
    if [[ -s "$tmp" ]] && [[ "$(tail -c 1 "$tmp" | wc -l | tr -d ' ')" == "0" ]]; then
      printf '\n' >> "$tmp"
    fi
  fi
  if [[ "${counts%% *}" == "0" ]]; then
    printf '%s\n%s\n%s\n' "$MANAGED_START" "$line" "$MANAGED_END" >> "$tmp"
  fi
  chmod "$mode" "$tmp"
  mv "$tmp" "$file"
}

remove_managed_block() {
  local file="$1" tmp mode
  [[ -e "$file" ]] || return 0
  validate_managed_block "$file"
  mode="$(stat -f '%Lp' "$file")"
  tmp="$(mktemp "${file}.tmp.XXXXXX")"
  awk -v start="$MANAGED_START" -v end="$MANAGED_END" '
    $0 == start { managed = 1; next }
    $0 == end { managed = 0; next }
    !managed { print }
  ' "$file" > "$tmp"
  chmod "$mode" "$tmp"
  mv "$tmp" "$file"
}

managed_block_matches() {
  local file="$1"
  validate_managed_block "$file"
  awk -v start="$MANAGED_START" -v end="$MANAGED_END" -v payload="$MANAGED_PAYLOAD" '
    $0 == start { inside = 1; next }
    $0 == end { inside = 0; next }
    inside { lines++; if ($0 == payload) matches++ }
    END { exit !(lines == 1 && matches == 1) }
  ' "$file"
}
