# mac-terminal-kit

A reversible macOS terminal setup that combines WezTerm, Starship, zoxide,
fzf, eza, bat, Delta, btop, and fastfetch into one restrained configuration.
It configures an existing terminal stack; it is not a terminal emulator.

## What it installs

- WezTerm with the Graphite Signal color scheme and pane shortcuts
- Hack Nerd Font
- A compact two-line Starship prompt
- zoxide and fzf navigation
- eza, bat, Delta, btop, and fastfetch integrations
- Safe shell aliases without replacing `cd`, `cat`, or other core commands

The installer uses Homebrew, supports Apple Silicon and Intel Macs, and expects
macOS 13 or newer with zsh.

## Install

Clone the repository so you can inspect the scripts before running them:

```bash
git clone https://github.com/Jashanveer/mac-terminal-kit.git
cd mac-terminal-kit
./install.sh
```

Preview the operation or skip Homebrew packages:

```bash
./install.sh --dry-run
./install.sh --no-packages
```

Open WezTerm after installation. If `~/.local/bin` is not already in `PATH`,
add it to your shell path to use the `macterm` command directly.

## Commands

```text
macterm install [--no-packages] [--dry-run]
macterm doctor
macterm backup
macterm restore <backup-id>
macterm uninstall [--purge-packages]
macterm info
```

`macterm doctor` reports missing tools and configuration. `macterm info` runs
fastfetch without adding startup noise to every shell.

## Files changed

The installer adds one marked block to `~/.zshrc`, one exact include to
`~/.gitconfig`, and a `~/.wezterm.lua` symlink only when that path is free.
Existing WezTerm configuration is left untouched.

Managed files are stored in:

```text
~/.config/mac-terminal-kit
~/.local/share/mac-terminal-kit
~/.local/bin/macterm
```

Backups and package ownership records are stored under
`~/.local/state/mac-terminal-kit`. Every install, restore, and uninstall begins
with a new snapshot. Uninstall keeps Homebrew packages unless
`--purge-packages` is explicitly supplied, and even then removes only packages
that were absent before installation.

## Customize

Edit the source files under `config/`, then run `./install.sh --no-packages`
again. The Graphite Signal palette uses a near-black background, neutral text,
green status, blue paths, amber warnings, and red errors.

## Development

Run the isolated test and lint scripts:

```bash
./scripts/lint.sh
./tests/run.sh
```

Tests use a temporary `HOME`; they do not modify your real dotfiles.

## License

MIT
