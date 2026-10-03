-- TODO:
-- https://github.com/zzamboni/dot-hammerspoon/blob/master/init.org#url-dispatching-to-site-specific-browsers
--
--https://github.com/zzamboni/dot-hammerspoon/blob/master/init.org#caffeine-control-systemdisplay-sleep
hs.window.animationDuration = 0

-- Install the `hs` CLI (idempotent) so `hs -c 'hs.reload()'` works from the shell
require("hs.ipc")
hs.ipc.cliInstall("/opt/homebrew")

super = { "alt", "cmd" }

-- -- Keybindings for window management
winmanHotkeys = {
	resizeDown = "j",
	resizeUp = "k",
	resizeRight = "l",
	resizeLeft = "h",
	showDesktop = "o",
	cascadeAllWindows = ",",
	cascadeAppWindows = ".",
	snapToGrid = "/",
	maximizeWindow = ";",
	moveUp = "Up",
	moveDown = "Down",
	moveLeft = "Left",
	moveRight = "Right",
}

winmanScreenProfiles = {
	ultrawide = {
		screenNamePattern = "^MPG 491C OLED$",
		minWidth = 3400,
		minAspectRatio = 2.8,
		layouts = {
			centered = { x = 0.2, y = 0, w = 0.6, h = 1 },
			leftFocus = { x = 0, y = 0, w = 0.2, h = 1 },
			rightFocus = { x = 0.8, y = 0, w = 0.2, h = 1 },
		},
	},
}
require("winman")

-- Ctrl+Shift+Cmd+M: create a superbuilders Google Meet and paste its link
instantMeet = require("instant_meet")

-- Machine-local features should only run on this Mac, not every machine that
-- uses these dotfiles.
local thisMacUUID = hs.execute([[ioreg -rd1 -c IOPlatformExpertDevice | awk -F'"' '/IOPlatformUUID/{print $4}']])
local isSuperbuildersMac = tostring(thisMacUUID):match("603D3362%-8D95%-5386%-8575%-B6C7FF89EA6E") ~= nil
if isSuperbuildersMac then
	require("worksmart_monitor")
end

-- ─── Ultrawide brightness override ──────────────────────────────────────────
-- The MPG 491C OLED ignores DDC brightness while HDR is enabled. With HDR off,
-- push SDR luminance to max whenever the monitor is connected.
local M1DDC = "/opt/homebrew/bin/m1ddc"
local ULTRAWIDE_NAME = "MPG 491C OLED"

local function ultrawideDisplayId()
	local out = hs.execute(M1DDC .. " display list")
	if not out then
		return nil
	end
	for line in out:gmatch("[^\n]+") do
		local id, name = line:match("^%[(%d+)%]%s+(.-)%s+%(")
		if id and name == ULTRAWIDE_NAME then
			return id
		end
	end
	return nil
end

local function setUltrawideBrightness()
	local id = ultrawideDisplayId()
	if id then
		hs.execute(string.format("%s display %s set luminance 100", M1DDC, id))
	end
end

-- Run once on load (covers Hammerspoon reload while monitor is already plugged in)
hs.timer.doAfter(1, setUltrawideBrightness)

-- Re-apply whenever displays change (plug/unplug, wake from sleep)
local lastUltrawidePresent = false
ultrawideWatcher = hs.screen.watcher.new(function()
	local present = false
	for _, s in ipairs(hs.screen.allScreens()) do
		if s:name() == ULTRAWIDE_NAME then
			present = true
			break
		end
	end
	if present and not lastUltrawidePresent then
		hs.timer.doAfter(2, setUltrawideBrightness)
	end
	lastUltrawidePresent = present
end)
ultrawideWatcher:start()
for _, s in ipairs(hs.screen.allScreens()) do
	if s:name() == ULTRAWIDE_NAME then
		lastUltrawidePresent = true
		break
	end
end
-- ────────────────────────────────────────────────────────────────────────────

local module = {}
local appList = {
	["n"] = isSuperbuildersMac and "Nessie" or "Notes",
	["l"] = "Linear",
	["f"] = "Google Chrome",
	["j"] = "Ghostty",
	["s"] = "Slack",
	["w"] = "WorkFlowy",
	["d"] = "Discord",
	["r"] = "Reminders",
	["1"] = "1Password",
	["i"] = "Finder",
	["t"] = "Microsoft Teams",
	["m"] = "Gmail",
	["g"] = "Grok Bot",
}
local urlList = {
	["o"] = "cleanshot://capture-text", -- Capture text (OCR) with Ctrl+Cmd+O
	["e"] = "https://claude.ai/new",
	["0"] = "https://calendar.google.com",
}

for k, v in pairs(urlList) do
	module["app_" .. v] = hs.hotkey.bind({ "ctrl", "cmd" }, k, function()
		hs.execute("open " .. v)
	end)
end

for k, v in pairs(appList) do
	module["app_" .. v] = hs.hotkey.bind({ "ctrl", "cmd" }, k, function()
		hs.application.launchOrFocus(v)
	end)
end

local function centerWindow(win, widthRatio, heightRatio)
	local screenFrame = win:screen():frame()
	local width = screenFrame.w * widthRatio
	local height = screenFrame.h * heightRatio
	local x = screenFrame.x + (screenFrame.w - width) / 2
	local y = screenFrame.y + (screenFrame.h - height) / 2
	win:setFrame(hs.geometry.rect(x, y, width, height))
end

-- ChatGPT desktop launcher
hs.hotkey.bind({ "cmd", "shift" }, "c", function()
	hs.application.launchOrFocus("ChatGPT")
end)

-- ChatGPT desktop: focus and start a new chat
hs.hotkey.bind({ "ctrl", "cmd" }, "c", function()
	hs.application.launchOrFocus("ChatGPT")
	hs.timer.doAfter(0.3, function()
		local app = hs.application.find("ChatGPT")
		if app then
			hs.eventtap.keyStroke({ "cmd" }, "n", 0, app)
		end
	end)
end)

-- Books launcher with large custom window size
hs.hotkey.bind({ "ctrl", "cmd" }, "b", function()
	hs.application.launchOrFocus("Books")

	-- Wait for the app window to appear, then resize and center it
	hs.timer.doAfter(0.5, function()
		local books = hs.application.find("Books")
		if books then
			local win = books:focusedWindow() or books:mainWindow()
			if win then
				centerWindow(win, 0.75, 0.85)
			end
		end
	end)
end)

-- ag (the agent system, ~/ag): inbox capture, session shortcuts, image paste into remote agents,
-- and role-specific power/activity. Optional: a Mac without ag still loads the rest.
local ag_ok, ag_err = pcall(require, "ag")
if not ag_ok and not tostring(ag_err):match("module 'ag' not found") then
	hs.alert.show("ag.lua failed: " .. tostring(ag_err), 8)
end


-- Inspired by https://github.com/jasoncodes/dotfiles/blob/master/hammerspoon/control_escape.lua
-- You'll also have to install Karabiner Elements and map caps_lock to left_control there
len = function(t)
	local length = 0
	for k, v in pairs(t) do
		length = length + 1
	end
	return length
end

send_escape = false
prev_modifiers = {}

local terminal_app_names = {
	["Alacritty"] = true,
	["Ghostty"] = true,
	["iTerm2"] = true,
	["Terminal"] = true,
	["WezTerm"] = true,
}

local function frontmost_app_is_terminal()
	local app = hs.application.frontmostApplication()
	return app ~= nil and terminal_app_names[app:name()] == true
end

-- Terminals attach to Ag's sessions on the session host (`ag`; ag repo `ag-host`), so ask the host
-- whether the focused pane is an agent at its prompt: Escape there would
-- interrupt it. `ag-focus-agent` prints "agent" or "shell" (plain shell, or
-- an editor like nvim in the foreground). On the host itself, run it locally.
local session_host = (hs.execute(os.getenv("HOME") .. "/.local/bin/ag-host") or ""):gsub("%s", "")
if session_host == "" then session_host = "ag-engine" end
local focus_agent_script = "$HOME/.local/bin/ag-focus-agent"
local this_host = (hs.execute("scutil --get LocalHostName") or ""):gsub("%s", "")
local focus_agent_cmd = (this_host == session_host or this_host == "ag")
		and { "/bin/sh", { "-c", focus_agent_script } }
	or { "/usr/bin/ssh", { "-o", "BatchMode=yes", "-o", "ConnectTimeout=2", session_host, focus_agent_script } }

-- nil means unknown: suppress synthetic Escape in terminals until a check
-- succeeds, including after a timeout. Never turn a failed check into "safe".
local agent_pane_is_active = nil
local agent_check = nil
local agent_checked_at = nil

local function update_agent_pane_is_active()
	if not frontmost_app_is_terminal() then
		agent_pane_is_active = nil
		agent_checked_at = nil
		return
	end
	if agent_check then
		agent_check.publish()
		return
	end

	local check = {}
	agent_check = check
	local function fail()
		if agent_check ~= check then
			return
		end
		agent_check = nil
		agent_pane_is_active = nil
		agent_checked_at = nil
		check.timeout:stop()
		if check.task and check.task:isRunning() then
			check.task:terminate()
		end
	end
	check.timeout = hs.timer.doAfter(2, fail)

	-- Direct executable so the timeout terminates the actual process. Streaming
	-- drains stdout; the final chunk may arrive after termination, so parse on
	-- the next poll rather than in the exit callback.
	local chunks = {}
	local tail = ""
	local exited = false
	local exit_code
	check.task = hs.task.new(focus_agent_cmd[1], function(code, stdout)
		exit_code = code
		exited = true
		tail = stdout or ""
	end, function(_, stdout)
		chunks[#chunks + 1] = stdout or ""
		return true
	end, focus_agent_cmd[2])
	check.publish = function()
		if not exited or agent_check ~= check then
			return
		end
		local result = (table.concat(chunks) .. tail):match("^%s*(%a+)")
		if exit_code ~= 0 or (result ~= "agent" and result ~= "shell") then
			return fail()
		end
		agent_pane_is_active = result == "agent"
		agent_checked_at = hs.timer.absoluteTime()
		check.timeout:stop()
		agent_check = nil
	end
	if not check.task or not check.task:start() then
		fail()
	end
end

update_agent_pane_is_active()
agent_pane_timer = hs.timer.doEvery(0.5, update_agent_pane_is_active)

modifier_handler = function(evt)
	-- evt:getFlags() holds the modifiers that are currently held down
	local curr_modifiers = evt:getFlags()

	if curr_modifiers["ctrl"] and len(curr_modifiers) == 1 and len(prev_modifiers) == 0 then
		-- We need this here because we might have had additional modifiers, which
		-- we don't want to lead to an escape, e.g. [Ctrl + Cmd] —> [Ctrl] —> [ ]
		send_escape = true
	elseif prev_modifiers["ctrl"] and len(curr_modifiers) == 0 and send_escape then
		send_escape = false
		local terminal = frontmost_app_is_terminal()
		local fresh = agent_checked_at and hs.timer.absoluteTime() - agent_checked_at < 2e9
		if not terminal or (fresh and agent_pane_is_active == false) then
			hs.eventtap.keyStroke({}, "ESCAPE")
		end
	else
		send_escape = false
	end
	prev_modifiers = curr_modifiers
	return false
end

-- One tap observes both halves of the gesture. Separate taps can be disabled
-- independently by macOS, leaving the release handler injecting Escape after
-- Ctrl-b because the other tap never saw the b key.
control_escape_tap = hs.eventtap.new({
	hs.eventtap.event.types.flagsChanged,
	hs.eventtap.event.types.keyDown,
}, function(evt)
	if evt:getType() == hs.eventtap.event.types.keyDown then
		send_escape = false
		return false
	end
	return modifier_handler(evt)
end):start()

-- Clear gesture state before restarting so a release cannot complete an old
-- Control press after macOS disables the tap or enters Secure Input.
control_escape_watchdog = hs.timer.doEvery(0.5, function()
	local secure = hs.eventtap.isSecureInputEnabled()
	if secure or not control_escape_tap:isEnabled() then
		send_escape = false
		prev_modifiers = {}
		if not secure then
			control_escape_tap:start()
		end
	end
end)

hs.hotkey.bind({ "cmd", "alt", "ctrl" }, "h", function()
	hs.reload()
end)
