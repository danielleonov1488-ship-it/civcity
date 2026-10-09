'use strict';
// Кладёт файлы игры в desktop/game: страница, стили, скрипты, библиотеки и готовые модели.
// Сырые наборы моделей (assets/incoming), лаборатория и документы в программу не попадают.
const fs = require('fs');
const path = require('path');

const SRC = path.join(__dirname, '..');
const DST = path.join(__dirname, 'game');
fs.rmSync(DST, { recursive: true, force: true });
fs.mkdirSync(DST, { recursive: true });
for (const f of ['index.html', 'style.css']) fs.copyFileSync(path.join(SRC, f), path.join(DST, f));
for (const d of ['js', 'vendor', 'assets']) {
  fs.cpSync(path.join(SRC, d), path.join(DST, d), {
    recursive: true,
    filter: src => !src.includes(path.join('assets', 'incoming')),
  });
}
// опись файлов с контрольными суммами — по ней программа поймёт, что обновлять (updater.js)
fs.writeFileSync(path.join(DST, 'game-manifest.json'), JSON.stringify(require('../deploy/manifest').manifest(DST)));
let size = 0;
const walk = d => { for (const e of fs.readdirSync(d, { withFileTypes: true })) { const p = path.join(d, e.name); if (e.isDirectory()) walk(p); else size += fs.statSync(p).size; } };
walk(DST);
console.log(`игра подготовлена: ${(size / 1048576).toFixed(1)} МБ`);
