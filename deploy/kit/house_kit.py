# CivCity — свой набор деталей для домов (Blender 4.5, без окна).
# Владелец 11.11: «домики узкие, мало деталей; хочу черепицу как у нейросети, объёмные окна, ставни открываются,
# люди заходят внутрь». Этот скрипт строит дом целиком из деталей: цоколь из камней, стены с неровной штукатуркой,
# окна в глубине стены (рама, подоконник, перемычка, ставни на петлях), дверь, балки перекрытий, балкон,
# крышу из отдельных черепиц (плоские tegula + полукруглые imbrex, конёк, антефиксы), комнату внутри.
# Ставни, двери и навес — отдельные узлы с осью на петле (в игре их можно открывать).
#
#   bash tools/blender.sh -b --factory-startup -P deploy/kit/house_kit.py -- out=D:/x/pleb_A2.glb kind=pleb look=A floors=2 seed=3 [png=1]
#
# Координаты в коде — как в игре: x вправо, y вверх, z к улице (дверь на +z). Метры игры (этаж 2,1 м, человечек 1,1 м).
import bpy, bmesh, math, random, sys, os, colorsys
from mathutils import Vector, Matrix

ARGS = {}
if "--" in sys.argv:
    for a in sys.argv[sys.argv.index("--") + 1:]:
        if "=" in a:
            k, v = a.split("=", 1)
            ARGS[k] = v

KIND = ARGS.get("kind", "pleb")
LOOK = ARGS.get("look", "A")
FLOORS = int(ARGS.get("floors", "1"))
SEED = int(ARGS.get("seed", "1"))
OUT = ARGS.get("out", "D:/CivCity/.work/kit/out/house.glb")
PNG = ARGS.get("png", "1") == "1"
OPEN = float(ARGS.get("open", "1"))          # 1 — ставни открыты (день), 0 — закрыты
rng = random.Random(SEED * 7919 + FLOORS)

# ---------------- размеры ----------------
W = float(ARGS.get("w", "3.6"))      # фасад (было 2,82 — «узкие»)
D = float(ARGS.get("d", {"pleb": "4.2", "artisan": "5.0", "patrician": "7.35"}.get(KIND, "4.2")))
FLH = 2.1                            # этаж
PL = 0.24                            # цоколь
T = 0.22                             # толщина стены
HT = PL + FLOORS * FLH               # верх стен


def lin(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple((x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4) for x in c) + (1.0,)


def col(h, dv=0.0, dh=0.0, ds=0.0):
    """цвет '#rrggbb' с поправкой яркости/оттенка/насыщенности → линейный RGBA"""
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


# палитра облика
LOOKS = {
    "A": {"plaster": "#d9a35e", "plaster2": "#c98f4c", "trim": "#e6d3ad", "wood": "#7a5232", "wood2": "#5e3d24",
          "shutter": "#5f7f4a", "door": "#6b4428", "tile": "#b85f38", "stone": "#c2ae8e"},
    "B": {"plaster": "#e2c2a2", "plaster2": "#d4a090", "trim": "#eadbc0", "wood": "#80583a", "wood2": "#5a3a22",
          "shutter": "#4f6f8f", "door": "#5c3b26", "tile": "#c0683e", "stone": "#c4b49a"},
}
P = LOOKS.get(LOOK, LOOKS["A"])


# ---------------- построитель сетки ----------------
class MB:
    """bmesh с цветом вершин (угловой атрибут Col), точки — в осях игры"""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.cl = self.bm.loops.layers.float_color.new("Col")
        self.uvl = self.bm.loops.layers.uv.new("UVMap")
        self.mats = [MAT_KIT, MAT_PLASTER]

    @staticmethod
    def bl(p):
        return Vector((p[0], -p[2], p[1]))

    def v(self, p):
        return self.bm.verts.new(self.bl(p))

    def face(self, vs, c, out=None, uv=None, mat=0):
        """out — точка/направление: нормаль грани должна смотреть ОТ точки (out=("from", p)) или ПО направлению"""
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

    def box(self, ctr, size, c, rot=None, cols=None):
        """коробка: центр, размер (sx, sy, sz), цвет; rot — Matrix 3×3 в осях игры; cols — {'top': цвет,...}"""
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
            cc = (cols or {}).get(k, c)
            self.face([pts[i] for i in idx], cc, ("from", C))
        return pts

    def poly_prism(self, ring, y0, y1, c, ctop=None):
        """призма по кольцу точек (x, z) от y0 до y1"""
        n = len(ring)
        lo = [self.v((x, y0, z)) for x, z in ring]
        hi = [self.v((x, y1, z)) for x, z in ring]
        cx = sum(p[0] for p in ring) / n
        cz = sum(p[1] for p in ring) / n
        ctr = (cx, (y0 + y1) / 2, cz)
        for i in range(n):
            j = (i + 1) % n
            self.face([lo[i], lo[j], hi[j], hi[i]], c, ("from", ctr))
        self.face(hi[::-1], ctop or c, ("dir", (0, 1, 0)))
        self.face(lo, c, ("dir", (0, -1, 0)))

    def lathe(self, at, prof, seg, c, cols=None, close_top=False):
        """тело вращения: prof — [(r, y)...] снизу вверх; at — низ по центру"""
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

    def obj(self, coll, origin=None):
        me = bpy.data.meshes.new(self.name)
        self.bm.normal_update()
        self.bm.to_mesh(me)
        self.bm.free()
        ob = bpy.data.objects.new(self.name, me)
        coll.objects.link(ob)
        for m in self.mats:
            ob.data.materials.append(m)
        if origin is not None:
            o = Vector((origin[0], -origin[2], origin[1]))
            ob.data.transform(Matrix.Translation(-o))
            ob.location = o
        return ob


def rot_y(a):
    return Matrix.Rotation(a, 3, "Z")       # поворот вокруг вертикали игры (в Blender — Z)


def game_rot(axis, a):
    """поворот в осях игры: axis 'x' | 'y' | 'z'"""
    # ось игры x = Blender x; y игры = Blender z; z игры = −Blender y; матрица в осях игры строится сопряжением
    m = {"x": Matrix.Rotation(a, 3, "X"), "y": Matrix.Rotation(a, 3, "Y"), "z": Matrix.Rotation(a, 3, "Z")}[axis]
    return m


# ---------------- материалы ----------------
def make_mat(name, rough=0.85, emit=None):
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
    return m


TEX = ARGS.get("tex", "D:/CivCity/.work/kit/tex")


def make_plaster_mat():
    """штукатурка: цвет вершин × рисованная текстура (Codex) — в Blender через Multiply; перед выгрузкой картинка
    подключается прямо к Base Color (glTF сам умножит на COLOR_0)"""
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


def plaster_for_export():
    m = bpy.data.materials.get("CivPlaster")
    if not m:
        return
    nt = m.node_tree
    nt.links.new(nt.nodes["PlasterTex"].outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])


def decal(coll, name, P, U, N, uc, vc, w, h, img_name, urep=1.0, off=0.008):
    """картинка на стене (надпись, роспись): отдельный узел со своим материалом и прозрачностью"""
    mb = MB(name)
    q = [P(uc - w / 2, vc - h / 2, off), P(uc + w / 2, vc - h / 2, off), P(uc + w / 2, vc + h / 2, off), P(uc - w / 2, vc + h / 2, off)]
    mb.face([mb.v(x) for x in q], (1, 1, 1, 1), ("dir", tuple(N)), uv=[(0, 0), (urep, 0), (urep, 1), (0, 1)])
    m = bpy.data.materials.new(name + "Mat")
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    im = nt.nodes.new("ShaderNodeTexImage")
    im.image = bpy.data.images.load(os.path.join(TEX, img_name))
    nt.links.new(im.outputs["Color"], bsdf.inputs["Base Color"])
    if img_name.endswith("notice.png"):
        nt.links.new(im.outputs["Alpha"], bsdf.inputs["Alpha"])
        try:
            m.surface_render_method = "BLENDED"
        except Exception:
            m.blend_method = "BLEND"
    bsdf.inputs["Roughness"].default_value = 0.9
    mb.mats = [m]
    return mb.obj(coll)


# ---------------- стены ----------------
def noise2(u, v, ph):
    return (math.sin(u * 2.1 + ph[0]) * math.sin(v * 1.7 + ph[1]) * 0.5
            + math.sin(u * 5.3 + ph[2]) * math.sin(v * 4.1 + ph[3]) * 0.3
            + math.sin(u * 11.0 + v * 9.0 + ph[4]) * 0.2)


PH = [rng.uniform(0, 6.28) for _ in range(5)]


def wall(mb, inner, frame, x0, x1, y0, y1, openings, base, base_in, stains=(), caps=False):
    """Стена-плита: лицо (сетка ~0,3 м, штукатурка «рукой»: чуть неровная, пятна, грязь у земли, подтёки под окнами),
    изнанка (комната) и откосы проёмов. frame = (O, U, N): O — точка (u=0, v=0) на лице, U — вдоль стены, N — наружу.
    openings — [(u0, u1, v0, v1)] в координатах стены. v — высота (y игры)."""
    O, U, N = frame
    V = Vector((0, 1, 0))

    def P(u, v, n=0.0):
        return O + U * u + V * v + N * n

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
    # слить слишком близкие линии (меньше 4 см) — но края проёмов не трогать
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
    keep_u = [x0, x1] + [o[0] for o in openings] + [o[1] for o in openings]
    keep_v = [y0, y1] + [o[2] for o in openings] + [o[3] for o in openings]
    us = tidy(us, keep_u)
    vs = tidy(vs, keep_v)

    def inside(u, v):
        for (a, b, c, d) in openings:
            if a - 1e-6 <= u <= b + 1e-6 and c - 1e-6 <= v <= d + 1e-6:
                return True
        return False

    def on_edge(u, v):
        if abs(u - x0) < 1e-6 or abs(u - x1) < 1e-6 or abs(v - y0) < 1e-6 or abs(v - y1) < 1e-6:
            return True
        for (a, b, c, d) in openings:
            if (a - 1e-6 <= u <= b + 1e-6 and c - 1e-6 <= v <= d + 1e-6):
                return True
        return False

    def tone(u, v):
        n = noise2(u + O.x * 0.7, v + O.z * 0.7, PH)
        c = list(col(base, n * 0.07))
        if base == PAL["plaster"] and PAL.get("plaster2"):
            # нижняя часть стены — другим тоном (старая побелка, выцветшая краска), граница неровная
            edge = PL + 1.0 + 0.25 * noise2(u * 1.7, 0.3, PH)
            k = min(1.0, max(0.0, (edge - v) / 0.35)) * (0.85 if LOOK == "B" else 0.45)
            c2 = col(PAL["plaster2"], n * 0.07)
            c = [c[i] * (1 - k) + c2[i] * k for i in range(3)] + [1.0]
        g = max(0.0, 1.0 - (v - y0) / 0.55) if y0 < PL + 0.05 else 0.0     # грязь у земли
        for s in stains:                                                   # подтёки под подоконниками
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
            vid[(i, j)] = (mb.v(P(u, v, jit)), tone(u, v), UVp(u, v))
    out_dir = (N.x, N.y, N.z)
    for i in range(len(us) - 1):
        for j in range(len(vs) - 1):
            cu, cv = (us[i] + us[i + 1]) / 2, (vs[j] + vs[j + 1]) / 2
            if inside(cu, cv):
                continue
            q = [vid[(i, j)], vid[(i + 1, j)], vid[(i + 1, j + 1)], vid[(i, j + 1)]]
            mb.face([e[0] for e in q], [e[1] for e in q], ("dir", out_dir), uv=[e[2] for e in q], mat=1)
            # изнанка — в комнату, одним цветом
            inner.face([inner.v(P(us[i], vs[j], -T)), inner.v(P(us[i + 1], vs[j], -T)),
                        inner.v(P(us[i + 1], vs[j + 1], -T)), inner.v(P(us[i], vs[j + 1], -T))],
                       J(base_in, 0.04, 0.0, 0.0), ("dir", (-N.x, -N.y, -N.z)))
    # откосы
    for (a, b, c, d) in openings:
        cc = col(base, -0.12)
        ctr = P((a + b) / 2, (c + d) / 2, -T / 2)
        ctr = (ctr.x, ctr.y, ctr.z)
        for (p0, p1) in [((a, c), (b, c)), ((b, c), (b, d)), ((b, d), (a, d)), ((a, d), (a, c))]:
            mb.face([mb.v(P(p0[0], p0[1], 0)), mb.v(P(p1[0], p1[1], 0)), mb.v(P(p1[0], p1[1], -T)),
                     mb.v(P(p0[0], p0[1], -T))], cc, ("to", ctr),
                    uv=[UVp(p0[0], p0[1]), UVp(p1[0], p1[1]), (UVp(p1[0], p1[1])[0] + 0.14, UVp(p1[0], p1[1])[1]),
                        (UVp(p0[0], p0[1])[0] + 0.14, UVp(p0[0], p0[1])[1])], mat=1)
    # торцы плиты (углы дома) — иначе на углу щель в толщину стены
    if caps:
        for u, sgn in ((x0, -1), (x1, 1)):
            q = [P(u, y0, 0), P(u, y0, -T), P(u, y1, -T), P(u, y1, 0)]
            mb.face([mb.v(x) for x in q], [tone(u, y0), tone(u, y0), tone(u, y1), tone(u, y1)],
                    ("dir", tuple(U * sgn)), uv=[(0, y0 / 1.6), (0.14, y0 / 1.6), (0.14, y1 / 1.6), (0, y1 / 1.6)], mat=1)
    return P


def fix_reveals(mb):
    pass


# ---------------- детали фасада ----------------
def window(mb, P, U, N, u0, u1, v0, v1, shutters, sill=True, box=False, grille=False, surround=False):
    """окно в проёме [u0,u1]×[v0,v1] стены P: рама в глубине, подоконник, деревянная перемычка, ставни на петлях"""
    w = u1 - u0
    h = v1 - v0
    Rw = Matrix((U, Vector((0, 1, 0)), N)).transposed()     # колонки: U, Y, N
    fr = 0.045
    dep = -0.07
    wood = P["wood"] if isinstance(P, dict) else None
    c_w = J(PAL["wood"], 0.06)
    # рама
    if surround:
        # наличник: толстая светлая рамка вокруг проёма (как у лепных домиков) — косяки и верх
        ct = J(PAL["trim"], 0.04)
        for uu in (u0 - 0.045, u1 + 0.045):
            mb.box(Pw(P, uu, (v0 + v1) / 2 + 0.03, 0.03), (0.09, h + 0.1, 0.06), ct, Rw)
        mb.box(Pw(P, (u0 + u1) / 2, v1 + 0.07, 0.04), (w + 0.26, 0.12, 0.08), ct, Rw, cols={"top": J(PAL["trim"], 0.1)})
    for (cu, cv, su, sv) in [(u0 + fr / 2, (v0 + v1) / 2, fr, h), (u1 - fr / 2, (v0 + v1) / 2, fr, h),
                             ((u0 + u1) / 2, v0 + fr / 2, w, fr), ((u0 + u1) / 2, v1 - fr / 2, w, fr),
                             ((u0 + u1) / 2, (v0 + v1) / 2, 0.03, h - 2 * fr)]:
        mb.box(Pw(P, cu, cv, dep), (su, sv, 0.05), c_w, Rw)
    if grille:
        for k in range(1, 3):
            mb.box(Pw(P, (u0 + u1) / 2, v0 + h * k / 3, dep), (w, 0.025, 0.035), c_w, Rw)
    # тёмная глубина за рамой не нужна — за окном настоящая комната
    if sill:
        mb.box(Pw(P, (u0 + u1) / 2, v0 - 0.045, 0.04), (w + 0.24, 0.09, T * 0.5 + 0.12), J(PAL["stone"], 0.05), Rw,
               cols={"top": J(PAL["stone"], 0.03, 0, 0)})
    if not surround:     # перемычка: брус чуть шире проёма
        mb.box(Pw(P, (u0 + u1) / 2, v1 + 0.05, 0.015), (w + 0.2, 0.1, 0.1), J(PAL["wood2"], 0.06), Rw)
    if box:
        flower_box(mb, P, Rw, (u0 + u1) / 2, v0 - 0.07, w + 0.1)


def Pw(P, u, v, n):
    p = P(u, v, n)
    return (p.x, p.y, p.z)


def flower_box(mb, P, Rw, uc, vtop, w):
    c = J(PAL["wood"], 0.08)
    mb.box(Pw(P, uc, vtop - 0.09, 0.13), (w, 0.16, 0.18), c, Rw)
    mb.box(Pw(P, uc, vtop - 0.015, 0.13), (w - 0.04, 0.02, 0.14), col("#4a3524"), Rw)
    flowers = ["#d9534f", "#f0c24b", "#e98bb0", "#f4f1e8", "#c0392b"]
    n = int(w / 0.07)
    for i in range(n):
        u = uc - w / 2 + 0.05 + (w - 0.1) * i / max(1, n - 1)
        leaf_blob(mb, Pw(P, u + rng.uniform(-0.02, 0.02), vtop + 0.03, 0.13 + rng.uniform(-0.04, 0.04)), 0.05,
                  J("#5b8a3a", 0.12))
        if rng.random() < 0.7:
            fl = rng.choice(flowers)
            leaf_blob(mb, Pw(P, u + rng.uniform(-0.02, 0.02), vtop + 0.08 + rng.uniform(0, 0.04),
                             0.15 + rng.uniform(-0.03, 0.04)), 0.025, J(fl, 0.08))
    # свисающая зелень
    for i in range(3):
        u = uc - w / 2 + 0.06 + rng.uniform(0, w - 0.12)
        for k in range(3):
            leaf_blob(mb, Pw(P, u, vtop - 0.18 - 0.07 * k, 0.23), 0.03, J("#4f7d33", 0.1))


def leaf_blob(mb, at, r, c):
    """кустик/цветок — восьмигранник (низкополигональный «шарик»)"""
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


def col_shift(c, dv):
    return (c[0] * (1 + dv), c[1] * (1 + dv), c[2] * (1 + dv), 1.0)


def shutter_leaf(coll, name, hinge, U, N, w, h, side, open_a, base_col):
    """створка ставни: доски, две планки, петли. Ось — на петле (наружный край проёма), side = -1 левая, +1 правая.
    open_a — угол раскрытия (0 — закрыта, ~1.75 рад — прижата к стене)"""
    mb = MB(name)
    # строим в локальных осях створки: x от петли к центру проёма (·(−side)), y вверх, z наружу
    nb = 3
    for k in range(nb):
        x = (k + 0.5) * w / nb
        mb.box((x * -side, h / 2, 0.0), (w / nb - 0.008, h, 0.045), J(base_col, 0.1, 0.01, 0.1))
    for vv in (0.17, 0.83):
        mb.box((w / 2 * -side, h * vv, 0.03), (w * 0.94, 0.07, 0.022), J(base_col, -0.18))
    # косая планка между поперечными (Z) — ставня «держит форму»
    p0 = Vector((0.08 * -side, h * 0.22, 0.03))
    p1 = Vector(((w - 0.08) * -side, h * 0.78, 0.03))
    dl = (p1 - p0)
    ang = math.atan2(dl.y, dl.x)
    mb.box(tuple((p0 + p1) / 2), (dl.length, 0.06, 0.02), J(base_col, -0.2), Matrix.Rotation(ang, 3, "Z"))
    for vv in (0.2, 0.8):
        mb.box((0.02 * -side, h * vv, 0.03), (0.06, 0.03, 0.012), col("#2b2622"))
    ob = mb.obj(coll)
    # повернуть: локальные оси → U, Y, N мира; открытие — вокруг вертикали на петле
    Rw = Matrix((U, Vector((0, 1, 0)), N)).transposed()
    Ro = Matrix.Rotation(open_a * side, 3, "Y")            # в осях игры: вращение вокруг y
    M3 = Rw @ Ro
    # перевод игры → Blender: (x, y, z) → (x, −z, y)
    G = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))
    Mb = G @ M3 @ G.inverted()
    ob.matrix_world = Matrix.Translation(MB.bl(hinge)) @ Mb.to_4x4()
    return ob


def door_leaf(coll, name, hinge, U, N, w, h, open_a):
    mb = MB(name)
    nb = 4
    for k in range(nb):
        x = (k + 0.5) * w / nb
        mb.box((x, h / 2, 0.0), (w / nb - 0.008, h, 0.05), J(PAL["door"], 0.1, 0.01, 0.1))
    for vv in (0.15, 0.5, 0.85):
        mb.box((w / 2, h * vv, 0.032), (w * 0.95, 0.07, 0.02), J(PAL["door"], -0.2))
    for k in range(nb):               # гвозди-бляшки
        for vv in (0.15, 0.5, 0.85):
            mb.box(((k + 0.5) * w / nb, h * vv, 0.046), (0.018, 0.018, 0.012), col("#3a332c"))
    ring_c = col("#8a6a35")
    mb.box((w * 0.78, h * 0.52, 0.06), (0.05, 0.05, 0.02), ring_c)
    ob = mb.obj(coll)
    Rw = Matrix((U, Vector((0, 1, 0)), N)).transposed()
    Ro = Matrix.Rotation(open_a, 3, "Y")             # дверь открывается внутрь
    G = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))
    ob.matrix_world = Matrix.Translation(MB.bl(hinge)) @ (G @ (Rw @ Ro) @ G.inverted()).to_4x4()
    return ob


# ---------------- крыша из черепицы ----------------
def roof(mb, along_x, x0, x1, z0, z1, y_wall, pitch_deg=27.0, oe=0.34, og=0.18, antefix=True):
    """Двускатная крыша над прямоугольником [x0,x1]×[z0,z1] (стены), конёк вдоль X (along_x) или вдоль Z.
    Черепица: плоские tegula рядами внахлёст (каждый ряд чуть приподнят — тени-ступеньки) и полукруглые imbrex
    поверх стыков, конёк из крупных imbrex, на свесе — антефиксы-пальметты. Возвращает высоту конька."""
    a = math.radians(pitch_deg)
    if along_x:
        L0, L1 = x0 - og, x1 + og              # вдоль конька
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

    def W(l, s, n, side):
        """точка ската: l — вдоль конька, s — от свеса вверх по скату, n — по нормали; side ±1 (+ к улице / к +x)"""
        horiz = run - s * math.cos(a)          # расстояние от конька по горизонтали
        y = y_eave + s * math.sin(a) + n * math.cos(a)
        d = side * (horiz + n * math.sin(a))
        if along_x:
            return Vector((l, y, cz + d))
        return Vector((cz + d, y, l))

    tile = PAL["tile"]
    sp = 0.40                                   # шаг колонок tegula (крупно — читается с высоты камеры)
    L = 0.54                                    # длина черепицы
    step = 0.41                                 # шаг рядов (нахлёст 13 см)
    lift = 0.05
    ncol = int((L1 - L0) / sp)
    l_start = (L0 + L1) / 2 - ncol * sp / 2
    nrow = int(math.ceil((slope_len - 0.06) / step))
    deck_t = 0.1
    ridge_r = 0.12
    for side in (1, -1):
        # обрешётка-настил (снизу виден под свесом), торцевая доска по краю ската
        q = [W(L0, 0, -deck_t, side), W(L1, 0, -deck_t, side), W(L1, slope_len, -deck_t, side), W(L0, slope_len, -deck_t, side)]
        mb.face([mb.v(p) for p in q], col(PAL["wood2"], -0.1), ("dir", (0, -1, 0)))
        q2 = [W(L0, 0, 0, side), W(L1, 0, 0, side), W(L1, slope_len, 0, side), W(L0, slope_len, 0, side)]
        mb.face([mb.v(p) for p in q2], col(tile, -0.35), ("dir", (0, 1, 0)))
        mb.face([mb.v(W(L0, 0, -deck_t, side)), mb.v(W(L1, 0, -deck_t, side)), mb.v(W(L1, 0, 0, side)), mb.v(W(L0, 0, 0, side))],
                col(PAL["wood2"]), ("from", W((L0 + L1) / 2, 1.0, 0, side)))
        # ветровые доски по краям ската — толстая кромка крыши у фронтона
        for lv, sg in ((L0, -1), (L1, 1)):
            p0 = W(lv + sg * 0.03, 0, -deck_t * 0.5 + 0.01, side)
            p1 = W(lv + sg * 0.03, slope_len, -deck_t * 0.5 + 0.01, side)
            dirv = (p1 - p0).normalized()
            Uv = Vector((1, 0, 0)) if along_x else Vector((0, 0, 1))
            Nv = dirv.cross(Uv).normalized()
            if Nv.y < 0:
                Nv = -Nv
            mb.box(tuple((p0 + p1) / 2), (0.07, deck_t + 0.06, (p1 - p0).length + 0.04), J(PAL["wood2"], 0.06),
                   Matrix((Uv, Nv, dirv)).transposed())
        # стропила под свесом — торцы балок
        nr = int((L1 - L0) / 0.42)
        for k in range(nr + 1):
            l = L0 + 0.12 + (L1 - L0 - 0.24) * k / max(1, nr)
            s0 = 0.02
            s1 = oe / math.cos(a) + 0.15
            p0 = W(l, s0, -deck_t - 0.045, side)
            p1 = W(l, s1, -deck_t - 0.045, side)
            ctr = (p0 + p1) / 2
            dirv = (p1 - p0).normalized()
            Lb = (p1 - p0).length
            if along_x:
                Uv = Vector((1, 0, 0))
            else:
                Uv = Vector((0, 0, 1))
            Nv = dirv.cross(Uv).normalized()
            if Nv.y < 0:
                Nv = -Nv
            R = Matrix((Uv, Nv, dirv)).transposed()
            mb.box(tuple(ctr), (0.07, 0.09, Lb), J(PAL["wood"], 0.08), R)
        # черепица
        for r in range(nrow):
            s0 = r * step
            s1 = min(s0 + L, slope_len + 0.05)
            for c in range(ncol):
                l0 = l_start + c * sp + 0.012
                l1 = l_start + (c + 1) * sp - 0.012
                tc = J(tile, 0.09, 0.012, 0.1)
                rr = rng.random()
                if rr < 0.05:
                    tc = col(tile, 0.18, 0.01, -0.05)        # новая, светлая
                elif rr < 0.09:
                    tc = col(tile, -0.28, 0.0, -0.1)        # старая, тёмная
                elif rr < 0.11 and side == -1:
                    tc = col("#7f7a3e", rng.uniform(-0.1, 0.05))   # мох на северном скате
                lo = lift if r > 0 else 0.0
                th = 0.045
                ch = 0.03
                # нижний край приподнят (лежит на ряду ниже) и скруглён фаской — блик по кромке, как у лепной черепицы
                b0, b1 = W(l0, s0, lo, side), W(l1, s0, lo, side)
                b2, b3 = W(l1, s1, 0, side), W(l0, s1, 0, side)
                m0, m1 = W(l0 + 0.01, s0, lo + th * 0.55, side), W(l1 - 0.01, s0, lo + th * 0.55, side)
                t0, t1 = W(l0 + 0.01, s0 + ch, lo + th, side), W(l1 - 0.01, s0 + ch, lo + th, side)
                t2, t3 = W(l1 - 0.01, s1, th, side), W(l0 + 0.01, s1, th, side)
                pts = [b0, b1, b2, b3, m0, m1, t0, t1, t2, t3]
                vv = [mb.v(q) for q in pts]
                cc = tuple(sum(pts, Vector((0.0, 0.0, 0.0))) / len(pts))
                mb.face([vv[6], vv[7], vv[8], vv[9]], tc, ("from", cc))
                mb.face([vv[4], vv[5], vv[7], vv[6]], col_shift(tc, 0.12), ("from", cc))
                mb.face([vv[0], vv[1], vv[5], vv[4]], col_shift(tc, -0.3), ("from", cc))
                mb.face([vv[1], vv[2], vv[8], vv[7], vv[5]], col_shift(tc, -0.18), ("from", cc))
                mb.face([vv[3], vv[0], vv[4], vv[6], vv[9]], col_shift(tc, -0.18), ("from", cc))
                # бортики tegula

            # imbrex над стыками колонок (и по краям)
            for c in range(ncol + 1):
                lc = l_start + c * sp
                r0 = 0.09 if r > 0 else 0.095
                r1 = 0.078
                seg = 6
                ring0, ring1 = [], []
                base_lo = (lift if r > 0 else 0.0) + 0.035
                for k in range(seg + 1):
                    ph = math.pi * k / seg
                    ring0.append(mb.v(W(lc + r0 * math.cos(ph), s0 - 0.02, base_lo + r0 * math.sin(ph) * 0.95, side)))
                    ring1.append(mb.v(W(lc + r1 * math.cos(ph), s1 + 0.02, 0.035 + r1 * math.sin(ph) * 0.95, side)))
                ic = J(tile, 0.1, 0.012, 0.1)
                if rng.random() < 0.06:
                    ic = col(tile, -0.3)
                ctr = W(lc, (s0 + s1) / 2, 0.0, side)
                for k in range(seg):
                    sh = 0.12 * math.sin(math.pi * (k + 0.5) / seg) - 0.06
                    mb.face([ring0[k], ring0[k + 1], ring1[k + 1], ring1[k]], col_shift(ic, sh), ("from", tuple(ctr)))
                # торец снизу: полукруг (или антефикс на свесе)
                cen = mb.v(W(lc, s0 - 0.02, base_lo, side))
                for k in range(seg):
                    mb.face([cen, ring0[k], ring0[k + 1]], col_shift(ic, -0.3), ("from", tuple(W(lc, s0 + 0.2, base_lo, side))))
                if r == 0 and antefix:
                    antefix_at(mb, W(lc, -0.03, base_lo + 0.02, side), along_x, side, ic)
    # конёк: крупные imbrex внахлёст
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
                if along_x:
                    ring.append(mb.v((l, y_ridge + 0.02 + dy, cz + dd)))
                else:
                    ring.append(mb.v((cz + dd, y_ridge + 0.02 + dy, l)))
            rings.append(ring)
        ctr = (((l0 + l1) / 2, y_ridge, cz) if along_x else (cz, y_ridge, (l0 + l1) / 2))
        for s in range(seg):
            mb.face([rings[0][s], rings[0][s + 1], rings[1][s + 1], rings[1][s]], col_shift(ic, 0.06 * math.sin(math.pi * s / seg)), ("from", ctr))
        cen = mb.v(((l0, y_ridge + 0.02, cz) if along_x else (cz, y_ridge + 0.02, l0)))
        for s in range(seg):
            mb.face([cen, rings[0][s + 1], rings[0][s]], col_shift(ic, -0.25), ("from", ((l0 + 0.2, y_ridge, cz) if along_x else (cz, y_ridge, l0 + 0.2))))
    # фронтоны: треугольники штукатурки на торцах (между стенами), доска-ветровка по краю ската
    return y_ridge, (L0, L1, cz, half, rise, along_x, a, W, slope_len)


def antefix_at(mb, p, along_x, side, c):
    """антефикс — терракотовая пальметта на конце нижнего imbrex"""
    n = Vector((0, 0, side)) if along_x else Vector((side, 0, 0))
    u = Vector((1, 0, 0)) if along_x else Vector((0, 0, 1))
    pts = []
    for k in range(7):
        ph = math.pi * k / 6
        rr = 0.085 if k % 2 == 0 else 0.065
        pts.append(p + u * (rr * math.cos(ph)) + Vector((0, 0.02 + rr * math.sin(ph) * 1.25, 0)))
    pts = [p + u * 0.05, ] + pts[::-1] + [p - u * 0.05]
    fr = [mb.v(q + n * 0.012) for q in pts]
    bk = [mb.v(q - n * 0.012) for q in pts]
    cc = col_shift(c, 0.08)
    mb.face(fr, cc, ("dir", tuple(n)))
    mb.face(bk[::-1], col_shift(c, -0.2), ("dir", tuple(-n)))
    for i in range(len(pts) - 1):
        mb.face([fr[i], fr[i + 1], bk[i + 1], bk[i]], col_shift(c, -0.1), ("from", tuple(p + Vector((0, 0.06, 0)))))


def gable_walls(mb, inner, info, x0, x1, z0, z1, y_wall, base, base_in):
    L0, L1, cz, half, rise, along_x, a, W, slope_len = info
    # треугольник на торце: вершины (край стены, y_wall), (другой край, y_wall), (середина, y_wall+rise)
    ends = []
    if along_x:
        for x, nx in ((x0, -1), (x1, 1)):
            ends.append(([Vector((x, y_wall, z0)), Vector((x, y_wall, z1)), Vector((x, y_wall + rise, cz))], Vector((nx, 0, 0))))
    else:
        for z, nz in ((z0, -1), (z1, 1)):
            ends.append(([Vector((x0, y_wall, z)), Vector((x1, y_wall, z)), Vector((cz, y_wall + rise, z))], Vector((0, 0, nz))))
    for tri, n in ends:
        cs = [col_shift(col(base, noise2(p.x, p.y, PH) * 0.06 - 0.05 * (p.y - y_wall)), 0.1) for p in tri]
        mb.face([mb.v(p) for p in tri], cs, ("dir", tuple(n)),
                uv=[((p.x + p.z) / 1.6, p.y / 1.6) for p in tri], mat=1)
        inner.face([inner.v(p - n * T) for p in tri], col(base_in, -0.1), ("dir", tuple(-n)))
        # толщина по скатам (сверху под черепицей не видно — пропускаем)
    return ends


# ---------------- каменный цоколь ----------------
def plinth(mb, x0, x1, z0, z1, gaps):
    """ряд тёсаных камней по периметру; gaps — [(сторона, u0, u1)] где камней нет (порог двери)"""
    sides = [("front", Vector((x0, 0, z1)), Vector((1, 0, 0)), Vector((0, 0, 1)), x1 - x0),
             ("back", Vector((x1, 0, z0)), Vector((-1, 0, 0)), Vector((0, 0, -1)), x1 - x0),
             ("left", Vector((x0, 0, z0)), Vector((0, 0, 1)), Vector((-1, 0, 0)), z1 - z0),
             ("right", Vector((x1, 0, z1)), Vector((0, 0, -1)), Vector((1, 0, 0)), z1 - z0)]
    for name, O, U, N, Ln in sides:
        u = -0.03
        R = Matrix((U, Vector((0, 1, 0)), N)).transposed()
        while u < Ln + 0.02:
            ln = rng.uniform(0.32, 0.6)
            u1 = min(u + ln, Ln + 0.03)
            skip = any(g[0] == name and g[1] < (u + u1) / 2 < g[2] for g in gaps)
            if not skip and u1 - u > 0.06:
                h = PL + rng.uniform(-0.02, 0.01)
                c = (O + U * ((u + u1) / 2) + Vector((0, h / 2 - 0.02, 0)) + N * rng.uniform(0.01, 0.035))
                mb.box(tuple(c), (u1 - u - 0.012, h, 0.12), J(PAL["stone"], 0.1, 0.01, 0.2), R,
                       cols={"top": J(PAL["stone"], 0.12, 0.0, 0.1)})
            u = u1


# ---------------- заплаты: облезла штукатурка, видна кладка ----------------
def brick_patch(mb, P, U, N, uc, vc, r):
    R = Matrix((U, Vector((0, 1, 0)), N)).transposed()
    pts = []
    k = 9
    for i in range(k):
        a = 2 * math.pi * i / k
        rr = r * rng.uniform(0.6, 1.1)
        pts.append(mb.v(P(uc + rr * math.cos(a) * 1.3, vc + rr * math.sin(a) * 0.8, 0.004)))
    mb.face(pts, col("#8f5a42", rng.uniform(-0.1, 0.05)), ("dir", tuple(N)))
    bh = 0.05
    rows = int(r * 1.6 / bh)
    for j in range(rows):
        v = vc - r * 0.8 + (j + 0.5) * bh
        off = 0.06 if j % 2 else 0.0
        u = uc - r * 1.3 + off
        while u < uc + r * 1.3:
            du, dv = (u + 0.1 - uc) / (r * 1.3), (v - vc) / (r * 0.8)
            if du * du + dv * dv < 0.55:
                mb.box(Pw(P, u + 0.1, v, 0.008), (0.19, bh - 0.012, 0.012), J("#a4583a", 0.12, 0.015, 0.1), R)
            u += 0.21


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
    c = J(PAL["wood"], 0.06)
    mb.box(at, (ln, 0.04, 0.24), c, R)
    for s in (-1, 1):
        o = R @ Vector((s * (ln / 2 - 0.08), -0.13, 0))
        mb.box((at[0] + o.x, at[1] + o.y, at[2] + o.z), (0.05, 0.24, 0.2), J(PAL["wood2"], 0.06), R)


def firewood(mb, at, R, n=9):
    for i in range(n):
        row = i // 4
        k = i % 4
        o = R @ Vector(((k - 1.5) * 0.085 + row * 0.04, 0.04 + row * 0.075, 0))
        c = (at[0] + o.x, at[1] + o.y, at[2] + o.z)
        # полено — шестигранник вдоль z
        r = 0.04
        ring0, ring1 = [], []
        for s in range(6):
            a = 2 * math.pi * s / 6
            d = R @ Vector((math.cos(a) * r, math.sin(a) * r, 0))
            zz = R @ Vector((0, 0, 0.2))
            ring0.append(mb.v((c[0] + d.x - zz.x, c[1] + d.y - zz.y, c[2] + d.z - zz.z)))
            ring1.append(mb.v((c[0] + d.x + zz.x, c[1] + d.y + zz.y, c[2] + d.z + zz.z)))
        bark = J("#6b5039", 0.12)
        for s in range(6):
            t = (s + 1) % 6
            mb.face([ring0[s], ring0[t], ring1[t], ring1[s]], bark, ("from", c))
        mb.face(ring1, col("#c9a46e", rng.uniform(-0.1, 0.05)), ("from", c))
        mb.face(ring0[::-1], col("#c9a46e", rng.uniform(-0.1, 0.05)), ("from", c))


def basket(mb, at, r, h):
    prof = [(r * 0.8, 0), (r, h * 0.85), (r * 1.05, h)]
    mb.lathe(at, prof, 9, J("#b48a4f", 0.08), cols=[J("#b48a4f", 0.1), J("#a07840", 0.1)], close_top=False)
    mb.lathe((at[0], at[1] + h * 0.7, at[2]), [(r * 0.9, 0), (r * 0.92, 0.01)], 9, J("#7a8f3a", 0.1), close_top=True)
    for k in range(3):
        leaf_blob(mb, (at[0] + rng.uniform(-r * 0.4, r * 0.4), at[1] + h * 0.85, at[2] + rng.uniform(-r * 0.4, r * 0.4)),
                  r * 0.35, J(rng.choice(["#c0392b", "#e6b33a", "#7fa040"]), 0.1))


def awning(coll, name, P, U, N, uc, v, w, depth, cols2):
    """полосатый тканевый навес над дверью на двух шестах; ткань провисает"""
    mb = MB(name)
    nu, nd = 6, 3
    R = Matrix((U, Vector((0, 1, 0)), N)).transposed()
    grid = {}
    for i in range(nu + 1):
        for j in range(nd + 1):
            u = uc - w / 2 + w * i / nu
            d = depth * j / nd
            sag = 0.06 * math.sin(math.pi * i / nu) * (j / nd)
            y = v - d * 0.45 - sag
            grid[(i, j)] = mb.v(Pw(P, u, y, 0.02 + d))
    for i in range(nu):
        cc = col(cols2[i % 2], rng.uniform(-0.04, 0.04))
        for j in range(nd):
            q = [grid[(i, j)], grid[(i + 1, j)], grid[(i + 1, j + 1)], grid[(i, j + 1)]]
            mb.face(q, cc, ("dir", (0, 1, 0)))
            mb.face(q[::-1], col_shift(cc, -0.25), ("dir", (0, -1, 0)))
    # бахрома-фестоны спереди
    for i in range(nu):
        u0 = uc - w / 2 + w * i / nu
        u1 = u0 + w / nu
        y = v - depth * 0.45
        a = mb.v(Pw(P, u0, y - 0.06 * math.sin(math.pi * i / nu), 0.02 + depth))
        b = mb.v(Pw(P, u1, y - 0.06 * math.sin(math.pi * (i + 1) / nu), 0.02 + depth))
        m = mb.v(Pw(P, (u0 + u1) / 2, y - 0.12 - 0.06 * math.sin(math.pi * (i + 0.5) / nu), 0.02 + depth))
        mb.face([a, b, m], col(cols2[i % 2], -0.05), ("dir", tuple(N)))
        mb.face([b, a, m], col(cols2[i % 2], -0.3), ("dir", tuple(-N)))
    # шесты и брус
    for s in (-1, 1):
        top = Pw(P, uc + s * w / 2, v - depth * 0.45 - 0.02, depth + 0.02)
        mb.box((top[0], top[1] / 2, top[2]), (0.045, top[1], 0.045), J(PAL["wood"], 0.05), R)
    ob = mb.obj(coll)
    return ob


# ---------------- комната внутри ----------------
def interior(mb, x0, x1, z0, z1, y, floor_k):
    """пол из досок, мебель: очаг с угольками (внизу), стол, табурет, амфоры, полка; наверху — кровать, сундук"""
    c_floor = PAL["wood2"]
    n = int((x1 - x0) / 0.18)
    for i in range(n):
        u0 = x0 + (x1 - x0) * i / n
        mb.box(((u0 + (x1 - x0) / n / 2), y + 0.02, (z0 + z1) / 2), ((x1 - x0) / n - 0.006, 0.04, z1 - z0),
               J(c_floor, 0.12, 0.01, 0.1))
    if floor_k == 0:
        # очаг у задней стены слева
        hx, hz = x0 + 0.35, z0 + 0.3
        mb.box((hx, y + 0.18, hz), (0.6, 0.32, 0.45), J(PAL["stone"], 0.08), cols={"top": col("#3a2e26")})
        for k in range(5):
            leaf_blob(EMB, (hx + rng.uniform(-0.15, 0.15), y + 0.37, hz + rng.uniform(-0.1, 0.1)), 0.04,
                      col(rng.choice(["#ff7a1a", "#ffb03a", "#e8461c"])))
        mb.lathe((hx, y + 0.36, hz), [(0.12, 0), (0.15, 0.1), (0.12, 0.18)], 8, col("#3d3530"))
        # стол и табурет
        tx, tz = (x0 + x1) / 2 + 0.25, (z0 + z1) / 2 - 0.2
        mb.box((tx, y + 0.52, tz), (0.8, 0.05, 0.5), J(PAL["wood"], 0.05))
        for sx in (-1, 1):
            for sz in (-1, 1):
                mb.box((tx + sx * 0.33, y + 0.26, tz + sz * 0.19), (0.05, 0.5, 0.05), J(PAL["wood2"], 0.05))
        mb.lathe((tx - 0.15, y + 0.55, tz), [(0.06, 0), (0.1, 0.05), (0.11, 0.06)], 8, col("#b8693f"))
        leaf_blob(mb, (tx + 0.18, y + 0.6, tz + 0.05), 0.05, col("#d9a441"))
        mb.box((tx + 0.1, y + 0.2, tz + 0.45), (0.3, 0.04, 0.3), J(PAL["wood"], 0.05))
        mb.box((tx + 0.1, y + 0.1, tz + 0.45), (0.06, 0.2, 0.06), J(PAL["wood2"], 0.05))
        amphora(mb, (x1 - 0.2, y + 0.04, z0 + 0.25), 0.55, J("#c27a4a", 0.08))
        amphora(mb, (x1 - 0.42, y + 0.04, z0 + 0.22), 0.5, J("#b5703f", 0.08))
        # полка с горшками
        mb.box((x1 - 0.06, y + 1.05, (z0 + z1) / 2), (0.1, 0.03, 0.9), J(PAL["wood"], 0.05))
        for k in range(3):
            mb.lathe((x1 - 0.07, y + 1.07, (z0 + z1) / 2 - 0.3 + 0.3 * k), [(0.04, 0), (0.06, 0.07), (0.04, 0.12)], 7,
                     J(rng.choice(["#b8693f", "#c9a46e", "#7d8f99"]), 0.08))
    else:
        bx, bz = x0 + 0.5, z0 + 0.6
        mb.box((bx, y + 0.22, bz), (0.85, 0.3, 1.25), J(PAL["wood"], 0.05))
        mb.box((bx, y + 0.42, bz + 0.1), (0.8, 0.1, 1.0), J("#b0413e", 0.08))
        mb.box((bx, y + 0.43, bz - 0.48), (0.7, 0.1, 0.22), J("#efe6d2", 0.04))
        mb.box((x1 - 0.35, y + 0.22, z0 + 0.3), (0.55, 0.4, 0.35), J(PAL["wood"], 0.08), cols={"top": J(PAL["wood2"], 0.05)})
        amphora(mb, (x1 - 0.25, y + 0.04, z1 - 0.35), 0.45, J("#c27a4a", 0.08))


# =====================================================================================
def build():
    global PAL, MAT_KIT, MAT_PLASTER, EMB
    PAL = P
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob)
    coll = bpy.context.scene.collection
    MAT_KIT = make_mat("CivKit", 0.85)
    MAT_PLASTER = make_plaster_mat()
    mat_emb = make_mat("CivEmber", 0.5, emit=(1.0, 0.45, 0.1, 1.0))

    x0, x1 = -W / 2, W / 2
    z0, z1 = -D / 2, D / 2
    body = MB("House")
    inner = MB("Rooms")
    EMB = MB("Embers")
    base = P["plaster"]
    base_in = "#e6d5b8"

    # ---- проёмы по этажам ----
    # фасад: внизу дверь и окно; выше — окно и выход на балкон (2-й), два окна с ящиками цветов (3-й)
    door_u = (0.62, 1.44) if LOOK == "A" else (W / 2 - 0.41, W / 2 + 0.41)
    front_open = []
    win_specs = []      # (сторона, u0, u1, v0, v1, ставни, ящик)
    gy = PL
    front_open.append((door_u[0], door_u[1], gy, gy + 1.52))
    if LOOK == "A":
        win_specs.append(("front", 2.3, 2.95, gy + 0.78, gy + 1.5, True, False))
    else:
        win_specs.append(("front", 0.35, 0.9, gy + 0.8, gy + 1.45, True, True))
        win_specs.append(("front", W - 0.9, W - 0.35, gy + 0.8, gy + 1.45, True, False))
    balcony = None
    for f in range(1, FLOORS):
        y = PL + f * FLH
        if f == 1:
            win_specs.append(("front", 0.45, 1.1, y + 0.72, y + 1.5, True, LOOK == "B"))
            bu = (W - 1.35, W - 0.6)
            front_open.append((bu[0], bu[1], y + 0.02, y + 1.55))
            balcony = (bu, y)
        else:
            win_specs.append(("front", 0.5, 1.1, y + 0.75, y + 1.45, True, True))
            win_specs.append(("front", W - 1.1, W - 0.5, y + 0.75, y + 1.45, True, True))
    for (s, a, b, c, d, sh, bx) in win_specs:
        if s == "front":
            front_open.append((a, b, c, d))
    stains = [(a + 0.05, b - 0.05, c) for (s, a, b, c, d, sh, bx) in win_specs if s == "front"]

    # ---- стены: фасад, зад, бока ----
    walls = {
        "front": (Vector((x0, 0, z1)), Vector((1, 0, 0)), Vector((0, 0, 1)), W),
        "back": (Vector((x1, 0, z0)), Vector((-1, 0, 0)), Vector((0, 0, -1)), W),
        "left": (Vector((x0, 0, z0 + T)), Vector((0, 0, 1)), Vector((-1, 0, 0)), D - 2 * T),
        "right": (Vector((x1, 0, z1 - T)), Vector((0, 0, -1)), Vector((1, 0, 0)), D - 2 * T),
    }
    opens = {"front": front_open, "back": [], "left": [], "right": []}
    back_wins = []
    for f in range(FLOORS):
        y = PL + f * FLH
        u = W / 2 - 0.25 + (0.5 if f % 2 else -0.4)
        back_wins.append(("back", u, u + 0.45, y + 0.9, y + 1.4, f > 0, False))
        if f == FLOORS - 1 or f == 0:
            sw = (D - 2 * T) / 2 - 0.2 + (0.4 if f else 0.0)
            back_wins.append(("left", sw, sw + 0.4, y + 0.95, y + 1.4, False, False))
        sr = (D - 2 * T) * (0.3 if f % 2 == 0 else 0.55)
        back_wins.append(("right", sr, sr + 0.55, y + 0.8, y + 1.45, True, f == FLOORS - 1 and FLOORS > 1))
    for (s, a, b, c, d, sh, bx) in back_wins:
        opens[s].append((a, b, c, d))
    Ps = {}
    for name, (O, U, N, Ln) in walls.items():
        Ps[name] = (wall(body, inner, (O, U, N), 0.0, Ln, PL, HT, opens[name], base, base_in,
                         stains if name == "front" else (), caps=name in ("front", "back")), U, N)
    # перекрытия внутри (пол каждого этажа) и комнаты
    for f in range(FLOORS):
        y = PL + f * FLH
        interior(inner, x0 + T, x1 - T, z0 + T, z1 - T, y, f)
        if f > 0:
            body.box((0, y - 0.07, 0), (W - 2 * T + 0.02, 0.1, D - 2 * T + 0.02), col(P["wood2"], -0.2))
            # балки перекрытия — их торцы видны на фасаде
            nb = int(W / 0.5)
            for k in range(nb):
                bx = x0 + 0.3 + (W - 0.6) * k / max(1, nb - 1)
                if any(o[0] - 0.08 < bx - x0 < o[1] + 0.08 and o[2] - 0.2 < y < o[3] + 0.2 for o in front_open):
                    continue
                body.box((bx, y - 0.1, z1 + 0.05), (0.11, 0.11, 0.14), J(P["wood"], 0.1), cols={"pz": J(P["wood2"], 0.1)})
            # поясок-карниз между этажами (по всем сторонам)
            for name, (O, U, N, Ln) in walls.items():
                Pf = Ps[name][0]
                R = Matrix((U, Vector((0, 1, 0)), N)).transposed()
                ext = T if name in ("left", "right") else 0.0
                body.box(Pw(Pf, Ln / 2, y + 0.03, 0.025), (Ln + 2 * ext + 0.06, 0.06, 0.05), J(P["trim"], 0.04), R)
    body.box((0, PL - 0.02, 0), (W - 0.02, 0.06, D - 0.02), col(P["wood2"], -0.3))
    # карниз под крышей
    for name, (O, U, N, Ln) in walls.items():
        Pf = Ps[name][0]
        R = Matrix((U, Vector((0, 1, 0)), N)).transposed()
        ext = T if name in ("left", "right") else 0.0
        body.box(Pw(Pf, Ln / 2, HT - 0.05, 0.03), (Ln + 2 * ext + 0.08, 0.1, 0.06), J(P["trim"], 0.04), R)
        body.box(Pw(Pf, Ln / 2, HT - 0.11, 0.015), (Ln + 2 * ext + 0.04, 0.04, 0.03), J(P["trim"], -0.05), R)

    # ---- угловые камни: у A — тёсаные блоки вперевязку, у B — гладкая пилястра в цвет карниза ----
    corners = [(x0, z1, -1, 1), (x1, z1, 1, 1), (x0, z0, -1, -1), (x1, z0, 1, -1)]
    for (cx, cz_, sx, sz) in corners:
        if LOOK == "A":
            y = PL
            k = 0
            while y < HT - 0.12:
                h = min(0.24, HT - 0.1 - y)
                la, lb = (0.34, 0.2) if k % 2 == 0 else (0.2, 0.34)
                # блок обнимает угол: la — вдоль фасада/зада (x), lb — вдоль бока (z)
                xa, xb = cx - sx * la, cx + sx * 0.03
                za, zb = cz_ - sz * lb, cz_ + sz * 0.03
                body.box(((xa + xb) / 2, y + h / 2, (za + zb) / 2), (abs(xb - xa), h - 0.018, abs(zb - za)),
                         J(P["stone"], 0.09, 0.01, 0.15), cols={"top": J(P["stone"], 0.12)})
                y += h
                k += 1
        else:
            body.box((cx - sx * 0.06, (PL + HT) / 2, cz_ - sz * 0.06), (0.18, HT - PL - 0.1, 0.18), J(P["trim"], 0.03))

    # ---- цоколь ----
    plinth(body, x0, x1, z0, z1, [("front", door_u[0] - 0.02, door_u[1] + 0.02)])
    # порог-ступень
    body.box(((x0 + (door_u[0] + door_u[1]) / 2), 0.07, z1 + 0.16), (door_u[1] - door_u[0] + 0.24, 0.14, 0.36),
             J(P["stone"], 0.05), cols={"top": J(P["stone"], 0.1)})

    # ---- окна, ставни ----
    coll_sh = coll
    sh_i = 0
    for (s, a, b, c, d, sh, bx) in win_specs + back_wins:
        Pf, U, N = Ps[s]
        window(body, Pf, U, N, a, b, c, d, sh, sill=True, box=bx, grille=(s in ("back", "left")), surround=(s in ("front", "right")))
        if sh:
            w = (b - a) / 2
            h = d - c
            ang = (math.radians(rng.uniform(168, 176)) if OPEN > 0.5 else 0.0)      # распахнуты к стене
            if OPEN > 0.5 and rng.random() < 0.25:
                ang = math.radians(rng.uniform(70, 110))     # одна приоткрыта
            hl = Pf(a, c, 0.022)
            hr = Pf(b, c, 0.022)
            shutter_leaf(coll_sh, "Shutter.L.%d" % sh_i, hl, U, N, w, h, -1, ang, P["shutter"])
            shutter_leaf(coll_sh, "Shutter.R.%d" % sh_i, hr, U, N, w, h, 1,
                         ang if rng.random() < 0.8 else math.radians(rng.uniform(80, 130)), P["shutter"])
            sh_i += 1
    # ---- дверь ----
    Pf, U, N = Ps["front"]
    a, b = door_u
    c, d = PL, PL + 1.52
    R = Matrix((U, Vector((0, 1, 0)), N)).transposed()
    for (cu, su) in ((a + 0.04, 0.09), (b - 0.04, 0.09)):
        body.box(Pw(Pf, cu, (c + d) / 2, -0.05), (su, d - c, 0.1), J(P["stone"], 0.06), R)
    body.box(Pw(Pf, (a + b) / 2, d + 0.07, 0.02), (b - a + 0.3, 0.14, 0.14), J(P["stone"], 0.06), R,
             cols={"top": J(P["stone"], 0.1)})
    door_leaf(coll, "Door.0", Pf(a + 0.09, c, -0.1), U, N, b - a - 0.18, d - c - 0.03, math.radians(38) if OPEN > 0.5 else 0.0)

    # ---- балкон (2-й этаж) ----
    if balcony:
        (bu0, bu1), y = balcony
        Pf, U, N = Ps["front"]
        R = Matrix((U, Vector((0, 1, 0)), N)).transposed()
        u0, u1 = bu0 - 0.45, bu1 + 0.35
        dep = 0.62
        for k in range(4):
            u = u0 + 0.06 + (u1 - u0 - 0.12) * k / 3
            body.box(Pw(Pf, u, y - 0.06, dep / 2), (0.09, 0.1, dep + 0.1), J(P["wood"], 0.08), R)
        nb = int((u1 - u0) / 0.12)
        for k in range(nb):
            u = u0 + (u1 - u0) * (k + 0.5) / nb
            body.box(Pw(Pf, u, y + 0.01, dep / 2), ((u1 - u0) / nb - 0.008, 0.035, dep), J(P["wood"], 0.12, 0.01, 0.1), R)
        # перила: стойки и поручень
        for k in range(int((u1 - u0) / 0.13) + 1):
            u = u0 + 0.02 + (u1 - u0 - 0.04) * k / int((u1 - u0) / 0.13)
            body.box(Pw(Pf, u, y + 0.3, dep - 0.03), (0.03, 0.55, 0.03), J(P["wood2"], 0.06), R)
        body.box(Pw(Pf, (u0 + u1) / 2, y + 0.58, dep - 0.03), (u1 - u0 + 0.04, 0.05, 0.06), J(P["wood"], 0.06), R)
        for s in (-1, 1):
            uu = u0 + 0.02 if s < 0 else u1 - 0.02
            for k in range(4):
                body.box(Pw(Pf, uu, y + 0.3, 0.06 + (dep - 0.12) * k / 3), (0.03, 0.55, 0.03), J(P["wood2"], 0.06), R)
            body.box(Pw(Pf, uu, y + 0.58, dep / 2), (0.05, 0.05, dep), J(P["wood"], 0.06), R)
        # горшки с цветами и плющ с перил
        for k in range(2):
            pp = Pw(Pf, u0 + 0.2 + k * 0.32, y + 0.03, dep - 0.2)
            pot(body, pp, 0.22, J("#b8693f", 0.08))
        for k in range(5):
            pp = Pw(Pf, u0 + 0.1 + (u1 - u0 - 0.2) * k / 4, y + 0.45 - rng.uniform(0, 0.3), dep + 0.01)
            leaf_blob(body, pp, 0.05, J("#4f7d33", 0.12))
        door_leaf(coll, "Door.1", Pf(bu0 + 0.05, y + 0.02, -0.1), U, N, bu1 - bu0 - 0.1, 1.5, math.radians(70) if OPEN > 0.5 else 0.0)

    # ---- заплаты кладки ----
    Pf, U, N = Ps["front"]
    spots = [(1.95, PL + 0.45, 0.2), (0.25, PL + 1.6, 0.16)]
    if FLOORS > 1:
        spots.append((W - 0.3, PL + FLH + 0.5, 0.18))
    for (u, v, r) in spots:
        if not any(o[0] - 0.3 < u < o[1] + 0.3 and o[2] - 0.3 < v < o[3] + 0.3 for o in front_open):
            brick_patch(body, Pf, U, N, u, v, r)
    Pl, Ul, Nl = Ps["left"]
    brick_patch(body, Pl, Ul, Nl, (D - 2 * T) * 0.3, PL + 0.6, 0.22)

    # ---- крыша ----
    along_x = (LOOK == "A")
    y_ridge, info = roof(body, along_x, x0, x1, z0, z1, HT, pitch_deg=27.0 if along_x else 30.0, antefix=True)
    gable_walls(body, inner, info, x0, x1, z0, z1, HT, base, base_in)
    if not along_x:
        # фронтон к улице: круглое окошко-продух и терракотовый акротерий на коньке
        cz = (z1)
        ring_c = J(P["trim"], 0.03)
        for k in range(10):
            a = 2 * math.pi * k / 10
            body.box((0.17 * math.cos(a), HT + info[4] * 0.4 + 0.17 * math.sin(a), z1 + 0.03), (0.08, 0.08, 0.05), ring_c,
                     Matrix.Rotation(a, 3, "Z"))
        body.box((0.0, HT + info[4] * 0.4, z1 + 0.01), (0.26, 0.26, 0.02), col("#2a2018"))

    # ---- облик A: навес над дверью, скамья, горшки, дрова, корзина; облик B: бельё, амфора, метла, лестница ----
    Pf, U, N = Ps["front"]
    R = Matrix((U, Vector((0, 1, 0)), N)).transposed()
    if LOOK == "A":
        awning(coll, "Awning", Pf, U, N, (door_u[0] + door_u[1]) / 2, PL + 1.82, 1.3, 0.7, ("#efe3c8", "#b5452f"))
        bench(body, Pw(Pf, 2.6, 0.32, 0.32), 0.95, R)
        pot(body, Pw(Pf, 0.25, 0.0, 0.3), 0.32, J("#b8693f", 0.08))
        pot(body, Pw(Pf, 1.68, 0.0, 0.28), 0.24, J("#c27a4a", 0.08))
        pot(body, Pw(Pf, 3.3, 0.0, 0.3), 0.28, J("#a95f36", 0.08))
        Pl, Ul, Nl = Ps["left"]
        firewood(body, Pw(Pl, (D - 2 * T) * 0.62, 0.0, 0.18), Matrix((Ul, Vector((0, 1, 0)), Nl)).transposed() @ Matrix.Rotation(math.pi / 2, 3, "Y"), 11)
        basket(body, Pw(Pf, 2.05, 0.0, 0.35), 0.13, 0.2)
    else:
        amphora(body, Pw(Pf, (door_u[0]) - 0.3, 0.0, 0.25), 0.6, J("#c27a4a", 0.08))
        amphora(body, Pw(Pf, (door_u[0]) - 0.55, 0.0, 0.2), 0.5, J("#b5703f", 0.08))
        # метла у двери
        bp = Pw(Pf, door_u[1] + 0.22, 0.0, 0.12)
        body.box((bp[0], 0.55, bp[2]), (0.025, 1.0, 0.025), J(P["wood"], 0.05), Matrix.Rotation(0.12, 3, "Z"))
        body.lathe((bp[0] - 0.02, 0.02, bp[2]), [(0.09, 0), (0.06, 0.18), (0.02, 0.26)], 6, J("#c9a46e", 0.06))
        # бельё на верёвке вдоль бока
        Pl, Ul, Nl = Ps["left"]
        Rl = Matrix((Ul, Vector((0, 1, 0)), Nl)).transposed()
        yl = PL + 1.75 if FLOORS == 1 else PL + FLH + 1.6
        p0 = Pl(0.3, yl, 0.35)
        p1 = Pl(D - 2 * T - 0.3, yl, 0.35)
        rope = (p1 - p0)
        body.box(tuple((p0 + p1) / 2), (0.012, 0.012, rope.length), col("#d8cfbf"), Rl @ Matrix.Rotation(0, 3, "Y"))
        for s in (p0, p1):
            body.box((s.x, s.y / 2, s.z), (0.04, s.y, 0.04), J(P["wood"], 0.05))
            body.box(tuple(Pl(0.3 if s is p0 else D - 2 * T - 0.3, yl, 0.17)), (0.03, 0.03, 0.36), J(P["wood"], 0.05), Rl)
        cloths = ["#f4efe2", "#c94f3d", "#4f78a8", "#e8c35a", "#f4efe2"]
        n = 5
        for k in range(n):
            t = (k + 0.7) / (n + 0.4)
            c = p0 + rope * t
            w = rng.uniform(0.22, 0.32)
            h = rng.uniform(0.28, 0.42)
            body.box((c.x, c.y - h / 2 - 0.01, c.z), (0.012, h, w), J(cloths[k], 0.06), Rl)
        # лестница у бока
        Pr, Ur, Nr = Ps["right"]
        Rr = Matrix((Ur, Vector((0, 1, 0)), Nr)).transposed() @ Matrix.Rotation(-0.25, 3, "X")
        lp = Pr((D - 2 * T) * 0.5, 0.0, 0.45)
        for s in (-0.17, 0.17):
            o = Rr @ Vector((s, 0.9, 0))
            body.box((lp.x + o.x, o.y, lp.z + o.z), (0.04, 1.85, 0.04), J(P["wood"], 0.06), Rr)
        for k in range(6):
            o = Rr @ Vector((0, 0.2 + k * 0.3, 0))
            body.box((lp.x + o.x, o.y, lp.z + o.z), (0.34, 0.03, 0.03), J(P["wood"], 0.06), Rr)

    objs = [body.obj(coll), inner.obj(coll)]
    eo = EMB.obj(coll)
    eo.data.materials.clear()
    eo.data.materials.append(mat_emb)
    # роспись: у A — красная предвыборная надпись (как на стенах Помпей), у B — расписной пояс-меандр под карнизом
    Pf, U, N = Ps["front"]
    if LOOK == "A":
        decal(coll, "Notice", Pf, U, N, 1.92, PL + 1.2 if FLOORS == 1 else PL + FLH + 1.15, 0.66, 0.44, "notice.png")
    else:
        decal(coll, "Frieze", Pf, U, N, W / 2, HT - 0.34, W - 0.12, 0.24, "meander.png",
              urep=max(1, round((W - 0.12) / 0.24 / 4.14)))
    return y_ridge


def export_and_preview(y_ridge):
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    plaster_for_export()
    bpy.ops.object.select_all(action="SELECT")
    tris = 0
    for ob in bpy.context.scene.objects:
        if ob.type == "MESH":
            me = ob.data
            me.calc_loop_triangles()
            tris += len(me.loop_triangles)
    try:
        bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_yup=True,
                                  export_apply=True, export_vertex_color="ACTIVE", export_all_vertex_colors=False)
    except TypeError:
        bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_yup=True,
                                  export_apply=True, export_colors=True)
    print("KIT_OUT", OUT, "tris", tris, "ridge", round(y_ridge, 2), "W", W, "D", D)
    if not PNG:
        return
    m = bpy.data.materials.get("CivPlaster")
    if m:          # для картинки — снова цвет × текстура
        nt = m.node_tree
        mix = [n for n in nt.nodes if n.type == "MIX"][0]
        nt.links.new(mix.outputs[2], nt.nodes["Principled BSDF"].inputs["Base Color"])
    scn = bpy.context.scene
    # земля
    bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, -0.001))
    g = bpy.context.active_object
    gm = bpy.data.materials.new("Ground")
    gm.use_nodes = True
    gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = lin("#a89a78")
    g.data.materials.append(gm)
    # солнце и небо
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.2
    sun.data.angle = math.radians(3)
    sun.data.color = (1.0, 0.95, 0.86)
    sun.rotation_euler = (math.radians(50), 0, math.radians(-35))
    scn.collection.objects.link(sun)
    scn.world = bpy.data.worlds.new("W")
    scn.world.use_nodes = True
    bg = scn.world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = lin("#a9c3dc")
    bg.inputs["Strength"].default_value = 0.9
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scn.collection.objects.link(cam)
    scn.camera = cam
    cam.data.lens = 50
    hgt = y_ridge
    tgt = Vector((0.2, 0.0, hgt * 0.45))         # Blender: z вверх, фасад смотрит на −Y
    pos = tgt + Vector((5.2, -9.2, 5.6)) * (0.8 + 0.12 * FLOORS)
    cam.location = pos
    cam.rotation_euler = (tgt - pos).to_track_quat("-Z", "Y").to_euler()
    scn.render.resolution_x = 1100
    scn.render.resolution_y = 1000
    scn.render.film_transparent = False
    try:
        scn.render.engine = "BLENDER_EEVEE_NEXT"
    except TypeError:
        scn.render.engine = "BLENDER_EEVEE"
    try:
        scn.eevee.taa_render_samples = 48
        scn.eevee.use_shadows = True
    except Exception:
        pass
    scn.view_settings.view_transform = "AgX" if "AgX" in [i.identifier for i in scn.view_settings.bl_rna.properties["view_transform"].enum_items] else "Filmic"
    scn.view_settings.look = "None"
    scn.render.filepath = OUT[:-4] + ".png"
    bpy.ops.render.render(write_still=True)
    print("KIT_PNG", scn.render.filepath)


if __name__ == "__main__":
    yr = build()
    export_and_preview(yr)
