'use strict';
/* Мостовая кистью — как в Town to City. Земля поделена на мелкие клетки, 4×4 на клетку карты; кисть закрашивает их
   одним из покрытий: тропинка, гравий, мостовая, площадь. Ластик стирает, «улучшить» превращает тропинку и гравий
   в мостовую. Края плавные (marching squares по сглаженному полю мелких клеток), у мостовой и площади сами встают бордюры,
   узор и рельеф камня рисует видеокарта — без картинок. Дома, лавки и украшения ставятся прямо на мостовую, жители
   ходят по всему мощёному. Залежи (камень, мрамор, железо) и густой лес вечные — их не замостить (permanentNature). */

const SUB = 4;                    // мелких клеток на сторону клетки карты
const CS = PLOT * SUB;            // мелких клеток на сторону участка
// высота поверхности: тропинка и гравий почти вровень с землёй, мостовая и площадь приподняты, вокруг — бордюр
const PAVE_H = [0, 0.012, 0.016, 0.034, 0.036];
const KERB_TOP = 0.056, KERB_W = 0.07;
// cost — денариев за клетку карты (16 мелких клеток); kerb — бордюр по краю
const PAVE = [null,
  { id: 'dirt', name: 'Тропинка', cost: 0.5, kerb: false, color: '#b89a6a', desc: 'Утоптанная земля — почти даром, для окраин и садов' },
  { id: 'gravel', name: 'Гравий', cost: 1.5, kerb: false, color: '#d6cfbd', desc: 'Светлый гравий — аккуратно и недорого' },
  { id: 'stone', name: 'Мостовая', cost: 3, kerb: true, color: '#cfc2a2', desc: 'Тёсаный камень с бордюрами — для главных улиц, красивее' },
  { id: 'plaza', name: 'Площадь', cost: 5, kerb: true, color: '#ece4d2', desc: 'Плиты травертина — площади и форумы, самое нарядное' },
];
const PAVE_TYPES = PAVE.length - 1;

const Paving = {
  chunks: new Map(),     // 'px,py' → Uint8Array(CS*CS): покрытие мелких клеток участка
  version: 0,
  dirty: new Set(),      // участки, которые надо перерисовать
  meshes: new Map(),
  _px: NaN, _py: NaN, _pc: null,   // последний участок, к которому обращались (жители спрашивают тысячи раз за кадр)
  _wx: NaN, _wy: NaN, _wcov: null,
  noPermanent: false,

  /* ---------- Клетки ---------- */

  get(sx, sy) {
    const px = Math.floor(sx / CS), py = Math.floor(sy / CS);
    let c;
    if (px === this._px && py === this._py) c = this._pc;
    else { c = this.chunks.get(px + ',' + py); this._px = px; this._py = py; this._pc = c; }
    return c ? c[(sy - py * CS) * CS + (sx - px * CS)] : 0;
  },

  set(sx, sy, t) {
    const px = Math.floor(sx / CS), py = Math.floor(sy / CS), key = px + ',' + py;
    let c = this.chunks.get(key);
    if (!c) { if (!t) return; c = new Uint8Array(CS * CS); this.chunks.set(key, c); this._px = NaN; }
    const lx = sx - px * CS, ly = sy - py * CS;
    c[ly * CS + lx] = t;
    this.dirty.add(key);
    // соседние участки тоже: сглаживание края смотрит на клетку-другую через границу участка
    const dxs = lx <= 1 ? [0, -1] : lx === CS - 1 ? [0, 1] : [0], dys = ly <= 1 ? [0, -1] : ly === CS - 1 ? [0, 1] : [0];
    if (dxs.length > 1 || dys.length > 1) for (const dx of dxs) for (const dy of dys) this.dirty.add((px + dx) + ',' + (py + dy));
  },

  // покрытие в точке мира (в клетках карты, дробно)
  at(x, y) { return this.get(Math.floor(x * SUB), Math.floor(y * SUB)); },

  // высота поверхности под ногами
  surfY(x, y) { return PAVE_H[this.at(x, y)]; },

  // клетка карты заметно замощена — на ней не растёт трава, она считается «дорогой»
  covers(tx, ty) {
    let n = 0;
    for (let j = 0; j < SUB; j++) for (let i = 0; i < SUB; i++) if (this.get(tx * SUB + i, ty * SUB + j)) n++;
    return n >= 6;
  },

  // мостовая подходит к середине клетки — дерево или куст на ней не уместится
  hidesNature(tx, ty) {
    const x = tx * SUB + 1, y = ty * SUB + 1;
    return !!(this.get(x, y) || this.get(x + 1, y) || this.get(x, y + 1) || this.get(x + 1, y + 1)) || this.covers(tx, ty);
  },

  // вокруг точки на r нет мостовой — пучку травы здесь можно расти
  free(x, y, r) { return !this.at(x, y) && !this.at(x + r, y) && !this.at(x - r, y) && !this.at(x, y + r) && !this.at(x, y - r); },

  // Почему здесь нельзя мостить (null — можно): чужая земля, вода, вечные залежи и лес
  blocked(sx, sy) {
    const tx = Math.floor(sx / SUB), ty = Math.floor(sy / SUB);
    if (!isOwnedTile(tx, ty)) return 'Эта земля ещё не куплена';
    if (isWater(groundAt(tx, ty))) return 'Здесь вода';
    const p = permanentNature(tx, ty);
    if (p === 'deposit') return 'Здесь залежи — их нельзя замостить';
    if (p === 'forest') return 'Здесь лес — его нельзя замостить';
    return null;
  },

  /* ---------- Кисть ---------- */

  // Мазок от (ax, ay) до (bx, by) кистью радиуса r. mode: номер покрытия, 0 — ластик, -1 — «улучшить» до мостовой.
  // money — сколько можно потратить. Возвращает { changed, cost, reason, undo: [sx, sy, было, ...], cleared: [клетки] }:
  // кусты, цветы и одинокие деревья, на которые легла мостовая, убираются (их вернёт только Ctrl+Z)
  stroke(ax, ay, bx, by, r, mode, money) {
    const out = { changed: 0, cost: 0, reason: null, undo: [], cleared: [] };
    const x0 = Math.floor((Math.min(ax, bx) - r) * SUB), x1 = Math.ceil((Math.max(ax, bx) + r) * SUB);
    const y0 = Math.floor((Math.min(ay, by) - r) * SUB), y1 = Math.ceil((Math.max(ay, by) + r) * SUB);
    const dx = bx - ax, dy = by - ay, L2 = dx * dx + dy * dy, r2 = r * r;
    const touched = new Set();
    for (let sy = y0; sy <= y1; sy++) {
      for (let sx = x0; sx <= x1; sx++) {
        const cx = (sx + 0.5) / SUB, cy = (sy + 0.5) / SUB;
        let t = L2 ? ((cx - ax) * dx + (cy - ay) * dy) / L2 : 0;
        t = t < 0 ? 0 : t > 1 ? 1 : t;
        const ex = ax + dx * t - cx, ey = ay + dy * t - cy;
        if (ex * ex + ey * ey > r2) continue;
        const was = this.get(sx, sy);
        let to = was;
        if (mode === 0) to = 0;
        else if (mode === -1) { if (was === 1 || was === 2) to = 3; }
        else to = mode;
        if (to === was) continue;
        if (to) {
          const why = this.blocked(sx, sy);
          if (why) { out.reason = out.reason || why; continue; }
          const price = Math.max(0, PAVE[to].cost - (was ? PAVE[was].cost : 0)) / (SUB * SUB);
          if (out.cost + price > money + 1e-9) { out.reason = out.reason || 'Не хватает денариев'; continue; }
          out.cost += price;
        }
        out.undo.push(sx, sy, was);
        this.set(sx, sy, to);
        out.changed++;
        touched.add(Math.floor(sx / SUB) + ',' + Math.floor(sy / SUB));
      }
    }
    if (out.changed) {
      this.version++;
      for (const k of touched) {
        const [tx, ty] = k.split(',').map(Number);
        if (natureAt(tx, ty) && !permanentNature(tx, ty) && this.hidesNature(tx, ty)) { state.cleared.add(tkey(tx, ty)); out.cleared.push(tkey(tx, ty)); }
        Engine.natureChanged(tx, ty);
      }
    }
    return out;
  },

  // Вернуть мазок как было (Ctrl+Z): клетки и убранные под мостовую кусты
  undo(rec, cleared) {
    const touched = new Set();
    for (let i = rec.length - 3; i >= 0; i -= 3) {
      this.set(rec[i], rec[i + 1], rec[i + 2]);
      touched.add(Math.floor(rec[i] / SUB) + ',' + Math.floor(rec[i + 1] / SUB));
    }
    for (const k of cleared || []) { state.cleared.delete(k); touched.add(k); }
    this.version++;
    for (const k of touched) { const [tx, ty] = k.split(',').map(Number); Engine.natureChanged(tx, ty); }
  },

  /* ---------- Вопросы стройки и жителей ---------- */

  // по мостовой можно идти: замощено и не стоит постройка (по карте построек участка — жители спрашивают часто)
  walkable(x, y) {
    const sx = Math.floor(x * SUB), sy = Math.floor(y * SUB);
    if (!this.get(sx, sy)) return false;
    const px = this._px, py = this._py;          // get() только что запомнил этот участок
    if (px !== this._wx || py !== this._wy) { this._wcov = this.coverOf(px, py); this._wx = px; this._wy = py; }
    return !this._wcov[(sy - py * CS) * CS + (sx - px * CS)];
  },

  // есть ли мостовая вплотную к прямоугольнику постройки (снаружи, с зазором до gap)
  touchesBox(o, gap) {
    const g = gap === undefined ? 0.3 : gap;
    const per = 2 * (o.hw + o.hh) * 2, n = Math.max(8, Math.ceil(per / 0.2));
    for (let i = 0; i < n; i++) {
      // точка на периметре, отодвинутая наружу на g
      let u = (i / n) * per, lx, ly;
      if (u < 2 * o.hw) { lx = -o.hw + u; ly = -o.hh - g; }
      else if ((u -= 2 * o.hw) < 2 * o.hh) { lx = o.hw + g; ly = -o.hh + u; }
      else if ((u -= 2 * o.hh) < 2 * o.hw) { lx = o.hw - u; ly = o.hh + g; }
      else { u -= 2 * o.hw; lx = -o.hw - g; ly = o.hh - u; }
      const [x, y] = boxWorld(o, lx, ly);
      if (this.at(x, y)) return true;
    }
    return !!this.at(o.cx, o.cy);
  },

  // Ближайший край мостовой от точки: идём по кругу направлений, ищем первую замощённую точку
  // (outward — наоборот, первую незамощённую: точка внутри мостовой ищет её край).
  // Возвращает { d, x, y, nx, ny } — расстояние, найденную точку и направление к ней, или null
  nearestEdge(fx, fy, maxD, outward) {
    const hit = (x, y) => outward ? !this.at(x, y) : this.at(x, y) > 0;
    let best = null;
    for (let k = 0; k < 32; k++) {
      const a = k / 32 * Math.PI * 2, nx = Math.sin(a), ny = Math.cos(a);
      for (let d = 0.1; d <= maxD; d += 0.1) {
        if (hit(fx + nx * d, fy + ny * d)) {
          if (!best || d < best.d) best = { d, x: fx + nx * d, y: fy + ny * d, nx, ny };
          break;
        }
      }
    }
    if (!best) return null;
    // направление к мостовой — по соседним лучам, чтобы дом вставал ровно вдоль края, а не под углом к одной клетке
    let sx = 0, sy = 0;
    for (let k = -3; k <= 3; k++) {
      const a = Math.atan2(best.nx, best.ny) + k * 0.12, nx = Math.sin(a), ny = Math.cos(a);
      for (let d = 0.1; d <= best.d + 1.2; d += 0.1) if (hit(fx + nx * d, fy + ny * d)) { const w = 1 / (d + 0.2); sx += nx * w; sy += ny * w; break; }
    }
    const l = Math.hypot(sx, sy);
    if (l > 1e-6) { best.nx = sx / l; best.ny = sy / l; }
    return best;
  },

  // Где житель выходит из дома на мостовую: точка у фасада и направление «от дома»
  contact(b) {
    const a = bAng(b), cx = b.x + b.w / 2, cy = b.y + b.h / 2;
    const fx = Math.sin(a), fy = Math.cos(a);
    for (let d = b.h / 2 + 0.12; d <= b.h / 2 + 1.4; d += 0.12) {
      for (const side of [0, 0.3, -0.3, 0.6, -0.6]) {
        const x = cx + fx * d - fy * side * b.w, y = cy + fy * d + fx * side * b.w;
        if (this.walkable(x, y)) return { x, y, dir: a };
      }
    }
    // фасад не у мостовой — любая сторона
    const o = boxOfB(b);
    for (let k = 0; k < 16; k++) {
      const ang = k / 16 * Math.PI * 2;
      for (let d = 0.2; d <= 1.4; d += 0.2) {
        const x = cx + Math.sin(ang) * (o.R + d), y = cy + Math.cos(ang) * (o.R + d);
        if (this.walkable(x, y)) return { x, y, dir: ang };
      }
    }
    return null;
  },

  // Сколько клеток замощено (для советника и подсказок)
  count() {
    let n = 0;
    for (const c of this.chunks.values()) for (let i = 0; i < c.length; i++) if (c[i]) n++;
    return n / (SUB * SUB);
  },

  /* ---------- Сохранение: по участкам, длинами одинаковых подряд, в base64 ---------- */

  toJSON() {
    const out = {};
    for (const [key, c] of this.chunks) {
      const runs = [];
      let i = 0, any = false;
      while (i < c.length) {
        const v = c[i];
        let n = 1;
        while (i + n < c.length && c[i + n] === v && n < 255) n++;
        runs.push(n, v);
        if (v) any = true;
        i += n;
      }
      if (!any) continue;
      let s = '';
      for (let k = 0; k < runs.length; k += 4096) s += String.fromCharCode(...runs.slice(k, k + 4096));
      out[key] = btoa(s);
    }
    return { v: 1, sub: SUB, c: out };
  },

  fromJSON(o) {
    this.clear();
    if (!o || !o.c) return;
    for (const [key, s] of Object.entries(o.c)) {
      const bin = atob(s), c = new Uint8Array(CS * CS);
      let p = 0;
      for (let i = 0; i + 1 < bin.length; i += 2) {
        const n = bin.charCodeAt(i), v = bin.charCodeAt(i + 1);
        c.fill(v, p, Math.min(c.length, p + n));
        p += n;
      }
      this.chunks.set(key, c);
      this.dirty.add(key);
    }
    this._px = NaN;
    this.version++;
  },

  clear() {
    for (const key of this.chunks.keys()) this.dirty.add(key);
    this.chunks.clear();
    this.cover.clear();
    this._px = this._wx = NaN;
    this.version++;
  },

  // Старый город: улицы-кривые становятся полосами мостовой той же формы, площади — площадью
  fromRoads() {
    for (const e of Roads.edges.values()) {
      const xy = e.xy;
      if (!xy || xy.length < 4) continue;
      for (let i = 0; i + 3 < xy.length; i += 2) this.stamp(xy[i], xy[i + 1], xy[i + 2], xy[i + 3], ROAD_HALF, 3);
    }
    // перекрёстки — круглые, как были мощёные круги
    for (const n of Roads.nodes.values()) if (n.edges && n.edges.size >= 3) this.stamp(n.x, n.y, n.x, n.y, ROAD_HALF * 1.45, 3);
    for (const key of Roads.plaza) {
      const [tx, ty] = key.split(',').map(Number);
      for (let j = 0; j < SUB; j++) for (let i = 0; i < SUB; i++) this.set(tx * SUB + i, ty * SUB + j, 4);
    }
    this.version++;
  },

  // Мазок без проверок и денег — для переноса старых городов и готовых карт
  stamp(ax, ay, bx, by, r, t) {
    const x0 = Math.floor((Math.min(ax, bx) - r) * SUB), x1 = Math.ceil((Math.max(ax, bx) + r) * SUB);
    const y0 = Math.floor((Math.min(ay, by) - r) * SUB), y1 = Math.ceil((Math.max(ay, by) + r) * SUB);
    const dx = bx - ax, dy = by - ay, L2 = dx * dx + dy * dy;
    for (let sy = y0; sy <= y1; sy++) {
      for (let sx = x0; sx <= x1; sx++) {
        const cx = (sx + 0.5) / SUB, cy = (sy + 0.5) / SUB;
        let t2 = L2 ? ((cx - ax) * dx + (cy - ay) * dy) / L2 : 0;
        t2 = t2 < 0 ? 0 : t2 > 1 ? 1 : t2;
        const ex = ax + dx * t2 - cx, ey = ay + dy * t2 - cy;
        if (ex * ex + ey * ey <= r * r && this.get(sx, sy) < t) this.set(sx, sy, t);
      }
    }
    this.version++;
  },

  /* ---------- Отрисовка ---------- */

  // постройка поставлена, перенесена или убрана — под ней мостовая не рисуется (там своё основание):
  // забыть карту построек и перерисовать участки, которых она касается
  cover: new Map(),       // 'px,py' → Uint8Array: мелкая клетка под постройкой с основанием
  buildingChanged(b) {
    if (BUILDINGS[b.type].kind === 'decor') return;
    this._wx = NaN;
    const o = boxOfB(b);
    for (let py = Math.floor((o.cy - o.R) / PLOT); py <= Math.floor((o.cy + o.R) / PLOT); py++) {
      for (let px = Math.floor((o.cx - o.R) / PLOT); px <= Math.floor((o.cx + o.R) / PLOT); px++) {
        this.cover.delete(px + ',' + py);
        // соседние участки тоже: их края сглаживаются с оглядкой на этот
        for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
          const k = (px + dx) + ',' + (py + dy);
          if (this.chunks.has(k) || this.meshes.has(k)) this.dirty.add(k);
        }
      }
    }
  },

  // всё перерисовать (после загрузки города или смены качества)
  redrawAll() {
    this.cover.clear();
    this._wx = NaN;
    for (const k of this.chunks.keys()) this.dirty.add(k);
    for (const k of this.meshes.keys()) this.dirty.add(k);
  },

  coverOf(px, py) {
    const key = px + ',' + py;
    let c = this.cover.get(key);
    if (c) return c;
    c = new Uint8Array(CS * CS);
    const x0 = px * PLOT, y0 = py * PLOT;
    for (const b of state.buildings.values()) {
      // лагерь переселенцев стоит прямо на утоптанной земле — она видна и под шатрами
      if (b.lifted || BUILDINGS[b.type].kind === 'decor' || (b.type === 'center' && !b.tier)) continue;
      const o = boxOfB(b);
      if (o.cx + o.R < x0 || o.cx - o.R > x0 + PLOT || o.cy + o.R < y0 || o.cy - o.R > y0 + PLOT) continue;
      const i0 = Math.max(0, Math.floor((o.cx - o.R - x0) * SUB)), i1 = Math.min(CS - 1, Math.ceil((o.cx + o.R - x0) * SUB));
      const j0 = Math.max(0, Math.floor((o.cy - o.R - y0) * SUB)), j1 = Math.min(CS - 1, Math.ceil((o.cy + o.R - y0) * SUB));
      for (let j = j0; j <= j1; j++) for (let i = i0; i <= i1; i++) {
        // с запасом внутрь: край мостовой всегда заходит под стену, без просвета земли
        if (boxContains(o, x0 + (i + 0.5) / SUB, y0 + (j + 0.5) / SUB, -0.16)) c[j * CS + i] = 1;
      }
    }
    this.cover.set(key, c);
    return c;
  },

  material() {
    if (this._mat) return this._mat;
    // с обеих сторон: у бордюров стенки смотрят в разные стороны; нормаль берётся из вершин, обход неважен.
    // patchMaterial — тени облаков, как у земли и домов
    const m = patchMaterial(new THREE.MeshLambertMaterial({ color: '#ffffff', side: THREE.DoubleSide }));
    const base = m.onBeforeCompile;
    m.onBeforeCompile = sh => {
      base(sh);
      sh.vertexShader = sh.vertexShader
        .replace('#include <common>', '#include <common>\nattribute float aType;\nattribute float aEdge;\nvarying float vType;\nvarying float vEdge;\nvarying float vUp;\nvarying vec2 vP;')
        .replace('#include <begin_vertex>', '#include <begin_vertex>\nvType = aType; vEdge = aEdge; vUp = normal.y; vP = (modelMatrix * vec4(position, 1.0)).xz;');
      sh.fragmentShader = sh.fragmentShader
        .replace('#include <common>', `#include <common>
varying float vType;
varying float vEdge;
varying float vUp;
varying vec2 vP;
float _pH = 0.0;   // высота рельефа (в клетках) — из неё наклон нормали: камни выпуклые, швы утоплены
float ph(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
vec2 ph2(vec2 p) { return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453); }
float pn(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
  return mix(mix(ph(i), ph(i + vec2(1.0, 0.0)), f.x), mix(ph(i + vec2(0.0, 1.0)), ph(i + vec2(1.0, 1.0)), f.x), f.y); }
// камни неправильной формы: расстояние до шва и номер камня
vec2 cells(vec2 x) {
  vec2 n = floor(x), f = fract(x);
  float d1 = 8.0, d2 = 8.0; vec2 id = n;
  for (int j = -1; j <= 1; j++) for (int i = -1; i <= 1; i++) {
    vec2 g = vec2(float(i), float(j));
    vec2 r = g + ph2(n + g) * 0.86 + 0.07 - f;
    float d = dot(r, r);
    if (d < d1) { d2 = d1; d1 = d; id = n + g; } else if (d < d2) d2 = d;
  }
  return vec2(sqrt(d2) - sqrt(d1), ph(id));
}
vec3 paveColor() {
  float t = floor(vType + 0.5);
  float aa = clamp(length(fwidth(vP)) * 6.0, 0.0, 1.0);   // вдали узор мельче пикселя — сглаживаем
  vec3 c;
  if (t < 1.5) {                       // тропинка: тёплая земля, мягкий край в траву
    float n = pn(vP * 3.0) * 0.6 + pn(vP * 11.0) * 0.4;
    c = mix(vec3(0.62, 0.50, 0.33), vec3(0.75, 0.63, 0.44), n);
    c *= 0.94 + 0.08 * ph(floor(vP * 24.0)) * (1.0 - aa);
    c = mix(c, vec3(0.47, 0.55, 0.27), vEdge * 0.7);
  } else if (t < 2.5) {                // гравий: светлая россыпь
    float n = ph(floor(vP * 26.0));
    c = mix(vec3(0.74, 0.70, 0.60), vec3(0.88, 0.85, 0.76), mix(n, 0.5, aa));
    c *= 0.93 + 0.08 * pn(vP * 4.0);
    c = mix(c, vec3(0.52, 0.58, 0.32), vEdge * 0.45);
  } else if (t < 3.5) {                // мостовая: камни неправильной формы со швами
    vec2 v = cells(vP * 2.8);
    float j = smoothstep(0.02, 0.10 + aa * 0.1, v.x);
    c = mix(vec3(0.80, 0.74, 0.62), vec3(0.88, 0.82, 0.70), v.y) * (0.95 + 0.07 * pn(vP * 7.0));
    c = mix(mix(vec3(0.55, 0.50, 0.41), c, j), c * 0.9, aa);
    _pH = j * 0.012 + v.y * 0.002;
    c *= 1.0 - vEdge * 0.08;
  } else if (t < 4.5) {                // площадь: травертин плитами вразбежку
    vec2 q = vP * vec2(1.4, 2.1);
    q.x += mod(floor(q.y), 2.0) * 0.5;
    vec2 f = fract(q);
    float jn = min(min(f.x, 1.0 - f.x) * 1.5, min(f.y, 1.0 - f.y));
    float j = smoothstep(0.012, 0.045 + aa * 0.06, jn);
    c = vec3(0.92, 0.88, 0.79) * (0.93 + 0.08 * ph(floor(q))) * (0.96 + 0.05 * pn(vP * 5.0));
    c = mix(mix(c * 0.74, c, j), c * 0.95, aa);
    _pH = j * 0.006;
  } else {                             // бордюр
    c = vec3(0.90, 0.87, 0.80) * (0.95 + 0.05 * ph(floor(vP * 3.0)));
  }
  return pow(c, vec3(2.2));            // цвета заданы как на экране (sRGB) — в линейные
}`)
        .replace('vec4 diffuseColor = vec4( diffuse, opacity );', 'vec4 diffuseColor = vec4( diffuse * paveColor(), opacity );')
        .replace('#include <normal_fragment_maps>', `#include <normal_fragment_maps>
normal = normalize( vNormal );
if (vUp > 0.5) {
  // наклон рельефа по производным в мировых координатах; вдали (пиксель крупнее шва) — плавно гаснет
  vec2 dx = dFdx(vP), dy = dFdy(vP);
  float hx = dFdx(_pH), hy = dFdy(_pH), det = dx.x * dy.y - dx.y * dy.x;
  float fade = 1.0 - smoothstep(0.015, 0.05, length(fwidth(vP)));
  if (abs(det) > 1e-12 && fade > 0.0) {
    vec2 g = vec2(hx * dy.y - hy * dx.y, hy * dx.x - hx * dy.x) / det;
    vec3 nw = normalize(vec3(-g.x * fade, 1.0, -g.y * fade));
    normal = normalize((viewMatrix * vec4(nw, 0.0)).xyz);
  }
}`);
    };
    m.customProgramCacheKey = () => 'pave';
    return (this._mat = m);
  },

  // Перерисовать участки, где что-то поменялось (не больше трёх за кадр — кисть не тормозит)
  sync() {
    if (!this.dirty.size) return;
    let n = 0;
    for (const key of this.dirty) {
      this.dirty.delete(key);
      this.buildChunk(key);
      if (++n >= 3) break;
    }
  },

  buildChunk(key) {
    const old = this.meshes.get(key);
    if (old) { Engine.scene.remove(old); old.geometry.dispose(); this.meshes.delete(key); }
    const [px, py] = key.split(',').map(Number);
    const sx0 = px * CS, sy0 = py * CS, M = CS + 3;
    // мелкие клетки участка с полосой вокруг (сглаживанию нужны соседи):
    // G — что рисовать (под постройками с основанием пусто), R — как замощено на самом деле (по нему — бордюры,
    // чтобы вокруг дома на площади не вставал бордюр)
    const G = new Uint8Array(M * M), R = new Uint8Array(M * M);
    const has = new Uint8Array(PAVE_TYPES + 1);
    let any = false, cqx = NaN, cqy = NaN, cov = null;
    for (let j = -1; j <= CS + 1; j++) {
      const sy = sy0 + j, qy = Math.floor(sy / CS);
      for (let i = -1; i <= CS + 1; i++) {
        const sx = sx0 + i, v = this.get(sx, sy);
        if (!v) continue;
        const k = (j + 1) * M + i + 1, qx = this._px;
        R[k] = v;
        if (qx !== cqx || qy !== cqy) { cov = this.coverOf(qx, qy); cqx = qx; cqy = qy; }
        if (cov[(sy - qy * CS) * CS + (sx - qx * CS)]) continue;
        G[k] = v;
        has[v] = 1;
        any = true;
      }
    }
    if (!any) return;
    // сглаженное поле покрытия в узлах (центрах мелких клеток 0..CS): доля соседей того же покрытия с весами 4-2-1 (из 16).
    // Край проходит по уровню ISO между узлами — плавной линией под любым углом, без «лесенки»
    const N = CS + 1, ISO = 7;
    const field = m => {
      const F = new Uint8Array(N * N);
      for (let j = 0; j < N; j++) {
        for (let i = 0, c = (j + 1) * M + 1; i < N; i++, c++) {
          F[j * N + i] = 4 * m[c] + 2 * (m[c - 1] + m[c + 1] + m[c - M] + m[c + M]) + m[c - M - 1] + m[c - M + 1] + m[c + M - 1] + m[c + M + 1];
        }
      }
      return F;
    };
    // маски: каждое покрытие; мощено камнем (мостовая или площадь) — для бордюра; мостовая под постройкой — там бордюр не нужен
    const masks = [], mk = new Uint8Array(M * M), mr = new Uint8Array(M * M), ma = new Uint8Array(M * M);
    for (let t = 1; t <= PAVE_TYPES; t++) if (has[t]) masks[t] = new Uint8Array(M * M);
    for (let k = 0; k < M * M; k++) {
      const r = R[k];
      if (!r) continue;
      ma[k] = 1;
      if (G[k]) masks[G[k]][k] = 1; else mr[k] = 1;
      if (PAVE[r].kerb) mk[k] = 1;
    }
    const F = [];
    for (let t = 1; t <= PAVE_TYPES; t++) if (has[t]) F[t] = field(masks[t]);
    const FK = field(mk), FR = field(mr), FA = field(ma);

    const pos = [], nrm = [], typ = [], edg = [];
    const vert = (x, z, y, t, e, nx, ny, nz) => { pos.push(x, y, z); nrm.push(nx, ny, nz); typ.push(t); edg.push(e); };
    const s = 1 / SUB;
    // точка на ребре между узлами p и q, где поле пересекает уровень ISO
    const cross = (P, Q, vp, vq) => { const f = vq === vp ? 0.5 : clamp((ISO - vp) / (vq - vp), 0, 1); return [P[0] + (Q[0] - P[0]) * f, P[1] + (Q[1] - P[1]) * f]; };
    // ячейка целиком внутри покрытия t и без бордюра — её можно слить с соседней в один прямоугольник
    const solid = (i, j, t) => {
      const a = j * N + i, b = a + 1, c = a + N + 1, d = a + N;
      const f = F[t];
      if (!f || f[a] < ISO || f[b] < ISO || f[c] < ISO || f[d] < ISO) return false;
      const k = FK[a] >= ISO;
      return (FK[b] >= ISO) === k && (FK[c] >= ISO) === k && (FK[d] >= ISO) === k;
    };
    for (let j = 0; j < CS; j++) {
      const Y0 = (sy0 + j + 0.5) * s, Y1 = Y0 + s;
      let i = 0;
      while (i < CS) {
        const a = j * N + i, b = a + 1, c = a + N + 1, d = a + N;
        if (!FA[a] && !FA[b] && !FA[c] && !FA[d]) { i++; continue; }      // рядом ничего не мощено
        const X0 = (sx0 + i + 0.5) * s, X1 = X0 + s;
        // какое покрытие здесь сплошное (одно на ячейку — иначе смешанная ячейка)
        let full = 0;
        for (let t = 1; t <= PAVE_TYPES; t++) if (F[t] && solid(i, j, t)) { full = full ? -1 : t; }
        if (full > 0) {
          let e = i + 1;
          while (e < CS && solid(e, j, full)) e++;
          const XE = (sx0 + e + 0.5) * s, y = PAVE_H[full];
          vert(X0, Y0, y, full, 0, 0, 1, 0); vert(X0, Y1, y, full, 0, 0, 1, 0); vert(XE, Y1, y, full, 0, 0, 1, 0);
          vert(X0, Y0, y, full, 0, 0, 1, 0); vert(XE, Y1, y, full, 0, 0, 1, 0); vert(XE, Y0, y, full, 0, 0, 1, 0);
          i = e;
          continue;
        }
        const C = [[X0, Y0], [X1, Y0], [X1, Y1], [X0, Y1]], idx = [a, b, c, d];
        // каждое покрытие в ячейке — своим многоугольником (marching squares с плавной границей)
        for (let t = 1; t <= PAVE_TYPES; t++) {
          const f = F[t];
          if (!f) continue;
          const v = idx.map(k => f[k]);
          if (v[0] < ISO && v[1] < ISO && v[2] < ISO && v[3] < ISO) continue;
          const y = PAVE_H[t], poly = [];
          for (let k = 0; k < 4; k++) {
            const k2 = (k + 1) % 4, pin = v[k] >= ISO, qin = v[k2] >= ISO;
            if (pin) poly.push(C[k][0], C[k][1], 0);
            if (pin !== qin) { const p = cross(C[k], C[k2], v[k], v[k2]); poly.push(p[0], p[1], 1); }
          }
          for (let k = 1; k + 1 < poly.length / 3; k++) {
            for (const w of [0, k, k + 1]) vert(poly[w * 3], poly[w * 3 + 1], y, t, poly[w * 3 + 2], 0, 1, 0);
          }
        }
        // бордюр: по границе мостовой или площади с тем, что не мощено камнем (постройки не в счёт);
        // где он зашёл под дом — не нужен, под открытыми постройками (поля, сады) тем более
        const vk = idx.map(k => FK[k]), K = vk.map(x => x >= ISO), nk = K.filter(Boolean).length;
        const hid = FR[a] >= ISO || FR[b] >= ISO || FR[c] >= ISO || FR[d] >= ISO;
        if (nk && nk < 4 && !hid) {
          const mids = [];
          for (let k = 0; k < 4; k++) { const k2 = (k + 1) % 4; if (K[k] !== K[k2]) mids.push(cross(C[k], C[k2], vk[k], vk[k2])); }
          let ix = 0, iy = 0;
          for (let k = 0; k < 4; k++) if (K[k]) { ix += C[k][0] / nk; iy += C[k][1] / nk; }
          for (let m = 0; m + 1 < mids.length; m += 2) {
            const A = mids[m], B = mids[m + 1];
            const dx = B[0] - A[0], dy = B[1] - A[1], l = Math.hypot(dx, dy) || 1;
            let nx = -dy / l, ny = dx / l;              // внутрь, к мощёному
            if ((ix - A[0]) * nx + (iy - A[1]) * ny < 0) { nx = -nx; ny = -ny; }
            const a1 = [A[0] + nx * KERB_W, A[1] + ny * KERB_W], b1 = [B[0] + nx * KERB_W, B[1] + ny * KERB_W];
            const T = KERB_TOP;
            vert(A[0], A[1], T, 5, 0, 0, 1, 0); vert(B[0], B[1], T, 5, 0, 0, 1, 0); vert(b1[0], b1[1], T, 5, 0, 0, 1, 0);
            vert(A[0], A[1], T, 5, 0, 0, 1, 0); vert(b1[0], b1[1], T, 5, 0, 0, 1, 0); vert(a1[0], a1[1], T, 5, 0, 0, 1, 0);
            // наружная стенка — до земли; внутренняя — до камня
            for (const [P, Q, lo, w] of [[A, B, 0, -1], [a1, b1, PAVE_H[3] - 0.004, 1]]) {
              const ex = nx * w, ey = ny * w;
              vert(P[0], P[1], lo, 5, 0, ex, 0, ey); vert(Q[0], Q[1], lo, 5, 0, ex, 0, ey); vert(Q[0], Q[1], T, 5, 0, ex, 0, ey);
              vert(P[0], P[1], lo, 5, 0, ex, 0, ey); vert(Q[0], Q[1], T, 5, 0, ex, 0, ey); vert(P[0], P[1], T, 5, 0, ex, 0, ey);
            }
          }
        }
        i++;
      }
    }
    if (!pos.length) return;
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
    g.setAttribute('normal', new THREE.Float32BufferAttribute(nrm, 3));
    g.setAttribute('aType', new THREE.Float32BufferAttribute(typ, 1));
    g.setAttribute('aEdge', new THREE.Float32BufferAttribute(edg, 1));
    g.computeBoundingSphere();
    const mesh = new THREE.Mesh(g, this.material());
    mesh.receiveShadow = true;
    Engine.scene.add(mesh);
    this.meshes.set(key, mesh);
  },
};

// Залежи и густой лес — вечные: их не застроить и не замостить (решение владельца 9 октября).
// 'deposit' — камень, мрамор, железо; 'forest' — дерево, вокруг которого ещё хотя бы три дерева; иначе null
function permanentNature(tx, ty) {
  if (Paving.noPermanent) return null;     // готовые города (#promo, #test) строятся поверх природы, как раньше
  const n = natureAt(tx, ty);
  if (!n) return null;
  if (n === N_STONE || n === N_ROCK || n === N_MARBLE || n === N_IRON) return 'deposit';
  if (n >= N_OAK && n <= N_CYPRESS) {
    let k = 0;
    for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
      if (!dx && !dy) continue;
      const m = natureAt(tx + dx, ty + dy);
      if (m >= N_OAK && m <= N_CYPRESS) k++;
    }
    if (k >= 3) return 'forest';
  }
  return null;
}
