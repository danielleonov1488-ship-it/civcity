-- Карта строится кодом при запуске: Священная дорога с красной дорожкой, арка, 8 баз, кипарисы, свет.
-- База — квадрат 60×60 со стенами, воротами к дороге, 16 постаментами (видно столько, сколько открыто),
-- зелёной плитой сбора денег у каждого постамента, красной плитой «запереть базу» и лазерной стеной в воротах.
local Lighting = game:GetService("Lighting")
local PhysicsService = game:GetService("PhysicsService")
local CollectionService = game:GetService("CollectionService")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))

local World = {}

local C = {
	grass = Color3.fromRGB(106, 160, 76),
	road = Color3.fromRGB(198, 184, 156),
	walk = Color3.fromRGB(214, 202, 178),
	carpet = Color3.fromRGB(150, 28, 34),
	gold = Color3.fromRGB(226, 182, 74),
	marble = Color3.fromRGB(240, 236, 226),
	floor = Color3.fromRGB(230, 214, 178),
	terracotta = Color3.fromRGB(190, 92, 56),
	cypress = Color3.fromRGB(44, 90, 50),
	trunk = Color3.fromRGB(104, 76, 52),
	pad = Color3.fromRGB(70, 200, 100),
	lock = Color3.fromRGB(215, 50, 45),
	pedestal = Color3.fromRGB(226, 220, 206),
}

local WALL_H = 14
local GATE = 16
local SLOT_X = { -18, -6, 6, 18 }
local SLOT_Z = { -8, 2, 12, 22 }

local function part(parent, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Anchored = true
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local UP = CFrame.Angles(0, 0, math.rad(90))

local function column(parent, base, height, d, color)
	local p = part(parent, Vector3.new(height, d, d), base * CFrame.new(0, height / 2, 0) * UP, color, Enum.Material.Marble, Enum.PartType.Cylinder)
	part(parent, Vector3.new(d + 1, 0.8, d + 1), base * CFrame.new(0, height + 0.4, 0), C.gold, Enum.Material.Marble)
	part(parent, Vector3.new(d + 0.8, 0.6, d + 0.8), base * CFrame.new(0, 0.3, 0), color, Enum.Material.Marble)
	return p
end

local function cypress(parent, pos, h)
	part(parent, Vector3.new(1.2, 2.5, 1.2), CFrame.new(pos + Vector3.new(0, 1.25, 0)), C.trunk, Enum.Material.Wood)
	local crown = part(parent, Vector3.new(3.2, h, 3.2), CFrame.new(pos + Vector3.new(0, 1.8 + h / 2, 0)), C.cypress, Enum.Material.Grass)
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Sphere
	m.Parent = crown
end

local function banner(parent, cf, text)
	local b = part(parent, Vector3.new(4, 6, 0.3), cf, C.carpet, Enum.Material.Fabric)
	part(parent, Vector3.new(4.4, 0.3, 0.4), cf * CFrame.new(0, 3.1, 0), C.gold, Enum.Material.Metal)
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local g = Instance.new("SurfaceGui")
		g.Face = face
		g.CanvasSize = Vector2.new(200, 300)
		g.LightInfluence = 0.6
		g.Parent = b
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Text = text
		t.Font = Enum.Font.Fondamento
		t.TextScaled = true
		t.TextColor3 = C.gold
		t.Parent = g
	end
	return b
end

local function lighting()
	Lighting.ClockTime = 14.2
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(110, 100, 90)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 140, 125)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.GlobalShadows = true
	Lighting.GeographicLatitude = 30
	local atm = Instance.new("Atmosphere")
	atm.Density = 0.28
	atm.Offset = 0.15
	atm.Color = Color3.fromRGB(230, 214, 190)
	atm.Decay = Color3.fromRGB(150, 130, 110)
	atm.Glare = 0.3
	atm.Haze = 1.2
	atm.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.4
	bloom.Size = 24
	bloom.Threshold = 1.6
	bloom.Parent = Lighting
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Saturation = 0.12
	cc.Contrast = 0.06
	cc.TintColor = Color3.fromRGB(255, 248, 236)
	cc.Parent = Lighting
	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.04
	rays.Parent = Lighting
end

local function collisionGroups(n)
	for i = 1, n do
		pcall(function()
			PhysicsService:RegisterCollisionGroup("Barrier" .. i)
			PhysicsService:RegisterCollisionGroup("Owner" .. i)
		end)
		pcall(function()
			PhysicsService:CollisionGroupSetCollidable("Barrier" .. i, "Owner" .. i, false)
		end)
	end
end

local function buildPlot(root, index, cf)
	local m = Instance.new("Model")
	m.Name = "Plot" .. index
	m.Parent = root
	local function L(x, y, z)
		return cf * CFrame.new(x, y, z)
	end
	local H = Config.PLOT_SIZE / 2

	part(m, Vector3.new(Config.PLOT_SIZE, 0.4, Config.PLOT_SIZE), L(0, 1.2, 0), C.floor, Enum.Material.Sandstone)
	-- стены: задняя, боковые, передняя с воротами
	part(m, Vector3.new(Config.PLOT_SIZE, WALL_H, 2), L(0, 1.4 + WALL_H / 2, H - 1), C.marble, Enum.Material.Marble)
	part(m, Vector3.new(2, WALL_H, Config.PLOT_SIZE), L(-H + 1, 1.4 + WALL_H / 2, 0), C.marble, Enum.Material.Marble)
	part(m, Vector3.new(2, WALL_H, Config.PLOT_SIZE), L(H - 1, 1.4 + WALL_H / 2, 0), C.marble, Enum.Material.Marble)
	local seg = (Config.PLOT_SIZE - GATE) / 2
	for _, sx in ipairs({ -1, 1 }) do
		part(m, Vector3.new(seg, WALL_H, 2), L(sx * (GATE / 2 + seg / 2), 1.4 + WALL_H / 2, -H + 1), C.marble, Enum.Material.Marble)
		-- черепичный гребень
		part(m, Vector3.new(seg, 0.8, 2.6), L(sx * (GATE / 2 + seg / 2), 1.4 + WALL_H + 0.4, -H + 1), C.terracotta, Enum.Material.Slate)
		column(m, L(sx * (GATE / 2 + 1.2), 1.4, -H + 1), WALL_H + 2, 2.6, C.marble)
		banner(m, L(sx * (GATE / 2 + seg / 2), 1.4 + WALL_H - 4, -H - 0.2), "SPQR")
	end
	part(m, Vector3.new(Config.PLOT_SIZE, 0.8, 2.6), L(0, 1.4 + WALL_H + 0.4, H - 1), C.terracotta, Enum.Material.Slate)
	part(m, Vector3.new(2.6, 0.8, Config.PLOT_SIZE), L(-H + 1, 1.4 + WALL_H + 0.4, 0), C.terracotta, Enum.Material.Slate)
	part(m, Vector3.new(2.6, 0.8, Config.PLOT_SIZE), L(H - 1, 1.4 + WALL_H + 0.4, 0), C.terracotta, Enum.Material.Slate)
	-- перекладина над воротами
	part(m, Vector3.new(GATE + 5, 2, 3), L(0, 1.4 + WALL_H + 3.2, -H + 1), C.marble, Enum.Material.Marble)
	part(m, Vector3.new(GATE + 5.4, 0.5, 3.2), L(0, 1.4 + WALL_H + 4.4, -H + 1), C.gold, Enum.Material.Metal)

	-- лазерная стена в воротах (видна и твёрдая, только пока база заперта)
	local barrier = part(m, Vector3.new(GATE, WALL_H, 1), L(0, 1.4 + WALL_H / 2, -H + 1), C.lock, Enum.Material.Neon)
	barrier.Name = "Barrier"
	barrier.Transparency = 1
	barrier.CanCollide = false
	barrier.CollisionGroup = "Barrier" .. index

	-- табличка над воротами: имя хозяина и замок (текст рисует игрок у себя)
	local sign = part(m, Vector3.new(1, 1, 1), L(0, 1.4 + WALL_H + 7, -H + 1), C.marble)
	sign.Name = "Sign"
	sign.Transparency = 1
	sign.CanCollide = false
	sign:SetAttribute("Plot", index)
	sign:SetAttribute("OwnerName", "")
	sign:SetAttribute("LockUntil", 0)
	CollectionService:AddTag(sign, "PlotSign")

	-- плита «запереть базу»
	local lockPad = part(m, Vector3.new(6, 0.3, 6), L(17, 1.55, -H + 7), C.lock, Enum.Material.Neon)
	lockPad.Name = "LockPad"
	lockPad.Transparency = 0.15
	lockPad:SetAttribute("Plot", index)
	CollectionService:AddTag(lockPad, "LockPad")

	-- постаменты и плиты сбора
	local slots = {}
	local n = 0
	for _, z in ipairs(SLOT_Z) do
		for _, x in ipairs(SLOT_X) do
			n = n + 1
			local ped = part(m, Vector3.new(1.2, 5, 5), L(x, 2.0, z) * UP, C.pedestal, Enum.Material.Marble, Enum.PartType.Cylinder)
			ped.Name = "Pedestal" .. n
			local pad = part(m, Vector3.new(3.8, 0.2, 1.7), L(x, 1.5, z - 3.7), C.pad, Enum.Material.Neon)
			pad.Name = "Pad" .. n
			pad.Transparency = 0.2
			pad:SetAttribute("Bank", 0)
			pad:SetAttribute("Plot", index)
			pad:SetAttribute("Slot", n)
			CollectionService:AddTag(pad, "Pad")
			slots[n] = { pedestal = ped, pad = pad, cf = L(x, 2.6, z) }
		end
	end

	local units = Instance.new("Folder")
	units.Name = "Units"
	units.Parent = m

	return {
		index = index,
		cf = cf,
		model = m,
		slots = slots,
		barrier = barrier,
		sign = sign,
		lockPad = lockPad,
		units = units,
		spawn = L(0, 5, -20),
		entranceOut = (cf * CFrame.new(0, 1.3, -H - 6)).Position,
		entranceIn = (cf * CFrame.new(0, 1.4, -H + 5)).Position,
	}
end

function World.inside(plot, pos)
	local p = plot.cf:PointToObjectSpace(pos)
	local h = Config.PLOT_SIZE / 2 - 2
	return math.abs(p.X) < h and p.Z > -h and p.Z < h
end

function World.build()
	lighting()
	local root = Instance.new("Folder")
	root.Name = "Map"
	root.Parent = workspace

	-- земля
	part(root, Vector3.new(900, 2, 900), CFrame.new(0, 0, 0), C.grass, Enum.Material.Grass)
	-- дорога, тротуары, красная дорожка с золотой каймой
	part(root, Vector3.new(350, 0.2, 24), CFrame.new(0, 1.1, 0), C.road, Enum.Material.Cobblestone)
	part(root, Vector3.new(350, 0.2, 10), CFrame.new(0, 1.1, 17), C.walk, Enum.Material.Slate)
	part(root, Vector3.new(350, 0.2, 10), CFrame.new(0, 1.1, -17), C.walk, Enum.Material.Slate)
	part(root, Vector3.new(350, 0.1, 9), CFrame.new(0, 1.25, 0), C.carpet, Enum.Material.Fabric)
	part(root, Vector3.new(350, 0.12, 0.5), CFrame.new(0, 1.26, 4.6), C.gold, Enum.Material.Metal)
	part(root, Vector3.new(350, 0.12, 0.5), CFrame.new(0, 1.26, -4.6), C.gold, Enum.Material.Metal)

	-- триумфальная арка, откуда выходят римляне
	local ax = Config.BELT_START - 12
	for _, z in ipairs({ -10, 10 }) do
		part(root, Vector3.new(6, 26, 6), CFrame.new(ax, 14, z), C.marble, Enum.Material.Marble)
		column(root, CFrame.new(ax - 4, 1, z), 22, 2.4, C.marble)
		column(root, CFrame.new(ax + 4, 1, z), 22, 2.4, C.marble)
	end
	local beam = part(root, Vector3.new(8, 7, 27), CFrame.new(ax, 30.5, 0), C.marble, Enum.Material.Marble)
	part(root, Vector3.new(8.4, 1, 27.4), CFrame.new(ax, 34.5, 0), C.gold, Enum.Material.Metal)
	for _, face in ipairs({ Enum.NormalId.Left, Enum.NormalId.Right }) do
		local g = Instance.new("SurfaceGui")
		g.Face = face
		g.CanvasSize = Vector2.new(600, 160)
		g.Parent = beam
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Text = "VIA SACRA"
		t.Font = Enum.Font.Fondamento
		t.TextScaled = true
		t.TextColor3 = C.gold
		t.Parent = g
	end
	-- тёмные ворота в конце дороги, куда римляне уходят
	local ex = Config.BELT_END + 6
	for _, z in ipairs({ -9, 9 }) do
		part(root, Vector3.new(5, 20, 5), CFrame.new(ex, 11, z), C.marble, Enum.Material.Marble)
	end
	part(root, Vector3.new(6, 5, 23), CFrame.new(ex, 23.5, 0), C.marble, Enum.Material.Marble)
	local portal = part(root, Vector3.new(1, 20, 13), CFrame.new(ex, 11, 0), Color3.fromRGB(40, 20, 60), Enum.Material.Neon)
	portal.Transparency = 0.25
	portal.CanCollide = false

	-- колонны с флагами вдоль дороги
	for x = -120, 140, 70 do
		for _, z in ipairs({ -12.5, 12.5 }) do
			column(root, CFrame.new(x, 1.2, z), 12, 1.6, C.marble)
			banner(root, CFrame.new(x, 9, z + (z > 0 and 1 or -1)) * CFrame.Angles(0, math.rad(90), 0), "SPQR")
		end
	end

	-- базы
	collisionGroups(8)
	local plots = {}
	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = workspace
	local i = 0
	for _, side in ipairs({ 1, -1 }) do
		for _, x in ipairs(Config.PLOT_XS) do
			i = i + 1
			local cf = CFrame.new(x, 0, side * Config.PLOT_Z) * CFrame.Angles(0, side == 1 and 0 or math.pi, 0)
			plots[i] = buildPlot(plotsFolder, i, cf)
		end
	end

	-- кипарисы между базами и вокруг
	for _, x in ipairs({ -140, -70, 0, 70, 140 }) do
		for _, z in ipairs({ -27, 27, -55, 55, -80, 80 }) do
			cypress(root, Vector3.new(x + (math.random() - 0.5) * 2, 1, z), 9 + math.random() * 4)
		end
	end
	for _ = 1, 70 do
		local a = math.random() * math.pi * 2
		local r = 140 + math.random() * 200
		local p = Vector3.new(math.cos(a) * r * 1.3, 1, math.sin(a) * r)
		if math.abs(p.Z) > 95 or math.abs(p.X) > 200 then
			cypress(root, p, 8 + math.random() * 6)
		end
	end

	-- точка появления (игрока сразу переносит на его базу)
	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 0.2, 6)
	spawn.CFrame = CFrame.new(0, 1.3, -30)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = root

	local beltFolder = Instance.new("Folder")
	beltFolder.Name = "Belt"
	beltFolder.Parent = workspace

	return { plots = plots, belt = beltFolder }
end

return World
