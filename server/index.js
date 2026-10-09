'use strict';
/* Сервер CivCity: аккаунты (почта и пароль), сохранения городов в облаке, восстановление пароля по почте.
   Без лишних зависимостей: http, crypto и встроенная база SQLite из Node. Слушает только 127.0.0.1 —
   снаружи к нему ходят через Caddy (HTTPS). Игру (статические файлы) раздаёт сам Caddy.

   Пароли хранятся только как хэш scrypt с солью. Вход — по токену сессии (в базе лежит его хэш).
   На регистрацию, вход и сброс пароля стоят лимиты запросов. У каждого города хранится 10 последних
   сохранений — если что-то сломается, можно откатить. */

const http = require('http');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const { DatabaseSync } = require('node:sqlite');
const mail = require('./mail');

const PORT = +process.env.PORT || 3000;
const DATA = process.env.DATA_DIR || path.join(__dirname, 'data');
const SITE = process.env.SITE_URL || 'http://localhost';
const ORIGINS = (process.env.ORIGINS || '').split(',').map(s => s.trim()).filter(Boolean);
const MAX_SAVE = 6 * 1024 * 1024;     // сохранение города — до 6 МБ
const KEEP_SAVES = 10;
const SESSION_DAYS = 180;

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

const q = {
  userByEmail: db.prepare('SELECT * FROM users WHERE email = ?'),
  userById: db.prepare('SELECT * FROM users WHERE id = ?'),
  addUser: db.prepare('INSERT INTO users (email, pass, created, last_seen) VALUES (?, ?, ?, ?)'),
  setPass: db.prepare('UPDATE users SET pass = ? WHERE id = ?'),
  seen: db.prepare('UPDATE users SET last_seen = ? WHERE id = ?'),
  addSession: db.prepare('INSERT INTO sessions (hash, user_id, created, used, agent) VALUES (?, ?, ?, ?, ?)'),
  session: db.prepare('SELECT * FROM sessions WHERE hash = ?'),
  touchSession: db.prepare('UPDATE sessions SET used = ? WHERE hash = ?'),
  dropSession: db.prepare('DELETE FROM sessions WHERE hash = ?'),
  dropSessions: db.prepare('DELETE FROM sessions WHERE user_id = ?'),
  oldSessions: db.prepare('DELETE FROM sessions WHERE used < ?'),
  lastSave: db.prepare('SELECT id, created, size, data, meta FROM saves WHERE user_id = ? ORDER BY id DESC LIMIT 1'),
  lastSaveInfo: db.prepare('SELECT id, created, size, meta FROM saves WHERE user_id = ? ORDER BY id DESC LIMIT 1'),
  saveList: db.prepare('SELECT id, created, size, meta FROM saves WHERE user_id = ? ORDER BY id DESC'),
  saveById: db.prepare('SELECT id, created, size, data, meta FROM saves WHERE user_id = ? AND id = ?'),
  addSave: db.prepare('INSERT INTO saves (user_id, created, size, data, meta) VALUES (?, ?, ?, ?, ?)'),
  trimSaves: db.prepare(`DELETE FROM saves WHERE user_id = ? AND id NOT IN (SELECT id FROM saves WHERE user_id = ? ORDER BY id DESC LIMIT ${KEEP_SAVES})`),
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

function readBody(req, limit) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    req.on('data', c => {
      size += c.length;
      if (size > limit) { reject(new Fail(413, 'Слишком большой запрос')); req.destroy(); return; }
      chunks.push(c);
    });
    req.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
    req.on('error', reject);
  });
}

async function json(req, limit) {
  const raw = await readBody(req, limit || 64 * 1024);
  try { return raw ? JSON.parse(raw) : {}; } catch (e) { throw new Fail(400, 'Неверный запрос'); }
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
  'GET /api/health': () => ({ ok: true }),

  'POST /api/register': async (req) => {
    if (limited('reg:' + ipOf(req), 10, 3600e3)) throw new Fail(429, 'Слишком много попыток, попробуйте позже');
    const b = await json(req);
    const email = cleanEmail(b.email), pass = cleanPassword(b.password);
    if (q.userByEmail.get(email)) throw new Fail(409, 'Такая почта уже зарегистрирована — войдите');
    const now = Date.now();
    const r = q.addUser.run(email, hashPassword(pass), now, now);
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

  'GET /api/me': (req) => {
    const a = auth(req);
    const u = q.userById.get(a.userId);
    const s = q.lastSaveInfo.get(a.userId);
    return { email: u.email, save: s ? { id: s.id, created: s.created, size: s.size, meta: s.meta ? JSON.parse(s.meta) : null } : null };
  },

  // последнее сохранение города
  'GET /api/save': (req) => {
    const a = auth(req);
    const s = q.lastSave.get(a.userId);
    if (!s) return { save: null };
    return { save: { id: s.id, created: s.created, meta: s.meta ? JSON.parse(s.meta) : null, data: s.data } };
  },

  // новое сохранение; base — номер сохранения, от которого шёл этот город (защита от затирания с другого устройства)
  'PUT /api/save': async (req) => {
    const a = auth(req);
    if (limited('save:' + a.userId, 40, 600e3)) throw new Fail(429, 'Слишком часто');
    const b = await json(req, MAX_SAVE + 4096);
    if (typeof b.data !== 'string' || !b.data.length) throw new Fail(400, 'Пустое сохранение');
    if (b.data.length > MAX_SAVE) throw new Fail(413, 'Сохранение слишком большое');
    try { JSON.parse(b.data); } catch (e) { throw new Fail(400, 'Сохранение повреждено'); }
    const last = q.lastSaveInfo.get(a.userId);
    if (last && !b.force && b.base !== undefined && b.base !== null && b.base !== last.id) {
      throw Object.assign(new Fail(409, 'В облаке есть более новое сохранение'), { extra: { latest: { id: last.id, created: last.created, meta: last.meta ? JSON.parse(last.meta) : null } } });
    }
    const meta = b.meta && typeof b.meta === 'object' ? JSON.stringify(b.meta).slice(0, 1000) : null;
    const r = q.addSave.run(a.userId, Date.now(), b.data.length, b.data, meta);
    q.trimSaves.run(a.userId, a.userId);
    return { id: Number(r.lastInsertRowid) };
  },

  // список последних сохранений и откат к одному из них
  'GET /api/saves': (req) => ({ saves: q.saveList.all(auth(req).userId).map(s => ({ id: s.id, created: s.created, size: s.size, meta: s.meta ? JSON.parse(s.meta) : null })) }),

  'POST /api/restore': async (req) => {
    const a = auth(req);
    const b = await json(req);
    const s = q.saveById.get(a.userId, Number(b.id));
    if (!s) throw new Fail(404, 'Такого сохранения нет');
    const r = q.addSave.run(a.userId, Date.now(), s.size, s.data, s.meta);
    q.trimSaves.run(a.userId, a.userId);
    return { id: Number(r.lastInsertRowid) };
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
