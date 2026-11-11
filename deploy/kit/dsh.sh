#!/usr/bin/env bash
# DeepSeek Harness (установлен владельцем) без окна, через его аккаунт DeepSeek:
#   cd <папка-работы> && bash /d/CivCity/tools/dsh.sh "задача"        → ответ в stdout, ход мыслей в stderr
#   DSH_MODEL=deepseek-v4-pro bash tools/dsh.sh "..."                       → другая модель (модели: deepseek-flash, deepseek-v4-pro)
# exe вызывается напрямую (через dsh.cmd ломаются кавычки в длинных задачах).
DSH_DIR="$LOCALAPPDATA/Programs/DeepSeek Harness"
HERE="$(cd "$(dirname "$0")" && pwd)"
export ELECTRON_RUN_AS_NODE=1
run() { "$DSH_DIR/DeepSeek Harness.exe" --expose-internals "$DSH_DIR/resources/app.asar/dsh/node_modules/@deepseek-ai/dsh-desktop-host/lib/cli.js" "$@"; }
if [ "$1" = "--raw" ]; then shift; run "$@"; exit $?; fi
run --profile headless --patch "$(cygpath -w "$HERE/dsh-account.yml")" "$@"
