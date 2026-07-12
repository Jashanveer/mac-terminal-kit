#!/usr/bin/env bash

PROJECT_NAME="mac-terminal-kit"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
MACTERM_CONFIG_DIR="$CONFIG_HOME/$PROJECT_NAME"
MACTERM_STATE_DIR="$STATE_HOME/$PROJECT_NAME"
MACTERM_DATA_DIR="$DATA_HOME/$PROJECT_NAME"
MACTERM_BIN_DIR="$HOME/.local/bin"
MACTERM_BIN_PATH="$MACTERM_BIN_DIR/macterm"
ZSHRC_PATH="${ZDOTDIR:-$HOME}/.zshrc"
GITCONFIG_PATH="$HOME/.gitconfig"
WEZTERM_PATH="$HOME/.wezterm.lua"

log() { printf '[macterm] %s\n' "$*"; }
warn() { printf '[macterm] warning: %s\n' "$*" >&2; }
die() { printf '[macterm] error: %s\n' "$*" >&2; exit 1; }

ensure_macos() {
  local major
  [[ "$(uname -s)" == "Darwin" ]] || die "mac-terminal-kit supports macOS only"
  major="$(sw_vers -productVersion | cut -d. -f1)"
  [[ "$major" -ge 13 ]] || die "macOS 13 or newer is required"
}

ensure_parent() {
  mkdir -p "$(dirname "$1")"
}

path_checksum() {
  local path="$1"
  if [[ -f "$path" ]]; then
    shasum -a 256 "$path" | awk '{print $1}'
  elif [[ -d "$path" ]]; then
    (cd "$path" && find . -type f -exec shasum -a 256 {} \; 2>/dev/null | sort | shasum -a 256 | awk '{print $1}')
  else
    printf 'missing\n'
  fi
}

copy_tree() {
  local source="$1" destination="$2"
  rm -rf "$destination"
  mkdir -p "$destination"
  cp -R "$source/." "$destination/"
}

reject_managed_root_symlinks() {
  local path
  for path in "$MACTERM_CONFIG_DIR" "$MACTERM_STATE_DIR" "$MACTERM_DATA_DIR"; do
    [[ ! -L "$path" ]] || die "Refusing symlinked managed directory: $path"
  done
}

resolve_linked_path() {
  local path="$1" target hops=0
  while [[ -L "$path" ]]; do
    hops=$((hops + 1))
    [[ "$hops" -le 20 ]] || die "Too many symlink hops while resolving $1"
    target="$(readlink "$path")"
    if [[ "$target" == /* ]]; then
      path="$target"
    else
      path="$(dirname "$path")/$target"
    fi
  done
  printf '%s\n' "$path"
}

# Edit the content behind dotfile symlinks without replacing the symlinks.
ZSHRC_PATH="$(resolve_linked_path "$ZSHRC_PATH")"
GITCONFIG_PATH="$(resolve_linked_path "$GITCONFIG_PATH")"
