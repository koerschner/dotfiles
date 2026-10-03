-- ag-rule terminal-screenshot-paste (spec: rule.md beside this); hook: hammerspoon, loaded by ag.lua with agLib.
-- Sessions run on the session host (ag-host), so an image on this Mac's clipboard can't reach pi there.
-- Cmd+V in an Ag terminal window with an image (or copied image files) on the clipboard:
-- upload it to <host>:~/inbox/clipboard/ and type the remote path instead. Pi reads
-- image paths as attachments. Plain text pastes are untouched. Skipped on the host itself.
local AG_HOST_BIN = os.getenv("HOME") .. "/.local/bin/ag-host"
local PASTE_HOST = (hs.execute(AG_HOST_BIN):gsub("%s", ""))
if PASTE_HOST == "" then PASTE_HOST = "ag-engine" end
-- Whether this Mac is the session host (machines/README.md via machine-role).
local IS_HOST = select(2, hs.execute(os.getenv("HOME") .. "/.local/bin/machine-role host")) == true
local PASTE_DIR = "inbox/clipboard"
local PASTE_REMOTE_HOME = (hs.execute(AG_HOST_BIN .. " --home"):gsub("%s", "")) -- pi wants absolute paths
local IMAGE_EXT = { png = true, jpg = true, jpeg = true, gif = true, webp = true, heic = true }

-- Returns { {src=<local file>, ext=<remote ext>, convert=<bool>} ... } or nil. No image
-- encoding happens here: copied files are used as-is, and a raw clipboard image is
-- written as its raw bytes (instant); PNG conversion happens after the path is typed.
local function clipboardImages()
	local out = {}
	for _, u in ipairs(hs.pasteboard.readURL(nil, true) or {}) do
		local path = u.filePath
		local ext = path and (path:match("%.(%w+)$") or ""):lower()
		if ext and IMAGE_EXT[ext] then
			table.insert(out, { src = path, ext = ext })
		end
	end
	if #out > 0 then
		return out
	end
	for _, uti in ipairs({ "public.png", "public.tiff" }) do
		local data = hs.pasteboard.readDataForUTI(uti)
		if data and #data > 0 then
			local tmp = os.tmpname()
			local f = io.open(tmp, "wb")
			f:write(data)
			f:close()
			return { { src = tmp, ext = "png", convert = uti == "public.tiff", tmp = true } }
		end
	end
	return nil
end

local function shq(s)
	return "'" .. (s:gsub("'", "'\\''")) .. "'"
end

-- Type the (deterministic) remote paths immediately, upload in the background over one
-- multiplexed ssh connection (ControlMaster in ssh config). The upload finishes long
-- before you hit Enter; an alert appears only if it fails.
-- Pre-upload: every CleanShot capture is pushed to ag the moment it's written, so by
-- the time you press Cmd+V the file is already there and the paste just types its path.
-- CleanShot copies a file URL to its media folder PNG, which is matched against this map.
ag_preuploaded = {} -- local path -> remote path
local preuploaded = ag_preuploaded
local function uploadCmd(src, name, convert, tmp)
	local q = shq(src)
	local prep = convert and ("sips -s format png " .. q .. " --out " .. q .. ".png >/dev/null && ") or ""
	local up = convert and (q .. ".png") or q
	-- Write to .part then rename, so an agent never reads a half-uploaded file.
	return prep .. "ssh " .. PASTE_HOST .. " "
		.. shq("cat > " .. name .. ".part && mv " .. name .. ".part " .. name)
		.. " < " .. up .. (tmp and (" && rm -f " .. q .. " " .. q .. ".png") or "")
end

ag_upload_log = {} -- recent { started, finished, code } for debugging paste latency
local function runUpload(cmd)
	local entry = { started = hs.timer.secondsSinceEpoch() }
	table.insert(ag_upload_log, entry)
	if #ag_upload_log > 20 then
		table.remove(ag_upload_log, 1)
	end
	hs.task
		.new("/bin/sh", function(code, _, err)
			entry.finished, entry.code = hs.timer.secondsSinceEpoch(), code
			if code ~= 0 then
				hs.alert.show("Image upload to ag failed: " .. (err or ""), 5)
			end
		end, { "-c", cmd })
		:start()
end

-- Debounced: CleanShot writes, then may rewrite (annotations). Upload 50ms after the last
-- event, reusing the same remote name so the path you pasted stays valid.
local preuploadTimers = {}
local function preupload(path)
	local ext = (path:match("%.(%w+)$") or ""):lower()
	local base = path:match("[^/]+$")
	if not IMAGE_EXT[ext] or base:sub(1, 1) == "." then
		return
	end
	if not preuploaded[path] then
		local name = string.format("%s/%s-%s.%s", PASTE_DIR, os.date("%Y%m%d-%H%M%S"), hs.host.uuid():sub(1, 6), ext)
		preuploaded[path] = PASTE_REMOTE_HOME .. "/" .. name
	end
	local name = preuploaded[path]:sub(#PASTE_REMOTE_HOME + 2)
	if preuploadTimers[path] then
		preuploadTimers[path]:stop()
	end
	preuploadTimers[path] = hs.timer.doAfter(0.05, function()
		preuploadTimers[path] = nil
		if hs.fs.attributes(path) then
			runUpload(uploadCmd(path, name))
		end
	end)
end

-- Insert text as one terminal paste (keyStrokes sends one event per character, which
-- is slow through remote tmux). Swap the clipboard, send Cmd+V, restore it.
local pastingText = false
local function pasteText(text)
	local saved = hs.pasteboard.readAllData()
	hs.pasteboard.setContents(text)
	pastingText = true
	hs.eventtap.keyStroke({ "cmd" }, "v", 0)
	hs.timer.doAfter(0.3, function()
		pastingText = false
		hs.pasteboard.writeAllData(saved)
	end)
end

local function pasteImagesToAg(images)
	local stamp = os.date("%Y%m%d-%H%M%S")
	local remote, cmd = {}, {}
	for i, im in ipairs(images) do
		if preuploaded[im.src] then
			table.insert(remote, preuploaded[im.src])
		else
			local name = string.format("%s/%s-%d.%s", PASTE_DIR, stamp, i, im.ext)
			table.insert(remote, PASTE_REMOTE_HOME .. "/" .. name)
			table.insert(cmd, uploadCmd(im.src, name, im.convert, im.tmp))
		end
	end
	pasteText(table.concat(remote, " ") .. " ")
	if #cmd > 0 then
		runUpload(table.concat(cmd, " && "))
	end
end
ag_paste_images = function() -- debug/test entry point: same as Cmd+V in an Ag window
	local images = clipboardImages()
	if images then
		pasteImagesToAg(images)
	end
	return images ~= nil
end

-- Keep the ssh master warm so the first paste is fast too.
if not IS_HOST then
	ag_ssh_warm = hs.timer.doEvery(600, function()
		hs.task.new("/bin/sh", nil, { "-c", "mkdir -p ~/.ssh/sockets && { ssh -O check " .. PASTE_HOST .. " 2>/dev/null || ssh -fN " .. PASTE_HOST .. "; } && ssh " .. PASTE_HOST .. " mkdir -p " .. PASTE_DIR }):start()
	end)
	ag_ssh_warm:fire()

	-- Watch CleanShot's capture folders (media history holds the copied PNG; ~/Screenshots
	-- gets the saved one). Only files created after startup are uploaded.
	local started = os.time()
	ag_capture_watchers = {}
	for _, dir in ipairs({ os.getenv("HOME") .. "/Library/Application Support/CleanShot/media", os.getenv("HOME") .. "/Screenshots" }) do
		local w = hs.pathwatcher.new(dir, function(paths, flags)
			for i, p in ipairs(paths) do
				local f = flags[i]
				if (f.itemCreated or f.itemRenamed or f.itemModified) and f.itemIsFile then
					local attrs = hs.fs.attributes(p)
					if attrs and attrs.size > 0 and attrs.creation >= started then
						preupload(p)
					end
				end
			end
		end)
		w:start()
		table.insert(ag_capture_watchers, w)
	end
end

if not IS_HOST then
	ag_image_paste_tap = hs.eventtap
		.new({ hs.eventtap.event.types.keyDown }, function(evt)
			if pastingText or hs.keycodes.map[evt:getKeyCode()] ~= "v" or not agLib.flagsMatch(evt:getFlags(), { cmd = true }) then
				return false
			end
			if not agLib.focusedWindowIsAg() then
				return false
			end
			local images = clipboardImages()
			if not images then
				return false
			end
			pasteImagesToAg(images)
			return true
		end)
		:start()
end

return { paste = ag_paste_images, preuploaded = ag_preuploaded, log = ag_upload_log }
