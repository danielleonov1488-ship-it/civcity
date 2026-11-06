# Значки нового интерфейса (гибрид 1): кнопки скорости, «закрыть», меню — тёмно-коричневый знак на светлом кружке
# с тонким кольцом; портреты сословий — в таком же тонком кольце вместо золотого медальона.
# python gen_icons.py <папка assets/ui> (пишет в pa/icons и pa/)
import sys, math
from PIL import Image, ImageDraw, ImageChops
UI = sys.argv[1]
S = 4
N = 128
INK = (91, 59, 34)
TERRA = (176, 72, 44)
PAPER_C = (252, 245, 228); PAPER_E = (236, 222, 190)
CLEAR = (0, 0, 0, 0)


def disc(r, n=N):
    k = Image.new('L', (n * S, n * S), 0)
    c = n * S / 2
    ImageDraw.Draw(k).ellipse([c - r * S, c - r * S, c + r * S, c + r * S], fill=255)
    return k.resize((n, n), Image.LANCZOS)


def put(img, col, mask, a=1.0):
    if a < 1.0:
        mask = mask.point(lambda v: int(v * a))
    img.alpha_composite(Image.composite(Image.new('RGBA', img.size, col + (255,)), Image.new('RGBA', img.size, CLEAR), mask))


def chip():
    img = Image.new('RGBA', (N, N), CLEAR)
    g = Image.new('RGB', (N, N))
    px = g.load()
    for y in range(N):
        for x in range(N):
            t = min(1.0, math.hypot(x - N / 2 + 8, y - N / 2 + 12) / 70)
            px[x, y] = tuple(int(PAPER_C[i] + (PAPER_E[i] - PAPER_C[i]) * t) for i in range(3))
    img.alpha_composite(Image.composite(g.convert('RGBA'), Image.new('RGBA', (N, N), CLEAR), disc(60)))
    put(img, INK, ImageChops.subtract(disc(60), disc(54)))
    return img


def glyph(draw_fn, col=INK, ring=True):
    img = chip() if ring else Image.new('RGBA', (N, N), CLEAR)
    k = Image.new('L', (N * S, N * S), 0)
    draw_fn(ImageDraw.Draw(k), S)
    put(img, col, k.resize((N, N), Image.LANCZOS))
    return img


def pause(d, s):
    d.rounded_rectangle([44 * s, 38 * s, 58 * s, 90 * s], 4 * s, fill=255)
    d.rounded_rectangle([70 * s, 38 * s, 84 * s, 90 * s], 4 * s, fill=255)


def tri(d, s, x, w=30, h=50):
    d.polygon([(x * s, (64 - h / 2) * s), ((x + w) * s, 64 * s), (x * s, (64 + h / 2) * s)], fill=255)


def play(d, s):
    tri(d, s, 50, 34, 52)


def ff(d, s):
    tri(d, s, 36, 28, 46)
    tri(d, s, 64, 28, 46)


def ff3(d, s):
    tri(d, s, 30, 22, 40)
    tri(d, s, 53, 22, 40)
    tri(d, s, 76, 22, 40)


def close(d, s):
    w = 11 * s
    d.line([(44 * s, 44 * s), (84 * s, 84 * s)], fill=255, width=w)
    d.line([(84 * s, 44 * s), (44 * s, 84 * s)], fill=255, width=w)


def menu(d, s):
    for y in (34, 58, 82):
        d.rounded_rectangle([22 * s, (y - 6) * s, 106 * s, (y + 6) * s], 6 * s, fill=255)


import os
os.makedirs(f'{UI}/pa/icons', exist_ok=True)
for nm, fn, col, ring in [('pause', pause, INK, True), ('play', play, INK, True), ('fastfwd', ff, INK, True), ('fastfwd3', ff3, INK, True),
                          ('close', close, TERRA, True), ('menu', menu, INK, False)]:
    glyph(fn, col, ring).save(f'{UI}/pa/icons/{nm}.png')
    print(nm)

# портреты сословий: лицо из старого медальона, вместо золотого кольца — светлое тонкое
for cl in ('plebs', 'artisans', 'patricians'):
    src = Image.open(f'{UI}/ai/class_{cl}.png').convert('RGBA')
    M = src.width
    img = Image.new('RGBA', (M, M), CLEAR)
    r_in = M * 0.385
    face = Image.composite(src, Image.new('RGBA', (M, M), CLEAR), disc(r_in, M))
    put(img, (250, 242, 224), disc(M * 0.47, M))
    img.alpha_composite(face)
    put(img, INK, ImageChops.subtract(disc(M * 0.47, M), disc(M * 0.47 - 6, M)))
    put(img, INK, ImageChops.subtract(disc(r_in + 1, M), disc(r_in - 1, M)), 0.6)
    img.save(f'{UI}/pa/class_{cl}.png')
    print('class', cl)
