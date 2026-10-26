'use strict';
// Откат сервера боёв с городами на версию без героя (до Д11). Старый pvp.js считает силу снимка обороны и падает (500)
// на незнакомом бойце «hero» — поэтому ПЕРЕД заменой pvp.js и legion_sim.js на старые героя убирают из выставленных
// отрядов обороны: на его месте — легионер его уровня (так соперника видят и старые игры), сила пересчитана.
// Запуск на сервере, пока лежат НОВЫЕ pvp.js и legion_sim.js, а сам сервер остановлен (иначе новые игры успеют
// выставить героя снова):   DATA_DIR=<папка данных сервера> node pvp_nohero.js
// Недоигранные бои не трогаем: старый legion_sim пропускает незнакомых бойцов, а бои живут минуты.
const path = require('path');
const { noHero, snapPower } = require('./pvp');

// убрать героя из всех отрядов обороны в базе db (node:sqlite); вернуть, сколько отрядов поправлено
function stripHeroes(db) {
  const up = db.prepare('UPDATE pvp_players SET snapshot = ?, power = ? WHERE user_id = ?');
  let n = 0;
  for (const r of db.prepare(`SELECT user_id, snapshot FROM pvp_players WHERE snapshot LIKE '%"type":"hero"%'`).all()) {
    let s;
    try { s = JSON.parse(r.snapshot); } catch (e) { continue; }
    const t = noHero(s);
    if (t === s) continue;
    up.run(JSON.stringify(t), t.squad.length ? snapPower(t) : 0, r.user_id);
    n++;
  }
  return n;
}

if (require.main === module) {
  const { DatabaseSync } = require('node:sqlite');
  const file = path.join(process.env.DATA_DIR || path.join(__dirname, 'data'), 'civcity.db');
  const db = new DatabaseSync(file);
  const n = stripHeroes(db);
  db.close();
  console.log(`${file}: героя убрали из ${n} отрядов обороны`);
}

module.exports = { stripHeroes };
