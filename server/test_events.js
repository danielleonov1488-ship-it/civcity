'use strict';
// Проверка событий недели (server/events.js): node server/test_events.js — свой сервер, своя новая папка данных.
// Правило недели на отряд (сверка с облаком), враг недели один на всех, попытки в сутки, победу сервер повторяет сам
// (тест считает тот же бой у себя), слишком быстрый итог не засчитан, награда за первую победу на сложности, таблица.
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const sim = require('./legion_sim');
const ev = require('./events');

const DATA = process.env.TEST_DATA_DIR || path.join(__dirname, '..', '.work', 'srvtest_events', String(Date.now()));
const PORT = +process.env.TEST_PORT || 3016;
const API = `http://127.0.0.1:${PORT}/api`;
let fails = 0;
const ok = (c, msg, extra) => { console.log((c ? 'OK   ' : 'FAIL ') + msg + (c || extra === undefined ? '' : '  ' + JSON.stringify(extra))); if (!c) fails++; };
const sleep = ms => new Promise(r => setTimeout(r, ms));

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
async function call(method, p, body, token) {
  const headers = {};
  if (token) headers.Authorization = 'Bearer ' + token;
  let b;
  if (body !== undefined) { headers['Content-Type'] = 'application/json'; b = JSON.stringify(body); }
  const r = await fetch(API + p, { method, headers, body: b });
  let data = null;
  try { data = await r.json(); } catch (e) { /* */ }
  return { status: r.status, data };
}
function city({ level, buildings, levels, progress = 40 }) {
  return JSON.stringify({ version: 2, money: 9000, day: 30, level, research: ['legion'], next_id: buildings.length + 1,
    buildings: buildings.map((t, i) => ({ id: i + 1, type: t, tier: 1, x: 100 + i * 4, z: 90, pop: 0 })),
    legion: { v: 1, levels, upg: {}, squad: [], defense: [], perks: { oil: 3, testudo: 2 }, progress, built: [], glory: 10 } });
}

(async () => {
  fs.mkdirSync(DATA, { recursive: true });
  // правило и враг — чистые функции
  const w = ev.weekAt(Date.now());
  const rule = ev.ruleOf(w);
  ok(ev.enemyOf(w, 1).squad.length === 4 && JSON.stringify(ev.enemyOf(w, 2)) === JSON.stringify(ev.enemyOf(w, 2)), 'week enemy: deterministic, 4 units on tier 1');
  const r0 = ev.applyRule({ id: 'infantry', types: ['legionary', 'spearman'] }, { squad: [{ type: 'hero', level: 9, city: 3, kit: 1 }, { type: 'archer', level: 5 }, { type: 'spearman', level: 4 }], perks: { oil: 2 } });
  ok(r0.squad.length === 2 && r0.squad[0].type === 'legionary' && r0.squad[0].level === 9 && r0.perks.oil === 2, 'rule «infantry»: hero → legionary, archer dropped', r0);
  ok(ev.applyRule({ perks: false }, { squad: [{ type: 'archer', level: 3 }], perks: { oil: 3 } }).perks.oil === undefined, 'rule «no perks»');
  ok(ev.applyRule({ max: 3 }, { squad: [1, 2, 3, 4].map(() => ({ type: 'legionary', level: 2 })) }).squad.length === 3, 'rule «trio»');
  const srv = await start();
  let r;
  try {
    r = await call('POST', '/register', { email: 'a@events.test', password: 'secreta' });
    const tok = r.data.token;
    r = await call('GET', '/health');
    ok(r.data.events === true, 'health: events');
    r = await call('GET', '/events/state', undefined, tok);
    ok(r.status === 200 && r.data.rule.id === rule.id && r.data.tiers.length === 3 && r.data.me.tries_left === 5 && r.data.top.length === 0,
      `state: rule «${r.data && r.data.rule.name}», 3 tiers, 5 tries`, r.data);
    const all = ['barracks', 'range', 'spearcamp', 'ballistae', 'catapults'];
    r = await call('PUT', '/save?game=rome2', { data: city({ level: 6, buildings: all, levels: { legionary: 20, archer: 20, spearman: 20, ballista: 20, catapult: 20 } }), force: true }, tok);
    ok(r.status === 200, 'cloud city with a strong legion');
    const snap = { squad: [['legionary', 25], ['archer', 20], ['spearman', 20], ['ballista', 20], ['catapult', 20], ['archer', 20], ['legionary', 20]].map(([type, level]) => ({ type, level })), perks: { oil: 3, testudo: 2 } };
    r = await call('POST', '/events/trial/attack', { tier: 1, snapshot: snap }, tok);
    ok(r.status === 200 && r.data.battle && r.data.enemy.squad.length === 4 && r.data.attack.squad.every(e => e.level <= 20) && r.data.tries_left === 4,
      'attack tier 1: battle, week enemy, squad clamped to cloud levels and the rule applied', r.data && Object.assign({}, r.data, { enemy: undefined }));
    const A = r.data;
    const inputs = [[0, 'auto', true]];
    const rp = sim.replayPvp(A.attack, A.enemy, A.seed, inputs);
    ok(rp && rp.win, `test replays the same battle: win in ${rp && rp.time.toFixed(1)} s`);
    // слишком рано — не засчитан
    r = await call('POST', '/events/trial/result', { battle: A.battle, win: true, inputs }, tok);
    const early = (rp.time / 3 - 2) > 0.5;
    if (early) ok(r.data.accepted === false && r.data.score === 0 && /быстрее/.test(r.data.reason), 'too fast → not counted', r.data);
    else ok(r.data.accepted && r.data.score > 1000, 'short battle counted', r.data);
    // второй бой — честно ждём
    r = await call('POST', '/events/trial/attack', { tier: 1, snapshot: snap }, tok);
    const B = r.data;
    const rp2 = sim.replayPvp(B.attack, B.enemy, B.seed, inputs);
    await sleep(Math.max(0, (rp2.time / 3 - 2) * 1000) + 300);
    r = await call('POST', '/events/trial/result', { battle: B.battle, win: true, inputs }, tok);
    ok(r.data.accepted && r.data.win && r.data.score === ev.scoreOf(1, rp2) && r.data.score > 1000, `win counted: ${r.data.score} points`, r.data);
    const firstReward = early ? (r.data.reward.money === 800 && r.data.first) : true;
    ok(firstReward, 'first win on tier 1 this week: 800 denarii', r.data.reward);
    ok(r.data.me.best === r.data.score && r.data.top.length === 1 && r.data.top[0].score === r.data.score && r.data.me.place === 1, 'best score and table');
    r = await call('POST', '/events/trial/result', { battle: B.battle, win: true, inputs }, tok);
    ok(r.data.repeat === true, 'same battle again → repeat');
    // сочинённая победа — не сходится
    r = await call('POST', '/events/trial/attack', { tier: 3, snapshot: { squad: [{ type: 'legionary', level: 1 }] } }, tok);
    const C = r.data;
    const rp3 = sim.replayPvp(C.attack, C.enemy, C.seed, []);
    await sleep(500);
    r = await call('POST', '/events/trial/result', { battle: C.battle, win: true, inputs: [] }, tok);
    ok(rp3 && !rp3.win && r.data.accepted === false && r.data.score === 0, 'fake win of a weak squad → not counted', r.data.reason);
    // попытки
    r = await call('POST', '/events/trial/attack', { tier: 1, snapshot: snap }, tok);
    r = await call('POST', '/events/trial/attack', { tier: 1, snapshot: snap }, tok);
    ok(r.status === 200 && r.data.tries_left === 0, 'fifth try of the day is the last');
    r = await call('POST', '/events/trial/attack', { tier: 1, snapshot: snap }, tok);
    ok(r.status === 429, 'five tries a day', r.data);
  } catch (e) {
    console.error(e);
    fails++;
  } finally {
    await stop(srv);
  }
  console.log(fails ? `${fails} FAILED` : 'ALL OK');
  process.exit(fails ? 1 : 0);
})();
