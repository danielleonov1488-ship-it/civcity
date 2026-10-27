class_name HeroScreen
extends CanvasLayer
## Экран «Ваш герой» (решение владельца Д11): быстро и красиво создать своего римлянина — имя, пол, кожа, причёска,
## борода, наряд, цвета туники, тоги, каймы и плаща, венок; готовые наборы и «Случайный»; слева — живой герой
## на подиуме (свой маленький мир: колонны, жаровни, тёплый свет; мышью — повернуть). Не всплывающее окно: это часть
## начала новой игры (mode "new"), один раз в старом городе после обновления ("old": можно «Позже» — останется случайный
## герой) и «Изменить» в карточке героя ("edit"). Пока экран открыт, город стоит (скорость 0), камера не ездит.
## Что выбрать — Hero.items (открытое и закрытое: закрытое серым, с замочком, «Откроется: …» — в подсказке).

signal closed(saved: bool)

const LAYER := 42                      # над интерфейсом и обучением (10), под роликом повозки (40)? — над: экран — первым
const VP := Vector2i(720, 900)         # мирок героя (картинка слева)
const SKIN_COL := {"A": Color("efc9a4"), "B": Color("b98355"), "C": Color("dcaa7c")}
const HAIR_COL := {"A": Color("6b4a2e"), "B": Color("2b2a2b"), "C": Color("c49a64"), "S": Color("d2cdc4")}   # как волосы (Citizen._hair_mat)
const C_INK := Color("4a2c17")
const C_SOFT := Color("7a5a3c")
const C_BAD := Color("b0402a")
const C_GOLD := Color("c98a1e")
const C_CREAM := Color("fff4dc")

var hud: Hud
var game
var mode := "new"
var sx := 0
var pn := ""
var lk := {}
var _old := {}                         # запись героя до правки (её «видели» и снаряжение — переносятся)
var _name_auto := true                 # имя — случайное (игрок своего не вписывал): сменили пол — имя тоже своего пола

var vp: SubViewport
var who: Citizen
var cam: Camera3D
var pivot: Node3D
var turn := 0.35                       # поворот героя (мышью)
var _turn_v := 0.0
var _drag := false
var _t := 0.0
var _idle_t := 5.0
var _pose := ""

var root: Control
var body: VBoxContainer                # правая панель: поля выбора (пересобирается)
var btn_row: HBoxContainer             # кнопки под панелью (всегда на виду)
var name_edit: LineEdit
var err_lbl: Label
var hint_lbl: Label
var _speed0 := 1.0
var _cine0 := false
var _q := "high"                       # качество графики: на «Низкой» и «Очень низкой» мирок проще, город за экраном не рисуется
var _low := false
var _d3d0 := false
var _d3d_set := false


## Открыть экран: m — "new" | "old" | "edit"
static func open(g, m: String) -> HeroScreen:
	var old: HeroScreen = g.hud.get_node_or_null("HeroScreen")
	if old != null:
		return old
	var s := HeroScreen.new()
	s.name = "HeroScreen"
	s.game = g
	s.hud = g.hud
	s.mode = m
	s._old = (g.city.hero as Dictionary).duplicate(true) if Hero.exists(g.city) else {}
	if not s._old.is_empty():
		var om: Dictionary = s._old["m"]
		s.sx = int(om.get("sx", 0))
		s.pn = String(om.get("pn", ""))
		s.lk = (om.get("look", {}) as Dictionary).duplicate()
		s._name_auto = not bool(s._old.get("made", false))
	else:
		var rr := RandomNumberGenerator.new()
		rr.randomize()
		var h := Hero.random(rr)
		s.sx = int(h["m"]["sx"])
		s.pn = String(h["m"]["pn"])
		s.lk = h["m"]["look"]
	g.hud.add_child(s)
	return s


static func is_open(g) -> bool:
	return g != null and g.hud != null and g.hud.get_node_or_null("HeroScreen") != null


func _ready() -> void:
	layer = LAYER
	_speed0 = float(game.speed)                # как было (стояла на паузе — так и останется)
	hud.set_speed(0.0)
	if game.rig != null:
		_cine0 = bool(game.rig.cine)
		game.rig.cine = true                   # камера города стоит, пока выбираем
	_q = str(game.settings.get("quality", "high"))
	_low = Gfx.is_low(_q)
	if _low:
		_d3d0 = get_viewport().disable_3d      # слабый ноутбук: город под затемнением не рисуем (как в 3D-бою)
		get_viewport().disable_3d = true
		_d3d_set = true
	_make_world()
	_build_ui()
	_set_who(true)
	hud._hide_hover()


# =====================================================================
#   мирок героя: подиум, колонны, жаровни, тёплый свет
# =====================================================================

func _make_world() -> void:
	vp = SubViewport.new()
	vp.size = Vector2i(560, 700) if _low else VP      # картинка на экране — не больше 560×700
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_DISABLED if _low else Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("3a2618")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("ffe9c8")
	env.ambient_light_energy = 0.24
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.95
	env.glow_enabled = not _low
	env.glow_intensity = 0.25
	env.glow_hdr_threshold = 1.2
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	# фон — тёплое марево за спиной героя (кремовое в середине, к краям — терракота)
	var bg := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(3.6, 4.4)
	bg.mesh = qm
	var g := Gradient.new()
	g.set_color(0, Color("efcf94"))
	g.set_color(1, Color("2e190d"))
	g.add_point(0.3, Color("c4884a"))
	g.add_point(0.62, Color("6a3d20"))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.4)
	gt.fill_to = Vector2(0.98, 0.92)
	gt.width = 256
	gt.height = 256
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.albedo_texture = gt
	bg.material_override = bm
	bg.position = Vector3(0, 1.45, -2.6)
	vp.add_child(bg)
	# пол и подиум из мрамора в две ступени
	var floor_m := StandardMaterial3D.new()
	floor_m.albedo_color = Color("7a5a3c")
	floor_m.roughness = 0.9
	var fl := MeshInstance3D.new()
	var fd := CylinderMesh.new()
	fd.top_radius = 4.5
	fd.bottom_radius = 4.5
	fd.height = 0.05
	fl.mesh = fd
	fl.material_override = floor_m
	fl.position = Vector3(0, -0.025, 0)
	vp.add_child(fl)
	var marble := StandardMaterial3D.new()
	marble.albedo_color = Color("c4b8a4")
	marble.roughness = 0.6
	for st: Array in [[1.05, 0.12, 0.06], [0.82, 0.12, 0.18]]:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = float(st[0])
		cm.bottom_radius = float(st[0]) + 0.02
		cm.height = float(st[1])
		cm.radial_segments = 48
		mi.mesh = cm
		mi.material_override = marble
		mi.position = Vector3(0, float(st[2]), 0)
		vp.add_child(mi)
	# колонны и жаровни по бокам (Synty)
	Synty._index()
	for side: float in [-1.0, 1.0]:
		var col := Synty.make("SM_Bld_Pillar_02")
		if col != null:
			col.position = Vector3(side * 1.08, 0, -2.3)
			var ch := Artisau.aabb(col).size.y
			col.scale = Vector3.ONE * (2.6 / ch if ch > 0.1 else 0.7)     # колонна — чуть выше героя
			vp.add_child(col)
		var br := Synty.make("SM_Prop_Brazier_01")
		if br != null:
			br.position = Vector3(side * 0.82, 0, -1.25)
			br.scale = Vector3.ONE * 0.42
			vp.add_child(br)
			if _q != "verylow":
				var fire := OmniLight3D.new()
				fire.light_color = Color("ff9a3c")
				fire.light_energy = 1.4
				fire.omni_range = 2.6
				fire.position = br.position + Vector3(0, 0.75, 0)
				vp.add_child(fire)
			var flame := _flame()
			flame.position = br.position + Vector3(0, _brazier_top(br), 0)
			vp.add_child(flame)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-32, 28, 0)
	key.light_energy = 1.0
	key.light_color = Color("ffe6c2")
	key.shadow_enabled = _q != "verylow"
	vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-18, 180 + 35, 0)
	rim.light_energy = 1.3
	rim.light_color = Color("ffc979")
	vp.add_child(rim)
	var front := DirectionalLight3D.new()
	front.rotation_degrees = Vector3(-8, 0, 0)
	front.light_energy = 0.35
	front.light_color = Color("fff4e6")
	vp.add_child(front)
	pivot = Node3D.new()
	pivot.position = Vector3(0, 0.24, 0)
	vp.add_child(pivot)
	cam = Camera3D.new()
	cam.fov = 26.0
	cam.near = 0.05
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.3, 4.7), Vector3(0, 1.02, 0), Vector3.UP)


## Верх чаши жаровни (по её коробке) — там огонь
func _brazier_top(n: Node3D) -> float:
	var box := Artisau.aabb(n)
	return box.end.y - n.position.y - 0.04 if box.size.y > 0.01 else 0.6


## Огонь в жаровне: язычки-искры (тёплые, светятся)
func _flame() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 40
	p.lifetime = 0.75
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.08
	p.direction = Vector3.UP
	p.spread = 12.0
	p.initial_velocity_min = 0.25
	p.initial_velocity_max = 0.5
	p.gravity = Vector3(0, 0.3, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var qm := QuadMesh.new()
	qm.size = Vector2(0.075, 0.1)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1.0, 0.72, 0.38, 0.9)
	qm.material = m
	p.mesh = qm
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.85, 0.4, 1.0))
	ramp.set_color(1, Color(0.9, 0.25, 0.05, 0.0))
	p.color_ramp = ramp
	return p


## Герой на подиуме — по выбранному облику (новая модель — собрать заново, иначе — переодеть)
func _set_who(rebuild := false) -> void:
	Hero.fix_look(lk, sx)
	if who != null and is_instance_valid(who) and not rebuild and who.apply_look(lk.duplicate()):
		_sparkle()
		return
	if who != null and is_instance_valid(who):
		who.queue_free()
	who = Citizen.build(lk.duplicate())
	who.scale = Vector3.ONE
	Citizen.face_fix(who)
	pivot.add_child(who)
	who.play("Idle", 0.0)
	_pose = "Idle"
	_idle_t = 4.0
	if not rebuild:
		_sparkle()


func _sparkle() -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 16
	p.lifetime = 0.9
	p.explosiveness = 0.85
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.45
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.9
	p.gravity = Vector3(0, -0.4, 0)
	var qm := QuadMesh.new()
	qm.size = Vector2(0.06, 0.06)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color("ffe9a8")
	qm.material = mat
	p.mesh = qm
	vp.add_child(p)
	p.position = Vector3(0, 1.2, 0.2)
	p.emitting = true
	get_tree().create_timer(1.4).timeout.connect(p.queue_free)


func _process(dt: float) -> void:
	_t += dt
	if not _drag:
		_turn_v = lerpf(_turn_v, 0.0, minf(1.0, dt * 3.0))
		turn += _turn_v * dt
		turn = lerp_angle(turn, 0.35 + 0.12 * sin(_t * 0.4), minf(1.0, dt * 0.6)) if absf(_turn_v) < 0.05 else turn
	if pivot != null:
		pivot.rotation.y = turn
	# стоит, иногда оглядывается или поправляет одежду — живой
	if who != null and is_instance_valid(who):
		_idle_t -= dt
		if _idle_t <= 0.0:
			if _pose == "Idle":
				_pose = ["Look_Around", "Look_Around_M", "Idle_Talking"][randi() % 3]
				who.play(_pose, 0.4, 0.0)
				_idle_t = who.anim_len(_pose) if who.anim_len(_pose) > 0.0 else 5.0
			else:
				_pose = "Idle"
				who.play("Idle", 0.4)
				_idle_t = randf_range(5.0, 8.0)


# =====================================================================
#   экран
# =====================================================================

func _build_ui() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.theme = hud.theme_main
	root.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(root)
	# затемнение города и мягкая виньетка
	var dim := ColorRect.new()
	dim.color = Color(0.13, 0.08, 0.04, 1.0 if _low else 0.78)   # на «Низкой» город не рисуется — фон сплошной
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cc)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(col)
	var title := hud._label("Ваш герой" if mode != "edit" else "Герой: переодеть и переименовать", 40, false, C_CREAM, hud.font_title)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color("3a2412"))
	title.add_theme_constant_override("outline_size", 10)
	col.add_child(title)
	var sub := hud._label(_subtitle(), 18, true, Color("f3dcb0"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_outline_color", Color("3a2412"))
	sub.add_theme_constant_override("outline_size", 6)
	col.add_child(sub)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	# слева — живой герой в резной рамке
	var view := PanelContainer.new()
	view.add_theme_stylebox_override("panel", hud._box_panel(0))
	row.add_child(view)
	var vh := Control.new()
	var vs := _view_size()
	vh.custom_minimum_size = vs
	vh.mouse_filter = Control.MOUSE_FILTER_STOP
	vh.mouse_default_cursor_shape = Control.CURSOR_DRAG
	vh.tooltip_text = "Потяните мышью — повернуть героя"
	view.add_child(vh)
	var tr := TextureRect.new()
	tr.name = "view"
	tr.texture = vp.get_texture()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vh.add_child(tr)
	vh.gui_input.connect(_view_input)
	var turn_lbl := hud._label("Потяните мышью — повернуть", 14, true, Color(1, 0.95, 0.85, 0.85))
	turn_lbl.add_theme_color_override("font_outline_color", Color("3a2412"))
	turn_lbl.add_theme_constant_override("outline_size", 5)
	turn_lbl.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	turn_lbl.position = Vector2(vs.x * 0.5 - 100, vs.y - 30)
	turn_lbl.size = Vector2(200, 22)
	turn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vh.add_child(turn_lbl)
	# справа — свиток с выбором
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", hud._box_scroll_v(12))
	p.custom_minimum_size = Vector2(600, 0)
	row.add_child(p)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 4)
	p.add_child(pv)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(560, maxf(300.0, vs.y - 140.0))
	pv.add_child(sc)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 5)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(body)
	pv.add_child(hud._divider(12))
	btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	pv.add_child(btn_row)                         # кнопки — всегда на виду, под прокруткой
	_fill()
	_buttons()


func _subtitle() -> String:
	match mode:
		"old":
			return "В городе появился свой герой: гуляет по улицам и первым идёт в бой с Легионом. Создайте своего — или «Позже»"
		"edit":
			return "Новые вещи гардероба открывают рост города, Легион и истории"
	return "Герой будет жить в вашем городе, гулять по улицам и первым идти в бой с Легионом"


func _view_size() -> Vector2:
	var sz := root.get_viewport_rect().size if root != null and root.is_inside_tree() else Vector2(1600, 900)
	var h := clampf(sz.y - 190.0, 420.0, 700.0)
	return Vector2(roundf(h * 0.8), h)


func _view_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_drag = (e as InputEventMouseButton).pressed
	elif e is InputEventMouseMotion and _drag:
		var dx := (e as InputEventMouseMotion).relative.x
		turn += dx * 0.012
		_turn_v = dx * 0.6


## Правая панель: имя, пол, наборы, кожа и волосы, наряд и цвета, кнопки
func _fill() -> void:
	for ch in body.get_children():
		body.remove_child(ch)
		ch.queue_free()
	# имя
	var nr := HBoxContainer.new()
	nr.add_theme_constant_override("separation", 8)
	nr.add_child(_cap("Имя"))
	name_edit = LineEdit.new()
	name_edit.max_length = Hero.NAME_MAX
	name_edit.text = pn
	name_edit.placeholder_text = "Например, Гай Валерий"
	name_edit.custom_minimum_size = Vector2(330, 42)
	name_edit.add_theme_stylebox_override("normal", hud._box_pill(16, 6, "g_btn_on"))
	var fo := StyleBoxFlat.new()
	fo.draw_center = false
	fo.border_color = C_GOLD
	fo.set_border_width_all(2)
	fo.set_corner_radius_all(18)
	name_edit.add_theme_stylebox_override("focus", fo)
	name_edit.add_theme_font_override("font", hud.font_bold)
	name_edit.add_theme_font_size_override("font_size", 20)
	name_edit.add_theme_color_override("font_color", C_INK)
	name_edit.add_theme_color_override("font_placeholder_color", Color(C_SOFT, 0.55))
	name_edit.add_theme_color_override("caret_color", C_INK)
	name_edit.text_changed.connect(func(t: String):
		pn = t
		_name_auto = false
		err_lbl.text = "")
	nr.add_child(name_edit)
	var dice := _pill("Случайное", "dice", func():
		var rr := RandomNumberGenerator.new()
		rr.randomize()
		pn = Hero.random_name(rr, sx)
		name_edit.text = pn
		_name_auto = true
		err_lbl.text = "")
	dice.tooltip_text = "Случайное римское имя"
	nr.add_child(dice)
	body.add_child(nr)
	err_lbl = hud._label("", 15, true, C_BAD)
	err_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(err_lbl)
	# пол
	var sr := HBoxContainer.new()
	sr.add_theme_constant_override("separation", 8)
	sr.add_child(_cap("Кто"))
	for e: Array in [[0, "Римлянин"], [1, "Римлянка"]]:
		var v: int = e[0]
		var b := _pill(String(e[1]), "person", func(): _set_sx(v))
		b.toggle_mode = true
		b.set_pressed_no_signal(sx == v)
		sr.add_child(b)
	body.add_child(sr)
	# готовые наборы и «Случайный»
	body.add_child(hud._divider(10))
	var pt := hud._label("Готовые наборы", 18, true, C_INK)
	body.add_child(pt)
	var pf := HFlowContainer.new()
	pf.add_theme_constant_override("h_separation", 6)
	pf.add_theme_constant_override("v_separation", 6)
	for i in Hero.PRESETS.size():
		var pr: Dictionary = Hero.PRESETS[i]
		if int(pr["sx"]) != sx:
			continue
		var ii := i
		var b := _pill(String(pr["n"]), "", func(): _preset(ii))
		b.icon = _dot(Color(String(pr["look"]["cape"])))
		b.tooltip_text = "Набор «%s»" % pr["n"]
		pf.add_child(b)
	var rb := _pill("Случайный", "dice", func(): _random())
	rb.tooltip_text = "Случайный герой из того, что есть"
	pf.add_child(rb)
	body.add_child(pf)
	body.add_child(hud._divider(10))
	# лицо и волосы
	body.add_child(_swatches("Кожа", ["A", "B", "C"].map(func(t): return {"v": t, "n": Hero.SKIN_NAMES[t], "open": true, "why": ""}),
		String(lk.get("skin", "A")), func(v): _change("skin", v), SKIN_COL))
	var hm := Looks.hair_max(sx == 1)
	body.add_child(_stepper("Причёска", int(lk.get("hair", 1)), 0 if sx == 0 else 1, hm, "бритая", func(v: int): _change("hair", v)))
	if sx == 0:
		body.add_child(_stepper("Борода", int(lk.get("beard", 0)), 0, Looks.BEARDS, "нет", func(v: int): _change("beard", v)))
	body.add_child(_swatches("Волосы", Hero.items(game.city, "hc", lk), String(lk.get("hc", "A")), func(v): _change("hc", v), HAIR_COL))
	# наряд и цвета
	var outfits := Hero.items(game.city, "mdl", lk)
	body.add_child(_choice("Наряд", outfits, String(lk.get("mdl", "")), func(v): _change("mdl", v)))
	for e: Array in [["main", "Туника"], ["second", "Тога" if String(lk.get("mdl", "")).contains("Male") else "Нижняя туника"], ["trim", "Кайма"], ["cape", "Плащ"]]:
		var its := Hero.items(game.city, String(e[0]), lk)
		if its.is_empty():
			continue
		var k := String(e[0])
		body.add_child(_swatches(String(e[1]), its, String(lk.get(k, "")), func(v): _change(k, v), {}))
	body.add_child(_choice("Венок", Hero.items(game.city, "crown", lk), str(int(lk.get("crown", 1))), func(v): _change("crown", int(v))))
	hint_lbl = hud._label("Серые с замочком — откроются позже: ростом города, Легионом и историями", 14, false, C_SOFT)
	hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_lbl.custom_minimum_size = Vector2(540, 0)
	body.add_child(hint_lbl)


## Кнопки под панелью: «В город!» (новая игра) / «Готово» и «Позже» (старый город) / «Сохранить» и «Отмена» (правка)
func _buttons() -> void:
	var go := _big({"new": "В город!", "old": "Готово", "edit": "Сохранить"}.get(mode, "Готово"), "laurels", func(): _save())
	go.name = "go"
	btn_row.add_child(go)
	if mode == "old":
		var later := _big("Позже", "time", func(): _later())
		later.name = "later"
		later.tooltip_text = "Пусть пока будет этот герой — переодеть и переименовать можно в любой момент: «Изменить» в его карточке"
		btn_row.add_child(later)
	elif mode == "edit":
		var no := _big("Отмена", "close", func(): _close(false))
		no.name = "cancel"
		btn_row.add_child(no)


# ---------- элементы ----------

func _cap(t: String) -> Label:
	var l := hud._label(t, 17, true, C_INK)
	l.custom_minimum_size = Vector2(118, 0)
	return l


func _pill(text: String, icon: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	if icon != "":
		b.icon = hud.ico(icon, 24)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_font_override("font", hud.font_bold)
	b.add_theme_stylebox_override("normal", hud._box_pill(14, 5))
	b.add_theme_stylebox_override("hover", hud._box_pill(14, 5, "g_btn_hover"))
	b.add_theme_stylebox_override("pressed", hud._box_pill(14, 5, "g_btn_on"))
	b.add_theme_stylebox_override("hover_pressed", hud._box_pill(14, 5, "g_btn_on"))
	b.add_theme_color_override("font_color", C_INK)
	b.add_theme_color_override("font_pressed_color", C_INK)
	b.add_theme_color_override("font_hover_color", C_INK)
	b.pressed.connect(cb)
	return b


func _big(text: String, icon: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.icon = hud.ico(icon, 34)
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(210, 54)
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_font_override("font", hud.font_bold)
	b.pressed.connect(cb)
	return b


## Кружок цвета для кнопки набора (цвет его плаща)
func _dot(c: Color) -> Texture2D:
	var img := Image.create(18, 18, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 18:
		for x in 18:
			var d := Vector2(x - 8.5, y - 8.5).length()
			if d <= 8.5:
				img.set_pixel(x, y, Color("5a4128") if d > 7.0 else c)
	return ImageTexture.create_from_image(img)


## «Причёска  ◄ 3 из 7 ►»
func _stepper(title: String, cur: int, lo: int, hi: int, zero: String, cb: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(_cap(title))
	var prev := Button.new()
	prev.text = "◄"
	hud._small(prev, 34)
	prev.pressed.connect(func(): cb.call(hi if cur <= lo else cur - 1))
	row.add_child(prev)
	var val := hud._label(zero if cur == 0 and zero != "" else "%d из %d" % [cur, hi], 17, true, C_INK)
	val.custom_minimum_size = Vector2(96, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(val)
	var nxt := Button.new()
	nxt.text = "►"
	hud._small(nxt, 34)
	nxt.pressed.connect(func(): cb.call(lo if cur >= hi else cur + 1))
	row.add_child(nxt)
	return row


## Выбор из названий (наряд, венок): ◄ название ► — закрытые пропускаются, их видно в подсказке
func _choice(title: String, its: Array, cur: String, cb: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(_cap(title))
	var open := its.filter(func(e): return bool(e["open"]))
	var idx := 0
	for i in open.size():
		if str(open[i]["v"]) == cur:
			idx = i
	var prev := Button.new()
	prev.text = "◄"
	hud._small(prev, 34)
	prev.disabled = open.size() < 2
	prev.pressed.connect(func(): cb.call(open[(idx - 1 + open.size()) % open.size()]["v"]))
	row.add_child(prev)
	var val := hud._label(String(open[idx]["n"]) if not open.is_empty() else "—", 17, true, C_INK)
	val.custom_minimum_size = Vector2(190, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(val)
	var nxt := Button.new()
	nxt.text = "►"
	hud._small(nxt, 34)
	nxt.disabled = open.size() < 2
	nxt.pressed.connect(func(): cb.call(open[(idx + 1) % open.size()]["v"]))
	row.add_child(nxt)
	var locked := its.filter(func(e): return not bool(e["open"]))
	if not locked.is_empty():
		var lk_i := TextureRect.new()
		lk_i.texture = hud.ico("lock", 32)
		lk_i.custom_minimum_size = Vector2(22, 22)
		lk_i.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lk_i.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lk_i.mouse_filter = Control.MOUSE_FILTER_PASS
		lk_i.tooltip_text = "\n".join(locked.map(func(e): return "%s — %s" % [e["n"], String(e["why"]).trim_prefix("Откроется: ")]))
		lk_i.tooltip_text = "Ещё откроются:\n" + lk_i.tooltip_text
		row.add_child(lk_i)
	return row


## Ряд кружков-цветов: открытые — щёлкнуть, закрытые — серые с замочком (почему — в подсказке и строке под рядами)
func _swatches(title: String, its: Array, cur: String, cb: Callable, cols: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(_cap(title))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 5)
	flow.add_theme_constant_override("v_separation", 5)
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for e: Dictionary in its:
		var v = e["v"]
		var c: Color = cols.get(v, Color(String(v)) if String(v).is_valid_html_color() else Color.GRAY)
		var ok := bool(e["open"])
		var b := Button.new()
		b.custom_minimum_size = Vector2(30, 30)
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.tooltip_text = String(e["n"]) + ("" if ok else "\n" + String(e["why"]))
		var sb := StyleBoxFlat.new()
		sb.bg_color = c if ok else c.lerp(Color("9a8f80"), 0.6)
		sb.set_corner_radius_all(15)
		var on := str(v).to_lower() == cur.to_lower()
		sb.set_border_width_all(3 if on else 1)
		sb.border_color = Color("fff3c4") if on else Color("5a4128")
		if on:
			sb.shadow_color = Color(1.0, 0.85, 0.4, 0.7)
			sb.shadow_size = 3
		b.add_theme_stylebox_override("normal", sb)
		var sh := sb.duplicate() as StyleBoxFlat
		sh.border_color = Color("ffe08a")
		sh.set_border_width_all(3)
		b.add_theme_stylebox_override("hover", sh)
		b.add_theme_stylebox_override("pressed", sh)
		if not ok:
			var li := TextureRect.new()
			li.texture = hud.ico("lock", 32)
			li.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			li.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			li.set_anchors_preset(Control.PRESET_FULL_RECT)
			li.offset_left = 7
			li.offset_top = 7
			li.offset_right = -7
			li.offset_bottom = -7
			li.mouse_filter = Control.MOUSE_FILTER_IGNORE
			li.modulate = Color(1, 1, 1, 0.85)
			b.add_child(li)
			var why := "%s — %s" % [String(e["n"]), String(e["why"]).trim_prefix("Откроется: ")]
			b.pressed.connect(func(): hint_lbl.text = "Откроется позже: " + why)
		else:
			b.pressed.connect(func(): cb.call(v))
		flow.add_child(b)
	row.add_child(flow)
	return row


# ---------- выбор ----------

func _change(k: String, v) -> void:
	var mdl0 := String(lk.get("mdl", ""))
	lk[k] = v
	if k == "mdl" and String(v) == "SK_Chr_Worker_Male_01":
		Looks.set_main(lk, String(lk.get("main", "a3283a")))
	elif k == "main":
		Looks.set_main(lk, String(v))
	_set_who(String(lk.get("mdl", "")) != mdl0)
	if k == "mdl":
		_sparkle()
	_fill_keep()


## Пересобрать панель, не теряя места прокрутки
func _fill_keep() -> void:
	var sc := body.get_parent() as ScrollContainer
	var sv := sc.scroll_vertical if sc != null else 0
	_fill()
	if sc != null:
		sc.set_deferred("scroll_vertical", sv)


func _set_sx(v: int) -> void:
	if v == sx:
		_fill_keep()
		return
	sx = v
	# пол поменяли — набор этого пола (первый), имя — римское своего пола, если игрок своё ещё не вписал
	var keep_skin := String(lk.get("skin", "A"))
	for pr: Dictionary in Hero.PRESETS:
		if int(pr["sx"]) == sx:
			lk = (pr["look"] as Dictionary).duplicate()
			break
	lk["skin"] = keep_skin
	_auto_name()
	_set_who(true)
	_sparkle()
	_fill_keep()


## Имя своего пола, если игрок своё не вписывал
func _auto_name() -> void:
	if _name_auto or pn.strip_edges() == "":
		var rr := RandomNumberGenerator.new()
		rr.randomize()
		pn = Hero.random_name(rr, sx)
		_name_auto = true


func _preset(i: int) -> void:
	var pr: Dictionary = Hero.PRESETS[i]
	lk = (pr["look"] as Dictionary).duplicate()
	if sx != int(pr["sx"]):
		sx = int(pr["sx"])
		_auto_name()
	_set_who(true)
	_sparkle()
	_fill_keep()


func _random() -> void:
	var rr := RandomNumberGenerator.new()
	rr.randomize()
	lk = Hero.random_look(rr, sx)
	_set_who(true)
	_sparkle()
	_fill_keep()


func _save() -> void:
	var why := Hero.check_name(pn)
	if why != "":
		err_lbl.text = why
		return
	var c: City = game.city
	var sd := int(_old.get("m", {}).get("sd", 0)) if not _old.is_empty() else 0
	var h := Hero.make(pn, sx, lk, true, sd)
	if not _old.is_empty():
		h["seen"] = (_old.get("seen", []) as Array).duplicate()
		h["kit"] = int(_old.get("kit", -1))
	c.hero = h
	c.tips["hero_screen"] = true
	_close(true)


## «Позже»: остаётся случайный герой (переделать — «Изменить» в его карточке)
func _later() -> void:
	game.city.tips["hero_screen"] = true
	_close(false)


func _close(saved: bool) -> void:
	if game.rig != null:
		game.rig.cine = _cine0
	hud.set_speed(_speed0)
	if game.people != null:
		game.people.hero_refresh(saved)
	if hud.has_method("hero_btn_refresh"):
		hud.hero_btn_refresh()
	_d3d_back()
	closed.emit(saved)
	queue_free()


func _exit_tree() -> void:
	_d3d_back()                            # закрыли не кнопкой (выход в меню) — город снова рисуется


func _d3d_back() -> void:
	if _d3d_set and get_viewport() != null:
		get_viewport().disable_3d = _d3d0
	_d3d_set = false


func _unhandled_key_input(e: InputEvent) -> void:
	# клавиши города (инструменты, Esc — меню) не доходят до игры, пока экран открыт. Esc: в правке — как «Отмена»;
	# в начале игры экран не закрывается (выбор героя — часть начала), в старом городе — «Позже» есть кнопкой
	if not (e is InputEventKey):
		return
	get_viewport().set_input_as_handled()
	if (e as InputEventKey).pressed and (e as InputEventKey).keycode == KEY_ESCAPE and mode == "edit":
		_close(false)
