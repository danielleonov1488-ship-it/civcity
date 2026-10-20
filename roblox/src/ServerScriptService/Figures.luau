-- Фигурки римлян из деталей Roblox: крестьяне, легионеры, сенаторы, всадник, слон, Минотавр, Циклоп, Цербер, Юпитер.
-- Фигурка смотрит в -Z (вперёд) и стоит ногами на y = 0. Невидимый корень Root закреплён,
-- остальные детали приварены к нему: двигать фигурку — значит двигать только корень.
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))

local Figures = {}

local SKIN = Color3.fromRGB(234, 192, 150)
local HAIR = Color3.fromRGB(70, 48, 30)
local STEEL = Color3.fromRGB(186, 190, 198)
local BRASS = Color3.fromRGB(216, 172, 72)
local LEATHER = Color3.fromRGB(112, 74, 44)
local WOOD = Color3.fromRGB(130, 94, 60)
local BLACK = Color3.fromRGB(25, 22, 22)
local WHITE = Color3.fromRGB(245, 245, 240)

local function darker(c, k)
	return Color3.new(c.R * k, c.G * k, c.B * k)
end

local Builder = {}
Builder.__index = Builder

-- деталь: размер, позиция (от ног), цвет, [материал], [поворот], [форма]
function Builder:box(size, pos, color, material, rot, shape)
	local p = Instance.new("Part")
	if shape then
		p.Shape = shape
	end
	p.Size = size
	local cf = CFrame.new(pos)
	if rot then
		cf = cf * rot
	end
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = false
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.Parent = self.model
	return p
end

-- вытянутый шар: SpecialMesh Sphere растягивается по размеру детали
function Builder:ball(size, pos, color, material, rot)
	local p = self:box(size, pos, color, material, rot)
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Sphere
	m.Parent = p
	return p
end

-- цилиндр с осью X (диск щита, свиток); для стоячего — повернуть
function Builder:cyl(length, diameter, pos, color, material, rot)
	return self:box(Vector3.new(length, diameter, diameter), pos, color, material, rot, Enum.PartType.Cylinder)
end

local UP = CFrame.Angles(0, 0, math.rad(90)) -- ось цилиндра — вверх

local function weapon(b, kind, V, S)
	if kind == "sword" then
		b:box(S(0.16, 1.8, 0.38), V(1.4, 2.95, -0.5), STEEL, Enum.Material.Metal)
		b:box(S(0.22, 0.16, 0.85), V(1.4, 2.0, -0.5), BRASS, Enum.Material.Metal)
		b:box(S(0.18, 0.45, 0.18), V(1.4, 1.72, -0.5), LEATHER)
	elseif kind == "spear" then
		b:box(S(0.2, 6.0, 0.2), V(1.45, 3.0, -0.35), WOOD)
		b:box(S(0.3, 0.75, 0.3), V(1.45, 6.35, -0.35), STEEL, Enum.Material.Metal)
	elseif kind == "trident" then
		b:box(S(0.2, 5.0, 0.2), V(1.45, 2.6, -0.35), WOOD)
		b:box(S(0.95, 0.15, 0.15), V(1.45, 5.1, -0.35), STEEL, Enum.Material.Metal)
		for _, dx in ipairs({ -0.4, 0, 0.4 }) do
			b:box(S(0.12, 0.85, 0.12), V(1.45 + dx, 5.55, -0.35), STEEL, Enum.Material.Metal)
		end
	elseif kind == "bow" then
		b:box(S(0.18, 3.4, 0.3), V(1.55, 2.9, -0.45), WOOD)
		b:box(S(0.05, 3.1, 0.05), V(1.55, 2.9, -0.2), WHITE)
	elseif kind == "sling" then
		b:box(S(0.08, 1.2, 0.08), V(1.4, 1.45, -0.3), LEATHER)
		b:box(S(0.42, 0.3, 0.42), V(1.4, 0.85, -0.3), LEATHER)
	elseif kind == "rake" then
		b:box(S(0.18, 4.6, 0.18), V(1.45, 2.3, -0.4), WOOD)
		b:box(S(1.3, 0.2, 0.25), V(1.45, 4.6, -0.4), WOOD)
	elseif kind == "rod" then
		b:box(S(0.12, 5.2, 0.12), V(1.45, 3.4, -1.1), WOOD, nil, CFrame.Angles(math.rad(-28), 0, 0))
	elseif kind == "bread" then
		b:ball(S(0.65, 0.5, 1.15), V(1.45, 1.95, -0.5), Color3.fromRGB(205, 150, 78))
	elseif kind == "scroll" then
		b:cyl(1.2 * S(1, 1, 1).X, 0.36 * S(1, 1, 1).X, V(1.4, 2.1, -0.5), Color3.fromRGB(240, 226, 190))
		b:box(S(0.15, 0.48, 0.48), V(0.8, 2.1, -0.5), WOOD)
		b:box(S(0.15, 0.48, 0.48), V(2.0, 2.1, -0.5), WOOD)
	elseif kind == "flame" then
		b:box(S(0.8, 0.3, 0.8), V(1.45, 2.05, -0.45), BRASS, Enum.Material.Metal)
		local f = b:ball(S(0.5, 0.85, 0.5), V(1.45, 2.65, -0.45), Color3.fromRGB(255, 150, 40), Enum.Material.Neon)
		local l = Instance.new("PointLight")
		l.Color = Color3.fromRGB(255, 160, 60)
		l.Range = 10
		l.Brightness = 1.5
		l.Parent = f
	elseif kind == "bolt" then
		local y = Color3.fromRGB(255, 225, 60)
		b:box(S(0.26, 1.2, 0.26), V(1.45, 2.5, -0.5), y, Enum.Material.Neon, CFrame.Angles(0, 0, math.rad(25)))
		b:box(S(0.26, 1.0, 0.26), V(1.6, 3.35, -0.5), y, Enum.Material.Neon, CFrame.Angles(0, 0, math.rad(-35)))
		local top = b:box(S(0.26, 1.2, 0.26), V(1.45, 4.2, -0.5), y, Enum.Material.Neon, CFrame.Angles(0, 0, math.rad(25)))
		local l = Instance.new("PointLight")
		l.Color = y
		l.Range = 14
		l.Brightness = 2
		l.Parent = top
	elseif kind == "club" then
		b:box(S(0.65, 2.8, 0.65), V(1.55, 2.9, -0.4), WOOD, nil, CFrame.Angles(0, 0, math.rad(-12)))
	elseif kind == "axe" then
		b:box(S(0.22, 4.6, 0.22), V(1.5, 2.8, -0.4), WOOD)
		b:box(S(0.12, 1.3, 2.4), V(1.5, 4.7, -0.4), STEEL, Enum.Material.Metal)
	end
end

local function helmet(b, look, V, S, metal)
	local h = look.helm
	if h == "legion" or h == "centurion" or h == "praetorian" then
		b:box(S(1.56, 0.72, 1.46), V(0, 5.05, 0), metal, Enum.Material.Metal)
		b:box(S(1.56, 0.25, 0.45), V(0, 4.65, 0.68), metal, Enum.Material.Metal)
		b:box(S(0.12, 0.65, 0.55), V(-0.76, 4.4, -0.3), metal, Enum.Material.Metal)
		b:box(S(0.12, 0.65, 0.55), V(0.76, 4.4, -0.3), metal, Enum.Material.Metal)
		if h == "centurion" then
			b:box(S(1.95, 0.68, 0.34), V(0, 5.72, 0), look.crest or Color3.fromRGB(220, 30, 30), Enum.Material.Fabric)
		elseif look.crest then
			local tall = h == "praetorian" and 0.9 or 0.62
			b:box(S(0.32, tall, 1.5), V(0, 5.38 + tall / 2, 0.05), look.crest, Enum.Material.Fabric)
		end
		return 0.75
	elseif h == "gladiator" then
		b:box(S(1.6, 1.45, 1.5), V(0, 4.6, 0), metal, Enum.Material.Metal)
		b:box(S(1.0, 0.5, 0.06), V(0, 4.65, -0.77), BLACK)
		b:box(S(2.05, 0.12, 2.05), V(0, 5.2, 0), metal, Enum.Material.Metal)
		b:box(S(0.26, 0.45, 1.05), V(0, 5.5, 0), Color3.fromRGB(200, 40, 40), Enum.Material.Fabric)
		return 0.6
	elseif h == "straw" then
		b:box(Vector3.new(S(1, 1, 1).X * 0.15, S(1, 1, 1).X * 2.5, S(1, 1, 1).X * 2.5), V(0, 5.22, 0), Color3.fromRGB(222, 192, 112), nil, UP, Enum.PartType.Cylinder)
		b:box(S(1.3, 0.55, 1.25), V(0, 5.5, 0), Color3.fromRGB(214, 182, 100))
		return 0.55
	elseif h == "cap" then
		b:box(S(1.5, 0.5, 1.42), V(0, 5.2, 0), look.capColor or Color3.fromRGB(90, 110, 140), Enum.Material.Fabric)
		return 0.25
	elseif h == "chef" then
		b:box(S(1.5, 0.3, 1.42), V(0, 5.15, 0), WHITE)
		b:ball(S(1.6, 1.1, 1.5), V(0, 5.75, 0), WHITE)
		return 1.05
	elseif h == "hood" then
		b:box(S(1.62, 1.28, 1.5), V(0, 4.86, 0.12), darker(look.tunic or WOOD, 0.8), Enum.Material.Fabric)
		return 0.35
	elseif h == "laurel" then
		b:box(S(1.52, 0.24, 1.42), V(0, 5.0, 0), Color3.fromRGB(86, 146, 62), Enum.Material.Grass)
		b:box(S(0.3, 0.2, 0.55), V(-0.78, 5.05, -0.2), Color3.fromRGB(110, 170, 70))
		b:box(S(0.3, 0.2, 0.55), V(0.78, 5.05, -0.2), Color3.fromRGB(110, 170, 70))
		return 0
	elseif h == "veil" then
		b:box(S(1.62, 1.72, 1.5), V(0, 4.75, 0.15), WHITE, Enum.Material.Fabric)
		b:box(S(1.56, 0.3, 1.46), V(0, 5.35, 0.05), WHITE, Enum.Material.Fabric)
		return 0.2
	end
	return nil -- шлема нет — нужны волосы
end

-- человечек: s — масштаб, baseY — на какой высоте ноги (для всадника); opts: noLegs, noHead, bald, oneEye
local function human(b, look, s, baseY, opts)
	opts = opts or {}
	local function V(x, y, z)
		return Vector3.new(x * s, baseY + y * s, z * s)
	end
	local function S(x, y, z)
		return Vector3.new(x * s, y * s, z * s)
	end
	local skin = look.skin or SKIN
	local tunic = look.tunic or Color3.fromRGB(180, 160, 130)
	local metal = look.gold and BRASS or STEEL
	local toga = look.toga

	-- ноги и одежда
	if toga then
		b:box(S(2.15, 2.25, 1.2), V(0, 1.12, 0), toga, Enum.Material.Fabric)
		b:box(S(0.8, 0.22, 0.45), V(-0.5, 0.11, -0.55), LEATHER)
		b:box(S(0.8, 0.22, 0.45), V(0.5, 0.11, -0.55), LEATHER)
	elseif not opts.noLegs then
		b:box(S(0.8, 1.9, 0.85), V(-0.5, 0.95, 0), skin)
		b:box(S(0.8, 1.9, 0.85), V(0.5, 0.95, 0), skin)
		b:box(S(0.86, 0.26, 1.0), V(-0.5, 0.13, -0.05), LEATHER)
		b:box(S(0.86, 0.26, 1.0), V(0.5, 0.13, -0.05), LEATHER)
	end
	if not toga then
		b:box(S(2.15, 0.78, 1.2), V(0, 2.05, 0), look.armor and LEATHER or darker(tunic, 0.85), Enum.Material.Fabric)
	end

	-- туловище
	local torsoColor = toga or (look.armor and metal) or (look.bare and skin) or tunic
	b:box(S(2.0, 1.75, 1.05), V(0, 2.95, 0), torsoColor, look.armor and Enum.Material.Metal or (toga and Enum.Material.Fabric or nil))
	if look.armor then
		b:box(S(0.82, 0.55, 0.92), V(-1.4, 3.55, 0), tunic, Enum.Material.Fabric)
		b:box(S(0.82, 0.55, 0.92), V(1.4, 3.55, 0), tunic, Enum.Material.Fabric)
		b:box(S(2.06, 0.14, 1.1), V(0, 2.6, 0), darker(metal, 0.75), Enum.Material.Metal)
		b:box(S(2.06, 0.14, 1.1), V(0, 3.1, 0), darker(metal, 0.75), Enum.Material.Metal)
	elseif look.bare then
		b:box(S(0.3, 2.3, 1.1), V(0, 2.95, 0), LEATHER, nil, CFrame.Angles(0, 0, math.rad(38)))
	end
	if toga and look.stripe then
		b:box(S(0.42, 3.6, 1.26), V(0.15, 2.2, 0), look.stripe, Enum.Material.Fabric, CFrame.Angles(0, 0, math.rad(-28)))
	end
	if not toga then
		b:box(S(2.06, 0.28, 1.12), V(0, 2.15, 0), LEATHER)
	end

	-- руки
	b:box(S(0.7, 1.75, 0.75), V(-1.35, 2.9, 0), toga or skin, toga and Enum.Material.Fabric or nil)
	b:box(S(0.7, 1.75, 0.75), V(1.35, 2.9, 0), skin)

	-- плащ
	if look.cape then
		b:box(S(1.9, 2.9, 0.15), V(0, 2.35, 0.64), look.cape, Enum.Material.Fabric, CFrame.Angles(math.rad(-6), 0, 0))
	end

	-- голова
	local top = 5.25
	if not opts.noHead then
		b:box(S(1.4, 1.35, 1.3), V(0, 4.55, 0), skin)
		if opts.oneEye then
			b:ball(S(0.75, 0.75, 0.14), V(0, 4.7, -0.66), WHITE)
			b:box(S(0.32, 0.32, 0.06), V(0, 4.7, -0.74), BLACK)
			b:box(S(1.0, 0.14, 0.1), V(0, 5.08, -0.66), darker(skin, 0.5))
		else
			b:box(S(0.18, 0.3, 0.05), V(-0.3, 4.62, -0.66), BLACK)
			b:box(S(0.18, 0.3, 0.05), V(0.3, 4.62, -0.66), BLACK)
		end
		b:box(S(0.42, 0.08, 0.05), V(0, 4.18, -0.66), darker(skin, 0.55))
		if look.beard then
			b:box(S(1.32, 0.62, 0.36), V(0, 4.02, -0.55), look.beard)
		end
		local extra = helmet(b, look, V, S, metal)
		if extra == nil then
			if not opts.bald then
				local hair = look.hair or HAIR
				b:box(S(1.46, 0.36, 1.36), V(0, 5.15, 0.02), hair)
				b:box(S(1.46, 0.85, 0.3), V(0, 4.75, 0.56), hair)
			end
			extra = 0.15
		end
		top = 5.25 + extra
	end

	-- щит и оружие
	if look.shield == "scutum" then
		local c = look.shieldColor or Color3.fromRGB(170, 35, 35)
		b:box(S(0.3, 2.5, 1.55), V(-1.85, 2.6, -0.25), c)
		b:box(S(0.36, 0.45, 0.45), V(-2.02, 2.6, -0.25), BRASS, Enum.Material.Metal)
		b:box(S(0.32, 0.12, 1.55), V(-1.86, 3.8, -0.25), BRASS, Enum.Material.Metal)
		b:box(S(0.32, 0.12, 1.55), V(-1.86, 1.4, -0.25), BRASS, Enum.Material.Metal)
	elseif look.shield == "round" then
		b:cyl(0.3 * s, 1.95 * s, V(-1.85, 2.7, -0.2), look.shieldColor or Color3.fromRGB(150, 110, 50))
		b:box(S(0.36, 0.45, 0.45), V(-2.02, 2.7, -0.2), BRASS, Enum.Material.Metal)
	end
	if look.weapon then
		weapon(b, look.weapon, V, S)
	end
	return baseY + top * s
end

local function elephant(b)
	local gray = Color3.fromRGB(150, 150, 160)
	for _, x in ipairs({ -1.4, 1.4 }) do
		for _, z in ipairs({ -2.1, 2.1 }) do
			b:box(Vector3.new(1.45, 3.0, 1.45), Vector3.new(x, 1.5, z), gray)
		end
	end
	b:ball(Vector3.new(4.5, 3.9, 6.8), Vector3.new(0, 4.5, 0), gray)
	b:ball(Vector3.new(3.0, 2.8, 2.6), Vector3.new(0, 5.4, -3.6), gray)
	b:ball(Vector3.new(0.4, 2.9, 2.5), Vector3.new(-1.85, 5.5, -3.0), darker(gray, 0.85), nil, CFrame.Angles(0, math.rad(20), 0))
	b:ball(Vector3.new(0.4, 2.9, 2.5), Vector3.new(1.85, 5.5, -3.0), darker(gray, 0.85), nil, CFrame.Angles(0, math.rad(-20), 0))
	b:box(Vector3.new(0.85, 1.7, 0.85), Vector3.new(0, 4.0, -4.75), gray, nil, CFrame.Angles(math.rad(15), 0, 0))
	b:box(Vector3.new(0.7, 1.5, 0.7), Vector3.new(0, 2.7, -5.0), gray)
	b:box(Vector3.new(0.25, 0.25, 1.6), Vector3.new(-0.75, 4.3, -4.9), WHITE, nil, CFrame.Angles(math.rad(-25), 0, 0))
	b:box(Vector3.new(0.25, 0.25, 1.6), Vector3.new(0.75, 4.3, -4.9), WHITE, nil, CFrame.Angles(math.rad(-25), 0, 0))
	b:box(Vector3.new(0.22, 0.32, 0.1), Vector3.new(-1.0, 5.9, -4.72), BLACK)
	b:box(Vector3.new(0.22, 0.32, 0.1), Vector3.new(1.0, 5.9, -4.72), BLACK)
	b:box(Vector3.new(4.7, 0.3, 4.3), Vector3.new(0, 6.35, 0), Color3.fromRGB(170, 30, 30), Enum.Material.Fabric)
	b:box(Vector3.new(4.8, 0.32, 0.3), Vector3.new(0, 6.37, -2.15), BRASS, Enum.Material.Metal)
	b:box(Vector3.new(4.8, 0.32, 0.3), Vector3.new(0, 6.37, 2.15), BRASS, Enum.Material.Metal)
	b:box(Vector3.new(3.0, 1.8, 3.0), Vector3.new(0, 7.4, 0.3), Color3.fromRGB(176, 40, 36))
	b:box(Vector3.new(3.5, 0.35, 3.5), Vector3.new(0, 8.45, 0.3), BRASS, Enum.Material.Metal)
	b:box(Vector3.new(0.25, 1.6, 0.25), Vector3.new(0, 4.3, 3.45), gray, nil, CFrame.Angles(math.rad(25), 0, 0))
	return 9.0
end

local function minotaur(b)
	local s = 1.3
	local skin = Color3.fromRGB(122, 76, 46)
	human(b, { skin = skin, tunic = Color3.fromRGB(70, 46, 30), bare = true, weapon = "axe" }, s, 0, { noHead = true })
	local function V(x, y, z)
		return Vector3.new(x * s, y * s, z * s)
	end
	b:box(V(1.6, 1.5, 1.7), V(0, 4.6, 0.05), skin)
	b:box(V(1.1, 0.8, 0.6), V(0, 4.25, -0.95), Color3.fromRGB(176, 124, 92))
	b:box(V(0.2, 0.2, 0.05), V(-0.45, 4.9, -0.81), Color3.fromRGB(200, 30, 30), Enum.Material.Neon)
	b:box(V(0.2, 0.2, 0.05), V(0.45, 4.9, -0.81), Color3.fromRGB(200, 30, 30), Enum.Material.Neon)
	b:box(V(1.25, 0.28, 0.28), V(-1.3, 5.35, 0), Color3.fromRGB(240, 230, 205), nil, CFrame.Angles(0, 0, math.rad(-35)))
	b:box(V(1.25, 0.28, 0.28), V(1.3, 5.35, 0), Color3.fromRGB(240, 230, 205), nil, CFrame.Angles(0, 0, math.rad(35)))
	b:box(V(0.5, 0.5, 0.1), V(0, 3.95, -1.27), BRASS, Enum.Material.Metal)
	return 5.9 * s
end

local function cyclops(b)
	local s = 1.75
	return human(b, { skin = Color3.fromRGB(206, 184, 152), tunic = Color3.fromRGB(128, 94, 60), bare = true, weapon = "club" }, s, 0, { bald = true, oneEye = true })
end

local function cerberus(b)
	local fur = Color3.fromRGB(48, 42, 52)
	for _, x in ipairs({ -0.9, 0.9 }) do
		for _, z in ipairs({ -1.8, 1.8 }) do
			b:box(Vector3.new(0.85, 2.0, 0.85), Vector3.new(x, 1.0, z), fur)
		end
	end
	b:ball(Vector3.new(2.9, 2.5, 5.3), Vector3.new(0, 2.9, 0), fur)
	local glow = nil
	for _, x in ipairs({ -1.35, 0, 1.35 }) do
		local yaw = CFrame.Angles(0, math.rad(-x * 14), 0)
		b:box(Vector3.new(1.3, 1.2, 1.6), Vector3.new(x, 4.2, -2.9), fur, nil, yaw)
		b:box(Vector3.new(0.8, 0.6, 0.95), Vector3.new(x * 1.05, 3.9, -3.95), darker(fur, 1.3), nil, yaw)
		b:box(Vector3.new(0.2, 0.18, 0.05), Vector3.new(x - 0.32, 4.45, -3.72), Color3.fromRGB(255, 50, 30), Enum.Material.Neon)
		glow = b:box(Vector3.new(0.2, 0.18, 0.05), Vector3.new(x + 0.32, 4.45, -3.72), Color3.fromRGB(255, 50, 30), Enum.Material.Neon)
		b:box(Vector3.new(0.3, 0.65, 0.3), Vector3.new(x - 0.42, 5.0, -2.7), fur)
		b:box(Vector3.new(0.3, 0.65, 0.3), Vector3.new(x + 0.42, 5.0, -2.7), fur)
	end
	b:box(Vector3.new(3.0, 0.42, 0.55), Vector3.new(0, 3.85, -2.25), Color3.fromRGB(160, 30, 30))
	b:box(Vector3.new(0.4, 0.4, 2.0), Vector3.new(0, 3.4, 2.9), fur, nil, CFrame.Angles(math.rad(35), 0, 0))
	local l = Instance.new("PointLight")
	l.Color = Color3.fromRGB(255, 70, 40)
	l.Range = 12
	l.Brightness = 1.5
	l.Parent = glow
	return 5.6
end

local function rider(b, look)
	local brown = Color3.fromRGB(122, 82, 52)
	for _, x in ipairs({ -0.62, 0.62 }) do
		for _, z in ipairs({ -1.6, 1.6 }) do
			b:box(Vector3.new(0.62, 2.4, 0.62), Vector3.new(x, 1.2, z), brown)
		end
	end
	b:box(Vector3.new(2.0, 1.9, 4.2), Vector3.new(0, 3.25, 0), brown)
	b:box(Vector3.new(1.0, 1.9, 1.1), Vector3.new(0, 4.3, -2.0), brown, nil, CFrame.Angles(math.rad(-25), 0, 0))
	b:box(Vector3.new(0.95, 0.9, 1.7), Vector3.new(0, 5.0, -2.9), brown)
	b:box(Vector3.new(0.3, 1.6, 1.2), Vector3.new(0, 4.8, -1.8), darker(brown, 0.5))
	b:box(Vector3.new(0.16, 0.24, 0.05), Vector3.new(-0.42, 5.15, -3.6), BLACK)
	b:box(Vector3.new(0.16, 0.24, 0.05), Vector3.new(0.42, 5.15, -3.6), BLACK)
	b:box(Vector3.new(0.4, 1.6, 0.4), Vector3.new(0, 3.4, 2.25), darker(brown, 0.5), nil, CFrame.Angles(math.rad(25), 0, 0))
	b:box(Vector3.new(2.1, 0.2, 1.6), Vector3.new(0, 4.25, 0.2), look.cape or Color3.fromRGB(60, 60, 140), Enum.Material.Fabric)
	local s = 0.9
	local top = human(b, look, s, 2.3, { noLegs = true })
	b:box(Vector3.new(0.7, 1.6, 0.75), Vector3.new(-1.15, 3.7, 0.1), SKIN)
	b:box(Vector3.new(0.7, 1.6, 0.75), Vector3.new(1.15, 3.7, 0.1), SKIN)
	return top
end

local function mutate(model, mut)
	local m = Config.MUTATIONS[mut]
	if not m then
		return
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Material ~= Enum.Material.Neon then
			d.Color = d.Color:Lerp(m.color, mut == "gold" and 0.78 or 0.7)
			if mut == "gold" then
				d.Material = Enum.Material.Foil
				d.Reflectance = 0.15
			else
				d.Material = Enum.Material.Glass
				d.Transparency = 0.12
			end
		end
	end
end

function Figures.build(id, mut)
	local unit = Config.UNIT[id]
	local look = unit.look
	local model = Instance.new("Model")
	model.Name = id
	local b = setmetatable({ model = model }, Builder)
	local kind = look.kind or "human"
	local height
	if kind == "elephant" then
		height = elephant(b)
	elseif kind == "minotaur" then
		height = minotaur(b)
	elseif kind == "cyclops" then
		height = cyclops(b)
	elseif kind == "cerberus" then
		height = cerberus(b)
	elseif kind == "rider" then
		height = rider(b, look)
	else
		height = human(b, look, look.scale or 1, 0, {})
	end

	if mut then
		mutate(model, mut)
	end

	-- свечение у редких
	local rank = Config.RARITY[unit.rarity].rank
	local anchor = nil
	for _, d in ipairs(model:GetChildren()) do
		if d:IsA("BasePart") then
			anchor = d
		end
	end
	if rank >= 4 and anchor then
		local l = Instance.new("PointLight")
		l.Color = Config.RARITY[unit.rarity].color
		l.Range = 10 + rank
		l.Brightness = 0.8
		l.Parent = anchor
	end
	if (rank >= 6 or look.glow) and anchor then
		local sp = Instance.new("Sparkles")
		sp.SparkleColor = rank == 7 and Color3.fromRGB(255, 255, 255) or Config.RARITY[unit.rarity].color
		sp.Parent = anchor
	end

	-- корень и сварка
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(2.2, 0.2, 2.2)
	root.CFrame = CFrame.new(0, 0.1, 0)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.Massless = true
	root.Parent = model
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d ~= root then
			local w = Instance.new("WeldConstraint")
			w.Part0 = root
			w.Part1 = d
			w.Parent = root
		end
	end
	model.PrimaryPart = root
	local k = Config.RARITY[unit.rarity].scale or 1
	if k ~= 1 then
		model:ScaleTo(k) -- от корня под ногами: фигурка растёт вверх, стоять остаётся на месте
		height = height * k
	end
	model:SetAttribute("Height", height)
	return model
end

return Figures
