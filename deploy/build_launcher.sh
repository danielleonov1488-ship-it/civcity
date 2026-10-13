#!/usr/bin/env bash
# Сборка установщика лаунчера CivCity → desktop/dist/CivCity-<версия>-setup.exe (версия — в desktop/package.json).
#   bash deploy/build_launcher.sh
# Всё на диске D: кэши electron, electron-builder и npm — в .work/cache, временные файлы — в .work/tmp.
# Свои картинки (значок 30.png, фон 31.png из assets/incoming/ui_ai) подхватываются сами — см. desktop/prepare.js.
set -euo pipefail
cd "$(dirname "$0")/.."
W=$(cygpath -m "$(pwd)/.work" 2>/dev/null || echo "$(pwd)/.work")
mkdir -p "$W/cache/electron" "$W/cache/electron-builder" "$W/cache/npm" "$W/tmp/launcher_build" "$W/tmp/localappdata"
export ELECTRON_CACHE="$W/cache/electron" ELECTRON_BUILDER_CACHE="$W/cache/electron-builder" npm_config_cache="$W/cache/npm"
export TEMP="$W/tmp/launcher_build" TMP="$W/tmp/launcher_build" LOCALAPPDATA="$W/tmp/localappdata"
cd desktop
[ -d node_modules/electron-builder ] || npm ci
npm run build
VER=$(node -p "require('./package.json').version")
ls -la "dist/CivCity-$VER-setup.exe"
