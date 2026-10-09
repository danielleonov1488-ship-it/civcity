'use strict';
/* Самообновление игры в программе для ПК.
   Перед запуском программа сверяет свою копию игры с описью на сайте (game-manifest.json) и скачивает
   только изменившиеся файлы — обычно это сотни килобайт. Каждый файл проверяется по sha256; новая копия
   собирается рядом и встаёт на место старой одним переименованием, так что недокачанное обновление
   никогда не ломает рабочую версию. Нет сети — игра запускается как есть.
   Если на сайте игра требует более новую саму программу, предлагаем скачать установщик (сами .exe не ставим:
   подменённый на сервере установщик был бы опасен, а файлы игры работают в песочнице, как сайт). */
const { app, BrowserWindow, net, shell } = require('electron');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const SITE = (process.env.CIVCITY_UPDATE_URL || 'https://civcity.ru/').replace(/\/?$/, '/');
const MANIFEST = 'game-manifest.json';
// в описи — только файлы игры; путь с «..» или чем-то ещё — повод ничего не трогать
const ALLOWED = /^(index\.html|style\.css|(js|vendor|assets)\/[A-Za-z0-9_.\-/ ]+)$/;

const sleep = ms => new Promise(r => setTimeout(r, ms));
const sha256 = buf => crypto.createHash('sha256').update(buf).digest('hex');
const newer = (a, b) => (+a || 0) > (+b || 0);

function readManifest(dir) {
  try { return JSON.parse(fs.readFileSync(path.join(dir, MANIFEST), 'utf8')); } catch (e) { return null; }
}

// 0.9.10 > 0.9.2
function cmpVer(a, b) {
  const x = String(a).split('.').map(Number), y = String(b).split('.').map(Number);
  for (let i = 0; i < 3; i++) if ((x[i] || 0) !== (y[i] || 0)) return (x[i] || 0) - (y[i] || 0);
  return 0;
}

// Какую копию запускать: скачанную обновлением, если она новее вложенной в программу (после переустановки
// программы вложенная может оказаться новее — тогда она)
function pickRoot(bundled, local) {
  const b = readManifest(bundled), l = readManifest(local);
  if (l && fs.existsSync(path.join(local, 'index.html')) && (!b || newer(l.version, b.version))) return local;
  return bundled;
}

async function fetchBuf(url, ms) {
  const ctl = new AbortController();
  const t = setTimeout(() => ctl.abort(), ms);
  try {
    const r = await net.fetch(url, { signal: ctl.signal, cache: 'no-store' });
    if (!r.ok) throw new Error('HTTP ' + r.status);
    return Buffer.from(await r.arrayBuffer());
  } finally { clearTimeout(t); }
}

const SPLASH = `<!doctype html><html><head><meta charset="utf-8"><title>CivCity</title><style>
  html,body{margin:0;height:100%;background:#f4ecdc;font:15px/1.4 "Segoe UI",system-ui,sans-serif;color:#4a3626;user-select:none;-webkit-app-region:drag}
  .box{display:flex;flex-direction:column;justify-content:center;height:100%;padding:0 34px;box-sizing:border-box;gap:12px}
  h1{margin:0;font:600 30px/1 Georgia,"Times New Roman",serif;letter-spacing:.08em;color:#b5542f}
  #t{min-height:21px} .bar{height:8px;border-radius:5px;background:#e3d5bc;overflow:hidden}
  #f{height:100%;width:0;background:linear-gradient(90deg,#c8553d,#e9b949);transition:width .2s}
  .bar.wait #f{width:30%;animation:w 1.2s ease-in-out infinite alternate} @keyframes w{to{margin-left:70%}}
  .btns{display:none;gap:10px;-webkit-app-region:no-drag} .btns.on{display:flex}
  button{font:inherit;padding:8px 16px;border-radius:9px;border:1px solid #c9b291;background:#fffaf0;color:#4a3626;cursor:pointer}
  button.main{background:#b5542f;border-color:#b5542f;color:#fff}
</style></head><body><div class="box"><h1>CIVCITY</h1><div id="t">Проверяю обновления…</div>
  <div class="bar wait" id="b"><div id="f"></div></div>
  <div class="btns" id="q"><button class="main" onclick="document.title='download'">Скачать новую версию</button><button onclick="document.title='play'">Играть в этой</button></div>
</div><script>
  function set(t, p) { document.getElementById('t').textContent = t; const b = document.getElementById('b');
    b.classList.toggle('wait', p === null); document.getElementById('f').style.width = p === null ? '' : Math.round(p * 100) + '%'; }
  function ask() { set('Вышла новая версия программы CivCity. Скачайте и установите её — город сохранится.', 1);
    document.getElementById('b').style.display = 'none'; document.getElementById('q').classList.add('on'); }
</script></body></html>`;

function openSplash(icon) {
  const w = new BrowserWindow({
    width: 460, height: 230, frame: false, resizable: false, maximizable: false, center: true, show: false,
    backgroundColor: '#f4ecdc', title: 'CivCity', icon, webPreferences: { sandbox: true, contextIsolation: true },
  });
  const ready = new Promise(r => w.webContents.once('did-finish-load', r));
  w.loadURL('data:text/html;charset=utf-8,' + encodeURIComponent(SPLASH));
  w.once('ready-to-show', () => w.show());
  const call = async js => { await ready; if (!w.isDestroyed()) await w.webContents.executeJavaScript(js).catch(() => {}); };
  return {
    w,
    set: (text, p) => call(`set(${JSON.stringify(text)}, ${p == null ? 'null' : p})`),
    ask: () => new Promise(res => {
      call('ask()');
      w.on('page-title-updated', (e, title) => { if (title === 'download' || title === 'play') res(title); });
      w.on('closed', () => res('play'));
    }),
    close: () => { if (!w.isDestroyed()) w.close(); },
  };
}

// Возвращает 'quit', если игрок пошёл скачивать новую программу; иначе — после обновления или без него
async function run(bundled, local, icon) {
  const ui = openSplash(icon);
  try {
    let remote;
    try { remote = JSON.parse((await fetchBuf(SITE + MANIFEST + '?t=' + Date.now(), 5000)).toString('utf8')); } catch (e) { return; }
    if (!remote || !remote.files || !remote.version) return;

    if (remote.shell && cmpVer(remote.shell, app.getVersion()) > 0) {
      if (await ui.ask() === 'download') { shell.openExternal(SITE + 'download/CivCity-setup.exe'); return 'quit'; }
      return;
    }

    const root = pickRoot(bundled, local), cur = readManifest(root);
    if (cur && !newer(remote.version, cur.version)) return;

    const entries = Object.entries(remote.files);
    for (const [p, f] of entries) {
      if (!ALLOWED.test(p) || p.split('/').includes('..') || !/^[0-9a-f]{64}$/.test(f.h) || !(f.s >= 0)) throw new Error('опись повреждена: ' + p);
    }
    const same = ([p, f]) => cur && cur.files && cur.files[p] && cur.files[p].h === f.h && fs.existsSync(path.join(root, p));
    const need = entries.filter(e => !same(e));
    const stage = local + '-new';
    fs.rmSync(stage, { recursive: true, force: true });
    const put = (p, buf) => { const dst = path.join(stage, p); fs.mkdirSync(path.dirname(dst), { recursive: true }); fs.writeFileSync(dst, buf); };
    // неизменные файлы — копией из текущей версии, изменившиеся — с сайта
    for (const e of entries) if (same(e)) { const dst = path.join(stage, e[0]); fs.mkdirSync(path.dirname(dst), { recursive: true }); fs.copyFileSync(path.join(root, e[0]), dst); }
    const total = need.reduce((s, [, f]) => s + f.s, 0) || 1;
    let got = 0;
    ui.set('Обновляю игру…', 0);
    const queue = need.slice();
    const worker = async () => {
      while (queue.length) {
        const [p, f] = queue.shift();
        for (let attempt = 0; ; attempt++) {
          try {
            const buf = await fetchBuf(SITE + p.split('/').map(encodeURIComponent).join('/') + '?h=' + f.h.slice(0, 12), 60000);
            if (sha256(buf) !== f.h) throw new Error('файл пришёл повреждённым: ' + p);
            put(p, buf);
            break;
          } catch (e) { if (attempt >= 2) throw e; await sleep(500); }
        }
        got += f.s;
        ui.set('Обновляю игру…', got / total);
      }
    };
    await Promise.all([worker(), worker(), worker(), worker()]);
    fs.writeFileSync(path.join(stage, MANIFEST), JSON.stringify(remote));
    // новая копия встаёт на место старой
    const old = local + '-old';
    fs.rmSync(old, { recursive: true, force: true });
    if (fs.existsSync(local)) fs.renameSync(local, old);
    fs.renameSync(stage, local);
    fs.rmSync(old, { recursive: true, force: true });
    ui.set('Готово', 1);
    await sleep(250);
  } catch (e) {
    console.log('обновление не удалось:', e.message);
    fs.rmSync(local + '-new', { recursive: true, force: true });
    ui.set('Обновить не вышло — запускаю прежнюю версию', null);
    await sleep(1500);
  } finally {
    ui.close();
  }
}

module.exports = { run, pickRoot, readManifest };
