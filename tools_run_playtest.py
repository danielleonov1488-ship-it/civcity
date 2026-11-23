"""Run the windowed CivCity playtest under gpu_run.sh and assemble its report."""

import argparse
import csv
from datetime import datetime
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont


LANE = Path(__file__).resolve().parent
TASK = Path("D:/CivCity/.work/stage7/playtest13")
ERROR_LINE = re.compile(r"^\s*(SCRIPT ERROR:|ERROR:|push_error\b)\s*(.*)$")
THUMB = (256, 144)
COLS, ROWS = 5, 4
CAPTION = 37
PHASES = {1: "Обучение города", 2: "Свободная игра", 3: "Легион", 4: "Настройки и загрузка"}


def launch(output: Path) -> int:
    bash = Path(os.environ.get("ProgramFiles", "C:/Program Files")) / "Git/bin/bash.exe"
    shell = str(bash) if bash.is_file() else shutil.which("bash")
    if shell is None:
        raise RuntimeError("Git Bash не найден")
    profile = output / "profiles" / datetime.now().strftime("%Y%m%d_%H%M%S_%f")
    env = dict(os.environ, GPU_TIMEOUT=os.environ.get("GPU_TIMEOUT", "2700"), ONE_GODOT="1", CIVCITY_TESTWIN="hidden",
               CIVCITY_SAVEDIR=profile.as_posix(), CIVCITY_NOLOGIN="1")
    script = "/d/CivCity/.work/py/gpu_run.sh"
    args = [shell, "--noprofile", "--norc", script, "--resolution", "1920x1080", "--log-file",
            (output / "godot.log").as_posix(), "res://test_playtest.tscn", "--", "--new", "--nologin",
            "--playtest-postprocess", f"--savedir={profile.as_posix()}", f"out={output.as_posix()}"]
    with (output / "self_test.txt").open("x", encoding="utf-8") as log:
        with subprocess.Popen(args, cwd=LANE, env=env, stdout=subprocess.PIPE,
                              stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace") as process:
            assert process.stdout is not None
            for line in process.stdout:
                log.write(line)
                log.flush()
                print(line.rstrip(), flush=True)
            return process.wait()


def fonts() -> tuple[ImageFont.FreeTypeFont, ImageFont.FreeTypeFont]:
    folder = Path(os.environ.get("WINDIR", "C:/Windows")) / "Fonts"
    return ImageFont.truetype(str(folder / "arialbd.ttf"), 13), ImageFont.truetype(str(folder / "arial.ttf"), 12)


def fit(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.FreeTypeFont, width: int) -> str:
    if draw.textlength(text, font=font) <= width:
        return text
    while text and draw.textlength(text + "…", font=font) > width:
        text = text[:-1]
    return text + "…"


def sheets(output: Path) -> tuple[list[str], dict[str, int], list[str]]:
    shots = output / "shots"
    index = shots / "frames.tsv"
    totals: dict[str, int] = {}
    sources: dict[int, list[tuple[Path, int, str]]] = {}
    artifacts: list[str] = []
    problems: list[str] = []
    if not index.is_file():
        return artifacts, totals, problems
    with index.open(encoding="utf-8", newline="") as stream:
        for row in csv.reader(stream, delimiter="\t"):
            if len(row) != 4:
                continue
            filename, phase, second, title = row
            sources.setdefault(int(phase), []).append((shots / "frames" / filename, int(second), title))
    head, body = fonts()
    for phase, frames in sorted(sources.items()):
        frames.sort(key=lambda record: record[1])
        error_count = 0
        totals[f"p{phase}.frame_jpegs"] = 0
        totals[f"p{phase}.seconds_without_frame"] = frames[-1][1] + 1 - len(frames)
        if totals[f"p{phase}.seconds_without_frame"] > 0:
            problems.append(f"p{phase}: пропущены секунды записи кадров — {totals[f'p{phase}.seconds_without_frame']}")
        for start in range(0, len(frames), COLS * ROWS):
            height = THUMB[1] + CAPTION
            sheet = Image.new("RGB", (THUMB[0] * COLS, height * ROWS), "#242321")
            draw = ImageDraw.Draw(sheet)
            for cell, (path, second, title) in enumerate(frames[start:start + COLS * ROWS]):
                x = (cell % COLS) * THUMB[0]
                y = (cell // COLS) * height
                try:
                    with Image.open(path) as frame:
                        if frame.size != (1280, 720):
                            raise ValueError(f"неверный размер {frame.size}")
                        sheet.paste(frame.resize(THUMB, Image.Resampling.LANCZOS), (x, y))
                    totals[f"p{phase}.frame_jpegs"] += 1
                except (OSError, ValueError):
                    error_count += 1
                heading = f"{second // 60:02}:{second % 60:02}  ·  Фаза {phase}  ·  {PHASES[phase]}"
                draw.text((x + 7, y + THUMB[1] + 3), fit(draw, heading, head, THUMB[0] - 14),
                          font=head, fill="#ffffff")
                draw.text((x + 7, y + THUMB[1] + 19), fit(draw, title, body, THUMB[0] - 14),
                          font=body, fill="#e0d5c1")
            target = shots / f"sheet_{phase}_{start // (COLS * ROWS) + 1:02}.jpg"
            sheet.save(target, "JPEG", quality=90)
            artifacts.append(target.relative_to(output).as_posix())
        if error_count:
            problems.append(f"p{phase}: {error_count} JPEG отсутствуют или имеют неверный размер")
    return artifacts, totals, problems


def tallies(output: Path) -> tuple[dict[str, int], list[str], list[str]]:
    console = output / "self_test.txt"
    raw = output / "godot.log"
    errors = []
    counts = {"errors.count": 0, "errors.script": 0, "errors.engine": 0, "errors.push_error": 0}
    seen = set()
    issues = []
    if console.is_file():
        issues = [line.removeprefix("PLAYTEST ISSUE ") for line in console.read_text(encoding="utf-8").splitlines()
                  if line.startswith("PLAYTEST ISSUE ")]
    source = raw if raw.is_file() else console
    if not source.is_file():
        return counts, errors, issues
    for line in source.read_text(encoding="utf-8", errors="replace").splitlines():
        error = ERROR_LINE.match(line)
        if error is not None:
            kind = {"SCRIPT ERROR:": "script", "ERROR:": "engine", "push_error": "push_error"}[error[1]]
            counts["errors.count"] += 1
            counts[f"errors.{kind}"] += 1
            message = line.strip()
            if message not in seen and len(errors) < 20:
                errors.append(message)
            seen.add(message)
    return counts, errors, issues


def report(output: Path, exit_code: int | None) -> int:
    source = output / "metrics.json"
    data = json.loads(source.read_text(encoding="utf-8")) if source.is_file() else {}
    metrics, evidence = data.get("metrics", {}), data.get("evidence", {})
    extra, errors, logged_issues = tallies(output)
    count = extra["errors.count"]
    issues = list(dict.fromkeys(data.get("issues", []) + logged_issues))
    if count:
        issues.append(f"В журнале {count} строк с ошибками")
    if "routes" not in evidence:
        issues.append("Сцена не завершила запись метрик")
    else:
        for route, complete in evidence["routes"].items():
            if not complete:
                issues.append(f"Маршрут не завершён — {route}")
        for route in ("city_tutorial", "free_play", "fort", "reload"):
            if route not in evidence["routes"]:
                issues.append(f"Маршрут не начат — {route}")
    if exit_code not in (None, 0, 1):
        issues.append(f"Код выхода запуска {exit_code}")
    artifacts, frame_metrics, frame_issues = sheets(output)
    extra.update(frame_metrics, sheets_count=len(artifacts))
    issues.extend(frame_issues)
    issues = list(dict.fromkeys(issues))
    summary = []
    for key, value in extra.items():
        summary.append(f"PLAYTEST METRIC {key}={value}")
    for issue in issues:
        if issue not in logged_issues:
            summary.append(f"PLAYTEST ISSUE {issue}")
    lines = [f"PLAYTEST METRIC {key}={value}" for key, value in sorted((metrics | extra).items())]
    lines += [f"PLAYTEST ISSUE {issue}" for issue in issues]
    lines += ["", "Первые 20 уникальных ошибок", *(errors or ["—"]), "", "Подробности",
              json.dumps(evidence, ensure_ascii=False, indent=2), "", "Контактные листы", *artifacts,
              "", f"PLAYTEST DONE issues={len(issues)}"]
    (output / "report.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
    summary.append(lines[-1])
    if exit_code is not None:
        with (output / "self_test.txt").open("a", encoding="utf-8") as run_log:
            run_log.write("\n".join(summary) + "\n")
    print("\n".join(summary), flush=True)
    return int(bool(issues))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=TASK)
    parser.add_argument("--report-only", action="store_true")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    exit_code = None if args.report_only else launch(output)
    return report(output, exit_code)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    raise SystemExit(main())
