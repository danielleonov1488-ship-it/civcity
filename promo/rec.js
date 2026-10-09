'use strict';
/* Запись клипов для ролика: Electron открывает город для съёмок (#promo) в скрытом окне со своей видеокартой
   и запускает в нём сценарий съёмки (promo/shots.js). Кадры уходят в приёмник (capture.py → ffmpeg).
   Запуск: cd desktop && npx electron ../promo/rec.js [имя клипа ...] [--vertical] */
const { app, BrowserWindow } = require('electron');
const fs = require('fs');
const path = require('path');

app.commandLine.appendSwitch('ignore-gpu-blocklist');
app.commandLine.appendSwitch('disable-renderer-backgrounding');
app.commandLine.appendSwitch('disable-background-timer-throttling');

const only = process.argv.slice(2).filter(a => !a.startsWith('-') && !a.endsWith('.js') && a !== '.');
const vertical = process.argv.includes('--vertical'); // кадр 1440×2560 для TikTok/Shorts
const script = fs.readFileSync(path.join(__dirname, 'shots.js'), 'utf8');

app.whenReady().then(async () => {
  const win = new BrowserWindow({ show: false, width: 1280, height: 720, webPreferences: { backgroundThrottling: false, offscreen: false } });
  win.webContents.on('console-message', e => { if (e.level === 'error' || e.level === 3) console.log('[страница]', e.message); });
  await win.loadURL('http://localhost:5180/?rec=' + Date.now() + '#promo');
  const wait = ms => new Promise(r => setTimeout(r, ms));
  for (let i = 0; i < 240; i++) {
    const ok = await win.webContents.executeJavaScript('typeof Cinema !== "undefined" && typeof state !== "undefined" && !!state.testReady && !!Engine.renderer && !!window.Battle3D').catch(() => false);
    if (ok) break;
    await wait(500);
  }
  const gpu = await win.webContents.executeJavaScript(`(() => { const gl = Engine.renderer.getContext(); const e = gl.getExtension('WEBGL_debug_renderer_info'); return e ? gl.getParameter(e.UNMASKED_RENDERER_WEBGL) : 'нет данных'; })()`);
  console.log('видеокарта:', gpu);
  await win.webContents.executeJavaScript(script + `\n;window.__only = ${JSON.stringify(only)};`);
  await win.webContents.executeJavaScript(`PromoShots.start(window.__only, ${vertical})`);
  let last = '';
  for (;;) {
    const s = await win.webContents.executeJavaScript('JSON.stringify({ p: Cinema.progress, done: Cinema.done, err: Cinema.error, fin: PromoShots.finished })');
    const v = JSON.parse(s);
    const line = v.p ? `${v.p.name} ${v.p.i}/${v.p.N}` : '';
    if (line && line !== last && v.p.i % 30 === 0) { console.log(line, new Date().toLocaleTimeString()); last = line; }
    if (v.err) { console.log('ОШИБКА', v.err); break; }
    if (v.fin) { console.log('готово:', v.done.join(', ')); break; }
    await wait(1000);
  }
  app.quit();
});
