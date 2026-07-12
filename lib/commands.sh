#!/usr/bin/env bash

install_runtime() {
  reject_managed_root_symlinks
  mkdir -p "$MACTERM_DATA_DIR" "$MACTERM_BIN_DIR"
  if [[ -e "$MACTERM_BIN_PATH" && ! -L "$MACTERM_BIN_PATH" ]]; then
    die "$MACTERM_BIN_PATH exists and is not managed by mac-terminal-kit"
  fi
  if [[ -L "$MACTERM_BIN_PATH" && "$(readlink "$MACTERM_BIN_PATH")" != "$MACTERM_DATA_DIR/bin/macterm" ]]; then
    die "$MACTERM_BIN_PATH points to another program"
  fi
  if [[ "$MACTERM_REPO_ROOT" != "$MACTERM_DATA_DIR" ]]; then
    copy_tree "$MACTERM_REPO_ROOT/bin" "$MACTERM_DATA_DIR/bin"
    copy_tree "$MACTERM_REPO_ROOT/lib" "$MACTERM_DATA_DIR/lib"
    copy_tree "$MACTERM_REPO_ROOT/config" "$MACTERM_DATA_DIR/config"
    cp "$MACTERM_REPO_ROOT/Brewfile" "$MACTERM_DATA_DIR/Brewfile"
  fi
  chmod +x "$MACTERM_DATA_DIR/bin/macterm"
  ln -sfn "$MACTERM_DATA_DIR/bin/macterm" "$MACTERM_BIN_PATH"
}

install_configuration() {
  local staged_config
  reject_managed_root_symlinks
  mkdir -p "$CONFIG_HOME"
  staged_config="$(mktemp -d "$CONFIG_HOME/.mac-terminal-kit.XXXXXX")"
  cp "$MACTERM_REPO_ROOT/config/zsh/macterm.zsh" "$staged_config/macterm.zsh"
  cp "$MACTERM_REPO_ROOT/config/starship/starship.toml" "$staged_config/starship.toml"
  cp "$MACTERM_REPO_ROOT/config/git/delta.gitconfig" "$staged_config/delta.gitconfig"
  cp "$MACTERM_REPO_ROOT/config/bat/config" "$staged_config/bat-config"
  cp "$MACTERM_REPO_ROOT/config/wezterm/wezterm.lua" "$staged_config/wezterm.lua"
  rm -rf "$MACTERM_CONFIG_DIR"
  mv "$staged_config" "$MACTERM_CONFIG_DIR"

  add_managed_block "$ZSHRC_PATH" "$MANAGED_PAYLOAD"

  if [[ ! -e "$WEZTERM_PATH" && ! -L "$WEZTERM_PATH" ]]; then
    ln -s "$MACTERM_CONFIG_DIR/wezterm.lua" "$WEZTERM_PATH"
  elif [[ "$(readlink "$WEZTERM_PATH" 2>/dev/null || true)" != "$MACTERM_CONFIG_DIR/wezterm.lua" ]]; then
    warn "$WEZTERM_PATH already exists; leaving it unchanged"
  fi

  if command -v git >/dev/null 2>&1; then
    if ! git config --file "$GITCONFIG_PATH" --get-all include.path 2>/dev/null | grep -Fxq "$MACTERM_CONFIG_DIR/delta.gitconfig"; then
      ensure_parent "$GITCONFIG_PATH"
      git config --file "$GITCONFIG_PATH" --add include.path "$MACTERM_CONFIG_DIR/delta.gitconfig"
    fi
  fi
}

command_install() {
  local install_packages_flag=1 dry_run=0 backup_id
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --no-packages) install_packages_flag=0 ;;
      --dry-run) dry_run=1 ;;
      *) die "Unknown install option: $1" ;;
    esac
    shift
  done
  ensure_macos
  reject_managed_root_symlinks
  validate_managed_block "$ZSHRC_PATH"
  if [[ "$dry_run" == "1" ]]; then
    log "Would back up dotfiles, install managed config, and update shell initialization"
    [[ "$install_packages_flag" == "1" ]] && log "Would install packages from Brewfile"
    return 0
  fi

  backup_id="$(backup_create)"
  log "Backup created: $backup_id"
  if [[ "$install_packages_flag" == "1" ]]; then
    install_packages
  fi
  install_runtime
  install_configuration
  log "Installed. Add $MACTERM_BIN_DIR to PATH if needed, then open WezTerm."
}

command_backup() {
  local id
  reject_managed_root_symlinks
  id="$(backup_create)"
  log "Backup created: $id"
}

command_restore() {
  [[ $# -eq 1 ]] || die "Usage: macterm restore <backup-id>"
  local safety_id
  reject_managed_root_symlinks
  safety_id="$(backup_create)"
  backup_restore "$1"
  log "Restored $1 (pre-restore backup: $safety_id)"
}

command_uninstall() {
  local purge=0 backup_id package_result="kept" purge_failed=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --purge-packages) purge=1 ;;
      *) die "Unknown uninstall option: $1" ;;
    esac
    shift
  done
  reject_managed_root_symlinks
  backup_id="$(backup_create)"
  remove_managed_block "$ZSHRC_PATH"
  if command -v git >/dev/null 2>&1 &&
    git config --file "$GITCONFIG_PATH" --get-all include.path 2>/dev/null | grep -Fxq "$MACTERM_CONFIG_DIR/delta.gitconfig"; then
    git config --file "$GITCONFIG_PATH" --fixed-value --unset-all include.path "$MACTERM_CONFIG_DIR/delta.gitconfig"
  fi
  if [[ -L "$WEZTERM_PATH" && "$(readlink "$WEZTERM_PATH")" == "$MACTERM_CONFIG_DIR/wezterm.lua" ]]; then
    rm "$WEZTERM_PATH"
  fi
  if [[ "$purge" == "1" ]]; then
    if purge_project_packages; then
      package_result="removed"
    else
      package_result="partially removed; see warnings"
      purge_failed=1
    fi
  else
    rm -f "$MACTERM_STATE_DIR/packages-installed" "$MACTERM_STATE_DIR/packages-preexisting"
  fi
  rm -rf "$MACTERM_CONFIG_DIR" "$MACTERM_DATA_DIR"
  if [[ -L "$MACTERM_BIN_PATH" && "$(readlink "$MACTERM_BIN_PATH")" == "$MACTERM_DATA_DIR/bin/macterm" ]]; then
    rm "$MACTERM_BIN_PATH"
  fi
  log "Uninstalled (backup: $backup_id). Packages were $package_result."
  [[ "$purge_failed" == "0" ]]
}

command_doctor() {
  local failures=0 command path
  ensure_macos
  for path in "$MACTERM_CONFIG_DIR" "$MACTERM_STATE_DIR" "$MACTERM_DATA_DIR"; do
    if [[ -L "$path" ]]; then
      printf 'invalid symlinked managed root: %s\n' "$path"
      failures=$((failures + 1))
    fi
  done
  for command in wezterm starship zoxide fzf eza bat delta btop fastfetch; do
    if command -v "$command" >/dev/null 2>&1; then
      printf 'ok      %s\n' "$command"
    else
      printf 'missing %s\n' "$command"
      failures=$((failures + 1))
    fi
  done
  if [[ -f "$MACTERM_CONFIG_DIR/macterm.zsh" ]]; then
    printf 'ok      managed configuration\n'
  else
    printf 'missing managed configuration\n'
    failures=$((failures + 1))
  fi
  validate_managed_block "$ZSHRC_PATH"
  if managed_block_matches "$ZSHRC_PATH"; then
    printf 'ok      zsh integration\n'
  else
    printf 'invalid zsh integration\n'
    failures=$((failures + 1))
  fi
  for command in starship.toml delta.gitconfig bat-config wezterm.lua; do
    if [[ ! -f "$MACTERM_CONFIG_DIR/$command" ]]; then
      printf 'missing %s\n' "$command"
      failures=$((failures + 1))
    fi
  done
  if command -v git >/dev/null 2>&1 &&
    git config --file "$GITCONFIG_PATH" --get-all include.path 2>/dev/null | grep -Fxq "$MACTERM_CONFIG_DIR/delta.gitconfig"; then
    printf 'ok      Git Delta include\n'
  else
    printf 'missing Git Delta include\n'
    failures=$((failures + 1))
  fi
  if [[ -L "$WEZTERM_PATH" && "$(readlink "$WEZTERM_PATH")" == "$MACTERM_CONFIG_DIR/wezterm.lua" ]]; then
    printf 'ok      WezTerm integration\n'
  else
    printf 'invalid WezTerm integration\n'
    failures=$((failures + 1))
  fi
  [[ "$failures" == "0" ]] || return 1
}

command_info() {
  if command -v fastfetch >/dev/null 2>&1; then
    fastfetch
  else
    uname -a
    warn "fastfetch is not installed"
  fi
}
