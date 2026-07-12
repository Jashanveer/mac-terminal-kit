#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/mac-terminal-kit-lint.XXXXXX")
BASH_FILES="$TEMP_DIR/bash-files"
ZSH_FILES="$TEMP_DIR/zsh-files"

cleanup() {
  rm -rf -- "$TEMP_DIR"
}
trap cleanup EXIT HUP INT TERM

: >"$BASH_FILES"
: >"$ZSH_FILES"

find_shell_files() {
  local directory
  local file
  local first_line

  for directory in "$ROOT_DIR/bin" "$ROOT_DIR/lib" "$ROOT_DIR/scripts" "$ROOT_DIR/tests"; do
    [ -d "$directory" ] || continue
    while IFS= read -r file; do
      case "$file" in
        *.zsh)
          printf '%s\n' "$file" >>"$ZSH_FILES"
          ;;
        *.sh|*.bash)
          printf '%s\n' "$file" >>"$BASH_FILES"
          ;;
        *)
          first_line=$(sed -n '1p' "$file")
          case "$first_line" in
            *bash*) printf '%s\n' "$file" >>"$BASH_FILES" ;;
            *zsh*) printf '%s\n' "$file" >>"$ZSH_FILES" ;;
          esac
          ;;
      esac
    done < <(find "$directory" -type f ! -path '*/.git/*' | LC_ALL=C sort)
  done

  printf '%s\n' "$ROOT_DIR/install.sh" >>"$BASH_FILES"
}

lint_with() {
  local shell_name=$1
  local files=$2
  local file

  [ -s "$files" ] || return 0
  command -v "$shell_name" >/dev/null 2>&1 || {
    printf 'ERROR: %s is required to syntax-check project files\n' "$shell_name" >&2
    return 1
  }

  while IFS= read -r file; do
    printf '%s -n %s\n' "$shell_name" "${file#"$ROOT_DIR"/}"
    "$shell_name" -n "$file"
  done <"$files"
}

find_shell_files
lint_with bash "$BASH_FILES"
lint_with zsh "$ZSH_FILES"

if command -v shellcheck >/dev/null 2>&1 && [ -s "$BASH_FILES" ]; then
  printf 'shellcheck (optional)\n'
  while IFS= read -r file; do
    shellcheck -x -s bash "$file"
  done <"$BASH_FILES"
else
  printf 'shellcheck not installed; skipping optional static analysis\n'
fi

printf 'Shell syntax checks passed.\n'
