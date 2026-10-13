#!/usr/bin/env bash
# Сборка CivCity для Windows → D:/CivCity/build/game/
#
#   bash deploy/build_game.sh            # обычная сборка (то же: bash tools/build_game.sh)
#   bash deploy/build_game.sh --force    # пересобрать и большие наборы, даже если их файлы не менялись
#
# Что получается (договорённость с программой запуска и сервером):
#   CivCity.exe          — движок Godot 4.7.2 (меняется только при смене версии движка, значка или подписи файла)
#   CivCity.pck          — код, сцены, шейдеры: ~1 МБ, меняется почти в каждом обновлении
#   CivCity_ui.pck       — рисованный интерфейс, шрифты, звуки (assets/ui, assets/fonts, assets/sfx)
#   CivCity_models.pck   — модели и текстуры (assets/synty, people, animals, artisau)
#   CivCity_music.pck    — музыка (assets/music)
#   version.json         — {"version": "1.0.0", "build": N}; N растёт на 1 с каждой сборкой
# Большие наборы пересобираются, только если изменились их исходные файлы (сверка по SHA-1 в build/packs_state.json),
# иначе остаётся прежний файл байт в байт — программа запуска его не скачивает заново.
# Наборы подключает в игре scripts/packs.gd (автозагрузка Packs); состав наборов — фильтры в godot/export_presets.cfg.
# Сборка не рисует (headless), замок видеокарты не нужен. Запуск собранной игры для проверки — deploy/run_exported.sh.
set -uo pipefail

ROOT=/d/CivCity
GODOT=$ROOT/tools/godot/Godot_v4.7.2-stable_win64_console.exe
TEMPLATES=$ROOT/tools/godot/editor_data/export_templates/4.7.2.stable
PROJ=D:/CivCity/godot
OUT=$ROOT/build/game
STAGE=$ROOT/build/.stage
STATE=$ROOT/build/packs_state.json
LOGS=$ROOT/.work/build_game
FORCE=0
[ "${1:-}" = "--force" ] && FORCE=1

# имя набора в export_presets.cfg : файл. Папки набора берутся из его include_filter («assets/synty/*,…»).
# Новая большая папка с картинками/моделями: добавить её в include_filter нужного набора И в exclude_filter набора
# «Windows» (иначе она попадёт в CivCity.pck и каждое обновление станет тяжёлым). Новый набор — ещё и в scripts/packs.gd.
PACKS=(
  "Models:CivCity_models.pck"
  "Music:CivCity_music.pck"
  "UI:CivCity_ui.pck"
)

die() { echo "ОШИБКА: $*" >&2; exit 1; }
[ -x "$GODOT" ] || die "нет движка $GODOT"
[ -f "$TEMPLATES/windows_release_x86_64.exe" ] || die "нет шаблонов экспорта в $TEMPLATES (tools/godot-dl/Godot_v4.7.2-stable_export_templates.tpz)"
mkdir -p "$OUT" "$LOGS"
rm -rf "$STAGE" && mkdir -p "$STAGE"

# никаких файлов Godot на диске C: кэш/журналы редактора уже в tools/godot/editor_data (._sc_), а user:// игры —
# в .work (на случай, если экспорт что-то туда пишет)
export APPDATA='D:\CivCity\.work\build_appdata'

godot() { timeout 1800 "$GODOT" --headless --path "$PROJ" "$@"; }
check_log() {   # ошибки экспорта (не прогресс)
  grep -E "^(ERROR|SCRIPT ERROR)|Export failed|failed to export" "$1" | grep -v "RID allocations\|resources still in use\|ObjectDB instances" | head -20
}

echo "== 1/4 импорт ресурсов"
godot --import > "$LOGS/import.log" 2>&1 || die "импорт упал, см. $LOGS/import.log"

VERSION=$(sed -n 's/^config\/version="\(.*\)"/\1/p' $ROOT/godot/project.godot | head -1)
[ -n "$VERSION" ] || VERSION="1.0.0"

echo "== 2/4 код и движок (CivCity.exe + CivCity.pck)"
godot --export-release "Windows" "$(cygpath -m "$STAGE")/CivCity.exe" > "$LOGS/export_main.log" 2>&1
code=$?
[ $code -eq 0 ] && [ -f "$STAGE/CivCity.exe" ] && [ -f "$STAGE/CivCity.pck" ] || { check_log "$LOGS/export_main.log"; die "экспорт кода не удался (код $code), см. $LOGS/export_main.log"; }
check_log "$LOGS/export_main.log"
rm -f "$STAGE"/CivCity.console.exe
main_kb=$(( $(stat -c %s "$STAGE/CivCity.pck") / 1024 ))
if [ $main_kb -gt 5120 ]; then
  echo "   ВНИМАНИЕ: CivCity.pck = $main_kb КБ — в код попали большие файлы (новая папка ассетов?). Что внутри:"
  python -I "$ROOT/deploy/pck_list.py" "$STAGE/CivCity.pck" --groups | head -8
fi

echo "== 3/4 большие наборы"
for entry in "${PACKS[@]}"; do
  IFS=':' read -r preset file <<< "$entry"
  filters=$(python -I -c "
import configparser,sys
c=configparser.RawConfigParser(); c.read(sys.argv[1], encoding='utf-8')
for s in c.sections():
    if c.get(s,'name',fallback='').strip('\"')==sys.argv[2]: print(c.get(s,'include_filter')+'|'+c.get(s,'exclude_filter'))
" "$ROOT/godot/export_presets.cfg" "$preset")
  [ -n "$filters" ] || die "в godot/export_presets.cfg нет набора «$preset»"
  dirs=$(echo "${filters%%|*}" | tr -d '"' | tr ',' '\n' | sed 's#/\*$##' | tr '\n' ' ')
  hash=$(python -I - "$ROOT/godot" "$filters" $dirs <<'PY'
import hashlib, os, sys
root, extra, dirs = sys.argv[1], sys.argv[2], sys.argv[3:]
h = hashlib.sha1(('godot-4.7.2|' + extra).encode())
for d in sorted(dirs):
    for base, subs, files in os.walk(os.path.join(root, d)):
        subs.sort()
        for f in sorted(files):
            p = os.path.join(base, f)
            rel = os.path.relpath(p, root).replace('\\', '/')
            h.update(rel.encode() + b'\0')
            with open(p, 'rb') as fh:
                for chunk in iter(lambda: fh.read(1 << 20), b''):
                    h.update(chunk)
print(h.hexdigest())
PY
)
  old=$(python -I -c "import json,sys;print(json.load(open(sys.argv[1])).get(sys.argv[2],''))" "$STATE" "$file" 2>/dev/null || true)
  if [ $FORCE -eq 0 ] && [ "$hash" = "$old" ] && [ -f "$OUT/$file" ]; then
    echo "   $file — без изменений, остаётся прежний"
    continue
  fi
  echo "   $file — собираю ($preset)…"
  godot --export-pack "$preset" "$(cygpath -m "$STAGE")/$file" > "$LOGS/export_$preset.log" 2>&1
  code=$?
  [ $code -eq 0 ] && [ -f "$STAGE/$file" ] || { check_log "$LOGS/export_$preset.log"; die "набор $file не собрался (код $code), см. $LOGS/export_$preset.log"; }
  check_log "$LOGS/export_$preset.log"
  echo "$file $hash" >> "$STAGE/.hashes"
done

echo "== 4/4 version.json и перенос в $OUT"
BUILD=$(python -I -c "import json,sys;print(int(json.load(open(sys.argv[1])).get('build',0))+1)" "$OUT/version.json" 2>/dev/null || echo 1)
printf '{"version": "%s", "build": %d}\n' "$VERSION" "$BUILD" > "$STAGE/version.json"

old_exe=$(sha256sum "$OUT/CivCity.exe" 2>/dev/null | cut -d' ' -f1)
for f in "$STAGE"/*; do
  mv -f "$f" "$OUT/" || die "не удалось заменить $(basename "$f") (игра запущена?)"
done
if [ -f "$STAGE/.hashes" ]; then
  python -I - "$STATE" "$STAGE/.hashes" <<'PY'
import json, sys
state, src = sys.argv[1], sys.argv[2]
try:
    d = json.load(open(state))
except Exception:
    d = {}
for line in open(src):
    f, h = line.split()
    d[f] = h
json.dump(d, open(state, 'w'), indent=1, sort_keys=True)
PY
fi
rm -rf "$STAGE"
# лишнее из прежних сборок (старые имена наборов, консольная обёртка) — убрать, чтобы не попало на сервер
for f in "$OUT"/*; do
  case "$(basename "$f")" in
    CivCity.exe|CivCity.pck|CivCity_models.pck|CivCity_music.pck|CivCity_ui.pck|version.json) ;;
    *) echo "   убираю лишнее: $(basename "$f")"; rm -rf "$f" ;;
  esac
done
new_exe=$(sha256sum "$OUT/CivCity.exe" | cut -d' ' -f1)

echo
echo "Готово: CivCity $VERSION, сборка $BUILD → $OUT"
total=0
for f in CivCity.exe CivCity.pck CivCity_ui.pck CivCity_models.pck CivCity_music.pck version.json; do
  s=$(stat -c %s "$OUT/$f")
  total=$((total + s))
  printf '  %-20s %9.2f МБ  %s\n' "$f" "$(echo "$s" | awk '{print $1/1048576}')" "$(sha256sum "$OUT/$f" | cut -c1-12)"
done
printf '  %-20s %9.2f МБ\n' "всего" "$(echo "$total" | awk '{print $1/1048576}')"
[ -n "$old_exe" ] && { [ "$old_exe" = "$new_exe" ] && echo "  CivCity.exe не изменился (обновление его не скачивает)" || echo "  CivCity.exe ИЗМЕНИЛСЯ (обновление скачает ~$(( $(stat -c %s "$OUT/CivCity.exe") / 1048576 )) МБ)"; }
echo "  Обычное обновление (только код): CivCity.pck + version.json ≈ $(( ($(stat -c %s "$OUT/CivCity.pck") + 1023) / 1024 )) КБ"
