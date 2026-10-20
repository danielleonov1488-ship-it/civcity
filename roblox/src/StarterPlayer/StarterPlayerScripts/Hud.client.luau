-- Steal a Legion — интерфейс игрока: деньги, доход, замок базы, перерождение, сообщения,
-- таблички над римлянами, суммы на плитах, имена хозяев над воротами, отброс от удара.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Locale = require(ReplicatedStorage:WaitForChild("Locale"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
Locale.setLang(player.LocaleId)
local L = Locale.t

local FONT = Enum.Font.FredokaOne
local GOLD = Color3.fromRGB(255, 205, 70)
local GREEN = Color3.fromRGB(110, 235, 120)
local RED = Color3.fromRGB(255, 90, 80)

local gui = Instance.new("ScreenGui")
gui.Name = "LegionHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Parent = player:WaitForChild("PlayerGui")

local boards = Instance.new("Folder")
boards.Name = "LegionBoards"
boards.Parent = player.PlayerGui

local function label(parent, props)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = FONT
	t.TextScaled = true
	t.TextColor3 = Color3.new(1, 1, 1)
	for k, v in pairs(props) do
		t[k] = v
	end
	local s = Instance.new("UIStroke")
	s.Thickness = 2
	s.Color = Color3.fromRGB(20, 14, 10)
	s.Parent = t
	t.Parent = parent
	return t
end

local function corner(parent, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

---------------------------------------------------------------- верх: деньги и доход

local top = Instance.new("Frame")
top.AnchorPoint = Vector2.new(0.5, 0)
top.Position = UDim2.new(0.5, 0, 0, 6)
top.Size = UDim2.fromOffset(320, 92)
top.BackgroundTransparency = 1
top.Parent = gui

local cashLabel = label(top, { Size = UDim2.new(1, 0, 0, 52), Text = "$0", TextColor3 = GOLD })
local incomeLabel = label(top, { Position = UDim2.fromOffset(0, 52), Size = UDim2.new(1, 0, 0, 26), Text = "", TextColor3 = GREEN })

local lockLabel = label(gui, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 96),
	Size = UDim2.fromOffset(620, 24),
	Text = "",
})

local carryBanner = label(gui, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.3),
	Size = UDim2.fromOffset(620, 64),
	Text = L("carry_banner"),
	TextColor3 = RED,
	Visible = false,
})

---------------------------------------------------------------- кнопка перерождения

local rebirthBtn = Instance.new("TextButton")
rebirthBtn.AnchorPoint = Vector2.new(1, 1)
rebirthBtn.Position = UDim2.new(1, -16, 1, -110)
rebirthBtn.Size = UDim2.fromOffset(210, 70)
rebirthBtn.BackgroundColor3 = Color3.fromRGB(120, 40, 140)
rebirthBtn.AutoButtonColor = true
rebirthBtn.Text = ""
rebirthBtn.Parent = gui
corner(rebirthBtn, 14)
local rbStroke = Instance.new("UIStroke")
rbStroke.Thickness = 3
rbStroke.Color = GOLD
rbStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
rbStroke.Parent = rebirthBtn
local rbTitle = label(rebirthBtn, { Size = UDim2.new(1, -12, 0, 34), Position = UDim2.fromOffset(6, 4), Text = L("rebirth") })
local rbNeed = label(rebirthBtn, { Size = UDim2.new(1, -12, 0, 24), Position = UDim2.fromOffset(6, 40), Text = "", TextColor3 = GOLD })
rebirthBtn.Activated:Connect(function()
	remotes.Rebirth:FireServer()
end)

---------------------------------------------------------------- сообщения

local toasts = Instance.new("Frame")
toasts.AnchorPoint = Vector2.new(0.5, 0)
toasts.Position = UDim2.new(0.5, 0, 0, 126)
toasts.Size = UDim2.fromOffset(640, 200)
toasts.BackgroundTransparency = 1
toasts.Parent = gui
local list = Instance.new("UIListLayout")
list.HorizontalAlignment = Enum.HorizontalAlignment.Center
list.Padding = UDim.new(0, 4)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = toasts
local toastN = 0

local function toast(text, color)
	toastN = toastN + 1
	local t = label(toasts, { Size = UDim2.fromOffset(640, 30), Text = text, TextColor3 = color or Color3.new(1, 1, 1), LayoutOrder = toastN, TextTransparency = 1 })
	TweenService:Create(t, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()
	local items = {}
	for _, c in ipairs(toasts:GetChildren()) do
		if c:IsA("TextLabel") then
			table.insert(items, c)
		end
	end
	if #items > 4 then
		table.sort(items, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		items[1]:Destroy()
	end
	task.delay(3.6, function()
		if t.Parent then
			local tw = TweenService:Create(t, TweenInfo.new(0.5), { TextTransparency = 1 })
			tw:Play()
			tw.Completed:Wait()
			t:Destroy()
		end
	end)
end

local function arg(a)
	if type(a) ~= "string" then
		return tostring(a)
	end
	local kind, id = string.match(a, "^@(%a):(.*)$")
	if kind == "u" then
		return Locale.unit(id)
	elseif kind == "r" then
		return Locale.rarity(id)
	elseif kind == "m" then
		return Locale.mut(id ~= "" and id or nil)
	end
	return a
end

local TOAST_COLOR = {
	no_money = RED, no_slot = RED, is_locked = RED, being_stolen = RED, lost = RED, dropped = RED,
	bought = GREEN, stolen_ok = GREEN, defended = GREEN, run_home = GOLD, base_locked = GREEN,
	unlocked = GOLD, rebirth_done = GOLD, welcome = GOLD,
}

remotes.Notify.OnClientEvent:Connect(function(key, args, rarity)
	local parts = {}
	for i, a in ipairs(args or {}) do
		parts[i] = arg(a)
	end
	local color = TOAST_COLOR[key]
	if key == "spawn_rare" and rarity and Config.RARITY[rarity] then
		color = Config.RARITY[rarity].color
		if rarity == "secret" then
			color = Color3.fromRGB(240, 240, 240)
		end
	end
	toast(L(key, table.unpack(parts)), color)
end)

---------------------------------------------------------------- отброс от удара и деньги с плиты

remotes.Knock.OnClientEvent:Connect(function(v)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum then
		return
	end
	hum.PlatformStand = true
	hrp.AssemblyLinearVelocity = v
	task.delay(0.8, function()
		if hum.Parent then
			hum.PlatformStand = false
		end
	end)
end)

remotes.Collected.OnClientEvent:Connect(function(amount, pos)
	local att = Instance.new("Attachment")
	att.WorldPosition = pos
	att.Parent = workspace.Terrain
	local bb = Instance.new("BillboardGui")
	bb.Adornee = att
	bb.Size = UDim2.fromOffset(160, 40)
	bb.StudsOffset = Vector3.new(0, 2, 0)
	bb.AlwaysOnTop = true
	bb.Parent = boards
	local t = label(bb, { Size = UDim2.fromScale(1, 1), Text = "+$" .. Config.fmt(amount), TextColor3 = GREEN })
	TweenService:Create(bb, TweenInfo.new(1.1), { StudsOffset = Vector3.new(0, 6, 0) }):Play()
	TweenService:Create(t, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 }):Play()
	task.delay(1.2, function()
		bb:Destroy()
		att:Destroy()
	end)
end)

---------------------------------------------------------------- таблички над римлянами

local function ownerMult(userId)
	local pl = userId and userId ~= 0 and Players:GetPlayerByUserId(userId)
	return pl and (pl:GetAttribute("Multiplier") or 1) or 1
end

local function setupUnit(model)
	local root = model.PrimaryPart or model:WaitForChild("Root", 5)
	local id = model:GetAttribute("UnitId")
	local unit = id and Config.UNIT[id]
	if not root or not unit then
		return
	end
	local rar = Config.RARITY[unit.rarity]
	local mut = model:GetAttribute("Mut")
	if mut == "" then
		mut = nil
	end

	local bb = Instance.new("BillboardGui")
	bb.Adornee = root
	bb.Size = UDim2.fromOffset(210, 86)
	bb.StudsOffset = Vector3.new(0, (model:GetAttribute("Height") or 5) + 2.4, 0)
	bb.MaxDistance = 75
	bb.LightInfluence = 0
	bb.Parent = boards
	local y = 0
	if mut then
		label(bb, { Size = UDim2.new(1, 0, 0, 18), Text = Locale.mut(mut), TextColor3 = Config.MUTATIONS[mut].color })
		y = 18
	end
	label(bb, { Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 26), Text = Locale.unit(id) })
	local rl = label(bb, { Position = UDim2.fromOffset(0, y + 26), Size = UDim2.new(1, 0, 0, 20), Text = Locale.rarity(unit.rarity), TextColor3 = rar.color })
	if unit.rarity == "secret" then
		rl.TextColor3 = Color3.fromRGB(20, 20, 20)
		rl:FindFirstChildOfClass("UIStroke").Color = Color3.fromRGB(255, 255, 255)
	end
	local value = label(bb, { Position = UDim2.fromOffset(0, y + 46), Size = UDim2.new(1, 0, 0, 22), Text = "", TextColor3 = GREEN })

	-- детали модели доходят до клиента не всегда вместе с ней: кнопку ждём, а не ищем
	local promptAt = root:WaitForChild("PromptAt", 5)
	local prompt = promptAt and promptAt:WaitForChild("Prompt", 5)
	-- кнопку видит тот, кому она нужна: на дороге — все, на базе — все, кроме хозяина
	-- (сервер включает её для всех; своё «выключено» клиент ставит заново после любой смены)
	local function syncPrompt()
		local state = model:GetAttribute("State")
		local want = state == "belt" or (state == "home" and model:GetAttribute("Owner") ~= player.UserId)
		if prompt.Enabled ~= want then
			prompt.Enabled = want
		end
	end
	local function update()
		local state = model:GetAttribute("State")
		local owner = model:GetAttribute("Owner")
		if state == "belt" then
			value.Text = "$" .. Config.fmt(unit.price)
			value.TextColor3 = GOLD
		else
			local inc = unit.income * (mut and Config.MUTATIONS[mut].mult or 1) * ownerMult(owner)
			value.Text = L("income", Config.fmt(inc))
			value.TextColor3 = GREEN
		end
		if prompt then
			prompt.ObjectText = Locale.unit(id)
			if state == "belt" then
				prompt.ActionText = L("buy") .. " $" .. Config.fmt(unit.price)
			elseif state == "home" then
				prompt.ActionText = L("steal")
			end
			syncPrompt()
		end
	end
	update()
	model:GetAttributeChangedSignal("State"):Connect(update)
	model:GetAttributeChangedSignal("Owner"):Connect(update)
	if prompt then
		prompt:GetPropertyChangedSignal("Enabled"):Connect(syncPrompt)
	end
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) then
			bb:Destroy()
		end
	end)
end

---------------------------------------------------------------- плиты сбора, таблички баз, плиты замка

local function setupPad(pad)
	local bb = Instance.new("BillboardGui")
	bb.Adornee = pad
	bb.Size = UDim2.fromOffset(130, 34)
	bb.StudsOffset = Vector3.new(0, 1.6, 0)
	bb.MaxDistance = 45
	bb.LightInfluence = 0
	bb.Parent = boards
	local t = label(bb, { Size = UDim2.fromScale(1, 1), Text = "", TextColor3 = GREEN })
	local function update()
		local bank = pad:GetAttribute("Bank") or 0
		t.Text = bank > 0 and ("$" .. Config.fmt(bank)) or ""
	end
	update()
	pad:GetAttributeChangedSignal("Bank"):Connect(update)
end

local signs = {}
local function setupSign(sign)
	local bb = Instance.new("BillboardGui")
	bb.Adornee = sign
	bb.Size = UDim2.fromOffset(300, 74)
	bb.MaxDistance = 220
	bb.LightInfluence = 0
	bb.Parent = boards
	local name = label(bb, { Size = UDim2.new(1, 0, 0, 40), Text = "" })
	local lock = label(bb, { Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 0, 28), Text = "" })
	table.insert(signs, { sign = sign, name = name, lock = lock })
end

local function setupLockPad(pad)
	local bb = Instance.new("BillboardGui")
	bb.Adornee = pad
	bb.Size = UDim2.fromOffset(170, 30)
	bb.StudsOffset = Vector3.new(0, 2, 0)
	bb.MaxDistance = 40
	bb.LightInfluence = 0
	bb.Parent = boards
	label(bb, { Size = UDim2.fromScale(1, 1), Text = "🔒 " .. L("lock_pad"), TextColor3 = RED })
end

local function watch(tag, fn)
	for _, inst in ipairs(CollectionService:GetTagged(tag)) do
		task.spawn(fn, inst)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(fn)
end
watch("Unit", setupUnit)
watch("Pad", setupPad)
watch("PlotSign", setupSign)
watch("LockPad", setupLockPad)

---------------------------------------------------------------- обновление каждый кадр

RunService.RenderStepped:Connect(function()
	local cash = player:GetAttribute("Cash") or 0
	cashLabel.Text = "$" .. Config.fmt(cash)
	local inc = player:GetAttribute("Income") or 0
	incomeLabel.Text = inc > 0 and L("income", Config.fmt(inc)) or ""

	local nowT = workspace:GetServerTimeNow()
	local lockUntil = player:GetAttribute("LockUntil") or 0
	if lockUntil > nowT then
		lockLabel.Text = L("your_lock", math.ceil(lockUntil - nowT))
		lockLabel.TextColor3 = GREEN
	else
		lockLabel.Text = L("your_open")
		lockLabel.TextColor3 = RED
	end

	local cost = player:GetAttribute("RebirthCost") or 0
	if cash >= cost and cost > 0 then
		rbNeed.Text = L("rebirth_ready", tostring(Config.multiplier((player:GetAttribute("Rebirths") or 0) + 1)))
		rebirthBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 175)
	else
		rbNeed.Text = L("rebirth_need", Config.fmt(cost))
		rebirthBtn.BackgroundColor3 = Color3.fromRGB(90, 40, 100)
	end

	local carrying = player:GetAttribute("Carrying") == true
	carryBanner.Visible = carrying
	if carrying then
		carryBanner.TextTransparency = 0.15 + 0.15 * math.sin(os.clock() * 8)
	end

	for _, s in ipairs(signs) do
		local owner = s.sign:GetAttribute("OwnerName") or ""
		s.name.Text = owner ~= "" and L("base_of", owner) or L("free_base")
		s.name.TextColor3 = owner == player.DisplayName and GOLD or Color3.new(1, 1, 1)
		local lu = s.sign:GetAttribute("LockUntil") or 0
		if owner == "" then
			s.lock.Text = ""
		elseif lu > nowT then
			s.lock.Text = "🔒 " .. L("locked", math.ceil(lu - nowT))
			s.lock.TextColor3 = RED
		else
			s.lock.Text = L("open")
			s.lock.TextColor3 = GREEN
		end
	end
end)
