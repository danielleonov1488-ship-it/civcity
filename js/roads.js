'use strict';
/* Дороги без клеток: сеть узлов и плавных улиц, как в Town to City.
   Улица — кривая через опорные точки (сплайн Катмулла — Рома), разложенная на точки через каждые ROAD_STEP.
   Узлы — концы улиц и перекрёстки. Новая улица сама цепляется к старым концам и улицам и режет их на перекрёстках.
   Дома стоят вдоль улиц под любым углом, жители и кошки ходят по сети узлов. */

const ROAD_HALF = 0.5;     // полширины улицы (в клетках)
const ROAD_STEP = 0.25;    // шаг точек вдоль улицы
const ROAD_SNAP = 0.75;    // так близко конец новой улицы цепляется к старой
const ROAD_GRID = 1;       // ячейка поиска — одна клетка

const Roads = {
  nodes: new Map(),        // id → { id, x, y, edges: Set }
  edges: new Map(),        // id → { id, a, b, pts, xy, cum, n, L, keys, cover }
  hash: new Map(),         // "x,y" → [edgeId, segIndex, …] — кусочки улиц по клеткам
  tiles: new Map(),        // "x,y" → сколько улиц накрывают клетку (трава, деревья, вода под улицей)
  plaza: new Set(),        // "x,y" — мощёные клетки площадей (из широких дорог старых городов)
  nextId: 1,
  version: 0,

  clear() {
    this.nodes.clear(); this.edges.clear(); this.hash.clear(); this.tiles.clear(); this.plaza.clear();
    this.nextId = 1;
    this.version++;
  },

  /* ---------- Узлы и улицы ---------- */

  addNode(x, y) {
    const n = { id: this.nextId++, x, y, edges: new Set() };
    this.nodes.set(n.id, n);
    return n;
  },

  // pts — опорные точки от узла a до узла b (концы совпадают с узлами)
  addEdge(a, b, pts, id) {
    const e = { id: id || this.nextId++, a: a.id, b: b.id, pts: pts.map(p => [p[0], p[1]]) };
    e.pts[0] = [a.x, a.y];
    e.pts[e.pts.length - 1] = [b.x, b.y];
    this.nextId = Math.max(this.nextId, e.id + 1);
    sampleEdge(e);
    this.edges.set(e.id, e);
    a.edges.add(e.id);
    b.edges.add(e.id);
    this.index(e);
    this.version++;
    return e;
  },

  removeEdge(id) {
    const e = this.edges.get(id);
    if (!e) return;
    this.unindex(e);
    this.edges.delete(id);
    for (const nid of [e.a, e.b]) {
      const n = this.nodes.get(nid);
      if (!n) continue;
      n.edges.delete(id);
      if (!n.edges.size) this.nodes.delete(nid);
    }
    this.version++;
  },

  other(e, nid) { return e.a === nid ? e.b : e.a; },

  // Кусочки улицы раскладываются по клеткам: так быстро ищется ближайшая улица и клетки под ней
  index(e) {
    e.keys = [];
    e.cover = [];
    const seen = new Set(), cov = new Set(), M = ROAD_HALF + 0.3;
    for (let i = 0; i < e.n - 1; i++) {
      const x0 = e.xy[i * 2], y0 = e.xy[i * 2 + 1], x1 = e.xy[i * 2 + 2], y1 = e.xy[i * 2 + 3];
      for (let ty = Math.floor(Math.min(y0, y1) - M); ty <= Math.floor(Math.max(y0, y1) + M); ty++) {
        for (let tx = Math.floor(Math.min(x0, x1) - M); tx <= Math.floor(Math.max(x0, x1) + M); tx++) {
          const k = tx + ',' + ty;
          let arr = this.hash.get(k);
          if (!arr) this.hash.set(k, arr = []);
          arr.push(e.id, i);
          if (!seen.has(k)) { seen.add(k); e.keys.push(k); }
          if (!cov.has(k) && segDist(tx + 0.5, ty + 0.5, x0, y0, x1, y1) < ROAD_HALF + 0.2) cov.add(k);
        }
      }
    }
    for (const k of cov) { e.cover.push(k); this.tiles.set(k, (this.tiles.get(k) || 0) + 1); }
  },

  unindex(e) {
    for (const k of e.keys) {
      const arr = this.hash.get(k);
      if (!arr) continue;
      const out = [];
      for (let j = 0; j < arr.length; j += 2) if (arr[j] !== e.id) out.push(arr[j], arr[j + 1]);
      if (out.length) this.hash.set(k, out); else this.hash.delete(k);
    }
    for (const k of e.cover) {
      const c = (this.tiles.get(k) || 1) - 1;
      if (c > 0) this.tiles.set(k, c); else this.tiles.delete(k);
    }
  },

  covers(tx, ty) { const k = tx + ',' + ty; return this.tiles.has(k) || this.plaza.has(k); },
  inPlaza(x, y) { return this.plaza.has(Math.floor(x) + ',' + Math.floor(y)); },

  // Снести мощёную клетку площади (дорожки сети под ней сносятся отдельно)
  removePlaza(tx, ty) {
    if (!this.plaza.delete(tx + ',' + ty)) return false;
    this.version++;
    return true;
  },

  /* ---------- Поиск ---------- */

  // Ближайшая точка улицы не дальше maxD: { e, i, s, x, y, d, tx, ty } (tx, ty — направление улицы)
  nearest(x, y, maxD, skip) {
    let best = null;
    const seen = new Set();
    for (let ty = Math.floor(y - maxD); ty <= Math.floor(y + maxD); ty++) {
      for (let tx = Math.floor(x - maxD); tx <= Math.floor(x + maxD); tx++) {
        const arr = this.hash.get(tx + ',' + ty);
        if (!arr) continue;
        for (let j = 0; j < arr.length; j += 2) {
          const id = arr[j], i = arr[j + 1], key = id * 100000 + i;
          if (seen.has(key)) continue;
          seen.add(key);
          if (skip && skip(id)) continue;
          const e = this.edges.get(id);
          const x0 = e.xy[i * 2], y0 = e.xy[i * 2 + 1], x1 = e.xy[i * 2 + 2], y1 = e.xy[i * 2 + 3];
          const dx = x1 - x0, dy = y1 - y0, len2 = dx * dx + dy * dy || 1e-9;
          const t = clamp(((x - x0) * dx + (y - y0) * dy) / len2, 0, 1);
          const px = x0 + dx * t, py = y0 + dy * t, d = Math.hypot(x - px, y - py);
          if (d > maxD || (best && d >= best.d)) continue;
          const len = Math.sqrt(len2);
          best = { e, i, s: e.cum[i] + t * len, x: px, y: py, d, tx: dx / len, ty: dy / len };
        }
      }
    }
    return best;
  },

  nodeNear(x, y, r) {
    let best = null, bd = r;
    for (const n of this.nodes.values()) {
      const d = Math.hypot(n.x - x, n.y - y);
      if (d <= bd) { bd = d; best = n; }
    }
    return best;
  },

  // Точка и направление улицы на расстоянии s от её начала
  pointAt(e, s) {
    s = clamp(s, 0, e.L);
    let i = Math.min(e.n - 2, Math.floor(s / ROAD_STEP));
    while (i > 0 && e.cum[i] > s) i--;
    while (i < e.n - 2 && e.cum[i + 1] < s) i++;
    const x0 = e.xy[i * 2], y0 = e.xy[i * 2 + 1], x1 = e.xy[i * 2 + 2], y1 = e.xy[i * 2 + 3];
    const len = e.cum[i + 1] - e.cum[i] || 1e-9, t = (s - e.cum[i]) / len;
    return { x: x0 + (x1 - x0) * t, y: y0 + (y1 - y0) * t, tx: (x1 - x0) / len, ty: (y1 - y0) / len };
  },

  // Расстояние от улиц до повёрнутого прямоугольника здания (не дальше maxD, иначе Infinity)
  distToBox(o, maxD) {
    let best = Infinity;
    const r = o.R + maxD, seen = new Set();
    for (let ty = Math.floor(o.cy - r); ty <= Math.floor(o.cy + r); ty++) {
      for (let tx = Math.floor(o.cx - r); tx <= Math.floor(o.cx + r); tx++) {
        const arr = this.hash.get(tx + ',' + ty);
        if (!arr) continue;
        for (let j = 0; j < arr.length; j += 2) {
          const key = arr[j] * 100000 + arr[j + 1];
          if (seen.has(key)) continue;
          seen.add(key);
          const e = this.edges.get(arr[j]), i = arr[j + 1];
          const d = segBoxDist(o, e.xy[i * 2], e.xy[i * 2 + 1], e.xy[i * 2 + 2], e.xy[i * 2 + 3]);
          if (d < best) best = d;
        }
      }
    }
    return best;
  },

  length() {
    let L = 0;
    for (const e of this.edges.values()) L += e.L;
    return L;
  },

  /* ---------- Прокладка новой улицы ---------- */

  // Путь мыши → готовая к постройке улица: сглаживание, зацепка за старые улицы, проверка места
  plan(raw, straight) {
    if (raw.length < 2) return null;
    let ctrl;
    if (straight) ctrl = [raw[0], raw[raw.length - 1]];
    else {
      let p = resample(raw, ROAD_STEP);
      for (let k = 0; k < 3; k++) p = smooth(p);
      ctrl = simplify(p, 0.3);
    }
    ctrl = ctrl.map(p => [p[0], p[1]]);
    const snapEnd = (p, other) => {
      const n = this.nodeNear(p[0], p[1], ROAD_SNAP);
      if (n) return { node: n, x: n.x, y: n.y };
      const q = this.nearest(p[0], p[1], ROAD_SNAP);
      if (q && Math.hypot(q.x - other[0], q.y - other[1]) > 0.5) return { edge: q.e.id, s: q.s, x: q.x, y: q.y };
      return null;
    };
    const A = snapEnd(ctrl[0], ctrl[ctrl.length - 1]);
    const B = snapEnd(ctrl[ctrl.length - 1], ctrl[0]);
    if (A) ctrl[0] = [A.x, A.y];
    if (B) ctrl[ctrl.length - 1] = [B.x, B.y];
    // опорные точки слишком близко к зацепленным концам сбили бы изгиб — убираем
    while (ctrl.length > 2 && Math.hypot(ctrl[1][0] - ctrl[0][0], ctrl[1][1] - ctrl[0][1]) < 0.6) ctrl.splice(1, 1);
    while (ctrl.length > 2 && Math.hypot(ctrl[ctrl.length - 2][0] - ctrl[ctrl.length - 1][0], ctrl[ctrl.length - 2][1] - ctrl[ctrl.length - 1][1]) < 0.6) ctrl.splice(ctrl.length - 2, 1);
    const path = { pts: ctrl };
    sampleEdge(path);
    const plan = { pts: ctrl, path, A, B, L: path.L, crossings: [], err: null };
    plan.cost = roadCost(path.L);
    plan.err = this.check(plan);
    return plan;
  },

  // null — можно строить, иначе причина
  check(plan) {
    const P = plan.path;
    if (P.L < 0.6) return 'Слишком короткая дорога';
    if (plan.A && plan.B && plan.A.node && plan.A.node === plan.B.node) return 'Дорога замыкается сама на себя';
    // пересечения со старыми улицами: там будут перекрёстки
    const cross = [];
    for (let i = 0; i < P.n - 1; i++) {
      const x0 = P.xy[i * 2], y0 = P.xy[i * 2 + 1], x1 = P.xy[i * 2 + 2], y1 = P.xy[i * 2 + 3];
      const seen = new Set();
      for (let ty = Math.floor(Math.min(y0, y1)); ty <= Math.floor(Math.max(y0, y1)); ty++) {
        for (let tx = Math.floor(Math.min(x0, x1)); tx <= Math.floor(Math.max(x0, x1)); tx++) {
          const arr = this.hash.get(tx + ',' + ty);
          if (!arr) continue;
          for (let j = 0; j < arr.length; j += 2) {
            const key = arr[j] * 100000 + arr[j + 1];
            if (seen.has(key)) continue;
            seen.add(key);
            const e = this.edges.get(arr[j]), k = arr[j + 1];
            const hit = segCross(x0, y0, x1, y1, e.xy[k * 2], e.xy[k * 2 + 1], e.xy[k * 2 + 2], e.xy[k * 2 + 3]);
            if (!hit) continue;
            const s = P.cum[i] + hit[0] * (P.cum[i + 1] - P.cum[i]);
            if (s < 0.3 || s > P.L - 0.3) continue;   // у самых концов — это зацепка, а не пересечение
            cross.push({ s, x: x0 + (x1 - x0) * hit[0], y: y0 + (y1 - y0) * hit[0] });
          }
        }
      }
    }
    cross.sort((a, b) => a.s - b.s);
    plan.crossings = cross.filter((c, i) => !i || c.s - cross[i - 1].s > 0.6);
    // вдоль старой улицы класть нельзя: только пересекать и примыкать
    const near = s => (plan.A && s < 1.1) || (plan.B && s > P.L - 1.1) || plan.crossings.some(c => Math.abs(c.s - s) < 1.1);
    for (let i = 0; i < P.n; i++) {
      const x = P.xy[i * 2], y = P.xy[i * 2 + 1], s = P.cum[i];
      const tx = Math.floor(x), ty = Math.floor(y);
      if (!isOwnedTile(tx, ty)) return 'Эта земля ещё не куплена';
      if (isWater(groundAt(tx, ty))) return 'Через воду дорогу не проложить';
      if (!near(s) && this.nearest(x, y, 0.9)) return 'Здесь уже есть дорога';
      const b = buildingNear(x, y, ROAD_HALF - 0.04);
      if (b) return `Мешает: ${BUILDINGS[b.type].name.toLowerCase()}`;
    }
    if (!canAfford(plan.cost)) return 'Не хватает: ' + missingFor(plan.cost).join(', ');
    return null;
  },

  // Построить улицу по готовому плану: узлы на концах и перекрёстках, старые улицы режутся
  build(plan) {
    const P = plan.path;
    const at = (end, x, y) => {
      if (end && end.node && this.nodes.has(end.node.id)) return end.node;
      const n = this.nodeNear(x, y, 0.45);
      if (n) return n;
      const q = this.nearest(x, y, 0.3);
      if (q) return this.split(q.e, q.s);
      return this.addNode(x, y);
    };
    const stops = [{ s: 0, node: at(plan.A, P.xy[0], P.xy[1]) }];
    for (const c of plan.crossings) stops.push({ s: c.s, node: at(null, c.x, c.y) });
    stops.push({ s: P.L, node: at(plan.B, P.xy[(P.n - 1) * 2], P.xy[(P.n - 1) * 2 + 1]) });
    const made = [];
    for (let k = 0; k < stops.length - 1; k++) {
      const A = stops[k], B = stops[k + 1];
      if (A.node === B.node || B.s - A.s < 0.3) continue;
      made.push(this.addEdge(A.node, B.node, controlFrom(P, A.s, B.s)));
    }
    for (const e of made) clearNatureAlong(e);
    return made;
  },

  // Разрезать улицу точкой на расстоянии s — вернуть узел (у самых концов — сам конец)
  split(e, s) {
    if (s < 0.35) return this.nodes.get(e.a);
    if (s > e.L - 0.35) return this.nodes.get(e.b);
    const p = this.pointAt(e, s);
    const n = this.addNode(p.x, p.y);
    const a = this.nodes.get(e.a), b = this.nodes.get(e.b);
    const c1 = controlFrom(e, 0, s), c2 = controlFrom(e, s, e.L);
    this.removeEdge(e.id);
    // removeEdge мог убрать опустевшие концы — возвращаем их
    for (const m of [a, b]) if (!this.nodes.has(m.id)) this.nodes.set(m.id, m);
    this.addEdge(a, n, c1);
    this.addEdge(n, b, c2);
    return n;
  },

  // Снос куска улицы под курсором (около полутора клеток). Возвращает длину снесённого.
  removeAt(x, y) {
    const q = this.nearest(x, y, ROAD_HALF);
    if (!q) return 0;
    const e = q.e;
    let s0 = q.s - 0.6, s1 = q.s + 0.6;
    if (s0 < 0.4) s0 = 0;
    if (s1 > e.L - 0.4) s1 = e.L;
    // кусок [s0, s1] вырезается в отдельную улицу и сносится; найти его можно по средней точке
    const mid = this.pointAt(e, (s0 + s1) / 2);
    const pieceAt = () => { const h = this.nearest(mid.x, mid.y, 0.25); return h && h.e; };
    if (s1 < e.L) this.split(e, s1);
    let piece = pieceAt();
    if (piece && s0 > 0) { this.split(piece, s0); piece = pieceAt(); }
    if (!piece) return 0;
    const len = piece.L;
    this.removeEdge(piece.id);
    return len;
  },

  /* ---------- Улицы целиком для отрисовки: цепочки через узлы, где сходятся ровно две улицы ---------- */

  strokes() {
    const used = new Set(), out = [];
    for (const e0 of this.edges.values()) {
      if (used.has(e0.id)) continue;
      used.add(e0.id);
      const ahead = [], behind = [];
      let nid = e0.b;
      for (let next; (next = this.continueAt(nid, used));) {
        used.add(next.id);
        const fwd = next.a === nid;
        ahead.push({ e: next, fwd });
        nid = fwd ? next.b : next.a;
      }
      nid = e0.a;
      for (let next; (next = this.continueAt(nid, used));) {
        used.add(next.id);
        const fwd = next.b === nid;
        behind.push({ e: next, fwd });
        nid = fwd ? next.a : next.b;
      }
      out.push(this.makeStroke(behind.reverse().concat([{ e: e0, fwd: true }], ahead)));
    }
    return out;
  },

  // Улица продолжается через узел, только если в нём сходятся ровно две
  continueAt(nid, used) {
    const n = this.nodes.get(nid);
    if (!n || n.edges.size !== 2) return null;
    for (const id of n.edges) if (!used.has(id)) return this.edges.get(id);
    return null;
  },

  makeStroke(chain) {
    const pts = [];
    let rank = Infinity;
    for (const { e, fwd } of chain) {
      rank = Math.min(rank, e.id);
      for (let k = 0; k < e.n; k++) {
        const i = fwd ? k : e.n - 1 - k;
        if (pts.length && k === 0) continue;
        pts.push(e.xy[i * 2], e.xy[i * 2 + 1]);
      }
    }
    const first = chain[0], last = chain[chain.length - 1];
    const startNode = first.fwd ? first.e.a : first.e.b, endNode = last.fwd ? last.e.b : last.e.a;
    const deg = id => { const n = this.nodes.get(id); return n ? n.edges.size : 0; };
    return { rank, ids: chain.map(c => c.e.id), xy: pts, start: { id: startNode, deg: deg(startNode) }, end: { id: endNode, deg: deg(endNode) }, closed: startNode === endNode && chain.length > 1 };
  },

  /* ---------- Сохранение и перенос старых городов ---------- */

  toJSON() {
    const r = v => Math.round(v * 1000) / 1000;
    return {
      n: [...this.nodes.values()].map(n => [n.id, r(n.x), r(n.y)]),
      e: [...this.edges.values()].map(e => [e.id, e.a, e.b, e.pts.flatMap(p => [r(p[0]), r(p[1])])]),
      p: [...this.plaza],
    };
  },

  fromJSON(data) {
    this.clear();
    for (const [id, x, y] of data.n || []) {
      this.nodes.set(id, { id, x, y, edges: new Set() });
      this.nextId = Math.max(this.nextId, id + 1);
    }
    for (const [id, a, b, flat] of data.e || []) {
      const A = this.nodes.get(a), B = this.nodes.get(b);
      if (!A || !B) continue;
      const pts = [];
      for (let i = 0; i < flat.length; i += 2) pts.push([flat[i], flat[i + 1]]);
      this.addEdge(A, B, pts, id);
    }
    for (const n of [...this.nodes.values()]) if (!n.edges.size) this.nodes.delete(n.id);
    for (const k of data.p || []) this.plaza.add(k);
  },

  // Старые дороги по клеткам → сеть: прямые участки — одна улица, на углах и развилках — узлы.
  // Широкие дороги и площади (где дорога лежит квадратом 2×2) становятся мощёной площадью — как и были.
  fromTiles(tiles) {
    this.clear();
    const has = (x, y) => tiles.has(x + ',' + y);
    for (const k of tiles) {
      const [x, y] = k.split(',').map(Number);
      for (const [dx, dy] of [[0, 0], [-1, 0], [0, -1], [-1, -1]]) {
        const ax = x + dx, ay = y + dy;
        if (has(ax, ay) && has(ax + 1, ay) && has(ax, ay + 1) && has(ax + 1, ay + 1)) { this.plaza.add(k); break; }
      }
    }
    const DIRS = [[1, 0], [-1, 0], [0, 1], [0, -1]];
    const nb = (x, y) => DIRS.filter(([dx, dy]) => has(x + dx, y + dy));
    const isNode = (x, y) => {
      const d = nb(x, y);
      return d.length !== 2 || d[0][0] !== -d[1][0] || d[0][1] !== -d[1][1];
    };
    const nodeAt = new Map();
    const node = (x, y) => {
      const k = x + ',' + y;
      if (!nodeAt.has(k)) nodeAt.set(k, this.addNode(x + 0.5, y + 0.5));
      return nodeAt.get(k);
    };
    const done = new Set();
    for (const k of tiles) {
      const [x, y] = k.split(',').map(Number);
      if (!isNode(x, y)) continue;
      const dirs = nb(x, y);
      if (!dirs.length) {
        // одинокая клетка дороги — короткий кусочек улицы
        const a = this.addNode(x + 0.2, y + 0.5), b = this.addNode(x + 0.8, y + 0.5);
        this.addEdge(a, b, [[a.x, a.y], [b.x, b.y]]);
        continue;
      }
      for (const [dx, dy] of dirs) {
        let cx = x + dx, cy = y + dy;
        while (!isNode(cx, cy)) { cx += dx; cy += dy; }
        const key = [x, y, cx, cy].join(':'), back = [cx, cy, x, y].join(':');
        if (done.has(key) || done.has(back)) continue;
        done.add(key);
        const A = node(x, y), B = node(cx, cy);
        if (A !== B) this.addEdge(A, B, [[A.x, A.y], [B.x, B.y]]);
      }
    }
    this.roundCorners();
  },

  // Углы старых дорог скругляются: цепочка через узлы-повороты становится одной плавной улицей,
  // «лесенка» из клеток — ровной косой улицей. Угол срезается не больше чем на треть клетки.
  roundCorners() {
    const used = new Set();
    for (const e0 of [...this.edges.values()]) {
      if (used.has(e0.id) || !this.edges.has(e0.id)) continue;
      used.add(e0.id);
      const ahead = [], behind = [];
      let nid = e0.b;
      for (let next; (next = this.continueAt(nid, used));) { used.add(next.id); ahead.push(next); nid = this.other(next, nid); }
      const end = nid;
      nid = e0.a;
      for (let next; (next = this.continueAt(nid, used));) { used.add(next.id); behind.push(next); nid = this.other(next, nid); }
      const start = nid;
      if (!ahead.length && !behind.length) continue;
      if (start === end) continue;                     // кольцо — оставляем как есть
      // узлы цепочки по порядку от start до end
      const chain = behind.reverse().concat([e0], ahead);
      const ids = [start];
      for (const e of chain) ids.push(this.other(e, ids[ids.length - 1]));
      const P = ids.map(id => this.nodes.get(id)).map(n => [n.x, n.y]);
      // по прямым — опорная точка через клетку (сплайн их не выгнет), у поворота — срез угла
      const pts = [P[0]], k = P.length - 1;
      for (let i = 0; i < k; i++) {
        const a = P[i], b = P[i + 1], d = Math.hypot(b[0] - a[0], b[1] - a[1]);
        const at = s => [a[0] + (b[0] - a[0]) * s / d, a[1] + (b[1] - a[1]) * s / d];
        const s0 = i > 0 ? Math.min(0.3 * d, 0.33) : 0, s1 = i < k - 1 ? d - Math.min(0.3 * d, 0.33) : d;
        if (i > 0) pts.push(at(s0));
        for (let s = s0 + 1; s < s1 - 0.5; s += 1) pts.push(at(s));
        if (i < k - 1) pts.push(at(s1));
      }
      pts.push(P[k]);
      const A = this.nodes.get(start), B = this.nodes.get(end);
      for (const e of chain) this.removeEdge(e.id);
      for (const id of [A.id, B.id]) if (!this.nodes.has(id)) this.nodes.set(id, id === A.id ? A : B);
      used.add(this.addEdge(A, B, pts).id);
    }
  },
};

/* ---------- Геометрия ---------- */

function roadCost(L) {
  const k = Math.max(1, Math.ceil(L - 0.2));
  const out = {};
  for (const [r, v] of Object.entries(BUILDINGS.road.cost)) out[r] = v * k;
  return out;
}

function segDist(px, py, x0, y0, x1, y1) {
  const dx = x1 - x0, dy = y1 - y0, l2 = dx * dx + dy * dy || 1e-9;
  const t = clamp(((px - x0) * dx + (py - y0) * dy) / l2, 0, 1);
  return Math.hypot(px - x0 - dx * t, py - y0 - dy * t);
}

function segDistToEdge(e, x, y) {
  let d = Infinity;
  for (let i = 0; i < e.n - 1; i++) d = Math.min(d, segDist(x, y, e.xy[i * 2], e.xy[i * 2 + 1], e.xy[i * 2 + 2], e.xy[i * 2 + 3]));
  return d;
}

// Пересечение отрезков: [t по первому, u по второму] или null
function segCross(ax, ay, bx, by, cx, cy, dx, dy) {
  const rx = bx - ax, ry = by - ay, sx = dx - cx, sy = dy - cy;
  const den = rx * sy - ry * sx;
  if (Math.abs(den) < 1e-9) return null;
  const t = ((cx - ax) * sy - (cy - ay) * sx) / den, u = ((cx - ax) * ry - (cy - ay) * rx) / den;
  return t >= 0 && t <= 1 && u >= 0 && u <= 1 ? [t, u] : null;
}

// Расстояние от отрезка до повёрнутого прямоугольника o = { cx, cy, c, s, hw, hh }
function segBoxDist(o, x0, y0, x1, y1) {
  const loc = (x, y) => { const dx = x - o.cx, dy = y - o.cy; return [dx * o.c - dy * o.s, dx * o.s + dy * o.c]; };
  const [ax, ay] = loc(x0, y0), [bx, by] = loc(x1, y1);
  const W = o.hw, H = o.hh;
  const inBox = (x, y) => Math.abs(x) <= W && Math.abs(y) <= H;
  if (inBox(ax, ay) || inBox(bx, by)) return 0;
  const corners = [[-W, -H], [W, -H], [W, H], [-W, H]];
  for (let k = 0; k < 4; k++) {
    const p = corners[k], q = corners[(k + 1) % 4];
    if (segCross(ax, ay, bx, by, p[0], p[1], q[0], q[1])) return 0;
  }
  const pd = (x, y) => Math.hypot(Math.max(0, Math.abs(x) - W), Math.max(0, Math.abs(y) - H));
  let d = Math.min(pd(ax, ay), pd(bx, by));
  for (const [cx, cy] of corners) d = Math.min(d, segDist(cx, cy, ax, ay, bx, by));
  return d;
}

// Точки улицы: сплайн через опорные точки, затем ровный шаг ROAD_STEP вдоль кривой
function sampleEdge(e) {
  const P = e.pts;
  const dense = [];
  if (P.length === 2) dense.push(P[0], P[1]);
  else {
    for (let i = 0; i < P.length - 1; i++) {
      const p0 = P[i - 1] || [2 * P[0][0] - P[1][0], 2 * P[0][1] - P[1][1]];
      const p3 = P[i + 2] || [2 * P[i + 1][0] - P[i][0], 2 * P[i + 1][1] - P[i][1]];
      const len = Math.hypot(P[i + 1][0] - P[i][0], P[i + 1][1] - P[i][1]);
      const steps = Math.max(2, Math.ceil(len / 0.05));
      for (let k = i ? 1 : 0; k <= steps; k++) dense.push(catmullRom(p0, P[i], P[i + 1], p3, k / steps));
    }
  }
  const pts = resample(dense, ROAD_STEP);
  e.n = pts.length;
  e.xy = new Float32Array(e.n * 2);
  e.cum = new Float32Array(e.n);
  for (let i = 0; i < e.n; i++) {
    e.xy[i * 2] = pts[i][0];
    e.xy[i * 2 + 1] = pts[i][1];
    if (i) e.cum[i] = e.cum[i - 1] + Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]);
  }
  e.L = e.cum[e.n - 1];
}

// Центростремительный сплайн Катмулла — Рома: без петель и выбросов на крутых поворотах
function catmullRom(p0, p1, p2, p3, t) {
  const d = (a, b) => Math.max(1e-4, Math.sqrt(Math.hypot(b[0] - a[0], b[1] - a[1])));
  const t0 = 0, t1 = d(p0, p1), t2 = t1 + d(p1, p2), t3 = t2 + d(p2, p3);
  const tt = t1 + (t2 - t1) * t;
  const L = (a, b, ta, tb) => { const k = (tt - ta) / (tb - ta); return [a[0] + (b[0] - a[0]) * k, a[1] + (b[1] - a[1]) * k]; };
  const A1 = L(p0, p1, t0, t1), A2 = L(p1, p2, t1, t2), A3 = L(p2, p3, t2, t3);
  return L(L(A1, A2, t0, t2), L(A2, A3, t1, t3), t1, t2);
}

function resample(pts, step) {
  const out = [[pts[0][0], pts[0][1]]];
  let acc = 0, prev = pts[0];
  for (let i = 1; i < pts.length; i++) {
    const cur = pts[i];
    let seg = Math.hypot(cur[0] - prev[0], cur[1] - prev[1]);
    while (acc + seg >= step && seg > 1e-9) {
      const k = (step - acc) / seg;
      const p = [prev[0] + (cur[0] - prev[0]) * k, prev[1] + (cur[1] - prev[1]) * k];
      out.push(p);
      prev = p;
      seg = Math.hypot(cur[0] - prev[0], cur[1] - prev[1]);
      acc = 0;
    }
    acc += seg;
    prev = cur;
  }
  const end = pts[pts.length - 1];
  if (out.length > 1 && acc < step * 0.35) out[out.length - 1] = [end[0], end[1]];
  else out.push([end[0], end[1]]);
  return out;
}

function smooth(p) {
  if (p.length < 3) return p;
  const out = [p[0]];
  for (let i = 1; i < p.length - 1; i++) out.push([(p[i - 1][0] + 2 * p[i][0] + p[i + 1][0]) / 4, (p[i - 1][1] + 2 * p[i][1] + p[i + 1][1]) / 4]);
  out.push(p[p.length - 1]);
  return out;
}

// Дуглас — Пекер: дрожь руки убирается, плавный изгиб остаётся
function simplify(p, tol) {
  if (p.length < 3) return p.slice();
  const keep = new Uint8Array(p.length);
  keep[0] = keep[p.length - 1] = 1;
  const stack = [[0, p.length - 1]];
  while (stack.length) {
    const [a, b] = stack.pop();
    let best = -1, bd = tol;
    for (let i = a + 1; i < b; i++) {
      const d = segDist(p[i][0], p[i][1], p[a][0], p[a][1], p[b][0], p[b][1]);
      if (d > bd) { bd = d; best = i; }
    }
    if (best > 0) { keep[best] = 1; stack.push([a, best], [best, b]); }
  }
  return p.filter((_, i) => keep[i]);
}

// Опорные точки куска улицы от s0 до s1: примерно через клетку — сплайн через них повторит изгиб
function controlFrom(e, s0, s1) {
  const R = (s) => { const p = Roads.pointAt(e, s); return [p.x, p.y]; };
  const out = [R(s0)];
  const n = Math.max(0, Math.round((s1 - s0) / 1.0) - 1);
  if (n > 0) for (let k = 1; k <= n; k++) out.push(R(s0 + (s1 - s0) * k / (n + 1)));
  out.push(R(s1));
  return out;
}

// Деревья и кусты под новой улицей убираются
function clearNatureAlong(e) {
  for (const k of e.cover) {
    const [tx, ty] = k.split(',').map(Number);
    if (rawNatureAt(tx, ty)) state.cleared.add(k);
    Engine.natureChanged(tx, ty);
  }
}
