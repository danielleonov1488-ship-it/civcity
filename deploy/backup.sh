#!/usr/bin/env bash
# Копия базы аккаунтов с сервера (аккаунты, облачные сохранения, бои с городами) — по просьбе владельца, вручную:
#   bash deploy/backup.sh          (или ярлык «Копия аккаунтов.bat»)
# На сервере: sqlite3 .backup — целая копия на ходу, сервер не останавливается → /srv/civcity/backups/civcity-<время>.db.gz
# У себя: та же копия → D:/CivCity/backups/civcity-<время>.db.gz (папка в git не попадает). Старые копии не удаляются.
set -euo pipefail
cd "$(dirname "$0")/.."
HOST=${CIVCITY_HOST:-root@141.133.188.72}
KEY=${CIVCITY_KEY:-secrets/civcity2_ed25519}
SSH="ssh -i $KEY -o BatchMode=yes -o UserKnownHostsFile=secrets/known_hosts $HOST"
TS=$(date +%Y%m%d-%H%M%S)
NAME=civcity-$TS.db.gz
OUT=backups
mkdir -p "$OUT"
echo "== копия базы на сервере"
SUM=$($SSH bash -s -- "$TS" <<'EOF'
set -e
B=/srv/civcity/backups; mkdir -p "$B"; chmod 700 "$B"
T="$B/civcity-$1.db"
sqlite3 /srv/civcity/data/civcity.db ".backup '$T'"
ok=$(sqlite3 "$T" "PRAGMA integrity_check;")
[ "$ok" = "ok" ] || { echo "копия повреждена: $ok" >&2; exit 1; }
n=$(sqlite3 "$T" "SELECT count(*) FROM users;" 2>/dev/null || echo "?")
gzip -9 "$T"; chmod 600 "$T.gz"
echo "$(sha256sum "$T.gz" | cut -d' ' -f1) $n"
EOF
)
read -r H USERS <<< "$SUM"
echo "   на сервере: /srv/civcity/backups/$NAME (аккаунтов: $USERS)"
echo "== скачиваю к себе"
$SSH "cat /srv/civcity/backups/$NAME" > "$OUT/$NAME.part"
[ "$(sha256sum "$OUT/$NAME.part" | cut -d' ' -f1)" = "$H" ] || { echo "ОШИБКА: копия пришла повреждённой ($OUT/$NAME.part)"; exit 1; }
mv "$OUT/$NAME.part" "$OUT/$NAME"
echo "готово: $(pwd -W 2>/dev/null || pwd)/$OUT/$NAME ($(du -h "$OUT/$NAME" | cut -f1), аккаунтов: $USERS)"
