'use strict';
/* CivCity для Windows: игра в своём окне, без браузера.
   Файлы игры лежат внутри программы и отдаются по адресу app://game/ — так работают модули и загрузка моделей,
   а сохранение хранится в папке программы (как localStorage сайта). F11 — во весь экран.
   Перед запуском игра сама обновляется с сайта (updater.js): скачиваются только изменившиеся файлы. */

const { app, BrowserWindow, Menu, protocol, net, shell } = require('electron');
const path = require('path');
const { pathToFileURL } = require('url');
const Updater = require('./updater');

protocol.registerSchemesAsPrivileged([
  { scheme: 'app', privileges: { standard: true, secure: true, supportFetchAPI: true, corsEnabled: true, stream: true } },
]);

// для проверок обновления — отдельная папка данных, чтобы не трогать настоящие сохранения
if (process.env.CIVCITY_USERDATA) app.setPath('userData', process.env.CIVCITY_USERDATA);

// Игра: вложенная в программу (resources/game, при запуске из папки — game рядом) или скачанная обновлением
// (папка данных программы/game) — запускается та, что новее
const BUNDLED = app.isPackaged ? path.join(process.resourcesPath, 'game') : path.join(__dirname, 'game');
const LOCAL = path.join(app.getPath('userData'), 'game');
let ROOT = BUNDLED;
const ICON = path.join(__dirname, 'build', 'icon.png');
const smoke = !!process.env.CIVCITY_SMOKE;
let starting = true;      // пока идёт обновление, закрытие окна-заставки не завершает программу

// На ноутбуках с двумя видеокартами Windows по умолчанию отдаёт программу встроенной (Intel/AMD) — в разы слабее.
// Просим мощную; и не даём движку браузера отключать видеокарту из-за «чёрного списка» старых драйверов
app.commandLine.appendSwitch('force_high_performance_gpu');
app.commandLine.appendSwitch('ignore-gpu-blocklist');

if (!app.requestSingleInstanceLock()) app.quit();

let win = null;

function createWindow() {
  win = new BrowserWindow({
    width: 1440, height: 900, minWidth: 1024, minHeight: 640,
    title: 'CivCity',
    backgroundColor: '#d6e6e6',
    icon: ICON,
    show: false,
    autoHideMenuBar: true,
    // свёрнутое окно не рисует кадры впустую — дни игра досчитывает по часам (Game.background)
    webPreferences: { contextIsolation: true, sandbox: true, backgroundThrottling: true },
  });
  // самопроверка при сборке (CIVCITY_SMOKE=1): окно не показывается, игра грузится, в консоль — итог
  if (!smoke) win.once('ready-to-show', () => { win.maximize(); win.show(); });
  else {
    const errors = [];
    win.webContents.on('console-message', (e) => { if (e.level === 'error' || e.level === 3) errors.push(e.message); });
    win.webContents.on('did-finish-load', () => setTimeout(async () => {
      const r = await win.webContents.executeJavaScript(`({ game: typeof Game !== 'undefined', three: !!window.THREE, look2: typeof Look2 !== 'undefined' && Look2.ready, fighters: !!window.Battle3D, roads: typeof Roads !== 'undefined' ? Roads.edges.size : -1 })`).catch(err => ({ err: String(err) }));
      console.log('SMOKE', JSON.stringify(r), 'root:', ROOT === BUNDLED ? 'встроенная' : 'обновлённая', 'errors:', JSON.stringify(errors.slice(0, 5)));
      app.quit();
    }, 9000));
  }
  win.loadURL('app://game/index.html?desktop');
  // перед закрытием игра сохраняет город у себя и отправляет в облако (не дольше 4 секунд)
  let flushed = false;
  win.on('close', e => {
    if (flushed || smoke) return;
    e.preventDefault();
    const done = () => { flushed = true; win.close(); };
    Promise.race([
      win.webContents.executeJavaScript('typeof Account !== "undefined" ? Account.flush() : true').catch(() => true),
      new Promise(r => setTimeout(r, 4000)),
    ]).then(done, done);
  });
  win.webContents.on('before-input-event', (e, input) => {
    if (input.type !== 'keyDown') return;
    if (input.key === 'F11') { win.setFullScreen(!win.isFullScreen()); e.preventDefault(); }
    if (input.key === 'Escape' && win.isFullScreen() && input.alt) { win.setFullScreen(false); e.preventDefault(); }
  });
  // ссылки наружу открываются в обычном браузере
  win.webContents.setWindowOpenHandler(({ url }) => { if (/^https?:/.test(url)) shell.openExternal(url); return { action: 'deny' }; });
  win.webContents.on('will-navigate', (e, url) => { if (!url.startsWith('app://')) { e.preventDefault(); shell.openExternal(url); } });
}

app.on('second-instance', () => { if (win) { if (win.isMinimized()) win.restore(); win.focus(); } });

app.whenReady().then(async () => {
  protocol.handle('app', req => {
    const u = new URL(req.url);
    let p = decodeURIComponent(u.pathname);
    if (p === '/' || p === '') p = '/index.html';
    const file = path.normalize(path.join(ROOT, p));
    if (!file.startsWith(ROOT)) return new Response('Нет доступа', { status: 403 });
    return net.fetch(pathToFileURL(file).toString());
  });
  Menu.setApplicationMenu(null);
  // обновление перед стартом; при самопроверке — только если явно задан адрес обновлений
  if (!smoke || process.env.CIVCITY_UPDATE_URL) {
    if (await Updater.run(BUNDLED, LOCAL, ICON) === 'quit') { app.quit(); return; }
  }
  ROOT = Updater.pickRoot(BUNDLED, LOCAL);
  createWindow();
  starting = false;
});

app.on('window-all-closed', () => { if (!starting) app.quit(); });
