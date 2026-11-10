'use strict';
// Проверка союзов (server/unions.js): node server/test_unions.js — свой сервер, своя новая папка данных в .work.
// Создать (название по правилам), открытый союз — вступить сразу, закрытый — заявка и «принять»; места; готовые фразы;
// очки недели от друзей (подарок +2, «нравится» +1); глава уходит — главой старший; исключить; неделя на проверке
// короткая (UNION_WEEK_MS): награда по порогу — тем, кто принёс очки, один раз.
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const { DatabaseSync } = require('node:sqlite');

const DATA = process.env.TEST_DATA_DIR || path.join(__dirname, '..', '.work', 'srvtest_unions', String(Date.now()));
const PORT = +process.env.TEST_PORT || 3015;
const API = `http://127.0.0.1:${PORT}/api`;
const WEEK = 12000;
const EPOCH = Date.now() - 1000;
let fails = 0;
const ok = (c, msg, extra) => { console.log((c ? 'OK   ' : 'FAIL ') + msg + (c || extra === undefined ? '' : '  ' + JSON.stringify(extra))); if (!c) fails++; };
const sleep = ms => new Promise(r => setTimeout(r, ms));

function start() {
  return new Promise((resolve, reject) => {
    const p = spawn(process.execPath, ['--disable-warning=ExperimentalWarning', path.join(__dirname, 'index.js')], {
      env: { ...process.env, PORT: String(PORT), DATA_DIR: DATA, ORIGINS: '*', SMTP_HOST: '', SMTP_PASS: '',
        UNION_WEEK_MS: String(WEEK), UNION_EPOCH_MS: String(EPOCH) },
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
  const srv = await start();
  let r;
  try {
    const tok = {}, id = {};
    for (const n of ['a', 'b', 'c', 'd']) {
      r = await call('POST', '/register', { email: `${n}@unions.test`, password: 'secret' + n });
      tok[n] = r.data.token;
      await call('PUT', '/pvp/name', { name: { a: 'Аквилея', b: 'Брундизий', c: 'Капуя', d: 'Остия' }[n] }, tok[n]);
      await call('PUT', '/social/card', { card: { pop: 100, level: 3 } }, tok[n]);
    }
    r = await call('GET', '/health');
    ok(r.data.unions === true, 'health: unions');
    r = await call('GET', '/union/state', undefined, tok.a);
    ok(r.status === 200 && !r.data.me.in_union && r.data.phrases.length >= 8 && r.data.goals.length === 3, 'state: not in a union, phrases and goals');
    r = await call('POST', '/union/create', { name: 'хм', emblem: 1 }, tok.a);
    ok(r.status === 400, 'too short name → 400');
    r = await call('POST', '/union/create', { name: 'Волчья стая', emblem: 1, color: 3 }, tok.a);
    ok(r.status === 200 && r.data.me.in_union && r.data.me.leader && r.data.union.name === 'Волчья стая' && r.data.union.list.length === 1, 'A creates «Волчья стая» and leads it', r.data);
    const uA = r.data.union.id;
    r = await call('POST', '/union/create', { name: 'волчья  СТАЯ' }, tok.b);
    ok(r.status === 409, 'same name (case, spaces) → 409');
    r = await call('POST', '/union/create', { name: 'Орлы Тибра', open: false, emblem: 0 }, tok.c);
    ok(r.status === 200 && !r.data.union.open, 'C creates closed «Орлы Тибра»');
    const uC = r.data.union.id;
    r = await call('GET', '/union/list?q=' + encodeURIComponent('вол'), undefined, tok.b);
    ok(r.data.list.length === 1 && r.data.list[0].name === 'Волчья стая' && r.data.list[0].leader === 'Аквилея' && r.data.list[0].n === 1, 'list by name prefix with leader', r.data);
    r = await call('POST', '/union/join', { id: uA }, tok.b);
    ok(r.status === 200 && r.data.union.list.length === 2 && r.data.union.chat.some(c => c.name === 'Брундизий'), 'B joins the open union (greets in chat)');
    r = await call('POST', '/union/join', { id: uC }, tok.d);
    ok(r.status === 200 && r.data.requested && !r.data.me.in_union, 'D asks to join the closed union');
    r = await call('GET', '/union/state', undefined, tok.c);
    ok(r.data.requests && r.data.requests.length === 1 && r.data.requests[0].name === 'Остия', 'C sees the request');
    id.d = r.data.requests[0].id;
    r = await call('POST', '/union/accept', { id: id.d }, tok.b);
    ok(r.status === 409 || r.status === 403, 'not a leader cannot accept');
    r = await call('POST', '/union/accept', { id: id.d, yes: true }, tok.c);
    ok(r.status === 200 && r.data.union.list.length === 2, 'C accepts D');
    r = await call('POST', '/union/join', { id: uA }, tok.d);
    ok(r.status === 409, 'already in a union → 409');

    // фразы
    r = await call('POST', '/union/say', { phrase: 1 }, tok.a);
    ok(r.status === 200 && r.data.union.chat[r.data.union.chat.length - 1].text === 'Отличный бой!', 'A says a phrase');
    r = await call('POST', '/union/say', { phrase: 99 }, tok.a);
    ok(r.status === 400, 'unknown phrase → 400');

    // очки недели от друзей: B дарит A подарок (+2), A ставит «нравится» B (+1)
    r = await call('GET', '/social/find?name=' + encodeURIComponent('Аквилея'), undefined, tok.b);
    id.a = r.data.list[0].id;
    r = await call('GET', '/social/find?name=' + encodeURIComponent('Брундизий'), undefined, tok.a);
    id.b = r.data.list[0].id;
    await call('POST', '/social/gift', { id: id.a, kind: 'cat' }, tok.b);
    await call('POST', '/social/like', { id: id.b }, tok.a);
    r = await call('GET', '/union/state', undefined, tok.a);
    ok(r.data.union.week_pts === 3 && r.data.me.week_pts === 1 && r.data.union.list.find(m => m.name === 'Брундизий').week_pts === 2, 'week points: gift +2, like +1', r.data.union);

    // доберём очки до первого порога прямо в базе (бои проверяет test_pvp.js), ждём новую неделю
    const db = new DatabaseSync(path.join(DATA, 'civcity.db'));
    db.prepare('UPDATE unions SET week_pts = 70 WHERE id = ?').run(uA);
    db.close();
    await sleep(Math.max(0, EPOCH + WEEK - Date.now()) + 600);
    r = await call('GET', '/union/state', undefined, tok.a);
    ok(r.data.union.week_pts === 0 && r.data.me.prize && r.data.me.prize.tier === 1 && r.data.me.prize.money === 1000 && r.data.me.prize.pts === 70,
      'new week: A has the tier-1 prize', r.data.me);
    r = await call('POST', '/union/prize', {}, tok.a);
    ok(r.data.prize && r.data.prize.glory === 5, 'A takes the prize');
    r = await call('POST', '/union/prize', {}, tok.a);
    ok(r.data.prize === null, 'only once');
    r = await call('GET', '/union/state', undefined, tok.c);
    ok(!r.data.me.prize, 'C (union under the goal) — no prize');

    // глава уходит — главой становится старший; исключить
    r = await call('POST', '/union/leave', {}, tok.a);
    ok(r.status === 200 && !r.data.me.in_union, 'A leaves');
    r = await call('GET', '/union/state', undefined, tok.b);
    ok(r.data.me.leader && r.data.union.list.length === 1, 'B becomes the leader');
    r = await call('POST', '/union/kick', { id: id.d }, tok.c);
    ok(r.status === 200 && r.data.union.list.length === 1, 'C kicks D');
    r = await call('POST', '/union/leave', {}, tok.b);
    r = await call('GET', '/union/list?q=', undefined, tok.a);
    ok(r.data.list.length === 1 && r.data.list[0].name === 'Орлы Тибра', 'empty union disappears');
  } catch (e) {
    console.error(e);
    fails++;
  } finally {
    await stop(srv);
  }
  console.log(fails ? `${fails} FAILED` : 'ALL OK');
  process.exit(fails ? 1 : 0);
})();
