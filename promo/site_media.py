# Медиа для сайта civcity.ru из съёмок витрины (promo/render_v2.sh):
#   site_media/loops/   — бесшовные петли 1280×720 без текста: <имя>.webm (VP9) и <имя>.mp4 (H.264) + <имя>.jpg (первый кадр)
#   site_media/screens/ — снимки: civcity-<имя>.png (3840×2160), .jpg (2560×1440), thumbs/<имя>.jpg (960×540)
#   site_media/video/   — промо-ролик для страницы: civcity-promo-2-1080p.mp4 + постер (если ролик уже собран)
#   site_media/manifest.json — список файлов с подписями (для вёрстки сайта)
# Запуск: python -I D:/CivCity/promo/site_media.py [loops|screens|video|all]
# Петля: из 7-секундного клипа берётся 5 с (с 1-й секунды), а последняя секунда плавно перетекает в кадры,
# что шли прямо перед началом, — конец петли совпадает с её началом, шва не видно.
import json
import os
import shutil
import subprocess
import sys

ROOT = r'D:\CivCity'
SHOTS = os.path.join(ROOT, 'promo', 'video', 'public2', 'shots2')
OUT = os.path.join(ROOT, 'site_media')
FF = shutil.which('ffmpeg') or 'ffmpeg'

LOOPS = {
    'loop_market': 'Рынок: горожане у прилавков и фонтана',
    'loop_street': 'Главная улица утром',
    'loop_park': 'Парк у пруда, лебеди и утки',
    'loop_villa': 'Улица вилл патрициев с садами',
    'loop_forum': 'Форум и пантеон',
    'loop_temple': 'Храм Юпитера на закате',
    'loop_night': 'Ночной рынок: фонари и жаровни',
    'loop_fields': 'Въезд в город: поля, виноградники, арка',
}
SCREENS = {
    'overview': 'Весь город в золотой час',
    'market': 'Рынок с фонтаном',
    'main-street': 'Главная улица',
    'cat': 'Девочка гладит кошку на форуме',
    'villas': 'Виллы патрициев',
    'temple-sunset': 'Храм Юпитера на закате',
    'park': 'Парк у пруда',
    'forum': 'Форум и пантеон',
    'arrival': 'Новые жители въезжают через арку',
    'dusk': 'Сумерки на главной улице',
    'night': 'Ночной город',
    'aqueduct': 'Акведук с холмов',
}


def run(args):
    r = subprocess.run([FF, '-hide_banner', '-loglevel', 'error', '-y', *args])
    if r.returncode != 0:
        raise SystemExit('ffmpeg failed: ' + ' '.join(args))


def loops():
    d = os.path.join(OUT, 'loops')
    os.makedirs(d, exist_ok=True)
    for name in LOOPS:
        src = os.path.join(SHOTS, name + '.mp4')
        if not os.path.exists(src):
            print('нет клипа', src)
            continue
        short = name.replace('loop_', '')
        # main = [1; 6) с, pre = [0; 1) с поверх последней секунды, прозрачность 0→1
        fc = ('[0:v]trim=start=1:end=6,setpts=PTS-STARTPTS[m];'
              '[1:v]trim=start=0:end=1,setpts=PTS-STARTPTS+4/TB,format=yuva420p,fade=t=in:st=4:d=1:alpha=1[p];'
              '[m][p]overlay=eof_action=pass,scale=1280:720:flags=lanczos,format=yuv420p[v]')
        base = os.path.join(d, short)
        run(['-i', src, '-i', src, '-filter_complex', fc, '-map', '[v]', '-an', '-c:v', 'libx264', '-preset', 'slow', '-crf', '21',
             '-profile:v', 'high', '-movflags', '+faststart', base + '.mp4'])
        run(['-i', base + '.mp4', '-an', '-c:v', 'libvpx-vp9', '-b:v', '0', '-crf', '33', '-row-mt', '1', '-deadline', 'good', '-cpu-used', '2',
             base + '.webm'])
        run(['-i', base + '.mp4', '-frames:v', '1', '-q:v', '3', base + '.jpg'])
        print('петля', short)


def screens():
    d = os.path.join(OUT, 'screens')
    th = os.path.join(d, 'thumbs')
    os.makedirs(th, exist_ok=True)
    from PIL import Image
    for name in SCREENS:
        png = os.path.join(d, 'civcity-%s.png' % name)
        if not os.path.exists(png):
            print('нет снимка', png)
            continue
        im = Image.open(png).convert('RGB')
        im.resize((2560, 1440), Image.LANCZOS).save(os.path.join(d, 'civcity-%s.jpg' % name), quality=90, optimize=True, progressive=True)
        im.resize((960, 540), Image.LANCZOS).save(os.path.join(th, 'civcity-%s.jpg' % name), quality=85, optimize=True, progressive=True)
        print('снимок', name)


def video():
    src = os.path.join(ROOT, 'promo', 'video', 'out', 'civcity-promo-2.mp4')
    if not os.path.exists(src):
        print('ролик ещё не собран:', src)
        return
    d = os.path.join(OUT, 'video')
    os.makedirs(d, exist_ok=True)
    run(['-i', src, '-vf', 'scale=1920:1080:flags=lanczos', '-c:v', 'libx264', '-preset', 'slow', '-crf', '20', '-pix_fmt', 'yuv420p',
         '-c:a', 'aac', '-b:a', '192k', '-movflags', '+faststart', os.path.join(d, 'civcity-promo-2-1080p.mp4')])
    run(['-ss', '52', '-i', src, '-frames:v', '1', '-vf', 'scale=1920:1080:flags=lanczos', '-q:v', '2', os.path.join(d, 'civcity-promo-2-poster.jpg')])
    print('ролик для сайта готов')


def manifest():
    m = {'loops': [], 'screens': [], 'video': []}
    for name, alt in LOOPS.items():
        short = name.replace('loop_', '')
        if os.path.exists(os.path.join(OUT, 'loops', short + '.webm')):
            m['loops'].append({'webm': 'loops/%s.webm' % short, 'mp4': 'loops/%s.mp4' % short, 'poster': 'loops/%s.jpg' % short,
                               'width': 1280, 'height': 720, 'seconds': 5, 'alt': alt})
    for name, alt in SCREENS.items():
        if os.path.exists(os.path.join(OUT, 'screens', 'civcity-%s.png' % name)):
            m['screens'].append({'png': 'screens/civcity-%s.png' % name, 'jpg': 'screens/civcity-%s.jpg' % name,
                                 'thumb': 'screens/thumbs/civcity-%s.jpg' % name, 'alt': alt})
    if os.path.exists(os.path.join(OUT, 'video', 'civcity-promo-2-1080p.mp4')):
        m['video'].append({'mp4': 'video/civcity-promo-2-1080p.mp4', 'poster': 'video/civcity-promo-2-poster.jpg',
                           'alt': 'CivCity — уютный градостроитель про Древний Рим (ролик)'})
    with open(os.path.join(OUT, 'manifest.json'), 'w', encoding='utf-8') as f:
        json.dump(m, f, ensure_ascii=False, indent=1)
    print('manifest:', len(m['loops']), 'петель,', len(m['screens']), 'снимков,', len(m['video']), 'ролик')


if __name__ == '__main__':
    what = sys.argv[1] if len(sys.argv) > 1 else 'all'
    if what in ('loops', 'all'):
        loops()
    if what in ('screens', 'all'):
        screens()
    if what in ('video', 'all'):
        video()
    manifest()
