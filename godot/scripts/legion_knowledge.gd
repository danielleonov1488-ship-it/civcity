extends RefCounted
## Цены и связи дерева Легиона. Время указано в игровых часах.

const NODES := {
	"smith": {"name": "Кузнечное знание", "needs": [], "hq": 2, "money": 800, "mats": {"iron": 20, "wood": 20}, "hours": 0, "art": "anvil", "opens": ["sword"], "tiers": "I–II"},
	"bows": {"name": "Лучное дело", "needs": ["smith"], "hq": 2, "money": 1200, "mats": {"wood": 40, "leather": 20}, "hours": 1, "art": "bow", "opens": ["bow"], "tiers": "I–II"},
	"staffs": {"name": "Посохи жрецов", "needs": ["smith"], "hq": 3, "money": 1500, "mats": {"wood": 60}, "hours": 2, "art": "staff", "opens": ["staff"], "tiers": "I–II"},
	"spears": {"name": "Копья конницы", "needs": ["bows"], "hq": 4, "money": 2500, "mats": {"iron": 60, "wood": 60}, "hours": 4, "art": "spear", "opens": ["spear"], "tiers": "I–II"},
	"weap3": {"name": "Оружие III–IV", "needs": ["smith"], "hq": 3, "money": 2500, "mats": {"iron": 80}, "hours": 4, "art": "sword", "opens": ["sword"], "tiers": "III–IV"},
	"weap5": {"name": "Оружие V–VI", "needs": ["weap3"], "hq": 5, "money": 6000, "mats": {"iron": 200}, "hours": 12, "art": "sword", "opens": ["sword"], "tiers": "V–VI"},
	"weap7": {"name": "Оружие VII–VIII", "needs": ["weap5"], "hq": 7, "money": 15000, "mats": {"iron": 500}, "hours": 24, "art": "sword", "opens": ["sword"], "tiers": "VII–VIII"},
	"weap9": {"name": "Оружие IX–X", "needs": ["weap7"], "hq": 9, "money": 35000, "mats": {"iron": 1200}, "hours": 48, "art": "sword", "opens": ["sword"], "tiers": "IX–X"},
	"armor1": {"name": "Броня: шлем, щит, доспех", "needs": ["smith"], "hq": 3, "money": 1800, "mats": {"iron": 40, "leather": 40}, "hours": 2, "art": "armor", "opens": ["helmet", "offhand", "armor"], "tiers": "I–II"},
	"armor3": {"name": "Броня III–IV", "needs": ["armor1"], "hq": 4, "money": 3000, "mats": {"iron": 100, "leather": 60}, "hours": 6, "art": "armor", "opens": ["helmet", "offhand", "armor"], "tiers": "III–IV"},
	"armor5": {"name": "Броня V–VI", "needs": ["armor3"], "hq": 6, "money": 8000, "mats": {"iron": 250, "leather": 150}, "hours": 16, "art": "armor", "opens": ["helmet", "offhand", "armor"], "tiers": "V–VI"},
	"armor7": {"name": "Броня VII–VIII", "needs": ["armor5"], "hq": 8, "money": 20000, "mats": {"iron": 600, "leather": 400}, "hours": 30, "art": "armor", "opens": ["helmet", "offhand", "armor"], "tiers": "VII–VIII"},
	"armor9": {"name": "Броня IX–X", "needs": ["armor7"], "hq": 10, "money": 45000, "mats": {"iron": 1400, "leather": 900}, "hours": 48, "art": "armor", "opens": ["helmet", "offhand", "armor"], "tiers": "IX–X"},
	"outfit": {"name": "Рабочая одежда", "needs": ["smith"], "hq": 3, "money": 1500, "mats": {"leather": 60}, "hours": 3, "art": "cloth", "opens": ["cook", "smith", "scribe", "priest", "builder"], "tiers": ""},
	"outfit2": {"name": "Тонкое шитьё", "needs": ["outfit"], "hq": 6, "money": 8000, "mats": {"leather": 300}, "hours": 24, "art": "cloth", "opens": [], "tiers": "+5%"},
	"smelt": {"name": "Чистая переплавка", "needs": ["smith"], "hq": 4, "money": 3000, "mats": {}, "hours": 6, "art": "smelt", "opens": [], "tiers": "×1.5"},
	"reforge": {"name": "Перековка", "needs": ["weap3"], "hq": 5, "money": 7000, "mats": {"iron": 200, "wood": 100}, "hours": 12, "art": "reforge", "opens": [], "tiers": "+1"},
	"luck1": {"name": "Удачная ковка I", "needs": ["smelt"], "hq": 6, "money": 10000, "mats": {"iron": 300}, "hours": 24, "art": "laurel", "opens": [], "tiers": "52/30/13/4/1"},
	"luck2": {"name": "Удачная ковка II", "needs": ["luck1"], "hq": 8, "money": 25000, "mats": {"iron": 800}, "hours": 48, "art": "laurel", "opens": [], "tiers": "42/33/17/6/2"},
	"sets": {"name": "Реликвии легионов", "needs": ["weap5", "armor5"], "hq": 6, "money": 12000, "mats": {"iron": 300, "leather": 300}, "hours": 24, "art": "scroll", "opens": [], "tiers": ""},
}


static func recipe_requirements(kind: String, tier: int) -> Array[String]:
	var band := 1 + 2 * ((clampi(tier, 1, 10) - 1) / 2)
	if Gear.WORK_OUTFITS.has(kind):
		return ["outfit"]
	if kind in ["helmet", "offhand", "armor"]:
		return ["armor%d" % band]
	var branch := String({"sword": "smith", "bow": "bows", "staff": "staffs", "spear": "spears"}.get(kind, "smith"))
	if band == 1:
		return [branch]
	return ["weap%d" % band] if kind == "sword" else [branch, "weap%d" % band]
