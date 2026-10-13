'use strict';
/* Подготовка перед сборкой установщика (npm run build).
   - Свои картинки владельца (docs/ART_PROMPTS_2.md): положите в assets/incoming/ui_ai/ файлы
       30.png — значок игры  → build/icon.png (значок программы, ярлыка и установщика),
       31.png — фон лаунчера → launcher/bg.jpg (картинка в шапке окна лаунчера).
     Нужен ffmpeg (есть в PATH — переводим сами; нет — остаются прежние картинки).
   - Убираем desktop/game: это копия старой браузерной игры из лаунчера 0.9 — теперь игра скачивается с сайта. */
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const INCOMING = path.join(__dirname, '..', 'assets', 'incoming', 'ui_ai');

fs.rmSync(path.join(__dirname, 'game'), { recursive: true, force: true });

function ffmpeg(args) {
  try { execFileSync('ffmpeg', ['-hide_banner', '-loglevel', 'error', '-y', ...args], { stdio: 'inherit' }); return true; } catch (e) { return false; }
}

function art(file, out, args, what) {
  const src = path.join(INCOMING, file);
  if (!fs.existsSync(src)) return;
  if (ffmpeg(['-i', src, ...args, out])) console.log(`${what} — из ${file}`);
  else console.log(`${file} есть, но перевести не вышло (нет ffmpeg?) — ${what} прежний`);
}

// setsar=1 обязательно: без него ffmpeg пишет в PNG разрешение 0 по ширине, оно уходит в значок, и Windows не может
// его прочитать — у exe и установщика пустое окошко вместо орла. Цветовой профиль (ICC) тоже убираем — значку он не нужен.
art('30.png', path.join(__dirname, 'build', 'icon.png'), ['-vf', 'sidedata=mode=delete:type=ICC_PROFILE,scale=512:512:flags=lanczos,setsar=1', '-pix_fmt', 'rgba'], 'значок программы');
art('31.png', path.join(__dirname, 'launcher', 'bg.jpg'), ['-vf', 'scale=1600:-2:flags=lanczos', '-q:v', '3'], 'фон лаунчера');
console.log('лаунчер подготовлен');
