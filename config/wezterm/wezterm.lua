local wezterm = require("wezterm")
local act = wezterm.action

local config = wezterm.config_builder and wezterm.config_builder() or {}

config.color_scheme = "Graphite Signal"
config.color_schemes = {
  ["Graphite Signal"] = {
    foreground = "#d8dee9",
    background = "#111418",
    cursor_bg = "#9be28f",
    cursor_fg = "#111418",
    cursor_border = "#9be28f",
    selection_fg = "#f2f5f7",
    selection_bg = "#34414a",
    scrollbar_thumb = "#394149",
    split = "#46515b",
    ansi = {
      "#1d2228",
      "#f07178",
      "#9be28f",
      "#e6c76e",
      "#7cc7ff",
      "#c792ea",
      "#7fdbca",
      "#c8d0d8",
    },
    brights = {
      "#5d6873",
      "#ff8a90",
      "#b6f2aa",
      "#f2d889",
      "#9bd5ff",
      "#d8a9f4",
      "#9ae8db",
      "#f2f5f7",
    },
    tab_bar = {
      background = "#0c0f12",
      active_tab = {
        bg_color = "#9be28f",
        fg_color = "#111418",
        intensity = "Bold",
      },
      inactive_tab = {
        bg_color = "#1d2228",
        fg_color = "#8b96a1",
      },
      inactive_tab_hover = {
        bg_color = "#2a3138",
        fg_color = "#d8dee9",
      },
      new_tab = {
        bg_color = "#0c0f12",
        fg_color = "#8b96a1",
      },
      new_tab_hover = {
        bg_color = "#2a3138",
        fg_color = "#9be28f",
      },
    },
  },
}

config.font = wezterm.font_with_fallback({
  "Hack Nerd Font",
  "Apple Color Emoji",
})
config.font_size = 14.0
config.line_height = 1.05
config.cell_width = 1.0

config.window_background_opacity = 0.96
config.macos_window_background_blur = 18
config.window_decorations = "RESIZE"
config.window_padding = {
  left = 14,
  right = 14,
  top = 12,
  bottom = 10,
}
config.initial_cols = 120
config.initial_rows = 34
config.adjust_window_size_when_changing_font_size = false

config.use_fancy_tab_bar = false
config.hide_tab_bar_if_only_one_tab = true
config.tab_bar_at_bottom = false
config.tab_max_width = 28
config.show_new_tab_button_in_tab_bar = false

config.default_cursor_style = "BlinkingBlock"
config.cursor_blink_rate = 650
config.animation_fps = 60
config.max_fps = 120
config.scrollback_lines = 10000
config.enable_scroll_bar = false
config.audible_bell = "Disabled"
config.window_close_confirmation = "NeverPrompt"

config.leader = { key = "Space", mods = "CTRL", timeout_milliseconds = 1000 }
config.keys = {
  { key = "|", mods = "LEADER|SHIFT", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
  { key = "-", mods = "LEADER", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
  { key = "h", mods = "LEADER", action = act.ActivatePaneDirection("Left") },
  { key = "j", mods = "LEADER", action = act.ActivatePaneDirection("Down") },
  { key = "k", mods = "LEADER", action = act.ActivatePaneDirection("Up") },
  { key = "l", mods = "LEADER", action = act.ActivatePaneDirection("Right") },
  { key = "z", mods = "LEADER", action = act.TogglePaneZoomState },
  { key = "x", mods = "LEADER", action = act.CloseCurrentPane({ confirm = true }) },
  { key = "r", mods = "LEADER", action = act.ReloadConfiguration },
  { key = "[", mods = "LEADER", action = act.ActivateCopyMode },
}

return config
