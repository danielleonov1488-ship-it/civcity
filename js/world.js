'use strict';
/* Мир: бесконечная карта из участков, рельеф, природа, залежи.
   Постройки стоят без клеток: центр и угол поворота; занятость ищется по клеткам-корзинкам. */

const World = {
  terrain: new Map(),   // "px,py" → { ground, nature, vari }
  occ: new Map(),       // "x,y" → здание, накрывающее центр клетки (трава, деревья, клик)
  bgrid: new Map(),     // "x,y" → постройки, задевающие клетку (поиск соседей)
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
function isRoad(tx, ty) { return Paving.covers(tx, ty); }

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

// Постройка открыта: изучено знание, побеждено нужное число боссов, хватает рейтинга легиона (для чудес)
function isUnlocked(type) {
  const d = BUILDINGS[type];
  if (d.tech && !state.techs.includes(d.tech)) return false;
  if (d.boss && !(state.army && Math.floor(state.army.progress / STAGES_PER_REGION) >= d.boss)) return false;
  return !d.rating || !!(state.army && state.army.rating >= d.rating);
}

// Чего не хватает, чтобы открыть постройку: знание, победа над боссом или рейтинг
function lockName(type) {
  const d = BUILDINGS[type];
  if (d.tech && !state.techs.includes(d.tech)) return TECH_BY_ID[d.tech].name;
  if (d.boss && !isUnlocked(type)) return `Победа: ${Army.bossName(d.boss)}`;
  return d.rating ? `Рейтинг легиона ${d.rating}` : '';
}

/* ---------- Постройки без клеток ----------
   b.x, b.y — левый верхний угол неповёрнутого прямоугольника (центр — x + w/2, y + h/2), b.ang — поворот.
   Фасад смотрит в сторону (sin ang, cos ang): 0 — юг (+y), π/2 — восток. */

function bAng(b) { return b.ang !== undefined ? b.ang : (b.rot || 0) * Math.PI / 2; }
function normAng(a) { a %= Math.PI * 2; return a < 0 ? a + Math.PI * 2 : a; }
function rotIndex(a) { return Math.round(normAng(a) / (Math.PI / 2)) % 4; }

// Прямоугольник постройки: центр, полуразмеры, cos и sin угла; pad — запас (минус — ужать); s — размер украшения
function boxOf(type, cx, cy, ang, pad, s) {
  const d = BUILDINGS[type];
  // украшение занимает меньше своей клетки (fp — сколько места): их можно ставить теснее
  const deco = d.kind === 'decor', k = s || 1;
  const hw = (deco ? (d.fp || 0.72) * d.w : d.w) * k / 2 + (pad || 0), hh = (deco ? (d.fp || 0.72) * d.h : d.h) * k / 2 + (pad || 0);
  return { cx, cy, hw, hh, c: Math.cos(ang), s: Math.sin(ang), R: Math.hypot(hw, hh) };
}
function boxOfB(b, pad) { return boxOf(b.type, b.x + b.w / 2, b.y + b.h / 2, bAng(b), pad, b.s); }

function boxLocal(o, x, y) { const dx = x - o.cx, dy = y - o.cy; return [dx * o.c - dy * o.s, dx * o.s + dy * o.c]; }
function boxWorld(o, lx, ly) { return [o.cx + lx * o.c + ly * o.s, o.cy - lx * o.s + ly * o.c]; }
function boxContains(o, x, y, pad) { const [lx, ly] = boxLocal(o, x, y), p = pad || 0; return Math.abs(lx) <= o.hw + p && Math.abs(ly) <= o.hh + p; }
function boxPointDist(o, x, y) { const [lx, ly] = boxLocal(o, x, y); return Math.hypot(Math.max(0, Math.abs(lx) - o.hw), Math.max(0, Math.abs(ly) - o.hh)); }
function boxCorners(o) { return [[-o.hw, -o.hh], [o.hw, -o.hh], [o.hw, o.hh], [-o.hw, o.hh]].map(([a, b]) => boxWorld(o, a, b)); }

// Пересекаются ли два повёрнутых прямоугольника (теорема о разделяющей оси)
function boxOverlap(a, b) {
  const A = boxCorners(a), B = boxCorners(b);
  for (const o of [a, b]) {
    for (const [ax, ay] of [[o.c, -o.s], [o.s, o.c]]) {
      let a0 = Infinity, a1 = -Infinity, b0 = Infinity, b1 = -Infinity;
      for (const [x, y] of A) { const p = x * ax + y * ay; a0 = Math.min(a0, p); a1 = Math.max(a1, p); }
      for (const [x, y] of B) { const p = x * ax + y * ay; b0 = Math.min(b0, p); b1 = Math.max(b1, p); }
      if (a1 <= b0 || b1 <= a0) return false;
    }
  }
  return true;
}

// Постройка раскладывается по клеткам: где она задевает клетку и какие клетки накрывает целиком
function occupy(b) {
  const o = boxOfB(b);
  b._keys = [];
  b._cov = [];
  for (let ty = Math.floor(o.cy - o.R); ty <= Math.floor(o.cy + o.R); ty++) {
    for (let tx = Math.floor(o.cx - o.R); tx <= Math.floor(o.cx + o.R); tx++) {
      const k = tkey(tx, ty);
      let set = World.bgrid.get(k);
      if (!set) World.bgrid.set(k, set = new Set());
      set.add(b);
      b._keys.push(k);
      if (boxContains(o, tx + 0.5, ty + 0.5, 0.15)) { World.occ.set(k, b); b._cov.push(k); }
    }
  }
}

function unoccupy(b) {
  for (const k of b._keys || []) { const set = World.bgrid.get(k); if (set) { set.delete(b); if (!set.size) World.bgrid.delete(k); } }
  for (const k of b._cov || []) if (World.occ.get(k) === b) World.occ.delete(k);
}

function buildingsNear(x, y, r) {
  const out = new Set();
  for (let ty = Math.floor(y - r); ty <= Math.floor(y + r); ty++) {
    for (let tx = Math.floor(x - r); tx <= Math.floor(x + r); tx++) {
      const set = World.bgrid.get(tkey(tx, ty));
      if (set) for (const b of set) out.add(b);
    }
  }
  return out;
}

// Постройка, к которой точка ближе r (или внутри неё)
function buildingNear(x, y, r) {
  for (const b of buildingsNear(x, y, r + 0.5)) if (boxPointDist(boxOfB(b), x, y) < r) return b;
  return null;
}
function buildingAtPoint(x, y) { return buildingNear(x, y, 1e-6); }

// Место под постройку: своя земля, без воды, не на залежах, не в лесу и не на других постройках. null — свободно.
// На мостовую ставить можно — дом встанет прямо на камни
function placeBlocked(type, cx, cy, ang, s) {
  const o = boxOf(type, cx, cy, ang, 0, s);
  const nx = Math.max(1, Math.ceil(o.hw * 4)), ny = Math.max(1, Math.ceil(o.hh * 4));
  for (let j = 0; j <= ny; j++) {
    for (let i = 0; i <= nx; i++) {
      const [x, y] = boxWorld(o, (i / nx * 2 - 1) * (o.hw - 0.04), (j / ny * 2 - 1) * (o.hh - 0.04));
      const tx = Math.floor(x), ty = Math.floor(y);
      if (!isOwnedTile(tx, ty)) return 'Эта земля ещё не куплена';
      if (isWater(groundAt(tx, ty))) return 'Здесь вода';
    }
  }
  const tight = boxOf(type, cx, cy, ang, -0.03, s);
  for (const b of buildingsNear(cx, cy, o.R + 0.5)) if (boxOverlap(tight, boxOfB(b, -0.03))) return 'Место занято';
  // залежи и густой лес вечные: ни под домом, ни вплотную к стенам (там их убрала бы стройка)
  const pad = BUILDINGS[type].kind === 'decor' ? 0 : 0.25, big = boxOf(type, cx, cy, ang, pad, s);
  for (let ty = Math.floor(cy - big.R); ty <= Math.floor(cy + big.R); ty++) {
    for (let tx = Math.floor(cx - big.R); tx <= Math.floor(cx + big.R); tx++) {
      if (!boxContains(big, tx + 0.5, ty + 0.5)) continue;
      const keep = permanentNature(tx, ty);
      if (keep) return keep === 'deposit' ? 'Здесь залежи — на них строить нельзя' : 'Здесь лес — его нельзя вырубить';
    }
  }
  return null;
}

function nearWaterBox(o, r) {
  for (let ty = Math.floor(o.cy - o.R - r); ty <= Math.floor(o.cy + o.R + r); ty++) {
    for (let tx = Math.floor(o.cx - o.R - r); tx <= Math.floor(o.cx + o.R + r); tx++) {
      if (isWater(groundAt(tx, ty)) && boxPointDist(o, tx + 0.5, ty + 0.5) <= r + 0.5) return true;
    }
  }
  return false;
}

// null — можно строить, иначе причина отказа
function checkPlace(type, cx, cy, ang, s) {
  const d = BUILDINGS[type];
  if (!isUnlocked(type)) return 'Сначала изучите нужную технологию';
  if (d.unique && countType(type) > 0) return 'Такое здание в городе уже есть';
  const err = placeBlocked(type, cx, cy, ang, s);
  if (err) return err;
  if (d.needsWater && !nearWaterBox(boxOf(type, cx, cy, ang), 2)) return 'Нужно ставить у воды';
  if (!canAfford(d.cost)) return 'Не хватает: ' + missingFor(d.cost).join(', ');
  return null;
}

/* Куда встать постройке под курсором. У края мостовой дом сам разворачивается фасадом к ней и встаёт вплотную,
   а если место занято — сдвигается вдоль края к ближайшему свободному. Посреди площади и вдали от мостовой —
   там, где курсор, и как повернул игрок (Z / C или колёсико с Shift). */
function snapPlace(type, fx, fy, ang0) {
  const d = BUILDINGS[type];
  const free = { cx: fx, cy: fy, ang: ang0 || 0, road: false };
  if (d.kind === 'decor') return free;
  // курсор на мостовой: у самого края — дом встаёт снаружи, лицом к ней; дальше от края — прямо на камни
  const inside = Paving.at(fx, fy) > 0;
  const snapFrom = (x, y) => {
    if (Paving.at(x, y)) {
      const q = Paving.nearestEdge(x, y, 0.7, true);
      if (!q) return null;
      return { cx: q.x + q.nx * (d.h / 2 + 0.02), cy: q.y + q.ny * (d.h / 2 + 0.02), ang: Math.atan2(-q.nx, -q.ny), road: true, tx: -q.ny, ty: q.nx };
    }
    const q = Paving.nearestEdge(x, y, d.h / 2 + 1.4);
    if (!q) return null;
    return { cx: q.x - q.nx * (d.h / 2 + 0.02), cy: q.y - q.ny * (d.h / 2 + 0.02), ang: Math.atan2(q.nx, q.ny), road: true, tx: -q.ny, ty: q.nx };
  };
  const c0 = snapFrom(fx, fy);
  if (!c0) return free;
  if (!placeBlocked(type, c0.cx, c0.cy, c0.ang)) return snugUp(type, c0, snapFrom, fx, fy);
  // занято — ищем свободное место рядом вдоль края
  for (const ds of [0.25, -0.25, 0.5, -0.5, 0.75, -0.75, 1, -1, 1.25, -1.25, 1.5, -1.5]) {
    const c = snapFrom(fx + c0.tx * ds, fy + c0.ty * ds);
    if (c && !placeBlocked(type, c.cx, c.cy, c.ang)) return snugUp(type, c, snapFrom, fx + c0.tx * ds, fy + c0.ty * ds);
  }
  return inside ? free : c0;
}

/* Дома встают впритык: если рядом вдоль той же улицы уже стоит постройка и между ними меньше клетки,
   новая придвигается к ней боком до касания (каждая остаётся лицом к своему краю мостовой — на изгибе улицы
   дома сходятся углами, как в старых городах) */
function snugUp(type, c0, snapFrom, fx, fy) {
  const d = BUILDINGS[type];
  const fxn = Math.sin(c0.ang), fyn = Math.cos(c0.ang), sx = c0.tx, sy = c0.ty;
  let best = null;
  for (const n of buildingsNear(c0.cx, c0.cy, d.w + 3)) {
    const nd = BUILDINGS[n.type];
    if (nd.kind === 'decor' || n.lifted) continue;
    if (Math.cos(bAng(n) - c0.ang) < 0.85) continue;              // смотрит в другую сторону
    const dx = n.x + n.w / 2 - c0.cx, dy = n.y + n.h / 2 - c0.cy;
    if (Math.abs(dx * fxn + dy * fyn) > 1.0) continue;             // стоит не в том же ряду
    const u = dx * sx + dy * sy, gap = Math.abs(u) - (d.w + n.w) / 2;
    if (gap < 0.03 || gap > 1.2) continue;
    if (!best || gap < best.gap) best = { gap, dir: Math.sign(u) };
  }
  if (!best) return c0;
  // насколько можно придвинуться, чтобы не задеть соседа: поиск делением пополам
  let lo = 0, hi = best.gap + 0.05, out = c0;
  for (let i = 0; i < 8; i++) {
    const k = (lo + hi) / 2;
    const c = snapFrom(fx + sx * best.dir * k, fy + sy * best.dir * k);
    if (c && !placeBlocked(type, c.cx, c.cy, c.ang)) { lo = k; out = c; } else hi = k;
  }
  return out;
}

function makeBuilding(type, x, y) {
  const d = BUILDINGS[type];
  const b = { id: state.nextId++, type, x, y, w: d.w, h: d.h, rot: 0, ang: 0, born: performance.now() };
  if (d.kind === 'house') Object.assign(b, { tier: 0, pop: 0, up: 0, down: 0, happy: 50, lock: false });
  return b;
}

// Поставить постройку центром в (cx, cy) с поворотом ang
function placeBuilding(type, cx, cy, ang, free, s) {
  const d = BUILDINGS[type];
  const b = makeBuilding(type, cx - d.w / 2, cy - d.h / 2);
  if (s && Math.abs(s - 1) > 0.01) b.s = s;
  b.ang = normAng(ang || 0);
  b.rot = rotIndex(b.ang);
  state.buildings.set(b.id, b);
  occupy(b);
  clearNatureUnder(b);
  if (!free) pay(d.cost);
  Engine.buildingsChanged(b);
  Paving.buildingChanged(b);
  return b;
}

// Кусты, цветы и одинокие деревья под постройкой убираются, трава под ней не растёт (залежи и лес вечные)
function clearNatureUnder(b) {
  const o = boxOfB(b, 0.3);
  for (let ty = Math.floor(o.cy - o.R); ty <= Math.floor(o.cy + o.R); ty++) {
    for (let tx = Math.floor(o.cx - o.R); tx <= Math.floor(o.cx + o.R); tx++) {
      if (!boxContains(o, tx + 0.5, ty + 0.5)) continue;
      if (rawNatureAt(tx, ty) && !permanentNature(tx, ty)) state.cleared.add(tkey(tx, ty));
      Engine.natureChanged(tx, ty);
    }
  }
}

/* ---------- Перенос постройки ----------
   Пока постройку несут, она снята с карты (не мешает сама себе) и не рисуется; жители, уровень и товары при ней.
   Перенос бесплатный. */
function liftBuilding(b) {
  unoccupy(b);
  for (const k of b._cov || []) { const [tx, ty] = k.split(',').map(Number); Engine.natureChanged(tx, ty); }
  b.lifted = true;
  Engine.buildingsChanged(b);
  Paving.buildingChanged(b);
}

function dropBuilding(b, cx, cy, ang) {
  if (cx !== undefined) {
    b.x = cx - b.w / 2;
    b.y = cy - b.h / 2;
    b.ang = normAng(ang || 0);
    b.rot = rotIndex(b.ang);
    b.animAt = performance.now();
  }
  b.lifted = false;
  occupy(b);
  clearNatureUnder(b);
  Engine.buildingsChanged(b);
  Paving.buildingChanged(b);
}

// Можно ли поставить переносимую постройку сюда (null — можно)
function checkMove(b, cx, cy, ang) {
  const err = placeBlocked(b.type, cx, cy, ang, b.s);
  if (err) return err;
  if (BUILDINGS[b.type].needsWater && !nearWaterBox(boxOf(b.type, cx, cy, ang), 2)) return 'Нужно ставить у воды';
  return null;
}

// По клеткам, как раньше: левый верхний угол (tx, ty), фасадом к ближайшей мостовой (для тестового города)
function placeOnTile(type, tx, ty, free) {
  const d = BUILDINGS[type], cx = tx + d.w / 2, cy = ty + d.h / 2;
  const q = Paving.nearestEdge(cx, cy, d.w / 2 + 1.2);
  const ang = q ? Math.round(Math.atan2(q.nx, q.ny) / (Math.PI / 2)) * Math.PI / 2 : 0;
  if (placeBlocked(type, cx, cy, ang)) return null;
  return placeBuilding(type, cx, cy, ang, free);
}

function removeBuilding(b, refund) {
  unoccupy(b);
  for (const k of b._cov || []) { const [tx, ty] = k.split(',').map(Number); Engine.natureChanged(tx, ty); }
  state.buildings.delete(b.id);
  if (refund) {
    const c = BUILDINGS[b.type].cost;
    for (const [res, amount] of Object.entries(c)) {
      const back = Math.floor(amount * REFUND_SHARE);
      if (res === 'money') state.money += back;
      else if (res !== 'glory') state.goods[res] = (state.goods[res] || 0) + back;
    }
  }
  Engine.buildingsChanged(b, true);
  Paving.buildingChanged(b);
}

// Мостовая вплотную к постройке (с небольшим зазором) или постройка стоит прямо на ней
function hasRoadAccess(b) {
  return Paving.touchesBox(boxOfB(b), 0.45);
}

// Поворот постройки больше не меняется сам — она стоит, как её поставили
function orientToRoad(b) { return b.rot || 0; }

// Где житель выходит из дома на улицу: точка мостовой у фасада (или у любой стены) и направление от дома
function roadContact(b) { return Paving.contact(b); }

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
