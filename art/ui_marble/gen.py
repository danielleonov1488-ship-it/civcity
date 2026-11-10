# Интерфейс «мрамор» (выбор владельца 11.11.2026, вариант 2 Codex: .work/codex_img/styles/v2_marble.png): белый мрамор с
# прожилками, тонкое золото, пурпур — у нажатого. Те же имена и размеры, что у «пергамента» (art/ui_pa/gen.py), чтобы
# рамки ложились на те же поля. python gen.py <папка вывода>  (игра: res://assets/ui/marble/)
import sys, math
from PIL import Image, ImageDraw, ImageFilter, ImageChops
OUT = sys.argv[1]
S = 4                                   # сглаживание
INK = (176, 128, 46)                    # обводка — тонкое золото
PAPER_T = (252, 251, 249); PAPER_B = (237, 235, 233)
HOVER_T = (255, 255, 255); HOVER_B = (244, 238, 248)
ON_T = (236, 222, 245); ON_B = (218, 197, 233)
LOCK_T = (226, 225, 224); LOCK_B = (208, 206, 205)
GOLD = (201, 152, 52)
TERRA = (110, 40, 96)                   # пурпур: галочки, тонкая черта нажатого
LEAF = (214, 172, 72); LEAF_D = (150, 106, 28)   # лавр — золотой
PAD = 6                                 # тень вокруг панелей
CLEAR = (0, 0, 0, 0)


def grain(w, h, amt=5):
    n = Image.effect_noise((w, h), 40).convert('L')
    return n.point(lambda v: 128 + (v - 128) * amt // 40)


def vgrad(w, h, top, bot):
    g = Image.new('RGB', (1, h))
    for y in range(h):
        t = y / max(1, h - 1)
        g.putpixel((0, y), tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)))
    return g.resize((w, h))


import random


def veins(w0, h0, seed):
    # прожилки — как трещинки в мраморе: несколько ломаных из края в край с дрожью и тонкими ответвлениями,
    # разной толщины; считаем втрое крупнее и уменьшаем (без зубцов); плюс мягкие серые облачка
    K = 3
    w, h = w0 * K, h0 * K
    rnd = random.Random(seed)
    m = Image.new('L', (w, h), 0)
    d = ImageDraw.Draw(m)
    n = 2 + (w0 * h0 > 20000) + (w0 * h0 > 60000)
    for v in range(n):
        x, y = rnd.uniform(-0.1, 0.4) * w, rnd.uniform(0, 1) * h
        ang = rnd.uniform(-0.6, 0.6)
        pts = [(x, y)]
        steps = 26
        L = math.hypot(w, h) / steps * 1.1
        for k in range(steps):
            ang += rnd.uniform(-0.45, 0.45)
            ang = max(-1.1, min(1.1, ang))
            x += math.cos(ang) * L
            y += math.sin(ang) * L
            pts.append((x, y))
            if rnd.random() < 0.12:                     # ответвление
                bx, by, ba = x, y, ang + rnd.choice((-1, 1)) * rnd.uniform(0.5, 1.0)
                bp = [(bx, by)]
                for q in range(rnd.randint(3, 7)):
                    ba += rnd.uniform(-0.4, 0.4)
                    bx += math.cos(ba) * L * 0.7
                    by += math.sin(ba) * L * 0.7
                    bp.append((bx, by))
                d.line(bp, fill=140, width=max(1, int(K * 0.8)))
        d.line(pts, fill=255 if v == 0 else 190, width=max(1, int(K * rnd.uniform(1.0, 1.8))), joint='curve')
    m = m.filter(ImageFilter.GaussianBlur(K * 0.6))
    cl = Image.new('L', (6, 6))
    cl.putdata([rnd.randint(0, 255) for _ in range(36)])
    cl = cl.resize((w, h), Image.BICUBIC).filter(ImageFilter.GaussianBlur(K * 6)).point(lambda v: max(0, v - 140))
    return ImageChops.lighter(m, cl).resize((w0, h0), Image.LANCZOS)


def paper(w, h, top, bot, amt=5):
    base = vgrad(w, h, top, bot)
    if not amt:
        return base
    gr = grain(w, h, max(2, amt // 2))
    base = ImageChops.overlay(base, Image.merge('RGB', (gr, gr, gr)))
    vm = veins(w, h, w * 131 + h).point(lambda v: int(v * 0.3 * min(1.0, amt / 5)))
    grey = Image.new('RGB', (w, h), (150, 146, 150))
    return Image.composite(grey, base, vm)


def rrect_mask(w, h, x0, y0, x1, y1, r):
    m = Image.new('L', (w * S, h * S), 0)
    ImageDraw.Draw(m).rounded_rectangle([x0 * S, y0 * S, x1 * S - 1, y1 * S - 1], r * S, fill=255)
    return m.resize((w, h), Image.LANCZOS)


def ring_mask(w, h, x0, y0, x1, y1, r, t):
    m = Image.new('L', (w * S, h * S), 0)
    d = ImageDraw.Draw(m)
    d.rounded_rectangle([x0 * S, y0 * S, x1 * S - 1, y1 * S - 1], r * S, fill=255)
    d.rounded_rectangle([(x0 + t) * S, (y0 + t) * S, (x1 - t) * S - 1, (y1 - t) * S - 1], max(0, r - t) * S, fill=0)
    return m.resize((w, h), Image.LANCZOS)


def put(img, col, mask, alpha=1.0):
    if alpha < 1.0:
        mask = mask.point(lambda v: int(v * alpha))
    layer = Image.new('RGBA', img.size, col + (255,))
    img.alpha_composite(Image.composite(layer, Image.new('RGBA', img.size, CLEAR), mask))


def fill(img, src, mask):
    img.alpha_composite(Image.composite(src.convert('RGBA'), Image.new('RGBA', img.size, CLEAR), mask))


def panel(w, h, r, top, bot, outline=INK, ow=2.0, hair=True, hair_in=5, shadow=True, grain_amt=5, hair_col=None, hair_a=0.4):
    pad = PAD if shadow else 0
    W, H = w + pad * 2, h + pad * 2
    img = Image.new('RGBA', (W, H), CLEAR)
    if shadow:
        sm = rrect_mask(W, H, pad, pad + 2, pad + w, pad + h + 2, r).filter(ImageFilter.GaussianBlur(3))
        put(img, (40, 30, 45), sm, 0.3)
    fill(img, paper(W, H, top, bot, grain_amt), rrect_mask(W, H, pad, pad, pad + w, pad + h, r))
    put(img, (255, 255, 255), ring_mask(W, H, pad + ow, pad + ow, pad + w - ow, pad + h - ow, max(0, r - ow), 1.0), 0.7)
    put(img, outline, ring_mask(W, H, pad, pad, pad + w, pad + h, r, ow))
    if hair:
        put(img, hair_col or INK, ring_mask(W, H, pad + hair_in, pad + hair_in, pad + w - hair_in, pad + h - hair_in, max(1, r - hair_in), 1.0), hair_a)
    return img


def save(img, name):
    img.save(f'{OUT}/{name}.png')
    print(name, img.size)


# окна и полосы
save(panel(84, 84, 12, PAPER_T, PAPER_B), 'g_panel')
save(panel(64, 64, 10, PAPER_T, PAPER_B, hair_in=4), 'g_panel_s')
save(panel(48, 48, 9, PAPER_T, PAPER_B, ow=1.8, hair_in=3, hair_a=0.3), 'g_panel_xs')
# кнопки-плашки
save(panel(120, 36, 9, PAPER_T, PAPER_B, ow=1.6, hair=False, grain_amt=3), 'g_btn')
save(panel(120, 36, 9, HOVER_T, HOVER_B, outline=(206, 160, 60), ow=2.0, hair=False, grain_amt=3), 'g_btn_hover')
save(panel(120, 36, 9, ON_T, ON_B, outline=(176, 128, 46), ow=2.0, hair=True, hair_in=3, hair_col=TERRA, hair_a=0.6, grain_amt=3), 'g_btn_on')
# карточки построек
save(panel(96, 130, 9, PAPER_T, PAPER_B, ow=1.8, hair_in=4, hair_a=0.3), 'g_card')
save(panel(96, 130, 9, HOVER_T, HOVER_B, outline=GOLD, ow=2.6, hair_in=4, hair_col=TERRA, hair_a=0.45), 'g_card_hover')
save(panel(96, 130, 9, LOCK_T, LOCK_B, outline=(110, 98, 86), ow=1.8, hair_in=4, hair_a=0.25), 'g_card_lock')


# медальоны: светлый кружок с тонким коричневым кольцом (128 px — рисуются ~34–60 px)
def medal(fill_c, fill_e, ring, rw, hair_col=INK, hair_a=0.35, glow=None):
    N = 128
    img = Image.new('RGBA', (N, N), CLEAR)
    c = N * S / 2

    def disc(r):
        k = Image.new('L', (N * S, N * S), 0)
        ImageDraw.Draw(k).ellipse([c - r * S, c - r * S, c + r * S, c + r * S], fill=255)
        return k.resize((N, N), Image.LANCZOS)

    def ring_m(r0, r1):
        return ImageChops.subtract(disc(r0), disc(r1))

    g = Image.new('RGB', (N, N))
    px = g.load()
    for y in range(N):
        for x in range(N):
            t = min(1.0, math.hypot(x - N / 2 + 8, y - N / 2 + 12) / 70)
            px[x, y] = tuple(int(fill_c[i] + (fill_e[i] - fill_c[i]) * t) for i in range(3))
    gr = grain(N, N, 3)
    g = ImageChops.overlay(g, Image.merge('RGB', (gr, gr, gr)))
    if glow:
        put(img, glow, ring_m(63, 54).filter(ImageFilter.GaussianBlur(2.5)), 0.6)
    fill(img, g, disc(60))
    put(img, ring, ring_m(60, 60 - rw))
    put(img, hair_col, ring_m(60 - rw - 4, 60 - rw - 5.5), hair_a)
    return img


save(medal(PAPER_T, (232, 230, 230), INK, 4.5), 'medal')
save(medal(HOVER_T, (240, 234, 246), (206, 160, 60), 5.5, hair_col=TERRA, hair_a=0.4), 'medal_hover')
save(medal((246, 238, 250), (222, 204, 236), GOLD, 7.0, hair_col=TERRA, hair_a=0.6, glow=(255, 214, 130)), 'medal_on')
save(medal(LOCK_T, LOCK_B, (120, 110, 100), 4.5, hair_a=0.25), 'medal_lock')


# галочки (28 px, 1:1)
def check(on):
    N = 28
    img = Image.new('RGBA', (N, N), CLEAR)
    fill(img, paper(N, N, HOVER_T, PAPER_B, 0), rrect_mask(N, N, 2, 2, 26, 26, 5))
    put(img, INK, ring_mask(N, N, 2, 2, 26, 26, 5, 1.8))
    if on:
        k = Image.new('L', (N * S, N * S), 0)
        ImageDraw.Draw(k).line([(7 * S, 14.5 * S), (12 * S, 19.5 * S), (21.5 * S, 8.5 * S)], fill=255, width=int(3.2 * S), joint='curve')
        put(img, TERRA, k.resize((N, N), Image.LANCZOS))
    return img


save(check(False), 'g_check_off')
save(check(True), 'g_check_on')


def knob():
    N = 28
    img = Image.new('RGBA', (N, N), CLEAR)
    k = Image.new('L', (N * S, N * S), 0)
    ImageDraw.Draw(k).ellipse([2 * S, 2 * S, 26 * S, 26 * S], fill=255)
    fill(img, paper(N, N, HOVER_T, PAPER_B, 0), k.resize((N, N), Image.LANCZOS))
    r = Image.new('L', (N * S, N * S), 0)
    d = ImageDraw.Draw(r)
    d.ellipse([2 * S, 2 * S, 26 * S, 26 * S], fill=255)
    d.ellipse([4 * S, 4 * S, 24 * S, 24 * S], fill=0)
    d.ellipse([10 * S, 10 * S, 18 * S, 18 * S], fill=255)
    put(img, INK, r.resize((N, N), Image.LANCZOS))
    return img


save(knob(), 'g_knob')


def track(is_fill):
    w, h = 97, 16
    img = Image.new('RGBA', (w, h), CLEAR)
    top, bot = ((150, 76, 140), (104, 40, 96)) if is_fill else ((236, 234, 236), (248, 247, 248))
    fill(img, paper(w, h, top, bot, 0), rrect_mask(w, h, 1, 2, 96, 14, 6))
    put(img, (80, 28, 72) if is_fill else INK, ring_mask(w, h, 1, 2, 96, 14, 6, 1.5))
    return img


for nm, f in [('g_slider', False), ('g_slider_fill', True)]:
    t = track(f)
    save(t, nm)
    save(t.transpose(Image.Transpose.ROTATE_90), nm + '_v')


# лавровая веточка (для таблички): стебель дугой, листья парами вдоль него, к концу мельче
def sprig(img, x0, y0, length, ang, flip=1, leaves=7, size=1.0):
    d = ImageDraw.Draw(img)
    pts = []
    for i in range(41):
        t = i / 40
        a = math.radians(ang) + flip * t * 0.7
        if i == 0:
            pts.append((x0, y0))
        else:
            px, py = pts[-1]
            pts.append((px + math.cos(a) * length / 40, py - math.sin(a) * length / 40))
    d.line(pts, fill=LEAF_D + (255,), width=max(2, int(2.2 * size)))
    for i in range(leaves):
        t = 0.12 + 0.86 * i / (leaves - 1)
        k = min(39, int(t * 40))
        px, py = pts[k]
        tx, ty = pts[k + 1][0] - px, pts[k + 1][1] - py
        a = math.atan2(-ty, tx)
        sides = (-1, 1) if i < leaves - 1 else (0,)
        for side in sides:
            la = a + side * 0.62
            L = (9.5 - 3.5 * t) * size
            cx = px + math.cos(la) * L * 0.95
            cy = py - math.sin(la) * L * 0.95
            leaf = Image.new('RGBA', (int(L * 2.6), int(L * 2.6)), CLEAR)
            ld = ImageDraw.Draw(leaf)
            lw = L * 0.38
            cc = L * 1.3
            ld.ellipse([cc - L, cc - lw, cc + L, cc + lw], fill=LEAF + (255,), outline=LEAF_D + (255,), width=max(1, int(0.9 * size)))
            ld.line([(cc - L * 0.8, cc), (cc + L * 0.7, cc)], fill=LEAF_D + (140,), width=max(1, int(0.6 * size)))
            leaf = leaf.rotate(math.degrees(la), resample=Image.BICUBIC, expand=False)
            img.alpha_composite(leaf, (int(cx - leaf.width / 2), int(cy - leaf.height / 2)))


# табличка с названием города 640×169: пергамент, по бокам — веточки лавра
def plate():
    w, h = 640, 169
    big = Image.new('RGBA', (w * 2, h * 2), CLEAR)
    sprig(big, 64, 262, 200, 88, -1, 7, 2.6)
    sprig(big, w * 2 - 64, 262, 200, 92, 1, 7, 2.6)
    spr = big.resize((w, h), Image.LANCZOS)
    img = panel(w - 2 * PAD - 8, h - 2 * PAD - 30, 22, PAPER_T, PAPER_B, ow=4.0, hair_in=9, hair_a=0.45)
    out = Image.new('RGBA', (w, h), CLEAR)
    out.alpha_composite(img, (4, 15))
    out.alpha_composite(spr)
    return out


save(plate(), 'plate')


# разделитель 900×59: тонкая линия, посередине ромбик
def divider():
    w, h = 900, 59
    s = S
    k = Image.new('L', (w * s, h * s), 0)
    d = ImageDraw.Draw(k)
    cy = h / 2 * s
    d.line([(30 * s, cy), (412 * s, cy)], fill=255, width=4 * s)
    d.line([(488 * s, cy), (870 * s, cy)], fill=255, width=4 * s)
    d.polygon([(450 * s, cy - 16 * s), (474 * s, cy), (450 * s, cy + 16 * s), (426 * s, cy)], fill=255)
    for x in (24, 876):
        d.ellipse([(x - 6) * s, cy - 6 * s, (x + 6) * s, cy + 6 * s], fill=255)
    img = Image.new('RGBA', (w, h), CLEAR)
    put(img, INK, k.resize((w, h), Image.LANCZOS), 0.7)
    return img


save(divider(), 'divider')


# свитки старого интерфейса — теперь те же спокойные окна (валики убраны)
save(panel(84, 84, 12, PAPER_T, PAPER_B), 'g_scroll_v')
save(panel(84, 84, 12, PAPER_T, PAPER_B), 'g_scroll_h')
