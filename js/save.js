'use strict';
/* Сохранение города в браузере (localStorage). */

const SAVE_KEY = PROMO_MODE ? 'civcity.save.promo' : TEST_MODE ? 'civcity.save.test' : 'civcity.save.v2';
const SETTINGS_KEY = 'civcity.settings';

// Настройки игрока: качество графики и смена дня и ночи (общие для всех городов)
const Settings = {
  quality: 'high',
  qAuto: true,         // качество подбирается само, пока игрок не выбрал его вручную
  dayCycle: true,
  music: 0.5,
  sfx: 0.7,

  load() {
    const coarse = window.matchMedia && window.matchMedia('(pointer: coarse)').matches;
    this.quality = coarse || Math.min(window.innerWidth, window.innerHeight) < 600 ? 'medium' : 'high';
    try {
      const s = JSON.parse(localStorage.getItem(SETTINGS_KEY) || '{}');
      if (QUALITY[s.quality]) this.quality = s.quality;
      this.qAuto = s.qAuto !== false;
      if (typeof s.dayCycle === 'boolean') this.dayCycle = s.dayCycle;
      if (typeof s.music === 'number') this.music = clamp(s.music, 0, 1);
      if (typeof s.sfx === 'number') this.sfx = clamp(s.sfx, 0, 1);
    } catch (e) { /* по умолчанию */ }
    // в программе для ПК качество выбирают в лаунчере
    try {
      const d = window.civDesktop && civDesktop.prefs();
      if (d && QUALITY[d.quality]) { this.quality = d.quality; this.qAuto = false; } else if (d && d.quality === 'auto') this.qAuto = true;
    } catch (e) { /* нет моста */ }
  },

  save() {
    try { localStorage.setItem(SETTINGS_KEY, JSON.stringify({ quality: this.quality, qAuto: this.qAuto, dayCycle: this.dayCycle, music: this.music, sfx: this.sfx })); } catch (e) { /* нет хранилища */ }
  },
};

function serialize() {
  const buildings = [];
  const r4 = v => Math.round(v * 10000) / 10000;
  for (const b of state.buildings.values()) {
    const o = { i: b.id, t: b.type, x: r4(b.x), y: r4(b.y), r: b.rot || 0, a: r4(bAng(b)) };
    if (BUILDINGS[b.type].kind === 'house') Object.assign(o, { tier: b.tier, pop: b.pop, up: b.up, down: b.down, lock: b.lock || undefined, req: b.req || undefined, bonusUntil: b.bonusUntil || undefined });
    buildings.push(o);
  }
  const s = { ...state };
  delete s.stats;
  return {
    ...s,
    plots: [...state.plots],
    cleared: [...state.cleared],
    buildings,
    roads: Roads.toJSON(),
    camera: { x: Engine.cam.x, z: Engine.cam.z, yaw: Engine.cam.yawTarget, dist: Engine.cam.distTarget },
  };
}

function deserialize(data) {
  const s = newState(data.seed);
  for (const [k, v] of Object.entries(data)) {
    if (k === 'plots' || k === 'cleared' || k === 'buildings' || k === 'roads') continue;
    s[k] = v;
  }
  s.plots = new Set(data.plots);
  s.cleared = new Set(data.cleared);
  s.buildings = new Map();
  for (const g of GOOD_IDS) s.goods[g] = s.goods[g] || 0;
  s.speed = Math.min(3, s.speed || 0);
  s.lastSpeed = Math.min(3, s.lastSpeed || 1);
  s.stats = {};
  state = s;
  World.terrain.clear();
  World.occ.clear();
  World.bgrid.clear();
  // города до свободной стройки: дороги были постройками на клетках — их собираем в улицы
  const roadTiles = new Set();
  for (const o of data.buildings) {
    if (o.t === 'road') { roadTiles.add(o.x + ',' + o.y); continue; }
    if (!BUILDINGS[o.t]) continue;
    const b = makeBuilding(o.t, o.x, o.y);
    b.id = o.i;
    b.born = 0;
    b.rot = o.r || 0;
    b.ang = o.a !== undefined ? o.a : b.rot * Math.PI / 2;
    if (BUILDINGS[o.t].kind === 'house') Object.assign(b, { tier: o.tier, pop: o.pop, up: o.up || 0, down: o.down || 0, lock: !!o.lock, req: o.req || null, bonusUntil: o.bonusUntil || 0 });
    state.buildings.set(b.id, b);
    occupy(b);
  }
  if (data.roads) Roads.fromJSON(data.roads);
  else Roads.fromTiles(roadTiles);
  state.nextId = Math.max(state.nextId, ...[...state.buildings.keys()].map(k => k + 1), 1);
}

function saveGame() {
  // город из облака уже записан и страница перезагружается — не затирать его текущим
  if (typeof Account !== 'undefined' && Account.reloading) return;
  try {
    localStorage.setItem(SAVE_KEY, JSON.stringify(serialize()));
  } catch (e) { /* хранилище недоступно — играем без сохранения */ }
}

function loadGame() {
  try {
    const raw = localStorage.getItem(SAVE_KEY);
    if (!raw) return false;
    const data = JSON.parse(raw);
    // город на клетках переносится в свободную стройку; прежнее сохранение остаётся запасной копией
    if (!data.roads) { try { if (!localStorage.getItem(SAVE_KEY + '.grid')) localStorage.setItem(SAVE_KEY + '.grid', raw); } catch (e) { /* нет места */ } }
    deserialize(data);
    return true;
  } catch (e) {
    return false;
  }
}
