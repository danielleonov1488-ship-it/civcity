'use strict';
// Сверка боя сервера (server/legion_sim.js) с боем игры (LegionSim, godot/scripts/legion_sim.gd) — до бита.
//   bash .work/py/gpu_run.sh --headless --script res://scripts/test_sim_dump.gd -- n=50 fort=1 out=D:/CivCity/.work/sim_dump.json
//   node server/test_sim.js [D:/CivCity/.work/sim_dump.json]
// Каждый бой из файла повторяется здесь с тем же зерном, отрядами и нажатиями; должны совпасть победа, живые,
// число шагов, время и доля здоровья. Печатает «ALL OK» или первые расхождения.
const fs = require('fs');
const path = require('path');
const { isDeepStrictEqual } = require('node:util');
const { replayPvp, cleanInputs } = require('./legion_sim');
const { fortFacts, fighter } = require('./legion_fort');

const file = process.argv[2] || path.join(__dirname, '..', '.work', 'sim_dump.json');
const hex = x => { const b = Buffer.alloc(8); b.writeDoubleLE(x); return b.toString('hex'); };
const list = JSON.parse(fs.readFileSync(file, 'utf8'));
let bad = 0, wins = 0, presses = 0, forts = 0, old = 0, mixed = 0, fighters = 0;
const t0 = Date.now();

function rebuilt(snap, save, battle, side) {
  if (!save) return snap;
  const fort = fortFacts(save);
  const squad = snap.squad.map(e => {
    const got = fighter(fort, fort.soldiers.get(fort.squad[e.place]), e.place);
    const want = { type: e.unit || e.type, level: e.level, place: e.place, gear_v: e.gear_v, stats3: e.stats3 };
    if (!isDeepStrictEqual(got, want)) {
      bad++;
      if (bad <= 10) console.log(`FAIL #${battle} ${side} ${e.place}: числа сервера ${JSON.stringify(got)}\n                 числа игры ${JSON.stringify(want)}`);
    }
    fighters++;
    return { ...e, stats3: got.stats3 };
  });
  return { ...snap, squad };
}

for (const [i, b] of list.entries()) {
  const inputs = cleanInputs(b.inputs);
  if (!inputs) { console.log(`FAIL #${i}: нажатия не прошли проверку`, JSON.stringify(b.inputs).slice(0, 200)); bad++; continue; }
  presses += inputs.length;
  if (b.att_fort && b.def_fort) forts++;
  else if (b.att_fort || b.def_fort) mixed++;
  else old++;
  const att = rebuilt(b.att, b.att_fort, i, 'att');
  const def = rebuilt(b.def, b.def_fort, i, 'def');
  const r = replayPvp(att, def, b.seed, inputs);
  const got = { win: r.win, alive: r.alive, total: r.total, steps: r.steps, time: hex(r.time), hp_left: hex(r.hp_left) };
  const want = { win: b.win, alive: b.alive, total: b.total, steps: b.steps, time: b.time, hp_left: b.hp_left };
  if (Object.hasOwn(b, 'timeout')) { got.timeout = r.timeout; want.timeout = b.timeout; }
  if (JSON.stringify(got) !== JSON.stringify(want)) {
    bad++;
    if (bad <= 10) console.log(`FAIL #${i} seed ${b.seed}: сервер ${JSON.stringify(got)}\n                 игра   ${JSON.stringify(want)}`);
  }
  if (r.win) wins++;
}
const ms = Date.now() - t0;
console.log(`${list.length} боёв, побед ${wins}, нажатий ${presses}, ${(ms / Math.max(1, list.length)).toFixed(1)} мс на бой`);
if (fighters) console.log(`Форт: ${forts}, смешанные: ${mixed}, старые: ${old}. Пересчитано бойцов: ${fighters}.`);
console.log(bad ? `${bad} FAILED` : 'ALL OK');
process.exit(bad ? 1 : 0);
