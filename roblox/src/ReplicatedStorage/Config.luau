-- Steal a Legion: все числа игры в одном месте — юниты, редкости, цены, доход, таймеры.
local Config = {}

Config.TITLE = "Steal a Legion"

-- деньги и база
Config.START_CASH = 100
Config.SLOTS_BASE = 8           -- постаментов на базе в начале
Config.SLOTS_PER_REBIRTH = 2    -- +2 за каждое перерождение
Config.SLOTS_MAX = 16
Config.LOCK_TIME = 60           -- сколько секунд база заперта после нажатия на плиту
Config.LOCK_PER_REBIRTH = 10
Config.JOIN_LOCK = 30           -- при входе в игру база заперта сама

-- дорога (конвейер)
Config.SPAWN_EVERY = 2.6        -- новый римлянин каждые N секунд
Config.BELT_SPEED = 7
Config.BELT_START = -150
Config.BELT_END = 165
Config.LEGENDARY_EVERY = 300    -- гарантированный легендарный раз в 5 минут
Config.MYTHIC_EVERY = 900       -- мифический раз в 15 минут

-- игроки и кража
Config.PLAYER_SPEED = 22
Config.CARRY_SPEED = 13         -- с добычей над головой бежишь медленнее
Config.HOME_SPEED = 22          -- купленный юнит идёт к тебе на базу
Config.STEAL_HOLD = 1.2         -- сколько держать E, чтобы схватить чужого
Config.HIT_COOLDOWN = 0.6
Config.HIT_RANGE = 9
Config.SAVE_EVERY = 60

-- карта
Config.PLOT_XS = { -105, -35, 35, 105 }
Config.PLOT_Z = 52
Config.PLOT_SIZE = 60

-- scale — во сколько раз фигурка крупнее обычной: чем реже, тем внушительнее
Config.RARITIES = {
	{ id = "common", weight = 56, scale = 1, color = Color3.fromRGB(225, 225, 225), en = "Common", ru = "Обычный" },
	{ id = "rare", weight = 25, scale = 1.08, color = Color3.fromRGB(95, 215, 95), en = "Rare", ru = "Редкий" },
	{ id = "epic", weight = 12, scale = 1.16, color = Color3.fromRGB(185, 105, 255), en = "Epic", ru = "Эпический" },
	{ id = "legendary", weight = 5, scale = 1.25, color = Color3.fromRGB(255, 195, 45), en = "Legendary", ru = "Легендарный" },
	{ id = "mythic", weight = 1.6, scale = 1.3, color = Color3.fromRGB(255, 70, 70), en = "Mythic", ru = "Мифический" },
	{ id = "divine", weight = 0.35, scale = 1.4, color = Color3.fromRGB(255, 245, 160), en = "Divine", ru = "Божественный" },
	{ id = "secret", weight = 0.05, scale = 1.5, color = Color3.fromRGB(30, 30, 30), en = "Secret", ru = "Секретный" },
}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

-- look — как выглядит фигурка (см. ServerScriptService/Figures)
Config.UNITS = {
	{ id = "farmer", rarity = "common", price = 25, income = 1, en = "Farmer", ru = "Крестьянин",
		look = { tunic = rgb(150, 118, 78), helm = "straw", weapon = "rake" } },
	{ id = "fisher", rarity = "common", price = 60, income = 2, en = "Fisherman", ru = "Рыбак",
		look = { tunic = rgb(84, 128, 160), helm = "cap", capColor = rgb(60, 90, 120), weapon = "rod" } },
	{ id = "baker", rarity = "common", price = 150, income = 4, en = "Baker", ru = "Пекарь",
		look = { tunic = rgb(238, 228, 206), helm = "chef", weapon = "bread" } },
	{ id = "recruit", rarity = "common", price = 300, income = 7, en = "Recruit", ru = "Новобранец",
		look = { tunic = rgb(170, 62, 52), helm = "legion", weapon = "sword" } },

	{ id = "slinger", rarity = "rare", price = 750, income = 15, en = "Slinger", ru = "Пращник",
		look = { tunic = rgb(122, 140, 72), helm = "hood", weapon = "sling" } },
	{ id = "archer", rarity = "rare", price = 1500, income = 28, en = "Archer", ru = "Лучник",
		look = { tunic = rgb(70, 112, 62), helm = "cap", capColor = rgb(50, 80, 45), cape = rgb(58, 88, 50), weapon = "bow" } },
	{ id = "legionary", rarity = "rare", price = 3000, income = 50, en = "Legionary", ru = "Легионер",
		look = { tunic = rgb(180, 40, 40), armor = true, helm = "legion", crest = rgb(205, 30, 30), shield = "scutum", weapon = "sword" } },

	{ id = "gladiator", rarity = "epic", price = 8000, income = 110, en = "Gladiator", ru = "Гладиатор",
		look = { tunic = rgb(120, 72, 42), bare = true, helm = "gladiator", shield = "round", shieldColor = rgb(160, 118, 54), weapon = "trident" } },
	{ id = "rider", rarity = "epic", price = 15000, income = 190, en = "Cavalryman", ru = "Всадник",
		look = { kind = "rider", tunic = rgb(60, 82, 150), armor = true, helm = "legion", crest = rgb(240, 240, 240), cape = rgb(50, 62, 130), weapon = "spear" } },
	{ id = "centurion", rarity = "epic", price = 30000, income = 330, en = "Centurion", ru = "Центурион",
		look = { tunic = rgb(170, 30, 30), armor = true, helm = "centurion", crest = rgb(225, 30, 30), cape = rgb(150, 22, 22), shield = "scutum", weapon = "sword" } },

	{ id = "praetorian", rarity = "legendary", price = 80000, income = 700, en = "Praetorian", ru = "Преторианец",
		look = { tunic = rgb(92, 32, 112), armor = true, gold = true, helm = "praetorian", crest = rgb(248, 248, 248), cape = rgb(102, 32, 122), shield = "scutum", shieldColor = rgb(102, 32, 122), weapon = "spear" } },
	{ id = "senator", rarity = "legendary", price = 160000, income = 1200, en = "Senator", ru = "Сенатор",
		look = { toga = rgb(246, 241, 230), stripe = rgb(140, 30, 60), hair = rgb(150, 150, 150), weapon = "scroll" } },
	{ id = "vestal", rarity = "legendary", price = 300000, income = 2000, en = "Vestal", ru = "Весталка",
		look = { toga = rgb(252, 252, 250), helm = "veil", weapon = "flame" } },

	{ id = "elephant", rarity = "mythic", price = 1000000, income = 5000, en = "War Elephant", ru = "Боевой слон", look = { kind = "elephant" } },
	{ id = "minotaur", rarity = "mythic", price = 2500000, income = 11000, en = "Minotaur", ru = "Минотавр", look = { kind = "minotaur" } },
	{ id = "cyclops", rarity = "mythic", price = 6000000, income = 24000, en = "Cyclops", ru = "Циклоп", look = { kind = "cyclops" } },

	{ id = "caesar", rarity = "divine", price = 25000000, income = 80000, en = "Caesar", ru = "Цезарь",
		look = { toga = rgb(250, 246, 236), stripe = rgb(110, 30, 140), cape = rgb(110, 30, 140), helm = "laurel", weapon = "scroll", glow = true } },
	{ id = "cerberus", rarity = "divine", price = 60000000, income = 170000, en = "Cerberus", ru = "Цербер", look = { kind = "cerberus" } },

	{ id = "jupiter", rarity = "secret", price = 250000000, income = 600000, en = "Jupiter", ru = "Юпитер",
		look = { toga = rgb(250, 250, 255), stripe = rgb(232, 192, 62), helm = "laurel", weapon = "bolt", beard = rgb(238, 238, 238), hair = rgb(238, 238, 238), scale = 1.45, glow = true } },
}

Config.MUTATIONS = {
	gold = { mult = 2, chance = 0.05, color = Color3.fromRGB(255, 200, 40), en = "Gold", ru = "Золотой" },
	diamond = { mult = 3, chance = 0.015, color = Color3.fromRGB(140, 225, 255), en = "Diamond", ru = "Алмазный" },
}

-- справочники
Config.RARITY = {}
Config.BY_RARITY = {}
for i, r in ipairs(Config.RARITIES) do
	r.rank = i
	Config.RARITY[r.id] = r
	Config.BY_RARITY[r.id] = {}
end
Config.UNIT = {}
for _, u in ipairs(Config.UNITS) do
	Config.UNIT[u.id] = u
	table.insert(Config.BY_RARITY[u.rarity], u)
end

function Config.rebirthCost(rebirths)
	return 1000000 * (10 ^ rebirths)
end

function Config.multiplier(rebirths)
	return 1 + 0.5 * rebirths
end

function Config.slots(rebirths)
	return math.min(Config.SLOTS_MAX, Config.SLOTS_BASE + Config.SLOTS_PER_REBIRTH * rebirths)
end

function Config.lockTime(rebirths)
	return Config.LOCK_TIME + Config.LOCK_PER_REBIRTH * rebirths
end

function Config.unitIncome(id, mut, rebirths)
	local u = Config.UNIT[id]
	local m = mut and Config.MUTATIONS[mut]
	return u.income * (m and m.mult or 1) * Config.multiplier(rebirths)
end

-- 1234 → 1.23K, 5600000 → 5.6M
local SUFFIX = { "", "K", "M", "B", "T", "Qa", "Qi" }
function Config.fmt(n)
	n = math.floor(n)
	if n < 1000 then
		return tostring(n)
	end
	local i = 1
	local v = n
	while v >= 1000 and i < #SUFFIX do
		v = v / 1000
		i = i + 1
	end
	local digits = v >= 100 and 0 or (v >= 10 and 1 or 2)
	local scale = 10 ^ digits
	v = math.floor(v * scale) / scale
	local s = string.format("%." .. digits .. "f", v)
	s = tostring(tonumber(s))
	return s .. SUFFIX[i]
end

return Config
