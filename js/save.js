'use strict';
/* Сохранение города в браузере (localStorage). */

const SAVE_KEY = TEST_MODE ? 'civcity.save.test' : 'civcity.save.v2';
const SETTINGS_KEY = 'civcity.settings';

// Настройки игрока: качество графики и смена дня и ночи (общие для всех городов)
const Settings = {
  quality: 'high',
  dayCycle: true,

  load() {
    const coarse = window.matchMedia && window.matchMedia('(pointer: coarse)').matches;
    this.quality = coarse || Math.min(window.innerWidth, window.innerHeight) < 600 ? 'medium' : 'high';
    try {
      const s = JSON.parse(localStorage.getItem(SETTINGS_KEY) || '{}');
      if (QUALITY[s.quality]) this.quality = s.quality;
      if (typeof s.dayCycle === 'boolean') this.dayCycle = s.dayCycle;
    } catch (e) { /* по умолчанию */ }
  },

  save() {
    try { localStorage.setItem(SETTINGS_KEY, JSON.stringify({ quality: this.quality, dayCycle: this.dayCycle })); } catch (e) { /* нет хранилища */ }
  },
};

function serialize() {
  const buildings = [];
  for (const b of state.buildings.values()) {
    const o = { i: b.id, t: b.type, x: b.x, y: b.y, r: b.rot || 0 };
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
    camera: { x: Engine.cam.x, z: Engine.cam.z, yaw: Engine.cam.yawTarget, dist: Engine.cam.distTarget },
  };
}

function deserialize(data) {
  const s = newState(data.seed);
  for (const [k, v] of Object.entries(data)) {
    if (k === 'plots' || k === 'cleared' || k === 'buildings') continue;
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
  for (const o of data.buildings) {
    if (!BUILDINGS[o.t]) continue;
    const b = makeBuilding(o.t, o.x, o.y);
    b.id = o.i;
    b.born = 0;
    b.rot = o.r || 0;
    if (BUILDINGS[o.t].kind === 'house') Object.assign(b, { tier: o.tier, pop: o.pop, up: o.up || 0, down: o.down || 0, lock: !!o.lock, req: o.req || null, bonusUntil: o.bonusUntil || 0 });
    state.buildings.set(b.id, b);
    occupy(b);
  }
  state.nextId = Math.max(state.nextId, ...[...state.buildings.keys()].map(k => k + 1), 1);
}

function saveGame() {
  try {
    localStorage.setItem(SAVE_KEY, JSON.stringify(serialize()));
  } catch (e) { /* хранилище недоступно — играем без сохранения */ }
}

function loadGame() {
  try {
    const raw = localStorage.getItem(SAVE_KEY);
    if (!raw) return false;
    deserialize(JSON.parse(raw));
    return true;
  } catch (e) {
    return false;
  }
}
