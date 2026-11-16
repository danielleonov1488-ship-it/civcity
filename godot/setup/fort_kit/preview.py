"""Render all fort GLBs as a 1600 x 900 Eevee contact sheet (Blender 4.5).

blender -b -P preview.py -- in=D:/path/to/fort out=D:/path/to/preview.png
Uses Blender and the Python standard library; keeps individual tile PNGs.
"""
from __future__ import annotations

import math
from pathlib import Path
import struct
import sys
import zlib


DEFAULT_IN = Path(__file__).resolve().parents[2] / "assets" / "fort"
DEFAULT_OUT = Path("D:/CivCity/.work/stage3/fortart/preview.png")
ORDER = ("palisade_seg", "palisade_seg_b", "tower", "gate", "bridge",
         "tent_small", "tent_long", "tent_command", "stakes_row")
WIDTH, HEIGHT = 1600, 900


def png_chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff)


def png_bytes(width, height, rgba):
    """Encode display-referred RGBA unchanged; no second AgX conversion."""
    stride = width * 4
    if len(rgba) != stride * height:
        raise ValueError("Invalid contact sheet pixel count")
    raw = b"".join(b"\0" + rgba[y * stride:(y + 1) * stride] for y in range(height))
    return (b"\x89PNG\r\n\x1a\n" + png_chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
            + png_chunk(b"sRGB", b"\0") + png_chunk(b"IDAT", zlib.compress(raw, 6)) + png_chunk(b"IEND", b""))


def read_png(path):
    """Decode Blender's non-interlaced RGBA8 PNG, including all five filters."""
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"Invalid PNG: {path}")
    offset, packed, header = 8, bytearray(), None
    while offset < len(data):
        size = struct.unpack_from(">I", data, offset)[0]
        kind = data[offset + 4:offset + 8]
        body = data[offset + 8:offset + 8 + size]
        crc = struct.unpack_from(">I", data, offset + 8 + size)[0]
        if zlib.crc32(kind + body) & 0xffffffff != crc:
            raise ValueError(f"Corrupt PNG: {path}")
        if kind == b"IHDR":
            header = struct.unpack(">IIBBBBB", body)
        elif kind == b"IDAT":
            packed.extend(body)
        offset += size + 12
        if kind == b"IEND":
            break
    if header is None or header[2:] != (8, 6, 0, 0, 0):
        raise ValueError(f"Expected non-interlaced RGBA8: {path}")
    width, height = header[:2]
    raw = zlib.decompress(packed)
    stride = width * 4
    if len(raw) != (stride + 1) * height:
        raise ValueError(f"Wrong PNG payload size: {path}")
    rgba, previous = bytearray(), bytearray(stride)
    for y in range(height):
        start = y * (stride + 1)
        filter_type = raw[start]
        row = bytearray(raw[start + 1:start + 1 + stride])
        for x in range(stride):
            left = row[x - 4] if x >= 4 else 0
            above = previous[x]
            upper_left = previous[x - 4] if x >= 4 else 0
            if filter_type == 0:
                predictor = 0
            elif filter_type == 1:
                predictor = left
            elif filter_type == 2:
                predictor = above
            elif filter_type == 3:
                predictor = (left + above) // 2
            elif filter_type == 4:
                p = left + above - upper_left
                distances = (abs(p - left), abs(p - above), abs(p - upper_left))
                predictor = (left, above, upper_left)[distances.index(min(distances))]
            else:
                raise ValueError(f"Unknown PNG filter: {filter_type}")
            row[x] = (row[x] + predictor) & 255
        rgba.extend(row)
        previous = row
    return width, height, rgba


def options(argv):
    args = argv[argv.index("--") + 1:] if "--" in argv else argv[1:]
    result = {"in": DEFAULT_IN, "out": DEFAULT_OUT}
    for arg in args:
        if "=" not in arg or arg.split("=", 1)[0] not in result:
            raise ValueError(f"Unknown argument: {arg}")
        key, value = arg.split("=", 1)
        result[key] = Path(value).expanduser().resolve()
    return result


def material(bpy, name, color, emission=False):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    if emission:
        nodes = mat.node_tree.nodes
        output = nodes.get("Material Output")
        shader = nodes.new("ShaderNodeEmission")
        shader.inputs["Color"].default_value = (*color, 1)
        mat.node_tree.links.new(shader.outputs[0], output.inputs["Surface"])
    else:
        shader = mat.node_tree.nodes.get("Principled BSDF")
        shader.inputs["Base Color"].default_value = (*color, 1)
        shader.inputs["Roughness"].default_value = 0.9
    return mat


def new_object(bpy, scene, name, data):
    obj = bpy.data.objects.new(name, data)
    scene.collection.objects.link(obj)
    return obj


def point_at(obj, point):
    obj.rotation_euler = (point - obj.location).to_track_quat("-Z", "Y").to_euler()


def add_label(bpy, scene, camera, name, text, x, y, size, mat):
    curve = bpy.data.curves.new(name, "FONT")
    curve.body = text
    curve.size = size
    curve.align_x = "LEFT"
    curve.align_y = "BOTTOM_BASELINE"
    obj = new_object(bpy, scene, name, curve)
    obj.parent = camera
    obj.location = (x, y, -1.0)
    curve.materials.append(mat)
    # Text lies between camera and model; no physical support or ground shadow.
    if hasattr(obj, "visible_shadow"):
        obj.visible_shadow = False


def render_tile(bpy, Vector, filename, tile_path, width, height, ground_mat, text_mat):
    scene = bpy.data.scenes.new("Preview " + filename.stem)
    bpy.context.window.scene = scene
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x = width
    scene.render.resolution_y = height
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = False
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.render.filepath = str(tile_path)
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.exposure = 0
    scene.view_settings.gamma = 1
    # No saved .blend scene is changed or removed.
    scene.world = bpy.data.worlds.new("Fort daylight " + filename.stem)
    scene.world.use_nodes = True
    background = scene.world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = (0.72, 0.78, 0.86, 1)
    background.inputs["Strength"].default_value = 0.45
    bpy.ops.import_scene.gltf(filepath=str(filename))
    imported = list(scene.objects)
    meshes = [obj for obj in imported if obj.type == "MESH"]
    if not meshes:
        raise RuntimeError(f"No meshes in {filename}")
    bpy.context.view_layer.update()
    points = [obj.matrix_world @ Vector(corner) for obj in meshes for corner in obj.bound_box]
    lo = Vector(tuple(min(p[i] for p in points) for i in range(3)))
    hi = Vector(tuple(max(p[i] for p in points) for i in range(3)))
    # GLTF importer returns the exported Y-up kit to Blender Z-up.
    center = (lo + hi) * 0.5
    dims = hi - lo
    camera_data = bpy.data.cameras.new("Fort orthographic")
    camera = new_object(bpy, scene, "Fort camera", camera_data)
    camera_data.type = "ORTHO"
    camera_data.clip_start = 0.05
    camera_data.clip_end = 300
    camera.location = center + Vector((8, -12, 8)).normalized() * 35
    point_at(camera, center)
    scene.camera = camera
    bpy.context.view_layer.update()
    inv = camera.matrix_world.inverted()
    projected = [inv @ p for p in points]
    xmin, xmax = min(p.x for p in projected), max(p.x for p in projected)
    ymin, ymax = min(p.y for p in projected), max(p.y for p in projected)
    camera_data.ortho_scale = 1
    frame = camera_data.view_frame(scene=scene)
    unit_width = max(p.x for p in frame) - min(p.x for p in frame)
    unit_height = max(p.y for p in frame) - min(p.y for p in frame)
    # Reserve lower 18% for captions and another margin for soft shadows.
    camera_data.ortho_scale = max((xmax - xmin) / (unit_width * 0.82),
                                  (ymax - ymin) / (unit_height * 0.70))
    frame = camera_data.view_frame(scene=scene)
    view_w = max(p.x for p in frame) - min(p.x for p in frame)
    view_h = max(p.y for p in frame) - min(p.y for p in frame)
    right = camera.rotation_euler.to_matrix() @ Vector((1, 0, 0))
    up = camera.rotation_euler.to_matrix() @ Vector((0, 1, 0))
    camera.location += right * ((xmin + xmax) / 2) + up * ((ymin + ymax) / 2 - view_h * 0.07)
    # A large plane avoids a visible horizon in every orthographic cell.
    ground_mesh = bpy.data.meshes.new("Ground")
    ground_mesh.from_pydata([(-100, -100, lo.z - 0.018), (100, -100, lo.z - 0.018),
                            (100, 100, lo.z - 0.018), (-100, 100, lo.z - 0.018)], [], [(0, 1, 2, 3)])
    ground = new_object(bpy, scene, "Light grey ground", ground_mesh)
    ground.data.materials.append(ground_mat)
    sun_data = bpy.data.lights.new("Warm sunlight", "SUN")
    sun_data.energy = 2.1
    sun_data.color = (1.0, 0.86, 0.68)
    sun_data.angle = math.radians(12)
    sun = new_object(bpy, scene, "Warm sunlight", sun_data)
    sun.location = center + Vector((-7, -9, 14))
    point_at(sun, center)
    fill_data = bpy.data.lights.new("Soft fill", "AREA")
    fill_data.energy = 900
    fill_data.shape = "DISK"
    fill_data.size = 9
    fill = new_object(bpy, scene, "Soft fill", fill_data)
    fill.location = center + Vector((5, -2, 9))
    point_at(fill, center)
    add_label(bpy, scene, camera, "Piece label", filename.stem,
              -view_w * 0.46, -view_h * 0.405, view_h * 0.048, text_mat)
    caption = f"{dims.x:.2f} x {dims.y:.2f} x {dims.z:.2f} m  |  independent scale"
    add_label(bpy, scene, camera, "Size label", caption,
              -view_w * 0.46, -view_h * 0.466, view_h * 0.033, text_mat)
    bpy.ops.render.render(write_still=True)
    result_w, result_h, pixels = read_png(tile_path)
    if (result_w, result_h) != (width, height):
        raise RuntimeError(f"Invalid render result for {filename}")
    print(f"FORT PREVIEW TILE {filename.name} {width}x{height}")
    return pixels


def main():
    opts = options(sys.argv)
    files = sorted(opts["in"].glob("*.glb"),
                   key=lambda p: (ORDER.index(p.stem) if p.stem in ORDER else len(ORDER), p.name))
    if not files:
        raise FileNotFoundError(f"No GLBs in {opts['in']}; run fort_kit.py first")
    if opts["out"].exists():
        raise FileExistsError(f"Preserving {opts['out']}; choose a new out= PNG path")
    tile_dir = opts["out"].parent / (opts["out"].stem + "_tiles")
    for filename in files:
        if (tile_dir / (filename.stem + ".png")).exists():
            raise FileExistsError(f"Preserving tiles in {tile_dir}; choose a new out= PNG path")
    import bpy
    from mathutils import Vector
    if bpy.app.version < (4, 5, 0):
        raise RuntimeError("Blender 4.5 or later is required")
    columns = 3 if len(files) <= 9 else math.ceil(math.sqrt(len(files) * WIDTH / HEIGHT))
    rows = math.ceil(len(files) / columns)
    cell_w, cell_h = WIDTH // columns, HEIGHT // rows
    tile_w, tile_h = cell_w - 8, cell_h - 8
    if min(tile_w, tile_h) < 32:
        raise ValueError("Too many GLBs for a legible 1600 x 900 sheet")
    tile_dir.mkdir(parents=True, exist_ok=True)
    ground_mat = material(bpy, "Preview light grey", (0.67, 0.68, 0.67))
    text_mat = material(bpy, "Preview ink", (0.035, 0.029, 0.022), emission=True)
    sheet_pixels = bytearray((217, 218, 217, 255)) * (WIDTH * HEIGHT)
    for i, filename in enumerate(files):
        pixels = render_tile(bpy, Vector, filename, tile_dir / (filename.stem + ".png"),
                             tile_w, tile_h, ground_mat, text_mat)
        x = (i % columns) * cell_w + 4
        y = (i // columns) * cell_h + 4
        for row in range(tile_h):
            dst = ((y + row) * WIDTH + x) * 4
            src = row * tile_w * 4
            sheet_pixels[dst:dst + tile_w * 4] = pixels[src:src + tile_w * 4]
    opts["out"].parent.mkdir(parents=True, exist_ok=True)
    opts["out"].write_bytes(png_bytes(WIDTH, HEIGHT, sheet_pixels))
    if not opts["out"].is_file():
        raise RuntimeError("Contact sheet was not saved")
    print(f"FORT PREVIEW DONE {opts['out']} {WIDTH}x{HEIGHT} ({len(files)} pieces)")


if __name__ == "__main__":
    main()
