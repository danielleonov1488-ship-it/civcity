'use strict';
/* Рельеф уступами (как в Town to City): у каждой клетки земли — уровень 0…4, один уровень — полклетки в высоту.
   Между уровнями — подпорные стены из камня. Кисть «Рельеф» поднимает, опускает и выравнивает землю.
   Постройка стоит на одном уровне; мостовая лежит на своей клетке, а где она подходит к уступу с обеих сторон —
   сами собой получаются каменные ступени, по которым ходят жители. Вода и берег всегда на нулевом уровне. */

const LEVEL_H = 0.5;          // высота одного уровня
const LEVEL_MAX = 4;
const TERRAIN_COST = 8;       // денариев за подъём или опускание клетки на уровень
const TERRAIN_SIZES = [1, 2, 3, 4, 5];   // кисть рельефа — квадрат из стольких клеток на сторону
// подпорные стены: тёсаный камень тёплых оттенков (как у домов в стиле Synty), тёмный раствор, карниз у мостовой
const CLIFF_STONE = ['#d6cab0', '#cbbea2', '#ddd2ba', '#c2b598', '#d1c5aa'].map(h => new THREE.Color(h));
const CLIFF_MORTAR = new THREE.Color('#7d705b');
const CLIFF_CAP = new THREE.Color('#d8ccb0');

const Terrain = {
  levels: new Map(),          // 'tx,ty' → уровень (нулевые не храним)
  version: 0,
  brush: { mode: 1, size: 2 },   // 1 — поднять, -1 — опустить, 0 — выровнять; size — сторона квадрата в клетках

  levelAt(tx, ty) { return this.levels.size ? this.levels.get(tx + ',' + ty) || 0 : 0; },
  heightAt(x, y) { return this.levels.size ? this.levelAt(Math.floor(x), Math.floor(y)) * LEVEL_H : 0; },
  any() { return this.levels.size > 0; },
  // самый высокий уступ (для луча курсора)
  maxLevel() {
    if (this._maxV !== this.version) { this._maxV = this.version; this._max = 0; for (const l of this.levels.values()) if (l > this._max) this._max = l; }
    return this._max;
  },

  set(tx, ty, l) {
    const k = tx + ',' + ty;
    if (l > 0) this.levels.set(k, l); else this.levels.delete(k);
  },

  // Почему клетку нельзя поднимать или опускать (null — можно)
  blocked(tx, ty) {
    if (!isOwnedTile(tx, ty)) return 'Эта земля ещё не куплена';
    if (isWater(groundAt(tx, ty))) return 'Здесь вода';
    // у самой воды берег остаётся низким
    for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) if (isWater(groundAt(tx + dx, ty + dy))) return 'У воды берег не поднять';
    for (const b of buildingsNear(tx + 0.5, ty + 0.5, 1.5)) {
      if (b.lifted || b.on) continue;
      const o = boxOfB(b);
      if (boxPointDist(o, tx + 0.5, ty + 0.5) < 0.62) return 'Мешает постройка — перенесите её';
    }
    return null;
  },

  // клетки под кистью: квадрат size×size вокруг точки (x, y) — левый верхний угол
  brushOrigin(x, y, size) { return [Math.floor(x - size / 2 + 0.5), Math.floor(y - size / 2 + 0.5)]; },

  // Мазок кисти: квадрат size×size от клетки (tx0, ty0). done — клетки, уже изменённые этим мазком (каждую — раз за мазок).
  // to — уровень для «выровнять». Возвращает { changed: [[tx, ty, было]], cost, reason }
  stroke(tx0, ty0, size, mode, to, done, money) {
    const out = { changed: [], cost: 0, reason: null };
    for (let ty = ty0; ty < ty0 + size; ty++) {
      for (let tx = tx0; tx < tx0 + size; tx++) {
        const k = tx + ',' + ty;
        if (done.has(k)) continue;
        const was = this.levelAt(tx, ty);
        const want = mode === 0 ? to : clamp(was + mode, 0, LEVEL_MAX);
        if (want === was) continue;
        const why = this.blocked(tx, ty);
        if (why) { out.reason = out.reason || why; continue; }
        const price = Math.abs(want - was) * TERRAIN_COST;
        if (out.cost + price > money) { out.reason = out.reason || 'Не хватает денариев'; continue; }
        out.cost += price;
        done.add(k);
        this.set(tx, ty, want);
        out.changed.push([tx, ty, was]);
      }
    }
    if (out.changed.length) this.changed(out.changed);
    return out;
  },

  undo(list) {
    for (const [tx, ty, was] of list) this.set(tx, ty, was);
    this.changed(list);
  },

  // клетки поменяли высоту: перерисовать землю, природу и мостовую вокруг
  changed(list) {
    this.version++;
    const plots = new Set();
    for (const [tx, ty] of list) {
      for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) plots.add(plotOf(tx + dx) + ',' + plotOf(ty + dy));
      Engine.natureChanged(tx, ty);
    }
    for (const k of plots) {
      const [px, py] = k.split(',').map(Number);
      Engine.plotChanged(px, py);
      Paving.dirty.add(k);
    }
    Paving.version++;
    if (typeof Minimap !== 'undefined') Minimap.dirty = true;
  },

  /* ---------- Ступени между уровнями ----------
     Мелкая клетка мостовой — ступени, если она у края своей клетки, за краем клетка на уровень выше,
     и там, за краем, тоже мостовая. Ступени занимают две мелкие клетки от края (k — 0 у самого края, 1 — дальше). */
  stairAt(sx, sy) {
    if (!this.levels.size || !Paving.get(sx, sy)) return null;
    const tx = Math.floor(sx / SUB), ty = Math.floor(sy / SUB), L = this.levelAt(tx, ty);
    const lx = sx - tx * SUB, ly = sy - ty * SUB;
    for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
      if (this.levelAt(tx + dx, ty + dy) !== L + 1) continue;
      const k = dx > 0 ? SUB - 1 - lx : dx < 0 ? lx : dy > 0 ? SUB - 1 - ly : ly;
      if (k > 1) continue;
      // клетка у самого края и клетка за краем — замощены
      const ex = dx ? (dx > 0 ? tx * SUB + SUB - 1 : tx * SUB) : sx, ey = dy ? (dy > 0 ? ty * SUB + SUB - 1 : ty * SUB) : sy;
      if (!Paving.get(ex, ey) || !Paving.get(ex + dx, ey + dy)) continue;
      const deep = !!Paving.get(ex - dx, ey - dy);    // есть ли вторая ступень
      if (k === 1 && !deep) continue;
      return { dx, dy, k, deep, L };
    }
    return null;
  },

  // высота поверхности под ногами: земля, мостовая и ступени
  surfY(x, y) {
    const base = this.heightAt(x, y);
    if (!this.levels.size) return base + Paving.surfY(x, y);
    const sx = Math.floor(x * SUB), sy = Math.floor(y * SUB), st = this.stairAt(sx, sy);
    if (!st) return base + Paving.surfY(x, y);
    // расстояние до края клетки в сторону подъёма
    const tx = Math.floor(x), ty = Math.floor(y);
    const d = st.dx > 0 ? tx + 1 - x : st.dx < 0 ? x - tx : st.dy > 0 ? ty + 1 - y : y - ty;
    const run = st.deep ? 2 / SUB : 1 / SUB;
    return base + PAVE_H[3] + LEVEL_H * clamp(1 - d / run, 0, 1);
  },

  // можно ли шагнуть из (x0, y0) в (x1, y1): на тот же уровень — да, на соседний — только по ступеням
  canStep(x0, y0, x1, y1) {
    if (!this.levels.size) return true;
    const a = this.levelAt(Math.floor(x0), Math.floor(y0)), b = this.levelAt(Math.floor(x1), Math.floor(y1));
    if (a === b) return true;
    if (Math.abs(a - b) > 1) return false;
    const lo = a < b ? [x0, y0] : [x1, y1];
    return !!this.stairAt(Math.floor(lo[0] * SUB), Math.floor(lo[1] * SUB));
  },

  // есть ли ступени между соседними клетками (для поиска пути переселенцев)
  edgePass(tx, ty, nx, ny) {
    const a = this.levelAt(tx, ty), b = this.levelAt(nx, ny);
    if (a === b) return true;
    if (Math.abs(a - b) > 1) return false;
    const [lx, ly, hx, hy] = a < b ? [tx, ty, nx, ny] : [nx, ny, tx, ty];
    const dx = hx - lx, dy = hy - ly;
    for (let i = 0; i < SUB; i++) {
      const sx = dx ? (dx > 0 ? lx * SUB + SUB - 1 : lx * SUB) : lx * SUB + i, sy = dy ? (dy > 0 ? ly * SUB + SUB - 1 : ly * SUB) : ly * SUB + i;
      if (this.stairAt(sx, sy)) return true;
    }
    return false;
  },

  toJSON() { return [...this.levels.entries()]; },
  fromJSON(a) {
    this.levels = new Map(Array.isArray(a) ? a : []);
    this.version++;
  },
  clear() { this.levels.clear(); this.version++; },
};

// Высота основания постройки: украшение на стене висит, где его повесили; остальное стоит на земле своей клетки
function bY(b) { return b.on ? (b.yo || 0) : Terrain.heightAt(b.x + b.w / 2, b.y + b.h / 2) + (b.yo || 0); }
