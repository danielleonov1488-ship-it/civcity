'use strict';
/* События недели (docs/ONLINE_V2.md §3). Неделя — WEEK от EPOCH (понедельник 2.11.2026, 00:00 UTC), у всех одна и та же.

   Испытание недели (здесь, на сервере): бой Легиона с отрядом, который сервер собирает по номеру недели (у всех один и
   тот же), по особому правилу недели (RULES: «только пехота», «без умений»…). Три сложности (TIERS) — у каждой своя
   сила врага и награда за первую победу на ней за неделю. Попыток — TRIES в сутки. Очки: победа — 1000 × сложность +
   100 за каждого вернувшегося + до 300 за здоровье + до 360 за скорость; поражение — 0. Лучший счёт недели — в таблице,
   тройка прошлой недели — в зале славы. Как бои с городами: отряд игрока сверяется с городом в облаке (checkSquad из
   pvp.js), правило применяет сервер (клиент воюет ровно тем отрядом, что вернул сервер), победу сервер повторяет сам
   (legion_sim.js) — засчитывается итог повтора.
   Нашествие варваров и подземелья — бои без сервера (godot/scripts/legion_events.gd), по тому же номеру недели. */

const crypto = require('crypto');
const { replayPvp, cleanInputs } = require('./legion_sim');
const { unitStats, power, snapPower, noHero } = require('./pvp');

const WEEK = +process.env.EVENT_WEEK_MS || 7 * 864e5;
const EPOCH = +process.env.EVENT_EPOCH_MS || Date.UTC(2026, 10, 2);
const TRIES = 5;
const BATTLE_TTL = 30 * 60e3;
const MAX_SPEED = 3;
const MAX_LEVEL = 40;
const RULES = [
  { id: 'infantry', name: 'Только пехота', text: 'В бой идут только легионеры и копейщики (герой — легионером).', types: ['legionary', 'spearman'] },
  { id: 'noperks', name: 'Без умений', text: 'Умения в этом бою не действуют: всё решают бойцы.', perks: false },
  { id: 'ranged', name: 'Стрелы и машины', text: 'В бой идут только лучники, баллисты и катапульты.', types: ['archer', 'ballista', 'catapult'] },
  { id: 'lvl15', name: 'Молодые бойцы', text: 'Бойцы не выше 15 уровня — победит умение, а не уровни.', maxlvl: 15 },
  { id: 'trio', name: 'Трое против всех', text: 'В отряде только трое первых бойцов.', max: 3 },
];
const TIERS = [
  { n: 1, name: 'Испытание', power: 800, money: 800, glory: 4 },
  { n: 2, name: 'Серьёзное испытание', power: 2400, money: 2000, glory: 10 },
  { n: 3, name: 'Испытание героев', power: 6000, money: 4500, glory: 22 },
];

const int = v => (Number.isFinite(+v) ? Math.trunc(+v) : 0);
const num = v => (Number.isFinite(+v) ? +v : 0);
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const weekAt = t => Math.max(0, Math.floor((t - EPOCH) / WEEK));
const dayAt = t => Math.floor(t / 864e5);
const ruleOf = w => RULES[w % RULES.length];

function rng(seed) {
  let s = seed >>> 0 || 1;
  return () => { s ^= s << 13; s >>>= 0; s ^= s >>> 17; s ^= s << 5; s >>>= 0; return s / 4294967296; };
}

// враг испытания: по номеру недели и сложности — у всех один и тот же
function enemyOf(week, tier) {
  const T = TIERS[tier - 1];
  const rnd = rng(week * 7919 + tier * 104729 + 17);
  const pool = ['legionary', 'legionary', 'spearman', 'archer', 'archer', 'ballista', 'catapult'];
  const n = [4, 5, 7][tier - 1];
  const types = Array.from({ length: n }, () => pool[Math.floor(rnd() * pool.length)]);
  const pw = (t, l) => power(unitStats(t, l, 0, 0));
  let best = 1, diff = Infinity;
  for (let L = 1; L <= MAX_LEVEL; L++) {
    const d = Math.abs(types.reduce((a, t) => a + pw(t, L), 0) - T.power);
    if (d < diff) { diff = d; best = L; }
  }
  const perks = tier >= 2 ? { oil: tier - 1, testudo: tier - 1 } : {};
  const snap = { v: 1, squad: types.map(t => ({ type: t, level: best })), perks, atk_b: 0, hp_b: 0 };
  return snap;
}

// правило недели — на проверенный сервером отряд
function applyRule(rule, snap) {
  let s = noHero(snap);
  let squad = Array.isArray(s.squad) ? s.squad.slice() : [];
  if (rule.types) squad = squad.filter(e => e && rule.types.includes(e.type));
  if (rule.maxlvl) squad = squad.map(e => Object.assign({}, e, { level: Math.min(int(e.level) || 1, rule.maxlvl) }));
  if (rule.max) squad = squad.slice(0, rule.max);
  return { v: 1, squad, perks: rule.perks === false ? {} : Object.assign({}, s.perks || {}), atk_b: num(s.atk_b), hp_b: num(s.hp_b) };
}

function scoreOf(tier, r) {
  if (!r || !r.win) return 0;
  return 1000 * tier + 100 * int(r.alive) + Math.round(300 * clamp(num(r.hp_left), 0, 1)) + Math.round(2 * Math.max(0, 180 - num(r.time)));
}

function install({ db, routes, auth, json, limited, Fail, pvpPlayer, checkSquad, facts, hooks }) {
  db.exec(`
    CREATE TABLE IF NOT EXISTS event_battles (
      token TEXT PRIMARY KEY,
      user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      week INTEGER NOT NULL, tier INTEGER NOT NULL,
      att_snap TEXT NOT NULL, def_snap TEXT NOT NULL, seed INTEGER NOT NULL,
      created INTEGER NOT NULL, status TEXT NOT NULL DEFAULT 'open', score INTEGER
    );
    CREATE TABLE IF NOT EXISTS event_scores (
      week INTEGER NOT NULL,
      user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      best INTEGER NOT NULL DEFAULT 0, best_tier INTEGER NOT NULL DEFAULT 0,
      tries_day INTEGER NOT NULL DEFAULT 0, tries_n INTEGER NOT NULL DEFAULT 0,
      won INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (week, user_id)
    );
    CREATE INDEX IF NOT EXISTS event_scores_best ON event_scores(week, best);
  `);
  const q = {
    row: db.prepare('SELECT * FROM event_scores WHERE week = ? AND user_id = ?'),
    addRow: db.prepare('INSERT OR IGNORE INTO event_scores (week, user_id) VALUES (?, ?)'),
    tries: db.prepare('UPDATE event_scores SET tries_day = ?, tries_n = ? WHERE week = ? AND user_id = ?'),
    best: db.prepare('UPDATE event_scores SET best = MAX(best, ?), best_tier = CASE WHEN ? > best THEN ? ELSE best_tier END, won = won | ? WHERE week = ? AND user_id = ?'),
    top: db.prepare(`SELECT s.user_id, s.best, s.best_tier, p.name FROM event_scores s LEFT JOIN pvp_players p ON p.user_id = s.user_id
      WHERE s.week = ? AND s.best > 0 ORDER BY s.best DESC, s.user_id ASC LIMIT ?`),
    place: db.prepare('SELECT COUNT(*) AS n FROM event_scores WHERE week = ? AND best > ?'),
    addBattle: db.prepare('INSERT INTO event_battles (token, user_id, week, tier, att_snap, def_snap, seed, created) VALUES (?, ?, ?, ?, ?, ?, ?, ?)'),
    battle: db.prepare('SELECT * FROM event_battles WHERE token = ?'),
    finish: db.prepare("UPDATE event_battles SET status = ?, score = ? WHERE token = ? AND status = 'open'"),
  };

  function row(uid, w) {
    q.addRow.run(w, uid);
    return q.row.get(w, uid);
  }
  function triesLeft(r, now) {
    return r.tries_day === dayAt(now) ? Math.max(0, TRIES - r.tries_n) : TRIES;
  }
  const topOf = (w, n) => q.top.all(w, n).map((r, i) => ({ place: i + 1, name: r.name || '?', score: r.best, tier: r.best_tier }));

  function state(uid) {
    const now = Date.now(), w = weekAt(now);
    pvpPlayer(uid);
    const r = row(uid, w);
    const rule = ruleOf(w);
    return {
      week: w, ends_in: Math.max(0, Math.ceil((EPOCH + (w + 1) * WEEK - now) / 1000)),
      rule: { id: rule.id, name: rule.name, text: rule.text },
      tiers: TIERS.map(t => ({ n: t.n, name: t.name, power: snapPower(enemyOf(w, t.n)), money: t.money, glory: t.glory, won: !!(r.won & (1 << t.n)) })),
      me: { best: r.best, best_tier: r.best_tier, tries_left: triesLeft(r, now), tries: TRIES, place: r.best > 0 ? q.place.get(w, r.best).n + 1 : 0 },
      top: topOf(w, 10), hall: topOf(w - 1, 3),
    };
  }

  routes['GET /api/events/state'] = (req) => {
    const a = auth(req);
    if (limited(`ev:state:${a.userId}`, 60, 600e3)) throw new Fail(429, 'Слишком часто');
    return state(a.userId);
  };

  routes['POST /api/events/trial/attack'] = async (req) => {
    const a = auth(req);
    if (limited(`ev:att:${a.userId}`, 20, 600e3)) throw new Fail(429, 'Слишком часто');
    const b = await json(req);
    const tier = clamp(int(b.tier), 1, TIERS.length);
    const now = Date.now(), w = weekAt(now);
    const f = facts(a.userId);
    if (f && !f.legion) throw new Fail(409, 'Легион ещё не собран');
    const c = checkSquad(f, b.snapshot);
    const att = applyRule(ruleOf(w), c.snap);
    if (!att.squad.length) throw new Fail(409, `Правило недели «${ruleOf(w).name}»: в вашем отряде нет подходящих бойцов. ${ruleOf(w).text}`);
    const r = row(a.userId, w);
    const left = triesLeft(r, now);
    if (left <= 0) throw new Fail(429, 'Попытки на сегодня кончились — завтра снова');
    const def = enemyOf(w, tier);
    const seed = crypto.randomInt(1, 0xffffff);
    const token = crypto.randomBytes(18).toString('base64url');
    q.tries.run(dayAt(now), r.tries_day === dayAt(now) ? r.tries_n + 1 : 1, w, a.userId);
    q.addBattle.run(token, a.userId, w, tier, JSON.stringify(att), JSON.stringify(def), seed, now);
    return { battle: token, seed, tier, enemy: def, attack: att, rule: ruleOf(w), tries_left: left - 1, name: `${TIERS[tier - 1].name}: «${ruleOf(w).name}»` };
  };

  routes['POST /api/events/trial/result'] = async (req) => {
    const a = auth(req);
    if (limited(`ev:res:${a.userId}`, 30, 600e3)) throw new Fail(429, 'Слишком часто');
    const b = await json(req);
    const bt = q.battle.get(String(b.battle || ''));
    if (!bt || bt.user_id !== a.userId) throw new Fail(404, 'Такого боя нет');
    const now = Date.now();
    if (bt.status !== 'open') return Object.assign(state(a.userId), { repeat: true, score: bt.score || 0, accepted: bt.status === 'done' });
    let score = 0, note = '', rp = null;
    if (now - bt.created > BATTLE_TTL) note = 'бой не доложен вовремя';
    else if (b.win && !b.retreat) {
      const inputs = cleanInputs(b.inputs);
      try { rp = inputs ? replayPvp(JSON.parse(bt.att_snap), JSON.parse(bt.def_snap), bt.seed, inputs) : null; } catch (e) { rp = null; }
      if (!rp) note = 'бой не повторить';
      else if (!rp.win) note = 'итог не сходится с боем';
      else if (now - bt.created < (rp.time / MAX_SPEED - 2) * 1000) note = 'бой закончился быстрее, чем его можно досмотреть';
      else score = scoreOf(bt.tier, rp);
    }
    const r = row(a.userId, bt.week);
    const first = score > 0 && !(r.won & (1 << bt.tier));
    q.finish.run(note ? 'rejected' : 'done', score, bt.token);
    if (score > 0) q.best.run(score, score, bt.tier, 1 << bt.tier, bt.week, a.userId);
    if (score > 0 && hooks) hooks.points(a.userId, 2 * bt.tier);       // очки союза: победа в испытании
    const T = TIERS[bt.tier - 1];
    return Object.assign(state(a.userId), { accepted: !note, reason: note ? 'Бой не засчитан: ' + note : '', win: score > 0, score,
      reward: first ? { money: T.money, glory: T.glory } : {}, first });
  };

  return { state };
}

module.exports = { install, RULES, TIERS, enemyOf, applyRule, scoreOf, weekAt, ruleOf };
