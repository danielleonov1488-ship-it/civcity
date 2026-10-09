#!/usr/bin/env bash
# Выкладка CivCity на сервер: игра (статические файлы), сервер аккаунтов, настройки Caddy.
#   bash deploy/deploy.sh            — игра и сервер
#   bash deploy/deploy.sh setup      — первая настройка сервера (пользователь, папки, служба), потом выкладка
# Ключ доступа — ~/.ssh/civcity_ed25519. Старые файлы игры на сервере заменяются целиком.
set -euo pipefail
cd "$(dirname "$0")/.."
HOST=${CIVCITY_HOST:-root@159.194.249.20}
SSH="ssh -i $HOME/.ssh/civcity_ed25519 -o BatchMode=yes $HOST"

if [ "${1:-}" = "setup" ]; then
  $SSH 'set -e
    id civcity >/dev/null 2>&1 || useradd --system --home /srv/civcity --shell /usr/sbin/nologin civcity
    mkdir -p /srv/civcity/www /srv/civcity/server /srv/civcity/data /srv/civcity/backups
    chown -R civcity:civcity /srv/civcity/data
    [ -f /etc/civcity.env ] || printf "PORT=3000\nSITE_URL=http://159.194.249.20\nORIGINS=https://civcity.ru,https://www.civcity.ru,https://danielleonov1488-ship-it.github.io\nSMTP_HOST=\nSMTP_PORT=465\nSMTP_USER=\nSMTP_PASS=\nMAIL_FROM=\n" > /etc/civcity.env
    chmod 600 /etc/civcity.env'
fi

# игра: страница, стили, скрипты, библиотеки, готовые модели (без сырых наборов)
# и опись файлов с контрольными суммами — по ней программа для ПК обновляется сама
node deploy/manifest.js . game-manifest.json
tar -czf - --exclude=assets/incoming index.html style.css game-manifest.json js vendor assets \
  | $SSH 'set -e; rm -rf /srv/civcity/www.new; mkdir -p /srv/civcity/www.new; tar -xzf - -C /srv/civcity/www.new
    [ -d /srv/civcity/www/download ] && cp -r /srv/civcity/www/download /srv/civcity/www.new/ || true
    rm -rf /srv/civcity/www.old; mv /srv/civcity/www /srv/civcity/www.old; mv /srv/civcity/www.new /srv/civcity/www; rm -rf /srv/civcity/www.old'

# сервер аккаунтов
tar -czf - -C server index.js mail.js setmail.js testmail.js package.json node_modules \
  | $SSH 'set -e; tar -xzf - -C /srv/civcity/server'
scp -q -i "$HOME/.ssh/civcity_ed25519" deploy/civcity.service "$HOST:/etc/systemd/system/civcity.service"
scp -q -i "$HOME/.ssh/civcity_ed25519" deploy/Caddyfile "$HOST:/etc/caddy/Caddyfile"
$SSH 'set -e
  rm -f /etc/systemd/system/caddy.service.d/site.conf
  caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile >/dev/null 2>&1 || { echo "Caddyfile с ошибкой"; exit 1; }
  systemctl daemon-reload; systemctl enable --now civcity >/dev/null 2>&1; systemctl restart civcity
  systemctl reload caddy || systemctl restart caddy
  sleep 1; systemctl is-active civcity caddy'
echo "выложено"
