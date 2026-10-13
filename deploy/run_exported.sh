#!/usr/bin/env bash
# Запуск собранной игры (build/game/CivCity.exe) строго под общим замком видеокарты, как gpu_run.sh:
#   bash deploy/run_exported.sh -- --demo --shot=D:/CivCity/.work/shot.png --frames=200
# Сохранения — в D:/CivCity/.work/exp_saves (CIVCITY_SAVEDIR), данные Godot (журнал godot.log, кэш шейдеров) —
# в D:/CivCity/.work/exp_appdata (APPDATA подменён, чтобы ничего не писалось на диск C).
# Журнал игры после запуска: D:/CivCity/.work/exp_appdata/CivCity Game/logs/godot.log
LOCK=/d/CivCity/.work/gpu.lock
EXE=${CIVCITY_EXE:-/d/CivCity/build/game/CivCity.exe}
mkdir -p /d/CivCity/.work/exp_saves /d/CivCity/.work/exp_appdata
for i in $(seq 1 900); do
  if mkdir "$LOCK" 2>/dev/null; then break; fi
  sleep 2
done
trap 'rmdir "$LOCK" 2>/dev/null' EXIT
export APPDATA='D:\CivCity\.work\exp_appdata'
export CIVCITY_SAVEDIR=${CIVCITY_SAVEDIR:-D:/CivCity/.work/exp_saves}
timeout ${RUN_TIMEOUT:-300} "$EXE" "$@"
code=$?
echo "exit=$code"
LOG="/d/CivCity/.work/exp_appdata/CivCity Game/logs/godot.log"
if [ -f "$LOG" ]; then
  echo "--- godot.log (ошибки и предупреждения):"
  grep -nE "ERROR|WARNING|SCRIPT ERROR|Packs|SHOT" "$LOG" | head -60
fi
exit $code
