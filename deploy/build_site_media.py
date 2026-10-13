# Картинки, шрифты и видео для сайта civcity.ru (папка site/) — из готовых съёмок и рисованного интерфейса игры.
#   python -I D:/CivCity/deploy/build_site_media.py [all|art|fonts|hero|loops|screens|trailer|credits] …
# Что откуда:
#   site/assets/img/    — логотип, значки, портреты классов, Легион (листы 35/37/41 и карты 40a–40h) из godot/assets/ui/ai,
#                         значок сайта (favicon.ico, apple-touch-icon.png, icon-192.png), картинка для соцсетей og-image.jpg
#   site/assets/fonts/  — Philosopher Bold и Alegreya Sans (как в игре), только латиница и кириллица, WOFF
#   site/media/hero/    — фон первого экрана: бесшовная петля из 4 сцен (рынок → виллы → парк → форум), 1600×900 и 960×540,
#                         VP9 (webm) + H.264 (mp4) + кадр-заставка webp. Источник — 7-секундные клипы promo/video/public2/shots2
#                         (если их нет — 5-секундные петли из site_media/loops)
#   site/media/loops/   — 8 бесшовных петель 960×540 для «Живого города» (из site_media/loops)
#   site/media/screens/ — 12 снимков 1920×1080 webp + миниатюры 640×360 (из site_media/screens/*.png)
#   site/media/trailer/ — ролик со звуком 1080p и 720p (H.264, faststart) + заставка (из promo/video/out/civcity-promo-2.mp4)
#   site/credits/index.html — список музыки между <!-- music:start --> и <!-- music:end --> (из godot/assets/music/CREDITS.txt)
# site/media/ большая (в .gitignore) — перед выкладкой сайта (bash deploy/deploy.sh site) её нужно собрать этим скриптом.
# ffmpeg — из WinGet, всё пишется только в D:/CivCity (временное — в .work/site_build). Видеокарта не нужна.
import html
import json
import os
import re
import shutil
import subprocess
import sys

ROOT = r'D:\CivCity'
SITE = os.path.join(ROOT, 'site')
IMG = os.path.join(SITE, 'assets', 'img')
FONTS = os.path.join(SITE, 'assets', 'fonts')
MEDIA = os.path.join(SITE, 'media')
UI = os.path.join(ROOT, 'godot', 'assets', 'ui', 'ai')
SM = os.path.join(ROOT, 'site_media')
SHOTS = os.path.join(ROOT, 'promo', 'video', 'public2', 'shots2')
TMP = os.path.join(ROOT, '.work', 'site_build')
FF = shutil.which('ffmpeg') or 'ffmpeg'
FP = shutil.which('ffprobe') or 'ffprobe'

LOOPS = ['market', 'street', 'park', 'villa', 'forum', 'temple', 'night', 'fields']
SCREENS = ['overview', 'market', 'main-street', 'cat', 'villas', 'temple-sunset', 'park', 'forum', 'arrival', 'dusk', 'night', 'aqueduct']
HERO = ['market', 'villa', 'park', 'forum']      # порядок сцен в петле первого экрана
ICONS = ['housing', 'family', 'cat', 'legion', 'save', 'scroll', 'fountain', 'commerce', 'laurels', 'swords', 'helmet', 'sun',
         'moon', 'cart', 'coins', 'decor', 'research', 'happy', 'keys', 'level', 'play', 'shield', 'eagle', 'lamp', 'tree', 'time']
UNITS = ['legionary', 'spearman', 'archer', 'ballista', 'catapult']                          # лист 35, слева направо
BOSSES = ['chief', 'greatbear', 'gaulKing', 'giant', 'minotaur', 'cyclops', 'elephant', 'cerberus']   # лист 37, 4×2
WONDERS = ['arch', 'amphitheatre', 'pantheon', 'circus', 'aqueduct', 'trajan', 'caracalla', 'jupiter']  # лист 41, 4×2
MAPS = 'abcdefgh'                                                                             # карты 40a–40h по провинциям


def run(args, what=''):
    r = subprocess.run([FF, '-hide_banner', '-loglevel', 'error', '-y', *args])
    if r.returncode != 0:
        raise SystemExit('ffmpeg не справился (%s): %s' % (what, ' '.join(args)))


def duration(path):
    out = subprocess.run([FP, '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', path], capture_output=True, text=True)
    return float(out.stdout.strip() or 0)


def kb(path):
    return '%d КБ' % (os.path.getsize(path) // 1024)


def webp(im, path, q=80, size=None, lossless=False):
    from PIL import Image
    if size:
        im = im.resize(size, Image.LANCZOS)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path, 'WEBP', quality=q, method=6, lossless=lossless)
    return path


# ---------- рисованный интерфейс → webp ----------

def art():
    from PIL import Image
    os.makedirs(IMG, exist_ok=True)
    rgba = lambda p: Image.open(os.path.join(UI, p)).convert('RGBA')
    logo = rgba('logo.png')
    webp(logo, os.path.join(IMG, 'logo.webp'), 80, (720, round(720 * logo.height / logo.width)))
    webp(logo, os.path.join(IMG, 'logo-sm.webp'), 84, (240, round(240 * logo.height / logo.width)))
    logo.resize((450, round(450 * logo.height / logo.width)), Image.LANCZOS).save(os.path.join(IMG, 'logo.png'), optimize=True)
    webp(rgba('divider.png'), os.path.join(IMG, 'divider.webp'), 85)
    webp(rgba('plate.png'), os.path.join(IMG, 'plate.webp'), 85)
    webp(rgba('advisor.png'), os.path.join(IMG, 'advisor.webp'), 85, (192, 192))
    for c in ('plebs', 'artisans', 'patricians'):
        webp(rgba('class_%s.png' % c), os.path.join(IMG, 'class-%s.webp' % c), 85, (144, 144))
    for name in ICONS:
        webp(Image.open(os.path.join(UI, 'icons', name + '.png')).convert('RGBA'), os.path.join(IMG, 'icons', name + '.webp'), 85, (96, 96))
    # Легион: роды войск (лист 35 — 5 в ряд), боссы и чудеса (листы 37 и 41 — 4×2), карты провинций
    sheet = rgba('legion/35.png')
    cw = sheet.width // 5
    for i, name in enumerate(UNITS):
        webp(sheet.crop((i * cw, 0, (i + 1) * cw, sheet.height)), os.path.join(IMG, 'legion', 'unit-%s.webp' % name), 85, (128, 128))
    for sheet_name, names, prefix, px in (('legion/37.png', BOSSES, 'boss', 128), ('legion/41.png', WONDERS, 'wonder', 200)):
        sheet = rgba(sheet_name)
        cw, ch = sheet.width // 4, sheet.height // 2
        for i, name in enumerate(names):
            x, y = (i % 4) * cw, (i // 4) * ch
            webp(sheet.crop((x, y, x + cw, y + ch)), os.path.join(IMG, 'legion', '%s-%s.webp' % (prefix, name)), 85, (px, px))
    for i, ch in enumerate(MAPS):
        im = Image.open(os.path.join(UI, 'legion', '40%s.jpg' % ch)).convert('RGB')
        webp(im, os.path.join(IMG, 'legion', 'map-%d.webp' % (i + 1)), 78, (1280, round(1280 * im.height / im.width)))
    # значок сайта — значок игры (орёл со штандартом)
    icon = rgba('app_icon.png')
    icon.save(os.path.join(SITE, 'favicon.ico'), sizes=[(16, 16), (32, 32), (48, 48), (64, 64)])
    for px, name in ((180, 'apple-touch-icon.png'), (192, 'icon-192.png')):
        bg = Image.new('RGBA', (px, px), (247, 239, 220, 255))      # на пергаменте: iOS не любит прозрачность
        ic = icon.resize((round(px * 0.86), round(px * 0.86)), Image.LANCZOS)
        bg.alpha_composite(ic, ((px - ic.width) // 2, (px - ic.height) // 2))
        bg.convert('RGB').save(os.path.join(SITE, name), optimize=True)
    icon.save(os.path.join(SITE, 'icon-256.png'), optimize=True)
    webp(icon, os.path.join(IMG, 'app-icon.webp'), 86, (192, 192))
    # картинка для соцсетей 1200×630: город с высоты + логотип
    src = os.path.join(SM, 'screens', 'civcity-market.png')
    if os.path.exists(src):
        from PIL import ImageFilter
        im = Image.open(src).convert('RGB')
        w = 1200
        im = im.resize((w, round(w * im.height / im.width)), Image.LANCZOS)
        top = (im.height - 630) // 2
        im = im.crop((0, top, w, top + 630)).convert('RGBA')
        shade = Image.new('RGBA', im.size, (0, 0, 0, 0))
        g = Image.linear_gradient('L').rotate(90).resize(im.size)   # тень слева направо
        shade.putalpha(g.point(lambda v: int(v * 0.55)))
        im = Image.alpha_composite(im, Image.merge('RGBA', (*Image.new('RGB', im.size, (30, 18, 8)).split(), shade.getchannel('A'))))
        lg = logo.resize((560, round(560 * logo.height / logo.width)), Image.LANCZOS)
        glow = lg.getchannel('A').filter(ImageFilter.GaussianBlur(14)).point(lambda v: int(v * 0.6))
        im.alpha_composite(Image.merge('RGBA', (*Image.new('RGB', lg.size, (0, 0, 0)).split(), glow)), (40, (630 - lg.height) // 2))
        im.alpha_composite(lg, (40, (630 - lg.height) // 2))
        im.convert('RGB').save(os.path.join(SITE, 'og-image.jpg'), quality=86, optimize=True, progressive=True)
    total = sum(os.path.getsize(os.path.join(d, f)) for d, _, fs in os.walk(IMG) for f in fs)
    print('картинки: %d КБ в assets/img' % (total // 1024))


# ---------- шрифты: только нужные знаки, WOFF ----------

FONT_FILES = {
    'philosopher-bold': 'Philosopher-Bold.ttf',
    'alegreya-sans-medium': 'AlegreyaSans-Medium.ttf',
    'alegreya-sans-bold': 'AlegreyaSans-Bold.ttf',
    'alegreya-sans-extrabold': 'AlegreyaSans-ExtraBold.ttf',
}
UNICODES = ('U+0020-007E,U+00A0-00BF,U+00D7,U+0401,U+0410-044F,U+0451,U+2010-2027,U+2030-203A,U+2116,U+20BD,U+2190-2193,'
            'U+2212,U+2264,U+2265,U+2713,U+00E9')


def fonts():
    from fontTools import subset
    os.makedirs(FONTS, exist_ok=True)
    for out, src in FONT_FILES.items():
        opts = subset.Options()
        opts.flavor = 'woff'
        opts.layout_features = ['kern', 'liga', 'lnum', 'pnum', 'tnum', 'case', 'locl']
        opts.name_IDs = [0, 1, 2, 3, 4, 5, 6]
        opts.notdef_outline = True
        font = subset.load_font(os.path.join(ROOT, 'godot', 'assets', 'fonts', src), opts)
        sub = subset.Subsetter(opts)
        sub.populate(unicodes=subset.parse_unicodes(UNICODES))
        sub.subset(font)
        path = os.path.join(FONTS, out + '.woff')
        subset.save_font(font, path, opts)
        print('шрифт', out, kb(path))
    shutil.copy(os.path.join(ROOT, 'godot', 'assets', 'fonts', 'CREDITS.txt'), os.path.join(FONTS, 'CREDITS.txt'))


# ---------- видео ----------

def vp9(src, dst, crf, extra_vf=None):
    vf = ['-vf', extra_vf] if extra_vf else []
    run(['-i', src, *vf, '-an', '-c:v', 'libvpx-vp9', '-b:v', '0', '-crf', str(crf), '-row-mt', '1', '-deadline', 'good',
         '-cpu-used', '2', '-g', '150', '-pix_fmt', 'yuv420p', dst], 'vp9 ' + os.path.basename(dst))


def h264(src, dst, crf, extra_vf=None):
    vf = ['-vf', extra_vf] if extra_vf else []
    run(['-i', src, *vf, '-an', '-c:v', 'libx264', '-preset', 'slow', '-crf', str(crf), '-profile:v', 'high', '-pix_fmt', 'yuv420p',
         '-g', '150', '-movflags', '+faststart', dst], 'h264 ' + os.path.basename(dst))


def hero():
    """Петля из 4 сцен с плавными переходами. Сцены A B C D и снова A: переходы через каждые P секунд, длиной T.
    Вырезаем отрезок [T; 4P+T): в его начале сцена A с T-й секунды, в конце — та же A с той же секунды → шва нет."""
    d = os.path.join(MEDIA, 'hero')
    os.makedirs(d, exist_ok=True)
    os.makedirs(TMP, exist_ok=True)
    srcs = []
    for name in HERO:
        big = os.path.join(SHOTS, 'loop_%s.mp4' % name)
        srcs.append(big if os.path.exists(big) else os.path.join(SM, 'loops', name + '.mp4'))
    srcs.append(srcs[0])
    shortest = min(duration(s) for s in srcs)
    T = 1.2
    P = min(5.0, shortest - T - 0.5)
    parts = []
    for i in range(5):
        parts.append('[%d:v]trim=0:%.3f,setpts=PTS-STARTPTS,fps=30,scale=1600:900:flags=lanczos,format=yuv420p,setsar=1[v%d]'
                     % (i, P + T + 0.5, i))
    chain, prev = [], 'v0'
    for i in range(1, 5):
        out = 'x%d' % i
        chain.append('[%s][v%d]xfade=transition=fade:duration=%.3f:offset=%.3f[%s]' % (prev, i, T, P * i, out))
        prev = out
    s0 = T + 0.3        # с запасом: в конце петли переход в A уже закончился
    fc = ';'.join(parts + chain) + ';[%s]trim=start=%.3f:end=%.3f,setpts=PTS-STARTPTS[out]' % (prev, s0, 4 * P + s0)
    master = os.path.join(TMP, 'hero_master.mp4')
    args = []
    for s in srcs:
        args += ['-i', s]
    run([*args, '-filter_complex', fc, '-map', '[out]', '-an', '-c:v', 'libx264', '-preset', 'medium', '-crf', '12', '-pix_fmt', 'yuv420p', master],
        'hero master')
    small = 'scale=960:540:flags=lanczos'
    vp9(master, os.path.join(d, 'hero-1600.webm'), 45)          # фон под затемнением: ~2 МБ на 20 с
    h264(master, os.path.join(d, 'hero-1600.mp4'), 31)
    vp9(master, os.path.join(d, 'hero-960.webm'), 43, small)
    h264(master, os.path.join(d, 'hero-960.mp4'), 30, small)
    run(['-i', master, '-frames:v', '1', os.path.join(TMP, 'hero.png')], 'hero poster')
    from PIL import Image
    im = Image.open(os.path.join(TMP, 'hero.png')).convert('RGB')
    webp(im, os.path.join(d, 'hero-1600.webp'), 74)
    webp(im, os.path.join(d, 'hero-960.webp'), 72, (960, 540))
    print('первый экран: %.1f с;' % (4 * P), ', '.join('%s %s' % (f, kb(os.path.join(d, f))) for f in sorted(os.listdir(d))))


def loops():
    d = os.path.join(MEDIA, 'loops')
    os.makedirs(d, exist_ok=True)
    from PIL import Image
    os.makedirs(TMP, exist_ok=True)
    for name in LOOPS:
        src = os.path.join(SM, 'loops', name + '.mp4')
        if not os.path.exists(src):
            print('нет петли', src)
            continue
        sc = 'scale=960:540:flags=lanczos'
        vp9(src, os.path.join(d, name + '.webm'), 37, sc)
        h264(src, os.path.join(d, name + '.mp4'), 27, sc)
        run(['-i', src, '-frames:v', '1', os.path.join(TMP, 'loop.png')], 'poster')
        webp(Image.open(os.path.join(TMP, 'loop.png')).convert('RGB'), os.path.join(d, name + '.webp'), 72, (960, 540))
        print('петля', name, kb(os.path.join(d, name + '.webm')), kb(os.path.join(d, name + '.mp4')))


def screens():
    from PIL import Image
    d = os.path.join(MEDIA, 'screens')
    os.makedirs(os.path.join(d, 'thumbs'), exist_ok=True)
    for name in SCREENS:
        png = os.path.join(SM, 'screens', 'civcity-%s.png' % name)
        if not os.path.exists(png):
            print('нет снимка', png)
            continue
        im = Image.open(png).convert('RGB')
        webp(im, os.path.join(d, name + '.webp'), 80, (1920, 1080))
        webp(im, os.path.join(d, 'thumbs', name + '.webp'), 74, (640, 360))
        print('снимок', name, kb(os.path.join(d, name + '.webp')), kb(os.path.join(d, 'thumbs', name + '.webp')))


def trailer():
    src = os.path.join(ROOT, 'promo', 'video', 'out', 'civcity-promo-2.mp4')
    if not os.path.exists(src):
        src = os.path.join(SM, 'video', 'civcity-promo-2-1080p.mp4')
    if not os.path.exists(src):
        print('ролика нет — пропускаю')
        return
    d = os.path.join(MEDIA, 'trailer')
    os.makedirs(d, exist_ok=True)
    for h, crf, rate in ((1080, 25, '4.5M'), (720, 25, '2.5M')):
        dst = os.path.join(d, 'civcity-trailer-%dp.mp4' % h)
        run(['-i', src, '-vf', 'scale=-2:%d:flags=lanczos' % h, '-c:v', 'libx264', '-preset', 'slow', '-crf', str(crf), '-maxrate', rate,
             '-bufsize', '%gM' % (float(rate[:-1]) * 2), '-profile:v', 'high', '-pix_fmt', 'yuv420p', '-g', '60',
             '-c:a', 'aac', '-b:a', '160k', '-movflags', '+faststart', dst], 'trailer %d' % h)
        print('ролик', h, kb(dst))
    trailer_poster()


def trailer_poster():
    # заставка без надписей ролика: снимок всего города в золотой час
    from PIL import Image
    d = os.path.join(MEDIA, 'trailer')
    os.makedirs(d, exist_ok=True)
    poster = os.path.join(SM, 'screens', 'civcity-overview.png')
    webp(Image.open(poster).convert('RGB'), os.path.join(d, 'poster.webp'), 76, (1280, 720))


# ---------- авторы музыки → site/credits/index.html ----------

def credits():
    page = os.path.join(SITE, 'credits', 'index.html')
    if not os.path.exists(page):
        print('нет', page)
        return
    rows = []
    with open(os.path.join(ROOT, 'godot', 'assets', 'music', 'CREDITS.txt'), encoding='utf-8') as f:
        for line in f:
            m = re.match(r'^\d+_[\w]+\.ogg — (.+?) — (.+?) — (https?://\S+)\s*$', line.strip())
            if not m:
                continue
            title, lic, url = m.groups()
            title = re.sub(r'\.(ogg|flac|mp3|opus)$', '', title)
            rows.append('      <li><a href="%s" rel="noopener" target="_blank">%s</a> <span class="lic">%s</span></li>'
                        % (html.escape(url), html.escape(title), html.escape(lic)))
    with open(page, encoding='utf-8') as f:
        s = f.read()
    block = '<!-- music:start -->\n' + '\n'.join(rows) + '\n      <!-- music:end -->'
    s2 = re.sub(r'<!-- music:start -->.*?<!-- music:end -->', lambda _: block, s, flags=re.S)
    with open(page, 'w', encoding='utf-8', newline='\n') as f:
        f.write(s2)
    print('авторы: %d записей музыки' % len(rows))


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    what = sys.argv[1:] or ['all']
    steps = {'art': art, 'fonts': fonts, 'hero': hero, 'loops': loops, 'screens': screens, 'trailer': trailer, 'poster': trailer_poster,
             'credits': credits}
    for name, fn in steps.items():
        if 'all' in what or name in what:
            fn()
    if not ('all' in what or set(what) <= set(steps)):
        raise SystemExit('не знаю: %s. Можно: all %s' % (' '.join(w for w in what if w not in steps), ' '.join(steps)))
