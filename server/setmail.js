'use strict';
// Записывает настройки почты в /etc/civcity.env. Данные приходят через stdin одной строкой base64 (JSON в UTF-8) —
// так пароль с любыми буквами доходит целым и не попадает в командную строку. При ошибке введённое не печатается.
// Запускается на сервере ярлыком «Почта для игры.bat» с компьютера владельца.
const fs = require('fs');
const FILE = '/etc/civcity.env';

let raw = '';
process.stdin.on('data', c => { raw += c; });
process.stdin.on('end', () => {
  let v;
  try {
    const b64 = raw.replace(/[^A-Za-z0-9+/=]/g, '');
    v = JSON.parse(Buffer.from(b64, 'base64').toString('utf8'));
  } catch (e) {
    console.error('Не удалось прочитать данные от ярлыка');
    process.exit(1);
  }
  const user = String(v.user || '').trim();
  const set = {
    SMTP_HOST: v.host || 'smtp.beget.com',
    SMTP_PORT: String(v.port || 465),
    SMTP_USER: user,
    SMTP_PASS: String(v.pass || '').replace(/[\r\n]/g, ''),
    MAIL_FROM: `CivCity <${user}>`,
  };
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(user)) { console.error('Адрес ящика выглядит неверно'); process.exit(1); }
  if (!set.SMTP_PASS) { console.error('Пустой пароль'); process.exit(1); }
  const lines = fs.existsSync(FILE) ? fs.readFileSync(FILE, 'utf8').split(/\r?\n/).filter(Boolean) : [];
  const out = lines.filter(l => !Object.keys(set).includes(l.split('=')[0]));
  for (const [k, val] of Object.entries(set)) out.push(`${k}=${val}`);
  fs.writeFileSync(FILE, out.join('\n') + '\n', { mode: 0o600 });
  console.log('Настройки почты записаны');
});
