'use strict';
// Проверка сервера перед выкладкой: node server/test.js   (ничего не трогает, кроме своей папки данных)
// Старые адреса работают как раньше (ячейка web), ячейка rome2 новой игры: сжатие, конфликты, история,
// «уничтожить город», откат, пределы размера; переход со старой базы (без колонок game/zdata).
// Данные — в TEST_DATA_DIR (по умолчанию ../.work/srvtest), порт — TEST_PORT (3011).
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const zlib = require('zlib');
const { DatabaseSync } = require('node:sqlite');

const DATA = process.env.TEST_DATA_DIR || path.join(__dirname, '..', '.work', 'srvtest');
const PORT = +process.env.TEST_PORT || 3011;
const API = `http://127.0.0.1:${PORT}/api`;
let fails = 0;
const ok = (c, msg) => { console.log((c ? 'OK   ' : 'FAIL ') + msg); if (!c) fails++; };

function start() {
  return new Promise((resolve, reject) => {
    const p = spawn(process.execPath, ['--disable-warning=ExperimentalWarning', path.join(__dirname, 'index.js')], {
      env: { ...process.env, PORT: String(PORT), DATA_DIR: DATA, ORIGINS: '*', SMTP_HOST: '', SMTP_PASS: '' },
      stdio: ['ignore', 'pipe', 'pipe'] });
    let done = false;
    p.stdout.on('data', d => { if (!done && /server on/.test(String(d))) { done = true; resolve(p); } });
    p.stderr.on('data', d => process.stderr.write('[srv] ' + d));
    p.on('exit', c => { if (!done) reject(new Error('server exit ' + c)); });
  });
}
const stop = p => new Promise(r => { p.on('exit', r); p.kill(); });

async function call(method, p, body, token, opt = {}) {
  const headers = {};
  if (token) headers.Authorization = 'Bearer ' + token;
  let b;
  if (body !== undefined) {
    headers['Content-Type'] = 'application/json';
    b = typeof body === 'string' || Buffer.isBuffer(body) ? body : JSON.stringify(body);
    if (opt.gzip) { b = zlib.gzipSync(b); headers['Content-Encoding'] = 'gzip'; }
    if (opt.enc) headers['Content-Encoding'] = opt.enc;
  }
  const r = await fetch(API + p, { method, headers, body: b });
  let data = null;
  try { data = await r.json(); } catch (e) { /* */ }
  return { status: r.status, data };
}

// город новой игры, похожий на настоящий: постройки с клетками в base64 и изменения земли
function fakeCity(n, landKb) {
  const b = [];
  for (let i = 0; i < n; i++) b.push({ id: i + 1, type: 'house_pleb', tier: 1, x: 100 + i, z: 90, yaw: 0, variant: i % 6, color: i % 10, y: 1, pop: 4, families: [], host: -1, hire: -1, cells: crypto.randomBytes(300).toString('base64') });
  return JSON.stringify({ money: 5000, rp: 0, day: 3, level: 2, research: [], buildings: b, next_id: n + 1, land: { h: crypto.randomBytes(landKb * 768).toString('base64') }, hour: 9, version: 2 });
}

// старая база (как до ячеек): пользователь с паролем secret1 и 3 сохранения браузерной игры
function oldDb() {
  fs.rmSync(DATA, { recursive: true, force: true });
  fs.mkdirSync(DATA, { recursive: true });
  const db = new DatabaseSync(path.join(DATA, 'civcity.db'));
  db.exec(`CREATE TABLE users (id INTEGER PRIMARY KEY, email TEXT NOT NULL UNIQUE, pass TEXT NOT NULL, created INTEGER NOT NULL, last_seen INTEGER);
    CREATE TABLE sessions (hash TEXT PRIMARY KEY, user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE, created INTEGER NOT NULL, used INTEGER NOT NULL, agent TEXT);
    CREATE TABLE saves (id INTEGER PRIMARY KEY, user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE, created INTEGER NOT NULL, size INTEGER NOT NULL, data TEXT NOT NULL, meta TEXT);
    CREATE INDEX saves_user ON saves(user_id, id);
    CREATE TABLE resets (hash TEXT PRIMARY KEY, user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE, expires INTEGER NOT NULL);`);
  const salt = crypto.randomBytes(16);
  const h = crypto.scryptSync('secret1', salt, 32, { N: 16384, r: 8, p: 1, maxmem: 64 * 1024 * 1024 });
  db.prepare('INSERT INTO users (email, pass, created) VALUES (?, ?, ?)').run('old@test.ru', `s1$${salt.toString('base64')}$${h.toString('base64')}`, Date.now());
  for (let i = 1; i <= 3; i++) db.prepare('INSERT INTO saves (user_id, created, size, data, meta) VALUES (1, ?, 10, ?, ?)').run(Date.now() - (4 - i) * 1000, JSON.stringify({ web: i }), JSON.stringify({ city: 'Веб', pop: i }));
  db.close();
}

(async () => {
  oldDb();
  const srv = await start();
  let r;
  try {
    r = await call('POST', '/login', { email: 'Old@Test.ru', password: 'secret1' });
    ok(r.status === 200 && r.data.token, 'old database: old player logs in');
    const oldTok = r.data.token;
    r = await call('GET', '/health');
    ok(r.data.ok && r.data.games.includes('rome2'), 'health lists games');
    r = await call('GET', '/me', undefined, oldTok);
    ok(r.status === 200 && r.data.email === 'old@test.ru' && r.data.save && r.data.save.meta.pop === 3 && !('game' in r.data), 'migrated: old token + web save visible in /me');
    r = await call('GET', '/save', undefined, oldTok);
    ok(r.data.save && JSON.parse(r.data.save.data).web === 3 && !('game' in r.data), 'migrated: GET /save (web) unchanged');
    r = await call('GET', '/me?game=rome2', undefined, oldTok);
    ok(r.data.game === 'rome2' && r.data.save === null, 'rome2 slot empty for old user');
    r = await call('GET', '/save?game=rome2', undefined, oldTok);
    ok(r.data.game === 'rome2' && r.data.save === null, 'GET /save?game=rome2 empty');
    r = await call('GET', '/me?game=nope', undefined, oldTok);
    ok(r.status === 400, 'unknown game → 400');

    // новый игрок
    r = await call('POST', '/register', { email: 'new@test.ru', password: 'secret2' });
    const tok = r.data.token;
    ok(r.status === 200 && tok, 'register new');
    r = await call('POST', '/login', { email: 'NEW@test.ru', password: 'secret2' });
    ok(r.status === 200 && r.data.token && r.data.email === 'new@test.ru', 'login');
    r = await call('POST', '/login', { email: 'new@test.ru', password: 'wrong' });
    ok(r.status === 401, 'login wrong password → 401');

    // большой город новой игры, сжатый
    const demo = fakeCity(208, 600);       // ~0,8 МБ, как готовый городок
    const promo = fakeCity(654, 1950);     // ~2,5 МБ, как большая витрина
    r = await call('PUT', '/save?game=rome2', { data: demo, base: null, meta: { pop: 120, day: 7 } }, tok, { gzip: true });
    ok(r.status === 200 && r.data.id && r.data.game === 'rome2' && r.data.created, 'rome2 PUT gzip demo city (' + demo.length + ' chars)');
    const id1 = r.data.id;
    r = await call('GET', '/save?game=rome2', undefined, tok);
    ok(r.data.save && r.data.save.data === demo && r.data.save.id === id1, 'rome2 GET returns identical data');
    r = await call('GET', '/me?game=rome2', undefined, tok);
    ok(r.data.save && r.data.save.id === id1 && r.data.save.meta.pop === 120 && r.data.save.size === Buffer.byteLength(demo), 'rome2 /me info');
    r = await call('GET', '/me', undefined, tok);
    ok(r.data.save === null, 'web slot of new user still empty (isolation)');
    r = await call('PUT', '/save?game=rome2', { data: promo, base: id1, meta: { pop: 900 } }, tok);
    ok(r.status === 200, 'rome2 PUT plain promo city (' + promo.length + ' chars)');
    const id2 = r.data.id;
    // конфликт
    r = await call('PUT', '/save?game=rome2', { data: '{"a":1}', base: id1 }, tok, { gzip: true });
    ok(r.status === 409 && r.data.latest && r.data.latest.id === id2 && r.data.latest.meta.pop === 900, 'stale base → 409 with latest');
    r = await call('PUT', '/save?game=rome2', { data: '{"a":1}', base: id1, force: true }, tok, { gzip: true });
    ok(r.status === 200, 'force overrides 409');
    // плохие запросы
    r = await call('PUT', '/save?game=rome2', { data: '[1,2]', base: null, force: true }, tok);
    ok(r.status === 400, 'rome2 array data → 400');
    r = await call('PUT', '/save?game=rome2', { data: '{broken', force: true }, tok);
    ok(r.status === 400, 'broken JSON → 400');
    r = await call('PUT', '/save?game=rome2', Buffer.from('not gzip at all'), tok, { enc: 'gzip' });
    ok(r.status === 400, 'bad gzip → 400');
    r = await call('PUT', '/save?game=rome2', { data: '{"a":1}', force: true }, tok, { enc: 'br' });
    ok(r.status === 415, 'unknown encoding → 415');
    r = await call('PUT', '/save', { data: '{"a":1}' }, tok, { gzip: true });
    ok(r.status === 415, 'web slot does not take gzip → 415');
    const bomb = '{"data":"' + 'x'.repeat(40 * 1024 * 1024) + '"}';
    r = await call('PUT', '/save?game=rome2', bomb, tok, { gzip: true });
    ok(r.status === 413, 'gzip bomb (40 MB inside ' + Math.round(zlib.gzipSync(bomb).length / 1024) + ' KB) → 413');
    r = await call('PUT', '/save', JSON.stringify({ data: 'z'.repeat(9 * 1024 * 1024) }), tok);
    ok(r.status === 413, 'web body over limit → real 413 answer (not a dropped connection)');
    r = await call('PUT', '/save?game=rome2', require('crypto').randomBytes(9 * 1024 * 1024), tok, { enc: 'gzip' });
    ok(r.status === 413, 'rome2 compressed body over 8 MB → 413');
    const big = JSON.stringify({ data: JSON.stringify({ s: 'y'.repeat(13 * 1024 * 1024) }), force: true });
    r = await call('PUT', '/save?game=rome2', big, tok, { gzip: true });
    ok(r.status === 413, 'save over 12 MB → 413');

    // хранится сжатым
    const db = new DatabaseSync(path.join(DATA, 'civcity.db'));
    const row = db.prepare('SELECT length(data) AS dl, length(zdata) AS zl, size FROM saves WHERE id = ?').get(id2);
    ok(row.dl === 0 && row.zl > 0 && row.zl < row.size * 0.8, `rome2 stored gzipped: ${row.size} → ${row.zl} bytes`);
    const wrow = db.prepare("SELECT game, length(data) AS dl, zdata FROM saves WHERE user_id = (SELECT id FROM users WHERE email='old@test.ru') ORDER BY id DESC").get();
    ok(wrow.game === 'web' && wrow.dl > 0 && wrow.zdata === null, 'old web rows: game=web, plain data');

    // история: 3 последних + по одному на прошедший час, до 10
    const uid = db.prepare("SELECT id FROM users WHERE email='new@test.ru'").get().id;
    db.prepare('DELETE FROM saves WHERE user_id = ? AND game = ?').run(uid, 'rome2');
    const ins = db.prepare("INSERT INTO saves (user_id, game, created, size, data, zdata, meta) VALUES (?, 'rome2', ?, 7, '', ?, ?)");
    const H = 3600e3, now = Date.now();
    const z = zlib.gzipSync('{"a":1}');
    const times = [];
    for (let h = 30; h >= 1; h--) for (let k = 0; k < 4; k++) times.push(now - h * H + k * 90e3);  // по 4 сохранения в каждом из 30 прошлых часов
    for (const t of times) ins.run(uid, t, z, JSON.stringify({ t }));
    r = await call('GET', '/save?game=rome2', undefined, tok);
    const base = r.data.save.id;
    r = await call('PUT', '/save?game=rome2', { data: '{"latest":1}', base, meta: { pop: 1 } }, tok);
    ok(r.status === 200, 'PUT after history seed');
    let list = (await call('GET', '/saves?game=rome2', undefined, tok)).data.saves;
    const hours = new Set(list.slice(3).map(s => Math.floor(s.created / H)));
    ok(list.length === 10 && hours.size === 7, `history thinned to ${list.length} (3 recent + ${hours.size} hourly)`);
    // 12 сохранений подряд: 3 последних + часовые остаются
    let last = r.data.id;
    for (let i = 0; i < 12; i++) { r = await call('PUT', '/save?game=rome2', { data: `{"n":${i}}`, base: last }, tok); last = r.data.id; }
    list = (await call('GET', '/saves?game=rome2', undefined, tok)).data.saves;
    const older = list.filter(s => now - s.created > 1800e3);
    ok(list.length === 10 && older.length >= 6, `after 12 quick saves: ${list.length} kept, ${older.length} older hourly backups survive`);

    // уничтожить город
    r = await call('POST', '/destroy?game=rome2', { meta: { city: 'Новый Рим', pop: 5 } }, tok);
    ok(r.status === 200 && r.data.id && r.data.game === 'rome2', 'destroy → tombstone');
    const tomb = r.data.id;
    r = await call('GET', '/me?game=rome2', undefined, tok);
    ok(r.data.save.id === tomb && r.data.save.destroyed === true && r.data.save.meta.city === 'Новый Рим', '/me shows destroyed');
    r = await call('GET', '/save?game=rome2', undefined, tok);
    ok(r.data.save.destroyed === true && r.data.save.data === null, 'GET /save shows destroyed, data null');
    r = await call('POST', '/restore?game=rome2', { id: tomb }, tok);
    ok(r.status === 400, 'restore tombstone → 400');
    r = await call('POST', '/destroy', {}, tok);
    ok(r.status === 400, 'destroy not allowed for web slot');
    r = await call('PUT', '/save?game=rome2', { data: '{"fresh":1}', base: last }, tok);
    ok(r.status === 409, 'old base after destroy → 409');
    r = await call('PUT', '/save?game=rome2', { data: '{"fresh":1}', base: tomb }, tok);
    ok(r.status === 200, 'new city after destroy (base = tombstone)');
    list = (await call('GET', '/saves?game=rome2', undefined, tok)).data.saves;
    ok(list[1].destroyed === true && list[2].id === last, 'history: new city, tombstone, previous city');
    // новый город сохраняется дальше в тот же час — прежний город прореживание не вытесняет
    let nb = r.data.id;
    for (let i = 0; i < 4; i++) { r = await call('PUT', '/save?game=rome2', { data: `{"fresh":${i + 2}}`, base: nb }, tok); nb = r.data.id; }
    list = (await call('GET', '/saves?game=rome2', undefined, tok)).data.saves;
    ok(list.some(s => s.id === last) && list.some(s => s.destroyed), `after 4 more saves in the same hour the destroyed city (${last}) is still in history`);
    // уничтожение с устаревшим base (ждало связи, а город тем временем сохраняли с другого компьютера) → 409
    r = await call('POST', '/destroy?game=rome2', { meta: { city: 'Новый Рим' }, base: last }, tok);
    ok(r.status === 409 && r.data.latest && r.data.latest.id === nb, 'destroy with stale base → 409 with latest');
    // «оставить город с этого компьютера» (force поверх другого) — облачный город тоже остаётся в истории
    const cloudCity = nb;
    r = await call('PUT', '/save?game=rome2', { data: '{"other_pc":1}', base: tomb, force: true }, tok);
    nb = r.data.id;
    for (let i = 0; i < 4; i++) { r = await call('PUT', '/save?game=rome2', { data: `{"other_pc":${i + 2}}`, base: nb }, tok); nb = r.data.id; }
    list = (await call('GET', '/saves?game=rome2', undefined, tok)).data.saves;
    ok(list.some(s => s.id === cloudCity), `forced switch: replaced cloud city (${cloudCity}) is still in history`);
    r = await call('POST', '/restore?game=rome2', { id: last }, tok);
    ok(r.status === 200 && r.data.game === 'rome2', 'restore previous city');
    r = await call('GET', '/save?game=rome2', undefined, tok);
    ok(r.data.save.data === '{"n":11}', 'restored data is the previous city');
    r = await call('POST', '/restore?game=rome2', { id: (await call('GET', '/saves', undefined, oldTok)).data.saves[0].id }, oldTok);
    ok(r.status === 404, 'restore id from another slot → 404');

    // старая ячейка: 12 сохранений → 10, ячейка rome2 не трогается
    const before = (await call('GET', '/saves?game=rome2', undefined, tok)).data.saves.length;
    let wb = null;
    for (let i = 0; i < 12; i++) { r = await call('PUT', '/save', { data: `{"w":${i}}`, base: wb, meta: { city: 'W' } }, tok); wb = r.data.id; }
    const wl = (await call('GET', '/saves', undefined, tok)).data;
    const after = (await call('GET', '/saves?game=rome2', undefined, tok)).data.saves.length;
    ok(wl.saves.length === 10 && !('game' in wl) && before === after, `web trim per slot: web ${wl.saves.length}, rome2 ${before}→${after}`);
    r = await call('PUT', '/save', { data: '{"w":"x"}', base: 1 }, tok);
    ok(r.status === 409 && r.data.latest.id === wb, 'web conflict unchanged');

    // выход
    r = await call('POST', '/logout', undefined, tok);
    r = await call('GET', '/me?game=rome2', undefined, tok);
    ok(r.status === 401, 'logout kills token');
    r = await call('POST', '/forgot', { email: 'new@test.ru' });
    ok(r.status === 200 && r.data.ok, 'forgot ok (mail logged)');
    db.close();
  } finally {
    await stop(srv);
  }
  console.log(fails ? `${fails} FAILED` : 'ALL OK');
  process.exit(fails ? 1 : 0);
})().catch(e => { console.error(e); process.exit(2); });
