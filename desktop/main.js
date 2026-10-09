'use strict';
/* CivCity для Windows: игра в своём окне, без браузера.
   Файлы игры лежат внутри программы и отдаются по адресу app://game/ — так работают модули и загрузка моделей,
   а сохранение хранится в папке программы (как localStorage сайта). F11 — во весь экран. */

const { app, BrowserWindow, Menu, protocol, net, shell } = require('electron');
const path = require('path');
const { pathToFileURL } = require('url');

protocol.registerSchemesAsPrivileged([
  { scheme: 'app', privileges: { standard: true, secure: true, supportFetchAPI: true, corsEnabled: true, stream: true } },
]);

// в собранной программе игра лежит в resources/game, при запуске из папки — в game рядом
const ROOT = app.isPackaged ? path.join(process.resourcesPath, 'game') : path.join(__dirname, 'game');

if (!app.requestSingleInstanceLock()) app.quit();

let win = null;

function createWindow() {
  win = new BrowserWindow({
    width: 1440, height: 900, minWidth: 1024, minHeight: 640,
    title: 'CivCity',
    backgroundColor: '#d6e6e6',
    icon: path.join(__dirname, 'build', 'icon.png'),
    show: false,
    autoHideMenuBar: true,
    webPreferences: { contextIsolation: true, sandbox: true, backgroundThrottling: false },
  });
  // самопроверка при сборке (CIVCITY_SMOKE=1): окно не показывается, игра грузится, в консоль — итог
  const smoke = !!process.env.CIVCITY_SMOKE;
  if (!smoke) win.once('ready-to-show', () => { win.maximize(); win.show(); });
  else {
    const errors = [];
    win.webContents.on('console-message', (e) => { if (e.level === 'error' || e.level === 3) errors.push(e.message); });
    win.webContents.on('did-finish-load', () => setTimeout(async () => {
      const r = await win.webContents.executeJavaScript(`({ game: typeof Game !== 'undefined', three: !!window.THREE, look2: typeof Look2 !== 'undefined' && Look2.ready, fighters: !!window.Battle3D, roads: typeof Roads !== 'undefined' ? Roads.edges.size : -1 })`).catch(err => ({ err: String(err) }));
      console.log('SMOKE', JSON.stringify(r), 'errors:', JSON.stringify(errors.slice(0, 5)));
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

app.whenReady().then(() => {
  protocol.handle('app', req => {
    const u = new URL(req.url);
    let p = decodeURIComponent(u.pathname);
    if (p === '/' || p === '') p = '/index.html';
    const file = path.normalize(path.join(ROOT, p));
    if (!file.startsWith(ROOT)) return new Response('Нет доступа', { status: 403 });
    return net.fetch(pathToFileURL(file).toString());
  });
  Menu.setApplicationMenu(null);
  createWindow();
});

app.on('window-all-closed', () => app.quit());
