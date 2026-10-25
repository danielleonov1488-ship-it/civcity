class_name Legion
extends RefCounted
## Легион — армия по мотивам Hustle Castle (старый замысел владельца, перенесён из js/army.js).
## Здания Легиона стоят на карте города и растут уровнями (решение владельца Д10): улучшение — в карточке здания,
## по настоящим часам; Казармы — легионеры и места в отряде, Стрельбище — лучники, Кузница — урон и здоровье всем,
## Лазарет — лечение между волнами, мастерские — машины, Склад оружия — броня (и снаряжение героя, L.3). Окно «Легион»:
##   «Походы» — 8 провинций по 10 боёв, в конце каждой босс; после восьмой — «Поход II, III…» без конца;
##   «Войска» — отряд, уровни зданий Легиона (кнопка «На карте» — к зданию и его карточке), умения;
##   «Против городов» — нападение на отряды обороны других игроков (их сохранённый отряд), рейтинг побед,
##               заряды атак, лёгкая добыча (ни у кого не отнимается);
##   «Чудеса» — чудеса света: первые три открывает рейтинг походов, старшие — рейтинг побед над городами.
## Бой считает LegionSim (без графики); 3D-бой (legion_battle.gd) только рисует его и жмёт умения.
##
## Здесь — данные (таблицы бойцов, врагов, провинций, умений, чудес), правила и состояние игрока.
## Состояние сохраняется вместе с городом: City.save_data()["legion"] = to_dict(); объект — game.city.legion.
##
## Контракт для окна «Легион» и 3D-боя (подробности — у каждой функции):
##   доступ:   window_open(), lock_text(), available(type), unit_lock_text(type), slots(), next_slot_boss(),
##             squad (Array id, "" — пусто), set_slot(i, type), auto_squad()/use_auto_squad(), squad_stats(), squad_power()
##   прокачка: levels[type], upgrade_info(type) {cur,to,max,blocked,limit,cost{money[,glory]},time},
##             can_upgrade(type) -> "" | почему нет, upgrade(type), upgrade_left(type) с, upgrade_progress(type) 0…1,
##             cap(), next_cap_city_level(); таймеры проверяет City.sim_day → on_hour() (и можно звать tick()).
##             type — род войск или здание поддержки (forge | infirmary | armory); здание → ключ: bkey(здание)
##   здания:   BUILDING_IDS, bkey(b), b_level(b), b_built(b), b_reserve(b) (уровень «в запасе»), b_effect(b, ур.),
##             b_upgrade_text(b) («Улучшить — N ден., M Славы, время»), vis_tier(ур.) — облик (City: b.tier)
##   умения:   perks[id] (0 — закрыто), perk_cost(id), can_upgrade_perk(id), upgrade_perk(id), open_perks()
##   походы:   frontier() {cycle,r,s}, stage_info(c,r,s) {…, waves, reward, open, done, first, stars, power, recommended},
##             stage_open/stage_done, region_done, region_rank_ok/region_lock_text, next_stage(st), odds(st) [класс, слова],
##             reward_for(st, first), food_cost(st), can_fight(st) -> "" | почему нет, counter_tips(st), unlocks_at(n),
##             flags["turn_page"] — перелистнуть карту на новую провинцию (окно сбрасывает)
##   бой:      setup = make_battle(st[, seed]) → LegionSim.new(setup) (крутит 3D-бой шагом LegionSim.DT) →
##             out = apply_result(setup, sim.result) {win, stars, first, reward, rating, boss_beaten, unlocks, next}
##   чудеса:   WONDERS, wonder_state(id) built|open|locked, wonder_cost(id), can_build_wonder(id), build_wonder(id)
##             (чудеса-постройки ставит игрок: game.set_tool(w.building), Слава спишется в City.place)
##   город:    glory, rating, triumph()/can_triumph(), city_happy()
##   города:   pvp_rating, pvp_charges_now(), pvp_next_charge(), pvp_can_attack(), defense_snapshot() (на сервер),
##             make_pvp_battle({name, rating, city_level, snapshot[, battle, seed, stakes, reward]}) → LegionSim →
##             apply_pvp_result(setup, result), pvp_defense([{name, win, delta, t[, glory]}]) — итоги нападений на нас,
##             pvp_log. Сеть (сервер /api/pvp, рейтинг и заряды с сервера) — LegionNet (legion_net.gd)
##   картинки: art(kind, id) {file, grid, i}, art_texture(kind, id) -> Texture2D | null (kind: unit|enemy|perk|wonder|map)
##   слова:    fmt_duration(с), roman(n), boss_name(n)

signal changed                      # что-то поменялось (уровень, отряд, Слава) — перерисовать окно
## Окно «Легион» просит бой (start_battle / start_pvp_battle): setup из make_battle / make_pvp_battle.
## 3D-бой подключается к сигналу, крутит LegionSim и зовёт apply_result / apply_pvp_result; если никто не слушает —
## окно считает бой само (без картинки) и показывает итог
signal battle_requested(setup: Dictionary)
## 3D-бой закрыт (игрок вернулся в город): out — итог apply_result / apply_pvp_result ({} — бой брошен).
## Окно «Легион» открывается снова на той же вкладке и показывает итог
signal battle_closed(out: Dictionary)

# =====================================================================
#   рода войск
# =====================================================================
## Числа — на 1 уровне. range — дальность удара (м поля), rate — секунд между ударами, speed — шагов в секунду
## (0 — машина стоит в тылу). vs — против кого бьют сильнее (тег врага → множитель урона).
## tags — свои теги (в боях с городами по ним бьют чужие vs). art — портрет: лист 35 (5 в ряд), номер.
const UNITS := {
	"legionary": {"name": "Легионер", "many": "Легионеры", "gen": "легионеров", "building": "barracks",
		"role": "Щит и меч. Держит строй и принимает удар на себя.", "strong": "людей ближнего боя",
		"hp": 270, "atk": 22, "armor": 32, "range": 1.0, "rate": 1.0, "speed": 1.6, "vs": {"human": 1.3},
		"tags": ["human"], "cost_k": 1.0, "art": 0},
	"spearman": {"name": "Копейщик", "many": "Копейщики", "gen": "копейщиков", "building": "spearcamp",
		"role": "Тяжёлая броня и длинное копьё: бьёт первым, но ходит медленно.", "strong": "зверей и великанов",
		"hp": 330, "atk": 19, "armor": 48, "range": 1.7, "rate": 1.3, "speed": 1.1, "vs": {"beast": 1.6, "giant": 1.6},
		"tags": ["human", "armored"], "cost_k": 1.1, "art": 1},
	"archer": {"name": "Лучник", "many": "Лучники", "gen": "лучников", "building": "range",
		"role": "Стреляет издалека, но сам хрупкий — держится за спинами.", "strong": "стрелков и быстрых зверей",
		"hp": 150, "atk": 19, "armor": 10, "range": 7.5, "rate": 1.15, "speed": 1.5, "shot": "arrow", "vs": {"ranged": 1.35, "swift": 1.35},
		"tags": ["human", "ranged"], "cost_k": 1.0, "art": 2},
	"ballista": {"name": "Баллиста", "many": "Баллисты", "gen": "баллист", "building": "ballistae",
		"role": "Тяжёлый болт пробивает строй врагов насквозь. Стоит в тылу.", "strong": "бронированных и чудовищ",
		"hp": 220, "atk": 50, "armor": 22, "range": 13.0, "rate": 3.0, "speed": 0.0, "shot": "bolt", "pierce": true, "vs": {"armored": 1.6, "giant": 1.5},
		"tags": ["machine", "armored"], "cost_k": 1.25, "art": 3},
	"catapult": {"name": "Катапульта", "many": "Катапульты", "gen": "катапульт", "building": "catapults",
		"role": "Камень по площади: бьёт редко, но накрывает толпу. Стоит в тылу.", "strong": "толпу",
		"hp": 240, "atk": 40, "armor": 22, "range": 14.0, "min_range": 2.5, "rate": 4.0, "speed": 0.0, "shot": "stone", "splash": 1.6, "vs": {"swarm": 1.4, "human": 1.15},
		"tags": ["machine"], "cost_k": 1.35, "art": 4},
}
const UNIT_IDS := ["legionary", "spearman", "archer", "ballista", "catapult"]
const BUILDING_UNIT := {"barracks": "legionary", "spearcamp": "spearman", "range": "archer", "ballistae": "ballista", "catapults": "catapult"}

# =====================================================================
#   здания Легиона на карте (Д10, как в Hustle Castle)
# =====================================================================
## Каждое военное здание растёт уровнями: улучшение — в его карточке, по настоящим часам (UPGRADE_TIME), сразу платится.
## У зданий бойцов уровень здания — это уровень рода войск (levels: так его знает и сервер боёв с городами);
## у Кузницы, Лазарета и Склада оружия — свой (blevels). Здание ещё не поставлено, а уровень выше первого — он «в запасе»
## (старые сохранения: уровни войск и умения перенесены в здания) и заработает, как только здание поставят
const BUILDING_IDS := ["barracks", "range", "spearcamp", "ballistae", "catapults", "forge", "infirmary", "armory"]
## Здания поддержки: max — наивысший уровень (выше — предел уровня города CAP_BY_CITY), cost_k — множитель цены улучшений
const SUPPORT := {
	"forge": {"max": 10, "cost_k": 1.2},
	"infirmary": {"max": 10, "cost_k": 1.0},
	"armory": {"max": 10, "cost_k": 1.1},
}
## Кузница: +FORGE урона и здоровья всем бойцам за уровень (доля); Лазарет: между волнами боя раненые восстанавливают
## INFIRMARY здоровья за уровень (доля; бой с городом — одна волна, его это не касается); Склад оружия: +ARMORY брони
const FORGE := 0.03
const INFIRMARY := 0.06
const ARMORY := 2.0
## Места в отряде: каждое новое (после боссов SLOT_BOSSES) — ещё и с Казармами этого уровня (копия в server/pvp.js)
const SLOT_BARRACKS := [2, 3, 5, 7]
## Кузница и Склад оружия в боях с городами: только когда сервер (server/legion_sim.js, server/pvp.js) повторяет бой
## с ними и владелец сказал «да» выкладке. Пока false: в снимках отряда и в бою с городом — только уровни бойцов и чудеса
const PVP_MODS := false
## Облик здания растёт с уровнем: 1-й — как построено, дальше — знамёна, пристройки, ограда, статуя, золото (VIS_MAX + 1 обликов)
const VIS_MAX := 5

# =====================================================================
#   враги
# =====================================================================
## tags: human — люди, beast — звери, giant — великаны, ranged — стрелки, armored — в броне, swift — быстрые,
## swarm — стаей. prefer: "ranged" — сначала бросаются на стрелков. Боссы: cleave — удар задевает всех
## рядом с целью (радиус), charge — разбег (удар ×1,8 и отброс), bites — кусает столько ближних сразу,
## shot+splash — бросает камни по площади, summon — созывает подмогу: первый раз через first секунд после выхода на поле,
## дальше каждые every секунд (за warn секунд — рог; foes — кто вбегает, сила как у врагов боя). art — портрет: лист 36 (враги, 4×4) или 37 (боссы, 4×2), номер.
const ENEMIES := {
	"bandit": {"name": "Разбойник", "hp": 120, "atk": 12, "armor": 5, "range": 0.95, "rate": 1.0, "speed": 1.7, "tags": ["human"], "art": 0},
	"slinger": {"name": "Пращник", "hp": 85, "atk": 11, "armor": 0, "range": 6.5, "rate": 1.3, "speed": 1.6, "shot": "sling", "tags": ["human", "ranged"], "art": 1},
	"wolf": {"name": "Волк", "hp": 85, "atk": 10, "armor": 0, "range": 0.85, "rate": 0.75, "speed": 2.8, "prefer": "ranged", "tags": ["beast", "swift", "swarm"], "art": 2},
	"boar": {"name": "Вепрь", "hp": 170, "atk": 15, "armor": 18, "range": 0.9, "rate": 1.1, "speed": 2.1, "tags": ["beast"], "art": 3},
	"bear": {"name": "Медведь", "hp": 380, "atk": 26, "armor": 20, "range": 1.1, "rate": 1.4, "speed": 1.4, "size": 1.25, "tags": ["beast", "giant"], "art": 4},
	"gaul": {"name": "Галл", "hp": 200, "atk": 18, "armor": 14, "range": 1.0, "rate": 1.05, "speed": 1.6, "tags": ["human"], "art": 5},
	"gaulArcher": {"name": "Галльский лучник", "hp": 115, "atk": 16, "armor": 6, "range": 7.0, "rate": 1.25, "speed": 1.5, "shot": "arrow", "tags": ["human", "ranged"], "art": 6},
	"berserker": {"name": "Берсерк", "hp": 240, "atk": 27, "armor": 4, "range": 1.0, "rate": 0.8, "speed": 2.1, "tags": ["human", "swift"], "art": 7},
	"bull": {"name": "Бешеный бык", "hp": 300, "atk": 22, "armor": 25, "range": 1.0, "rate": 1.3, "speed": 2.3, "size": 1.1, "tags": ["beast"], "art": 8},
	"pirate": {"name": "Пират", "hp": 190, "atk": 20, "armor": 10, "range": 1.0, "rate": 0.95, "speed": 1.8, "tags": ["human", "swift"], "art": 9},
	"mercenary": {"name": "Наёмник Карфагена", "hp": 260, "atk": 20, "armor": 38, "range": 1.0, "rate": 1.1, "speed": 1.4, "tags": ["human", "armored"], "art": 10},
	"shade": {"name": "Тень Аида", "hp": 240, "atk": 23, "armor": 32, "range": 1.0, "rate": 1.0, "speed": 1.6, "tags": ["human", "armored"], "art": 11},
	"hellhound": {"name": "Адский пёс", "hp": 130, "atk": 15, "armor": 8, "range": 0.85, "rate": 0.7, "speed": 3.0, "prefer": "ranged", "tags": ["beast", "swift", "swarm"], "art": 12},
	# боссы — последний бой каждой провинции
	"chief": {"name": "Атаман разбойников", "boss": true, "hp": 620, "atk": 26, "armor": 18, "range": 1.1, "rate": 1.0, "speed": 1.6, "size": 1.3, "tags": ["human"], "art": 0,
		"summon": {"first": 5.0, "every": 12.0, "warn": 3.0, "foes": ["bandit", "bandit", "bandit"]}},
	"greatbear": {"name": "Медведь-шатун", "boss": true, "hp": 1050, "atk": 36, "armor": 25, "range": 1.3, "rate": 1.4, "speed": 1.5, "size": 1.7, "cleave": 1.2, "tags": ["beast", "giant"], "art": 1},
	"gaulKing": {"name": "Вождь галлов", "boss": true, "hp": 1150, "atk": 34, "armor": 32, "range": 1.2, "rate": 1.0, "speed": 1.6, "size": 1.35, "cleave": 1.0, "tags": ["human", "armored"], "art": 2},
	"giant": {"name": "Германский великан", "boss": true, "hp": 1700, "atk": 46, "armor": 22, "range": 1.6, "rate": 1.6, "speed": 1.2, "size": 1.9, "cleave": 1.5, "tags": ["human", "giant"], "art": 3},
	"minotaur": {"name": "Минотавр", "boss": true, "hp": 2300, "atk": 56, "armor": 40, "range": 1.5, "rate": 1.4, "speed": 1.6, "size": 1.75, "cleave": 1.3, "charge": true, "tags": ["beast", "giant", "armored"], "art": 4},
	"cyclops": {"name": "Циклоп", "boss": true, "hp": 3000, "atk": 62, "armor": 30, "range": 8.0, "rate": 2.6, "speed": 1.1, "size": 2.1, "shot": "boulder", "splash": 1.8, "tags": ["giant"], "art": 5},
	"elephant": {"name": "Боевой слон Ганнибала", "boss": true, "hp": 4000, "atk": 70, "armor": 50, "range": 1.7, "rate": 1.8, "speed": 1.2, "size": 1.45, "cleave": 1.8, "tags": ["beast", "giant", "armored"], "art": 6},
	"cerberus": {"name": "Цербер", "boss": true, "hp": 4600, "atk": 80, "armor": 40, "range": 1.5, "rate": 1.1, "speed": 1.9, "size": 1.9, "bites": 3, "tags": ["beast", "giant"], "art": 7},
}

# =====================================================================
#   провинции карты походов
# =====================================================================
## Каждая — своя карта на весь экран (рисованный фон 40a…40h), тропа из STAGES боёв, последний — босс.
## rank — с какого уровня города (Defs.LEVELS) провинция открыта: первая — с «Хутора» (там Легион открывает история
## «Разбойники у арки», решение владельца Д9 от 25.10), холмы — с «Посёлка» (лес по таймерам улучшений тянется через
## «Деревню»), дальше — по две на уровень.
## Самый трудный бой провинции (target_level) не выше предела бойцов CAP_BY_CITY её уровня — стены нет.
## trophy — украшение в город за все 30 звёзд провинции (Defs.B, unlock «trophy:<id провинции>»)
const REGIONS := [
	{"id": "forest", "name": "Лес разбойников", "biome": "forest", "foes": ["bandit", "bandit", "slinger", "wolf"], "boss": "chief", "rank": 1,
		"desc": "Шайки на лесной дороге: пращники в кустах, волчьи тропы, атаман с шайкой. Подбирайте отряд под бой.", "map": "40a",
		"trophy": "trophy_cart"},
	{"id": "hills", "name": "Дикие холмы", "biome": "hills", "foes": ["wolf", "wolf", "boar", "bear"], "boss": "greatbear", "rank": 3,
		"desc": "Волчьи стаи и медведи. Копейщики держат зверя на расстоянии.", "map": "40b"},
	{"id": "gaul", "name": "Галльская чаща", "biome": "darkforest", "foes": ["gaul", "gaul", "gaulArcher", "boar"], "boss": "gaulKing", "rank": 5,
		"desc": "Галлы бьются отчаянно, их лучники прячутся за деревьями.", "map": "40c"},
	{"id": "germania", "name": "Германские болота", "biome": "swamp", "foes": ["berserker", "wolf", "gaulArcher", "berserker"], "boss": "giant", "rank": 5,
		"desc": "Берсерки не знают страха. В тумане ждёт великан.", "map": "40d"},
	{"id": "crete", "name": "Лабиринт Минотавра", "biome": "labyrinth", "foes": ["bull", "pirate", "bull", "slinger"], "boss": "minotaur", "rank": 6,
		"desc": "Каменные коридоры Крита и бешеные быки.", "map": "40e"},
	{"id": "sicily", "name": "Скалы циклопов", "biome": "rocks", "foes": ["pirate", "slinger", "pirate", "boar"], "boss": "cyclops", "rank": 6,
		"desc": "Пираты на берегу, а наверху — циклоп с камнями.", "map": "40f"},
	{"id": "carthage", "name": "Пески Карфагена", "biome": "desert", "foes": ["mercenary", "slinger", "mercenary", "pirate"], "boss": "elephant", "rank": 7,
		"desc": "Наёмники в броне и боевые слоны Ганнибала.", "map": "40g"},
	{"id": "hades", "name": "Врата Аида", "biome": "hades", "foes": ["shade", "hellhound", "shade", "hellhound"], "boss": "cerberus", "rank": 7,
		"desc": "Тени и адские псы стерегут вход. За ними — Цербер.", "map": "40h"},
]
const STAGES := 10
## Сложность и добыча растут как при восьми боях на провинцию (так проверен баланс старой игры)
const STAGE_STEP := 0.8
## Сила врагов: ×STAGE_GROWTH^Dc (Dc — глубина боя внутри круга: 0…63), боссов — ×BOSS_GROWTH^Dc (их числа и так
## растут от провинции к провинции), × подгонка TUNE. На каждом новом круге похода враги сильнее ровно настолько,
## насколько бойцы сильнее на CYCLE_CAP уровней (level_k) — каждый круг просит на CYCLE_CAP уровней больше
static var STAGE_GROWTH := 1.035
static var BOSS_GROWTH := 1.01
## Сколько врагов в волне: 2 + (бой × 0,8 + провинция × WAVE_R) / WAVE_DIV, не больше WAVE_MAX
## (в последней волне боёв с 6-го — на одного больше)
static var WAVE_R := 1.0
static var WAVE_DIV := 3.0
static var WAVE_MAX := 6
## Подгонка силы врагов каждого боя первого круга (множитель к силе), посчитана проверками баланса
## (scripts/test_legion.gd mode=calibrate): отряд обычного игрока (состав — auto_squad) на уровне target_level(r, s)
## с умениями побеждает в ≥90% боёв, а без умений на уровень выше — в ≥40% (умения стоят примерно уровня,
## но без них никто не упирается в стену). Лес (этап 3b): свои бои (FIXED), «Лучший состав» под бой — с умениями ≥90%,
## без умений на том же уровне — от 35% там, где решает масло (mode=calibrate regions=0 np_off=0 need_np=0.35); бои с
## пращниками (2-й и 7-й) — легче наибольшего: «не тот» отряд там всё равно ~0%, зато «все вернулись» достижимо на T+2
## (mode=squads: верно / без умений / не тот / звёзды); первый бой — учебный: с маслом в миг остановки 100%, без масла 0%,
## «Авто» (бережёт масло для кучи) 100% (mode=tut). Пусто — без подгонки
static var TUNE: Array = [
	[1.8, 2.0, 2.4, 1.82, 1.86, 2.06, 1.6, 1.89, 1.32, 1.12],   # Лес разбойников (этап 3b: свои бои, отряд под бой; бой 1 — учебный, mode=tut)
	[2.98, 2.82, 4.29, 1.34, 2.04, 1.38, 1.31, 0.91, 0.92, 1.27],   # Дикие холмы
	[2.19, 2.64, 1.78, 1.31, 1.37, 1.08, 0.87, 0.8, 0.81, 0.93],   # Галльская чаща
	[3.92, 1.83, 1.54, 1.27, 0.96, 1.32, 1.01, 0.6, 0.6, 0.88],   # Германские болота
	[1.45, 1.87, 1.31, 0.74, 0.94, 0.61, 0.82, 0.54, 0.51, 0.66],   # Лабиринт Минотавра
	[2.1, 2.04, 1.32, 1.0, 1.08, 0.74, 0.8, 0.55, 0.66, 0.97],   # Скалы циклопов
	[0.94, 1.06, 0.86, 0.7, 0.62, 0.6, 0.52, 0.5, 0.45, 0.57],   # Пески Карфагена
	[1.07, 1.13, 1.11, 0.59, 0.67, 0.55, 0.63, 0.48, 0.41, 0.52],   # Врата Аида
]
## То же для кругов со второго (отряд уже полный, умения сильные): множитель поверх TUNE и роста уровней;
## посчитано на втором круге (mode=calibrate cycle=1) с той же целью. Дальше каждый круг ещё ×CYCLE_EXTRA
static var TUNE_C: Array = [
	[2.23, 3.06, 2.15, 2.34, 2.57, 2.16, 2.87, 2.33, 2.45, 2.31],   # Лес разбойников (этап 3b: свои бои леса на всех кругах)
	[1.98, 2.04, 2.17, 2.02, 2.08, 1.97, 1.82, 1.77, 1.87, 1.89],   # Дикие холмы
	[1.97, 1.8, 1.94, 1.78, 1.81, 1.75, 1.85, 1.82, 1.66, 1.67],   # Галльская чаща
	[1.46, 1.38, 1.51, 1.43, 1.47, 1.43, 1.44, 1.51, 1.49, 1.43],   # Германские болота
	[1.38, 1.46, 1.34, 1.42, 1.39, 1.43, 1.45, 1.36, 1.39, 1.44],   # Лабиринт Минотавра
	[1.2, 1.2, 1.2, 1.25, 1.2, 1.23, 1.2, 1.22, 1.22, 1.19],   # Скалы циклопов
	[1.25, 1.26, 1.26, 1.17, 1.17, 1.18, 1.19, 1.2, 1.19, 1.18],   # Пески Карфагена
	[1.06, 1.06, 1.12, 1.06, 1.06, 1.07, 1.05, 1.03, 1.03, 1.06],   # Врата Аида
]
static var CYCLE_EXTRA := 1.05
## Каждый пройденный круг похода поднимает предел уровня бойцов на CYCLE_CAP (походы бесконечны)
const CYCLE_CAP := 6
## …и ещё запас в CYCLE_ROOM уровней (на дальних кругах бои разнятся сильнее — чтобы ни один не стал стеной)
const CYCLE_ROOM := 3

# =====================================================================
#   умения в бою: открываются победами над боссами, усиливаются за Славу
# =====================================================================
## cd — перезарядка (с), boss — после какого по счёту босса открывается (0 — с первого дня Легиона: в каждом бою есть
## своя кнопка). art — лист 38 (4×4), номер.
const PERKS := {
	"oil": {"name": "Кипящее масло", "cd": 14.0, "boss": 0, "art": 0, "desc": "Котёл опрокидывают на самую плотную толпу врагов: сильный урон и ожог."},
	"testudo": {"name": "Черепаха", "cd": 20.0, "boss": 2, "art": 1, "desc": "Отряд смыкает щиты: урон по бойцам заметно меньше."},
	"bandage": {"name": "Перевязка", "cd": 22.0, "boss": 3, "art": 2, "desc": "Лекари перевязывают раненых: отряд лечится."},
	"volley": {"name": "Залп", "cd": 18.0, "boss": 4, "art": 3, "desc": "Лучники из тыла бьют по всем врагам разом."},
	"horn": {"name": "Боевой рог", "cd": 25.0, "boss": 6, "art": 4, "desc": "Отряд бьёт и двигается быстрее."},
}
const PERK_IDS := ["oil", "testudo", "bandage", "volley", "horn"]
const PERK_MAX := 5

# =====================================================================
#   прокачка родов войск
# =====================================================================
## Уровни 1…10 — первый круг походов; каждый пройденный круг поднимает предел на CYCLE_CAP (до MAX_LEVEL)
const MAX_LEVEL := 40
## Секунд настоящего времени на улучшение до уровня n: от 5 минут до двух суток (выше 10-го — по двое суток)
const UPGRADE_TIME := [0, 0, 300, 1800, 3600, 5400, 7200, 14400, 28800, 86400, 172800]
## Предел уровня бойцов от уровня города (индекс — Defs.LEVELS): растите город, чтобы растить армию.
## На уровне города, где открывается провинция, предел не ниже её самого трудного боя (target_level):
## лес (до 3-го) — с «Хутора», холмы (до 4-го) — с «Посёлка»
const CAP_BY_CITY := [3, 3, 3, 4, 4, 6, 8, 10]
const SQUAD_BASE := 3
const SQUAD_MAX := 7
## После скольких боссов открывается ещё одно место в отряде
const SLOT_BOSSES := [1, 3, 5, 7]
## Рейтинг походов — достижение, не тратится: за новый бой, за босса, за повтор
const RATING := {"first": 3, "boss": 12, "repeat": 1}
## Награда за первую победу в бою — во столько раз больше
const FIRST_K := 2.5
## Провиант на поход: денариев на бойца (растёт со сложностью боя)
const FOOD := {"base": 5.0, "per_d": 2.0}
## Триумф: за Славу город празднует — счастье всех домов выше на время
const TRIUMPH := {"glory": 15, "hours": 72, "happy": 5}

# =====================================================================
#   чудеса света
# =====================================================================
## Первые три открывает рейтинг походов (rating), старшие — рейтинг побед над городами (pvp: true).
## building — постройка в городе (Defs.B, ставится как обычная, сверх денариев стоит glory Славы);
## без building — чудо «строится» прямо в окне за Славу и денарии (money) и действует на весь город.
## army — бонус бойцам (доля), happy — счастье всех домов (%), glory_day — Славы в игровой день.
## art — картинка: лист 41 (4×2), номер.
const WONDERS := [
	{"id": "arch", "building": "arch", "rating": 30, "glory": 25, "army": {"atk": 0.05}, "glory_day": 0.0, "art": 0,
		"bonus": "+5% урона всем бойцам. Красота и счастье вокруг арки."},
	{"id": "colosseum", "building": "colosseum", "rating": 120, "glory": 50, "army": {"hp": 0.10}, "glory_day": 0.5, "art": 1,
		"bonus": "+10% здоровья бойцам, Слава каждый день. Счастье большого квартала."},
	{"id": "pantheon", "building": "pantheon", "rating": 250, "glory": 80, "army": {"atk": 0.10}, "glory_day": 0.5, "art": 2,
		"bonus": "+10% урона бойцам, Слава каждый день. Счастье большого квартала."},
	{"id": "circus", "name": "Большой цирк", "pvp": true, "rating": 200, "glory": 120, "money": 20000, "happy": 4, "glory_day": 0.5, "art": 3,
		"bonus": "Скачки колесниц: +4% счастья всему городу и Слава каждый день."},
	{"id": "aqueduct", "name": "Акведук Клавдия", "pvp": true, "rating": 450, "glory": 160, "money": 30000, "happy": 4, "art": 4,
		"bonus": "Чистая вода всему городу: +4% счастья всем домам."},
	{"id": "trajan", "name": "Колонна Траяна", "pvp": true, "rating": 800, "glory": 220, "money": 40000, "army": {"atk": 0.15, "hp": 0.15}, "art": 5,
		"bonus": "+15% урона и здоровья всей армии."},
	{"id": "caracalla", "name": "Термы Каракаллы", "pvp": true, "rating": 1200, "glory": 300, "money": 60000, "happy": 6, "art": 6,
		"bonus": "Термы для всего города: +6% счастья всем домам."},
	{"id": "jupiter", "name": "Храм Юпитера Капитолийского", "pvp": true, "rating": 1800, "glory": 400, "money": 90000, "happy": 4, "glory_day": 1.0,
		"army": {"atk": 0.05, "hp": 0.05}, "art": 7, "bonus": "Величайший храм Рима: +4% счастья, +5% силы армии и Слава каждый день."},
]

# =====================================================================
#   бои с другими городами (асинхронно: нападаем на сохранённый отряд обороны соперника)
# =====================================================================
## charges — сколько атак в запасе, regen — секунд на один заряд; рейтинг побед не уходит ниже нуля
const PVP := {"charges": 5, "regen": 1800, "win_base": 20, "win_min": 8, "win_max": 40, "loss_base": 10, "loss_min": 3, "loss_max": 20,
	"loot_money": 2.0, "loot_base": 150, "glory": 2}
## Бои с городами — с «Посёлка», как до Д9: Легион теперь с «Хутора», а добыча боёв (~1000 ден. за победу) рассчитана
## на казну «Посёлка»; на «Хуторе» и в «Деревне» она обесценила бы тесные деньги. Сервер проверяет то же (server/pvp.js)
const PVP_MIN_LEVEL := 3

# =====================================================================
#   картинки (владелец пришлёт: D:/CivCity/assets/incoming/ui_ai/35.png … 41.png, разложим в assets/ui/ai/legion)
# =====================================================================
## Лист → [колонок, строк]. Окно грузит картинку, если файл есть, иначе рисует свою заглушку.
const ART_SHEETS := {"35": [5, 1], "36": [4, 4], "37": [4, 2], "38": [4, 4], "39": [4, 4], "41": [4, 2]}
const ART_DIR := "res://assets/ui/ai/legion/"

# =====================================================================
#   состояние игрока (сохраняется)
# =====================================================================
var levels := {}            # род войск → уровень (1…MAX_LEVEL) = уровень его здания
var blevels := {}           # здание поддержки (SUPPORT) → уровень (1…max)
var upg := {}               # идущее улучшение: род или здание поддержки → {"to": уровень, "end": unix-время конца, "total": секунд всего}
var squad: Array = ["legionary", "legionary", "legionary"]   # отряд походов (места по порядку, "" — пусто)
var defense: Array = []     # отряд обороны для боёв с городами ([] — как отряд походов)
var perks := {}             # умение → уровень (0 — закрыто)
var stars := {}             # "круг-провинция-бой" → звёзды-биты (STAR_WIN | STAR_SAFE | STAR_TASK), лучшее за все заходы
var chests := {}            # "круг-провинция" → сундук за 30 звёзд уже выдан
var trophies := {}          # id провинции → трофей (украшение) открыт в городе
var progress := 0           # сколько боёв первого прохода пройдено подряд (сквозь круги)
var wins := 0
var rating := 0             # рейтинг походов (не тратится)
var glory := 0.0            # Слава (тратится: умения, чудеса, триумф, высокие уровни бойцов)
var pvp_rating := 0         # рейтинг побед над городами
var pvp_charges: int = PVP["charges"]
var pvp_charge_t := 0.0     # unix-время, с которого копится следующий заряд
var pvp_wins := 0
var pvp_losses := 0
var pvp_log: Array = []     # последние бои с городами: [{t, name, win, delta, money}]
var built := {}             # чудеса без постройки в городе, которые уже возведены: id → true
var triumph_left := 0       # сколько игровых часов ещё идёт триумф
var glory_acc := 0.0        # дробные Славы от чудес (копятся по часам)
var flags := {}             # для окна: что уже показано (перелистнуть карту на новую провинцию и т. п.)

## Для проверок: ускорение таймеров улучшений (не сохраняется)
var time_k := 1.0
## Для проверок без города: всё открыто, предел — MAX_LEVEL
var free_mode := false
## Для бота темпа: свои «настоящие часы» (секунды; < 0 — часы компьютера). Бот играет по игровым часам, а таймеры
## улучшений идут по настоящим — бот ведёт их сам (1 игровой час = 25 с при 1×)
static var clock := -1.0

var _city: WeakRef = null


func _init() -> void:
	_ensure()


func bind(c: Object) -> void:
	_city = weakref(c) if c != null else null


func city() -> Object:
	return _city.get_ref() if _city != null else null


func _ensure() -> void:
	for k in UNIT_IDS:
		if not levels.has(k):
			levels[k] = 1
	for k in SUPPORT:
		if not blevels.has(k):
			blevels[k] = 1
	for p in PERK_IDS:
		if not perks.has(p):
			perks[p] = 1 if int(PERKS[p]["boss"]) <= 0 else 0      # масло — с первого дня


static func now() -> float:
	return clock if clock >= 0.0 else Time.get_unix_time_from_system()


# =====================================================================
#   доступ: окно, рода войск, отряд
# =====================================================================

## Окно «Легион» открыто: «Легион» открыт (историей «Разбойники у арки» или прежним исследованием — Defs.RESEARCH)
func window_open() -> bool:
	if free_mode:
		return true
	var c = city()
	return c != null and (c.research as Dictionary).has("legion")


## Почему окно ещё закрыто ("" — открыто)
func lock_text() -> String:
	if window_open():
		return ""
	var c = city()
	var rank := int(REGIONS[0]["rank"])
	var head := "Легион откроется в истории горожан «%s»" % story_title()
	if c == null or int(c.level) < rank:
		return head + " — она придёт, когда город станет «%s»." % Defs.LEVELS[rank]["name"]
	# город уже дорос: говорим, чего история ждёт на самом деле (старый город без Легиона — тоже сюда)
	var s: Dictionary = c.stories
	var off: Dictionary = s.get("offer", {})
	if String(off.get("id", "")) == STORY:
		return head + " — она уже ждёт вас: над домом переселенца свиток с просьбой, щёлкните его."
	if (s.get("later", {}) as Dictionary).has(STORY):
		return head + " — вы её отложили, она скоро вернётся."
	# истории идут по одной: сначала та, что идёт (или ждёт ответа)
	var act: Dictionary = s.get("active", {})
	var busy: Dictionary = act if not act.is_empty() else off
	if not busy.is_empty():
		return head + " — она придёт после истории «%s»." % StoryDefs.title_of(StoryDefs.story(String(busy.get("id", ""))), busy)
	var af := String(StoryDefs.story(STORY).get("after", ""))
	if af != "" and int(c.level) < 2 and not (s.get("done", {}) as Dictionary).has(af):
		return head + " — она придёт после истории «%s»." % String(StoryDefs.story(af).get("title", af))
	return head + " — она скоро придёт: горожане попросят о защите."


## История, которая открывает Легион (Д9), и её название
const STORY := "bandits"


static func story_title() -> String:
	return String(StoryDefs.story(STORY).get("title", "Разбойники у арки"))


## Военный квартал у арки, который предложила история «Разбойники у арки»: [x, z, радиус] или []. Здания Легиона (Д10)
## предлагается ставить сюда (Stories._legion_zone: пятно и «В военном квартале ✓» у курсора), бонуса «рядом» нет
func quarter() -> Array:
	var q: Array = flags.get("quarter", [])
	return q if q.size() == 3 else []


func city_level() -> int:
	if free_mode:
		return Defs.LEVELS.size() - 1
	var c = city()
	return int(c.level) if c != null else 0


func city_money() -> float:
	var c = city()
	return float(c.money) if c != null else 1e12


## Сколько таких построек в городе
func count_type(type: String) -> int:
	var c = city()
	if c == null:
		return 0
	var n := 0
	for id in c.buildings:
		if c.buildings[id]["type"] == type:
			n += 1
	return n


## Род войск можно брать в бой (здание поддержки работает): его постройка стоит в городе
func available(type: String) -> bool:
	if free_mode:
		return true
	return count_type(building_of(type)) > 0


## Почему род войск (здание поддержки) недоступен ("" — доступен): нужна победа над боссом, исследование, уровень города
## или постройка
func unit_lock_text(type: String) -> String:
	if available(type):
		return ""
	var b := building_of(type)
	var c = city()
	if c != null and not c.unlocked(b):
		return "Откроется %s" % Defs.unlock_text(String(Defs.B[b].get("unlock", "")))
	return "Постройте в городе: %s" % Defs.B[b]["name"]


func bosses() -> int:
	return progress / STAGES


static func boss_name(n: int) -> String:
	var R: Dictionary = REGIONS[(n - 1) % REGIONS.size()]
	return ENEMIES[R["boss"]]["name"]


## Места в отряде: три с начала и ещё по одному за боссов — каждое с Казармами нужного уровня (SLOT_BARRACKS, Д10).
## Места, открытые до зданий Легиона (flags.slots0, перенос старого сохранения), не отнимаются
func slots() -> int:
	var n := SQUAD_BASE
	var bl := _slot_barracks()
	for i in SLOT_BOSSES.size():
		if bosses() >= int(SLOT_BOSSES[i]) and bl >= int(SLOT_BARRACKS[i]):
			n += 1
	return maxi(n, int(flags.get("slots0", 0)))


## Уровень Казарм для мест в отряде (без города и в проверках — без этого условия)
func _slot_barracks() -> int:
	return MAX_LEVEL if free_mode or city() == null else int(levels.get("legionary", 1))


## Сколько мест в отряде позволяют Казармы уровня lvl (если побеждены все нужные боссы)
static func slots_at(lvl: int) -> int:
	var n := SQUAD_BASE
	for need in SLOT_BARRACKS:
		if lvl >= int(need):
			n += 1
	return n


## После какого по счёту босса откроется следующее место (0 — все открыты)
func next_slot_boss() -> int:
	for b in SLOT_BOSSES:
		if bosses() < int(b):
			return int(b)
	return 0


## Почему закрыто место отряда номер i (с нуля; "" — открыто): босс и/или уровень Казарм
func slot_lock_text(i: int) -> String:
	if i < slots():
		return ""
	var k := clampi(i - SQUAD_BASE, 0, SLOT_BOSSES.size() - 1)
	var parts := []
	if bosses() < int(SLOT_BOSSES[k]):
		parts.append("после победы над боссом: %s" % boss_name(int(SLOT_BOSSES[k])))
	if _slot_barracks() < int(SLOT_BARRACKS[k]):
		parts.append("с Казармами %d уровня" % int(SLOT_BARRACKS[k]))
	return "Место откроется " + " и ".join(parts) if not parts.is_empty() else "Место откроется позже"


func set_slot(i: int, type: String) -> void:
	while squad.size() <= i:
		squad.append("")
	squad[i] = type
	changed.emit()


func set_defense_slot(i: int, type: String) -> void:
	if defense.is_empty():
		defense = squad.duplicate()
	while defense.size() <= i:
		defense.append("")
	defense[i] = type
	changed.emit()


## Хороший состав из доступных родов войск под бой st: впереди держат строй легионеры и копейщики, за ними лучники,
## в тылу машины (кнопка «Лучший состав» в окне; так же собирают отряд проверки баланса). Пока мест три (лес до
## первого босса), состав — ответ на бой: против пращников — с лучником, против волков и шайки — три легионера
## (wants_archer); волчьи бои леса (bite) — без лучника при любом числе мест. Без боя (st пуст) — бой переднего края
func auto_squad(st := {}) -> Array:
	var have := []
	for t in UNIT_IDS:
		if available(t):
			have.append(t)
	if st.is_empty():
		var fr := frontier()
		st = stage(int(fr["cycle"]), int(fr["r"]), int(fr["s"]))
	return counter_squad(st, have, slots())


## Состав под бой st из родов have на n мест (так же собирает отряд проверка баланса test_legion.gd)
static func counter_squad(st: Dictionary, have: Array, n: int) -> Array:
	var out := []
	if have.is_empty():
		return out
	# порядок предпочтения по местам: каждый род по очереди, пока есть места
	var plan := ["legionary", "archer", "spearman", "ballista", "legionary", "catapult", "archer", "spearman", "legionary"]
	# волки леса рвут лучников (bite): там лучника не берём и при четырёх местах и больше, пока есть легионеры
	var wolves := bool(st.get("bite", false)) and "legionary" in have
	var bow := not wolves and (n > SQUAD_BASE or wants_archer(st) or not ("legionary" in have))
	for t in plan:
		if out.size() >= n:
			break
		if t == "archer" and not bow:
			continue
		if t in have:
			out.append(t)
	while out.size() < n:
		out.append("legionary" if "legionary" in have else have[0])
	return out


## Бою на три места нужен лучник: у боёв леса — squad "bow" («пращники в кустах») или "any" с ними; у прочих — врагов-стрелков
## двое и больше, а зверей, что бросаются на стрелков, нет
static func wants_archer(st: Dictionary) -> bool:
	if bool(st.get("fixed", false)):
		# «годятся оба»: при пращниках в кустах «Лучший состав» всё же берёт лучника (без умений с ним надёжнее)
		return String(st.get("squad", "")) == "bow" or (String(st.get("squad", "")) == "any" and bool(st.get("kite", false)))
	var ranged := 0
	for w: Array in st.get("waves", []):
		for k in w:
			var E: Dictionary = ENEMIES[k]
			if String(E.get("prefer", "")) == "ranged":
				return false
			if float(E["range"]) > 3.0:
				ranged += 1
	return ranged >= 2


func use_auto_squad(st := {}) -> void:
	squad = auto_squad(st)
	changed.emit()


## Отряд отличается от «Лучшего состава» для боя st (по родам войск, порядок мест не важен). Бою «годятся оба»
## (squad "any") подходят и три легионера, и легионеры с лучником. С четырёх мест «Лучший состав» уже не ответ на бой
## (общий порядок родов войск) — не под бой только лучник в волчьем бою леса (bite)
func squad_off(st: Dictionary) -> bool:
	var a := []
	for u: Dictionary in squad_stats():
		a.append(String(u["key"]))
	a.sort()
	var b := auto_squad(st)
	b.sort()
	if a == b:
		return false
	if slots() > SQUAD_BASE:
		return bool(st.get("bite", false)) and "archer" in a and not "archer" in b
	if String(st.get("squad", "")) == "any" and slots() <= SQUAD_BASE:
		var bow := ["archer", "legionary", "legionary"]
		var leg := ["legionary", "legionary", "legionary"]
		return not (a == bow or a == leg)
	return true


# =====================================================================
#   бонусы чудес
# =====================================================================

## Чудо возведено: постройка стоит в городе (или куплено в окне)
func wonder_built(w: Dictionary) -> bool:
	if w.has("building"):
		return count_type(String(w["building"])) > 0
	return built.has(w["id"])


## Бонус чудес армии: "atk" или "hp" (доля)
func bonus(key: String) -> float:
	var v := 0.0
	for w: Dictionary in WONDERS:
		if w.has("army") and (w["army"] as Dictionary).has(key) and wonder_built(w):
			v += float(w["army"][key])
	return v


# =====================================================================
#   боевые числа
# =====================================================================

## Боец рода type на уровне lvl с бонусами чудес и Кузницы (atk_b, hp_b — доли) и Склада оружия (armor_b — броня).
## То же для чужих отрядов в боях с городами (там armor_b нет: сервер его не знает)
static func unit_stats(type: String, lvl: int, atk_b := 0.0, hp_b := 0.0, armor_b := 0.0) -> Dictionary:
	var U: Dictionary = UNITS[type]
	var hp_k := 1.0 + 0.19 * (lvl - 1) + hp_b
	var atk_k := 1.0 + 0.22 * (lvl - 1) + atk_b
	return {"key": type, "name": U["name"], "level": lvl, "hp": roundi(float(U["hp"]) * hp_k), "atk": roundi(float(U["atk"]) * atk_k),
		"armor": float(U["armor"]) + 6.0 * (lvl - 1) + armor_b, "range": float(U["range"]), "min_range": float(U.get("min_range", 0.0)),
		"rate": float(U["rate"]), "speed": float(U["speed"]), "shot": String(U.get("shot", "")), "pierce": bool(U.get("pierce", false)),
		"splash": float(U.get("splash", 0.0)), "vs": U["vs"], "tags": U["tags"], "size": 1.0, "boss": false}


## Боец нашего Легиона: в походах — с Кузницей и Складом оружия; pvp — как его увидит сервер боёв с городами
## (без них, пока PVP_MODS выключен)
func stats(type: String, pvp := false) -> Dictionary:
	var mods := not pvp or PVP_MODS
	return unit_stats(type, int(levels.get(type, 1)), bonus("atk") + (forge_b() if mods else 0.0), bonus("hp") + (forge_b() if mods else 0.0),
		armory_b() if mods else 0.0)


## Враг на силе scale (круг и глубина похода)
static func enemy_stats(key: String, scale: float) -> Dictionary:
	var E: Dictionary = ENEMIES[key]
	return {"key": key, "name": E["name"], "level": 0, "hp": roundi(float(E["hp"]) * scale), "atk": roundi(float(E["atk"]) * pow(scale, 0.92)),
		"armor": minf(85.0, float(E["armor"]) + log(scale) * 6.0), "range": float(E["range"]), "min_range": 0.0, "rate": float(E["rate"]),
		"speed": float(E["speed"]), "shot": String(E.get("shot", "")), "pierce": false, "splash": float(E.get("splash", 0.0)),
		"cleave": float(E.get("cleave", 0.0)), "charge": bool(E.get("charge", false)), "bites": int(E.get("bites", 0)),
		"prefer": String(E.get("prefer", "")), "vs": {}, "tags": E["tags"], "boss": bool(E.get("boss", false)), "size": float(E.get("size", 1.0))}


## «Сила» бойца для сравнения с врагом: живучесть × урон в секунду
static func power(s: Dictionary) -> int:
	var armor := float(s["armor"])
	var ehp := float(s["hp"]) / (1.0 - armor / (armor + 100.0))
	var mult := (1.5 if float(s.get("splash", 0.0)) > 0.0 else 1.0) * (1.3 if bool(s.get("pierce", false)) else 1.0) * (1.15 if float(s["range"]) > 3.0 else 1.0)
	return roundi(sqrt(ehp * float(s["atk"]) / float(s["rate"]) * mult) * 1.6)


## Бойцы отряда (только доступные и на открытых местах): "campaign" — походы, "pvp" — тот же отряд в бою с городом,
## "defense" — отряд обороны (бои с городами считаются без Кузницы и Склада оружия, пока PVP_MODS выключен)
func squad_stats(which := "campaign") -> Array:
	var src: Array = squad if which != "defense" or defense.is_empty() else defense
	var out := []
	var n := slots()
	for i in mini(n, src.size()):
		var t: String = src[i]
		if t != "" and UNITS.has(t) and available(t):
			out.append(stats(t, which != "campaign"))
	return out


func squad_power(which := "campaign") -> int:
	var p := 0
	for s: Dictionary in squad_stats(which):
		p += power(s)
	return p


# =====================================================================
#   прокачка: уровни зданий Легиона (род войск или здание поддержки), по настоящим часам
# =====================================================================

## Предел уровня бойцов при нынешнем уровне города
func cap() -> int:
	if free_mode:
		return MAX_LEVEL
	var cd := cycles_done()
	return mini(MAX_LEVEL, int(CAP_BY_CITY[clampi(city_level(), 0, CAP_BY_CITY.size() - 1)]) + (CYCLE_CAP * cd + CYCLE_ROOM if cd > 0 else 0))


## Предел уровня для ключа: род войск — cap(); здание поддержки — его наивысший уровень и предел города
## (круги походов его не поднимают)
func cap_of(key: String) -> int:
	if UNITS.has(key):
		return cap()
	var mx := int(SUPPORT.get(key, {}).get("max", 1))
	if free_mode:
		return mx
	return mini(mx, int(CAP_BY_CITY[clampi(city_level(), 0, CAP_BY_CITY.size() - 1)]))


## Наивысший уровень ключа вообще
static func max_of(key: String) -> int:
	return MAX_LEVEL if UNITS.has(key) else int(SUPPORT.get(key, {}).get("max", 1))


## Уровень по ключу (род войск — уровень его здания; здание поддержки — свой)
func level_of(key: String) -> int:
	if UNITS.has(key):
		return int(levels.get(key, 1))
	return int(blevels.get(key, 1))


func _set_level(key: String, v: int) -> void:
	if UNITS.has(key):
		levels[key] = v
	else:
		blevels[key] = v


## Сколько кругов походов пройдено целиком (побеждён Цербер)
func cycles_done() -> int:
	return progress / (REGIONS.size() * STAGES)


## С какого уровня города предел поднимется (−1 — рост города его уже не поднимет). Считает как cap():
## пройденные круги походов прибавляют к пределу города и после первого круга (у зданий поддержки — без кругов)
func next_cap_city_level(key := "") -> int:
	var sup := SUPPORT.has(key)
	var c := cap_of(key) if sup else cap()
	var cd := cycles_done()
	var extra := (CYCLE_CAP * cd + CYCLE_ROOM) if cd > 0 and not sup else 0
	var mx := max_of(key) if sup else MAX_LEVEL
	for i in range(city_level() + 1, CAP_BY_CITY.size()):
		if mini(mx, int(CAP_BY_CITY[i]) + extra) > c:
			return i
	return -1


## Цена улучшения рода войск до уровня to: денарии, с 6-го уровня — ещё и Слава (выше 10-го растёт медленнее)
static func unit_cost(type: String, to: int) -> Dictionary:
	return level_cost(type, to)


## То же для любого ключа (род войск или здание поддержки — свой множитель cost_k)
static func level_cost(key: String, to: int) -> Dictionary:
	var f := float((UNITS[key] if UNITS.has(key) else SUPPORT.get(key, {})).get("cost_k", 1.0))
	var over := maxi(0, to - 10)
	var c := {"money": int(round(700.0 * pow(1.6, mini(to, 10) - 2) * (1.0 + 0.25 * over) * f / 10.0)) * 10}
	if to >= 6:
		c["glory"] = int(round(4.0 * pow(1.35, mini(to, 10) - 6) * (1.0 + 0.5 * over) * f))
	return c


## Всё про следующее улучшение: {cur, to, max, blocked (выше предела города), limit, cost, time (с)}
func upgrade_info(type: String) -> Dictionary:
	var cur := level_of(type)
	var mx := max_of(type)
	var to := mini(cur + 1, mx)
	var limit := mini(mx, cap_of(type))
	return {"cur": cur, "to": to, "max": cur >= mx, "blocked": cur + 1 > limit, "limit": limit,
		"cost": level_cost(type, to), "time": float(UPGRADE_TIME[mini(to, UPGRADE_TIME.size() - 1)]) / maxf(0.001, time_k)}


## Можно ли улучшить ("" — можно, иначе почему нельзя)
func can_upgrade(type: String) -> String:
	if not UNITS.has(type) and not SUPPORT.has(type):
		return "Нет такого рода войск"
	if not available(type):
		return unit_lock_text(type)
	if upg.has(type):
		return "Уже улучшается"
	var i := upgrade_info(type)
	if i["max"]:
		return "Максимальный уровень"
	if i["blocked"]:
		var nl := next_cap_city_level(type)
		var more := ""
		if nl >= 0:
			more = " Дальше — когда город станет «%s»." % Defs.LEVELS[nl]["name"]
		elif UNITS.has(type) and cap() < MAX_LEVEL:
			more = " Дальше — после следующего круга походов."
		# после первого круга предел складывается из уровня города и пройденных кругов
		return "Предел %s — %d уровень.%s" % ["города" if cycles_done() == 0 or SUPPORT.has(type) else "сейчас", i["limit"], more]
	return _afford_text(i["cost"])


func _afford_text(cost: Dictionary) -> String:
	if float(cost.get("money", 0)) > city_money():
		return "Не хватает денариев"
	if float(cost.get("glory", 0)) > glory + 0.001:
		return "Не хватает Славы"
	return ""


func _pay(cost: Dictionary) -> void:
	var c = city()
	if c != null:
		c.money -= float(cost.get("money", 0))
		if c.has_method("flow"):
			c.flow("legion", -float(cost.get("money", 0)))   # история денег за сутки (этап 2.4)
	glory -= float(cost.get("glory", 0))


## Начать улучшение (платит сразу); true — началось
func upgrade(type: String) -> bool:
	if can_upgrade(type) != "":
		return false
	var i := upgrade_info(type)
	_pay(i["cost"])
	upg[type] = {"to": i["to"], "end": now() + float(i["time"]), "total": float(i["time"])}
	var c = city()
	if c != null:
		c.changed.emit()                            # казна наверху экрана — сразу, а не через игровой час
	changed.emit()
	return true


## Секунд до конца улучшения (0 — не идёт)
func upgrade_left(type: String) -> float:
	if not upg.has(type):
		return 0.0
	return maxf(0.0, float(upg[type]["end"]) - now())


## Доля пройденного улучшения 0…1
func upgrade_progress(type: String) -> float:
	if not upg.has(type):
		return 0.0
	return clampf(1.0 - upgrade_left(type) / maxf(1.0, float(upg[type]["total"])), 0.0, 1.0)


## Завершить улучшение (по таймеру; проверки — с ускорением): уровень вырос — здание на карте меняет облик
func finish_upgrade(type: String) -> String:
	if not upg.has(type):
		return ""
	var to := int(upg[type]["to"])
	var s0 := slots()
	_set_level(type, maxi(level_of(type), to))
	upg.erase(type)
	sync_tiers(true)
	changed.emit()
	var bn := String(Defs.B[building_of(type)]["name"])
	if UNITS.has(type):
		# Казармы доросли до места, которое ждало их уровня (босс уже побеждён), — скажем в том же событии
		var more := " Открыто ещё одно место в отряде." if slots() > s0 else ""
		return "%s — %d уровень: %s сильнее и крепче!%s" % [bn, to, String(UNITS[type]["many"]).to_lower(), more]
	return "%s — %d уровень: %s" % [bn, to, String(b_effect(building_of(type), to)[0]).to_lower()]


## Проверка таймеров по настоящим часам — улучшения идут, даже когда игра закрыта.
## Возвращает тексты событий (City кладёт их в колокольчик)
func tick() -> Array:
	var out := []
	var t := now()
	for type in upg.keys():
		if t >= float(upg[type]["end"]):
			out.append(finish_upgrade(type))
	return out


# =====================================================================
#   здания Легиона на карте (Д10)
# =====================================================================

## Ключ уровня здания: род войск (здания бойцов) или само здание (поддержка)
static func bkey(btype: String) -> String:
	return String(BUILDING_UNIT.get(btype, btype))


## Здание, которое растит ключ (род войск → его здание)
static func building_of(key: String) -> String:
	return String(UNITS[key]["building"]) if UNITS.has(key) else key


static func is_building(btype: String) -> bool:
	return btype in BUILDING_IDS


func b_level(btype: String) -> int:
	return level_of(bkey(btype))


func b_built(btype: String) -> bool:
	return free_mode or count_type(btype) > 0


## Уровень «в запасе»: здания нет, а уровень выше первого (перенос старого сохранения, снесли) — 0, если нечего ждать
func b_reserve(btype: String) -> int:
	if b_built(btype):
		return 0
	var l := b_level(btype)
	return l if l > 1 else 0


## Облик здания (City: запись постройки, поле tier) по уровню: 1-й — как построено (tier 0)
static func vis_tier(lvl: int) -> int:
	return clampi(lvl - 1, 0, VIS_MAX)


## Запись здания этого типа на карте ({} — не поставлено)
func building_rec(btype: String) -> Dictionary:
	var c = city()
	if c == null:
		return {}
	for id in c.buildings:
		if String(c.buildings[id]["type"]) == btype:
			return c.buildings[id]
	return {}


## Облик зданий Легиона по их уровням (после загрузки и улучшения); show — перерисовать изменившиеся (с облачком)
func sync_tiers(show := false) -> void:
	var c = city()
	if c == null:
		return
	for id in c.buildings:
		var b: Dictionary = c.buildings[id]
		if not is_building(String(b["type"])):
			continue
		var t := vis_tier(b_level(String(b["type"])))
		if int(b["tier"]) != t:
			b["tier"] = t
			if show and c.has_signal("house_changed"):
				c.house_changed.emit(b, true)


## Кузница, Склад оружия, Лазарет — пока стоят в городе (уровень «в запасе» не действует)
func forge_b() -> float:
	return FORGE * level_of("forge") if available("forge") and not free_mode else 0.0


func armory_b() -> float:
	return ARMORY * level_of("armory") if available("armory") and not free_mode else 0.0


func heal_b() -> float:
	return INFIRMARY * level_of("infirmary") if available("infirmary") and not free_mode else 0.0


## Что даёт здание на уровне lvl — строки для карточки и окна («сейчас» и «на следующем уровне»)
func b_effect(btype: String, lvl: int) -> Array:
	match btype:
		"forge":
			return ["+%d%% урона и здоровья всем бойцам в походах" % roundi(FORGE * lvl * 100.0)]
		"infirmary":
			return ["Между волнами боя раненые восстанавливают %d%% здоровья" % roundi(INFIRMARY * lvl * 100.0)]
		"armory":
			return ["+%d брони всем бойцам в походах" % roundi(ARMORY * lvl), "Позже — снаряжение героя"]
	var u := bkey(btype)
	if not UNITS.has(u):
		return []
	var s := unit_stats(u, lvl, bonus("atk") + forge_b(), bonus("hp") + forge_b(), armory_b())   # как в походе (stats) и на плитке «Войска»
	var out := ["%s %d уровня: здоровье %d, урон %d, броня %d" % [UNITS[u]["many"], lvl, int(s["hp"]), int(s["atk"]), roundi(float(s["armor"]))]]
	if btype == "barracks":
		# места, открытые до зданий Легиона (slots0), — не меньше: следующий уровень не обещает уже имеющееся место
		out.append("Мест в отряде — до %d (новые места — и за победы над боссами)" % maxi(slots_at(lvl), int(flags.get("slots0", 0))))
	return out


## Надпись кнопки улучшения: «Улучшить — 1 790 ден., 4 Славы, 1 ч»
func b_upgrade_text(btype: String) -> String:
	var i := upgrade_info(bkey(btype))
	var parts := ["%s ден." % _num(int(i["cost"].get("money", 0)))]
	if int(i["cost"].get("glory", 0)) > 0:
		parts.append("%d Славы" % int(i["cost"]["glory"]))
	parts.append(fmt_duration(float(i["time"])))
	return "Улучшить — " + ", ".join(parts)


static func _num(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = " " + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if v < 0 else "") + s + out


# =====================================================================
#   умения
# =====================================================================

func perk_cost(id: String) -> int:
	return 6 + 6 * int(perks.get(id, 0))


func can_upgrade_perk(id: String) -> String:
	var lvl := int(perks.get(id, 0))
	if lvl <= 0:
		return "Откроется после победы: %s" % boss_name(int(PERKS[id]["boss"]))
	if lvl >= PERK_MAX:
		return "Максимум"
	if glory + 0.001 < perk_cost(id):
		return "Не хватает Славы"
	return ""


func upgrade_perk(id: String) -> bool:
	if can_upgrade_perk(id) != "":
		return false
	glory -= perk_cost(id)
	perks[id] = int(perks[id]) + 1
	changed.emit()
	return true


## Открытые умения: {id: уровень}
func open_perks() -> Dictionary:
	var out := {}
	for p in PERK_IDS:
		if int(perks.get(p, 0)) > 0:
			out[p] = int(perks[p])
	return out


# =====================================================================
#   карта походов
# =====================================================================

static func stage_key(cycle: int, r: int, s: int) -> String:
	return "%d-%d-%d" % [cycle, r, s]


## Номер боя по порядку: 0, 1, 2… сквозь провинции и круги
static func stage_index(cycle: int, r: int, s: int) -> int:
	return (cycle * REGIONS.size() + r) * STAGES + s


## Провинция открыта уровнем города (на первом круге; дальше — тоже нужен её уровень)
func region_rank_ok(r: int) -> bool:
	return free_mode or city_level() >= int(REGIONS[r]["rank"])


## Почему провинция закрыта уровнем города ("" — открыта)
func region_lock_text(r: int) -> String:
	if region_rank_ok(r):
		return ""
	return "Откроется, когда город станет «%s»" % Defs.LEVELS[int(REGIONS[r]["rank"])]["name"]


## Бой открыт: пройден предыдущий и провинция открыта уровнем города
func stage_open(cycle: int, r: int, s: int) -> bool:
	return stage_index(cycle, r, s) <= progress and region_rank_ok(r)


func stage_done(cycle: int, r: int, s: int) -> bool:
	return stage_index(cycle, r, s) < progress


## Где передний край: {cycle, r, s}
func frontier() -> Dictionary:
	var per := REGIONS.size() * STAGES
	return {"cycle": progress / per, "r": (progress % per) / STAGES, "s": progress % STAGES}


## Провинция пройдена (побеждён её босс на этом круге)
func region_done(cycle: int, r: int) -> bool:
	return stage_index(cycle, r, STAGES - 1) < progress


static func roman(n: int) -> String:
	var vals := [[1000, "M"], [900, "CM"], [500, "D"], [400, "CD"], [100, "C"], [90, "XC"], [50, "L"], [40, "XL"], [10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]]
	var s := ""
	for v: Array in vals:
		while n >= int(v[0]):
			s += String(v[1])
			n -= int(v[0])
	return s


## Сила врагов боя: [обычных, босса] — рост по глубине круга, подгонка TUNE, множитель круга
static func base_scales(cycle: int, r: int, s: int, tuned := true) -> Array:
	var Dc := (r * STAGES + s) * STAGE_STEP
	var k := 1.0
	if tuned and r < TUNE.size() and s < (TUNE[r] as Array).size():
		k *= float(TUNE[r][s])
	if cycle > 0:
		k *= level_k(target_level(cycle, r, s)) / level_k(target_level(0, r, s)) * pow(CYCLE_EXTRA, cycle - 1)
		if tuned and r < TUNE_C.size() and s < (TUNE_C[r] as Array).size():
			k *= float(TUNE_C[r][s])
	return [pow(STAGE_GROWTH, Dc) * k, pow(BOSS_GROWTH, Dc) * k]


## Во сколько раз боец уровня lvl сильнее бойца 1-го уровня (здоровье +19%, урон +22% за уровень — в среднем ~20%)
static func level_k(lvl: int) -> float:
	return 1.0 + 0.2 * (lvl - 1)


## Уровень бойцов, на котором обычный отряд уверенно побеждает в этом бою (подсказка в окне перед боем):
## в первой провинции — FOREST_T (с 3-го боя нужен 2-й уровень, с 6-го — 3-й), дальше по уровню на провинцию,
## к концу провинции +1, босс +2; каждый круг +CYCLE_CAP
const FOREST_T := [1, 1, 2, 2, 2, 3, 3, 3, 3, 3]


static func target_level(cycle: int, r: int, s: int) -> int:
	if r == 0 and s < FOREST_T.size():
		return int(FOREST_T[s]) + cycle * CYCLE_CAP
	var base := r + 1
	var add := 2 if s == STAGES - 1 else (1 if s >= 4 else 0)
	return base + add + cycle * CYCLE_CAP


## Бои с заданным составом (лес — загадка на выбор отряда: «пращники в кустах — берите лучника, волчья тропа —
## легионеров»): "r-s" → {name — название боя, waves, packs (номера волн, которые выходят тесной кучей — масло
## накроет всех), kite — пращники «в кустах» отходят от мечей (лучники выцеливают их издалека), bite — волки рвут
## стрелков (урон по лучникам ×BITE), squad — кого брать, пока мест три: "bow" — с лучником, "leg" — три легионера,
## "any" — годятся оба (test_legion mode=squads: «не тот» отряд там почти не хуже); без squad — "bow" при kite без bite,
## иначе "leg"; task — задание на третью звезду [вид, число] (STAR_TASKS), tip — совет на карточке}.
## Первый бой леса — учебный: двое разбойников, потом шайка кучей (без масла её трём легионерам не одолеть).
## Состав одинаков на всех кругах — растёт только сила
const FIXED := {
	"0-0": {"name": "Засада на дороге", "waves": [["bandit", "bandit"], ["bandit", "bandit", "bandit", "bandit", "slinger"]], "packs": [1],
		"task": ["oil", 4]},
	"0-1": {"name": "Пращники в кустах", "waves": [["slinger", "slinger", "slinger", "bandit"]], "kite": true, "task": ["fast", 20],
		"tip": "Пращники прячутся в кустах и отбегают от мечей — лучник снимет их издалека."},
	"0-2": {"name": "Волчья тропа", "waves": [["wolf", "wolf", "wolf"], ["wolf", "wolf", "wolf"]], "bite": true, "task": ["hp", 25],
		"tip": "Волки бросаются на лучников и рвут их — идите легионерами."},
	"0-3": {"name": "Шайка у брода", "waves": [["bandit", "bandit", "slinger"], ["bandit", "bandit", "bandit", "bandit", "bandit"]], "packs": [1],
		"squad": "any", "task": ["oil", 4], "tip": "Вторая волна идёт толпой — приберегите масло."},
	"0-4": {"name": "Лесные стрелки", "waves": [["slinger", "slinger", "bandit"], ["bandit", "bandit", "slinger", "slinger"]], "kite": true,
		"task": ["hp", 40], "tip": "Пращники отбегают в кусты — без лучника их долго ловить."},
	"0-5": {"name": "Волки и шайка", "waves": [["wolf", "wolf", "wolf"], ["bandit", "bandit", "bandit", "bandit", "bandit"]], "packs": [1], "bite": true,
		"task": ["oil", 4], "tip": "Сначала волки (лучника загрызут), потом шайка толпой — масло для неё."},
	"0-6": {"name": "Пращники за частоколом", "waves": [["bandit", "slinger", "slinger", "slinger"], ["bandit", "bandit", "slinger", "slinger", "slinger"]],
		"kite": true, "task": ["fast", 60], "tip": "Разбойники прикрывают пращников — лучник достанет их из-за спин."},
	"0-7": {"name": "Волчья ночь", "waves": [["wolf", "wolf", "wolf"], ["bandit", "bandit", "wolf"], ["wolf", "wolf", "wolf", "bandit"]], "bite": true,
		"task": ["hp", 35], "tip": "Три волчьих набега — лучника в отряд не берите."},
	"0-8": {"name": "Большая шайка", "waves": [["slinger", "slinger", "slinger"], ["slinger", "bandit", "slinger", "slinger"], ["bandit", "bandit", "bandit", "bandit", "bandit", "bandit"]],
		"packs": [2], "kite": true, "squad": "any", "task": ["oil", 5], "tip": "Сначала пращники в кустах, в конце — шайка толпой: масло прибережите для неё."},
	"0-9": {"waves": [["bandit", "bandit", "slinger", "slinger"], ["chief", "bandit", "bandit"]], "squad": "any", "task": ["oil", 4],
		"tip": "Атаман трубит в рог и созывает шайку. Масло — когда она сбежится к нему."},
}
## Волки на «волчьей тропе» (bite) рвут стрелков: урон по лучникам во столько раз больше
static var BITE := 3.2
## Стрелки «в кустах» (kite): сколько метров могут отойти от мечей; урон по ним мечом (BUSH) и стрелой или камнем
## (BUSH_SHOT) — во столько раз (прячутся в кустах: мечом их не достать, стрела сверху достанет)
static var KITE := 5.0
static var BUSH := 0.35
static var BUSH_SHOT := 1.8
## Задания на третью звезду: вид → [текст (число — %d), чем меряется в итоге боя]
## oil — масло накрыло N+ врагов разом; fast — победа быстрее N с; hp — у отряда осталось больше N% здоровья
const STAR_TASKS := {"oil": "Масло накрыло %d+ врагов разом", "fast": "Победа быстрее %d с", "hp": "У отряда больше %d%% здоровья"}
## Звёзды боя — биты: победа, все вернулись, задание боя (stars[ключ боя] — лучшее, что набрано, по всем заходам)
const STAR_WIN := 1
const STAR_SAFE := 2
const STAR_TASK := 4
const STAR_ALL := 7
## Первые три звезды в бою — столько Славы; все 30 звёзд провинции — сундук Славы (CHEST × (1 + круг)) и трофей в город
const STAR_GLORY := 2
const CHEST := [15, 20, 25, 30, 35, 40, 45, 50]


## Состав и награда боя — одинаковые при каждом заходе. Возвращает:
## {cycle, r, s, idx, key, D, boss, waves: [[ключ врага, …], …], packs: [номер волны], scale, reward: {money, glory[, rp]},
##  title, name, region, fixed, theme (название боя из FIXED или ""), kite, bite, squad ("bow" | "leg" | "any" | "" — FIXED), task [вид, число], tip}
static func stage(cycle: int, r: int, s: int) -> Dictionary:
	var R: Dictionary = REGIONS[r]
	var idx := stage_index(cycle, r, s)
	var D := idx * STAGE_STEP                       # добыча растёт сквозь круги
	var sk := s * STAGE_STEP
	var rng := RandomNumberGenerator.new()
	rng.seed = (r * STAGES + s) * 7919 + 13         # состав боя одинаков на всех кругах — растёт только сила
	var boss := s == STAGES - 1
	var n_waves := 2 if boss else (1 if s < 3 else (2 if s < 7 else 3))
	var bs := base_scales(cycle, r, s)
	var scale: float = bs[0]
	var boss_scale: float = bs[1]
	var foes: Array = R["foes"]
	var waves := []
	for w in n_waves:
		var n := mini(WAVE_MAX, 2 + int(floor((sk + r * WAVE_R) / WAVE_DIV)) + (1 if w == n_waves - 1 and not boss and s >= 5 else 0))
		var wave := []
		for i in n:
			wave.append(foes[rng.randi() % foes.size()])
		if boss and w == n_waves - 1:
			wave.resize(mini(wave.size(), 2))
			wave.push_front(R["boss"])
		waves.append(wave)
	var packs: Array = []
	var fx: Dictionary = FIXED.get("%d-%d" % [r, s], {})
	if not fx.is_empty():
		waves = (fx["waves"] as Array).duplicate(true)
		packs = (fx.get("packs", []) as Array).duplicate()
	var reward := {"money": roundi(minf(30000.0, 100.0 * pow(1.05, D))),
		"glory": maxi(1, roundi((1 + floor(D / 5.0)) * STAGE_STEP)) + (3 if boss else 0)}
	if boss:
		reward["money"] = int(reward["money"]) * 3
		reward["rp"] = roundi(minf(3000.0, 40.0 * pow(1.04, D)))
	var title: String = R["name"] + ((" " + roman(cycle + 1)) if cycle > 0 else "")
	return {"cycle": cycle, "r": r, "s": s, "idx": idx, "key": stage_key(cycle, r, s), "D": D, "boss": boss, "waves": waves, "packs": packs,
		"scale": scale, "boss_scale": boss_scale, "reward": reward, "title": title, "name": (ENEMIES[R["boss"]]["name"] if boss else "Бой %d" % (s + 1)), "region": R["id"],
		"fixed": not fx.is_empty(), "theme": String(fx.get("name", "")), "kite": bool(fx.get("kite", false)), "bite": bool(fx.get("bite", false)),
		"squad": String(fx.get("squad", ("bow" if bool(fx.get("kite", false)) and not bool(fx.get("bite", false)) else "leg") if not fx.is_empty() else "")),
		"task": (fx["task"] as Array).duplicate() if fx.has("task") else (["hp", 50] if "%d-%d" % [r, s] in TASK_HP else default_task(waves)),
		"tip": String(fx.get("tip", ""))}


## Задание на третью звезду у боя не из FIXED: «масло накрыло 3+ разом», если в бою есть волна от трёх врагов, иначе
## (ранние бои провинций — по двое) — «у отряда больше 50% здоровья»: масло там больше двоих не накроет
static func default_task(waves: Array) -> Array:
	var big := 0
	for w: Array in waves:
		big = maxi(big, w.size())
	return ["oil", 3] if big >= 3 else ["hp", 50]


## Бои не из FIXED, где трое врагов есть, а в кучу под котёл не сбиваются (пращник или лучник стоит поодаль от пары
## бойцов, волки и псы бросаются на стрелков врозь с берсерками и тенями) — задание тоже «здоровье»: масло больше двоих
## не накроет. Мерил test_legion mode=tasks (терпеливый игрок бережёт масло до кучи; он же проверка regress.sh)
const TASK_HP := ["2-2", "2-3", "3-0", "3-1", "3-2", "4-1", "5-0", "5-1", "7-0"]


## То же, что stage() — имя для окна и боя
func stage_info(cycle: int, r: int, s: int) -> Dictionary:
	var st := stage(cycle, r, s)
	st["open"] = stage_open(cycle, r, s)
	st["done"] = stage_done(cycle, r, s)
	st["first"] = st["idx"] == progress
	st["star_mask"] = int(stars.get(st["key"], 0))
	st["stars"] = star_count(int(st["star_mask"]))
	st["power"] = stage_power(st)
	st["recommended"] = recommended_level(st)
	return st


## Следующий бой после этого, если он уже открыт ({} — нет)
func next_stage(st: Dictionary) -> Dictionary:
	var c := int(st["cycle"])
	var r := int(st["r"])
	var s := int(st["s"]) + 1
	if s >= STAGES:
		s = 0
		r += 1
		if r >= REGIONS.size():
			r = 0
			c += 1
	return stage_info(c, r, s) if stage_open(c, r, s) else {}


## Сила врага k в бою st (у боссов — своя, меньшая прибавка). Особенности боя: kite — стрелки отходят от мечей,
## bite — звери, что бросаются на стрелков, рвут их сильнее; summon босса — подмога с силой врагов этого боя.
## Всё это — только у врагов походов (бои с городами собирают бойцов из UNITS — сервер их не знает)
static func foe_stats(st: Dictionary, k: String) -> Dictionary:
	var E: Dictionary = ENEMIES[k]
	var s := enemy_stats(k, float(st["boss_scale"]) if bool(E.get("boss", false)) else float(st["scale"]))
	if bool(st.get("kite", false)) and String(s["shot"]) != "":
		s["kite"] = KITE
		s["bush"] = [BUSH, BUSH_SHOT]
	if bool(st.get("bite", false)) and String(s["prefer"]) == "ranged":
		s["vs"] = {"ranged": BITE}
	if E.has("summon"):
		var sm: Dictionary = E["summon"]
		var foes := []
		for f in sm["foes"]:
			foes.append(enemy_stats(String(f), float(st["scale"])))
		s["summon"] = {"first": float(sm.get("first", sm["every"])), "every": float(sm["every"]), "warn": float(sm["warn"]), "foes": foes}
	return s


static func stage_power(st: Dictionary) -> int:
	var p := 0
	for w: Array in st["waves"]:
		for k in w:
			p += power(foe_stats(st, k))
	return p


## Шансы для окна перед боем: [класс "good" | "mid" | "hard" | "bad", слова].
## est — оценка прогоном боёв (odds_estimate / окно считает её в фоне): «Победа ~45% · с лучником ~85%».
## Без неё — по среднему уровню отряда и рекомендованному (target_level — на нём обычный отряд с умениями побеждает
## в 9 боях из 10, без умений нужен уровень выше); отряд не под бой (пока мест три) — как уровень долой
func odds(st: Dictionary, est := {}) -> Array:
	var sq := squad_stats()
	if sq.is_empty():
		return ["bad", "В отряде никого"]
	if not est.is_empty():
		var p := float(est["cur"])
		var v := "good" if p >= 0.8 else ("mid" if p >= 0.5 else ("hard" if p >= 0.2 else "bad"))
		var words := "Победа ~%d%%" % roundi(p * 100.0)
		if est.has("best") and float(est["best"]) >= p + 0.15:
			words += " · %s ~%d%%" % [best_words(est.get("best_types", [])), roundi(float(est["best"]) * 100.0)]
		return [v, words]
	var lv := 0.0
	for u: Dictionary in sq:
		lv += float(u["level"])
	lv /= sq.size()
	var T := float(recommended_level(st))
	var off := slots() <= SQUAD_BASE and squad_off(st)
	if off:
		T += 1.0
	if lv >= T + 0.5:
		return ["good", "Шансы хорошие"]
	var v := "mid" if lv >= T - 0.5 else ("hard" if lv >= T - 1.5 else "bad")
	if off:
		return [v, "Отряд не под этот бой — «Лучший состав»"]
	return [v, {"mid": "Победа — с умениями", "hard": "Будет очень тяжело", "bad": "Враг сильнее"}[v]]


## Чем «Лучший состав» отличается от нынешнего отряда (для шансов): «с лучником», «без лучника», «лучшим составом»
func best_words(best_types: Array) -> String:
	var cur := []
	for u: Dictionary in squad_stats():
		cur.append(String(u["key"]))
	var bow_b := "archer" in best_types
	var bow_c := "archer" in cur
	if bow_b and not bow_c:
		return "с лучником"
	if bow_c and not bow_b:
		return "тремя легионерами" if best_types.count("legionary") == best_types.size() and best_types.size() == 3 else "без лучника"
	return "лучшим составом"


## Совет по составу для боя st: "" — отряд и так под бой, иначе кого взять (карточка боя, итог поражения)
func squad_hint(st: Dictionary) -> String:
	if squad_stats().is_empty():
		return ""
	if slots() <= SQUAD_BASE and wants_archer(st) and not available("archer") and "archer" in can_get():
		var c = city()
		if c != null and not c.unlocked("range"):
			return "Тут пригодится лучник: изучите «Стрельбище» и поставьте его в городе."
		return "Тут пригодится лучник: поставьте в городе Стрельбище."
	if slots() <= SQUAD_BASE and wants_archer(st) and not available("archer"):
		# лес открыт с «Хутора», а «Стрельбище» — в ряду «Деревни»: скажем, когда лучник появится
		var ra := Defs.research(String(Defs.B["range"].get("unlock", "")))
		if not ra.is_empty() and int(ra["lvl"]) > city_level():
			return "Тут пригодится лучник: «Стрельбище» откроется в исследованиях, когда город станет «%s»." % Defs.LEVELS[int(ra["lvl"])]["name"]
	if not squad_off(st):
		return ""
	var best := auto_squad(st)
	var cur := []
	for u: Dictionary in squad_stats():
		cur.append(String(u["key"]))
	if "archer" in best and not "archer" in cur:
		return "Для этого боя возьмите лучника — «Лучший состав»."
	if "archer" in cur and not "archer" in best and bool(st.get("bite", false)):
		if slots() <= SQUAD_BASE:
			return "Волки загрызут лучника — лучше три легионера («Лучший состав»)."
		return "Волки загрызут лучника — идите без него («Лучший состав»)."
	if "archer" in cur and not "archer" in best and slots() <= SQUAD_BASE:
		return "Тут лучше три легионера: лучника некому прикрыть («Лучший состав»)."
	return "Для этого боя есть состав лучше — «Лучший состав»."


## Оценка шансов прогоном боёв (ODDS_RUNS боёв с «Авто» — как внимательный игрок): задание для odds_run —
## {key, cur: [setup…], best: [setup…] (пусто, если «Лучший состав» тот же), best_types}. Одно и то же для
## одинаковых отряда, уровней и умений (key — для запоминания)
const ODDS_RUNS := 8


func odds_job(st: Dictionary) -> Dictionary:
	var cur := []
	for u: Dictionary in squad_stats():
		cur.append(String(u["key"]))
	var best := auto_squad(st)
	var cs := cur.duplicate()
	var bs := best.duplicate()
	cs.sort()
	bs.sort()
	var same := cs == bs
	return {"key": odds_key(st), "cur": _odds_setups(st, cur), "best": [] if same else _odds_setups(st, best), "best_types": best}


## Ключ оценки шансов: бой, отряд, уровни, умения, бонусы чудес (одинаковый ключ — та же оценка)
func odds_key(st: Dictionary) -> String:
	var cur := []
	for u: Dictionary in squad_stats():
		cur.append(String(u["key"]))
	var key := [st["key"], cur, open_perks(), bonus("atk"), bonus("hp"), auto_squad(st), forge_b(), armory_b(), heal_b()]
	for t in UNIT_IDS:
		key.append(int(levels.get(t, 1)))
	return str(key)


func _odds_setups(st: Dictionary, types: Array) -> Array:
	var sq := []
	for t in types:
		if available(String(t)):
			sq.append(stats(String(t)))
	var waves := []
	for w: Array in st["waves"]:
		var ws := []
		for k in w:
			ws.append(foe_stats(st, k))
		waves.append(ws)
	var out := []
	for i in ODDS_RUNS:
		var s := {"kind": "campaign", "squad": sq, "waves": waves, "perks": open_perks(), "seed": 1000 + i * 7919,
			"packs": (st.get("packs", []) as Array).duplicate()}
		if heal_b() > 0.0:
			s["heal_wave"] = heal_b()
		out.append(s)
	return out


## Посчитать задание odds_job (можно в фоне: только LegionSim и готовые числа) → {cur, best?, best_types}
static func odds_run(job: Dictionary) -> Dictionary:
	var out := {"cur": _win_rate(job["cur"]), "best_types": job["best_types"]}
	if not (job["best"] as Array).is_empty():
		out["best"] = _win_rate(job["best"])
	return out


static func _win_rate(setups: Array) -> float:
	if setups.is_empty() or (setups[0]["squad"] as Array).is_empty():
		return 0.0
	var w := 0
	for s: Dictionary in setups:
		var r := LegionSim.new(s.duplicate(true)).run(true)
		if bool(r["win"]):
			w += 1
	return float(w) / setups.size()


## То же сразу (проверки)
func odds_estimate(st: Dictionary) -> Dictionary:
	return odds_run(odds_job(st))


## Рекомендованный уровень бойцов для боя (подсказка в окне перед боем)
static func recommended_level(st: Dictionary) -> int:
	return target_level(int(st["cycle"]), int(st["r"]), int(st["s"]))


## Награда с учётом первой победы
static func reward_for(st: Dictionary, first: bool) -> Dictionary:
	var k := FIRST_K if first else 1.0
	var out := {}
	for res in st["reward"]:
		out[res] = maxi(1, roundi(float(st["reward"][res]) * k))
	return out


## Провиант на поход (денарии)
func food_cost(st: Dictionary) -> int:
	return roundi(squad_stats().size() * (FOOD["base"] + FOOD["per_d"] * float(st["D"])))


## Можно ли в бой ("" — можно, иначе почему нельзя)
func can_fight(st: Dictionary) -> String:
	if not window_open():
		return lock_text()
	if not region_rank_ok(int(st["r"])):
		return region_lock_text(int(st["r"]))
	if not stage_open(int(st["cycle"]), int(st["r"]), int(st["s"])):
		return "Сначала пройдите предыдущие бои"
	if squad_stats().is_empty():
		return "В отряде нет бойцов — постройте Казармы и поставьте легионеров в отряд."
	if float(food_cost(st)) > city_money():
		return "Не хватает денариев на провиант: нужно %d." % food_cost(st)
	return ""


## Подсказка по составу: кого брать против этих врагов. have — рода войск, которые игрок может взять или построить
## сейчас (пусто — все): не советуем то, чего ещё нет (копейщики и катапульты — после боссов). У боя из FIXED — свой совет
static func counter_tips(st: Dictionary, have := []) -> String:
	if String(st.get("tip", "")) != "":
		var t := String(st["tip"])
		if have.is_empty() or "archer" in have or not t.contains("лучник"):
			return "Совет: " + t.left(1).to_lower() + t.substr(1)
	var tags := {}
	var big := false
	for w: Array in st["waves"]:
		if w.size() >= 4:
			big = true
		for k in w:
			for t in ENEMIES[k]["tags"]:
				tags[t] = true
	var ok := func(u: String) -> bool: return have.is_empty() or u in have
	var advice := []
	if (tags.has("beast") or tags.has("giant")) and ok.call("spearman"):
		advice.append("копейщики сильнее против зверей и великанов")
	# пока мест три, лучник — только против стрелков без волков (wants_archer): совет — по составу боя
	if (tags.has("ranged") or tags.has("swift")) and ok.call("archer") and (int(st.get("r", -1)) != 0 or int(st.get("cycle", 0)) > 0 or wants_archer(st)):
		advice.append("лучники быстро снимают стрелков и волков")
	if (tags.has("armored") or tags.has("giant")) and ok.call("ballista"):
		advice.append("баллиста пробивает броню")
	if tags.has("swarm") or big:
		advice.append("катапульта и «Кипящее масло» хороши против толпы" if ok.call("catapult") else "«Кипящее масло» хорошо против толпы")
	if advice.is_empty():
		return ""
	return "Совет: " + "; ".join(advice.slice(0, 2)) + "."


## Рода войск, которые игрок может взять в отряд, построить или изучить на нынешнем уровне города (для советов);
## открытые победой над боссом — только после неё
func can_get() -> Array:
	var out := []
	var c = city()
	for t in UNIT_IDS:
		var b := String(UNITS[t]["building"])
		var r := Defs.research(String(Defs.B[b].get("unlock", "")))
		if free_mode or available(t) or (c != null and (c.unlocked(b) or (not r.is_empty() and int(r["lvl"]) <= city_level()))):
			out.append(t)
	return out


## Совет по составу для этого игрока: без родов войск, которых ещё нет
func tips(st: Dictionary) -> String:
	return counter_tips(st, can_get())


## Что открыла победа над n-м боссом: умения, место в отряде, военные постройки (строки для окна).
## barracks — уровень Казарм: место открывается, только если они уже нужного уровня (SLOT_BARRACKS, Д10)
static func unlocks_at(n: int, barracks := MAX_LEVEL) -> Array:
	var out := []
	for id in PERK_IDS:
		if int(PERKS[id]["boss"]) == n:
			out.append("умение «%s»" % PERKS[id]["name"])
	var si := SLOT_BOSSES.find(n)
	if si >= 0:
		var need := int(SLOT_BARRACKS[si])
		out.append("ещё одно место в отряде" if barracks >= need else "место в отряде — когда Казармы дойдут до %d уровня" % need)
	for b in BUILDING_UNIT:
		if String(Defs.B.get(b, {}).get("unlock", "")) == "boss%d" % n:
			out.append("%s — %s" % [String(Defs.B[b]["name"]).to_lower(), String(UNITS[BUILDING_UNIT[b]]["many"]).to_lower()])
	return out


# =====================================================================
#   бой
# =====================================================================

## Настройка боя похода для LegionSim.new(setup) (тот же setup — в 3D-бой):
## {kind: "campaign", stage, squad: [статы бойцов], waves: [[статы врагов]], perks: {id: ур.}, seed, food, packs: [номер волны],
##  tutorial: "oil" — учебный первый бой (шайка сбилась в кучу — бой замирает, стрелка на «Кипящее масло»)}.
## packs и tutorial — только в походах: бои с городами (сервер, server/legion_sim.js) их не знают
func make_battle(st: Dictionary, seed_v := -1) -> Dictionary:
	var waves := []
	for w: Array in st["waves"]:
		var ws := []
		for k in w:
			ws.append(foe_stats(st, k))
		waves.append(ws)
	if seed_v < 0:
		seed_v = (int(now() * 1000.0) & 0xffffff) + 1
	var s := {"kind": "campaign", "stage": st, "squad": squad_stats(), "waves": waves, "perks": open_perks(), "seed": seed_v,
		"food": food_cost(st), "packs": (st.get("packs", []) as Array).duplicate()}
	if tutorial_battle(st):
		s["tutorial"] = "oil"
	if heal_b() > 0.0:
		s["heal_wave"] = heal_b()             # Лазарет: между волнами раненые восстанавливают долю здоровья (только походы)
	return s


## Этот бой — учебный: самый первый бой похода, ещё не пройден, и масло в учебном бою ещё не жали
func tutorial_battle(st: Dictionary) -> bool:
	return int(st.get("idx", -1)) == 0 and progress == 0 and not flags.has("tut_oil") and int(perks.get("oil", 0)) > 0


## Кнопка «В бой» окна «Легион»: проверить и попросить 3D-бой (сигнал battle_requested).
## Возвращает setup ({} — нельзя: почему — can_fight(st)). Кто слушает сигнал — тот и крутит бой
func start_battle(st: Dictionary) -> Dictionary:
	if can_fight(st) != "":
		return {}
	var setup := make_battle(st)
	battle_requested.emit(setup)
	return setup


## То же для боя с городом: opp — {name, rating, city_level, snapshot}
func start_pvp_battle(opp: Dictionary) -> Dictionary:
	if pvp_can_attack() != "":
		return {}
	var setup := make_pvp_battle(opp)
	battle_requested.emit(setup)
	return setup


# =====================================================================
#   обучение: 4 шага со стрелкой (окно «Легион» пишет шаг, hud ставит стрелку)
# =====================================================================

const TUT_STEPS := ["barracks", "medal", "fight", "troops"]


## Шаг обучения ("" — нет: Легион ещё закрыт, обучение пройдено или пропущено). Шаг выводится из состояния игры:
## barracks — поставить Казармы, medal — открыть окно «Легион», fight — первый (учебный) бой, troops — улучшить бойцов
func tut_step() -> String:
	if free_mode or String(flags.get("tut", "")) == "done" or not window_open():
		return ""
	if count_type("barracks") == 0:
		return "barracks"
	if not flags.has("seen"):
		return "medal"
	if progress == 0 and not flags.has("tut_fought"):
		return "fight"
	if upg.is_empty() and int(levels.get("legionary", 1)) <= 1:
		return "troops"
	flags["tut"] = "done"                         # все шаги позади
	return ""


## Номер шага 1…4 (0 — нет такого)
static func tut_num(step: String) -> int:
	return TUT_STEPS.find(step) + 1


## «Пропустить обучение»: стрелки, полоса шагов и советы больше не показываются. Учебный бой остаётся (один раз
## замрёт на масле): первый бой посчитан на масло в нужный миг, без него его почти не выиграть.
## flags.tut_oil ставит только нажатие масла в учебном бою (и загрузка сохранения, где первый бой уже позади)
func tut_skip() -> void:
	flags["tut"] = "done"
	changed.emit()


## Звёзды боя за мастерство (биты): STAR_WIN — победа, STAR_SAFE — никто не пал, STAR_TASK — задание боя (task)
static func star_mask(result: Dictionary, st: Dictionary) -> int:
	if not bool(result.get("win", false)):
		return 0
	var m := STAR_WIN
	if int(result.get("alive", 0)) >= int(result.get("total", 1)):
		m |= STAR_SAFE
	if task_done(result, st):
		m |= STAR_TASK
	return m


## Сколько звёзд в наборе битов
static func star_count(mask: int) -> int:
	return (mask & 1) + ((mask >> 1) & 1) + ((mask >> 2) & 1)


## Звёзд за бой (0…3)
static func stars_for(result: Dictionary, st := {}) -> int:
	return star_count(star_mask(result, st))


## Задание боя на третью звезду: [вид, число] (без него — default_task по волнам боя)
static func task_of(st: Dictionary) -> Array:
	var t: Array = st.get("task", [])
	return t if t.size() == 2 and STAR_TASKS.has(String(t[0])) else default_task(st.get("waves", []))


static func task_done(result: Dictionary, st: Dictionary) -> bool:
	var t := task_of(st)
	var n := int(t[1])
	match String(t[0]):
		"fast":
			return float(result.get("time", 999.0)) <= float(n)
		"hp":
			return float(result.get("hp_left", 0.0)) * 100.0 > float(n)
	return int(result.get("oil_best", 0)) >= n


## Условия трёх звёзд боя — строки для карточки и итога
static func star_texts(st: Dictionary) -> Array:
	var t := task_of(st)
	return ["Победа", "Все вернулись из боя", STAR_TASKS[String(t[0])] % int(t[1])]


## Почему не далась звезда i (1 — все вернулись, 2 — задание) — для экрана итога
static func star_miss(i: int, result: Dictionary, st: Dictionary) -> String:
	if i == 1:
		var fell := int(result.get("total", 0)) - int(result.get("alive", 0))
		return "пали %d из %d" % [fell, int(result.get("total", 0))]
	var t := task_of(st)
	match String(t[0]):
		"fast":
			return "бой шёл %d с" % ceili(float(result.get("time", 0.0)))
		"hp":
			return "осталось %d%%" % floori(float(result.get("hp_left", 0.0)) * 100.0)
	var n := int(result.get("oil_best", 0))
	return "масло не жали" if int(result.get("perks_used", 0)) == 0 and n == 0 else "лучшее — %d разом" % n


## Звёзды провинции (cycle, r): сколько набрано из 30
func region_stars(cycle: int, r: int) -> int:
	var n := 0
	for s in STAGES:
		n += star_count(int(stars.get(stage_key(cycle, r, s), 0)))
	return n


## Трофей провинции уже в городе (украшение Defs.B с unlock «trophy:<id>»)
func has_trophy(id: String) -> bool:
	return trophies.has(id)


## Итог боя похода: провиант, звёзды, добыча, рейтинг, открытие следующего боя и наград за боссов.
## result — LegionSim.result ({win, alive, total, timeout, time, hp_left, oil_best…}); возвращает его, дополнив:
## {stars (за этот бой), star_mask, star_best (лучшее в этом бою за все заходы), star_glory (первые 3 звезды — Слава),
##  chest ({} или {glory, trophy, region} — все 30 звёзд провинции), first, reward ({} при поражении), rating,
##  boss_beaten, unlocks: [строки], next: stage_info или {}}
func apply_result(setup: Dictionary, result: Dictionary) -> Dictionary:
	var st: Dictionary = setup["stage"]
	var c = city()
	if c != null:
		c.money -= float(setup.get("food", 0))
		if c.has_method("flow"):
			c.flow("legion", -float(setup.get("food", 0)))
	var first := bool(result.get("win", false)) and int(st["idx"]) == progress
	var out := result.duplicate()
	out["first"] = first
	out["reward"] = {}
	out["rating"] = 0
	out["stars"] = 0
	out["star_mask"] = 0
	out["star_best"] = star_count(int(stars.get(st["key"], 0)))
	out["star_glory"] = 0
	out["chest"] = {}
	out["unlocks"] = []
	out["boss_beaten"] = false
	if bool(result.get("win", false)):
		var mask := star_mask(result, st)
		var old := int(stars.get(st["key"], 0))
		stars[st["key"]] = old | mask
		out["stars"] = star_count(mask)
		out["star_mask"] = mask
		out["star_best"] = star_count(old | mask)
		var reward := reward_for(st, first)
		# первые три звезды в этом бою — немного Славы
		if (old | mask) == STAR_ALL and old != STAR_ALL:
			reward["glory"] = int(reward.get("glory", 0)) + STAR_GLORY
			out["star_glory"] = STAR_GLORY
		out["money_lost"] = _give(reward)      # казна полна — сколько денариев не уместилось (окно итога скажет честно)
		out["reward"] = reward
		out["chest"] = _chest(int(st["cycle"]), int(st["r"]))
		wins += 1
		var gain: int = (RATING["boss"] if st["boss"] else RATING["first"]) if first else RATING["repeat"]
		rating += gain
		out["rating"] = gain
		if first:
			progress += 1
			if st["boss"]:
				var n := bosses()
				for id in PERK_IDS:
					if int(PERKS[id]["boss"]) == n and int(perks.get(id, 0)) == 0:
						perks[id] = 1
				out["unlocks"] = unlocks_at(n, _slot_barracks())
				out["boss_beaten"] = true
				flags["turn_page"] = true       # карта перелистнётся на следующую провинцию
				if c != null and c.has_method("_event"):
					var u: Array = out["unlocks"]
					c._event("Легион победил: %s!%s" % [st["name"], (" Открыто: " + ", ".join(u) + ".") if not u.is_empty() else ""], "legion")
		out["next"] = next_stage(st)
	if c != null:
		c.changed.emit()
	changed.emit()
	return out


## Все 30 звёзд провинции (cycle, r) — один раз сундук Славы и (на первом таком круге) трофей в город.
## Возвращает {} или {glory, trophy (тип украшения или ""), region}
func _chest(cycle: int, r: int) -> Dictionary:
	var ck := "%d-%d" % [cycle, r]
	if chests.has(ck) or region_stars(cycle, r) < STAGES * 3:
		return {}
	chests[ck] = true
	var R: Dictionary = REGIONS[r]
	var g := int(CHEST[r % CHEST.size()]) * (1 + cycle)
	glory += g
	var tr := String(R.get("trophy", ""))
	if tr != "" and not trophies.has(String(R["id"])):
		trophies[String(R["id"])] = true
	else:
		tr = ""
	var c = city()
	if c != null and c.has_method("_event"):
		c._event("Все 30 звёзд: %s! Сундук Славы +%d%s" % [R["name"], g,
			(". Трофей «%s» — в разделе «Украшения»" % Defs.B[tr]["name"]) if tr != "" and Defs.B.has(tr) else ""], "laurels")
	return {"glory": g, "trophy": tr, "region": String(R["name"])}


## Выдать награду; вернёт, сколько денариев не уместилось в казну (полна — предел остаётся, но говорим честно)
func _give(reward: Dictionary) -> int:
	var c = city()
	var lost := 0
	for k in reward:
		var v := float(reward[k])
		match k:
			"glory":
				glory += v
			"money":
				if c != null:
					lost = maxi(0, roundi(v - maxf(0.0, c.money_cap() - c.money)))
					var m0: float = c.money
					c.money = minf(c.money_cap(), c.money + v)
					if c.has_method("flow"):
						c.flow("legion", c.money - m0)
			"rp":
				if c != null:
					c.rp = maxf(c.rp, minf(c.rp_cap(), c.rp + v))   # сверх полок (возврат очков) не срезаем — как в sim_day
	return lost


# =====================================================================
#   чудеса
# =====================================================================

static func wonder(id: String) -> Dictionary:
	for w: Dictionary in WONDERS:
		if w["id"] == id:
			return w
	return {}


static func wonder_name(w: Dictionary) -> String:
	if w.has("building"):
		return String(Defs.B[w["building"]]["name"])
	return String(w["name"])


## Рейтинг, которым открывается чудо (походов или побед над городами)
func wonder_rating_now(w: Dictionary) -> int:
	return pvp_rating if bool(w.get("pvp", false)) else rating


## "built" — возведено; "open" — можно строить; "locked" — не хватает рейтинга
func wonder_state(id: String) -> String:
	var w := wonder(id)
	if w.is_empty():
		return "locked"
	if wonder_built(w):
		return "built"
	return "open" if wonder_rating_now(w) >= int(w["rating"]) else "locked"


## Цена чуда: {money, glory}
func wonder_cost(id: String) -> Dictionary:
	var w := wonder(id)
	if w.has("building"):
		return {"money": int(Defs.B[w["building"]]["cost"]), "glory": int(w["glory"])}
	return {"money": int(w.get("money", 0)), "glory": int(w["glory"])}


## Постройку-чудо можно ставить в городе: открыта рейтингом (City.unlocked спрашивает сюда)
func wonder_unlocks(type: String) -> bool:
	for w: Dictionary in WONDERS:
		if String(w.get("building", "")) == type and rating >= int(w["rating"]):
			return true
	return false


## Можно ли возвести чудо ("" — можно). Для чудес-построек — ставит игрок (game.set_tool(building)),
## Слава спишется при постановке (City.place)
func can_build_wonder(id: String) -> String:
	var w := wonder(id)
	if w.is_empty():
		return "Нет такого чуда"
	var st := wonder_state(id)
	if st == "built":
		return "Уже построено"
	if st == "locked":
		return "Нужен рейтинг %s %d" % ["побед над городами" if bool(w.get("pvp", false)) else "походов", int(w["rating"])]
	return _afford_text(wonder_cost(id))


## Возвести чудо без постройки (кнопка в окне). Чудеса-постройки ставятся в городе — тут false
func build_wonder(id: String) -> bool:
	var w := wonder(id)
	if w.has("building") or can_build_wonder(id) != "":
		return false
	_pay(wonder_cost(id))
	built[id] = true
	var c = city()
	if c != null:
		if c.has_method("_event"):
			c._event("Возведено чудо света: %s! %s" % [wonder_name(w), w["bonus"]], "laurels")
		c.compute()
		c.changed.emit()
	changed.emit()
	return true


# =====================================================================
#   город: счастье, Слава по часам, триумф
# =====================================================================

## Сколько процентов счастья всем домам дают чудеса-без-постройки и триумф (City.compute)
func city_happy() -> int:
	var h := 0
	for w: Dictionary in WONDERS:
		if not w.has("building") and built.has(w["id"]):
			h += int(w.get("happy", 0))
	if triumph_left > 0:
		h += int(TRIUMPH["happy"])
	return h


## Раз в игровой час (City.sim_day): таймеры улучшений, Слава от чудес, триумф. Возвращает события [[текст, значок, тихо?]]
## (улучшение здания — только в колокольчик: на карте здание и так меняет облик с облачком)
func on_hour() -> Array:
	var out := []
	for m in tick():
		out.append([m, "legion", true])
	var gd := 0.0
	for w: Dictionary in WONDERS:
		if float(w.get("glory_day", 0.0)) > 0.0 and wonder_built(w):
			gd += float(w["glory_day"])
	if gd > 0.0:
		glory_acc += gd / 24.0
		if glory_acc >= 1.0:
			var g := floorf(glory_acc)
			glory += g
			glory_acc -= g
	if triumph_left > 0:
		triumph_left -= 1
		if triumph_left == 0:
			out.append(["Триумф окончен: город возвращается к будням", "laurels"])
			var c = city()
			if c != null:
				c.compute()
	return out


func can_triumph() -> String:
	if not window_open():
		return lock_text()
	if triumph_left > 0:
		return "Триумф уже идёт"
	if glory + 0.001 < float(TRIUMPH["glory"]):
		return "Нужно %d Славы" % TRIUMPH["glory"]
	return ""


## Триумф: за Славу весь город празднует — счастье всех домов выше
func triumph() -> bool:
	if can_triumph() != "":
		return false
	glory -= float(TRIUMPH["glory"])
	triumph_left = int(TRIUMPH["hours"])
	var c = city()
	if c != null:
		if c.has_method("_event"):
			c._event("Триумф! Город празднует %d дня: счастье всех домов +%d%%" % [int(TRIUMPH["hours"]) / 24, TRIUMPH["happy"]], "laurels")
		c.compute()
		c.changed.emit()
	changed.emit()
	return true


# =====================================================================
#   бои с другими городами
# =====================================================================

## Сколько атак в запасе сейчас (заряды копятся по настоящим часам)
func pvp_charges_now() -> int:
	_pvp_regen()
	return pvp_charges


## Секунд до следующего заряда (0 — запас полон)
func pvp_next_charge() -> float:
	_pvp_regen()
	if pvp_charges >= int(PVP["charges"]):
		return 0.0
	return maxf(0.0, pvp_charge_t + float(PVP["regen"]) / maxf(0.001, time_k) - now())


func _pvp_regen() -> void:
	var regen := float(PVP["regen"]) / maxf(0.001, time_k)
	var t := now()
	if pvp_charges >= int(PVP["charges"]):
		pvp_charge_t = t
		return
	if pvp_charge_t <= 0.0:
		pvp_charge_t = t
	var n := int(floor((t - pvp_charge_t) / regen))
	if n > 0:
		pvp_charges = mini(int(PVP["charges"]), pvp_charges + n)
		pvp_charge_t += n * regen
		if pvp_charges >= int(PVP["charges"]):
			pvp_charge_t = t


## Бои с городами открыты: Легион собран и город уже «Посёлок» (PVP_MIN_LEVEL)
func pvp_open() -> bool:
	return window_open() and pvp_rank_text() == ""


## Почему бои с городами ещё закрыты по уровню города ("" — открыты)
func pvp_rank_text() -> String:
	if free_mode or city_level() >= PVP_MIN_LEVEL:
		return ""
	return "Бои с городами откроются, когда город станет «%s»." % Defs.LEVELS[PVP_MIN_LEVEL]["name"]


func pvp_can_attack() -> String:
	if not window_open():
		return lock_text()
	if pvp_rank_text() != "":
		return pvp_rank_text()
	if squad_stats().is_empty():
		return "В отряде нет бойцов"
	if pvp_charges_now() <= 0:
		return "Отряд отдыхает: следующая атака через %s" % fmt_duration(pvp_next_charge())
	return ""


## Снимок отряда обороны для сервера (его увидят нападающие). Только числа — без имён и денег
func defense_snapshot() -> Dictionary:
	var sq := []
	var src: Array = defense if not defense.is_empty() else squad
	for i in mini(slots(), src.size()):
		var t: String = src[i]
		if t != "" and UNITS.has(t) and available(t):
			sq.append({"type": t, "level": int(levels.get(t, 1))})
	return {"v": 1, "squad": sq, "perks": open_perks(), "atk_b": pvp_bonus("atk"), "hp_b": pvp_bonus("hp"),
		"power": squad_power("defense"), "rating": pvp_rating, "city_level": city_level()}


## Бонус урона или здоровья ("atk" | "hp"), который знает сервер боёв с городами: чудеса (и Кузница — когда PVP_MODS)
func pvp_bonus(key: String) -> float:
	return bonus(key) + (forge_b() if PVP_MODS else 0.0)


## Сила снимка соперника (для подбора и окна)
static func snapshot_power(snap: Dictionary) -> int:
	var p := 0
	for e: Dictionary in snap.get("squad", []):
		if UNITS.has(String(e.get("type", ""))):
			p += power(unit_stats(String(e["type"]), clampi(int(e.get("level", 1)), 1, MAX_LEVEL), float(snap.get("atk_b", 0.0)), float(snap.get("hp_b", 0.0))))
	return p


## Настройка боя с городом: отряд соперника стоит строем справа (одна «волна», не выходит из-за края),
## его умения жмёт сам бой (enemy_auto). opp — {name, rating, city_level, snapshot[, attack]}.
## attack — наш отряд, каким его проверил и запомнил сервер (LegionNet.pvp_attack): воюем ровно им — сервер
## повторит бой с тем же зерном и нашими нажатиями (server/legion_sim.js) и засчитает итог повтора
func make_pvp_battle(opp: Dictionary, seed_v := -1) -> Dictionary:
	var snap: Dictionary = opp.get("snapshot", {})
	var foes := snapshot_stats(snap)
	var ep := snapshot_perks(snap)
	var att = opp.get("attack")
	var mine: Array = snapshot_stats(att) if att is Dictionary else squad_stats("pvp")
	var ap: Dictionary = snapshot_perks(att) if att is Dictionary else open_perks()
	if seed_v < 0:
		seed_v = int(opp.get("seed", -1))           # зерно боя выдал сервер (LegionNet.pvp_attack)
	if seed_v < 0:
		seed_v = (int(now() * 1000.0) & 0xffffff) + 1
	return {"kind": "pvp", "opponent": opp, "squad": mine, "waves": [foes], "perks": ap, "enemy_perks": ep,
		"enemy_auto": true, "enemy_formation": true, "seed": seed_v}


## Бойцы снимка отряда (свой отряд с сервера или отряд обороны соперника) — так же считает server/legion_sim.js
static func snapshot_stats(snap: Dictionary) -> Array:
	var out := []
	for e in snap.get("squad", []):
		if not (e is Dictionary):
			continue
		var t := String(e.get("type", ""))
		if UNITS.has(t):
			out.append(unit_stats(t, clampi(int(e.get("level", 1)), 1, MAX_LEVEL), clampf(float(snap.get("atk_b", 0.0)), 0.0, 0.6), clampf(float(snap.get("hp_b", 0.0)), 0.0, 0.6)))
	return out


static func snapshot_perks(snap: Dictionary) -> Dictionary:
	var out := {}
	var ps = snap.get("perks", {})
	if ps is Dictionary:
		for p in ps:
			if PERKS.has(p):
				out[p] = clampi(int(ps[p]), 0, PERK_MAX)
	return out


## Изменение рейтинга побед за бой с соперником рейтинга opp
func pvp_delta(win: bool, opp: int) -> int:
	if win:
		return clampi(int(PVP["win_base"]) + (opp - pvp_rating) / 25, int(PVP["win_min"]), int(PVP["win_max"]))
	return -clampi(int(PVP["loss_base"]) + (pvp_rating - opp) / 50, int(PVP["loss_min"]), int(PVP["loss_max"]))


## Итог боя с городом: заряд, рейтинг, лёгкая добыча (денарии и Слава — ни у кого не отнимаются).
## Если бой выдал сервер (LegionNet), в opp есть stakes {win, loss} и reward {money, glory} — берём их, чтобы
## экран итога показал ровно то, что засчитает сервер. Возвращает result, дополнив {delta, reward}
func apply_pvp_result(setup: Dictionary, result: Dictionary) -> Dictionary:
	var opp: Dictionary = setup.get("opponent", {})
	var win := bool(result.get("win", false))
	_pvp_regen()
	if pvp_charges >= int(PVP["charges"]):
		pvp_charge_t = now()
	pvp_charges = maxi(0, pvp_charges - 1)
	var d := pvp_delta(win, int(opp.get("rating", 0)))
	var stakes: Dictionary = opp.get("stakes", {})
	if stakes.has("win" if win else "loss"):
		d = int(stakes["win" if win else "loss"])
	pvp_rating = maxi(0, pvp_rating + d)
	var reward := {}
	var lost := 0
	if win:
		pvp_wins += 1
		var op := snapshot_power(opp.get("snapshot", {}))
		reward = {"money": roundi(float(PVP["loot_base"]) + float(PVP["loot_money"]) * op), "glory": int(PVP["glory"]) + int(opp.get("city_level", 0)) / 2}
		var sr: Dictionary = opp.get("reward", {})
		if sr.has("money"):
			reward = {"money": int(sr["money"]), "glory": int(sr.get("glory", 0))}
		lost = _give(reward)
	else:
		pvp_losses += 1
	pvp_log.push_front({"t": now(), "name": String(opp.get("name", "?")), "win": win, "delta": d, "money": int(reward.get("money", 0)), "attack": true,
		"battle": String(opp.get("battle", ""))})
	if pvp_log.size() > 20:
		pvp_log.resize(20)
	var out := result.duplicate()
	out["delta"] = d
	out["reward"] = reward
	out["money_lost"] = lost
	var c = city()
	if c != null:
		c.changed.emit()
	changed.emit()
	return out


## Сервер сообщил, что на наш город нападали: [{name, win (нападавший победил), delta (наш рейтинг), t[, glory]}];
## glory — Слава за отбитый натиск (или минус, если сервер настроен отнимать Славу у проигравшей обороны)
func pvp_defense(entries: Array) -> void:
	for e: Dictionary in entries:
		pvp_rating = maxi(0, pvp_rating + int(e.get("delta", 0)))
		var gl := float(e.get("glory", 0.0))
		glory = maxf(0.0, glory + gl)
		pvp_log.push_front({"t": float(e.get("t", now())), "name": String(e.get("name", "?")), "win": not bool(e.get("win", false)),
			"delta": int(e.get("delta", 0)), "money": 0, "glory": int(gl), "attack": false})
	if pvp_log.size() > 20:
		pvp_log.resize(20)
	changed.emit()


# =====================================================================
#   картинки
# =====================================================================

## Где картинка: {file: "res://…/36.png", grid: [кол., строк], i: номер на листе}. Лист может ещё не прийти —
## окно проверяет ResourceLoader.exists(file) и рисует заглушку
static func art(kind: String, id: String) -> Dictionary:
	var sheet := ""
	var i := 0
	match kind:
		"unit":
			sheet = "35"
			i = int(UNITS[id]["art"])
		"enemy":
			var E: Dictionary = ENEMIES[id]
			sheet = "37" if bool(E.get("boss", false)) else "36"
			i = int(E["art"])
		"perk":
			sheet = "38"
			i = int(PERKS[id]["art"])
		"wonder":
			sheet = "41"
			i = int(wonder(id)["art"])
		"map":
			for R: Dictionary in REGIONS:
				if R["id"] == id:
					return {"file": ART_DIR + String(R["map"]) + ".png", "grid": [1, 1], "i": 0}
	return {"file": ART_DIR + sheet + ".png", "grid": ART_SHEETS.get(sheet, [1, 1]), "i": i}


## Кусок листа картинок (AtlasTexture) или null, если файла ещё нет
static func art_texture(kind: String, id: String) -> Texture2D:
	var a := art(kind, id)
	if not ResourceLoader.exists(a["file"]):
		a["file"] = String(a["file"]).get_basename() + ".jpg"       # карты провинций лежат в .jpg (.work/py/legion_art.py)
		if not ResourceLoader.exists(a["file"]):
			return null
	var tex := load(a["file"]) as Texture2D
	if tex == null:
		return null
	var g: Array = a["grid"]
	if int(g[0]) * int(g[1]) <= 1:
		return tex
	var w := tex.get_width() / int(g[0])
	var h := tex.get_height() / int(g[1])
	var at := AtlasTexture.new()
	at.atlas = tex
	var i := int(a["i"])
	at.region = Rect2((i % int(g[0])) * w, (i / int(g[0])) * h, w, h)
	return at


# =====================================================================
#   слова
# =====================================================================

static func fmt_duration(sec: float) -> String:
	var s := maxi(0, ceili(sec))
	if s < 60:
		return "%d с" % s
	if s < 3600:
		return "%d мин%s" % [s / 60, (" %d с" % (s % 60)) if s % 60 != 0 and s < 600 else ""]
	if s < 86400:
		return "%d ч%s" % [s / 3600, (" %d мин" % (s % 3600 / 60)) if s % 3600 >= 60 else ""]
	return "%d сут%s" % [s / 86400, (" %d ч" % (s % 86400 / 3600)) if s % 86400 >= 3600 else ""]


# =====================================================================
#   сохранение
# =====================================================================

## v2 (этап 3b): stars — биты звёзд за мастерство (в v1 — число звёзд по выжившим), chests, trophies.
## v3 (Д10): blevels — уровни Кузницы, Лазарета, Склада оружия; levels — по-прежнему уровни родов войск (= их зданий)
func to_dict() -> Dictionary:
	return {"v": 3, "levels": levels, "blevels": blevels, "upg": upg, "squad": squad, "defense": defense, "perks": perks, "stars": stars,
		"progress": progress, "wins": wins, "rating": rating, "glory": glory, "pvp_rating": pvp_rating, "pvp_charges": pvp_charges,
		"pvp_charge_t": pvp_charge_t, "pvp_wins": pvp_wins, "pvp_losses": pvp_losses, "pvp_log": pvp_log, "built": built.keys(),
		"triumph_left": triumph_left, "glory_acc": glory_acc, "flags": flags, "chests": chests.keys(), "trophies": trophies.keys()}


func from_dict(d: Dictionary) -> void:
	levels = {}
	for k in d.get("levels", {}):
		if UNITS.has(k):
			levels[k] = clampi(int(d["levels"][k]), 1, MAX_LEVEL)
	blevels = {}
	for k in d.get("blevels", {}):
		if SUPPORT.has(k):
			blevels[k] = clampi(int(d["blevels"][k]), 1, max_of(k))
	upg = {}
	for k in d.get("upg", {}):
		var u: Dictionary = d["upg"][k]
		if UNITS.has(k) or SUPPORT.has(k):
			upg[k] = {"to": int(u.get("to", 2)), "end": float(u.get("end", 0.0)), "total": float(u.get("total", 1.0))}
	squad = []
	for t in d.get("squad", ["legionary", "legionary", "legionary"]):
		squad.append(String(t) if UNITS.has(String(t)) else "")
	defense = []
	for t in d.get("defense", []):
		defense.append(String(t) if UNITS.has(String(t)) else "")
	perks = {}
	for p in d.get("perks", {}):
		if PERKS.has(p):
			perks[p] = clampi(int(d["perks"][p]), 0, PERK_MAX)
	stars = {}
	var v1 := int(d.get("v", 1)) < 2
	for k in d.get("stars", {}):
		var n := int(d["stars"][k])
		# старые звёзды (v1) — число по выжившим: честно переносим, что известно — победа и «все вернулись» (3 = все живы);
		# задание боя тогда не считалось — его звезду надо добыть заново
		if v1:
			n = (STAR_WIN | (STAR_SAFE if n >= 3 else 0)) if n > 0 else 0
		stars[String(k)] = n & STAR_ALL
	chests = {}
	for k in d.get("chests", []):
		chests[String(k)] = true
	trophies = {}
	for k in d.get("trophies", []):
		trophies[String(k)] = true
	progress = int(d.get("progress", 0))
	wins = int(d.get("wins", 0))
	rating = int(d.get("rating", 0))
	glory = float(d.get("glory", 0.0))
	pvp_rating = int(d.get("pvp_rating", 0))
	pvp_charges = int(d.get("pvp_charges", PVP["charges"]))
	pvp_charge_t = float(d.get("pvp_charge_t", 0.0))
	pvp_wins = int(d.get("pvp_wins", 0))
	pvp_losses = int(d.get("pvp_losses", 0))
	pvp_log = d.get("pvp_log", [])
	built = {}
	for k in d.get("built", []):
		built[String(k)] = true
	triumph_left = int(d.get("triumph_left", 0))
	glory_acc = float(d.get("glory_acc", 0.0))
	flags = d.get("flags", {})
	_ensure()
	# умения за уже побеждённых боссов (и масло — с первого дня: старым сохранениям тоже)
	for p in PERK_IDS:
		if bosses() >= int(PERKS[p]["boss"]) and int(perks[p]) == 0:
			perks[p] = 1
	# старое сохранение, где уже воевали: обучение и учебный бой позади
	if progress > 0 and not flags.has("tut"):
		flags["tut"] = "done"
		flags["tut_oil"] = true
	if int(d.get("v", 1)) < 3:
		_migrate_d10()
	changed.emit()


## Старое сохранение (до зданий Легиона, Д10): уровни войск уже стали уровнями их зданий (levels — то же число;
## здания нет — уровень «в запасе»); умения дают уровни «в запасе» новым зданиям: Перевязка — Лазарету, Черепаха — Складу
## оружия, Залп и Боевой рог — Кузнице (сами умения не меняются). Места в отряде, открытые до Д10, не отнимаются
## (новые места просят ещё и Казармы нужного уровня). Идущие улучшения переносятся как есть.
## flags.d10_new — советник один раз расскажет о зданиях Легиона (LegionUi)
func _migrate_d10() -> void:
	var kept := SQUAD_BASE
	for b in SLOT_BOSSES:
		if bosses() >= int(b):
			kept += 1
	if kept > SQUAD_BASE:
		flags["slots0"] = kept
	var from := {"infirmary": ["bandage"], "armory": ["testudo"], "forge": ["volley", "horn"]}
	for k in from:
		var l := 1
		for p in from[k]:
			l = maxi(l, int(perks.get(p, 0)))
		blevels[k] = clampi(maxi(int(blevels.get(k, 1)), l), 1, mini(max_of(k), cap_of(k)))   # не выше предела города (уровень города уже загружен)
	if not flags.is_empty() or progress > 0:
		flags["d10_new"] = true
