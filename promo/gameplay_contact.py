"""Каталог и лист контактов из готовых игровых клипов."""

import argparse
from html import escape
import os
from pathlib import Path
import subprocess

from PIL import Image, ImageDraw, ImageFont, ImageOps, ImageStat

from render_gameplay import CATEGORIES, CLIPS, ROOT, SIZES, STAGE, binaries, probe

CATALOG = ROOT / "promo/gameplay_20261125"
FORMATS = {"vertical": "Вертикальные · 9:16", "horizontal": "Горизонтальные · 16:9"}
POSTERS = {"fruit_stall": 0.48, "hire": 0.7, "battle": 0.38, "cityrise": 0.96}


def frame(ffmpeg, src, seconds, destination, width):
    subprocess.run([
        ffmpeg, "-y", "-hide_banner", "-loglevel", "error", "-threads", "2", "-ss", str(seconds),
        "-i", src, "-vf", f"scale={width}:-2", "-frames:v", "1", "-threads", "2", "-q:v", "3", destination,
    ], check=True)


def collect(out, rejected, media):
    ffmpeg, ffprobe = binaries()
    groups = []
    for orientation, size in SIZES.items():
        folder = out / "thumbs" / orientation
        os.makedirs(folder, exist_ok=True)
        for group, category in CLIPS.items():
            entries = []
            for name, dur, _, caption in category:
                relative = f"{orientation}/{name}.mp4"
                src = media / relative
                if relative in rejected or not probe(src, ffprobe, size, dur):
                    continue
                thumb = folder / f"{name}.jpg"
                if not thumb.exists() or thumb.stat().st_mtime < src.stat().st_mtime:
                    frame(ffmpeg, src, dur * POSTERS.get(name, 0.55), thumb, 480)
                entries.append((relative, thumb, dur, caption, src.stat().st_size))
            if entries:
                groups.append((orientation, group, entries))
    return groups


def make_html(out, groups, media):
    orientation = ""
    content = []
    for ratio, group, entries in groups:
        if orientation != ratio:
            orientation = ratio
            content.append(f"<h2>{FORMATS[ratio]}</h2>")
        content.append(f'<section><h3>{CATEGORIES[group]}</h3><div class="grid {ratio}">')
        for relative, thumb, dur, caption, _ in entries:
            file = Path(relative).name
            img = thumb.relative_to(out).as_posix()
            href = Path(os.path.relpath(media / relative, out)).as_posix()
            content.append(
                f'<article><a href="{escape(href)}"><img loading="lazy" src="{img}" alt="{escape(caption)}">'
                f'<div class="meta"><strong>{file}</strong><span>{dur:g} с</span></div></a>'
                f'<p>{escape(caption)}</p></article>'
            )
        content.append("</div></section>")
    html = """<!doctype html>
<html lang="ru"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>CivCity · Кадры для монтажа</title>
<style>
:root{color-scheme:light;background:#f3eee3;color:#302820;font:16px/1.45 "Segoe UI",sans-serif}
body{max-width:1400px;margin:auto;padding:clamp(18px,4vw,60px)}
h1,h2,h3{font-family:Cambria,Georgia,serif;line-height:1.05;margin:0}
h1{font-size:clamp(36px,6vw,66px)} h2{font-size:34px;margin-top:48px} h3{font-size:24px;margin:26px 0 12px}
p{margin:6px 0 0} .lead{color:#665645;margin:12px 0 18px}
.grid{display:grid;gap:16px;grid-template-columns:repeat(auto-fill,minmax(min(100%,180px),1fr))}
.horizontal{grid-template-columns:repeat(auto-fill,minmax(min(100%,248px),1fr))}
article{min-width:0;background:#fffcf3;border:1px solid #ddcfb9;padding:8px;border-radius:8px}
article p{font-size:.94rem;margin:4px 2px 2px}
a{color:inherit;text-decoration:none;display:block} a:hover strong{text-decoration:underline}
a:focus-visible{outline:3px solid #658056;outline-offset:3px}
img{display:block;width:100%;border-radius:4px;aspect-ratio:9/16;object-fit:contain;background:#221d19}
.horizontal img{aspect-ratio:16/9} .meta{display:flex;gap:5px;flex-wrap:wrap;justify-content:space-between;margin:7px 2px 0}
.meta span{color:#665645;white-space:nowrap} strong{overflow-wrap:anywhere}
</style></head><body><header><h1>CivCity · Кадры для монтажа</h1>
<p class="lead">25 ноября 2026 · MP4, 60 кадров/с · щёлкните по кадру, чтобы открыть клип</p></header>
"""
    (out / "index.html").write_text(html + "\n".join(content) + "\n</body></html>\n", encoding="utf-8")


def wrap(draw, text, font, width):
    lines = []
    line = ""
    for word in text.split():
        trial = f"{line} {word}".strip()
        if line and draw.textlength(trial, font=font) > width:
            lines.append(line)
            line = word
        else:
            line = trial
    if line:
        lines.append(line)
    return lines


def make_jpg(out, groups):
    cols, width, gap, margin = 5, 252, 16, 38
    fonts = Path(os.environ["WINDIR"]) / "Fonts"
    title = ImageFont.truetype(str(fonts / "cambria.ttc"), 53)
    header = ImageFont.truetype(str(fonts / "cambria.ttc"), 34)
    section = ImageFont.truetype(str(fonts / "cambria.ttc"), 27)
    regular = ImageFont.truetype(str(fonts / "segoeui.ttf"), 16)
    bold = ImageFont.truetype(str(fonts / "segoeuib.ttf"), 17)
    heights = {"vertical": 360, "horizontal": 132}
    last = ""
    height = 132 + margin
    for ratio, _, entries in groups:
        height += 52 if ratio != last else 0
        height += 44 + ((len(entries) + cols - 1) // cols) * (heights[ratio] + 99)
        last = ratio
    sheet = Image.new("RGB", (2 * margin + cols * width + (cols - 1) * gap, height), "#f3eee3")
    d = ImageDraw.Draw(sheet)
    ink = "#302820"
    d.text((margin, 27), "CivCity · Кадры для монтажа", font=title, fill=ink)
    d.text((margin, 92), "25 ноября 2026 · MP4 · 60 кадров/с", font=regular, fill="#665645")
    y, last = 132, ""
    for ratio, category, entries in groups:
        if ratio != last:
            d.text((margin, y), FORMATS[ratio], font=header, fill=ink)
            y += 52
            last = ratio
        d.text((margin, y), CATEGORIES[category], font=section, fill=ink)
        y += 44
        img_h = heights[ratio]
        for i, (src, thumb, dur, text, _) in enumerate(entries):
            x = margin + (i % cols) * (width + gap)
            yy = y + (i // cols) * (img_h + 99)
            d.rounded_rectangle((x, yy, x + width, yy + img_h + 86), radius=7, fill="#fffcf3", outline="#ddcfb9")
            with Image.open(thumb) as original:
                img = ImageOps.contain(original, (width - 14, img_h - 7), Image.Resampling.LANCZOS)
                sheet.paste(img, (x + (width - img.width) // 2, yy + 7))
            d.text((x + 8, yy + img_h + 9), f"{Path(src).name}   ·   {dur:g} с", font=bold, fill=ink)
            for j, line in enumerate(wrap(d, text, regular, width - 16)):
                d.text((x + 8, yy + img_h + 34 + j * 19), line, font=regular, fill=ink)
        y += ((len(entries) + cols - 1) // cols) * (img_h + 99)
    sheet.save(out / "contact_sheet.jpg", quality=92, optimize=True)


def review(media, groups):
    ffmpeg, _ = binaries()
    dest = STAGE / "review"
    os.makedirs(dest, exist_ok=True)
    rows = []
    for _, _, entries in groups:
        for relative, _, duration, _, _ in entries:
            name = relative.replace("/", "_").removesuffix(".mp4")
            samples = []
            for label, fraction in (("start", 0.0), ("mid", 0.5), ("end", 0.98)):
                pic = dest / f"{name}_{label}.jpg"
                src = media / relative
                if not pic.exists() or pic.stat().st_mtime < src.stat().st_mtime:
                    frame(ffmpeg, src, duration * fraction, pic, 250)
                with Image.open(pic) as im:
                    if ImageStat.Stat(im.convert("L")).mean[0] < 12:
                        print("Проверьте тёмный кадр", relative, label)
                samples.append(pic)
            rows.append((name, samples))
    font = ImageFont.truetype(str(Path(os.environ["WINDIR"]) / "Fonts/segoeui.ttf"), 14)
    for start in range(0, len(rows), 8):
        batch = rows[start:start + 8]
        board = Image.new("RGB", (1000, ((len(batch) + 1) // 2) * 300), "#27221e")
        d = ImageDraw.Draw(board)
        for i, (name, samples) in enumerate(batch):
            x, y = (i % 2) * 500 + 6, (i // 2) * 300 + 6
            d.text((x, y), name, font=font, fill="#fff9ec")
            for j, path in enumerate(samples):
                with Image.open(path) as img:
                    board.paste(ImageOps.contain(img, (158, 264), Image.Resampling.LANCZOS), (x + j * 165, y + 21))
        board.save(dest / f"review_{start // 8 + 1:02}.jpg", quality=90)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=CATALOG)
    parser.add_argument("--media", type=Path, help="Читать клипы из другой папки, не записывая туда каталог")
    parser.add_argument("--exclude", type=Path, help="Список отклонённых дублей, один путь на строку")
    parser.add_argument("--review", action="store_true")
    args = parser.parse_args()
    rejected = set(args.exclude.read_text(encoding="utf-8").splitlines()) if args.exclude else set()
    media = args.media or args.out
    groups = collect(args.out, rejected, media)
    if not groups:
        parser.exit(1, "Нет проверенных клипов\n")
    make_html(args.out, groups, media)
    make_jpg(args.out, groups)
    if args.review:
        review(media, groups)
    for ratio in SIZES:
        clips = [entry for key, _, entries in groups if key == ratio for entry in entries]
        print(f"{ratio}: {len(clips)} клипов, {sum(e[2] for e in clips):g} с, {sum(e[4] for e in clips) / 1048576:.1f} МиБ")


if __name__ == "__main__":
    main()
