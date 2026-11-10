'use strict';
/* Союзы игроков (docs/ONLINE_V2.md §4). Мягкая командная игра без свободного чата:

   - Союз — до MAX_MEMBERS городов: название (те же правила, что у города: names.js), герб (EMBLEMS) и цвет, открытый
     (вступают сразу) или по заявке (глава принимает). Глава может исключить; ушёл глава — главой становится самый
     старший по вступлению; ушли все — союза нет.
   - Цель недели (неделя — WEEK от EPOCH, понедельник 00:00 UTC): очки союза за неделю — сумма очков участников. Очки
     идут сами (hooks.points из боёв и друзей): победа над городом +3, поражение +1, гости из вашего города у других
     +1, «нравится» +1, подарок другу +2. Пороги GOALS; в начале новой недели каждый, кто был в союзе и принёс очки
     прошлой недели, забирает награду по порогу, до которого дошёл союз (POST /api/union/prize, один раз).
   - Чат — только готовыми фразами (PHRASES), так не нужна проверка текста. Последние CHAT_KEEP сообщений.
   Почты здесь нет: участники видны по названиям городов. */

const names = require('./names');

const MAX_MEMBERS = 15;
const WEEK = +process.env.UNION_WEEK_MS || 7 * 864e5;
const EPOCH = +process.env.UNION_EPOCH_MS || Date.UTC(2026, 10, 2);
const GOALS = [{ pts: 60, money: 1000, glory: 5 }, { pts: 160, money: 2500, glory: 12 }, { pts: 360, money: 5000, glory: 25 }];
const EMBLEMS = ['орёл', 'волчица', 'лавры', 'щит', 'меч', 'колонна', 'амфора', 'лев', 'дельфин', 'колос', 'солнце', 'корабль'];
const COLORS = 8;
const PHRASES = ['Аве, друзья!', 'Отличный бой!', 'Поможем с целью недели!', 'Спасибо за подарок!', 'Загляните в мой город!',
  'Иду в атаку!', 'Хорошая неделя, все молодцы!', 'Доброй ночи, Рим!', 'Добавляйтесь в друзья!', 'Слава Риму!'];
const CHAT_KEEP = 40;
const NAME_RE = /^[\p{L}\p{N} '’\-«»".]+$/u;

const int = v => (Number.isFinite(+v) ? Math.trunc(+v) : 0);
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const nameKey = s => String(s).toLowerCase().replace(/ё/g, 'е').replace(/\s+/g, ' ').trim();
const weekAt = t => Math.max(0, Math.floor((t - EPOCH) / WEEK));
const tierOf = pts => { let t = -1; GOALS.forEach((g, i) => { if (pts >= g.pts) t = i; }); return t; };

function install({ db, routes, auth, json, limited, Fail, pvpPlayer, hooks }) {
  db.exec(`
    CREATE TABLE IF NOT EXISTS unions (
      id INTEGER PRIMARY KEY,
      name TEXT NOT NULL,
      name_key TEXT NOT NULL UNIQUE,
      emblem INTEGER NOT NULL DEFAULT 0,
      color INTEGER NOT NULL DEFAULT 0,
      open INTEGER NOT NULL DEFAULT 1,
      created INTEGER NOT NULL,
      week INTEGER NOT NULL DEFAULT 0,
      week_pts INTEGER NOT NULL DEFAULT 0,
      total_pts INTEGER NOT NULL DEFAULT 0
    );
    CREATE TABLE IF NOT EXISTS union_members (
      user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
      union_id INTEGER NOT NULL REFERENCES unions(id) ON DELETE CASCADE,
      leader INTEGER NOT NULL DEFAULT 0,
      joined INTEGER NOT NULL,
      week INTEGER NOT NULL DEFAULT 0,
      week_pts INTEGER NOT NULL DEFAULT 0,
      last_week INTEGER NOT NULL DEFAULT -1,
      last_pts INTEGER NOT NULL DEFAULT 0,
      claimed INTEGER NOT NULL DEFAULT -1
    );
    CREATE INDEX IF NOT EXISTS union_members_u ON union_members(union_id, joined);
    CREATE TABLE IF NOT EXISTS union_requests (
      union_id INTEGER NOT NULL REFERENCES unions(id) ON DELETE CASCADE,
      user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      created INTEGER NOT NULL,
      PRIMARY KEY (union_id, user_id)
    );
    CREATE TABLE IF NOT EXISTS union_weeks (
      union_id INTEGER NOT NULL REFERENCES unions(id) ON DELETE CASCADE,
      week INTEGER NOT NULL,
      pts INTEGER NOT NULL,
      PRIMARY KEY (union_id, week)
    );
    CREATE TABLE IF NOT EXISTS union_chat (
      n INTEGER PRIMARY KEY,
      union_id INTEGER NOT NULL REFERENCES unions(id) ON DELETE CASCADE,
      name TEXT NOT NULL,
      phrase INTEGER NOT NULL,
      created INTEGER NOT NULL
    );
    CREATE INDEX IF NOT EXISTS union_chat_u ON union_chat(union_id, n);
  `);

  const q = {
    union: db.prepare('SELECT * FROM unions WHERE id = ?'),
    byKey: db.prepare('SELECT id FROM unions WHERE name_key = ?'),
    add: db.prepare('INSERT INTO unions (name, name_key, emblem, color, open, created, week) VALUES (?, ?, ?, ?, ?, ?, ?)'),
    setWeek: db.prepare('UPDATE unions SET week = ?, week_pts = 0 WHERE id = ?'),
    addPts: db.prepare('UPDATE unions SET week_pts = week_pts + ?, total_pts = total_pts + ? WHERE id = ?'),
    archive: db.prepare('INSERT OR REPLACE INTO union_weeks (union_id, week, pts) VALUES (?, ?, ?)'),
    weekPts: db.prepare('SELECT pts FROM union_weeks WHERE union_id = ? AND week = ?'),
    drop: db.prepare('DELETE FROM unions WHERE id = ?'),
    member: db.prepare('SELECT * FROM union_members WHERE user_id = ?'),
    members: db.prepare(`SELECT m.*, p.name, p.rating, p.city_level FROM union_members m LEFT JOIN pvp_players p ON p.user_id = m.user_id
      WHERE m.union_id = ? ORDER BY m.leader DESC, m.week_pts DESC, m.joined ASC`),
    count: db.prepare('SELECT COUNT(*) AS n FROM union_members WHERE union_id = ?'),
    join: db.prepare('INSERT INTO union_members (user_id, union_id, leader, joined, week) VALUES (?, ?, ?, ?, ?)'),
    leave: db.prepare('DELETE FROM union_members WHERE user_id = ?'),
    oldest: db.prepare('SELECT user_id FROM union_members WHERE union_id = ? ORDER BY joined ASC LIMIT 1'),
    setLeader: db.prepare('UPDATE union_members SET leader = 1 WHERE user_id = ?'),
    rollMember: db.prepare('UPDATE union_members SET last_week = week, last_pts = week_pts, week = ?, week_pts = 0 WHERE user_id = ?'),
    memberPts: db.prepare('UPDATE union_members SET week_pts = week_pts + ? WHERE user_id = ?'),
    claim: db.prepare('UPDATE union_members SET claimed = ? WHERE user_id = ? AND claimed < ?'),
    list: db.prepare(`SELECT u.*, (SELECT COUNT(*) FROM union_members m WHERE m.union_id = u.id) AS n,
      (SELECT p.name FROM union_members m JOIN pvp_players p ON p.user_id = m.user_id WHERE m.union_id = u.id AND m.leader = 1) AS leader_name
      FROM unions u WHERE u.name_key LIKE ? ESCAPE '\\' ORDER BY u.week_pts DESC, u.total_pts DESC, u.id ASC LIMIT 30`),
    request: db.prepare('INSERT OR IGNORE INTO union_requests (union_id, user_id, created) VALUES (?, ?, ?)'),
    requests: db.prepare(`SELECT r.user_id, p.name, p.rating, p.city_level FROM union_requests r LEFT JOIN pvp_players p ON p.user_id = r.user_id
      WHERE r.union_id = ? ORDER BY r.created ASC LIMIT 30`),
    hasRequest: db.prepare('SELECT 1 AS y FROM union_requests WHERE union_id = ? AND user_id = ?'),
    dropRequest: db.prepare('DELETE FROM union_requests WHERE union_id = ? AND user_id = ?'),
    dropRequestsOf: db.prepare('DELETE FROM union_requests WHERE user_id = ?'),
    say: db.prepare('INSERT INTO union_chat (union_id, name, phrase, created) VALUES (?, ?, ?, ?)'),
    chat: db.prepare('SELECT n, name, phrase, created FROM union_chat WHERE union_id = ? ORDER BY n DESC LIMIT ?'),
    trimChat: db.prepare(`DELETE FROM union_chat WHERE union_id = ? AND n NOT IN (SELECT n FROM union_chat WHERE union_id = ? ORDER BY n DESC LIMIT ${CHAT_KEEP})`),
    nameOf: db.prepare('SELECT name FROM pvp_players WHERE user_id = ?'),
  };

  function tx(fn) {
    db.exec('BEGIN IMMEDIATE');
    try { const r = fn(); db.exec('COMMIT'); return r; } catch (e) { try { db.exec('ROLLBACK'); } catch (e2) { /* */ } throw e; }
  }
  const nameOf = uid => { pvpPlayer(uid); const r = q.nameOf.get(uid); return r ? r.name : '?'; };

  // новая неделя: очки прошлой — в архив союза, у участников — «прошлая неделя» (для награды)
  function rollUnion(u, cur) {
    if (u.week >= cur) return u;
    q.archive.run(u.id, u.week, u.week_pts);
    q.setWeek.run(cur, u.id);
    return q.union.get(u.id);
  }
  function rollMember(m, cur) {
    if (m.week >= cur) return m;
    q.rollMember.run(cur, m.user_id);
    return q.member.get(m.user_id);
  }

  // очки союзу и участнику (из боёв и друзей) — тихо, если союза нет
  function points(uid, n) {
    if (!(n > 0)) return;
    let m = q.member.get(uid);
    if (!m) return;
    const cur = weekAt(Date.now());
    tx(() => {
      let u = q.union.get(m.union_id);
      if (!u) return;
      u = rollUnion(u, cur);
      m = rollMember(m, cur);
      q.addPts.run(n, n, u.id);
      q.memberPts.run(n, uid);
    });
  }
  if (hooks) hooks.points = (uid, n) => { try { points(uid, n); } catch (e) { console.error('union points:', e); } };

  function cleanName(s) {
    const t = String(s || '').replace(/[\u0000-\u001f\u007f]/g, '').replace(/\s+/g, ' ').trim();
    if (t.length < 3 || t.length > 24) throw new Fail(400, 'Название союза — от 3 до 24 знаков');
    if (!NAME_RE.test(t) || !/\p{L}/u.test(t)) throw new Fail(400, 'В названии — только буквы, цифры, пробел и дефис');
    if (names.rude(t)) throw new Fail(400, 'Такое название не подойдёт — придумайте другое');
    return t;
  }

  // награда прошлой недели для участника: {week, tier, money, glory} или null
  function prizeOf(m, u) {
    if (!m || !u) return null;
    const last = m.last_week;
    if (last < 0 || m.last_pts <= 0 || m.claimed >= last) return null;
    const w = q.weekPts.get(u.id, last);
    const t = w ? tierOf(w.pts) : -1;
    if (t < 0) return null;
    return { week: last, tier: t + 1, pts: w.pts, money: GOALS[t].money, glory: GOALS[t].glory };
  }

  function unionOut(u, full, uid) {
    const now = Date.now();
    const cur = weekAt(now);
    const out = { id: u.id, name: u.name, emblem: u.emblem, color: u.color, open: !!u.open, week_pts: u.week >= cur ? u.week_pts : 0,
      total_pts: u.total_pts, members: q.count.get(u.id).n, max: MAX_MEMBERS };
    if (full) {
      out.list = q.members.all(u.id).map(m => ({ id: m.user_id, name: m.name || '?', leader: !!m.leader, week_pts: m.week >= cur ? m.week_pts : 0,
        rating: m.rating || 0, city_level: m.city_level || 0, me: m.user_id === uid }));
      out.chat = q.chat.all(u.id, 30).reverse().map(c => ({ name: c.name, text: PHRASES[c.phrase] || '…', phrase: c.phrase, t: Math.floor(c.created / 1000) }));
      out.goals = GOALS;
      out.ends_in = Math.max(0, Math.ceil((EPOCH + (cur + 1) * WEEK - now) / 1000));
    }
    return out;
  }

  function state(uid) {
    const cur = weekAt(Date.now());
    let m = q.member.get(uid);
    const out = { me: { name: nameOf(uid), in_union: !!m }, phrases: PHRASES, emblems: EMBLEMS, colors: COLORS, max: MAX_MEMBERS, goals: GOALS };
    if (!m) return out;
    let u = q.union.get(m.union_id);
    if (!u) { q.leave.run(uid); out.me.in_union = false; return out; }
    tx(() => { u = rollUnion(u, cur); m = rollMember(m, cur); });
    out.me.leader = !!m.leader;
    out.me.week_pts = m.week_pts;
    out.me.prize = prizeOf(m, u);
    out.union = unionOut(u, true, uid);
    if (m.leader && !u.open) out.requests = q.requests.all(u.id).map(r => ({ id: r.user_id, name: r.name || '?', rating: r.rating || 0, city_level: r.city_level || 0 }));
    return out;
  }

  function mustMember(uid) {
    const m = q.member.get(uid);
    if (!m) throw new Fail(409, 'Вы не в союзе');
    return m;
  }

  function leaveUnion(uid) {
    const m = q.member.get(uid);
    if (!m) return;
    q.leave.run(uid);
    if (q.count.get(m.union_id).n === 0) { q.drop.run(m.union_id); return; }
    if (m.leader) { const o = q.oldest.get(m.union_id); if (o) q.setLeader.run(o.user_id); }
  }

  /* ---------- адреса ---------- */

  routes['GET /api/union/state'] = (req) => {
    const a = auth(req);
    if (limited(`un:state:${a.userId}`, 60, 600e3)) throw new Fail(429, 'Слишком часто');
    return state(a.userId);
  };

  routes['GET /api/union/list'] = (req, url) => {
    const a = auth(req);
    if (limited(`un:list:${a.userId}`, 40, 600e3)) throw new Fail(429, 'Слишком часто');
    const k = nameKey(url.searchParams.get('q') || '');
    const like = k.replace(/[\\%_]/g, m => '\\' + m) + '%';
    const cur = weekAt(Date.now());
    return { list: q.list.all(like).map(u => Object.assign(unionOut(u, false, a.userId), { n: u.n, leader: u.leader_name || '?', week_pts: u.week >= cur ? u.week_pts : 0 })) };
  };

  routes['POST /api/union/create'] = async (req) => {
    const a = auth(req);
    if (limited(`un:create:${a.userId}`, 10, 3600e3)) throw new Fail(429, 'Слишком часто — подождите');
    const b = await json(req);
    const nm = cleanName(b.name);
    if (q.member.get(a.userId)) throw new Fail(409, 'Вы уже в союзе — сначала выйдите из него');
    if (q.byKey.get(nameKey(nm))) throw new Fail(409, 'Такое название уже занято');
    tx(() => {
      const r = q.add.run(nm, nameKey(nm), clamp(int(b.emblem), 0, EMBLEMS.length - 1), clamp(int(b.color), 0, COLORS - 1), b.open === false ? 0 : 1, Date.now(), weekAt(Date.now()));
      q.join.run(a.userId, Number(r.lastInsertRowid), 1, Date.now(), weekAt(Date.now()));
      q.dropRequestsOf.run(a.userId);
    });
    return state(a.userId);
  };

  routes['POST /api/union/join'] = async (req) => {
    const a = auth(req);
    if (limited(`un:join:${a.userId}`, 20, 600e3)) throw new Fail(429, 'Слишком часто');
    const b = await json(req);
    if (q.member.get(a.userId)) throw new Fail(409, 'Вы уже в союзе — сначала выйдите из него');
    const u = q.union.get(int(b.id));
    if (!u) throw new Fail(404, 'Такого союза нет');
    if (q.count.get(u.id).n >= MAX_MEMBERS) throw new Fail(409, 'В союзе нет мест');
    if (!u.open) {
      q.request.run(u.id, a.userId, Date.now());
      return Object.assign(state(a.userId), { requested: true });
    }
    tx(() => { q.join.run(a.userId, u.id, 0, Date.now(), weekAt(Date.now())); q.dropRequestsOf.run(a.userId); });
    q.say.run(u.id, nameOf(a.userId), 0, Date.now());
    return state(a.userId);
  };

  routes['POST /api/union/leave'] = async (req) => {
    const a = auth(req);
    if (limited(`un:leave:${a.userId}`, 20, 600e3)) throw new Fail(429, 'Слишком часто');
    mustMember(a.userId);
    tx(() => leaveUnion(a.userId));
    return state(a.userId);
  };

  // глава: принять или отклонить заявку, исключить
  routes['POST /api/union/accept'] = async (req) => {
    const a = auth(req);
    const b = await json(req);
    const m = mustMember(a.userId);
    if (!m.leader) throw new Fail(403, 'Это может только глава союза');
    const who = int(b.id);
    if (!q.hasRequest.get(m.union_id, who)) throw new Fail(404, 'Такой заявки нет');
    tx(() => {
      q.dropRequest.run(m.union_id, who);
      if (b.yes === false) return;
      if (q.member.get(who)) throw new Fail(409, 'Этот город уже в союзе');
      if (q.count.get(m.union_id).n >= MAX_MEMBERS) throw new Fail(409, 'В союзе нет мест');
      q.join.run(who, m.union_id, 0, Date.now(), weekAt(Date.now()));
      q.dropRequestsOf.run(who);
    });
    return state(a.userId);
  };

  routes['POST /api/union/kick'] = async (req) => {
    const a = auth(req);
    const b = await json(req);
    const m = mustMember(a.userId);
    if (!m.leader) throw new Fail(403, 'Это может только глава союза');
    const who = q.member.get(int(b.id));
    if (!who || who.union_id !== m.union_id || who.user_id === a.userId) throw new Fail(404, 'Такого участника нет');
    q.leave.run(who.user_id);
    return state(a.userId);
  };

  routes['POST /api/union/say'] = async (req) => {
    const a = auth(req);
    if (limited(`un:say:${a.userId}`, 6, 60e3)) throw new Fail(429, 'Не так часто');
    const b = await json(req);
    const m = mustMember(a.userId);
    const ph = int(b.phrase);
    if (ph < 0 || ph >= PHRASES.length) throw new Fail(400, 'Такой фразы нет');
    q.say.run(m.union_id, nameOf(a.userId), ph, Date.now());
    q.trimChat.run(m.union_id, m.union_id);
    return state(a.userId);
  };

  // награда прошлой недели — один раз
  routes['POST /api/union/prize'] = async (req) => {
    const a = auth(req);
    if (limited(`un:prize:${a.userId}`, 20, 600e3)) throw new Fail(429, 'Слишком часто');
    const st = state(a.userId);
    const pz = st.me.prize;
    if (!pz) return { prize: null, state: st };
    const took = Number(q.claim.run(pz.week, a.userId, pz.week).changes) > 0;
    return { prize: took ? pz : null, state: state(a.userId) };
  };

  return { points };
}

module.exports = { install, GOALS, PHRASES, EMBLEMS, MAX_MEMBERS, weekAt, tierOf };
