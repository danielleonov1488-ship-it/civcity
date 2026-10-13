'use strict';
/* Загрузка и обновление игры для лаунчера.
   Игра — программа на Godot: CivCity.exe и наборы данных .pck (их собирает deploy/build_game.sh).
   На сайте лежит опись https://civcity.ru/game/manifest.json (её пишет deploy/game_manifest.js):
     { "version": "1.0.0", "build": 5, "launcher": "1.0.0", "exe": "CivCity.exe",
       "files": { "CivCity.pck": { "size": 912345, "sha256": "…", "zst": 812345, "zsha": "…" }, … } }
   Сами файлы — по адресу game/f/<sha256> или game/f/<zsha>.zst (сжатая копия, если сжатие заметно
   экономит трафик; "zst" — её размер, "zsha" — её sha256). У каждого содержимого свой адрес, поэтому скачиваемый файл не может
   подмениться на полпути, даже если в это время на сайт выкладывают новую сборку.

   Как обновляется (Updater.ensure):
   1. сверяет опись сайта со своей (game/manifest.json): качать нужно только файлы с другим sha256;
   2. качает их в game-dl/ по два сразу; недокачанное лежит там как <sha256>.part или <zsha>.zst.part и при следующей
      попытке (или следующем запуске) докачивается с места обрыва; каждый файл проверяется по sha256;
   3. собирает новую копию игры в game-new/ (неизменные файлы — жёсткими ссылками, без копирования),
      затем ставит её на место старой двумя переименованиями папок. Оборванную замену доделывает recover().
   Нет сети — играем в том, что уже установлено. Лаунчер новее не ставим сами: если опись просит версию
   лаунчера выше нашей ("launcher"), только сообщаем — установщик игрок скачивает с сайта.

   Подпись. Лаунчер запускает скачанную программу (CivCity.exe и код в .pck), поэтому опись подписана ключом
   Ed25519, который есть только на компьютере владельца (deploy/game_manifest.js, secrets/); здесь — открытая
   половина ключа (PUBKEY). На сайте лежит обёртка { "format": 2, "manifest": "<текст описи>", "sig": "<подпись>" }:
   подпись проверяется по байтам текста ДО того, как опись читается, а sha256 файлов идут из уже проверенной описи —
   подменённый на сервере файл или опись лаунчер не примет. Так же проверяется и опись установленной копии.
   Опись со сборкой старше установленной не ставится (откат на сервере — только с "rollback": true в подписанной
   описи, его ставит deploy.sh rollback). */
const { app, net } = require('electron');
const fs = require('fs');
const fsp = fs.promises;
const path = require('path');
const crypto = require('crypto');
const zlib = require('zlib');
const { Readable, Transform } = require('stream');
const { pipeline } = require('stream/promises');

const SITE = (process.env.CIVCITY_UPDATE_URL || 'https://civcity.ru/').replace(/\/?$/, '/');
const GAME_URL = SITE + 'game/';
const MANIFEST = 'manifest.json';
const NAME_RE = /^[A-Za-z0-9][A-Za-z0-9_.-]{0,80}$/;   // только простые имена, без папок и «..»
const HEX_RE = /^[0-9a-f]{64}$/;
const WORKERS = 2;
const TRIES = 6;
// открытый ключ подписи описи (Ed25519, SPKI DER в base64); закрытый — secrets/manifest_ed25519.pem у владельца
const PUBKEY_B64 = 'MCowBQYDK2VwAyEANXsEFXqsQwc8CKbwH7mEhyXsdmYB3+e2ulq6Y4bkALc=';
const PUBKEY = crypto.createPublicKey({ key: Buffer.from(PUBKEY_B64, 'base64'), format: 'der', type: 'spki' });

const sleep = ms => new Promise(r => setTimeout(r, ms));
// пауза, которую обрывает signal (остановили загрузку — не ждём до конца паузы)
const pause = (ms, signal) => new Promise(r => {
  if (signal && signal.aborted) { r(); return; }
  const t = setTimeout(r, ms);
  if (signal) signal.addEventListener('abort', () => { clearTimeout(t); r(); }, { once: true });
});

// 1,5 МБ / 120 МБ — по-русски, с запятой
function mb(bytes) {
  const v = bytes / 1048576;
  return (v < 10 ? v.toFixed(1) : Math.round(v).toString()).replace('.', ',') + ' МБ';
}

// 1.0.10 > 1.0.9
function cmpVer(a, b) {
  const x = String(a).split('.').map(Number), y = String(b).split('.').map(Number);
  for (let i = 0; i < 3; i++) if ((x[i] || 0) !== (y[i] || 0)) return (x[i] || 0) - (y[i] || 0);
  return 0;
}

function readJson(file) {
  try { return JSON.parse(fs.readFileSync(file, 'utf8')); } catch (e) { return null; }
}

function writeJsonAtomic(file, obj) {
  const tmp = file + '.tmp';
  fs.writeFileSync(tmp, JSON.stringify(obj, null, 1));
  fs.renameSync(tmp, file);
}

// опись в порядке: простые имена, sha256 и размер у каждого файла, сама игра (.exe) есть в списке
function validManifest(m) {
  if (!m || typeof m !== 'object' || !m.files || typeof m.files !== 'object') return false;
  const names = Object.keys(m.files);
  if (!names.length) return false;
  for (const n of names) {
    const f = m.files[n];
    if (!NAME_RE.test(n) || n.toLowerCase() === MANIFEST || /\.(part|tmp)$/i.test(n)) return false;
    if (!f || !HEX_RE.test(f.sha256) || !Number.isSafeInteger(f.size) || f.size < 0) return false;
    if (f.zst !== undefined && !(Number.isSafeInteger(f.zst) && f.zst > 0 && HEX_RE.test(f.zsha))) return false;
  }
  const exe = m.exe || 'CivCity.exe';
  return typeof exe === 'string' && /\.exe$/i.test(exe) && !!m.files[exe];
}

// Подписанная опись (байты обёртки) → опись или null. Сначала подпись по байтам текста, потом разбор и проверка
// формы. У описи остаётся скрытое поле raw — байты обёртки, их и кладём к установленной игре.
function openSigned(buf) {
  let w;
  try { w = JSON.parse(Buffer.isBuffer(buf) ? buf.toString('utf8') : String(buf)); } catch (e) { return null; }
  if (!w || typeof w !== 'object' || typeof w.manifest !== 'string' || typeof w.sig !== 'string') return null;
  let ok = false;
  try { ok = crypto.verify(null, Buffer.from(w.manifest, 'utf8'), PUBKEY, Buffer.from(w.sig, 'base64')); } catch (e) { ok = false; }
  if (!ok) return null;
  let m;
  try { m = JSON.parse(w.manifest); } catch (e) { return null; }
  if (!validManifest(m)) return null;
  Object.defineProperty(m, 'raw', { value: Buffer.isBuffer(buf) ? buf : Buffer.from(String(buf), 'utf8'), enumerable: false });
  return m;
}

function writeAtomic(file, bytes) {
  const tmp = file + '.tmp';
  fs.writeFileSync(tmp, bytes);
  fs.renameSync(tmp, file);
}

function sizeOf(file) {
  try { return fs.statSync(file).size; } catch (e) { return -1; }
}

function hashFile(file) {
  return new Promise((resolve, reject) => {
    const h = crypto.createHash('sha256');
    fs.createReadStream(file).on('data', d => h.update(d)).on('end', () => resolve(h.digest('hex'))).on('error', reject);
  });
}

// Windows ненадолго держит только что скачанные файлы (антивирус их проверяет) — переименование повторяем
async function rename(from, to) {
  for (let i = 0; ; i++) {
    try { await fsp.rename(from, to); return; } catch (e) {
      if (i >= 40 || !['EPERM', 'EBUSY', 'EACCES', 'ENOTEMPTY'].includes(e.code)) throw e;
      await sleep(250);
    }
  }
}

const rmrf = p => fsp.rm(p, { recursive: true, force: true, maxRetries: 8, retryDelay: 250 });

async function linkOrCopy(src, dst) {
  try { await fsp.link(src, dst); } catch (e) { await fsp.copyFile(src, dst); }
}

async function fetchBuf(url, ms) {
  const ctl = new AbortController();
  const t = setTimeout(() => ctl.abort(), ms);
  try {
    const r = await net.fetch(url, { signal: ctl.signal, cache: 'no-store' });
    if (!r.ok) throw new Error('сайт ответил ' + r.status);
    return Buffer.from(await r.arrayBuffer());
  } finally { clearTimeout(t); }
}

// Скачать url в файл part (want байт). Если part уже начат — докачать с места обрыва (Range).
// onBytes(n) — сколько байт прибавилось (или убавилось, если пришлось начать сначала);
// stop — AbortSignal всей загрузки (другой файл не скачался — этот бросаем сразу, ошибка с stopped: true)
async function download(url, part, want, onBytes, stop) {
  let have = sizeOf(part);
  if (have < 0) have = 0;
  if (have > want) { fs.rmSync(part, { force: true }); onBytes(-have); have = 0; }
  if (have === want) return;
  if (stop && stop.aborted) throw Object.assign(new Error('загрузка остановлена'), { stopped: true });
  const ctl = new AbortController();
  let idle = null;
  const poke = () => { clearTimeout(idle); idle = setTimeout(() => ctl.abort(), 30000); };   // 30 с без данных — обрыв
  poke();
  const signal = stop ? AbortSignal.any([ctl.signal, stop]) : ctl.signal;
  try {
    const r = await net.fetch(url, { headers: have ? { Range: `bytes=${have}-` } : {}, cache: 'no-store', signal });
    if (have && r.status === 206) {
      const m = /bytes (\d+)-/.exec(r.headers.get('content-range') || '');
      if (!m || +m[1] !== have) throw new Error('сайт докачивает не с того места');
    } else if (have && (r.status === 200 || r.status === 416)) {
      // сайт не умеет докачку или кусок испорчен — начинаем этот файл заново
      onBytes(-have);
      have = 0;
      if (r.status === 416) { fs.rmSync(part, { force: true }); throw new Error('докачка не удалась, начну заново'); }
    }
    if (!r.ok) throw new Error('сайт ответил ' + r.status);
    const out = fs.createWriteStream(part, { flags: have ? 'a' : 'w' });
    const count = new Transform({ transform(chunk, enc, cb) { poke(); onBytes(chunk.length); cb(null, chunk); } });
    if (r.body) await pipeline(Readable.fromWeb(r.body), count, out);
    else await new Promise((res, rej) => out.end(err => (err ? rej(err) : res())));
  } catch (e) {
    if (stop && stop.aborted) throw Object.assign(new Error('загрузка остановлена'), { stopped: true });
    if (e.name === 'AbortError') throw new Error('нет ответа от сайта');
    throw e;
  } finally { clearTimeout(idle); }
  if (sizeOf(part) !== want) throw new Error('файл скачался не целиком');
}

// распаковать .zst и сверить результат с описью
async function unpack(src, dst, f) {
  const h = crypto.createHash('sha256');
  let size = 0;
  const tap = new Transform({ transform(c, e, cb) { h.update(c); size += c.length; cb(null, c); } });
  await pipeline(fs.createReadStream(src), zlib.createZstdDecompress(), tap, fs.createWriteStream(dst));
  return size === f.size && h.digest('hex') === f.sha256;
}

class Updater {
  constructor(dataDir) {
    this.dir = path.join(dataDir, 'game');
    this.next = this.dir + '-new';
    this.old = this.dir + '-old';
    this.dl = this.dir + '-dl';
  }

  // опись установленной копии (подпись проверяется, файлы — нет) или null
  localManifest(dir = this.dir) {
    let buf;
    try { buf = fs.readFileSync(path.join(dir, MANIFEST)); } catch (e) { return null; }
    return openSigned(buf);
  }

  // установленная копия: опись, если все файлы на месте и нужного размера
  installed(dir = this.dir) {
    const m = this.localManifest(dir);
    if (!m) return null;
    for (const [n, f] of Object.entries(m.files)) if (sizeOf(path.join(dir, n)) !== f.size) return null;
    return m;
  }

  exePath(m) { return path.join(this.dir, m.exe || 'CivCity.exe'); }

  // доделать замену папок, если прошлый раз её оборвали (выключили компьютер и т. п.)
  async recover() {
    if (!fs.existsSync(this.dir)) {
      if (this.installed(this.next)) await rename(this.next, this.dir);
      else if (fs.existsSync(this.old)) await rename(this.old, this.dir);
    }
    await rmrf(this.old).catch(() => {});
    await rmrf(this.next).catch(() => {});
  }

  async fetchManifest() {
    let last = null;
    for (let i = 0; i < 2; i++) {
      try {
        const m = openSigned(await fetchBuf(GAME_URL + MANIFEST + '?t=' + Date.now(), 10000));
        if (!m) throw Object.assign(new Error('опись игры на сайте не прошла проверку подписи'), { unsigned: true });
        return m;
      } catch (e) { last = e; if (i === 0) await sleep(1000); }
    }
    throw last;
  }

  /* Привести игру к версии с сайта. opts.verify — заново посчитать sha256 установленных файлов («Проверить файлы»).
     opts.onStatus(текст, доля 0..1 или null, подстрочник). Возвращает { state, manifest, error }:
       ready   — игра уже свежая;      updated — скачали и поставили новую;
       offline — нет связи, играем в установленной;  shell — нужна новая версия лаунчера (manifest — установленная, если есть);
       failed  — обновить не вышло (manifest — установленная, если есть);  error — игры нет и скачать не вышло */
  async ensure(opts = {}) {
    const say = opts.onStatus || (() => {});
    try { await this.recover(); } catch (e) { console.log('recover:', e.message); }
    say('Проверяю обновления…', null);
    let remote;
    try { remote = await this.fetchManifest(); } catch (e) {
      console.log('опись игры:', e.message);
      const have = this.installed();
      if (e.unsigned) {
        const why = 'опись игры на сайте не прошла проверку подписи';
        return have ? { state: 'failed', manifest: have, error: 'Обновить не вышло: ' + why }
          : { state: 'error', error: 'Скачать игру не вышло: ' + why + '. Попробуйте позже.' };
      }
      if (have) return { state: 'offline', manifest: have };
      return { state: 'error', error: 'Нет связи с сервером, а игра ещё не скачана. Проверьте интернет и попробуйте ещё раз.' };
    }
    if (remote.launcher && cmpVer(remote.launcher, app.getVersion()) > 0) return { state: 'shell', manifest: this.installed() };

    const local = this.localManifest();
    // сборка на сайте старше установленной: ставим, только если это подписанный откат ("rollback": true)
    if (local && Number.isInteger(local.build) && Number.isInteger(remote.build) && remote.build < local.build && remote.rollback !== true) {
      console.log(`опись игры: на сайте сборка ${remote.build} старше установленной ${local.build} — не ставлю`);
      const have = this.installed();
      if (have) return { state: 'ready', manifest: have };
      return { state: 'error', error: 'Скачать игру не вышло: на сайте сборка старее установленной. Попробуйте позже.' };
    }
    const names = Object.keys(remote.files);
    const keep = new Set();
    for (let i = 0; i < names.length; i++) {
      const n = names[i], f = remote.files[n], l = local && local.files[n];
      const file = path.join(this.dir, n);
      let ok = !!l && l.sha256 === f.sha256 && l.size === f.size && sizeOf(file) === f.size;
      if (ok && opts.verify) {
        say('Проверяю файлы игры…', i / names.length, n);
        ok = (await hashFile(file).catch(() => '')) === f.sha256;
      }
      if (ok) keep.add(n);
    }
    const need = names.filter(n => !keep.has(n));
    if (!need.length) {
      // всё на месте: обновить опись (если поменялись только сведения о сборке) и убрать лишние старые файлы
      try {
        if (!local.raw.equals(remote.raw)) {
          for (const n of Object.keys(local.files)) if (!remote.files[n]) fs.rmSync(path.join(this.dir, n), { force: true });
          writeAtomic(path.join(this.dir, MANIFEST), remote.raw);
        }
      } catch (e) { console.log('опись игры:', e.message); }
      return { state: 'ready', manifest: remote };
    }

    const fresh = !this.installed();
    try {
      await this.fetchAll(need.map(n => remote.files[n]), fresh, say);
      say('Устанавливаю…', 1);
      await this.assemble(remote, keep);
      await this.swap();
      await rmrf(this.dl).catch(() => {});
      return { state: 'updated', manifest: remote, fresh };
    } catch (e) {
      console.log('обновление не удалось:', e.message);
      await rmrf(this.next).catch(() => {});
      const have = this.installed();
      const msg = e.code === 'ENOSPC' ? 'на диске не хватает места' : e.message;
      return { state: have ? 'failed' : 'error', manifest: have, error: (have ? 'Обновить не вышло' : 'Скачать игру не вышло') + ': ' + msg };
    }
  }

  // скачать нужные файлы в game-dl/ (с докачкой, проверкой и повторами)
  async fetchAll(files, fresh, say) {
    await fsp.mkdir(this.dl, { recursive: true });
    const uniq = [...new Map(files.map(f => [f.sha256, f])).values()];
    // в game-dl/ — только куски нужных сейчас файлов; прочее (от старых версий) убираем
    const wanted = new Set(uniq.flatMap(f => [f.sha256, f.sha256 + '.part', f.zst ? f.zsha + '.zst.part' : '']));
    for (const n of fs.readdirSync(this.dl)) if (!wanted.has(n)) fs.rmSync(path.join(this.dl, n), { recursive: true, force: true });

    const total = uniq.reduce((s, f) => s + (f.zst || f.size), 0);
    let done = 0;
    for (const f of uniq) {
      if (sizeOf(path.join(this.dl, f.sha256)) === f.size) done += f.zst || f.size;
      else done += Math.max(0, sizeOf(this.partOf(f)));
    }
    // место на диске: скачать оставшееся + распаковать сжатое + запас
    try {
      const st = await fsp.statfs(this.dl);
      const need = total - done + uniq.reduce((s, f) => s + (f.zst ? f.size : 0), 0) + 64 * 1048576;
      const free = st.bavail * st.bsize;
      if (free < need) throw Object.assign(new Error(`на диске не хватает места — освободите ещё ${mb(need - free)}`), { code: 'NOSPACE' });
    } catch (e) { if (e.code === 'NOSPACE') throw e; }

    // ход: доля, скорость (по последним секундам) и сколько осталось
    const title = fresh ? 'Скачиваю игру' : 'Скачиваю обновление';
    const marks = [[Date.now(), done]];
    let shown = 0;
    const report = force => {
      const now = Date.now();
      if (!force && now - shown < 150) return;
      shown = now;
      marks.push([now, done]);
      while (marks.length > 2 && now - marks[0][0] > 4000) marks.shift();
      const [t0, b0] = marks[0];
      const speed = now - t0 > 700 ? (done - b0) / ((now - t0) / 1000) : 0;
      let sub = '';
      if (speed > 1024) {
        const left = (total - done) / speed;
        sub = `${mb(speed).replace(' МБ', ' МБ/с')}` + (left > 90 ? ` · ещё ~${Math.ceil(left / 60)} мин` : left > 5 ? ` · ещё ~${Math.ceil(left)} с` : '');
      }
      say(`${title}: ${mb(Math.min(done, total)).replace(' МБ', '')} из ${mb(total)}`, total ? done / total : 1, sub);
    };
    report(true);
    const onBytes = n => { done += n; if (!stop.signal.aborted) report(false); };   // stop — ниже, вызывается уже после

    const queue = uniq.slice().sort((a, b) => (a.zst || a.size) - (b.zst || b.size));   // мелкие — первыми
    // Один файл не скачался совсем — останавливаем и второго работника (его загрузку обрываем), и ждём, пока оба
    // закончат: после возврата ничего не должно писать в game-dl и менять надпись лаунчера
    const stop = new AbortController();
    let failed = null;
    const worker = async () => {
      while (!failed && queue.length) {
        try { await this.fetchOne(queue.shift(), onBytes, stop.signal); } catch (e) {
          if (!failed) failed = e;
          queue.length = 0;
          stop.abort();
        }
      }
    };
    await Promise.allSettled(Array.from({ length: Math.min(WORKERS, queue.length) }, worker));
    if (failed) throw failed;
    report(true);
  }

  // недокачанный файл: сжатая копия — по своему sha256 (zsha), чтобы не докачивать в неё другую сжатую копию
  partOf(f) {
    return path.join(this.dl, f.zst ? f.zsha + '.zst.part' : f.sha256 + '.part');
  }

  async fetchOne(f, onBytes, stop) {
    const final = path.join(this.dl, f.sha256);
    if (sizeOf(final) === f.size) return;
    const zst = !!f.zst;
    const url = GAME_URL + 'f/' + (zst ? f.zsha + '.zst' : f.sha256);
    const part = this.partOf(f);
    const want = zst ? f.zst : f.size;
    for (let attempt = 1; ; attempt++) {
      try {
        await download(url, part, want, onBytes, stop);
        if (zst) {
          const tmp = final + '.tmp';
          // испорченным считаем только то, что не распаковалось или не сошлось с описью; ошибка диска (нет места,
          // файл занят антивирусом — у них есть syscall) — не повод выбрасывать скачанное и качать заново
          const ok = await unpack(part, tmp, f).catch(e => {
            fs.rmSync(tmp, { force: true });
            if (e && e.syscall) throw e;
            return false;
          });
          if (!ok) { fs.rmSync(tmp, { force: true }); throw Object.assign(new Error('файл пришёл повреждённым'), { bad: true }); }
          await rename(tmp, final);
          fs.rmSync(part, { force: true });
        } else {
          if ((await hashFile(part)) !== f.sha256) throw Object.assign(new Error('файл пришёл повреждённым'), { bad: true });
          await rename(part, final);
        }
        return;
      } catch (e) {
        if (e.bad) { onBytes(-Math.max(0, sizeOf(part))); fs.rmSync(part, { force: true }); }
        if (e.stopped || (stop && stop.aborted) || e.code === 'ENOSPC' || attempt >= TRIES) throw e;
        console.log(`попытка ${attempt}: ${f.sha256.slice(0, 12)} — ${e.message}`);
        await pause(Math.min(15000, 1000 * 2 ** (attempt - 1)), stop);
      }
    }
  }

  // новая копия игры в game-new/: неизменные файлы — ссылками на установленные, новые — из game-dl/
  async assemble(remote, keep) {
    await rmrf(this.next);
    await fsp.mkdir(this.next, { recursive: true });
    for (const [n, f] of Object.entries(remote.files)) {
      const src = keep.has(n) ? path.join(this.dir, n) : path.join(this.dl, f.sha256);
      await linkOrCopy(src, path.join(this.next, n));
    }
    writeAtomic(path.join(this.next, MANIFEST), remote.raw);
    if (!this.installed(this.next)) throw new Error('новая копия игры собралась не целиком');
  }

  // game-new/ встаёт на место game/ (старая копия — в game-old/ и удаляется)
  async swap() {
    await rmrf(this.old);
    if (fs.existsSync(this.dir)) {
      try { await rename(this.dir, this.old); } catch (e) {
        throw new Error('файлы игры заняты — закройте игру и попробуйте ещё раз');
      }
    }
    try { await rename(this.next, this.dir); } catch (e) {
      if (!fs.existsSync(this.dir) && fs.existsSync(this.old)) await rename(this.old, this.dir).catch(() => {});
      throw e;
    }
    await rmrf(this.old).catch(() => {});
  }
}

module.exports = { Updater, SITE, cmpVer, mb, readJson, writeJsonAtomic, validManifest, openSigned, PUBKEY_B64 };
