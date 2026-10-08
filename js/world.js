'use strict';
/* Мир: бесконечная карта из участков, рельеф, природа, залежи, занятость клеток. */

const World = {
  terrain: new Map(),   // "px,py" → { ground, nature, vari }
  occ: new Map(),       // "x,y" → здание на клетке
};

function plotOf(t) { return Math.floor(t / PLOT); }

const START_C = PLOT / 2;

// Насколько клетка «суха»: ниже WATER_LEVEL — озеро
function waterValue(tx, ty) {
  let w = fbm(tx * 0.04, ty * 0.04, state.seed + 5);
  w = (w - 0.5) * 1.9 + 0.5;
  const dx = tx - START_C, dy = ty - START_C;
  const d = Math.sqrt(dx * dx + dy * dy);
  w += Math.max(0, 1 - d / 15) * 0.65;               // центр стартового участка сухой
  const px = tx - (PLOT - 5), py = ty - 4;            // гарантированный пруд в углу старта
  w -= Math.max(0, 1 - Math.sqrt(px * px + py * py) / 4.6) * 1.1;
  return w;
}

function genPlot(px, py) {
  const n = PLOT * PLOT;
  const ground = new Uint8Array(n), nature = new Uint8Array(n), vari = new Uint8Array(n);
  const s = state.seed;
  const start = px === 0 && py === 0;
  for (let j = 0; j < PLOT; j++) {
    for (let i = 0; i < PLOT; i++) {
      const tx = px * PLOT + i, ty = py * PLOT + j, k = j * PLOT + i;
      vari[k] = (hash2(tx, ty, s + 99) * 256) | 0;
      const w = waterValue(tx, ty);
      if (w < WATER_LEVEL) { ground[k] = w < WATER_LEVEL - 0.08 ? G_DEEP : G_WATER; continue; }
      if (w < WATER_LEVEL + 0.035) { ground[k] = G_SAND; continue; }

      const g = fbm(tx * 0.08 + 50, ty * 0.08, s + 11);
      ground[k] = g < 0.42 ? 0 : g < 0.5 ? 1 : g < 0.58 ? 2 : 3;

      const dx = tx - START_C + 0.5, dy = ty - START_C + 0.5;
      const d = Math.sqrt(dx * dx + dy * dy);
      const r = hash2(tx, ty, s + 3);

      // Залежи: камень часто, мрамор и железо — редко и не на стартовом участке
      const stoneN = valueNoise(tx * 0.13, ty * 0.13, s + 41);
      const marbleN = valueNoise(tx * 0.09, ty * 0.09, s + 53);
      const ironN = valueNoise(tx * 0.1, ty * 0.1, s + 67);
      const sx = tx - 4.5, sy = ty - (PLOT - 5.5);
      const startStone = start && Math.sqrt(sx * sx + sy * sy) < 2.6;
      if ((stoneN > 0.83 || startStone) && r < 0.75) { nature[k] = N_STONE; continue; }
      if (!start && marbleN > 0.86 && r < 0.75) { nature[k] = N_MARBLE; continue; }
      if (!start && ironN > 0.87 && r < 0.75) { nature[k] = N_IRON; continue; }

      // Деревья растут рощами; вокруг центра старта — поляна, в углу старта — гарантированная роща
      const forest = fbm(tx * 0.06, ty * 0.06, s + 23);
      let density = (forest - 0.42) * 1.5;
      if (d < 8) density -= 0.7; else if (d < 11) density -= 0.25;
      if (start) {
        const gx = tx - 4.5, gy = ty - 4.5, gd = Math.sqrt(gx * gx + gy * gy);
        if (gd < 4.2) density = Math.max(density, 0.75 - gd * 0.08);
      }
      if (r < density) {
        const r2 = hash2(tx, ty, s + 7);
        nature[k] = r2 < 0.42 ? N_OAK : r2 < 0.78 ? N_PINE : N_CYPRESS;
      } else if (r > 0.993) nature[k] = N_ROCK;
      else if (r > 0.978 && d > 4) nature[k] = N_BUSH;
      else if (r > 0.95) nature[k] = N_FLOWERS;
    }
  }
  return { ground, nature, vari };
}

function plotTerrain(px, py) {
  const k = px + ',' + py;
  let t = World.terrain.get(k);
  if (!t) { t = genPlot(px, py); World.terrain.set(k, t); }
  return t;
}

function groundAt(tx, ty) {
  const px = plotOf(tx), py = plotOf(ty);
  return plotTerrain(px, py).ground[(ty - py * PLOT) * PLOT + (tx - px * PLOT)];
}

function rawNatureAt(tx, ty) {
  const px = plotOf(tx), py = plotOf(ty);
  return plotTerrain(px, py).nature[(ty - py * PLOT) * PLOT + (tx - px * PLOT)];
}

function natureAt(tx, ty) {
  const n = rawNatureAt(tx, ty);
  if (!n || state.cleared.has(tkey(tx, ty))) return 0;
  return n;
}

function isWater(g) { return g >= G_WATER; }
function isOwnedPlot(px, py) { return state.plots.has(px + ',' + py); }
function isOwnedTile(tx, ty) { return isOwnedPlot(plotOf(tx), plotOf(ty)); }
function buildingAt(tx, ty) { return World.occ.get(tkey(tx, ty)); }
function isRoad(tx, ty) { const b = World.occ.get(tkey(tx, ty)); return !!b && b.type === 'road'; }

/* ---------- Цены и оплата ---------- */

function canAfford(cost, times) {
  const k = times || 1;
  for (const [res, amount] of Object.entries(cost)) {
    if (res === 'money') { if (state.money < amount * k) return false; }
    else if (res === 'glory') { if (state.glory < amount * k) return false; }
    else if ((state.goods[res] || 0) < amount * k) return false;
  }
  return true;
}

function missingFor(cost) {
  const out = [];
  for (const [res, amount] of Object.entries(cost)) {
    const have = res === 'money' ? state.money : res === 'glory' ? state.glory : (state.goods[res] || 0);
    if (have < amount) out.push(res === 'money' ? 'денариев' : res === 'glory' ? 'Славы' : GOODS[res].name.toLowerCase());
  }
  return out;
}

function pay(cost, sign) {
  const k = sign === undefined ? 1 : sign;
  for (const [res, amount] of Object.entries(cost)) {
    if (res === 'money') state.money -= amount * k;
    else if (res === 'glory') state.glory -= amount * k;
    else state.goods[res] = (state.goods[res] || 0) - amount * k;
  }
}

/* ---------- Участки земли ---------- */

function plotPrice() {
  const n = state.plots.size;
  return Math.round(600 * Math.pow(1.55, n - 1) / 50) * 50;
}

function canBuyPlot(px, py) {
  if (isOwnedPlot(px, py)) return false;
  return isOwnedPlot(px + 1, py) || isOwnedPlot(px - 1, py) || isOwnedPlot(px, py + 1) || isOwnedPlot(px, py - 1);
}

function buyPlot(px, py) {
  const price = plotPrice();
  if (!canBuyPlot(px, py) || state.money < price) return false;
  state.money -= price;
  state.plots.add(px + ',' + py);
  Engine.plotChanged(px, py);
  return true;
}

// Что интересного на участке — для окна покупки
function plotFeatures(px, py) {
  const t = plotTerrain(px, py);
  const c = { water: 0, trees: 0, stone: 0, marble: 0, iron: 0 };
  for (let k = 0; k < t.ground.length; k++) {
    if (isWater(t.ground[k])) c.water++;
    const n = t.nature[k];
    if (n >= N_OAK && n <= N_CYPRESS) c.trees++;
    if (n === N_STONE) c.stone++;
    if (n === N_MARBLE) c.marble++;
    if (n === N_IRON) c.iron++;
  }
  return c;
}

/* ---------- Постройки ---------- */

function isUnlocked(type) {
  const d = BUILDINGS[type];
  return !d.tech || state.techs.includes(d.tech);
}

// Левый верхний угол постройки, чтобы её центр оказался под курсором
function footprintOrigin(type, fx, fy) {
  const d = BUILDINGS[type];
  return [Math.round(fx - d.w / 2), Math.round(fy - d.h / 2)];
}

function nearWater(x, y, w, h, r) {
  for (let ty = y - r; ty < y + h + r; ty++) {
    for (let tx = x - r; tx < x + w + r; tx++) {
      if (isWater(groundAt(tx, ty))) return true;
    }
  }
  return false;
}

// null — можно строить, иначе причина отказа
function checkPlace(type, x, y) {
  const d = BUILDINGS[type];
  if (!isUnlocked(type)) return 'Сначала изучите нужную технологию';
  for (let j = 0; j < d.h; j++) {
    for (let i = 0; i < d.w; i++) {
      const tx = x + i, ty = y + j;
      if (!isOwnedTile(tx, ty)) return 'Эта земля ещё не куплена';
      if (isWater(groundAt(tx, ty))) return 'Здесь вода';
      if (World.occ.has(tkey(tx, ty))) return 'Место занято';
    }
  }
  if (d.needsWater && !nearWater(x, y, d.w, d.h, 2)) return 'Нужно ставить у воды';
  if (!canAfford(d.cost)) return 'Не хватает: ' + missingFor(d.cost).join(', ');
  return null;
}

function occupy(b) {
  for (let j = 0; j < b.h; j++) for (let i = 0; i < b.w; i++) World.occ.set(tkey(b.x + i, b.y + j), b);
}

function makeBuilding(type, x, y) {
  const d = BUILDINGS[type];
  const b = { id: state.nextId++, type, x, y, w: d.w, h: d.h, rot: 0, born: performance.now() };
  if (d.kind === 'house') Object.assign(b, { tier: 0, pop: 0, up: 0, down: 0, happy: 50, lock: false });
  return b;
}

function placeBuilding(type, x, y, free) {
  const b = makeBuilding(type, x, y);
  state.buildings.set(b.id, b);
  occupy(b);
  for (let j = 0; j < b.h; j++) {
    for (let i = 0; i < b.w; i++) {
      const tx = x + i, ty = y + j;
      if (rawNatureAt(tx, ty)) state.cleared.add(tkey(tx, ty));
      Engine.natureChanged(tx, ty);
    }
  }
  if (!free) pay(BUILDINGS[type].cost);
  b.rot = orientToRoad(b);
  if (type === 'road') refreshOrientationsAround(x, y);
  Engine.buildingsChanged(b);
  return b;
}

function removeBuilding(b, refund) {
  for (let j = 0; j < b.h; j++) for (let i = 0; i < b.w; i++) { World.occ.delete(tkey(b.x + i, b.y + j)); Engine.natureChanged(b.x + i, b.y + j); }
  state.buildings.delete(b.id);
  if (refund) {
    const c = BUILDINGS[b.type].cost;
    for (const [res, amount] of Object.entries(c)) {
      const back = Math.floor(amount * REFUND_SHARE);
      if (res === 'money') state.money += back;
      else if (res !== 'glory') state.goods[res] = (state.goods[res] || 0) + back;
    }
  }
  if (b.type === 'road') refreshOrientationsAround(b.x, b.y);
  Engine.buildingsChanged(b, true);
}

function hasRoadAccess(b) {
  for (let i = 0; i < b.w; i++) {
    if (isRoad(b.x + i, b.y - 1) || isRoad(b.x + i, b.y + b.h)) return true;
  }
  for (let j = 0; j < b.h; j++) {
    if (isRoad(b.x - 1, b.y + j) || isRoad(b.x + b.w, b.y + j)) return true;
  }
  return false;
}

/* Куда смотрит фасад: 0 — юг (+y), 1 — восток (+x), 2 — север, 3 — запад.
   Здание разворачивается к ближайшей дороге. */
function orientToRoad(b) {
  if (b.type === 'road' || BUILDINGS[b.type].kind === 'decor') return b.rot || 0;
  const sides = [
    () => { for (let i = 0; i < b.w; i++) if (isRoad(b.x + i, b.y + b.h)) return true; },
    () => { for (let j = 0; j < b.h; j++) if (isRoad(b.x + b.w, b.y + j)) return true; },
    () => { for (let i = 0; i < b.w; i++) if (isRoad(b.x + i, b.y - 1)) return true; },
    () => { for (let j = 0; j < b.h; j++) if (isRoad(b.x - 1, b.y + j)) return true; },
  ];
  for (let r = 0; r < 4; r++) if (sides[r]()) return r;
  return b.rot || 0;
}

function refreshOrientationsAround(x, y) {
  const seen = new Set();
  for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
    const b = buildingAt(x + dx, y + dy);
    if (!b || b.type === 'road' || seen.has(b)) continue;
    seen.add(b);
    const r = orientToRoad(b);
    if (r !== b.rot) { b.rot = r; Engine.buildingsChanged(b); }
  }
}

function adjacentRoads(b) {
  const out = [];
  const add = (x, y) => { if (isRoad(x, y)) out.push([x, y]); };
  for (let i = 0; i < b.w; i++) { add(b.x + i, b.y - 1); add(b.x + i, b.y + b.h); }
  for (let j = 0; j < b.h; j++) { add(b.x - 1, b.y + j); add(b.x + b.w, b.y + j); }
  return out;
}

// Квадрат расстояния между центрами двух построек (в клетках)
function dist2(a, b) {
  const dx = (a.x + a.w / 2) - (b.x + b.w / 2), dy = (a.y + a.h / 2) - (b.y + b.h / 2);
  return dx * dx + dy * dy;
}

// Сколько залежей нужного вида вокруг добытчика (0..1 от нормы)
function depositFactor(type, x, y) {
  const d = BUILDINGS[type];
  if (!d.deposit) return { count: 0, factor: 1 };
  const kinds = DEPOSIT_OF[d.deposit];
  const cx = x + d.w / 2, cy = y + d.h / 2, r = d.depositRadius;
  let n = 0;
  for (let ty = Math.floor(cy - r); ty <= cy + r; ty++) {
    for (let tx = Math.floor(cx - r); tx <= cx + r; tx++) {
      const dx = tx + 0.5 - cx, dy = ty + 0.5 - cy;
      if (dx * dx + dy * dy > r * r) continue;
      if (tx >= x && tx < x + d.w && ty >= y && ty < y + d.h) continue;
      if (kinds.includes(natureAt(tx, ty))) n++;
    }
  }
  return { count: n, factor: Math.min(1, n / d.depositNeed) };
}

// L-образный путь дороги от точки до точки
function roadPath(sx, sy, ex, ey) {
  const out = [];
  const dx = Math.sign(ex - sx), dy = Math.sign(ey - sy);
  let x = sx, y = sy;
  out.push([x, y]);
  if (Math.abs(ex - sx) >= Math.abs(ey - sy)) {
    while (x !== ex) { x += dx; out.push([x, y]); }
    while (y !== ey) { y += dy; out.push([x, y]); }
  } else {
    while (y !== ey) { y += dy; out.push([x, y]); }
    while (x !== ex) { x += dx; out.push([x, y]); }
  }
  return out;
}
