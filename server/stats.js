'use strict';
// Счётчик посещений без слежки: только общие числа за день (сколько раз открыли сайт, скачали игру,
// запустили лаунчер, проверили обновление игры) и сколько было разных людей.
// Caddy шлёт сюда строки своего журнала запросов по 127.0.0.1:3001 (на диск журнал не пишется).
// «Разных людей» считаем по коду из адреса подключения и строки браузера, смешанных со случайной солью дня:
// соль живёт только в памяти и меняется в полночь по Москве, в базу попадают одни итоговые числа.
const net = require('net');
const crypto = require('crypto');

const KEYS = [
  ['site', p => p === '/' || p === '/index.html'],
  ['download_win', p => p.startsWith('/download/CivCity-setup')],
  ['download_mac', p => p.startsWith('/download/CivCity-mac')],
  ['launcher', p => p === '/api/launcher'],
  ['game_check', p => p === '/game/manifest.json'],
  ['mac_check', p => p === '/game/mac.json'],
];
const BOT = /bot|crawl|spider|slurp|preview|monitor|curl|wget|python|scan/i;

function header(h, name) {
  if (!h) return '';
  const v = h[name] || h[name.toLowerCase()];
  return Array.isArray(v) ? String(v[0] || '') : String(v || '');
}

function mskDay(ts) {
  return new Date(Math.round(ts * 1000) + 3 * 3600 * 1000).toISOString().slice(0, 10);
}

function install({ db, port = 3001, host = '127.0.0.1', listen = true }) {
  db.exec(`CREATE TABLE IF NOT EXISTS stats_daily (
    day TEXT NOT NULL,
    key TEXT NOT NULL,
    total INTEGER NOT NULL,
    uniq INTEGER NOT NULL,
    PRIMARY KEY (day, key)
  )`);
  const upsert = db.prepare(`INSERT INTO stats_daily (day, key, total, uniq) VALUES (?, ?, ?, ?)
    ON CONFLICT (day, key) DO UPDATE SET total = total + excluded.total, uniq = uniq + excluded.uniq`);
  let day = '';
  let salt = null;
  let seen = new Map();

  function count(entry) {
    const req = entry && entry.request;
    if (!req || req.method !== 'GET') return;
    const status = Number(entry.status) || 0;
    if (status < 200 || status >= 400) return;
    const uri = String(req.uri || '').split('?')[0];
    const key = (KEYS.find(([, test]) => test(uri)) || [])[0];
    if (!key) return;
    const ua = header(req.headers, 'User-Agent');
    if (BOT.test(ua) && key === 'site') return;
    const d = mskDay(Number(entry.ts) || Date.now() / 1000);
    if (d !== day) {
      day = d;
      salt = crypto.randomBytes(16);
      seen = new Map();
    }
    // Загрузка по частям (докачка) — один раз: целиком (200) или первая часть (Range с нулевого байта)
    const range = header(req.headers, 'Range');
    const whole = status === 200 || (status === 206 && /^bytes=0-/.test(range));
    const ip = String(req.client_ip || req.remote_ip || '');
    const code = crypto.createHash('sha256').update(salt).update(ip + '|' + ua).digest('hex').slice(0, 16);
    let set = seen.get(key);
    if (!set) seen.set(key, set = new Set());
    const fresh = !set.has(code);
    set.add(code);
    if (whole || fresh) upsert.run(day, key, whole ? 1 : 0, fresh ? 1 : 0);
  }

  function feed(text) {
    for (const line of text.split('\n')) {
      if (!line.trim()) continue;
      try { count(JSON.parse(line)); } catch (e) { /* чужая строка — пропускаем */ }
    }
  }

  if (listen) {
    const server = net.createServer(sock => {
      let buf = '';
      sock.setEncoding('utf8');
      sock.on('data', chunk => {
        buf += chunk;
        const cut = buf.lastIndexOf('\n');
        if (cut >= 0) {
          feed(buf.slice(0, cut));
          buf = buf.slice(cut + 1);
        }
        if (buf.length > 1e6) buf = '';
      });
      sock.on('error', () => {});
    });
    server.on('error', e => console.log('stats: ' + e.message));
    server.listen(port, host);
  }
  return { feed, count };
}

module.exports = { install, mskDay };
