'use strict';
/* Сервер CivCity: аккаунты (почта и пароль), сохранения городов в облаке, восстановление пароля по почте.
   Без лишних зависимостей: http, crypto и встроенная база SQLite из Node. Слушает только 127.0.0.1 —
   снаружи к нему ходят через Caddy (HTTPS). Игру (статические файлы) раздаёт сам Caddy.

   Пароли хранятся только как хэш scrypt с солью. Вход — по токену сессии (в базе лежит его хэш).
   На регистрацию, вход и сброс пароля стоят лимиты запросов. У каждого города хранится 10 последних
   сохранений — если что-то сломается, можно откатить.

   Ячейки сохранений (?game=…): у каждой игры свой город, они не мешают друг другу.
     web   — старая браузерная игра (по умолчанию, без ?game — всё как раньше);
     rome2 — новая игра на Godot (программа для ПК). Её город хранится сжатым (gzip), может прийти сжатым
             (Content-Encoding: gzip), история — 3 последних сохранения и по одному на каждый прошедший час
             (всего до 10), есть «Уничтожить город» (POST /api/destroy — отметка в истории, прежний город
             остаётся в истории и его можно вернуть). Город, который сменили (уничтожили, откатили, заменили
             городом с другого компьютера), прореживание не трогает: его последнее сохранение держится в истории,
             пока не вытеснят 10 более новых. */

const http = require('http');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');
const { DatabaseSync } = require('node:sqlite');
const mail = require('./mail');

const PORT = +process.env.PORT || 3000;
const DATA = process.env.DATA_DIR || path.join(__dirname, 'data');
const SITE = process.env.SITE_URL || 'http://localhost';
const ORIGINS = (process.env.ORIGINS || '').split(',').map(s => s.trim()).filter(Boolean);
const MAX_SAVE = 6 * 1024 * 1024;     // сохранение города — до 6 МБ
const KEEP_SAVES = 10;
const SESSION_DAYS = 180;

// игры и их ячейки сохранений. Город новой игры: готовый городок (208 построек) — 0,8 МБ (сжатый 0,3 МБ),
// большая витрина (654 постройки) — 2,5 МБ (сжатый 1 МБ). Предел — 12 МБ несжатого, запрос — до 8 МБ сжатого
const GAMES = {
  web: { maxSave: MAX_SAVE, zip: false, destroy: false },
  rome2: { maxSave: 12 * 1024 * 1024, maxBody: 8 * 1024 * 1024, zip: true, destroy: true, recent: 3, bucket: 3600e3 },
};

fs.mkdirSync(DATA, { recursive: true });
const db = new DatabaseSync(path.join(DATA, 'civcity.db'));
db.exec(`
  PRAGMA journal_mode = WAL;
  PRAGMA foreign_keys = ON;
  CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY,
    email TEXT NOT NULL UNIQUE,
    pass TEXT NOT NULL,
    created INTEGER NOT NULL,
    last_seen INTEGER
  );
  CREATE TABLE IF NOT EXISTS sessions (
    hash TEXT PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created INTEGER NOT NULL,
    used INTEGER NOT NULL,
    agent TEXT
  );
  CREATE TABLE IF NOT EXISTS saves (
    id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created INTEGER NOT NULL,
    size INTEGER NOT NULL,
    data TEXT NOT NULL,
    meta TEXT
  );
  CREATE INDEX IF NOT EXISTS saves_user ON saves(user_id, id);
  CREATE TABLE IF NOT EXISTS resets (
    hash TEXT PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    expires INTEGER NOT NULL
  );
`);
// ячейка игры у сохранений (старые записи — web) и сжатый город (zdata, gzip) — для новой игры
{
  const cols = db.prepare('PRAGMA table_info(saves)').all().map(c => c.name);
  if (!cols.includes('game')) db.exec(`ALTER TABLE saves ADD COLUMN game TEXT NOT NULL DEFAULT 'web'`);
  if (!cols.includes('zdata')) db.exec('ALTER TABLE saves ADD COLUMN zdata BLOB');
  // flags: 1 — это сохранение сменило город (откат, «оставить город с этого компьютера» поверх облачного):
  // предыдущий город прореживание истории не удаляет (см. trimHistory)
  if (!cols.includes('flags')) db.exec('ALTER TABLE saves ADD COLUMN flags INTEGER NOT NULL DEFAULT 0');
  db.exec('CREATE INDEX IF NOT EXISTS saves_user_game ON saves(user_id, game, id)');
}
// когда игрок поставил галочку согласия на обработку данных (лаунчер 1.0.2+, игра сборки 15+); у старых — пусто
if (!db.prepare('PRAGMA table_info(users)').all().some(c => c.name === 'consent')) db.exec('ALTER TABLE users ADD COLUMN consent INTEGER');
const SWITCHED = 1;

const q = {
  userByEmail: db.prepare('SELECT * FROM users WHERE email = ?'),
  userById: db.prepare('SELECT * FROM users WHERE id = ?'),
  addUser: db.prepare('INSERT INTO users (email, pass, created, last_seen, consent) VALUES (?, ?, ?, ?, ?)'),
  setPass: db.prepare('UPDATE users SET pass = ? WHERE id = ?'),
  seen: db.prepare('UPDATE users SET last_seen = ? WHERE id = ?'),
  addSession: db.prepare('INSERT INTO sessions (hash, user_id, created, used, agent) VALUES (?, ?, ?, ?, ?)'),
  session: db.prepare('SELECT * FROM sessions WHERE hash = ?'),
  touchSession: db.prepare('UPDATE sessions SET used = ? WHERE hash = ?'),
  dropSession: db.prepare('DELETE FROM sessions WHERE hash = ?'),
  dropSessions: db.prepare('DELETE FROM sessions WHERE user_id = ?'),
  oldSessions: db.prepare('DELETE FROM sessions WHERE used < ?'),
  lastSave: db.prepare('SELECT id, created, size, data, zdata, meta FROM saves WHERE user_id = ? AND game = ? ORDER BY id DESC LIMIT 1'),
  lastSaveInfo: db.prepare('SELECT id, created, size, meta FROM saves WHERE user_id = ? AND game = ? ORDER BY id DESC LIMIT 1'),
  saveList: db.prepare('SELECT id, created, size, meta FROM saves WHERE user_id = ? AND game = ? ORDER BY id DESC'),
  saveById: db.prepare('SELECT id, created, size, data, zdata, meta FROM saves WHERE user_id = ? AND game = ? AND id = ?'),
  addSave: db.prepare('INSERT INTO saves (user_id, game, created, size, data, zdata, meta, flags) VALUES (?, ?, ?, ?, ?, ?, ?, ?)'),
  trimSaves: db.prepare(`DELETE FROM saves WHERE user_id = ? AND game = ? AND id NOT IN (SELECT id FROM saves WHERE user_id = ? AND game = ? ORDER BY id DESC LIMIT ${KEEP_SAVES})`),
  saveTimes: db.prepare('SELECT id, created, size, flags FROM saves WHERE user_id = ? AND game = ? ORDER BY id DESC'),
  dropSave: db.prepare('DELETE FROM saves WHERE id = ?'),
  addReset: db.prepare('INSERT INTO resets (hash, user_id, expires) VALUES (?, ?, ?)'),
  reset: db.prepare('SELECT * FROM resets WHERE hash = ?'),
  dropResets: db.prepare('DELETE FROM resets WHERE user_id = ? OR expires < ?'),
};

/* ---------- Пароли и токены ---------- */

const SCRYPT = { N: 16384, r: 8, p: 1, maxmem: 64 * 1024 * 1024 };
function hashPassword(pw) {
  const salt = crypto.randomBytes(16);
  const h = crypto.scryptSync(pw, salt, 32, SCRYPT);
  return `s1$${salt.toString('base64')}$${h.toString('base64')}`;
}
function checkPassword(pw, stored) {
  const [v, salt, h] = String(stored).split('$');
  if (v !== 's1') return false;
  const got = crypto.scryptSync(pw, Buffer.from(salt, 'base64'), 32, SCRYPT);
  const want = Buffer.from(h, 'base64');
  return got.length === want.length && crypto.timingSafeEqual(got, want);
}
const sha = s => crypto.createHash('sha256').update(s).digest('hex');
const newToken = () => crypto.randomBytes(32).toString('base64url');

function openSession(userId, agent) {
  const token = newToken(), now = Date.now();
  q.addSession.run(sha(token), userId, now, now, String(agent || '').slice(0, 160));
  return token;
}

/* ---------- Лимиты запросов: не больше n за окно по ключу (адрес, почта) ---------- */

const buckets = new Map();
function limited(key, n, windowMs) {
  const now = Date.now();
  let b = buckets.get(key);
  if (!b || now - b.t > windowMs) { b = { t: now, n: 0 }; buckets.set(key, b); }
  b.n++;
  return b.n > n;
}
setInterval(() => { const now = Date.now(); for (const [k, b] of buckets) if (now - b.t > 3600e3) buckets.delete(k); }, 600e3).unref();
setInterval(() => q.oldSessions.run(Date.now() - SESSION_DAYS * 864e5), 3600e3).unref();

/* ---------- HTTP ---------- */

class Fail extends Error { constructor(status, msg) { super(msg); this.status = status; } }

// тело запроса; сжатое (Content-Encoding: gzip) — только если указан zipLimit: столько можно прислать сжатым,
// а распакованное всё равно не больше limit (защита от «зип-бомбы»)
function readBody(req, limit, zipLimit) {
  const enc = String(req.headers['content-encoding'] || '').trim().toLowerCase();
  const zipped = enc === 'gzip';
  if (enc && enc !== 'identity' && !(zipped && zipLimit)) return Promise.reject(new Fail(415, 'Неверное сжатие запроса'));
  const max = zipped ? zipLimit : limit;
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    req.on('data', c => {
      size += c.length;
      if (size > max) {
        // лишнее дочитываем впустую (до 4 пределов), чтобы клиент получил ответ 413, а не обрыв связи
        if (size > max * 4) { reject(new Fail(413, 'Слишком большой запрос')); req.destroy(); }
        chunks.length = 0;
        return;
      }
      chunks.push(c);
    });
    req.on('end', () => {
      if (size > max) { reject(new Fail(413, 'Слишком большой запрос')); return; }
      let buf = Buffer.concat(chunks);
      if (zipped) {
        try { buf = zlib.gunzipSync(buf, { maxOutputLength: limit }); } catch (e) {
          reject(e.code === 'ERR_BUFFER_TOO_LARGE' || e instanceof RangeError ? new Fail(413, 'Слишком большой запрос') : new Fail(400, 'Повреждённый сжатый запрос'));
          return;
        }
      }
      resolve(buf.toString('utf8'));
    });
    req.on('error', reject);
  });
}

async function json(req, limit, zipLimit) {
  const raw = await readBody(req, limit || 64 * 1024, zipLimit);
  try { return raw ? JSON.parse(raw) : {}; } catch (e) { throw new Fail(400, 'Неверный запрос'); }
}

/* ---------- Ячейки сохранений ---------- */

// какая игра: ?game=… (без него — старая браузерная web)
function gameOf(url) {
  const g = url.searchParams.get('game') || 'web';
  if (!Object.prototype.hasOwnProperty.call(GAMES, g)) throw new Fail(400, 'Нет такой игры');
  return g;
}

const metaOf = s => { try { return s.meta ? JSON.parse(s.meta) : null; } catch (e) { return null; } };
// подпись сохранения (город, жители, день…) — не длиннее 1000 знаков; длиннее — не храним (обрезанный JSON был бы испорчен)
function metaStr(m) {
  if (!m || typeof m !== 'object') return null;
  const s = JSON.stringify(m);
  return s.length <= 1000 ? s : null;
}
const isTomb = s => !s.size && !s.data && !s.zdata;          // отметка «город уничтожен»
const dataOf = s => s.zdata ? zlib.gunzipSync(s.zdata).toString('utf8') : s.data;
function saveInfo(s) {
  const o = { id: s.id, created: s.created, size: s.size, meta: metaOf(s) };
  if (isTomb(s)) o.destroyed = true;
  return o;
}

// История новой игры: 3 последних сохранения и самое позднее из каждого прошедшего часа, всего до 10.
// Сохранения идут каждые полторы минуты — без прореживания история покрывала бы всего четверть часа.
// Сменённый город (перед отметкой «уничтожен» или перед сохранением с flags SWITCHED) не прореживается: его
// последнее сохранение остаётся, иначе новый город в тот же час вытеснил бы его за пару сохранений
function trimHistory(userId, game) {
  const g = GAMES[game];
  if (!g.bucket) { q.trimSaves.run(userId, game, userId, game); return; }
  const seen = new Set();
  let kept = 0;
  let protect = false;                 // следующее (более старое) настоящее сохранение — прежний город, держим
  for (const [i, r] of q.saveTimes.all(userId, game).entries()) {
    const b = Math.floor(r.created / g.bucket);
    const tomb = !r.size;
    const mark = tomb || !!(r.flags & SWITCHED);   // сама отметка смены тоже остаётся — по ней держится прежний город
    const keep = kept < KEEP_SAVES && (i < g.recent || !seen.has(b) || mark || protect);
    seen.add(b);
    if (!tomb) protect = false;
    if (mark) protect = true;
    if (keep) kept++;
    else q.dropSave.run(r.id);
  }
}

function addSave(userId, game, data, meta, flags = 0) {
  const g = GAMES[game];
  const z = g.zip && data ? zlib.gzipSync(Buffer.from(data, 'utf8'), { level: 6 }) : null;
  const now = Date.now();
  const r = q.addSave.run(userId, game, now, data ? Buffer.byteLength(data, 'utf8') : 0, z ? '' : data, z, meta, flags);
  trimHistory(userId, game);
  return { id: Number(r.lastInsertRowid), created: now };
}

function ipOf(req) { return String(req.headers['x-forwarded-for'] || req.socket.remoteAddress || '').split(',')[0].trim(); }

function auth(req) {
  const m = /^Bearer (.+)$/.exec(req.headers.authorization || '');
  if (!m) throw new Fail(401, 'Нужно войти');
  const h = sha(m[1]);
  const s = q.session.get(h);
  if (!s) throw new Fail(401, 'Вход устарел — войдите снова');
  const now = Date.now();
  if (now - s.used > 3600e3) { q.touchSession.run(now, h); q.seen.run(now, s.user_id); }
  return { userId: s.user_id, hash: h };
}

const EMAIL_RE = /^[^\s@]{1,64}@[^\s@]{1,190}\.[^\s@]{2,20}$/;
function cleanEmail(e) {
  const s = String(e || '').trim().toLowerCase();
  if (!EMAIL_RE.test(s)) throw new Fail(400, 'Проверьте адрес почты');
  return s;
}
function cleanPassword(p) {
  const s = String(p || '');
  if (s.length < 6) throw new Fail(400, 'Пароль — не короче 6 знаков');
  if (s.length > 200) throw new Fail(400, 'Слишком длинный пароль');
  return s;
}

const routes = {
  'GET /api/health': () => ({ ok: true, games: Object.keys(GAMES), pvp: true }),

  // новости и ссылки для лаунчера программы для ПК (файл launcher.json рядом с сервером; правится без перезапуска)
  'GET /api/launcher': () => {
    try { return JSON.parse(fs.readFileSync(path.join(__dirname, 'launcher.json'), 'utf8')); } catch (e) { return { news: [], links: [] }; }
  },

  'POST /api/register': async (req) => {
    if (limited('reg:' + ipOf(req), 10, 3600e3)) throw new Fail(429, 'Слишком много попыток, попробуйте позже');
    const b = await json(req);
    const email = cleanEmail(b.email), pass = cleanPassword(b.password);
    if (q.userByEmail.get(email)) throw new Fail(409, 'Такая почта уже зарегистрирована — войдите');
    const now = Date.now();
    const r = q.addUser.run(email, hashPassword(pass), now, now, b.consent === true ? now : null);
    return { token: openSession(Number(r.lastInsertRowid), req.headers['user-agent']), email };
  },

  'POST /api/login': async (req) => {
    const b = await json(req);
    const email = cleanEmail(b.email);
    if (limited('login:' + ipOf(req), 30, 600e3) || limited('login:' + email, 10, 600e3)) throw new Fail(429, 'Слишком много попыток, подождите 10 минут');
    const u = q.userByEmail.get(email);
    if (!u || !checkPassword(String(b.password || ''), u.pass)) throw new Fail(401, 'Неверная почта или пароль');
    q.seen.run(Date.now(), u.id);
    return { token: openSession(u.id, req.headers['user-agent']), email };
  },

  'POST /api/logout': async (req) => { const a = auth(req); q.dropSession.run(a.hash); return { ok: true }; },

  // кто вошёл и последнее сохранение его города (в ячейке ?game=…); game в ответе — только когда спросили ячейку
  'GET /api/me': (req, url) => {
    const a = auth(req);
    const game = gameOf(url);
    const u = q.userById.get(a.userId);
    const s = q.lastSaveInfo.get(a.userId, game);
    const out = { email: u.email, save: s ? saveInfo(s) : null };
    if (url.searchParams.has('game')) out.game = game;
    return out;
  },

  // последнее сохранение города (у уничтоженного: destroyed: true и data: null)
  'GET /api/save': (req, url) => {
    const a = auth(req);
    const game = gameOf(url);
    const s = q.lastSave.get(a.userId, game);
    const out = { save: null };
    if (s) {
      out.save = { id: s.id, created: s.created, meta: metaOf(s), data: isTomb(s) ? null : dataOf(s) };
      if (isTomb(s)) out.save.destroyed = true;
    }
    if (url.searchParams.has('game')) out.game = game;
    return out;
  },

  // новое сохранение; base — номер сохранения, от которого шёл этот город (защита от затирания с другого устройства)
  'PUT /api/save': async (req, url) => {
    const a = auth(req);
    const game = gameOf(url), g = GAMES[game];
    if (limited(`save:${game}:${a.userId}`, 40, 600e3)) throw new Fail(429, 'Слишком часто');
    const b = await json(req, Math.ceil(g.maxSave * 1.25) + 4096, g.maxBody);
    if (typeof b.data !== 'string' || !b.data.length) throw new Fail(400, 'Пустое сохранение');
    if (b.data.length > g.maxSave) throw new Fail(413, 'Сохранение слишком большое');
    let parsed;
    try { parsed = JSON.parse(b.data); } catch (e) { throw new Fail(400, 'Сохранение повреждено'); }
    if (g.zip && (!parsed || typeof parsed !== 'object' || Array.isArray(parsed))) throw new Fail(400, 'Сохранение повреждено');
    const last = q.lastSaveInfo.get(a.userId, game);
    if (last && !b.force && b.base !== undefined && b.base !== null && b.base !== last.id) {
      throw Object.assign(new Fail(409, 'В облаке есть более новое сохранение'), { extra: { latest: saveInfo(last) } });
    }
    // город идёт не от последнего сохранения в облаке (force поверх другого, или base не знает) — это смена города
    const switched = !!last && !isTomb(last) && b.base !== last.id;
    const r = addSave(a.userId, game, b.data, metaStr(b.meta), switched ? SWITCHED : 0);
    const out = { id: r.id };
    if (url.searchParams.has('game')) Object.assign(out, { game, created: r.created });
    return out;
  },

  // список последних сохранений и откат к одному из них
  'GET /api/saves': (req, url) => {
    const a = auth(req);
    const game = gameOf(url);
    const out = { saves: q.saveList.all(a.userId, game).map(saveInfo) };
    if (url.searchParams.has('game')) out.game = game;
    return out;
  },

  'POST /api/restore': async (req, url) => {
    const a = auth(req);
    const game = gameOf(url);
    const b = await json(req);
    const s = q.saveById.get(a.userId, game, Number(b.id));
    if (!s) throw new Fail(404, 'Такого сохранения нет');
    if (isTomb(s)) throw new Fail(400, 'Это отметка «город уничтожен» — вернуть можно только сам город');
    const r = addSave(a.userId, game, dataOf(s), s.meta, SWITCHED);
    const out = { id: r.id };
    if (url.searchParams.has('game')) Object.assign(out, { game, created: r.created });
    return out;
  },

  // «Уничтожить город» (новая игра): в истории появляется отметка, дальше игра начинает чистое поле и сохраняет его поверх.
  // Прежний город остаётся в истории (GET /api/saves) — его можно вернуть через /api/restore.
  // base — номер сохранения, который игрок видел, когда уничтожал (уничтожение могло ждать связи): если с тех пор
  // город в облаке сохранили с другого компьютера — 409, уничтожать чужой свежий прогресс молча нельзя
  'POST /api/destroy': async (req, url) => {
    const a = auth(req);
    const game = gameOf(url);
    if (!GAMES[game].destroy) throw new Fail(400, 'Здесь город уничтожается в самой игре');
    if (limited(`destroy:${a.userId}`, 10, 3600e3)) throw new Fail(429, 'Слишком часто');
    const b = await json(req);
    const last = q.lastSaveInfo.get(a.userId, game);
    if (last && !b.force && b.base !== undefined && b.base !== null && b.base !== last.id) {
      throw Object.assign(new Fail(409, 'Город в облаке сохранили с другого компьютера'), { extra: { latest: saveInfo(last) } });
    }
    const meta = metaStr(Object.assign({}, b.meta && typeof b.meta === 'object' && !Array.isArray(b.meta) ? b.meta : {}, { destroyed: true })) || '{"destroyed":true}';
    const r = addSave(a.userId, game, '', meta);
    return { id: r.id, game, created: r.created };
  },

  // письмо со ссылкой для нового пароля; ответ всегда один — так нельзя узнать, есть ли такая почта
  'POST /api/forgot': async (req) => {
    const b = await json(req);
    const email = cleanEmail(b.email);
    if (limited('forgot:' + ipOf(req), 10, 3600e3) || limited('forgot:' + email, 3, 3600e3)) throw new Fail(429, 'Письмо уже отправлено — проверьте почту и папку «Спам»');
    const u = q.userByEmail.get(email);
    if (u) {
      const token = newToken();
      q.dropResets.run(u.id, Date.now());
      q.addReset.run(sha(token), u.id, Date.now() + 3600e3);
      const link = `${SITE}/#reset=${token}`;
      mail.send(email, 'CivCity: новый пароль',
        `Здравствуйте!\n\nКто-то (надеемся, вы) попросил новый пароль для CivCity.\nЧтобы задать его, откройте ссылку в течение часа:\n\n${link}\n\nЕсли вы ничего не просили — просто удалите это письмо, пароль останется прежним.\n\nCivCity`)
        .catch(e => console.error('mail:', e.message));
    }
    return { ok: true };
  },

  'POST /api/reset': async (req) => {
    if (limited('reset:' + ipOf(req), 20, 3600e3)) throw new Fail(429, 'Слишком много попыток');
    const b = await json(req);
    const pass = cleanPassword(b.password);
    const r = q.reset.get(sha(String(b.token || '')));
    if (!r || r.expires < Date.now()) throw new Fail(400, 'Ссылка устарела — запросите новую');
    q.setPass.run(hashPassword(pass), r.user_id);
    q.dropSessions.run(r.user_id);
    q.dropResets.run(r.user_id, Date.now());
    const u = q.userById.get(r.user_id);
    return { token: openSession(r.user_id, req.headers['user-agent']), email: u.email };
  },
};

// Бои с городами (Легион новой игры, /api/pvp/…) — в pvp.js; отряды сверяются с последним городом в облаке (rome2)
require('./pvp').install({ db, routes, auth, json, limited, Fail,
  latestSave: uid => {
    const s = q.lastSaveInfo.get(uid, 'rome2');
    if (!s || !s.size) return null;
    return { id: s.id, load: () => { const f = q.saveById.get(uid, 'rome2', s.id); return f && !isTomb(f) ? dataOf(f) : ''; } };
  } });

function cors(req, res) {
  const o = req.headers.origin;
  if (o && (ORIGINS.includes(o) || o === 'app://game')) {
    res.setHeader('Access-Control-Allow-Origin', o);
    res.setHeader('Vary', 'Origin');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, OPTIONS');
    res.setHeader('Access-Control-Max-Age', '86400');
  }
}

const server = http.createServer(async (req, res) => {
  cors(req, res);
  if (req.method === 'OPTIONS') { res.writeHead(204); res.end(); return; }
  const url = new URL(req.url, 'http://x');
  const route = routes[`${req.method} ${url.pathname}`];
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.setHeader('Cache-Control', 'no-store');
  if (!route) { res.writeHead(404); res.end(JSON.stringify({ error: 'Нет такого адреса' })); return; }
  try {
    const out = await route(req, url);
    res.writeHead(200);
    res.end(JSON.stringify(out));
  } catch (e) {
    const status = e.status || 500;
    if (status === 500) console.error(new Date().toISOString(), req.method, url.pathname, e);
    res.writeHead(status);
    res.end(JSON.stringify(Object.assign({ error: status === 500 ? 'Ошибка сервера, попробуйте ещё раз' : e.message }, e.extra || {})));
  }
});

server.listen(PORT, '127.0.0.1', () => console.log(`CivCity server on 127.0.0.1:${PORT}, data ${DATA}`));
