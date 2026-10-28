#!/usr/bin/env bash
# Выкладка CivCity на сервер — одной командой: сайт, игра для лаунчера, установщик, сервер аккаунтов, Caddy.
#   bash deploy/deploy.sh                 — всё
#   bash deploy/deploy.sh game site …     — только названное: site | game | installer | server (можно несколько)
#   bash deploy/deploy.sh mac             — игра для Mac: build/mac/CivCity-mac.zip → /download/ и /game/mac.json
#                                           (в «всё» не входит; страница https://civcity.ru/mac/ — часть сайта, site)
#   bash deploy/deploy.sh caddy           — только Caddyfile (проверить и перечитать Caddy, сервер аккаунтов не трогать)
#   bash deploy/deploy.sh setup           — сначала первая настройка сервера (пользователь, папки, служба), потом всё
#   bash deploy/deploy.sh check           — всё подготовить и проверить у себя, на сервер ничего не отправлять
#   bash deploy/deploy.sh rollback N      — вернуть на сайт игру сборки N (из пяти последних выложенных)
# Перед выкладкой: bash tools/build_game.sh (игра → build/game), bash deploy/build_launcher.sh (установщик),
# bash tools/build_game.sh mac (игра для Mac → build/mac),
# сайт — в папке site/. По шагам — deploy/RELEASE.md. Ключ — ~/.ssh/civcity_ed25519; CIVCITY_HOST — другой сервер.
#
# Что где на сервере:
#   /srv/civcity/www/              сайт (папка site/): собирается рядом (www.new) и встаёт на место целиком
#   /srv/civcity/www/download/     установщики (переезжают в новую www); CivCity-setup.exe — из desktop/dist
#   /srv/civcity/www/game-manifest.json  заглушка для лаунчеров 0.9.x — они видят «Вышла новая версия, скачайте»
#   /srv/civcity/game/             игра для лаунчера, https://civcity.ru/game/ (см. Caddyfile):
#       manifest.json — опись, подписанная ключом владельца (secrets/, см. deploy/game_manifest.js); ставится
#                       последней, одним переименованием — лаунчеры видят либо старую, либо новую,
#       f/<sha256>, f/<zsha>.zst — файлы и сжатые копии по содержимому (заливаются только новые; перед заменой
#                       описи все нужные ей файлы сверяются по sha256),
#       releases/<сборка>.json — описи пяти последних сборок (для отката); ненужные им файлы удаляются
#       mac.json — сборка для Mac: {build, min, url, size, sha256, version}. Игра на Mac читает его при запуске
#                       (scripts/mac_update.gd): её сборка меньше min — окно «скачайте новую версию», играть нельзя;
#                       меньше build — тихая строка в меню. min = build (каждый выпуск обязателен), иначе MAC_MIN=N
#   /srv/civcity/www/download/CivCity-mac.zip, CivCity-mac-<сборка>.zip — архив для Mac (три последние сборки;
#                       в mac.json — адрес с номером: кэш браузера не подсунет прежний архив)
#   /srv/civcity/server/           сервер аккаунтов (служба civcity), его база — /srv/civcity/data
#   /srv/civcity/incoming/         то, что заливается сейчас (снаружи не видно)
# Для проверки самой выкладки без сервера: CIVCITY_SSH — своя команда вместо ssh, CIVCITY_REMOTE_ROOT — своя папка
# вместо /srv/civcity, CIVCITY_SITE — свой адрес сайта для проверки в конце, CIVCITY_GAME_DIR и CIVCITY_SITE_DIR —
# другие папки игры и сайта (обычно build/game и site).
set -euo pipefail
cd "$(dirname "$0")/.."
HOST=${CIVCITY_HOST:-root@159.194.249.20}
KEY="$HOME/.ssh/civcity_ed25519"
SSH=${CIVCITY_SSH:-ssh -i $KEY -o BatchMode=yes $HOST}
R=${CIVCITY_REMOTE_ROOT:-/srv/civcity}
SITE=${CIVCITY_SITE:-https://civcity.ru}
GAME_DIR=${CIVCITY_GAME_DIR:-build/game}
MAC_DIR=${CIVCITY_MAC_DIR:-build/mac}
SITE_DIR=${CIVCITY_SITE_DIR:-site}
STAGE=.work/deploy
KEEP=5
die() { echo "ОШИБКА: $*" >&2; exit 1; }
mb() { awk -v b="$1" 'BEGIN { printf "%.1f МБ", b / 1048576 }'; }
# run [аргументы] <<'EOF' … EOF — выполнить скрипт на сервере ($1 в нём — корень /srv/civcity, дальше — аргументы)
run() { $SSH bash -s -- "$R" "$@"; }
# up ИМЯ < файл — залить в $R/incoming/ИМЯ
up() { $SSH "cat > '$R/incoming/$1'"; }

SETUP=0; CHECK=0; PARTS=()
while [ $# -gt 0 ]; do
  case "$1" in
    setup) SETUP=1 ;;
    check) CHECK=1 ;;
    site|game|installer|server|mac|caddy) PARTS+=("$1") ;;
    rollback)
      N=${2:-}
      [[ "$N" =~ ^[0-9]+$ ]] || die "rollback: укажите номер сборки, например: bash deploy/deploy.sh rollback 12"
      # Лаунчер не ставит сборку старше установленной, если в подписанной описи нет "rollback": true, — поэтому
      # прежнюю опись берём с сервера, проверяем её подпись и подписываем заново у себя (ключ на сервер не попадает)
      RB="$STAGE/rollback"
      rm -rf "$RB"; mkdir -p "$RB"
      run "$N" > "$RB/old.json" <<'EOF' || die "откат не получился"
cd "$1/game" || exit 1
mkdir -p "$1/incoming"
[ -f "releases/$2.json" ] || { echo "Сборки $2 на сервере нет. Есть: $(ls releases | sed 's/\.json$//' | sort -n | tr '\n' ' ')" >&2; exit 1; }
cat "releases/$2.json"
EOF
      node deploy/game_manifest.js --rollback "$RB/old.json" "$RB" || die "опись отката не получилась"
      tar -cf - -C "$RB" manifest.json blobs.txt | up rollback.tar
      run "$N" <<'EOF' || die "откат не получился"
set -e
M="$1/incoming/rollback"
rm -rf "$M"; mkdir -p "$M"
tar -xf "$1/incoming/rollback.tar" -C "$M"
cd "$1/game"
while read -r h p; do [ -e "$p" ] || { echo "Файлы сборки $2 уже удалены — откатить нельзя"; exit 1; }; done < "$M/blobs.txt"
sha256sum -c --quiet "$M/blobs.txt" || { echo "файлы сборки $2 на сервере повреждены — откатить нельзя"; exit 1; }
chmod 644 "$M/manifest.json"
mv -f "$M/manifest.json" manifest.json
rm -rf "$M" "$1/incoming/rollback.tar"
echo "Игра на сайте — сборка $2. Лаунчеры поставят её при следующем «Играть»."
EOF
      exit 0 ;;
    *) die "не знаю «$1». Можно: site, game, installer, server, mac, caddy, setup, check, rollback N" ;;
  esac
  shift
done
[ ${#PARTS[@]} -eq 0 ] && PARTS=(site game installer server)
has() { [[ " ${PARTS[*]} " == *" $1 "* ]]; }
mkdir -p "$STAGE"

# ---------- 1. подготовка у себя ----------

VER=$(node -p "require('./desktop/package.json').version")
SETUP_EXE=desktop/dist/CivCity-$VER-setup.exe
if has installer; then
  [ -f "$SETUP_EXE" ] || die "нет установщика $SETUP_EXE — соберите: bash deploy/build_launcher.sh"
fi
if has game; then
  echo "== опись игры ($GAME_DIR)"
  node deploy/game_manifest.js "$GAME_DIR" "$STAGE" || die "опись игры не получилась"
  BUILD=$(tr -d '\r\n' < "$STAGE/game/build.txt")
fi
if has mac; then
  MZIP=$MAC_DIR/CivCity-mac.zip
  [ -f "$MZIP" ] && [ -f "$MAC_DIR/version.json" ] || die "нет $MZIP — соберите: bash tools/build_game.sh mac"
  echo "== игра для Mac ($MZIP)"
  python -I deploy/mac_zip_check.py "$MZIP" || die "архив для Mac неправильный — не выкладываю"
  MBUILD=$(python -I -c "import json,sys;print(int(json.load(open(sys.argv[1]))['build']))" "$MAC_DIR/version.json") || die "$MAC_DIR/version.json не читается"
  MVER=$(python -I -c "import json,sys;print(json.load(open(sys.argv[1])).get('version',''))" "$MAC_DIR/version.json")
  MMIN=${MAC_MIN:-$MBUILD}
  [[ "$MMIN" =~ ^[0-9]+$ ]] && [ "$MMIN" -le "$MBUILD" ] || die "MAC_MIN=$MMIN: нужен номер сборки не больше $MBUILD"
  MSIZE=$(stat -c %s "$MZIP")
  MSUM=$(sha256sum "$MZIP" | cut -d' ' -f1)
  MURL="$SITE/download/CivCity-mac-$MBUILD.zip"
  printf '{"build": %d, "min": %d, "url": "%s", "size": %d, "sha256": "%s", "version": "%s"}\n' \
    "$MBUILD" "$MMIN" "$MURL" "$MSIZE" "$MSUM" "$MVER" > "$STAGE/mac.json"
  echo "   сборка $MBUILD, обязательна для всех ниже $MMIN, $(mb "$MSIZE")"
fi
if has site; then
  [ -f "$SITE_DIR/index.html" ] || die "нет сайта: $SITE_DIR/index.html"
  # заглушка для лаунчеров 0.9.x (её же пишет game_manifest.js; здесь — если выкладываем сайт без игры)
  [ -f "$STAGE/game-manifest.json" ] || printf '{"version":"100000","shell":"%s","files":{}}\n' "$VER" > "$STAGE/game-manifest.json"
  # список файлов сайта с sha256 (как у sha256sum) — чтобы залить только изменившиеся
  node -e '
    const fs = require("fs"), path = require("path"), crypto = require("crypto");
    const root = process.argv[1], out = [];
    const walk = rel => { for (const e of fs.readdirSync(path.join(root, rel), { withFileTypes: true })) {
      const r = rel ? rel + "/" + e.name : e.name;
      if (e.isDirectory()) walk(r);
      else if (e.isFile()) out.push(crypto.createHash("sha256").update(fs.readFileSync(path.join(root, r))).digest("hex") + "  " + r);
    } };
    walk("");
    const bad = out.filter(l => /[\\\n]/.test(l) || l.slice(66).startsWith("download/") || l.slice(66) === "game-manifest.json");
    if (bad.length) { console.error("в site/ неподходящие имена (или download/, game-manifest.json — их делает выкладка):\n" + bad.join("\n")); process.exit(1); }
    fs.writeFileSync(process.argv[2], out.sort().join("\n") + "\n");
  ' "$SITE_DIR" "$STAGE/site.sha" || die "$SITE_DIR/ не подходит"
  echo "== сайт: $(wc -l < "$STAGE/site.sha") файлов, $(du -sh "$SITE_DIR" | cut -f1)"
fi

if [ $CHECK -eq 1 ]; then
  echo
  echo "Проверка у себя закончена, на сервер ничего не отправлено. Будет выложено: ${PARTS[*]}"
  if has game; then echo "  игра: сборка $BUILD → $STAGE/game (проверить лаунчером — см. deploy/RELEASE.md)"; fi
  if has installer; then echo "  установщик: $SETUP_EXE ($(mb "$(stat -c %s "$SETUP_EXE")"))"; fi
  if has mac; then echo "  Mac: $MZIP → /download/CivCity-mac.zip и CivCity-mac-$MBUILD.zip; /game/mac.json: $(cat "$STAGE/mac.json")"; fi
  exit 0
fi

# ---------- 2. первая настройка сервера ----------

if [ $SETUP -eq 1 ]; then
  echo "== первая настройка сервера"
  run <<'EOF'
set -e
id civcity >/dev/null 2>&1 || useradd --system --home "$1" --shell /usr/sbin/nologin civcity
mkdir -p "$1/www" "$1/server" "$1/data" "$1/backups"
chown -R civcity:civcity "$1/data"
[ -f /etc/civcity.env ] || printf "PORT=3000\nSITE_URL=https://civcity.ru\nORIGINS=https://civcity.ru,https://www.civcity.ru\nSMTP_HOST=\nSMTP_PORT=465\nSMTP_USER=\nSMTP_PASS=\nMAIL_FROM=\n" > /etc/civcity.env
chmod 600 /etc/civcity.env
EOF
fi

run <<'EOF'
mkdir -p "$1/incoming" "$1/game/f" "$1/game/releases"
EOF

# ---------- 3. игра для лаунчера ----------

if has game; then
  echo "== игра: сборка $BUILD"
  # что уже лежит на сервере: имя и размер (файл того же имени, но другого размера — испорчен, заливаем заново)
  have=$(run <<'EOF'
cd "$1/game/f" && find . -maxdepth 1 -type f -printf '%f %s\n'
EOF
)
  : > "$STAGE/game/upload.txt"
  while read -r h p; do
    grep -qxF "${p#f/} $(stat -c %s "$STAGE/game/$p")" <<< "$have" || echo "$h  $p" >> "$STAGE/game/upload.txt"
  done < "$STAGE/game/blobs.txt"
  if [ -s "$STAGE/game/upload.txt" ]; then
    bytes=0
    while read -r h p; do bytes=$((bytes + $(stat -c %s "$STAGE/game/$p"))); done < "$STAGE/game/upload.txt"
    echo "   заливаю новые файлы: $(wc -l < "$STAGE/game/upload.txt") шт., $(mb $bytes)"
    tar -cf - -C "$STAGE/game" upload.txt $(awk '{print $2}' "$STAGE/game/upload.txt") | up game.tar
    run <<'EOF'
set -e
I="$1/incoming/game"
rm -rf "$I"; mkdir -p "$I"
tar -xf "$1/incoming/game.tar" -C "$I"
cd "$I"
sha256sum -c --quiet upload.txt || { echo "файлы игры пришли повреждёнными"; exit 1; }
chmod 644 f/*
mv -f f/* "$1/game/f/"
cd /; rm -rf "$I" "$1/incoming/game.tar"
EOF
  else
    echo "   все файлы уже на сервере"
  fi
  # опись — последней: сначала проверить, что все её файлы на месте, потом одним переименованием
  tar -cf - -C "$STAGE/game" manifest.json blobs.txt | up meta.tar
  run "$BUILD" "$KEEP" <<'EOF'
set -e
M="$1/incoming/meta"
rm -rf "$M"; mkdir -p "$M"
tar -xf "$1/incoming/meta.tar" -C "$M"
cd "$1/game"
while read -r h p; do [ -e "$p" ] || { echo "на сервере нет $p — опись не меняю"; exit 1; }; done < "$M/blobs.txt"
# и что они те самые (по sha256), а не испорченные: иначе все лаунчеры упрутся в «файл пришёл повреждённым».
# Испорченные удаляем — следующая выкладка зальёт их заново
if ! sha256sum -c --quiet "$M/blobs.txt" > "$M/bad.txt" 2>&1; then
  echo "файлы игры на сервере не сходятся с описью — опись не меняю (испорченные удалены, выложите ещё раз):"
  cat "$M/bad.txt"
  sed -n 's/: FAILED.*$//p' "$M/bad.txt" | grep '^f/' | while IFS= read -r b; do rm -f -- "$b"; done
  exit 1
fi
cp "$M/manifest.json" "releases/$2.json"
chmod 644 "$M/manifest.json" "releases/$2.json"
mv -f "$M/manifest.json" manifest.json
rm -rf "$M" "$1/incoming/meta.tar"
# чистка: описи пяти последних сборок и только нужные им файлы
ls -1 releases/*.json | sort -t/ -k2 -n | head -n -"$3" | xargs -r rm -f
grep -oh '[0-9a-f]\{64\}' manifest.json releases/*.json | sort -u > "$1/incoming/keep.txt"
for f in f/*; do n=${f#f/}; n=${n%.zst}; grep -qxF "$n" "$1/incoming/keep.txt" || rm -f "$f"; done
rm -f "$1/incoming/keep.txt"
echo "   на сайте игра сборки $2 ($(du -sh f | cut -f1) файлов игры на сервере)"
EOF
fi

# ---------- 4. установщик ----------

if has installer; then
  echo "== установщик $VER"
  sum=$(sha256sum "$SETUP_EXE" | cut -d' ' -f1)
  old=$(run <<'EOF'
sha256sum "$1/www/download/CivCity-setup.exe" 2>/dev/null | cut -d" " -f1 || true
EOF
)
  if [ "$sum" = "$old" ]; then
    echo "   на сервере тот же"
  else
    echo "   заливаю $(mb "$(stat -c %s "$SETUP_EXE")")…"
    up CivCity-setup.exe.part < "$SETUP_EXE"
    run "$sum" "$VER" <<'EOF'
set -e
cd "$1/incoming"
echo "$2  CivCity-setup.exe.part" | sha256sum -c --quiet || { echo "установщик пришёл повреждённым"; exit 1; }
chmod 644 CivCity-setup.exe.part
mkdir -p "$1/www/download"
mv -f CivCity-setup.exe.part "$1/www/download/CivCity-setup.exe"
ln -f "$1/www/download/CivCity-setup.exe" "$1/www/download/CivCity-$3-setup.exe"
EOF
  fi
fi

# ---------- 4б. игра для Mac ----------

if has mac; then
  echo "== игра для Mac: сборка $MBUILD"
  # сначала архив (под номером сборки и под постоянным именем для страницы /mac/), потом mac.json — игры узнают о
  # новой сборке, только когда её уже можно скачать
  old=$(run "$MBUILD" <<'EOF'
sha256sum "$1/www/download/CivCity-mac-$2.zip" 2>/dev/null | cut -d" " -f1 || true
EOF
)
  if [ "$MSUM" = "$old" ]; then
    echo "   архив этой сборки уже на сервере"
  else
    echo "   заливаю $(mb "$MSIZE")…"
    up CivCity-mac.zip.part < "$MZIP"
  fi
  run "$MSUM" "$MBUILD" "$([ "$MSUM" = "$old" ] && echo have || echo new)" <<'EOF'
set -e
D="$1/www/download"
mkdir -p "$D"
if [ "$4" = new ]; then
  cd "$1/incoming"
  echo "$2  CivCity-mac.zip.part" | sha256sum -c --quiet || { echo "архив для Mac пришёл повреждённым"; exit 1; }
  chmod 644 CivCity-mac.zip.part
  mv -f CivCity-mac.zip.part "$D/CivCity-mac-$3.zip"
fi
rm -f "$D/CivCity-mac.zip.new"
if ! [ "$D/CivCity-mac-$3.zip" -ef "$D/CivCity-mac.zip" ]; then
  # постоянное имя (кнопка на странице /mac/) — та же сборка, одним переименованием
  ln -f "$D/CivCity-mac-$3.zip" "$D/CivCity-mac.zip.new"
  mv -f "$D/CivCity-mac.zip.new" "$D/CivCity-mac.zip"
fi
# три последние сборки (кто-то как раз скачивает по ссылке из mac.json), остальные — убрать
ls -1 "$D"/CivCity-mac-*.zip 2>/dev/null | sed -n 's#.*/CivCity-mac-\([0-9]*\)\.zip$#\1#p' | sort -n | head -n -3 | while read -r n; do rm -f "$D/CivCity-mac-$n.zip"; done
EOF
  up mac.json < "$STAGE/mac.json"
  run <<'EOF'
set -e
chmod 644 "$1/incoming/mac.json"
mv -f "$1/incoming/mac.json" "$1/game/mac.json"
EOF
  echo "   /game/mac.json: сборка $MBUILD, обязательна с $MMIN"
fi

# ---------- 5. сайт ----------

if has site; then
  echo "== сайт"
  run <<'EOF' | sed -E 's#^([0-9a-f]{64}) [ *]\./#\1  #' > "$STAGE/site.remote"
cd "$1/www" 2>/dev/null && find . -path ./download -prune -o -type f -print0 | xargs -0 -r sha256sum || true
EOF
  grep -vxFf "$STAGE/site.remote" "$STAGE/site.sha" | cut -c67- > "$STAGE/site.changed" || true
  cut -c67- "$STAGE/site.sha" > "$STAGE/site.files"
  echo "   новых и изменившихся файлов: $(wc -l < "$STAGE/site.changed")"
  tar -czf - -C "$SITE_DIR" -T "$(pwd)/$STAGE/site.changed" | up site.tgz
  tar -cf - -C "$STAGE" site.files site.changed game-manifest.json | up site-meta.tar
  run <<'EOF'
set -e
W="$1/www"; I="$1/incoming"; M="$I/site-meta"
rm -rf "$M" "$W.new"; mkdir -p "$M"
tar -xf "$I/site-meta.tar" -C "$M"
# новая www — жёсткими ссылками на старую (мгновенно, без копирования); download/ переезжает как есть
if [ -d "$W" ]; then cp -al "$W" "$W.new"; else mkdir -p "$W.new"; fi
cd "$W.new"
# убрать то, чего в новом сайте нет (старую браузерную игру и т. п.), и изменившееся (новое придёт из архива)
find . -path ./download -prune -o -type f -print | sed 's#^\./##' | grep -vxFf "$M/site.files" | while IFS= read -r f; do rm -f -- "$f"; done
while IFS= read -r f; do rm -f -- "$f"; done < "$M/site.changed"
tar -xzf "$I/site.tgz" -C "$W.new"
find . -path ./download -prune -o -type d -empty -print | sort -r | while IFS= read -r d; do rmdir -- "$d" 2>/dev/null || true; done
mkdir -p download
cp "$M/game-manifest.json" game-manifest.json
chmod -R a+rX "$W.new"
cd /
rm -rf "$W.old"
if [ -d "$W" ]; then mv "$W" "$W.old"; fi
mv "$W.new" "$W"
rm -rf "$W.old" "$I/site.tgz" "$I/site-meta.tar" "$M"
echo "   сайт на месте"
EOF
fi

# ---------- 6. сервер аккаунтов и Caddy ----------

if has server; then
  echo "== сервер аккаунтов и Caddy"
  # зависимости сервера (nodemailer) едут вместе с ним: на сервере npm нет, без них служба падала бы по кругу
  [ -f server/node_modules/nodemailer/package.json ] || die "нет server/node_modules — выполните: (cd server && npm ci --omit=dev)"
  tar -czf - -C server --exclude=./data --exclude='*.db' --exclude='*.db-*' --exclude='*.log' \
    --exclude=./test.js --exclude=./test_pvp.js --exclude=./test_sim.js . | up server.tgz
  up civcity.service < deploy/civcity.service
  up Caddyfile < deploy/Caddyfile
  run <<'EOF'
set -e
I="$1/incoming"
tar -xzf "$I/server.tgz" -C "$1/server" --no-same-owner
if ! caddy validate --config "$I/Caddyfile" --adapter caddyfile >/dev/null 2>&1; then
  echo "Caddyfile с ошибкой — оставляю прежний:"; caddy validate --config "$I/Caddyfile" --adapter caddyfile 2>&1 | tail -5; exit 1
fi
mv -f "$I/civcity.service" /etc/systemd/system/civcity.service
mv -f "$I/Caddyfile" /etc/caddy/Caddyfile
rm -f "$I/server.tgz" /etc/systemd/system/caddy.service.d/site.conf
# журналы сервера (ошибки, иногда с почтой или IP) — не дольше 30 дней: так обещает политика конфиденциальности
J=/etc/systemd/journald.conf.d/civcity.conf
if ! grep -qs '^MaxRetentionSec=30day' "$J"; then
  mkdir -p "$(dirname "$J")"
  printf '[Journal]\nMaxRetentionSec=30day\n' > "$J"
  systemctl restart systemd-journald
fi
systemctl daemon-reload
systemctl enable --now civcity >/dev/null 2>&1
systemctl restart civcity
systemctl reload caddy || systemctl restart caddy
# служба поднимается сама (Restart=always, через 3 с), поэтому «active» сразу после старта ничего не значит:
# ждём, пока сервер ответит на /api/health, и проверяем, что он потом не падал (NRestarts не вырос)
P=$(sed -n 's/^PORT=//p' /etc/civcity.env 2>/dev/null | tail -1); P=${P:-3000}
health() {
  if command -v curl >/dev/null 2>&1; then curl -fsS --max-time 3 "http://127.0.0.1:$P/api/health" >/dev/null 2>&1
  else node -e "fetch('http://127.0.0.1:$P/api/health',{signal:AbortSignal.timeout(3000)}).then(r=>process.exit(r.ok?0:1),()=>process.exit(1))"; fi
}
up=0
for i in $(seq 1 15); do
  if health && systemctl is-active --quiet civcity caddy; then up=1; break; fi
  sleep 1
done
r0=$(systemctl show -p NRestarts --value civcity 2>/dev/null || echo 0)
sleep 4      # дольше RestartSec: упади сервер на первых запросах или при переделке базы — это будет видно
r1=$(systemctl show -p NRestarts --value civcity 2>/dev/null || echo 0)
systemctl is-active civcity caddy || true
if [ $up -ne 1 ] || [ "$r1" != "$r0" ] || ! health; then
  echo "сервер аккаунтов не отвечает или перезапускается (перезапусков было $r0, стало $r1):"
  journalctl -u civcity -n 20 --no-pager || true
  exit 1
fi
echo "   сервер аккаунтов отвечает"
EOF
fi

# ---------- 6б. только Caddy (без перезапуска сервера аккаунтов) ----------

if has caddy && ! has server; then
  echo "== Caddy"
  up Caddyfile < deploy/Caddyfile
  run <<'EOF'
set -e
I="$1/incoming"
if ! caddy validate --config "$I/Caddyfile" --adapter caddyfile >/dev/null 2>&1; then
  echo "Caddyfile с ошибкой — оставляю прежний:"; caddy validate --config "$I/Caddyfile" --adapter caddyfile 2>&1 | tail -5; exit 1
fi
mv -f "$I/Caddyfile" /etc/caddy/Caddyfile
systemctl reload caddy || systemctl restart caddy
systemctl is-active --quiet caddy || { echo "Caddy не поднялся"; exit 1; }
echo "   Caddy перечитал настройки"
EOF
fi

# ---------- 7. проверка снаружи ----------

echo "== проверка $SITE"
ok=1
if curl -fsS --max-time 15 "$SITE/api/health" >/dev/null; then echo "   сервер аккаунтов отвечает"; else echo "   ВНИМАНИЕ: $SITE/api/health не отвечает"; ok=0; fi
if has game; then
  got=$(curl -fsS --max-time 15 "$SITE/game/manifest.json" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{console.log(JSON.parse(JSON.parse(s).manifest).build)}catch(e){console.log("?")}})' || true)
  if [ "$got" = "$BUILD" ]; then echo "   опись игры: сборка $got"; else echo "   ВНИМАНИЕ: $SITE/game/manifest.json даёт сборку «$got», ждали $BUILD"; ok=0; fi
fi
if has installer; then
  len=$(curl -fsSI --max-time 15 "$SITE/download/CivCity-setup.exe" | tr -d '\r' | awk 'tolower($1)=="content-length:"{print $2}' || true)
  if [ "$len" = "$(stat -c %s "$SETUP_EXE")" ]; then echo "   установщик скачивается ($(mb "$len"))"; else echo "   ВНИМАНИЕ: установщик на сайте не того размера («$len»)"; ok=0; fi
fi
if has site; then
  if curl -fsS --max-time 15 "$SITE/game-manifest.json" | grep -q "\"shell\":\"$VER\""; then echo "   старые лаунчеры увидят «Вышла новая версия» ($VER)"; else echo "   ВНИМАНИЕ: $SITE/game-manifest.json не тот"; ok=0; fi
fi
if has mac; then
  got=$(curl -fsS --max-time 15 "$SITE/game/mac.json" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const j=JSON.parse(s);console.log(j.build+" "+j.min+" "+j.url)}catch(e){console.log("?")}})' || true)
  if [ "$got" = "$MBUILD $MMIN $MURL" ]; then echo "   /game/mac.json: сборка $MBUILD, обязательна с $MMIN"; else echo "   ВНИМАНИЕ: $SITE/game/mac.json даёт «$got», ждали «$MBUILD $MMIN $MURL»"; ok=0; fi
  for u in "$MURL" "$SITE/download/CivCity-mac.zip"; do
    hdr=$(curl -fsSI --max-time 15 "$u" | tr -d '\r' || true)
    len=$(awk 'tolower($1)=="content-length:"{print $2}' <<< "$hdr")
    typ=$(awk 'tolower($1)=="content-type:"{print $2}' <<< "$hdr")
    if [ "$len" = "$MSIZE" ] && [ "$typ" = "application/zip" ]; then echo "   архив для Mac скачивается: ${u#$SITE} ($(mb "$len"), $typ)"
    else echo "   ВНИМАНИЕ: ${u#$SITE}: размер «$len» (ждали $MSIZE), тип «$typ» (ждали application/zip; тип задаёт Caddyfile — bash deploy/deploy.sh caddy)"; ok=0; fi
  done
fi
# код выхода: 0 — выложено и проверено; 1 — выкладка оборвалась (die); 2 — файлы ушли, но проверка снаружи не прошла
if [ $ok -eq 1 ]; then echo "выложено"; else echo "выложено, но проверка нашла неполадки (см. выше)"; exit 2; fi
