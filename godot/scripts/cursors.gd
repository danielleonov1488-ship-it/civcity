extends RefCounted
## Рисованные курсоры игры (лист владельца из ChatGPT assets/incoming/ui_ai/raw/57_cursors.webp →
## assets/ui/ai/cursors/<имя>.png, 128×128 с прозрачным фоном; нарезка — .work/py/cursors_slice.py).
## Все нарезаны в ОДНОМ масштабе: у всех стрелок кончик в одной точке картинки, поэтому при смене
## «стрелка → стрелка с плюсом → красная стрелка» стрелка не прыгает и не меняет размер.
## Подключение: const Cursors := preload("res://scripts/cursors.gd"); Cursors.put(Input.CURSOR_ARROW, "build", px)

const DIR := "res://assets/ui/ai/cursors/"
const SRC := 128.0
## Сторона картинки курсора в логических точках (база окна 1600×900): в 1920×1080 это 50 px, сама стрелка ≈ 39 px;
## растёт вместе с размером окна и ползунком «Размер интерфейса»
const BASE := 42.0

## Горячая точка (куда «щёлкает» курсор) в точках картинки 128×128: у стрелок — кончик, у руки — кончик пальца,
## у песочных часов, стрелок-растяжек, прицела, знака «нельзя» — середина, у лупы — середина стекла
const HOT := {
	"arrow": Vector2(11.4, 11.4), "arrow_glow": Vector2(11.4, 11.4), "arrow_red": Vector2(11.4, 11.4), "arrow_grey": Vector2(11.4, 11.4),
	"hand": Vector2(40.6, 14.3), "hand_glow": Vector2(40.6, 14.3), "hand_red": Vector2(40.6, 14.3), "hand_grey": Vector2(40.6, 14.3),
	"wait": Vector2(64, 64), "wait_glow": Vector2(64, 64), "wait_red": Vector2(64, 64), "wait_grey": Vector2(64, 64),
	"move": Vector2(64, 64), "resize_v": Vector2(64, 64), "resize_h": Vector2(64, 64), "forbidden": Vector2(64, 64),
	"monument": Vector2(11.4, 11.4), "build": Vector2(11.4, 11.4), "demolish": Vector2(11.4, 11.4), "stone": Vector2(11.4, 11.4),
	"tree": Vector2(11.4, 11.4), "wheat": Vector2(11.4, 11.4), "road": Vector2(11.4, 11.4), "water": Vector2(11.4, 11.4),
	"hammer": Vector2(11.4, 11.4), "shovel": Vector2(11.4, 11.4), "brush": Vector2(11.4, 11.4), "scroll": Vector2(11.4, 11.4),
	"coin": Vector2(11.4, 11.4), "people": Vector2(11.4, 11.4), "sword": Vector2(11.4, 11.4), "cross": Vector2(64, 64),
	"cross2": Vector2(64, 64), "magnifier": Vector2(64, 64), "rotate": Vector2(64, 64), "resize_diag": Vector2(64, 64),
	"speech": Vector2(64, 64), "help": Vector2(64, 64),
}

static var _cache := {}                 # "имя:px" → Image
static var _on := {}                    # форма курсора → "имя:px", что уже поставлено (ставим только при смене)


## Размер картинки курсора в пикселях экрана для этого окна (с учётом растяжения и «Размера интерфейса»)
static func size_for(vp: Viewport) -> int:
	var s := vp.get_final_transform().get_scale().x if vp else 1.0
	return int(clampf(roundf(BASE * s), 24.0, 160.0))


## Картинка курсора нужного размера (нет такой — обычная стрелка)
static func image(key: String, px: int) -> Image:
	var ck := "%s:%d" % [key, px]
	if _cache.has(ck):
		return _cache[ck]
	var path := DIR + key + ".png"
	if not HOT.has(key) or not ResourceLoader.exists(path):
		path = DIR + "arrow.png"
	var img: Image = null
	if ResourceLoader.exists(path):
		img = (load(path) as Texture2D).get_image()
		if img.is_compressed():
			img.decompress()
		img.clear_mipmaps()
		img.convert(Image.FORMAT_RGBA8)
		img.resize(px, px, Image.INTERPOLATE_LANCZOS)
	_cache[ck] = img
	return img


## Поставить для формы курсора shape (Input.CURSOR_*) рисованный курсор key размера px. Повтор того же — ничего не делает
static func put(shape: Input.CursorShape, key: String, px: int) -> void:
	if not HOT.has(key):
		key = "arrow"
	var sig := "%s:%d" % [key, px]
	if _on.get(shape, "") == sig:
		return
	var img := image(key, px)
	if img == null:
		return
	_on[shape] = sig
	Input.set_custom_mouse_cursor(img, shape, (HOT[key] as Vector2) * float(px) / SRC)


## Что сейчас стоит на форме shape ("" — курсор Windows)
static func current(shape: Input.CursorShape) -> String:
	return String(_on.get(shape, "")).get_slice(":", 0)


## Песочные часы, пока игра грузится (интерфейса ещё нет)
static func wait(n: Node) -> void:
	put(Input.CURSOR_ARROW, "wait", size_for(n.get_viewport() if n.is_inside_tree() else null))
