class_name Clouds
extends Node3D
## Тени облаков (план 24.10, K-own-22): по городу медленно плывут мягкие тени, как в летний день.
## Девять больших Decal (3×3) с одной бесшовной картинкой шума идут за камерой и сдвигаются ветром; тень чуть темнит
## и холодит цвет земли, домов, деревьев и жителей. Вызовов отрисовки не добавляет (Decal ложится в уже идущий проход).
## Только на «Высокой» и «Средней»: на «Низкой» и «Очень низкой» облаков нет (Gfx.apply); ночью тени нет.
## Сверка картинки «Средней»/«Высокой» с эталоном (test_perf) — без облаков: на снимках Decal спрятаны (_freeze).

const TILE := 192.0                    # одна плитка — одна картинка шума (бесшовная), 3×3 плитки вокруг камеры
const HIGH := 150.0                    # высота коробки Decal: и низина у пруда, и крыша храма
const SPEED := 1.3                     # м/с — облака плывут медленно
const WIND := Vector2(0.93, 0.37)
const STRENGTH := 0.36                 # насколько тень темнит цвет (днём)
const SHADE := Color(0.06, 0.07, 0.11)  # тень чуть синеватая — как от неба

var game
var enabled := false
var day := 1.0                         # 0 — ночь, 1 — день (game._set_hour)
var off := Vector2.ZERO                # сдвиг ветром, по модулю плитки
var tiles: Array[Decal] = []
static var _tex: ImageTexture
const TEX := 256


func _ready() -> void:
	name = "Clouds"
	var tex := texture()
	for i in 9:
		var d := Decal.new()
		d.size = Vector3(TILE, HIGH, TILE)
		d.texture_albedo = tex
		d.albedo_mix = 1.0
		d.upper_fade = 0.0
		d.lower_fade = 0.0
		d.normal_fade = 0.0
		d.modulate = Color(1, 1, 1, 0)
		add_child(d)
		tiles.append(d)
	visible = false
	_alpha()


## Бесшовный мягкий шум: прозрачное небо и пятна облаков с размытыми краями (одна картинка на всю игру).
## Картинка готова сразу (не NoiseTexture2D: та рисуется в фоне, а атлас Decal берёт её пустой)
static func texture() -> ImageTexture:
	if _tex != null:
		return _tex
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.seed = 11
	n.frequency = 0.011
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = 4
	n.fractal_gain = 0.45
	var src := n.get_seamless_image(TEX, TEX, false, false, 0.2, true)
	src.convert(Image.FORMAT_L8)
	var lum := src.get_data()
	var out := PackedByteArray()
	out.resize(TEX * TEX * 4)
	var r := int(SHADE.r * 255.0)
	var g := int(SHADE.g * 255.0)
	var b := int(SHADE.b * 255.0)
	for i in TEX * TEX:
		# небо прозрачное, облако — плотное, края мягкие
		var a := smoothstep(0.5, 0.72, lum[i] / 255.0)
		out[i * 4] = r
		out[i * 4 + 1] = g
		out[i * 4 + 2] = b
		out[i * 4 + 3] = int(a * 255.0)
	var img := Image.create_from_data(TEX, TEX, false, Image.FORMAT_RGBA8, out)
	img.generate_mipmaps()
	_tex = ImageTexture.create_from_image(img)
	return _tex


## Уровень графики: облака есть или нет (только сам узел — Decal внутри не трогаем: их прячут снимки test_perf)
func set_enabled(on: bool) -> void:
	enabled = on
	_alpha()


## Свет суток (game._set_hour): ночью теней нет, в сумерках они тают
func set_day(k: float) -> void:
	day = clampf(k, 0.0, 1.0)
	_alpha()


func _alpha() -> void:
	var a := STRENGTH * smoothstep(0.15, 0.85, day)
	visible = enabled and a > 0.01
	for d in tiles:
		d.modulate = Color(1, 1, 1, a)


func _process(dt: float) -> void:
	if not visible or game == null or game.rig == null:
		return
	off = Vector2(fposmod(off.x + WIND.x * SPEED * dt, TILE), fposmod(off.y + WIND.y * SPEED * dt, TILE))
	place(game.rig.target)


## Плитки вокруг точки t: средняя — та, в которой t (до края картинки не меньше TILE в любую сторону)
func place(t: Vector3) -> void:
	var bx := floorf((t.x - off.x) / TILE) * TILE + off.x
	var bz := floorf((t.z - off.y) / TILE) * TILE + off.y
	for j in 3:
		for i in 3:
			tiles[j * 3 + i].global_position = Vector3(bx + (i - 1) * TILE + TILE * 0.5, t.y + 25.0, bz + (j - 1) * TILE + TILE * 0.5)
