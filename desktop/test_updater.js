'use strict';
/* Проверка загрузчика лаунчера (updater.js) без Electron и без сети: node desktop/test_updater.js
   Сайт — в памяти (подмена net.fetch), опись подписана своим ключом этой проверки (настоящий ключ — только у владельца).
   Проверяет: «Играть» доступна, пока музыка ещё не скачана (1.11 плана 24.10); музыка докачивается потом и ложится в
   game/; подмена описи и файлов не проходит (подпись, sha256); обновление посреди докачки не теряет её куски и
   не кладёт музыку от другой описи. В конце — «UPDATER DONE fails=N». */
const Module = require('module');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

process.env.CIVCITY_UPDATE_URL = 'https://test.civcity.local/';
const site = new Map();               // путь → Buffer
const gates = new Map();              // путь → Promise: ответ ждёт, пока его не откроют
const hits = new Map();               // путь → сколько раз просили
let bad = new Set();                  // пути, по которым сайт отдаёт испорченные байты

const fakeNet = {
  async fetch(url, opts = {}) {
    const u = new URL(url);
    const p = u.pathname;
    hits.set(p, (hits.get(p) || 0) + 1);
    if (gates.has(p)) await gates.get(p).promise;
    if (opts.signal && opts.signal.aborted) throw Object.assign(new Error('aborted'), { name: 'AbortError' });
    let body = site.get(p);
    if (!body) return new Response('нет', { status: 404 });
    if (bad.has(p)) { body = Buffer.from(body); body[0] ^= 0xff; }
    const range = (opts.headers || {}).Range;
    if (range) {
      const from = +/bytes=(\d+)-/.exec(range)[1];
      if (from >= body.length) return new Response('', { status: 416 });
      return new Response(body.subarray(from), { status: 206, headers: { 'content-range': `bytes ${from}-${body.length - 1}/${body.length}` } });
    }
    return new Response(body, { status: 200 });
  },
};
const origLoad = Module._load;
Module._load = function (req, parent, isMain) {
  if (req === 'electron') return { app: { getVersion: () => '1.0.3' }, net: fakeNet };
  return origLoad.apply(this, arguments);
};
const { Updater, LATER } = require('./updater');

let fails = 0;
function check(ok, what) {
  console.log((ok ? 'ok   ' : 'FAIL ') + what);
  if (!ok) fails++;
}
const sha = b => crypto.createHash('sha256').update(b).digest('hex');
const gate = p => { let open; const promise = new Promise(r => { open = r; }); gates.set(p, { promise, open }); return () => { gates.delete(p); open(); }; };

const { publicKey, privateKey } = crypto.generateKeyPairSync('ed25519');
const other = crypto.generateKeyPairSync('ed25519');

// выложить сборку: файлы по sha256 и подписанная опись
function publish(build, files, key = privateKey) {
  const m = { version: '1.0.0', build, launcher: '1.0.0', exe: 'CivCity.exe', files: {} };
  for (const [n, b] of Object.entries(files)) {
    const h = sha(b);
    m.files[n] = { size: b.length, sha256: h };
    site.set('/game/f/' + h, b);
  }
  const text = JSON.stringify(m);
  const sig = crypto.sign(null, Buffer.from(text, 'utf8'), key).toString('base64');
  site.set('/game/manifest.json', Buffer.from(JSON.stringify({ format: 2, manifest: text, sig })));
  return m;
}
const rnd = n => crypto.randomBytes(n);

(async () => {
  // временная папка — рядом с проектом (.work), не на системном диске
  const tmpBase = process.env.CIVCITY_TEST_TMP || path.join(__dirname, '..', '.work', 'tmp');
  fs.mkdirSync(tmpBase, { recursive: true });
  const root = fs.mkdtempSync(path.join(tmpBase, 'civ_upd_'));
  try {
    check(LATER.has('CivCity_music.pck') && !LATER.has('CivCity.pck') && !LATER.has('CivCity.exe'), 'потом — только музыка');
    const up = new Updater(root, { pubkey: publicKey, tries: 2, pauseMs: 20 });
    const music1 = rnd(300000);
    const files1 = { 'CivCity.exe': rnd(5000), 'CivCity.pck': rnd(2000), 'CivCity_models.pck': rnd(100000), 'CivCity_ui.pck': rnd(20000), 'CivCity_music.pck': music1 };
    const m1 = publish(1, files1);
    const musicPath = '/game/f/' + m1.files['CivCity_music.pck'].sha256;

    // 1. первая установка: музыку не ждём (её ответ «висит») — игра ставится и без неё
    let openMusic = gate(musicPath);
    const r1 = await up.ensure();
    check(r1.state === 'updated' && r1.fresh, `первая установка: ${r1.state}`);
    check(JSON.stringify(r1.later) === '["CivCity_music.pck"]', 'музыка — в списке «потом»: ' + JSON.stringify(r1.later));
    check(!!up.playable() && !up.installed(), 'играть можно (playable), но установлено не всё (installed — нет)');
    check(!fs.existsSync(path.join(up.dir, 'CivCity_music.pck')), 'музыки в game/ ещё нет');
    check(!hits.get(musicPath), 'ensure() музыку и не просил');
    for (const n of ['CivCity.exe', 'CivCity.pck', 'CivCity_models.pck', 'CivCity_ui.pck'])
      check(sha(fs.readFileSync(path.join(up.dir, n))) === m1.files[n].sha256, `${n} на месте и верный`);

    // 2. докачка музыки после «Играть»: пока ответ висит — не готово; открыли — файл в game/, всё установлено
    let said = '';
    const lp = up.fetchLater(r1.manifest, t => { said = t; });
    await new Promise(r => setTimeout(r, 50));
    check(!fs.existsSync(path.join(up.dir, 'CivCity_music.pck')), 'пока музыка качается — в game/ её нет');
    openMusic();
    const placed = await lp;
    check(JSON.stringify(placed) === '["CivCity_music.pck"]', 'fetchLater поставил музыку');
    check(sha(fs.readFileSync(path.join(up.dir, 'CivCity_music.pck'))) === m1.files['CivCity_music.pck'].sha256, 'музыка в game/ — верная');
    check(!!up.installed() && up.missingLater(up.installed()).length === 0, 'теперь установлено всё');
    check(said.startsWith('Музыка докачивается'), 'ход докачки для лаунчера: ' + said);
    check(!fs.existsSync(path.join(up.dir, 'CivCity_music.pck.tmp')), 'без .tmp в game/');

    // 3. ничего не поменялось — готово, ничего не качаем
    hits.clear();
    const r3 = await up.ensure();
    check(r3.state === 'ready' && r3.later.length === 0, `повторная проверка: ${r3.state}, later ${JSON.stringify(r3.later)}`);
    check([...hits.keys()].every(k => k === '/game/manifest.json'), 'скачана только опись');

    // 4. подменённая опись (подпись другим ключом) — не принимается, установленная остаётся
    const good = site.get('/game/manifest.json');
    publish(2, { ...files1, 'CivCity.pck': rnd(2100) }, other.privateKey);
    const r4 = await up.ensure();
    check(r4.state === 'failed' && /подписи/.test(r4.error), `чужая подпись: ${r4.state} — ${r4.error}`);
    check(up.installed() && up.installed().build === 1, 'установленная сборка 1 цела');
    // испорченная подпись (текст описи поменяли, подпись старая)
    const w = JSON.parse(good.toString());
    w.manifest = w.manifest.replace('"build":1', '"build":7');
    site.set('/game/manifest.json', Buffer.from(JSON.stringify(w)));
    const r4b = await up.ensure();
    check(r4b.state === 'failed', `поправленный текст описи без новой подписи: ${r4b.state}`);
    site.set('/game/manifest.json', good);

    // 5. новая сборка: поменялась только музыка — копия ставится без старой музыки, новая докачивается потом
    const music2 = rnd(310000);
    const m5 = publish(3, { ...files1, 'CivCity_music.pck': music2 });
    const mus2Path = '/game/f/' + m5.files['CivCity_music.pck'].sha256;
    openMusic = gate(mus2Path);
    const r5 = await up.ensure();
    check(r5.state === 'updated' && !r5.fresh && JSON.stringify(r5.later) === '["CivCity_music.pck"]', `только музыка новая: ${r5.state}, later ${JSON.stringify(r5.later)}`);
    check(!fs.existsSync(path.join(up.dir, 'CivCity_music.pck')), 'старой музыки (не по описи) в game/ нет');
    check(up.playable() && up.playable().build === 3, 'играть можно в сборке 3');

    // 6. обновление посреди докачки музыки: её куски в game-dl/ не теряются, музыка от прежней описи не кладётся
    const lp6 = up.fetchLater(r5.manifest);
    await new Promise(r => setTimeout(r, 30));
    const part = path.join(up.dl, m5.files['CivCity_music.pck'].sha256 + '.part');
    fs.mkdirSync(up.dl, { recursive: true });
    fs.writeFileSync(part, music2.subarray(0, 1000));        // будто часть уже скачана
    const m6 = publish(4, { ...files1, 'CivCity.pck': rnd(2200), 'CivCity_music.pck': music2 });
    const r6 = await up.ensure();
    check(r6.state === 'updated' && up.playable().build === 4, `код обновился посреди докачки: ${r6.state}`);
    check(fs.existsSync(part), 'кусок музыки в game-dl/ цел');
    openMusic();
    const placed6 = await lp6;
    check(placed6.length === 0 && !fs.existsSync(path.join(up.dir, 'CivCity_music.pck')), 'музыку от прежней описи (сборка 3) в новую копию не положили');
    const placed6b = await up.fetchLater(r6.manifest);
    check(JSON.stringify(placed6b) === '["CivCity_music.pck"]' && !!up.installed(), 'с новой описью — сразу (уже скачана) и всё установлено');

    // 7. музыка пришла испорченной (sha256 не тот) — в game/ не кладётся, ошибка наружу
    const music3 = rnd(200000);
    const m7 = publish(5, { ...files1, 'CivCity.pck': rnd(2300), 'CivCity_music.pck': music3 });
    const r7 = await up.ensure();
    check(r7.state === 'updated' && r7.later.length === 1, 'сборка 5 без музыки');
    bad = new Set(['/game/f/' + m7.files['CivCity_music.pck'].sha256]);
    let err = null;
    await up.fetchLater(r7.manifest).catch(e => { err = e; });
    check(!!err && /повреждённым/.test(err.message), 'испорченная музыка: ' + (err && err.message));
    check(!fs.existsSync(path.join(up.dir, 'CivCity_music.pck')), 'испорченная музыка в game/ не попала');
    check(!!up.playable() && !up.installed(), 'играть можно и дальше');
    bad = new Set();
    check((await up.fetchLater(r7.manifest)).length === 1 && !!up.installed(), 'со второго раза — поставлена');

    // 8. без сети: играем в установленной (и без музыки тоже)
    fs.rmSync(path.join(up.dir, 'CivCity_music.pck'));
    const saved = site.get('/game/manifest.json');
    site.delete('/game/manifest.json');
    const r8 = await up.ensure();
    check(r8.state === 'failed' || r8.state === 'offline' || r8.state === 'ready', `опись не скачалась: ${r8.state}`);
    check(!!r8.manifest, 'установленная копия без музыки — годится для игры');
    site.set('/game/manifest.json', saved);

    // 9a. «Проверить файлы»: музыка того же размера, но испорченная — убирается и докачивается заново
    await up.fetchLater(up.playable());
    const musPath = path.join(up.dir, 'CivCity_music.pck');
    const good9 = fs.readFileSync(musPath);
    const bad9 = Buffer.from(good9); bad9[100] ^= 0x55;
    fs.writeFileSync(musPath, bad9);
    const r9 = await up.ensure({ verify: true });
    check(r9.state === 'ready' && JSON.stringify(r9.later) === '["CivCity_music.pck"]' && !fs.existsSync(musPath),
      `проверка файлов: испорченная музыка убрана, докачается (${r9.state}, ${JSON.stringify(r9.later)})`);
    check((await up.fetchLater(r9.manifest)).length === 1 && fs.readFileSync(musPath).equals(good9), '…и докачана верной');

    // 9. прерванная замена папок: game/ нет, game-new/ без музыки — восстанавливается (playable)
    fs.renameSync(up.dir, up.next);
    await up.recover();
    check(!!up.playable(), 'recover() поднял копию без музыки');
  } catch (e) {
    console.log('FAIL исключение:', e && e.stack);
    fails++;
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
  console.log(`UPDATER DONE fails=${fails}`);
  process.exit(fails ? 1 : 0);
})();
