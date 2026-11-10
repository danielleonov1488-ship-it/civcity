'use strict';
// Проверка арены 2.0 (лиги и сезоны, server/pvp.js): node server/test_arena.js — свой сервер, своя новая папка данных.
// Сезон на проверке короткий (ARENA_LEN_MS): рейтинги и нападения задаём прямо в базе, ждём конца сезона и смотрим
// награды по высшей лиге, мягкий сброс рейтинга, зал славы (тройка), «забрать награду» один раз, таблицу сезона.
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const { DatabaseSync } = require('node:sqlite');
const pvp = require('./pvp');

const DATA = process.env.TEST_DATA_DIR || path.join(__dirname, '..', '.work', 'srvtest_arena', String(Date.now()));
const PORT = +process.env.TEST_PORT || 3014;
const API = `http://127.0.0.1:${PORT}/api`;
const LEN = 9000;
const EPOCH = Date.now() - 2000;          // сезон 1 кончается через ~7 с
let fails = 0;
const ok = (c, msg, extra) => { console.log((c ? 'OK   ' : 'FAIL ') + msg + (c || extra === undefined ? '' : '  ' + JSON.stringify(extra))); if (!c) fails++; };
const sleep = ms => new Promise(r => setTimeout(r, ms));

function start() {
  return new Promise((resolve, reject) => {
    const p = spawn(process.execPath, ['--disable-warning=ExperimentalWarning', path.join(__dirname, 'index.js')], {
      env: { ...process.env, PORT: String(PORT), DATA_DIR: DATA, ORIGINS: '*', SMTP_HOST: '', SMTP_PASS: '',
        ARENA_EPOCH_MS: String(EPOCH), ARENA_LEN_MS: String(LEN) },
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

(async () => {
  fs.mkdirSync(DATA, { recursive: true });
  ok(pvp.leagueOf(0) === 0 && pvp.leagueOf(99) === 0 && pvp.leagueOf(100) === 1 && pvp.leagueOf(700) === 4 && pvp.leagueOf(5000) === 5, 'leagues by rating');
  const srv = await start();
  let r;
  try {
    const tok = {}, uid = {};
    for (const n of ['a', 'b', 'c', 'd', 'e']) {
      r = await call('POST', '/register', { email: `${n}@arena.test`, password: 'secret' + n });
      tok[n] = r.data.token;
      r = await call('GET', '/pvp/state', undefined, tok[n]);
    }
    const ar = r.data.me.arena;
    ok(ar && ar.season === 1 && ar.league === 0 && ar.league_name === 'Тироны' && ar.next.name === 'Гастаты' && ar.next.at === 100 && ar.ends_in > 0 && ar.ends_in <= 8,
      `state.arena: season 1, Тироны, next Гастаты at 100, ends in ${ar && ar.ends_in} s`, ar);
    ok(ar.prize === null && Array.isArray(ar.hall) && ar.hall.length === 0, 'no prize and empty hall yet');
    ok(r.data.me.arena.min_att === 3, 'min attacks for a prize: 3');
    // рейтинги и нападения сезона — прямо в базе (бои проверяет test_pvp.js)
    const db = new DatabaseSync(path.join(DATA, 'civcity.db'));
    const ids = db.prepare('SELECT user_id, name FROM pvp_players ORDER BY user_id').all();
    ['a', 'b', 'c', 'd', 'e'].forEach((n, i) => { uid[n] = ids[i].user_id; });
    const set = db.prepare('UPDATE pvp_players SET rating = ?, peak = ?, s_att = ?, wins = ? WHERE user_id = ?');
    set.run(1040, 1100, 10, 30, uid.a);      // Легаты; лучший сезона
    set.run(720, 760, 6, 20, uid.b);         // Центурионы
    set.run(260, 480, 3, 9, uid.c);          // упал из Триариев в Принципы — награда по высшей (Триарии)
    set.run(900, 900, 2, 8, uid.d);          // нападений мало — без награды и вне зала
    set.run(50, 50, 0, 0, uid.e);            // не играл
    db.close();
    r = await call('GET', '/pvp/season', undefined, tok.b);
    ok(r.status === 200 && r.data.top.length === 4 && r.data.top[0].rating === 1040 && r.data.top[0].league === 5 && r.data.top[2].me && r.data.top[1].rating === 900,
      'season table: those who attacked this season, by rating', r.data && r.data.top);

    await sleep(Math.max(0, EPOCH + LEN - Date.now()) + 600);
    r = await call('GET', '/pvp/state', undefined, tok.a);
    const A = r.data.me;
    ok(A.arena.season === 2 && A.rating === Math.round(1040 * 0.6) && A.arena.peak === A.rating && A.arena.s_att === 0,
      `season 2: A rating soft-reset to ${A.rating}`, A.arena);
    ok(A.arena.prize && A.arena.prize.season === 1 && A.arena.prize.league === 5 && A.arena.prize.name === 'Легаты' && A.arena.prize.place === 1 &&
      A.arena.prize.money === 12000 && A.arena.prize.glory === 45 + 40, 'A prize: Легаты, 1st place, 12000 + 85 glory', A.arena.prize);
    ok(A.arena.hall.length === 3 && A.arena.hall.map(h => h.place).join() === '1,2,3' && A.arena.hall[0].rating === 1040 && A.arena.hall[2].rating === 260,
      'hall of season 1: top 3 who attacked enough (D excluded)', A.arena.hall);
    r = await call('GET', '/pvp/state', undefined, tok.c);
    ok(r.data.me.arena.prize && r.data.me.arena.prize.league === 3 && r.data.me.arena.prize.place === 3 && r.data.me.arena.prize.glory === 18 + 15,
      'C prize by peak league (Триарии) and 3rd place', r.data.me.arena.prize);
    r = await call('GET', '/pvp/state', undefined, tok.d);
    ok(r.data.me.arena.prize === null && r.data.me.rating === 540, 'D: too few attacks — no prize, rating still reset', r.data.me);
    r = await call('GET', '/pvp/state', undefined, tok.e);
    ok(r.data.me.arena.prize === null, 'E: did not play — no prize');
    r = await call('POST', '/pvp/prize', {}, tok.a);
    ok(r.status === 200 && r.data.prize && r.data.prize.money === 12000 && r.data.me.arena.prize === null, 'A takes the prize');
    r = await call('POST', '/pvp/prize', {}, tok.a);
    ok(r.status === 200 && r.data.prize === null, 'prize only once');
    r = await call('GET', '/pvp/season', undefined, tok.a);
    ok(r.data.top.length === 0, 'new season table is empty');
  } catch (e) {
    console.error(e);
    fails++;
  } finally {
    await stop(srv);
  }
  console.log(fails ? `${fails} FAILED` : 'ALL OK');
  process.exit(fails ? 1 : 0);
})();
