'use strict';
// Проверка «Друзей и гостей» (server/social.js): node server/test_social.js — свой сервер, своя новая папка данных в .work.
// Карточка города (чистка полей), поиск и друзья по названию, гости (сначала друзья), «гости побывали» (только из
// выданного списка, раз в сутки на пару), подарки (лимиты, забрать один раз), «в гости» (город из облака), «Нравится».
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');

const DATA = process.env.TEST_DATA_DIR || path.join(__dirname, '..', '.work', 'srvtest_social', String(Date.now()));
const PORT = +process.env.TEST_PORT || 3013;
const API = `http://127.0.0.1:${PORT}/api`;
let fails = 0;
const ok = (c, msg, extra) => { console.log((c ? 'OK   ' : 'FAIL ') + msg + (c || extra === undefined ? '' : '  ' + JSON.stringify(extra))); if (!c) fails++; };

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
const card = (pop, extra = {}) => Object.assign({ pop, level: 4, rank: 'Посёлок', title: 'Муниципий', fame: 120, beauty: 40, day: 33,
  hero: 'Постумия Агриппина', cats: 2, inns: 1, sights: ['Арка', 'Форум'] }, extra);

(async () => {
  fs.mkdirSync(DATA, { recursive: true });
  const srv = await start();
  let r;
  try {
    const tok = {}, name = {}, id = {};
    for (const n of ['a', 'b', 'c', 'd']) {
      r = await call('POST', '/register', { email: `${n}@social.test`, password: 'secret' + n });
      tok[n] = r.data.token;
    }
    ok(tok.a && tok.b && tok.c && tok.d, 'four players registered');
    r = await call('GET', '/social/state', undefined, null);
    ok(r.status === 401, 'state without login → 401');
    for (const n of ['a', 'b', 'c', 'd']) {
      r = await call('GET', '/social/state', undefined, tok[n]);
      name[n] = r.data && r.data.me.name;
    }
    ok(r.status === 200 && !!name.d && Array.isArray(r.data.guests) && r.data.me.gifts_left === 3, `state: name «${name.d}», 3 gifts`, r.data);
    // названия — как в боях (общие); зададим свои, чтобы искать
    for (const [n, nm] of [['a', 'Аквилея Новая'], ['b', 'Брундизий'], ['c', 'Капуя Малая']]) {
      r = await call('PUT', '/pvp/name', { name: nm }, tok[n]);
      name[n] = nm;
    }
    ok(r.status === 200 && r.data.me.name === 'Капуя Малая', 'city names set through /pvp/name');

    // карточки
    r = await call('PUT', '/social/card', { card: card(310, { hero: 'x'.repeat(100), sights: ['А', 'Б', 'В', 'Г', 'Д', 'Е', 'Ж', 'З'], evil: 1 }) }, tok.a);
    ok(r.status === 200, 'card A published');
    r = await call('PUT', '/social/card', { card: 'nope' }, tok.a);
    ok(r.status === 400, 'bad card → 400');
    for (const n of ['b', 'c']) await call('PUT', '/social/card', { card: card(100 + n.charCodeAt(0)) }, tok[n]);
    r = await call('GET', '/social/state', undefined, tok.a);
    const ca = r.data.me.card;
    ok(ca && ca.hero.length === 40 && ca.sights.length === 6 && ca.evil === undefined && ca.pop === 310, 'card cleaned: hero 40 chars, 6 sights, unknown fields dropped', ca);

    // поиск и друзья
    r = await call('GET', '/social/find?name=' + encodeURIComponent('капуя'), undefined, tok.a);
    ok(r.status === 200 && r.data.list.length === 1 && r.data.list[0].name === 'Капуя Малая' && r.data.list[0].card.pop > 0, 'find by name prefix (case-insensitive)', r.data);
    id.c = r.data.list[0].id;
    r = await call('POST', '/social/friend', { name: 'брундизий' }, tok.a);
    ok(r.status === 200 && r.data.friends.length === 1 && r.data.friends[0].name === 'Брундизий' && r.data.friends[0].live, 'A adds B by name', r.data);
    id.b = r.data.friends[0].id;
    r = await call('POST', '/social/friend', { name: 'Нет Такого' }, tok.a);
    ok(r.status === 404, 'unknown city → 404');
    r = await call('POST', '/social/friend', { name: 'Аквилея Новая' }, tok.a);
    ok(r.status === 400, 'cannot friend yourself');
    r = await call('POST', '/social/friend', { id: id.c }, tok.a);
    ok(r.status === 200 && r.data.friends.length === 2 && r.data.me.friends === 2, 'A adds C by id');
    r = await call('GET', '/social/state', undefined, tok.b);
    ok(r.data.me.followers === 1, 'B sees one follower');
    id.a = null;

    // гости: друзья первыми; D без карточки не приезжает
    r = await call('GET', '/social/state', undefined, tok.a);
    const g = r.data.guests;
    ok(g.length === 2 && g.every(x => x.friend) && g.map(x => x.name).sort().join() === 'Брундизий,Капуя Малая' && g[0].hero === 'Постумия Агриппина',
      'guests of A: friends B and C (D has no card)', g);
    r = await call('GET', '/social/state', undefined, tok.d);
    ok(r.data.guests.length === 3 && r.data.guests.every(x => !x.friend), 'guests of D: random live cities', r.data.guests);
    id.a = r.data.guests.find(x => x.name === 'Аквилея Новая').id;

    // «гости побывали»: только из выданного списка, пара — раз в сутки
    r = await call('POST', '/social/visited', { ids: [id.b, id.c, 999] }, tok.a);
    ok(r.status === 200 && r.data.counted === 2, 'A: guests from B and C counted (unknown id ignored)', r.data);
    r = await call('POST', '/social/visited', { ids: [id.b] }, tok.a);
    ok(r.data.counted === 0, 'same pair again today → not counted');
    r = await call('GET', '/social/state', undefined, tok.b);
    ok(r.data.me.visits === 1 && r.data.me.new_visits === 1, 'B: one visit, new');
    r = await call('GET', '/social/state?ack=1', undefined, tok.b);
    r = await call('GET', '/social/state', undefined, tok.b);
    ok(r.data.me.new_visits === 0 && r.data.me.visits === 1, 'B: ack clears "new"');

    // подарки
    r = await call('POST', '/social/gift', { id: id.b, kind: 'cat' }, tok.a);
    ok(r.status === 200 && r.data.gifts_left === 2, 'A sends B a cat', r.data);
    r = await call('POST', '/social/gift', { id: id.b, kind: 'statue' }, tok.a);
    ok(r.status === 409, 'second gift to the same city today → 409');
    r = await call('POST', '/social/gift', { id: id.c, kind: 'dragon' }, tok.a);
    ok(r.status === 400, 'unknown gift → 400');
    r = await call('POST', '/social/gift', { id: id.c, kind: 'fountain' }, tok.a);
    r = await call('POST', '/social/gift', { id: (await call('GET', '/social/find?name=' + encodeURIComponent(name.d.slice(0, 5)), undefined, tok.a)).data.list.length ? 0 : 0, kind: 'bench' }, tok.a);
    ok(r.status === 404, 'gift to a missing city → 404');
    r = await call('GET', '/social/state', undefined, tok.b);
    const inbox = r.data.inbox;
    ok(inbox.length === 1 && inbox[0].kind === 'cat' && inbox[0].from === 'Аквилея Новая' && inbox[0].name === 'кошка', 'B inbox: cat from A', inbox);
    r = await call('POST', '/social/claim', { ids: [inbox[0].id] }, tok.b);
    ok(r.data.claimed.length === 1 && r.data.claimed[0].kind === 'cat', 'B claims the cat');
    r = await call('POST', '/social/claim', { ids: [inbox[0].id] }, tok.b);
    ok(r.data.claimed.length === 0, 'claiming twice gives nothing');
    r = await call('POST', '/social/claim', { ids: [inbox[0].id] }, tok.c);
    ok(r.data.claimed.length === 0, 'someone else cannot claim it');

    // в гости: города без облака нет; с облаком — данные
    r = await call('GET', '/social/city?id=' + id.b, undefined, tok.a);
    ok(r.status === 404, 'visit a city without a cloud save → 404');
    const cityJson = JSON.stringify({ version: 2, day: 40, level: 4, buildings: [{ id: 1, type: 'house', x: 1, z: 2 }] });
    r = await call('PUT', '/save?game=rome2', { data: cityJson, force: true, meta: { city: 'Брундизий' } }, tok.b);
    ok(r.status === 200, 'B uploads its city');
    r = await call('GET', '/social/city?name=' + encodeURIComponent('Брундизий'), undefined, tok.a);
    ok(r.status === 200 && r.data.data === cityJson && r.data.name === 'Брундизий' && r.data.friend === true && r.data.card.pop > 0 && !r.data.liked,
      'A visits B by name: city data, card, friend flag', r.data && Object.assign({}, r.data, { data: undefined }));
    ok(!JSON.stringify(r.data).includes('@social.test'), 'no e-mails in the visit answer');
    r = await call('POST', '/social/like', { id: id.b }, tok.a);
    ok(r.status === 200 && r.data.first && r.data.likes === 1, 'A likes B');
    r = await call('POST', '/social/like', { id: id.b }, tok.a);
    ok(r.data.first === false && r.data.likes === 1, 'second like today does not count');
    r = await call('GET', '/social/city?id=' + id.b, undefined, tok.a);
    ok(r.data.liked === true, 'visit shows "already liked today"');
    r = await call('POST', '/social/unfriend', { id: id.b }, tok.a);
    ok(r.data.friends.length === 1 && r.data.friends[0].name === 'Капуя Малая', 'A unfriends B');
  } catch (e) {
    console.error(e);
    fails++;
  } finally {
    await stop(srv);
  }
  console.log(fails ? `${fails} FAILED` : 'ALL OK');
  process.exit(fails ? 1 : 0);
})();
