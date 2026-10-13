#!/usr/bin/env bash
# Автопроверка СОБРАННОЙ игры (build/game) без человека — сценарии из godot/scripts/qa_drive.gd (аргумент --qa).
# Под замком видеокарты (через deploy/run_exported.sh), всё на диске D. Нужны: свой сервер аккаунтов и тестовые аккаунты:
#   PORT=3010 DATA_DIR=D:/CivCity/.work/srvdata node server/index.js            (в отдельном окне)
#   bash .work/py/gpu_run.sh res://test_qa_city.tscn                              (город с Легионом → .work/qa/legion_city.json)
#   node deploy/qa_accounts.js                                                    (аккаунты → .work/qa/accounts.json)
# Затем:
#   bash deploy/qa_exported.sh login     — окно входа: регистрация A, «Играть», новый город, дома, в облако, выход
#   bash deploy/qa_exported.sh restore   — «чистый компьютер»: вход A, город скачан из облака, «Играть», выход
#   bash deploy/qa_exported.sh legion    — вход как от лаунчера (CIVCITY_SESSION B), окно «Легион», 3D-бой ×3 «Авто»,
#                                          итог, «В лагерь», «Против городов» (список соперников с сервера), выход
#   bash deploy/qa_exported.sh all       — все три по очереди
# Итог — строки «QA …», последняя «QA DONE fails=N»; снимки — в .work/qa/shots/<сценарий>/; журнал — .work/qa/logs/.
set -uo pipefail
ROOT=/d/CivCity
ACC=$ROOT/.work/qa/accounts.json
[ -f "$ACC" ] || { echo "нет $ACC — сначала node deploy/qa_accounts.js"; exit 1; }
j() { python -I -c "import json,sys;d=json.load(open(sys.argv[1]));print(eval(sys.argv[2]))" "$ACC" "$1"; }
API=$(j "d['api']")
LOG="$ROOT/.work/exp_appdata/CivCity Game/logs/godot.log"
fails=0
one() {
  local sc=$1; shift
  local sd=$ROOT/.work/qa/saves_$sc
  rm -rf "$sd"; mkdir -p "$sd" "$ROOT/.work/qa/shots/$sc" "$ROOT/.work/qa/logs"
  echo '{"fullscreen":false,"tut_done":true,"quality":"high"}' > "$sd/settings.json"
  rm -f "$LOG"
  CIVCITY_SAVEDIR=$(cygpath -m "$sd") RUN_TIMEOUT=480 bash "$ROOT/deploy/run_exported.sh" -- --menu --api="$API" --qa=$sc \
    --qa_out="D:/CivCity/.work/qa/shots/$sc" "$@" > "$ROOT/.work/qa/logs/$sc.out" 2>&1
  cp "$LOG" "$ROOT/.work/qa/logs/$sc.godot.log" 2>/dev/null
  echo "== $sc: $(grep '^exit=' "$ROOT/.work/qa/logs/$sc.out")"
  grep -E "^QA|SCRIPT ERROR|^ERROR|^WARNING" "$LOG" | grep -v "^QA shot"
  grep -q "^QA DONE fails=0" "$LOG" || fails=$((fails + 1))
}
run() {
  case "$1" in
    login)   one login --qa_reg=1 --qa_mail="$(j "d['A']['email']")" --qa_pass="$(j "d['A']['password']")" ;;
    restore) one restore --qa_mail="$(j "d['A']['email']")" --qa_pass="$(j "d['A']['password']")" --qa_expect=4 ;;
    legion)  CIVCITY_SESSION=$(python -I -c "import json,sys;d=json.load(open(sys.argv[1]));print(json.dumps({'token':d['B']['token'],'email':d['B']['email'],'api':d['api']}))" "$ACC") one legion ;;
    *) echo "сценарии: login | restore | legion | all"; exit 2 ;;
  esac
}
if [ "${1:-all}" = "all" ]; then for s in login restore legion; do run $s; done; else run "$1"; fi
echo; [ $fails -eq 0 ] && echo "ВСЁ В ПОРЯДКЕ" || echo "ЕСТЬ ОШИБКИ: $fails"
exit $fails
