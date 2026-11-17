class_name MagisUI
extends Control
## Шесть магистратур целиком в одном окне; числа обновляются по сигналу города.

const KIT := "res://assets/ui/kitA/"
const ART := "res://assets/ui/magis/"
const INK := Color("4a2511")
const GOOD := Color("286312")
const BAD := Color("9b241c")
const Ring = preload("res://scripts/fort_ui_ring.gd")
const FX_ICON := {"tax_k": "chest", "happy": "family", "need_radius": "need_services", "need_weight": "need_food", "shop_income": "chest", "build_cost": "build", "upkeep": "worker", "rp_rate": "research", "arrivals": "family", "arrival_class": "worker", "work_output": "craft", "goods_price": "need_goods", "tourists": "map", "festival_happy": "star", "legion_gate": "soldier", "legion_rations": "need_food", "legion_denarii": "chest"}
const ADVICE := {"censura": "Открыта Цензура: выберите курс города", "aedilitas": "Открыт Эдилитет: выберите курс города", "quaestura": "Открыта Квестура: выберите курс города", "praetura": "Открыта Претура: выберите курс города", "tribunus": "Открыт Военный трибунат: выберите курс города", "pontificatus": "Открыт Понтификат: выберите курс города"}
var hud: Hud
var city: City
var frame: Panel
var columns: Control
var top_button: Button
var popup: Control
var popup_panel: Panel
var preview_label: Label
var selected := ""
var cards := {}
var style_textures := {}


static func of(h: Hud) -> MagisUI:
	return h.root.get_node_or_null("MagisUI") as MagisUI if h != null and h.root != null else null


static func attach(h: Hud) -> MagisUI:
	var u := of(h)
	if u == null:
		u = MagisUI.new()
		u.setup(h)
	return u


static func close_for(h: Hud) -> void:
	var u := of(h)
	if u != null:
		u.close()


static func advise(h: Hud) -> bool:
	var c: City = h.game.city
	for m: Dictionary in Defs.MAGIS:
		var key := "magis_open_" + String(m["id"])
		if Magis.is_open(c, String(m["id"])) and not c.tips.has(key):
			c.tips[key] = true
			h.advisor(String(ADVICE[m["id"]]), "Выберите эдикт. Он займёт место и вступит в силу через несколько игровых часов.")
			return true
	return false


func setup(h: Hud) -> void:
	hud = h
	city = h.game.city
	name = "MagisUI"
	h.root.add_child(self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()
	var shade := ColorRect.new()
	shade.color = Color(0.12, 0.06, 0.02, 0.58)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			close())
	frame = Panel.new()
	frame.name = "MagisWindow"
	frame.size = Vector2(920, 496)
	frame.add_theme_stylebox_override("panel", _style("panels/card_frame", 24))
	add_child(frame)
	var ribbon := _image("panels/ribbon_title", Rect2(254, 5, 412, 44))
	frame.add_child(ribbon)
	_label(frame, "Магистратуры", Rect2(270, 10, 380, 30), 23, true)
	var x := _button("", close, "red")
	x.position = Vector2(872, 8)
	x.size = Vector2(36, 36)
	x.icon = _texture("buttons/close_btn")
	x.expand_icon = true
	x.tooltip_text = I18n.t("Закрыть")
	frame.add_child(x)
	columns = Control.new()
	columns.name = "MagisColumns"
	columns.position = Vector2(22, 56)
	columns.size = Vector2(876, 416)
	frame.add_child(columns)
	_label(frame, "С уровня «Город» — два места в каждой магистратуре", Rect2(100, 473, 720, 18), 12)
	top_button = _button("", open, "cream")
	top_button.name = "MagisButton"
	top_button.custom_minimum_size = Vector2(h.TOP_BTN, h.TOP_BTN)
	top_button.add_theme_stylebox_override("normal", _style("buttons/round_frame", 20))
	top_button.icon = icon("magis_censura")
	top_button.expand_icon = true
	top_button.tooltip_text = I18n.t("Магистратуры")
	h.top_panel.add_child(top_button)
	h.top_panel.move_child(top_button, h.top_btns["research"].get_parent().get_index() + 1)
	h.top_btns["magis"] = top_button
	city.changed.connect(refresh)
	resized.connect(_layout)
	refresh()


func _texture(path: String) -> Texture2D:
	return load(KIT + path + ".png") as Texture2D


func icon(id: String) -> Texture2D:
	var path := ART + id + ".png"
	return load(path) as Texture2D if ResourceLoader.exists(path) else _texture("icons/tasks")


func _style(path: String, margin := 12) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	if not style_textures.has(path):
		# Исходный комплект крупный: уменьшаем рамку до масштаба интерфейса перед 9-slice.
		var source := _texture(path).get_image()
		if source.is_compressed():
			source.decompress()
		source.resize(maxi(1, source.get_width() / 4), maxi(1, source.get_height() / 4), Image.INTERPOLATE_LANCZOS)
		source.generate_mipmaps()
		style_textures[path] = ImageTexture.create_from_image(source)
	style.texture = style_textures[path]
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, margin)
		style.set_content_margin(side, 4)
	return style


func _image(path: String, rect: Rect2) -> TextureRect:
	var view := TextureRect.new()
	view.texture = _texture(path)
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.position = rect.position
	view.size = rect.size
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return view


func _label(parent: Control, text: String, rect: Rect2, pixels := 13, bold := false) -> Label:
	var label := hud._label(I18n.t(text), pixels, bold, INK)
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _button(text: String, action: Callable, color := "cream") -> Button:
	var b := Button.new()
	b.text = I18n.t(text)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_color_override("font_disabled_color", Color("806649"))
	b.add_theme_font_size_override("font_size", 16)
	for state: String in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(state, _style("buttons/btn_" + color, 14))
	b.add_theme_stylebox_override("focus", _style("buttons/btn_gold", 14))
	if color == "cream":
		b.add_theme_stylebox_override("hover", _style("buttons/btn_gold", 14))
	b.add_theme_stylebox_override("pressed", _style("buttons/btn_" + color + "_pressed", 14))
	b.add_theme_stylebox_override("disabled", _style("buttons/btn_disabled", 14))
	b.pressed.connect(action)
	return b


func open() -> void:
	if city.level < 1:
		return
	hud._close_windows()
	hud._close_tray()
	hud._hide_info()
	hud.root.move_child(self, hud.root.get_child_count() - 1)
	show()
	refresh()
	(cards[Defs.MAGIS[0]["edicts"][0]["id"]] as Button).grab_focus()


func close() -> void:
	_close_popup()
	hide()


func _layout() -> void:
	if frame == null:
		return
	var factor := minf(1.0, minf((size.x - 32.0) / 920.0, (size.y - 32.0) / 496.0))
	frame.scale = Vector2.ONE * maxf(0.1, factor)
	frame.position = (size - frame.size * frame.scale) * 0.5
	if is_instance_valid(popup_panel):
		popup_panel.scale = frame.scale
		popup_panel.position = (size - popup_panel.size * popup_panel.scale) * 0.5


func refresh() -> void:
	top_button.visible = city.level >= 1 and hud.game.mode in ["new", "play"] and not hud.clean
	if not visible:
		return
	for child in columns.get_children():
		columns.remove_child(child)
		child.queue_free()
	cards.clear()
	for i in Defs.MAGIS.size():
		_column(Defs.MAGIS[i], i)
	_layout()
	if selected != "":
		_popup(selected)


func _column(m: Dictionary, index: int) -> void:
	var column := Control.new()
	column.name = String(m["id"])
	column.position = Vector2(index * 146, 0)
	column.size = Vector2(142, 416)
	columns.add_child(column)
	var opened := Magis.is_open(city, String(m["id"]))
	var medallion := _image("buttons/round_frame", Rect2(48, 0, 46, 46))
	medallion.texture = icon(String(m["icon"]))
	column.add_child(medallion)
	_label(column, String(m["name"]), Rect2(0, 44, 142, 34), 15, true)
	var occupied := Magis.occupied(city, String(m["id"]))
	for slot in (2 if opened else 0):
		var at := Vector2(36 + slot * 38, 80)
		var button := _button("", func():
			if slot < occupied.size():
				_popup(String(occupied[slot])))
		button.position = at
		button.size = Vector2(32, 32)
		button.add_theme_stylebox_override("normal", _style("panels/slot_round", 10))
		button.icon = _texture("icons/plus" if opened and slot < Magis.seats(city) else "icons/lock")
		button.expand_icon = true
		button.tooltip_text = I18n.t("Свободное место") if slot < Magis.seats(city) else I18n.t("Второе место — с уровня «Город»")
		column.add_child(button)
		if slot < occupied.size():
			var id := String(occupied[slot])
			button.icon = icon(id)
			var left := int(city.magis_orders[id]["left"])
			button.tooltip_text = I18n.t(String(Magis.edict(id)["name"]))
			if left > 0:
				var ring := Ring.new()
				ring.size = Vector2(36, 36)
				ring.position = Vector2(-2, -2)
				ring.value = 1.0 - float(left) / float(Magis.edict(id)["hours"])
				ring.tint = Color("ffb51c")
				button.add_child(ring)
				button.tooltip_text += " · " + (I18n.t("Через %d ч") % left)
	for i in 3:
		_card(column, m["edicts"][i], i, opened)
	if not opened:
		medallion.modulate = Color("9d907c")
		column.add_child(_image("icons/lock", Rect2(57, 7, 28, 28)))
		column.add_child(_image("buttons/level_badge", Rect2(3, 84, 25, 25)))
		var rank_label := _label(column, String(Defs.LEVELS[int(m["rank"])]["name"]), Rect2(24, 86, 110, 22), 12, true)
		rank_label.add_theme_color_override("font_color", BAD)


func _card(column: Control, e: Dictionary, index: int, opened: bool) -> void:
	var id := String(e["id"])
	var active := Magis.active(city, id)
	var b := _button("", func(): _popup(id), "green" if active else "cream")
	b.name = "Edict_" + id
	b.position = Vector2(4, 118 + index * 98)
	b.size = Vector2(134, 94)
	b.tooltip_text = I18n.t(String(e["text"]))
	column.add_child(b)
	cards[id] = b
	if not opened:
		b.modulate = Color(0.66, 0.64, 0.59)
	var art := _image("icons/tasks", Rect2(7, 7, 35, 35))
	art.texture = icon(id)
	b.add_child(art)
	_label(b, String(e["name"]), Rect2(45, 5, 82, 38), 13, true)
	var fx: Dictionary = e["fx"]
	var idx := 0
	for key: String in fx:
		var value := float(fx[key])
		var addition := key.begins_with("happy:") or key == "legion_denarii"
		var delta := value if addition and key != "legion_denarii" else (value * 100.0 if key == "legion_denarii" else (value - 1.0) * 100.0)
		var positive := delta > 0.0
		var good := not positive if key in ["upkeep", "build_cost", "legion_rations", "legion_denarii"] or key.begins_with("need_weight:") else positive
		var x := 6.0 + idx * (122.0 / fx.size())
		var image := _image("icons/" + String(FX_ICON[key.get_slice(":", 0)]), Rect2(x, 47, 15, 15))
		b.add_child(image)
		var number := ("+" if positive else "−") + str(roundi(absf(delta))) + ("" if key.begins_with("happy:") else "%")
		var l := _label(b, number, Rect2(x + 14, 45, 122.0 / fx.size() - 14, 20), 11, true)
		l.add_theme_color_override("font_color", GOOD if good else BAD)
		idx += 1
	var price := _image("panels/topbar_pill", Rect2(18, 70, 98, 19))
	b.add_child(price)
	var text := str(e["cost"])
	if city.magis_orders.has(id):
		var left := int(city.magis_orders[id]["left"])
		text = (I18n.t("Через %d ч") % left) if left > 0 else I18n.t("Действует")
	elif int(city.magis_cooldown.get(id, 0)) > 0:
		text = I18n.t("%d ч") % int(city.magis_cooldown[id])
	else:
		b.add_child(_image("icons/chest", Rect2(22, 71, 16, 16)))
	_label(b, text, Rect2(22, 69, 92, 21), 11, true)


func _close_popup() -> void:
	selected = ""
	if is_instance_valid(popup):
		remove_child(popup)
		popup.queue_free()
	popup = null
	popup_panel = null


func _popup(id: String) -> void:
	_close_popup()
	selected = id
	var e := Magis.edict(id)
	popup = Control.new()
	popup.name = "EdictPopup"
	add_child(popup)
	popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.12, 0.06, 0.02, 0.5)
	popup.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			_close_popup())
	popup_panel = Panel.new()
	popup_panel.size = Vector2(530, 338)
	popup_panel.add_theme_stylebox_override("panel", _style("panels/card_frame", 24))
	popup.add_child(popup_panel)
	var art := _image("icons/tasks", Rect2(22, 17, 56, 56))
	art.texture = icon(id)
	popup_panel.add_child(art)
	_label(popup_panel, String(e["name"]), Rect2(82, 22, 390, 43), 22, true)
	var x := _button("", _close_popup, "red")
	x.icon = _texture("buttons/close_btn")
	x.expand_icon = true
	x.position = Vector2(478, 15)
	x.size = Vector2(32, 32)
	popup_panel.add_child(x)
	_label(popup_panel, String(e["text"]), Rect2(26, 77, 478, 42), 15)
	var lines := [I18n.t("Было → стало")]
	for row: Dictionary in MagisPreview.rows(city, id):
		lines.append("%s: %s → %s%s" % [row["label"], Hud.fmt_rate(float(row["before"])), Hud.fmt_rate(float(row["after"])), row["unit"]])
	if id == "trib_war_chest":
		lines.append(I18n.t("Казна Легиона: %s") % Hud.fmt_rate(city.magis_treasury))
	preview_label = _label(popup_panel, "\n".join(lines), Rect2(30, 122, 470, 91), 15, true)
	preview_label.name = "EdictPreview"
	var adopted := city.magis_orders.has(id)
	var pending := adopted and int(city.magis_orders[id]["left"]) > 0
	var reason := Magis.can_adopt(city, id) if not adopted else ""
	var timing := I18n.t("Вступит в силу через %d ч") % int(e["hours"])
	if adopted:
		timing = (I18n.t("Вступит в силу через %d ч") % int(city.magis_orders[id]["left"])) if pending else I18n.t("Действует до отмены")
	if reason != "":
		timing = I18n.t(reason)
	_label(popup_panel, timing, Rect2(28, 219, 474, 27), 14, true)
	var label := I18n.t("Отменить · вернуть %d") % int(e["cost"]) if pending else (I18n.t("Отменить") if adopted else I18n.t("Принять · %d") % int(e["cost"]))
	var action := func() -> void:
		if adopted:
			Magis.cancel(city, id)
		else:
			Magis.adopt(city, id)
	var accept := _button(label, action, "red" if adopted else "green")
	accept.name = "EdictAction"
	accept.position = Vector2(116, 253)
	accept.size = Vector2(298, 43)
	accept.disabled = not adopted and reason != ""
	popup_panel.add_child(accept)
	_label(popup_panel, "После отмены повторное принятие — через 24 ч", Rect2(26, 302, 478, 20), 12)
	_layout()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		if is_instance_valid(popup):
			_close_popup()
		else:
			close()
		get_viewport().set_input_as_handled()
