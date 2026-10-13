'use strict';
/* CivCity для Windows — лаунчер.
   Окно лаунчера (desktop/launcher): новости с сервера, вход и регистрация, настройки, ход загрузки и «Играть».
   Сама игра — отдельная программа на движке Godot (CivCity.exe и наборы .pck). Лаунчер скачивает её в свою
   папку данных (game/) и держит свежей (updater.js), а по «Играть» запускает, передавая вход и папку сохранений:
     CIVCITY_SESSION = {"token": "…", "email": "…", "api": "https://civcity.ru/api"}
     CIVCITY_SAVEDIR = <папка данных>/saves   (город city.json и настройки игры settings.json)
   Пока игра открыта, лаунчер спрятан; закрыли игру — он возвращается.
   Вход хранится в папке данных, токен зашифрован средствами Windows (пароль нигде не хранится).

   Для проверок (переменные окружения): CIVCITY_USERDATA — своя папка данных, CIVCITY_UPDATE_URL — свой сайт
   (там game/manifest.json), CIVCITY_API — свой сервер аккаунтов, CIVCITY_GAME_ARGS — JSON-список доп. аргументов
   игры, CIVCITY_SMOKE=1 — самопроверка: после загрузки сам жмёт «Играть», когда игра закроется — выходит
   (CIVCITY_SMOKE_CLOSE=N — закрыть окно игры через N секунд), CIVCITY_SHOTS — папка для снимков окна лаунчера. */

const { app, BrowserWindow, Menu, protocol, net, shell, ipcMain, safeStorage } = require('electron');
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');
const { pathToFileURL } = require('url');
const { Updater, SITE, readJson, writeJsonAtomic } = require('./updater');

protocol.registerSchemesAsPrivileged([
  { scheme: 'app', privileges: { standard: true, secure: true, supportFetchAPI: true, corsEnabled: true, stream: true } },
]);

// для проверок — отдельная папка данных, чтобы не трогать настоящие сохранения
if (process.env.CIVCITY_USERDATA) app.setPath('userData', process.env.CIVCITY_USERDATA);

// Лаунчеру видеокарта не нужна (простое окно), а игре она нужна целиком — не будим её зря
app.disableHardwareAcceleration();

const DATA = app.getPath('userData');
const SAVES = path.join(DATA, 'saves');
const GAME_SETTINGS = path.join(SAVES, 'settings.json');
const LAUNCHER = path.join(__dirname, 'launcher');
const ICON = path.join(__dirname, 'build', 'icon.png');
const API = (process.env.CIVCITY_API || SITE + 'api').replace(/\/$/, '');
const smoke = !!process.env.CIVCITY_SMOKE;
const SHOTS = process.env.CIVCITY_SHOTS || '';
// Второй запуск программы: сразу выходим. app.quit() до 'ready' только ставит флаг — 'ready' всё равно
// приходит, и второй экземпляр успевал бы тронуть папки игры (recover() удалял game-new у первого, пока тот ставит
// обновление). app.exit() выходит сразу; первый экземпляр получит 'second-instance' и покажет своё окно.
if (!app.requestSingleInstanceLock()) {
  app.exit(0);
  return;
}
const updater = new Updater(DATA);

/* ---------- Журнал (для разбора, если у игрока что-то не так): папка данных/launcher.log ---------- */

const LOG = path.join(DATA, 'launcher.log');
function log(...a) {
  const line = new Date().toISOString() + ' ' + a.join(' ');
  console.log(line);
  try {
    if (fs.existsSync(LOG) && fs.statSync(LOG).size > 256 * 1024) fs.renameSync(LOG, LOG + '.1');
    fs.appendFileSync(LOG, line + '\n');
  } catch (e) { /* не страшно */ }
}

/* ---------- Что программа помнит: вход и настройки лаунчера ---------- */

const STORE = path.join(DATA, 'launcher.json');
const CONTENT = path.join(DATA, 'launcher-content.json');
const QUALITY = ['low', 'medium', 'high'];
let store = { email: null, token: null, prefs: { autostart: false } };

function loadStore() {
  try {
    const s = JSON.parse(fs.readFileSync(STORE, 'utf8'));
    let token = null;
    if (s.tokenEnc && safeStorage.isEncryptionAvailable()) { try { token = safeStorage.decryptString(Buffer.from(s.tokenEnc, 'base64')); } catch (e) { token = null; } }
    else if (s.token) token = s.token;
    const p = s.prefs || {};
    store = { email: s.email || null, token, prefs: { autostart: !!p.autostart } };
    // из лаунчера 0.9: качество и «во весь экран» теперь хранит сама игра — переносим, если игра ещё не настроена
    if (!fs.existsSync(GAME_SETTINGS) && (p.fullscreen || QUALITY.includes(p.quality))) {
      const g = {};
      if (p.fullscreen) g.fullscreen = true;
      if (QUALITY.includes(p.quality)) g.quality = p.quality;
      try { fs.mkdirSync(SAVES, { recursive: true }); writeJsonAtomic(GAME_SETTINGS, g); } catch (e) { /* не страшно */ }
    }
  } catch (e) { /* первый запуск */ }
}

function saveStore() {
  const out = { email: store.email, prefs: store.prefs };
  if (store.token) {
    if (safeStorage.isEncryptionAvailable()) out.tokenEnc = safeStorage.encryptString(store.token).toString('base64');
    else out.token = store.token;
  }
  try { fs.mkdirSync(DATA, { recursive: true }); fs.writeFileSync(STORE, JSON.stringify(out)); } catch (e) { log('не удалось сохранить вход и настройки:', e.message); }
}

// Качество графики и «во весь экран» — настройки самой игры (settings.json в папке сохранений):
// лаунчер показывает и меняет их там же, поэтому в игре и в лаунчере они всегда одинаковые
function gamePrefs() {
  const g = readJson(GAME_SETTINGS) || {};
  return { quality: QUALITY.includes(g.quality) ? g.quality : 'high', fullscreen: !!g.fullscreen, autostart: store.prefs.autostart };
}

function setGamePref(key, value) {
  const g = readJson(GAME_SETTINGS) || {};
  g[key] = value;
  fs.mkdirSync(SAVES, { recursive: true });
  writeJsonAtomic(GAME_SETTINGS, g);
}

// Запрос к серверу игры; ошибки возвращаются как { error, status } — их текст показывает лаунчер
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

/* ---------- Состояние: загрузка игры и сама игра ---------- */

let launcher = null;
let links = [];
let task = null;          // идущая проверка/загрузка игры
let lastCheck = 0;        // когда в последний раз сверялись с сайтом
let child = null;         // запущенная игра
let starting = false;     // «Играть» нажато, игра ещё запускается
// что видит лаунчер: текст и доля под полоской, подстрочник (скорость), занят ли, есть ли установленная игра,
// нужна ли новая версия программы, запущена ли игра, версия установленной игры
const upd = { text: 'Проверяю обновления…', sub: '', p: null, busy: true, ready: false, shell: false, running: false, starting: false, game: null };

function gameInfo(m) { return m ? { version: m.version || '', build: m.build || null } : null; }

function sendUpdate(s) {
  Object.assign(upd, s);
  if (launcher && !launcher.isDestroyed()) launcher.webContents.send('l:update', upd);
}

function readyText(m) {
  return m ? `Игра готова · версия ${m.version || '?'}${m.build ? ` (сборка ${m.build})` : ''}` : 'Игра ещё не скачана';
}

// Проверить и при нужде скачать игру; одновременно — только одна такая работа
function prepare(opts = {}) {
  if (task) return task;
  task = (async () => {
    sendUpdate({ busy: true, sub: '', p: null, text: opts.verify ? 'Проверяю файлы игры…' : 'Проверяю обновления…' });
    let shotDl = !SHOTS;
    let live = true;          // после конца проверки запоздалый ход загрузки надпись уже не меняет
    const r = await updater.ensure({
      verify: !!opts.verify,
      onStatus: (text, p, sub) => {
        if (!live) return;
        sendUpdate({ text, p, sub: sub || '' });
        if (!shotDl && p > 0.15) { shotDl = true; shot('download'); }
      },
    });
    live = false;
    lastCheck = Date.now();
    log('обновление:', r.state, r.manifest ? `${r.manifest.version}/${r.manifest.build}` : '-', r.error || '');
    const m = r.manifest || updater.installed();
    const s = { busy: false, sub: '', p: 1, ready: !!m, game: gameInfo(m), shell: r.state === 'shell' };
    if (r.state === 'ready' || r.state === 'updated') s.text = r.state === 'updated' && !r.fresh ? 'Игра обновлена · ' + readyText(m).replace('Игра готова · ', '') : readyText(m);
    else if (r.state === 'offline') s.text = 'Нет связи с сервером — играем в установленной версии';
    else if (r.state === 'shell') s.text = m ? 'Вышла новая версия программы — играть можно и в этой' : 'Нужна новая версия программы CivCity';
    else { s.text = r.error; s.p = m ? 1 : 0; }
    sendUpdate(s);
    return r;
  })().finally(() => { task = null; });
  return task;
}

// «Играть»: вход ещё действует → игра свежая → запуск
async function play(why) {
  if (child || starting) return {};
  if (!store.token) return { error: 'Сначала войдите в аккаунт' };
  starting = true;
  sendUpdate({ starting: true });
  try {
    // без сети тоже играем: город сохранится у себя и уйдёт в облако, когда связь появится
    const me = await api('GET', '/me', null, store.token);
    if (me.status === 401) {
      store.token = null;
      saveStore();
      return { relogin: me.error || 'Вход устарел — войдите снова' };
    }
    if (me.email && me.email !== store.email) { store.email = me.email; saveStore(); }
    if (task) await task;
    else if (!updater.installed() || Date.now() - lastCheck > 60000) await prepare();
    const m = updater.installed();
    if (!m) return { error: upd.text };
    return launch(m, why);
  } finally {
    starting = false;
    sendUpdate({ starting: false });
  }
}

function launch(m, why) {
  const exe = updater.exePath(m);
  fs.mkdirSync(SAVES, { recursive: true });
  const env = { ...process.env };
  for (const k of Object.keys(env)) if (/^(ELECTRON_|CIVCITY_)/.test(k)) delete env[k];
  env.CIVCITY_SESSION = JSON.stringify({ token: store.token, email: store.email, api: API });
  env.CIVCITY_SAVEDIR = SAVES;
  let args = [];
  try { if (process.env.CIVCITY_GAME_ARGS) args = JSON.parse(process.env.CIVCITY_GAME_ARGS).map(String); } catch (e) { log('CIVCITY_GAME_ARGS — не JSON'); }
  const started = Date.now();
  let p;
  try {
    p = spawn(exe, args, { cwd: path.dirname(exe), env, stdio: 'ignore', windowsHide: false });
  } catch (e) {
    log('запуск игры не удался:', e.message);
    return { error: 'Не удалось запустить игру: ' + e.message };
  }
  child = p;
  log('игра запущена:', exe, m.version + '/' + m.build, why, JSON.stringify(args));
  sendUpdate({ running: true, text: 'Игра запущена', sub: '' });
  let hideTimer = null;
  p.once('spawn', () => {
    // пока окно игры появляется, лаунчер ещё виден; потом прячется до её закрытия
    hideTimer = setTimeout(() => { if (child === p && launcher && !launcher.isDestroyed()) launcher.hide(); }, 1500);
    if (SHOTS) setTimeout(() => shot('running'), 600);
    // самопроверка: закрыть окно игры через N секунд, как крестиком (игра сохраняет город и выходит)
    const close = +process.env.CIVCITY_SMOKE_CLOSE || 0;
    if (smoke && close) setTimeout(() => { if (child === p) spawn('taskkill', ['/PID', String(p.pid)], { stdio: 'ignore', windowsHide: true }); }, close * 1000);
  });
  let ended = false;
  const end = (code, err) => {
    if (ended) return;
    ended = true;
    clearTimeout(hideTimer);
    if (child === p) child = null;
    lastCheck = 0;           // следующее «Играть» снова сверится с сайтом
    const secs = Math.round((Date.now() - started) / 1000);
    const crashed = !!err || (code !== 0 && secs < 20);
    log('игра закрылась:', err ? 'ошибка ' + err.message : 'код ' + code, `через ${secs} с`);
    if (smoke) { console.log('SMOKE game-exit', JSON.stringify({ code, err: err ? err.message : null, secs })); setTimeout(() => app.quit(), 1500); }
    if ((why === 'autostart' && !crashed && !smoke) || !launcher || launcher.isDestroyed()) { if (!smoke) app.quit(); return; }
    const text = err ? 'Не удалось запустить игру: ' + err.message
      : crashed ? `Игра закрылась с ошибкой (код ${code}). Нажмите «Играть» ещё раз; не поможет — «Проверить файлы игры».`
      : readyText(updater.installed());
    sendUpdate({ running: false, text, sub: '', p: 1 });
    showLauncher();
    if (SHOTS) setTimeout(() => shot('after'), 800);
  };
  p.once('error', e => end(null, e));
  p.once('exit', code => end(code, null));
  return { ok: true };
}

function showLauncher() {
  if (!launcher || launcher.isDestroyed()) return;
  if (launcher.isMinimized()) launcher.restore();
  launcher.show();
  launcher.moveTop();
  launcher.focus();
}

// снимок окна лаунчера (для проверок, CIVCITY_SHOTS)
async function shot(name) {
  if (!SHOTS || !launcher || launcher.isDestroyed()) return;
  try {
    const img = await launcher.webContents.capturePage();
    fs.mkdirSync(SHOTS, { recursive: true });
    fs.writeFileSync(path.join(SHOTS, `launcher_${name}.png`), img.toPNG());
  } catch (e) { log('снимок не вышел:', e.message); }
}

/* ---------- Окно лаунчера ---------- */

function createLauncher() {
  launcher = new BrowserWindow({
    width: 980, height: 620, resizable: false, maximizable: false, fullscreenable: false, frame: false, show: false,
    backgroundColor: '#f8f1e2', title: 'CivCity', icon: fs.existsSync(ICON) ? ICON : undefined,   // в собранной программе — значок из exe
    webPreferences: { preload: path.join(__dirname, 'preload-launcher.js'), contextIsolation: true, sandbox: true },
  });
  launcher.loadURL('app://launcher/index.html');
  launcher.once('ready-to-show', () => launcher.show());
  launcher.webContents.on('did-finish-load', () => launcher.webContents.send('l:update', upd));
  launcher.webContents.setWindowOpenHandler(() => ({ action: 'deny' }));
  launcher.webContents.on('will-navigate', e => e.preventDefault());
  launcher.on('closed', () => { launcher = null; });
}

/* ---------- Связь с окном лаунчера (только от него) ---------- */

const fromLauncher = e => !!launcher && !launcher.isDestroyed() && e.sender === launcher.webContents;

ipcMain.handle('l:info', e => {
  if (!fromLauncher(e)) return null;
  return { email: store.token ? store.email : null, prefs: gamePrefs(), version: app.getVersion(), game: gameInfo(updater.installed()) };
});

// новости и ссылки; без сети — те, что были в прошлый раз
ipcMain.handle('l:content', async e => {
  if (!fromLauncher(e)) return null;
  let c = await api('GET', '/launcher');
  if (c.error) { try { c = JSON.parse(fs.readFileSync(CONTENT, 'utf8')); } catch (err) { c = { news: [], links: [] }; } }
  else { try { fs.writeFileSync(CONTENT, JSON.stringify(c)); } catch (err) { /* не страшно */ } }
  links = Array.isArray(c.links) ? c.links.map(l => l && l.url).filter(Boolean) : [];
  if (SHOTS) setTimeout(() => shot(store.token ? 'start' : 'login'), 700);
  return c;
});

ipcMain.handle('l:login', async (e, mode, email, password, consent) => {
  if (!fromLauncher(e)) return { error: 'Нет доступа' };
  const body = { email: String(email || ''), password: String(password || '') };
  if (mode === 'register') body.consent = consent === true;     // галочка согласия на обработку данных
  const r = await api('POST', mode === 'register' ? '/register' : '/login', body);
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
  if (!fromLauncher(e)) return gamePrefs();
  try {
    if (key === 'autostart') { store.prefs.autostart = !!value; saveStore(); }
    else if (!child && key === 'fullscreen') setGamePref('fullscreen', !!value);
    else if (!child && key === 'quality' && QUALITY.includes(value)) setGamePref('quality', value);
  } catch (err) { log('настройка не сохранилась:', err.message); }
  return gamePrefs();
});

ipcMain.handle('l:play', e => (fromLauncher(e) ? play('button') : null));
ipcMain.handle('l:verify', async e => {
  if (!fromLauncher(e) || child || task) return;
  await prepare({ verify: true });
});
ipcMain.handle('l:saves', e => {
  if (!fromLauncher(e)) return;
  fs.mkdirSync(SAVES, { recursive: true });
  shell.openPath(SAVES);
});
ipcMain.handle('l:shell', e => { if (fromLauncher(e)) { shell.openExternal(SITE + 'download/CivCity-setup.exe'); if (!child) app.quit(); } });

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
  if (what === 'min') launcher.minimize(); else if (!child) app.quit(); else launcher.hide();
});

// второй запуск программы: показать уже открытый лаунчер
app.on('second-instance', () => {
  showLauncher();
  if (child) sendUpdate({ text: 'Игра уже запущена' });
});

/* ---------- Запуск ---------- */

function serve(root, p) {
  const file = path.normalize(path.join(root, p));
  if (!file.startsWith(root + path.sep)) return new Response('Нет доступа', { status: 403 });
  return net.fetch(pathToFileURL(file).toString());
}

app.whenReady().then(async () => {
  protocol.handle('app', req => {
    const u = new URL(req.url);
    let p = decodeURIComponent(u.pathname);
    if (p === '/' || p === '') p = '/index.html';
    if (u.hostname !== 'launcher') return new Response('Нет такого адреса', { status: 404 });
    return serve(LAUNCHER, p);
  });
  Menu.setApplicationMenu(null);
  fs.mkdirSync(DATA, { recursive: true });
  loadStore();
  log(`лаунчер ${app.getVersion()} запущен; сайт ${SITE}, сервер ${API}`);
  const have = updater.installed();
  sendUpdate({ ready: !!have, game: gameInfo(have) });
  createLauncher();

  const r = await prepare();
  if (smoke) {
    console.log('SMOKE update', JSON.stringify({ state: r.state, version: r.manifest && r.manifest.version, build: r.manifest && r.manifest.build, error: r.error || null, login: !!store.token }));
    if (SHOTS) { await new Promise(r => setTimeout(r, 600)); await shot('ready'); }
    const p = store.token && upd.ready ? await play('smoke') : { error: 'нет входа или игры' };
    console.log('SMOKE play', JSON.stringify(p));
    if (!p.ok) setTimeout(() => app.quit(), 500);
    return;
  }
  // «запускать сразу»: если вход уже есть, лаунчер только мелькает
  if (store.prefs.autostart && store.token && upd.ready && !upd.shell) setTimeout(() => play('autostart'), 600);
});

app.on('window-all-closed', () => { if (!child) app.quit(); });
