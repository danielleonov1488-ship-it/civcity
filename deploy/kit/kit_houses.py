# CivCity — все дома игры из своего набора деталей (Blender 4.5, без окна). Владелец 11.11: «переделал бы все дома
# на новые». Из образца house_kit.py: тот же стиль (крупная черепица tegula+imbrex, рисованная штукатурка, угловые
# камни, окна в глубине стены, ставни на петлях, комнаты внутри), но:
#  - выгрузка для игры: по .glb на облик и этажность (House — всё неподвижное, Walls — штукатурка без цвета: игра
#    красит её цветом дома, Rooms — комнаты, Embers — угольки, Notice/Frieze — роспись);
#  - ставни и двери — общие для всех домов (common.glb, ось на петле): в игре одна MultiMesh на вид створки;
#  - kit.json — для игры: где створки (и как открыты), дверь, след на земле, стены для настенных украшений, насесты.
#
#   bash tools/blender.sh -b --factory-startup -P deploy/kit/kit_houses.py -- [kinds=pleb,artisan,patrician]
#       [only=pleb_0_2,…] [out=godot/assets/kit/houses] [png=1 preview=D:/CivCity/.work/kit/prev]
#
# Координаты в коде — как в игре: x вправо, y вверх, z к улице (дверь на +z). Метры игры (этаж 2,1 м, человечек 1,1 м).
import bpy, bmesh, math, random, sys, os, json, zlib, colorsys
from mathutils import Vector, Matrix

ARGS = {}
if "--" in sys.argv:
    for a in sys.argv[sys.argv.index("--") + 1:]:
        if "=" in a:
            k, v = a.split("=", 1)
            ARGS[k] = v

OUT_DIR = ARGS.get("out", "D:/CivCity/.work/lanes/a/godot/assets/kit/houses")
KINDS = ARGS.get("kinds", "pleb,artisan,patrician").split(",")
ONLY = [x for x in ARGS.get("only", "").split(",") if x]
PNG = ARGS.get("png", "0") == "1"
PREV = ARGS.get("preview", "D:/CivCity/.work/kit/prev")
TEX = ARGS.get("tex", "D:/CivCity/.work/kit/tex")
META_ONLY = ARGS.get("meta_merge", "1") == "1"       # дописывать kit.json (а не затирать), если выгружаем часть

FLH = 2.1
PL = 0.24
T = 0.22

# материалы деталей (номер слота в MB): дерево и ткань — с развёрткой в метрах (картинка-множитель × цвет вершин),
# вывеска — клетка общей картинки signs.png
M_KIT, M_PLASTER, M_WOOD, M_CLOTH, M_SIGN, M_FRESCO, M_MARBLE, M_STONE, M_BANNER, M_ASHM = 0, 1, 2, 3, 4, 5, 6, 7, 8, 9
TS = {M_WOOD: 0.9, M_CLOTH: 0.42, M_MARBLE: 0.8, M_STONE: 0.9, M_ASHM: 1.6}       # сколько метров на одну картинку
_uvr = random.Random(7)                 # сдвиги развёртки — свой поток (облик домов от этого не меняется)

# ---- текущий дом (configure) ----
KIND = "pleb"
V = 0
FLOORS = 1
W = 3.6
D = 4.2
HT = PL + FLH
rng = random.Random(1)
PH = [0.0] * 5
P = {}
DS = {}
MOV = []            # створки: {"mesh": имя в common, "o": [x,y,z], "x":[..], "y":[..], "z":[..], "kind", "open"}
CANON = {}          # имя створки → параметры (для common.glb)
FACES = {}          # сторона → {"n","a","d","bound","block"}
EXTRA_BLOCK = {}    # сторона → [[u, y, w, h]]
LIGHTS = []
PERCH = []
DOOR_PT = [0, 0, 0]
FP = []


def seed_of(*parts):
    return zlib.crc32("|".join(str(p) for p in parts).encode("utf-8"))


def use(key):
    """свой поток случайности на кусок дома: первый этаж не меняется, когда дом растёт"""
    global rng
    rng = random.Random(seed_of(KIND, V, key))


def lin(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple((x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4) for x in c) + (1.0,)


def col(h, dv=0.0, dh=0.0, ds=0.0):
    h = h.lstrip("#")
    r, g, b = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    hh, ss, vv = colorsys.rgb_to_hsv(r, g, b)
    hh = (hh + dh) % 1.0
    ss = min(1.0, max(0.0, ss * (1.0 + ds)))
    vv = min(1.0, max(0.0, vv * (1.0 + dv)))
    r, g, b = colorsys.hsv_to_rgb(hh, ss, vv)
    return lin("#%02x%02x%02x" % (int(r * 255), int(g * 255), int(b * 255)))


def J(h, v=0.08, hue=0.01, s=0.08):
    return col(h, rng.uniform(-v, v), rng.uniform(-hue, hue), rng.uniform(-s, s))


def col_shift(c, dv):
    return (c[0] * (1 + dv), c[1] * (1 + dv), c[2] * (1 + dv), 1.0)


# ---------------- построитель сетки ----------------
class MB:
    def __init__(self, name, mats=None):
        self.name = name
        self.bm = bmesh.new()
        self.cl = self.bm.loops.layers.float_color.new("Col")
        self.uvl = self.bm.loops.layers.uv.new("UVMap")
        self.mats = mats if mats is not None else [MAT_KIT, MAT_PLASTER, MAT_WOOD, MAT_CLOTH, MAT_SIGN, MAT_FRESCO, MAT_MARBLE, MAT_STONE, MAT_BANNER, MAT_ASHM]

    @staticmethod
    def bl(p):
        return Vector((p[0], -p[2], p[1]))

    def v(self, p):
        return self.bm.verts.new(self.bl(p))

    def face(self, vs, c, out=None, uv=None, mat=0):
        try:
            f = self.bm.faces.new(vs)
        except ValueError:
            return None
        f.normal_update()
        if out is not None:
            kind, q = out
            q = self.bl(q) if kind in ("from", "to") else Vector((q[0], -q[2], q[1]))
            ctr = f.calc_center_median()
            d = (ctr - q) if kind == "from" else ((q - ctr) if kind == "to" else q)
            if f.normal.dot(d) < 0:
                f.normal_flip()
        flipped = [l.vert for l in f.loops] != list(vs)
        for i, l in enumerate(f.loops):
            k = vs.index(l.vert) if flipped else i
            l[self.cl] = c[k] if isinstance(c, list) else c
            if uv is not None:
                l[self.uvl].uv = uv[k]
        f.material_index = mat
        return f

    def box(self, ctr, size, c, rot=None, cols=None, skip=(), mat=0, ts=None):
        hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
        uvon = mat in TS
        if uvon:
            ts = ts or TS[mat]
            grain = max(range(3), key=lambda i: size[i])       # волокна — вдоль длинной стороны
            ou, ov = _uvr.random(), _uvr.random()
        R = rot or Matrix.Identity(3)
        C = Vector(ctr)
        pts = {}
        for sx in (-1, 1):
            for sy in (-1, 1):
                for sz in (-1, 1):
                    pts[(sx, sy, sz)] = self.v(C + R @ Vector((sx * hx, sy * hy, sz * hz)))
        F = {
            "px": [(1, -1, -1), (1, 1, -1), (1, 1, 1), (1, -1, 1)],
            "nx": [(-1, -1, -1), (-1, -1, 1), (-1, 1, 1), (-1, 1, -1)],
            "top": [(-1, 1, -1), (-1, 1, 1), (1, 1, 1), (1, 1, -1)],
            "bot": [(-1, -1, -1), (1, -1, -1), (1, -1, 1), (-1, -1, 1)],
            "pz": [(-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)],
            "nz": [(-1, -1, -1), (-1, 1, -1), (1, 1, -1), (1, -1, -1)],
        }
        AX = {"px": (1, 2), "nx": (1, 2), "top": (0, 2), "bot": (0, 2), "pz": (0, 1), "nz": (0, 1)}
        for k, idx in F.items():
            if k in skip:
                continue
            cc = (cols or {}).get(k, c)
            uv = None
            if uvon:
                a, b = AX[k]
                if b == grain:
                    a, b = b, a
                uv = [(ou + q[a] * size[a] / 2 / ts, ov + q[b] * size[b] / 2 / ts) for q in idx]
            self.face([pts[i] for i in idx], cc, ("from", C), uv=uv, mat=mat)
        return pts

    def lathe(self, at, prof, seg, c, cols=None, close_top=False, mat=0, ts=None):
        uvon = mat in TS
        if uvon:
            ts = ts or TS[mat]
            circ = 2 * math.pi * max(r for r, _ in prof)
            ou = _uvr.random()
        rings = []
        for k, (r, y) in enumerate(prof):
            ring = []
            for s in range(seg):
                a = 2 * math.pi * s / seg
                ring.append(self.v((at[0] + r * math.cos(a), at[1] + y, at[2] + r * math.sin(a))))
            rings.append(ring)
        for k in range(len(rings) - 1):
            cc = cols[k] if cols else c
            for s in range(seg):
                t = (s + 1) % seg
                a, b, d, e = rings[k][s], rings[k][t], rings[k + 1][t], rings[k + 1][s]
                mid = (at[0], at[1] + (prof[k][1] + prof[k + 1][1]) / 2, at[2])
                uv = None
                if uvon:          # волокна — по высоте (клёпки бочки, стенки миски)
                    c0, c1 = ou + s / seg * circ / ts, ou + (s + 1) / seg * circ / ts
                    y0, y1 = prof[k][1] / ts, prof[k + 1][1] / ts
                    uv = [(y0, c0), (y0, c1), (y1, c1), (y1, c0)]
                self.face([a, b, d, e], cc, ("from", mid), uv=uv, mat=mat)
        self.face(rings[0][::-1], c, ("dir", (0, -1, 0)), mat=mat)
        if close_top:
            self.face(rings[-1], cols[-1] if cols else c, ("dir", (0, 1, 0)), mat=mat)

    def empty(self):
        return len(self.bm.faces) == 0

    def obj(self, coll):
        me = bpy.data.meshes.new(self.name)
        self.bm.normal_update()
        self.bm.to_mesh(me)
        self.bm.free()
        ob = bpy.data.objects.new(self.name, me)
        coll.objects.link(ob)
        for m in self.mats:
            ob.data.materials.append(m)
        return ob


def RW(U, N):
    return Matrix((U, Vector((0, 1, 0)), N)).transposed()


def Pw(P_, u, v, n):
    p = P_(u, v, n)
    return (p.x, p.y, p.z)


# ---------------- материалы (в игре их подменяет KitLib по имени) ----------------
def make_mat(name, rough=0.85, emit=None):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    attr = nt.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Col"
    nt.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = rough
    if emit:
        bsdf.inputs["Emission Color"].default_value = emit
        bsdf.inputs["Emission Strength"].default_value = 2.0
    # крошечная белая картинка × цвет вершин (Mix Multiply): так glTF пишет и COLOR_0, и текстуру, а импорт Godot
    # с текстурой не выбрасывает цвет вершин (без неё — выбрасывал, а он здесь — весь цвет)
    if name not in ("CivPlaster", "CivWood", "CivCloth", "CivSign", "CivFresco", "CivMarble", "CivStone", "CivBanner", "CivAshlarT", "CivAshlarM", "CivBrickW"):     # у этих — своя картинка × цвет вершин
        img = nt.nodes.new("ShaderNodeTexImage")
        img.name = "WhiteTex"
        img.image = white_image()
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "MULTIPLY"
        mix.inputs["Factor"].default_value = 1.0
        nt.links.new(img.outputs["Color"], mix.inputs[6])
        nt.links.new(attr.outputs["Color"], mix.inputs[7])
        nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
    return m


def make_tex_mat(name, img_file, rough):
    """цвет вершин × картинка-множитель (дерево, ткань, вывески); в игре — KitLib с той же картинкой"""
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = make_mat(name, rough)
    nt = m.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    vc = [n for n in nt.nodes if n.type == "VERTEX_COLOR"][0]
    img = nt.nodes.new("ShaderNodeTexImage")
    path = os.path.join(TEX, img_file)
    img.image = bpy.data.images.load(path) if os.path.exists(path) else white_image()
    img.name = "DetailTex"
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs["Factor"].default_value = 1.0
    nt.links.new(vc.outputs["Color"], mix.inputs[6])
    nt.links.new(img.outputs["Color"], mix.inputs[7])
    nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
    return m


def white_image():
    im = bpy.data.images.get("civ_white")
    if im is None:
        im = bpy.data.images.new("civ_white", 4, 4)
        im.pixels = [1.0] * 64
        im.pack()
    return im


_SAVED_IMG = {}


def kit_for_export(on):
    """для выгрузки все картинки (штукатурка, роспись) временно — крошечные белые: в игре материалы общие (KitLib
    подставляет свои картинки по имени материала), а в каждом .glb копия картинки лишь раздувала бы файл"""
    for m in bpy.data.materials:
        if not m.use_nodes:
            continue
        for n in m.node_tree.nodes:
            if n.type == "TEX_IMAGE" and n.name != "WhiteTex":
                key = (m.name, n.name)
                if on:
                    _SAVED_IMG[key] = n.image
                    n.image = white_image()
                elif key in _SAVED_IMG:
                    n.image = _SAVED_IMG.pop(key)
    return
    for m in bpy.data.materials:
        if not m.use_nodes or "WhiteTex" not in m.node_tree.nodes:
            continue
        nt = m.node_tree
        bsdf = nt.nodes["Principled BSDF"]
        if on:
            nt.links.new(nt.nodes["WhiteTex"].outputs["Color"], bsdf.inputs["Base Color"])
        else:
            vc = [n for n in nt.nodes if n.type == "VERTEX_COLOR"][0]
            nt.links.new(vc.outputs["Color"], bsdf.inputs["Base Color"])


def make_plaster_mat():
    m = bpy.data.materials.get("CivPlaster")
    if m:
        return m
    m = make_mat("CivPlaster", 0.9)
    nt = m.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    vc = [n for n in nt.nodes if n.type == "VERTEX_COLOR"][0]
    img = nt.nodes.new("ShaderNodeTexImage")
    img.image = bpy.data.images.load(os.path.join(TEX, "plaster_mul.png"))
    img.name = "PlasterTex"
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs["Factor"].default_value = 1.0
    nt.links.new(vc.outputs["Color"], mix.inputs[6])
    nt.links.new(img.outputs["Color"], mix.inputs[7])
    nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
    return m


def make_decal_mat(name, img_name, alpha):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    im = nt.nodes.new("ShaderNodeTexImage")
    im.image = bpy.data.images.load(os.path.join(TEX, img_name))
    nt.links.new(im.outputs["Color"], bsdf.inputs["Base Color"])
    if alpha:
        nt.links.new(im.outputs["Alpha"], bsdf.inputs["Alpha"])
        try:
            m.surface_render_method = "BLENDED"
        except Exception:
            pass
    bsdf.inputs["Roughness"].default_value = 0.9
    return m


# ---------------- стены ----------------
def noise2(u, v, ph):
    return (math.sin(u * 2.1 + ph[0]) * math.sin(v * 1.7 + ph[1]) * 0.5
            + math.sin(u * 5.3 + ph[2]) * math.sin(v * 4.1 + ph[3]) * 0.3
            + math.sin(u * 11.0 + v * 9.0 + ph[4]) * 0.2)


PLASTER = "#f3ebdf"          # светлая основа: цвет дома даёт игра (палитра), здесь — только пятна, грязь, подтёки
PLASTER_LOW = "#ddd0bd"      # нижняя часть стены — старая побелка, тоном темнее
ROOM = "#e6d5b8"


def wall(walls, inner, side, frame, x0, x1, y0, y1, openings, stains=(), caps=False, low=True):
    """Стена-плита: лицо в Walls (сетка ~0,3 м, неровная штукатурка), изнанка в Rooms, откосы проёмов.
    frame = (O, U, N): O — точка (u=0, v=0) на лице, U — вдоль стены, N — наружу. Записывает стену в FACES"""
    O, U, N = frame
    Yv = Vector((0, 1, 0))

    def P(u, v, n=0.0):
        return O + U * u + Yv * v + N * n

    us = set([x0, x1])
    vs = set([y0, y1])
    k = max(2, int(round((x1 - x0) / 0.3)))
    for i in range(k + 1):
        us.add(x0 + (x1 - x0) * i / k)
    k = max(2, int(round((y1 - y0) / 0.3)))
    for i in range(k + 1):
        vs.add(y0 + (y1 - y0) * i / k)
    for (a, b, c, d) in openings:
        us.update([a, b])
        vs.update([c, d])
    us = sorted(u for u in us if x0 - 1e-6 <= u <= x1 + 1e-6)
    vs = sorted(v for v in vs if y0 - 1e-6 <= v <= y1 + 1e-6)

    def tidy(arr, keep):
        out = []
        iskeep = lambda x: any(abs(x - q) < 1e-6 for q in keep)
        for x in arr:
            if out and x - out[-1] < 0.04:
                if iskeep(x) and iskeep(out[-1]):
                    out.append(x)
                elif iskeep(x):
                    out[-1] = x
                continue
            out.append(x)
        return out
    us = tidy(us, [x0, x1] + [o[0] for o in openings] + [o[1] for o in openings])
    vs = tidy(vs, [y0, y1] + [o[2] for o in openings] + [o[3] for o in openings])

    def inside(u, v):
        for (a, b, c, d) in openings:
            if a - 1e-6 <= u <= b + 1e-6 and c - 1e-6 <= v <= d + 1e-6:
                return True
        return False

    def on_edge(u, v):
        if abs(u - x0) < 1e-6 or abs(u - x1) < 1e-6 or abs(v - y0) < 1e-6 or abs(v - y1) < 1e-6:
            return True
        return inside(u, v)

    def tone(u, v):
        n = noise2(u + O.x * 0.7, v + O.z * 0.7, PH)
        c = list(col(PLASTER, n * 0.06))
        if low:
            edge = PL + 0.95 + 0.25 * noise2(u * 1.7, 0.3, PH)
            kk = min(1.0, max(0.0, (edge - v) / 0.35)) * DS.get("two_tone", 0.5)
            c2 = col(PLASTER_LOW, n * 0.06)
            c = [c[i] * (1 - kk) + c2[i] * kk for i in range(3)] + [1.0]
        g = max(0.0, 1.0 - (v - y0) / 0.55) if y0 < PL + 0.05 else 0.0
        for s in stains:
            if s[0] <= u <= s[1] and s[2] - 0.6 <= v <= s[2]:
                g = max(g, 0.55 * (1.0 - (s[2] - v) / 0.6))
        top = max(0.0, 1.0 - (y1 - v) / 0.35) * 0.35 if y1 >= HT - 0.05 else 0.0
        dk = (1.0 - 0.2 * g - 0.14 * top) * 1.13
        return (c[0] * dk, c[1] * dk * (1.0 - 0.02 * g), c[2] * dk * (1.0 - 0.07 * g), 1.0)

    uo = (O.x * 0.37 + O.z * 0.61) % 1.0

    def UVp(u, v):
        return ((u / 1.6 + uo), v / 1.6)

    vid = {}
    for i, u in enumerate(us):
        for j, v in enumerate(vs):
            jit = 0.0 if on_edge(u, v) else rng.uniform(-0.013, 0.013)
            vid[(i, j)] = (walls.v(P(u, v, jit)), tone(u, v), UVp(u, v))
    out_dir = (N.x, N.y, N.z)
    for i in range(len(us) - 1):
        for j in range(len(vs) - 1):
            cu, cv = (us[i] + us[i + 1]) / 2, (vs[j] + vs[j + 1]) / 2
            if inside(cu, cv):
                continue
            q = [vid[(i, j)], vid[(i + 1, j)], vid[(i + 1, j + 1)], vid[(i, j + 1)]]
            walls.face([e[0] for e in q], [e[1] for e in q], ("dir", out_dir), uv=[e[2] for e in q], mat=1)
            inner.face([inner.v(P(us[i], vs[j], -T)), inner.v(P(us[i + 1], vs[j], -T)),
                        inner.v(P(us[i + 1], vs[j + 1], -T)), inner.v(P(us[i], vs[j + 1], -T))],
                       J(ROOM, 0.04, 0.0, 0.0), ("dir", (-N.x, -N.y, -N.z)))
    for (a, b, c, d) in openings:
        cc = col(PLASTER, -0.12)
        ctr = P((a + b) / 2, (c + d) / 2, -T / 2)
        ctr = (ctr.x, ctr.y, ctr.z)
        for (p0, p1) in [((a, c), (b, c)), ((b, c), (b, d)), ((b, d), (a, d)), ((a, d), (a, c))]:
            walls.face([walls.v(P(p0[0], p0[1], 0)), walls.v(P(p1[0], p1[1], 0)), walls.v(P(p1[0], p1[1], -T)),
                        walls.v(P(p0[0], p0[1], -T))], cc, ("to", ctr),
                       uv=[UVp(p0[0], p0[1]), UVp(p1[0], p1[1]), (UVp(p1[0], p1[1])[0] + 0.14, UVp(p1[0], p1[1])[1]),
                           (UVp(p0[0], p0[1])[0] + 0.14, UVp(p0[0], p0[1])[1])], mat=1)
    if caps:
        for u, sgn in ((x0, -1), (x1, 1)):
            q = [P(u, y0, 0), P(u, y0, -T), P(u, y1, -T), P(u, y1, 0)]
            walls.face([walls.v(x) for x in q], [tone(u, y0), tone(u, y0), tone(u, y1), tone(u, y1)],
                       ("dir", tuple(U * sgn)), uv=[(0, y0 / 1.6), (0.14, y0 / 1.6), (0.14, y1 / 1.6), (0, y1 / 1.6)], mat=1)
    # стена для настенных украшений (WallDecor): u — вдоль a от начала координат, как в игре
    u_base = O.dot(U)
    FACES[side] = {"n": [N.x, N.y, N.z], "a": [U.x, U.y, U.z], "d": O.dot(N),
                   "bound": [u_base + x0, y0, x1 - x0, y1 - y0],
                   "block": [[u_base + a - 0.12, c - 0.1, b - a + 0.24, d - c + 0.22] for (a, b, c, d) in openings],
                   "open": [[round(u_base + a, 3), round(c, 3), round(b - a, 3), round(d - c, 3)] for (a, b, c, d) in openings]}
    return P


def block(side, P_, U, u0, u1, v0, v1):
    """выступ на стене side (навес, балкон, ящик цветов) — туда настенное украшение не вешать"""
    o = P_(0, 0, 0)
    base = o.dot(U)
    EXTRA_BLOCK.setdefault(side, []).append([base + min(u0, u1), v0, abs(u1 - u0), v1 - v0])


# ---------------- створки (общие) ----------------
SHUTTER_COLS = {"green": "#5f7f4a", "blue": "#4f6f8f", "brown": "#7a5232", "teal": "#4f8a80", "red": "#8f3f33",
                "ochre": "#b07a35"}
DOOR_COLS = {"oak": "#6b4428", "dark": "#4f3020", "green": "#4a6040", "blue": "#3f5670", "red": "#7a3528", "bronze": "#8a6a3a"}


def mov(kind, key, hinge, U, N, open_a, side=1):
    """записать створку: ось — на петле; open_a — угол раскрытия (вокруг вертикали)"""
    Rw = RW(U, N)
    sgn = side
    Ro = Matrix.Rotation(open_a * sgn, 3, "Y")
    M3 = Rw @ Ro
    cols3 = [M3.col[0], M3.col[1], M3.col[2]]
    MOV.append({"mesh": key, "kind": kind, "o": [round(hinge[0], 4), round(hinge[1], 4), round(hinge[2], 4)],
                "x": [round(c, 5) for c in cols3[0]], "y": [round(c, 5) for c in cols3[1]], "z": [round(c, 5) for c in cols3[2]],
                "open": round(open_a, 4), "side": side,
                "u": [round(U.x, 5), round(U.y, 5), round(U.z, 5)], "nrm": [round(N.x, 5), round(N.y, 5), round(N.z, 5)]})


def shutter_key(colkey, w, h, side):
    k = "sh_%s_%d_%d_%s" % (colkey, round(w * 100), round(h * 100), "L" if side < 0 else "R")
    CANON[k] = ("shutter", colkey, w, h, side, DS.get("brace", True))
    return k


def door_key(colkey, w, h, side=1):
    k = "door_%s_%d_%d" % (colkey, round(w * 100), round(h * 100)) + ("" if side > 0 else "_M")
    CANON[k] = ("door", colkey, w, h, side, False)
    return k


def build_shutter(mb, colkey, w, h, side, brace):
    base_col = SHUTTER_COLS[colkey]
    r = random.Random(seed_of("sh", colkey, w, h, side))
    jj = lambda hx, v=0.1: col(hx, r.uniform(-v, v), r.uniform(-0.01, 0.01), r.uniform(-0.1, 0.1))
    nb = 3
    for k in range(nb):
        x = (k + 0.5) * w / nb
        mb.box((x * -side, h / 2, 0.0), (w / nb - 0.008, h, 0.045), jj(base_col), mat=M_WOOD)
    for vv in (0.17, 0.83):
        mb.box((w / 2 * -side, h * vv, 0.03), (w * 0.94, 0.07, 0.022), col(base_col, -0.18), mat=M_WOOD)
    if brace:
        p0 = Vector((0.08 * -side, h * 0.22, 0.03))
        p1 = Vector(((w - 0.08) * -side, h * 0.78, 0.03))
        dl = (p1 - p0)
        ang = math.atan2(dl.y, dl.x)
        mb.box(tuple((p0 + p1) / 2), (dl.length, 0.06, 0.02), col(base_col, -0.2), Matrix.Rotation(ang, 3, "Z"), mat=M_WOOD)
    for vv in (0.17, 0.83):
        mb.box((0.02 * -side, h * vv, 0.035), (0.06, 0.03, 0.012), col("#2b2622"))


def build_door(mb, colkey, w, h, side=1):
    """створка двери: доски, планки, гвозди, кольцо; side −1 — зеркальная (правая створка парадной двери)"""
    base = DOOR_COLS[colkey]
    r = random.Random(seed_of("door", colkey, w, h))
    jj = lambda hx, v=0.1: col(hx, r.uniform(-v, v), r.uniform(-0.01, 0.01), r.uniform(-0.1, 0.1))
    nb = 4 if w > 0.45 else 3
    for k in range(nb):
        x = (k + 0.5) * w / nb
        mb.box((x * side, h / 2, 0.0), (w / nb - 0.008, h, 0.05), jj(base), mat=M_WOOD)
    for vv in (0.15, 0.5, 0.85):
        mb.box((w / 2 * side, h * vv, 0.032), (w * 0.95, 0.07, 0.02), col(base, -0.2), mat=M_WOOD)
    for k in range(nb):
        for vv in (0.15, 0.5, 0.85):
            mb.box(((k + 0.5) * w / nb * side, h * vv, 0.046), (0.018, 0.018, 0.012), col("#3a332c"))
    mb.box((w * 0.78 * side, h * 0.52, 0.06), (0.05, 0.05, 0.02), col("#8a6a35"))


# ---------------- детали фасада ----------------
def window(body, P_, U, N, side, u0, u1, v0, v1, shutters=True, box=False, grille=False, surround=False, open_k=None, hood=False):
    w = u1 - u0
    h = v1 - v0
    Rw = RW(U, N)
    if hood:
        # фронтончик над окном: два ската из светлого камня на полочке
        ct = J(P["trim"], 0.04)
        body.box(Pw(P_, (u0 + u1) / 2, v1 + 0.16, 0.06), (w + 0.34, 0.06, 0.12), ct, Rw)
        for sgn in (-1, 1):
            ang = math.radians(20) * sgn
            body.box(Pw(P_, (u0 + u1) / 2 + sgn * (w + 0.34) / 4, v1 + 0.24, 0.06), ((w + 0.34) / 2 / math.cos(math.radians(20)) + 0.02, 0.05, 0.12),
                     ct, Rw @ Matrix.Rotation(-ang, 3, "Z"))
    fr = 0.045
    dep = -0.07
    c_w = J(P["wood"], 0.06)
    if surround:
        ct = J(P["trim"], 0.04)
        for uu in (u0 - 0.045, u1 + 0.045):
            body.box(Pw(P_, uu, (v0 + v1) / 2 + 0.03, 0.03), (0.09, h + 0.1, 0.06), ct, Rw)
        body.box(Pw(P_, (u0 + u1) / 2, v1 + 0.07, 0.04), (w + 0.26, 0.12, 0.08), ct, Rw, cols={"top": J(P["trim"], 0.1)})
    for (cu, cv, su, sv) in [(u0 + fr / 2, (v0 + v1) / 2, fr, h), (u1 - fr / 2, (v0 + v1) / 2, fr, h),
                             ((u0 + u1) / 2, v0 + fr / 2, w, fr), ((u0 + u1) / 2, v1 - fr / 2, w, fr),
                             ((u0 + u1) / 2, (v0 + v1) / 2, 0.03, h - 2 * fr)]:
        body.box(Pw(P_, cu, cv, dep), (su, sv, 0.05), c_w, Rw, mat=M_WOOD)
    if grille:
        for k in range(1, 3):
            body.box(Pw(P_, (u0 + u1) / 2, v0 + h * k / 3, dep), (w, 0.025, 0.035), c_w, Rw, mat=M_WOOD)
    body.box(Pw(P_, (u0 + u1) / 2, v0 - 0.045, 0.04), (w + 0.24, 0.09, T * 0.5 + 0.12), J(P["stone"], 0.05), Rw,
             cols={"top": J(P["stone"], 0.03, 0, 0)})
    if not surround:
        body.box(Pw(P_, (u0 + u1) / 2, v1 + 0.05, 0.015), (w + 0.2, 0.1, 0.1), J(P["wood2"], 0.06), Rw, mat=M_WOOD)
    if box:
        flower_box(body, P_, Rw, (u0 + u1) / 2, v0 - 0.07, w + 0.1)
        block(side, P_, U, u0 - 0.1, u1 + 0.1, v0 - 0.5, v0)
    if shutters:
        ws = w / 2
        ang = math.radians(rng.uniform(168, 176))
        if rng.random() < 0.22:
            ang = math.radians(rng.uniform(70, 110))
        if open_k is not None:
            ang = open_k
        ang2 = ang if rng.random() < 0.8 else math.radians(rng.uniform(80, 130))
        ck = DS["shutter"]
        mov("shutter", shutter_key(ck, ws, h, -1), P_(u0, v0, 0.022), U, N, ang, -1)
        mov("shutter", shutter_key(ck, ws, h, 1), P_(u1, v0, 0.022), U, N, ang2, 1)
        block(side, P_, U, u0 - ws - 0.05, u1 + ws + 0.05, v0, v1)


def flower_box(mb, P_, Rw, uc, vtop, w):
    c = J(P["wood"], 0.08)
    mb.box(Pw(P_, uc, vtop - 0.09, 0.13), (w, 0.16, 0.18), c, Rw, mat=M_WOOD)
    mb.box(Pw(P_, uc, vtop - 0.015, 0.13), (w - 0.04, 0.02, 0.14), col("#4a3524"), Rw)
    flowers = ["#d9534f", "#f0c24b", "#e98bb0", "#f4f1e8", "#c0392b"]
    n = int(w / 0.07)
    for i in range(n):
        u = uc - w / 2 + 0.05 + (w - 0.1) * i / max(1, n - 1)
        leaf_blob(mb, Pw(P_, u + rng.uniform(-0.02, 0.02), vtop + 0.03, 0.13 + rng.uniform(-0.04, 0.04)), 0.05, J("#5b8a3a", 0.12))
        if rng.random() < 0.7:
            leaf_blob(mb, Pw(P_, u + rng.uniform(-0.02, 0.02), vtop + 0.08 + rng.uniform(0, 0.04),
                             0.15 + rng.uniform(-0.03, 0.04)), 0.025, J(rng.choice(flowers), 0.08))
    for i in range(3):
        u = uc - w / 2 + 0.06 + rng.uniform(0, w - 0.12)
        for k in range(3):
            leaf_blob(mb, Pw(P_, u, vtop - 0.18 - 0.07 * k, 0.23), 0.03, J("#4f7d33", 0.1))


def leaf_blob(mb, at, r, c):
    x, y, z = at
    top = mb.v((x, y + r, z))
    bot = mb.v((x, y - r * 0.8, z))
    ring = []
    for k in range(5):
        a = 2 * math.pi * k / 5 + rng.uniform(-0.2, 0.2)
        rr = r * rng.uniform(0.85, 1.15)
        ring.append(mb.v((x + rr * math.cos(a), y + rng.uniform(-0.2, 0.2) * r, z + rr * math.sin(a))))
    for k in range(5):
        j = (k + 1) % 5
        mb.face([ring[k], ring[j], top], col_shift(c, 0.06), ("from", at))
        mb.face([ring[j], ring[k], bot], col_shift(c, -0.12), ("from", at))


def door(body, P_, U, N, side, a, b, c, d, colkey, stone=True, arch=False, open_a=None):
    R = RW(U, N)
    if arch:
        # кирпичная арка над дверью (полукруг из клиньев) и косяки из кирпича
        r = (b - a) / 2 + 0.06
        cu = (a + b) / 2
        for k in range(9):
            ph = math.pi * (k + 0.5) / 9
            pu = cu + math.cos(ph) * (r + 0.06)
            pv = d - 0.02 + math.sin(ph) * (r * 0.55 + 0.06)
            body.box(Pw(P_, pu, pv, 0.02), (0.08, 0.13, 0.08), J("#a4583a", 0.12, 0.015, 0.1), R @ Matrix.Rotation(ph - math.pi / 2, 3, "Z"))
        for uu in (a - 0.05, b + 0.05):
            for k in range(int((d - c) / 0.12)):
                body.box(Pw(P_, uu + (0.02 if k % 2 else -0.02), c + 0.06 + k * 0.12, 0.02), (0.12, 0.1, 0.07), J("#a4583a", 0.12, 0.015, 0.1), R)
    elif stone:
        for cu in (a + 0.04, b - 0.04):
            body.box(Pw(P_, cu, (c + d) / 2, -0.05), (0.09, d - c, 0.1), J(P["stone"], 0.06), R, mat=M_STONE)
        body.box(Pw(P_, (a + b) / 2, d + 0.07, 0.02), (b - a + 0.3, 0.14, 0.14), J(P["stone"], 0.06), R,
                 cols={"top": J(P["stone"], 0.1)})
    else:
        body.box(Pw(P_, (a + b) / 2, d + 0.05, 0.015), (b - a + 0.24, 0.1, 0.1), J(P["wood2"], 0.06), R, mat=M_WOOD)
    ang = math.radians(38) if open_a is None else open_a
    mov("door", door_key(colkey, b - a - 0.18, d - c - 0.03), P_(a + 0.09, c, -0.1), U, N, ang)
    block(side, P_, U, a - 0.2, b + 0.2, c, d + 0.3)


# ---------------- крыша из черепицы ----------------
def antefix_at(mb, p, along_x, side, c):
    n = Vector((0, 0, side)) if along_x else Vector((side, 0, 0))
    u = Vector((1, 0, 0)) if along_x else Vector((0, 0, 1))
    pts = []
    for k in range(7):
        ph = math.pi * k / 6
        rr = 0.085 if k % 2 == 0 else 0.065
        pts.append(p + u * (rr * math.cos(ph)) + Vector((0, 0.02 + rr * math.sin(ph) * 1.25, 0)))
    pts = [p + u * 0.05] + pts[::-1] + [p - u * 0.05]
    fr = [mb.v(q + n * 0.012) for q in pts]
    bk = [mb.v(q - n * 0.012) for q in pts]
    mb.face(fr, col_shift(c, 0.08), ("dir", tuple(n)))
    mb.face(bk[::-1], col_shift(c, -0.2), ("dir", tuple(-n)))
    for i in range(len(pts) - 1):
        mb.face([fr[i], fr[i + 1], bk[i + 1], bk[i]], col_shift(c, -0.1), ("from", tuple(p + Vector((0, 0.06, 0)))))


def roof(mb, along_x, x0, x1, z0, z1, y_wall, pitch_deg=27.0, oe=0.34, og=0.18, antefix=True, ends=(True, True)):
    a = math.radians(pitch_deg)
    if along_x:
        L0, L1 = x0 - og, x1 + og
        half = (z1 - z0) / 2
        cz = (z0 + z1) / 2
    else:
        L0, L1 = z0 - og, z1 + og
        half = (x1 - x0) / 2
        cz = (x0 + x1) / 2
    run = half + oe
    rise = half * math.tan(a)
    y_ridge = y_wall + rise
    y_eave = y_wall - oe * math.tan(a)
    slope_len = run / math.cos(a)

    def Wp(l, s, n, side):
        horiz = run - s * math.cos(a)
        y = y_eave + s * math.sin(a) + n * math.cos(a)
        d = side * (horiz + n * math.sin(a))
        if along_x:
            return Vector((l, y, cz + d))
        return Vector((cz + d, y, l))

    tile = P["tile"]
    sp, L, step, lift = 0.40, 0.54, 0.41, 0.05
    ncol = int((L1 - L0) / sp)
    l_start = (L0 + L1) / 2 - ncol * sp / 2
    nrow = int(math.ceil((slope_len - 0.06) / step))
    deck_t = 0.1
    ridge_r = 0.12
    Uv = Vector((1, 0, 0)) if along_x else Vector((0, 0, 1))
    for side in (1, -1):
        q = [Wp(L0, 0, -deck_t, side), Wp(L1, 0, -deck_t, side), Wp(L1, slope_len, -deck_t, side), Wp(L0, slope_len, -deck_t, side)]
        mb.face([mb.v(p) for p in q], col(P["wood2"], -0.1), ("dir", (0, -1, 0)))
        q2 = [Wp(L0, 0, 0, side), Wp(L1, 0, 0, side), Wp(L1, slope_len, 0, side), Wp(L0, slope_len, 0, side)]
        mb.face([mb.v(p) for p in q2], col(tile, -0.35), ("dir", (0, 1, 0)))
        mb.face([mb.v(Wp(L0, 0, -deck_t, side)), mb.v(Wp(L1, 0, -deck_t, side)), mb.v(Wp(L1, 0, 0, side)), mb.v(Wp(L0, 0, 0, side))],
                col(P["wood2"]), ("from", Wp((L0 + L1) / 2, 1.0, 0, side)))
        for lv, sg in ((L0, -1), (L1, 1)):
            p0 = Wp(lv + sg * 0.03, 0, -deck_t * 0.5 + 0.01, side)
            p1 = Wp(lv + sg * 0.03, slope_len, -deck_t * 0.5 + 0.01, side)
            dirv = (p1 - p0).normalized()
            Nv = dirv.cross(Uv).normalized()
            if Nv.y < 0:
                Nv = -Nv
            mb.box(tuple((p0 + p1) / 2), (0.07, deck_t + 0.06, (p1 - p0).length + 0.04), J(P["wood2"], 0.06),
                   Matrix((Uv, Nv, dirv)).transposed())
        nr = int((L1 - L0) / 0.42)
        for k in range(nr + 1):
            l = L0 + 0.12 + (L1 - L0 - 0.24) * k / max(1, nr)
            p0 = Wp(l, 0.02, -deck_t - 0.045, side)
            p1 = Wp(l, oe / math.cos(a) + 0.15, -deck_t - 0.045, side)
            dirv = (p1 - p0).normalized()
            Nv = dirv.cross(Uv).normalized()
            if Nv.y < 0:
                Nv = -Nv
            mb.box(tuple((p0 + p1) / 2), (0.07, 0.09, (p1 - p0).length), J(P["wood"], 0.08), Matrix((Uv, Nv, dirv)).transposed(), mat=M_WOOD)
        for r in range(nrow):
            s0 = r * step
            s1 = min(s0 + L, slope_len + 0.05)
            for c in range(ncol):
                l0 = l_start + c * sp + 0.012
                l1 = l_start + (c + 1) * sp - 0.012
                tc = J(tile, 0.09, 0.012, 0.1)
                rr = rng.random()
                if rr < 0.05:
                    tc = col(tile, 0.18, 0.01, -0.05)
                elif rr < 0.09:
                    tc = col(tile, -0.28, 0.0, -0.1)
                elif rr < 0.11 and side == -1:
                    tc = col("#7f7a3e", rng.uniform(-0.1, 0.05))
                lo = lift if r > 0 else 0.0
                th, ch = 0.045, 0.03
                b0, b1 = Wp(l0, s0, lo, side), Wp(l1, s0, lo, side)
                b2, b3 = Wp(l1, s1, 0, side), Wp(l0, s1, 0, side)
                m0, m1 = Wp(l0 + 0.01, s0, lo + th * 0.55, side), Wp(l1 - 0.01, s0, lo + th * 0.55, side)
                t0, t1 = Wp(l0 + 0.01, s0 + ch, lo + th, side), Wp(l1 - 0.01, s0 + ch, lo + th, side)
                t2, t3 = Wp(l1 - 0.01, s1, th, side), Wp(l0 + 0.01, s1, th, side)
                pts = [b0, b1, b2, b3, m0, m1, t0, t1, t2, t3]
                vv = [mb.v(q) for q in pts]
                cc = tuple(sum(pts, Vector((0.0, 0.0, 0.0))) / len(pts))
                mb.face([vv[6], vv[7], vv[8], vv[9]], tc, ("from", cc))
                mb.face([vv[4], vv[5], vv[7], vv[6]], col_shift(tc, 0.12), ("from", cc))
                mb.face([vv[0], vv[1], vv[5], vv[4]], col_shift(tc, -0.3), ("from", cc))
                mb.face([vv[1], vv[2], vv[8], vv[7], vv[5]], col_shift(tc, -0.18), ("from", cc))
                mb.face([vv[3], vv[0], vv[4], vv[6], vv[9]], col_shift(tc, -0.18), ("from", cc))
            for c in range(ncol + 1):
                lc = l_start + c * sp
                r0 = 0.09 if r > 0 else 0.095
                r1 = 0.078
                seg = 6
                ring0, ring1 = [], []
                base_lo = (lift if r > 0 else 0.0) + 0.035
                for k in range(seg + 1):
                    ph = math.pi * k / seg
                    ring0.append(mb.v(Wp(lc + r0 * math.cos(ph), s0 - 0.02, base_lo + r0 * math.sin(ph) * 0.95, side)))
                    ring1.append(mb.v(Wp(lc + r1 * math.cos(ph), s1 + 0.02, 0.035 + r1 * math.sin(ph) * 0.95, side)))
                ic = J(tile, 0.1, 0.012, 0.1)
                if rng.random() < 0.06:
                    ic = col(tile, -0.3)
                ctr = Wp(lc, (s0 + s1) / 2, 0.0, side)
                for k in range(seg):
                    sh = 0.12 * math.sin(math.pi * (k + 0.5) / seg) - 0.06
                    mb.face([ring0[k], ring0[k + 1], ring1[k + 1], ring1[k]], col_shift(ic, sh), ("from", tuple(ctr)))
                cen = mb.v(Wp(lc, s0 - 0.02, base_lo, side))
                for k in range(seg):
                    mb.face([cen, ring0[k], ring0[k + 1]], col_shift(ic, -0.3), ("from", tuple(Wp(lc, s0 + 0.2, base_lo, side))))
                if r == 0 and antefix:
                    antefix_at(mb, Wp(lc, -0.03, base_lo + 0.02, side), along_x, side, ic)
    nk = int((L1 - L0) / 0.4) + 1
    for k in range(nk):
        l0 = L0 - 0.02 + k * 0.4
        l1 = min(l0 + 0.44, L1 + 0.04)
        ic = J(tile, 0.08, 0.01, 0.08)
        seg = 7
        rings = []
        for l, rr in ((l0, ridge_r * 1.06), (l1, ridge_r)):
            ring = []
            for s in range(seg + 1):
                ph = math.radians(-10) + math.radians(200) * s / seg
                dy = rr * math.sin(ph) * 0.9
                dd = rr * math.cos(ph)
                ring.append(mb.v((l, y_ridge + 0.02 + dy, cz + dd) if along_x else (cz + dd, y_ridge + 0.02 + dy, l)))
            rings.append(ring)
        ctr = (((l0 + l1) / 2, y_ridge, cz) if along_x else (cz, y_ridge, (l0 + l1) / 2))
        for s in range(seg):
            mb.face([rings[0][s], rings[0][s + 1], rings[1][s + 1], rings[1][s]], col_shift(ic, 0.06 * math.sin(math.pi * s / seg)), ("from", ctr))
        cen = mb.v(((l0, y_ridge + 0.02, cz) if along_x else (cz, y_ridge + 0.02, l0)))
        for s in range(seg):
            mb.face([cen, rings[0][s + 1], rings[0][s]], col_shift(ic, -0.25), ("from", ((l0 + 0.2, y_ridge, cz) if along_x else (cz, y_ridge, l0 + 0.2))))
    # насесты для птиц: по коньку
    for f in (0.2, 0.5, 0.8):
        l = L0 + (L1 - L0) * f
        PERCH.append([l, y_ridge + 0.13, cz] if along_x else [cz, y_ridge + 0.13, l])
    return y_ridge, rise


def gable_walls(walls, inner, along_x, x0, x1, z0, z1, y_wall, rise, front_detail=False):
    cz = (z0 + z1) / 2 if along_x else (x0 + x1) / 2
    ends = []
    if along_x:
        for x, nx in ((x0, -1), (x1, 1)):
            ends.append(([Vector((x, y_wall, z0)), Vector((x, y_wall, z1)), Vector((x, y_wall + rise, cz))], Vector((nx, 0, 0))))
    else:
        for z, nz in ((z0, -1), (z1, 1)):
            ends.append(([Vector((x0, y_wall, z)), Vector((x1, y_wall, z)), Vector((cz, y_wall + rise, z))], Vector((0, 0, nz))))
    for tri, n in ends:
        cs = [col_shift(col(PLASTER, noise2(p.x, p.y, PH) * 0.06 - 0.05 * (p.y - y_wall)), 0.1) for p in tri]
        walls.face([walls.v(p) for p in tri], cs, ("dir", tuple(n)), uv=[((p.x + p.z) / 1.6, p.y / 1.6) for p in tri], mat=1)
        inner.face([inner.v(p - n * T) for p in tri], col(ROOM, -0.1), ("dir", tuple(-n)))


def plinth(mb, x0, x1, z0, z1, gaps):
    sides = [("front", Vector((x0, 0, z1)), Vector((1, 0, 0)), Vector((0, 0, 1)), x1 - x0),
             ("back", Vector((x1, 0, z0)), Vector((-1, 0, 0)), Vector((0, 0, -1)), x1 - x0),
             ("left", Vector((x0, 0, z0)), Vector((0, 0, 1)), Vector((-1, 0, 0)), z1 - z0),
             ("right", Vector((x1, 0, z1)), Vector((0, 0, -1)), Vector((1, 0, 0)), z1 - z0)]
    for name, O, U, N, Ln in sides:
        u = -0.03
        R = RW(U, N)
        while u < Ln + 0.02:
            ln = rng.uniform(0.32, 0.6)
            u1 = min(u + ln, Ln + 0.03)
            skip = any(g[0] == name and g[1] < (u + u1) / 2 < g[2] for g in gaps)
            if not skip and u1 - u > 0.06:
                h = PL + rng.uniform(-0.02, 0.01)
                c = (O + U * ((u + u1) / 2) + Vector((0, h / 2 - 0.02, 0)) + N * rng.uniform(0.01, 0.035))
                mb.box(tuple(c), (u1 - u - 0.012, h, 0.12), J(P["stone"], 0.1, 0.01, 0.2), R,
                       cols={"top": J(P["stone"], 0.12, 0.0, 0.1)}, skip=("bot",))
            u = u1


def brick_patch(mb, P_, U, N, uc, vc, r):
    R = RW(U, N)
    pts = []
    for i in range(9):
        a = 2 * math.pi * i / 9
        rr = r * rng.uniform(0.6, 1.1)
        pts.append(mb.v(P_(uc + rr * math.cos(a) * 1.3, vc + rr * math.sin(a) * 0.8, 0.004)))
    mb.face(pts, col("#8f5a42", rng.uniform(-0.1, 0.05)), ("dir", tuple(N)))
    bh = 0.05
    for j in range(int(r * 1.6 / bh)):
        v = vc - r * 0.8 + (j + 0.5) * bh
        u = uc - r * 1.3 + (0.06 if j % 2 else 0.0)
        while u < uc + r * 1.3:
            du, dv = (u + 0.1 - uc) / (r * 1.3), (v - vc) / (r * 0.8)
            if du * du + dv * dv < 0.55:
                mb.box(Pw(P_, u + 0.1, v, 0.008), (0.19, bh - 0.012, 0.012), J("#a4583a", 0.12, 0.015, 0.1), R)
            u += 0.21


def brick_facing(mb, P_, U, N, u0, u1, v0, v1, openings):
    """кирпичная облицовка низа стены (opus latericium): ряды кирпича вперевязку поверх штукатурки"""
    R = RW(U, N)
    bh, bl = 0.075, 0.24
    rows = int((v1 - v0) / bh)
    for j in range(rows):
        v = v0 + (j + 0.5) * bh
        u = u0 + (bl / 2 if j % 2 else 0.0)
        while u < u1 - 0.02:
            ua, ub = u, min(u + bl, u1)
            uc = (ua + ub) / 2
            if not any(a - 0.02 < uc < b + 0.02 and c - 0.02 < v < d + 0.02 for (a, b, c, d) in openings):
                mb.box(Pw(P_, uc, v, 0.012), (ub - ua - 0.014, bh - 0.012, 0.03), J("#a85a3a", 0.12, 0.015, 0.12), R,
                       skip=("nz",))
            u = ub
    # верхний край — каменный поясок (через двери и окна не идёт)
    cuts = sorted((a, b) for (a, b, c, d) in openings if c < v1 + 0.02 < d)
    u = u0 - 0.01
    for (a, b) in cuts + [(u1 + 0.01, u1 + 0.01)]:
        if a - u > 0.04:
            mb.box(Pw(P_, (u + a) / 2, v1 + 0.02, 0.03), (a - u, 0.05, 0.06), J(P["stone"], 0.05), R, mat=M_STONE)
        u = max(u, b)


# ---------------- реквизит ----------------
def pot(mb, at, h, c, herb=True):
    prof = [(h * 0.22, 0), (h * 0.34, h * 0.35), (h * 0.33, h * 0.75), (h * 0.27, h * 0.92), (h * 0.33, h)]
    mb.lathe(at, prof, 8, c, close_top=True)
    if herb:
        for k in range(4):
            leaf_blob(mb, (at[0] + rng.uniform(-h * 0.2, h * 0.2), at[1] + h + h * rng.uniform(0.1, 0.45),
                           at[2] + rng.uniform(-h * 0.2, h * 0.2)), h * 0.22, J("#5b8a3a", 0.15))


def amphora(mb, at, h, c):
    prof = [(0.0, 0), (h * 0.06, h * 0.05), (h * 0.2, h * 0.3), (h * 0.22, h * 0.5), (h * 0.16, h * 0.72),
            (h * 0.07, h * 0.82), (h * 0.065, h * 0.95), (h * 0.085, h)]
    mb.lathe(at, prof, 8, c, close_top=True)
    for s in (-1, 1):
        mb.box((at[0] + s * h * 0.12, at[1] + h * 0.84, at[2]), (0.02, h * 0.16, 0.025), c)


def bench(mb, at, ln, R):
    mb.box(at, (ln, 0.04, 0.24), J(P["wood"], 0.06), R, mat=M_WOOD)
    for s in (-1, 1):
        o = R @ Vector((s * (ln / 2 - 0.08), -0.13, 0))
        mb.box((at[0] + o.x, at[1] + o.y, at[2] + o.z), (0.05, 0.24, 0.2), J(P["wood2"], 0.06), R, mat=M_WOOD)


def firewood(mb, at, R, n=9):
    for i in range(n):
        row = i // 4
        k = i % 4
        o = R @ Vector(((k - 1.5) * 0.085 + row * 0.04, 0.04 + row * 0.075, 0))
        c = (at[0] + o.x, at[1] + o.y, at[2] + o.z)
        r = 0.04
        ring0, ring1 = [], []
        for s in range(6):
            a = 2 * math.pi * s / 6
            dd = R @ Vector((math.cos(a) * r, math.sin(a) * r, 0))
            zz = R @ Vector((0, 0, 0.2))
            ring0.append(mb.v((c[0] + dd.x - zz.x, c[1] + dd.y - zz.y, c[2] + dd.z - zz.z)))
            ring1.append(mb.v((c[0] + dd.x + zz.x, c[1] + dd.y + zz.y, c[2] + dd.z + zz.z)))
        bark = J("#6b5039", 0.12)
        for s in range(6):
            t = (s + 1) % 6
            mb.face([ring0[s], ring0[t], ring1[t], ring1[s]], bark, ("from", c))
        mb.face(ring1, col("#c9a46e", rng.uniform(-0.1, 0.05)), ("from", c))
        mb.face(ring0[::-1], col("#c9a46e", rng.uniform(-0.1, 0.05)), ("from", c))


def basket(mb, at, r, h):
    mb.lathe(at, [(r * 0.8, 0), (r, h * 0.85), (r * 1.05, h)], 9, J("#b48a4f", 0.08),
             cols=[J("#b48a4f", 0.1), J("#a07840", 0.1)])
    mb.lathe((at[0], at[1] + h * 0.7, at[2]), [(r * 0.9, 0), (r * 0.92, 0.01)], 9, J("#7a8f3a", 0.1), close_top=True)
    for k in range(3):
        leaf_blob(mb, (at[0] + rng.uniform(-r * 0.4, r * 0.4), at[1] + h * 0.85, at[2] + rng.uniform(-r * 0.4, r * 0.4)),
                  r * 0.35, J(rng.choice(["#c0392b", "#e6b33a", "#7fa040"]), 0.1))


def awning(mb, P_, U, N, uc, v, w, depth, cols2, poles=True, drop=0.45, braces=True, ns=6):
    """полосатый тканевый навес: провис, ткань чуть вздута между швами, фестоны с кисточками по краю, верёвки к стене"""
    R = RW(U, N)
    sub, nd = 3, 4
    nu = ns * sub
    ts = TS[M_CLOTH]
    stripe = [col(cols2[k % 2], rng.uniform(-0.03, 0.03)) for k in range(ns)]

    def yd(i, d):
        t = d / depth
        return v - d * drop - 0.06 * math.sin(math.pi * i / nu) * t + 0.016 * math.sin(math.pi * (i % sub) / sub) * (0.3 + 0.7 * t)

    grid = {}
    for i in range(nu + 1):
        for j in range(nd + 1):
            dd = depth * j / nd
            grid[(i, j)] = Pw(P_, uc - w / 2 + w * i / nu, yd(i, dd), 0.02 + dd)
    sheet(mb, grid, nu, nd, lambda i, j: stripe[min(ns - 1, i // sub)], (0, 1, 0), lambda i, j: (w * i / nu / ts, depth * j / nd / ts))
    # фестоны: по краю каждой полосы — полукруглый язык ткани; на стыках — кисточки
    vg = {}
    for i in range(nu + 1):
        top = yd(i, depth)
        t = (i % sub) / sub if i < nu else 0.0
        lobe = 0.05 + 0.055 * math.sin(math.pi * t)
        vg[(i, 0)] = Pw(P_, uc - w / 2 + w * i / nu, top + 0.004, 0.02 + depth + 0.004)
        vg[(i, 1)] = Pw(P_, uc - w / 2 + w * i / nu, top - lobe, 0.022 + depth + 0.004)
    sheet(mb, vg, nu, 1, lambda i, j: col_shift(stripe[min(ns - 1, i // sub)], -0.04), tuple(N), lambda i, j: (w * i / nu / ts, j * 0.1 / ts))
    tc = col(cols2[1], -0.2)
    for k in range(ns + 1):
        i = k * sub
        p = Vector(Pw(P_, uc - w / 2 + w * i / nu, yd(i, depth) - 0.05, 0.024 + depth))
        ball(mb, tuple(p), 0.011, tc, seg=5, rings=3)
        spindle(mb, p, p + Vector((0, -0.06, 0)), [(0.006, 0.0), (0.014, 0.6), (0.012, 1.0)], 5, tc)
    # рейка у стены
    mb.box(Pw(P_, uc, v + 0.01, 0.03), (w + 0.06, 0.05, 0.05), J(P["wood"], 0.06), R, mat=M_WOOD)
    if poles:
        for s in (-1, 1):
            top = Pw(P_, uc + s * w / 2, v - depth * drop - 0.02, depth + 0.02)
            mb.box((top[0], top[1] / 2, top[2]), (0.045, top[1], 0.045), J(P["wood"], 0.05), R, mat=M_WOOD)
    elif braces:
        for s in (-1, 1):       # подкосы к стене и растяжки-верёвки к стене повыше
            p0 = Vector(Pw(P_, uc + s * (w / 2 - 0.05), v - 0.55, 0.02))
            p1 = Vector(Pw(P_, uc + s * (w / 2 - 0.05), v - depth * drop, depth))
            dl = p1 - p0
            Rr = Matrix((U, dl.normalized().cross(U).normalized(), dl.normalized())).transposed()
            mb.box(tuple((p0 + p1) / 2), (0.04, 0.04, dl.length), J(P["wood2"], 0.05), Rr, mat=M_WOOD)
            rod(mb, Pw(P_, uc + s * (w / 2 - 0.02), yd(0 if s < 0 else nu, depth) + 0.01, 0.02 + depth),
                Pw(P_, uc + s * (w / 2 - 0.12), v + 0.32, 0.02), 0.012, col(ROPE))
            mb.box(Pw(P_, uc + s * (w / 2 - 0.12), v + 0.32, 0.02), (0.03, 0.03, 0.04), col(IRON), R)


def canopy(mb, P_, U, N, uc, v, w, depth):
    """черепичный козырёк над дверью на деревянных кронштейнах"""
    R = RW(U, N)
    a = math.radians(24)
    nrow = 2
    ncol = max(2, int(w / 0.34))
    for r in range(nrow):
        for c in range(ncol):
            u0 = uc - w / 2 + w * c / ncol
            u1 = u0 + w / ncol - 0.02
            d0 = depth * (1 - (r + 1) / nrow)
            d1 = depth * (1 - r / nrow) + 0.06
            tc = J(P["tile"], 0.09, 0.01, 0.1)
            lo = 0.035 * (1 - r)
            q = [Pw(P_, u0, v - d1 * math.tan(a) + lo, 0.02 + d1), Pw(P_, u1, v - d1 * math.tan(a) + lo, 0.02 + d1),
                 Pw(P_, u1, v - d0 * math.tan(a), 0.02 + d0), Pw(P_, u0, v - d0 * math.tan(a), 0.02 + d0)]
            vv = [mb.v(x) for x in q]
            mb.face(vv, tc, ("dir", (0, 1, 0)))
            top = [mb.v((x[0], x[1] + 0.04, x[2])) for x in q]
            mb.face(top, col_shift(tc, 0.05), ("dir", (0, 1, 0)))
            mb.face([vv[0], vv[1], top[1], top[0]], col_shift(tc, -0.3), ("dir", tuple(N)))
        for c in range(ncol + 1):
            uu = uc - w / 2 + w * c / ncol - 0.01
            p0 = Vector(Pw(P_, uu, v + 0.06, 0.04))
            p1 = Vector(Pw(P_, uu, v - depth * math.tan(a) + 0.06, depth + 0.06))
            dl = p1 - p0
            Rr = Matrix((U, dl.normalized().cross(U).normalized(), dl.normalized())).transposed()
            if Rr.col[1].y < 0:
                Rr = Matrix((U, -dl.normalized().cross(U).normalized(), dl.normalized())).transposed()
            mb.box(tuple((p0 + p1) / 2), (0.1, 0.07, dl.length), J(P["tile"], 0.08, 0.01, 0.08), Rr)
    for s in (-1, 1):
        p0 = Vector(Pw(P_, uc + s * (w / 2 - 0.08), v - 0.45, 0.03))
        p1 = Vector(Pw(P_, uc + s * (w / 2 - 0.08), v - depth * math.tan(a) * 0.9, depth * 0.9))
        dl = p1 - p0
        Rr = Matrix((U, dl.normalized().cross(U).normalized(), dl.normalized())).transposed()
        mb.box(tuple((p0 + p1) / 2), (0.06, 0.06, dl.length), J(P["wood2"], 0.05), Rr, mat=M_WOOD)
        mb.box(Pw(P_, uc + s * (w / 2 - 0.08), v - depth * math.tan(a) * 0.5, depth * 0.5), (0.07, 0.07, depth), J(P["wood"], 0.05), R, mat=M_WOOD)


def pergola(mb, P_, U, N, u0, u1, h, depth, dens=1.0):
    """деревянная пергола перед фасадом с виноградной лозой"""
    R = RW(U, N)
    for uu in (u0, u1):
        top = Pw(P_, uu, h, depth)
        mb.box((top[0], h / 2, top[2]), (0.09, h, 0.09), J(P["wood"], 0.06), R, mat=M_WOOD)
    mb.box(Pw(P_, (u0 + u1) / 2, h + 0.04, depth), (u1 - u0 + 0.3, 0.09, 0.09), J(P["wood"], 0.06), R, mat=M_WOOD)
    nb = int((u1 - u0) / 0.32) + 1
    for k in range(nb):
        uu = u0 + (u1 - u0) * k / max(1, nb - 1)
        mb.box(Pw(P_, uu, h + 0.12, depth / 2), (0.06, 0.07, depth + 0.3), J(P["wood2"], 0.06), R, mat=M_WOOD)
    # лоза: густые листья поверху, свисающие плети, грозди
    for k in range(int((u1 - u0) * depth * 70 * dens)):
        uu = rng.uniform(u0 - 0.1, u1 + 0.1)
        dd = rng.uniform(0.0, depth + 0.1)
        leaf_blob(mb, Pw(P_, uu, h + 0.18 + rng.uniform(-0.03, 0.06), dd), rng.uniform(0.05, 0.08), J(rng.choice(["#4f7d33", "#5f8f3a", "#3f6b2a"]), 0.1))
    for k in range(10):
        uu = rng.uniform(u0, u1)
        dd = rng.uniform(depth * 0.4, depth + 0.05)
        for j in range(rng.randint(1, 3)):
            leaf_blob(mb, Pw(P_, uu, h + 0.05 - j * 0.09, dd), 0.04, J("#4f7d33", 0.12))
    for k in range(5):
        uu = rng.uniform(u0 + 0.1, u1 - 0.1)
        dd = rng.uniform(depth * 0.3, depth)
        for j in range(5):
            leaf_blob(mb, Pw(P_, uu + rng.uniform(-0.03, 0.03), h + 0.02 - j * 0.035, dd + rng.uniform(-0.03, 0.03)), 0.022, J("#5a2d5f", 0.1))
    # лоза по столбу
    for uu in (u0, u1):
        for j in range(8):
            leaf_blob(mb, Pw(P_, uu + rng.uniform(-0.06, 0.06), 0.3 + j * h / 9, depth + rng.uniform(-0.06, 0.06)), 0.045, J("#4f7d33", 0.12))


def ivy_patch(mb, P_, U, N, u0, w, h, dens=1.0):
    """плющ по стене: плотный низ, неровный верх; стебли тёмные"""
    R = RW(U, N)
    cols = ["#3f6b2a", "#4f7d33", "#5b8a3a", "#66923b"]
    n = int(w * h * 55 * dens)
    for k in range(n):
        uu = u0 + rng.uniform(0, w)
        top = h * (0.55 + 0.45 * abs(math.sin(uu * 3.1 + PH[2])))
        vv = PL + rng.uniform(0, 1) ** 1.6 * top
        leaf_blob(mb, Pw(P_, uu, vv, 0.03 + rng.uniform(0, 0.05)), rng.uniform(0.04, 0.07), J(rng.choice(cols), 0.08))


def laundry(mb, P_, U, N, side_len, y):
    R = RW(U, N)
    p0 = P_(0.3, y, 0.35)
    p1 = P_(side_len - 0.3, y, 0.35)
    rope = p1 - p0
    mb.box(tuple((p0 + p1) / 2), (rope.length, 0.012, 0.012), col("#d8cfbf"), R)
    for s, uu in ((p0, 0.3), (p1, side_len - 0.3)):
        mb.box(Pw(P_, uu, y, 0.17), (0.03, 0.03, 0.36), J(P["wood"], 0.05), R, mat=M_WOOD)
    cloths = ["#f4efe2", "#c94f3d", "#4f78a8", "#e8c35a", "#f4efe2"]
    n = 5
    for k in range(n):
        t = (k + 0.7) / (n + 0.4)
        c = p0 + rope * t
        w = rng.uniform(0.22, 0.32)
        h = rng.uniform(0.28, 0.42)
        mb.box((c.x, c.y - h / 2 - 0.01, c.z), (w, h, 0.012), J(cloths[k], 0.06), R)


def ladder(mb, P_, U, N, u, h):
    R = RW(U, N) @ Matrix.Rotation(-0.25, 3, "X")
    lp = P_(u, 0.0, 0.45)
    for s in (-0.17, 0.17):
        o = R @ Vector((s, h / 2, 0))
        mb.box((lp.x + o.x, o.y, lp.z + o.z), (0.04, h, 0.04), J(P["wood"], 0.06), R, mat=M_WOOD)
    for k in range(int(h / 0.3)):
        o = R @ Vector((0, 0.2 + k * 0.3, 0))
        mb.box((lp.x + o.x, o.y, lp.z + o.z), (0.34, 0.03, 0.03), J(P["wood"], 0.06), R, mat=M_WOOD)


def interior(mb, emb, x0, x1, z0, z1, y, floor_k):
    n = int((x1 - x0) / 0.18)
    for i in range(n):
        u0 = x0 + (x1 - x0) * i / n
        mb.box(((u0 + (x1 - x0) / n / 2), y + 0.02, (z0 + z1) / 2), ((x1 - x0) / n - 0.006, 0.04, z1 - z0),
               J(P["wood2"], 0.12, 0.01, 0.1), skip=("bot",))
    if floor_k == 0:
        hx, hz = x0 + 0.35, z0 + 0.3
        mb.box((hx, y + 0.18, hz), (0.6, 0.32, 0.45), J(P["stone"], 0.08), cols={"top": col("#3a2e26")}, skip=("bot",), mat=M_STONE)
        for k in range(5):
            leaf_blob(emb, (hx + rng.uniform(-0.15, 0.15), y + 0.37, hz + rng.uniform(-0.1, 0.1)), 0.04,
                      col(rng.choice(["#ff7a1a", "#ffb03a", "#e8461c"])))
        mb.lathe((hx, y + 0.36, hz), [(0.12, 0), (0.15, 0.1), (0.12, 0.18)], 8, col("#3d3530"))
        tx, tz = (x0 + x1) / 2 + 0.25, (z0 + z1) / 2 - 0.2
        mb.box((tx, y + 0.52, tz), (0.8, 0.05, 0.5), J(P["wood"], 0.05), mat=M_WOOD)
        for sx in (-1, 1):
            for sz in (-1, 1):
                mb.box((tx + sx * 0.33, y + 0.26, tz + sz * 0.19), (0.05, 0.5, 0.05), J(P["wood2"], 0.05), mat=M_WOOD)
        mb.lathe((tx - 0.15, y + 0.55, tz), [(0.06, 0), (0.1, 0.05), (0.11, 0.06)], 8, col("#b8693f"))
        amphora(mb, (x1 - 0.2, y + 0.04, z0 + 0.25), 0.55, J("#c27a4a", 0.08))
        amphora(mb, (x1 - 0.42, y + 0.04, z0 + 0.22), 0.5, J("#b5703f", 0.08))
        mb.box((x1 - 0.06, y + 1.05, (z0 + z1) / 2), (0.1, 0.03, 0.9), J(P["wood"], 0.05), mat=M_WOOD)
        for k in range(3):
            mb.lathe((x1 - 0.07, y + 1.07, (z0 + z1) / 2 - 0.3 + 0.3 * k), [(0.04, 0), (0.06, 0.07), (0.04, 0.12)], 7,
                     J(rng.choice(["#b8693f", "#c9a46e", "#7d8f99"]), 0.08))
    else:
        bx, bz = x0 + 0.5, z0 + 0.6
        mb.box((bx, y + 0.22, bz), (0.85, 0.3, 1.25), J(P["wood"], 0.05), mat=M_WOOD)
        mb.box((bx, y + 0.42, bz + 0.1), (0.8, 0.1, 1.0), J("#b0413e", 0.08))
        mb.box((bx, y + 0.43, bz - 0.48), (0.7, 0.1, 0.22), J("#efe6d2", 0.04))
        mb.box((x1 - 0.35, y + 0.22, z0 + 0.3), (0.55, 0.4, 0.35), J(P["wood"], 0.08), cols={"top": J(P["wood2"], 0.05)}, mat=M_WOOD)
        amphora(mb, (x1 - 0.25, y + 0.04, z1 - 0.35), 0.45, J("#c27a4a", 0.08))


def corner_stones(body, x0, x1, z0, z1, style):
    corners = [(x0, z1, -1, 1), (x1, z1, 1, 1), (x0, z0, -1, -1), (x1, z0, 1, -1)]
    for (cx, cz_, sx, sz) in corners:
        if style == "stone":
            y = PL
            k = 0
            while y < HT - 0.12:
                h = min(0.24, HT - 0.1 - y)
                la, lb = (0.34, 0.2) if k % 2 == 0 else (0.2, 0.34)
                xa, xb = cx - sx * la, cx + sx * 0.03
                za, zb = cz_ - sz * lb, cz_ + sz * 0.03
                body.box(((xa + xb) / 2, y + h / 2, (za + zb) / 2), (abs(xb - xa), h - 0.018, abs(zb - za)),
                         J(P["stone"], 0.09, 0.01, 0.15), cols={"top": J(P["stone"], 0.12)})
                y += h
                k += 1
        elif style == "pilaster":
            body.box((cx - sx * 0.06, (PL + HT) / 2, cz_ - sz * 0.06), (0.18, HT - PL - 0.1, 0.18), J(P["trim"], 0.03))


def lean_to(body, x0, x1, z_wall, depth, y_top, y_low):
    """навес скатом от стены (z_wall) назад на столбах: черепица рядами, балки, столбы"""
    zb = z_wall - depth
    a = math.atan2(y_top - y_low, depth)
    ncol = max(2, int((x1 - x0) / 0.36))
    nrow = max(2, int(depth / 0.38))
    for r in range(nrow):
        for c in range(ncol):
            u0 = x0 + (x1 - x0) * c / ncol + 0.01
            u1 = x0 + (x1 - x0) * (c + 1) / ncol - 0.01
            d0 = depth * r / nrow - 0.02
            d1 = depth * (r + 1) / nrow + 0.06
            yy0 = y_top - d0 * math.tan(a)
            yy1 = y_top - d1 * math.tan(a) + (0.03 if r < nrow - 1 else 0)
            tc = J(P["tile"], 0.09, 0.01, 0.1)
            q = [(u0, yy1 + 0.02, z_wall - d1), (u1, yy1 + 0.02, z_wall - d1), (u1, yy0 + 0.02, z_wall - d0), (u0, yy0 + 0.02, z_wall - d0)]
            vv = [body.v(x) for x in q]
            body.face(vv, tc, ("dir", (0, 1, 0)))
            top = [body.v((x[0], x[1] + 0.04, x[2])) for x in q]
            body.face(top, col_shift(tc, 0.05), ("dir", (0, 1, 0)))
            body.face([vv[1], vv[0], top[0], top[1]], col_shift(tc, -0.3), ("dir", (0, 0, -1)))
            body.face(vv[::-1], col_shift(tc, -0.4), ("dir", (0, -1, 0)))
        for c in range(ncol + 1):
            uu = x0 + (x1 - x0) * c / ncol
            p0 = Vector((uu, y_top + 0.07, z_wall + 0.02))
            p1 = Vector((uu, y_low + 0.05, zb - 0.06))
            dl = p1 - p0
            Rr = Matrix((Vector((1, 0, 0)), dl.normalized().cross(Vector((1, 0, 0))).normalized(), dl.normalized())).transposed()
            if Rr.col[1].y < 0:
                Rr = Matrix((Vector((1, 0, 0)), -dl.normalized().cross(Vector((1, 0, 0))).normalized(), dl.normalized())).transposed()
            body.box(tuple((p0 + p1) / 2), (0.1, 0.07, dl.length), J(P["tile"], 0.08, 0.01, 0.08), Rr)
    for xx in (x0 + 0.08, x1 - 0.08):
        body.box((xx, (y_low - 0.05) / 2, zb + 0.05), (0.09, y_low - 0.05, 0.09), J(P["wood"], 0.06), mat=M_WOOD)
    body.box(((x0 + x1) / 2, y_low - 0.04, zb + 0.05), (x1 - x0, 0.09, 0.1), J(P["wood"], 0.06), mat=M_WOOD)
    # каменный пол двора
    for k in range(int((x1 - x0) / 0.5) + 1):
        for j in range(int(depth / 0.45) + 1):
            body.box((x0 + 0.25 + k * 0.5, 0.015, z_wall - 0.22 - j * 0.45), (0.46, 0.03, 0.41), J(P["stone"], 0.1, 0.01, 0.15), skip=("bot",), mat=M_STONE)


CRAFT_KEYS = {0: "cloth", 1: "pots", 2: "copper", 3: "grain"}


def craft_goods(body, emb, S, craft):
    """товар ремесла: на прилавке, на перекладине в проёме, на полке позади и на улице перед лавкой"""
    key = CRAFT_KEYS.get(craft, craft)
    TRADE_GOODS.get(key, g_cloth)(body, emb, S)


def shopfront(body, emb, P_, U, N, side, u0, u1, craft, top):
    """лавка на первом этаже: широкий проём под деревянной балкой, каменный прилавок с росписью (как в Помпеях),
    товар ремесла, расписная вывеска на железном кронштейне"""
    R = RW(U, N)
    key = CRAFT_KEYS.get(craft, craft)
    sign = DS.get("sign", key)
    panel = DS.get("panel", sign)
    body.box(Pw(P_, (u0 + u1) / 2, top + 0.07, 0.02), (u1 - u0 + 0.26, 0.14, 0.16), J(P["wood"], 0.06), R, mat=M_WOOD)
    for k in range(int((u1 - u0) / 0.3)):            # гвозди-шляпки по балке
        body.box(Pw(P_, u0 + 0.12 + k * 0.3, top + 0.07, 0.103), (0.018, 0.018, 0.008), col(IRON), R)
    for uu in (u0 + 0.05, u1 - 0.05):
        body.box(Pw(P_, uu, (PL + top) / 2, -0.06), (0.1, top - PL, 0.12), J(P["stone"], 0.06), R, mat=M_STONE)
    cu1 = u0 + (u1 - u0) * 0.72
    ch = 0.72
    body.box(Pw(P_, (u0 + cu1) / 2 + 0.04, PL + ch / 2, 0.02), (cu1 - u0 - 0.08, ch, 0.34), J(P["trim"], 0.04), R,
             cols={"pz": J("#a83f2c", 0.05)})
    body.box(Pw(P_, (u0 + cu1) / 2 + 0.04, PL + ch + 0.025, 0.04), (cu1 - u0 + 0.0, 0.05, 0.4), J("#e8e2d6", 0.03), R)
    body.box(Pw(P_, (u0 + cu1) / 2 + 0.04, PL + 0.03, 0.2), (cu1 - u0 - 0.04, 0.06, 0.04), J(P["stone"], 0.05), R, mat=M_STONE)
    # роспись на передней стенке прилавка (вывеска лавки) и мраморная крошка по краям
    cl = cu1 - u0 - 0.08
    ph = min(0.54, cl / 1.5 * 0.92)
    pw = ph * 1.5
    pc = (u0 + cu1) / 2 + 0.04
    body.box(Pw(P_, pc, PL + 0.1 + ch * 0.47, 0.192), (pw + 0.05, ph + 0.05, 0.006), J("#ece4d2", 0.03), R)
    sign_board(body, P_, U, N, pc, PL + 0.1 + ch * 0.47, pw, ph, 0.197, panel)
    for sgn in (-1, 1):
        a, b = (pc + sgn * (pw / 2 + 0.06), pc + sgn * (cl / 2 - 0.03))
        if abs(b - a) > 0.06:
            inlay(body, P_, R, min(a, b), max(a, b), PL + 0.14, PL + ch - 0.06, 0.193)
    S = {"P": P_, "U": U, "N": N, "R": R, "u0": u0 + 0.08, "u1": cu1 - 0.04, "y": PL + ch + 0.05, "top": top,
         "rail": (u0 + 0.14, u1 - 0.14, top - 0.08, 0.08),
         "shelf": (u0 + 0.12, cu1 - 0.06, -0.86, [PL + 0.5, PL + 0.9, PL + 1.28]),
         "out": (u0 + 0.02, cu1 + 0.05, 0.5), "ent": (cu1 + 0.04, u1 - 0.06)}
    # железная перекладина под балкой: на ней висит товар
    ru0, ru1, rv, rn = S["rail"]
    rod(body, Pw(P_, u0 + 0.08, rv, rn), Pw(P_, u1 - 0.08, rv, rn), 0.016, col(IRON))
    for uu in (u0 + 0.08, u1 - 0.08):
        rod(body, Pw(P_, uu, rv, rn), Pw(P_, uu, top, -0.02), 0.012, col(IRON))
    craft_goods(body, emb, S, craft)
    # вывеска на кронштейне — двусторонняя, у края проёма
    su = u1 + 0.2 if u1 < W - 0.4 else u0 - 0.2
    hang_sign(body, P_, U, N, su, top + 0.34, sign)
    block(side, P_, U, u0 - 0.1, u1 + 0.5, PL, top + 0.6)


def sign_uv(key):
    i = SIGNS.index(key) if key in SIGNS else 0
    cx, cy = i % 6, i // 6
    e = 3.0 / 2304
    return cx / 6 + e, (cx + 1) / 6 - e, 1 - (cy + 1) / 7 + e * 1.3, 1 - cy / 7 - e * 1.3


def sign_board(mb, P_, U, N, uc, vc, w, h, n, key):
    """расписная доска (клетка signs.png) на стене или прилавке, лицом к улице"""
    u0, u1, v0, v1 = sign_uv(key)
    q = [P_(uc - w / 2, vc - h / 2, n), P_(uc + w / 2, vc - h / 2, n), P_(uc + w / 2, vc + h / 2, n), P_(uc - w / 2, vc + h / 2, n)]
    mb.face([mb.v(tuple(p)) for p in q], (1.0, 1.0, 1.0, 1.0), ("dir", tuple(N)), uv=[(u0, v0), (u1, v0), (u1, v1), (u0, v1)], mat=M_SIGN)


def hang_sign(mb, P_, U, N, su, v, key, w=0.54, h=0.36, out=0.62):
    """вывеска поперёк улицы: железный кронштейн с завитком, на двух цепочках — доска, расписанная с обеих сторон"""
    R = RW(U, N)
    Y = Vector((0, 1, 0))
    rod(mb, P_(su, v, 0.0), P_(su, v, out), 0.026, col(IRON))
    rod(mb, P_(su, v - 0.26, 0.0), P_(su, v, out * 0.62), 0.018, col(IRON))
    torus(mb, tuple(P_(su, v + 0.035, out * 0.55)), Matrix((N, U, Y)).transposed(), 0.045, 0.007, col(IRON), seg=8, seg2=3)
    mb.box(Pw(P_, su, v, 0.02), (0.07, 0.1, 0.03), col(IRON), R)
    c = P_(su, v - 0.1 - h / 2, out * 0.55)
    for s in (-1, 1):
        a = P_(su, v - 0.012, out * 0.55 + s * (w / 2 - 0.05))
        rod(mb, a, a + Vector((0, -0.088, 0)), 0.008, col(IRON))
    Rb = Matrix((N, Y, U)).transposed()
    mb.box(tuple(c), (w + 0.05, h + 0.05, 0.03), J("#6b4428", 0.05), Rb, mat=M_WOOD)
    u0, u1, v0, v1 = sign_uv(key)
    for sgn in (-1, 1):
        right = -N * sgn
        off = U * (0.0165 * sgn)
        q = [c - right * (w / 2) - Y * (h / 2) + off, c + right * (w / 2) - Y * (h / 2) + off,
             c + right * (w / 2) + Y * (h / 2) + off, c - right * (w / 2) + Y * (h / 2) + off]
        mb.face([mb.v(tuple(p)) for p in q], (1.0, 1.0, 1.0, 1.0), ("dir", tuple(U * sgn)), uv=[(u0, v0), (u1, v0), (u1, v1), (u0, v1)], mat=M_SIGN)


def inlay(mb, P_, R, a, b, v0, v1, n):
    """мраморная крошка на прилавке (как в помпейских термополиях)"""
    for k in range(int((b - a) * (v1 - v0) * 34) + 2):
        uu = rng.uniform(a + 0.03, b - 0.03)
        vv = rng.uniform(v0 + 0.03, v1 - 0.03)
        s = rng.uniform(0.035, 0.065)
        mb.box(Pw(P_, uu, vv, n), (s, s * rng.uniform(0.6, 1.2), 0.006),
               J(rng.choice(["#d9cfbf", "#b9a98f", "#7f8f6a", "#8f4a3a", "#c9a55a", "#8a8f99"]), 0.05),
               R @ Matrix.Rotation(rng.uniform(0, 3.1), 3, "Z"))


def yard_props(body, emb, x0, x1, zb, z_wall, craft):
    zc = (zb + z_wall) / 2
    craft = {0: "loom", 1: "kiln", 2: "anvil", 3: "mill"}.get(craft, craft)
    if craft in TRADE_YARDS:
        TRADE_YARDS[craft](body, emb, x0, x1, zb, z_wall, zc)
        return
    if craft == "loom":     # ткацкий станок и корзины шерсти
        for xx in (-0.45, 0.45):
            body.box((xx, 0.6, zc), (0.06, 1.2, 0.06), J(P["wood"], 0.05), mat=M_WOOD)
        body.box((0, 1.15, zc), (1.0, 0.06, 0.06), J(P["wood"], 0.05), mat=M_WOOD)
        body.box((0, 0.35, zc), (1.0, 0.06, 0.06), J(P["wood"], 0.05), mat=M_WOOD)
        for k in range(14):
            body.box((-0.42 + k * 0.065, 0.75, zc), (0.012, 0.78, 0.012), J(rng.choice(["#b5452f", "#3f6fa8", "#e1b84a", "#efe3c8"]), 0.05))
        for k in range(2):
            basket(body, (x1 - 0.35 - k * 0.35, 0.0, zc + 0.1), 0.15, 0.24)
    elif craft == "kiln":   # печь для обжига (угольки в устье) и вазы
        kx = x0 + 0.65
        body.lathe((kx, 0.0, zc), [(0.42, 0.0), (0.44, 0.4), (0.36, 0.75), (0.2, 0.95), (0.08, 1.02)], 10, J("#b07a52", 0.06), close_top=True)
        body.box((kx, 0.22, zc + 0.36), (0.26, 0.3, 0.14), col("#2a2018"))
        for k in range(4):
            leaf_blob(emb, (kx + rng.uniform(-0.08, 0.08), 0.12, zc + 0.38), 0.04, col(rng.choice(["#ff7a1a", "#ffb03a"])))
        SMOKE.append([kx, 1.1, zc])
        for k in range(4):
            amphora(body, (x1 - 0.3 - k * 0.24, 0.0, zc - 0.1 + (k % 2) * 0.2), 0.45, J("#c27a4a", 0.08))
    elif craft == "anvil":  # наковальня, точило, бочка
        body.box((-0.2, 0.25, zc), (0.22, 0.5, 0.22), J("#6b5039", 0.06))
        body.box((-0.2, 0.55, zc), (0.4, 0.12, 0.16), col("#3a3a3c"))
        body.lathe((0.6, 0.0, zc), [(0.16, 0.0), (0.18, 0.25), (0.16, 0.5)], 10, J(P["wood"], 0.06), close_top=True, mat=M_WOOD)
        body.lathe((x0 + 0.45, 0.2, zc), [(0.2, 0.0), (0.2, 0.08)], 12, J(P["stone"], 0.05), close_top=True, mat=M_STONE)
    else:                   # ручная мельница и мешки
        body.lathe((0.0, 0.0, zc), [(0.3, 0.0), (0.28, 0.3), (0.12, 0.6), (0.18, 0.85)], 10, J(P["stone"], 0.06), close_top=True, mat=M_STONE)
        for k in range(3):
            body.lathe((x1 - 0.3 - k * 0.3, 0.0, zc), [(0.12, 0), (0.15, 0.15), (0.12, 0.3), (0.06, 0.36)], 8, J("#d8c49a", 0.06), close_top=True)


# ---------------- товар лавок: мелкие формы ----------------
SIGNS = ["meat", "bread", "shoes", "dye", "togas", "pots", "oil", "lamps", "wine", "perfume", "jewel", "cloth", "barber",
         "medic", "thermo", "taberna", "fullonica", "mansio", "fruit", "veg", "fish", "fresco", "copper", "grain",
         "scriptorium", "school", "library", "academy", "warehouse", "vigiles",
         "herbalist", "sculptor", "catshop", "shelter", "balnea", "baths", "prefect"]
IRON = "#3a3633"
ROPE = "#c9b48a"
BRONZE = "#b08a3a"
CLAY = ["#c27a4a", "#b5703f", "#d08a55", "#a8402a"]


def LP(at, R, x, y, z):
    return tuple(Vector(at) + R @ Vector((x, y, z)))


def _orient(d):
    d = Vector(d).normalized()
    up = Vector((0, 1, 0)) if abs(d.y) < 0.95 else Vector((1, 0, 0))
    a = up.cross(d).normalized()
    b = d.cross(a).normalized()
    return a, b, d


def _ymat(d):
    """поворот, у которого ось y смотрит по d (кольца, лежащие поперёк d)"""
    a, b, dd = _orient(d)
    return Matrix((a, dd, b)).transposed()


def prof_r(prof, t):
    for k in range(len(prof) - 1):
        (r0, t0), (r1, t1) = prof[k], prof[k + 1]
        if t0 <= t <= t1:
            return r0 + (r1 - r0) * (t - t0) / max(1e-6, t1 - t0)
    return prof[-1][0]


def spindle(mb, a, b, prof, seg, c, cols=None, mat=0, sq=(1.0, 1.0)):
    """тело вращения вдоль отрезка a→b; prof — [(радиус, доля длины)]; sq — сплющить сечение"""
    a = Vector(a)
    b = Vector(b)
    L = (b - a).length
    if L < 1e-5:
        return
    ea, eb, ed = _orient(b - a)
    rings = []
    for (r, t) in prof:
        if r < 1e-5:
            v = mb.v(tuple(a + ed * (t * L)))
            rings.append([v] * seg)
            continue
        ring = []
        for s in range(seg):
            an = 2 * math.pi * s / seg
            ring.append(mb.v(tuple(a + ea * (r * sq[0] * math.cos(an)) + eb * (r * sq[1] * math.sin(an)) + ed * (t * L))))
        rings.append(ring)
    uvon = mat in TS
    tsz = TS.get(mat, 1.0)
    circ = 2 * math.pi * max(r for r, _ in prof)
    for k in range(len(rings) - 1):
        cc = cols[min(k, len(cols) - 1)] if cols else c
        mid = tuple(a + ed * ((prof[k][1] + prof[k + 1][1]) / 2 * L))
        for s in range(seg):
            t2 = (s + 1) % seg
            q = [rings[k][s], rings[k][t2], rings[k + 1][t2], rings[k + 1][s]]
            uvq = None
            if uvon:
                c0, c1 = s / seg * circ / tsz, (s + 1) / seg * circ / tsz
                y0, y1 = prof[k][1] * L / tsz, prof[k + 1][1] * L / tsz
                uvq = [(y0, c0), (y0, c1), (y1, c1), (y1, c0)]
            if q[0] is q[1]:
                q, uvq = q[1:], (uvq[1:] if uvq else None)
            elif q[2] is q[3]:
                q, uvq = q[:3], (uvq[:3] if uvq else None)
            mb.face(q, cc, ("from", mid), uv=uvq, mat=mat)
    if prof[0][0] > 1e-5:
        mb.face(rings[0][::-1], cols[0] if cols else c, ("dir", tuple(-ed)), mat=mat)
    if prof[-1][0] > 1e-5:
        mb.face(rings[-1], cols[-1] if cols else c, ("dir", tuple(ed)), mat=mat)


def ball(mb, at, r, c, seg=7, rings=4, sq=(1.0, 1.0, 1.0), cols=None, R=None):
    """шар (сплющенный sq); cols — функция (пояс, долька) → цвет"""
    R = R or Matrix.Identity(3)
    C = Vector(at)
    top = mb.v(tuple(C + R @ Vector((0, r * sq[1], 0))))
    bot = mb.v(tuple(C + R @ Vector((0, -r * sq[1], 0))))
    lat = []
    for i in range(1, rings):
        th = math.pi * i / rings
        lat.append([mb.v(tuple(C + R @ Vector((r * sq[0] * math.sin(th) * math.cos(2 * math.pi * s / seg), r * sq[1] * math.cos(th),
                                                r * sq[2] * math.sin(th) * math.sin(2 * math.pi * s / seg))))) for s in range(seg)])
    cc = (lambda i, s: cols(i, s)) if cols else (lambda i, s: c)
    for s in range(seg):
        t = (s + 1) % seg
        mb.face([lat[0][s], lat[0][t], top], col_shift(cc(0, s), 0.05), ("from", at))
        for i in range(len(lat) - 1):
            mb.face([lat[i][s], lat[i][t], lat[i + 1][t], lat[i + 1][s]], cc(i + 1, s), ("from", at))
        mb.face([lat[-1][t], lat[-1][s], bot], col_shift(cc(rings - 1, s), -0.1), ("from", at))


def disc(mb, at, rx, rz, h, c, R=None, seg=10, top=None):
    """плоская лепёшка с овальным сечением (стейк, светильник, монета)"""
    R = R or Matrix.Identity(3)
    C = Vector(at)
    lo = [mb.v(tuple(C + R @ Vector((rx * math.cos(2 * math.pi * s / seg), 0, rz * math.sin(2 * math.pi * s / seg))))) for s in range(seg)]
    hi = [mb.v(tuple(C + R @ Vector((rx * math.cos(2 * math.pi * s / seg), h, rz * math.sin(2 * math.pi * s / seg))))) for s in range(seg)]
    mid = tuple(C + R @ Vector((0, h / 2, 0)))
    for s in range(seg):
        t = (s + 1) % seg
        mb.face([lo[s], lo[t], hi[t], hi[s]], col_shift(c, -0.08), ("from", mid))
    mb.face(hi, top or col_shift(c, 0.05), ("dir", tuple(R @ Vector((0, 1, 0)))))
    mb.face(lo[::-1], col_shift(c, -0.2), ("dir", tuple(R @ Vector((0, -1, 0)))))


def torus(mb, at, R, rr, r, c, seg=10, seg2=5):
    """кольцо в плоскости xz (ось — y поворота R)"""
    C = Vector(at)
    rings = []
    for i in range(seg):
        a = 2 * math.pi * i / seg
        cen = Vector((rr * math.cos(a), 0, rr * math.sin(a)))
        o = Vector((math.cos(a), 0, math.sin(a)))
        rings.append(([mb.v(tuple(C + R @ (cen + o * (r * math.cos(2 * math.pi * k / seg2)) + Vector((0, r * math.sin(2 * math.pi * k / seg2), 0)))))
                       for k in range(seg2)], C + R @ cen))
    for i in range(seg):
        (ra, ca), (rb, cb) = rings[i], rings[(i + 1) % seg]
        for k in range(seg2):
            kk = (k + 1) % seg2
            mb.face([ra[k], ra[kk], rb[kk], rb[k]], c, ("from", tuple((ca + cb) / 2)))


def rod(mb, a, b, t, c, mat=0):
    a = Vector(a)
    b = Vector(b)
    d = b - a
    if d.length < 1e-5:
        return
    ea, eb, ed = _orient(d)
    mb.box(tuple((a + b) / 2), (t, t, d.length), c, Matrix((ea, eb, ed)).transposed(), mat=mat)


def sag_pts(p0, p1, sag, n):
    p0 = Vector(p0)
    p1 = Vector(p1)
    return [p0 + (p1 - p0) * (i / n) + Vector((0, -sag * 4 * (i / n) * (1 - i / n), 0)) for i in range(n + 1)]


def sheet(mb, grid, nu, nv, colfn, nrm, uvfn=None, mat=M_CLOTH, back=-0.25, off=0.004):
    """двусторонний лист ткани по сетке точек grid[(i, j)]; nrm — куда смотрит лицо"""
    nrm = Vector(nrm)
    F = {k: mb.v(v) for k, v in grid.items()}
    B = {k: mb.v(tuple(Vector(v) - nrm * off)) for k, v in grid.items()}
    for i in range(nu):
        for j in range(nv):
            ks = [(i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)]
            cc = colfn(i, j)
            uv = [uvfn(*k) for k in ks] if uvfn else None
            mb.face([F[k] for k in ks], cc, ("dir", tuple(nrm)), uv=uv, mat=mat)
            mb.face([B[k] for k in ks[::-1]], col_shift(cc, back), ("dir", tuple(-nrm)), uv=uv[::-1] if uv else None, mat=mat)


def drape(mb, P_, N, uc, vtop, w, h, n0, c, folds=3, amp=0.025, hem=0.02):
    """висящее полотно со складками (складки шире книзу, неровный подол)"""
    nu, nv = max(2, folds * 4), 4
    ts = TS[M_CLOTH]
    grid = {}
    for i in range(nu + 1):
        for j in range(nv + 1):
            t = j / nv
            hm = hem * math.sin(i * 1.7 + uc * 9) if j == nv else 0.0
            grid[(i, j)] = Pw(P_, uc - w / 2 + w * i / nu, vtop - h * t + hm,
                              n0 + amp * math.sin(2 * math.pi * folds * i / nu) * (0.3 + 0.7 * t))
    base = J(c, 0.04)
    sheet(mb, grid, nu, nv, lambda i, j: col_shift(base, 0.06 * math.cos(2 * math.pi * folds * (i + 0.5) / nu)), N,
          lambda i, j: (w * i / nu / ts, h * j / nv / ts))


def it_hook(mb, hook, ln=0.07):
    h = Vector(hook)
    rod(mb, h, h + Vector((0, -ln, 0)), 0.008, col(IRON))
    return h + Vector((0, -ln, 0))


# --- мясо ---
def it_ham(mb, hook, s=1.0):
    top = it_hook(mb, hook, 0.05)
    bone = top + Vector((0, -0.06 * s, 0))
    spindle(mb, top, bone, [(0.012 * s, 0), (0.014 * s, 0.5), (0.02 * s, 1.0)], 6, J("#efe6d2", 0.04))
    end = bone + Vector((0.012, -0.36 * s, 0.008))
    prof = [(0.022 * s, 0.0), (0.05 * s, 0.18), (0.085 * s, 0.45), (0.105 * s, 0.72), (0.09 * s, 0.9), (0.0, 1.0)]
    base = J("#8f4a30", 0.05)
    spindle(mb, bone, end, prof, 12, base, sq=(1.0, 0.82), cols=[base, base, base, base, J("#c8806a", 0.04)])
    for t in (0.3, 0.58):                     # верёвочная обвязка
        p = bone + (end - bone) * t
        torus(mb, tuple(p), _ymat(end - bone), prof_r(prof, t) + 0.004, 0.006, col(ROPE), seg=9, seg2=3)


def sausage_chain(mb, pts, r, c):
    for i in range(len(pts) - 1):
        spindle(mb, pts[i], pts[i + 1], [(r * 0.35, 0), (r, 0.22), (r, 0.78), (r * 0.35, 1.0)], 6, J(c, 0.07))


def it_sausages(mb, hook, n=5, r=0.022, c="#8c3a28"):
    p = it_hook(mb, hook, 0.04)
    pts = [p]
    for i in range(n):
        p = p + Vector((math.sin(i * 1.3) * 0.014, -r * 3.3, math.cos(i * 1.1) * 0.01))
        pts.append(p)
    sausage_chain(mb, pts, r, c)


def it_chicken(mb, hook):
    top = it_hook(mb, hook, 0.03)
    for s in (-1, 1):
        rod(mb, top, top + Vector((s * 0.025, -0.1, 0)), 0.01, col("#d9a84a"))
    c = top + Vector((0, -0.2, 0))
    ball(mb, tuple(c), 0.075, J("#ecc9a8", 0.04), seg=8, rings=5, sq=(0.85, 1.25, 0.8))
    for s in (-1, 1):
        ball(mb, tuple(c + Vector((s * 0.06, 0.02, 0))), 0.035, J("#e6bf9c", 0.04), seg=6, rings=3, sq=(0.5, 1.2, 0.8))
    spindle(mb, c + Vector((0, -0.08, 0)), c + Vector((0, -0.17, 0.01)), [(0.018, 0), (0.012, 0.8), (0.0, 1.0)], 5, J("#e6bf9c", 0.04))


def chopping_block(mb, at, r, h):
    mb.lathe(at, [(r, 0.0), (r * 1.03, h * 0.5), (r, h)], 12, J("#6b5039", 0.06), mat=M_WOOD)
    for k, rr in enumerate((r * 0.98, r * 0.74, r * 0.5, r * 0.24)):
        mb.lathe((at[0], at[1] + h + 0.0015 * k, at[2]), [(rr, 0.0), (rr, 0.0015)], 12,
                 col("#c9a46e" if k % 2 == 0 else "#a8834e", rng.uniform(-0.05, 0.05)), close_top=True)


def cleaver(mb, at, R, ang=0.0):
    Rr = R @ Matrix.Rotation(ang, 3, "Y")
    mb.box(LP(at, Rr, 0, 0.035, 0), (0.15, 0.1, 0.008), col("#aab1b8"), Rr)
    mb.box(LP(at, Rr, 0.11, 0.07, 0), (0.1, 0.026, 0.022), J("#5a3a22", 0.05), Rr, mat=M_WOOD)


def knife(mb, at, R, ang=0.0):
    Rr = R @ Matrix.Rotation(ang, 3, "Y")
    mb.box(LP(at, Rr, 0, 0.004, 0), (0.12, 0.006, 0.022), col("#aab1b8"), Rr)
    mb.box(LP(at, Rr, 0.1, 0.008, 0), (0.08, 0.016, 0.018), J("#5a3a22", 0.05), Rr, mat=M_WOOD)


def board(mb, at, R, w, d, c="#a07a52"):
    mb.box(LP(at, R, 0, 0.012, 0), (w, 0.024, d), J(c, 0.06), R, mat=M_WOOD)


def steak(mb, at, R, s=1.0, ang=0.0):
    Rr = R @ Matrix.Rotation(ang, 3, "Y")
    disc(mb, at, 0.085 * s, 0.055 * s, 0.022, J("#efe2cf", 0.03), Rr, seg=10)
    disc(mb, LP(at, Rr, -0.008 * s, 0.0, 0.0), 0.07 * s, 0.045 * s, 0.026, J("#a62e2a", 0.08), Rr, seg=10)


def ribs(mb, at, R):
    mb.box(LP(at, R, 0, 0.02, 0), (0.26, 0.04, 0.14), J("#a8352c", 0.06), R)
    mb.box(LP(at, R, 0, 0.03, -0.05), (0.26, 0.022, 0.04), J("#efe2cf", 0.04), R)
    for k in range(6):
        mb.box(LP(at, R, -0.11 + k * 0.044, 0.042, 0.01), (0.016, 0.012, 0.15), J("#efe6d2", 0.03), R)


# --- дерево, утварь ---
def barrel(mb, at, h, r, top_col=None):
    prof = [(r * 0.86, 0.0), (r, 0.3), (r * 1.04, 0.5), (r, 0.7), (r * 0.86, 1.0)]
    mb.lathe(at, [(rr, t * h) for rr, t in prof], 12, J("#8a6038", 0.06), mat=M_WOOD, close_top=top_col is None)
    for t in (0.1, 0.36, 0.64, 0.9):
        rr = prof_r(prof, t) + 0.005
        mb.lathe((at[0], at[1] + h * t - 0.013, at[2]), [(rr, 0.0), (rr, 0.026)], 12, col(IRON))
    if top_col:
        mb.lathe((at[0], at[1] + h - 0.03, at[2]), [(r * 0.85, 0.0), (r * 0.85, 0.001)], 12, top_col, close_top=True)


def bucket(mb, at, r=0.09, h=0.16, water=True):
    mb.lathe(at, [(r * 0.85, 0.0), (r, h)], 10, J("#8a6038", 0.06), mat=M_WOOD)
    for t in (0.25, 0.8):
        rr = r * (0.85 + 0.15 * t) + 0.004
        mb.lathe((at[0], at[1] + h * t - 0.01, at[2]), [(rr, 0.0), (rr, 0.02)], 10, col(IRON))
    mb.lathe((at[0], at[1] + h * 0.8, at[2]), [(r * 0.95, 0.0), (r * 0.95, 0.001)], 10, col("#5f8fa0") if water else col("#5a3a22"), close_top=True)


def crate(mb, at, R, w, h, d, c="#9a7048"):
    """ящик из реек с щелями"""
    for sx in (-1, 1):
        for sz in (-1, 1):
            mb.box(LP(at, R, sx * (w / 2 - 0.02), h / 2, sz * (d / 2 - 0.02)), (0.04, h, 0.04), J(c, 0.06, 0.01, 0.05), R, mat=M_WOOD)
    ns = max(2, int(h / 0.075))
    for k in range(ns):
        yy = (k + 0.5) * h / ns
        for sz in (-1, 1):
            mb.box(LP(at, R, 0, yy, sz * (d / 2 - 0.006)), (w - 0.03, h / ns * 0.68, 0.012), J(c, 0.08, 0.01, 0.06), R, mat=M_WOOD)
        for sx in (-1, 1):
            mb.box(LP(at, R, sx * (w / 2 - 0.006), yy, 0), (0.012, h / ns * 0.68, d - 0.03), J(c, 0.08, 0.01, 0.06), R, mat=M_WOOD)
    mb.box(LP(at, R, 0, 0.012, 0), (w - 0.03, 0.02, d - 0.03), J(c, 0.1), R, mat=M_WOOD)


def stool(mb, at, h=0.3):
    x, y, z = at
    mb.lathe((x, y + h - 0.03, z), [(0.12, 0.0), (0.12, 0.03)], 10, J("#8a6038", 0.05), close_top=True, mat=M_WOOD)
    for k in range(3):
        a = 2 * math.pi * k / 3 + 0.4
        rod(mb, (x + math.cos(a) * 0.07, y + h - 0.03, z + math.sin(a) * 0.07), (x + math.cos(a) * 0.11, y, z + math.sin(a) * 0.11), 0.025,
            J("#6b4428", 0.05), mat=M_WOOD)


def bench2(mb, at, R, ln=0.8):
    mb.box(LP(at, R, 0, 0.3, 0), (ln, 0.04, 0.24), J("#7a5232", 0.06), R, mat=M_WOOD)
    for s in (-1, 1):
        mb.box(LP(at, R, s * (ln / 2 - 0.08), 0.14, 0), (0.05, 0.28, 0.2), J("#5e3d24", 0.06), R, mat=M_WOOD)


def broom(mb, at, R):
    a = Vector(LP(at, R, 0, 0.12, 0))
    b = Vector(LP(at, R, 0.12, 0.95, -0.12))
    rod(mb, a, b, 0.022, J("#8a6038", 0.05), mat=M_WOOD)
    spindle(mb, a + (a - b).normalized() * 0.18, a + (b - a).normalized() * 0.04, [(0.08, 0.0), (0.05, 0.6), (0.02, 1.0)], 8, J("#d9c27a", 0.08))


def shelf_unit(mb, S, fill):
    su0, su1, sn, lv = S["shelf"]
    R, P_ = S["R"], S["P"]
    for uu in (su0, su1):
        mb.box(Pw(P_, uu, (PL + lv[-1] + 0.04) / 2, sn), (0.04, lv[-1] + 0.04 - PL, 0.26), J("#5e3d24", 0.05), R, mat=M_WOOD)
    for v in lv:
        mb.box(Pw(P_, (su0 + su1) / 2, v - 0.015, sn), (su1 - su0 + 0.04, 0.03, 0.26), J("#7a5232", 0.06), R, mat=M_WOOD)
        fill(v, su0 + 0.07, su1 - 0.07, sn)


def row(a, b, k):
    return [a + (b - a) * (i + 0.5) / k for i in range(k)]


def hooks(S, k):
    ru0, ru1, rv, rn = S["rail"]
    return [Pw(S["P"], u, rv, rn) for u in row(ru0, ru1, k)]


# --- посуда, хлеб ---
def jug(mb, at, h, c, handle=True):
    prof = [(h * 0.2, 0.0), (h * 0.3, h * 0.15), (h * 0.34, h * 0.42), (h * 0.24, h * 0.7), (h * 0.12, h * 0.82), (h * 0.13, h * 0.95), (h * 0.17, h)]
    mb.lathe(at, prof, 10, c, close_top=True)
    if handle:
        x, y, z = at
        rod(mb, (x + h * 0.12, y + h * 0.9, z), (x + h * 0.36, y + h * 0.76, z), h * 0.05, c)
        rod(mb, (x + h * 0.36, y + h * 0.76, z), (x + h * 0.3, y + h * 0.45, z), h * 0.05, c)


def bowl(mb, at, r, c, food=None):
    mb.lathe(at, [(r * 0.45, 0.0), (r * 0.8, r * 0.22), (r, r * 0.48)], 10, c)
    mb.lathe((at[0], at[1] + r * 0.38, at[2]), [(r * 0.9, 0.0), (r * 0.9, 0.001)], 10, col(food) if food else col_shift(c, -0.3), close_top=True)
    if food:
        ball(mb, (at[0], at[1] + r * 0.4, at[2]), r * 0.7, J(food, 0.06), seg=7, rings=3, sq=(1.0, 0.35, 1.0))


def plate_stack(mb, at, r, n, c):
    for k in range(n):
        mb.lathe((at[0], at[1] + k * 0.013, at[2]), [(r * 0.7, 0.0), (r, 0.01), (r, 0.013)], 10, J(c, 0.04), close_top=True)


def cup(mb, at, r, c):
    x, y, z = at
    mb.lathe(at, [(r * 0.35, 0.0), (r * 0.3, r * 0.3), (r * 0.6, r * 0.5), (r, r * 0.95)], 9, c)
    mb.lathe((x, y + r * 0.8, z), [(r * 0.92, 0.0), (r * 0.92, 0.001)], 9, col_shift(c, -0.35), close_top=True)


def amphora_ax(mb, base, top, c):
    h = (Vector(top) - Vector(base)).length
    spindle(mb, base, top, [(0.0, 0.0), (h * 0.06, 0.05), (h * 0.2, 0.3), (h * 0.22, 0.5), (h * 0.16, 0.72), (h * 0.07, 0.82),
                            (h * 0.065, 0.95), (h * 0.085, 1.0)], 9, c)


def amphora_rack(mb, P_, U, N, uc, n, k=3, h=0.52):
    """деревянная стойка, к перекладине прислонены амфоры"""
    R = RW(U, N)
    w = k * 0.25 + 0.12
    for vv in (0.2, 0.42):
        mb.box(Pw(P_, uc, vv, n - 0.1), (w, 0.04, 0.045), J("#6b4428", 0.05), R, mat=M_WOOD)
    for s in (-1, 1):
        mb.box(Pw(P_, uc + s * w / 2, 0.23, n - 0.1), (0.045, 0.46, 0.045), J("#5e3d24", 0.05), R, mat=M_WOOD)
    for i in range(k):
        uu = uc - w / 2 + 0.185 + i * 0.25
        amphora_ax(mb, Pw(P_, uu, 0.02, n + 0.13), Pw(P_, uu + 0.02 * (i - 1), 0.02 + h * 0.96, n - 0.09), col_shift(J(rng.choice(CLAY[:3]), 0.06), -0.12))


def bread_round(mb, at, r, c="#b9773a"):
    """круглый хлеб с восемью насечками (panis quadratus из Помпей)"""
    h = r * 0.62
    seg = 16
    prof = [(r * 0.96, 0.0), (r, h * 0.3), (r * 0.9, h * 0.7), (r * 0.55, h * 0.95), (r * 0.14, h)]
    x, y, z = at
    rings = []
    for (rr, yy) in prof:
        rings.append([mb.v((x + rr * (0.84 if (s % 2 == 0 and yy > h * 0.25) else 1.0) * math.cos(2 * math.pi * s / seg), y + yy,
                            z + rr * (0.84 if (s % 2 == 0 and yy > h * 0.25) else 1.0) * math.sin(2 * math.pi * s / seg))) for s in range(seg)])
    base = J(c, 0.08)
    cs = [col_shift(base, -0.12), base, col_shift(base, -0.05), col_shift(base, -0.15)]
    for k in range(len(rings) - 1):
        for s in range(seg):
            t = (s + 1) % seg
            mb.face([rings[k][s], rings[k][t], rings[k + 1][t], rings[k + 1][s]], cs[k], ("from", (x, y + h * 0.3, z)))
    mb.face(rings[-1], col_shift(base, 0.1), ("dir", (0, 1, 0)))
    mb.face(rings[0][::-1], col_shift(base, -0.3), ("dir", (0, -1, 0)))


def loaf_long(mb, at, R, l=0.22, c="#c08442", ang=0.0):
    Rr = R @ Matrix.Rotation(ang, 3, "Y")
    spindle(mb, LP(at, Rr, -l / 2, 0.035, 0), LP(at, Rr, l / 2, 0.035, 0), [(0.015, 0.0), (0.04, 0.15), (0.045, 0.5), (0.04, 0.85), (0.015, 1.0)], 8,
            J(c, 0.08), sq=(1.0, 0.75))


# --- обувь, кожа ---
def shoe(mb, at, R, c, boot=False, ang=0.0):
    Rr = R @ Matrix.Rotation(ang, 3, "Y")
    mb.box(LP(at, Rr, 0, 0.008, 0), (0.06, 0.016, 0.17), col("#3a2a1e"), Rr)
    spindle(mb, LP(at, Rr, 0, 0.032, -0.078), LP(at, Rr, 0, 0.022, 0.085), [(0.026, 0.0), (0.032, 0.25), (0.029, 0.6), (0.016, 0.92), (0.0, 1.0)], 7,
            J(c, 0.06), sq=(1.0, 0.8))
    if boot:
        mb.lathe(LP(at, Rr, 0, 0.03, -0.055), [(0.03, 0.0), (0.032, 0.11), (0.035, 0.15)], 7, J(c, 0.06))
        mb.box(LP(at, Rr, 0, 0.12, -0.03), (0.05, 0.01, 0.012), col(ROPE), Rr)


def sandal(mb, at, R, c, ang=0.0):
    Rr = R @ Matrix.Rotation(ang, 3, "Y")
    mb.box(LP(at, Rr, 0, 0.008, 0), (0.062, 0.016, 0.17), J("#8a5a32", 0.05), Rr)
    for zz in (-0.05, 0.0, 0.05):
        mb.box(LP(at, Rr, 0, 0.022, zz), (0.066, 0.014, 0.012), J(c, 0.05), Rr)
    mb.box(LP(at, Rr, 0, 0.045, -0.078), (0.052, 0.05, 0.01), J(c, 0.05), Rr)


def it_sandals(mb, hook, R, c):
    top = it_hook(mb, hook, 0.05)
    for s in (-1, 1):
        Rh = R @ Matrix.Rotation(math.pi / 2, 3, "X") @ Matrix.Rotation(s * 0.15, 3, "Y")
        sandal(mb, tuple(top + R @ Vector((s * 0.04, -0.09, 0.02))), Rh, c)


def it_boots(mb, hook, R, c):
    top = it_hook(mb, hook, 0.04)
    for s in (-1, 1):
        Rh = R @ Matrix.Rotation(math.pi, 3, "X") @ Matrix.Rotation(s * 0.2, 3, "Y")
        shoe(mb, tuple(top + R @ Vector((s * 0.04, -0.02, 0.0))), Rh, c, boot=True)


def hide(mb, P_, N, uc, vtop, w, h, n, c):
    """распяленная шкура: неровный край с «лапами»"""
    vc = vtop - h / 2
    pts = []
    for k in range(14):
        a = 2 * math.pi * k / 14
        jag = 1.0 + (0.2 if k % 7 in (1, 3, 4, 6) else -0.05) + rng.uniform(-0.05, 0.05)
        pts.append(P_(uc + math.cos(a) * w / 2 * jag, vc + math.sin(a) * h / 2 * jag, n + 0.012 * math.sin(a * 3)))
    base = J(c, 0.06)
    for off, dirv, cc in ((0.0, N, base), (-0.004, -N, col_shift(base, -0.25))):
        ctr = mb.v(tuple(P_(uc, vc, n + 0.015 + off)))
        ring = [mb.v(tuple(p + N * off)) for p in pts]
        for k in range(14):
            mb.face([ring[k], ring[(k + 1) % 14], ctr], cc, ("dir", tuple(dirv)))


# --- ткани ---
def tunic(mb, P_, N, R, uc, vtop, n0, c, stripe=None):
    mb.box(Pw(P_, uc, vtop + 0.012, n0), (0.46, 0.022, 0.022), J("#6b4428", 0.05), R, mat=M_WOOD)
    drape(mb, P_, N, uc, vtop, 0.34, 0.5, n0 + 0.012, c, folds=3, amp=0.012)
    for s in (-1, 1):
        drape(mb, P_, N, uc + s * 0.22, vtop - 0.005, 0.11, 0.17, n0 + 0.008, c, folds=1, amp=0.008)
    if stripe:
        for s in (-1, 1):
            mb.box(Pw(P_, uc + s * 0.08, vtop - 0.25, n0 + 0.03), (0.032, 0.5, 0.004), col(stripe), R)


def bolt(mb, a, b, r, c):
    a = Vector(a)
    b = Vector(b)
    spindle(mb, a, b, [(r, 0.0), (r, 1.0)], 10, J(c, 0.04), mat=M_CLOTH)
    d = (b - a).normalized()
    for p, sgn in ((a, -1), (b, 1)):
        spindle(mb, p - d * 0.002 * sgn, p + d * 0.004 * sgn, [(r * 0.62, 0.0), (r * 0.62, 1.0)], 10, col_shift(J(c, 0.04), -0.18))
        spindle(mb, p - d * 0.002 * sgn, p + d * 0.008 * sgn, [(r * 0.2, 0.0), (r * 0.2, 1.0)], 6, J("#8a6038", 0.05))


def folded_stack(mb, at, R, w, d, n, cols):
    y = 0.0
    for k in range(n):
        hh = rng.uniform(0.03, 0.04)
        Rr = R @ Matrix.Rotation(rng.uniform(-0.08, 0.08), 3, "Y")
        mb.box(LP(at, Rr, rng.uniform(-0.01, 0.01), y + hh / 2, 0), (w, hh, d), J(cols[k % len(cols)], 0.04), Rr, mat=M_CLOTH)
        y += hh
    return y


def skein(mb, hook, N, c):
    top = it_hook(mb, hook, 0.03)
    torus(mb, tuple(top + Vector((0, -0.07, 0))), _ymat(N), 0.065, 0.02, J(c, 0.05), seg=10, seg2=5)


def wool_balls(mb, at, k, cols):
    for i in range(k):
        a = 2 * math.pi * i / k
        ball(mb, (at[0] + math.cos(a) * 0.05, at[1] + 0.035 + (0.04 if i == k - 1 else 0.0), at[2] + math.sin(a) * 0.05), 0.038,
             J(cols[i % len(cols)], 0.06), seg=7, rings=4)


# --- светильники, стекло, золото ---
def lucerna(mb, emb, at, R, c, lit=False, s=1.0):
    disc(mb, at, 0.045 * s, 0.045 * s, 0.022 * s, J(c, 0.06), R, seg=10)
    spindle(mb, LP(at, R, 0, 0.012 * s, 0.03 * s), LP(at, R, 0, 0.012 * s, 0.078 * s), [(0.017 * s, 0.0), (0.012 * s, 1.0)], 6, J(c, 0.06))
    mb.box(LP(at, R, 0, 0.026 * s, -0.047 * s), (0.012 * s, 0.03 * s, 0.022 * s), J(c, 0.06), R)
    mb.lathe(LP(at, R, 0, 0.022 * s, 0), [(0.013 * s, 0), (0.009 * s, 0.003)], 6, col("#3a2a1a"), close_top=True)
    if lit:
        leaf_blob(emb, LP(at, R, 0, 0.032 * s, 0.08 * s), 0.013 * s, col("#ffb03a"))


def hanging_lamp(mb, emb, hook):
    h = Vector(hook)
    c = h + Vector((0, -0.22, 0))
    for k in range(3):
        a = 2 * math.pi * k / 3
        rod(mb, h, c + Vector((math.cos(a) * 0.04, 0.01, math.sin(a) * 0.04)), 0.004, col("#6a5a3a"))
    mb.lathe(tuple(c + Vector((0, -0.02, 0))), [(0.015, 0), (0.055, 0.02), (0.05, 0.032)], 10, J(BRONZE, 0.06), close_top=True)
    for k in range(2):
        a = math.pi * k
        leaf_blob(emb, tuple(c + Vector((math.cos(a) * 0.06, 0.03, math.sin(a) * 0.06))), 0.014, col("#ffb03a"))


def candelabrum(mb, emb, at, h=1.0):
    x, y, z = at
    for k in range(3):
        a = 2 * math.pi * k / 3 + 0.5
        rod(mb, (x, y + 0.13, z), (x + math.cos(a) * 0.13, y + 0.005, z + math.sin(a) * 0.13), 0.016, col("#9a7a3a"))
    mb.lathe((x, y + 0.1, z), [(0.02, 0.0), (0.013, 0.08), (0.011, h * 0.8), (0.016, h * 0.84), (0.011, h * 0.88), (0.012, h * 0.9 - 0.1)], 8, J(BRONZE, 0.05))
    mb.lathe((x, y + h - 0.02, z), [(0.02, 0.0), (0.075, 0.02), (0.075, 0.03)], 10, J(BRONZE, 0.05), close_top=True)
    lucerna(mb, emb, (x, y + h + 0.01, z), Matrix.Identity(3), "#b08a3a", lit=True, s=0.9)


def bottle(mb, at, h, c):
    prof = [(h * 0.12, 0.0), (h * 0.25, h * 0.15), (h * 0.27, h * 0.35), (h * 0.12, h * 0.55), (h * 0.06, h * 0.62), (h * 0.055, h * 0.92), (h * 0.08, h)]
    mb.lathe(at, prof, 8, c, close_top=True)


GLASS = ["#4fb0c8", "#e8a33a", "#8a6ad0", "#e87aa8", "#5ac87a", "#c84f4f"]


def steps(mb, at, R, w, k=3, dz=0.1, dy=0.07):
    """ступенчатая подставка для мелкого товара; возвращает [(y, z)] полок"""
    out = []
    for i in range(k):
        mb.box(LP(at, R, 0, dy * (i + 0.5), -dz * i), (w, dy * (i + 1), dz), J("#7a5232", 0.06), R, mat=M_WOOD)
        out.append((dy * (i + 1), -dz * i))
    return out


def necklace(mb, p0, p1, sag, n, gem=None):
    pts = sag_pts(p0, p1, sag, n)
    for i, p in enumerate(pts):
        g = gem and i % 3 == 1
        ball(mb, tuple(p), 0.011 if g else 0.008, col(gem[i % len(gem)] if g else "#e8c45a"), seg=5, rings=3)
    ball(mb, tuple(pts[n // 2] + Vector((0, -0.02, 0))), 0.016, col("#c8303a" if not gem else gem[0]), seg=6, rings=3)


def tray(mb, at, R, w, d, c="#6a2a3a"):
    mb.box(LP(at, R, 0, 0.012, 0), (w + 0.03, 0.024, d + 0.03), J("#5e3d24", 0.05), R, mat=M_WOOD)
    mb.box(LP(at, R, 0, 0.026, 0), (w, 0.006, d), J(c, 0.04), R, mat=M_CLOTH)


def scales(mb, at, R, s=1.0):
    mb.lathe(at, [(0.05 * s, 0.0), (0.045 * s, 0.016 * s)], 10, J("#5e3d24", 0.05), close_top=True, mat=M_WOOD)
    rod(mb, at, LP(at, R, 0, 0.3 * s, 0), 0.012 * s, col("#6a5a3a"))
    mb.box(LP(at, R, 0, 0.3 * s, 0), (0.3 * s, 0.01 * s, 0.01 * s), col(BRONZE), R)
    for sx in (-1, 1):
        top = Vector(LP(at, R, sx * 0.14 * s, 0.3 * s, 0))
        pan = Vector(LP(at, R, sx * 0.14 * s, 0.12 * s, 0))
        for k in range(3):
            a = 2 * math.pi * k / 3
            rod(mb, top, pan + Vector((math.cos(a) * 0.04 * s, 0.01, math.sin(a) * 0.04 * s)), 0.003, col("#6a5a3a"))
        mb.lathe(tuple(pan), [(0.02 * s, 0.0), (0.05 * s, 0.015 * s)], 10, col(BRONZE))


def arca(mb, at, R, w=0.34, h=0.22, d=0.22):
    mb.box(LP(at, R, 0, h / 2, 0), (w, h, d), J("#6b4428", 0.05), R, mat=M_WOOD)
    for xx in (-w * 0.36, 0.0, w * 0.36):
        mb.box(LP(at, R, xx, h / 2, 0), (0.024, h + 0.006, d + 0.006), col(IRON), R)
    mb.box(LP(at, R, 0, h * 0.72, d / 2 + 0.006), (0.05, 0.05, 0.01), col(BRONZE), R)


def mortar(mb, at, R, r=0.07, herb="#6a7a3a"):
    mb.lathe(at, [(r * 0.7, 0.0), (r, r * 0.6), (r * 1.05, r * 0.9)], 10, J("#c9c0b0", 0.04))
    mb.lathe((at[0], at[1] + r * 0.72, at[2]), [(r * 0.9, 0.0), (r * 0.9, 0.001)], 10, J(herb, 0.08), close_top=True)
    spindle(mb, LP(at, R, 0.01, r * 0.5, 0), LP(at, R, 0.07, r * 2.4, -0.03), [(0.014, 0.0), (0.012, 0.6), (0.018, 1.0)], 6, J("#bfb6a6", 0.04))


def scroll(mb, at, R, l=0.2, r=0.024):
    a = Vector(LP(at, R, -l / 2, r, 0))
    b = Vector(LP(at, R, l / 2, r, 0))
    spindle(mb, a, b, [(r, 0.0), (r, 1.0)], 8, J("#e8dcb8", 0.04))
    d = (b - a).normalized()
    for p, sgn in ((a, -1), (b, 1)):
        spindle(mb, p, p + d * 0.02 * sgn, [(r * 0.35, 0.0), (r * 0.45, 1.0)], 6, J("#5a3a22", 0.05))


def jar(mb, at, h, c, lid="#7a5232"):
    mb.lathe(at, [(h * 0.3, 0.0), (h * 0.38, h * 0.4), (h * 0.3, h * 0.85), (h * 0.26, h * 0.9)], 8, c, close_top=True)
    mb.lathe((at[0], at[1] + h * 0.88, at[2]), [(h * 0.3, 0.0), (h * 0.3, h * 0.07), (h * 0.08, h * 0.11), (h * 0.06, h * 0.2)], 8, col(lid), close_top=True)


# --- растения, овощи, фрукты, рыба ---
def herb_bundle(mb, hook, c="#5f7f3a", fl=None):
    top = it_hook(mb, hook, 0.04)
    for k in range(6):
        a = 2 * math.pi * k / 6
        end = top + Vector((math.cos(a) * 0.045, -0.22, math.sin(a) * 0.045))
        rod(mb, top, end, 0.006, col("#6a7a3a"))
        leaf_blob(mb, tuple(end + Vector((0, 0.05, 0))), 0.036, J(c, 0.1))
        leaf_blob(mb, tuple(end + Vector((0, 0.11, 0))), 0.028, J(c, 0.1))
        if fl:
            leaf_blob(mb, tuple(end), 0.02, J(fl, 0.08))
    torus(mb, tuple(top + Vector((0, -0.03, 0))), Matrix.Identity(3), 0.02, 0.006, col(ROPE), seg=8, seg2=3)


def garlic_braid(mb, hook, n=6, c="#efe6d2"):
    top = it_hook(mb, hook, 0.03)
    rod(mb, top, top + Vector((0, -n * 0.045, 0)), 0.009, col(ROPE))
    for i in range(n):
        p = top + Vector(((i % 2 - 0.5) * 0.034, -0.03 - i * 0.045, 0.012 * (i % 3 - 1)))
        mb.lathe((p.x, p.y - 0.028, p.z), [(0.008, 0.0), (0.028, 0.012), (0.026, 0.032), (0.005, 0.054)], 7, J(c, 0.05), close_top=True)


def grapes(mb, top, s=1.0, c="#5a2d5f"):
    t = Vector(top)
    rod(mb, t, t + Vector((0, 0.03 * s, 0)), 0.005, col("#6a5a3a"))
    y = 0.0
    for ri, k in enumerate((5, 5, 4, 3, 2, 1)):
        rr = 0.011 * s * k / 1.6 + 0.002
        for i in range(k):
            a = 2 * math.pi * i / k + ri * 0.6
            ball(mb, tuple(t + Vector((math.cos(a) * rr, -y, math.sin(a) * rr))), 0.013 * s, J(c, 0.1), seg=5, rings=3)
        y += 0.019 * s
    leaf_blob(mb, tuple(t + Vector((0.02, 0.02, 0))), 0.03 * s, J("#5f8f3a", 0.1))


def fruit(mb, at, kind, s=1.0):
    x, y, z = at
    if kind == "apple":
        ball(mb, (x, y + 0.03 * s, z), 0.032 * s, J(rng.choice(["#c0392b", "#d9534f", "#a8c04a", "#e8862e"]), 0.08), seg=7, rings=4, sq=(1, 0.9, 1))
        mb.box((x, y + 0.062 * s, z), (0.004, 0.016, 0.004), col("#5a3a22"))
    elif kind == "pear":
        mb.lathe((x, y, z), [(0.02 * s, 0.0), (0.034 * s, 0.025 * s), (0.027 * s, 0.05 * s), (0.015 * s, 0.075 * s), (0.005 * s, 0.09 * s)], 7,
                 J("#c8c04a", 0.08), close_top=True)
    elif kind == "pom":
        ball(mb, (x, y + 0.038 * s, z), 0.04 * s, J("#b02a2a", 0.08), seg=7, rings=4)
        mb.lathe((x, y + 0.074 * s, z), [(0.012 * s, 0.0), (0.008 * s, 0.012 * s), (0.012 * s, 0.018 * s)], 6, col("#8a2020"))
    elif kind == "fig":
        mb.lathe((x, y, z), [(0.018 * s, 0.0), (0.028 * s, 0.02 * s), (0.018 * s, 0.045 * s), (0.004 * s, 0.058 * s)], 7, J("#5a2d4f", 0.08), close_top=True)
    elif kind == "melon":
        ball(mb, (x, y + 0.07 * s, z), 0.08 * s, col("#5f8a3a"), seg=10, rings=5, sq=(1.15, 0.9, 1.0),
             cols=lambda i, k: col("#5f8a3a" if k % 2 else "#a8c070", -0.03 * i))
    elif kind == "cabbage":
        ball(mb, (x, y + 0.06 * s, z), 0.06 * s, J("#a8c870", 0.06), seg=8, rings=4)
        for k in range(6):
            a = 2 * math.pi * k / 6
            ball(mb, (x + math.cos(a) * 0.045 * s, y + 0.05 * s, z + math.sin(a) * 0.045 * s), 0.04 * s, J("#6f9a4a", 0.08), seg=6, rings=3,
                 sq=(0.7, 1.0, 0.45), R=Matrix.Rotation(-a, 3, "Y"))
    elif kind == "onion":
        mb.lathe((x, y, z), [(0.012 * s, 0.0), (0.032 * s, 0.022 * s), (0.026 * s, 0.045 * s), (0.004 * s, 0.07 * s)], 8,
                 J(rng.choice(["#c08a3a", "#8a3a5a", "#d9b46a"]), 0.06), close_top=True)
    elif kind == "turnip":
        ball(mb, (x, y + 0.03 * s, z), 0.03 * s, col("#efe6e0"), seg=7, rings=4, cols=lambda i, k: col("#8a3a6a" if i == 0 else "#efe6e0"))
        for k in range(3):
            leaf_blob(mb, (x + (k - 1) * 0.012, y + 0.07 * s, z), 0.02 * s, J("#5f8f3a", 0.1))


def carrot(mb, a, b):
    spindle(mb, a, b, [(0.018, 0.0), (0.016, 0.3), (0.008, 0.8), (0.0, 1.0)], 6, J("#e07a2a", 0.06))
    d = (Vector(a) - Vector(b)).normalized()
    for k in range(3):
        leaf_blob(mb, tuple(Vector(a) + d * (0.03 + k * 0.02) + Vector((0, 0.01 * k, 0))), 0.02, J("#5f9a3a", 0.1))


def leek(mb, a, b):
    spindle(mb, a, b, [(0.016, 0.0), (0.016, 0.55), (0.02, 0.75), (0.008, 1.0)], 6, J("#e8e8c8", 0.04),
            cols=[col("#f0eedc"), col("#c8d890"), col("#5f8f3a")])


def fish(mb, at, R, l=0.26, c="#9aa6b2", ang=0.0):
    """рыба на боку: тело, хвост, плавник, глаз"""
    Rr = R @ Matrix.Rotation(ang, 3, "Y")
    head = Vector(LP(at, Rr, l * 0.45, 0.022, 0))
    tail = Vector(LP(at, Rr, -l * 0.4, 0.022, 0))
    belly = col("#d9dfe5")
    spindle(mb, head, tail, [(0.0, 0.0), (0.03, 0.14), (0.036, 0.4), (0.022, 0.75), (0.007, 1.0)], 8, J(c, 0.05),
            cols=[col_shift(J(c, 0.04), -0.1), J(c, 0.04), J(c, 0.04), col_shift(belly, -0.1)], sq=(1.0, 0.42))
    sd = Rr @ Vector((0, 0, 1))
    tb = Vector(LP(at, Rr, -l * 0.4, 0.024, 0))
    for cc, off in ((J(c, 0.05), 0.0), (col_shift(J(c, 0.05), -0.2), -0.003)):
        q = [tb, tb + (tail - head).normalized() * 0.07 + sd * 0.045, tb + (tail - head).normalized() * 0.07 - sd * 0.045]
        mb.face([mb.v(tuple(p + Vector((0, off, 0)))) for p in q], cc, ("dir", (0, 1 if off == 0 else -1, 0)))
    mb.box(LP(at, Rr, l * 0.33, 0.034, 0.012), (0.01, 0.006, 0.01), col("#1a1a1a"), Rr)


def octopus(mb, at, R):
    x, y, z = at
    ball(mb, (x, y + 0.04, z), 0.045, J("#c9605a", 0.05), seg=8, rings=4, sq=(1.0, 0.8, 1.25))
    for k in range(8):
        a = 2 * math.pi * k / 8
        p = Vector((x + math.cos(a) * 0.03, y + 0.015, z + math.sin(a) * 0.03))
        pts = [p]
        for j in range(4):
            b = a + 0.35 * j
            p = p + Vector((math.cos(b) * 0.035, 0.0, math.sin(b) * 0.035))
            pts.append(p)
        for j in range(4):
            spindle(mb, pts[j], pts[j + 1], [(0.012 * (1 - j / 4.5), 0.0), (0.012 * (1 - (j + 1) / 4.5), 1.0)], 5, J("#c9605a", 0.06))


def sack(mb, at, r=0.13, h=0.3, grain="#e3c46a", open_=True):
    if open_:
        mb.lathe(at, [(r * 0.85, 0.0), (r, h * 0.3), (r * 0.95, h * 0.72), (r * 1.06, h * 0.86), (r * 1.08, h)], 9, J("#d8c49a", 0.06), mat=M_CLOTH)
        mb.lathe((at[0], at[1] + h * 0.92, at[2]), [(r * 1.0, 0.0), (r * 1.0, 0.001)], 9, J(grain, 0.05), close_top=True)
        ball(mb, (at[0], at[1] + h * 0.93, at[2]), r * 0.75, J(grain, 0.06), seg=8, rings=3, sq=(1.0, 0.35, 1.0))
    else:
        mb.lathe(at, [(r * 0.85, 0.0), (r, h * 0.3), (r * 0.95, h * 0.72), (r * 0.45, h * 0.9), (r * 0.25, h)], 9, J("#d8c49a", 0.06), mat=M_CLOTH,
                 close_top=True)
        torus(mb, (at[0], at[1] + h * 0.9, at[2]), Matrix.Identity(3), r * 0.45, 0.008, col(ROPE), seg=8, seg2=3)


def brazier(mb, emb, at):
    x, y, z = at
    for k in range(3):
        a = 2 * math.pi * k / 3
        rod(mb, (x + math.cos(a) * 0.06, y + 0.3, z + math.sin(a) * 0.06), (x + math.cos(a) * 0.14, y, z + math.sin(a) * 0.14), 0.016, col(IRON))
    mb.lathe((x, y + 0.28, z), [(0.06, 0.0), (0.15, 0.07), (0.16, 0.09)], 10, col(IRON))
    for k in range(6):
        leaf_blob(emb, (x + rng.uniform(-0.08, 0.08), y + 0.36, z + rng.uniform(-0.08, 0.08)), 0.03, col(rng.choice(["#ff7a1a", "#ffb03a", "#e0501a"])))
    mb.lathe((x, y + 0.37, z), [(0.06, 0.0), (0.09, 0.05), (0.08, 0.1), (0.09, 0.11)], 9, col("#2a2420"), close_top=True)


def plant_pot(mb, at, h=0.32):
    """горшок с кустиком (лавр, розмарин): листва шапкой в два зелёных"""
    x, y, z = at
    mb.lathe(at, [(h * 0.22, 0.0), (h * 0.34, h * 0.35), (h * 0.33, h * 0.75), (h * 0.37, h * 0.8), (h * 0.36, h * 0.9)], 10, J("#b8693f", 0.08))
    mb.lathe((x, y + h * 0.82, z), [(h * 0.33, 0.0), (h * 0.33, 0.001)], 10, col("#4a3524"), close_top=True)
    for k in range(14):
        a = 2 * math.pi * k / 7 + (0.4 if k >= 7 else 0.0)
        rr = h * (0.28 if k < 7 else 0.14)
        leaf_blob(mb, (x + math.cos(a) * rr, y + h * (1.05 if k < 7 else 1.3) + rng.uniform(-0.03, 0.03), z + math.sin(a) * rr), h * 0.2,
                  J(rng.choice(["#4f7d33", "#5f8f3a", "#3f6b2a"]), 0.1))


# =====================================================================================
#   ТОВАР ЛАВОК (S — места: прилавок u0..u1 на высоте y, перекладина rail, полка позади, «улица» out, вход ent)
# =====================================================================================
def g_meat(b, e, S):
    P_, R, y, u0, u1 = S["P"], S["R"], S["y"], S["u0"], S["u1"]
    for i, h in enumerate(hooks(S, 7)):
        (it_ham(b, h, 1.0 + 0.08 * (i % 2)) if i % 3 == 0 else (it_sausages(b, h, 5) if i % 3 == 1 else it_chicken(b, h)))
    ru0, ru1, rv, rn = S["rail"]
    sausage_chain(b, sag_pts(Pw(P_, ru0, rv - 0.02, rn + 0.03), Pw(P_, ru1, rv - 0.02, rn + 0.03), 0.09, 18), 0.02, "#9a4030")
    chopping_block(b, Pw(P_, u0 + 0.16, y, 0.04), 0.14, 0.13)
    cleaver(b, Pw(P_, u0 + 0.16, y + 0.135, 0.04), R, 0.5)
    board(b, Pw(P_, u0 + 0.58, y, 0.06), R, 0.42, 0.26)
    for k in range(3):
        steak(b, Pw(P_, u0 + 0.45 + k * 0.13, y + 0.024, 0.04 + (k % 2) * 0.05), R, 1.0, rng.uniform(-0.5, 0.5))
    knife(b, Pw(P_, u0 + 0.6, y + 0.024, 0.16), R, 0.2)
    ribs(b, Pw(P_, u1 - 0.22, y, 0.05), R)
    bowl(b, Pw(P_, u1 - 0.06, y, -0.09), 0.07, J("#c27a4a", 0.05), food="#8c3a28")
    shelf_unit(b, S, lambda v, a, c, n: [jar(b, Pw(P_, uu, v, n), 0.17, J(rng.choice(["#c27a4a", "#e8e2d6", "#9a6a3a"]), 0.06)) for uu in row(a, c, 5)])
    ou0, ou1, on = S["out"]
    barrel(b, Pw(P_, ou0 + 0.25, 0.0, on), 0.42, 0.15, top_col=col("#efece4"))
    bucket(b, Pw(P_, ou0 + 0.56, 0.0, on + 0.04))


def g_bread(b, e, S):
    P_, R, N, y, u0, u1 = S["P"], S["R"], S["N"], S["y"], S["u0"], S["u1"]
    for h in hooks(S, 4):                      # бублики-«буцеллаты» связками
        top = it_hook(b, h, 0.05)
        rod(b, top, top + Vector((0, -0.24, 0)), 0.006, col(ROPE))
        for k in range(3):
            torus(b, tuple(top + Vector((0, -0.07 - k * 0.075, 0))), _ymat(N), 0.045, 0.018, J("#c08442", 0.08), seg=10, seg2=5)
    for bu in (u0 + 0.25, u0 + 0.75):          # доски с горками круглых хлебов
        board(b, Pw(P_, bu, y, 0.04), R, 0.44, 0.3)
        for k, (du, dn, dy) in enumerate(((-0.12, -0.06, 0), (0.0, -0.07, 0), (0.12, -0.05, 0), (-0.07, 0.07, 0), (0.07, 0.08, 0), (0.0, 0.0, 0.05))):
            bread_round(b, Pw(P_, bu + du, y + 0.024 + dy, 0.04 + dn), 0.07)
    basket(b, Pw(P_, u1 - 0.12, y, 0.02), 0.12, 0.12)
    for k in range(3):
        loaf_long(b, Pw(P_, u1 - 0.14 + (k - 1) * 0.05, y + 0.1, 0.02), R, 0.18, "#c8904a", 1.2 + k * 0.3)
    shelf_unit(b, S, lambda v, a, c, n: [bread_round(b, Pw(P_, uu, v, n + (0.05 if i % 2 else -0.04)), 0.07) for i, uu in enumerate(row(a, c, 7))])
    ou0, ou1, on = S["out"]
    sack(b, Pw(P_, ou0 + 0.22, 0.0, on), 0.14, 0.34, "#efe8d8")
    sack(b, Pw(P_, ou0 + 0.5, 0.0, on + 0.06), 0.13, 0.3, "#efe8d8", open_=False)
    stool(b, Pw(P_, ou1 - 0.2, 0.0, on))
    basket(b, Pw(P_, ou1 - 0.2, 0.3, on), 0.12, 0.12)
    for k in range(4):
        bread_round(b, Pw(P_, ou1 - 0.2 + (k % 2 - 0.5) * 0.08, 0.38 + (k // 2) * 0.04, on + (k // 2 - 0.5) * 0.06), 0.05)
    eu0, eu1 = S["ent"]                        # лопата пекаря у косяка
    a = Vector(Pw(P_, eu1 - 0.02, 0.05, 0.06))
    bb = Vector(Pw(P_, eu1 + 0.02, 1.25, -0.02))
    rod(b, a, bb, 0.03, J("#8a6038", 0.05), mat=M_WOOD)
    b.box(tuple(a + (a - bb).normalized() * -0.12 + Vector((0, 0.08, 0))), (0.03, 0.26, 0.2), J("#a07a52", 0.05), RW(S["U"], N), mat=M_WOOD)


def g_shoes(b, e, S):
    P_, R, N, y, u0, u1 = S["P"], S["R"], S["N"], S["y"], S["u0"], S["u1"]
    cols = ["#7a4a2a", "#5a3a22", "#9a6a3a", "#3a2a1e", "#8a3a2a"]
    hs = hooks(S, 6)
    for i, h in enumerate(hs):
        (it_sandals(b, h, R, cols[i % 5]) if i % 2 == 0 else it_boots(b, h, R, cols[(i + 2) % 5]))
    ru0, ru1, rv, rn = S["rail"]
    for uu in (ru0 - 0.02, ru1 + 0.02):        # шкуры по краям проёма
        hide(b, P_, N, uu, rv - 0.03, 0.26, 0.42, 0.11, "#a4744a")
    for k, uu in enumerate(row(u0, u1 - 0.3, 4)):
        for s_ in (-1, 1):
            shoe(b, Pw(P_, uu + s_ * 0.036, y, 0.08), R, cols[k % 5], boot=k % 2 == 1, ang=0.1 * s_)
    b.lathe(Pw(P_, u1 - 0.16, y, 0.02), [(0.03, 0.0), (0.034, 0.05), (0.02, 0.1), (0.012, 0.16)], 7, J("#c9a46e", 0.05), mat=M_WOOD)   # колодка
    spindle(b, Pw(P_, u1 - 0.3, y + 0.035, -0.08), Pw(P_, u1 - 0.02, y + 0.035, -0.08), [(0.035, 0.0), (0.035, 1.0)], 8, J("#a4744a", 0.06))
    shelf_unit(b, S, lambda v, a, c, n: [shoe(b, Pw(P_, uu, v, n), R, cols[i % 5], boot=i % 3 == 0) for i, uu in enumerate(row(a, c, 6))])
    ou0, ou1, on = S["out"]
    bench2(b, Pw(P_, ou0 + 0.5, 0.0, on), R, 0.8)
    for k in range(3):
        for s_ in (-1, 1):
            sandal(b, Pw(P_, ou0 + 0.25 + k * 0.25 + s_ * 0.04, 0.32, on), R, cols[(k + 1) % 5], 0.1 * s_)


def g_dye(b, e, S):
    P_, R, N, y, u0, u1 = S["P"], S["R"], S["N"], S["y"], S["u0"], S["u1"]
    cols = ["#9a2f28", "#2f4f8f", "#d9a02a", "#6a2f8a", "#3f7f4a", "#c8602a"]
    ru0, ru1, rv, rn = S["rail"]
    for k, uu in enumerate(row(ru0, ru1, 5)):
        drape(b, P_, N, uu, rv - 0.01, 0.2, 0.46 - 0.06 * (k % 2), rn + 0.02, cols[k], folds=2, amp=0.018)
    for k, uu in enumerate(row(u0, u1 - 0.35, 4)):
        bowl(b, Pw(P_, uu, y, 0.08), 0.075, J("#c9c0b0", 0.04), food=cols[k])
    folded_stack(b, Pw(P_, u1 - 0.17, y, 0.02), R, 0.24, 0.2, 6, cols)
    wool_balls(b, Pw(P_, u0 + 0.35, y, -0.1), 5, cols)
    shelf_unit(b, S, lambda v, a, c, n: [jar(b, Pw(P_, uu, v, n), 0.15, J("#c27a4a", 0.06), lid=cols[i % 6]) for i, uu in enumerate(row(a, c, 5))])
    ou0, ou1, on = S["out"]
    b.lathe(Pw(P_, ou0 + 0.35, 0.0, on), [(0.2, 0.0), (0.24, 0.3), (0.25, 0.34)], 12, J("#8a6038", 0.06), mat=M_WOOD)
    b.lathe(Pw(P_, ou0 + 0.35, 0.27, on), [(0.23, 0.0), (0.23, 0.001)], 12, col("#5a2a7a"), close_top=True)
    rod(b, Pw(P_, ou0 + 0.3, 0.2, on), Pw(P_, ou0 + 0.5, 0.75, on - 0.1), 0.025, J("#8a6038", 0.05), mat=M_WOOD)


def g_togas(b, e, S):
    P_, R, N, y, u0, u1 = S["P"], S["R"], S["N"], S["y"], S["u0"], S["u1"]
    full = DS.get("sign") == "fullonica"
    cols = ["#f4efe2", "#d8e4ec", "#efe0b8"] if full else ["#f2ece0", "#b5452f", "#3f6fa8", "#d9a02a"]
    ru0, ru1, rv, rn = S["rail"]
    for k, uu in enumerate(row(ru0, ru1, 3)):
        top = Vector(Pw(P_, uu, rv, rn))
        rod(b, top, top + Vector((0, -0.05, 0)), 0.008, col(IRON))
        tunic(b, P_, N, R, uu, rv - 0.06, rn + 0.03, cols[k % len(cols)], stripe="#6a2f8a" if (k == 0 and not full) else None)
    for k in range(3):                         # штуки ткани
        a = Pw(P_, u0 + 0.02, y + 0.04 + k * 0.075, 0.1 - k * 0.07)
        bolt(b, a, Pw(P_, u0 + 0.5, y + 0.04 + k * 0.075, 0.1 - k * 0.07), 0.04, cols[(k + 1) % len(cols)])
    folded_stack(b, Pw(P_, u0 + 0.75, y, 0.04), R, 0.28, 0.22, 6, cols + ["#e8e0d0"])
    b.box(Pw(P_, u1 - 0.18, y + 0.006, 0.1), (0.12, 0.008, 0.02), col(BRONZE), R @ Matrix.Rotation(0.4, 3, "Y"))     # ножницы
    for k in range(3):
        b.lathe(Pw(P_, u1 - 0.1 - k * 0.07, y, -0.05), [(0.02, 0.0), (0.025, 0.004), (0.022, 0.05), (0.025, 0.054)], 7, J(["#b5452f", "#3f6fa8", "#e1b84a"][k], 0.05), close_top=True)
    shelf_unit(b, S, lambda v, a, c, n: [folded_stack(b, Pw(P_, uu, v, n), R, 0.2, 0.2, 4, cols) for uu in row(a, c, 3)])
    ou0, ou1, on = S["out"]
    if full:                                   # чан, где топчут сукно, и корзина отбелённого
        b.lathe(Pw(P_, ou0 + 0.3, 0.0, on), [(0.24, 0.0), (0.26, 0.28), (0.28, 0.3)], 12, J(P["stone"], 0.05), mat=M_STONE)
        b.lathe(Pw(P_, ou0 + 0.3, 0.24, on), [(0.25, 0.0), (0.25, 0.001)], 12, col("#c8d8d0"), close_top=True)
        drape(b, P_, N, ou0 + 0.3, 0.32, 0.3, 0.1, on + 0.24, "#f4efe2", folds=2, amp=0.02)
        basket(b, Pw(P_, ou1 - 0.2, 0.0, on), 0.15, 0.2)
        folded_stack(b, Pw(P_, ou1 - 0.2, 0.18, on), R, 0.2, 0.18, 3, cols)
    else:                                      # стойка с тогой
        uu = ou0 + 0.35
        rod(b, Pw(P_, uu, 0.0, on), Pw(P_, uu, 1.05, on), 0.035, J("#6b4428", 0.05), mat=M_WOOD)
        b.box(Pw(P_, uu, 1.0, on), (0.42, 0.035, 0.035), J("#6b4428", 0.05), R, mat=M_WOOD)
        b.lathe(Pw(P_, uu, 0.0, on), [(0.14, 0.0), (0.12, 0.04)], 8, J("#6b4428", 0.05), close_top=True, mat=M_WOOD)
        drape(b, P_, N, uu, 1.02, 0.44, 0.66, on + 0.03, "#f2ece0", folds=3, amp=0.03)
        b.box(Pw(P_, uu - 0.12, 0.7, on + 0.065), (0.04, 0.6, 0.004), col("#6a2f8a"), R @ Matrix.Rotation(0.3, 3, "Z"))


def g_pots(b, e, S):
    P_, R, N, y, u0, u1 = S["P"], S["R"], S["N"], S["y"], S["u0"], S["u1"]
    for k, h in enumerate(hooks(S, 5)):        # кувшинчики на ремешках
        top = it_hook(b, h, 0.06 + 0.04 * (k % 2))
        jug(b, tuple(top + Vector((0, -0.16, 0))), 0.16, J(CLAY[k % 4], 0.06), handle=False)
    xs = row(u0, u1, 7)
    for k, uu in enumerate(xs):
        c = J(CLAY[k % 4], 0.06)
        if k % 3 == 0:
            jug(b, Pw(P_, uu, y, 0.06), 0.22, c)
        elif k % 3 == 1:
            plate_stack(b, Pw(P_, uu, y, 0.08), 0.08, 4, CLAY[3])
            bowl(b, Pw(P_, uu, y + 0.055, 0.08), 0.06, c)
        else:
            cup(b, Pw(P_, uu - 0.03, y, 0.1), 0.045, col("#2a2420"))
            cup(b, Pw(P_, uu + 0.04, y, 0.02), 0.045, c)
    shelf_unit(b, S, lambda v, a, c, n: [(jug(b, Pw(P_, uu, v, n), 0.18, J(CLAY[i % 4], 0.06)) if i % 2 else bowl(b, Pw(P_, uu, v, n), 0.07, J(CLAY[i % 4], 0.06))) for i, uu in enumerate(row(a, c, 6))])
    ou0, ou1, on = S["out"]
    amphora_rack(b, P_, S["U"], N, ou0 + 0.42, on, 3)
    b.lathe(Pw(P_, ou1 - 0.15, 0.0, on + 0.05), [(0.1, 0.0), (0.18, 0.12), (0.17, 0.26), (0.12, 0.32), (0.14, 0.35)], 10, J(CLAY[0], 0.06), close_top=True)


def g_oil(b, e, S):
    P_, R, N, y, u0, u1 = S["P"], S["R"], S["N"], S["y"], S["u0"], S["u1"]
    for k, h in enumerate(hooks(S, 5)):
        top = it_hook(b, h, 0.06)
        if k % 2 == 0:
            bottle(b, tuple(top + Vector((0, -0.2, 0))), 0.2, J("#b08a4a", 0.06))
        else:                                  # ветка оливы с плодами
            for j in range(5):
                leaf_blob(b, tuple(top + Vector(((j % 2 - 0.5) * 0.05, -0.04 - j * 0.04, 0.01))), 0.03, J("#6f8a4a", 0.08))
                ball(b, tuple(top + Vector(((j % 2 - 0.5) * -0.04, -0.05 - j * 0.04, 0.03))), 0.012, J("#3a3a2a", 0.1), seg=5, rings=3)
    for k, uu in enumerate(row(u0, u1 - 0.4, 3)):   # долии в прилавке
        c = Vector(Pw(P_, uu, y - 0.02, 0.04))
        b.lathe((c.x, c.y, c.z), [(0.11, 0.0), (0.11, 0.02)], 10, col("#4a3a1a"), close_top=True)
        b.lathe((c.x, c.y, c.z), [(0.135, 0.0), (0.135, 0.035)], 10, J("#c27a4a", 0.06))
    board(b, Pw(P_, u1 - 0.2, y, 0.04), R, 0.34, 0.24)
    bowl(b, Pw(P_, u1 - 0.28, y + 0.024, 0.04), 0.065, J("#d9c8a8", 0.04), food="#6f7a3a")
    bowl(b, Pw(P_, u1 - 0.12, y + 0.024, 0.06), 0.06, J("#d9c8a8", 0.04), food="#2a2420")
    jug(b, Pw(P_, u1 - 0.18, y + 0.024, -0.06), 0.18, J("#b5703f", 0.06))
    b.lathe(Pw(P_, u0 + 0.05, y, -0.1), [(0.008, 0.0), (0.012, 0.06), (0.06, 0.12)], 8, col(BRONZE))          # воронка
    shelf_unit(b, S, lambda v, a, c, n: [jug(b, Pw(P_, uu, v, n), 0.2, J(CLAY[i % 3], 0.06)) for i, uu in enumerate(row(a, c, 5))])
    ou0, ou1, on = S["out"]
    amphora_rack(b, P_, S["U"], N, ou0 + 0.5, on, 4)


def g_lamps(b, e, S):
    P_, R, N, y, u0, u1 = S["P"], S["R"], S["N"], S["y"], S["u0"], S["u1"]
    for k, h in enumerate(hooks(S, 5)):
        if k % 2 == 0:
            hanging_lamp(b, e, h)
        else:                                  # связка глиняных светильников
            top = it_hook(b, h, 0.04)
            for j in range(3):
                lucerna(b, e, tuple(top + Vector(((j - 1) * 0.04, -0.12 - j * 0.07, 0.0))), R @ Matrix.Rotation(-1.2, 3, "X"), CLAY[j % 3])
    st = steps(b, Pw(P_, (u0 + u1) / 2 - 0.1, y, 0.14), R, u1 - u0 - 0.3, 3)
    for (sy, sz) in st:
        for k, uu in enumerate(row(u0 + 0.05, u1 - 0.35, 5)):
            lucerna(b, e, Pw(P_, uu, y + sy, 0.14 + sz), R, CLAY[(k + int(sy * 100)) % 4], lit=(k + int(sy * 100)) % 4 == 0)
    candelabrum(b, e, Pw(P_, u1 - 0.12, y, 0.0), 0.55)
    shelf_unit(b, S, lambda v, a, c, n: [lucerna(b, e, Pw(P_, uu, v, n), R, CLAY[i % 4]) for i, uu in enumerate(row(a, c, 8))])
    ou0, ou1, on = S["out"]
    candelabrum(b, e, Pw(P_, ou0 + 0.25, 0.0, on), 1.1)
    candelabrum(b, e, Pw(P_, ou0 + 0.6, 0.0, on + 0.08), 0.85)


def g_wine(b, e, S):
    P_, R, N, y, u0, u1 = S["P"], S["R"], S["N"], S["y"], S["u0"], S["u1"]
    for k, h in enumerate(hooks(S, 5)):
        top = it_hook(b, h, 0.05 + 0.04 * (k % 2))
        grapes(b, tuple(top), 1.3, "#5a2d5f" if k % 3 else "#8fa04a")
    for k, uu in enumerate(row(u0, u1 - 0.45, 2)):
        c = Vector(Pw(P_, uu, y - 0.02, 0.04))
        b.lathe((c.x, c.y, c.z), [(0.11, 0.0), (0.11, 0.02)], 10, col("#3a1a2a"), close_top=True)
        b.lathe((c.x, c.y, c.z), [(0.135, 0.0), (0.135, 0.035)], 10, J("#c27a4a", 0.06))
    jug(b, Pw(P_, u1 - 0.36, y, 0.06), 0.22, J("#b5703f", 0.06))
    for k in range(3):
        cup(b, Pw(P_, u1 - 0.22 + k * 0.07, y, 0.1 - (k % 2) * 0.08), 0.04, J(["#a8402a", "#2a2420", BRONZE][k], 0.05))
    board(b, Pw(P_, u1 - 0.12, y, -0.08), R, 0.22, 0.16)
    grapes(b, Pw(P_, u1 - 0.12, y + 0.11, -0.08), 1.2)
    shelf_unit(b, S, lambda v, a, c, n: [(amphora(b, Pw(P_, uu, v, n), 0.3, J(CLAY[i % 3], 0.06)) if i % 2 == 0 else jug(b, Pw(P_, uu, v, n), 0.18, J(CLAY[(i + 1) % 4], 0.06))) for i, uu in enumerate(row(a, c, 5))])
    ou0, ou1, on = S["out"]
    if not DS.get("tables"):
        amphora_rack(b, P_, S["U"], N, ou0 + 0.42, on, 3)
        barrel(b, Pw(P_, ou1 - 0.12, 0.0, on + 0.05), 0.45, 0.16)


def g_perfume(b, e, S):
    P_, R, N, y, u0, u1 = S["P"], S["R"], S["N"], S["y"], S["u0"], S["u1"]
    for k, h in enumerate(hooks(S, 6)):
        herb_bundle(b, h, "#7a8f5a" if k % 2 else "#8f8fb0", fl=["#e98bb0", "#9a7ad0", "#f4f1e8", "#d9534f"][k % 4])
    st = steps(b, Pw(P_, (u0 + u1) / 2 - 0.12, y, 0.14), R, u1 - u0 - 0.34, 3)
    for j, (sy, sz) in enumerate(st):
        for k, uu in enumerate(row(u0 + 0.04, u1 - 0.4, 6)):
            bottle(b, Pw(P_, uu, y + sy, 0.14 + sz), 0.09 + 0.03 * ((k + j) % 3), J(GLASS[(k + 2 * j) % 6], 0.05))
    mortar(b, Pw(P_, u1 - 0.14, y, 0.06), R, 0.06, "#c87aa0")
    basket(b, Pw(P_, u1 - 0.12, y, -0.1), 0.09, 0.08)
    for k in range(6):
        ball(b, Pw(P_, u1 - 0.12 + rng.uniform(-0.05, 0.05), y + 0.1, -0.1 + rng.uniform(-0.05, 0.05)), 0.02,
             J(rng.choice(["#e98bb0", "#d9534f", "#f4f1e8"]), 0.06), seg=6, rings=3)
    shelf_unit(b, S, lambda v, a, c, n: [bottle(b, Pw(P_, uu, v, n), 0.1 + 0.03 * (i % 2), J(GLASS[i % 6], 0.05)) for i, uu in enumerate(row(a, c, 8))])
    ou0, ou1, on = S["out"]
    for k in range(2):
        uu = ou0 + 0.22 + k * 0.4
        basket(b, Pw(P_, uu, 0.0, on), 0.15, 0.2)
        for j in range(9):
            ball(b, Pw(P_, uu + rng.uniform(-0.09, 0.09), 0.2 + rng.uniform(0, 0.05), on + rng.uniform(-0.09, 0.09)), 0.028,
                 J(["#e98bb0", "#9a7ad0"][k] if j % 3 else "#5f8f3a", 0.08), seg=6, rings=3)


def g_jewel(b, e, S):
    P_, R, N, y, u0, u1 = S["P"], S["R"], S["N"], S["y"], S["u0"], S["u1"]
    ru0, ru1, rv, rn = S["rail"]
    gems = ["#c8303a", "#2a6ac8", "#3aa86a"]
    for k, uu in enumerate(row(ru0, ru1, 2)):      # доски с ожерельями на бархате
        top = Vector(Pw(P_, uu, rv, rn))
        rod(b, top, top + Vector((0, -0.06, 0)), 0.006, col(IRON))
        b.box(Pw(P_, uu, rv - 0.24, rn + 0.01), (0.42, 0.34, 0.02), J("#4a2a36", 0.04), R, mat=M_CLOTH)
        for j in range(3):
            necklace(b, Pw(P_, uu - 0.15, rv - 0.12 - j * 0.03, rn + 0.025), Pw(P_, uu + 0.15, rv - 0.12 - j * 0.03, rn + 0.025), 0.08 + j * 0.02, 12, gem=gems[j:] + gems[:j])
    for k, uu in enumerate(row(u0, u1 - 0.4, 3)):
        tray(b, Pw(P_, uu, y, 0.08), R, 0.24, 0.18)
        for j in range(7):
            p = Pw(P_, uu - 0.09 + (j % 4) * 0.06, y + 0.032, 0.03 + (j // 4) * 0.08)
            if k == 0:
                disc(b, p, 0.014, 0.014, 0.004, col("#e8c45a"), seg=8)
            elif k == 1:
                torus(b, (p[0], p[1] + 0.006, p[2]), Matrix.Identity(3), 0.012, 0.004, col("#e8c45a"), seg=8, seg2=3)
            else:
                ball(b, (p[0], p[1] + 0.008, p[2]), 0.011, col(gems[j % 3]), seg=6, rings=3)
    scales(b, Pw(P_, u1 - 0.3, y, -0.04), R, 0.8)
    arca(b, Pw(P_, u1 - 0.12, y, 0.02), R, 0.2, 0.14, 0.16)
    shelf_unit(b, S, lambda v, a, c, n: [(cup(b, Pw(P_, uu, v, n), 0.05, col("#e0b84a" if i % 2 else "#d0d4d8")) if i % 3 else plate_stack(b, Pw(P_, uu, v, n), 0.07, 2, "#d0d4d8")) for i, uu in enumerate(row(a, c, 6))])
    ou0, ou1, on = S["out"]
    plant_pot(b, Pw(P_, ou0 + 0.25, 0.0, on - 0.2), 0.34)


def g_cloth(b, e, S):
    P_, R, N, y, u0, u1 = S["P"], S["R"], S["N"], S["y"], S["u0"], S["u1"]
    cols = ["#b5452f", "#3f6fa8", "#e1b84a", "#4f8a5a", "#8a4f9a", "#efe3c8"]
    ru0, ru1, rv, rn = S["rail"]
    for k, uu in enumerate(row(ru0, ru1, 6)):
        if k % 2 == 0:
            drape(b, P_, N, uu, rv - 0.01, 0.22, 0.48, rn + 0.02, cols[k], folds=2, amp=0.02)
        else:
            skein(b, Pw(P_, uu, rv, rn), N, cols[k])
    for k in range(3):
        bolt(b, Pw(P_, u0 + 0.02, y + 0.045 + k * 0.08, 0.1 - k * 0.06), Pw(P_, u0 + 0.52, y + 0.045 + k * 0.08, 0.1 - k * 0.06), 0.045, cols[k + 1])
    folded_stack(b, Pw(P_, u0 + 0.78, y, 0.04), R, 0.26, 0.22, 5, cols)
    basket(b, Pw(P_, u1 - 0.15, y, 0.04), 0.11, 0.1)
    wool_balls(b, Pw(P_, u1 - 0.15, y + 0.06, 0.04), 4, ["#efe3c8", "#b5452f", "#3f6fa8", "#e1b84a"])
    spindle(b, Pw(P_, u1 - 0.32, y + 0.01, -0.08), Pw(P_, u1 - 0.32, y + 0.25, -0.08), [(0.006, 0.0), (0.03, 0.15), (0.03, 0.55), (0.006, 1.0)], 7, J("#efe3c8", 0.05))
    shelf_unit(b, S, lambda v, a, c, n: [bolt(b, Pw(P_, uu - 0.08, v + 0.04, n), Pw(P_, uu + 0.08, v + 0.04, n), 0.04, cols[i % 6]) for i, uu in enumerate(row(a, c, 4))])
    ou0, ou1, on = S["out"]
    basket(b, Pw(P_, ou0 + 0.25, 0.0, on), 0.16, 0.22)
    wool_balls(b, Pw(P_, ou0 + 0.25, 0.18, on), 5, ["#efe3c8", "#d8cfbf", "#b5452f"])


def g_barber(b, e, S):
    P_, R, N, y, u0, u1 = S["P"], S["R"], S["N"], S["y"], S["u0"], S["u1"]
    ru0, ru1, rv, rn = S["rail"]
    for k, uu in enumerate(row(ru0, ru1, 4)):
        if k == 2:
            top = Vector(Pw(P_, uu, rv, rn))
            rod(b, top, top + Vector((0, -0.05, 0)), 0.006, col(IRON))
            b.box(tuple(top + Vector((0, -0.25, 0))), (0.06, 0.4, 0.006), J("#7a4a2a", 0.05), R)              # ремень для бритвы
        else:
            drape(b, P_, N, uu, rv - 0.01, 0.24, 0.34, rn + 0.02, ["#f4efe2", "#efe6d0", "#d8e0e8"][k % 3], folds=2, amp=0.015)
    b.lathe(Pw(P_, u0 + 0.2, y, 0.04), [(0.08, 0.0), (0.15, 0.06), (0.16, 0.08)], 12, J("#c9c2b2", 0.04))      # таз
    b.lathe(Pw(P_, u0 + 0.2, y + 0.05, 0.04), [(0.14, 0.0), (0.14, 0.001)], 12, col("#7fb0c0"), close_top=True)
    mx = u0 + 0.55
    rod(b, Pw(P_, mx, y, -0.06), Pw(P_, mx, y + 0.18, -0.06), 0.02, col(BRONZE))
    b.lathe(Pw(P_, mx, y, -0.06), [(0.05, 0.0), (0.04, 0.02)], 8, col(BRONZE), close_top=True)
    disc(b, Pw(P_, mx, y + 0.28, -0.06), 0.1, 0.1, 0.012, col("#e8d8a0"), R @ Matrix.Rotation(math.pi / 2, 3, "X"), seg=12)   # зеркало
    b.box(Pw(P_, u0 + 0.85, y + 0.004, 0.06), (0.26, 0.008, 0.18), J("#f4efe2", 0.03), R, mat=M_CLOTH)
    for k in range(3):
        b.box(Pw(P_, u0 + 0.77 + k * 0.08, y + 0.012, 0.06), (0.02, 0.006, 0.12), col("#b0b8c0" if k != 1 else BRONZE), R)
    b.box(Pw(P_, u1 - 0.12, y + 0.025, 0.08), (0.14, 0.05, 0.012), J("#d9c8a0", 0.04), R)                     # гребень
    for k in range(3):
        jar(b, Pw(P_, u1 - 0.22 + k * 0.08, y, -0.08), 0.1, J(["#c27a4a", "#e8e2d6", "#7d8f99"][k], 0.05))
    shelf_unit(b, S, lambda v, a, c, n: [(folded_stack(b, Pw(P_, uu, v, n), R, 0.18, 0.18, 3, ["#f4efe2", "#d8e0e8"]) if i % 2 else jar(b, Pw(P_, uu, v, n), 0.12, J(CLAY[i % 3], 0.05))) for i, uu in enumerate(row(a, c, 5))])
    ou0, ou1, on = S["out"]
    bench2(b, Pw(P_, ou0 + 0.48, 0.0, on - 0.04), R, 0.85)


def g_medic(b, e, S):
    P_, R, N, y, u0, u1 = S["P"], S["R"], S["N"], S["y"], S["u0"], S["u1"]
    for k, h in enumerate(hooks(S, 6)):
        (garlic_braid(b, h, 5) if k == 3 else herb_bundle(b, h, ["#5f7f3a", "#7a8f5a", "#6a7a4a"][k % 3], fl=["#f0d24a", None, "#b08ad0"][k % 3]))
    mortar(b, Pw(P_, u0 + 0.14, y, 0.06), R, 0.07)
    for k, uu in enumerate(row(u0 + 0.28, u1 - 0.5, 4)):
        jar(b, Pw(P_, uu, y, 0.08), 0.13, J(["#c27a4a", "#7d8f99", "#e8e2d6", "#4f7a6a"][k], 0.05))
    scroll(b, Pw(P_, u1 - 0.36, y, -0.06), R, 0.22)
    scroll(b, Pw(P_, u1 - 0.32, y + 0.048, -0.05), R @ Matrix.Rotation(0.3, 3, "Y"), 0.2)
    arca(b, Pw(P_, u1 - 0.12, y, 0.04), R, 0.2, 0.08, 0.14)                              # ящичек с инструментами
    for k in range(4):
        b.box(Pw(P_, u1 - 0.18 + k * 0.035, y + 0.084, 0.04), (0.008, 0.006, 0.11), col(BRONZE), R)
    shelf_unit(b, S, lambda v, a, c, n: [(jar(b, Pw(P_, uu, v, n), 0.13, J(["#c27a4a", "#7d8f99", "#e8e2d6", "#4f7a6a"][i % 4], 0.05)) if i % 3 else scroll(b, Pw(P_, uu, v, n), R, 0.16)) for i, uu in enumerate(row(a, c, 6))])
    ou0, ou1, on = S["out"]
    plant_pot(b, Pw(P_, ou0 + 0.22, 0.0, on - 0.1), 0.3)
    plant_pot(b, Pw(P_, ou0 + 0.55, 0.0, on - 0.05), 0.26)


def g_thermo(b, e, S):
    P_, R, N, y, u0, u1 = S["P"], S["R"], S["N"], S["y"], S["u0"], S["u1"]
    for k, h in enumerate(hooks(S, 6)):
        if k % 3 == 0:
            it_sausages(b, h, 4)
        elif k % 3 == 1:
            garlic_braid(b, h, 5)
        else:                                  # половник
            top = it_hook(b, h, 0.03)
            rod(b, top, top + Vector((0, -0.24, 0)), 0.012, col(BRONZE))
            b.lathe(tuple(top + Vector((0, -0.3, 0))), [(0.02, 0.0), (0.04, 0.03), (0.04, 0.04)], 8, col(BRONZE), close_top=True)
    foods = ["#7a4a2a", "#6f7a3a", "#c8602a", "#d9b46a"]
    for k, uu in enumerate(row(u0, u1 - 0.35, 3)):  # долии с едой, в каждой — половник
        c = Vector(Pw(P_, uu, y - 0.02, 0.04))
        b.lathe((c.x, c.y, c.z), [(0.115, 0.0), (0.115, 0.022)], 10, col(foods[k]), close_top=True)
        b.lathe((c.x, c.y, c.z), [(0.14, 0.0), (0.14, 0.035)], 10, J("#c27a4a", 0.06))
        rod(b, (c.x, c.y + 0.02, c.z), Pw(P_, uu + 0.06, y + 0.2, -0.04), 0.01, col(BRONZE))
    for k in range(3):
        bowl(b, Pw(P_, u1 - 0.28 + k * 0.1, y, 0.1), 0.05, J("#c27a4a", 0.05), food=foods[(k + 1) % 4])
    jug(b, Pw(P_, u1 - 0.12, y, -0.06), 0.2, J("#b5703f", 0.06))
    bread_round(b, Pw(P_, u1 - 0.3, y, -0.08), 0.06)
    cup(b, Pw(P_, u1 - 0.2, y, -0.1), 0.04, col("#a8402a"))
    shelf_unit(b, S, lambda v, a, c, n: [(jug(b, Pw(P_, uu, v, n), 0.16, J(CLAY[i % 4], 0.05)) if i % 2 else plate_stack(b, Pw(P_, uu, v, n), 0.07, 3, CLAY[i % 4])) for i, uu in enumerate(row(a, c, 6))])
    ou0, ou1, on = S["out"]
    amphora_rack(b, P_, S["U"], N, ou0 + 0.42, on, 3)
    brazier(b, e, Pw(P_, ou1 - 0.12, 0.0, on + 0.08))


def g_copper(b, e, S):
    P_, R, N, y, u0, u1 = S["P"], S["R"], S["N"], S["y"], S["u0"], S["u1"]
    for k, h in enumerate(hooks(S, 6)):
        top = it_hook(b, h, 0.05)
        if k % 2 == 0:                         # котёл на дужке
            c = top + Vector((0, -0.18, 0))
            b.lathe(tuple(c), [(0.05, 0.0), (0.1, 0.05), (0.11, 0.12), (0.1, 0.14)], 10, J("#b0703a", 0.08))
            for s in (-1, 1):
                rod(b, top, c + Vector((s * 0.1, 0.13, 0)), 0.006, col(IRON))
        else:                                  # сковорода
            c = top + Vector((0, -0.16, 0))
            disc(b, tuple(c), 0.09, 0.09, 0.03, J("#b0703a", 0.08), _ymat(Vector(N)), seg=10)
            rod(b, top, c + Vector((0, 0.05, 0)), 0.014, J("#8c5a30", 0.06))
    for k, uu in enumerate(row(u0, u1 - 0.3, 3)):
        b.lathe(Pw(P_, uu, y, 0.06), [(0.07, 0.0), (0.12, 0.05), (0.13, 0.12), (0.12, 0.14)], 10, J("#b8783a", 0.08))
    b.box(Pw(P_, u1 - 0.15, y + 0.015, 0.06), (0.1, 0.03, 0.04), col(IRON), R)                     # молоток
    b.box(Pw(P_, u1 - 0.06, y + 0.015, 0.06), (0.16, 0.02, 0.02), J("#8a6038", 0.05), R, mat=M_WOOD)
    shelf_unit(b, S, lambda v, a, c, n: [b.lathe(Pw(P_, uu, v, n), [(0.05, 0.0), (0.08, 0.04), (0.085, 0.1)], 10, J("#b0703a", 0.08)) for uu in row(a, c, 5)])
    ou0, ou1, on = S["out"]
    b.lathe(Pw(P_, ou0 + 0.3, 0.0, on), [(0.12, 0.0), (0.22, 0.1), (0.24, 0.26), (0.22, 0.3)], 12, J("#a8683a", 0.06))
    for k in range(4):
        b.box(Pw(P_, ou0 + 0.7, 0.01 + k * 0.012, on - 0.05), (0.3, 0.01, 0.22), J("#c08048", 0.06), R @ Matrix.Rotation(0.1 * k, 3, "Y"))


def g_grain(b, e, S):
    P_, R, N, y, u0, u1 = S["P"], S["R"], S["N"], S["y"], S["u0"], S["u1"]
    for k, h in enumerate(hooks(S, 4)):
        garlic_braid(b, h, 5, "#c08a3a" if k % 2 else "#efe6d2")
    grains = ["#e3c46a", "#d8c89a", "#8a5a3a", "#c87a3a"]
    for k, uu in enumerate(row(u0, u1 - 0.4, 3)):
        bowl(b, Pw(P_, uu, y, 0.06), 0.11, J("#8a6038", 0.05), food=grains[k])
    b.lathe(Pw(P_, u1 - 0.25, y, 0.04), [(0.08, 0.0), (0.09, 0.13)], 10, J("#8a6038", 0.06), mat=M_WOOD)      # модий
    b.lathe(Pw(P_, u1 - 0.25, y + 0.11, 0.04), [(0.085, 0.0), (0.085, 0.001)], 10, col(grains[0]), close_top=True)
    scales(b, Pw(P_, u1 - 0.08, y, -0.06), R, 0.7)
    shelf_unit(b, S, lambda v, a, c, n: [sack(b, Pw(P_, uu, v, n), 0.09, 0.22, grains[i % 4], open_=i % 2 == 0) for i, uu in enumerate(row(a, c, 4))])
    ou0, ou1, on = S["out"]
    for k in range(3):
        sack(b, Pw(P_, ou0 + 0.2 + k * 0.28, 0.0, on), 0.13, 0.32, grains[k], open_=k != 1)


def g_scrolls(b, e, S):
    """скрипторий: листы папируса и связки свитков на перекладине, на прилавке — стопки свитков, чернильница с
    тростниковыми перьями, восковые таблички, капса; на полке — свитки рядами (на улице — стол писца, его ставит дом)"""
    P_, R, N, y, u0, u1 = S["P"], S["R"], S["N"], S["y"], S["u0"], S["u1"]
    ru0, ru1, rv, rn = S["rail"]
    for k, uu in enumerate(row(ru0, ru1, 5)):
        if k % 2 == 0:
            drape(b, P_, N, uu, rv - 0.01, 0.2, 0.3, rn + 0.02, "#efe3c0", folds=1, amp=0.01)
        else:
            top = it_hook(b, Pw(P_, uu, rv, rn), 0.05)
            for j in range(3):
                spindle(b, top + Vector(((j - 1) * 0.045, -0.02, 0.0)), top + Vector(((j - 1) * 0.05, -0.3, 0.01 * j)), [(0.024, 0.0), (0.024, 1.0)], 7, J("#e8dcb8", 0.04))
            torus(b, tuple(top + Vector((0, -0.12, 0))), Matrix.Identity(3), 0.07, 0.008, col("#9a2f28"), seg=10, seg2=3)
    for k in range(3):                         # стопки свитков
        uu = u0 + 0.15 + k * 0.25
        for j in range(3 - k % 2):
            scroll(b, Pw(P_, uu, y + j * 0.046, 0.06 + (j % 2) * 0.02), R @ Matrix.Rotation(0.1 * j, 3, "Y"), 0.22, 0.023)
    b.lathe(Pw(P_, u1 - 0.42, y, 0.08), [(0.03, 0.0), (0.035, 0.03), (0.02, 0.05), (0.025, 0.06)], 8, col(BRONZE), close_top=True)   # чернильница
    b.lathe(Pw(P_, u1 - 0.28, y, 0.08), [(0.025, 0.0), (0.028, 0.08)], 8, J("#c27a4a", 0.05))
    for k in range(4):
        rod(b, Pw(P_, u1 - 0.28, y + 0.04, 0.08), Pw(P_, u1 - 0.28 + (k - 1.5) * 0.02, y + 0.2, 0.08 + (k % 2) * 0.02), 0.006, col("#c9b48a"))
    for k in range(2):
        wax_tablet(b, Pw(P_, u1 - 0.14, y + k * 0.02, -0.02 + k * 0.03), R, 0.2 * k)
    capsa(b, Pw(P_, u1 - 0.12, y, -0.12), 5)
    shelf_unit(b, S, lambda v, a, c, n: [scroll(b, Pw(P_, uu, v + (i % 2) * 0.045, n), R @ Matrix.Rotation(math.pi / 2, 3, "Y"), 0.22, 0.023) for i, uu in enumerate(row(a, c, 9))])


def scribe_desk(body, x, z1):
    """стол писца перед лавкой (детали Synty: стол и табурет — писец сидит лицом к лавке), на столе свиток и чернильница"""
    PROPS.append(["SM_Prop_Table_05", round(x, 3), 0.0, round(z1 + 0.55, 3), math.pi / 2, 0.95])
    PROPS.append(["SM_Prop_Seat_Stool_01", round(x, 3), 0.0, round(z1 + 1.05, 3), 0.0, 0.95])
    ty = 0.7767 * 0.95 * 0.72 + 0.002
    scroll(body, (x - 0.08, ty, z1 + 0.55), Matrix.Identity(3), 0.3, 0.02)
    body.box((x - 0.08, ty + 0.001, z1 + 0.62), (0.26, 0.002, 0.12), col("#efe3c0"))
    body.lathe((x + 0.22, ty, z1 + 0.5), [(0.025, 0.0), (0.03, 0.025), (0.018, 0.045)], 8, col(BRONZE), close_top=True)
    rod(body, (x + 0.22, ty + 0.03, z1 + 0.5), (x + 0.26, ty + 0.17, z1 + 0.46), 0.006, col("#c9b48a"))
    capsa(body, (x - 0.55, 0.0, z1 + 0.65), 6)


TRADE_GOODS = {"meat": g_meat, "bread": g_bread, "shoes": g_shoes, "dye": g_dye, "togas": g_togas, "oil": g_oil,
               "lamps": g_lamps, "wine": g_wine, "perfume": g_perfume, "jewel": g_jewel, "barber": g_barber, "medic": g_medic,
               "thermo": g_thermo, "cloth": g_cloth, "pots": g_pots, "copper": g_copper, "grain": g_grain, "scrolls": g_scrolls}


def y_oven(body, emb, x0, x1, zb, z_wall, zc):
    """пекарня: купол хлебной печи с огнём в устье (дым) и жернова-«песочные часы» (как в Помпеях)"""
    kx = x0 + 0.7
    body.box((kx, 0.25, zc), (0.95, 0.5, 0.9), J(P["stone"], 0.06), cols={"top": J(P["stone"], 0.1)}, mat=M_STONE)
    body.lathe((kx, 0.5, zc), [(0.42, 0.0), (0.4, 0.2), (0.28, 0.4), (0.1, 0.5)], 10, J("#c08a5a", 0.06), close_top=True)
    body.box((kx, 0.66, zc + 0.43), (0.3, 0.26, 0.06), col("#2a2018"))
    for k in range(4):
        leaf_blob(emb, (kx + rng.uniform(-0.08, 0.08), 0.6, zc + 0.44), 0.04, col(rng.choice(["#ff7a1a", "#ffb03a"])))
    SMOKE.append([kx, 1.2, zc])
    mx = x1 - 0.55
    body.lathe((mx, 0.0, zc), [(0.3, 0.0), (0.3, 0.25), (0.16, 0.5), (0.26, 0.75), (0.12, 0.95), (0.24, 1.15)], 10, J("#6f6a62", 0.06), close_top=True)
    body.box((mx, 0.75, zc), (0.9, 0.06, 0.06), J(P["wood"], 0.05), mat=M_WOOD)


def y_vats(body, emb, x0, x1, zb, z_wall, zc):
    """красильня / прачечная: каменные чаны с краской и полотна на верёвке"""
    cols = ["#9a2f28", "#2f4f8f", "#d9a02a"]
    for k in range(3):
        cx = x0 + 0.55 + k * (x1 - x0 - 1.1) / 2
        body.lathe((cx, 0.0, zc), [(0.32, 0.0), (0.32, 0.45), (0.27, 0.45)], 12, J(P["stone"], 0.06), mat=M_STONE)
        body.lathe((cx, 0.38, zc), [(0.27, 0.0), (0.0, 0.0)], 12, col(cols[k]))
    for xx in (x0 + 0.1, x1 - 0.1):
        body.box((xx, 0.8, zb + 0.15), (0.05, 1.6, 0.05), J(P["wood"], 0.05), mat=M_WOOD)
    body.box(((x0 + x1) / 2, 1.55, zb + 0.15), (x1 - x0 - 0.2, 0.012, 0.012), col("#d8cfbf"))
    for k in range(4):
        body.box((x0 + 0.5 + k * (x1 - x0 - 1.0) / 3, 1.3, zb + 0.15), (0.3, 0.5, 0.012), J(cols[k % 3], 0.05))


def y_stable(body, emb, x0, x1, zb, z_wall, zc):
    """гостиница: конюшенный двор — каменная поилка, ясли с сеном, тюки, колесо телеги"""
    body.box((x0 + 0.7, 0.22, zc), (1.0, 0.44, 0.38), J(P["stone"], 0.06), cols={"top": J(P["stone"], 0.1)}, mat=M_STONE)
    body.box((x0 + 0.7, 0.4, zc), (0.9, 0.02, 0.3), col("#5fa6b8"))
    body.box((x1 - 0.6, 0.45, zc - 0.05), (0.8, 0.1, 0.4), J(P["wood"], 0.06), mat=M_WOOD)
    for sx in (-1, 1):
        body.box((x1 - 0.6 + sx * 0.36, 0.22, zc - 0.05), (0.06, 0.45, 0.06), J(P["wood2"], 0.05), mat=M_WOOD)
    for k in range(6):
        leaf_blob(body, (x1 - 0.85 + k * 0.1, 0.55, zc - 0.05 + rng.uniform(-0.08, 0.08)), 0.07, J("#d9c27a", 0.08))
    for k in range(2):
        body.box(((x0 + x1) / 2 - 0.85 + k * 0.05, 0.18 + k * 0.36, zc + (k - 0.5) * 0.1), (0.42, 0.34, 0.3), J("#d9c27a", 0.08))
    cart(body, ((x0 + x1) / 2 + 0.35, 0.0, zc), Matrix.Rotation(math.pi / 2, 3, "Y"))


def cart(mb, at, R):
    """двухколёсная телега: кузов из досок с бортами, колёса со спицами на оси, оглобли упёрты в землю"""
    for sx in (-1, 1):
        c = Vector(LP(at, R, sx * 0.4, 0.3, 0.0))
        torus(mb, tuple(c), R @ Matrix.Rotation(math.pi / 2, 3, "Z"), 0.27, 0.028, J("#6b4428", 0.05), seg=14, seg2=4)
        for k in range(8):
            a = 2 * math.pi * k / 8
            rod(mb, c, c + R @ Vector((0, math.cos(a) * 0.26, math.sin(a) * 0.26)), 0.022, J("#7a5232", 0.05), mat=M_WOOD)
        spindle(mb, c - R @ Vector((0.06, 0, 0)), c + R @ Vector((0.06, 0, 0)), [(0.05, 0.0), (0.05, 1.0)], 8, J("#5e3d24", 0.05))
    rod(mb, LP(at, R, -0.46, 0.3, 0.0), LP(at, R, 0.46, 0.3, 0.0), 0.05, J("#5e3d24", 0.05), mat=M_WOOD)
    mb.box(LP(at, R, 0, 0.4, 0.05), (0.72, 0.05, 1.0), J("#8a6038", 0.06), R, mat=M_WOOD)
    for sx in (-1, 1):
        mb.box(LP(at, R, sx * 0.35, 0.52, 0.05), (0.04, 0.2, 1.0), J("#7a5232", 0.06), R, mat=M_WOOD)
    mb.box(LP(at, R, 0, 0.52, -0.43), (0.72, 0.2, 0.04), J("#7a5232", 0.06), R, mat=M_WOOD)
    for sx in (-1, 1):
        rod(mb, LP(at, R, sx * 0.25, 0.4, 0.5), LP(at, R, sx * 0.22, 0.04, 0.95), 0.045, J("#6b4428", 0.05), mat=M_WOOD)
    for k in range(3):
        sack(mb, LP(at, R, -0.15 + k * 0.15, 0.43, 0.1 + (k % 2) * 0.15), 0.1, 0.22, open_=False)


TRADE_YARDS = {"oven": y_oven, "vats": y_vats, "stable": y_stable}

# лавки: облик (навес, крыша, этажи), товар, двор; actor — где стоит лавочник (u вдоль фасада от левого края)
TRADES = {
    "butcher": {"goods": "meat", "front": "awning", "awning": ("#efe3c8", "#9a2f28"), "roof": "x", "floors": 1, "shutter": "red", "door": "oak", "pal": 0},
    "bakery": {"goods": "bread", "front": "canopy", "roof": "z", "floors": 2, "yard": "oven", "shutter": "brown", "door": "oak", "pal": 2, "corners": "stone"},
    "cobbler": {"goods": "shoes", "front": "awning", "awning": ("#e9d9b8", "#5a3a22"), "roof": "x", "floors": 1, "shutter": "brown", "door": "dark", "pal": 2},
    "dyer": {"goods": "dye", "front": "awning", "awning": ("#efe3c8", "#6a2f8a"), "roof": "x", "floors": 2, "yard": "vats", "shutter": "teal", "door": "green", "pal": 1, "balcony": True},
    "tailor": {"goods": "togas", "front": "awning", "awning": ("#f4efe2", "#3f6fa8"), "roof": "z", "floors": 2, "shutter": "blue", "door": "dark", "pal": 1, "boxes": True, "corners": "pilaster"},
    "potter": {"goods": "pots", "front": "canopy", "roof": "x", "floors": 1, "yard": "kiln", "shutter": "teal", "door": "oak", "pal": 0},
    "oilshop": {"goods": "oil", "front": "canopy", "roof": "z", "floors": 2, "shutter": "green", "door": "oak", "pal": 0, "corners": "stone"},
    "lamps": {"goods": "lamps", "front": "awning", "awning": ("#efe3c8", "#c9a14a"), "roof": "x", "floors": 2, "shutter": "ochre", "door": "dark", "pal": 2, "balcony": True},
    "wineshop": {"goods": "wine", "front": "pergola", "roof": "x", "floors": 2, "shutter": "red", "door": "dark", "pal": 0, "boxes": True},
    "perfumer": {"goods": "perfume", "front": "awning", "awning": ("#f4efe2", "#d98fb0"), "roof": "z", "floors": 2, "shutter": "teal", "door": "green", "pal": 1, "boxes": True, "corners": "pilaster", "decal": "frieze"},
    "jeweler": {"goods": "jewel", "front": "awning", "awning": ("#f4efe2", "#5a2a3a"), "roof": "z", "floors": 2, "shutter": "blue", "door": "dark", "pal": 1, "corners": "pilaster"},
    "weaver": {"goods": "cloth", "front": "awning", "awning": ("#efe3c8", "#3f6fa8"), "roof": "x", "floors": 1, "yard": "loom", "shutter": "green", "door": "oak", "pal": 0},
    "barber": {"goods": "barber", "front": "awning", "awning": ("#f4efe2", "#4f78a8"), "roof": "x", "floors": 1, "shutter": "blue", "door": "oak", "pal": 1, "chair": True},
    "medic": {"goods": "medic", "front": "canopy", "roof": "z", "floors": 2, "shutter": "green", "door": "green", "pal": 1, "boxes": True, "corners": "stone"},
    "thermopolium": {"goods": "thermo", "panel": "fresco", "front": "awning", "awning": ("#efe3c8", "#b5452f"), "roof": "x", "floors": 2, "w": 4.2, "shutter": "red", "door": "oak", "pal": 0, "balcony": True, "wide": True},
    "taberna": {"goods": "wine", "sign": "taberna", "front": "awning", "awning": ("#efe3c8", "#7a3528"), "roof": "z", "floors": 2, "w": 4.2, "d": 4.2, "shutter": "brown", "door": "dark", "pal": 2, "tables": True, "corners": "stone"},
    "fullonica": {"goods": "togas", "sign": "fullonica", "front": "awning", "awning": ("#f4efe2", "#4f78a8"), "roof": "x", "floors": 2, "w": 4.2, "yard": "vats", "shutter": "blue", "door": "oak", "pal": 1, "balcony": True},
    "scriptorium": {"goods": "scrolls", "sign": "scriptorium", "front": "awning", "awning": ("#efe3c8", "#9a2f28"), "roof": "z", "floors": 2, "d": 3.0, "shutter": "blue", "door": "dark", "pal": 1, "boxes": True, "scribe": True},
    "herbalist": {"goods": "herbs", "sign": "herbalist", "front": "awning", "awning": ("#efe3c8", "#4f8a5a"), "roof": "x", "floors": 1, "d": 3.0, "shutter": "green", "door": "green", "pal": 1},
    "catshop": {"goods": "cats", "sign": "catshop", "front": "awning", "awning": ("#f4efe2", "#e98bb0"), "roof": "z", "floors": 1, "d": 3.0, "shutter": "teal", "door": "red", "pal": 2},
    "mansio": {"goods": "wine", "sign": "mansio", "front": "canopy", "roof": "z", "floors": 3, "w": 4.8, "d": 4.4, "yard": "stable", "shutter": "green", "door": "dark", "pal": 2, "corners": "stone", "boxes": True},
}


def y_tables(body, x0, x1, z1):
    """столы и табуреты перед таверной (под перголой) — детали Synty в чертеже (Spectacle сажает на них гостей)"""
    # столы ближе к середине, табуреты — спереди и сзади стола: по краям остаётся место постоять у жаровни (Spectacle)
    # длинный стол со скамьями под навесом, у фасада (как в прежней таверне: гостей садится больше)
    PROPS.append(["SM_Prop_Table_08", 0.0, 0.0, round(z1 + 0.62, 3), 0.0, [0.62, 0.95, 0.75]])
    for dz in (-0.45, 0.45):
        PROPS.append(["SM_Prop_Seat_Bench_05", 0.0, 0.0, round(z1 + 0.62 + dz, 3), 0.0, [0.6, 1.0, 0.8]])
    for k, xx in enumerate((x0 + 1.25, x1 - 1.35)):
        zz = z1 + 1.75
        PROPS.append(["SM_Prop_Table_07", round(xx, 3), 0.0, round(zz, 3), 0.0, 1.0])
        for sgn in (-1, 1):
            PROPS.append(["SM_Prop_Seat_Chair_01", round(xx + 0.04 * sgn, 3), 0.0, round(zz + sgn * 0.47, 3), 0.0 if sgn < 0 else math.pi, 0.95])
        # на столешнице (у Synty — 0,552 в единицах чертежа, ×ARCH = 0,397 м): кувшин и две чаши
        PROPS.append(["SM_Prop_Jug_01", round(xx + 0.07, 3), 0.398, round(zz, 3), 0.0, 0.42])
        for (dx, dz) in ((-0.14, 0.1), (0.16, -0.1)):
            PROPS.append(["SM_Prop_Goblet_01", round(xx + dx, 3), 0.398, round(zz + dz, 3), 0.0, 0.5])
    # на длинном столе (верх 0,7825×0,95×ARCH = 0,535 м): кувшин, чаши, хлеб, миска с оливками
    ty = 0.536
    zt = z1 + 0.62
    jug(body, (-0.34, ty, zt - 0.04), 0.2, J("#b5703f", 0.06))
    for (dx, dz, c) in ((-0.12, -0.15, "#a8402a"), (0.22, 0.16, "#2a2420"), (0.42, -0.12, "#a8402a")):
        cup(body, (dx, ty, zt + dz), 0.04, J(c, 0.05))
    board(body, (0.05, ty, zt + 0.02), Matrix.Identity(3), 0.26, 0.18)
    bread_round(body, (0.05, ty + 0.024, zt + 0.02), 0.06)
    bowl(body, (0.38, ty, zt + 0.05), 0.06, J("#d9c8a8", 0.04), food="#6f7a3a")
    return
    for k, xx in enumerate((x0 + 0.8, x1 - 0.9)):
        zz = z1 + 1.0
        body.box((xx, 0.48, zz), (0.7, 0.05, 0.5), J(P["wood"], 0.06), mat=M_WOOD)
        for sx in (-1, 1):
            for sz in (-1, 1):
                body.box((xx + sx * 0.28, 0.23, zz + sz * 0.18), (0.05, 0.46, 0.05), J(P["wood2"], 0.05), mat=M_WOOD)
        for sz in (-1, 1):
            bench(body, (xx, 0.3, zz + sz * 0.45), 0.8, Matrix.Identity(3))
        body.lathe((xx - 0.12, 0.5, zz), [(0.04, 0.0), (0.06, 0.08), (0.03, 0.12)], 7, J("#c27a4a", 0.06))
        body.lathe((xx + 0.15, 0.5, zz), [(0.05, 0.0), (0.07, 0.03)], 8, J("#b0703a", 0.06))


def basket2(mb, at, r, h):
    """плетёная корзина: пояски плетения в два тона, ободок"""
    x, y, z = at
    n = 4
    prof = [(r * 0.8 + r * 0.2 * k / n, h * k / n) for k in range(n + 1)]
    mb.lathe(at, prof, 10, J("#b48a4f", 0.06), cols=[J("#b48a4f" if k % 2 else "#9a7040", 0.05) for k in range(n)])
    torus(mb, (x, y + h, z), Matrix.Identity(3), r * 1.0, 0.012, J("#8a6038", 0.05), seg=10, seg2=4)
    mb.lathe((x, y + h * 0.75, z), [(r * 0.95, 0.0), (r * 0.95, 0.001)], 10, col("#5a4428"), close_top=True)


def heap(mb, at, r, kind, s=1.0):
    """горка плодов в корзине или ящике (выше к середине)"""
    x, y, z = at
    pts = [(0.0, 0.0)]
    for rr, k in ((r * 0.5, 6), (r * 0.86, 10)):
        for i in range(k):
            a = 2 * math.pi * i / k + rr * 7
            pts.append((math.cos(a) * rr, math.sin(a) * rr))
    for (dx, dz) in pts:
        hy = (1 - (dx * dx + dz * dz) / (r * r)) * r * 0.4
        fruit(mb, (x + dx, y + hy, z + dz), kind, s)


def build_stall(kind):
    """рыночный прилавок: дощатый стол со скатертью, шесты, тканевый навес с фестонами, корзины и ящики с товаром,
    связки на перекладине, вывеска; позади — запас в ящиках и мешках"""
    coll = bpy.context.scene.collection
    body = MB("House")
    emb = MB("Embers", [MAT_EMBER])
    use("stall")
    cols = {"fruit": ("#f4efe2", "#d9534f"), "veg": ("#f4efe2", "#4f8a5a"), "fish": ("#f4efe2", "#3f6fa8")}[kind]
    w, d = 2.3, 1.5
    x0, x1, z0, z1 = -w / 2, w / 2, -d / 2, d / 2
    I3 = Matrix.Identity(3)
    Xv, Zv = Vector((1, 0, 0)), Vector((0, 0, 1))
    # стол: столешница из досок, ножки, нижняя полка, скатерть спереди
    for k in range(5):
        body.box((0, 0.82, 0.25 - 0.24 + k * 0.12), (w - 0.2, 0.05, 0.115), J(P["wood"], 0.08), mat=M_WOOD)
    for sx in (-1, 1):
        for sz in (0.0, 0.5):
            body.box((sx * (w / 2 - 0.15), 0.4, sz), (0.06, 0.8, 0.06), J(P["wood2"], 0.05), mat=M_WOOD)
    body.box((0, 0.3, 0.25), (w - 0.3, 0.04, 0.5), J(P["wood2"], 0.06), mat=M_WOOD)
    Pt = lambda u, v, n: Vector((x0 + u, v, 0.565 + n))
    drape(body, Pt, Zv, w / 2, 0.85, w - 0.12, 0.42, 0.0, cols[0], folds=7, amp=0.012)
    # шесты, перекладины, навес
    hb, hf = 2.15, 1.85
    for (xx, zz, hh) in ((x0 + 0.05, z0 + 0.05, hb), (x1 - 0.05, z0 + 0.05, hb), (x0 + 0.05, z1 + 0.15, hf), (x1 - 0.05, z1 + 0.15, hf)):
        body.box((xx, hh / 2, zz), (0.06, hh, 0.06), J(P["wood"], 0.05), mat=M_WOOD)
    body.box((0, hf - 0.05, z1 + 0.15), (w, 0.05, 0.05), J(P["wood"], 0.05), mat=M_WOOD)
    body.box((0, hb - 0.05, z0 + 0.05), (w, 0.05, 0.05), J(P["wood"], 0.05), mat=M_WOOD)
    Pa = lambda u, v, n: Vector((x0 - 0.05 + u, v, z0 - 0.02 + n))
    awning(body, Pa, Xv, Zv, (w + 0.1) / 2, hb + 0.06, w + 0.1, d + 0.2, cols, poles=False, drop=(hb - hf) / (d + 0.2), braces=False)
    # вывеска на цепочках у левого края перекладины
    sx_ = x0 + 0.45
    yb = hf - 0.3
    for s in (-1, 1):
        rod(body, (sx_ + s * 0.2, hf - 0.07, z1 + 0.15), (sx_ + s * 0.2, yb + 0.17, z1 + 0.15), 0.007, col(IRON))
    body.box((sx_, yb, z1 + 0.15), (0.5, 0.36, 0.025), J("#6b4428", 0.05), mat=M_WOOD)
    Ps = lambda u, v, n: Vector((u, v, z1 + 0.15 + n))
    sign_board(body, Ps, Xv, Zv, sx_, yb, 0.45, 0.3, 0.014, kind)
    Pb = lambda u, v, n: Vector((-u, v, z1 + 0.15 - n))
    sign_board(body, Pb, -Xv, -Zv, -sx_, yb, 0.45, 0.3, 0.014, kind)
    # связки на перекладине
    hx = [0.05, 0.4, 0.75]
    for k, xx in enumerate(hx):
        hk = (xx, hf - 0.075, z1 + 0.15)
        if kind == "fruit":
            grapes(body, it_hook(body, hk, 0.06 + 0.03 * (k % 2)), 1.4, "#5a2d5f" if k != 1 else "#8fa04a")
        elif kind == "veg":
            (garlic_braid(body, hk, 6) if k != 1 else herb_bundle(body, hk, "#5f8f3a"))
        else:
            top = it_hook(body, hk, 0.04)
            Rh = Matrix.Rotation(math.pi / 2, 3, "Y") @ Matrix.Rotation(-math.pi / 2, 3, "Z")
            fish(body, tuple(top + Vector((0, -0.16, 0))), Rh, 0.24, "#a8a080")
    # товар на столе
    y = 0.845
    zc = 0.22
    if kind == "fish":
        for k, cx in enumerate((x0 + 0.45, -0.1, x1 - 0.5)):
            body.box((cx, y + 0.03, zc), (0.62, 0.06, 0.48), J("#7a5232", 0.06), mat=M_WOOD)
            body.box((cx, y + 0.062, zc), (0.58, 0.012, 0.44), col("#e6f0f2"))
            for j in range(9):                 # колотый лёд
                body.box((cx + rng.uniform(-0.26, 0.26), y + 0.07, zc + rng.uniform(-0.19, 0.19)), (0.03, 0.02, 0.03), col("#f4fbfc"),
                         Matrix.Rotation(rng.uniform(0, 3), 3, "Y"))
            if k == 1:
                octopus(body, (cx, y + 0.068, zc), I3)
                for j in range(3):
                    fish(body, (cx + (j - 1) * 0.16, y + 0.068, zc + 0.15), I3, 0.18, "#c9605a", math.pi / 2 + 0.2 * j)
            else:
                for j in range(5):
                    fish(body, (cx - 0.2 + j * 0.1, y + 0.068, zc), I3, 0.3 if k == 0 else 0.24, ["#9aa6b2", "#a8b0a0", "#8a96a6"][j % 3],
                         math.pi / 2 + rng.uniform(-0.15, 0.15))
        scales(body, (x1 - 0.2, y, zc - 0.22), I3, 0.7)
        knife(body, (x0 + 0.85, y, zc + 0.27), I3, 0.3)
        bucket(body, (x1 + 0.22, 0.0, 0.45), 0.12, 0.22)
        crate(body, (x0 - 0.2, 0.0, 0.4), I3, 0.34, 0.24, 0.3)
        for j in range(4):
            body.box((x0 - 0.2 + rng.uniform(-0.1, 0.1), 0.25, 0.4 + rng.uniform(-0.08, 0.08)), (0.04, 0.03, 0.04), col("#f4fbfc"))
    else:
        conts = (["apple", "pear", "pom", "fig"] if kind == "fruit" else ["cabbage", "onion", "turnip", "carrot"])
        for k, cx in enumerate((x0 + 0.42, x0 + 0.95, x1 - 0.85, x1 - 0.35)):
            kd = conts[k]
            if k % 2 == 0:
                crate(body, (cx, y, zc), I3, 0.42, 0.14, 0.36)
                if kd == "carrot":
                    for j in range(14):
                        a = Vector((cx - 0.15 + (j % 7) * 0.05, y + 0.15 + (j // 7) * 0.03, zc - 0.12 + (j // 7) * 0.1))
                        carrot(body, a, a + Vector((0.02, 0.0, 0.2)))
                elif kd == "cabbage":
                    for j in range(4):
                        fruit(body, (cx + (j % 2 - 0.5) * 0.19, y + 0.1, zc + (j // 2 - 0.5) * 0.16), "cabbage", 1.2)
                else:
                    heap(body, (cx, y + 0.12, zc), 0.17, kd, 1.35)
            else:
                basket2(body, (cx, y, zc), 0.19, 0.14)
                if kd == "carrot":             # морковь веером из корзины
                    for j in range(12):
                        a = 2 * math.pi * j / 12
                        p0 = Vector((cx + math.cos(a) * 0.05, y + 0.16, zc + math.sin(a) * 0.05))
                        carrot(body, p0, p0 + Vector((math.cos(a) * 0.12, -0.04, math.sin(a) * 0.12)))
                else:
                    heap(body, (cx, y + 0.11, zc), 0.16, kd, 1.35)
        if kind == "fruit":
            for j in range(2):
                fruit(body, (0.0 + (j - 0.5) * 0.2, y, zc + 0.24), "melon", 1.0)
            board(body, (x1 - 0.6, y, zc - 0.22), I3, 0.3, 0.16)
            grapes(body, (x1 - 0.6, y + 0.12, zc - 0.22), 1.3)
        else:
            for j in range(5):                 # пучок лука-порея
                leek(body, (x0 + 0.2 + j * 0.03, y + 0.03, zc + 0.27), (x0 + 0.62 + j * 0.03, y + 0.05, zc + 0.2))
        scales(body, (0.0, y, zc - 0.25), I3, 0.7)
        basket2(body, (x1 + 0.22, 0.0, 0.5), 0.17, 0.22)
        heap(body, (x1 + 0.22, 0.2, 0.5), 0.15, conts[0], 1.3)
        basket2(body, (x0 - 0.02, 0.0, 0.62), 0.15, 0.2)
        heap(body, (x0 - 0.02, 0.18, 0.62), 0.13, conts[2] if kind == "fruit" else "onion", 1.3)
        crate(body, (x1 + 0.12, 0.0, 0.05), I3, 0.36, 0.26, 0.3)
        heap(body, (x1 + 0.12, 0.24, 0.05), 0.13, conts[1], 1.3)
    # дощечка с ценой
    body.box((x1 - 0.25, y + 0.1, zc + 0.29), (0.2, 0.14, 0.015), col("#2f3330"), Matrix.Rotation(-0.25, 3, "X"))
    body.box((x1 - 0.25, y + 0.1, zc + 0.298), (0.12, 0.012, 0.002), col("#e8e8e0"), Matrix.Rotation(-0.25, 3, "X"))
    # позади — запас: ящики и мешки (у торговца свой закуток — как у прежнего прилавка)
    for k in range(3):
        crate(body, (x0 + 0.4 + k * 0.42, 0.0 + (0.34 if k == 1 else 0.0), z0 - 0.3), I3, 0.38, 0.32, 0.3)
    crate(body, (x0 + 0.4 + 0.42, 0.0, z0 - 0.3), I3, 0.38, 0.32, 0.3)
    for k in range(2):
        sack(body, (x1 - 0.35 - k * 0.32, 0.0, z0 - 0.35), 0.15, 0.38, open_=False)
    body.obj(coll)
    if not emb.empty():
        emb.obj(coll)
    DOOR_PT[0], DOOR_PT[2] = 0.0, z1 + 0.85
    FP.append([x0 - 0.15, z0 - 0.6, w + 0.4, d + 1.05])
    ACTORS.append([0.0, 0.0, z0 + 0.25, 0.0, "Idle", "any"])
    PERCH.append([0.0, hb + 0.06, 0.0])
    return hb + 0.1


def column(body, at, h, r, c):
    """колонна: база, ствол с утолщением, капитель"""
    x, y, z = at
    body.lathe((x, y, z), [(r * 1.35, 0.0), (r * 1.35, 0.06), (r * 1.15, 0.1)], 10, c, mat=M_MARBLE)
    body.lathe((x, y + 0.1, z), [(r * 1.08, 0.0), (r * 1.1, (h - 0.3) * 0.35), (r * 0.94, h - 0.3)], 10, c, mat=M_MARBLE)
    body.lathe((x, y + h - 0.2, z), [(r * 0.95, 0.0), (r * 1.3, 0.12), (r * 1.4, 0.14)], 10, c, mat=M_MARBLE)
    body.box((x, y + h - 0.03, z), (r * 3.0, 0.06, r * 3.0), c, mat=M_MARBLE)


def portico(body, walls, inner, x0p, x1p, z_wall, depth, style, top):
    """портик домуса перед входом: мраморный пол со ступенями, колонны, архитрав, черепичная кровля с фронтоном"""
    marble = "#ece6da"
    zf = z_wall + depth
    for k in range(3):        # ступени
        body.box(((x0p + x1p) / 2, 0.05 + k * 0.08, zf - k * 0.18 + 0.12), (x1p - x0p + 0.3 - k * 0.1, 0.1, 0.4), J(marble, 0.04, 0.0, 0.0),
                 cols={"top": J(marble, 0.06, 0.0, 0.0)}, skip=("bot",))
    body.box(((x0p + x1p) / 2, PL / 2, z_wall + depth / 2), (x1p - x0p + 0.2, PL, depth + 0.05), J(marble, 0.04, 0.0, 0.0), skip=("bot",), mat=M_MARBLE)
    if style == "arcade":
        # каменная арка на пилонах вместо колонн
        for xx in (x0p + 0.15, x1p - 0.15):
            body.box((xx, (PL + top) / 2, zf - 0.12), (0.26, top - PL, 0.26), J(P["stone"], 0.05), mat=M_STONE)
        cu = (x0p + x1p) / 2
        rr = (x1p - x0p) / 2 - 0.28
        for k in range(11):
            ph = math.pi * (k + 0.5) / 11
            body.box((cu + math.cos(ph) * (rr + 0.08), top - 0.5 + math.sin(ph) * (rr * 0.6 + 0.08), zf - 0.12), (0.12, 0.16, 0.26), J(P["stone"], 0.06),
                     Matrix.Rotation(ph - math.pi / 2, 3, "Z"))
        body.box((cu, top + 0.1, zf - 0.12), (x1p - x0p + 0.1, 0.22, 0.3), J(P["stone"], 0.05), mat=M_STONE)
    else:
        n = 4 if style == "temple" else 2
        for k in range(n):
            xx = x0p + 0.18 + (x1p - x0p - 0.36) * k / (n - 1)
            column(body, (xx, PL, zf - 0.15), top - PL, 0.085, J(marble, 0.03, 0.0, 0.0))
        body.box(((x0p + x1p) / 2, top + 0.08, zf - 0.15), (x1p - x0p + 0.12, 0.16, 0.22), J(marble, 0.03, 0.0, 0.0), mat=M_MARBLE)
        for xx in (x0p + 0.18, x1p - 0.18):     # архитрав к стене
            body.box((xx, top + 0.08, z_wall + depth / 2), (0.16, 0.16, depth), J(marble, 0.03, 0.0, 0.0), mat=M_MARBLE)
    if style == "loggia":
        # плоская кровля-терраса с балюстрадой
        body.box(((x0p + x1p) / 2, top + 0.22, z_wall + depth / 2), (x1p - x0p + 0.14, 0.12, depth + 0.1), J(marble, 0.03, 0.0, 0.0), mat=M_MARBLE)
        for k in range(int((x1p - x0p) / 0.16) + 1):
            xx = x0p + k * 0.16
            body.lathe((xx, top + 0.28, zf - 0.04), [(0.035, 0), (0.05, 0.12), (0.03, 0.24)], 6, J(marble, 0.03, 0.0, 0.0), mat=M_MARBLE)
        body.box(((x0p + x1p) / 2, top + 0.54, zf - 0.04), (x1p - x0p + 0.1, 0.05, 0.1), J(marble, 0.03, 0.0, 0.0), mat=M_MARBLE)
        for k in range(2):
            pot(body, (x0p + 0.3 + k * (x1p - x0p - 0.6), top + 0.28, z_wall + depth * 0.4), 0.24, J("#b8693f", 0.08))
    elif style != "arcade":
        yr, rise = roof(body, False, x0p, x1p, z_wall, zf, top + 0.16, pitch_deg=22.0, oe=0.14, og=0.12)
        # фронтон — треугольник с медальоном
        tri = [Vector((x0p, top + 0.16, zf + 0.02)), Vector((x1p, top + 0.16, zf + 0.02)), Vector(((x0p + x1p) / 2, top + 0.16 + rise, zf + 0.02))]
        body.face([body.v(q) for q in tri], J(marble, 0.02, 0.0, 0.0), ("dir", (0, 0, 1)))
        for k in range(10):
            a = 2 * math.pi * k / 10
            body.box(((x0p + x1p) / 2 + 0.12 * math.cos(a), top + 0.16 + rise * 0.4 + 0.12 * math.sin(a), zf + 0.05), (0.06, 0.06, 0.04),
                     J("#c9a14a", 0.05), Matrix.Rotation(a, 3, "Z"))
    # фонари по сторонам двери, горшки с лавром
    for xx in (x0p + 0.18, x1p - 0.18):
        pot(body, (xx, PL, zf - 0.55), 0.3, J("#b8693f", 0.08))


def cypress(body, at, h):
    x, y, z = at
    body.box((x, y + 0.15, z), (0.06, 0.3, 0.06), J("#5a4030", 0.05))
    for k in range(7):
        t = k / 6
        r = 0.22 * (1 - t * 0.85) + 0.03
        leaf_blob(body, (x + rng.uniform(-0.02, 0.02), y + 0.35 + t * (h - 0.4), z + rng.uniform(-0.02, 0.02)), r, J("#2f5a2a", 0.08))


def garden(body, x0, x1, zb, z_wall, kind):
    """сад за домусом: стенка с черепичным гребнем, дорожка, фонтан или бассейн, кипарисы, клумбы, статуя, скамья"""
    hw = 0.95
    for (a, b) in (((x0, zb), (x1, zb)), ((x0, zb), (x0, z_wall)), ((x1, zb), (x1, z_wall))):
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        cx, cz = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
        R = Matrix.Rotation(math.atan2(b[1] - a[1], b[0] - a[0]) * -1, 3, "Y")
        body.box((cx, hw / 2, cz), (L + 0.14, hw, 0.14), J("#efe6d6", 0.04, 0.0, 0.0), R)
        body.box((cx, hw + 0.03, cz), (L + 0.2, 0.06, 0.22), J(P["tile"], 0.06), R)
    # дорожка
    for k in range(int((z_wall - zb) / 0.3)):
        body.box((0.0, 0.02, z_wall - 0.15 - k * 0.3), (0.5, 0.04, 0.26), J(P["stone"], 0.08, 0.0, 0.1), skip=("bot",), mat=M_STONE)
    zc = (zb + z_wall) / 2
    if kind % 2 == 0:
        # круглый фонтан
        body.lathe((0.0, 0.0, zc), [(0.5, 0.0), (0.5, 0.22), (0.44, 0.22)], 14, J("#e8e2d6", 0.03, 0.0, 0.0))
        body.lathe((0.0, 0.16, zc), [(0.44, 0.0), (0.0, 0.0)], 14, col("#5fa6b8"))
        column(body, (0.0, 0.16, zc), 0.45, 0.05, J("#e8e2d6", 0.03, 0.0, 0.0))
        body.lathe((0.0, 0.62, zc), [(0.04, 0.0), (0.2, 0.06), (0.18, 0.08)], 10, J("#e8e2d6", 0.03, 0.0, 0.0))
    else:
        # прямоугольный бассейн
        body.box((0.0, 0.1, zc), (1.4, 0.2, 0.8), J("#e8e2d6", 0.03, 0.0, 0.0))
        body.box((0.0, 0.19, zc), (1.3, 0.02, 0.7), col("#5fa6b8"))
    for sx in (-1, 1):
        cypress(body, (sx * (W / 2 - 0.35), 0.0, zb + 0.35), 1.7)
        for k in range(5):     # клумбы
            leaf_blob(body, (sx * (W / 2 - 0.4), 0.15, z_wall - 0.4 - k * 0.22), 0.12, J("#4f7d33", 0.1))
            if rng.random() < 0.7:
                leaf_blob(body, (sx * (W / 2 - 0.4) + rng.uniform(-0.06, 0.06), 0.27, z_wall - 0.4 - k * 0.22), 0.04, J(rng.choice(["#d9534f", "#f4f1e8", "#e98bb0"]), 0.06))
    # статуя на постаменте
    sx = -0.9 if kind % 2 == 0 else 0.9
    body.box((sx, 0.3, zb + 0.5), (0.3, 0.6, 0.3), J("#e8e2d6", 0.03, 0.0, 0.0))
    body.lathe((sx, 0.6, zb + 0.5), [(0.1, 0.0), (0.12, 0.3), (0.09, 0.55), (0.05, 0.62), (0.08, 0.7), (0.0, 0.8)], 8, J("#f2eee6", 0.02, 0.0, 0.0))
    bench(body, (-sx, 0.3, zb + 0.45), 0.8, Matrix.Identity(3))


def dado(body, P_, U, N, u0, u1, h, colhex):
    """расписной цоколь стены (помпейский красный) с тёмной полосой поверху"""
    R = RW(U, N)
    # перед неровной штукатуркой (у стены вершины гуляют до ±1,3 см — тонкий цоколь иначе «проваливался»)
    body.box(Pw(P_, (u0 + u1) / 2, PL + h / 2, 0.018), (u1 - u0, h, 0.008), J(colhex, 0.04, 0.0, 0.0), R)
    body.box(Pw(P_, (u0 + u1) / 2, PL + h, 0.021), (u1 - u0, 0.04, 0.01), col("#2a2018"), R)


# =====================================================================================
#   ОБЛИКИ
# =====================================================================================
PALS = [
    {"trim": "#e6d3ad", "wood": "#7a5232", "wood2": "#5e3d24", "tile": "#b85f38", "stone": "#c2ae8e"},
    {"trim": "#eadbc0", "wood": "#80583a", "wood2": "#5a3a22", "tile": "#c0683e", "stone": "#c4b49a"},
    {"trim": "#e9dcc2", "wood": "#74503a", "wood2": "#553826", "tile": "#a95634", "stone": "#bfb09a"},
]

PLEB = [
    # 0 «Ставни»: конёк вдоль улицы, полосатый навес над дверью, скамья, горшки, дрова, предвыборная надпись
    {"roof": "x", "corners": "stone", "front": "awning", "decal": "notice", "shutter": "green", "door": "oak",
     "two_tone": 0.45, "props": ["bench", "pots", "firewood", "basket"], "pal": 0},
    # 1 «Балкон»: деревянный балкон на 2-м этаже (у одноэтажного — черепичный козырёк), бельё, амфоры
    {"roof": "x", "corners": None, "front": "canopy", "shutter": "blue", "door": "dark", "two_tone": 0.7,
     "props": ["amphorae", "laundry", "broom"], "balcony": True, "pal": 1},
    # 2 «Фронтон»: фронтон к улице с круглым окошком, расписной пояс-меандр, ящики цветов
    {"roof": "z", "corners": "pilaster", "front": None, "decal": "frieze", "shutter": "teal", "door": "green",
     "two_tone": 0.4, "props": ["pots", "pots2"], "boxes": True, "pal": 1},
    # 3 «Кирпич»: низ из кирпича, кирпичная арка над дверью, лестница, поленница
    {"roof": "x", "corners": "stone", "front": None, "lower": "brick", "arch": True, "shutter": "brown", "door": "oak",
     "two_tone": 0.0, "props": ["ladder", "firewood", "basket"], "pal": 2},
    # 4 «Навес»: пергола с виноградом перед входом, скамья в тени, фронтон к улице
    {"roof": "z", "corners": None, "front": "pergola", "shutter": "red", "door": "dark", "two_tone": 0.5,
     "props": ["bench", "amphorae", "pots"], "ivy": True, "pal": 0},
]


ART = [
    # 0 ткач — лавка тканей, полосатый навес, балкон
    {"craft": 0, "roof": "x", "corners": "stone", "shutter": "green", "door": "oak", "two_tone": 0.4, "awning": ("#efe3c8", "#3f6fa8"),
     "balcony": True, "pal": 0},
    # 1 зерно — мешки и корзины, черепичный козырёк над лавкой
    {"craft": 3, "roof": "z", "corners": None, "shutter": "ochre", "door": "dark", "two_tone": 0.6, "canopy": True, "boxes": True, "pal": 1},
    # 2 медник — котлы на балке, кирпичный низ
    {"craft": 2, "roof": "x", "corners": "stone", "lower": "brick", "shutter": "brown", "door": "oak", "two_tone": 0.0,
     "awning": ("#e9d9b8", "#7a5232"), "pal": 2},
    # 3 гончар — амфоры, печь во дворе (дымок), фронтон к улице
    {"craft": 1, "roof": "z", "corners": "pilaster", "shutter": "teal", "door": "green", "two_tone": 0.5, "awning": ("#f4efe2", "#c94f3d"),
     "decal": "frieze", "pal": 1},
    # 4 медник — котлы, пергола с виноградом у двери
    {"craft": 2, "roof": "x", "corners": None, "shutter": "red", "door": "dark", "two_tone": 0.5, "canopy": True, "ivy": True, "pal": 0},
]
PAT = [
    # 0 «Перистиль»: портик с фронтоном на двух колоннах, красный расписной цоколь, фонтан в саду
    {"portico": "pediment", "roof": "x", "corners": "pilaster", "shutter": "green", "door": "oak", "dado": "#8e2f24", "pal": 0},
    # 1 «Лоджия»: портик-терраса с балюстрадой, бассейн в саду
    {"portico": "loggia", "roof": "x", "corners": "stone", "shutter": "blue", "door": "dark", "dado": "#7a3a2a", "pal": 1},
    # 2 «Храм»: четыре колонны и фронтон, мраморные пилястры
    {"portico": "temple", "roof": "z", "corners": "pilaster", "shutter": "teal", "door": "green", "pal": 1},
    # 3 «Аркада»: каменная арка у входа, кирпичный низ
    {"portico": "arcade", "roof": "x", "corners": "stone", "shutter": "brown", "door": "oak", "lower": "brick", "pal": 2},
    # 4–5 городской домус (после перестройки): три этажа, портик с фронтоном / терраса
    {"portico": "pediment", "roof": "z", "corners": "pilaster", "shutter": "red", "door": "dark", "dado": "#8e2f24", "decal": "frieze", "pal": 0},
    {"portico": "loggia", "roof": "x", "corners": "stone", "shutter": "green", "door": "oak", "dado": "#6a3a2a", "pal": 2},
]
SMOKE = []
ACTORS = []
PROPS = []          # детали Synty в чертеже: [имя, x, y, z, поворот, масштаб] (метры; масштаб — как у Synty в игре)


# =====================================================================================
#   ОБЩЕСТВЕННЫЕ ЗДАНИЯ (школа, библиотека, академия, склад): корпус — как у домов (стены, окна, ставни, комнаты,
#   крыша), фасад и двор — свои; росписи и рельефы — клетки fresco.png (Codex), вывески — signs.png
# =====================================================================================
FRESCO = ["school", "mosaic", "tymp_lib", "tymp_acad", "ins_lib", "ins_acad", "garden", "birds", "tymp_pref", "ins_pref", "ins_therm", "dolphins"]
FRESCO_ROWS = 6
MARBLE = "#ece6da"
GOLD = "#d9b54a"


def fresco_uv(key, band=False):
    i = FRESCO.index(key)
    cx, cy = i % 2, i // 2
    e = 3.0 / 1536
    u0, u1 = cx / 2 + e, (cx + 1) / 2 - e
    v0, v1 = 1 - (cy + 1) / FRESCO_ROWS + e, 1 - cy / FRESCO_ROWS - e
    if band:                                   # надпись — средняя треть картинки
        v0, v1 = v0 + (v1 - v0) * 0.34, v0 + (v1 - v0) * 0.66
    return u0, u1, v0, v1


def fresco_quad(mb, P_, N, uc, vc, w, h, n, key, band=False):
    u0, u1, v0, v1 = fresco_uv(key, band)
    q = [P_(uc - w / 2, vc - h / 2, n), P_(uc + w / 2, vc - h / 2, n), P_(uc + w / 2, vc + h / 2, n), P_(uc - w / 2, vc + h / 2, n)]
    mb.face([mb.v(tuple(p)) for p in q], (1.0, 1.0, 1.0, 1.0), ("dir", tuple(N)), uv=[(u0, v0), (u1, v0), (u1, v1), (u0, v1)], mat=M_FRESCO)


def fresco_floor(mb, cx, y, cz, w, d, key):
    u0, u1, v0, v1 = fresco_uv(key)
    q = [(cx - w / 2, y, cz + d / 2), (cx + w / 2, y, cz + d / 2), (cx + w / 2, y, cz - d / 2), (cx - w / 2, y, cz - d / 2)]
    mb.face([mb.v(p) for p in q], (1.0, 1.0, 1.0, 1.0), ("dir", (0, 1, 0)), uv=[(u0, v0), (u1, v0), (u1, v1), (u0, v1)], mat=M_FRESCO)


def framed_fresco(mb, P_, U, N, side, uc, vc, w, h, key):
    """роспись в мраморной раме с карнизиком и полочкой (и запрет украшениям поверх неё)"""
    R = RW(U, N)
    mb.box(Pw(P_, uc, vc, 0.012), (w + 0.12, h + 0.12, 0.024), J(MARBLE, 0.03, 0.0, 0.0), R, mat=M_MARBLE)
    mb.box(Pw(P_, uc, vc + h / 2 + 0.09, 0.03), (w + 0.26, 0.06, 0.06), J(MARBLE, 0.03, 0.0, 0.0), R, mat=M_MARBLE)
    mb.box(Pw(P_, uc, vc - h / 2 - 0.08, 0.03), (w + 0.2, 0.05, 0.06), J(MARBLE, 0.03, 0.0, 0.0), R, mat=M_MARBLE)
    fresco_quad(mb, P_, N, uc, vc, w, h, 0.026, key)
    block(side, P_, U, uc - w / 2 - 0.14, uc + w / 2 + 0.14, vc - h / 2 - 0.12, vc + h / 2 + 0.14)


def column3(body, at, h, r, c=None, seg=16, ionic=True, face=(1.0, 0.0, 0.0)):
    """мраморная колонна: аттическая база (два вала), ствол с утонением и каннелюрами (желобки — гранями через одну
    темнее), капитель — эхин, ионические волюты по сторонам, абака"""
    x, y, z = at
    c = c or J(MARBLE, 0.02, 0.0, 0.0)
    body.box((x, y + 0.03, z), (r * 3.0, 0.06, r * 3.0), c, mat=M_MARBLE)
    body.lathe((x, y + 0.06, z), [(r * 1.38, 0.0), (r * 1.4, 0.03), (r * 1.25, 0.06), (r * 1.18, 0.07), (r * 1.28, 0.1), (r * 1.1, 0.13)], seg, c, mat=M_MARBLE)
    y0 = y + 0.19
    sh = h - 0.19 - 0.3
    rings = [(r * 1.04, 0.0), (r * 1.06, sh * 0.3), (r * 0.98, sh * 0.7), (r * 0.88, sh)]
    vs = []
    for (rr, yy) in rings:
        vs.append([body.v((x + rr * math.cos(2 * math.pi * s / seg), y0 + yy, z + rr * math.sin(2 * math.pi * s / seg))) for s in range(seg)])
    dark = col_shift(c, -0.1)
    for k in range(len(rings) - 1):
        for s in range(seg):
            t = (s + 1) % seg
            uv = [(rings[k][1] / 0.8, s / seg), (rings[k][1] / 0.8, (s + 1) / seg), (rings[k + 1][1] / 0.8, (s + 1) / seg), (rings[k + 1][1] / 0.8, s / seg)]
            body.face([vs[k][s], vs[k][t], vs[k + 1][t], vs[k + 1][s]], dark if s % 2 else c, ("from", (x, y0 + (rings[k][1] + rings[k + 1][1]) / 2, z)), uv=uv, mat=M_MARBLE)
    yc = y0 + sh
    body.lathe((x, yc, z), [(r * 0.92, 0.0), (r * 1.0, 0.03), (r * 0.95, 0.05), (r * 1.25, 0.14)], seg, c, mat=M_MARBLE)
    fx, fz = face[0], face[2]
    if ionic:
        side = Vector((fx, 0, fz)).normalized()
        out = Vector((-fz, 0, fx))
        for s in (-1, 1):
            vc = Vector((x, yc + 0.1, z)) + side * (s * r * 1.15)
            spindle(body, vc - out * r * 1.0, vc + out * r * 1.0, [(r * 0.32, 0.0), (r * 0.36, 0.1), (r * 0.3, 0.5), (r * 0.36, 0.9), (r * 0.32, 1.0)], 10, c, mat=M_MARBLE)
            for e in (-1, 1):
                body.lathe(tuple(vc + out * e * r * 1.01), [(r * 0.22, 0.0), (r * 0.06, 0.004)], 8, col_shift(c, -0.15))
    body.box((x, yc + 0.22, z), (r * 3.0, 0.08, r * 3.0), c, mat=M_MARBLE)


def dentils(mb, P_, U, N, u0, u1, v):
    """зубчатый карниз: полка, ряд «сухариков», выносная плита"""
    R = RW(U, N)
    m = J(MARBLE, 0.03, 0.0, 0.0)
    mb.box(Pw(P_, (u0 + u1) / 2, v - 0.05, 0.03), (u1 - u0, 0.05, 0.06), m, R, mat=M_MARBLE)
    n = int((u1 - u0) / 0.1)
    for k in range(n):
        mb.box(Pw(P_, u0 + (k + 0.5) * (u1 - u0) / n, v + 0.01, 0.06), (0.05, 0.07, 0.07), col_shift(m, -0.04), R, mat=M_MARBLE)
    mb.box(Pw(P_, (u0 + u1) / 2, v + 0.07, 0.07), (u1 - u0 + 0.08, 0.05, 0.14), m, R, mat=M_MARBLE)


def pilaster(mb, P_, U, N, side, uc, v0, v1, w=0.24):
    """пилястра: база, плоский ствол с тремя желобками, капитель с завитками"""
    R = RW(U, N)
    m = J(MARBLE, 0.03, 0.0, 0.0)
    mb.box(Pw(P_, uc, v0 + 0.08, 0.04), (w + 0.08, 0.16, 0.08), m, R, mat=M_MARBLE)
    mb.box(Pw(P_, uc, (v0 + v1) / 2, 0.025), (w, v1 - v0 - 0.3, 0.05), m, R, mat=M_MARBLE)
    for k in (-1, 0, 1):
        mb.box(Pw(P_, uc + k * w * 0.27, (v0 + v1) / 2, 0.051), (0.025, v1 - v0 - 0.45, 0.004), col_shift(m, -0.14), R)
    mb.box(Pw(P_, uc, v1 - 0.1, 0.035), (w + 0.06, 0.12, 0.07), m, R, mat=M_MARBLE)
    for s in (-1, 1):
        mb.lathe(tuple(P_(uc + s * (w / 2 + 0.01), v1 - 0.1, 0.07)), [(0.045, 0.0), (0.045, 0.01)], 8, col_shift(m, -0.06), close_top=True)
    mb.box(Pw(P_, uc, v1 - 0.02, 0.045), (w + 0.12, 0.05, 0.09), m, R, mat=M_MARBLE)
    block(side, P_, U, uc - w / 2 - 0.05, uc + w / 2 + 0.05, v0, v1)


def swag(mb, p0, p1, sag, h, c, nrm, fringe=GOLD):
    """тканевая гирлянда-фестон между двумя точками: верх чуть провисает, низ — дугой; бахрома и кисти, розетки"""
    p0, p1 = Vector(p0), Vector(p1)
    nrm = Vector(nrm)
    n = 12
    grid = {}
    ts = TS[M_CLOTH]
    L = (p1 - p0).length
    for i in range(n + 1):
        t = i / n
        base = p0 + (p1 - p0) * t
        top = base + Vector((0, -sag * 0.25 * 4 * t * (1 - t), 0))
        bot = base + Vector((0, -(sag + h) * (4 * t * (1 - t)) ** 0.8 - 0.02, 0)) + nrm * (0.05 * 4 * t * (1 - t))
        fold = 0.012 * math.sin(i * 1.9)
        grid[(i, 0)] = tuple(top + nrm * fold)
        grid[(i, 1)] = tuple((top + bot) / 2 + nrm * (0.04 * 4 * t * (1 - t) + fold))
        grid[(i, 2)] = tuple(bot + nrm * fold)
    base_c = J(c, 0.04)
    sheet(mb, grid, n, 2, lambda i, j: col_shift(base_c, (0.07 if j == 0 else -0.04 * j) + 0.04 * math.sin(i * 1.9)), nrm,
          lambda i, j: (L * i / n / ts, (sag + h) * j / 2 / ts))
    fc = col(fringe)
    for i in range(1, n):
        q = Vector(grid[(i, 2)])
        rod(mb, q, q + Vector((0, -0.045, 0)), 0.008, fc)
    for p in (p0, p1):                         # розетка и две кисти на месте подвеса
        mb.lathe(tuple(p + nrm * 0.02), [(0.05, 0.0), (0.035, 0.02), (0.0, 0.03)], 8, fc)
        for s in (-1, 1):
            a = p + nrm * 0.03 + Vector((s * 0.02, -0.02, 0))
            spindle(mb, a, a + Vector((0, -0.16, 0)), [(0.006, 0.0), (0.014, 0.7), (0.018, 0.85), (0.0, 1.0)], 6, fc)


def banner(mb, P_, U, N, side, uc, vtop, w, h, n, idx):
    """торжественное знамя (вексиллум) на бронзовом пруте с шарами: полотно со складками, рисунок — клетка banners.png"""
    R = RW(U, N)
    mb.box(Pw(P_, uc, vtop + 0.02, n + 0.04), (w + 0.12, 0.03, 0.03), col(BRONZE), R)
    for s in (-1, 1):
        ball(mb, Pw(P_, uc + s * (w / 2 + 0.07), vtop + 0.02, n + 0.04), 0.03, col(GOLD), seg=6, rings=3)
    for s in (-1, 1):
        rod(mb, Pw(P_, uc + s * (w / 2 - 0.02), vtop + 0.02, n + 0.04), Pw(P_, uc + s * (w / 2 - 0.02), vtop + 0.12, 0.0), 0.012, col(BRONZE))
    nu, nv = 8, 5
    grid = {}
    for i in range(nu + 1):
        for j in range(nv + 1):
            t = j / nv
            grid[(i, j)] = Pw(P_, uc - w / 2 + w * i / nu, vtop - h * t, n + 0.012 * math.sin(2 * math.pi * 2 * i / nu) * (0.4 + 0.6 * t) + 0.04 * t * t)
    u0, u1 = idx / 4 + 0.002, (idx + 1) / 4 - 0.002
    sheet(mb, grid, nu, nv, lambda i, j: col_shift((1.0, 1.0, 1.0, 1.0), 0.06 * math.cos(2 * math.pi * 2 * (i + 0.5) / nu) - 0.06), N,
          lambda i, j: (u0 + (u1 - u0) * i / nu, 1.0 - j / nv * 0.996), mat=M_BANNER, back=-0.35)
    block(side, P_, U, uc - w / 2 - 0.1, uc + w / 2 + 0.1, vtop - h - 0.05, vtop + 0.15)


def laurel(mb, p0, p1, sag, nrm):
    """лавровая гирлянда с красными лентами на концах"""
    pts = sag_pts(p0, p1, sag, 14)
    nrm = Vector(nrm)
    for k, p in enumerate(pts):
        for j in range(4):                     # листья — вытянутые, вразброс (не «кристаллы»)
            a = rng.uniform(0, 6.28)
            ball(mb, tuple(p + nrm * 0.03 + Vector((math.cos(a) * 0.025, math.sin(a) * 0.03, 0))), 0.035,
                 J(rng.choice(["#4f7d33", "#3f6b2a", "#5f8f3a"]), 0.1), seg=5, rings=3, sq=(0.45, 1.0, 0.22),
                 R=Matrix.Rotation(a, 3, "Z") @ Matrix.Rotation(rng.uniform(-0.6, 0.6), 3, "Y"))
        if k % 3 == 1:
            ball(mb, tuple(p + nrm * 0.07), 0.016, J("#c0392b", 0.08), seg=5, rings=3)
    for p in (pts[0], pts[-1]):
        for s in (-1, 1):
            a = p + nrm * 0.04
            rod(mb, a, a + Vector((s * 0.05, -0.28, 0)), 0.022, col("#a8302a"))


def clipeus(mb, P_, N, uc, vc, r=0.22):
    """бронзовый щит-медальон на стене: диск, обод, умбон"""
    Rn = _ymat(N)
    c = P_(uc, vc, 0.02)
    disc(mb, tuple(c), r, r, 0.03, col("#b08a3a"), Rn, seg=16, top=col("#c9a14a"))
    torus(mb, tuple(c + N * 0.03), Rn, r * 0.92, 0.018, col("#8a6a2a"), seg=16, seg2=4)
    ball(mb, tuple(c + N * 0.04), r * 0.28, col("#d9b54a"), seg=8, rings=4, sq=(1.0, 0.5, 1.0), R=Rn)


def tripod(mb, emb, at, h=1.0):
    """бронзовая жаровня на треноге — стоит на земле; огонь в чаше (свет ночью — LIGHTS kind=hang)"""
    x, y, z = at
    for k in range(3):
        a = 2 * math.pi * k / 3 + 0.3
        rod(mb, (x + math.cos(a) * 0.05, y + h - 0.12, z + math.sin(a) * 0.05), (x + math.cos(a) * 0.22, y, z + math.sin(a) * 0.22), 0.028, col("#9a7a3a"))
        ball(mb, (x + math.cos(a) * 0.22, y + 0.03, z + math.sin(a) * 0.22), 0.035, col("#8a6a2a"), seg=6, rings=3)
    torus(mb, (x, y + h * 0.45, z), Matrix.Identity(3), 0.12, 0.012, col("#9a7a3a"), seg=10, seg2=3)
    mb.lathe((x, y + h - 0.14, z), [(0.04, 0.0), (0.17, 0.1), (0.2, 0.14), (0.21, 0.17)], 12, col(BRONZE))
    for k in range(7):
        leaf_blob(emb, (x + rng.uniform(-0.1, 0.1), y + h + 0.02, z + rng.uniform(-0.1, 0.1)), 0.05, col(rng.choice(["#ff7a1a", "#ffb03a", "#e0501a"])))
    LIGHTS.append({"lamp": [round(x, 3), round(y + h + 0.15, 3), round(z, 3)], "kind": "hang"})


def acroterion(mb, at, s=1.0):
    """акротерий: пальметта из мрамора на углу фронтона"""
    x, y, z = at
    m = J(MARBLE, 0.03, 0.0, 0.0)
    mb.box((x, y + 0.04 * s, z), (0.16 * s, 0.08 * s, 0.1 * s), m, mat=M_MARBLE)
    for k in range(5):
        a = math.radians(-50 + k * 25)
        ball(mb, (x + math.sin(a) * 0.1 * s, y + 0.1 * s + math.cos(a) * 0.1 * s, z), 0.05 * s, m, seg=6, rings=3, sq=(0.5, 1.4, 0.3),
             R=Matrix.Rotation(-a, 3, "Z"))


def floor_tiles(mb, x0, x1, z0, z1, y, s=0.4, c1="#ece6da", c2="#bf8f72"):
    """мраморный пол шашками (opus sectile)"""
    nx, nz = max(1, int(round((x1 - x0) / s))), max(1, int(round((z1 - z0) / s)))
    for i in range(nx):
        for j in range(nz):
            cc = c1 if (i + j) % 2 == 0 else c2
            mb.box((x0 + (i + 0.5) * (x1 - x0) / nx, y + 0.006, z0 + (j + 0.5) * (z1 - z0) / nz), ((x1 - x0) / nx - 0.012, 0.012, (z1 - z0) / nz - 0.012),
                   J(cc, 0.04, 0.0, 0.0), mat=M_MARBLE, skip=("bot",))


def balustrade(mb, xa, xb, z, h=0.85):
    """мраморная балюстрада: цоколь, столбики-балясины, поручень, тумбы по концам"""
    m = J(MARBLE, 0.02, 0.0, 0.0)
    xa, xb = min(xa, xb), max(xa, xb)
    mb.box(((xa + xb) / 2, 0.06, z), (xb - xa, 0.12, 0.26), J(P["stone"], 0.04), mat=M_STONE)
    mb.box(((xa + xb) / 2, h - 0.04, z), (xb - xa, 0.08, 0.22), m, mat=M_MARBLE)
    n = int((xb - xa) / 0.16)
    for k in range(n):
        xx = xa + (k + 0.5) * (xb - xa) / n
        mb.lathe((xx, 0.12, z), [(0.04, 0.0), (0.03, 0.08), (0.055, (h - 0.2) * 0.45), (0.03, (h - 0.2) * 0.85), (0.04, h - 0.2)], 8, m, mat=M_MARBLE)
    for xx in (xa + 0.08, xb - 0.08):
        mb.box((xx, h / 2, z), (0.2, h, 0.26), m, mat=M_MARBLE)
        mb.lathe((xx, h, z), [(0.06, 0.0), (0.09, 0.06), (0.05, 0.12), (0.0, 0.16)], 8, m, mat=M_MARBLE)


def socle(mb, P_, U, N, u0, u1, h, openings):
    """цоколь из тёсаного камня вдоль стены (блоки вперевязку, через проёмы не идёт)"""
    R = RW(U, N)
    for row in range(2):
        v = 0.0 + row * h / 2
        u = u0 + (0.25 if row % 2 else 0.0)
        while u < u1 - 0.05:
            ub = min(u + 0.5, u1)
            uc = (u + ub) / 2
            if not any(a - 0.03 < uc < b + 0.03 and c < v + h / 4 < d for (a, b, c, d) in openings):
                mb.box(Pw(P_, uc, v + h / 4, 0.025), (ub - u - 0.02, h / 2 - 0.02, 0.05), J(P["stone"], 0.06), R, mat=M_STONE)
            u = ub
    mb.box(Pw(P_, (u0 + u1) / 2, h + 0.02, 0.04), (u1 - u0, 0.05, 0.08), J(P["stone"], 0.04), R, mat=M_STONE)


def temple_front(body, x0p, x1p, z_wall, depth, y0, colh, n, key=None, ins=None, r=0.1, pitch=22.0, steps=3, swags=None):
    """портик с фронтоном: подиум со ступенями и полом шашками, колонны с каннелюрами, архитрав (с надписью),
    фронтон с рельефом и акротериями, черепичная кровля; swags — цвет тканевых гирлянд между колоннами"""
    zf = z_wall + depth
    m = MARBLE
    for k in range(steps):
        th = y0 * (steps - k) / steps
        body.box(((x0p + x1p) / 2, th / 2, zf + 0.1 + k * 0.2), (x1p - x0p + 0.3 + k * 0.2, th, 0.2), J(m, 0.03, 0.0, 0.0),
                 cols={"top": J(m, 0.05, 0.0, 0.0)}, skip=("bot",), mat=M_MARBLE)
    body.box(((x0p + x1p) / 2, y0 / 2, z_wall + depth / 2), (x1p - x0p + 0.3, y0, depth + 0.05), J(P["stone"], 0.03), skip=("bot",), mat=M_STONE)
    floor_tiles(body, x0p - 0.1, x1p + 0.1, z_wall + 0.05, zf, y0)
    cx = []
    for k in range(n):
        xx = x0p + 0.2 + (x1p - x0p - 0.4) * k / (n - 1)
        cx.append(xx)
        column3(body, (xx, y0, zf - 0.18), colh, r, face=(1.0, 0.0, 0.0))
    top = y0 + colh
    ah = 0.3
    body.box(((x0p + x1p) / 2, top + ah / 2, zf - 0.18), (x1p - x0p + 0.2, ah, 0.3), J(m, 0.02, 0.0, 0.0), mat=M_MARBLE)
    body.box(((x0p + x1p) / 2, top + 0.03, zf - 0.02), (x1p - x0p + 0.22, 0.05, 0.03), J(m, -0.04, 0.0, 0.0), mat=M_MARBLE)
    body.box(((x0p + x1p) / 2, top + ah + 0.04, zf - 0.16), (x1p - x0p + 0.34, 0.08, 0.36), J(m, 0.03, 0.0, 0.0), mat=M_MARBLE)
    nd = int((x1p - x0p + 0.3) / 0.1)
    for k in range(nd):                        # сухарики под выносной плитой
        body.box((x0p - 0.15 + (k + 0.5) * (x1p - x0p + 0.3) / nd, top + ah - 0.01, zf + 0.0), (0.045, 0.05, 0.05), J(m, -0.02, 0.0, 0.0), mat=M_MARBLE)
    for xx in (x0p + 0.2, x1p - 0.2):
        body.box((xx, top + ah / 2, z_wall + depth / 2), (0.2, ah, depth), J(m, 0.02, 0.0, 0.0), mat=M_MARBLE)
    if ins:
        P_ = lambda u, v, nn: Vector((x0p + u, v, zf - 0.18 + 0.151 + nn))
        fresco_quad(body, P_, Vector((0, 0, 1)), (x1p - x0p) / 2, top + ah / 2, min(x1p - x0p - 0.3, ah * 4.0 * 2.2), ah * 0.86, 0.0, ins, band=True)
    if swags:
        for k in range(n - 1):
            swag(body, (cx[k] + r * 1.4, top - 0.02, zf - 0.02), (cx[k + 1] - r * 1.4, top - 0.02, zf - 0.02), 0.22, 0.16, swags, (0, 0, 1))
    yb = top + ah + 0.08
    yr, rise = roof(body, False, x0p - 0.05, x1p + 0.05, z_wall, zf, yb, pitch_deg=pitch, oe=0.16, og=0.14, antefix=True)
    tri = [Vector((x0p, yb, zf + 0.0)), Vector((x1p, yb, zf + 0.0)), Vector(((x0p + x1p) / 2, yb + rise * 0.95, zf + 0.0))]
    body.face([body.v(q) for q in tri], J(m, 0.02, 0.0, 0.0), ("dir", (0, 0, 1)), mat=M_MARBLE)
    if key:
        a, b, apex = [q + Vector((0, 0, 0.012)) for q in tri]
        a = a + Vector((0.18, 0.04, 0))
        b = b + Vector((-0.18, 0.04, 0))
        apex = apex + Vector((0, -0.08, 0))
        u0, u1, v0, v1 = fresco_uv(key)
        body.face([body.v(tuple(a)), body.v(tuple(b)), body.v(tuple(apex))], (1.0, 1.0, 1.0, 1.0), ("dir", (0, 0, 1)),
                  uv=[(u0, v0 + (v1 - v0) * 0.1), (u1, v0 + (v1 - v0) * 0.1), ((u0 + u1) / 2, v0 + (v1 - v0) * 0.85)], mat=M_FRESCO)
    for s in (-1, 1):                          # карнизы по скатам
        p0 = Vector(((x0p + x1p) / 2, yb + rise * 0.95 + 0.04, zf + 0.04))
        p1 = Vector((x0p - 0.05 if s < 0 else x1p + 0.05, yb + 0.02, zf + 0.04))
        rod(body, p0, p1, 0.09, J(m, 0.03, 0.0, 0.0), mat=M_MARBLE)
        acroterion(body, (x0p - 0.02 if s < 0 else x1p + 0.02, yb + 0.06, zf + 0.04), 1.1)
    acroterion(body, ((x0p + x1p) / 2, yb + rise * 0.95 + 0.06, zf + 0.04), 1.4)
    return yb + rise


def statue_prop(x, z, yaw=0.0, s=0.7, y=0.0, plinth=True, k=None):
    """статуя Synty на постаменте (в чертёж — как деталь; метры, масштаб — как у Synty в игре)"""
    k = k if k is not None else 1 + rng.randrange(7)
    if plinth:
        PROPS.append(["SM_Prop_Plinth_04", round(x, 3), round(y, 3), round(z, 3), 0.0, round(s * 1.2, 3)])
        y += 0.68 * s * 1.2 * 0.72
    PROPS.append(["SM_Prop_Statue_0%d" % k, round(x, 3), round(y, 3), round(z, 3), yaw, s])


def tree_prop(name, x, z, s):
    PROPS.append([name, round(x, 3), 0.0, round(z, 3), round(rng.uniform(0, 6.28), 3), s])


def niche(body, P_, U, N, side, uc, v0, w=0.62, h=1.5):
    """ниша в стене: тёмная арка, мраморное обрамление с клинчатой аркой и замковым камнем, полка; внутри — статуя"""
    R = RW(U, N)
    m = J(MARBLE, 0.03, 0.0, 0.0)
    body.box(Pw(P_, uc, v0 + h / 2, 0.006), (w, h, 0.012), col("#4a3c30"), R)
    for k in range(9):
        ph = math.pi * (k + 0.5) / 9
        body.box(Pw(P_, uc + math.cos(ph) * (w / 2 + 0.04), v0 + h + math.sin(ph) * 0.22, 0.03), (0.07, 0.11, 0.06), m,
                 R @ Matrix.Rotation(ph - math.pi / 2, 3, "Z"), mat=M_MARBLE)
    body.box(Pw(P_, uc, v0 + h + 0.27, 0.045), (0.09, 0.14, 0.09), J(MARBLE, 0.05, 0.0, 0.0), R, mat=M_MARBLE)
    for uu in (uc - w / 2 - 0.04, uc + w / 2 + 0.04):
        body.box(Pw(P_, uu, v0 + h / 2, 0.03), (0.08, h, 0.06), m, R, mat=M_MARBLE)
    body.box(Pw(P_, uc, v0 - 0.04, 0.08), (w + 0.2, 0.08, 0.18), m, R, mat=M_MARBLE)
    body.box(Pw(P_, uc, v0 - 0.14, 0.05), (w + 0.1, 0.12, 0.1), m, R, mat=M_MARBLE)
    p = P_(uc, v0, 0.12)
    statue_prop(p.x, p.z, 0.0 if N.z > 0.5 else math.atan2(N.x, N.z), 0.62, p.y, plinth=False)
    block(side, P_, U, uc - w / 2 - 0.12, uc + w / 2 + 0.12, v0 - 0.2, v0 + h + 0.36)


def wax_tablet(mb, at, R, ang=0.0):
    Rr = R @ Matrix.Rotation(ang, 3, "Y")
    mb.box(LP(at, Rr, 0, 0.008, 0), (0.16, 0.016, 0.11), J("#6b4428", 0.05), Rr, mat=M_WOOD)
    mb.box(LP(at, Rr, 0, 0.017, 0), (0.13, 0.004, 0.085), J("#c8a03a", 0.05), Rr)
    mb.box(LP(at, Rr, 0.04, 0.022, 0.0), (0.006, 0.006, 0.09), col("#d8d0c0"), Rr @ Matrix.Rotation(0.5, 3, "Y"))


def abacus(mb, at, R):
    mb.box(LP(at, R, 0, 0.03, 0), (0.34, 0.06, 0.12), J("#5e3d24", 0.05), R, mat=M_WOOD)
    mb.box(LP(at, R, 0, 0.18, 0), (0.3, 0.24, 0.02), J("#6b4428", 0.05), R, mat=M_WOOD)
    for j in range(4):
        for k in range(5):
            ball(mb, LP(at, R, -0.1 + k * 0.035 + (0.06 if j % 2 else 0.0), 0.11 + j * 0.05, 0.014), 0.012, col(["#b5452f", "#e1b84a", "#3f6fa8", "#efe3c8"][j]), seg=5, rings=3)


def sundial(mb, at):
    x, y, z = at
    mb.lathe(at, [(0.12, 0.0), (0.12, 0.06), (0.06, 0.1), (0.055, 0.62), (0.1, 0.68), (0.1, 0.72)], 10, J(MARBLE, 0.03, 0.0, 0.0), close_top=True, mat=M_MARBLE)
    mb.box((x, y + 0.79, z), (0.006, 0.14, 0.1), col(BRONZE), Matrix.Rotation(0.6, 3, "X"))
    for k in range(9):
        a = math.pi * k / 8
        mb.box((x + math.cos(a) * 0.075, y + 0.722, z + math.sin(a) * 0.075), (0.008, 0.003, 0.03), col("#3a332c"), Matrix.Rotation(-a, 3, "Y"))


def lectern(mb, at, R):
    mb.box(LP(at, R, 0, 0.45, 0), (0.06, 0.9, 0.06), J("#6b4428", 0.05), R, mat=M_WOOD)
    mb.box(LP(at, R, 0, 0.92, 0.02), (0.36, 0.03, 0.26), J("#7a5232", 0.05), R @ Matrix.Rotation(-0.4, 3, "X"), mat=M_WOOD)
    mb.box(LP(at, R, 0, 0.03, 0), (0.3, 0.06, 0.3), J("#5e3d24", 0.05), R, mat=M_WOOD)
    scroll(mb, LP(at, R, 0, 0.94, 0.03), R @ Matrix.Rotation(-0.4, 3, "X"), 0.26, 0.022)


def capsa(mb, at, n=6):
    x, y, z = at
    mb.lathe(at, [(0.11, 0.0), (0.12, 0.22)], 10, J("#8a5a32", 0.05), mat=M_WOOD)
    torus(mb, (x, y + 0.22, z), Matrix.Identity(3), 0.12, 0.01, col(BRONZE), seg=10, seg2=3)
    for k in range(n):
        a = 2 * math.pi * k / n
        spindle(mb, (x + math.cos(a) * 0.06, y + 0.05, z + math.sin(a) * 0.06), (x + math.cos(a) * 0.07, y + 0.32, z + math.sin(a) * 0.07),
                [(0.022, 0.0), (0.022, 1.0)], 7, J("#e8dcb8", 0.04))


def armarium(mb, P_, U, N, uc, n, w=1.0, h=1.6):
    R = RW(U, N)
    mb.box(Pw(P_, uc, PL + h / 2, n), (w, h, 0.32), J("#6b4428", 0.05), R, mat=M_WOOD)
    rows, cols = 4, 4
    for i in range(cols):
        for j in range(rows):
            cu = uc - w / 2 + (i + 0.5) * w / cols
            cv = PL + 0.1 + (j + 0.5) * (h - 0.2) / rows
            mb.box(Pw(P_, cu, cv, n + 0.161), (w / cols - 0.04, (h - 0.2) / rows - 0.04, 0.004), col("#2a2018"), R)
            for k in range(3):
                spindle(mb, Pw(P_, cu - 0.05 + k * 0.05, cv - 0.06 + (k % 2) * 0.04, n + 0.16), Pw(P_, cu - 0.05 + k * 0.05, cv - 0.06 + (k % 2) * 0.04, n + 0.06),
                        [(0.024, 0.0), (0.024, 1.0)], 6, J("#e8dcb8", 0.05))


def marble_bench(mb, at, R, ln=1.0):
    m = J(MARBLE, 0.03, 0.0, 0.0)
    mb.box(LP(at, R, 0, 0.3, 0), (ln, 0.07, 0.32), m, R, mat=M_MARBLE)
    for s in (-1, 1):
        mb.box(LP(at, R, s * (ln / 2 - 0.1), 0.14, 0), (0.12, 0.28, 0.26), m, R, mat=M_MARBLE)
        mb.box(LP(at, R, s * (ln / 2 - 0.1), 0.33, 0), (0.14, 0.04, 0.3), m, R, mat=M_MARBLE)
        ball(mb, LP(at, R, s * (ln / 2 - 0.1), 0.2, 0.14), 0.05, col_shift(m, -0.05), seg=6, rings=3, sq=(0.6, 1.0, 0.4))


def tholos(body, cx, cz, r, h, y0=0.0):
    """круглая беседка-толос: подиум, кольцо колонн с каннелюрами, антаблемент с сухариками, черепичный купол"""
    m = MARBLE
    for k in range(2):
        body.lathe((cx, y0 + k * 0.08, cz), [(r + 0.25 - k * 0.12, 0.0), (r + 0.25 - k * 0.12, 0.08)], 16, J(m, 0.03, 0.0, 0.0), close_top=True, mat=M_MARBLE)
    n = 8
    for k in range(n):
        a = 2 * math.pi * k / n
        column3(body, (cx + math.cos(a) * r, y0 + 0.16, cz + math.sin(a) * r), h, 0.065, seg=12, face=(-math.sin(a), 0, math.cos(a)))
    top = y0 + 0.16 + h
    body.lathe((cx, top, cz), [(r + 0.12, 0.0), (r + 0.12, 0.18), (r + 0.18, 0.2), (r + 0.18, 0.26)], 16, J(m, 0.02, 0.0, 0.0), mat=M_MARBLE)
    for k in range(32):
        a = 2 * math.pi * k / 32
        body.box((cx + math.cos(a) * (r + 0.13), top + 0.15, cz + math.sin(a) * (r + 0.13)), (0.04, 0.05, 0.05), J(m, -0.03, 0.0, 0.0), Matrix.Rotation(-a, 3, "Y"), mat=M_MARBLE)
    prof = [(r + 0.2, 0.0), (r * 0.95, r * 0.35), (r * 0.7, r * 0.62), (r * 0.38, r * 0.82), (0.06, r * 0.9)]
    body.lathe((cx, top + 0.26, cz), prof, 16, J(P["tile"], 0.06), cols=[J(P["tile"], 0.05), J(P["tile"], 0.05, 0.01), J(P["tile"], 0.05), J(P["tile"], 0.05)])
    for k in range(16):
        a = 2 * math.pi * k / 16
        for j in range(len(prof) - 1):
            p0 = Vector((cx + math.cos(a) * prof[j][0], top + 0.26 + prof[j][1], cz + math.sin(a) * prof[j][0]))
            p1 = Vector((cx + math.cos(a) * prof[j + 1][0], top + 0.26 + prof[j + 1][1], cz + math.sin(a) * prof[j + 1][0]))
            rod(body, p0 + (p0 - Vector((cx, top, cz))).normalized() * 0.01, p1 + (p1 - Vector((cx, top, cz))).normalized() * 0.01, 0.05, J(P["tile"], 0.08, 0.01, 0.06))
    body.lathe((cx, top + 0.26 + r * 0.9, cz), [(0.08, 0.0), (0.05, 0.1), (0.09, 0.16), (0.0, 0.3)], 8, J("#c9a14a", 0.05))
    return top


def stoa(body, x_wall, sgn, z0s, z1s, depth, h, fresco=None):
    """крытая колоннада вдоль бока двора: стена снаружи, внутри — помпейский красный низ и роспись в раме, колонны,
    навес черепицей скатом во двор"""
    m = MARBLE
    xw = x_wall
    xc = x_wall - sgn * depth
    body.box((xw, h / 2, (z0s + z1s) / 2), (0.18, h, z1s - z0s), J("#f6f2ea", 0.02, 0.0, 0.0), mat=M_ASHM)
    body.box((xw - sgn * 0.095, 0.5, (z0s + z1s) / 2), (0.012, 0.8, z1s - z0s - 0.05), J("#a83f2c", 0.04))
    body.box((xw - sgn * 0.097, 0.92, (z0s + z1s) / 2), (0.012, 0.05, z1s - z0s - 0.05), J("#e8d8a8", 0.03))
    if fresco:
        Pw_ = lambda u, v, n: Vector((xw - sgn * (0.09 + n), v, (z0s + z1s) / 2 + sgn * (u - (z1s - z0s) / 2)))
        Nw = Vector((-sgn, 0, 0))
        Uw = Vector((0, 0, sgn))
        framed_fresco(body, Pw_, Uw, Nw, "stoa", (z1s - z0s) / 2, 1.42, min(1.5, z1s - z0s - 0.6), 0.7, fresco)
    body.box(((xw + xc) / 2, 0.04, (z0s + z1s) / 2), (depth + 0.1, 0.08, z1s - z0s), J(m, 0.03, 0.0, 0.0), skip=("bot",), mat=M_MARBLE)
    nc = max(2, int((z1s - z0s) / 1.0) + 1)
    for k in range(nc):
        zz = z0s + 0.15 + (z1s - z0s - 0.3) * k / (nc - 1)
        column3(body, (xc, 0.08, zz), h - 0.1, 0.06, seg=10, face=(0.0, 0.0, 1.0))
    body.box((xc, h + 0.06, (z0s + z1s) / 2), (0.18, 0.14, z1s - z0s + 0.1), J(m, 0.02, 0.0, 0.0), mat=M_MARBLE)
    along = Vector((0, 0, 1))
    nrow = int((z1s - z0s) / 0.3)
    for k in range(nrow):
        zz = z0s + (k + 0.5) * (z1s - z0s) / nrow
        p0 = Vector((xw, h + 0.4, zz))
        p1 = Vector((xc - sgn * 0.2, h + 0.1, zz))
        dl = p1 - p0
        ny = dl.normalized().cross(along).normalized()
        if ny.y < 0:
            ny = -ny
        Rr = Matrix((along, ny, dl.normalized())).transposed()
        body.box(tuple((p0 + p1) / 2), ((z1s - z0s) / nrow - 0.02, 0.05, dl.length + 0.05), J(P["tile"], 0.08, 0.01, 0.08), Rr)
        body.box(tuple((p0 + p1) / 2 + Vector((0, 0.04, 0))), (0.09, 0.07, dl.length + 0.05), J(P["tile"], 0.08, 0.01, 0.08), Rr)


def hoist(body, P_, U, N, uc, v):
    """подъёмник склада: балка с блоком над грузовой дверью, верёвка, мешок на крюке"""
    R = RW(U, N)
    body.box(Pw(P_, uc, v, 0.45), (0.14, 0.14, 0.9), J(P["wood2"], 0.05), R, mat=M_WOOD)
    rod(body, Pw(P_, uc, v - 0.35, 0.0), Pw(P_, uc, v - 0.07, 0.6), 0.08, J(P["wood2"], 0.05), mat=M_WOOD)
    torus(body, tuple(P_(uc, v - 0.12, 0.82)), Matrix((N, U, Vector((0, 1, 0)))).transposed(), 0.06, 0.02, J("#6b4428", 0.05), seg=10, seg2=4)
    rod(body, Pw(P_, uc, v - 0.18, 0.86), Pw(P_, uc, v - 1.05, 0.86), 0.014, col(ROPE))
    rod(body, Pw(P_, uc, v - 0.18, 0.78), Pw(P_, uc, PL + FLH - 0.2, 0.2), 0.014, col(ROPE))
    sack(body, Pw(P_, uc, v - 1.38, 0.86), 0.12, 0.32, open_=False)


def rope_coil(mb, at):
    x, y, z = at
    for k in range(4):
        torus(mb, (x, y + 0.02 + k * 0.03, z), Matrix.Identity(3), 0.14 - k * 0.012, 0.016, J(ROPE, 0.05), seg=12, seg2=4)


def pergola_hooks(u0, u1, targets):
    """точки на поперечных балках перголы (pergola: балки через ~0,32 м), ближайшие к желаемым"""
    nb = int((u1 - u0) / 0.32) + 1
    us = [u0 + (u1 - u0) * k / max(1, nb - 1) for k in range(nb)]
    return [min(us, key=lambda q: abs(q - t)) for t in targets]


# ---- облики ----
# fwins: (этаж, u0, u1, низ над полом, верх над полом, ставни, ящик с цветами, наличник, решётка[, фронтончик])
CIVIC = {
    "school": {"w": 6.4, "d": 3.5, "floors": 2, "roof": "x", "pal": 1, "tint": "#f0d98c", "shutter": "green", "door": "oak",
               "door_u": (2.65, 3.75), "door_h": 1.62, "double": True, "corners": "stone", "sign": "school", "socle": 0.5,
               "fwins": [(0, 0.55, 1.25, 0.75, 1.5, True, False, True, False), (0, 5.15, 5.85, 0.75, 1.5, True, False, True, False),
                         (1, 0.6, 1.25, 0.72, 1.48, True, True, True, False, True), (1, 5.15, 5.8, 0.72, 1.48, True, True, True, False, True)],
               "frescos": [(1, 3.2, 1.12, 1.5, 0.75, "school")]},
    "library": {"w": 8.0, "d": 3.8, "floors": 2, "roof": "x", "pal": 2, "tint": "#ecd0a0", "shutter": "brown", "door": "bronze", "walls": "ashlar",
                "door_u": (3.4, 4.6), "door_h": 1.8, "double": True, "corners": "stone", "sign": "library", "decal": "frieze",
                "fwins": [(1, 0.55, 1.15, 0.72, 1.5, False, True, True, True, True), (1, 6.85, 7.45, 0.72, 1.5, False, True, True, True, True)],
                "niches": [(0, 1.15), (0, 6.85)], "pilasters": [0.3, 2.05, 5.95, 7.7]},
    "academy": {"w": 9.6, "d": 4.0, "floors": 2, "roof": "x", "pal": 1, "tint": "#f4ead6", "shutter": "teal", "door": "bronze", "walls": "marble",
                "door_u": (4.2, 5.4), "door_h": 1.85, "double": True, "corners": "stone", "sign": "academy", "decal": "frieze",
                "fwins": [(0, 0.6, 1.2, 0.7, 1.55, False, False, True, True), (0, 8.4, 9.0, 0.7, 1.55, False, False, True, True),
                          (1, 0.6, 1.2, 0.72, 1.5, False, True, True, True, True), (1, 8.4, 9.0, 0.72, 1.5, False, True, True, True, True)],
                "niches": [(0, 2.0), (0, 7.6)], "pilasters": [0.3, 1.45, 8.15, 9.3]},
    "warehouse": {"w": 6.4, "d": 3.8, "floors": 2, "roof": "x", "pal": 0, "tint": "#c98466", "shutter": "brown", "door": "dark", "walls": "brick",
                  "door_u": (2.45, 3.95), "door_h": 1.72, "double": True, "corners": "stone", "sign": "warehouse",
                  "fwins": [(0, 0.6, 1.05, 1.05, 1.45, False, False, False, True), (0, 5.35, 5.8, 1.05, 1.45, False, False, False, True),
                            (1, 0.6, 1.2, 0.8, 1.4, True, False, False, False), (1, 5.2, 5.8, 0.8, 1.4, True, False, False, False)],
                  "loading": (2.85, 3.55)},
}


def civic_front(body, walls, inner, emb, Pf, U, N, x0, x1, z0, z1):
    """фасад и двор общественного здания; возвращает (fz0, fz1, fx0, fx1) — следа на земле"""
    R = RW(U, N)
    fz0, fz1, fx0, fx1 = z0, z1, x0, x1
    door_u = DS["door_u"]
    opens = [(door_u[0] - 0.1, door_u[1] + 0.1, 0.0, PL + DS.get("door_h", 1.6))]
    if DS.get("socle"):
        socle(body, Pf, U, N, 0.0, W, DS["socle"], opens)
    if V in ("school", "library", "academy", "prefect", "balnea", "baths"):     # зубчатый карниз под свесом крыши
        dentils(body, Pf, U, N, 0.0, W, HT - 0.22)
    for uc in DS.get("pilasters", []):
        pilaster(body, Pf, U, N, "front", uc, PL, HT - 0.3)
    for (f, uc, vo, w, h, key) in DS.get("frescos", []):
        framed_fresco(body, Pf, U, N, "front", uc, PL + f * FLH + vo, w, h, key)
    for (f, uc) in DS.get("niches", []):
        niche(body, Pf, U, N, "front", uc, PL + f * FLH + 0.12, 0.6, 1.4 if f == 0 else 1.25)
    if V == "school":
        dep = 2.3
        ph = PL + 1.78
        pergola(body, Pf, U, N, 0.18, W - 0.18, ph, dep, 0.38)
        for uu in (0.18, W - 0.18):
            column3(body, Pw(Pf, uu, 0.0, dep), ph + 0.02, 0.075, seg=12)
        body.box(((x0 + x1) / 2, 0.03, z1 + dep / 2), (W - 0.1, 0.06, dep), J(P["stone"], 0.04), skip=("bot",), mat=M_STONE)
        for (xx, zz) in ((-1.15, 0.62), (1.15, 0.62), (-1.15, 1.22), (1.15, 1.22)):
            PROPS.append(["SM_Prop_Seat_Bench_01", xx, 0.06, round(z1 + zz, 3), 0.0, 1.0])
            for k in range(2):
                wax_tablet(body, (xx - 0.25 + k * 0.5, 0.06 + 0.354, z1 + zz - 0.02), Matrix.Identity(3), rng.uniform(-0.3, 0.3))
        PROPS.append(["SM_Prop_Seat_Chair_03", 0.62, 0.06, round(z1 + 1.95, 3), math.pi, 0.75])
        ACTORS.append([0.0, 0.06, round(z1 + 1.85, 3), math.pi, "Idle", "rich"])
        lectern(body, (-0.55, 0.06, z1 + 1.95), Matrix.Rotation(math.pi, 3, "Y"))
        capsa(body, (-1.0, 0.06, z1 + 2.0))
        abacus(body, (1.15, 0.06, z1 + 1.95), Matrix.Rotation(math.pi + 0.3, 3, "Y"))
        sundial(body, (x0 + 0.5, 0.06, z1 + 1.7))
        plant_pot(body, (x1 - 0.45, 0.06, z1 + 1.8), 0.32)
        plant_pot(body, (x1 - 0.45, 0.06, z1 + 0.5), 0.26)
        # светильники — на цепях с поперечных балок перголы (низ балки — ph + 0,085)
        for uu in pergola_hooks(0.18, W - 0.18, (1.2, W - 1.2)):
            hanging_lamp(body, emb, Pw(Pf, uu, ph + 0.085, dep * 0.6))
            LIGHTS.append({"lamp": [round(x0 + uu, 3), round(ph - 0.15, 3), round(z1 + dep * 0.6, 3)], "kind": "hang"})
        # гирлянды по передней балке, вывеска посередине
        for (a, b) in ((0.3, 1.75), (1.75, W / 2 - 0.36), (W / 2 + 0.36, W - 1.75), (W - 1.75, W - 0.3)):
            swag(body, Pw(Pf, a, ph + 0.0, dep + 0.06), Pw(Pf, b, ph + 0.0, dep + 0.06), 0.14, 0.1, "#3f7f4a", tuple(N))
        yb = PL + 1.5
        for s in (-1, 1):
            rod(body, Pw(Pf, W / 2 + s * 0.22, ph + 0.04, dep), Pw(Pf, W / 2 + s * 0.22, yb + 0.18, dep), 0.008, col(IRON))
        body.box(Pw(Pf, W / 2, yb, dep), (0.56, 0.38, 0.025), J("#6b4428", 0.05), R, mat=M_WOOD)
        sign_board(body, Pf, U, N, W / 2, yb, 0.5, 0.333, dep + 0.014, "school")
        # знамёна на верхнем этаже по сторонам фрески
        for uu in (1.85, W - 1.85):
            banner(body, Pf, U, N, "front", uu, HT - 0.32, 0.42, 0.95, 0.06, 3)
        laurel(body, Pf(door_u[0] - 0.05, PL + 1.82, 0.08), Pf(door_u[1] + 0.05, PL + 1.82, 0.08), 0.12, tuple(N))
        for s in (-1, 1):
            tree_prop("SM_Env_Tree_Thin_0%d" % (1 + (s > 0)), s * (W / 2 + 0.38), z1 - 0.35, 0.42)
        block("front", Pf, U, 0.0, W, 0.0, PL + 2.0)
        fz1 = z1 + dep + 0.1
        fx0, fx1 = x0 - 0.6, x1 + 0.6
        DOOR_PT[2] = z1 + dep + 0.4
    elif V == "library":
        dep = 2.0
        yt = temple_front(body, x0 + 2.25, x1 - 2.25, z1, dep, 0.36, 2.05, 4, key="tymp_lib", ins="ins_lib", r=0.1, swags="#9a2f28")
        armarium(body, Pf, U, N, W / 2 - 0.62, -0.95, 0.9, 1.5)
        armarium(body, Pf, U, N, W / 2 + 0.62, -0.95, 0.9, 1.5)
        laurel(body, Pf(door_u[0] - 0.05, PL + 1.98, 0.1), Pf(door_u[1] + 0.05, PL + 1.98, 0.1), 0.14, tuple(N))
        for uu in (2.75, W - 2.75):            # знамёна с совой Минервы
            banner(body, Pf, U, N, "front", uu, HT - 0.36, 0.44, 1.0, 0.06, 2)
        clipeus(body, Pf, N, W / 2, HT - 0.6, 0.2)
        for s in (-1, 1):
            p = (s * (W / 2 - 1.05), z1 + 1.05)
            PROPS.append(["SM_Prop_Pillar_Base_02", round(p[0], 3), 0.0, round(p[1], 3), 0.0, 0.8])
            PROPS.append(["SM_Prop_Statue_0%d" % (1 + rng.randrange(7)), round(p[0], 3), round(1.2 * 0.72, 3), round(p[1], 3), 0.0, 0.85])
            marble_bench(body, (s * (W / 2 - 1.1), 0.0, z1 + 0.35), Matrix.Identity(3), 1.1)
            capsa(body, (s * (W / 2 - 0.45), 0.0, z1 + 0.4))
            scroll(body, (s * (W / 2 - 1.3), 0.37, z1 + 0.35), Matrix.Rotation(0.4 * s, 3, "Y"), 0.2)
            tree_prop("SM_Env_Tree_Thin_0%d" % (1 + (s > 0)), s * (W / 2 + 0.45), z1 + 0.5, 0.45)
            tripod(body, emb, (s * 2.4, 0.0, z1 + dep + 0.35), 0.95)
            plant_pot(body, (s * (W / 2 - 2.05), 0.36, z1 + dep - 0.25), 0.34)
        block("front", Pf, U, 2.0, W - 2.0, 0.0, HT)
        fz1 = z1 + dep + 0.6
        fx0, fx1 = x0 - 0.7, x1 + 0.7
        DOOR_PT[2] = z1 + dep + 0.8
    elif V == "academy":
        dep = 1.7
        yt = temple_front(body, x0 + 2.4, x1 - 2.4, z1, dep, 0.36, FLH * 2 - 0.25, 4, key="tymp_acad", ins="ins_acad", r=0.15, pitch=20.0, swags="#5a2a6a")
        armarium(body, Pf, U, N, W / 2 - 0.65, -0.95, 0.9, 1.5)
        armarium(body, Pf, U, N, W / 2 + 0.65, -0.95, 0.9, 1.5)
        laurel(body, Pf(door_u[0] - 0.05, PL + 2.03, 0.1), Pf(door_u[1] + 0.05, PL + 2.03, 0.1), 0.14, tuple(N))
        for uu in (2.05, W - 2.05):            # знамёна с орлом
            banner(body, Pf, U, N, "front", uu, HT - 0.36, 0.46, 1.05, 0.06, 1)
        # двор: мраморные дорожки крестом, колоннады с росписью, толос со статуей, мозаика философов
        zc0, zc1 = z1 + dep + 0.1, z1 + dep + 4.6
        body.box(((x0 + x1) / 2, 0.02, (zc0 + zc1) / 2), (W - 0.1, 0.04, zc1 - zc0), J("#9cb35c", 0.05), skip=("bot",))
        body.box((0.0, 0.05, (zc0 + zc1) / 2), (1.2, 0.04, zc1 - zc0), J(MARBLE, 0.03, 0.0, 0.0), skip=("bot",), mat=M_MARBLE)
        tz = (zc0 + zc1) / 2 + 0.2
        body.box((0.0, 0.05, tz), (W - 3.2, 0.04, 1.2), J(MARBLE, 0.03, 0.0, 0.0), skip=("bot",), mat=M_MARBLE)
        for s in (-1, 1):
            stoa(body, s * (W / 2 - 0.05), s, zc0, zc1, 1.3, 2.0, fresco="garden" if s < 0 else "birds")
        tholos(body, 0.0, tz, 0.75, 1.65, 0.06)
        statue_prop(0.0, tz, math.pi, 0.62, 0.22, plinth=True)
        fresco_floor(body, 0.0, 0.072, zc0 + 0.75, 2.1, 1.4, "mosaic")
        for s in (-1, 1):
            marble_bench(body, (s * 1.75, 0.05, tz), Matrix.Rotation(math.pi / 2 * s, 3, "Y"), 1.2)
            tree_prop("SM_Env_Tree_03", s * 2.2, zc1 - 0.9, 0.34)
            # клумбы в каменных бортиках
            bx, bz = s * 1.75, zc0 + 0.6
            for (dx, dz, ww, dd) in ((0, -0.32, 1.4, 0.06), (0, 0.32, 1.4, 0.06), (-0.7, 0, 0.06, 0.7), (0.7, 0, 0.06, 0.7)):
                body.box((bx + dx, 0.08, bz + dz), (ww, 0.12, dd), J(P["stone"], 0.05), mat=M_STONE)
            for k in range(9):
                leaf_blob(body, (bx + rng.uniform(-0.6, 0.6), 0.14, bz + rng.uniform(-0.25, 0.25)), 0.11, J(rng.choice(["#4f7d33", "#5f8f3a"]), 0.1))
                leaf_blob(body, (bx + rng.uniform(-0.6, 0.6), 0.24, bz + rng.uniform(-0.25, 0.25)), 0.045, J(rng.choice(["#e98bb0", "#f0c24b", "#f4f1e8", "#d9534f"]), 0.08))
            tripod(body, emb, (s * 2.75, 0.0, z1 + dep + 0.35), 1.0)
            tripod(body, emb, (s * 0.62, 0.0, zc1 - 0.45), 0.9)
        # балюстрада по фронту, ворота: колонны, фронтончик, лавровая гирлянда, табличка
        for s in (-1, 1):
            balustrade(body, s * 0.95, s * (W / 2 - 0.05), zc1, 0.85)
            column3(body, (s * 0.85, 0.0, zc1), 2.0, 0.08, seg=12, face=(1.0, 0.0, 0.0))
        body.box((0.0, 2.08, zc1), (2.0, 0.16, 0.28), J(MARBLE, 0.02, 0.0, 0.0), mat=M_MARBLE)
        for s in (-1, 1):
            rod(body, (0.0, 2.6, zc1 + 0.1), (s * 1.0, 2.16, zc1 + 0.1), 0.1, J(MARBLE, 0.03, 0.0, 0.0), mat=M_MARBLE)
        body.face([body.v((-0.95, 2.16, zc1 + 0.1)), body.v((0.95, 2.16, zc1 + 0.1)), body.v((0.0, 2.56, zc1 + 0.1))], J(MARBLE, 0.02, 0.0, 0.0), ("dir", (0, 0, 1)), mat=M_MARBLE)
        acroterion(body, (0.0, 2.6, zc1 + 0.1), 1.0)
        laurel(body, (-0.72, 1.95, zc1 + 0.16), (0.72, 1.95, zc1 + 0.16), 0.16, (0, 0, 1))
        sign_board(body, lambda u, v, n: Vector((u, v, zc1 + 0.141 + n)), Vector((1, 0, 0)), Vector((0, 0, 1)), 0.0, 2.36, 0.24, 0.16, 0.0, "academy")
        block("front", Pf, U, 2.0, W - 2.0, 0.0, HT)
        fz1 = zc1 + 0.2
        DOOR_PT[2] = zc1 + 0.6
    elif V == "warehouse":
        lu0, lu1 = DS["loading"]
        y1 = PL + FLH
        mov("door", door_key(DS["door"], (lu1 - lu0 - 0.06) / 2, 1.45, 1), Pf(lu0 + 0.03, y1 + 0.12, -0.1), U, N, math.radians(80), 1)
        mov("door", door_key(DS["door"], (lu1 - lu0 - 0.06) / 2, 1.45, -1), Pf(lu1 - 0.03, y1 + 0.12, -0.1), U, N, math.radians(80), -1)
        body.box(Pw(Pf, (lu0 + lu1) / 2, y1 + 0.06, 0.12), (lu1 - lu0 + 0.2, 0.08, 0.26), J(P["wood"], 0.05), R, mat=M_WOOD)
        for uu in (lu0 - 0.07, lu1 + 0.07):     # каменное обрамление грузовой двери
            body.box(Pw(Pf, uu, y1 + 0.85, 0.03), (0.12, 1.5, 0.06), J(P["stone"], 0.05), R, mat=M_STONE)
        body.box(Pw(Pf, (lu0 + lu1) / 2, y1 + 1.66, 0.04), (lu1 - lu0 + 0.36, 0.14, 0.08), J(P["stone"], 0.05), R, mat=M_STONE)
        hoist(body, Pf, U, N, (lu0 + lu1) / 2, HT - 0.2)
        body.box(Pw(Pf, W / 2, PL + 1.97, 0.01), (0.66, 0.46, 0.02), J("#6b4428", 0.05), R, mat=M_WOOD)
        sign_board(body, Pf, U, N, W / 2, PL + 1.95 + 0.02, 0.6, 0.4, 0.024, "warehouse")
        for uu in (2.15, 4.25):                # государственный склад: знамёна SPQR
            banner(body, Pf, U, N, "front", uu, HT - 0.4, 0.38, 0.85, 0.06, 0)
        for uu in (0.825, W - 0.825):
            canopy(body, Pf, U, N, uu, PL + 1.72, 0.85, 0.42)
        for k in range(4):
            sack(body, Pw(Pf, 0.28 + k * 0.27, 0.0, 0.3 + (k % 2) * 0.08), 0.13, 0.32, open_=False)
        for k in range(3):
            sack(body, Pw(Pf, 0.42 + k * 0.27, 0.27, 0.32), 0.12, 0.3, open_=False)
        sack(body, Pw(Pf, 0.68, 0.52, 0.32), 0.12, 0.3, open_=True)
        crate(body, Pw(Pf, 1.65, 0.0, 0.3), R, 0.42, 0.36, 0.36)
        crate(body, Pw(Pf, 1.65, 0.36, 0.3), R, 0.38, 0.3, 0.32)
        scales(body, Pw(Pf, 1.65, 0.66, 0.3), R, 0.8)
        rope_coil(body, Pw(Pf, 2.2, 0.0, 0.35))
        for k in range(4):
            amphora(body, Pw(Pf, 4.45 + k * 0.24, 0.0, 0.25 + (k % 2) * 0.12), 0.55, J(rng.choice(CLAY[:3]), 0.06))
        for k, (du, dv) in enumerate(((0.0, 0.0), (0.36, 0.0), (0.18, 0.5))):
            barrel(body, Pw(Pf, 5.55 + du, dv, 0.32), 0.48, 0.16)
        cart(body, (x1 + 0.75, 0.0, z1 - 1.0), Matrix.Rotation(0.05, 3, "Y"))
        rod(body, (x0 - 0.2, 0.0, 0.3), (x0 - 0.02, 2.4, 0.2), 0.05, J(P["wood"], 0.05), mat=M_WOOD)
        rod(body, (x0 - 0.2, 0.0, -0.2), (x0 - 0.02, 2.4, -0.3), 0.05, J(P["wood"], 0.05), mat=M_WOOD)
        for k in range(8):
            yy = 0.25 + k * 0.28
            t = yy / 2.4
            body.box((x0 - 0.2 + 0.18 * t, yy, 0.05 - 0.1 * t), (0.04, 0.04, 0.52), J(P["wood2"], 0.05), mat=M_WOOD)
        fx1 = x1 + 1.35
        fx0 = x0 - 0.3
        fz1 = z1 + 0.5
        DOOR_PT[2] = z1 + 0.8
    elif V in CIVIC_FRONTS:
        fz0, fz1, fx0, fx1 = CIVIC_FRONTS[V](body, emb, Pf, U, N, R, x0, x1, z0, z1)
    return fz0, fz1, fx0, fx1


# ---------- общественные здания, прогон 3: вигилы, префект, бани, термы, скульптор, приют; травник и кошачья лавка ----------
PETS_K = []          # животные и вещицы при здании (как CatExtra.PETS): [кто, [x,y,z] м, поворот, движение, масштаб, облик, вещица]


def pet(kind, p, yaw, motion, s=1.0, item=None):
    e = [kind, [round(p[0], 3), round(p[1], 3), round(p[2], 3)], round(yaw, 3), motion, s, -1]
    if item is not None:
        e.append(item)
    PETS_K.append(e)


def flat_roof(body, x0, x1, z0, z1, y, domes=()):
    """плоская крыша: настил из плитки, парапет с мраморным поручнем, купола (r, x, z) с окошком-фонарём наверху"""
    body.box(((x0 + x1) / 2, y + 0.06, (z0 + z1) / 2), (x1 - x0 + 0.08, 0.12, z1 - z0 + 0.08), J("#b98a6a", 0.04), mat=M_STONE)
    m = J(MARBLE, 0.02, 0.0, 0.0)
    for (xa, xb, za, zb) in ((x0, x1, z1, z1), (x0, x1, z0, z0), (x0, x0, z0, z1), (x1, x1, z0, z1)):
        L = max(abs(xb - xa), abs(zb - za))
        along_x = abs(xb - xa) > 0.01
        cx, cz = (xa + xb) / 2, (za + zb) / 2
        size = (L + 0.12, 0.36, 0.14) if along_x else (0.14, 0.36, L + 0.12)
        body.box((cx, y + 0.3, cz), size, J(P["trim"], 0.03))
        body.box((cx, y + 0.5, cz), (size[0] + 0.04, 0.05, size[2] + 0.04), m, mat=M_MARBLE)
    top = y + 0.55
    for (r, dx, dz) in domes:
        body.lathe((dx, y + 0.12, dz), [(r + 0.12, 0.0), (r + 0.12, 0.22), (r + 0.06, 0.26)], 16, J(P["trim"], 0.03))
        prof = [(r, 0.0), (r * 0.94, r * 0.35), (r * 0.76, r * 0.66), (r * 0.45, r * 0.88), (r * 0.16, r * 0.98)]
        body.lathe((dx, y + 0.38, dz), prof, 18, J("#d8cbb8", 0.03), cols=[J("#d8cbb8", 0.03), J("#cfc1ac", 0.03), J("#c8b9a2", 0.03), J("#c0b09a", 0.03)], mat=M_STONE)
        for k in range(18):                    # рёбра купола
            a = 2 * math.pi * k / 18
            for j in range(len(prof) - 1):
                p0 = Vector((dx + math.cos(a) * prof[j][0], y + 0.38 + prof[j][1], dz + math.sin(a) * prof[j][0]))
                p1 = Vector((dx + math.cos(a) * prof[j + 1][0], y + 0.38 + prof[j + 1][1], dz + math.sin(a) * prof[j + 1][0]))
                c = Vector((dx, y + 0.38, dz))
                if k % 3 == 0:
                    rod(body, p0 + (p0 - c).normalized() * 0.012, p1 + (p1 - c).normalized() * 0.012, 0.04, m, mat=M_MARBLE)
        lt = y + 0.38 + r * 0.98
        body.lathe((dx, lt - 0.02, dz), [(r * 0.18, 0.0), (r * 0.18, 0.12), (r * 0.22, 0.14), (r * 0.08, 0.26), (0.0, 0.32)], 10, J(MARBLE, 0.03, 0.0, 0.0), mat=M_MARBLE)
        top = max(top, lt + 0.3)
    return top


def pool(body, x0, x1, z0, z1, step_side=1):
    """бассейн: мраморный бортик, ступени в воду с одного края, вода (#water — в ней Spectacle «купает» жителей)"""
    m = J(MARBLE, 0.02, 0.0, 0.0)
    rim = 0.16
    for (cx, cz, sx, sz) in (((x0 + x1) / 2, z0, x1 - x0 + rim * 2, rim), ((x0 + x1) / 2, z1, x1 - x0 + rim * 2, rim),
                             (x0, (z0 + z1) / 2, rim, z1 - z0), (x1, (z0 + z1) / 2, rim, z1 - z0)):
        body.box((cx, 0.12, cz), (sx, 0.24, sz), m, cols={"top": J(MARBLE, 0.05, 0.0, 0.0)}, mat=M_MARBLE)
    body.box(((x0 + x1) / 2, 0.01, (z0 + z1) / 2), (x1 - x0, 0.02, z1 - z0), J("#4f8fa8", 0.04))      # голубая мозаика дна
    zs = z1 - rim / 2 if step_side > 0 else z0 + rim / 2
    for k in range(2):
        body.box(((x0 + x1) / 2, 0.06 + k * 0.06, zs - step_side * (0.18 + k * 0.16)), (min(1.0, x1 - x0 - 0.3), 0.06, 0.16), m, mat=M_MARBLE)
    wx, wz, wy = (x0 + x1) / 2, (z0 + z1) / 2, 0.075
    PROPS.append(["#water", round(wx, 3), round(wy, 3), round(wz, 3), 0.0, [round((x1 - x0 - 0.02) / 0.72, 3), round(0.15 / 0.72, 3), round((z1 - z0 - 0.02) / 0.72, 3)]])


def lion_spout(body, P_, U, N, uc, v, water_to):
    """львиная маска на стене: мраморная плита, бронзовая голова с гривой, из пасти — струя в бассейн"""
    R = RW(U, N)
    body.box(Pw(P_, uc, v, 0.02), (0.38, 0.42, 0.04), J(MARBLE, 0.03, 0.0, 0.0), R, mat=M_MARBLE)
    torus(body, tuple(P_(uc, v, 0.05)), _ymat(N), 0.11, 0.035, col("#9a7a3a"), seg=12, seg2=4)
    ball(body, tuple(P_(uc, v, 0.07)), 0.09, col(BRONZE), seg=8, rings=4, sq=(1.0, 1.0, 0.7), R=_ymat(N))
    spindle(body, P_(uc, v - 0.04, 0.12), P_(uc, v - 0.05, 0.2), [(0.02, 0.0), (0.016, 1.0)], 6, col("#8a6a2a"))
    a = Vector(P_(uc, v - 0.05, 0.2))
    b = Vector(water_to)
    mid = (a + b) / 2 + Vector((0, 0.1, 0)) + (b - a).normalized() * 0.0
    rod(body, a, mid, 0.03, col("#bfe4f0"))
    rod(body, mid, b, 0.03, col("#bfe4f0"))


def fasces(body, at, R):
    """фасции: пучок прутьев, перехваченный красными ремнями, с топором наверху"""
    x, y, z = at
    for k in range(7):
        a = 2 * math.pi * k / 7
        o = R @ Vector((math.cos(a) * 0.04, 0, math.sin(a) * 0.04))
        rod(body, (x + o.x, y, z + o.z), (x + o.x, y + 1.05, z + o.z), 0.028, J("#8a5a32", 0.06), mat=M_WOOD)
    for t in (0.2, 0.5, 0.8):
        torus(body, (x, y + 1.05 * t, z), Matrix.Identity(3), 0.07, 0.012, col("#a8302a"), seg=10, seg2=3)
    body.box(LP(at, R, 0.1, 1.0, 0.0), (0.14, 0.12, 0.012), col("#aab1b8"), R)


def wattle(body, xa, za, xb, zb, h=0.85):
    """плетень: колья и переплетённые прутья"""
    a, b = Vector((xa, 0, za)), Vector((xb, 0, zb))
    L = (b - a).length
    d = (b - a).normalized()
    n = max(2, int(L / 0.35) + 1)
    side = Vector((-d.z, 0, d.x))
    for k in range(n):
        p = a + d * (L * k / (n - 1))
        rod(body, p, p + Vector((0, h + 0.08, 0)), 0.04, J("#7a5a3a", 0.08), mat=M_WOOD)
    for j in range(5):
        y = 0.15 + j * (h - 0.15) / 4
        pts = []
        for k in range(n * 2 - 1):
            t = k / (n * 2 - 2)
            pts.append(a + d * (L * t) + Vector((0, y, 0)) + side * (0.025 * (1 if (k + j) % 2 else -1)))
        for k in range(len(pts) - 1):
            rod(body, pts[k], pts[k + 1], 0.022, J("#a07a50", 0.08), mat=M_WOOD)


def watchtower(body, emb, cx, cz, ph=2.9):
    """дозорная вышка вигилов: четыре столба, помост с перилами, лестница, черепичная кровля, жаровня (дым, свет)"""
    for (dx, dz) in ((-0.55, -0.55), (0.55, -0.55), (-0.55, 0.55), (0.55, 0.55)):
        rod(body, (cx + dx, 0.0, cz + dz), (cx + dx * 0.92, ph + 1.3, cz + dz * 0.92), 0.1, J(P["wood"], 0.05), mat=M_WOOD)
    for (dx, dz) in ((-0.55, 0.0), (0.55, 0.0)):
        rod(body, (cx + dx, 0.3, cz - 0.55), (cx + dx, ph - 0.2, cz + 0.55), 0.05, J(P["wood2"], 0.05), mat=M_WOOD)
    for k in range(9):                         # помост
        body.box((cx, ph, cz - 0.6 + k * 0.15), (1.3, 0.05, 0.13), J(P["wood"], 0.08), mat=M_WOOD)
    for s in (-1, 1):                          # перила
        body.box((cx, ph + 0.55, cz + s * 0.62), (1.3, 0.05, 0.05), J(P["wood2"], 0.05), mat=M_WOOD)
        body.box((cx + s * 0.62, ph + 0.55, cz), (0.05, 0.05, 1.3), J(P["wood2"], 0.05), mat=M_WOOD)
        for k in range(5):
            body.box((cx - 0.5 + k * 0.25, ph + 0.28, cz + s * 0.62), (0.03, 0.5, 0.03), J(P["wood2"], 0.05), mat=M_WOOD)
    for k in range(int(ph / 0.3)):             # лестница сбоку
        y = 0.25 + k * 0.3
        body.box((cx - 0.75, y, cz + 0.2), (0.04, 0.04, 0.45), J(P["wood2"], 0.05), mat=M_WOOD)
    for s in (-1, 1):
        rod(body, (cx - 0.75, 0.0, cz + 0.2 + s * 0.22), (cx - 0.72, ph + 0.6, cz + 0.2 + s * 0.22), 0.04, J(P["wood"], 0.05), mat=M_WOOD)
    roof(body, True, cx - 0.75, cx + 0.75, cz - 0.75, cz + 0.75, ph + 1.3, pitch_deg=30.0, oe=0.12, og=0.1, antefix=False)
    body.lathe((cx, ph + 0.03, cz), [(0.06, 0.0), (0.18, 0.12), (0.2, 0.18)], 12, col(IRON))
    for k in range(6):
        leaf_blob(emb, (cx + rng.uniform(-0.1, 0.1), ph + 0.2, cz + rng.uniform(-0.1, 0.1)), 0.06, col(rng.choice(["#ff7a1a", "#ffb03a", "#e0501a"])))
    SMOKE.append([round(cx, 3), round(ph + 0.5, 3), round(cz, 3)])
    LIGHTS.append({"lamp": [round(cx, 3), round(ph + 0.4, 3), round(cz, 3)], "kind": "hang"})


def axe(body, at, R, ang=0.0):
    Rr = R @ Matrix.Rotation(ang, 3, "Z")
    body.box(LP(at, Rr, 0, 0.35, 0), (0.035, 0.7, 0.035), J("#8a6038", 0.05), Rr, mat=M_WOOD)
    body.box(LP(at, Rr, 0.06, 0.65, 0), (0.12, 0.1, 0.012), col("#aab1b8"), Rr)


def ladder2(body, P_, U, N, u, h, lean=0.22):
    """приставная лестница у стены"""
    for s in (-1, 1):
        rod(body, Pw(P_, u + s * 0.18, 0.0, lean + 0.05), Pw(P_, u + s * 0.18, h, 0.06), 0.045, J(P["wood"], 0.05), mat=M_WOOD)
    for k in range(int(h / 0.3)):
        t = (k + 0.5) / int(h / 0.3)
        body.box(Pw(P_, u, h * t, lean + 0.05 - (lean - 0.01) * t), (0.36, 0.035, 0.035), J(P["wood2"], 0.05), RW(U, N), mat=M_WOOD)


def unfinished_statue(x, z, yaw, s, k=1):
    PROPS.append(["SM_Prop_Statue_Unfinished_0%d" % k, round(x, 3), 0.0, round(z, 3), yaw, s])


def scaffold(body, cx, cz, w, d, h):
    for (dx, dz) in ((-w / 2, -d / 2), (w / 2, -d / 2), (-w / 2, d / 2), (w / 2, d / 2)):
        rod(body, (cx + dx, 0.0, cz + dz), (cx + dx, h, cz + dz), 0.05, J(P["wood"], 0.06), mat=M_WOOD)
    for y in (h * 0.5, h - 0.05):
        for s in (-1, 1):
            body.box((cx, y, cz + s * d / 2), (w + 0.1, 0.04, 0.04), J(P["wood2"], 0.05), mat=M_WOOD)
        for k in range(4):
            body.box((cx - w / 2 + (k + 0.5) * w / 4, y + 0.03, cz), (w / 4 - 0.02, 0.03, d + 0.1), J(P["wood"], 0.08), mat=M_WOOD)
    rod(body, (cx - w / 2, 0.1, cz + d / 2), (cx + w / 2, h * 0.5, cz + d / 2), 0.035, J(P["wood2"], 0.05), mat=M_WOOD)


def marble_block(body, at, size, ang=0.0):
    body.box((at[0], at[1] + size[1] / 2, at[2]), size, J(MARBLE, 0.04, 0.0, 0.0), Matrix.Rotation(ang, 3, "Y"), mat=M_MARBLE)


def crane(body, at, h=2.6):
    """деревянный подъёмный «журавль»: тренога, блок, верёвка с крюком над глыбой"""
    x, y, z = at
    top = Vector((x, y + h, z))
    for k in range(3):
        a = 2 * math.pi * k / 3 + 0.4
        rod(body, (x + math.cos(a) * 0.7, y, z + math.sin(a) * 0.7), top, 0.07, J(P["wood"], 0.05), mat=M_WOOD)
    torus(body, tuple(top + Vector((0, -0.15, 0))), Matrix.Rotation(math.pi / 2, 3, "X"), 0.08, 0.025, J("#6b4428", 0.05), seg=10, seg2=4)
    rod(body, top + Vector((0, -0.2, 0)), top + Vector((0, -1.4, 0)), 0.015, col(ROPE))
    body.box(tuple(top + Vector((0, -1.45, 0))), (0.06, 0.1, 0.02), col(IRON))


# --- товар травника и кошачьей лавки ---
def g_herbs(b, e, S):
    P_, R, N, y, u0, u1 = S["P"], S["R"], S["N"], S["y"], S["u0"], S["u1"]
    fl = ["#e98bb0", "#9a7ad0", "#f0d24a", "#f4f1e8", None, "#d9534f"]
    for k, h in enumerate(hooks(S, 7)):
        herb_bundle(b, h, ["#5f7f3a", "#7a8f5a", "#6a7a4a", "#8a9a5a"][k % 4], fl=fl[k % len(fl)])
    mortar(b, Pw(P_, u0 + 0.14, y, 0.06), R, 0.07, "#7a9a4a")
    for k, uu in enumerate(row(u0 + 0.3, u1 - 0.45, 4)):
        jar(b, Pw(P_, uu, y, 0.08), 0.13, J(["#c27a4a", "#7d8f99", "#e8e2d6", "#4f7a6a"][k], 0.05), lid=["#7a5232", "#5a3a22", "#9a2f28", "#3f6fa8"][k])
    basket(b, Pw(P_, u1 - 0.14, y, 0.04), 0.1, 0.08)
    for k in range(7):
        ball(b, Pw(P_, u1 - 0.14 + rng.uniform(-0.05, 0.05), y + 0.08, 0.04 + rng.uniform(-0.05, 0.05)), 0.02, J(rng.choice(["#9a7ad0", "#f0d24a", "#e98bb0"]), 0.06), seg=6, rings=3)
    scales(b, Pw(P_, u1 - 0.36, y, -0.1), R, 0.6)
    shelf_unit(b, S, lambda v, a, c, n: [jar(b, Pw(P_, uu, v, n), 0.12 + 0.03 * (i % 2), J(["#c27a4a", "#7d8f99", "#e8e2d6", "#4f7a6a"][i % 4], 0.05)) for i, uu in enumerate(row(a, c, 7))])
    ou0, ou1, on = S["out"]
    # грядка мяты в деревянном ящике и горшки с травами
    b.box(Pw(P_, ou0 + 0.45, 0.14, on - 0.05), (0.8, 0.28, 0.32), J(P["wood"], 0.06), R, mat=M_WOOD)
    b.box(Pw(P_, ou0 + 0.45, 0.27, on - 0.05), (0.74, 0.02, 0.26), col("#4a3524"), R)
    for k in range(12):
        leaf_blob(b, Pw(P_, ou0 + 0.12 + k * 0.06, 0.32 + rng.uniform(0, 0.05), on - 0.05 + rng.uniform(-0.08, 0.08)), 0.05, J(rng.choice(["#4f8f3a", "#5f9a4a", "#6a9a3a"]), 0.1))
    plant_pot(b, Pw(P_, ou1 - 0.15, 0.0, on - 0.05), 0.3)


def g_cats(b, e, S):
    """кошачья лавка: на прилавке подставки со шляпками и кошка, на полках корзинки и подушки, у двери — корзинка-
    лежанка и миски; на перекладине — клубки и бубенчики; клубок на нитке — под навесом (вещицы и кошки — PETS_K)"""
    P_, R, N, y, u0, u1 = S["P"], S["R"], S["N"], S["y"], S["u0"], S["u1"]
    for k, h in enumerate(hooks(S, 6)):
        top = it_hook(b, h, 0.04 + 0.03 * (k % 2))
        if k % 2 == 0:
            ball(b, tuple(top + Vector((0, -0.05, 0))), 0.045, J(["#d9506e", "#3f6fa8", "#e1b84a"][k // 2 % 3], 0.05), seg=7, rings=4)
        else:
            torus(b, tuple(top + Vector((0, -0.07, 0))), _ymat(N), 0.05, 0.01, col("#a8302a"), seg=10, seg2=3)
            ball(b, tuple(top + Vector((0, -0.12, 0.02))), 0.018, col(GOLD), seg=6, rings=3)
    # подставки для вещиц (вещицы ставит игра) и место кошки на прилавке
    for k, uu in enumerate((u0 + 0.35, u1 - 0.25)):
        b.lathe(Pw(P_, uu, y, 0.06), [(0.05, 0.0), (0.03, 0.03), (0.025, 0.1), (0.06, 0.12)], 10, J(MARBLE, 0.03, 0.0, 0.0), close_top=True, mat=M_MARBLE)
        p = Pw(P_, uu, y + 0.12, 0.06)
        pet("acc", p, 0.4 - 0.7 * k, ["pileus", "wreath"][k], [1.6, 1.5][k])
    b.box(Pw(P_, (u0 + u1) / 2 + 0.05, y + 0.012, 0.04), (0.3, 0.024, 0.24), J("#c87aa0", 0.04), R, mat=M_CLOTH)
    pet("cat", Pw(P_, (u0 + u1) / 2 + 0.05, y + 0.025, 0.04), 0.35, "sit", 1.0, "petasos")
    shelf_unit(b, S, lambda v, a, c, n: [(basket(b, Pw(P_, uu, v, n), 0.08, 0.07) if i % 2 == 0 else
                                          ball(b, Pw(P_, uu, v + 0.04, n), 0.07, J(["#e98bb0", "#8fb0d9", "#f0d24a"][i % 3], 0.05), seg=8, rings=4, sq=(1.0, 0.5, 1.0)))
                                         for i, uu in enumerate(row(a, c, 5))])
    su0, su1, sn, lv = S["shelf"]
    pet("cat", Pw(P_, (su0 + su1) / 2, lv[-1] + 0.005, sn), 0.2, "sleep", 0.9, "bandana")
    pet("acc", Pw(P_, su0 + 0.25, lv[1] + 0.01, sn), 0.3, "cape", 1.3)
    pet("acc", Pw(P_, su1 - 0.25, lv[2] + 0.01, sn), 0.0, "flower", 1.8)
    ou0, ou1, on = S["out"]
    bx = ou0 + 0.3
    basket2(b, Pw(P_, bx, 0.0, on - 0.05), 0.22, 0.12)
    b.box(Pw(P_, bx, 0.1, on - 0.05), (0.32, 0.06, 0.32), J("#e98bb0", 0.04), R, mat=M_CLOTH)
    pet("cat", Pw(P_, bx, 0.13, on - 0.05), 2.2, "sleep", 0.9, "bow")
    for k, food in enumerate(("#f4f1e8", "#c9605a")):
        bowl(b, Pw(P_, ou0 + 0.75 + k * 0.18, 0.0, on + 0.05), 0.06, J("#c27a4a", 0.05), food=food)
    pet("cat", Pw(P_, ou1 - 0.3, 0.0, on + 0.05), 0.1, "pet", 1.0, "collar")
    plant_pot(b, Pw(P_, ou1 + 0.25, 0.0, on - 0.15), 0.28)
    pet("toy", Pw(P_, ou1 - 0.3, 1.95, 0.5), 0.0, "", 1.0)          # клубок на нитке — с навеса


def civ_vigiles(body, emb, Pf, U, N, R, x0, x1, z0, z1):
    tx, tz = x1 + 0.95, z1 - 0.65
    watchtower(body, emb, tx, tz, 2.9)
    # под вышкой — бочка-водовозка на колёсах
    cart(body, (tx, 0.0, tz + 0.1), Matrix.Rotation(math.pi / 2, 3, "Y"))
    barrel(body, (tx, 0.45, tz + 0.15), 0.5, 0.18)
    # у стены: лестницы, вёдра, стойка с топорами и крюками, бочки с водой
    ladder2(body, Pf, U, N, 2.25, 2.2)
    body.box(Pw(Pf, 2.95, PL + 1.35, 0.04), (0.6, 0.5, 0.04), J(P["wood"], 0.05), R, mat=M_WOOD)
    for k, uu in enumerate((2.75, 2.95, 3.15)):
        if k == 1:
            rod(body, Pw(Pf, uu, PL + 0.9, 0.08), Pw(Pf, uu, PL + 1.9, 0.08), 0.03, J("#8a6038", 0.05), mat=M_WOOD)
            body.box(Pw(Pf, uu + 0.05, PL + 1.88, 0.08), (0.1, 0.03, 0.02), col(IRON), R)
        else:
            axe(body, Pf(uu, PL + 1.0, 0.08), R, 0.0)
    for k in range(4):
        bucket(body, Pw(Pf, 2.4 + k * 0.28, 0.0, 0.32), 0.09, 0.16)
    for k in range(2):
        barrel(body, Pw(Pf, W - 0.3, 0.0, 0.28 + k * 0.42), 0.55, 0.18, top_col=col("#5f8fa0"))
    rope_coil(body, Pw(Pf, 0.3, 0.0, 0.35))
    body.box(Pw(Pf, W / 2 + 0.6, PL + 1.92, 0.01), (0.56, 0.4, 0.02), J("#6b4428", 0.05), R, mat=M_WOOD)
    sign_board(body, Pf, U, N, W / 2 + 0.6, PL + 1.92, 0.5, 0.333, 0.024, "vigiles")
    ACTORS.append([round(x0 + 1.2, 3), 0.0, round(z1 + 0.55, 3), 0.0, "Idle", "pleb"])
    ACTORS.append([round(x1 - 0.65, 3), 0.0, round(z1 + 0.75, 3), math.pi + 0.5, "Interact", "pleb"])
    DOOR_PT[2] = z1 + 0.9
    return z0, z1 + 0.6, x0, x1 + 1.75


def civ_prefect(body, emb, Pf, U, N, R, x0, x1, z0, z1):
    dep = 1.3
    temple_front(body, x0 + 1.2, x1 - 1.2, z1, dep, 0.36, 2.05, 4, key="tymp_pref", ins="ins_pref", r=0.1, swags="#9a2f28")
    for s in (-1, 1):
        fasces(body, (s * 0.85, 0.36, z1 + 0.25), Matrix.Identity(3))
        statue_prop(s * 2.3, z1 + 0.8, 0.0, 0.62)
        tripod(body, emb, (s * 2.05, 0.0, z1 + dep + 0.45), 0.95)
        tree_prop("SM_Env_Tree_Thin_0%d" % (1 + (s > 0)), s * (W / 2 + 0.35), z0 + 0.6, 0.48)
    banner(body, Pf, U, N, "front", 1.55, HT - 0.32, 0.4, 0.9, 0.06, 0)
    banner(body, Pf, U, N, "front", W - 1.55, HT - 0.32, 0.4, 0.9, 0.06, 1)
    laurel(body, Pf(DS["door_u"][0] - 0.05, PL + 1.98, 0.1), Pf(DS["door_u"][1] + 0.05, PL + 1.98, 0.1), 0.14, tuple(N))
    ACTORS.append([-0.55, 0.36, round(z1 + 0.8, 3), 0.4, "Idle", "rich"])
    ACTORS.append([0.6, 0.36, round(z1 + 0.95, 3), -0.6, "Idle", "rich"])
    block("front", Pf, U, 1.0, W - 1.0, 0.0, HT)
    DOOR_PT[2] = z1 + dep + 0.9
    return z0, z1 + dep + 0.65, x0 - 0.6, x1 + 0.6


def civ_balnea(body, emb, Pf, U, N, R, x0, x1, z0, z1):
    px0, px1, pz0, pz1 = x0 + 0.35, x0 + 3.65, z1 + 0.4, z1 + 2.15
    pool(body, px0, px1, pz0, pz1, step_side=1)
    lion_spout(body, Pf, U, N, 2.0, PL + 1.0, (x0 + 2.0, 0.16, pz0 + 0.35))
    framed_fresco(body, Pf, U, N, "front", 2.0, PL + 1.62, 1.1, 0.42, "dolphins")
    # вход справа: мраморная дорожка, черепичный навес на колонках
    du0, du1 = DS["door_u"]
    dx = x0 + (du0 + du1) / 2
    body.box((dx, 0.025, z1 + 1.0), (1.4, 0.05, 2.0), J(MARBLE, 0.03, 0.0, 0.0), skip=("bot",), mat=M_MARBLE)
    for s in (-1, 1):
        column3(body, (dx + s * 0.62, 0.05, z1 + 1.7), 1.95, 0.065, seg=12)
    canopy(body, Pf, U, N, (du0 + du1) / 2, PL + 1.98, 1.5, 1.6)
    for k in range(2):
        folded_stack(body, (px0 + 0.4 + k * 0.4, 0.24, pz1 + 0.0), Matrix.Identity(3), 0.28, 0.14, 3, ["#f4efe2", "#d8e4ec", "#efe0b8"])
    amphora(body, (x1 - 0.25, 0.0, z1 + 0.35), 0.55, J("#c27a4a", 0.06))
    basket2(body, (x1 - 0.3, 0.0, z1 + 1.4), 0.16, 0.2)
    tripod(body, emb, (x0 + 0.1, 0.0, pz1 + 0.35), 0.9)
    tree_prop("SM_Env_Tree_Palm_01", x1 + 0.35, z0 + 0.5, 0.33)
    ACTORS.append([round(x0 + 2.0, 3), 0.0, round(pz1 + 0.35, 3), math.pi, "Idle", "any"])
    DOOR_PT[0] = dx
    DOOR_PT[2] = z1 + 2.2
    return z0, pz1 + 0.5, x0, x1 + 0.6


def civ_baths(body, emb, Pf, U, N, R, x0, x1, z0, z1):
    pz0, pz1 = z1 + 0.6, z1 + 3.6              # след — как у прежних терм (10 × 7,2 м)
    for s in (-1, 1):
        xa, xb = sorted((s * 0.75, s * 3.45))
        pool(body, xa, xb, pz0, pz1, step_side=1)
        # фонтан во главе бассейна: мраморная чаша на ножке, струя
        fx = (xa + xb) / 2
        body.lathe((fx, 0.24, pz0 + 0.05), [(0.08, 0.0), (0.06, 0.25), (0.25, 0.32), (0.27, 0.4)], 12, J(MARBLE, 0.03, 0.0, 0.0), mat=M_MARBLE)
        body.lathe((fx, 0.6, pz0 + 0.05), [(0.24, 0.0), (0.24, 0.001)], 12, col("#7fbfd0"), close_top=True)
        rod(body, (fx, 0.62, pz0 + 0.05), (fx, 0.95, pz0 + 0.05), 0.03, col("#bfe4f0"))
        stoa(body, s * (W / 2 - 0.05), s, z1 + 0.3, z1 + 3.9, 1.15, 2.0, fresco="dolphins")
        marble_bench(body, (s * (W / 2 - 0.55), 0.08, z1 + 2.1), Matrix.Rotation(math.pi / 2 * s, 3, "Y"), 1.0)
        statue_prop(s * 2.1, pz1 + 0.35, 0.0, 0.7)
        tripod(body, emb, (s * 1.0, 0.0, pz1 + 0.35), 0.95)
    body.box((0.0, 0.03, (z1 + pz1 + 0.6) / 2), (1.4, 0.06, pz1 + 0.6 - z1), J(MARBLE, 0.03, 0.0, 0.0), skip=("bot",), mat=M_MARBLE)
    framed_fresco(body, Pf, U, N, "front", W / 2, PL + FLH + 1.05, 2.2, 0.95, "dolphins")
    banner(body, Pf, U, N, "front", 3.45, HT - 0.3, 0.42, 0.95, 0.06, 1)
    banner(body, Pf, U, N, "front", W - 3.45, HT - 0.3, 0.42, 0.95, 0.06, 0)
    laurel(body, Pf(DS["door_u"][0] - 0.05, PL + 2.03, 0.1), Pf(DS["door_u"][1] + 0.05, PL + 2.03, 0.1), 0.14, tuple(N))
    P_ = lambda u, v, n: Pf(u, v, n)
    fresco_quad(body, P_, N, W / 2, PL + DS["door_h"] + 0.2, 1.6, 0.26, 0.03, "ins_therm", band=True)
    DOOR_PT[2] = pz1 + 0.85
    return z0, pz1 + 0.6, x0, x1


def civ_sculptor(body, emb, Pf, U, N, R, x0, x1, z0, z1):
    du0, du1 = DS["door_u"]
    for uu in (du0 + (du1 - du0) / 3, du0 + 2 * (du1 - du0) / 3):     # столбы в широком проёме мастерской
        column3(body, Pw(Pf, uu, 0.0, -0.05), PL + DS["door_h"] + 0.05, 0.07, seg=10, ionic=False)
    body.box(Pw(Pf, (du0 + du1) / 2, PL + DS["door_h"] + 0.08, 0.02), (du1 - du0 + 0.2, 0.16, 0.18), J(P["wood"], 0.05), R, mat=M_WOOD)
    # верстак с инструментами под крышей
    body.box((x0 + 1.0, 0.55, z1 - 0.6), (1.2, 0.06, 0.5), J(P["wood"], 0.06), mat=M_WOOD)
    for s in (-1, 1):
        for t in (-1, 1):
            body.box((x0 + 1.0 + s * 0.52, 0.27, z1 - 0.6 + t * 0.2), (0.06, 0.54, 0.06), J(P["wood2"], 0.05), mat=M_WOOD)
    for k in range(4):
        body.box((x0 + 0.6 + k * 0.22, 0.6, z1 - 0.6 + rng.uniform(-0.1, 0.1)), (0.16, 0.025, 0.03), col("#aab1b8" if k % 2 else "#8a6038"), Matrix.Rotation(rng.uniform(-0.5, 0.5), 3, "Y"))
    body.box((x0 + 1.45, 0.62, z1 - 0.55), (0.1, 0.08, 0.08), J("#6b4428", 0.05), mat=M_WOOD)
    # двор: низкая каменная стенка с проходом, глыбы, щебень, статуя в лесах, почти готовая, готовая у входа
    yz = z1 + 2.7
    for (xa, za, xb, zb) in ((x0, z1, x0, yz), (x1, z1, x1, yz), (x0, yz, -0.7, yz), (0.7, yz, x1, yz)):
        L = max(abs(xb - xa), abs(zb - za))
        along_x = abs(xb - xa) > 0.01
        size = (L, 0.55, 0.22) if along_x else (0.22, 0.55, L)
        body.box(((xa + xb) / 2, 0.275, (za + zb) / 2), size, J(P["stone"], 0.05), mat=M_STONE)
        body.box(((xa + xb) / 2, 0.58, (za + zb) / 2), (size[0] + 0.04, 0.06, size[2] + 0.04), J(MARBLE, 0.03, 0.0, 0.0), mat=M_MARBLE)
    unfinished_statue(-0.6, z1 + 1.2, 0.2, 0.9, 1)
    scaffold(body, -0.6, z1 + 1.2, 0.9, 0.7, 2.0)
    unfinished_statue(1.4, z1 + 1.1, -0.4, 0.95, 2)
    crane(body, (1.4, 0.0, z1 + 1.1), 2.5)
    marble_block(body, (x1 - 0.55, 0.0, z1 + 2.1), (0.6, 0.5, 0.45), 0.4)
    marble_block(body, (x1 - 0.6, 0.5, z1 + 2.1), (0.4, 0.3, 0.35), 0.1)
    marble_block(body, (x0 + 0.6, 0.0, z1 + 2.2), (0.55, 0.4, 0.4), -0.3)
    for k in range(9):
        marble_block(body, (rng.uniform(x0 + 0.5, x1 - 0.5), 0.0, z1 + rng.uniform(0.5, 2.3)), (rng.uniform(0.06, 0.14),) * 3, rng.uniform(0, 3))
    for k in range(3):                         # штабель плит
        marble_block(body, (x0 + 0.55, k * 0.13, z1 + 0.65), (0.7, 0.12, 0.45), 0.05 * k)
    statue_prop(1.05, yz + 0.25, -0.3, 0.7)
    # вывеска на столбе у входа
    rod(body, (-0.95, 0.0, yz + 0.15), (-0.95, 1.75, yz + 0.15), 0.06, J(P["wood"], 0.05), mat=M_WOOD)
    body.box((-0.95, 1.55, yz + 0.15), (0.5, 0.34, 0.025), J("#6b4428", 0.05), mat=M_WOOD)
    sign_board(body, lambda u, v, n: Vector((u, v, yz + 0.15 + 0.014 + n)), Vector((1, 0, 0)), Vector((0, 0, 1)), -0.95, 1.55, 0.45, 0.3, 0.0, "sculptor")
    ACTORS.append([-0.6, 0.0, round(z1 + 1.75, 3), math.pi, "Interact", "any"])
    ACTORS.append([1.0, 0.0, round(z1 + 1.65, 3), math.pi - 0.6, "Interact", "any"])
    DOOR_PT[2] = yz + 0.5
    return z0, yz + 0.35, x0, x1


def civ_shelter(body, emb, Pf, U, N, R, x0, x1, z0, z1):
    # загон справа от домика: плетень сзади, сбоку и спереди с проходом у домика
    ex = x1 + 3.0
    pz0, pz1 = z0, z1 + 0.2
    wattle(body, x1 + 0.05, pz0, ex, pz0)
    wattle(body, ex, pz0, ex, pz1)
    wattle(body, x1 + 1.0, pz1, ex, pz1)
    # лавка с корзинками для кошек у заднего плетня
    bx = x1 + 1.2
    body.box((bx, 0.33, pz0 + 0.35), (1.3, 0.05, 0.32), J(P["wood"], 0.06), mat=M_WOOD)
    for s in (-1, 1):
        body.box((bx + s * 0.55, 0.16, pz0 + 0.35), (0.06, 0.32, 0.28), J(P["wood2"], 0.06), mat=M_WOOD)
    for k, xx in enumerate((bx - 0.35, bx + 0.35)):
        basket2(body, (xx, 0.355, pz0 + 0.35), 0.18, 0.1)
        body.box((xx, 0.44, pz0 + 0.35), (0.26, 0.05, 0.26), J(["#c87aa0", "#8fb0d9"][k], 0.04), mat=M_CLOTH)
        pet("cat", (xx, 0.47, pz0 + 0.35), [2.4, 0.6][k], "sleep", 1.0)
    # навес для ослика: столбы, черепица, ясли с сеном; рядом тюки сена и корыто с водой
    sx, sz = ex - 0.6, (pz0 + pz1) / 2 + 0.1
    for (dx, dz) in ((-0.5, -0.55), (0.5, -0.55), (-0.5, 0.55), (0.5, 0.55)):
        rod(body, (sx + dx, 0.0, sz + dz), (sx + dx, 1.5 + (0.15 if dx > 0 else 0.0), sz + dz), 0.07, J(P["wood"], 0.05), mat=M_WOOD)
    roof(body, False, sx - 0.65, sx + 0.65, sz - 0.7, sz + 0.7, 1.55, pitch_deg=18.0, oe=0.1, og=0.1, antefix=False)
    body.box((sx + 0.35, 0.5, sz), (0.3, 0.12, 0.9), J(P["wood"], 0.06), mat=M_WOOD)
    for k in range(5):
        leaf_blob(body, (sx + 0.35, 0.6, sz - 0.35 + k * 0.17), 0.07, J("#d9c27a", 0.08))
    pet("donkey", (sx - 0.1, 0.0, sz), math.pi / 2 + 0.2, "Eating", 0.95)
    for k in range(2):
        body.box((x1 + 2.2 - k * 0.5, 0.18 + (0.0 if k == 0 else 0.0), pz1 - 0.45), (0.45, 0.36, 0.32), J("#d9c27a", 0.08))
    body.box((x1 + 1.4, 0.15, pz1 - 0.4), (0.25, 0.3, 0.7), J(P["stone"], 0.05), mat=M_STONE)
    body.box((x1 + 1.4, 0.29, pz1 - 0.4), (0.18, 0.02, 0.62), col("#5fa6b8"))
    # миски у порога, мешок корма, вывеска
    du0, du1 = DS["door_u"]
    for k in range(2):
        bowl(body, Pf(du0 - 0.35 - k * 0.2, 0.0, 0.3), 0.06, J("#c27a4a", 0.05), food=["#f4f1e8", "#c9a46e"][k])
    sack(body, Pw(Pf, 0.25, 0.0, 0.3), 0.12, 0.3, open_=True, grain="#b08a5a")
    body.box(Pw(Pf, W / 2, HT - 0.3, 0.01), (0.5, 0.36, 0.02), J("#6b4428", 0.05), R, mat=M_WOOD)
    sign_board(body, Pf, U, N, W / 2, HT - 0.3, 0.45, 0.3, 0.024, "shelter")
    ACTORS.append([round(x1 + 0.6, 3), 0.0, round(z1 - 0.3, 3), -math.pi / 2 - 0.4, "Interact", "any"])
    DOOR_PT[2] = z1 + 0.6
    return z0 - 0.05, z1 + 0.35, x0, ex + 0.1


CIVIC_FRONTS = {"vigiles": civ_vigiles, "prefect": civ_prefect, "balnea": civ_balnea, "baths": civ_baths, "sculptor": civ_sculptor, "shelter": civ_shelter}

CIVIC.update({
    "vigiles": {"w": 3.6, "d": 2.4, "floors": 1, "roof": "x", "pal": 0, "tint": "#d4895e", "shutter": "red", "door": "red", "lower": "brick",
                "door_u": (0.45, 1.95), "door_h": 1.7, "double": True, "corners": "stone", "sign": "vigiles",
                "fwins": [(0, 2.55, 3.15, 0.8, 1.45, True, False, True, False)]},
    "prefect": {"w": 5.6, "d": 3.2, "floors": 2, "roof": "x", "pal": 1, "tint": "#f4efe6", "shutter": "green", "door": "bronze", "dado": "#a83f2c", "dado_h": 0.95,
                "door_u": (2.25, 3.35), "door_h": 1.8, "double": True, "corners": "stone", "sign": "prefect", "decal": "frieze",
                "fwins": [(0, 0.55, 1.2, 0.8, 1.55, False, False, True, True), (0, 4.4, 5.05, 0.8, 1.55, False, False, True, True),
                          (1, 0.5, 1.1, 0.72, 1.5, True, True, True, False, True), (1, 4.5, 5.1, 0.72, 1.5, True, True, True, False, True)]},
    "balnea": {"w": 6.4, "d": 2.6, "floors": 1, "roof": "flat", "pal": 1, "tint": "#f2eee6", "shutter": "teal", "door": "oak", "dado": "#3f6f9f", "dado_h": 0.7,
               "door_u": (4.55, 5.55), "door_h": 1.65, "double": True, "corners": "stone", "sign": "balnea", "domes": [(0.7, -0.9, 0.0)],
               "fwins": [(0, 0.6, 1.15, 1.0, 1.5, False, False, True, True), (0, 2.85, 3.4, 1.0, 1.5, False, False, True, True)]},
    "baths": {"w": 10.0, "d": 3.0, "floors": 2, "roof": "flat", "pal": 1, "tint": "#f6f0e6", "shutter": "teal", "door": "bronze", "dado": "#a83f2c", "dado_h": 1.75,
              "door_u": (4.4, 5.6), "door_h": 1.85, "double": True, "corners": "stone", "sign": "baths", "domes": [(1.35, 0.0, 0.0), (0.7, -3.3, 0.0), (0.7, 3.3, 0.0)],
              "fwins": [(0, 0.7, 1.3, 0.75, 1.55, False, False, True, True), (0, 8.7, 9.3, 0.75, 1.55, False, False, True, True),
                        (1, 0.7, 1.3, 0.72, 1.5, False, True, True, True, True), (1, 2.3, 2.9, 0.72, 1.5, False, True, True, True, True),
                        (1, 7.1, 7.7, 0.72, 1.5, False, True, True, True, True), (1, 8.7, 9.3, 0.72, 1.5, False, True, True, True, True)],
              "niches": [(0, 2.4), (0, 7.6)], "pilasters": [1.75, 8.25]},
    "sculptor": {"w": 5.4, "d": 2.0, "floors": 1, "roof": "x", "pal": 2, "tint": "#ece4d4", "shutter": "brown", "door": "oak", "nodoor": True,
                 "door_u": (0.55, 4.85), "door_h": 1.7, "double": False, "corners": "stone", "sign": "sculptor", "fwins": []},
    "shelter": {"w": 2.6, "d": 2.6, "floors": 1, "roof": "z", "pal": 0, "tint": "#ecdcc4", "shutter": "blue", "door": "blue",
                "door_u": (0.55, 1.35), "door_h": 1.55, "double": False, "corners": "stone", "sign": "shelter",
                "fwins": [(0, 1.7, 2.2, 0.8, 1.4, True, True, True, False)]},
})


TRADE_GOODS.update({"herbs": g_herbs, "cats": g_cats})


def configure(kind, v, floors):
    global KIND, V, FLOORS, W, D, HT, PH, P, DS, MOV, FACES, EXTRA_BLOCK, LIGHTS, PERCH, DOOR_PT, FP, SMOKE
    global ACTORS, PROPS, PETS_K
    KIND, V, FLOORS = kind, v, floors
    PROPS = []
    PETS_K = []
    W = 3.6
    D = 4.3 if kind == "patrician" else 3.9          # глубина — как у прежних домов (след при перестройке тот же)
    ACTORS = []
    if kind in ("shop", "stall"):
        DS = dict(TRADES.get(v, {})) if kind == "shop" else {"pal": 0}
        W = DS.get("w", 3.6)
        D = DS.get("d", 3.9)
        FLOORS = DS.get("floors", 1) if kind == "shop" else 1
        if DS.get("front") == "canopy":
            DS["canopy"] = True
    if kind == "civic":
        DS = dict(CIVIC[v])
        W, D, FLOORS = DS["w"], DS["d"], DS["floors"]
    HT = PL + FLOORS * FLH
    use("ph")
    PH = [rng.uniform(0, 6.28) for _ in range(5)]
    if kind not in ("shop", "stall", "civic"):
        DS = dict({"pleb": PLEB, "artisan": ART, "patrician": PAT}[kind][v])
    P = dict(PALS[DS.get("pal", 0)])
    MOV, FACES, EXTRA_BLOCK, LIGHTS, PERCH, FP, SMOKE = [], {}, {}, [], [], [], []
    DOOR_PT = [0, 0, D / 2 + 0.3]


def build_house():
    """дом: коробка W×D, этажи 1–3; облик — PLEB / ART / PAT [V]. Ремесленник — лавка внизу и двор с навесом позади,
    патриций — портик перед входом и сад позади"""
    coll = bpy.context.scene.collection
    x0, x1 = -W / 2, W / 2
    z0, z1 = -D / 2, D / 2
    body = MB("House")
    walls = MB("Walls", [MAT_KIT, WALL_MATS[DS["walls"]]]) if KIND == "civic" and DS.get("walls") else MB("Walls")
    inner = MB("Rooms")
    emb = MB("Embers", [MAT_EMBER])
    use("g")
    left = ((V if isinstance(V, int) else seed_of(V)) + (1 if FLOORS else 0)) % 2 == 0          # дверь слева или справа
    door_u = (0.55, 1.37) if left else (W - 1.37, W - 0.55)
    win_u = (W - 1.25, W - 0.6) if left else (0.6, 1.25)
    door_h = 1.52
    shop_u = None
    wins = []           # (сторона, u0, u1, v0, v1, ставни, ящик, наличник, решётка[, фронтончик])
    if KIND in ("artisan", "shop"):
        # лавка — широкий проём, дверь — в другом пролёте
        sw = W - 1.5
        shop_u = (0.28, 0.28 + sw) if left else (W - 0.28 - sw, W - 0.28)
        door_u = (W - 1.12, W - 0.36) if left else (0.36, 1.12)
        win_u = shop_u
        front_open = [(door_u[0], door_u[1], PL, PL + door_h), (shop_u[0], shop_u[1], PL, PL + 1.62)]
    elif KIND == "patrician":
        # парадная двустворчатая дверь посередине, по сторонам — высокие узкие окна с решёткой (домус глух к улице)
        door_u = (W / 2 - 0.55, W / 2 + 0.55)
        door_h = 1.72
        win_u = (0.35, 0.8)
        front_open = [(door_u[0], door_u[1], PL, PL + door_h)]
        wins.append(("front", 0.32, 0.72, PL + 1.15, PL + 1.62, False, False, True, True))
        wins.append(("front", W - 0.72, W - 0.32, PL + 1.15, PL + 1.62, False, False, True, True))
    elif KIND == "civic":
        door_u = DS["door_u"]
        door_h = DS.get("door_h", 1.6)
        win_u = (0.6, 1.2)
        front_open = [(door_u[0], door_u[1], PL, PL + door_h)]
        for fw in DS.get("fwins", []):
            wins.append(("front", fw[1], fw[2], PL + fw[0] * FLH + fw[3], PL + fw[0] * FLH + fw[4]) + tuple(fw[5:]))
        if DS.get("loading"):
            front_open.append((DS["loading"][0], DS["loading"][1], PL + FLH + 0.12, PL + FLH + 1.6))
    else:
        front_open = [(door_u[0], door_u[1], PL, PL + door_h)]
        wins.append(("front", win_u[0], win_u[1], PL + 0.78, PL + 1.5, True, DS.get("boxes", False), True, False))
    balcony = None
    for f in range(1, FLOORS if KIND != "civic" else 1):
        use("f%d" % f)
        y = PL + f * FLH
        if KIND == "patrician":
            hood = True
            wins.append(("front", 0.42, 1.06, y + 0.72, y + 1.5, True, f == FLOORS - 1, True, False, True))
            wins.append(("front", W - 1.06, W - 0.42, y + 0.72, y + 1.5, True, f == FLOORS - 1, True, False, True))
            if FLOORS == 3 and f == 1:
                wins.append(("front", W / 2 - 0.25, W / 2 + 0.25, y + 0.8, y + 1.4, False, False, True, True))
        elif f == 1 and DS.get("balcony"):
            bu = (door_u[0] + 0.05, door_u[1] - 0.05)
            front_open.append((bu[0], bu[1], y + 0.02, y + 1.55))
            balcony = (bu, y)
            wu = win_u
            if shop_u:                     # над лавкой — обычное окно, а не во всю ширину проёма
                cu = (shop_u[0] + shop_u[1]) / 2
                wu = (cu - 0.32, cu + 0.32)
            wins.append(("front", wu[0], wu[1], y + 0.72, y + 1.48, True, False, True, False))
        else:
            boxes = DS.get("boxes", False) or f == FLOORS - 1
            wins.append(("front", 0.5, 1.12, y + 0.74, y + 1.46, True, boxes, True, False))
            wins.append(("front", W - 1.12, W - 0.5, y + 0.74, y + 1.46, True, boxes and f > 1, True, False))
    for f in range(FLOORS):
        use("b%d" % f)
        y = PL + f * FLH
        u = W / 2 - 0.25 + (0.5 if f % 2 else -0.4)
        wins.append(("back", u, u + 0.45, y + 0.9, y + 1.4, f > 0, False, False, True))
        sl = (D - 2 * T) / 2 - 0.2 + (0.35 if f else 0.0)
        wins.append(("left", sl, sl + 0.42, y + 0.92, y + 1.4, False, False, False, True))
        sr = (D - 2 * T) * (0.3 if f % 2 == 0 else 0.55)
        wins.append(("right", sr, sr + 0.55, y + 0.8, y + 1.45, True, f == FLOORS - 1 and FLOORS > 1, True, False))
        if KIND == "civic":                    # широкий зал: окна и по краям задней стены
            wins.append(("back", 0.6, 1.05, y + 0.9, y + 1.4, f > 0, False, False, True))
            wins.append(("back", W - 1.05, W - 0.6, y + 0.9, y + 1.4, f > 0, False, False, True))
    for wv in wins:
        if wv[0] == "front":
            front_open.append((wv[1], wv[2], wv[3], wv[4]))
    stains = [(wv[1] + 0.05, wv[2] - 0.05, wv[3]) for wv in wins if wv[0] == "front"]
    use("g")
    walls_def = {
        "front": (Vector((x0, 0, z1)), Vector((1, 0, 0)), Vector((0, 0, 1)), W),
        "back": (Vector((x1, 0, z0)), Vector((-1, 0, 0)), Vector((0, 0, -1)), W),
        "left": (Vector((x0, 0, z0 + T)), Vector((0, 0, 1)), Vector((-1, 0, 0)), D - 2 * T),
        "right": (Vector((x1, 0, z1 - T)), Vector((0, 0, -1)), Vector((1, 0, 0)), D - 2 * T),
    }
    opens = {"front": front_open, "back": [], "left": [], "right": []}
    for wv in wins:
        if wv[0] != "front":
            opens[wv[0]].append((wv[1], wv[2], wv[3], wv[4]))
    Ps = {}
    for name, (O, U, N, Ln) in walls_def.items():
        Ps[name] = (wall(walls, inner, name, (O, U, N), 0.0, Ln, PL, HT, opens[name],
                         stains if name == "front" else (), caps=name in ("front", "back")), U, N)
    for f in range(FLOORS):
        use("i%d" % f)
        y = PL + f * FLH
        interior(inner, emb, x0 + T, x1 - T, z0 + T, z1 - T, y, f)
        if f > 0:
            body.box((0, y - 0.07, 0), (W - 2 * T + 0.02, 0.1, D - 2 * T + 0.02), col(P["wood2"], -0.2), mat=M_WOOD)
            nb = int(W / 0.5)
            for k in range(nb):
                bx = x0 + 0.3 + (W - 0.6) * k / max(1, nb - 1)
                if any(o[0] - 0.08 < bx - x0 < o[1] + 0.08 and o[2] - 0.2 < y < o[3] + 0.2 for o in front_open):
                    continue
                body.box((bx, y - 0.1, z1 + 0.05), (0.11, 0.11, 0.14), J(P["wood"], 0.1), cols={"pz": J(P["wood2"], 0.1)}, mat=M_WOOD)
            for name, (O, U, N, Ln) in walls_def.items():
                Pf = Ps[name][0]
                ext = T if name in ("left", "right") else 0.0
                body.box(Pw(Pf, Ln / 2, y + 0.03, 0.025), (Ln + 2 * ext + 0.06, 0.06, 0.05), J(P["trim"], 0.04), RW(U, N))
    body.box((0, PL - 0.02, 0), (W - 0.02, 0.06, D - 0.02), col(P["wood2"], -0.3), mat=M_WOOD)
    use("g")
    for name, (O, U, N, Ln) in walls_def.items():
        Pf = Ps[name][0]
        ext = T if name in ("left", "right") else 0.0
        body.box(Pw(Pf, Ln / 2, HT - 0.05, 0.03), (Ln + 2 * ext + 0.08, 0.1, 0.06), J(P["trim"], 0.04), RW(U, N))
        body.box(Pw(Pf, Ln / 2, HT - 0.11, 0.015), (Ln + 2 * ext + 0.04, 0.04, 0.03), J(P["trim"], -0.05), RW(U, N))
    corner_stones(body, x0, x1, z0, z1, DS.get("corners"))
    plinth(body, x0, x1, z0, z1, [("front", door_u[0] - 0.02, door_u[1] + 0.02)])
    body.box(((x0 + (door_u[0] + door_u[1]) / 2), 0.07, z1 + 0.16), (door_u[1] - door_u[0] + 0.24, 0.14, 0.36),
             J(P["stone"], 0.05), cols={"top": J(P["stone"], 0.1)})
    Pf, U, N = Ps["front"]
    if DS.get("lower") == "brick":
        brick_facing(body, Pf, U, N, 0.0, W, PL, PL + 0.95, front_open)
        Pl, Ul, Nl = Ps["left"]
        brick_facing(body, Pl, Ul, Nl, 0.0, D - 2 * T, PL, PL + 0.95, opens["left"])
        Pr, Ur, Nr = Ps["right"]
        brick_facing(body, Pr, Ur, Nr, 0.0, D - 2 * T, PL, PL + 0.95, opens["right"])
    # окна и ставни
    for wv in wins:
        s, a, b, c, d, sh, bx, sur, gr = wv[:9]
        use("w%s%d%d" % (s, int(a * 10), int(c * 10)))
        Pf_, U_, N_ = Ps[s]
        window(body, Pf_, U_, N_, s, a, b, c, d, shutters=sh, box=bx, grille=gr, surround=sur, hood=len(wv) > 9 and wv[9])
    # дверь
    use("g")
    if DS.get("nodoor"):
        block("front", Pf, U, door_u[0] - 0.2, door_u[1] + 0.2, PL, PL + door_h + 0.3)
    elif KIND == "patrician" or DS.get("double"):
        # парадная дверь: две створки, каменный наличник с карнизом
        a, b = door_u
        R = RW(U, N)
        for cu in (a + 0.05, b - 0.05):
            body.box(Pw(Pf, cu, PL + door_h / 2, -0.04), (0.12, door_h, 0.12), J("#ece6da", 0.03, 0.0, 0.0), R)
        body.box(Pw(Pf, (a + b) / 2, PL + door_h + 0.09, 0.03), (b - a + 0.34, 0.18, 0.16), J("#ece6da", 0.03, 0.0, 0.0), R)
        lw = (b - a - 0.2) / 2
        mov("door", door_key(DS["door"], lw, door_h - 0.03, 1), Pf(a + 0.1, PL, -0.1), U, N, math.radians(55), 1)
        mov("door", door_key(DS["door"], lw, door_h - 0.03, -1), Pf(b - 0.1, PL, -0.1), U, N, math.radians(55), -1)
        block("front", Pf, U, a - 0.2, b + 0.2, PL, PL + door_h + 0.3)
    else:
        door(body, Pf, U, N, "front", door_u[0], door_u[1], PL, PL + door_h, DS["door"], stone=not DS.get("arch"), arch=DS.get("arch", False))
    if shop_u:
        use("shop")
        shopfront(body, emb, Pf, U, N, "front", shop_u[0], shop_u[1], DS.get("goods", DS.get("craft")), PL + 1.62)
        # лавочник — за прилавком, лицом к улице
        cu = shop_u[0] + (shop_u[1] - shop_u[0]) * 0.36
        ACTORS.append([round(x0 + cu, 3), 0.0, round(z1 - 0.5, 3), 0.0, "Interact", "any"])
        if DS.get("scribe"):
            # писец за столом перед лавкой — первым (работник один — его место первое)
            scribe_desk(body, x0 + (shop_u[0] + shop_u[1]) / 2, z1)
            ACTORS.insert(0, [round(x0 + (shop_u[0] + shop_u[1]) / 2, 3), 0.0, round(z1 + 1.05, 3), math.pi, "Sitting_Idle", "pleb"])
        if DS.get("chair"):
            # цирюльня: кресло у входа, в нём клиент (второй «при деле»)
            chx = x0 + shop_u[1] - 0.35
            body.box((chx, PL + 0.25, z1 - 0.45), (0.42, 0.06, 0.4), J(P["wood"], 0.06), mat=M_WOOD)
            body.box((chx, PL + 0.55, z1 - 0.66), (0.42, 0.55, 0.05), J(P["wood"], 0.06), mat=M_WOOD)
            for sx in (-1, 1):
                for sz in (-1, 1):
                    body.box((chx + sx * 0.17, PL + 0.12, z1 - 0.45 + sz * 0.16), (0.04, 0.24, 0.04), J(P["wood2"], 0.05), mat=M_WOOD)
            ACTORS[-1] = [round(chx + 0.45, 3), 0.0, round(z1 - 0.4, 3), -math.pi / 2, "Interact", "any"]
            ACTORS.append([round(chx, 3), 0.0, round(z1 - 0.42, 3), 0.0, "Sitting_Idle", "pleb"])
    door_mid = (door_u[0] + door_u[1]) / 2
    DOOR_PT[0] = x0 + door_mid
    DOOR_PT[2] = z1 + 0.35
    # фонарик у двери (в игре — «#wall_lamp_dim», ночью еле теплится)
    lu = door_u[1] + 0.22 if left else door_u[0] - 0.22
    if KIND in ("artisan", "shop"):
        lu = door_u[0] - 0.2 if left else door_u[1] + 0.2
    elif KIND == "patrician":
        lu = door_u[1] + 0.28
    if KIND == "civic":                        # фонари по обе стороны парадной двери
        for lu in (door_u[0] - 0.26, door_u[1] + 0.26):
            LIGHTS.append({"lamp": [round(x0 + lu, 3), round(PL + 1.62, 3), round(z1 + 0.02, 3)], "yaw": 0.0})
            block("front", Pf, U, lu - 0.15, lu + 0.15, PL + 1.3, PL + 1.9)
    else:
        LIGHTS.append({"lamp": [x0 + lu, PL + 1.62, z1 + 0.02], "yaw": 0.0})
        block("front", Pf, U, lu - 0.15, lu + 0.15, PL + 1.3, PL + 1.9)
    # балкон
    if balcony:
        use("f1")
        (bu0, bu1), y = balcony
        R = RW(U, N)
        u0, u1 = bu0 - 0.4, bu1 + 0.4
        dep = 0.62
        for k in range(4):
            uu = u0 + 0.06 + (u1 - u0 - 0.12) * k / 3
            body.box(Pw(Pf, uu, y - 0.06, dep / 2), (0.09, 0.1, dep + 0.1), J(P["wood"], 0.08), R, mat=M_WOOD)
        nbp = int((u1 - u0) / 0.12)
        for k in range(nbp):
            uu = u0 + (u1 - u0) * (k + 0.5) / nbp
            body.box(Pw(Pf, uu, y + 0.01, dep / 2), ((u1 - u0) / nbp - 0.008, 0.035, dep), J(P["wood"], 0.12, 0.01, 0.1), R, mat=M_WOOD)
        nr = int((u1 - u0) / 0.13)
        for k in range(nr + 1):
            uu = u0 + 0.02 + (u1 - u0 - 0.04) * k / nr
            body.box(Pw(Pf, uu, y + 0.3, dep - 0.03), (0.03, 0.55, 0.03), J(P["wood2"], 0.06), R, mat=M_WOOD)
        body.box(Pw(Pf, (u0 + u1) / 2, y + 0.58, dep - 0.03), (u1 - u0 + 0.04, 0.05, 0.06), J(P["wood"], 0.06), R, mat=M_WOOD)
        for s_ in (-1, 1):
            uu = u0 + 0.02 if s_ < 0 else u1 - 0.02
            for k in range(4):
                body.box(Pw(Pf, uu, y + 0.3, 0.06 + (dep - 0.12) * k / 3), (0.03, 0.55, 0.03), J(P["wood2"], 0.06), R, mat=M_WOOD)
            body.box(Pw(Pf, uu, y + 0.58, dep / 2), (0.05, 0.05, dep), J(P["wood"], 0.06), R, mat=M_WOOD)
        for k in range(2):
            pot(body, Pw(Pf, u0 + 0.2 + k * 0.32, y + 0.03, dep - 0.2), 0.22, J("#b8693f", 0.08))
        for k in range(5):
            leaf_blob(body, Pw(Pf, u0 + 0.1 + (u1 - u0 - 0.2) * k / 4, y + 0.45 - rng.uniform(0, 0.3), dep + 0.01), 0.05, J("#4f7d33", 0.12))
        mov("door", door_key(DS["door"], bu1 - bu0 - 0.1, 1.5), Pf(bu0 + 0.05, y + 0.02, -0.1), U, N, math.radians(70))
        block("front", Pf, U, u0, u1, y - 0.15, y + 0.65)
    # перед входом
    use("g")
    fr = DS.get("front")
    R = RW(U, N)
    if KIND == "shop" and DS.get("front") == "pergola":
        fr = "pergola"
    elif KIND in ("artisan", "shop"):
        fr = None
        su = shop_u
        if DS.get("awning"):
            awning(body, Pf, U, N, (su[0] + su[1]) / 2, PL + 1.98, su[1] - su[0] + 0.25, 0.75, DS["awning"], poles=False)
        elif DS.get("canopy"):
            canopy(body, Pf, U, N, (su[0] + su[1]) / 2, PL + (2.0 if FLOORS > 1 else 1.86), su[1] - su[0] + 0.2, 0.6)
        block("front", Pf, U, su[0] - 0.15, su[1] + 0.15, PL + 1.55, PL + 2.1)
    if KIND in ("patrician", "civic") and DS.get("dado"):
        for name in ("front", "left", "right"):
            Pd, Ud, Nd = Ps[name]
            Ln = W if name == "front" else D - 2 * T
            ops = opens[name]
            cuts = sorted([(o[0], o[1]) for o in ops if o[2] < PL + DS.get("dado_h", 0.78)])
            u = 0.0
            for (ca, cb) in cuts + [(Ln, Ln)]:
                if ca - u > 0.05:
                    dado(body, Pd, Ud, Nd, u, ca, DS.get("dado_h", 0.78), DS["dado"])
                u = cb
    if fr == "awning":
        awning(body, Pf, U, N, door_mid, PL + 1.82, 1.3, 0.7, ("#efe3c8", "#b5452f"))
        block("front", Pf, U, door_mid - 0.7, door_mid + 0.7, PL + 1.4, PL + 1.9)
    elif fr == "canopy" and not balcony:
        canopy(body, Pf, U, N, door_mid, PL + (1.9 if FLOORS > 1 else 1.74), 1.25, 0.55)
        block("front", Pf, U, door_mid - 0.7, door_mid + 0.7, PL + 1.5, PL + 2.0)
    elif fr == "pergola":
        pu0, pu1 = (door_u[0] - 0.35, min(W - 0.15, door_u[1] + 0.9)) if left else (max(0.15, door_u[0] - 0.9), door_u[1] + 0.35)
        if KIND == "shop":
            pu0, pu1 = 0.15, W - 0.15        # во весь фасад: под ней прилавок и столы
        pergola(body, Pf, U, N, pu0, pu1, PL + 1.75, 0.95)
        block("front", Pf, U, pu0, pu1, 0.0, PL + 2.0)
    props = DS.get("props", []) if KIND == "pleb" else []
    free_u = (win_u[0] + win_u[1]) / 2
    if "bench" in props:
        bench(body, Pw(Pf, free_u, 0.32, 0.32), 0.9, R)
    if "pots" in props:
        pot(body, Pw(Pf, 0.22, 0.0, 0.3), 0.32, J("#b8693f", 0.08))
        pot(body, Pw(Pf, door_u[1] + 0.25 if left else door_u[0] - 0.25, 0.0, 0.28), 0.24, J("#c27a4a", 0.08))
    if "pots2" in props:
        pot(body, Pw(Pf, W - 0.22, 0.0, 0.3), 0.28, J("#a95f36", 0.08))
    if "basket" in props:
        basket(body, Pw(Pf, free_u + (0.55 if left else -0.55), 0.0, 0.35), 0.13, 0.2)
    if "amphorae" in props:
        uu = door_u[0] - 0.3 if left and door_u[0] > 0.5 else (door_u[1] + 0.3 if not left else free_u + 0.6)
        amphora(body, Pw(Pf, uu, 0.0, 0.25), 0.6, J("#c27a4a", 0.08))
        amphora(body, Pw(Pf, uu + 0.24, 0.0, 0.2), 0.5, J("#b5703f", 0.08))
    if "broom" in props:
        bp_ = Pw(Pf, door_u[1] + 0.2 if left else door_u[0] - 0.2, 0.0, 0.12)
        body.box((bp_[0], 0.55, bp_[2]), (0.025, 1.0, 0.025), J(P["wood"], 0.05), Matrix.Rotation(0.12, 3, "Z"), mat=M_WOOD)
        body.lathe((bp_[0] - 0.02, 0.02, bp_[2]), [(0.09, 0), (0.06, 0.18), (0.02, 0.26)], 6, J("#c9a46e", 0.06))
    Pl, Ul, Nl = Ps["left"]
    if "firewood" in props:
        firewood(body, Pw(Pl, (D - 2 * T) * 0.62, 0.0, 0.18), RW(Ul, Nl) @ Matrix.Rotation(math.pi / 2, 3, "Y"), 11)
    if "laundry" in props:
        laundry(body, Pl, Ul, Nl, D - 2 * T, PL + 1.75 if FLOORS == 1 else PL + FLH + 1.6)
        block("left", Pl, Ul, 0.2, D - 2 * T - 0.2, PL + 1.2, PL + FLH + 1.8)
    if "ladder" in props:
        Pr, Ur, Nr = Ps["right"]
        ladder(body, Pr, Ur, Nr, (D - 2 * T) * 0.5, 1.85)
    if DS.get("ivy"):
        Pr, Ur, Nr = Ps["right"]
        ivy_patch(body, Pr, Ur, Nr, 0.1, 1.2, min(HT - PL - 0.3, 2.6))
    # заплаты кладки
    use("patch")
    spots = [(W * 0.55, PL + 0.45, 0.2), (0.25, PL + 1.6, 0.16)]
    if FLOORS > 1:
        spots.append((W - 0.3, PL + FLH + 0.5, 0.18))
    if DS.get("lower") != "brick" and KIND != "civic":      # у общественных зданий — роспись и камень, без заплат
        for (u, v, r) in spots:
            if not any(o[0] - 0.3 < u < o[1] + 0.3 and o[2] - 0.3 < v < o[3] + 0.3 for o in front_open):
                brick_patch(body, Pf, U, N, u, v, r)
        brick_patch(body, Pl, Ul, Nl, (D - 2 * T) * 0.3, PL + 0.6, 0.22)
    # крыша
    use("roof")
    along_x = DS["roof"] != "z"
    if DS["roof"] == "flat":
        y_ridge = flat_roof(body, x0, x1, z0, z1, HT, DS.get("domes", ()))
        rise = 0.0
        for (px, pz) in ((x0, z1), (x1, z1), (x0, z0), (x1, z0), (0.0, z1)):
            PERCH.append([round(px, 3), round(HT + 0.53, 3), round(pz, 3)])
    else:
        y_ridge, rise = roof(body, along_x, x0, x1, z0, z1, HT, pitch_deg=27.0 if along_x else 30.0)
        gable_walls(walls, inner, along_x, x0, x1, z0, z1, HT, rise)
    if not along_x:
        ring_c = J(P["trim"], 0.03)
        for k in range(10):
            a = 2 * math.pi * k / 10
            body.box((0.17 * math.cos(a), HT + rise * 0.4 + 0.17 * math.sin(a), z1 + 0.03), (0.08, 0.08, 0.05), ring_c, Matrix.Rotation(a, 3, "Z"))
        body.box((0.0, HT + rise * 0.4, z1 + 0.01), (0.26, 0.26, 0.02), col("#2a2018"))
    # роспись
    deco = []
    if DS.get("decal") == "notice":
        yv = PL + 1.2 if FLOORS == 1 else PL + FLH + 1.15
        uc = free_u if FLOORS == 1 else W / 2
        if FLOORS == 1:
            uc = (door_u[1] + win_u[0]) / 2 if left else (win_u[1] + door_u[0]) / 2
        deco.append(("Notice", uc, yv + (0.0 if FLOORS == 1 else 0.0), 0.62, 0.41, "NoticeMat", "notice.png", True, 1.0))
    elif DS.get("decal") == "frieze":
        deco.append(("Frieze", W / 2, HT - 0.34, W - 0.12, 0.24, "FriezeMat", "meander.png", False, max(1, round((W - 0.12) / 0.24 / 4.14))))
    for (name, uc, vc, w, h, mname, img, alpha, urep) in deco:
        mb = MB(name, [make_decal_mat(mname, img, alpha)])
        q = [Pf(uc - w / 2, vc - h / 2, 0.008), Pf(uc + w / 2, vc - h / 2, 0.008), Pf(uc + w / 2, vc + h / 2, 0.008), Pf(uc - w / 2, vc + h / 2, 0.008)]
        mb.face([mb.v(x) for x in q], (1, 1, 1, 1), ("dir", tuple(N)), uv=[(0, 0), (urep, 0), (urep, 1), (0, 1)])
        mb.obj(coll)
    fz0, fz1 = z0, z1
    fx0, fx1 = x0, x1
    if KIND == "civic":
        use("civic")
        fz0, fz1, fx0, fx1 = civic_front(body, walls, inner, emb, Ps["front"][0], Ps["front"][1], Ps["front"][2], x0, x1, z0, z1)
    if KIND == "shop" and DS.get("scribe"):
        fz1 = z1 + 1.35
        DOOR_PT[2] = z1 + 1.6
    if KIND == "shop" and DS.get("yard"):
        use("yard")
        yd = 1.0
        lean_to(body, x0 + 0.05, x1 - 0.05, z0, yd, PL + 1.75, PL + 1.35)
        yard_props(body, emb, x0, x1, z0 - yd, z0, DS["yard"])
        fz0 = z0 - yd - 0.1
    if KIND == "shop" and DS.get("tables"):
        y_tables(body, x0, x1, z1)
        fz1 = z1 + 2.3
        DOOR_PT[2] = fz1 + 0.3                 # вход — с улицы к столам (под перголой — уже «внутри»)
        ACTORS.append([round(x1 - 0.5, 3), 0.0, round(z1 + 2.0, 3), math.pi, "Idle", "any"])
    if KIND == "shop" and DS.get("front") == "pergola" and not DS.get("tables"):
        fz1 = z1 + 1.0
        DOOR_PT[2] = fz1 + 0.3
    if KIND == "artisan":
        use("yard")
        yd = 1.0
        lean_to(body, x0 + 0.05, x1 - 0.05, z0, yd, PL + 1.75, PL + 1.35)
        yard_props(body, emb, x0, x1, z0 - yd, z0, DS["craft"])
        fz0 = z0 - yd - 0.1
    if KIND == "patrician":
        use("portico")
        pw = 2.1 if DS["portico"] != "temple" else 2.8
        pd = 0.9
        portico(body, walls, inner, -pw / 2, pw / 2, z1, pd, DS["portico"], PL + 1.95)
        fz1 = z1 + pd + 0.15
        DOOR_PT[2] = z1 + pd + 0.45
        use("garden")
        gd = 1.85
        garden(body, x0 + 0.02, x1 - 0.02, z0 - gd, z0, V)
        fz0 = z0 - gd - 0.1
        # дверь в сад
        Pb, Ub, Nb = Ps["back"]
    objs = []
    for mb in (body, walls, inner, emb):
        if not mb.empty():
            objs.append(mb.obj(coll))
    FP.append([round(fx0 - 0.05, 3), round(fz0, 3), round(fx1 - fx0 + 0.1, 3), round(fz1 - fz0 + 0.05, 3)])
    return y_ridge


# =====================================================================================
#   ВЫГРУЗКА
# =====================================================================================
def clear_scene():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob)
    for me in list(bpy.data.meshes):
        if me.users == 0:
            bpy.data.meshes.remove(me)


def export_glb(path, objs=None):
    bpy.ops.object.select_all(action="DESELECT")
    for ob in (objs or bpy.context.scene.objects):
        if ob.type == "MESH":
            ob.select_set(True)
    tris = 0
    for ob in bpy.context.selected_objects:
        ob.data.calc_loop_triangles()
        tris += len(ob.data.loop_triangles)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True,
                              export_apply=True, export_vertex_color="ACTIVE", export_all_vertex_colors=False,
                              export_image_format="AUTO", export_materials="EXPORT")
    return tris


def preview(path, y_ridge):
    scn = bpy.context.scene
    m = bpy.data.materials.get("CivPlaster")
    tint = (1.0, 0.78, 0.47, 1.0)
    bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, -0.001))
    g = bpy.context.active_object
    gm = bpy.data.materials.get("Ground") or bpy.data.materials.new("Ground")
    gm.use_nodes = True
    gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = lin("#a89a78")
    g.data.materials.append(gm)
    walls = bpy.context.scene.objects.get("Walls")
    if walls:      # превью: стены цвета «охра» (в игре — цвет дома)
        wm = bpy.data.materials.get("PreviewWalls")
        if not wm:
            wm = make_plaster_mat().copy()
            wm.name = "PreviewWalls"
            nt = wm.node_tree
            mix = [n for n in nt.nodes if n.type == "MIX"][0]
            mul = nt.nodes.new("ShaderNodeMix")
            mul.data_type = "RGBA"
            mul.blend_type = "MULTIPLY"
            mul.inputs["Factor"].default_value = 1.0
            mul.inputs[7].default_value = lin("#ffc777")
            nt.links.new(mix.outputs[2], mul.inputs[6])
            nt.links.new(mul.outputs[2], nt.nodes["Principled BSDF"].inputs["Base Color"])
        walls.data.materials[1] = wm
    # створки — из библиотеки, на свои места
    for e in MOV:
        mb = MB("prev_" + e["mesh"])
        kind, ck, w, h, side, brace = CANON[e["mesh"]]
        (build_shutter(mb, ck, w, h, side, brace) if kind == "shutter" else build_door(mb, ck, w, h, side))
        ob = mb.obj(scn.collection)
        M3 = Matrix((e["x"], e["y"], e["z"])).transposed()
        G = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))
        ob.matrix_world = Matrix.Translation(MB.bl(e["o"])) @ (G @ M3 @ G.inverted()).to_4x4()
    if not bpy.data.objects.get("Sun"):
        sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
        sun.data.energy = 3.2
        sun.data.angle = math.radians(3)
        sun.data.color = (1.0, 0.95, 0.86)
        sun.rotation_euler = (math.radians(50), 0, math.radians(-35))
        scn.collection.objects.link(sun)
    scn.world = bpy.data.worlds.get("W") or bpy.data.worlds.new("W")
    scn.world.use_nodes = True
    bg = scn.world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = lin("#a9c3dc")
    bg.inputs["Strength"].default_value = 0.9
    cam = bpy.data.objects.get("Cam")
    if not cam:
        cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
        scn.collection.objects.link(cam)
    scn.camera = cam
    cam.data.lens = 50
    tgt = Vector((0.2, 0.0, y_ridge * 0.45))
    pos = tgt + Vector((5.2, -9.2, 5.6)) * (0.8 + 0.12 * FLOORS)
    cam.location = pos
    cam.rotation_euler = (tgt - pos).to_track_quat("-Z", "Y").to_euler()
    scn.render.resolution_x = 800
    scn.render.resolution_y = 760
    try:
        scn.render.engine = "BLENDER_EEVEE_NEXT"
    except TypeError:
        scn.render.engine = "BLENDER_EEVEE"
    try:
        scn.eevee.taa_render_samples = 32
    except Exception:
        pass
    scn.view_settings.view_transform = "AgX"
    scn.render.filepath = path
    m2 = bpy.data.materials.get("CivPlaster")
    bpy.ops.render.render(write_still=True)
    if ARGS.get("close", "0") == "1":
        # крупный план витрины: лавка, прилавок, вывеска (для проверки мелочей)
        tgt = Vector((0.0, -D / 2 - 0.2, 1.05)) if KIND != "stall" else Vector((0.0, 0.0, 1.0))
        cam.location = tgt + Vector((1.5, -3.3, 1.25)) * float(ARGS.get("zoom", "1.0"))
        cam.rotation_euler = (tgt - cam.location).to_track_quat("-Z", "Y").to_euler()
        scn.render.filepath = path.replace(".png", "_c.png")
        bpy.ops.render.render(write_still=True)


def plaster_for_export(on):
    return                     # «текстура × цвет вершин» через Mix — glTF понимает, перевязывать не нужно
    m = bpy.data.materials.get("CivPlaster")
    if not m:
        return
    nt = m.node_tree
    if on:
        nt.links.new(nt.nodes["PlasterTex"].outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])
    else:
        mix = [n for n in nt.nodes if n.type == "MIX"][0]
        nt.links.new(mix.outputs[2], nt.nodes["Principled BSDF"].inputs["Base Color"])


def main():
    global MAT_KIT, MAT_PLASTER, MAT_EMBER, MAT_WOOD, MAT_CLOTH, MAT_SIGN, MAT_FRESCO, MAT_MARBLE, MAT_STONE, MAT_BANNER, WALL_MATS, MAT_ASHM
    os.makedirs(OUT_DIR, exist_ok=True)
    meta_path = os.path.join(OUT_DIR, "kit.json")
    meta = {"houses": {}, "common": []}
    if META_ONLY and os.path.exists(meta_path):
        with open(meta_path, encoding="utf-8") as f:
            meta = json.load(f)
    clear_scene()
    MAT_KIT = make_mat("CivKit", 0.85)
    MAT_PLASTER = make_plaster_mat()
    MAT_EMBER = make_mat("CivEmber", 0.5, emit=(1.0, 0.45, 0.1, 1.0))
    MAT_WOOD = make_tex_mat("CivWood", "wood_mul.png", 0.8)
    MAT_CLOTH = make_tex_mat("CivCloth", "cloth_mul.png", 0.95)
    MAT_SIGN = make_tex_mat("CivSign", "signs.png", 0.8)
    MAT_FRESCO = make_tex_mat("CivFresco", "fresco.png", 0.85)
    MAT_MARBLE = make_tex_mat("CivMarble", "marble_mul.png", 0.5)
    MAT_STONE = make_tex_mat("CivStone", "stone_mul.png", 0.9)
    MAT_BANNER = make_tex_mat("CivBanner", "banners.png", 0.95)
    WALL_MATS = {"ashlar": make_tex_mat("CivAshlarT", "ashlar_trav.png", 0.85), "marble": make_tex_mat("CivAshlarM", "ashlar_marble.png", 0.55),
                 "brick": make_tex_mat("CivBrickW", "brick_wall.png", 0.9)}
    MAT_ASHM = WALL_MATS["marble"]
    jobs = []
    if "pleb" in KINDS:
        for v in range(5):
            for fl in (1, 2, 3):
                jobs.append(("pleb", v, fl))
    if "artisan" in KINDS:
        for v in range(5):
            for fl in (1, 2, 3):
                jobs.append(("artisan", v, fl))
    if "patrician" in KINDS:
        for v in range(6):
            for fl in ((1, 2) if v < 4 else (1, 2, 3)):
                jobs.append(("patrician", v, fl))
    if "shop" in KINDS:
        for t in TRADES:
            jobs.append(("shop", t, 0))
    if "stall" in KINDS:
        for t in ("fruit", "veg", "fish"):
            jobs.append(("stall", t, 0))
    if "civic" in KINDS:
        for t in CIVIC:
            jobs.append(("civic", t, 0))
    all_canon = {}
    for (kind, v, fl) in jobs:
        hid = ("%s_%s" % (kind, v)) if kind in ("shop", "stall") else ("civ_" + v if kind == "civic" else "%s_%d_%d" % (kind, v, fl))
        if ONLY and hid not in ONLY:
            continue
        clear_scene()
        configure(kind, v, fl)
        y_ridge = build_stall(v) if kind == "stall" else build_house()
        plaster_for_export(True)
        kit_for_export(True)
        tris = export_glb(os.path.join(OUT_DIR, hid + ".glb"))
        kit_for_export(False)
        faces = []
        for side, f in FACES.items():
            f = dict(f)
            f["block"] = f["block"] + EXTRA_BLOCK.get(side, [])
            f["side"] = side
            faces.append(f)
        meta["houses"][hid] = {"w": W, "d": D, "ht": HT, "ridge": round(y_ridge, 3), "floors": FLOORS, "tris": tris,
                               "parts": [o.name for o in bpy.context.scene.objects if o.type == "MESH"],
                               "mov": MOV, "door": [round(x, 3) for x in DOOR_PT], "fp": FP, "faces": faces,
                               "lights": LIGHTS, "perch": [[round(c, 3) for c in p] for p in PERCH],
                               "smoke": SMOKE, "actors": ACTORS, "props": PROPS}
        if kind == "civic":
            meta["houses"][hid]["tint"] = DS.get("tint", "#f3ebdf")
        if PETS_K:
            meta["houses"][hid]["pets"] = [[e[0], [round(c / 0.72, 3) for c in e[1]]] + e[2:] for e in PETS_K]
        all_canon.update(CANON)
        print("KIT", hid, "tris", tris, "mov", len(MOV))
        if PNG:
            os.makedirs(PREV, exist_ok=True)
            plaster_for_export(False)
            preview(os.path.join(PREV, hid + ".png"), y_ridge)
    # общие створки
    known = set(meta.get("common", []))
    known.update(all_canon.keys())
    clear_scene()
    objs = []
    canon_all = dict(all_canon)
    for k in sorted(known):
        if k not in canon_all:
            # створка из прошлой выгрузки — восстановим по имени
            parts = k.split("_")
            if parts[0] == "sh":
                canon_all[k] = ("shutter", parts[1], int(parts[2]) / 100, int(parts[3]) / 100, -1 if parts[4] == "L" else 1, True)
            else:
                canon_all[k] = ("door", parts[1], int(parts[2]) / 100, int(parts[3]) / 100, -1 if k.endswith("_M") else 1, False)
        kind, ck, w, h, side, brace = canon_all[k]
        mb = MB(k)
        if kind == "shutter":
            build_shutter(mb, ck, w, h, side, brace)
        else:
            build_door(mb, ck, w, h, side)
        objs.append(mb.obj(bpy.context.scene.collection))
    kit_for_export(True)
    tris = export_glb(os.path.join(OUT_DIR, "common.glb"), objs)
    meta["common"] = sorted(known)
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False, separators=(",", ":"))
    print("KIT common", len(known), "tris", tris)


if __name__ == "__main__":
    main()
