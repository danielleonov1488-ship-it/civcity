class_name CityName
extends RefCounted
## Название города — одно на всё: табличка вверху слева, сохранение (city.name), облако, таблица лучших городов,
## «Ваш город в боях», летописи соперников. Хранит его сервер (server/pvp.js: имя единственное, PUT /api/pvp/name),
## игра держит копию в сохранении; пока сервер не ответил (нет связи, старое сохранение) — «Новый Рим».
##
## Здесь: те же проверки, что у сервера (server/names.js — списки строка в строку, сверяет server/test_pvp.js),
## и окно «Название города» — одно и то же для таблички (щелчок по ней) и для кнопки «Имя» в «Легионе».
## Сохраняет окно через LegionNet.set_city_name (сервер → city.name, табличка, сохранение, облако).

const PLACEHOLDER := "Новый Рим"
const MIN_LEN := 3
const MAX_LEN := 24
const MSG_LEN := "Название — от 3 до 24 знаков"
const MSG_CHARS := "В названии — только буквы, цифры, пробел и дефис"
const MSG_RESERVED := "Такие названия («Город 123») даёт сам сервер — придумайте своё"
const MSG_RUDE := "Такое название не подойдёт — придумайте другое"

# грубые слова — как в server/names.js (корни: *_WORD — только в начале слова, *_JOIN — и во всём названии без пробелов,
# остальные — в любом месте слова)
const RUDE_RU := "хуй хуе хуя хуи пизд пезд бляд блят ебан ебат ебал ебло ебуч ебну уебищ мудак мудил мудач пидор пидр пидарас залуп гандон гондон шлюх дроч жоп говн мраз шалав"
const RUDE_RU_WORD := "еб бля сука сукин заеб наеб выеб въеб отъеб съеб поеб доеб долбоеб пидар уеб порн"
const RUDE_EN := "fuck shit cunt bitch whore pusy ashole porn twat"
const RUDE_EN_WORD := "dick cock slut wank"
const RUDE_RU_JOIN := "пизд пезд залуп шлюх уебищ долбоеб мудак пидорас пидарас"
const RUDE_EN_JOIN := "fuck cunt bitch whore"
# украинские буквы и буквы с надстрочными знаками → обычные; безобидные латинские слова (только целым словом)
const EXTRA := "і=и ї=и є=е ў=у ґ=г á=a à=a â=a ä=a ã=a å=a é=e è=e ê=e ë=e í=i ì=i î=i ï=i ó=o ò=o ô=o ö=o õ=o ø=o ú=u ù=u û=u ü=u ý=y ÿ=y ç=c ñ=n"
const SAFE_LAT := "pueblo lebanon ebony eboracum ebusus eboli huesca huelva scunthorpe dickinson cockermouth"
# латинские буквы и цифры, похожие на русские; транслит (сначала длинные сочетания); русские, похожие на латинские
const LOOK := "a=а b=в c=с e=е h=н k=к m=м n=п o=о p=р r=г t=т u=и x=х y=у 0=о 1=и 3=з 4=ч 6=б 9=я @=а"
const TRANS := "shch=щ sch=щ zh=ж kh=х ch=ч sh=ш ts=ц ya=я yu=ю yo=е ye=е a=а b=б c=с d=д e=е f=ф g=г h=х i=и j=й k=к l=л m=м n=н o=о p=п q=к r=р s=с t=т u=у v=в w=в x=х y=й z=з"
const LAT := "а=a в=b с=c е=e н=h к=k м=m о=o р=p т=t у=y х=x и=u п=n г=r ь=b 0=o 1=i 3=e 4=a 5=s 7=t 8=b @=a $=s"
const KEEP := "-'’."                           # внутри слова: слово не рвут (как цифры)

const C_INK := Color("4a2c17")
const C_SOFT := Color("7a5a3c")
const C_BAD := Color("b0402a")
const C_GOLD := Color("c98a1e")

static var _re := {}
static var _pairs := {}


# =====================================================================
#   правила (как cleanName в server/pvp.js)
# =====================================================================

static func _rx(key: String, pat: String) -> RegEx:
	if not _re.has(key):
		_re[key] = RegEx.create_from_string(pat)
	return _re[key]


## Как сервер: без управляющих знаков, пробелы (и «широкие» пробелы) — по одному, без пробелов по краям
static func clean(s: String) -> String:
	var t := _rx("ctl", "[\\x{0000}-\\x{001f}\\x{007f}]").sub(s, "", true)
	t = _rx("ws", "[\\s\\x{00a0}\\x{1680}\\x{2000}-\\x{200a}\\x{2028}\\x{2029}\\x{202f}\\x{205f}\\x{3000}\\x{feff}]+").sub(t, " ", true)
	return t.strip_edges()


## Ключ имени (занятость, запасные «Город 123»): строчные, ё → е, пробелы по одному
static func key(s: String) -> String:
	return clean(s).to_lower().replace("ё", "е")


## Почему такое название нельзя ("" — можно). current — нынешнее имя (своё запасное «Город 123» оставить можно).
## Занятость проверяет только сервер
static func check(s: String, current := "") -> String:
	var t := clean(s)
	if t.length() < MIN_LEN or t.length() > MAX_LEN:
		return MSG_LEN
	if _rx("ok", "^[\\p{L}\\p{N} '’\\-«»\".]+$").search(t) == null or _rx("letter", "\\p{L}").search(t) == null:
		return MSG_CHARS
	if rude(t):
		return MSG_RUDE
	if key(t) != key(current) and _rx("reserved", "^город \\d+(-\\d+)?$").search(key(t)) != null:
		return MSG_RESERVED
	return ""


## Грубое ли название: буквы попроще (і → и, ý → y), без безобидных латинских слов; три вида текста (двойники →
## кириллица, транслит, двойники → латиница), в каждом — слова, склейки коротких слов и всё название одной строкой
## (server/names.js — те же шаги)
static func rude(s: String) -> bool:
	var t := _swap(s.to_lower().replace("ё", "е"), "extra")
	t = _rx("safe", "(^|[^a-z])(" + SAFE_LAT.replace(" ", "|") + ")(?=$|[^a-z])").sub(t, "$1 ", true)
	return _hits(_swap(t, "look"), RUDE_RU, RUDE_RU_WORD, RUDE_RU_JOIN) or _hits(_translit(t), RUDE_RU, RUDE_RU_WORD, RUDE_RU_JOIN) \
		or _hits(_swap(t, "lat"), RUDE_EN, RUDE_EN_WORD, RUDE_EN_JOIN)


static func _pairs_of(which: String) -> Array:
	if not _pairs.has(which):
		var src: String = {"extra": EXTRA, "look": LOOK, "trans": TRANS, "lat": LAT}[which]
		var a := []
		for tok in src.split(" "):
			a.append(tok.split("=", true, 1))
		_pairs[which] = a
	return _pairs[which]


## Посимвольная замена (ключи — по одному знаку)
static func _swap(t: String, which: String) -> String:
	var m := {}
	for p: PackedStringArray in _pairs_of(which):
		m[p[0]] = p[1]
	var o := ""
	for ch in t:
		o += String(m.get(ch, ch))
	return o


## Транслит: на каждом месте — первое подходящее сочетание из списка
static func _translit(t: String) -> String:
	var o := ""
	var i := 0
	while i < t.length():
		var hit := false
		for p: PackedStringArray in _pairs_of("trans"):
			if t.substr(i, p[0].length()) == p[0]:
				o += p[1]
				i += p[0].length()
				hit = true
				break
		if not hit:
			o += t[i]
			i += 1
	return o


## Повторы букв подряд — одной буквой
static func _squash(w: String) -> String:
	var o := ""
	for ch in w:
		if o == "" or o[o.length() - 1] != ch:
			o += ch
	return o


## Слова и куски для сверки: части (их делит любой не-буквенный знак, цифры выкидываются), склейки коротких частей
## (1–2 буквы) с соседями и слова целиком (дефис, апостроф, точка их не делят: «Пиз-дец» → «пиздец»)
static func _chunks(t: String) -> Array:
	var words := []
	var whole := []
	var cur := ""
	var wcur := ""
	var letter := _rx("letter", "\\p{L}")
	for ch in t:
		if letter.search(ch) != null:
			cur += ch
			wcur += ch
			continue
		var c := ch.unicode_at(0)
		if c >= 0x30 and c <= 0x39:
			continue
		if cur != "":
			words.append(_squash(cur))
		cur = ""
		if KEEP.contains(ch):
			continue
		if wcur != "":
			whole.append(_squash(wcur))
		wcur = ""
	if cur != "":
		words.append(_squash(cur))
	if wcur != "":
		whole.append(_squash(wcur))
	var glued := []
	for i in words.size():
		if not glued.is_empty() and ((words[i] as String).length() <= 2 or (words[i - 1] as String).length() <= 2):
			glued[glued.size() - 1] += words[i]
		else:
			glued.append(words[i])
	for g in glued:
		words.append(_squash(g))
	return words + whole


## Всё название одной строкой: только буквы a–z, а–я
static func _joined(t: String) -> String:
	var o := ""
	for ch in t:
		var c := ch.unicode_at(0)
		if (c >= 0x61 and c <= 0x7a) or (c >= 0x430 and c <= 0x44f):
			o += ch
	return _squash(o)


static func _hits(t: String, any: String, word: String, join: String) -> bool:
	var a := any.split(" ")
	var w := word.split(" ")
	for c: String in _chunks(t):
		for r in a:
			if c.contains(r):
				return true
		for r in w:
			if c.begins_with(r):
				return true
	var j := _joined(t)
	for r in join.split(" "):
		if j.contains(r):
			return true
	return false


# =====================================================================
#   окно «Название города»
# =====================================================================

## Открытое окно (на hud.root) или null
static func window(hud) -> Control:
	if hud == null or hud.root == null:
		return null
	var w := hud.root.get_node_or_null("CityName") as Control
	return w if w != null and not w.is_queued_for_deletion() else null


## Закрыть окно; true — оно было открыто
static func close(hud) -> bool:
	var w := window(hud)
	if w == null:
		return false
	w.get_parent().remove_child(w)
	w.queue_free()
	return true


## Нынешнее имя: что знает сервер, иначе — из сохранения
static func current(hud) -> String:
	var nm := String(LegionNet.me().me_state.get("name", ""))
	if nm == "" and hud != null and hud.game != null and hud.game.city != null:
		nm = String(hud.game.city.name)
	return nm


## Окно «Название города» поверх всего. done(name) — после удачного сохранения (окно «Легион» перерисует себя)
static func open(hud, done := Callable()) -> void:
	close(hud)
	var net := LegionNet.me()
	var ov := Control.new()
	ov.name = "CityName"
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.12, 0.07, 0.03, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(cc)
	var p := PanelContainer.new()
	p.name = "win"
	p.add_theme_stylebox_override("panel", hud._box_scroll_v(18))
	p.custom_minimum_size = Vector2(520, 0)
	cc.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var t: Label = hud._label("Название города", 28, false, C_INK, hud.font_title)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var about: Label = hud._wrap(hud._label("Это имя на табличке вверху слева. Его видят соперники, летописи их боёв и таблица лучших городов. От 3 до 24 знаков: буквы, цифры, пробел, дефис.", 15, false, C_SOFT), 450)
	about.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(about)
	var e := LineEdit.new()
	e.name = "field"
	e.max_length = MAX_LEN
	e.text = current(hud)
	e.placeholder_text = "Например, Аквилея Новая"
	e.custom_minimum_size = Vector2(420, 46)
	e.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	e.alignment = HORIZONTAL_ALIGNMENT_CENTER
	e.add_theme_stylebox_override("normal", hud._box_pill(18, 8, "g_btn_on"))
	var fo := StyleBoxFlat.new()
	fo.draw_center = false
	fo.border_color = C_GOLD
	fo.set_border_width_all(2)
	fo.set_corner_radius_all(20)
	e.add_theme_stylebox_override("focus", fo)
	e.add_theme_font_override("font", hud.font_bold)
	e.add_theme_font_size_override("font_size", 20)
	e.add_theme_color_override("font_color", C_INK)
	e.add_theme_color_override("font_placeholder_color", Color(C_SOFT, 0.55))
	e.add_theme_color_override("caret_color", C_INK)
	e.add_theme_color_override("selection_color", Color(C_GOLD, 0.35))
	e.add_theme_color_override("font_selected_color", C_INK)
	e.mouse_default_cursor_shape = Control.CURSOR_IBEAM
	v.add_child(e)
	# почему не вышло: текст сервера (занято, не подойдёт) или честная причина без связи; ниже — мелкий код сбоя
	var err: Label = hud._wrap(hud._label("", 15, true, C_BAD), 450)
	err.name = "error"
	err.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(err)
	var code: Label = hud._label("", 13, false, C_SOFT)
	code.name = "code"
	code.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	code.visible = false
	v.add_child(code)
	var bh := HBoxContainer.new()
	bh.alignment = BoxContainer.ALIGNMENT_CENTER
	bh.add_theme_constant_override("separation", 12)
	v.add_child(bh)
	var ok := _button(hud, "Сохранить", 180)
	ok.name = "save"
	bh.add_child(ok)
	var no := _button(hud, "Отмена", 150)
	no.name = "cancel"
	bh.add_child(no)
	var shut := func(): close(hud)
	var go := func():
		if ok.disabled:
			return
		var nm := clean(e.text)
		var cur := current(hud)
		var why := check(nm, cur)
		if why != "":
			err.text = why
			code.visible = false
			return
		if nm == cur and bool(net.me_state.get("custom", false)):
			net.adopt_name()                              # то же имя — на сервере уже оно; табличке и сохранению — тоже
			close(hud)
			return
		ok.disabled = true
		ok.text = "Сохраняем…"
		err.text = ""
		code.visible = false
		net.set_city_name(nm, func(msg: String, offline: bool):
			if not is_instance_valid(ok):
				return                                    # окно закрыли, пока ждали (имя всё равно сохранится)
			ok.disabled = false
			ok.text = "Повторить" if msg != "" and offline else "Сохранить"
			if msg == "":
				close(hud)
				if done.is_valid():
					done.call(nm)
				return
			err.text = msg
			var cl := String((net.last_fail as Dictionary).get("code", "")) if offline else ""
			code.text = cl
			code.visible = cl != "")
	ok.pressed.connect(go)
	no.pressed.connect(shut)
	e.text_submitted.connect(func(_t): go.call())
	e.text_changed.connect(func(_t):
		if not ok.disabled:
			ok.text = "Сохранить")
	# Esc в поле — закрыть окно (иначе Esc в городе открыл бы меню игры)
	e.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventKey and (ev as InputEventKey).pressed and (ev as InputEventKey).keycode == KEY_ESCAPE:
			e.accept_event()
			close(hud))
	hud.root.add_child(ov)
	hud._hide_hover()
	e.call_deferred("grab_focus")
	e.call_deferred("select_all")


static func _button(hud, text: String, w: float) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(w, 46)
	b.add_theme_font_override("font", hud.font_bold)
	b.add_theme_font_size_override("font_size", 19)
	return b
