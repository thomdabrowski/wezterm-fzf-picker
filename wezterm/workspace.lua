local wezterm = require("wezterm")
local act = wezterm.action

local M = {}

-- Tool tracking --------------------------------------------------------------

local function is_nvim(p)
	local proc = p:get_foreground_process_name()
	return proc and proc:match("([^/]+)$") == "nvim"
end

-- Track spawned tool tabs per workspace: { workspace_name = { nvim = tab_id } }
local tool_tabs = {}

local function open_or_focus_tool(window, tool, file, cwd)
	local mux_win = window:mux_window()
	local ws = window:active_workspace()
	local tabs = mux_win:tabs()
	local active_pane = mux_win:active_tab():active_pane()

	-- Check tracked tab ID
	if tool_tabs[ws] and tool_tabs[ws][tool] then
		local target_id = tool_tabs[ws][tool]
		for i, tab in ipairs(tabs) do
			if tab:tab_id() == target_id then
				window:perform_action(act.ActivateTab(i - 1), active_pane)
				if file then
					tab:active_pane():send_text("\x1b:edit " .. file .. "\n")
				end
				return
			end
		end
		tool_tabs[ws][tool] = nil
	end

	-- Scan for untracked instances
	for i, tab in ipairs(tabs) do
		for _, p in ipairs(tab:panes()) do
			if tool == "nvim" and is_nvim(p) then
				tool_tabs[ws] = tool_tabs[ws] or {}
				tool_tabs[ws][tool] = tab:tab_id()
				window:perform_action(act.ActivateTab(i - 1), active_pane)
				if file then
					p:send_text("\x1b:edit " .. file .. "\n")
				end
				return
			end
		end
	end

	-- Not found — spawn new tab
	tool_tabs[ws] = tool_tabs[ws] or {}
	local nvim_cmd = file and ("nvim " .. file) or "nvim ."
	local spawn_opts = { args = { "zsh", "-l", "-c", nvim_cmd } }
	if cwd then
		spawn_opts.cwd = cwd
	end
	local new_tab = mux_win:spawn_tab(spawn_opts)
	if new_tab then
		tool_tabs[ws][tool] = new_tab:tab_id()
		new_tab:set_title("nvim")
	end
end

-- Workspace switching helpers ------------------------------------------------

function M.tracked_switch_relative(direction)
	return wezterm.action_callback(function(window, pane)
		wezterm.GLOBAL.previous_workspace = window:active_workspace()
		window:perform_action(act.SwitchWorkspaceRelative(direction), pane)
	end)
end

-- Public API -----------------------------------------------------------------

function M.project_selector()
	return wezterm.action_callback(function(window, pane)
		local new_pane = pane:split({
			direction = "Bottom",
			size = 0.1,
			args = { wezterm.home_dir .. "/.config/scripts/project-selector" },
		})
		new_pane:activate()
		window:perform_action(act.TogglePaneZoomState, new_pane)
	end)
end

function M.switch_to_prev_workspace()
	return wezterm.action_callback(function(window, pane)
		local current = window:active_workspace()
		local previous = wezterm.GLOBAL.previous_workspace
		if not previous or current == previous then
			window:toast_notification("WezTerm", "No previous workspace", nil, 2000)
			return
		end
		wezterm.GLOBAL.previous_workspace = current
		window:perform_action(act.SwitchToWorkspace({ name = previous }), pane)
	end)
end

function M.setup_status_bar()
	wezterm.on("update-right-status", function(window, pane)
		local ws_name = window:active_workspace()

		-- Track workspace changes for previous workspace toggle
		local tracked = wezterm.GLOBAL._tracked_workspace
		if not tracked then
			wezterm.GLOBAL._tracked_workspace = ws_name
		elseif ws_name ~= tracked then
			wezterm.GLOBAL.previous_workspace = tracked
			wezterm.GLOBAL._tracked_workspace = ws_name
		end

		window:set_right_status(wezterm.format({
			{ Foreground = { Color = "#6e94b2" } },
			{ Text = ws_name .. " " },
			{ Foreground = { Color = "#606079" } },
			{ Text = "| " },
			{ Foreground = { Color = "#cdcdcd" } },
			{ Text = os.date("%a %d %H:%M") .. " " },
		}))
	end)
end

--- Kill a workspace by force-closing all its panes (kills PTY + processes).
local function kill_workspace(window, target_ws)
	local current_ws = window:active_workspace()

	if target_ws == current_ws then
		window:toast_notification("WezTerm", "Can't kill current workspace", nil, 3000)
		return
	end

	if target_ws == "default" then
		window:toast_notification("WezTerm", "Can't kill default workspace", nil, 3000)
		return
	end

	-- Collect pane IDs via mux, then kill each with the CLI.
	-- perform_action(CloseCurrentPane) doesn't work across workspaces,
	-- but `wezterm cli kill-pane` operates at the mux level.
	local pane_ids = {}
	for _, mux_win in ipairs(wezterm.mux.all_windows()) do
		if mux_win:get_workspace() == target_ws then
			for _, tab in ipairs(mux_win:tabs()) do
				for _, p in ipairs(tab:panes()) do
					table.insert(pane_ids, tostring(p:pane_id()))
				end
			end
		end
	end

	for _, id in ipairs(pane_ids) do
		wezterm.run_child_process({ "wezterm", "cli", "kill-pane", "--pane-id", id })
	end

	-- Clean up tool_tabs tracking
	tool_tabs[target_ws] = nil
end

function M.setup_workspace_switching()
	wezterm.on("user-var-changed", function(window, pane, name, value)
		if name == "kill_workspace" then
			kill_workspace(window, value)
			return
		end

		if name ~= "switch_workspace" then
			return
		end

		local tool_action, tool_file
		local nvim_file_match = value:match(":nvim:(.+)$")
		if nvim_file_match then
			tool_action = "nvim"
			tool_file = nvim_file_match
			value = value:gsub(":nvim:.+$", "")
		elseif value:match(":nvim$") then
			tool_action = "nvim"
			value = value:gsub(":nvim$", "")
		end

		local target_ws, project_path
		if value:match("^existing:") then
			target_ws = value:gsub("^existing:", "")
		elseif value:match("^project:") then
			project_path = value:gsub("^project:", "")
			target_ws = project_path:match("([^/]+)$")
		end

		if value:match("^existing:") then
			window:perform_action(act.SwitchToWorkspace({ name = target_ws }), pane)
		elseif value:match("^project:") then
			window:perform_action(
				act.SwitchToWorkspace({ name = target_ws, spawn = { cwd = project_path } }),
				pane
			)
		end

		if tool_action and target_ws then
			local tool = tool_action
			local ws = target_ws
			local file = tool_file
			local cwd = project_path
			wezterm.time.call_after(0.3, function()
				for _, gui_win in ipairs(wezterm.gui.gui_windows()) do
					if gui_win:active_workspace() == ws then
						pcall(open_or_focus_tool, gui_win, tool, file, cwd)
						break
					end
				end
			end)
		end
	end)
end

return M
