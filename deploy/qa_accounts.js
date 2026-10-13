'use strict';
/* Тестовые аккаунты для автопроверки собранной игры (deploy/qa_exported.sh) — только на СВОЁМ сервере аккаунтов:
     PORT=3010 DATA_DIR=D:/CivCity/.work/srvdata node server/index.js
     node deploy/qa_accounts.js [--api=http://127.0.0.1:3010/api] [--city=D:/CivCity/.work/qa/legion_city.json]
   A — почта и пароль (регистрируется сама игра в сценарии login), B — регистрируется здесь, в его облако кладётся
   город с Легионом (его пишет res://test_qa_city.tscn). Пароли случайные, лежат только в .work/qa/accounts.json.
   Сервер пускает ~5 регистраций в час с одного адреса — при «слишком много попыток» перезапустите локальный сервер. */
const fs = require('fs'), zlib = require('zlib'), crypto = require('crypto'), path = require('path');
const arg = (k, d) => { const a = process.argv.find(x => x.startsWith(`--${k}=`)); return a ? a.slice(k.length + 3) : d; };
const API = arg('api', 'http://127.0.0.1:3010/api').replace(/\/$/, '');
const CITY = arg('city', 'D:/CivCity/.work/qa/legion_city.json');
const OUT = path.join(__dirname, '..', '.work', 'qa', 'accounts.json');
if (!/^https?:\/\/(127\.0\.0\.1|localhost)(:\d+)?\//.test(API + '/')) { console.error('только свой сервер (127.0.0.1)'); process.exit(1); }
const rnd = () => crypto.randomBytes(6).toString('hex');
async function call(method, p, body, token, gz) {
  const h = { 'Content-Type': 'application/json' };
  if (token) h.Authorization = 'Bearer ' + token;
  let data = body ? JSON.stringify(body) : undefined;
  if (gz) { data = zlib.gzipSync(Buffer.from(data)); h['Content-Encoding'] = 'gzip'; }
  const r = await fetch(API + p, { method, headers: h, body: data });
  return { status: r.status, data: await r.json().catch(() => ({})) };
}
(async () => {
  const acc = { api: API, A: { email: `qa-a-${rnd()}@test.local`, password: 'Qa' + rnd() }, B: { email: `qa-b-${rnd()}@test.local`, password: 'Qb' + rnd() } };
  const r = await call('POST', '/register', { email: acc.B.email, password: acc.B.password });
  if (r.status !== 200) throw new Error('регистрация B: ' + r.status + ' ' + JSON.stringify(r.data));
  acc.B.token = r.data.token;
  const city = fs.readFileSync(CITY, 'utf8');
  const n = JSON.parse(city).buildings.length;
  const p = await call('PUT', '/save?game=rome2', { data: city, base: null, force: false, meta: { pop: 704, day: 1, level: 6, n, city: 'Новый Рим', v: '1.0.0' } }, acc.B.token, true);
  if (p.status !== 200) throw new Error('город B в облако: ' + p.status + ' ' + JSON.stringify(p.data));
  acc.B.buildings = n;
  fs.mkdirSync(path.dirname(OUT), { recursive: true });
  fs.writeFileSync(OUT, JSON.stringify(acc, null, 1));
  console.log(`аккаунты готовы: A (для login/restore), B (город ${n} построек в облаке) → ${OUT}`);
})().catch(e => { console.error('ОШИБКА:', e.message); process.exit(1); });
