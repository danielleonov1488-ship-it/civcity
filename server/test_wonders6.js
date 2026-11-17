'use strict';
// Без сервера, сети, файловой базы, удаления файлов и дочерних процессов.
const assert = require('node:assert/strict');
const { DatabaseSync } = require('node:sqlite');
const pvp = require('./pvp');

(async () => {
  const db = new DatabaseSync(':memory:');
  try {
    db.exec('CREATE TABLE users (id INTEGER PRIMARY KEY, email TEXT)');
    const routes = {}, saves = {};
    class Fail extends Error { constructor(status, message) { super(message); this.status = status; } }
    pvp.install({ db, routes, auth: req => ({ userId: req.uid }), json: async req => req.body,
      limited: () => false, Fail, latestSave: uid => ({ id: uid, load: () => saves[uid] }) });
    const wonders = ['arch', 'colosseum', 'pantheon', 'circus', 'aqueduct', 'trajan', 'caracalla', 'jupiter'];
    for (const [uid, placed, bought] of [[1, [], []], [2, wonders, []], [3, [], wonders], [4, wonders, wonders]]) {
      db.prepare('INSERT INTO users (id, email) VALUES (?, ?)').run(uid, `wonder${uid}@test`);
      saves[uid] = JSON.stringify({ version: 2, level: 5, research: ['legion'], wonders_v: 1,
        buildings: ['barracks', ...placed].map((type, i) => ({ id: i + 1, type, tier: 0 })),
        legion: { v: 3, levels: { legionary: 3 }, perks: {}, built: bought, progress: 0 } });
      const response = await routes['PUT /api/pvp/defense']({ uid, body: {
        snapshot: { squad: [{ type: 'legionary', level: 3 }], atk_b: 0.35, hp_b: 0.30 }
      } });
      assert.equal(response.power, pvp.power(pvp.unitStats('legionary', 3, 0, 0)));
      const snapshot = JSON.parse(db.prepare('SELECT snapshot FROM pvp_players WHERE user_id = ?').get(uid).snapshot);
      assert.equal(snapshot.atk_b, 0);
      assert.equal(snapshot.hp_b, 0);
      console.log(`WONDERS6 SERVER PASS placed=${placed.length} bought=${bought.length}`);
    }
    // Обновление сервера очищает уже выставленную старую оборону один раз.
    const legacy = { v: 1, squad: [{ type: 'legionary', level: 3 }], atk_b: 0.35, hp_b: 0.30 };
    db.prepare('UPDATE pvp_players SET snapshot = ?, power = ? WHERE user_id = 4').run(JSON.stringify(legacy), pvp.snapPower(legacy));
    db.prepare("UPDATE pvp_meta SET v = 0 WHERE k = 'city_wonders_v'").run();
    pvp.install({ db, routes: {}, auth: req => ({ userId: req.uid }), json: async req => req.body,
      limited: () => false, Fail, latestSave: uid => ({ id: uid, load: () => saves[uid] }) });
    const migrated = db.prepare('SELECT snapshot, power FROM pvp_players WHERE user_id = 4').get();
    assert.equal(JSON.parse(migrated.snapshot).atk_b, 0);
    assert.equal(JSON.parse(migrated.snapshot).hp_b, 0);
    assert.equal(migrated.power, pvp.power(pvp.unitStats('legionary', 3, 0, 0)));
    assert.deepEqual(JSON.parse(migrated.snapshot).squad, legacy.squad);
    console.log('WONDERS6 SERVER PASS legacy published defense migrated');
    console.log('WONDERS6 SERVER DONE fails=0');
  } finally {
    db.close();
  }
})().catch(error => { console.error('WONDERS6 SERVER FAIL', error); process.exitCode = 1; });
