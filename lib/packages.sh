#!/usr/bin/env bash

FORMULAE="starship zoxide fzf eza bat git-delta btop fastfetch"
CASKS="wezterm font-hack-nerd-font"

capture_preexisting_packages() {
  local package
  mkdir -p "$MACTERM_STATE_DIR"
  : > "$MACTERM_STATE_DIR/packages-preexisting"
  for package in $FORMULAE; do
    brew list --formula "$package" >/dev/null 2>&1 && printf 'formula\t%s\n' "$package" >> "$MACTERM_STATE_DIR/packages-preexisting"
  done
  for package in $CASKS; do
    brew list --cask "$package" >/dev/null 2>&1 && printf 'cask\t%s\n' "$package" >> "$MACTERM_STATE_DIR/packages-preexisting"
  done
}

install_packages() {
  local status
  command -v brew >/dev/null 2>&1 || die "Homebrew is required. Install it from https://brew.sh and retry."
  capture_preexisting_packages
  log "Installing terminal packages from Brewfile"
  set +e
  brew bundle --file "$MACTERM_REPO_ROOT/Brewfile"
  status=$?
  set -e
  record_project_packages
  return "$status"
}

record_project_packages() {
  local package
  mkdir -p "$MACTERM_STATE_DIR"
  touch "$MACTERM_STATE_DIR/packages-installed"
  for package in $FORMULAE; do
    if brew list --formula "$package" >/dev/null 2>&1 &&
      ! grep -Fxq $'formula\t'"$package" "$MACTERM_STATE_DIR/packages-preexisting" &&
      ! grep -Fxq $'formula\t'"$package" "$MACTERM_STATE_DIR/packages-installed"; then
      printf 'formula\t%s\n' "$package" >> "$MACTERM_STATE_DIR/packages-installed"
    fi
  done
  for package in $CASKS; do
    if brew list --cask "$package" >/dev/null 2>&1 &&
      ! grep -Fxq $'cask\t'"$package" "$MACTERM_STATE_DIR/packages-preexisting" &&
      ! grep -Fxq $'cask\t'"$package" "$MACTERM_STATE_DIR/packages-installed"; then
      printf 'cask\t%s\n' "$package" >> "$MACTERM_STATE_DIR/packages-installed"
    fi
  done
}

purge_project_packages() {
  local kind package remaining status
  [[ -f "$MACTERM_STATE_DIR/packages-installed" ]] || return 0
  command -v brew >/dev/null 2>&1 || { warn "Homebrew unavailable; packages were not removed"; return 1; }
  remaining="$(mktemp "$MACTERM_STATE_DIR/packages-installed.XXXXXX")"
  while IFS=$'\t' read -r kind package; do
    [[ -n "$package" ]] || continue
    set +e
    brew uninstall "--$kind" "$package"
    status=$?
    set -e
    if [[ "$status" -ne 0 ]]; then
      warn "Could not remove $package"
      printf '%s\t%s\n' "$kind" "$package" >> "$remaining"
    fi
  done < "$MACTERM_STATE_DIR/packages-installed"
  mv "$remaining" "$MACTERM_STATE_DIR/packages-installed"
  [[ ! -s "$MACTERM_STATE_DIR/packages-installed" ]]
}
