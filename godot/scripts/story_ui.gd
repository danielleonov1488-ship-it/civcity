class_name StoryUi
extends RefCounted
## Интерфейс историй горожан (scripts/stories.gd):
##  - облачко в ролике: портрет в медальоне (живая голова говорящего — его клон в своём маленьком мире, рисуется только
##    пока облачко видно; нет клона — рисованный портрет класса или советника), имя и кто он, текст печатается,
##    «›» — дальше, кнопки выбора;
##  - золотая строка наверху «Просьб горожан» (Hud._fill_tasks_body зовёт task_row);
##  - журнал «Истории горожан» с «Пересмотреть»;
##  - маленькие подписи над миром вне роликов («мяу!», «Мурка! Кис-кис!») — Label3D;
##  - картинки, нарисованные кодом: сердечко, след лапки, мягкое пятно света для места поисков.

const PORTRAIT := 112                  # медальон портрета, точек
const CPS := 38.0                      # букв в секунду (печать текста)

var st                                 # Stories
var hud
var game
var panel: PanelContainer              # облачко
var name_lbl: Label
var role_lbl: Label
var text_lbl: Label
var more_lbl: Label                    # «›» — щёлкните, чтобы дальше
var pills: HBoxContainer               # кнопки выбора
var face_box: Control                  # медальон с портретом
var face_tex: TextureRect
var _vps := {}                         # кто говорит → SubViewport с его головой
var _speaker := ""
var _tw: Tween
var _pick := Callable()

static var _heart: Texture2D
static var _paw: Texture2D
static var _glow: Texture2D
static var _mask: Shader


func _init(s) -> void:
	st = s
	hud = s.hud
	game = s.game


# ---------- облачко в ролике ----------

## Собрать облачко в слое ролика (над нижней полосой, посередине); прячется до первой реплики
func bubble(parent: Control) -> void:
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", hud._box_scroll_h(6))
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.custom_minimum_size = Vector2(780, 0)
	panel.offset_left = -390
	panel.offset_right = 390
	var vh: float = parent.get_viewport().get_visible_rect().size.y
	panel.offset_bottom = -vh * CineKit.BAR * 0.55
	panel.offset_top = panel.offset_bottom
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.modulate.a = 0.0
	parent.add_child(panel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(h)
	face_box = Panel.new()
	face_box.custom_minimum_size = Vector2(PORTRAIT, PORTRAIT)
	face_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	face_box.add_theme_stylebox_override("panel", hud._medal("medal_on", PORTRAIT))
	face_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(face_box)
	face_tex = TextureRect.new()
	face_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	var o := PORTRAIT * 0.13
	face_tex.offset_left = o
	face_tex.offset_top = o
	face_tex.offset_right = -o
	face_tex.offset_bottom = -o
	face_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	face_tex.material = _mask_mat()
	face_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face_box.add_child(face_tex)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var nh := HBoxContainer.new()
	nh.add_theme_constant_override("separation", 10)
	nh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(nh)
	name_lbl = hud._label("", 24, false, hud.C_INK, hud.font_title)
	nh.add_child(name_lbl)
	role_lbl = hud._label("", 15, true, hud.C_SOFT)
	role_lbl.size_flags_vertical = Control.SIZE_SHRINK_END
	nh.add_child(role_lbl)
	text_lbl = hud._label("", 19)
	text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_lbl.custom_minimum_size = Vector2(560, 58)
	v.add_child(text_lbl)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(row)
	pills = HBoxContainer.new()
	pills.add_theme_constant_override("separation", 10)
	pills.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pills.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(pills)
	more_lbl = hud._label("›", 30, false, hud.C_GOLD, hud.font_title)
	more_lbl.size_flags_vertical = Control.SIZE_SHRINK_END
	more_lbl.modulate.a = 0.0
	row.add_child(more_lbl)


## Реплика: who — {name, role, kind: citizen|cat|pic, …}; текст печатается
func say(who: Dictionary, text: String) -> void:
	if panel == null:
		return
	_clear_pills()
	name_lbl.text = String(who.get("name", ""))
	role_lbl.text = String(who.get("role", ""))
	_face(who)
	text_lbl.text = text
	text_lbl.visible_ratio = 0.0
	more_lbl.modulate.a = 0.0
	if panel.modulate.a < 1.0:
		panel.create_tween().tween_property(panel, "modulate:a", 1.0, 0.3)
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = text_lbl.create_tween()
	_tw.tween_property(text_lbl, "visible_ratio", 1.0, maxf(0.3, text.length() / CPS))
	_tw.tween_callback(_typed)


## Допечатано: «›» — или кнопки выбора (они появляются, когда вопрос прочитан)
func _typed() -> void:
	if more_lbl == null:
		return
	more_lbl.modulate.a = 1.0 if pills.get_child_count() == 0 else 0.0
	if not pills.visible:
		pills.visible = true
		pills.modulate.a = 0.0
		pills.create_tween().tween_property(pills, "modulate:a", 1.0, 0.25)


## Текст ещё печатается
func typing() -> bool:
	return text_lbl != null and text_lbl.visible_ratio < 1.0


## Допечатать сразу (щелчок во время печати)
func finish_typing() -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	if text_lbl != null:
		text_lbl.visible_ratio = 1.0
	_typed()


## Кнопки выбора под репликой: opts — [[подпись, значение, …]], cb(значение)
func choices(opts: Array, cb: Callable) -> void:
	_clear_pills()
	_pick = cb
	for o: Array in opts:
		var b := Button.new()
		b.text = String(o[0])
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.add_theme_font_override("font", hud.font_bold)
		b.add_theme_font_size_override("font_size", 17)
		b.add_theme_stylebox_override("normal", hud._box_pill(18, 5))
		b.add_theme_stylebox_override("hover", hud._box_pill(18, 5, "g_btn_hover"))
		b.add_theme_stylebox_override("pressed", hud._box_pill(18, 5, "g_btn_on"))
		for s in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(s, hud.C_INK)
		var val := String(o[1])
		b.pressed.connect(func():
			var f := _pick
			_pick = Callable()
			if f.is_valid():
				f.call(val))
		pills.add_child(b)
	more_lbl.modulate.a = 0.0
	pills.visible = not typing()


func choosing() -> bool:
	return pills != null and pills.get_child_count() > 0


func _clear_pills() -> void:
	if pills == null:
		return
	for ch in pills.get_children():
		pills.remove_child(ch)
		ch.queue_free()


## Облачко ушло (ролик кончился): клоны для портретов — долой
func close() -> void:
	for k in _vps:
		var vp: SubViewport = _vps[k]
		if is_instance_valid(vp):
			vp.queue_free()
	_vps = {}
	_speaker = ""
	panel = null


# ---------- портрет: живая голова говорящего ----------

static func _mask_mat() -> ShaderMaterial:
	if _mask == null:
		_mask = Shader.new()
		_mask.code = "shader_type canvas_item;\nvoid fragment() {\n\tvec4 c = texture(TEXTURE, UV);\n\tfloat r = length(UV - vec2(0.5));\n\tc.a *= 1.0 - smoothstep(0.47, 0.5, r);\n\tCOLOR = c * COLOR;\n}\n"
	var m := ShaderMaterial.new()
	m.shader = _mask
	return m


## Портрет говорящего: свой маленький мир с клоном (обновляется, только пока он говорит)
func _face(who: Dictionary) -> void:
	var key := "%s:%s:%s" % [who.get("kind", ""), who.get("seed", who.get("fur", "")), who.get("pic", "")]
	if key == _speaker and face_tex.texture != null:
		_anim_face(who, true)
		return
	for k in _vps:
		(_vps[k] as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED
	_speaker = key
	var kind := String(who.get("kind", "pic"))
	if kind == "pic" or game.get_viewport() == null:
		face_tex.texture = load(Hud.AI + String(who.get("pic", "advisor.png")))
		return
	if not _vps.has(key):
		var vp := _portrait_vp(who)
		if vp == null:
			face_tex.texture = load(Hud.AI + String(who.get("pic", "advisor.png")))
			return
		_vps[key] = vp
	var vpk: SubViewport = _vps[key]
	vpk.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	face_tex.texture = vpk.get_texture()
	_anim_face(who, true)


## Говорит — движения разговора; молчит — спокойно
func _anim_face(who: Dictionary, talk: bool) -> void:
	var vp: SubViewport = _vps.get(_speaker)
	if vp == null:
		return
	var m := vp.get_node_or_null("who")
	if m is Citizen:
		(m as Citizen).play("Idle_Talking" if talk else "Idle")


func _portrait_vp(who: Dictionary) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(224, 224)
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	st.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("e8d3a6")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("fff1d8")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, 35, 0)
	key.light_energy = 1.25
	key.light_color = Color("fff0d6")
	vp.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10, -140, 0)
	fill.light_energy = 0.45
	fill.light_color = Color("cfe0ff")
	vp.add_child(fill)
	var cam := Camera3D.new()
	cam.fov = 24.0
	cam.near = 0.02
	vp.add_child(cam)
	var dist := 1.0
	var sk: Skeleton3D = null
	var bone := -1
	var off := Vector3.ZERO
	match String(who.get("kind", "")):
		"citizen":
			var rr := RandomNumberGenerator.new()
			rr.seed = int(who.get("seed", 1))
			var c := Citizen.create(rr, bool(who.get("female", false)), bool(who.get("child", false)), String(who.get("cls", "")) == "patricians", "", String(who.get("cls", "plebs")))
			c.name = "who"
			vp.add_child(c)
			if bool(who.get("child", false)):
				People.kid_look(c)
			c.play("Idle_Talking")
			sk = c.find_children("*", "Skeleton3D", true, false)[0]
			bone = sk.find_bone("Head")
			off = Vector3(0, 0.05, 0) * c.scale.y / Citizen.SIZE
			dist = 1.0 * c.scale.y / Citizen.SIZE
		"cat":
			var cn := People.cat_node(int(who.get("fur", 0)), "Pet", 7)
			cn.name = "who"
			cn.rotation.y = 0.35
			vp.add_child(cn)
			var sks := cn.find_children("*", "Skeleton3D", true, false)
			if not sks.is_empty():
				sk = sks[0]
				bone = sk.find_bone("Bone.003")
			off = Vector3(0, 0.06, 0.03)          # кость — у основания головы: смотрим в мордочку
			dist = 0.46
		_:
			vp.queue_free()
			return null
	vp.set_meta("face", [cam, sk, bone, off, dist])
	_aim(vp)
	return vp


## Камера портрета — на голову говорящего (голова движется: зовётся каждый кадр, пока он говорит)
func _aim(vp: SubViewport) -> void:
	var f: Array = vp.get_meta("face", [])
	if f.is_empty():
		return
	var cam: Camera3D = f[0]
	var sk = f[1]
	var head := Vector3(0, 0.3, 0.15)
	if sk != null and is_instance_valid(sk) and int(f[2]) >= 0:
		head = ((sk as Skeleton3D).global_transform * (sk as Skeleton3D).get_bone_global_pose(int(f[2]))).origin
	head += f[3]
	var dir := Vector3(sin(0.32), 0.12, cos(0.32)).normalized()
	cam.position = head + dir * float(f[4])
	cam.look_at(head - Vector3(0, 0.02, 0), Vector3.UP)


## Каждый кадр ролика: портрет следит за головой
func track() -> void:
	var vp: SubViewport = _vps.get(_speaker)
	if vp != null and is_instance_valid(vp):
		_aim(vp)


# ---------- золотая строка в «Просьбах горожан» ----------

## Строка истории наверху свитка: медальон, название, что делать, кнопки (Stories.row_info)
func task_row(box: Control) -> void:
	var info: Dictionary = st.row_info()
	if info.is_empty():
		return
	var pc := PanelContainer.new()
	var sb: StyleBox = hud._box_pill(10, 6, "g_btn_on")
	pc.add_theme_stylebox_override("panel", sb)
	pc.mouse_filter = Control.MOUSE_FILTER_PASS
	pc.tooltip_text = String(info.get("tip", ""))
	box.add_child(pc)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(h)
	var med := Panel.new()
	med.custom_minimum_size = Vector2(44, 44)
	med.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	med.mouse_filter = Control.MOUSE_FILTER_IGNORE
	med.add_theme_stylebox_override("panel", hud._medal("medal_on", 44))
	var ic: TextureRect = hud._icon(String(info.get("icon", "scroll")), 28, hud.C_INK)
	ic.position = Vector2(8, 8)
	med.add_child(ic)
	h.add_child(med)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var t: Label = hud._wrap(hud._label(String(info["title"]), 16, false, hud.C_INK, hud.font_title), 222)
	v.add_child(t)
	var sub: Label = hud._wrap(hud._label(String(info.get("text", "")), 13, true, hud.C_SOFT), 222)
	v.add_child(sub)
	var btns: Array = info.get("buttons", [])
	if not btns.is_empty():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for bd: Array in btns:
			var b := Button.new()
			b.text = String(bd[0])
			b.focus_mode = Control.FOCUS_NONE
			b.add_theme_font_size_override("font_size", 13)
			b.add_theme_stylebox_override("normal", hud._box_pill(12, 3))
			b.add_theme_stylebox_override("hover", hud._box_pill(12, 3, "g_btn_hover"))
			b.add_theme_stylebox_override("pressed", hud._box_pill(12, 3, "g_btn_on"))
			b.custom_minimum_size = Vector2(0, 26)
			b.pressed.connect(bd[1])
			row.add_child(b)
		v.add_child(row)


# ---------- журнал «Истории горожан» ----------

func open_journal() -> void:
	if hud.journal_panel == null:
		var w: Array = hud._window("Истории горожан", 600)
		hud.journal_panel = w[0]
		var sc := ScrollContainer.new()
		sc.custom_minimum_size = Vector2(560, 420)
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		(w[1] as VBoxContainer).add_child(sc)
		var list := VBoxContainer.new()
		list.name = "list"
		list.add_theme_constant_override("separation", 8)
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc.add_child(list)
	fill_journal()
	if not hud.journal_panel.visible:
		hud._toggle(hud.journal_panel)


func fill_journal() -> void:
	if hud.journal_panel == null:
		return
	var list: VBoxContainer = hud.journal_panel.find_child("list", true, false)
	hud._clear(list)
	var S: Dictionary = game.city.stories
	var any := false
	var info: Dictionary = st.row_info()
	if not info.is_empty():
		any = true
		list.add_child(_entry(String(info.get("icon", "scroll")), String(info["title"]), String(info.get("text", "")), "сейчас", Callable()))
	var done: Array = (S["done"] as Dictionary).keys()
	done.sort_custom(func(a, b): return int(S["done"][a].get("h", 0)) > int(S["done"][b].get("h", 0)))
	for id in done:
		var s := StoryDefs.story(String(id))
		if s.is_empty():
			continue
		any = true
		var e: Dictionary = S["done"][id]
		var who := StoryDefs.fill(String(s.get("who", "")), e)
		var how := String(e.get("text", ""))
		var sid := String(id)
		list.add_child(_entry(String(s.get("icon", "scroll")), String(s["title"]), "%s. %s" % [who, how] if who != "" else how,
			"день %d" % (int(e.get("day", 0)) + 1), func(): st.replay(sid)))
	if not any:
		var l: Label = hud._wrap(hud._label("Пока ни одной истории. Горожане иногда просят градоначальника о помощи — над домом просящего тогда появляется свиток, а наверху «Просьб горожан» — золотая строка.", 16, false, hud.C_SOFT), 540)
		list.add_child(l)


func _entry(icon: String, title: String, text: String, when: String, replay: Callable) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var med := Panel.new()
	med.custom_minimum_size = Vector2(52, 52)
	med.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	med.add_theme_stylebox_override("panel", hud._medal("medal", 52))
	var ic: TextureRect = hud._icon(icon, 32)
	ic.position = Vector2(10, 10)
	med.add_child(ic)
	h.add_child(med)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	h.add_child(v)
	var th := HBoxContainer.new()
	th.add_child(hud._label(title, 19, false, hud.C_INK, hud.font_title))
	var wl: Label = hud._label(when, 14, true, hud.C_SOFT)
	wl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	th.add_child(wl)
	v.add_child(th)
	v.add_child(hud._wrap(hud._label(text, 15, false, hud.C_INK), 440))
	if replay.is_valid():
		var b := Button.new()
		b.text = "Пересмотреть"
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 14)
		b.add_theme_stylebox_override("normal", hud._box_pill(14, 3))
		b.add_theme_stylebox_override("hover", hud._box_pill(14, 3, "g_btn_hover"))
		b.add_theme_stylebox_override("pressed", hud._box_pill(14, 3, "g_btn_on"))
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.pressed.connect(replay)
		v.add_child(b)
	return h


# ---------- над миром: подписи, сердечки, следы ----------

## Маленькая подпись над точкой мира (вне роликов): всплывает и тает за dur с
func bubble3d(at: Vector3, text: String, dur := 3.0, size := 30) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = hud.font_bold
	l.font_size = size
	l.outline_size = 9
	l.modulate = Color("fff4dc")
	l.outline_modulate = Color("5a3a1a")
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.pixel_size = 0.006
	l.position = at
	game.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", at.y + 0.9, dur)
	tw.parallel().tween_property(l, "modulate:a", 0.0, dur * 0.5).set_delay(dur * 0.5)
	tw.parallel().tween_property(l, "outline_modulate:a", 0.0, dur * 0.5).set_delay(dur * 0.5)
	tw.tween_callback(l.queue_free)


## Сердечки над кошкой (встреча): поднимаются и тают
func hearts(at: Vector3, n := 6) -> void:
	for i in n:
		var s := Sprite3D.new()
		s.texture = heart_tex()
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		s.pixel_size = 0.0045 * (0.8 + 0.1 * (i % 3))
		s.modulate = Color(1, 1, 1, 0.0)
		s.no_depth_test = true
		var off := Vector3(cos(i * 2.4) * 0.35, 0.2 + 0.05 * i, sin(i * 2.4) * 0.35)
		s.position = at + off
		game.add_child(s)
		var tw := s.create_tween()
		tw.tween_interval(0.18 * i)
		tw.tween_property(s, "modulate:a", 1.0, 0.25)
		tw.parallel().tween_property(s, "position:y", at.y + off.y + 1.3, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(s, "modulate:a", 0.0, 0.5)
		tw.tween_callback(s.queue_free)


static func heart_tex() -> Texture2D:
	if _heart == null:
		var n := 64
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				# сердечко: (x² + y² − 1)³ − x² y³ ≤ 0, с мягким краем
				# 4×4 точки в пикселе — край гладкий
				var a := 0.0
				var vv := 0.0
				for sy in 4:
					for sx in 4:
						var u := (x + (sx + 0.5) / 4.0 - n * 0.5) / (n * 0.4)
						var v := -(y + (sy + 0.5) / 4.0 - n * 0.56) / (n * 0.4)
						if pow(u * u + v * v - 1.0, 3.0) - u * u * v * v * v <= 0.0:
							a += 1.0 / 16.0
						vv = v
				var col := Color("e8505b").lerp(Color("ff9aa0"), clampf(vv * 0.5 + 0.3, 0.0, 1.0))
				img.set_pixel(x, y, Color(col.r, col.g, col.b, a))
		img.generate_mipmaps()
		_heart = ImageTexture.create_from_image(img)
	return _heart


## След лапки (для декали на земле): подушечка и четыре пальчика
static func paw_tex() -> Texture2D:
	if _paw == null:
		var n := 64
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		var blobs := [[Vector2(0.5, 0.64), 0.19], [Vector2(0.27, 0.36), 0.085], [Vector2(0.42, 0.24), 0.09], [Vector2(0.58, 0.24), 0.09], [Vector2(0.73, 0.36), 0.085]]
		for y in n:
			for x in n:
				var p := Vector2((x + 0.5) / n, (y + 0.5) / n)
				var a := 0.0
				for bl: Array in blobs:
					var d := p.distance_to(bl[0]) / float(bl[1])
					a = maxf(a, clampf((1.0 - d) * 6.0, 0.0, 1.0))
				img.set_pixel(x, y, Color(1, 1, 1, a))
		img.generate_mipmaps()
		_paw = ImageTexture.create_from_image(img)
	return _paw


## Мягкое пятно света: ярко в середине, к краю сходит на нет (без кольца — не «круг охвата»)
static func glow_tex() -> Texture2D:
	if _glow == null:
		var n := 128
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var r := Vector2((x + 0.5) / n - 0.5, (y + 0.5) / n - 0.5).length() * 2.0
				var a := pow(clampf(1.0 - r, 0.0, 1.0), 1.6)
				img.set_pixel(x, y, Color(1, 1, 1, a))
		img.generate_mipmaps()
		_glow = ImageTexture.create_from_image(img)
	return _glow
