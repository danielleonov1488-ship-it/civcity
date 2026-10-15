class_name StoryDefs
extends RefCounted
## «Истории горожан» — данные (как Defs для построек). Историю ведёт узел Stories (scripts/stories.gd),
## ролики — CineKit (полосы, камера) и StoryUi (облачко с портретом, журнал, золотая строка в «Просьбах»).
##
## Правила (план этапа 4, решение владельца Д7):
##  - история только по желанию игрока: свиток над домом просящего и золотая строка в «Просьбах горожан»;
##    ролик — только по щелчку; «Отложить» — снова через сутки (LATER_H);
##  - одна история за раз; первая — через FIRST_H игровых часов после обучения, дальше — GAP_H между историями;
##  - по рангу (lvl) и числу жителей (pop); предлагаем, только если её правда можно пройти (Stories.can_offer);
##  - награды — не деньги: украшения, счастье (временное или рядом), очки исследований, Слава.
##
## Схема истории:
##  id, title, icon (значок медальона), lvl, pop, cast {роль: {cls, child, female}} — кого просить (дом по классу),
##  who / role — имя и подпись в облачке («Луций Корнелий», «сын семьи Корнелиев»),
##  ask — строка просьбы (колокольчик и золотая строка), steps — шаги, reward — награда, line — строка в счастье дома.
##  Шаг: {id, cine?: [такты ролика], goal?: [вид, …], text?, hints?: [[часов, текст]], giveup?: текст}.
##  Шаг без цели — ролик; шаг с целью — ждём, пока игрок её выполнит.
##  Виды целей (Stories.progress):
##   ["find", что, {rmin, rmax, ring, ring2, shrink_h, paw_h, giveup_h, hide: [виды украшений], fur, name}] — найти щелчком;
##   ["around", R, {вид: n, …}] — рядом с домом просящего (в R м) стоят такие постройки;
##   ["built_after", тип, R] — построен новый (после начала шага) дом/постройка этого типа в R м;
##   ["score", вид, R, [пороги]] — сколько таких рядом: бронза/серебро/золото; кнопка «Готово» с первого порога;
##   ["choice", [[подпись, значение], …]] — выбор в золотой строке;
##   ["pay", "money"|"glory", n] — кнопка «Заплатить»;
##   ["wait", часов]; ["p", [вид, …], n] — как у просьб горожан (City.progress_of);
##   ["flag", ключ, {значение: цель, …}] — цель по прежнему выбору (свадьба: сад или таверна).
##  Такты ролика (Stories._beat_start):
##   ["actor", роль, "door"|"near_cat"] — человек появляется; ["fly", роль|"cat", "talk"] — камера к нему;
##   ["anim", роль, движение]; ["walk", роль, "cat", движение]; ["say", роль|"cat", текст];
##   ["choice", роль, текст, [[подпись, значение, ответ], …]]; ["cat", "sit"|"pet"|"sleep"]; ["fx", "hearts"|"puff", роль|"cat"];
##   ["wait", сек]; ["reward"] — подпись внизу: что дала история.
##  Награда: unlock (украшение «s_…»), happy_home [%, ч], happy_area [%, R, ч], happy_all [%, ч],
##   monument [%, R] (навсегда, рядом; % может быть списком по порогам score), rp, glory, cats.
##  В текстах: {kid} — имя ребёнка, {nomen} — родовое имя («Корнелий»), {fam_gen} — «Корнелиев», {cat} — имя кошки.

const FIRST_H := 4                     # первая история — через 4 игровых часа после конца обучения
const GAP_H := 16                      # от конца прошлой истории до новой просьбы
const LATER_H := 24                    # «Отложить» — снова через сутки

## Имена мальчиков (по семье — всегда одно и то же)
const BOYS := ["Луций", "Гай", "Марк", "Тит", "Квинт", "Публий", "Авл", "Децим", "Секст", "Гней"]

const STORIES := [
	{"id": "cat", "title": "Где Мурка?", "icon": "cat", "lvl": 1, "pop": 20,
		"cast": {"kid": {"cls": "plebs", "child": true, "female": false}},
		"who": "{kid} {nomen}", "role": "сын семьи {fam_gen}",
		"ask": "Маленький {kid} из семьи {fam_gen} чем-то расстроен — над их домом свиток с просьбой.",
		"steps": [
			{"id": "ask", "cine": [
				["actor", "kid", "door"],
				["fly", "kid", "talk"],
				["anim", "kid", "Look_Around"],
				["say", "kid", "Градоначальник! Беда — пропала моя Мурка. Рыжая-рыжая, а грудка белая, как молоко."],
				["anim", "kid", "Idle_Talking"],
				["say", "kid", "Утром прогрохотала повозка, Мурка испугалась и убежала. Мама говорит, кошки сами возвращаются… а она всё не идёт."],
				["choice", "kid", "Поможешь её найти? Она где-то близко — я слышал, как она мяукает!",
					[["Найдём её вместе!", "go", "Ура! Слушай, где мяукает, и заглядывай за сено, корзины и кусты — она любит тёплые уголки."],
					["Чуть позже, малыш", "later", "Ладно… Я пока сам поищу у колодца. Приходи потом, хорошо?"]]]]},
			{"id": "find", "text": "Найдите рыжую Мурку: она прячется недалеко от дома {fam_gen}. Прислушайтесь к «мяу» и щёлкните по кошке.",
				"goal": ["find", "cat", {"rmin": 12.0, "rmax": 40.0, "ring": 22.0, "ring2": 12.0, "shrink_h": 3, "paw_h": 6, "giveup_h": 12,
					"hide": ["hay", "cart", "amphorae", "goods", "bush", "well", "tree", "cypress", "planter", "fence", "palm"], "fur": 0, "name": "Мурка"}],
				"hints": [[3, "{kid}: «Она любит тёплые уголки — у сена, корзин и кустов». Место поисков стало теснее."],
					[6, "Над Муркой появился след лапки — щёлкните по нему или по кошке."]],
				"giveup": "{kid} сам нашёл Мурку — она дремала в укромном уголке. Кошка снова дома."},
			{"id": "home", "cine": [
				["fly", "cat", "talk"],
				["cat", "sit"],
				["actor", "kid", "near_cat"],
				["say", "cat", "Мяу?"],
				["walk", "kid", "cat", "Jog_Fwd"],
				["anim", "kid", "Crouch_Idle"],
				["cat", "pet"],
				["fx", "hearts", "cat"],
				["say", "kid", "Мурка! Нашлась! Больше никогда-никогда не убегай, слышишь?"],
				["say", "cat", "Мрр-мяу!"],
				["reward"],
				["say", "kid", "Спасибо, градоначальник! Мама сплетёт Мурке новую корзинку — и городу сплетёт, честно-честно!"]]}],
		"reward": {"unlock": "s_cat", "happy_home": [8, 72], "rp": 20, "cats": 1},
		"line": "Мурка снова дома"},
]

## Проверки добавляют сюда свои истории (другие виды целей), игра — не трогает
static var extra: Array = []


static func all() -> Array:
	return STORIES + extra


static func story(id: String) -> Dictionary:
	for s: Dictionary in all():
		if String(s["id"]) == id:
			return s
	return {}


## История, что открывает это украшение («s_cat»), или {}
static func by_unlock(u: String) -> Dictionary:
	for s: Dictionary in all():
		if String((s.get("reward", {}) as Dictionary).get("unlock", "")) == u:
			return s
	return {}


## Первое слово семьи: «Юлии Максимы» → «Юлии»
static func _fam1(fam: String) -> String:
	return fam.get_slice(" ", 0)


## «Корнелии» → «Корнелиев», «Помпеи» → «Помпеев»
static func fam_gen(fam: String) -> String:
	var f := _fam1(fam)
	return (f.left(f.length() - 1) + "ев") if f.ends_with("и") else f


## «Корнелии» → «Корнелий», «Помпеи» → «Помпей»
static func nomen(fam: String) -> String:
	var f := _fam1(fam)
	return (f.left(f.length() - 1) + "й") if f.ends_with("и") else f


## Имя мальчика из семьи (по имени семьи — всегда одно и то же)
static func boy(fam: String) -> String:
	var h := 0
	for i in fam.length():
		h = (h * 31 + fam.unicode_at(i)) % 100003
	return BOYS[h % BOYS.size()]


## Подставить имена: {kid}, {nomen}, {fam_gen}, {cat}
static func fill(text: String, bind: Dictionary) -> String:
	var fam := String(bind.get("fam", ""))
	return text.replace("{kid}", String(bind.get("kid", ""))).replace("{nomen}", nomen(fam)) \
		.replace("{fam_gen}", fam_gen(fam)).replace("{cat}", String(bind.get("cat_name", "Мурка")))


## Шаг истории с целью find (что ищем и как) — или {}
static func find_opts(s: Dictionary) -> Dictionary:
	for st: Dictionary in s.get("steps", []):
		var g: Array = st.get("goal", [])
		if not g.is_empty() and String(g[0]) == "find":
			return g[2]
	return {}
