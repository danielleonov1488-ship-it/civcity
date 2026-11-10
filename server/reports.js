'use strict';
// Жалобы на сообщения в разговорах союзов (server/unions.js): node server/reports.js [дней=7]
// Запускать на сервере: cd /srv/civcity/server && DATA_DIR=/srv/civcity/data node reports.js
// Печатает: когда, союз, автор, сколько жалоб, текст. Ничего не меняет.
const path = require('path');
const { DatabaseSync } = require('node:sqlite');
const DATA = process.env.DATA_DIR || path.join(__dirname, 'data');
const days = Number(process.argv[2] || 7);
const db = new DatabaseSync(path.join(DATA, 'civcity.db'), { readOnly: true });
const rows = db.prepare(`SELECT r.msg, MIN(r.created) AS t, r.author_name AS who, r.text, COUNT(DISTINCT r.reporter) AS n, u.name AS un
  FROM union_reports r LEFT JOIN unions u ON u.id = r.union_id WHERE r.created > ? GROUP BY r.msg ORDER BY n DESC, t DESC`).all(Date.now() - days * 864e5);
if (!rows.length) console.log(`Жалоб за ${days} дн. нет`);
for (const r of rows) console.log(`${new Date(r.t).toISOString().slice(0, 16)}  «${r.un || '?'}»  ${r.who || '?'}  жалоб: ${r.n}  ${JSON.stringify(r.text)}`);
