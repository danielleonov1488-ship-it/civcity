#!/usr/bin/env bash
# Съёмка клипов для промо-ролика v2 (Godot-витрина --promo, scripts/promo_cam.gd).
# Каждый клип — отдельный запуск игры через общий замок видеокарты (.work/py/gpu_run.sh), по одному.
#   bash promo/render_v2.sh                 # всё: широкие клипы, вертикальные, петли для сайта, снимки
#   bash promo/render_v2.sh wide            # только широкие 2560×1440
#   bash promo/render_v2.sh vertical        # только вертикальные 1080×1920
#   bash promo/render_v2.sh loops           # петли для сайта (1920×1080 → site_media.py склеит 1280×720)
#   bash promo/render_v2.sh stills          # 12 снимков 3840×2160 в site_media/screens
#   bash promo/render_v2.sh clip market     # один клип (можно добавить vertical)
# Клипы: promo/video/public2/shots2/<имя>.mp4 и <имя>_v.mp4 (оттуда их берёт монтаж); превью кадров — .work/promo/cam_rec.
set -u
cd /d/CivCity
RUN="bash .work/py/gpu_run.sh --fixed-fps 30 res://promo_cam.tscn --"
WIDE="arrival street grow market cat villa park forum aqueduct pullback temple dusk night"
VERT="arrival street grow market cat villa park pullback temple dusk night"
LOOPS="loop_market loop_street loop_park loop_villa loop_forum loop_temple loop_night loop_fields"

one() {  # имя [vertical]
  local t0=$(date +%s)
  $RUN clip=$1 ${2:-} 2>&1 | grep -E "PROMO_CAM|ERROR|SCRIPT ERROR" | grep -v "^\s*at:"
  echo "   ($1 ${2:-}: $(( $(date +%s) - t0 )) s)"
}

what=${1:-all}
case "$what" in
  clip) one "$2" "${3:-}" ;;
  wide) for c in $WIDE; do one $c; done ;;
  vertical) for c in $VERT; do one $c vertical; done ;;
  loops) for c in $LOOPS; do one $c; done ;;
  stills) $RUN stills=all 2>&1 | grep -E "STILL|PROMO_CAM|ERROR" ;;
  all)
    for c in $WIDE; do one $c; done
    for c in $VERT; do one $c vertical; done
    for c in $LOOPS; do one $c; done
    $RUN stills=all 2>&1 | grep -E "STILL|PROMO_CAM|ERROR"
    ;;
esac
