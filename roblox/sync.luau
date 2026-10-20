-- Забрать код из src/ в открытое место Studio (пара к sync_server.py).
-- Выполнять через MCP execute_luau в режиме Edit, пока запущен python -I sync_server.py.
-- Скрипты, которых нет в src/, не трогает; новые создаёт (папки — Folder).
local HttpService = game:GetService("HttpService")
HttpService.HttpEnabled = true
local list = HttpService:JSONDecode(HttpService:GetAsync("http://127.0.0.1:34873/all", true))
local SPECIAL = { StarterPlayerScripts = true, StarterCharacterScripts = true }
local changed = {}
for _, e in ipairs(list) do
	local node = game:GetService(e.path[1])
	for i = 2, #e.path - 1 do
		local name = e.path[i]
		local child = node:FindFirstChild(name)
		if not child then
			child = Instance.new(SPECIAL[name] and name or "Folder")
			child.Name = name
			child.Parent = node
		end
		node = child
	end
	local name = e.path[#e.path]
	local script = node:FindFirstChild(name)
	if script and script.ClassName ~= e.class then
		script:Destroy()
		script = nil
	end
	if not script then
		script = Instance.new(e.class)
		script.Name = name
		script.Parent = node
	end
	if script.Source ~= e.source then
		script.Source = e.source
		table.insert(changed, table.concat(e.path, "."))
	end
end
return #list .. " files, changed: " .. (#changed > 0 and table.concat(changed, ", ") or "none")
