'use strict';
/* Сайт CivCity у себя на компьютере — для проверки лаунчера и сайта перед выкладкой.
     node deploy/local_site.js [--port=8090] [--root=.work/deploy] [--site=site] [--throttle=КБ/с] [--api=http://127.0.0.1:3010]
   Раздаёт то же, что сервер: /game/… (опись и файлы игры из <root>/game, их готовит deploy/game_manifest.js),
   /game-manifest.json (заглушка для лаунчеров 0.9.x), всё остальное — из папки сайта (если задана).
   --api — пропускать /api/… к своему серверу аккаунтов (PORT=3010 DATA_DIR=… node server/index.js) и писать
   в журнал каждый запрос (с входом или без — сам токен не пишется): так видно, что игра получила вход от лаунчера.
   Умеет докачку (Range), как Caddy; --throttle — искусственно медленная раздача (проверить докачку и ход загрузки).
   Лаунчер на него: CIVCITY_UPDATE_URL=http://127.0.0.1:8090/ (сервер аккаунтов — отдельно, CIVCITY_API). */
const http = require('http');
const fs = require('fs');
const path = require('path');

const arg = (k, d) => { const a = process.argv.find(x => x.startsWith(`--${k}=`)); return a ? a.slice(k.length + 3) : d; };
const ROOT = path.join(__dirname, '..');
const PORT = +arg('port', 8090);
const DEPLOY = path.resolve(arg('root', path.join(ROOT, '.work', 'deploy')));
const SITE = arg('site', '') ? path.resolve(arg('site')) : '';
const THROTTLE = +arg('throttle', 0) * 1024;   // байт в секунду, 0 — без ограничения
const API = arg('api', '').replace(/\/$/, '');

const TYPES = { '.html': 'text/html; charset=utf-8', '.css': 'text/css', '.js': 'text/javascript', '.json': 'application/json', '.png': 'image/png', '.jpg': 'image/jpeg', '.webp': 'image/webp', '.svg': 'image/svg+xml', '.mp4': 'video/mp4', '.woff2': 'font/woff2', '.ico': 'image/x-icon',
  '.webm': 'video/webm', '.woff': 'font/woff', '.webmanifest': 'application/manifest+json', '.xml': 'application/xml', '.txt': 'text/plain; charset=utf-8' };

// /game/… — из папки игры; остальное — из папки сайта, а чего там нет — из папки игры (там лежит game-manifest.json)
function resolve(urlPath) {
  const p = decodeURIComponent(urlPath);
  const tries = p.startsWith('/game/') ? [[DEPLOY, p]] : [...(SITE ? [[SITE, p.endsWith('/') ? p + 'index.html' : p]] : []), [DEPLOY, p]];
  for (const [base, rel] of tries) {
    const file = path.normalize(path.join(base, rel));
    try { if (file.startsWith(base + path.sep) && fs.statSync(file).isFile()) return file; } catch (e) { /* нет такого */ }
  }
  return null;
}

function proxy(req, res, u) {
  const target = new URL(API + u.pathname + u.search);
  const up = http.request(target, { method: req.method, headers: { ...req.headers, host: target.host } }, r => {
    console.log(req.method, u.pathname + u.search, r.statusCode, req.headers.authorization ? 'с входом' : 'без входа', req.headers['user-agent'] || '');
    res.writeHead(r.statusCode, r.headers);
    r.pipe(res);
  });
  up.on('error', e => { console.log(req.method, u.pathname, 502, e.message); res.writeHead(502); res.end(); });
  req.pipe(up);
}

http.createServer((req, res) => {
  const u = new URL(req.url, 'http://x');
  if (API && u.pathname.startsWith('/api/')) { proxy(req, res, u); return; }
  const file = resolve(u.pathname);
  let st = null;
  try { st = file && fs.statSync(file); } catch (e) { st = null; }
  if (!st || !st.isFile()) { res.writeHead(404); res.end('not found'); console.log(req.method, u.pathname, 404); return; }
  const size = st.size;
  let start = 0, end = size - 1, code = 200;
  const m = /^bytes=(\d+)-(\d*)$/.exec(req.headers.range || '');
  if (m) {
    start = +m[1];
    end = m[2] ? Math.min(+m[2], size - 1) : size - 1;
    if (start >= size || start > end) { res.writeHead(416, { 'Content-Range': `bytes */${size}` }); res.end(); console.log(req.method, u.pathname, 416); return; }
    code = 206;
  }
  const headers = { 'Content-Type': TYPES[path.extname(file)] || 'application/octet-stream', 'Content-Length': end - start + 1, 'Accept-Ranges': 'bytes' };
  if (code === 206) headers['Content-Range'] = `bytes ${start}-${end}/${size}`;
  headers['Cache-Control'] = u.pathname.startsWith('/game/f/') ? 'public, max-age=31536000, immutable' : 'no-cache';
  res.writeHead(code, headers);
  console.log(req.method, u.pathname, code, code === 206 ? `${start}-${end}/${size}` : size);
  if (req.method === 'HEAD') { res.end(); return; }
  const stream = fs.createReadStream(file, { start, end, highWaterMark: 64 * 1024 });
  if (!THROTTLE) { stream.pipe(res); return; }
  stream.on('data', chunk => {
    stream.pause();
    res.write(chunk);
    setTimeout(() => stream.resume(), (chunk.length / THROTTLE) * 1000);
  });
  stream.on('end', () => res.end());
  res.on('close', () => stream.destroy());
}).listen(PORT, '127.0.0.1', () => console.log(`сайт CivCity у себя: http://127.0.0.1:${PORT}/  (игра — ${DEPLOY}${SITE ? `, сайт — ${SITE}` : ''}${THROTTLE ? `, ${THROTTLE / 1024} КБ/с` : ''})`));
