'use strict';
// Проверка счётчика посещений: node server/test_stats.js
const assert = require('assert');
const { DatabaseSync } = require('node:sqlite');
const stats = require('./stats');
const db = new DatabaseSync(':memory:');
const s = stats.install({ db, listen: false });
const ts = Date.UTC(2026, 10, 26, 9, 0, 0) / 1000;
const line = (uri, ip, ua, status = 200, range = '') => JSON.stringify({
  ts, status, request: { method: 'GET', uri, client_ip: ip, headers: Object.assign({ 'User-Agent': [ua] }, range ? { Range: [range] } : {}) } });
s.feed([
  line('/', '1.1.1.1', 'Mozilla A'),
  line('/', '1.1.1.1', 'Mozilla A'),
  line('/', '2.2.2.2', 'Mozilla B'),
  line('/', '3.3.3.3', 'Googlebot'),
  line('/download/CivCity-setup.exe', '1.1.1.1', 'Mozilla A', 206, 'bytes=0-'),
  line('/download/CivCity-setup.exe', '1.1.1.1', 'Mozilla A', 206, 'bytes=1000-'),
  line('/api/launcher', '4.4.4.4', 'CivCityLauncher/1.0.0'),
  line('/api/launcher', '4.4.4.4', 'CivCityLauncher/1.0.0'),
  line('/game/manifest.json?x=1', '4.4.4.4', 'CivCityLauncher/1.0.0'),
  line('/missing', '5.5.5.5', 'Mozilla C', 404),
].join('\n'));
const rows = {};
for (const r of db.prepare('SELECT key, total, uniq, day FROM stats_daily').all()) rows[r.key] = r;
assert.deepStrictEqual([rows.site.total, rows.site.uniq], [3, 2]);
assert.deepStrictEqual([rows.download_win.total, rows.download_win.uniq], [1, 1]);
assert.deepStrictEqual([rows.launcher.total, rows.launcher.uniq], [2, 1]);
assert.deepStrictEqual([rows.game_check.total, rows.game_check.uniq], [1, 1]);
assert.strictEqual(rows.site.day, '2026-11-26');
assert.ok(!JSON.stringify(db.prepare('SELECT * FROM stats_daily').all()).includes('1.1.1.1'));
console.log('stats OK', JSON.stringify(rows));
