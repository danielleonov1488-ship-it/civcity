'use strict';
// Правила бойца форта из legion.gd, gear.gd и soldiers.gd.
const { FORT_UNITS, MAX_LEVEL, KIT_MAX, unitStats } = require('./legion_sim');

const FORT_PLACES = 5;
const SLOTS = ['weapon', 'offhand', 'helmet', 'armor'];
const OUTFITS = ['cook', 'smith', 'scribe', 'priest', 'builder'];
const RARITY = [1.0, 1.1, 1.2, 1.3, 1.4];
const BASE = {
  weapon: { atk: 0.55 }, offhand: { hp: 0.12, armor: 8.0 },
  helmet: { hp: 0.18, armor: 3.0 }, armor: { hp: 0.25, armor: 9.0 },
};
const SETS = {
  gallic: [{ atk: 0.08 }, 'stun'], german: [{ hp: 0.10 }, 'rage'],
  british: [{ armor: 6.0 }, 'reflect'], egyptian: [{ heal: 0.08 }, 'drain'],
  parthian: [{ ranged: 0.08 }, 'kite'], praetorian: [{ atk: 0.05, hp: 0.05 }, 'revive'],
};
const TALENTS = {
  legionary: [
    [{ armor: 6.0 }, { atk: 0.08 }], [{ hp: 0.1 }, { rate: 0.08 }],
    [{ vs: { human: 1.15 } }, { vs: { beast: 1.15 } }], [{ set: 'reflect' }, { set: 'rage' }],
    [{ set: 'revive' }, { set: 'stun' }],
  ],
  archer: [
    [{ atk: 0.08 }, { range: 0.8 }], [{ hp: 0.1 }, { rate: 0.08 }],
    [{ vs: { beast: 1.15 } }, { vs: { ranged: 1.15 } }], [{ set: 'kite' }, { atk: 0.12 }],
    [{ set: 'revive' }, { vs: { giant: 1.2, armored: 1.2 } }],
  ],
};

const integer = (v, fallback = 0) => Number.isSafeInteger(v) ? v : fallback;
const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));
const array = v => Array.isArray(v) ? v : [];

function indexById(list) {
  const map = new Map();
  for (const entry of array(list)) {
    const id = integer(entry?.id);
    if (id > 0) map.set(id, map.has(id) ? null : entry);
  }
  return map;
}

function fortFacts(L) {
  const soldiers = indexById(L.soldiers);
  const items = indexById(L.items);
  const squad = array(L.squad3).slice(0, FORT_PLACES).map(id => integer(id));
  const savedMembers = new Set(squad.filter(id => soldiers.get(id)));
  let hq = 0, barracks = 0;
  for (const plot of array(L.fort.plots)) {
    if (plot?.b === 'hq') hq = Math.max(hq, integer(plot.lv));
    if (plot?.b === 'barracks') barracks = Math.max(barracks, integer(plot.lv));
  }
  const slots = Math.max(savedMembers.size, hq >= 6 ? 5 : hq >= 4 ? 4 : hq >= 2 ? 3 : 2);
  return { barracks: clamp(barracks, 1, 12), slots, squad, soldiers, items };
}

function gearOf(fort, s) {
  const worn = [];
  // Порядок сохранения совпадает с порядком сложения чисел в Legion.gear_bonus.
  for (const [slot, id] of Object.entries(s.gear || {})) {
    if (!SLOTS.includes(slot) && slot !== 'outfit') continue;
    const it = fort.items.get(integer(id));
    if (!it || it.slot !== slot || it.on !== s.id) continue;
    if (slot === 'outfit' && !OUTFITS.includes(it.kind)) continue;
    const tier = clamp(integer(it.tier, 1 + Math.floor((Math.max(1, integer(it.ilvl)) - 1) / 5)), 1, KIT_MAX);
    const rarity = clamp(integer(it.rarity), 0, RARITY.length - 1);
    worn.push({ slot, tier, rarity, cls: it.cls, set: it.set });
  }
  return worn;
}

// Знания открывают рецепты. Вещь той же формы может выпасть или прийти с Рынка до изучения рецепта.
// Одежда (включая «Тонкое шитьё») ускоряет работу форта и не меняет бой.
function fighter(fort, soldier, place, maxLevel = MAX_LEVEL) {
  const worn = gearOf(fort, soldier);
  const cls = worn.find(it => it.slot === 'weapon')?.cls;
  const type = cls === 'spearman' ? 'cavalry' : FORT_UNITS.includes(cls) ? cls : 'legionary';
  const rank = clamp(integer(soldier.rank), 0, maxLevel - 1);
  const bonus = 0.05 * (clamp(integer(soldier.stars, 1), 1, 5) - 1) + 0.03 * rank;
  const gear = { atk: 0.0, hp: 0.0, armor: 0.0 };
  const looks = {};
  const counts = new Map();
  for (const it of worn) {
    if (it.slot === 'outfit') continue;
    const k = (1.0 + 0.8 * (it.tier - 1)) * RARITY[it.rarity];
    for (const stat of Object.keys(gear)) gear[stat] += (BASE[it.slot][stat] ?? 0.0) * k;
    looks[it.slot] = it.rarity;
    if (Object.hasOwn(SETS, it.set)) counts.set(it.set, (counts.get(it.set) || 0) + 1);
  }
  const set = { atk: 0.0, hp: 0.0, armor: 0.0, ranged: 0.0, heal: 0.0 };
  const effects = {};
  for (const [id, n] of counts) {
    const [pair, effect] = SETS[id];
    if (n >= 2) for (const [stat, value] of Object.entries(pair)) set[stat] += value;
    if (n >= 4) effects[`set_${effect}`] = true;
  }
  const room = Math.min(fort.barracks, maxLevel);
  const ranged = (type === 'priest' || type === 'archer') ? set.ranged : 0.0;
  const stats = unitStats(type, 1, bonus + gear.atk + set.atk + ranged + 0.04 * (room - 1),
    bonus + gear.hp + set.hp + 0.04 * (room - 1), gear.armor + set.armor + (room - 1));
  stats.vs = { ...stats.vs };
  for (const [i, choices] of (TALENTS[type] || []).entries()) {
    const t = choices[integer(array(soldier.tal)[i], -1)];
    if (!t || rank < 2 * (i + 1)) continue;
    if (t.atk) stats.atk = Math.round(stats.atk * (1.0 + t.atk));
    if (t.hp) stats.hp = Math.round(stats.hp * (1.0 + t.hp));
    if (t.armor) stats.armor += t.armor;
    if (t.rate) stats.rate *= 1.0 - t.rate;
    if (t.range) stats.range += t.range;
    for (const [tag, value] of Object.entries(t.vs || {})) stats.vs[tag] = (stats.vs[tag] ?? 1.0) * value;
    if (t.set) effects[`set_${t.set}`] = true;
  }
  if (type === 'legionary') {
    for (const tag of ['swift', 'cavalry', 'beast']) stats.vs[tag] = Math.max(stats.vs[tag] ?? 1.0, 1.3);
    stats.tags = [...stats.tags, 'armored', 'melee'];
  }
  if (type === 'archer') stats.vs.armored = Math.max(stats.vs.armored ?? 1.0, 1.3);
  const { hp, atk, armor, rate, range, speed, vs, tags, heal, heal_every } = stats;
  const stats3 = { hp, atk, armor, rate, range, speed, vs, tags, row: place < 3 ? 0 : 1, place, ...effects };
  if (heal) Object.assign(stats3, { heal, heal_every });
  if (set.heal > 0.0) stats3.heal_k = 1.0 + set.heal;
  if (Object.keys(looks).length) stats3.gear_look = looks;
  return { type, level: rank + 1, place, gear_v: 1, stats3 };
}

module.exports = { FORT_PLACES, fortFacts, fighter };
