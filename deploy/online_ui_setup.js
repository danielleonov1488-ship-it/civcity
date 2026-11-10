'use strict';
// Учётки для проверки окон онлайна 2.0 (test_online_ui.tscn) на своём сервере: node setup_ui.js <api> <city.json> <out tokens.json>
// A — игрок (смотрит окна), B — друг (его город в облаке — для «В гости», дарит A подарки, глава союза), C — ещё город.
const fs = require('fs');
const API = process.argv[2] || 'http://127.0.0.1:3020/api';
const CITY = process.argv[3];
const OUT = process.argv[4];
async function call(method, p, body, token) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = 'Bearer ' + token;
  const r = await fetch(API + p, { method, headers, body: body === undefined ? undefined : JSON.stringify(body) });
  let d = null; try { d = await r.json(); } catch (e) { /* */ }
  if (r.status !== 200) throw new Error(method + ' ' + p + ': ' + r.status + ' ' + JSON.stringify(d));
  return d;
}
(async () => {
  const st = Date.now().toString(36);
  const sx = ' ' + st.slice(-3).toUpperCase();
  const tok = {};
  for (const n of ['a', 'b', 'c']) tok[n] = (await call('POST', '/register', { email: `ui-${n}-${st}@test.local`, password: 'secret-' + n })).token;
  await call('PUT', '/pvp/name', { name: 'Аквилея' + sx }, tok.a);
  await call('PUT', '/pvp/name', { name: 'Брундизий' + sx }, tok.b);
  await call('PUT', '/pvp/name', { name: 'Капуя' + sx }, tok.c);
  await call('PUT', '/social/card', { card: { pop: 704, level: 6, rank: 'Большой город', title: 'Колония', fame: 900, hero: 'Гай Валерий', cats: 4, inns: 2, sights: ['Колизей', 'Форум', 'Арка'] } }, tok.b);
  await call('PUT', '/social/card', { card: { pop: 210, level: 4, rank: 'Посёлок', title: 'Муниципий', fame: 120, hero: 'Постумия Агриппина', sights: ['Храм'] } }, tok.c);
  await call('PUT', '/social/card', { card: { pop: 400, level: 5, rank: 'Городок', hero: 'Марк' } }, tok.a);
  const data = fs.readFileSync(CITY, 'utf8');
  await call('PUT', '/save?game=rome2', { data, force: true, meta: { city: 'Брундизий' } }, tok.b);
  const a = await call('GET', '/social/find?name=' + encodeURIComponent('Аквилея' + sx), undefined, tok.b);
  const aid = a.list[0].id;
  await call('POST', '/social/friend', { name: 'Брундизий' + sx }, tok.a);
  await call('POST', '/social/friend', { name: 'Капуя' + sx }, tok.a);
  await call('POST', '/social/gift', { id: aid, kind: 'statue' }, tok.b);
  await call('POST', '/social/gift', { id: aid, kind: 'cat' }, tok.c);
  const u = await call('POST', '/union/create', { name: 'Волчья стая' + sx, emblem: 1, color: 0 }, tok.b);
  await call('POST', '/union/say', { phrase: 0 }, tok.b);
  await call('POST', '/union/join', { id: u.union.id }, tok.c);
  await call('POST', '/union/say', { phrase: 4 }, tok.c);
  await call('POST', '/union/say', { text: 'Добро пожаловать в стаю! В субботу вместе идём на арену.' }, tok.b);
  fs.writeFileSync(OUT, JSON.stringify({ api: API, a: tok.a, b: tok.b, c: tok.c, union: u.union.id, c_name: 'Капуя' + sx }));
  console.log('ok', OUT);
})().catch(e => { console.error(e); process.exit(1); });
