--!nocheck
local HttpService  = game:GetService("HttpService")
local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local function toRaw(url)
	if url:find("github%.com") and url:find("/blob/") then
		url=url:gsub("https?://github%.com/", "https://raw.githubusercontent.com/")
		url=url:gsub("/blob/", "/")
	end
	return url
end
local function fetch(url)
	url=toRaw(url)
	local ok, result = pcall(HttpService.GetAsync, HttpService, url)
	if not ok then return nil, result end
	return result
end
local function inferName(url)
	return (url:match("([^/]+)$") or "notion_script"):gsub("%.%w+$", "")
end
local function log(tag, msg)
	print(("[notion :: %s] %s"):format(tag, msg))
end
local function warn_(tag, msg)
	warn(("[notion :: %s] %s"):format(tag, msg))
end
local notion = {}
notion.__index = notion
function notion:get(url, parent, scriptType)
	local src, err = fetch(url)
	if not src then
		warn_(("get"), ("Failed to fetch '%s'\n    → %s"):format(url, err))
		return nil
	end
	local inst = Instance.new(scriptType or "ModuleScript")
	inst.Name   = inferName(url)
	inst.Source = src
	inst.Parent = parent or workspace
	log("get", ("Loaded '%s' → %s"):format(inst.Name, inst.Parent:GetFullName()))
	return inst
end
function notion:run(url)
	local src, err = fetch(url)
	if not src then
		warn_(("run"), ("Fetch failed for '%s'\n    → %s"):format(url, err))
		return
	end
	local fn, parseErr = loadstring(src)
	if not fn then
		warn_(("run"), ("Parse error in '%s'\n    → %s"):format(url, parseErr))
		return
	end

	log("run", ("Executing '%s'"):format(inferName(url)))
	return fn()
end

function notion:read(url)
	local src, err = fetch(url)
	if not src then
		warn_(("read"), ("Could not read '%s'\n    → %s"):format(url, err))
		return nil
	end
	return src
end
function notion:batch(urls, delay)
	assert(type(urls) == "table", "notion:batch expects a table of URLs")
	for i, url in ipairs(urls) do
		log("batch", ("Running %d/%d → '%s'"):format(i, #urls, inferName(url)))
		self:run(url)
		if delay and i < #urls then
			task.wait(delay)
		end
	end
end
function notion:json(url)
	local src, err = fetch(url)
	if not src then
		warn_(("json"), ("Fetch failed → %s"):format(err))
		return nil
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, src)
	if not ok then
		warn_(("json"), ("Decode error → %s"):format(decoded))
		return nil
	end
	return decoded
end
function notion:ping(url)
	local src, err = fetch(url)
	local reachable = src ~= nil
	log("ping", ("%s → %s"):format(url, reachable and "OK" or ("FAIL: " .. tostring(err))))
	return reachable, err
end
function notion:env()
	local plr = Players.LocalPlayer
	print(" Player   :", plr and plr.Name or "N/A")
	print(" UserId   :", plr and plr.UserId or "N/A")
	print(" Game     :", game.Name, "| PlaceId:", game.PlaceId)
	print(" JobId    :", game.JobId ~= "" and game.JobId or "Studio")
	print(" Platform :", RunService:IsStudio() and "Studio" or "Live")
end
setmetatable(notion, {
	__call = function(self, url, parent, scriptType)
		if not url or url == "" then
			warn_("call", "No URL provided.")
			return nil
		end
		return self:get(url, parent, scriptType)
	end
})

return notion
