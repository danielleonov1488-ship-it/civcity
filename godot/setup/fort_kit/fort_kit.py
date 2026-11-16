"""CivCity fort kit. Blender 4.5; geometry checks also run in ordinary Python.

blender -b -P fort_kit.py -- out=D:/path/to/new/fort
python -B fort_kit.py --check
"""
from __future__ import annotations

import json
import math
from pathlib import Path
import random
import sys


DEFAULT_OUT = Path(__file__).resolve().parents[2] / "assets" / "fort"
DEFAULT_TEXTURES = Path("D:/CivCity/godot/assets/synty/Textures/Base")
NAMES = (
    "palisade_seg", "palisade_seg_b", "tower", "gate", "bridge",
    "tent_small", "tent_long", "tent_command", "stakes_row",
)
COLORS = {"canvas": "E9DCC0", "red": "B23A2E", "rope": "8A6A45"}


def add(a, b):
    return tuple(x + y for x, y in zip(a, b))


def sub(a, b):
    return tuple(x - y for x, y in zip(a, b))


def mul(a, s):
    return tuple(x * s for x in a)


def dot(a, b):
    return sum(x * y for x, y in zip(a, b))


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1],
            a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def length(v):
    return math.sqrt(dot(v, v))


def unit(v):
    n = length(v)
    if n < 1e-9:
        raise ValueError("Zero length member")
    return mul(v, 1.0 / n)


def axes(a, b):
    z = unit(sub(b, a))
    helper = (0, 1, 0) if abs(z[1]) < 0.9 else (1, 0, 0)
    x = unit(cross(helper, z))
    return x, cross(z, x), z


class Mesh:
    """One mesh, indexed faces, per-corner UVs; no Blender dependency."""

    def __init__(self, name, materials):
        self.name = name
        self.materials = materials
        self.vertices = []
        self.faces = []
        self.uvs = []
        self.slots = []
        self.details = {}

    def surface(self, vertices, faces, material=0, uvs=None):
        offset = len(self.vertices)
        self.vertices.extend(vertices)
        for i, face in enumerate(faces):
            self.faces.append(tuple(offset + v for v in face))
            self.slots.append(material)
            # Canvas UVs are harmless; wood always supplies metric UVs.
            self.uvs.append(uvs[i] if uvs else [(vertices[v][0], vertices[v][2]) for v in face])

    def panel(self, points, material=0):
        self.surface(points, [tuple(range(len(points)))], material)

    def beam(self, a, b, width, depth=None, material=0, x_axis=None):
        """Rectangular member. V follows its length, including diagonal braces."""
        depth = width if depth is None else depth
        x, y, z = axes(a, b)
        if x_axis is not None:
            x = unit(x_axis)
            if abs(dot(x, z)) > 1e-6:
                raise ValueError("Beam cross-section is not perpendicular")
            y = cross(z, x)
        vertices = []
        for c in (a, b):
            for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                vertices.append(add(c, add(mul(x, sx * width / 2), mul(y, sy * depth / 2))))
        faces = [(3, 2, 1, 0), (4, 5, 6, 7)]
        uv = [[(0, 0), (width, 0), (width, depth), (0, depth)]] * 2
        for i in range(4):
            j = (i + 1) % 4
            faces.append((i, j, j + 4, i + 4))
            span = width if i % 2 == 0 else depth
            # One texture repeat along two metres; narrow U avoids giant grain.
            uv.append([(0.07, 0), (0.07 + span / 2, 0),
                       (0.07 + span / 2, length(sub(b, a)) / 2),
                       (0.07, length(sub(b, a)) / 2)])
        self.surface(vertices, faces, material, uv)

    def pole(self, a, b, radius, material=0, sides=8, tip=0.0, phase=0.0):
        """Faceted cylinder, optionally ending in a real sharpened cone."""
        x, y, z = axes(a, b)
        n = length(sub(b, a))
        shoulder = sub(b, mul(z, tip))
        vertices = []
        for c in (a, shoulder):
            for i in range(sides):
                angle = phase + 2 * math.pi * i / sides
                vertices.append(add(c, add(mul(x, math.cos(angle) * radius),
                                          mul(y, math.sin(angle) * radius))))
        faces = [tuple(reversed(range(sides)))]
        uv = [[(0.5 + math.cos(2 * math.pi * i / sides) * radius,
                0.5 + math.sin(2 * math.pi * i / sides) * radius)
               for i in reversed(range(sides))]]
        for i in range(sides):
            j = (i + 1) % sides
            faces.append((i, j, j + sides, i + sides))
            u0, u1 = i / sides * math.pi * radius, (i + 1) / sides * math.pi * radius
            uv.append([(u0, 0), (u1, 0), (u1, (n - tip) / 2), (u0, (n - tip) / 2)])
        if tip:
            vertices.append(b)
            for i in range(sides):
                faces.append((sides + i, sides + (i + 1) % sides, sides * 2))
                uv.append([(i / sides * math.pi * radius, (n - tip) / 2),
                           ((i + 1) / sides * math.pi * radius, (n - tip) / 2),
                           ((i + 0.5) / sides * math.pi * radius, n / 2)])
        else:
            faces.append(tuple(range(sides, sides * 2)))
            uv.append([(vertices[i][0], vertices[i][1]) for i in range(sides, sides * 2)])
        self.surface(vertices, faces, material, uv)

    def rope(self, a, b):
        # Two straight spans suggest a little sag without curves or subdivision.
        mid = add(mul(add(a, b), 0.5), (0, 0, -0.035))
        self.pole(a, mid, 0.018, material=2, sides=6)
        self.pole(mid, b, 0.018, material=2, sides=6)

    def ground(self):
        zmin = min(v[2] for v in self.vertices)
        self.vertices = [(x, y, z - zmin) for x, y, z in self.vertices]
        return self

    def bounds(self):
        return [[min(v[i] for v in self.vertices) for i in range(3)],
                [max(v[i] for v in self.vertices) for i in range(3)]]

    def validate(self):
        assert 1 <= len(self.materials) <= 3, self.name
        assert len(self.faces) == len(self.slots) == len(self.uvs)
        assert all(math.isfinite(c) for v in self.vertices for c in v)
        for face, slot, uv in zip(self.faces, self.slots, self.uvs):
            assert 0 <= slot < len(self.materials)
            assert len(face) == len(uv) and len(set(face)) == len(face)
            assert all(math.isfinite(c) for pair in uv for c in pair)
            a = self.vertices[face[0]]
            for i in range(1, len(face) - 1):
                assert length(cross(sub(self.vertices[face[i]], a),
                                    sub(self.vertices[face[i + 1]], a))) > 1e-10, self.name
        assert abs(self.bounds()[0][2]) < 1e-8, self.name
        assert self.triangles() < 16000, self.name

    def triangles(self):
        return sum(len(f) - 2 for f in self.faces)


def palisade(name, seed):
    mesh = Mesh(name, ["wood_log", "wood_plank"])
    rng = random.Random(seed)
    heights, leans = [], []
    for i in range(8):
        x = -0.875 + i * 0.25
        h = rng.uniform(3.3, 3.9)
        # Lean towards/away from camp; exact 2 m modular width stays intact.
        lean = rng.uniform(-2.0, 2.0)
        mesh.pole((x, 0, 0), (x, math.tan(math.radians(lean)) * h, h),
                  0.125, sides=8, tip=0.32)
        heights.append(h)
        leans.append(lean)
    mesh.beam((-1, 0.22, 2.35), (1, 0.22, 2.35), 0.22, 0.18, material=1)
    mesh.details = {"seed": seed, "log_heights": heights, "lean_degrees": leans,
                    "module_width": 2.0, "inner_side": "+Y in Blender / -Z in Godot"}
    return mesh.ground()


def railing(mesh, a, b, bottom, top, panels=3):
    a, b = (*a, bottom), (*b, bottom)
    span = sub(b, a)
    for z in (bottom + 0.12, top):
        mesh.beam((a[0], a[1], z), (b[0], b[1], z), 0.11, material=1)
    for i in range(panels + 1):
        p = add(a, mul(span, i / panels))
        mesh.beam(p, (p[0], p[1], top + 0.06), 0.12)
    for i in range(panels):
        p = add(a, mul(span, (i + 0.08) / panels))
        q = add(a, mul(span, (i + 0.92) / panels))
        mesh.beam((p[0], p[1], bottom + 0.2), (q[0], q[1], top - 0.08), 0.07, material=1)
        mesh.beam((q[0], q[1], bottom + 0.2), (p[0], p[1], top - 0.08), 0.07, material=1)


def tower():
    mesh = Mesh("tower", ["wood_log", "wood_plank"])
    corners = [(-1.23, -1.23), (1.23, -1.23), (1.23, 1.23), (-1.23, 1.23)]
    for x, y in corners:
        mesh.beam((x, y, 0), (x, y, 9), 0.36)
        mesh.pole((x, y, 9), (x, y, 9.1), 0.22, material=1)
    for lo, hi in ((0.35, 3.88), (4.37, 7.63)):
        for i, p in enumerate(corners):
            q = corners[(i + 1) % 4]
            # Offset crossing braces slightly to avoid coplanar surfaces.
            outward = mul(unit((p[0] + q[0], p[1] + q[1], 0)), 0.11)
            mesh.beam(add((*p, lo), outward), add((*q, hi), outward), 0.18)
            mesh.beam(sub((*q, lo), outward), sub((*p, hi), outward), 0.18)
    for floor in (4.1, 7.85):
        for y in (-1.25, 1.25):
            mesh.beam((-1.48, y, floor - 0.2), (1.48, y, floor - 0.2), 0.25)
        # The last three planks leave a ladder hatch in the rear-right corner.
        for i in range(15):
            x = -1.4 + i * 0.2
            end = 0.5 if i >= 11 else 1.5
            mesh.beam((x, -1.5, floor), (x, end, floor), 0.19, 0.13, material=1,
                      x_axis=(1, 0, 0))
        for i, p in enumerate([(-1.43, -1.43), (1.43, -1.43), (1.43, 1.43), (-1.43, 1.43)]):
            q = [(-1.43, -1.43), (1.43, -1.43), (1.43, 1.43), (-1.43, 1.43)][(i + 1) % 4]
            railing(mesh, p, q, floor + 0.07, floor + 1.05)
    # Interior ladder reaches through both hatches, including ground access.
    for z0, z1 in ((0.08, 4.35), (4.18, 8.12)):
        a, b = (1.02, 0.62, z0), (1.02, 1.15, z1)
        for dx in (-0.23, 0.23):
            mesh.beam(add(a, (dx, 0, 0)), add(b, (dx, 0, 0)), 0.075, material=1)
        for i in range(1, 13):
            p = add(a, mul(sub(b, a), i / 13))
            mesh.beam(add(p, (-0.23, 0, 0)), add(p, (0.23, 0, 0)), 0.06, material=1)
    mesh.details = {"platform_heights": [4.1, 7.85], "ladder_hatches": True}
    return mesh.ground()


def gate():
    mesh = Mesh("gate", ["wood_log", "wood_plank"])
    for x in (-2.45, 2.45):
        mesh.beam((x, 0, 0), (x, 0, 4.45), 0.4)
        mesh.beam((x, 0, 4.45), (x, 0, 4.57), 0.52, material=1)
    mesh.beam((-2.65, 0, 4.22), (2.65, 0, 4.22), 0.32)
    for side in (-1, 1):
        theta = math.radians(70)
        along = (-side * math.cos(theta), math.sin(theta), 0)
        hinge = (side * 2.22, 0, 0)

        def point(u, z, behind=0.0):
            return add(add(hinge, mul(along, u)),
                       add((0, 0, z), mul(cross((0, 0, 1), along), behind)))

        for i in range(8):
            u = (i + 0.5) * 2.2 / 8
            mesh.beam(point(u, 0.12), point(u, 3.52), 0.267, 0.12,
                      material=1, x_axis=along)
        for z in (0.55, 2.85):
            mesh.beam(point(0.03, z, 0.09), point(2.16, z, 0.09), 0.15)
        mesh.beam(point(0.1, 0.67, 0.1), point(2.1, 2.75, 0.1), 0.13)
        # Wooden hinge barrels keep the two-material palette.
        for z in (0.6, 2.9):
            mesh.pole(point(0.015, z - 0.13), point(0.015, z + 0.13), 0.105)
    mesh.details = {"clear_opening": 4.5, "leaf_angle_degrees": 70, "inward": "+Y"}
    return mesh.ground()


def bridge():
    mesh = Mesh("bridge", ["wood_log", "wood_plank"])
    for x in (-1.08, 1.08):
        mesh.beam((x, -3, 0.17), (x, 3, 0.17), 0.28, 0.34, x_axis=(1, 0, 0))
    for i in range(30):
        y = -2.9 + i * 0.2
        mesh.beam((-1.75, y, 0.41), (1.75, y, 0.41), 0.18, 0.15,
                  material=1, x_axis=(0, 1, 0))
    for x in (-1.60, 1.60):
        for y in (-2.85, -1.425, 0, 1.425, 2.85):
            mesh.beam((x, y, 0.32), (x, y, 1.35), 0.2)
            mesh.pole((x, y, 1.35), (x, y, 1.43), 0.145, material=1)
        for z in (0.82, 1.28):
            mesh.beam((x, -3, z), (x, 3, z), 0.13, material=1)
    mesh.details = {"deck_top": 0.485, "size": [3.5, 6.0]}
    return mesh.ground()


def peg(mesh, x, y):
    mesh.pole((x, y, 0), (x + 0.035, y, 0.28), 0.045, material=2, sides=6)
    return (x, y, 0.17)


def tent(name, width, depth, height, pole_count):
    mesh = Mesh(name, ["canvas", "red", "rope"])
    half, front, back = width / 2, -depth / 2, depth / 2
    eave, base = height * 0.43, 0.08
    for side in (-1, 1):
        x = side * half
        roof = [(0, front, height), (x, front, eave), (x, back, eave), (0, back, height)]
        if side < 0:
            roof.reverse()
        mesh.panel(roof)
        wall = [(x, front, base), (x, back, base), (x, back, eave), (x, front, eave)]
        if side < 0:
            wall.reverse()
        mesh.panel(wall)
        # Red hem replaces the lower panel; no coplanar decal geometry.
        hem = [(x, front, base), (x, back, base), (x, back, base + 0.16), (x, front, base + 0.16)]
        wall_low = len(mesh.faces) - 1
        for vi in mesh.faces[wall_low]:
            vx, vy, vz = mesh.vertices[vi]
            if abs(vz - base) < 1e-8:
                mesh.vertices[vi] = (vx, vy, base + 0.16)
        if side < 0:
            hem.reverse()
        mesh.panel(hem, 1)
        # Eave valance, subtly outside the side wall.
        mesh.panel([(x + side * 0.014, front, eave + 0.02),
                    (x + side * 0.014, back, eave + 0.02),
                    (x + side * 0.014, back, eave - 0.12),
                    (x + side * 0.014, front, eave - 0.12)], 1)
    mesh.panel([(-half, back, base), (half, back, base), (half, back, eave),
                (0, back, height), (-half, back, eave)])
    # Tied-back flaps expose the interior. The apex stays joined at the ridge.
    for side in (-1, 1):
        x, neck = side * half, side * half * 0.82
        mesh.panel([(0, front - 0.012, height), (x, front - 0.012, eave),
                    (neck, front - 0.11, eave * 0.55)])
        mesh.panel([(x, front - 0.012, eave), (x, front, base),
                    (side * half * 0.5, front - 0.04, base),
                    (neck, front - 0.11, eave * 0.55)])
        mesh.pole((neck - 0.07, front - 0.12, eave * 0.55),
                  (neck + 0.07, front - 0.12, eave * 0.55), 0.027, material=2, sides=6)
        # Red diagonal front binding frames the open entrance.
        mesh.panel([(0, front - 0.025, height), (x, front - 0.025, eave),
                    (x, front - 0.025, eave - 0.09), (0, front - 0.025, height - 0.09)], 1)
    pole_ys = [front + 0.12 + i * (depth - 0.24) / (pole_count - 1) for i in range(pole_count)]
    for y in pole_ys:
        mesh.pole((0, y, 0), (0, y, height - 0.025), 0.055, material=2)
    mesh.pole((0, front, height - 0.055), (0, back, height - 0.055), 0.045, material=2)
    for side in (-1, 1):
        for y in pole_ys:
            target = peg(mesh, side * (half + 0.65), y)
            mesh.rope((side * half, y, eave), target)
    for y, sign in ((front, -1), (back, 1)):
        mesh.rope((0, y, height - 0.05), peg(mesh, 0, y + sign * 0.7))
    mesh.details = {"canvas_size": [width, depth, height], "poles": pole_count,
                    "front": "-Y in Blender / +Z in Godot",
                    "pole_material": "rope brown; no fourth material"}
    return mesh.ground()


def command_tent():
    mesh = Mesh("tent_command", ["canvas", "red", "rope"])
    w, front, back, eave, peak = 3.0, -2.5, 2.5, 2.2, 3.8
    # Short ridge and hipped ends match the command marquee silhouette.
    ridge_front, ridge_back = (0, -0.8, peak), (0, 0.8, peak)
    for side in (-1, 1):
        x = side * w
        # Alternate broad cream panels with narrow red roof stripes.
        for t0, t1, slot in ((0, 0.10, 1), (0.10, 0.48, 0), (0.48, 0.55, 1), (0.55, 1, 0)):
            def p(t, y, r):
                return add(mul(r, 1 - t), mul((x, y, eave), t))
            mesh.panel([p(t0, front, ridge_front), p(t1, front, ridge_front),
                        p(t1, back, ridge_back), p(t0, back, ridge_back)], slot)
        mesh.panel([(x, front, 0.24), (x, back, 0.24), (x, back, eave), (x, front, eave)])
        mesh.panel([(x, front, 0.08), (x, back, 0.08), (x, back, 0.24), (x, front, 0.24)], 1)
    # Split the hip triangles to make a central red stripe actual geometry.
    for y, ridge in ((front, ridge_front), (back, ridge_back)):
        for x0, x1, slot in ((-w, -0.38, 0), (-0.38, 0.38, 1), (0.38, w, 0)):
            mesh.panel([(x0, y, eave), (x1, y, eave), ridge], slot)
    mesh.panel([(-w, back, 0.24), (w, back, 0.24), (w, back, eave), (-w, back, eave)])
    mesh.panel([(-w, back, 0.08), (w, back, 0.08), (w, back, 0.24), (-w, back, 0.24)], 1)
    # Wide walk-in front with gathered side curtains.
    for side in (-1, 1):
        mesh.panel([(side * 0.95, front, eave), (side * w, front, eave),
                    (side * w, front, 0.08), (side * 1.2, front, 0.08),
                    (side * 2.05, front - 0.12, 1.05)])
        mesh.pole((side * 1.87, front - 0.14, 1.05),
                  (side * 2.2, front - 0.14, 1.05), 0.035, material=2, sides=6)
    # Faceted scalloped valance on all four sides.
    corners = [(-w, front), (w, front), (w, back), (-w, back)]
    for i, a in enumerate(corners):
        b = corners[(i + 1) % 4]
        for j in range(12):
            p = tuple(a[k] + (b[k] - a[k]) * j / 12 for k in range(2))
            q = tuple(a[k] + (b[k] - a[k]) * (j + 1) / 12 for k in range(2))
            outward = unit((a[0] + b[0], a[1] + b[1], 0))
            mesh.panel([add((*p, eave + 0.025), mul(outward, 0.025)),
                        add((*q, eave + 0.025), mul(outward, 0.025)),
                        add((*q, eave - 0.12), mul(outward, 0.025)),
                        add(((p[0] + q[0]) / 2, (p[1] + q[1]) / 2, eave - 0.22), mul(outward, 0.025)),
                        add((*p, eave - 0.12), mul(outward, 0.025))], 1)
    for y in (-0.8, 0.8):
        mesh.pole((0, y, 0), (0, y, peak + 0.08), 0.075, material=2)
    mesh.pole(ridge_front, ridge_back, 0.06, material=2)
    for x, y in corners:
        mesh.pole((x * 0.99, y * 0.99, 0), (x * 0.99, y * 0.99, eave), 0.055, material=2)
        target = peg(mesh, x + math.copysign(0.7, x), y + math.copysign(0.65, y))
        mesh.rope((x, y, eave), target)
    # Front standard, a notched red cloth with a restrained angular fold.
    mesh.pole((1.05, front - 0.35, 0), (1.05, front - 0.35, 3.65), 0.055, material=2)
    mesh.pole((0.62, front - 0.35, 3.48), (1.48, front - 0.35, 3.48), 0.035, material=2)
    mesh.panel([(0.67, front - 0.38, 3.46), (1.05, front - 0.46, 3.46),
                (1.05, front - 0.46, 2.55), (0.67, front - 0.38, 2.4)], 1)
    mesh.panel([(1.05, front - 0.46, 3.46), (1.43, front - 0.38, 3.46),
                (1.43, front - 0.38, 2.4), (1.05, front - 0.46, 2.55)], 1)
    mesh.details = {"canvas_size": [6, 5, 3.8], "ridge_length": 1.6, "front": "-Y"}
    return mesh.ground()


def stakes():
    mesh = Mesh("stakes_row", ["wood_log", "wood_plank"])
    rng = random.Random(7103)
    for i in range(10):
        x = -1.35 + i * 0.3
        mesh.pole((x, 0.16, 0), (x, -0.15, rng.uniform(0.72, 0.95)),
                  0.075, sides=6, tip=0.2)
    mesh.beam((-1.46, 0.13, 0.34), (1.46, 0.13, 0.34), 0.10, material=1)
    return mesh.ground()


def build_all():
    return [palisade("palisade_seg", 1729), palisade("palisade_seg_b", 2718),
            tower(), gate(), bridge(), tent("tent_small", 2.6, 3.2, 2.2, 2),
            tent("tent_long", 3.5, 8.0, 2.6, 3), command_tent(), stakes()]


def linear_color(hex_color):
    rgb = [int(hex_color[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in rgb) + (1.0,)


def make_materials(bpy, textures):
    materials = {}
    for name in ("wood_log", "wood_plank", "canvas", "red", "rope"):
        mat = bpy.data.materials.new("fort_" + name)
        mat.use_nodes = True
        mat.diffuse_color = linear_color(COLORS.get(name, "A17A50"))
        mat.use_backface_culling = name.startswith("wood") or name == "rope"
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value = mat.diffuse_color
        bsdf.inputs["Roughness"].default_value = 0.87
        if name.startswith("wood"):
            tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
            filename = "Wood_01.png" if name == "wood_log" else "Wood_02.png"
            tex.image = bpy.data.images.load(str(textures / filename), check_existing=True)
            tex.image.colorspace_settings.name = "sRGB"
            tex.interpolation = "Linear"
            tex.extension = "REPEAT"
            mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        materials[name] = mat
    return materials


def export_piece(bpy, scene, spec, materials, out):
    bpy.ops.object.select_all(action="DESELECT")
    data = bpy.data.meshes.new(spec.name)
    data.from_pydata(spec.vertices, [], spec.faces)
    data.update()
    obj = bpy.data.objects.new(spec.name, data)
    scene.collection.objects.link(obj)
    for name in spec.materials:
        data.materials.append(materials[name])
    uv = data.uv_layers.new(name="UVMap")
    for poly, slot, coords in zip(data.polygons, spec.slots, spec.uvs):
        poly.material_index = slot
        poly.use_smooth = False
        for loop, value in zip(poly.loop_indices, coords):
            uv.data[loop].uv = value
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    # Canvas has open edges; bevel only the solid wooden kit.
    if "canvas" not in spec.materials:
        bevel = obj.modifiers.new("Small timber edges", "BEVEL")
        bevel.width = 0.012
        bevel.segments = 1
        bevel.limit_method = "ANGLE"
        bevel.angle_limit = math.radians(60)
        bevel.affect = "EDGES"
        bpy.ops.object.modifier_apply(modifier=bevel.name)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    # Bevel can shorten extremities; restore the ground datum after evaluation.
    bottom = min(v.co.z for v in obj.data.vertices)
    for v in obj.data.vertices:
        v.co.z -= bottom
    obj.data.update()
    obj.data.calc_loop_triangles()
    triangles = len(obj.data.loop_triangles)
    if triangles > 24000:
        raise RuntimeError(f"Unexpected triangle count: {spec.name}: {triangles}")
    obj["fort_piece"] = spec.name
    obj["units"] = "metres"
    obj["front_blender"] = "-Y"
    bpy.ops.export_scene.gltf(filepath=str(out / (spec.name + ".glb")),
                              export_format="GLB", use_selection=True,
                              export_yup=True, export_apply=True,
                              export_texcoords=True, export_normals=True,
                              export_materials="EXPORT", export_image_format="NONE",   # картинки Synty в GLB не кладём (их не коммитят) — дерево Synty подставит игра
                              export_animations=False, export_cameras=False,
                              export_lights=False, export_extras=True)
    if not (out / (spec.name + ".glb")).is_file():
        raise RuntimeError(f"Missing exported GLB: {spec.name}")
    bounds = [[min(v.co[i] for v in obj.data.vertices) for i in range(3)],
              [max(v.co[i] for v in obj.data.vertices) for i in range(3)]]
    obj.hide_set(True)
    obj.select_set(False)
    print(f"FORT EXPORT {spec.name}.glb triangles={triangles} materials={len(spec.materials)}")
    return {"file": spec.name + ".glb", "meshes": 1, "triangles": triangles,
            "materials": spec.materials, "bounds_blender": bounds, "details": spec.details}


def parse_options(argv):
    args = argv[argv.index("--") + 1:] if "--" in argv else argv[1:]
    options = {"out": DEFAULT_OUT, "textures": DEFAULT_TEXTURES, "check": False}
    for arg in args:
        if arg == "--check":
            options["check"] = True
        elif "=" in arg and arg.split("=", 1)[0] in ("out", "textures"):
            key, value = arg.split("=", 1)
            options[key] = Path(value).expanduser().resolve()
        else:
            raise ValueError(f"Unknown argument: {arg}")
    return options


def check_geometry(pieces):
    assert tuple(p.name for p in pieces) == NAMES
    for piece in pieces:
        piece.validate()
        dims = sub(piece.bounds()[1], piece.bounds()[0])
        print(f"FORT CHECK {piece.name}: {piece.triangles()} base triangles; "
              f"{len(piece.materials)} materials; bounds=" + "/".join(f"{v:.3f}" for v in dims))
    for wall in pieces[:2]:
        assert abs(sub(wall.bounds()[1], wall.bounds()[0])[0] - 2.0) < 1e-8
        assert all(3.3 <= h <= 3.9 for h in wall.details["log_heights"])
        assert all(abs(a) <= 2 for a in wall.details["lean_degrees"])
    assert pieces[0].vertices != pieces[1].vertices
    assert pieces[0].vertices == palisade("palisade_seg", 1729).vertices
    assert pieces[3].details["clear_opening"] == 4.5
    bridge_dims = sub(pieces[4].bounds()[1], pieces[4].bounds()[0])
    assert abs(bridge_dims[0] - 3.5) < 1e-8 and abs(bridge_dims[1] - 6) < 1e-8


def main():
    options = parse_options(sys.argv)
    pieces = build_all()
    check_geometry(pieces)
    if options["check"]:
        print("FORT CHECK DONE (no Blender, no files written)")
        return
    # Fail before touching output if textures or Blender are unavailable.
    import bpy
    if bpy.app.version < (4, 5, 0):
        raise RuntimeError("Blender 4.5 or later is required")
    for filename in ("Wood_01.png", "Wood_02.png"):
        if not (options["textures"] / filename).is_file():
            raise FileNotFoundError(options["textures"] / filename)
    out = options["out"]
    for filename in [name + ".glb" for name in NAMES] + ["fort_manifest.json"]:
        if (out / filename).exists():
            raise FileExistsError(f"Preserving existing file: {out / filename}. Use a new out= directory.")
    out.mkdir(parents=True, exist_ok=True)
    scene = bpy.data.scenes.new("Fort kit export")
    bpy.context.window.scene = scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    materials = make_materials(bpy, options["textures"])
    records = [export_piece(bpy, scene, piece, materials, out) for piece in pieces]
    manifest = {"generator": "fort_kit.py", "blender": bpy.app.version_string,
                "units": "metres", "origin": "ground centre of design footprint",
                "godot_axes": "X right, Y up, +Z front; camp interior -Z",
                "licensed_textures": "Synty Wood_01/02 embedded in GLB; keep assets private",
                "pieces": records}
    (out / "fort_manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"FORT DONE {out} ({len(records)} pieces)")


if __name__ == "__main__":
    main()
