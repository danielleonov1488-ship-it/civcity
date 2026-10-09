'use strict';
/* CivCity для Windows.
   Сначала открывается лаунчер (desktop/launcher): новости с сервера, вход и регистрация, настройки, ход
   обновления и кнопка «Играть». Игра перед стартом сама обновляется с сайта (updater.js) — скачиваются
   только изменившиеся файлы. Вход общий у лаунчера и игры: программа хранит его в папке данных, токен
   зашифрован средствами Windows (пароль нигде не хранится).
   Файлы игры отдаются по адресу app://game/, лаунчер — по app://launcher/. F11 — во весь экран. */

const { app, BrowserWindow, Menu, protocol, net, shell, ipcMain, safeStorage } = require('electron');
const fs = require('fs');
const path = require('path');
const { pathToFileURL } = require('url');
const Updater = require('./updater');

protocol.registerSchemesAsPrivileged([
  { scheme: 'app', privileges: { standard: true, secure: true, supportFetchAPI: true, corsEnabled: true, stream: true } },
]);

// для проверок — отдельная папка данных, чтобы не трогать настоящие сохранения
if (process.env.CIVCITY_USERDATA) app.setPath('userData', process.env.CIVCITY_USERDATA);

// Игра: вложенная в программу (resources/game, при запуске из папки — game рядом) или скачанная обновлением
// (папка данных программы/game) — запускается та, что новее
const BUNDLED = app.isPackaged ? path.join(process.resourcesPath, 'game') : path.join(__dirname, 'game');
const LOCAL = path.join(app.getPath('userData'), 'game');
const LAUNCHER = path.join(__dirname, 'launcher');
const ICON = path.join(__dirname, 'build', 'icon.png');
const API = (process.env.CIVCITY_API || Updater.SITE + 'api').replace(/\/$/, '');
const smoke = !!process.env.CIVCITY_SMOKE;
let ROOT = BUNDLED;

// На ноутбуках с двумя видеокартами Windows по умолчанию отдаёт программу встроенной (Intel/AMD) — в разы слабее.
// Просим мощную; и не даём движку браузера отключать видеокарту из-за «чёрного списка» старых драйверов
app.commandLine.appendSwitch('force_high_performance_gpu');
app.commandLine.appendSwitch('ignore-gpu-blocklist');

if (!app.requestSingleInstanceLock()) app.quit();

/* ---------- Что программа помнит: вход и настройки лаунчера ---------- */

const STORE = path.join(app.getPath('userData'), 'launcher.json');
const CONTENT = path.join(app.getPath('userData'), 'launcher-content.json');
const DEF_PREFS = { quality: 'auto', fullscreen: false, autostart: false };
let store = { email: null, token: null, prefs: { ...DEF_PREFS } };

function loadStore() {
  try {
    const s = JSON.parse(fs.readFileSync(STORE, 'utf8'));
    let token = null;
    if (s.tokenEnc && safeStorage.isEncryptionAvailable()) { try { token = safeStorage.decryptString(Buffer.from(s.tokenEnc, 'base64')); } catch (e) { token = null; } }
    else if (s.token) token = s.token;
    store = { email: s.email || null, token, prefs: { ...DEF_PREFS, ...(s.prefs || {}) } };
  } catch (e) { /* первый запуск */ }
}

function saveStore() {
  const out = { email: store.email, prefs: store.prefs };
  if (store.token) {
    if (safeStorage.isEncryptionAvailable()) out.tokenEnc = safeStorage.encryptString(store.token).toString('base64');
    else out.token = store.token;
  }
  try { fs.mkdirSync(path.dirname(STORE), { recursive: true }); fs.writeFileSync(STORE, JSON.stringify(out)); } catch (e) { console.log('не удалось сохранить вход и настройки:', e.message); }
}

// Запрос к серверу игры; ошибки возвращаются как { error } — их текст показывает лаунчер
async function api(method, p, body, token) {
  const ctl = new AbortController();
  const t = setTimeout(() => ctl.abort(), 10000);
  try {
    const headers = {};
    if (body) headers['Content-Type'] = 'application/json';
    if (token) headers.Authorization = 'Bearer ' + token;
    const r = await net.fetch(API + p, { method, headers, body: body ? JSON.stringify(body) : undefined, signal: ctl.signal, cache: 'no-store' });
    let data = {};
    try { data = await r.json(); } catch (e) { /* не JSON */ }
    if (!r.ok) return { error: data.error || 'Сервер не ответил, попробуйте позже', status: r.status };
    return data;
  } catch (e) {
    return { error: 'Нет связи с сервером. Проверьте интернет и попробуйте ещё раз.', status: 0 };
  } finally { clearTimeout(t); }
}

/* ---------- Окна ---------- */

let launcher = null, game = null;
const upd = { text: 'Проверяю обновления…', p: null, done: false, shell: false, build: null };
let links = [];

function sendUpdate(s) {
  Object.assign(upd, s);
  if (launcher && !launcher.isDestroyed()) launcher.webContents.send('l:update', upd);
}

function createLauncher() {
  launcher = new BrowserWindow({
    width: 980, height: 620, resizable: false, maximizable: false, fullscreenable: false, frame: false, show: false,
    backgroundColor: '#f8f1e2', title: 'CivCity', icon: ICON,
    webPreferences: { preload: path.join(__dirname, 'preload-launcher.js'), contextIsolation: true, sandbox: true },
  });
  launcher.loadURL('app://launcher/index.html');
  launcher.once('ready-to-show', () => launcher.show());
  launcher.webContents.on('did-finish-load', () => launcher.webContents.send('l:update', upd));
  launcher.webContents.setWindowOpenHandler(() => ({ action: 'deny' }));
  launcher.webContents.on('will-navigate', e => e.preventDefault());
  launcher.on('closed', () => { launcher = null; });
}

function startGame() {
  if (game) return;
  ROOT = Updater.pickRoot(BUNDLED, LOCAL);
  game = new BrowserWindow({
    width: 1440, height: 900, minWidth: 1024, minHeight: 640,
    title: 'CivCity', backgroundColor: '#d6e6e6', icon: ICON, show: false, autoHideMenuBar: true,
    // свёрнутое окно не рисует кадры впустую — дни игра досчитывает по часам (Game.background)
    webPreferences: { preload: path.join(__dirname, 'preload-game.js'), contextIsolation: true, sandbox: true, backgroundThrottling: true },
  });
  // самопроверка при сборке (CIVCITY_SMOKE=1): окно не показывается, игра грузится, в консоль — итог
  if (!smoke) {
    game.once('ready-to-show', () => {
      if (store.prefs.fullscreen) game.setFullScreen(true); else game.maximize();
      game.show();
      if (launcher && !launcher.isDestroyed()) launcher.close();
    });
  } else {
    const errors = [];
    game.webContents.on('console-message', (e) => { if (e.level === 'error' || e.level === 3) errors.push(e.message); });
    game.webContents.on('did-finish-load', () => setTimeout(async () => {
      const r = await game.webContents.executeJavaScript(`({ game: typeof Game !== 'undefined', three: !!window.THREE, look2: typeof Look2 !== 'undefined' && Look2.ready, fighters: !!window.Battle3D, roads: typeof Roads !== 'undefined' ? Roads.edges.size : -1, desktop: !!window.civDesktop, gated: typeof Account !== 'undefined' && Account.gated })`).catch(err => ({ err: String(err) }));
      console.log('SMOKE', JSON.stringify(r), 'root:', ROOT === BUNDLED ? 'встроенная' : 'обновлённая', 'errors:', JSON.stringify(errors.slice(0, 5)));
      app.quit();
    }, 9000));
  }
  game.loadURL('app://game/index.html?desktop');
  // перед закрытием игра сохраняет город у себя и отправляет в облако (не дольше 4 секунд)
  let flushed = false;
  game.on('close', e => {
    if (flushed || smoke) return;
    e.preventDefault();
    const done = () => { flushed = true; game.close(); };
    Promise.race([
      game.webContents.executeJavaScript('typeof Account !== "undefined" ? Account.flush() : true').catch(() => true),
      new Promise(r => setTimeout(r, 4000)),
    ]).then(done, done);
  });
  game.on('closed', () => { game = null; });
  game.webContents.on('before-input-event', (e, input) => {
    if (input.type !== 'keyDown') return;
    if (input.key === 'F11') { game.setFullScreen(!game.isFullScreen()); e.preventDefault(); }
    if (input.key === 'Escape' && game.isFullScreen() && input.alt) { game.setFullScreen(false); e.preventDefault(); }
  });
  // ссылки наружу открываются в обычном браузере
  game.webContents.setWindowOpenHandler(({ url }) => { if (/^https?:/.test(url)) shell.openExternal(url); return { action: 'deny' }; });
  game.webContents.on('will-navigate', (e, url) => { if (!url.startsWith('app://')) { e.preventDefault(); shell.openExternal(url); } });
}

/* ---------- Связь окон с программой (только от своих окон) ---------- */

const fromLauncher = e => !!launcher && !launcher.isDestroyed() && e.sender === launcher.webContents;
const fromGame = e => !!game && !game.isDestroyed() && e.sender === game.webContents;

ipcMain.handle('l:info', e => {
  if (!fromLauncher(e)) return null;
  const m = Updater.readManifest(Updater.pickRoot(BUNDLED, LOCAL));
  return { email: store.token ? store.email : null, prefs: store.prefs, version: app.getVersion(), build: m ? m.version : null };
});

// новости и ссылки; без сети — те, что были в прошлый раз
ipcMain.handle('l:content', async e => {
  if (!fromLauncher(e)) return null;
  let c = await api('GET', '/launcher');
  if (c.error) { try { c = JSON.parse(fs.readFileSync(CONTENT, 'utf8')); } catch (err) { c = { news: [], links: [] }; } }
  else { try { fs.writeFileSync(CONTENT, JSON.stringify(c)); } catch (err) { /* не страшно */ } }
  links = Array.isArray(c.links) ? c.links.map(l => l && l.url).filter(Boolean) : [];
  return c;
});

ipcMain.handle('l:login', async (e, mode, email, password) => {
  if (!fromLauncher(e)) return { error: 'Нет доступа' };
  const r = await api('POST', mode === 'register' ? '/register' : '/login', { email: String(email || ''), password: String(password || '') });
  if (r.error) return { error: r.error };
  store.email = r.email;
  store.token = r.token;
  saveStore();
  return { email: r.email };
});

ipcMain.handle('l:forgot', async (e, email) => {
  if (!fromLauncher(e)) return { error: 'Нет доступа' };
  const r = await api('POST', '/forgot', { email: String(email || '') });
  return r.error ? { error: r.error } : { ok: true };
});

ipcMain.handle('l:logout', async e => {
  if (!fromLauncher(e)) return false;
  if (store.token) api('POST', '/logout', null, store.token);
  store.token = null;
  saveStore();
  return true;
});

ipcMain.handle('l:setPref', (e, key, value) => {
  if (!fromLauncher(e) || !(key in DEF_PREFS)) return store.prefs;
  store.prefs[key] = typeof DEF_PREFS[key] === 'boolean' ? !!value : ['auto', 'low', 'medium', 'high'].includes(value) ? value : DEF_PREFS[key];
  saveStore();
  return store.prefs;
});

ipcMain.handle('l:play', e => { if (fromLauncher(e) && store.token && upd.done) startGame(); });
ipcMain.handle('l:shell', e => { if (fromLauncher(e)) { shell.openExternal(Updater.SITE + 'download/CivCity-setup.exe'); app.quit(); } });

// наружу — только https: свой сайт и ссылки, которые прислал сервер
ipcMain.handle('l:open', (e, url) => {
  if (!fromLauncher(e)) return;
  try {
    const u = new URL(String(url));
    if (u.protocol === 'https:' && (/(^|\.)civcity\.ru$/.test(u.hostname) || links.includes(String(url)))) shell.openExternal(u.toString());
  } catch (err) { /* не адрес */ }
});

ipcMain.on('l:win', (e, what) => {
  if (!fromLauncher(e)) return;
  if (what === 'min') launcher.minimize(); else app.quit();
});

ipcMain.on('g:session', e => { e.returnValue = fromGame(e) && store.token ? { email: store.email, token: store.token } : null; });
ipcMain.on('g:setSession', (e, s) => {
  if (!fromGame(e)) return;
  if (s && s.token) { store.email = String(s.email || ''); store.token = String(s.token); } else store.token = null;
  saveStore();
});
ipcMain.on('g:api', e => { e.returnValue = API; });
ipcMain.on('g:prefs', e => { e.returnValue = fromGame(e) ? store.prefs : DEF_PREFS; });
ipcMain.on('g:setPref', (e, key, value) => {
  if (!fromGame(e) || key !== 'quality' || !['auto', 'low', 'medium', 'high'].includes(value)) return;
  store.prefs.quality = value;
  saveStore();
});

app.on('second-instance', () => { const w = game || launcher; if (w) { if (w.isMinimized()) w.restore(); w.focus(); } });

/* ---------- Запуск ---------- */

// файлы лаунчера; шрифты берём из игры
function serve(root, p) {
  const file = path.normalize(path.join(root, p));
  if (!file.startsWith(root)) return new Response('Нет доступа', { status: 403 });
  return net.fetch(pathToFileURL(file).toString());
}

app.whenReady().then(async () => {
  protocol.handle('app', req => {
    const u = new URL(req.url);
    let p = decodeURIComponent(u.pathname);
    if (p === '/' || p === '') p = '/index.html';
    if (u.hostname === 'launcher') return p.startsWith('/fonts/') ? serve(path.join(ROOT, 'vendor'), p) : serve(LAUNCHER, p);
    return serve(ROOT, p);
  });
  Menu.setApplicationMenu(null);
  loadStore();
  ROOT = Updater.pickRoot(BUNDLED, LOCAL);

  // самопроверка при сборке: без лаунчера, обновление — только если явно задан адрес
  if (smoke) {
    if (process.env.CIVCITY_UPDATE_URL) await Updater.run(BUNDLED, LOCAL, { set: (t) => console.log('обновление:', t), shell: async () => 'play' });
    startGame();
    return;
  }

  createLauncher();
  const r = await Updater.run(BUNDLED, LOCAL, {
    set: (text, p) => sendUpdate({ text, p }),
    // вышла новая программа: лаунчер показывает «Скачать», а играть можно и в этой
    shell: async () => { sendUpdate({ shell: true, text: 'Доступна новая версия программы', p: 1 }); return 'play'; },
  });
  if (r === 'quit') { app.quit(); return; }
  ROOT = Updater.pickRoot(BUNDLED, LOCAL);
  const m = Updater.readManifest(ROOT);
  sendUpdate({ done: true, p: 1, build: m ? m.version : null });
  // «запускать сразу»: если вход уже есть, лаунчер только мелькает
  if (store.prefs.autostart && store.token && !upd.shell) setTimeout(() => startGame(), 600);
});

app.on('window-all-closed', () => app.quit());
