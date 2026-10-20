-- Тексты игры: английский для всех, русский — если у игрока русский язык в Roblox.
local Config = require(script.Parent:WaitForChild("Config"))

local Locale = { lang = "en" }

local T = {
	buy = { en = "Buy", ru = "Купить" },
	steal = { en = "Steal", ru = "Украсть" },
	base_of = { en = "%s's base", ru = "База: %s" },
	free_base = { en = "Free base", ru = "Свободная база" },
	locked = { en = "LOCKED %d", ru = "ЗАПЕРТО %d" },
	open = { en = "OPEN", ru = "ОТКРЫТО" },
	lock_pad = { en = "LOCK BASE", ru = "ЗАПЕРЕТЬ БАЗУ" },
	rebirth = { en = "Rebirth", ru = "Перерождение" },
	rebirth_need = { en = "Need $%s", ru = "Нужно $%s" },
	rebirth_ready = { en = "Ready! Income x%s", ru = "Готово! Доход ×%s" },
	income = { en = "+$%s/s", ru = "+$%s/с" },
	collect = { en = "$%s", ru = "$%s" },
	your_lock = { en = "Your base is locked: %d s", ru = "Твоя база заперта: %d с" },
	your_open = { en = "Your base is OPEN — step on the red plate to lock it", ru = "Твоя база ОТКРЫТА — встань на красную плиту, чтобы запереть" },
	carry_banner = { en = "RUN TO YOUR BASE!", ru = "БЕГИ НА СВОЮ БАЗУ!" },
	welcome = { en = "Buy Romans on the Via Sacra — and steal them from others!", ru = "Покупай римлян на Священной дороге — и кради их у других!" },
	no_money = { en = "Not enough cash", ru = "Не хватает денег" },
	no_slot = { en = "No free pedestal on your base", ru = "На твоей базе нет свободного постамента" },
	bought = { en = "%s is heading to your base!", ru = "%s идёт к тебе на базу!" },
	run_home = { en = "Got it! Run to your base!", ru = "Схватил! Беги на свою базу!" },
	being_stolen = { en = "%s is stealing your %s! Hit them!", ru = "%s крадёт твоего: %s! Ударь вора!" },
	stolen_ok = { en = "You stole %s!", ru = "Ты украл: %s!" },
	lost = { en = "%s stole your %s", ru = "%s украл у тебя: %s" },
	dropped = { en = "Dropped! %s went back home", ru = "Выронил! %s вернулся домой" },
	defended = { en = "You stopped the thief! %s is back", ru = "Ты остановил вора! %s вернулся" },
	is_locked = { en = "This base is locked", ru = "Эта база заперта" },
	base_locked = { en = "Base locked for %d s", ru = "База заперта на %d с" },
	unlocked = { en = "Your base is open now!", ru = "Твоя база снова открыта!" },
	spawn_rare = { en = "%s %s is walking the Via Sacra!", ru = "По Священной дороге идёт %s %s!" },
	rebirth_done = { en = "Rebirth %d! Income x%s, more pedestals", ru = "Перерождение %d! Доход ×%s, больше постаментов" },
	gladius = { en = "Gladius", ru = "Гладиус" },
}

function Locale.setLang(code)
	code = string.lower(code or "")
	Locale.lang = string.sub(code, 1, 2) == "ru" and "ru" or "en"
end

function Locale.t(key, ...)
	local e = T[key]
	if not e then
		return key
	end
	local s = e[Locale.lang] or e.en
	if select("#", ...) > 0 then
		local ok, out = pcall(string.format, s, ...)
		if ok then
			return out
		end
	end
	return s
end

function Locale.unit(id)
	local u = Config.UNIT[id]
	return u and (u[Locale.lang] or u.en) or id
end

function Locale.rarity(id)
	local r = Config.RARITY[id]
	return r and (r[Locale.lang] or r.en) or id
end

function Locale.mut(id)
	local m = id and Config.MUTATIONS[id]
	return m and (m[Locale.lang] or m.en) or ""
end

return Locale
