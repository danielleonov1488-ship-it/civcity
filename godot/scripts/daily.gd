class_name Daily
## Задания дня Легиона (Легион 2.0, docs/LEGION_V2.md 3.10; без сервера — по дню Москвы на этом компьютере):
## каждый день 5 заданий из пула, каждое — свиток; все 5 — дневной сундук. Сундуки растут по лестнице недели
## (Медный → … → «Сундук Цезаря»); пропуск дня лестницу не сбрасывает — только останавливает. Только новая игра.

const POOL := [
	{"id": "win3", "kind": "camp_win", "need": 3, "text": "Выиграть 3 боя похода"},
	{"id": "new1", "kind": "camp_first", "need": 1, "text": "Пройти новый бой похода"},
	{"id": "stars", "kind": "three_stars", "need": 1, "text": "Взять все 3 звезды в бою"},
	{"id": "boss", "kind": "boss", "need": 1, "text": "Победить босса похода (можно младшего)"},
	{"id": "oil", "kind": "oil4", "need": 1, "text": "Накрыть маслом 4 врагов разом"},
	{"id": "train", "kind": "train", "need": 1, "text": "Начать тренировку воина"},
	{"id": "recruit", "kind": "recruit", "need": 1, "text": "Взять новобранца"},
	{"id": "forge", "kind": "forge", "need": 1, "text": "Начать ковку вещи", "needs": "forge"},
	{"id": "smelt", "kind": "smelt", "need": 1, "text": "Разобрать ненужную вещь"},
	{"id": "equip", "kind": "equip", "need": 2, "text": "Надеть 2 вещи на воинов"},
	{"id": "upgrade", "kind": "upgrade", "need": 1, "text": "Начать улучшение здания Легиона"},
]
const PER_DAY := 5
const LADDER := ["Медный", "Бронзовый", "Серебряный", "Золотой", "Самоцветный", "Императорский", "Сундук Цезаря"]


## Задания на день d для Легиона lg: [{id, kind, need, text, n}]
static func roll(lg, d: int) -> Array:
	var pool := []
	for t: Dictionary in POOL:
		if String(t.get("needs", "")) == "forge" and lg.forge_lvl() <= 0:
			continue
		pool.append(t)
	var rng := RandomNumberGenerator.new()
	rng.seed = d * 7919 + 17
	var out := []
	while out.size() < mini(PER_DAY, pool.size()):
		var t: Dictionary = pool[rng.randi() % pool.size()]
		if out.any(func(x): return x["id"] == t["id"]):
			continue
		var e := t.duplicate()
		e["n"] = 0
		out.append(e)
	return out


static func ladder_name(step: int) -> String:
	var s := String(LADDER[clampi(step, 0, LADDER.size() - 1)])
	return s if s.begins_with("Сундук") else "%s сундук" % s


## Что в сундуке ступени step: {glory, mats (каждого), shard: [редкость, сколько], rarity_min (вещь не ниже)}
static func chest(step: int) -> Dictionary:
	var L := clampi(step, 0, LADDER.size() - 1)
	return {"glory": 3 + 2 * L, "mats": 30 + 20 * L, "shard": [mini(3, L / 2), 1 + L / 3], "rarity_min": 1 if L < 3 else (2 if L < 6 else 3)}
