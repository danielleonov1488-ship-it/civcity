'use strict';
// Записывает настройки почты в /etc/civcity.env. Данные приходят через stdin (JSON), в командную строку не попадают.
// Запускается на сервере ярлыком «Почта для игры.bat» с компьютера владельца.
const fs = require('fs');
const FILE = '/etc/civcity.env';

let raw = '';
process.stdin.on('data', c => { raw += c; });
process.stdin.on('end', () => {
  const v = JSON.parse(raw);
  const set = {
    SMTP_HOST: v.host || 'smtp.beget.com',
    SMTP_PORT: String(v.port || 465),
    SMTP_USER: String(v.user || '').trim(),
    SMTP_PASS: String(v.pass || ''),
    MAIL_FROM: `CivCity <${String(v.user || '').trim()}>`,
  };
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(set.SMTP_USER)) { console.error('Адрес ящика выглядит неверно'); process.exit(1); }
  const lines = fs.existsSync(FILE) ? fs.readFileSync(FILE, 'utf8').split('\n').filter(Boolean) : [];
  const out = lines.filter(l => !Object.keys(set).includes(l.split('=')[0]));
  for (const [k, val] of Object.entries(set)) out.push(`${k}=${val.replace(/\n/g, '')}`);
  fs.writeFileSync(FILE, out.join('\n') + '\n', { mode: 0o600 });
  console.log('Настройки почты записаны');
});
