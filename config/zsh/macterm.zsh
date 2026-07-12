# Graphite Signal shell integrations. Safe to source more than once.
if [[ -n "${GRAPHITE_SIGNAL_ZSH_LOADED:-}" ]]; then
  return 0
fi
typeset -g GRAPHITE_SIGNAL_ZSH_LOADED=1

export STARSHIP_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/mac-terminal-kit/starship.toml"
export BAT_CONFIG_PATH="${XDG_CONFIG_HOME:-$HOME/.config}/mac-terminal-kit/bat-config"

if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

if command -v fzf >/dev/null 2>&1; then
  eval "$(fzf --zsh)"

  export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS:+${FZF_DEFAULT_OPTS} }--height=45% --layout=reverse --border=sharp --info=inline --prompt='› ' --pointer='◆' --marker='●' --color=bg+:#1d2228,bg:#111418,spinner:#9be28f,hl:#7cc7ff,fg:#d8dee9,header:#c792ea,info:#8b96a1,pointer:#9be28f,marker:#e6c76e,fg+:#f2f5f7,prompt:#9be28f,hl+:#9bd5ff"
  export FZF_CTRL_T_OPTS="${FZF_CTRL_T_OPTS:+${FZF_CTRL_T_OPTS} }--preview 'bat --color=always --style=numbers --line-range=:300 {} 2>/dev/null || eza --tree --color=always {} 2>/dev/null'"
  export FZF_ALT_C_OPTS="${FZF_ALT_C_OPTS:+${FZF_ALT_C_OPTS} }--preview 'eza --tree --color=always --level=2 {} 2>/dev/null'"
fi

if command -v eza >/dev/null 2>&1; then
  alias l='eza --group-directories-first'
  alias ll='eza --long --group --git --icons=auto --group-directories-first'
  alias la='eza --long --all --group --git --icons=auto --group-directories-first'
  alias lt='eza --tree --level=2 --icons=auto --group-directories-first'
fi

if command -v bat >/dev/null 2>&1; then
  alias bcat='bat'
  alias bplain='bat --plain'
fi

if command -v btop >/dev/null 2>&1; then
  alias sysmon='btop'
fi

if command -v fastfetch >/dev/null 2>&1; then
  alias ff='fastfetch'
fi
