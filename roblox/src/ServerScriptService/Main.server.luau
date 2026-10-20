-- Steal a Legion — сервер: дорога с римлянами, покупка, база, доход, кража, удар гладиусом, замок, перерождение, сохранение.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Figures = require(script.Parent:WaitForChild("Figures"))
local World = require(script.Parent:WaitForChild("World"))

Players.CharacterAutoLoads = false

-- связь с игроками
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage
local function remote(name)
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end
local Notify = remote("Notify") -- (ключ текста, параметры)
local Knock = remote("Knock") -- (скорость отброса)
local Collected = remote("Collected") -- (сумма, место)
local RebirthReq = remote("Rebirth")

local world = World.build()
local plots = world.plots
local beltFolder = world.belt

local profiles = {} -- [Player] = профиль
local refreshPedestals -- объявлено ниже
local belt = {} -- римляне на дороге

local function now()
	return workspace:GetServerTimeNow()
end

-- сохранения (в Studio без доступа к API просто не сохраняется)
local store = nil
do
	local ok, res = pcall(function()
		return DataStoreService:GetDataStore("StealALegion_v1")
	end)
	if ok then
		store = res
	end
end

---------------------------------------------------------------- профиль игрока

local function freeSlot(p)
	for s = 1, Config.slots(p.rebirths) do
		if not p.slots[s] then
			return s
		end
	end
	return nil
end

local function incomeOf(p)
	local total = 0
	for _, u in pairs(p.slots) do
		if u.state == "home" then
			total = total + Config.unitIncome(u.id, u.mut, p.rebirths)
		end
	end
	return total
end

local function setCash(p, v)
	p.cash = v
	local ls = p.player:FindFirstChild("leaderstats")
	if ls then
		ls.Cash.Value = math.floor(math.min(v, 9e15))
	end
	p.player:SetAttribute("Cash", v)
end

local function refreshAttrs(p)
	local pl = p.player
	pl:SetAttribute("Income", incomeOf(p))
	pl:SetAttribute("Rebirths", p.rebirths)
	pl:SetAttribute("RebirthCost", Config.rebirthCost(p.rebirths))
	pl:SetAttribute("Multiplier", Config.multiplier(p.rebirths))
	pl:SetAttribute("LockUntil", p.lockUntil)
	pl:SetAttribute("Carrying", p.carrying ~= nil)
	local ls = pl:FindFirstChild("leaderstats")
	if ls then
		ls.Rebirths.Value = p.rebirths
		ls.Steals.Value = p.steals
	end
end

-- постаменты: сколько открыто у хозяина
refreshPedestals = function(plot, p)
	local open = p and Config.slots(p.rebirths) or 0
	for s, slot in ipairs(plot.slots) do
		local on = s <= open
		slot.pedestal.Transparency = on and 0 or 0.75
		slot.pad.Transparency = on and 0.2 or 1
		slot.pad.CanTouch = on
		if not on then
			slot.pad:SetAttribute("Bank", 0)
		end
	end
end

---------------------------------------------------------------- римляне (юниты)

local onPrompt -- объявлено ниже

local function makeUnit(id, mut)
	local model = Figures.build(id, mut)
	model:SetAttribute("UnitId", id)
	model:SetAttribute("Mut", mut or "")
	model:SetAttribute("Owner", 0)
	model:SetAttribute("State", "belt")
	CollectionService:AddTag(model, "Unit")
	local root = model.PrimaryPart
	local att = Instance.new("Attachment")
	att.Name = "PromptAt"
	att.Position = Vector3.new(0, (model:GetAttribute("Height") or 5) * 0.55, 0)
	att.Parent = root
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Prompt"
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 13
	prompt.RequiresLineOfSight = false
	prompt.ActionText = "Buy"
	prompt.ObjectText = Config.UNIT[id].en
	prompt.Parent = att
	local u = { id = id, mut = mut, model = model, root = root, prompt = prompt, state = "belt" }
	prompt.Triggered:Connect(function(player)
		onPrompt(u, player)
	end)
	return u
end

local function setState(u, state)
	u.state = state
	u.model:SetAttribute("State", state)
	u.prompt.Enabled = state == "belt" or state == "home"
	if state == "home" then
		u.prompt.HoldDuration = Config.STEAL_HOLD
	end
end

local function destroyUnit(u)
	u.state = "gone"
	if u.carryWeld then
		u.carryWeld:Destroy()
		u.carryWeld = nil
	end
	if u.model then
		u.model:Destroy()
	end
end

local function slotCF(p, slot)
	return p.plot.slots[slot].cf
end

-- переставить фигурку целиком. Пока модель не в workspace, сварка не тянет детали за корнем,
-- поэтому при переносе корня вне мира детали оставались бы на старом месте — PivotTo двигает всё.
local function place(u, cf)
	u.model:PivotTo(cf)
end

-- поставить юнита на постамент хозяина (сразу или пешком от текущего места)
local function assign(u, p, slot, walk)
	u.owner = p
	u.slot = slot
	p.slots[slot] = u
	u.model:SetAttribute("Owner", p.player.UserId)
	if walk then
		local from = u.root.Position
		local plot = p.plot
		u.walkPos = Vector3.new(from.X, 1.3, from.Z)
		u.path = {
			Vector3.new(plot.entranceOut.X, 1.3, from.Z),
			plot.entranceOut,
			plot.entranceIn,
			plot.slots[slot].cf.Position,
		}
		u.pathI = 1
		u.model.Parent = p.plot.units
		setState(u, "walk")
	else
		place(u, slotCF(p, slot))
		u.model.Parent = p.plot.units
		setState(u, "home")
	end
end

---------------------------------------------------------------- дорога

local function rollRarity()
	local total = 0
	for _, r in ipairs(Config.RARITIES) do
		total = total + r.weight
	end
	local x = math.random() * total
	for _, r in ipairs(Config.RARITIES) do
		x = x - r.weight
		if x <= 0 then
			return r.id
		end
	end
	return "common"
end

local function rollMut()
	local x = math.random()
	local d = Config.MUTATIONS.diamond.chance
	if x < d then
		return "diamond"
	elseif x < d + Config.MUTATIONS.gold.chance then
		return "gold"
	end
	return nil
end

local function spawnBelt(force)
	local rid = force or rollRarity()
	local list = Config.BY_RARITY[rid]
	local id = list[math.random(1, #list)].id
	local u = makeUnit(id, rollMut())
	u.x = Config.BELT_START
	u.phase = math.random() * 6
	place(u, CFrame.new(u.x, 1.3, 0) * CFrame.Angles(0, -math.pi / 2, 0))
	u.model.Parent = beltFolder
	table.insert(belt, u)
	if Config.RARITY[rid].rank >= 4 then
		Notify:FireAllClients("spawn_rare", { "@r:" .. rid, "@u:" .. id }, rid)
	end
end

local function removeFromBelt(u)
	for i, b in ipairs(belt) do
		if b == u then
			table.remove(belt, i)
			return
		end
	end
end

---------------------------------------------------------------- покупка и кража

local function buy(u, player)
	local p = profiles[player]
	if not p or u.state ~= "belt" then
		return
	end
	local price = Config.UNIT[u.id].price
	if p.cash < price then
		Notify:FireClient(player, "no_money", {})
		return
	end
	local slot = freeSlot(p)
	if not slot then
		Notify:FireClient(player, "no_slot", {})
		return
	end
	setCash(p, p.cash - price)
	removeFromBelt(u)
	assign(u, p, slot, true)
	Notify:FireClient(player, "bought", { "@u:" .. u.id })
end

local function charParts(player)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hrp and hum and hum.Health > 0 then
		return char, hrp, hum
	end
	return nil
end

local function releaseCarry(u)
	local carrier = u.carrier
	u.carrier = nil
	if u.carryWeld then
		u.carryWeld:Destroy()
		u.carryWeld = nil
	end
	u.root.Anchored = true
	if carrier then
		carrier.carrying = nil
		local _, _, hum = charParts(carrier.player)
		if hum then
			hum.WalkSpeed = Config.PLAYER_SPEED
		end
		refreshAttrs(carrier)
	end
end

-- вор выронил добычу: юнит возвращается хозяину
local function returnHome(u)
	releaseCarry(u)
	local owner = u.owner
	if owner and profiles[owner.player] and owner.slots[u.slot] == u then
		place(u, slotCF(owner, u.slot))
		setState(u, "home")
		refreshAttrs(owner)
	else
		destroyUnit(u)
	end
end

local function steal(u, player)
	local thief = profiles[player]
	local owner = u.owner
	if not thief or not owner or thief == owner or u.state ~= "home" or thief.carrying then
		return
	end
	if owner.lockUntil > now() then
		Notify:FireClient(player, "is_locked", {})
		return
	end
	if not freeSlot(thief) then
		Notify:FireClient(player, "no_slot", {})
		return
	end
	local _, hrp, hum = charParts(player)
	if not hrp then
		return
	end
	u.carrier = thief
	thief.carrying = u
	setState(u, "carried")
	place(u, hrp.CFrame * CFrame.new(0, 3.4, 0))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hrp
	weld.Part1 = u.root
	weld.Parent = u.root
	u.carryWeld = weld
	u.root.Anchored = false
	hum.WalkSpeed = Config.CARRY_SPEED
	refreshAttrs(owner)
	refreshAttrs(thief)
	Notify:FireClient(owner.player, "being_stolen", { player.DisplayName, "@u:" .. u.id })
	Notify:FireClient(player, "run_home", {})
end

-- вор добежал до своей базы
local function deliver(thief)
	local u = thief.carrying
	local owner = u.owner
	local slot = freeSlot(thief)
	if not slot then
		returnHome(u)
		Notify:FireClient(thief.player, "no_slot", {})
		return
	end
	releaseCarry(u)
	if owner and owner.slots[u.slot] == u then
		owner.slots[u.slot] = nil
	end
	assign(u, thief, slot, false)
	thief.steals = thief.steals + 1
	refreshAttrs(thief)
	Notify:FireClient(thief.player, "stolen_ok", { "@u:" .. u.id })
	if owner and profiles[owner.player] then
		refreshAttrs(owner)
		Notify:FireClient(owner.player, "lost", { thief.player.DisplayName, "@u:" .. u.id })
	end
end

-- вора ударили или он погиб: добыча падает и уходит домой
local function drop(thief, byPlayer)
	local u = thief.carrying
	if not u then
		return
	end
	returnHome(u)
	Notify:FireClient(thief.player, "dropped", { "@u:" .. u.id })
	if byPlayer and u.owner and byPlayer == u.owner.player then
		Notify:FireClient(byPlayer, "defended", { "@u:" .. u.id })
	end
end

onPrompt = function(u, player)
	if u.state == "belt" then
		buy(u, player)
	elseif u.state == "home" then
		steal(u, player)
	end
end

---------------------------------------------------------------- плиты сбора денег

local function collect(p, s)
	local bank = p.banks[s] or 0
	if bank < 1 then
		return
	end
	local pad = p.plot.slots[s].pad
	p.banks[s] = 0
	pad:SetAttribute("Bank", 0)
	setCash(p, p.cash + bank)
	Collected:FireClient(p.player, bank, pad.Position)
end

-- хозяин стоит на плите (Touched срабатывает только при наступании, а стоять и собирать — удобнее)
local function standsOn(pad, pos)
	local o = pad.CFrame:PointToObjectSpace(pos)
	return math.abs(o.X) < pad.Size.X / 2 + 0.8 and math.abs(o.Z) < pad.Size.Z / 2 + 0.8 and o.Y > 0 and o.Y < 6
end

---------------------------------------------------------------- замок базы

local function setBarrier(plot, on)
	plot.barrier.Transparency = on and 0.88 or 1
	plot.barrier.CanCollide = on
	for _, beam in ipairs(plot.beams) do
		beam.Transparency = on and 0.05 or 1
	end
end

local function lockBase(p, seconds)
	p.lockUntil = now() + seconds
	setBarrier(p.plot, true)
	p.plot.sign:SetAttribute("LockUntil", p.lockUntil)
	refreshAttrs(p)
	Notify:FireClient(p.player, "base_locked", { tostring(math.floor(seconds)) })
end

for _, plot in ipairs(plots) do
	plot.lockPad.Touched:Connect(function(hit)
		local p = plot.owner
		if not p or not p.player.Character or not hit:IsDescendantOf(p.player.Character) then
			return
		end
		if p.lockUntil > now() then
			return
		end
		lockBase(p, Config.lockTime(p.rebirths))
	end)
	for s, slot in ipairs(plot.slots) do
		slot.pad.Touched:Connect(function(hit)
			local p = plot.owner
			if p and p.player.Character and hit:IsDescendantOf(p.player.Character) then
				collect(p, s)
			end
		end)
	end
end

---------------------------------------------------------------- гладиус

local function makeGladius()
	local tool = Instance.new("Tool")
	tool.Name = "Gladius"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ToolTip = "Hit thieves!"
	tool.Grip = CFrame.fromMatrix(Vector3.new(0, 0, -1.5), Vector3.new(0, 1, 0), Vector3.new(0, 0, 1))
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.3, 0.6, 3.6)
	handle.Color = Color3.fromRGB(196, 200, 208)
	handle.Material = Enum.Material.Metal
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	local guard = Instance.new("Part")
	guard.Name = "Guard"
	guard.Size = Vector3.new(0.4, 1.5, 0.28)
	guard.Color = Color3.fromRGB(216, 172, 72)
	guard.Material = Enum.Material.Metal
	guard.CanCollide = false
	guard.Massless = true
	guard.CFrame = handle.CFrame * CFrame.new(0, 0, -1.15)
	guard.Parent = tool
	local w = Instance.new("WeldConstraint")
	w.Part0 = handle
	w.Part1 = guard
	w.Parent = handle
	return tool
end

local function hit(player, tool)
	local p = profiles[player]
	local _, hrp = charParts(player)
	if not p or not hrp then
		return
	end
	local t = os.clock()
	if t - p.lastHit < Config.HIT_COOLDOWN then
		return
	end
	p.lastHit = t
	local anim = Instance.new("StringValue")
	anim.Name = "toolanim"
	anim.Value = "Slash"
	anim.Parent = tool
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			local _, ohrp = charParts(other)
			if ohrp then
				local d = ohrp.Position - hrp.Position
				local flat = Vector3.new(d.X, 0, d.Z)
				if d.Magnitude <= Config.HIT_RANGE and flat.Magnitude > 0.1 and hrp.CFrame.LookVector:Dot(flat.Unit) > 0.1 then
					Knock:FireClient(other, flat.Unit * 75 + Vector3.new(0, 38, 0))
					local op = profiles[other]
					if op and op.carrying then
						drop(op, player)
					end
				end
			end
		end
	end
end

---------------------------------------------------------------- вход и выход игроков

local function freePlot()
	for _, plot in ipairs(plots) do
		if not plot.owner then
			return plot
		end
	end
	return nil
end

local function setGroup(char, group)
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CollisionGroup = group
		end
	end
	char.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then
			d.CollisionGroup = group
		end
	end)
end

local function onCharacter(p, char)
	local hum = char:WaitForChild("Humanoid", 10)
	local hrp = char:WaitForChild("HumanoidRootPart", 10)
	if not hum or not hrp then
		return
	end
	setGroup(char, "Owner" .. p.plot.index)
	hum.WalkSpeed = Config.PLAYER_SPEED
	task.defer(function()
		char:PivotTo(p.plot.spawn)
	end)
	local tool = makeGladius()
	tool.Activated:Connect(function()
		hit(p.player, tool)
	end)
	tool.Parent = p.player:WaitForChild("Backpack")
	hum.Died:Connect(function()
		if p.carrying then
			drop(p, nil)
		end
		task.delay(3, function()
			if p.player.Parent then
				p.player:LoadCharacter()
			end
		end)
	end)
end

local function loadData(player)
	if not store then
		return nil
	end
	local ok, data = pcall(function()
		return store:GetAsync("u" .. player.UserId)
	end)
	if ok and type(data) == "table" then
		return data
	end
	return nil
end

local function saveData(p)
	if not store or not p.loaded then
		return
	end
	local units = {}
	for s, u in pairs(p.slots) do
		if u.state == "home" or u.state == "walk" then
			table.insert(units, { s = s, id = u.id, m = u.mut or "" })
		end
	end
	local data = { cash = p.cash, rebirths = p.rebirths, steals = p.steals, units = units, t = os.time() }
	pcall(function()
		store:SetAsync("u" .. p.player.UserId, data)
	end)
end

local function onPlayerAdded(player)
	local plot = freePlot()
	if not plot then
		player:Kick("Server is full")
		return
	end
	local p = {
		player = player,
		plot = plot,
		cash = Config.START_CASH,
		rebirths = 0,
		steals = 0,
		slots = {},
		banks = {},
		lockUntil = 0,
		lastHit = 0,
	}
	profiles[player] = p
	plot.owner = p

	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Parent = ls
	local reb = Instance.new("IntValue")
	reb.Name = "Rebirths"
	reb.Parent = ls
	local st = Instance.new("IntValue")
	st.Name = "Steals"
	st.Parent = ls
	ls.Parent = player

	local data = loadData(player)
	if data then
		p.cash = tonumber(data.cash) or p.cash
		p.rebirths = tonumber(data.rebirths) or 0
		p.steals = tonumber(data.steals) or 0
	end
	p.loaded = true
	plot.sign:SetAttribute("OwnerName", player.DisplayName)
	refreshPedestals(plot, p)
	if data and type(data.units) == "table" then
		for _, e in ipairs(data.units) do
			local s = tonumber(e.s)
			if Config.UNIT[e.id] and s and s <= Config.slots(p.rebirths) and not p.slots[s] then
				local u = makeUnit(e.id, (e.m ~= "" and Config.MUTATIONS[e.m]) and e.m or nil)
				assign(u, p, s, false)
			end
		end
	end
	setCash(p, p.cash)
	lockBase(p, Config.JOIN_LOCK)
	refreshAttrs(p)

	player.CharacterAdded:Connect(function(char)
		onCharacter(p, char)
	end)
	player:LoadCharacter()
	Notify:FireClient(player, "welcome", {})
end

local function onPlayerRemoving(player)
	local p = profiles[player]
	if not p then
		return
	end
	if p.carrying then
		drop(p, nil)
	end
	saveData(p)
	profiles[player] = nil
	local plot = p.plot
	plot.owner = nil
	for _, u in pairs(p.slots) do
		if u.state == "carried" then
			u.owner = nil -- вор унесёт к себе, хозяина больше нет
		else
			destroyUnit(u)
		end
	end
	setBarrier(plot, false)
	plot.sign:SetAttribute("OwnerName", "")
	plot.sign:SetAttribute("LockUntil", 0)
	for _, slot in ipairs(plot.slots) do
		slot.pad:SetAttribute("Bank", 0)
	end
	refreshPedestals(plot, nil)
end

for _, plot in ipairs(plots) do
	refreshPedestals(plot, nil)
end
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, pl in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, pl)
end
game:BindToClose(function()
	for _, p in pairs(profiles) do
		saveData(p)
	end
end)

---------------------------------------------------------------- перерождение

RebirthReq.OnServerEvent:Connect(function(player)
	local p = profiles[player]
	if not p or p.carrying then
		return
	end
	local cost = Config.rebirthCost(p.rebirths)
	if p.cash < cost then
		Notify:FireClient(player, "no_money", {})
		return
	end
	for _, u in pairs(p.slots) do
		if u.state == "carried" then
			u.owner = nil
		else
			destroyUnit(u)
		end
	end
	p.slots = {}
	p.banks = {}
	for _, slot in ipairs(p.plot.slots) do
		slot.pad:SetAttribute("Bank", 0)
	end
	p.rebirths = p.rebirths + 1
	setCash(p, Config.START_CASH) -- с нулём не на что купить даже крестьянина
	refreshPedestals(p.plot, p)
	refreshAttrs(p)
	Notify:FireClient(player, "rebirth_done", { tostring(p.rebirths), tostring(Config.multiplier(p.rebirths)) })
	saveData(p)
end)

---------------------------------------------------------------- проверка в Studio (в опубликованной игре этого нет)

if RunService:IsStudio() then
	local dbg = Instance.new("BindableFunction")
	dbg.Name = "LegionDebug"
	dbg.OnInvoke = function(cmd, player, a, b)
		local p = profiles[player]
		if not p then
			return "no profile"
		end
		if cmd == "cash" then
			setCash(p, p.cash + a)
		elseif cmd == "give" then
			local s = freeSlot(p)
			if not s then
				return "no slot"
			end
			assign(makeUnit(a, b), p, s, false)
			refreshAttrs(p)
		elseif cmd == "unlock" then
			p.lockUntil = now() -- главный цикл откроет базу
		end
		local units = {}
		for s, u in pairs(p.slots) do
			table.insert(units, s .. ":" .. u.id .. ":" .. u.state)
		end
		table.sort(units)
		return string.format("cash=%s rebirths=%d steals=%d carrying=%s lock=%.0f units=%s",
			Config.fmt(p.cash), p.rebirths, p.steals, p.carrying and p.carrying.id or "-",
			math.max(0, p.lockUntil - now()), table.concat(units, ","))
	end
	dbg.Parent = game:GetService("ServerStorage")
end

---------------------------------------------------------------- главный цикл

local spawnTimer = 0
local incomeTimer = 0
local saveTimer = 0
local lastLegendary = os.clock()
local lastMythic = os.clock()

RunService.Heartbeat:Connect(function(dt)
	local t = os.clock()

	-- новые римляне на дороге
	spawnTimer = spawnTimer + dt
	if spawnTimer >= Config.SPAWN_EVERY then
		spawnTimer = 0
		if t - lastMythic >= Config.MYTHIC_EVERY then
			lastMythic = t
			lastLegendary = t
			spawnBelt("mythic")
		elseif t - lastLegendary >= Config.LEGENDARY_EVERY then
			lastLegendary = t
			spawnBelt("legendary")
		else
			spawnBelt(nil)
		end
	end

	-- дорога движется
	for i = #belt, 1, -1 do
		local u = belt[i]
		u.x = u.x + Config.BELT_SPEED * dt
		if u.x > Config.BELT_END then
			table.remove(belt, i)
			destroyUnit(u)
		else
			local bob = math.abs(math.sin(t * 6 + u.phase)) * 0.35
			u.root.CFrame = CFrame.new(u.x, 1.3 + bob, 0) * CFrame.Angles(0, -math.pi / 2, math.sin(t * 6 + u.phase) * 0.06)
		end
	end

	-- купленные идут домой
	for _, p in pairs(profiles) do
		for _, u in pairs(p.slots) do
			if u.state == "walk" then
				-- walkPos — точка на пути без подпрыгивания (иначе подскок копится и фигурка взлетает)
				local target = u.path[u.pathI]
				local pos = u.walkPos
				local d = target - pos
				local step = Config.HOME_SPEED * dt
				if d.Magnitude <= step then
					u.walkPos = target
					u.pathI = u.pathI + 1
					if u.pathI > #u.path then
						u.root.CFrame = slotCF(p, u.slot)
						setState(u, "home")
						refreshAttrs(p)
					end
				else
					local np = pos + d.Unit * step
					u.walkPos = np
					local look = Vector3.new(d.X, 0, d.Z)
					local rot = look.Magnitude > 0.01 and CFrame.lookAt(np, np + look) or (u.root.CFrame - u.root.Position + np)
					local bob = math.abs(math.sin(t * 9)) * 0.3
					u.root.CFrame = rot + Vector3.new(0, bob, 0)
				end
			end
		end
		-- вор добежал до своей базы?
		if p.carrying then
			local _, hrp = charParts(p.player)
			if hrp and World.inside(p.plot, hrp.Position) then
				deliver(p)
			end
		end
		-- замок кончился
		if p.lockUntil > 0 and p.lockUntil <= now() then
			p.lockUntil = 0
			setBarrier(p.plot, false)
			p.plot.sign:SetAttribute("LockUntil", 0)
			refreshAttrs(p)
			Notify:FireClient(p.player, "unlocked", {})
		end
	end

	-- доход: раз в секунду на плиты у постаментов
	incomeTimer = incomeTimer + dt
	if incomeTimer >= 1 then
		incomeTimer = incomeTimer - 1
		for _, p in pairs(profiles) do
			local _, hrp = charParts(p.player)
			for s, u in pairs(p.slots) do
				if u.state == "home" then
					local pad = p.plot.slots[s].pad
					p.banks[s] = (p.banks[s] or 0) + Config.unitIncome(u.id, u.mut, p.rebirths)
					pad:SetAttribute("Bank", math.floor(p.banks[s]))
					if hrp and standsOn(pad, hrp.Position) then
						collect(p, s)
					end
				end
			end
		end
	end

	saveTimer = saveTimer + dt
	if saveTimer >= Config.SAVE_EVERY then
		saveTimer = 0
		for _, p in pairs(profiles) do
			task.spawn(saveData, p)
		end
	end
end)

-- первые римляне сразу, чтобы дорога не была пустой
for i = 1, 14 do
	spawnBelt(nil)
	belt[#belt].x = Config.BELT_START + i * 20
end
