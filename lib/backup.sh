#!/usr/bin/env bash

backup_targets() {
  printf '%s\t%s\n' zshrc "$ZSHRC_PATH"
  printf '%s\t%s\n' gitconfig "$GITCONFIG_PATH"
  printf '%s\t%s\n' wezterm "$WEZTERM_PATH"
  printf '%s\t%s\n' config "$MACTERM_CONFIG_DIR"
  printf '%s\t%s\n' data "$MACTERM_DATA_DIR"
  printf '%s\t%s\n' binary "$MACTERM_BIN_PATH"
}

backup_create() {
  local id directory label path
  id="$(date -u +%Y%m%dT%H%M%SZ)-$$"
  directory="$MACTERM_STATE_DIR/backups/$id"
  mkdir -p "$directory/items"
  : > "$directory/manifest.tsv"

  while IFS=$'\t' read -r label path; do
    if [[ -L "$path" ]]; then
      printf '%s\t%s\tsymlink\t%s\n' "$label" "$path" "$(readlink "$path")" >> "$directory/manifest.tsv"
      cp -P "$path" "$directory/items/$label"
    elif [[ -e "$path" ]]; then
      printf '%s\t%s\tpresent\t%s\n' "$label" "$path" "$(path_checksum "$path")" >> "$directory/manifest.tsv"
      cp -Rp "$path" "$directory/items/$label"
    else
      printf '%s\t%s\tmissing\t-\n' "$label" "$path" >> "$directory/manifest.tsv"
    fi
  done < <(backup_targets)

  printf '%s\n' "$id"
}

backup_restore() {
  local id="$1" directory label path state metadata item expected_path expected_count=0 actual_count=0 seen
  case "$id" in
    ''|*/*|*'..'*) die "Invalid backup id: $id" ;;
  esac
  directory="$MACTERM_STATE_DIR/backups/$id"
  [[ -f "$directory/manifest.tsv" ]] || die "Backup not found: $id"

  seen="$(mktemp "${TMPDIR:-/tmp}/macterm-backup-seen.XXXXXX")"
  : > "$seen"

  while IFS=$'\t' read -r label path state metadata; do
    actual_count=$((actual_count + 1))
    [[ -n "$label" && "$label" != */* ]] || { rm -f "$seen"; die "Invalid backup label"; }
    ! grep -Fxq "$label" "$seen" || { rm -f "$seen"; die "Duplicate backup label: $label"; }
    printf '%s\n' "$label" >> "$seen"
    expected_path="$(backup_targets | awk -F '\t' -v wanted="$label" '$1 == wanted { print $2; exit }')"
    [[ -n "$expected_path" && "$path" == "$expected_path" ]] || { rm -f "$seen"; die "Unexpected backup target: $label"; }
    item="$directory/items/$label"
    case "$state" in
      missing) ;;
      present)
        [[ -e "$item" ]] || die "Backup item is missing: $label"
        [[ "$(path_checksum "$item")" == "$metadata" ]] || die "Backup checksum failed: $label"
        ;;
      symlink)
        [[ "$label" != "config" && "$label" != "data" ]] || { rm -f "$seen"; die "Managed roots cannot be restored as symlinks"; }
        [[ -L "$item" ]] || { rm -f "$seen"; die "Backup symlink item is missing: $label"; }
        [[ -n "$metadata" && "$metadata" != "-" && "$(readlink "$item")" == "$metadata" ]] || {
          rm -f "$seen"
          die "Backup symlink metadata failed validation: $label"
        }
        ;;
      *) die "Invalid backup manifest state: $state" ;;
    esac
  done < "$directory/manifest.tsv"

  while IFS=$'\t' read -r label path; do
    expected_count=$((expected_count + 1))
    grep -Fxq "$label" "$seen" || { rm -f "$seen"; die "Backup target is missing: $label"; }
  done < <(backup_targets)
  rm -f "$seen"
  [[ "$actual_count" -eq "$expected_count" ]] || die "Backup manifest has unexpected entries"

  while IFS=$'\t' read -r label path state metadata; do
    item="$directory/items/$label"
    case "$state" in
      missing) rm -rf "$path" ;;
      present)
        ensure_parent "$path"
        rm -rf "$path"
        cp -Rp "$item" "$path"
        ;;
      symlink)
        ensure_parent "$path"
        rm -rf "$path"
        ln -s "$metadata" "$path"
        ;;
    esac
  done < "$directory/manifest.tsv"
}
