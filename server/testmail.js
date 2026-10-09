'use strict';
// Проверка почты: отправляет письмо на сам ящик игры. Запуск: node testmail.js (с настройками из /etc/civcity.env)
const fs = require('fs');
// настройки берутся из того же файла, что и у службы игры
for (const line of fs.readFileSync('/etc/civcity.env', 'utf8').split(/\r?\n/)) {
  const i = line.indexOf('=');
  if (i > 0 && !process.env[line.slice(0, i)]) process.env[line.slice(0, i)] = line.slice(i + 1);
}
const mail = require('./mail');
const to = process.env.SMTP_USER;
if (!to || !process.env.SMTP_PASS) { console.error('Почта ещё не настроена'); process.exit(1); }
mail.send(to, 'CivCity: почта работает', 'Это проверочное письмо. Если вы его видите — письма «Забыли пароль?» будут доходить до игроков.')
  .then(() => { console.log(`Проверочное письмо отправлено на ${to}`); process.exit(0); })
  .catch(e => { console.error(`Письмо не ушло: ${e.message}`); process.exit(1); });
