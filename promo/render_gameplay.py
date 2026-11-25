"""Съёмка PROMO27 из рабочей копии через общий замок Godot."""

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path("D:/CivCity")
LANE = Path(__file__).resolve().parents[1]
STAGE = ROOT / ".work/stage7/promo27"
HANDOFF = STAGE / "gameplay_20261125"
REMOTION = ROOT / "promo/video/node_modules/@remotion/compositor-win32-x64-msvc"
FPS = 60
SIZES = {"vertical": (1080, 1920), "horizontal": (1920, 1080)}
CATEGORIES = {
    "A": "Город без интерфейса",
    "B": "Как играть",
    "C": "Легион",
    "D": "Город с нуля",
}
# Имя, длительность, широкий дубль, подпись для монтажёра.
CLIPS = {
    "A": [
        ("arrival", 10, True, "Повозка с новосёлами въезжает через арку."),
        ("street", 9, True, "Тихий утренний пролёт вдоль главной улицы."),
        ("grow", 9, True, "Дом вырастает и получает два новых этажа."),
        ("market", 10, True, "Медленный облёт рынка с фонтаном и прохожими."),
        ("cat", 9, True, "Ребёнок подходит к кошке на площади и гладит её."),
        ("villa", 9, True, "Камера проходит вдоль вилл, садов и портиков."),
        ("park", 9, True, "Вечерний парк с беседками у воды."),
        ("forum", 9, True, "Форум и Пантеон в тёплом свете."),
        ("aqueduct", 10, True, "Акведук тянется к городу из-за холмов."),
        ("pullback", 12, True, "Камера отлетает от рынка и открывает весь город."),
        ("temple", 10, True, "Камера приближается к храму Юпитера на закате."),
        ("dusk", 10, True, "Над улицей сгущаются сумерки, зажигаются окна."),
        ("night", 9, True, "Ночной рынок освещают фонари и жаровни."),
        ("rain", 10, False, "Дождь над улицей и мокрой мостовой."),
        ("autumn", 10, False, "Осенние деревья и листопад у городского сада."),
        ("arena_full", 11, True, "Облёт амфитеатра с заполненными трибунами."),
        ("festival", 10, False, "Праздничные флаги и гирлянды на главной улице."),
        ("harvest", 10, False, "Поля, фруктовые ряды и работники за городской аркой."),
        ("boats", 10, False, "Лодка неспешно идёт по городскому озеру."),
        ("day_night", 14, True, "Над одним кварталом день сменяется ночью."),
        ("top_down", 14, False, "От крыши одного дома камера уходит вверх над городом."),
    ],
    "B": [
        ("road_drag", 10, False, "Курсор тянет мостовую от главной дороги."),
        ("three_houses", 14, True, "Три дома по очереди вырастают вдоль улицы."),
        ("move_in", 15, False, "Повозка привозит семью, игрок выбирает для неё дом."),
        ("fruit_stall", 11, True, "Игрок ставит фруктовую лавку, зелёный цвет показывает дома в охвате."),
        ("hire", 10, False, "Игрок нанимает работника через карточку лавки."),
        ("floor", 11, False, "Инструмент «Этаж» надстраивает жилой дом."),
        ("garden", 9, False, "Цветочный партер появляется у дороги."),
        ("fountain", 10, False, "Игрок ставит фонтан, над чашей поднимаются струи."),
        ("requests", 10, False, "После постройки игрок видит отметку выполненной просьбы."),
        ("research", 10, False, "Игрок открывает дерево исследований."),
        ("arena_build", 14, True, "Амфитеатр вырастает, зрители идут на трибуны."),
    ],
    "C": [
        ("fort", 11, True, "В разрезе форта видно, как люди работают в комнатах."),
        ("recruit", 10, False, "Игрок открывает список новобранцев и принимает бойца."),
        ("battle", 12, True, "Отряды сходятся в коротком игровом бою."),
        ("campaign", 10, False, "Карта похода с лагерями и этапами кампании."),
    ],
    "D": [
        ("cityrise", 20, True, "Из пустого участка вырастает город со своими кварталами."),
    ],
}


def binaries():
    return [shutil.which(name) or str(REMOTION / f"{name}.exe") for name in ("ffmpeg", "ffprobe")]


def probe(path, ffprobe, size, duration):
    if not path.is_file():
        return False
    result = subprocess.run(
        [ffprobe, "-v", "error", "-show_streams", "-of", "json", path],
        capture_output=True, text=True,
    )
    if result.returncode:
        return False
    streams = json.loads(result.stdout)["streams"]
    if len(streams) != 1:
        return False
    video = streams[0]
    return (
        (video.get("width"), video.get("height")) == size
        and video.get("avg_frame_rate") == f"{FPS}/1"
        and video.get("codec_name") == "h264"
        and video.get("pix_fmt") == "yuv420p"
        and int(video.get("nb_frames", 0)) == round(duration * FPS)
    )


def available_path(path):
    if not path.exists():
        return path
    for i in range(2, 1000):
        candidate = path.with_stem(f"{path.stem}_{i}")
        if not candidate.exists():
            return candidate
    raise RuntimeError(f"Нет свободного имени рядом с {path}")


def render(name, duration, orientation, out, args):
    ffmpeg, ffprobe = binaries()
    w, h = SIZES[orientation]
    video_dir = out / orientation
    shots = STAGE / "shots" / orientation
    logs = STAGE / "render_logs"
    saves = STAGE / "saves"
    for folder in (video_dir, shots, logs, saves):
        os.makedirs(folder, exist_ok=True)
    path = video_dir / f"{name}.mp4"
    if not args.redo and probe(path, ffprobe, (w, h), duration):
        print(f"Уже снят {orientation}/{name}", flush=True)
        return True
    pending = available_path(logs / f"{orientation}_{name}.mp4")
    env = dict(os.environ, ONE_GODOT="1", GPU_TIMEOUT="900",
               CIVCITY_NOLOGIN="1", CIVCITY_SAVEDIR=saves.as_posix())
    bash = Path(os.environ["ProgramFiles"]) / "Git/usr/bin/bash.exe"
    capture = [
        bash, "/d/CivCity/.work/py/gpu_run.sh", "--rendering-method", "forward_plus",
        "--fixed-fps", str(FPS), f"res://{args.scene}.tscn", "--", f"clip={name}", f"fps={FPS}",
        f"dur={duration}", f"size={w}x{h}", f"ffmpeg={Path(ffmpeg).as_posix()}",
        "rawpipe", "crf=14", "threads=6", "nologs", f"shot_name={name}",
        f"out={pending.as_posix()}", f"shots={shots.as_posix()}",
    ]
    if orientation == "vertical":
        capture.append("vertical")
    print(f"Съёмка {orientation}/{name} · {duration:g} с", flush=True)
    with available_path(logs / f"{orientation}_{name}.txt").open("x", encoding="utf-8") as log:
        result = subprocess.run(capture, env=env, cwd=LANE, stdout=log, stderr=log)
        log_path = log.name
    if result.returncode or not probe(pending, ffprobe, (w, h), duration):
        print(f"Сбой {orientation}/{name} · {log_path}", flush=True)
        return False
    if path.exists():
        path.rename(available_path(logs / f"{orientation}_{name}_previous.mp4"))
    pending.rename(path)
    print(f"Готов {orientation}/{name} · {path.stat().st_size / 1048576:.1f} МБ", flush=True)
    return True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("clips", nargs="*", help="Имена клипов из каталога; без имён — все")
    parser.add_argument("--format", choices=[*SIZES, "both"], default="both")
    parser.add_argument("--group", choices=CATEGORIES)
    parser.add_argument("--out", type=Path, default=HANDOFF)
    parser.add_argument("--redo", action="store_true", help="Переснять, сохранив предыдущий дубль в журнале")
    parser.add_argument("--scene", default="promo27_cam", help=argparse.SUPPRESS)
    args = parser.parse_args()
    names = {clip[0] for category in CLIPS.values() for clip in category}
    if unknown := set(args.clips) - names:
        parser.error("Неизвестные клипы: " + ", ".join(sorted(unknown)))
    failed = []
    for orientation in SIZES:
        if args.format not in (orientation, "both"):
            continue
        for group, category in CLIPS.items():
            if args.group and group != args.group:
                continue
            for name, duration, wide, _ in category:
                if args.clips and name not in args.clips:
                    continue
                if orientation == "horizontal" and not (wide or args.clips):
                    continue
                if not render(name, duration, orientation, args.out.resolve(), args):
                    failed.append(f"{orientation}/{name}")
    if failed:
        print("Требуют пересъёмки: " + ", ".join(failed), file=sys.stderr)
    return int(bool(failed))


if __name__ == "__main__":
    sys.exit(main())
