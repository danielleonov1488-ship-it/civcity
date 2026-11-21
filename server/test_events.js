'use strict';
// Локальный HTTP-тест. Каждое правило получает собственный город и неделю.
const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const { mkdirSync } = require('node:fs');
const path = require('node:path');
const { DatabaseSync } = require('node:sqlite');
const { RULES, enemyOf, scoreOf } = require('./events');
const { FORT_SNAPSHOT, replayPvp } = require('./legion_sim');

const DATA = process.env.TEST_DATA_DIR || path.join(__dirname, '..', '.work', 'srvtest_events', String(Date.now()));
const PORT = +process.env.TEST_PORT || 3016;
const API = `http://127.0.0.1:${PORT}/api`;
const DAY = 864e5;
const NOW = Date.UTC(2026, 10, 2, 12);
const AUTO = [[0, 'auto', true]];

function start(data, week) {
  return new Promise((resolve, reject) => {
    const boot = [
      'Date.now = () => Number(process.env.TEST_NOW);',
      'let seed = 0; require("node:crypto").randomInt = () => ++seed;',
      'require(process.argv[1]);',
    ].join(' ');
    const p = spawn(process.execPath, ['--disable-warning=ExperimentalWarning', '-e',
      boot, path.join(__dirname, 'index.js')], {
      env: { ...process.env, PORT: String(PORT), DATA_DIR: data, ORIGINS: '*', SMTP_HOST: '', SMTP_PASS: '',
        TEST_NOW: String(NOW), EVENT_WEEK_MS: String(7 * DAY), EVENT_EPOCH_MS: String(NOW - (7 * week + 1) * DAY) },
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    p.stdout.on('data', d => { if (/server on/.test(String(d))) resolve(p); });
    p.stderr.on('data', d => process.stderr.write('[srv] ' + d));
    p.on('error', reject);
    p.on('exit', c => reject(new Error('server exit ' + c)));
  });
}

const stop = p => new Promise(resolve => {
  if (p.exitCode !== null || p.signalCode !== null) return resolve();
  p.once('exit', resolve);
  p.kill();
});

async function call(method, route, body, token, status = 200) {
  const headers = {};
  if (token) headers.Authorization = 'Bearer ' + token;
  if (body !== undefined) headers['Content-Type'] = 'application/json';
  const reply = await fetch(API + route, { method, headers, body: JSON.stringify(body) });
  const result = await reply.json();
  assert.equal(reply.status, status, `${method} ${route}: ${JSON.stringify(result)}`);
  return result;
}

function fortCity() {
  const classes = ['legionary', 'cavalry', 'priest', 'archer', 'archer'];
  const items = [];
  const soldiers = classes.map((cls, place) => {
    const id = place + 1;
    const gear = {};
    for (const slot of ['weapon', 'offhand', 'helmet', 'armor']) {
      const item = { id: items.length + 1, on: id, cls, slot, tier: 10, rarity: 4 };
      gear[slot] = item.id;
      items.push(item);
    }
    return { id, cls, rank: 49, stars: 5, hero: place === 3, gear };
  });
  return {
    version: 2, level: 6, legion_v: 3, money: 9000, research: [], buildings: [],
    hero: { m: { pn: 'Гай Валерий', sx: 0, look: {} } },
    legion: {
      v: 3, fort: { roles_v: 1, plots: [{ b: 'hq', lv: 6 }, { b: 'barracks', lv: 10 }] },
      squad3: soldiers.map(s => s.id), perks: { oil: 3, testudo: 2 }, flags: { camp_open: true }, soldiers, items,
    },
  };
}

function fortSnapshot(city) {
  const squad = city.legion.soldiers.map((s, place) => ({
    sid: s.id, place, type: s.hero ? 'hero' : s.cls, level: s.rank + 1,
    ...(s.hero ? { unit: s.cls, hero_v: 3 } : {}),
  }));
  return { v: FORT_SNAPSHOT, squad, perks: city.legion.perks };
}

// Сдвигаем время начала только в БД теста. Так обе ветки проверки времени не зависят от скорости ПК.
function ageBattle(data, battle, seconds) {
  const db = new DatabaseSync(path.join(data, 'civcity.db'));
  try {
    const update = db.prepare('UPDATE event_battles SET created = ? WHERE token = ?');
    assert.equal(update.run(NOW - Math.ceil(seconds * 1000), battle).changes, 1);
  } finally {
    db.close();
  }
}

async function testWeek(rule, week) {
  const data = path.join(DATA, rule.id);
  mkdirSync(data, { recursive: true });
  const srv = await start(data, week);
  try {
    assert.equal((await call('GET', '/health')).events, true);
    const { token } = await call('POST', '/register', { email: 'fort@events.test', password: 'fort-test-pass' });
    const state = await call('GET', '/events/state', undefined, token);
    assert.equal(state.week, week);
    assert.equal(state.rule.id, rule.id);
    assert.equal(state.tiers.length, 3);
    assert.equal(state.me.tries_left, 5);
    assert.deepEqual(state.top, []);

    const city = fortCity();
    const snapshot = fortSnapshot(city);
    await call('PUT', '/save?game=rome2', { data: JSON.stringify(city), force: true }, token);
    const attack = (tier, squad = snapshot, status = 200) =>
      call('POST', '/events/trial/attack', { tier, snapshot: squad }, token, status);
    const report = bt => call('POST', '/events/trial/result', { battle: bt.battle, win: true, inputs: AUTO }, token);

    const cavalry = { ...snapshot, squad: [snapshot.squad[1]] };
    if (rule.types) {
      await attack(1, cavalry, 409);
      assert.equal((await call('GET', '/events/state', undefined, token)).me.tries_left, 5);
    }

    const first = await attack(1);
    assert.equal(first.rule.id, rule.id);
    assert.equal(first.tries_left, 4);
    assert.equal(first.attack.v, FORT_SNAPSHOT);
    assert.deepEqual(first.enemy, enemyOf(week, 1));
    const expectedPlaces = { infantry: [0], ranged: [3, 4], trio: [0, 1, 2] };
    assert.deepEqual(first.attack.squad.map(e => e.place), expectedPlaces[rule.id] || [0, 1, 2, 3, 4]);
    assert.deepEqual(first.attack.perks, rule.perks === false ? {} : snapshot.perks);
    for (const e of first.attack.squad) {
      const source = snapshot.squad[e.place];
      assert.equal(e.type, source.type);
      assert.equal(e.unit, source.unit);
      assert.equal(e.level, rule.maxlvl || 50);
      assert.equal(e.stats3.row, e.place < 3 ? 0 : 1);
      assert.ok(Number.isFinite(e.stats3.atk) && e.stats3.atk > 0 && e.stats3.hp > 0);
      assert.equal(e.sid, undefined);
    }
    if (rule.maxlvl) {
      // Казарма X, ранг 14, пять звёзд и оружие X, легендарное.
      assert.equal(first.attack.squad[0].stats3.atk, 182);
    }
    const replay = replayPvp(first.attack, first.enemy, first.seed, AUTO);
    assert.ok(replay.win, 'fully equipped fort wins the starter trial');
    const early = replay.time > 6;
    const immediate = await report(first);
    if (early) {
      assert.equal(immediate.accepted, false);
      assert.match(immediate.reason, /быстрее/);
      assert.equal(immediate.score, 0);
    } else {
      assert.equal(immediate.accepted, true);
      assert.equal(immediate.first, true);
    }

    const second = await attack(1);
    const replay2 = replayPvp(second.attack, second.enemy, second.seed, AUTO);
    assert.ok(replay2.win);
    ageBattle(data, second.battle, replay2.time / 3);
    const win = await report(second);
    assert.equal(win.accepted, true);
    assert.equal(win.win, true);
    assert.equal(win.score, scoreOf(1, replay2));
    assert.equal(win.first, early);
    assert.deepEqual(win.reward, early ? { money: 800, glory: 4 } : {});
    assert.equal(win.me.best, win.top[0].score);
    assert.equal(win.me.place, 1);
    assert.equal((await report(second)).repeat, true);

    const weakType = rule.id === 'ranged' ? 'archer' : 'legionary';
    const weak = await attack(3, { squad: [{ type: weakType, level: 1 }] });
    assert.equal(weak.attack.v, 1);
    assert.equal(weak.attack.squad[0].type, weakType);
    assert.equal(replayPvp(weak.attack, weak.enemy, weak.seed, AUTO).win, false);
    const rejected = await report(weak);
    assert.equal(rejected.accepted, false);
    assert.equal(rejected.score, 0);
    assert.match(rejected.reason, /не сходится/);
    if (!rule.types) {
      const cav = await attack(1, cavalry);
      assert.deepEqual(cav.attack.squad.map(e => e.type), ['cavalry']);
      assert.ok(Number.isFinite(replayPvp(cav.attack, cav.enemy, cav.seed, AUTO).time));
    } else {
      await attack(1);
    }
    assert.equal((await attack(1)).tries_left, 0);
    await attack(1, snapshot, 429);
    console.log(`OK   ${rule.id}: fort and legacy squads, replay, reward, score and daily limit`);
    return early;
  } finally {
    await stop(srv);
  }
}

(async () => {
  let failed = 0;
  let checkedEarly = false;
  for (const [week, rule] of RULES.entries()) {
    try {
      checkedEarly = await testWeek(rule, week) || checkedEarly;
    } catch (error) {
      failed++;
      console.error('FAIL ' + rule.id, error);
    }
  }
  if (!checkedEarly) {
    failed++;
    console.error('FAIL every winning replay completed in 6 seconds or less');
  }
  console.log(failed ? `${failed} FAILED` : 'ALL OK');
  process.exitCode = failed ? 1 : 0;
})();
