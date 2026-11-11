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
        self.mats = mats if mats is not None else [MAT_KIT, MAT_PLASTER]

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

    def box(self, ctr, size, c, rot=None, cols=None, skip=()):
        hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
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
        for k, idx in F.items():
            if k in skip:
                continue
            cc = (cols or {}).get(k, c)
            self.face([pts[i] for i in idx], cc, ("from", C))
        return pts

    def lathe(self, at, prof, seg, c, cols=None, close_top=False):
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
                self.face([a, b, d, e], cc, ("from", mid))
        self.face(rings[0][::-1], c, ("dir", (0, -1, 0)))
        if close_top:
            self.face(rings[-1], cols[-1] if cols else c, ("dir", (0, 1, 0)))

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
    if name != "CivPlaster":
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
                   "block": [[u_base + a - 0.12, c - 0.1, b - a + 0.24, d - c + 0.22] for (a, b, c, d) in openings]}
    return P


def block(side, P_, U, u0, u1, v0, v1):
    """выступ на стене side (навес, балкон, ящик цветов) — туда настенное украшение не вешать"""
    o = P_(0, 0, 0)
    base = o.dot(U)
    EXTRA_BLOCK.setdefault(side, []).append([base + min(u0, u1), v0, abs(u1 - u0), v1 - v0])


# ---------------- створки (общие) ----------------
SHUTTER_COLS = {"green": "#5f7f4a", "blue": "#4f6f8f", "brown": "#7a5232", "teal": "#4f8a80", "red": "#8f3f33",
                "ochre": "#b07a35"}
DOOR_COLS = {"oak": "#6b4428", "dark": "#4f3020", "green": "#4a6040", "blue": "#3f5670", "red": "#7a3528"}


def mov(kind, key, hinge, U, N, open_a, side=1):
    """записать створку: ось — на петле; open_a — угол раскрытия (вокруг вертикали)"""
    Rw = RW(U, N)
    sgn = side if kind == "shutter" else 1
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


def door_key(colkey, w, h):
    k = "door_%s_%d_%d" % (colkey, round(w * 100), round(h * 100))
    CANON[k] = ("door", colkey, w, h, 1, False)
    return k


def build_shutter(mb, colkey, w, h, side, brace):
    base_col = SHUTTER_COLS[colkey]
    r = random.Random(seed_of("sh", colkey, w, h, side))
    jj = lambda hx, v=0.1: col(hx, r.uniform(-v, v), r.uniform(-0.01, 0.01), r.uniform(-0.1, 0.1))
    nb = 3
    for k in range(nb):
        x = (k + 0.5) * w / nb
        mb.box((x * -side, h / 2, 0.0), (w / nb - 0.008, h, 0.045), jj(base_col))
    for vv in (0.17, 0.83):
        mb.box((w / 2 * -side, h * vv, 0.03), (w * 0.94, 0.07, 0.022), col(base_col, -0.18))
    if brace:
        p0 = Vector((0.08 * -side, h * 0.22, 0.03))
        p1 = Vector(((w - 0.08) * -side, h * 0.78, 0.03))
        dl = (p1 - p0)
        ang = math.atan2(dl.y, dl.x)
        mb.box(tuple((p0 + p1) / 2), (dl.length, 0.06, 0.02), col(base_col, -0.2), Matrix.Rotation(ang, 3, "Z"))
    for vv in (0.17, 0.83):
        mb.box((0.02 * -side, h * vv, 0.035), (0.06, 0.03, 0.012), col("#2b2622"))


def build_door(mb, colkey, w, h):
    base = DOOR_COLS[colkey]
    r = random.Random(seed_of("door", colkey, w, h))
    jj = lambda hx, v=0.1: col(hx, r.uniform(-v, v), r.uniform(-0.01, 0.01), r.uniform(-0.1, 0.1))
    nb = 4
    for k in range(nb):
        x = (k + 0.5) * w / nb
        mb.box((x, h / 2, 0.0), (w / nb - 0.008, h, 0.05), jj(base))
    for vv in (0.15, 0.5, 0.85):
        mb.box((w / 2, h * vv, 0.032), (w * 0.95, 0.07, 0.02), col(base, -0.2))
    for k in range(nb):
        for vv in (0.15, 0.5, 0.85):
            mb.box(((k + 0.5) * w / nb, h * vv, 0.046), (0.018, 0.018, 0.012), col("#3a332c"))
    mb.box((w * 0.78, h * 0.52, 0.06), (0.05, 0.05, 0.02), col("#8a6a35"))


# ---------------- детали фасада ----------------
def window(body, P_, U, N, side, u0, u1, v0, v1, shutters=True, box=False, grille=False, surround=False, open_k=None):
    w = u1 - u0
    h = v1 - v0
    Rw = RW(U, N)
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
        body.box(Pw(P_, cu, cv, dep), (su, sv, 0.05), c_w, Rw)
    if grille:
        for k in range(1, 3):
            body.box(Pw(P_, (u0 + u1) / 2, v0 + h * k / 3, dep), (w, 0.025, 0.035), c_w, Rw)
    body.box(Pw(P_, (u0 + u1) / 2, v0 - 0.045, 0.04), (w + 0.24, 0.09, T * 0.5 + 0.12), J(P["stone"], 0.05), Rw,
             cols={"top": J(P["stone"], 0.03, 0, 0)})
    if not surround:
        body.box(Pw(P_, (u0 + u1) / 2, v1 + 0.05, 0.015), (w + 0.2, 0.1, 0.1), J(P["wood2"], 0.06), Rw)
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
    mb.box(Pw(P_, uc, vtop - 0.09, 0.13), (w, 0.16, 0.18), c, Rw)
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
            body.box(Pw(P_, cu, (c + d) / 2, -0.05), (0.09, d - c, 0.1), J(P["stone"], 0.06), R)
        body.box(Pw(P_, (a + b) / 2, d + 0.07, 0.02), (b - a + 0.3, 0.14, 0.14), J(P["stone"], 0.06), R,
                 cols={"top": J(P["stone"], 0.1)})
    else:
        body.box(Pw(P_, (a + b) / 2, d + 0.05, 0.015), (b - a + 0.24, 0.1, 0.1), J(P["wood2"], 0.06), R)
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
            mb.box(tuple((p0 + p1) / 2), (0.07, 0.09, (p1 - p0).length), J(P["wood"], 0.08), Matrix((Uv, Nv, dirv)).transposed())
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
    # верхний край — каменный поясок
    mb.box(Pw(P_, (u0 + u1) / 2, v1 + 0.02, 0.03), (u1 - u0 + 0.02, 0.05, 0.06), J(P["stone"], 0.05), R)


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
    mb.box(at, (ln, 0.04, 0.24), J(P["wood"], 0.06), R)
    for s in (-1, 1):
        o = R @ Vector((s * (ln / 2 - 0.08), -0.13, 0))
        mb.box((at[0] + o.x, at[1] + o.y, at[2] + o.z), (0.05, 0.24, 0.2), J(P["wood2"], 0.06), R)


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


def awning(mb, P_, U, N, uc, v, w, depth, cols2, poles=True):
    nu, nd = 6, 3
    R = RW(U, N)
    grid = {}
    for i in range(nu + 1):
        for j in range(nd + 1):
            u = uc - w / 2 + w * i / nu
            d = depth * j / nd
            sag = 0.06 * math.sin(math.pi * i / nu) * (j / nd)
            grid[(i, j)] = mb.v(Pw(P_, u, v - d * 0.45 - sag, 0.02 + d))
    for i in range(nu):
        cc = col(cols2[i % 2], rng.uniform(-0.04, 0.04))
        for j in range(nd):
            q = [grid[(i, j)], grid[(i + 1, j)], grid[(i + 1, j + 1)], grid[(i, j + 1)]]
            mb.face(q, cc, ("dir", (0, 1, 0)))
            mb.face(q[::-1], col_shift(cc, -0.25), ("dir", (0, -1, 0)))
    for i in range(nu):
        u0 = uc - w / 2 + w * i / nu
        u1 = u0 + w / nu
        y = v - depth * 0.45
        a = mb.v(Pw(P_, u0, y - 0.06 * math.sin(math.pi * i / nu), 0.02 + depth))
        b = mb.v(Pw(P_, u1, y - 0.06 * math.sin(math.pi * (i + 1) / nu), 0.02 + depth))
        m = mb.v(Pw(P_, (u0 + u1) / 2, y - 0.12 - 0.06 * math.sin(math.pi * (i + 0.5) / nu), 0.02 + depth))
        mb.face([a, b, m], col(cols2[i % 2], -0.05), ("dir", tuple(N)))
        mb.face([b, a, m], col(cols2[i % 2], -0.3), ("dir", tuple(-N)))
    if poles:
        for s in (-1, 1):
            top = Pw(P_, uc + s * w / 2, v - depth * 0.45 - 0.02, depth + 0.02)
            mb.box((top[0], top[1] / 2, top[2]), (0.045, top[1], 0.045), J(P["wood"], 0.05), R)
    else:
        for s in (-1, 1):       # подкосы к стене
            p0 = Vector(Pw(P_, uc + s * (w / 2 - 0.05), v - 0.55, 0.02))
            p1 = Vector(Pw(P_, uc + s * (w / 2 - 0.05), v - depth * 0.45, depth))
            dl = p1 - p0
            Rr = Matrix((U, dl.normalized().cross(U).normalized(), dl.normalized())).transposed()
            mb.box(tuple((p0 + p1) / 2), (0.04, 0.04, dl.length), J(P["wood2"], 0.05), Rr)


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
        mb.box(tuple((p0 + p1) / 2), (0.06, 0.06, dl.length), J(P["wood2"], 0.05), Rr)
        mb.box(Pw(P_, uc + s * (w / 2 - 0.08), v - depth * math.tan(a) * 0.5, depth * 0.5), (0.07, 0.07, depth), J(P["wood"], 0.05), R)


def pergola(mb, P_, U, N, u0, u1, h, depth):
    """деревянная пергола перед фасадом с виноградной лозой"""
    R = RW(U, N)
    for uu in (u0, u1):
        top = Pw(P_, uu, h, depth)
        mb.box((top[0], h / 2, top[2]), (0.09, h, 0.09), J(P["wood"], 0.06), R)
    mb.box(Pw(P_, (u0 + u1) / 2, h + 0.04, depth), (u1 - u0 + 0.3, 0.09, 0.09), J(P["wood"], 0.06), R)
    nb = int((u1 - u0) / 0.32) + 1
    for k in range(nb):
        uu = u0 + (u1 - u0) * k / max(1, nb - 1)
        mb.box(Pw(P_, uu, h + 0.12, depth / 2), (0.06, 0.07, depth + 0.3), J(P["wood2"], 0.06), R)
    # лоза: густые листья поверху, свисающие плети, грозди
    for k in range(int((u1 - u0) * depth * 70)):
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
        mb.box(Pw(P_, uu, y, 0.17), (0.03, 0.03, 0.36), J(P["wood"], 0.05), R)
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
        mb.box((lp.x + o.x, o.y, lp.z + o.z), (0.04, h, 0.04), J(P["wood"], 0.06), R)
    for k in range(int(h / 0.3)):
        o = R @ Vector((0, 0.2 + k * 0.3, 0))
        mb.box((lp.x + o.x, o.y, lp.z + o.z), (0.34, 0.03, 0.03), J(P["wood"], 0.06), R)


def interior(mb, emb, x0, x1, z0, z1, y, floor_k):
    n = int((x1 - x0) / 0.18)
    for i in range(n):
        u0 = x0 + (x1 - x0) * i / n
        mb.box(((u0 + (x1 - x0) / n / 2), y + 0.02, (z0 + z1) / 2), ((x1 - x0) / n - 0.006, 0.04, z1 - z0),
               J(P["wood2"], 0.12, 0.01, 0.1), skip=("bot",))
    if floor_k == 0:
        hx, hz = x0 + 0.35, z0 + 0.3
        mb.box((hx, y + 0.18, hz), (0.6, 0.32, 0.45), J(P["stone"], 0.08), cols={"top": col("#3a2e26")}, skip=("bot",))
        for k in range(5):
            leaf_blob(emb, (hx + rng.uniform(-0.15, 0.15), y + 0.37, hz + rng.uniform(-0.1, 0.1)), 0.04,
                      col(rng.choice(["#ff7a1a", "#ffb03a", "#e8461c"])))
        mb.lathe((hx, y + 0.36, hz), [(0.12, 0), (0.15, 0.1), (0.12, 0.18)], 8, col("#3d3530"))
        tx, tz = (x0 + x1) / 2 + 0.25, (z0 + z1) / 2 - 0.2
        mb.box((tx, y + 0.52, tz), (0.8, 0.05, 0.5), J(P["wood"], 0.05))
        for sx in (-1, 1):
            for sz in (-1, 1):
                mb.box((tx + sx * 0.33, y + 0.26, tz + sz * 0.19), (0.05, 0.5, 0.05), J(P["wood2"], 0.05))
        mb.lathe((tx - 0.15, y + 0.55, tz), [(0.06, 0), (0.1, 0.05), (0.11, 0.06)], 8, col("#b8693f"))
        amphora(mb, (x1 - 0.2, y + 0.04, z0 + 0.25), 0.55, J("#c27a4a", 0.08))
        amphora(mb, (x1 - 0.42, y + 0.04, z0 + 0.22), 0.5, J("#b5703f", 0.08))
        mb.box((x1 - 0.06, y + 1.05, (z0 + z1) / 2), (0.1, 0.03, 0.9), J(P["wood"], 0.05))
        for k in range(3):
            mb.lathe((x1 - 0.07, y + 1.07, (z0 + z1) / 2 - 0.3 + 0.3 * k), [(0.04, 0), (0.06, 0.07), (0.04, 0.12)], 7,
                     J(rng.choice(["#b8693f", "#c9a46e", "#7d8f99"]), 0.08))
    else:
        bx, bz = x0 + 0.5, z0 + 0.6
        mb.box((bx, y + 0.22, bz), (0.85, 0.3, 1.25), J(P["wood"], 0.05))
        mb.box((bx, y + 0.42, bz + 0.1), (0.8, 0.1, 1.0), J("#b0413e", 0.08))
        mb.box((bx, y + 0.43, bz - 0.48), (0.7, 0.1, 0.22), J("#efe6d2", 0.04))
        mb.box((x1 - 0.35, y + 0.22, z0 + 0.3), (0.55, 0.4, 0.35), J(P["wood"], 0.08), cols={"top": J(P["wood2"], 0.05)})
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


def configure(kind, v, floors):
    global KIND, V, FLOORS, W, D, HT, PH, P, DS, MOV, FACES, EXTRA_BLOCK, LIGHTS, PERCH, DOOR_PT, FP
    KIND, V, FLOORS = kind, v, floors
    W = 3.6
    D = 4.2
    HT = PL + FLOORS * FLH
    use("ph")
    PH = [rng.uniform(0, 6.28) for _ in range(5)]
    DS = dict(PLEB[v % len(PLEB)]) if kind == "pleb" else {}
    P = dict(PALS[DS.get("pal", 0)])
    MOV, FACES, EXTRA_BLOCK, LIGHTS, PERCH, FP = [], {}, {}, [], [], []
    DOOR_PT = [0, 0, D / 2 + 0.3]


def build_pleb():
    """дом плебеев: коробка W×D, этажи 1–3; облик — PLEB[V]"""
    coll = bpy.context.scene.collection
    x0, x1 = -W / 2, W / 2
    z0, z1 = -D / 2, D / 2
    body = MB("House")
    walls = MB("Walls")
    inner = MB("Rooms")
    emb = MB("Embers", [MAT_EMBER])
    use("g")
    left = (V + (1 if FLOORS else 0)) % 2 == 0          # дверь слева (u 0.55…1.37) или справа
    door_u = (0.55, 1.37) if left else (W - 1.37, W - 0.55)
    win_u = (W - 1.25, W - 0.6) if left else (0.6, 1.25)
    front_open = [(door_u[0], door_u[1], PL, PL + 1.52)]
    wins = []           # (сторона, u0, u1, v0, v1, ставни, ящик, наличник, решётка)
    wins.append(("front", win_u[0], win_u[1], PL + 0.78, PL + 1.5, True, DS.get("boxes", False), True, False))
    balcony = None
    for f in range(1, FLOORS):
        use("f%d" % f)
        y = PL + f * FLH
        if f == 1 and DS.get("balcony"):
            bu = (door_u[0] + 0.05, door_u[1] - 0.05)
            front_open.append((bu[0], bu[1], y + 0.02, y + 1.55))
            balcony = (bu, y)
            wins.append(("front", win_u[0], win_u[1], y + 0.72, y + 1.48, True, False, True, False))
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
            body.box((0, y - 0.07, 0), (W - 2 * T + 0.02, 0.1, D - 2 * T + 0.02), col(P["wood2"], -0.2))
            nb = int(W / 0.5)
            for k in range(nb):
                bx = x0 + 0.3 + (W - 0.6) * k / max(1, nb - 1)
                if any(o[0] - 0.08 < bx - x0 < o[1] + 0.08 and o[2] - 0.2 < y < o[3] + 0.2 for o in front_open):
                    continue
                body.box((bx, y - 0.1, z1 + 0.05), (0.11, 0.11, 0.14), J(P["wood"], 0.1), cols={"pz": J(P["wood2"], 0.1)})
            for name, (O, U, N, Ln) in walls_def.items():
                Pf = Ps[name][0]
                ext = T if name in ("left", "right") else 0.0
                body.box(Pw(Pf, Ln / 2, y + 0.03, 0.025), (Ln + 2 * ext + 0.06, 0.06, 0.05), J(P["trim"], 0.04), RW(U, N))
    body.box((0, PL - 0.02, 0), (W - 0.02, 0.06, D - 0.02), col(P["wood2"], -0.3))
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
        s, a, b, c, d, sh, bx, sur, gr = wv
        use("w%s%d%d" % (s, int(a * 10), int(c * 10)))
        Pf_, U_, N_ = Ps[s]
        window(body, Pf_, U_, N_, s, a, b, c, d, shutters=sh, box=bx, grille=gr, surround=sur)
    # дверь
    use("g")
    door(body, Pf, U, N, "front", door_u[0], door_u[1], PL, PL + 1.52, DS["door"], stone=not DS.get("arch"), arch=DS.get("arch", False))
    door_mid = (door_u[0] + door_u[1]) / 2
    DOOR_PT[0] = x0 + door_mid
    DOOR_PT[2] = z1 + 0.35
    # фонарик у двери (в игре — «#wall_lamp_dim», ночью еле теплится)
    lu = door_u[1] + 0.22 if left else door_u[0] - 0.22
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
            body.box(Pw(Pf, uu, y - 0.06, dep / 2), (0.09, 0.1, dep + 0.1), J(P["wood"], 0.08), R)
        nbp = int((u1 - u0) / 0.12)
        for k in range(nbp):
            uu = u0 + (u1 - u0) * (k + 0.5) / nbp
            body.box(Pw(Pf, uu, y + 0.01, dep / 2), ((u1 - u0) / nbp - 0.008, 0.035, dep), J(P["wood"], 0.12, 0.01, 0.1), R)
        nr = int((u1 - u0) / 0.13)
        for k in range(nr + 1):
            uu = u0 + 0.02 + (u1 - u0 - 0.04) * k / nr
            body.box(Pw(Pf, uu, y + 0.3, dep - 0.03), (0.03, 0.55, 0.03), J(P["wood2"], 0.06), R)
        body.box(Pw(Pf, (u0 + u1) / 2, y + 0.58, dep - 0.03), (u1 - u0 + 0.04, 0.05, 0.06), J(P["wood"], 0.06), R)
        for s_ in (-1, 1):
            uu = u0 + 0.02 if s_ < 0 else u1 - 0.02
            for k in range(4):
                body.box(Pw(Pf, uu, y + 0.3, 0.06 + (dep - 0.12) * k / 3), (0.03, 0.55, 0.03), J(P["wood2"], 0.06), R)
            body.box(Pw(Pf, uu, y + 0.58, dep / 2), (0.05, 0.05, dep), J(P["wood"], 0.06), R)
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
    if fr == "awning":
        awning(body, Pf, U, N, door_mid, PL + 1.82, 1.3, 0.7, ("#efe3c8", "#b5452f"))
        block("front", Pf, U, door_mid - 0.7, door_mid + 0.7, PL + 1.4, PL + 1.9)
    elif fr == "canopy" and not balcony:
        canopy(body, Pf, U, N, door_mid, PL + (1.9 if FLOORS > 1 else 1.74), 1.25, 0.55)
        block("front", Pf, U, door_mid - 0.7, door_mid + 0.7, PL + 1.5, PL + 2.0)
    elif fr == "pergola":
        pu0, pu1 = (door_u[0] - 0.35, min(W - 0.15, door_u[1] + 0.9)) if left else (max(0.15, door_u[0] - 0.9), door_u[1] + 0.35)
        pergola(body, Pf, U, N, pu0, pu1, PL + 1.75, 0.95)
        block("front", Pf, U, pu0, pu1, 0.0, PL + 2.0)
    props = DS.get("props", [])
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
        body.box((bp_[0], 0.55, bp_[2]), (0.025, 1.0, 0.025), J(P["wood"], 0.05), Matrix.Rotation(0.12, 3, "Z"))
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
    if DS.get("lower") != "brick":
        for (u, v, r) in spots:
            if not any(o[0] - 0.3 < u < o[1] + 0.3 and o[2] - 0.3 < v < o[3] + 0.3 for o in front_open):
                brick_patch(body, Pf, U, N, u, v, r)
        brick_patch(body, Pl, Ul, Nl, (D - 2 * T) * 0.3, PL + 0.6, 0.22)
    # крыша
    use("roof")
    along_x = DS["roof"] == "x"
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
    objs = []
    for mb in (body, walls, inner, emb):
        if not mb.empty():
            objs.append(mb.obj(coll))
    FP.append([x0 - 0.05, z0 - 0.05, W + 0.1, D + 0.1])
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
        (build_shutter(mb, ck, w, h, side, brace) if kind == "shutter" else build_door(mb, ck, w, h))
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
    global MAT_KIT, MAT_PLASTER, MAT_EMBER
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
    jobs = []
    if "pleb" in KINDS:
        for v in range(5):
            for fl in (1, 2, 3):
                jobs.append(("pleb", v, fl))
    all_canon = {}
    for (kind, v, fl) in jobs:
        hid = "%s_%d_%d" % (kind, v, fl)
        if ONLY and hid not in ONLY:
            continue
        clear_scene()
        configure(kind, v, fl)
        y_ridge = build_pleb()
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
                               "lights": LIGHTS, "perch": [[round(c, 3) for c in p] for p in PERCH]}
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
                canon_all[k] = ("door", parts[1], int(parts[2]) / 100, int(parts[3]) / 100, 1, False)
        kind, ck, w, h, side, brace = canon_all[k]
        mb = MB(k)
        if kind == "shutter":
            build_shutter(mb, ck, w, h, side, brace)
        else:
            build_door(mb, ck, w, h)
        objs.append(mb.obj(bpy.context.scene.collection))
    kit_for_export(True)
    tris = export_glb(os.path.join(OUT_DIR, "common.glb"), objs)
    meta["common"] = sorted(known)
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False, separators=(",", ":"))
    print("KIT common", len(known), "tris", tris)


if __name__ == "__main__":
    main()
