class_name Gear
## Легион 2.0, этап 2 (docs/LEGION_V2.md 3.4, решение владельца: 5 редкостей): снаряжение воинов.
## Слоты (5): оружие, щит (у лучника — колчан, у механика — станок: баллиста или катапульта), шлем, доспех, знак.
## Редкость: обычная (серая), добротная (зелёная), редкая (синяя), эпическая (фиолетовая), легендарная (золотая).
## Уровень вещи растёт с глубиной похода. Вещи падают в боях (босс — наверняка и лучше), хранятся на Складе оружия.
## Оружие и щит — под класс воина, шлем, доспех и знак носит любой.

const SLOTS := ["weapon", "offhand", "helmet", "armor", "badge"]
const SLOT_NAME := {"weapon": "оружие", "offhand": "щит", "helmet": "шлем", "armor": "доспех", "badge": "знак"}
const RARITY := ["обычная", "добротная", "редкая", "эпическая", "легендарная"]
const RARITY_M := ["обычный", "добротный", "редкий", "эпический", "легендарный"]
const RARITY_N := ["обычное", "добротное", "редкое", "эпическое", "легендарное"]
const RARITY_COL := ["8a8070", "4f8a2a", "2f6fb0", "8a45b5", "c28a12"]
const RARITY_K := [1.0, 1.3, 1.7, 2.2, 2.8]
## Что даёт вещь на 1 уровне обычной редкости: atk / hp — доли, armor — броня
const BASE := {
	"weapon": {"atk": 0.06},
	"offhand": {"hp": 0.02, "armor": 3.0},
	"helmet": {"hp": 0.04, "armor": 1.0},
	"armor": {"hp": 0.05, "armor": 4.0},
	"badge": {"atk": 0.02, "hp": 0.02},
}
const LVL_K := 0.05                        # +5% к числам вещи за уровень
## Имена вещей: [род, мужской/женский/средний] — для «эпический гладий», «редкая лорика»
const NAMES := {
	"weapon": {"legionary": ["гладий", "m"], "spearman": ["копьё", "n"], "archer": ["лук", "m"], "engineer": ["станок баллисты", "m"]},
	"weapon_alt": {"engineer": ["катапульта", "f"]},
	"offhand": {"legionary": ["скутум", "m"], "spearman": ["щит", "m"], "archer": ["колчан", "m"], "engineer": ["ящик снарядов", "m"]},
	"helmet": {"": ["шлем", "m"]},
	"armor": {"": ["лорика", "f"]},
	"badge": {"": ["фалера", "f"]},
}
## Шанс вещи после победы и веса редкостей
const DROP_FIRST := 0.6                    # первая победа в бою
const DROP_REPEAT := 0.15                  # повтор
const DROP_W := [62.0, 26.0, 9.0, 2.6, 0.4]
const DROP_W_BOSS := [18.0, 40.0, 29.0, 11.0, 2.0]
## Кузница (этап 3): разобрать вещь — обломок её редкости; выковать вещь редкости r — обломки редкости r−1, денарии, время.
## Уровень Кузницы открывает редкость и ограничивает уровень вещи (5 × уровень)
const FORGE := [
	{"shards": 0, "money": 60, "h": 0.17, "lvl": 1},
	{"shards": 3, "money": 150, "h": 1.0, "lvl": 1},
	{"shards": 4, "money": 400, "h": 4.0, "lvl": 3},
	{"shards": 5, "money": 1200, "h": 8.0, "lvl": 5},
	{"shards": 5, "money": 3500, "h": 12.0, "lvl": 8},
]
const SHARD := ["серый обломок", "зелёный обломок", "синий обломок", "фиолетовый обломок", "золотой обломок"]
const STORE_BASE := 20                     # мест на Складе: 20 + 5 × уровень Склада оружия
const STORE_PER := 5


static func rarity_word(r: int, g: String) -> String:
	var a: Array = RARITY_M if g == "m" else (RARITY if g == "f" else RARITY_N)
	return String(a[clampi(r, 0, 4)])


static func color(r: int) -> Color:
	return Color(String(RARITY_COL[clampi(r, 0, 4)]))


## Числа вещи: {atk, hp, armor}
static func stats(it: Dictionary) -> Dictionary:
	var b: Dictionary = BASE.get(String(it.get("slot", "")), {})
	var k := (1.0 + LVL_K * (int(it.get("ilvl", 1)) - 1)) * float(RARITY_K[clampi(int(it.get("rarity", 0)), 0, 4)])
	return {"atk": float(b.get("atk", 0.0)) * k, "hp": float(b.get("hp", 0.0)) * k, "armor": float(b.get("armor", 0.0)) * k}


## «Сила» вещи для сравнения: проценты урона и здоровья + броня
static func score(it: Dictionary) -> float:
	var s := stats(it)
	return float(s["atk"]) * 100.0 + float(s["hp"]) * 100.0 + float(s["armor"]) * 0.8


static func name_of(it: Dictionary) -> String:
	var slot := String(it.get("slot", ""))
	var cls := String(it.get("cls", ""))
	var e: Array = []
	if slot == "weapon" and cls == "engineer" and String(it.get("engine", "")) == "catapult":
		e = NAMES["weapon_alt"]["engineer"]
	else:
		var d: Dictionary = NAMES.get(slot, {})
		e = d.get(cls, d.get("", ["вещь", "f"]))
	return "%s %s" % [rarity_word(int(it.get("rarity", 0)), String(e[1])).capitalize(), String(e[0])]


## Строка чисел: «+12% урона, +4 брони»
static func stats_text(it: Dictionary) -> String:
	var s := stats(it)
	var out := []
	if float(s["atk"]) > 0.0:
		out.append("+%d%% урона" % roundi(float(s["atk"]) * 100.0))
	if float(s["hp"]) > 0.0:
		out.append("+%d%% здоровья" % roundi(float(s["hp"]) * 100.0))
	if float(s["armor"]) > 0.0:
		out.append("+%d брони" % roundi(float(s["armor"])))
	return ", ".join(out)


## Подходит ли вещь воину класса cls (оружие и щит — под класс)
static func fits(it: Dictionary, cls: String) -> bool:
	var slot := String(it.get("slot", ""))
	return not (slot in ["weapon", "offhand"]) or String(it.get("cls", "")) == cls


static func roll_rarity(rng: RandomNumberGenerator, boss: bool) -> int:
	var w: Array = DROP_W_BOSS if boss else DROP_W
	var x := rng.randf() * 100.0
	for i in 5:
		x -= float(w[i])
		if x <= 0.0:
			return i
	return 0


## Новая вещь: слот и класс случайно (оружие и щит — под один из классов cls_list), уровень ilvl
static func roll(rng: RandomNumberGenerator, ilvl: int, boss: bool, cls_list: Array) -> Dictionary:
	var slot: String = SLOTS[rng.randi() % SLOTS.size()]
	var cls := ""
	if slot in ["weapon", "offhand"]:
		cls = String(cls_list[rng.randi() % cls_list.size()]) if not cls_list.is_empty() else "legionary"
	var it := {"slot": slot, "cls": cls, "rarity": roll_rarity(rng, boss), "ilvl": maxi(1, ilvl + rng.randi_range(-1, 1))}
	if slot == "weapon" and cls == "engineer":
		it["engine"] = "catapult" if rng.randf() < 0.5 else "ballista"
	return it
