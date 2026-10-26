'use strict';
/* Опись игры для лаунчера и всё, что ляжет на сайт в https://civcity.ru/game/.
     node deploy/game_manifest.js [папка сборки] [папка выкладки]
   папка сборки   — по умолчанию build/game (CivCity.exe, наборы .pck, version.json — их делает deploy/build_game.sh);
   папка выкладки — по умолчанию .work/deploy. В ней получается:
     game/manifest.json  — подписанная опись (её читает desktop/updater.js): обёртка
                           { "format": 2, "manifest": "<текст описи>", "sig": "<подпись Ed25519 текста, base64>" };
                           в описи — версия, сборка, файлы с размером и sha256 (у сжатых — ещё zst и zsha),
                           "later" — наборы, которые лаунчер может докачать уже после «Играть» (музыка);
     game/f/<sha256>     — файл как есть (жёсткая ссылка на файл сборки, места не занимает);
     game/f/<zsha>.zst   — сжатая копия, если сжатие экономит хотя бы 8 % (так, exe — 104 → ~28 МБ); имя — sha256
                           самой сжатой копии: другое сжатие того же файла (другая версия zstd) — другое имя, и на
                           сервере под одним именем никогда не лежат разные байты;
     game/blobs.txt      — что из f/ нужно на сайте (сжатая копия, если есть, иначе файл как есть) с sha256 —
                           по нему deploy.sh заливает только новое и проверяет залитое (sha256sum -c);
     game/build.txt      — номер сборки (для deploy.sh);
     game-manifest.json  — заглушка для лаунчеров 0.9.x (они читают https://civcity.ru/game-manifest.json):
                           её поле shell новее их версии, и они предлагают скачать новый установщик.
   Сжатие небыстрое (exe — около минуты), поэтому сжатые копии хранятся в <папка выкладки>/zcache по sha256:
   повторная опись без изменений в игре занимает секунды.

   Подпись: закрытый ключ — secrets/manifest_ed25519.pem (или путь в CIVCITY_SIGN_KEY), только на компьютере
   владельца, не в git и не на сервере. Его открытая половина вписана в desktop/updater.js (PUBKEY_B64) — опись,
   подписанную другим ключом, лаунчер не примет. Нет ключа — опись не делается. Ключ надо беречь (копия на флешке):
   без него обновить игру у игроков можно будет только новым установщиком лаунчера с новым ключом.

     node deploy/game_manifest.js --rollback <releases/N.json с сервера> <папка>
   — откат: проверить подпись прежней описи, поставить в неё "rollback": true (лаунчер иначе не ставит сборку
   старше установленной), подписать заново → <папка>/manifest.json и <папка>/blobs.txt (какие файлы нужны). */
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const zlib = require('zlib');
const { Transform, Writable } = require('stream');
const { pipeline } = require('stream/promises');

// Наименьшая версия лаунчера, которая умеет ставить игру по этой описи. Поднимать, только если формат описи
// меняется так, что старый лаунчер с ним не справится (тогда он предложит скачать новый установщик).
const LAUNCHER_MIN = '1.0.0';
const NAME_RE = /^[A-Za-z0-9][A-Za-z0-9_.-]{0,80}$/;   // как в desktop/updater.js
const EXE = 'CivCity.exe';
// что может подождать после «Играть» (поле "later" описи; лаунчер берёт оттуда лишь известные ему имена)
const LATER = ['CivCity_music.pck'];

const ROOT = path.join(__dirname, '..');
const ROLLBACK = process.argv[2] === '--rollback';
const BUILD = path.resolve(process.argv[2] || path.join(ROOT, 'build', 'game'));
const OUT = path.resolve(process.argv[3] || path.join(ROOT, '.work', 'deploy'));
const GAME = path.join(OUT, 'game');
const ZDIR = path.join(OUT, 'zcache');
const ZINFO = path.join(OUT, 'zcache.json');
const KEY_FILE = process.env.CIVCITY_SIGN_KEY || path.join(ROOT, 'secrets', 'manifest_ed25519.pem');

const die = msg => { console.error('ОШИБКА: ' + msg); process.exit(1); };
const MB = n => (n / 1048576).toFixed(2) + ' МБ';

// Ключ подписи и проверка, что его открытая половина — та, что вписана в лаунчер
function signKey() {
  let priv;
  try { priv = crypto.createPrivateKey(fs.readFileSync(KEY_FILE)); } catch (e) {
    die(`нет ключа подписи описи ${KEY_FILE} — без него лаунчеры игру не примут (ключ — у владельца, см. deploy/RELEASE.md)`);
  }
  if (priv.asymmetricKeyType !== 'ed25519') die(`${KEY_FILE} — не ключ Ed25519`);
  const pub = crypto.createPublicKey(priv);
  const b64 = pub.export({ type: 'spki', format: 'der' }).toString('base64');
  const src = fs.readFileSync(path.join(ROOT, 'desktop', 'updater.js'), 'utf8');
  const m = /const PUBKEY_B64 = '([A-Za-z0-9+/=]+)'/.exec(src);
  if (!m || m[1] !== b64) die(`ключ ${KEY_FILE} не тот, что вписан в лаунчер (desktop/updater.js, PUBKEY_B64)`);
  return { priv, pub };
}

// Обёртка с подписью: подписываются ровно байты текста описи
function wrap(text, key) {
  const sig = crypto.sign(null, Buffer.from(text, 'utf8'), key.priv).toString('base64');
  return JSON.stringify({ format: 2, manifest: text, sig }) + '\n';
}

// Что из f/ нужно описи на сайте: «sha256  f/имя» (сжатая копия, если есть)
function blobLines(manifest) {
  return Object.values(manifest.files).map(f => (f.zst ? `${f.zsha}  f/${f.zsha}.zst` : `${f.sha256}  f/${f.sha256}`));
}

// Откат: прежняя опись с сервера (проверить подпись!) → "rollback": true, новая подпись
function rollback(file, out) {
  const key = signKey();
  let w;
  try { w = JSON.parse(fs.readFileSync(file, 'utf8')); } catch (e) { die(`${file} — не опись`); }
  if (!w || typeof w.manifest !== 'string' || typeof w.sig !== 'string') die(`${file} — опись без подписи (старого формата)`);
  if (!crypto.verify(null, Buffer.from(w.manifest, 'utf8'), key.pub, Buffer.from(w.sig, 'base64'))) die(`подпись ${file} не сходится — эту опись подписывали не мы, откатывать на неё нельзя`);
  const m = JSON.parse(w.manifest);
  m.rollback = true;
  m.date = new Date().toISOString().replace(/\.\d+Z$/, 'Z');
  fs.mkdirSync(out, { recursive: true });
  fs.writeFileSync(path.join(out, 'manifest.json'), wrap(JSON.stringify(m, null, 1) + '\n', key));
  fs.writeFileSync(path.join(out, 'blobs.txt'), blobLines(m).join('\n') + '\n');
  console.log(`Опись отката: сборка ${m.build} (${m.version}), подписана заново с "rollback": true`);
}

async function sha256(file) {
  const h = crypto.createHash('sha256');
  for await (const chunk of fs.createReadStream(file)) h.update(chunk);
  return h.digest('hex');
}

// сжать zstd (уровень level) в out (или только посчитать размер, если out не задан)
async function zstd(file, level, out) {
  let size = 0;
  const count = new Transform({ transform(c, e, cb) { size += c.length; cb(null, c); } });
  const sink = out ? fs.createWriteStream(out) : new Writable({ write(c, e, cb) { cb(); } });
  const z = zlib.createZstdCompress({ params: { [zlib.constants.ZSTD_c_compressionLevel]: level, [zlib.constants.ZSTD_c_checksumFlag]: 1 } });
  await pipeline(fs.createReadStream(file), z, count, sink);
  return size;
}

function link(src, dst) {
  try { fs.linkSync(src, dst); } catch (e) { fs.copyFileSync(src, dst); }
}

async function main() {
  if (ROLLBACK) {
    if (!process.argv[3] || !process.argv[4]) die('откат: node deploy/game_manifest.js --rollback <опись> <папка>');
    rollback(path.resolve(process.argv[3]), path.resolve(process.argv[4]));
    return;
  }
  const key = signKey();
  if (!fs.existsSync(path.join(BUILD, EXE))) die(`нет ${EXE} в ${BUILD} — сначала соберите игру: bash tools/build_game.sh`);
  let ver;
  try { ver = JSON.parse(fs.readFileSync(path.join(BUILD, 'version.json'), 'utf8')); } catch (e) { die(`нет или испорчен version.json в ${BUILD}`); }
  if (!ver.version || !Number.isInteger(ver.build)) die('version.json без version/build');

  const names = fs.readdirSync(BUILD, { withFileTypes: true }).filter(d => d.isFile() && !d.name.startsWith('.')).map(d => d.name).sort();
  for (const n of names) if (!NAME_RE.test(n) || n.toLowerCase() === 'manifest.json') die(`неподходящее имя файла в сборке: ${n}`);

  let zinfo = {};
  try { zinfo = JSON.parse(fs.readFileSync(ZINFO, 'utf8')); } catch (e) { /* первый раз */ }
  fs.mkdirSync(ZDIR, { recursive: true });
  fs.rmSync(GAME, { recursive: true, force: true });
  fs.mkdirSync(path.join(GAME, 'f'), { recursive: true });

  const files = {};
  let total = 0, download = 0;
  for (const n of names) {
    const src = path.join(BUILD, n);
    const size = fs.statSync(src).size;
    const h = await sha256(src);
    const f = { size, sha256: h };
    link(src, path.join(GAME, 'f', h));
    // сжимать ли: сначала быстрая проба (уровень 3), и только если она обещает выгоду — настоящее сжатие (уровень 19)
    let z = zinfo[h];
    const zfile = path.join(ZDIR, h + '.zst');
    if (z && z.zst && (!fs.existsSync(zfile) || fs.statSync(zfile).size !== z.zst)) z = null;
    if (!z) {
      z = { raw: true };
      if (size > 64 * 1024) {
        const t = Date.now();
        const probe = await zstd(src, 3);
        if (probe < size * 0.96) {
          process.stdout.write(`  сжимаю ${n} (${MB(size)})… `);
          const zs = await zstd(src, 19, zfile);
          if (zs <= size * 0.92) { z = { zst: zs, zsha: await sha256(zfile) }; console.log(`${MB(zs)} за ${Math.round((Date.now() - t) / 1000)} с`); }
          else { fs.rmSync(zfile, { force: true }); console.log('выгода мала — оставляю как есть'); }
        }
      }
    }
    delete zinfo[h];
    zinfo[h] = z;            // недавно нужные — в конец, чтобы чистка кэша их не тронула
    if (z.zst) {
      f.zst = z.zst;
      f.zsha = z.zsha;
      link(zfile, path.join(GAME, 'f', z.zsha + '.zst'));
      download += z.zst;
    } else {
      download += size;
    }
    files[n] = f;
    total += size;
  }
  // в кэше сжатия — только то, что нужно этой сборке и паре прошлых (сжатый exe пригодится, если откатят)
  const keep = Object.keys(zinfo).slice(-24);
  zinfo = Object.fromEntries(keep.map(k => [k, zinfo[k]]));
  for (const n of fs.readdirSync(ZDIR)) if (!zinfo[n.replace(/\.zst$/, '')]) fs.rmSync(path.join(ZDIR, n), { force: true });
  fs.writeFileSync(ZINFO, JSON.stringify(zinfo, null, 1));

  const manifest = {
    format: 2,          // 2 — сжатые копии по своему sha256 (zsha), опись подписана
    version: String(ver.version),
    build: ver.build,
    date: new Date().toISOString().replace(/\.\d+Z$/, 'Z'),
    launcher: LAUNCHER_MIN,
    exe: EXE,
    total,
    download,
    files,
  };
  // наборы, без которых эта сборка играет (и подхватывает их на ходу, packs.gd): новый лаунчер докачивает их после
  // «Играть». Прежние описи (и откат на них) этого поля не имеют — там лаунчер ставит всё сразу, как раньше
  const later = LATER.filter(n => files[n]);
  if (later.length) manifest.later = later;
  fs.writeFileSync(path.join(GAME, 'manifest.json'), wrap(JSON.stringify(manifest, null, 1) + '\n', key));
  fs.writeFileSync(path.join(GAME, 'blobs.txt'), [...new Set(blobLines(manifest))].join('\n') + '\n');
  fs.writeFileSync(path.join(GAME, 'build.txt'), String(manifest.build) + '\n');

  // заглушка для лаунчеров 0.9.x: у них нет новой игры, а поле shell новее их версии → «Вышла новая версия, скачайте»
  // (files пустой: старый лаунчер ничего не качает; version — любое непустое)
  const shell = JSON.parse(fs.readFileSync(path.join(ROOT, 'desktop', 'package.json'), 'utf8')).version;
  fs.writeFileSync(path.join(OUT, 'game-manifest.json'), JSON.stringify({ version: String(100000 + ver.build), shell, files: {} }) + '\n');

  console.log(`Опись игры: ${manifest.version}, сборка ${manifest.build}, файлов ${names.length}, всего ${MB(total)}, скачивать с нуля ${MB(download)}`);
  for (const n of names) console.log(`  ${n.padEnd(20)} ${MB(files[n].size).padStart(11)}${files[n].zst ? ` → ${MB(files[n].zst)} (zst)` : ''}  ${files[n].sha256.slice(0, 12)}`);
  console.log(`  → ${GAME}`);
}

main().catch(e => die(e.stack || e.message));
