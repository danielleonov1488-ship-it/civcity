'use strict';
/* Письма игрокам (восстановление пароля) через почтовый ящик на домене по SMTP.
   Настройки — в /etc/civcity.env: SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, MAIL_FROM.
   Пока почта не настроена, письмо пишется в журнал сервера — так можно проверить ссылку. */

const nodemailer = require('nodemailer');

let transport = null;
function get() {
  if (transport) return transport;
  const host = process.env.SMTP_HOST;
  if (!host || !process.env.SMTP_PASS) return null;
  const port = +process.env.SMTP_PORT || 465;
  transport = nodemailer.createTransport({
    host, port, secure: port === 465,
    auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS },
  });
  return transport;
}

exports.send = async (to, subject, text) => {
  const t = get();
  if (!t) { console.log(`[почта не настроена] кому: ${to}\n${subject}\n${text}`); return; }
  await t.sendMail({ from: process.env.MAIL_FROM || `CivCity <${process.env.SMTP_USER}>`, to, subject, text });
};
