local wezterm = require("wezterm")
local config = wezterm.config_builder()

local workspace = require("workspace")

-- Font
config.font = wezterm.font("JetBrainsMono Nerd Font")
config.font_size = 14.0

-- Window
config.window_decorations = "RESIZE"
config.scrollback_lines = 5000
config.window_padding = { left = 4, right = 0, top = "0.5cell", bottom = 0 }

-- Tab bar
config.enable_tab_bar = true
config.tab_bar_at_bottom = true
config.use_fancy_tab_bar = false
config.show_new_tab_button_in_tab_bar = false
config.hide_tab_bar_if_only_one_tab = false
config.switch_to_last_active_tab_when_closing_tab = true

-- Leader key (Ctrl-b, tmux-style — change to your preference)
config.leader = { key = "b", mods = "CTRL", timeout_milliseconds = 2000 }

-- Keybindings
local act = wezterm.action
config.keys = {
	-- Workspace picker
	{ key = "g", mods = "LEADER", action = workspace.project_selector() },
	-- Previous workspace
	{ key = "b", mods = "LEADER", action = workspace.switch_to_prev_workspace() },
	-- Cycle workspaces
	{ key = "[", mods = "LEADER", action = workspace.tracked_switch_relative(-1) },
	{ key = "]", mods = "LEADER", action = workspace.tracked_switch_relative(1) },
	-- Splits
	{ key = "-", mods = "LEADER", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
	{ key = "\\", mods = "LEADER", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
	-- Tabs
	{ key = "c", mods = "LEADER", action = act.SpawnTab("CurrentPaneDomain") },
	{ key = "n", mods = "LEADER", action = act.ActivateTabRelative(1) },
	{ key = "p", mods = "LEADER", action = act.ActivateTabRelative(-1) },
	{ key = "x", mods = "LEADER", action = act.CloseCurrentPane({ confirm = true }) },
	-- Pane navigation
	{ key = "h", mods = "LEADER", action = act.ActivatePaneDirection("Left") },
	{ key = "j", mods = "LEADER", action = act.ActivatePaneDirection("Down") },
	{ key = "k", mods = "LEADER", action = act.ActivatePaneDirection("Up") },
	{ key = "l", mods = "LEADER", action = act.ActivatePaneDirection("Right") },
	{ key = "z", mods = "LEADER", action = act.TogglePaneZoomState },
}

-- Tab switching by number (1-9)
for i = 1, 9 do
	table.insert(config.keys, { key = tostring(i), mods = "LEADER", action = act.ActivateTab(i - 1) })
end

-- Maximize on startup
wezterm.on("gui-startup", function()
	local _, _, window = wezterm.mux.spawn_window({})
	window:gui_window():maximize()
end)

-- Register workspace handlers
workspace.setup_status_bar()
workspace.setup_workspace_switching()

return config
