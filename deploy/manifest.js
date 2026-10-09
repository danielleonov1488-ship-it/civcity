'use strict';
/* Опись файлов игры для самообновления программы для ПК: номер сборки (?v= из index.html),
   наименьшая версия программы-оболочки, которой подходит эта сборка, и sha256 каждого файла.
   Кладётся на сайт как game-manifest.json (deploy.sh) и внутрь программы (desktop/prepare.js).
   Запуск: node deploy/manifest.js [папка игры] [куда записать] */
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

// Повышать, когда меняется сама программа (desktop/main.js, updater.js) так, что старая с новой игрой не справится
const SHELL_MIN = '0.9.2';

function listFiles(root) {
  const out = ['index.html', 'style.css'];
  const walk = rel => {
    for (const e of fs.readdirSync(path.join(root, rel), { withFileTypes: true })) {
      const r = rel + '/' + e.name;
      if (r === 'assets/incoming') continue;          // сырые наборы моделей в игру не входят
      if (e.isDirectory()) walk(r); else out.push(r);
    }
  };
  for (const d of ['js', 'vendor', 'assets']) walk(d);
  return out;
}

function manifest(root) {
  const html = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
  const m = html.match(/boot\.js\?v=(\d+)/);
  const files = {};
  for (const rel of listFiles(root)) {
    const buf = fs.readFileSync(path.join(root, rel));
    files[rel] = { h: crypto.createHash('sha256').update(buf).digest('hex'), s: buf.length };
  }
  return { version: m ? m[1] : '0', shell: SHELL_MIN, files };
}

module.exports = { manifest, listFiles, SHELL_MIN };

if (require.main === module) {
  const root = process.argv[2] || path.join(__dirname, '..');
  const json = JSON.stringify(manifest(root));
  if (process.argv[3]) fs.writeFileSync(process.argv[3], json); else process.stdout.write(json);
}
