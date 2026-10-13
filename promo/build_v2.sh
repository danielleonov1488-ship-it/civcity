#!/usr/bin/env bash
# Монтаж промо-ролика v2 (Remotion, promo/video/src/Promo2.tsx) из клипов promo/render_v2.sh.
#   bash promo/build_v2.sh            # широкий 2560×1440 и вертикальный 1080×1920 + медиа для сайта
#   bash promo/build_v2.sh wide       # только широкий
#   bash promo/build_v2.sh vertical   # только вертикальный
#   bash promo/build_v2.sh site       # только site_media (петли, снимки, ролик 1080p)
# Видеокарту не трогает: кадры Remotion рисует процессор (--gl=swangle), кодирует x264 (NVENC требует драйвер NVIDIA 610+).
# Временные файлы и кэши — только на диске D.
set -eu
cd /d/CivCity/promo/video
export TEMP='D:\CivCity\.work\tmp' TMP='D:\CivCity\.work\tmp' TMPDIR='D:\CivCity\.work\tmp'
export npm_config_cache='D:/CivCity/.work/cache/npm' npm_config_update_notifier=false
mkdir -p /d/CivCity/.work/tmp out
R="node node_modules/@remotion/cli/remotion-cli.js render src/index.ts"
COMMON="--public-dir=public2 --gl=swangle --codec=h264 --pixel-format=yuv420p --audio-codec=aac --audio-bitrate=256k"
what=${1:-all}
if [ "$what" = all ] || [ "$what" = wide ]; then
  $R Promo2 out/civcity-promo-2.mp4 $COMMON --crf=17
fi
if [ "$what" = all ] || [ "$what" = vertical ]; then
  $R Vertical2 out/civcity-vertical-2.mp4 $COMMON --crf=18
fi
if [ "$what" = all ] || [ "$what" = site ]; then
  python -I /d/CivCity/promo/site_media.py all
fi
