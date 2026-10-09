'use strict';
/* 3D-модели. Всё собирается кодом: стены с цоколем и карнизом, объёмные окна со ставнями,
   черепичные крыши с рёбрами, каннелированные колонны, пышные деревья.
   Единица длины — одна клетка. Фасад здания смотрит на +Z (юг), движок поворачивает его к дороге. */

const PAL = {
  plaster: ['#f3e8cf', '#efd3a0', '#f0c3a8', '#f6f1e6', '#f2de9e', '#e6b493', '#dfe3cf'],
  roof: ['#c9643a', '#be5734', '#d27346'],
  thatch: '#d9b965', thatchDark: '#b99a4c', mud: '#cfb187',
  wood: '#9a6b44', woodDark: '#6e4a2f', woodLight: '#c49a6c',
  stone: '#d8d0bf', stoneDark: '#b7ad99', stoneLight: '#ebe5d7',
  marble: '#f7f4ed', marbleShade: '#e6dfd2',
  door: '#7a4e30', doorDark: '#4e3322', frame: '#ece3cf',
  shutter: ['#6d8f5a', '#4f7a8a', '#8a5a3a', '#a1453a', '#5d6f9a'],
  awning: ['#b8452f', '#3d7487', '#c58b2c', '#5f7a33', '#8a4a7a'],
  leaf: '#5d8f45', leafDark: '#467536', leafLight: '#80b25a', olive: '#97a86a', oliveDark: '#7d8e55',
  hedge: '#4f8040', cypress: '#3c6838', cypressLight: '#558a49',
  water: '#5fb3d3',
  gold: '#e3b445', bronze: '#9a7038', brick: '#b5654a', brickDark: '#9a5039', brickLight: '#c97b5c',
  dirt: '#c2a275', paving: '#e6dcc6', pavingDark: '#d3c6a8', sand: '#e8d6a6',
  soil: '#8a6646', wheat: '#e4c45c', wheatGreen: '#a9c36a', grape: '#6a3d78', fabric: '#f6eedc',
  red: '#a8362a', iron: '#7a6a62', rust: '#9a5a3c',
  flowers: ['#e8505b', '#f6c344', '#f08ab8', '#9b6bd1', '#ffffff', '#ff8c42'],
  laundry: ['#f4f0e6', '#c9d8e8', '#e8b9a0', '#d8d07a', '#b8c9a0'],
};

const _lin = new Map();
function lin(hex) {
  let c = _lin.get(hex);
  if (!c) { const col = new THREE.Color(hex); c = [col.r, col.g, col.b]; _lin.set(hex, c); }
  return c;
}
function shadeHex(hex, k) {
  const c = new THREE.Color(hex);
  c.multiplyScalar(k);
  return '#' + c.getHexString();
}

/* ---------- Сборщик геометрии ---------- */

// Облегчённые модели для дальнего обзора (Engine.updateLod): окна плоские, мелкие украшения не ставятся.
// Случайные числа расходуются как в полной модели (лишнее просто не рисуется — mute), поэтому цвета стен
// и огни в окнах у обеих моделей одинаковые и при смене ничего не «перещёлкивается»
let MODEL_LOD = false;
const LOD_PROP_MIN = 0.15;  // украшения ниже этого (в клетках: ящики, мешки, корзинки) в облегчённой модели не ставятся

class MB {
  constructor(seed) {
    this.buckets = { solid: { p: [], c: [] }, glow: { p: [], c: [] }, win: { p: [], c: [] } };
    this.bucket = 'solid';
    this.seed = (Math.abs(seed | 0) % 2147483646) + 1;
  }
  set glow(v) { this.bucket = v ? 'glow' : 'solid'; }
  get pos() { return this.buckets.solid.p; }
  get col() { return this.buckets.solid.c; }
  rand() { this.seed = (this.seed * 16807) % 2147483647; return (this.seed - 1) / 2147483646; }

  v(p, c) {
    if (this.mute) return;
    const B = this.buckets[this.bucket];
    B.p.push(p[0], p[1], p[2]); B.c.push(c[0], c[1], c[2]);
  }
  tri(a, b, c, ca, cb, cc) { this.v(a, ca); this.v(b, cb || ca); this.v(c, cc || ca); }

  // a, d — нижние вершины (их можно затемнить: «мягкая тень у земли»)
  quad(a, b, c, d, col, ao, jitter) {
    const j = 1 + (this.rand() - 0.5) * (jitter === undefined ? 0.05 : jitter);
    const c1 = [col[0] * j, col[1] * j, col[2] * j];
    const c0 = ao ? [c1[0] * ao, c1[1] * ao, c1[2] * ao] : c1;
    this.tri(a, b, c, c0, c1, c1);
    this.tri(a, c, d, c0, c1, c0);
  }

  box(x0, y0, z0, x1, y1, z1, color, o) {
    o = o || {};
    const c = lin(color), t = o.top ? lin(o.top) : c;
    const ao = o.ao === undefined ? (y0 < 0.05 ? 0.74 : 0.9) : o.ao;
    this.quad([x1, y0, z1], [x1, y1, z1], [x0, y1, z1], [x0, y0, z1], c, ao);
    this.quad([x0, y0, z0], [x0, y1, z0], [x1, y1, z0], [x1, y0, z0], c, ao);
    this.quad([x1, y0, z0], [x1, y1, z0], [x1, y1, z1], [x1, y0, z1], c, ao);
    this.quad([x0, y0, z1], [x0, y1, z1], [x0, y1, z0], [x0, y0, z0], c, ao);
    if (o.noTop !== true) this.quad([x0, y1, z0], [x0, y1, z1], [x1, y1, z1], [x1, y1, z0], t, 0, 0.03);
    if (o.bottom) this.quad([x0, y0, z0], [x1, y0, z0], [x1, y0, z1], [x0, y0, z1], c, 0);
  }

  // Коробка, выступающая из стены: face — какая стена, u — вдоль стены, depth — насколько выступает
  faceBox(face, plane, u0, u1, y0, y1, d, color, o) {
    if (face === 'z+') this.box(u0, y0, plane, u1, y1, plane + d, color, o);
    else if (face === 'z-') this.box(u0, y0, plane - d, u1, y1, plane, color, o);
    else if (face === 'x+') this.box(plane, y0, u0, plane + d, y1, u1, color, o);
    else this.box(plane - d, y0, u0, plane, y1, u1, color, o);
  }

  // Стена-коробка с цоколем внизу и карнизом наверху
  wall(x0, y0, z0, x1, y1, z1, color, o) {
    o = o || {};
    this.box(x0, y0, z0, x1, y1, z1, color);
    if (o.plinth !== false && y0 < 0.06) this.box(x0 - 0.018, y0, z0 - 0.018, x1 + 0.018, y0 + 0.075, z1 + 0.018, o.plinthColor || shadeHex(color, 0.84));
    if (o.cornice !== false) this.box(x0 - 0.035, y1 - 0.04, z0 - 0.035, x1 + 0.035, y1, z1 + 0.035, o.corniceColor || '#f0e8d8', { ao: 0.95 });
    if (o.band) this.box(x0 - 0.02, o.band - 0.025, z0 - 0.02, x1 + 0.02, o.band, z1 + 0.02, o.corniceColor || '#f0e8d8', { ao: 0.95 });
  }

  plate(x0, z0, x1, z1, y, color) { this.box(x0, 0, z0, x1, y, z1, color, { ao: 0.9 }); }

  // Неровное пятно земли, песка или камня вместо квадратной подложки: волнистый край и тонкий бортик.
  // Верх — чуть выше мостовой, чтобы пятно было видно и на площади
  patch(cx, cz, rx, rz, y, color, o) {
    o = o || {};
    const n = o.segs || 22, c = lin(color), j = o.jitter === undefined ? 0.1 : o.jitter;
    const ph = this.rand() * 6.28, k1 = 2 + Math.floor(this.rand() * 3), pts = [];
    for (let i = 0; i < n; i++) {
      const a = i / n * Math.PI * 2;
      const r = 1 + j * (Math.sin(a * k1 + ph) * 0.6 + (this.rand() - 0.5) * 0.7);
      pts.push([cx + Math.cos(a) * rx * r, cz + Math.sin(a) * rz * r]);
    }
    for (let i = 0; i < n; i++) {
      const p = pts[i], q = pts[(i + 1) % n];
      this.tri([cx, y, cz], [p[0], y, p[1]], [q[0], y, q[1]], c);
      this.quad([q[0], 0, q[1]], [q[0], y, q[1]], [p[0], y, p[1]], [p[0], 0, p[1]], c, 0.8, 0.02);
    }
  }

  cyl(cx, y0, cz, r, h, color, o) {
    o = o || {};
    const n = o.segs || 8, rt = o.rTop === undefined ? r : o.rTop;
    const c = lin(color), ao = o.ao === undefined ? (y0 < 0.05 ? 0.78 : 0.92) : o.ao;
    const cap = o.cap ? lin(o.cap) : c;
    const ph = o.phase || 0, sz = o.sz || 1, fl = o.flute || 0;
    const R = (i, base) => (fl && i % 2 ? base * (1 - fl) : base);
    for (let i = 0; i < n; i++) {
      const t0 = ph + i / n * Math.PI * 2, t1 = ph + (i + 1) / n * Math.PI * 2;
      const r0 = R(i, r), r1 = R(i + 1, r), q0r = R(i, rt), q1r = R(i + 1, rt);
      const p0 = [cx + Math.cos(t0) * r0, y0, cz + Math.sin(t0) * r0 * sz];
      const p1 = [cx + Math.cos(t1) * r1, y0, cz + Math.sin(t1) * r1 * sz];
      const q0 = [cx + Math.cos(t0) * q0r, y0 + h, cz + Math.sin(t0) * q0r * sz];
      const q1 = [cx + Math.cos(t1) * q1r, y0 + h, cz + Math.sin(t1) * q1r * sz];
      this.quad(p1, q1, q0, p0, c, ao, 0.03);
      if (rt > 0 && o.top !== false) this.tri([cx, y0 + h, cz], q0, q1, cap);
      if (o.bottom) this.tri([cx, y0, cz], p1, p0, c);
    }
  }

  cone(cx, y0, cz, r, h, color, segs) { this.cyl(cx, y0, cz, r, h, color, { rTop: 0, segs: segs || 8, top: false }); }

  // «Комок» листвы или камень: икосаэдр с неровностями (detail 1 — в 4 раза глаже)
  blob(cx, cy, cz, rx, ry, rz, color, o) {
    o = o || {};
    const t = (1 + Math.sqrt(5)) / 2;
    let V = [[-1, t, 0], [1, t, 0], [-1, -t, 0], [1, -t, 0], [0, -1, t], [0, 1, t], [0, -1, -t], [0, 1, -t], [t, 0, -1], [t, 0, 1], [-t, 0, -1], [-t, 0, 1]]
      .map(v => { const l = Math.hypot(...v); return [v[0] / l, v[1] / l, v[2] / l]; });
    let F = [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
      [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]];
    for (let d = 0; d < (o.detail || 0); d++) {
      const mid = new Map();
      const m = (a, b) => {
        const k = a < b ? a + '_' + b : b + '_' + a;
        if (!mid.has(k)) {
          const p = [(V[a][0] + V[b][0]) / 2, (V[a][1] + V[b][1]) / 2, (V[a][2] + V[b][2]) / 2];
          const l = Math.hypot(...p);
          V.push([p[0] / l, p[1] / l, p[2] / l]);
          mid.set(k, V.length - 1);
        }
        return mid.get(k);
      };
      const F2 = [];
      for (const [a, b, c] of F) { const ab = m(a, b), bc = m(b, c), ca = m(c, a); F2.push([a, ab, ca], [b, bc, ab], [c, ca, bc], [ab, bc, ca]); }
      F = F2;
    }
    const jit = o.jitter === undefined ? 0.16 : o.jitter;
    const P = V.map(v => {
      const k = 1 + (this.rand() - 0.5) * jit * 2;
      return [cx + v[0] * rx * k, cy + v[1] * ry * k, cz + v[2] * rz * k];
    });
    const base = lin(color), top = o.top ? lin(o.top) : null;
    const flat = o.flatBottom === undefined ? true : o.flatBottom;
    for (const [a, b, c] of F) {
      const pa = P[a].slice(), pb = P[b].slice(), pc = P[c].slice();
      if (flat) for (const p of [pa, pb, pc]) p[1] = Math.max(p[1], cy - ry * 0.55);
      const j = 1 + (this.rand() - 0.5) * 0.1;
      const yy = ((pa[1] + pb[1] + pc[1]) / 3 - cy) / ry;
      const up = 0.86 + clamp(yy, -1, 1) * 0.16;
      let cc = [base[0] * j * up, base[1] * j * up, base[2] * j * up];
      if (top && yy > 0.35) cc = [top[0] * j, top[1] * j, top[2] * j];
      this.tri(pa, pb, pc, cc);
    }
  }

  // Купол (полусфера, можно вытянуть по высоте), с рёбрами
  dome(cx, y0, cz, r, h, color, segs, ribs) {
    const n = segs || 16, rings = 7, c = lin(color);
    for (let i = 0; i < rings; i++) {
      const a0 = i / rings * Math.PI / 2, a1 = (i + 1) / rings * Math.PI / 2;
      const r0 = Math.cos(a0) * r, r1 = Math.cos(a1) * r, y_0 = y0 + Math.sin(a0) * h, y_1 = y0 + Math.sin(a1) * h;
      for (let k = 0; k < n; k++) {
        const t0 = k / n * Math.PI * 2, t1 = (k + 1) / n * Math.PI * 2;
        const p00 = [cx + Math.cos(t0) * r0, y_0, cz + Math.sin(t0) * r0], p01 = [cx + Math.cos(t1) * r0, y_0, cz + Math.sin(t1) * r0];
        const p10 = [cx + Math.cos(t0) * r1, y_1, cz + Math.sin(t0) * r1], p11 = [cx + Math.cos(t1) * r1, y_1, cz + Math.sin(t1) * r1];
        const l = (0.88 + 0.12 * (i / rings)) * (ribs && k % 2 ? 0.94 : 1);
        this.quad(p01, p11, p10, p00, [c[0] * l, c[1] * l, c[2] * l], 0, 0.02);
      }
    }
  }

  // Рёбра черепицы (имбрексы) и толщина края крыши
  ridgeLine(a, b, n, color) {
    const hh = 0.026, w = 0.026;
    const d = [b[0] - a[0], b[1] - a[1], b[2] - a[2]];
    let s = [d[1] * n[2] - d[2] * n[1], d[2] * n[0] - d[0] * n[2], d[0] * n[1] - d[1] * n[0]];
    const sl = Math.hypot(...s) || 1;
    s = [s[0] / sl * w, s[1] / sl * w, s[2] / sl * w];
    const up = [n[0] * hh, n[1] * hh, n[2] * hh];
    const add = (p, q) => [p[0] + q[0], p[1] + q[1], p[2] + q[2]];
    const sub = (p, q) => [p[0] - q[0], p[1] - q[1], p[2] - q[2]];
    const c = lin(color);
    this.quad(sub(a, s), add(a, up), add(b, up), sub(b, s), c, 0.85, 0.02);
    this.quad(add(a, up), add(a, s), add(b, s), add(b, up), [c[0] * 0.86, c[1] * 0.86, c[2] * 0.86], 0, 0.02);
  }

  fascia(a, b, color) {
    const c = lin(color), t = 0.045;
    this.quad([a[0], a[1] - t, a[2]], a, b, [b[0], b[1] - t, b[2]], c, 0, 0.02);
  }

  /* Двускатная крыша: конёк вдоль оси axis ('x' или 'z'), ряды черепицы и рёбра */
  gable(x0, z0, x1, z1, y, h, color, o) {
    o = o || {};
    const ov = o.over === undefined ? 0.09 : o.over;
    const axis = o.axis || ((x1 - x0) >= (z1 - z0) ? 'x' : 'z');
    const c = lin(color), c2 = lin(shadeHex(color, 0.9)), end = lin(o.end || PAL.plaster[0]);
    const rc = shadeHex(color, 1.08), fc = shadeHex(color, 0.7);
    const eo = o.endOver === undefined ? 0.05 : o.endOver;
    const ridges = o.ridges !== false;
    if (axis === 'x') {
      const zm = (z0 + z1) / 2, X0 = x0 - eo, X1 = x1 + eo;
      const n = Math.max(2, Math.round((X1 - X0) * 8));
      const D = z1 + ov - zm, L = Math.hypot(D, h);
      const nS = [0, D / L, h / L], nN = [0, D / L, -h / L];
      for (let i = 0; i < n; i++) {
        const a = X0 + (X1 - X0) * i / n, b = X0 + (X1 - X0) * (i + 1) / n, col = i % 2 ? c2 : c;
        this.quad([b, y, z1 + ov], [b, y + h, zm], [a, y + h, zm], [a, y, z1 + ov], col, 0.82, 0.02);
        this.quad([a, y, z0 - ov], [a, y + h, zm], [b, y + h, zm], [b, y, z0 - ov], col, 0.82, 0.02);
        if (ridges && i > 0) {
          this.ridgeLine([a, y, z1 + ov], [a, y + h, zm], nS, rc);
          this.ridgeLine([a, y, z0 - ov], [a, y + h, zm], nN, rc);
        }
      }
      const hy = y + h * ((zm - z0) / (zm - z0 + ov));
      this.tri([x0, y, z0], [x0, y, z1], [x0, hy, zm], end);
      this.tri([x1, y, z1], [x1, y, z0], [x1, hy, zm], end);
      this.fascia([X0, y, z1 + ov], [X1, y, z1 + ov], fc);
      this.fascia([X1, y, z0 - ov], [X0, y, z0 - ov], fc);
      this.box(X0, y + h - 0.03, zm - 0.04, X1, y + h + 0.04, zm + 0.04, shadeHex(color, 0.82), { ao: 1 });
    } else {
      const xm = (x0 + x1) / 2, Z0 = z0 - eo, Z1 = z1 + eo;
      const n = Math.max(2, Math.round((Z1 - Z0) * 8));
      const L = Math.hypot(x1 + ov - xm, h);
      const nE = [h / L, (x1 + ov - xm) / L, 0], nW = [-h / L, (x1 + ov - xm) / L, 0];
      for (let i = 0; i < n; i++) {
        const a = Z0 + (Z1 - Z0) * i / n, b = Z0 + (Z1 - Z0) * (i + 1) / n, col = i % 2 ? c2 : c;
        this.quad([x1 + ov, y, a], [xm, y + h, a], [xm, y + h, b], [x1 + ov, y, b], col, 0.82, 0.02);
        this.quad([x0 - ov, y, b], [xm, y + h, b], [xm, y + h, a], [x0 - ov, y, a], col, 0.82, 0.02);
        if (ridges && i > 0) {
          this.ridgeLine([x1 + ov, y, a], [xm, y + h, a], nE, rc);
          this.ridgeLine([x0 - ov, y, a], [xm, y + h, a], nW, rc);
        }
      }
      const hy = y + h * ((xm - x0) / (xm - x0 + ov));
      this.tri([x0, y, z1], [x1, y, z1], [xm, hy, z1], end);
      this.tri([x1, y, z0], [x0, y, z0], [xm, hy, z0], end);
      this.fascia([x1 + ov, y, Z1], [x1 + ov, y, Z0], fc);
      this.fascia([x0 - ov, y, Z0], [x0 - ov, y, Z1], fc);
      this.box(xm - 0.04, y + h - 0.03, Z0, xm + 0.04, y + h + 0.04, Z1, shadeHex(color, 0.82), { ao: 1 });
    }
  }

  /* Вальмовая (четырёхскатная) крыша с рёбрами черепицы */
  hip(x0, z0, x1, z1, y, h, color, o) {
    o = o || {};
    const ov = o.over === undefined ? 0.09 : o.over;
    x0 -= ov; z0 -= ov; x1 += ov; z1 += ov;
    const W = x1 - x0, D = z1 - z0, s = Math.min(W, D) / 2;
    const c = lin(color), c2 = lin(shadeHex(color, 0.9));
    const rc = shadeHex(color, 1.08), fc = shadeHex(color, 0.7);
    const ridges = o.ridges !== false;
    const slope = (E, e, nIn, L) => {
      const strips = Math.max(2, Math.round(L * 8));
      const pt = (u) => {
        const m = Math.min(u, L - u, s);
        return [E[0] + e[0] * u + nIn[0] * m, y + h * m / s, E[2] + e[2] * u + nIn[2] * m];
      };
      const nl = Math.hypot(h, s);
      const n = [-nIn[0] * h / nl, s / nl, -nIn[2] * h / nl];
      for (let i = 0; i < strips; i++) {
        const u0 = L * i / strips, u1 = L * (i + 1) / strips, col = i % 2 ? c2 : c;
        const a = [E[0] + e[0] * u0, y, E[2] + e[2] * u0], d = [E[0] + e[0] * u1, y, E[2] + e[2] * u1];
        this.quad(a, pt(u0), pt(u1), d, col, 0.82, 0.02);
        if (ridges && i > 0) {
          const m = Math.min(u0, L - u0, s);
          if (m > 0.05) this.ridgeLine(a, pt(u0), n, rc);
        }
      }
      this.fascia(E, [E[0] + e[0] * L, y, E[2] + e[2] * L], fc);
    };
    slope([x0, y, z1], [1, 0, 0], [0, 0, -1], W);
    slope([x1, y, z0], [-1, 0, 0], [0, 0, 1], W);
    slope([x1, y, z1], [0, 0, -1], [-1, 0, 0], D);
    slope([x0, y, z0], [0, 0, 1], [1, 0, 0], D);
    const rcap = shadeHex(color, 0.82);
    if (W > D) this.box(x0 + s, y + h - 0.025, z0 + s - 0.04, x1 - s, y + h + 0.04, z0 + s + 0.04, rcap, { ao: 1 });
    else if (D > W) this.box(x0 + s - 0.04, y + h - 0.025, z0 + s, x0 + s + 0.04, y + h + 0.04, z1 - s, rcap, { ao: 1 });
    if (o.finial) this.blob(x0 + W / 2, y + h + 0.06, z0 + D / 2, 0.05, 0.05, 0.05, PAL.gold, { jitter: 0, detail: 1 });
  }

  // Плоский прямоугольник на стене. face: 'z+', 'z-', 'x+', 'x-'; u — вдоль стены
  rect(face, plane, u0, u1, y0, y1, color, e) {
    const c = lin(color);
    e = e || 0.006;
    if (face === 'z+') this.quad([u1, y0, plane + e], [u1, y1, plane + e], [u0, y1, plane + e], [u0, y0, plane + e], c, 0, 0.02);
    else if (face === 'z-') this.quad([u0, y0, plane - e], [u0, y1, plane - e], [u1, y1, plane - e], [u1, y0, plane - e], c, 0, 0.02);
    else if (face === 'x+') this.quad([plane + e, y0, u0], [plane + e, y1, u0], [plane + e, y1, u1], [plane + e, y0, u1], c, 0, 0.02);
    else this.quad([plane - e, y0, u1], [plane - e, y1, u1], [plane - e, y1, u0], [plane - e, y0, u0], c, 0, 0.02);
  }

  // Арка (проём с полукруглым верхом) на стене
  arch(face, plane, uc, w, y0, h, color, e) {
    const c = lin(color), r = w / 2, ys = y0 + h - r;
    e = e || 0.007;
    const pts = [[uc - r, y0], [uc + r, y0]];
    for (let i = 0; i <= 8; i++) { const t = i / 8 * Math.PI; pts.push([uc + Math.cos(t) * r, ys + Math.sin(t) * r]); }
    const to3 = ([u, yy]) => face === 'z+' ? [u, yy, plane + e] : face === 'z-' ? [u, yy, plane - e] : face === 'x+' ? [plane + e, yy, u] : [plane - e, yy, u];
    const ctr = to3([uc, y0 + (h - r) * 0.6]);
    for (let i = 0; i < pts.length; i++) this.tri(ctr, to3(pts[i]), to3(pts[(i + 1) % pts.length]), c);
  }

  // Объёмное окно: стекло (ночью светится), рама, подоконник, ставни
  window(face, plane, uc, yc, w, h, shutter, o) {
    o = o || {};
    const u0 = uc - w / 2, u1 = uc + w / 2, y0 = yc - h / 2, y1 = yc + h / 2;
    const prev = this.bucket;
    this.bucket = 'win';
    this.rect(face, plane, u0, u1, y0, y1, this.rand() < 0.6 ? '#ffc070' : '#0b0b12');
    this.bucket = prev;
    const fc = o.frame || PAL.frame, t = 0.018;
    if (MODEL_LOD) {
      // издалека: ставни — плоскими прямоугольниками, рамы, подоконник и цветы не рисуются (но случайные числа идут как обычно)
      const sd = this.seed;
      if (shutter) { this.rect(face, plane, u0 - t - w * 0.5, u0 - t, y0, y1, shutter, 0.012); this.rect(face, plane, u1 + t, u1 + t + w * 0.5, y0, y1, shutter, 0.012); }
      this.seed = sd;
      this.mute = true;
    }
    this.rect(face, plane, uc - 0.006, uc + 0.006, y0, y1, fc, 0.009);
    this.faceBox(face, plane, u0 - t, u1 + t, y1, y1 + t * 1.6, 0.022, fc);
    this.faceBox(face, plane, u0 - t, u0, y0, y1, 0.018, fc, { noTop: true });
    this.faceBox(face, plane, u1, u1 + t, y0, y1, 0.018, fc, { noTop: true });
    this.faceBox(face, plane, u0 - t * 1.8, u1 + t * 1.8, y0 - 0.024, y0, 0.05, o.sill || '#ddd3bf');
    if (shutter) {
      this.faceBox(face, plane, u0 - t - w * 0.5, u0 - t, y0, y1, 0.012, shutter);
      this.faceBox(face, plane, u1 + t, u1 + t + w * 0.5, y0, y1, 0.012, shutter);
    }
    if (o.flowers) {
      this.faceBox(face, plane, u0 - 0.01, u1 + 0.01, y0 - 0.075, y0 - 0.024, 0.06, PAL.brickLight);
      for (let i = 0; i < 3; i++) {
        const u = u0 + (u1 - u0) * (i + 0.5) / 3, out = 0.045;
        const p = face === 'z+' ? [u, y0 - 0.01, plane + out] : face === 'z-' ? [u, y0 - 0.01, plane - out] : face === 'x+' ? [plane + out, y0 - 0.01, u] : [plane - out, y0 - 0.01, u];
        this.blob(p[0], p[1], p[2], 0.035, 0.03, 0.035, i % 2 ? PAL.leaf : PAL.flowers[(i + (o.seed || 0)) % 6], { jitter: 0.2 });
      }
    }
    this.mute = false;
  }

  // Дверь: каменное обрамление, деревянное полотно, ступенька
  door(face, plane, uc, w, h, o) {
    o = o || {};
    this.arch(face, plane, uc, w + 0.07, 0.02, h + 0.045, o.frame || '#e3d7bd', 0.006);
    this.arch(face, plane, uc, w, 0.02, h, o.color || PAL.door, 0.01);
    this.rect(face, plane, uc - 0.004, uc + 0.004, 0.03, h - w / 2, PAL.doorDark, 0.012);
    this.faceBox(face, plane, uc - w / 2 - 0.05, uc + w / 2 + 0.05, 0, 0.048, 0.08, PAL.stoneLight);
  }

  build(ox, oz) {
    const make = (B) => {
      if (!B.p.length) return null;
      const pos = B.p;
      for (let i = 0; i < pos.length; i += 3) { pos[i] -= ox; pos[i + 2] -= oz; }
      const g = new THREE.BufferGeometry();
      g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
      g.setAttribute('color', new THREE.Float32BufferAttribute(B.c, 3));
      g.computeVertexNormals();
      g.computeBoundingSphere();
      return g;
    };
    return { solid: make(this.buckets.solid), glow: make(this.buckets.glow), win: make(this.buckets.win) };
  }
}

/* ---------- Общие детали ---------- */

function windowRow(mb, face, plane, a0, a1, n, yc, w, h, shutter, o) {
  for (let i = 0; i < n; i++) mb.window(face, plane, a0 + (a1 - a0) * (i + 0.5) / n, yc, w, h, shutter, o);
}

function windowsAround(mb, x0, z0, x1, z1, yc, spacing, w, h, shutter, skipFront, o) {
  const nx = Math.max(1, Math.round((x1 - x0) / spacing)), nz = Math.max(1, Math.round((z1 - z0) / spacing));
  if (!skipFront) windowRow(mb, 'z+', z1, x0 + 0.06, x1 - 0.06, nx, yc, w, h, shutter, o);
  windowRow(mb, 'z-', z0, x0 + 0.06, x1 - 0.06, nx, yc, w, h, shutter, o);
  windowRow(mb, 'x+', x1, z0 + 0.06, z1 - 0.06, nz, yc, w, h, shutter, o);
  windowRow(mb, 'x-', x0, z0 + 0.06, z1 - 0.06, nz, yc, w, h, shutter, o);
}

// Каннелированная колонна с базой и капителью
function column(mb, x, z, y0, h, r, color) {
  const c = color || PAL.marble;
  mb.box(x - r * 1.5, y0, z - r * 1.5, x + r * 1.5, y0 + 0.028, z + r * 1.5, c, { ao: 0.9 });
  mb.cyl(x, y0 + 0.028, z, r * 1.3, 0.03, c, { segs: 12, rTop: r * 1.08, ao: 0.95 });
  mb.cyl(x, y0 + 0.058, z, r, h - 0.13, c, { segs: 16, flute: 0.12, rTop: r * 0.88, ao: 0.95 });
  mb.cyl(x, y0 + h - 0.072, z, r * 0.9, 0.04, c, { segs: 12, rTop: r * 1.35, ao: 1 });
  mb.box(x - r * 1.55, y0 + h - 0.032, z - r * 1.55, x + r * 1.55, y0 + h, z + r * 1.55, c, { ao: 1 });
}

function awning(mb, face, plane, a0, a1, y, depth, color) {
  const n = 6;
  for (let i = 0; i < n; i++) {
    const u0 = a0 + (a1 - a0) * i / n, u1 = a0 + (a1 - a0) * (i + 1) / n;
    const col = lin(i % 2 ? PAL.fabric : color);
    if (face === 'z+') mb.quad([u1, y - 0.11, plane + depth], [u1, y, plane], [u0, y, plane], [u0, y - 0.11, plane + depth], col, 0);
    else if (face === 'x+') mb.quad([plane + depth, y - 0.11, u0], [plane, y, u0], [plane, y, u1], [plane + depth, y - 0.11, u1], col, 0);
    else if (face === 'z-') mb.quad([u0, y - 0.11, plane - depth], [u0, y, plane], [u1, y, plane], [u1, y - 0.11, plane - depth], col, 0);
    else mb.quad([plane - depth, y - 0.11, u1], [plane, y, u1], [plane, y, u0], [plane - depth, y - 0.11, u0], col, 0);
  }
  // фестоны по краю
  for (let i = 0; i < n; i++) {
    const u = a0 + (a1 - a0) * (i + 0.5) / n, col = i % 2 ? PAL.fabric : color;
    if (face === 'z+') mb.box(u - (a1 - a0) / n / 2, y - 0.15, plane + depth - 0.005, u + (a1 - a0) / n / 2, y - 0.11, plane + depth, col, { ao: 1 });
    else if (face === 'x+') mb.box(plane + depth - 0.005, y - 0.15, u - (a1 - a0) / n / 2, plane + depth, y - 0.11, u + (a1 - a0) / n / 2, col, { ao: 1 });
  }
}

function pot(mb, x, z, s, flower, y) {
  y = y || 0;
  mb.cyl(x, y, z, 0.05 * s, 0.08 * s, PAL.brickLight, { segs: 8, rTop: 0.065 * s });
  mb.blob(x, y + 0.12 * s, z, 0.075 * s, 0.065 * s, 0.075 * s, PAL.leaf, { jitter: 0.2, detail: 1 });
  if (flower) for (let i = 0; i < 3; i++) mb.blob(x + (i - 1) * 0.03 * s, y + 0.17 * s, z + ((i % 2) - 0.5) * 0.03 * s, 0.025 * s, 0.025 * s, 0.025 * s, flower, { jitter: 0.1 });
}

function amphora(mb, x, z, s, color, y) {
  s = s || 1; y = y || 0;
  const c = color || PAL.brickLight;
  mb.cyl(x, y, z, 0.02 * s, 0.03 * s, c, { segs: 8, rTop: 0.055 * s });
  mb.cyl(x, y + 0.03 * s, z, 0.055 * s, 0.05 * s, c, { segs: 8, rTop: 0.065 * s });
  mb.cyl(x, y + 0.08 * s, z, 0.065 * s, 0.06 * s, c, { segs: 8, rTop: 0.03 * s });
  mb.cyl(x, y + 0.14 * s, z, 0.022 * s, 0.05 * s, c, { segs: 6, rTop: 0.028 * s });
}

function crate(mb, x, z, s, y) {
  y = y || 0;
  mb.box(x - 0.06 * s, y, z - 0.06 * s, x + 0.06 * s, y + 0.11 * s, z + 0.06 * s, PAL.woodLight);
  mb.box(x - 0.062 * s, y + 0.045 * s, z - 0.062 * s, x + 0.062 * s, y + 0.06 * s, z + 0.062 * s, PAL.wood, { ao: 1 });
}

function fence(mb, x0, z0, x1, z1, color) {
  const len = Math.hypot(x1 - x0, z1 - z0), n = Math.max(2, Math.round(len / 0.16));
  for (let i = 0; i <= n; i++) {
    const t = i / n, x = x0 + (x1 - x0) * t, z = z0 + (z1 - z0) * t;
    mb.box(x - 0.014, 0, z - 0.014, x + 0.014, 0.17, z + 0.014, color || PAL.wood, { ao: 0.85 });
  }
  if (Math.abs(x1 - x0) > Math.abs(z1 - z0)) { mb.box(Math.min(x0, x1), 0.11, z0 - 0.009, Math.max(x0, x1), 0.135, z0 + 0.009, color || PAL.wood, { ao: 1 }); mb.box(Math.min(x0, x1), 0.05, z0 - 0.009, Math.max(x0, x1), 0.07, z0 + 0.009, color || PAL.wood, { ao: 1 }); }
  else { mb.box(x0 - 0.009, 0.11, Math.min(z0, z1), x0 + 0.009, 0.135, Math.max(z0, z1), color || PAL.wood, { ao: 1 }); mb.box(x0 - 0.009, 0.05, Math.min(z0, z1), x0 + 0.009, 0.07, Math.max(z0, z1), color || PAL.wood, { ao: 1 }); }
}

function lowWall(mb, x0, z0, x1, z1, h, color) {
  mb.box(Math.min(x0, x1) - 0.03, 0, Math.min(z0, z1) - 0.03, Math.max(x0, x1) + 0.03, h, Math.max(z0, z1) + 0.03, color, { top: shadeHex(color, 1.06) });
  mb.box(Math.min(x0, x1) - 0.04, h, Math.min(z0, z1) - 0.04, Math.max(x0, x1) + 0.04, h + 0.025, Math.max(z0, z1) + 0.04, PAL.stoneLight, { ao: 1 });
}

function hedge(mb, x0, z0, x1, z1, h) {
  mb.box(x0, 0, z0, x1, h, z1, PAL.hedge, { top: shadeHex(PAL.hedge, 1.15), ao: 0.7 });
}

// Бельевая верёвка с бельём между двумя точками
function laundry(mb, a, b, seed) {
  const n = 5;
  const dx = b[0] - a[0], dz = b[2] - a[2], len = Math.hypot(dx, dz);
  const ux = dx / len, uz = dz / len, w = 0.008;
  for (let i = 0; i < 8; i++) {
    const t0 = i / 8, t1 = (i + 1) / 8;
    const sag = (t) => -Math.sin(t * Math.PI) * 0.05;
    const p0 = [a[0] + dx * t0, a[1] + sag(t0), a[2] + dz * t0], p1 = [a[0] + dx * t1, a[1] + sag(t1), a[2] + dz * t1];
    mb.quad([p0[0] - uz * w, p0[1], p0[2] + ux * w], [p0[0], p0[1] + w, p0[2]], [p1[0], p1[1] + w, p1[2]], [p1[0] - uz * w, p1[1], p1[2] + ux * w], lin('#8a7a6a'), 0);
  }
  for (let i = 0; i < n; i++) {
    const t = (i + 0.7) / (n + 0.4), cw = 0.05 + ((seed + i) % 3) * 0.015, ch = 0.07 + ((seed + i) % 2) * 0.04;
    const p = [a[0] + dx * t, a[1] - Math.sin(t * Math.PI) * 0.05, a[2] + dz * t];
    const col = lin(PAL.laundry[(seed + i) % PAL.laundry.length]);
    mb.quad([p[0] - ux * cw, p[1] - ch, p[2] - uz * cw], [p[0] - ux * cw, p[1], p[2] - uz * cw], [p[0] + ux * cw, p[1], p[2] + uz * cw], [p[0] + ux * cw, p[1] - ch, p[2] + uz * cw], col, 0);
  }
}

/* ---------- Украшения домов: вьюны, фонари, кашпо, угловая кладка ---------- */

// Точка на стене: face — какая стена, plane — её координата, u — вдоль стены, out — насколько от стены
function wallPoint(face, plane, u, y, out) {
  if (face === 'z+') return [u, y, plane + out];
  if (face === 'z-') return [u, y, plane - out];
  if (face === 'x+') return [plane + out, y, u];
  return [plane - out, y, u];
}

// Вьюн, ползущий по стене, с цветами (как бугенвиллея на средиземноморских домах)
function ivy(mb, face, plane, u, y0, y1, flowerColor, width) {
  const w = width || 0.16;
  const steps = Math.max(2, Math.round((y1 - y0) / 0.06));
  for (let i = 0; i <= steps; i++) {
    const y = y0 + (y1 - y0) * i / steps;
    const spread = w * (0.5 + 0.5 * Math.sin(i * 1.7 + u * 9));
    for (let k = 0; k < 2; k++) {
      const uu = u + (k ? 1 : -1) * spread * (0.3 + mb.rand() * 0.4);
      const p = wallPoint(face, plane, uu, y, 0.022);
      mb.blob(p[0], p[1], p[2], 0.04, 0.035, 0.04, i % 3 ? PAL.leaf : PAL.leafDark, { jitter: 0.25 });
      if (flowerColor && mb.rand() < 0.45) {
        const q = wallPoint(face, plane, uu + 0.02, y + 0.015, 0.045);
        mb.blob(q[0], q[1], q[2], 0.022, 0.022, 0.022, flowerColor, { jitter: 0.1 });
      }
    }
  }
  const b = wallPoint(face, plane, u, y0, 0.03);
  mb.cyl(b[0], 0, b[2], 0.05, 0.06, PAL.brickLight, { segs: 6, rTop: 0.06 });
}

// Настенный фонарь: кронштейн и фонарик, который ночью светится
function lantern(mb, face, plane, u, y) {
  const a = wallPoint(face, plane, u, y, 0), b = wallPoint(face, plane, u, y, 0.08);
  mb.box(Math.min(a[0], b[0]) - 0.008, y - 0.008, Math.min(a[2], b[2]) - 0.008, Math.max(a[0], b[0]) + 0.008, y + 0.008, Math.max(a[2], b[2]) + 0.008, PAL.woodDark, { ao: 1 });
  const c = wallPoint(face, plane, u, y, 0.08);
  mb.box(c[0] - 0.026, y - 0.075, c[2] - 0.026, c[0] + 0.026, y - 0.068, c[2] + 0.026, PAL.bronze, { ao: 1 });
  mb.box(c[0] - 0.03, y - 0.012, c[2] - 0.03, c[0] + 0.03, y, c[2] + 0.03, PAL.bronze, { ao: 1 });
  mb.glow = true;
  mb.box(c[0] - 0.02, y - 0.068, c[2] - 0.02, c[0] + 0.02, y - 0.012, c[2] + 0.02, '#ffcf6a', { ao: 1 });
  mb.glow = false;
}

// Висячий горшок с ниспадающей зеленью
function hangingPlant(mb, x, y, z, flower) {
  mb.box(x - 0.003, y, z - 0.003, x + 0.003, y + 0.08, z + 0.003, '#6a5a4a', { ao: 1 });
  mb.cyl(x, y - 0.05, z, 0.03, 0.05, PAL.brickLight, { segs: 8, rTop: 0.042 });
  mb.blob(x, y - 0.03, z, 0.055, 0.05, 0.055, PAL.leaf, { jitter: 0.25 });
  for (let i = 0; i < 3; i++) mb.blob(x + (i - 1) * 0.03, y - 0.08 - i * 0.012, z + ((i % 2) - 0.5) * 0.03, 0.022, 0.04, 0.022, PAL.leafDark, { jitter: 0.2 });
  if (flower) mb.blob(x, y + 0.005, z, 0.022, 0.02, 0.022, flower, { jitter: 0.1 });
}

// Каменное кашпо с цветами
function planter(mb, x, z, w, d, flower) {
  mb.box(x - w / 2, 0, z - d / 2, x + w / 2, 0.09, z + d / 2, PAL.stone, { top: PAL.soil });
  mb.box(x - w / 2 - 0.01, 0.08, z - d / 2 - 0.01, x + w / 2 + 0.01, 0.1, z + d / 2 + 0.01, PAL.stoneLight, { ao: 1 });
  const n = Math.max(2, Math.round(w / 0.07));
  for (let i = 0; i < n; i++) {
    const px = x - w / 2 + (i + 0.5) * w / n;
    mb.blob(px, 0.13, z, 0.04, 0.04, Math.min(0.04, d / 2), PAL.leaf, { jitter: 0.2 });
    if (i % 2 === 0) mb.blob(px, 0.17, z, 0.024, 0.022, 0.024, flower, { jitter: 0.1 });
  }
}

// Угловая каменная кладка на высоких домах
function quoins(mb, x0, z0, x1, z1, y0, y1, color) {
  const n = Math.round((y1 - y0) / 0.09);
  for (let i = 0; i < n; i++) {
    const ya = y0 + i * (y1 - y0) / n + 0.006, yb = ya + (y1 - y0) / n - 0.012;
    const long = i % 2 ? 0.1 : 0.06, e = 0.008;
    for (const [cx, cz, sx, sz] of [[x0, z0, 1, 1], [x1, z0, -1, 1], [x0, z1, 1, -1], [x1, z1, -1, -1]]) {
      const ox = -sx * e, oz = -sz * e;
      mb.box(Math.min(cx, cx + sx * long), ya, Math.min(cz, cz + oz), Math.max(cx, cx + sx * long), yb, Math.max(cz, cz + oz), color, { ao: 1 });
      mb.box(Math.min(cx, cx + ox), ya, Math.min(cz, cz + sz * long), Math.max(cx, cx + ox), yb, Math.max(cz, cz + sz * long), color, { ao: 1 });
    }
  }
}

function chickens(mb, x, z, n) {
  for (let i = 0; i < n; i++) {
    const cx = x + Math.cos(i * 2.3) * 0.15, cz = z + Math.sin(i * 2.3) * 0.12;
    mb.blob(cx, 0.045, cz, 0.04, 0.035, 0.03, i % 3 ? '#f4efe4' : '#b8784a', { jitter: 0.05 });
    mb.blob(cx + 0.03, 0.08, cz, 0.018, 0.02, 0.016, i % 3 ? '#f4efe4' : '#b8784a', { jitter: 0.05 });
    mb.box(cx + 0.034, 0.095, cz - 0.004, cx + 0.042, 0.105, cz + 0.004, '#c0392b', { ao: 1 });
  }
}

/* ---------- Деревья ---------- */

function treeOak(mb, x, z, s, d) {
  d = d === undefined ? 1 : d;
  mb.cyl(x, 0, z, 0.055 * s, 0.34 * s, '#7b5a3b', { segs: 6, rTop: 0.035 * s });
  mb.cyl(x + 0.03 * s, 0.22 * s, z, 0.022 * s, 0.16 * s, '#7b5a3b', { segs: 5, rTop: 0.012 * s });
  const blobs = [[-0.12, 0.45, 0.05, 0.21, PAL.leafDark], [0.12, 0.47, -0.06, 0.21, PAL.leaf], [0.02, 0.5, 0.14, 0.19, PAL.leaf],
    [-0.02, 0.62, -0.03, 0.22, PAL.leafLight], [0.1, 0.7, 0.06, 0.13, '#93c26a']];
  for (const [bx, by, bz, r, c] of blobs) mb.blob(x + bx * s, by * s, z + bz * s, r * s, r * 0.85 * s, r * s, c, { detail: d, jitter: 0.12 });
}

function treePine(mb, x, z, s, d) {
  d = d === undefined ? 1 : d;
  mb.cyl(x, 0, z, 0.04 * s, 0.4 * s, '#6d4c33', { segs: 6, rTop: 0.03 * s });
  mb.cyl(x + 0.01 * s, 0.38 * s, z, 0.03 * s, 0.36 * s, '#6d4c33', { segs: 6, rTop: 0.022 * s, phase: 0.2 });
  mb.blob(x + 0.03 * s, 0.78 * s, z, 0.36 * s, 0.1 * s, 0.33 * s, PAL.leafDark, { jitter: 0.12, detail: d });
  mb.blob(x - 0.08 * s, 0.84 * s, z + 0.06 * s, 0.24 * s, 0.08 * s, 0.22 * s, PAL.leaf, { jitter: 0.12, detail: d });
  mb.blob(x + 0.1 * s, 0.86 * s, z - 0.05 * s, 0.2 * s, 0.07 * s, 0.2 * s, PAL.leafLight, { jitter: 0.12, detail: d });
}

function treeCypress(mb, x, z, s, d) {
  d = d === undefined ? 1 : d;
  mb.cyl(x, 0, z, 0.03 * s, 0.1 * s, '#6d4c33', { segs: 5 });
  mb.blob(x, 0.36 * s, z, 0.13 * s, 0.3 * s, 0.13 * s, PAL.cypress, { jitter: 0.1, detail: d });
  mb.blob(x, 0.66 * s, z, 0.11 * s, 0.28 * s, 0.11 * s, PAL.cypress, { jitter: 0.1, detail: d });
  mb.blob(x - 0.02 * s, 0.6 * s, z + 0.04 * s, 0.07 * s, 0.3 * s, 0.07 * s, PAL.cypressLight, { jitter: 0.1, detail: d });
  mb.blob(x, 0.9 * s, z, 0.06 * s, 0.14 * s, 0.06 * s, PAL.cypressLight, { jitter: 0.1, detail: d });
}

function treeOlive(mb, x, z, s, d) {
  d = d === undefined ? 1 : d;
  mb.cyl(x, 0, z, 0.05 * s, 0.12 * s, '#7a5d40', { segs: 6, rTop: 0.04 * s });
  mb.cyl(x + 0.02 * s, 0.12 * s, z, 0.04 * s, 0.12 * s, '#7a5d40', { segs: 6, rTop: 0.03 * s, phase: 0.4 });
  mb.blob(x - 0.09 * s, 0.32 * s, z, 0.16 * s, 0.11 * s, 0.16 * s, PAL.oliveDark, { detail: d });
  mb.blob(x + 0.09 * s, 0.34 * s, z + 0.04 * s, 0.15 * s, 0.11 * s, 0.15 * s, PAL.olive, { detail: d });
  mb.blob(x, 0.43 * s, z - 0.05 * s, 0.14 * s, 0.1 * s, 0.14 * s, '#b1bc82', { detail: d });
}

function bush(mb, x, z, s, color, d) {
  mb.blob(x, 0.08 * s, z, 0.14 * s, 0.11 * s, 0.14 * s, color || PAL.leaf, { detail: d === undefined ? 1 : d, top: shadeHex(color || PAL.leaf, 1.2) });
}

function rocks(mb, x, z, s, color, n, seedish) {
  for (let i = 0; i < n; i++) {
    const a = (i / n) * Math.PI * 2 + seedish, r = i ? 0.22 * s : 0;
    mb.blob(x + Math.cos(a) * r, 0.06 * s, z + Math.sin(a) * r, (0.17 - i * 0.02) * s, (0.14 - i * 0.015) * s, (0.16 - i * 0.02) * s, color, { jitter: 0.3, top: shadeHex(color, 1.12) });
  }
}

/* ---------- Природа: заготовки для «инстансинга» (одна модель на тысячи копий) ---------- */

const NATURE_KINDS = {
  [N_OAK]: { variants: 3, mat: 'tree', build: (mb, v) => treeOak(mb, 0, 0, 1.15 + v * 0.08) },
  [N_PINE]: { variants: 3, mat: 'tree', build: (mb, v) => treePine(mb, 0, 0, 1.1 + v * 0.08) },
  [N_CYPRESS]: { variants: 2, mat: 'tree', build: (mb, v) => treeCypress(mb, 0, 0, 1.05 + v * 0.1) },
  [N_BUSH]: { variants: 2, mat: 'tree', build: (mb, v) => { bush(mb, 0, 0, 1.2); bush(mb, 0.12, 0.08, 0.8, v ? '#6a9a4a' : PAL.leafDark); } },
  [N_ROCK]: { variants: 2, mat: 'rock', build: (mb, v) => rocks(mb, 0, 0, 0.8, '#b4ad9f', 2, v) },
  [N_STONE]: { variants: 2, mat: 'rock', build: (mb, v) => rocks(mb, 0, 0, 1.15, v ? '#a9a396' : '#bdb6a8', 3, v * 2) },
  [N_MARBLE]: { variants: 2, mat: 'rock', build: (mb, v) => rocks(mb, 0, 0, 1.1, v ? '#f4f2ee' : '#e6e3dc', 3, v * 2) },
  [N_IRON]: { variants: 2, mat: 'rock', build: (mb, v) => rocks(mb, 0, 0, 1.1, v ? '#8e5a40' : '#7a4f3c', 3, v * 2) },
  [N_FLOWERS]: { variants: 3, mat: 'tree', build: (mb, v) => {
    for (let i = 0; i < 6; i++) {
      const a = i * 1.9 + v, r = 0.08 + (i % 3) * 0.08;
      mb.blob(Math.cos(a) * r, 0.03, Math.sin(a) * r, 0.04, 0.035, 0.04, PAL.leaf, { jitter: 0.2 });
      mb.blob(Math.cos(a) * r, 0.07, Math.sin(a) * r, 0.025, 0.022, 0.025, PAL.flowers[(i + v * 2) % 6], { jitter: 0.1 });
    }
  } },
  grass: { variants: 2, mat: 'tree', build: (mb, v) => {
    const cs = [lin('#7fa64e'), lin('#8db35a'), lin('#9cc064')];
    for (let b = 0; b < 7; b++) {
      const a = b * 2.4 + v, r = 0.04 + (b % 3) * 0.03, x = Math.cos(a) * r, z = Math.sin(a) * r;
      const h = 0.1 + ((b + v) % 4) * 0.03;
      mb.tri([x - 0.018, 0, z], [x + 0.018, 0, z], [x + Math.cos(a) * 0.04, h, z + Math.sin(a) * 0.04], cs[b % 3]);
    }
  } },
};

function natureGeometry(kind, v) {
  const mb = new MB(101 + String(kind).length * 7 + v * 31 + (typeof kind === 'number' ? kind * 13 : 5));
  NATURE_KINDS[kind].build(mb, v);
  return mb.build(0, 0).solid;
}

/* ---------- Жилые дома плебеев (2×2) ---------- */

// Двор у дома: неровное пятно утоптанной земли, а не квадрат; у каменных домов — без двора (стоят прямо на мостовой)
function houseLot(mb, color) { if (color !== PAL.paving) mb.patch(1, 1, 0.9, 0.86, 0.042, color); }

function plebHouse(mb, b) {
  const t = b.tier, v = b.variant;
  const wall = PAL.plaster[b.id % PAL.plaster.length];
  const roof = PAL.roof[b.id % 3];
  const sh = PAL.shutter[b.id % PAL.shutter.length];

  if (t === 0) {
    houseLot(mb, PAL.dirt);
    for (const [x, z] of [[0.3, 0.3], [1.7, 0.3], [1.7, 1.7], [0.3, 1.7]]) mb.box(x - 0.025, 0, z - 0.025, x + 0.025, 0.3, z + 0.025, PAL.wood);
    mb.box(0.3, 0.22, 0.29, 1.7, 0.232, 0.31, '#d8c7a0', { ao: 1 });
    mb.box(0.3, 0.22, 1.69, 1.7, 0.232, 1.71, '#d8c7a0', { ao: 1 });
    for (let i = 0; i < 4; i++) mb.box(0.72, 0.025 + i * 0.03, 0.9 + (i % 2) * 0.02, 1.28, 0.05 + i * 0.03, 1.06 + (i % 2) * 0.02, i % 2 ? PAL.woodLight : PAL.wood);
    for (let i = 0; i < 5; i++) mb.box(1.32 + (i % 2) * 0.1, 0.025 + Math.floor(i / 2) * 0.06, 1.22, 1.42 + (i % 2) * 0.1, 0.08 + Math.floor(i / 2) * 0.06, 1.32, PAL.brickLight);
    rocks(mb, 0.6, 1.4, 0.4, PAL.stoneDark, 2, 1);
    return;
  }

  if (t === 1) {
    houseLot(mb, PAL.dirt);
    if (v === 2) {
      mb.cyl(1, 0.025, 1, 0.48, 0.4, PAL.mud, { segs: 14 });
      mb.cyl(1, 0.025, 1, 0.5, 0.06, shadeHex(PAL.mud, 0.85), { segs: 14 });
      mb.cone(1, 0.42, 1, 0.64, 0.58, PAL.thatch, 14);
      mb.cone(1, 0.9, 1, 0.14, 0.14, PAL.thatchDark, 8);
      mb.door('z+', 1.47, 1, 0.17, 0.27);
      fence(mb, 0.15, 1.85, 0.7, 1.85);
      bush(mb, 1.7, 1.6, 1.1);
      chickens(mb, 0.45, 0.45, 3);
    } else {
      mb.wall(0.45, 0.025, 0.5, 1.55, 0.44, 1.45, PAL.mud, { cornice: false });
      for (const [x, z] of [[0.45, 0.5], [1.55, 0.5], [0.45, 1.45], [1.55, 1.45]]) mb.box(x - 0.03, 0.025, z - 0.03, x + 0.03, 0.44, z + 0.03, PAL.woodDark);
      mb.door('z+', 1.45, 1.0, 0.17, 0.28);
      mb.window('x+', 1.55, 0.95, 0.3, 0.1, 0.09, PAL.woodLight);
      mb.hip(0.45, 0.5, 1.55, 1.45, 0.44, 0.44, PAL.thatch, { over: 0.14, ridges: false });
      if (v === 1) {
        mb.box(1.55, 0.025, 0.6, 1.92, 0.32, 1.2, PAL.woodLight);
        mb.gable(1.55, 0.6, 1.95, 1.2, 0.32, 0.13, PAL.thatch, { axis: 'z', end: PAL.woodLight, ridges: false });
        for (let i = 0; i < 4; i++) {
          mb.box(0.12 + i * 0.1, 0.025, 0.1, 0.18 + i * 0.1, 0.05, 0.42, PAL.soil);
          for (let k = 0; k < 3; k++) mb.blob(0.15 + i * 0.1, 0.07, 0.15 + k * 0.11, 0.035, 0.03, 0.035, i % 2 ? '#7aa548' : '#9cc45a', { jitter: 0.2 });
        }
      } else {
        for (let i = 0; i < 3; i++) for (let k = 0; k < 2; k++) mb.cyl(1.68 + k * 0.08, 0.06 + i * 0.065, 1.15, 0.032, 0.3, PAL.woodDark, { segs: 6, cap: '#c9a072' });
        bush(mb, 0.3, 1.7, 1.1);
        chickens(mb, 1.5, 0.3, 2);
      }
      amphora(mb, 0.35, 1.62, 1.2);
    }
    return;
  }

  if (t === 2) {
    // Домик стоит во весь участок, стена к стене с соседями, — как первый этаж будущей инсулы:
    // тот же размер и цвет, поэтому, вырастая, дом не меняется внизу, а над ним надстраивают этажи
    const x0 = 0.08, z0 = 0.15, x1 = 1.92, z1 = 1.85, f = 0.5;
    const gw = PAL.plaster[(b.id + 1) % PAL.plaster.length];
    mb.wall(x0, 0.025, z0, x1, f, z1, gw);
    if (v === 2) {
      // аркада по фасаду — потом под ней будут лавки большого дома
      for (let i = 0; i < 4; i++) mb.arch('z+', z1, x0 + 0.22 + i * 0.42, 0.26, 0.04, 0.38, '#4d3a2c');
      for (let i = 0; i < 5; i++) mb.faceBox('z+', z1, x0 + 0.01 + i * 0.42 - 0.03, x0 + 0.01 + i * 0.42 + 0.03, 0.03, 0.44, 0.03, PAL.stoneLight);
      for (let i = 0; i < 3; i++) amphora(mb, x0 + 0.35 + i * 0.42, z1 + 0.12, 1, null);
      quoins(mb, x0, z0, x1, z1, 0.07, f - 0.04, PAL.stoneLight);
    } else {
      // дверь и лавка с прилавком под полосатым навесом
      mb.door('z+', z1, x0 + 0.4, 0.2, 0.34);
      const a = x0 + 0.85;
      mb.rect('z+', z1, a, a + 0.62, 0.03, 0.36, '#4d3a2c');
      mb.faceBox('z+', z1, a + 0.04, a + 0.58, 0.03, 0.15, 0.1, PAL.wood);
      for (let i = 0; i < 4; i++) mb.blob(a + 0.11 + i * 0.13, 0.18, z1 + 0.05, 0.035, 0.03, 0.035, ['#e05a3a', '#f0c040', '#7fb24a', '#a05ac0'][(i + b.id) % 4], { jitter: 0.1 });
      awning(mb, 'z+', z1, a - 0.03, a + 0.65, 0.45, 0.24, PAL.awning[b.id % PAL.awning.length]);
      mb.window('z+', z1, x1 - 0.16, 0.3, 0.12, 0.14, sh, { flowers: true, seed: b.id });
      pot(mb, x0 + 0.16, z1 + 0.1, 1, PAL.flowers[b.id % 6]);
      lantern(mb, 'z+', z1, x0 + 0.68, 0.38);
    }
    windowRow(mb, 'x-', x0, z0 + 0.3, z1 - 0.3, 2, 0.3, 0.12, 0.14, sh);
    windowRow(mb, 'x+', x1, z0 + 0.3, z1 - 0.3, 2, 0.3, 0.12, 0.14, sh);
    windowRow(mb, 'z-', z0, x0 + 0.3, x1 - 0.3, 3, 0.3, 0.12, 0.14, sh);
    // крыша: у каждого из трёх видов своя
    if (v === 1) {
      mb.gable(x0, z0, x1, z1, f, 0.42, roof, { axis: 'x', end: gw, over: 0.08 });
      mb.box(x1 - 0.42, f + 0.12, z0 + 0.3, x1 - 0.3, f + 0.48, z0 + 0.42, PAL.brickLight);
      mb.box(x1 - 0.44, f + 0.46, z0 + 0.28, x1 - 0.28, f + 0.5, z0 + 0.44, PAL.brickDark);
    } else {
      mb.hip(x0, z0, x1, z1, f, v === 2 ? 0.32 : 0.4, roof, { over: 0.08 });
      mb.box(x0 + 0.3, f + 0.1, z0 + 0.28, x0 + 0.42, f + 0.42, z0 + 0.4, PAL.brickLight);
      mb.box(x0 + 0.28, f + 0.4, z0 + 0.26, x0 + 0.44, f + 0.44, z0 + 0.42, PAL.brickDark);
    }
    if (b.id % 2) ivy(mb, 'x-', x0, z1 - 0.16, 0.03, f - 0.04, PAL.flowers[b.id % 3 === 0 ? 2 : 0]);
    return;
  }

  if (t === 3) {
    // Инсула: лавка внизу, жильё и деревянный балкон наверху
    houseLot(mb, PAL.paving);
    const x0 = 0.08, z0 = 0.15, x1 = 1.92, z1 = 1.85, f = 0.5;
    mb.wall(x0, 0.025, z0, x1, f, z1, PAL.plaster[(b.id + 1) % PAL.plaster.length], { cornice: false });
    mb.wall(x0 + 0.02, f, z0 + 0.02, x1 - 0.02, f * 2, z1 - 0.02, wall, { plinth: false });
    mb.box(x0 - 0.03, f - 0.02, z0 - 0.03, x1 + 0.03, f + 0.02, z1 + 0.03, PAL.stoneLight, { ao: 1 });
    if (v === 2) {
      for (let i = 0; i < 4; i++) mb.arch('z+', z1, x0 + 0.22 + i * 0.42, 0.26, 0.04, 0.38, '#4d3a2c');
      for (let i = 0; i < 4; i++) mb.arch('x+', x1, z0 + 0.22 + i * 0.42, 0.26, 0.04, 0.38, '#4d3a2c');
      for (let i = 0; i < 5; i++) mb.faceBox('z+', z1, x0 + 0.01 + i * 0.42 - 0.03, x0 + 0.01 + i * 0.42 + 0.03, 0.03, 0.44, 0.03, PAL.stoneLight);
    } else {
      // лавки с прилавками
      for (const [a, k] of [[x0 + 0.12, 0], [x0 + 0.95, 1]]) {
        mb.rect('z+', z1, a, a + 0.58, 0.03, 0.36, '#4d3a2c');
        mb.faceBox('z+', z1, a + 0.04, a + 0.54, 0.03, 0.15, 0.1, PAL.wood);
        for (let i = 0; i < 4; i++) mb.blob(a + 0.1 + i * 0.12, 0.18, z1 + 0.05, 0.035, 0.03, 0.035, ['#e05a3a', '#f0c040', '#7fb24a', '#a05ac0'][(i + k + b.id) % 4], { jitter: 0.1 });
        awning(mb, 'z+', z1, a - 0.03, a + 0.61, 0.45, 0.24, PAL.awning[(b.id + k) % PAL.awning.length]);
      }
      mb.rect('x+', x1, z0 + 0.3, z0 + 0.8, 0.03, 0.36, '#4d3a2c');
      awning(mb, 'x+', x1, z0 + 0.25, z0 + 0.85, 0.45, 0.22, PAL.awning[(b.id + 2) % PAL.awning.length]);
      for (let i = 0; i < 3; i++) amphora(mb, x1 + 0.08, z0 + 1.1 + i * 0.13, 1.1);
    }
    windowsAround(mb, x0 + 0.02, z0 + 0.02, x1 - 0.02, z1 - 0.02, f + 0.25, 0.42, 0.12, 0.16, sh, false);
    // балкон
    mb.box(x0 + 0.1, f + 0.02, z1, x1 - 0.1, f + 0.05, z1 + 0.18, PAL.wood);
    for (let i = 0; i <= 10; i++) { const u = x0 + 0.1 + i * (x1 - x0 - 0.2) / 10; mb.box(u - 0.009, f + 0.05, z1 + 0.16, u + 0.009, f + 0.19, z1 + 0.18, PAL.woodDark, { ao: 1 }); }
    mb.box(x0 + 0.1, f + 0.18, z1 + 0.15, x1 - 0.1, f + 0.2, z1 + 0.185, PAL.woodDark, { ao: 1 });
    for (const u of [x0 + 0.14, x1 - 0.14]) mb.box(u - 0.015, f - 0.12, z1 + 0.15, u + 0.015, f + 0.02, z1 + 0.18, PAL.woodDark);
    pot(mb, x0 + 0.3, z1 + 0.09, 0.8, PAL.flowers[b.id % 6], f + 0.05);
    pot(mb, x1 - 0.35, z1 + 0.09, 0.8, PAL.flowers[(b.id + 3) % 6], f + 0.05);
    hangingPlant(mb, x0 + 0.55, f - 0.005, z1 + 0.13, PAL.flowers[(b.id + 1) % 6]);
    hangingPlant(mb, x1 - 0.6, f - 0.005, z1 + 0.13, PAL.flowers[(b.id + 4) % 6]);
    quoins(mb, x0 + 0.02, z0 + 0.02, x1 - 0.02, z1 - 0.02, f + 0.02, f * 2 - 0.04, PAL.stoneLight);
    lantern(mb, 'x+', x1, z0 + 1.35, 0.4);
    if (b.id % 3 !== 1) ivy(mb, 'x-', x0, z1 - 0.18, 0.03, f * 2 - 0.06, b.id % 2 ? PAL.flowers[2] : PAL.flowers[0]);
    if (v === 1) {
      mb.box(x0 + 0.02, f * 2, z0 + 0.02, x1 - 0.02, f * 2 + 0.06, z1 - 0.02, PAL.stone);
      mb.wall(x0 + 0.02, f * 2, z0 + 0.02, x0 + 0.85, f * 2 + 0.42, z0 + 0.85, wall, { plinth: false });
      mb.window('z+', z0 + 0.85, x0 + 0.43, f * 2 + 0.24, 0.12, 0.14, sh);
      mb.hip(x0 + 0.02, z0 + 0.02, x0 + 0.85, z0 + 0.85, f * 2 + 0.42, 0.28, roof);
      for (const [px, pz] of [[1.1, 1.1], [1.75, 1.1], [1.1, 1.75], [1.75, 1.75]]) mb.box(px - 0.02, f * 2 + 0.06, pz - 0.02, px + 0.02, f * 2 + 0.4, pz + 0.02, PAL.wood);
      for (let i = 0; i < 6; i++) mb.box(1.06 + i * 0.14, f * 2 + 0.38, 1.05, 1.09 + i * 0.14, f * 2 + 0.42, 1.8, PAL.woodDark, { ao: 1 });
      mb.blob(1.42, f * 2 + 0.46, 1.42, 0.36, 0.05, 0.36, PAL.leaf, { jitter: 0.35, detail: 1 });
      for (let i = 0; i < 5; i++) mb.blob(1.15 + i * 0.13, f * 2 + 0.36, 1.2 + (i % 2) * 0.4, 0.03, 0.045, 0.03, PAL.grape, { jitter: 0.1 });
      pot(mb, 1.25, 1.3, 1.1, '#f6c344', f * 2 + 0.06);
      pot(mb, 1.6, 1.6, 1.1, '#e8505b', f * 2 + 0.06);
    } else {
      mb.hip(x0 + 0.02, z0 + 0.02, x1 - 0.02, z1 - 0.02, f * 2, 0.4, roof);
    }
    return;
  }

  // t === 4 — большая инсула в четыре этажа
  houseLot(mb, PAL.paving);
  const x0 = 0.1, z0 = 0.1, x1 = 1.9, z1 = 1.9, f = 0.44;
  mb.wall(x0, 0.025, z0, x1, f, z1, PAL.plaster[(b.id + 1) % PAL.plaster.length], { cornice: false });
  for (let i = 0; i < 4; i++) mb.arch('z+', z1, x0 + 0.23 + i * 0.45, 0.27, 0.04, 0.35, '#4d3a2c');
  for (let i = 0; i < 4; i++) mb.arch('x+', x1, z0 + 0.23 + i * 0.45, 0.27, 0.04, 0.35, '#4d3a2c');
  for (let i = 0; i < 5; i++) mb.faceBox('z+', z1, x0 + 0.005 + i * 0.4475 - 0.03, x0 + 0.005 + i * 0.4475 + 0.03, 0.03, 0.42, 0.03, PAL.stoneLight);
  awning(mb, 'z+', z1, x0 + 0.08, x0 + 0.84, 0.42, 0.24, PAL.awning[b.id % PAL.awning.length]);
  awning(mb, 'x+', x1, z0 + 0.95, z0 + 1.7, 0.42, 0.24, PAL.awning[(b.id + 1) % PAL.awning.length]);
  const floors = v === 1 ? 3 : 4;
  for (let k = 1; k < floors; k++) {
    const inset = v === 2 && k === floors - 1 ? 0.2 : 0.02;
    const c = k % 2 ? wall : shadeHex(wall, 0.96);
    mb.wall(x0 + inset, f * k, z0 + inset, x1 - inset, f * (k + 1), z1 - inset, c, { plinth: false, cornice: false });
    windowsAround(mb, x0 + inset, z0 + inset, x1 - inset, z1 - inset, f * k + 0.23, 0.36, 0.11, 0.16, k <= 2 ? sh : null, false, k === 1 ? { flowers: true, seed: b.id + k } : null);
    mb.box(x0 + inset - 0.03, f * k - 0.02, z0 + inset - 0.03, x1 - inset + 0.03, f * k + 0.015, z1 - inset + 0.03, PAL.stoneLight, { ao: 1 });
  }
  // балконы и бельё
  for (const k of [1, 2]) {
    mb.box(x0 + 0.3, f * k + 0.015, z1, x1 - 0.3, f * k + 0.045, z1 + 0.17, PAL.wood);
    for (let i = 0; i <= 8; i++) { const u = x0 + 0.3 + i * (x1 - x0 - 0.6) / 8; mb.box(u - 0.008, f * k + 0.045, z1 + 0.15, u + 0.008, f * k + 0.16, z1 + 0.17, PAL.woodDark, { ao: 1 }); }
    mb.box(x0 + 0.3, f * k + 0.15, z1 + 0.14, x1 - 0.3, f * k + 0.17, z1 + 0.175, PAL.woodDark, { ao: 1 });
    pot(mb, x0 + 0.45, z1 + 0.08, 0.7, PAL.flowers[(b.id + k) % 6], f * k + 0.045);
    pot(mb, x1 - 0.45, z1 + 0.08, 0.7, PAL.flowers[(b.id + k + 2) % 6], f * k + 0.045);
  }
  laundry(mb, [x0 + 0.12, f * 2 + 0.36, z1 + 0.25], [x1 - 0.12, f * 2 + 0.36, z1 + 0.25], b.id);
  mb.box(x0 + 0.1, f * 2 + 0.2, z1, x0 + 0.13, f * 2 + 0.4, z1 + 0.28, PAL.woodDark);
  mb.box(x1 - 0.13, f * 2 + 0.2, z1, x1 - 0.1, f * 2 + 0.4, z1 + 0.28, PAL.woodDark);
  quoins(mb, x0 + 0.02, z0 + 0.02, x1 - 0.02, z1 - 0.02, f + 0.02, f * (v === 2 ? floors - 1 : floors) - 0.03, PAL.stoneLight);
  for (const k of [1, 2]) hangingPlant(mb, x0 + 0.5 + (k - 1) * 0.8, f * k + 0.01, z1 + 0.12, PAL.flowers[(b.id + k) % 6]);
  for (const i of [1, 3]) lantern(mb, 'z+', z1 + 0.03, x0 + 0.005 + i * 0.4475, 0.4);
  ivy(mb, 'x-', x0 + 0.02, z1 - 0.22, 0.03, f * 2.7, PAL.flowers[b.id % 2 ? 2 : 0], 0.2);
  const top = f * floors;
  if (v === 1) {
    mb.gable(x0 + 0.02, z0 + 0.02, x1 - 0.02, z1 - 0.02, top, 0.44, roof, { axis: 'x', end: wall });
  } else {
    const inset = v === 2 ? 0.2 : 0.02;
    mb.hip(x0 + inset, z0 + inset, x1 - inset, z1 - inset, top, 0.38, roof);
    if (v === 2) {
      mb.box(x0, top - 0.02, z0, x1, top + 0.02, z1, PAL.stone);
      for (let i = 0; i < 4; i++) pot(mb, x0 + 0.1 + i * 0.55, z1 - 0.08, 0.9, PAL.flowers[(b.id + i) % 6], top + 0.02);
    }
  }
}

/* ---------- Дома патрициев (3×3) ---------- */

function patricianHouse(mb, b) {
  const t = b.tier;
  const wall = PAL.plaster[(b.id + 3) % PAL.plaster.length];
  const roof = PAL.roof[b.id % 3];
  const sh = PAL.shutter[(b.id + 1) % PAL.shutter.length];

  if (t === 0) {
    mb.patch(1.5, 1.5, 1.32, 1.28, 0.042, PAL.dirt);
    for (const [x, z] of [[0.3, 0.3], [2.7, 0.3], [2.7, 2.7], [0.3, 2.7]]) mb.box(x - 0.03, 0, z - 0.03, x + 0.03, 0.32, z + 0.03, PAL.wood);
    mb.box(1.0, 0.025, 1.1, 1.5, 0.22, 1.4, PAL.marble);
    mb.box(1.6, 0.025, 1.2, 1.9, 0.15, 1.5, PAL.marbleShade);
    for (let i = 0; i < 3; i++) mb.cyl(1.2 + i * 0.12, 0.06, 1.85, 0.05, 0.6, PAL.marble, { segs: 10, phase: 0 });
    return;
  }

  if (t >= 3) mb.patch(1.5, 1.45, 1.38, 1.3, 0.042, '#b6cd86', { jitter: 0.08 });

  if (t === 1 || t === 2) {
    // домус с атриумом: четыре крыла вокруг открытого двора с бассейном
    const zf = t === 2 ? 1.55 : 0.35;
    const X0 = 0.3, X1 = 2.7, Z0 = zf, Z1 = 2.7, H = 0.64;
    mb.wall(X0, 0.025, Z1 - 0.55, X1, H, Z1, wall);
    mb.wall(X0, 0.025, Z0, X1, H, Z0 + 0.45, wall);
    mb.wall(X0, 0.025, Z0 + 0.45, X0 + 0.55, H, Z1 - 0.55, wall);
    mb.wall(X1 - 0.55, 0.025, Z0 + 0.45, X1, H, Z1 - 0.55, wall);
    mb.gable(X0, Z1 - 0.55, X1, Z1, H, 0.3, roof, { axis: 'x', end: wall });
    mb.gable(X0, Z0, X1, Z0 + 0.45, H, 0.26, roof, { axis: 'x', end: wall });
    mb.gable(X0, Z0 + 0.45, X0 + 0.55, Z1 - 0.55, H, 0.26, roof, { axis: 'z', end: wall });
    mb.gable(X1 - 0.55, Z0 + 0.45, X1, Z1 - 0.55, H, 0.26, roof, { axis: 'z', end: wall });
    mb.plate(X0 + 0.55, Z0 + 0.45, X1 - 0.55, Z1 - 0.55, 0.035, PAL.marbleShade);
    const zc = (Z0 + Z1) / 2;
    mb.box(1.26, 0.035, zc - 0.22, 1.74, 0.07, zc + 0.22, PAL.marble);
    mb.plate(1.3, zc - 0.18, 1.7, zc + 0.18, 0.06, PAL.water);
    for (const [x, z] of [[1.0, zc - 0.3], [2.0, zc - 0.3], [1.0, zc + 0.3], [2.0, zc + 0.3]]) column(mb, x, z, 0.035, 0.6, 0.032);
    // вход с колоннами
    mb.door('z+', Z1, 1.5, 0.24, 0.44, { color: '#6a4026' });
    column(mb, 1.26, Z1 + 0.12, 0.025, 0.52, 0.036);
    column(mb, 1.74, Z1 + 0.12, 0.025, 0.52, 0.036);
    mb.box(1.15, 0.52, Z1 - 0.02, 1.85, 0.58, Z1 + 0.2, PAL.marble);
    mb.gable(1.15, Z1 - 0.02, 1.85, Z1 + 0.2, 0.58, 0.14, roof, { axis: 'z', end: PAL.marble, over: 0.03, ridges: false });
    windowRow(mb, 'z+', Z1, X0 + 0.1, 1.1, 2, 0.4, 0.12, 0.15, sh, { flowers: true, seed: b.id });
    windowRow(mb, 'z+', Z1, 1.9, X1 - 0.1, 2, 0.4, 0.12, 0.15, sh, { flowers: true, seed: b.id + 1 });
    windowRow(mb, 'x+', X1, Z0 + 0.1, Z1 - 0.1, 3, 0.4, 0.12, 0.15, sh);
    windowRow(mb, 'x-', X0, Z0 + 0.1, Z1 - 0.1, 3, 0.4, 0.12, 0.15, sh);
    pot(mb, 0.45, 2.86, 1.3, PAL.flowers[b.id % 6]);
    pot(mb, 2.55, 2.86, 1.3, PAL.flowers[(b.id + 2) % 6]);
    lantern(mb, 'z+', Z1, 1.08, 0.42);
    lantern(mb, 'z+', Z1, 1.92, 0.42);
    ivy(mb, 'x+', X1, Z1 - 0.12, 0.03, H - 0.04, PAL.flowers[b.id % 2 ? 2 : 0]);
    ivy(mb, 'x-', X0, Z1 - 0.12, 0.03, H - 0.04, PAL.flowers[b.id % 2 ? 0 : 2]);
    quoins(mb, X0, Z0, X1, Z1, 0.1, H - 0.05, PAL.stoneLight);
    planter(mb, 0.75, 2.88, 0.5, 0.1, PAL.flowers[(b.id + 3) % 6]);
    planter(mb, 2.25, 2.88, 0.5, 0.1, PAL.flowers[(b.id + 4) % 6]);
    if (t === 2) {
      // перистиль: сад с колоннадой
      mb.plate(0.3, 0.3, 2.7, 1.55, 0.045, '#a8c47a');
      for (let i = 0; i <= 6; i++) {
        column(mb, 0.35 + i * 0.383, 0.35, 0.03, 0.46, 0.028);
        if (i > 0 && i < 6) continue;
        for (let k = 1; k <= 2; k++) column(mb, 0.35 + i * 0.383, 0.35 + k * 0.4, 0.03, 0.46, 0.028);
      }
      mb.box(0.3, 0.46, 0.3, 2.7, 0.51, 0.42, PAL.marble);
      mb.box(0.3, 0.46, 0.3, 0.42, 0.51, 1.55, PAL.marble);
      mb.box(2.58, 0.46, 0.3, 2.7, 0.51, 1.55, PAL.marble);
      mb.cyl(1.5, 0.03, 0.95, 0.26, 0.09, PAL.stoneLight, { segs: 16 });
      mb.cyl(1.5, 0.12, 0.95, 0.22, 0.004, PAL.water, { segs: 16 });
      mb.cyl(1.5, 0.12, 0.95, 0.03, 0.22, PAL.marble, { segs: 8 });
      mb.fountain = [[1.5, 0.36, 0.95, 0.25]];
      treeCypress(mb, 0.75, 0.8, 0.6);
      treeCypress(mb, 2.25, 0.8, 0.6);
      hedge(mb, 0.5, 1.2, 1.2, 1.32, 0.12);
      hedge(mb, 1.8, 1.2, 2.5, 1.32, 0.12);
      bush(mb, 1.0, 0.6, 0.8, PAL.flowers[0]);
      bush(mb, 2.0, 0.6, 0.8, PAL.flowers[2]);
    }
    return;
  }

  if (t === 3) {
    // вилла: двухэтажный корпус, портик, сад с бассейном
    const H1 = 0.56, H2 = 1.08;
    mb.wall(0.3, 0.025, 0.35, 2.05, H2, 1.75, wall, { band: H1 });
    mb.wall(2.05, 0.025, 0.35, 2.75, H1, 1.35, shadeHex(wall, 0.97));
    windowsAround(mb, 0.3, 0.35, 2.05, 1.75, 0.3, 0.42, 0.12, 0.17, sh, true);
    windowsAround(mb, 0.3, 0.35, 2.05, 1.75, 0.8, 0.42, 0.12, 0.17, sh, false, { flowers: true, seed: b.id });
    windowRow(mb, 'z+', 1.35, 2.15, 2.65, 2, 0.3, 0.12, 0.16, sh);
    mb.hip(0.3, 0.35, 2.05, 1.75, H2, 0.44, roof);
    mb.hip(2.05, 0.35, 2.75, 1.35, H1, 0.28, roof);
    // портик с фронтоном
    mb.box(0.55, 0.025, 1.75, 1.8, 0.09, 2.2, PAL.marble);
    mb.box(0.65, 0.025, 2.2, 1.7, 0.05, 2.32, PAL.marbleShade);
    for (let i = 0; i < 5; i++) column(mb, 0.65 + i * 0.262, 2.1, 0.09, 0.64, 0.042);
    mb.box(0.55, 0.73, 1.75, 1.8, 0.81, 2.18, PAL.marble);
    mb.gable(0.55, 1.75, 1.8, 2.18, 0.81, 0.26, roof, { axis: 'z', end: PAL.marble, over: 0.04 });
    mb.blob(1.175, 1.1, 2.2, 0.04, 0.04, 0.04, PAL.gold, { jitter: 0, detail: 1 });
    mb.door('z+', 1.75, 1.18, 0.24, 0.46, { color: '#6a4026' });
    // сад
    mb.plate(2.0, 1.6, 2.88, 2.88, 0.04, PAL.stoneLight);
    mb.plate(2.1, 1.7, 2.78, 2.78, 0.055, PAL.water);
    for (let i = 0; i < 4; i++) treeCypress(mb, 0.22 + i * 0.13, 2.62 - (i % 2) * 0.1, 0.58);
    hedge(mb, 0.15, 2.82, 1.4, 2.92, 0.13);
    bush(mb, 1.8, 2.6, 1, PAL.flowers[(b.id + 1) % 6]);
    for (const [x, z] of [[1.5, 2.5], [1.88, 2.5]]) mb.box(x, 0.025, z, x + 0.05, 0.42, z + 0.05, PAL.marble);
    for (let i = 0; i < 4; i++) mb.box(1.45 + i * 0.13, 0.42, 2.45, 1.48 + i * 0.13, 0.46, 2.9, PAL.woodDark);
    mb.blob(1.7, 0.49, 2.67, 0.3, 0.06, 0.24, PAL.leaf, { jitter: 0.3, detail: 1 });
    for (let i = 0; i < 4; i++) mb.blob(1.55 + i * 0.1, 0.4, 2.6 + (i % 2) * 0.15, 0.03, 0.045, 0.03, PAL.grape, { jitter: 0.1 });
    statueFigure(mb, 2.44, 2.24, 0.055, 0.6, PAL.marble);
    quoins(mb, 0.3, 0.35, 2.05, 1.75, 0.1, H2 - 0.05, PAL.stoneLight);
    ivy(mb, 'x-', 0.3, 1.5, 0.03, H2 - 0.06, PAL.flowers[b.id % 2 ? 2 : 0], 0.2);
    ivy(mb, 'z+', 1.35, 2.5, 0.03, H1 - 0.05, PAL.flowers[b.id % 2 ? 0 : 2]);
    for (const x of [0.58, 1.77]) lantern(mb, 'z+', 2.16, x, 0.5);
    planter(mb, 0.95, 1.95, 0.4, 0.1, PAL.flowers[(b.id + 2) % 6]);
    return;
  }

  // t === 4 — дворец
  mb.box(0.18, 0.025, 0.22, 2.82, 0.13, 2.02, PAL.marble);
  mb.wall(0.3, 0.13, 0.3, 2.7, 1.28, 1.65, wall, { band: 0.72, plinth: false });
  windowsAround(mb, 0.3, 0.3, 2.7, 1.65, 0.44, 0.34, 0.12, 0.2, null, true);
  windowsAround(mb, 0.3, 0.3, 2.7, 1.65, 1.0, 0.34, 0.12, 0.2, null, false, { flowers: true, seed: b.id });
  for (let i = 0; i < 8; i++) {
    column(mb, 0.4 + i * 0.314, 1.86, 0.13, 0.55, 0.042);
    column(mb, 0.4 + i * 0.314, 1.86, 0.74, 0.5, 0.036);
  }
  mb.box(0.28, 0.68, 1.65, 2.72, 0.74, 1.98, PAL.marble);
  for (let i = 0; i <= 20; i++) mb.box(0.3 + i * 0.12 - 0.01, 0.74, 1.94, 0.3 + i * 0.12 + 0.01, 0.86, 1.96, PAL.marble, { ao: 1 });
  mb.box(0.3, 0.84, 1.93, 2.7, 0.87, 1.97, PAL.marble, { ao: 1 });
  mb.box(0.28, 1.24, 1.65, 2.72, 1.3, 1.98, PAL.marble);
  mb.hip(0.3, 0.3, 2.7, 1.98, 1.3, 0.42, roof, { finial: true });
  mb.box(1.02, 1.3, 1.6, 1.98, 1.37, 2.02, PAL.marble);
  mb.gable(1.02, 1.6, 1.98, 2.02, 1.37, 0.36, roof, { axis: 'z', end: PAL.marble, over: 0.04 });
  mb.blob(1.5, 1.76, 2.03, 0.055, 0.055, 0.055, PAL.gold, { jitter: 0, detail: 1 });
  for (const x of [1.08, 1.92]) statueFigure(mb, x, 1.97, 1.37, 0.35, PAL.gold, true);
  mb.box(0.95, 0.025, 2.02, 2.05, 0.07, 2.62, PAL.marbleShade);
  for (let i = 0; i < 3; i++) mb.box(1.1 - i * 0.03, 0.025, 2.0 + i * 0.05, 1.9 + i * 0.03, 0.13 - i * 0.04, 2.07 + i * 0.05, PAL.marble);
  mb.door('z+', 1.65, 1.5, 0.28, 0.5, { color: '#5a3420' });
  mb.cyl(1.5, 0.025, 2.46, 0.32, 0.09, PAL.stoneLight, { segs: 18 });
  mb.cyl(1.5, 0.115, 2.46, 0.28, 0.004, PAL.water, { segs: 18 });
  mb.cyl(1.5, 0.11, 2.46, 0.04, 0.26, PAL.marble, { segs: 8 });
  mb.cyl(1.5, 0.37, 2.46, 0.1, 0.03, PAL.marble, { segs: 12, rTop: 0.13 });
  mb.fountain = [[1.5, 0.45, 2.46, 0.35]];
  statueFigure(mb, 0.52, 2.46, 0.025, 0.85, PAL.marble);
  statueFigure(mb, 2.48, 2.46, 0.025, 0.85, PAL.marble);
  for (const x of [0.16, 2.84]) for (let i = 0; i < 3; i++) treeCypress(mb, x + (x < 1 ? 0.08 : -0.08), 2.15 + i * 0.25, 0.6);
  hedge(mb, 0.3, 2.82, 0.95, 2.92, 0.14);
  hedge(mb, 2.05, 2.82, 2.7, 2.92, 0.14);
  quoins(mb, 0.3, 0.3, 2.7, 1.65, 0.16, 1.24, PAL.marble);
  for (const x of [0.36, 2.64]) ivy(mb, 'z+', 1.65, x, 0.15, 0.7, PAL.flowers[b.id % 2 ? 2 : 0]);
  for (const x of [0.98, 2.02]) lantern(mb, 'z+', 1.98, x, 0.62);
  for (const x of [0.6, 2.4]) planter(mb, x, 2.1, 0.45, 0.1, PAL.flowers[(b.id + 1) % 6]);
}

/* ---------- Статуи и украшения ---------- */

function statueFigure(mb, x, z, y0, s, color, gold) {
  const c = color || PAL.marble;
  mb.box(x - 0.1 * s, y0, z - 0.1 * s, x + 0.1 * s, y0 + 0.04 * s, z + 0.1 * s, PAL.stone);
  mb.box(x - 0.085 * s, y0 + 0.04 * s, z - 0.085 * s, x + 0.085 * s, y0 + 0.18 * s, z + 0.085 * s, PAL.stoneLight);
  mb.box(x - 0.1 * s, y0 + 0.18 * s, z - 0.1 * s, x + 0.1 * s, y0 + 0.21 * s, z + 0.1 * s, PAL.stone);
  const y = y0 + 0.21 * s;
  mb.cyl(x, y, z, 0.062 * s, 0.25 * s, c, { segs: 10, rTop: 0.046 * s, flute: 0.08 });
  mb.blob(x, y + 0.3 * s, z, 0.04 * s, 0.047 * s, 0.04 * s, gold ? PAL.gold : c, { jitter: 0.04, detail: 1 });
  mb.box(x + 0.035 * s, y + 0.15 * s, z - 0.014 * s, x + 0.058 * s, y + 0.35 * s, z + 0.014 * s, c);
  mb.box(x - 0.085 * s, y + 0.1 * s, z - 0.014 * s, x - 0.045 * s, y + 0.21 * s, z + 0.014 * s, c);
  mb.box(x - 0.07 * s, y + 0.2 * s, z - 0.03 * s, x + 0.02 * s, y + 0.23 * s, z + 0.035 * s, shadeHex(c, 0.96));
}

function decorModel(mb, b) {
  // готовые мелочи набора (если он загружен), иначе — свои простые фигуры
  const P = (name, x, z, rot, h, y) => !!mb.prop && mb.prop(name, x, y || 0, z, rot || 0, h);
  switch (b.type) {
    case 'flowers':
      mb.cyl(0.5, 0, 0.5, 0.36, 0.1, PAL.stone, { segs: 16, cap: PAL.soil });
      mb.cyl(0.5, 0.08, 0.5, 0.38, 0.03, PAL.stoneLight, { segs: 16, top: false });
      mb.cyl(0.5, 0.1, 0.5, 0.33, 0.015, PAL.soil, { segs: 16 });
      for (let i = 0; i < 14; i++) {
        const fx = 0.22 + hash2(b.id, i, 5) * 0.56, fz = 0.22 + hash2(i, b.id, 6) * 0.56;
        mb.blob(fx, 0.15, fz, 0.06, 0.05, 0.06, PAL.leaf, { jitter: 0.2, detail: 1 });
        mb.blob(fx, 0.2, fz, 0.035, 0.03, 0.035, PAL.flowers[(b.id + i) % 6], { jitter: 0.1 });
      }
      break;
    case 'cypress': treeCypress(mb, 0.5, 0.5, 1.2); break;
    case 'pine': treePine(mb, 0.5, 0.5, 1.2); break;
    case 'olive': treeOlive(mb, 0.5, 0.5, 1.25); break;
    case 'bench':
      mb.box(0.2, 0, 0.42, 0.28, 0.12, 0.58, PAL.marble);
      mb.box(0.72, 0, 0.42, 0.8, 0.12, 0.58, PAL.marble);
      mb.box(0.15, 0.12, 0.38, 0.85, 0.16, 0.62, PAL.marble);
      mb.box(0.15, 0.16, 0.38, 0.85, 0.3, 0.42, PAL.marbleShade);
      mb.box(0.12, 0, 0.36, 0.2, 0.3, 0.64, PAL.marble);
      mb.box(0.8, 0, 0.36, 0.88, 0.3, 0.64, PAL.marble);
      break;
    case 'amphorae':
      amphora(mb, 0.35, 0.4, 1.4); amphora(mb, 0.6, 0.33, 1.3, '#c98a5a'); amphora(mb, 0.5, 0.65, 1.5); amphora(mb, 0.74, 0.62, 1.1, '#b06a44');
      crate(mb, 0.25, 0.72, 1.1);
      break;
    case 'lamp':
      mb.cyl(0.5, 0, 0.5, 0.1, 0.04, PAL.bronze, { segs: 8 });
      for (let i = 0; i < 3; i++) { const a = i * 2.09; mb.box(0.5 + Math.cos(a) * 0.06 - 0.012, 0.02, 0.5 + Math.sin(a) * 0.06 - 0.012, 0.5 + Math.cos(a) * 0.06 + 0.012, 0.14, 0.5 + Math.sin(a) * 0.06 + 0.012, PAL.bronze); }
      mb.cyl(0.5, 0.04, 0.5, 0.022, 0.52, PAL.bronze, { segs: 8, flute: 0.15 });
      mb.cyl(0.5, 0.56, 0.5, 0.05, 0.07, PAL.bronze, { segs: 10, rTop: 0.11 });
      mb.glow = true;
      mb.cone(0.5, 0.63, 0.5, 0.08, 0.18, '#ffa040', 8);
      mb.cone(0.5, 0.63, 0.5, 0.045, 0.25, '#ffe08a', 8);
      mb.glow = false;
      addLight(mb, 0.5, 0.7, 0.5, 1.4);
      break;
    case 'pergola':
      for (const [x, z] of [[0.15, 0.15], [0.85, 0.15], [0.15, 0.85], [0.85, 0.85]]) column(mb, x, z, 0, 0.56, 0.03);
      for (let i = 0; i < 6; i++) mb.box(0.08 + i * 0.168 - 0.014, 0.56, 0.06, 0.08 + i * 0.168 + 0.014, 0.6, 0.94, PAL.woodDark);
      mb.box(0.06, 0.6, 0.12, 0.94, 0.63, 0.16, PAL.woodDark); mb.box(0.06, 0.6, 0.84, 0.94, 0.63, 0.88, PAL.woodDark);
      mb.blob(0.5, 0.66, 0.5, 0.46, 0.07, 0.44, PAL.leaf, { jitter: 0.35, detail: 1 });
      for (let i = 0; i < 6; i++) mb.blob(0.22 + i * 0.11, 0.53, 0.28 + (i % 2) * 0.44, 0.035, 0.05, 0.035, PAL.grape, { jitter: 0.1 });
      mb.box(0.3, 0, 0.42, 0.7, 0.13, 0.58, PAL.marble);
      break;
    case 'mosaic': {
      mb.plate(0.02, 0.02, 0.98, 0.98, 0.03, '#efe6d2');
      const cols = ['#b8452f', '#3d7487', '#d9a93a', '#5f7a33', '#2f2a26'];
      for (let i = 0; i < 6; i++) for (let k = 0; k < 6; k++) {
        const d = Math.abs(i - 2.5) + Math.abs(k - 2.5);
        if ((d + b.id) % 2 > 0.5) continue;
        mb.plate(0.07 + i * 0.145, 0.07 + k * 0.145, 0.2 + i * 0.145, 0.2 + k * 0.145, 0.036, cols[(Math.floor(d) + b.id) % 5]);
      }
      break;
    }
    // ---- свет
    case 'lantern':
      // бронзовый фонарь со стеклянными стенками на столбе с завитком
      mb.cyl(0.5, 0, 0.5, 0.07, 0.05, PAL.stoneDark, { segs: 8 });
      mb.cyl(0.5, 0.05, 0.5, 0.02, 0.6, PAL.bronze, { segs: 8, flute: 0.1 });
      mb.box(0.5, 0.62, 0.49, 0.66, 0.64, 0.51, PAL.bronze);
      mb.box(0.645, 0.58, 0.49, 0.665, 0.64, 0.51, PAL.bronze);
      mb.box(0.6, 0.555, 0.45, 0.71, 0.575, 0.55, PAL.bronze);
      mb.glow = true; mb.box(0.61, 0.46, 0.46, 0.7, 0.555, 0.54, '#ffd27a'); mb.glow = false;
      mb.box(0.6, 0.445, 0.45, 0.71, 0.46, 0.55, PAL.bronze);
      addLight(mb, 0.655, 0.5, 0.5, 1.6);
      break;
    case 'torch':
      if (!P('Floor Torch', 0.5, 0.5, 0, 0.42)) mb.cyl(0.5, 0, 0.5, 0.025, 0.4, PAL.iron, { segs: 6 });
      centerFire(mb, 0.5, 0.4, 0.5, 0.8);
      break;
    case 'bigtorch':
      // высокая бронзовая чаша на треноге
      for (let i = 0; i < 3; i++) { const a = i * 2.09; mb.box(0.5 + Math.cos(a) * 0.1 - 0.015, 0, 0.5 + Math.sin(a) * 0.1 - 0.015, 0.5 + Math.cos(a) * 0.1 + 0.015, 0.2, 0.5 + Math.sin(a) * 0.1 + 0.015, PAL.bronze); }
      mb.cyl(0.5, 0.05, 0.5, 0.035, 0.6, PAL.bronze, { segs: 8, flute: 0.15 });
      mb.cyl(0.5, 0.62, 0.5, 0.07, 0.1, PAL.bronze, { segs: 12, rTop: 0.17 });
      mb.cyl(0.5, 0.72, 0.5, 0.175, 0.025, PAL.gold, { segs: 12 });
      centerFire(mb, 0.5, 0.72, 0.5, 1.5, true);
      break;
    case 'lamps':
      addLight(mb, 0.5, 0.5, 0.5, 1.6);
      // два столба и верёвка с масляными лампами, провисающая между ними
      for (const x of [0.06, 0.94]) { mb.box(x - 0.022, 0, 0.48, x + 0.022, 0.62, 0.52, PAL.woodDark); mb.box(x - 0.04, 0.6, 0.46, x + 0.04, 0.63, 0.54, PAL.wood); }
      for (let i = 0; i < 10; i++) {
        const t0 = i / 10, t1 = (i + 1) / 10, y = t => 0.6 - Math.sin(t * Math.PI) * 0.12;
        mb.box(0.06 + t0 * 0.88, y(t0) - 0.006, 0.497, 0.06 + t1 * 0.88, y(t0) + 0.004, 0.503, '#6a5a4a', { ao: 1 });
      }
      mb.glow = true;
      for (let i = 1; i < 6; i++) { const t = i / 6, x = 0.06 + t * 0.88, y = 0.6 - Math.sin(t * Math.PI) * 0.12; mb.blob(x, y - 0.05, 0.5, 0.028, 0.034, 0.028, i % 2 ? '#ffcf70' : '#ff9a50', { jitter: 0, detail: 1 }); }
      mb.glow = false;
      break;
    case 'campfire':
      for (let i = 0; i < 8; i++) { const a = i / 8 * Math.PI * 2; mb.blob(0.5 + Math.cos(a) * 0.17, 0.035, 0.5 + Math.sin(a) * 0.17, 0.055, 0.045, 0.05, i % 2 ? PAL.stoneDark : PAL.stone, { jitter: 0.25 }); }
      for (let i = 0; i < 3; i++) { const a = i * 2.1; mb.box(0.5 + Math.cos(a) * 0.03 - 0.12, 0.03, 0.5 + Math.sin(a) * 0.03 - 0.022, 0.5 + Math.cos(a) * 0.03 + 0.12, 0.07, 0.5 + Math.sin(a) * 0.03 + 0.022, i % 2 ? PAL.woodDark : PAL.wood); }
      centerFire(mb, 0.5, 0.06, 0.5, 1.1, true);
      break;
    // ---- улица
    case 'barrels':
      if (!P('Closed Barrel', 0.38, 0.42, 0, 0.2)) mb.cyl(0.38, 0, 0.42, 0.1, 0.2, PAL.wood, { segs: 8 });
      if (!P('Closed Barrel', 0.62, 0.48, 0.6, 0.18)) mb.cyl(0.62, 0, 0.48, 0.09, 0.18, PAL.wood, { segs: 8 });
      if (!P('Opened Barrel', 0.5, 0.68, 0, 0.16)) mb.cyl(0.5, 0, 0.68, 0.085, 0.16, PAL.woodLight, { segs: 8 });
      break;
    case 'crates':
      crate(mb, 0.38, 0.45, 1.3); crate(mb, 0.62, 0.5, 1.2); crate(mb, 0.48, 0.47, 1.1, 0.14);
      break;
    case 'sacks':
      // мешки с зерном, корзина фруктов и ведро пряностей
      for (const [x, z, c] of [[0.34, 0.4, '#d8c39a'], [0.5, 0.36, '#cdb486'], [0.42, 0.56, '#d8c39a']]) {
        mb.blob(x, 0.1, z, 0.1, 0.1, 0.09, c, { jitter: 0.12 });
        mb.cyl(x, 0.18, z, 0.04, 0.05, shadeHex(c, 0.85), { segs: 6, rTop: 0.02 });
      }
      mb.cyl(0.68, 0, 0.5, 0.09, 0.09, PAL.woodLight, { segs: 10, rTop: 0.11 });
      for (let i = 0; i < 5; i++) mb.blob(0.66 + (i % 3) * 0.03, 0.11, 0.48 + Math.floor(i / 3) * 0.04, 0.035, 0.03, 0.035, ['#e05a3a', '#f0c040', '#7fb24a'][i % 3]);
      mb.cyl(0.6, 0, 0.7, 0.065, 0.1, PAL.wood, { segs: 8 });
      mb.cyl(0.6, 0.1, 0.7, 0.06, 0.012, '#c8742c', { segs: 8 });
      break;
    case 'hay':
      // тюки сена, перетянутые верёвкой
      for (const [x0, z0, x1, z1, y0, y1] of [[0.22, 0.32, 0.56, 0.58, 0, 0.18], [0.52, 0.48, 0.8, 0.72, 0, 0.16], [0.3, 0.38, 0.58, 0.6, 0.18, 0.33]]) {
        mb.box(x0, y0, z0, x1, y1, z1, PAL.thatch, { top: '#e3c977' });
        mb.box(x0 + (x1 - x0) * 0.3, y0, z0 - 0.004, x0 + (x1 - x0) * 0.3 + 0.015, y1 + 0.002, z1 + 0.004, PAL.thatchDark, { ao: 1 });
        mb.box(x0 + (x1 - x0) * 0.7, y0, z0 - 0.004, x0 + (x1 - x0) * 0.7 + 0.015, y1 + 0.002, z1 + 0.004, PAL.thatchDark, { ao: 1 });
      }
      for (let i = 0; i < 6; i++) mb.box(0.2 + i * 0.1, 0.0, 0.76 + (i % 2) * 0.04, 0.24 + i * 0.1, 0.012, 0.8 + (i % 2) * 0.04, '#e3c977', { ao: 1 });
      break;
    case 'cart':
      if (!P('Cart', 0.5, 0.5, 0, 0.42)) {
        mb.box(0.2, 0.14, 0.3, 0.8, 0.3, 0.7, PAL.wood);
        for (const z of [0.27, 0.73]) mb.cyl(0.5, 0.14, z, 0.14, 0.03, PAL.woodDark, { segs: 10 });
      }
      break;
    case 'stall':
      stall(mb, 0.15, 0.3, PAL.awning[0], 0);
      break;
    case 'banner':
      if (!P('Banner', 0.5, 0.5, 0, 0.92)) { mb.box(0.48, 0, 0.48, 0.52, 0.92, 0.52, PAL.woodDark); mb.box(0.52, 0.5, 0.49, 0.78, 0.88, 0.51, PAL.red); }
      break;
    case 'sundial':
      if (!P('Sun Clock', 0.5, 0.5, 0, 0.36)) {
        mb.cyl(0.5, 0, 0.5, 0.12, 0.28, PAL.stone, { segs: 10 });
        mb.cyl(0.5, 0.28, 0.5, 0.2, 0.04, PAL.marble, { segs: 16 });
        mb.box(0.49, 0.32, 0.4, 0.51, 0.42, 0.6, PAL.bronze);
      }
      break;
    case 'roundbench':
      if (!P('Circle bench', 0.5, 0.5, 0, 0.26)) {
        for (let i = 0; i < 12; i++) { const a = i / 12 * Math.PI * 2; mb.box(0.5 + Math.cos(a) * 0.36 - 0.06, 0, 0.5 + Math.sin(a) * 0.36 - 0.06, 0.5 + Math.cos(a) * 0.36 + 0.06, 0.12, 0.5 + Math.sin(a) * 0.36 + 0.06, PAL.stoneLight); }
        treeOlive(mb, 0.5, 0.5, 0.9);
      }
      break;
    // ---- сад
    case 'flowerbush':
      if (!P('Flower Bush', 0.5, 0.5, 0, 0.32)) { bush(mb, 0.5, 0.5, 1.2, PAL.leaf); for (let i = 0; i < 6; i++) mb.blob(0.5 + Math.cos(i) * 0.12, 0.2, 0.5 + Math.sin(i) * 0.12, 0.03, 0.03, 0.03, PAL.flowers[i % 6]); }
      break;
    case 'planter':
      // каменный вазон на ножке с подстриженным самшитом
      mb.cyl(0.5, 0, 0.5, 0.12, 0.05, PAL.stoneLight, { segs: 12 });
      mb.cyl(0.5, 0.05, 0.5, 0.06, 0.08, PAL.stone, { segs: 10 });
      mb.cyl(0.5, 0.13, 0.5, 0.12, 0.12, PAL.stoneLight, { segs: 12, rTop: 0.17 });
      mb.cyl(0.5, 0.25, 0.5, 0.175, 0.02, PAL.stone, { segs: 12 });
      mb.blob(0.5, 0.36, 0.5, 0.15, 0.14, 0.15, PAL.hedge, { jitter: 0.12, detail: 1 });
      break;
    case 'palm':
      if (!P(b.id % 2 ? 'Palm' : 'Palm.001', 0.5, 0.5, b.id * 1.3, 1.0)) { mb.cyl(0.5, 0, 0.5, 0.04, 0.9, PAL.woodDark, { segs: 6 }); for (let i = 0; i < 7; i++) { const a = i / 7 * Math.PI * 2; mb.blob(0.5 + Math.cos(a) * 0.2, 0.9, 0.5 + Math.sin(a) * 0.2, 0.22, 0.04, 0.08, PAL.leaf); } }
      break;
    case 'bigjar':
      // высокая расписная ваза на низком постаменте
      mb.cyl(0.5, 0, 0.5, 0.17, 0.08, PAL.stoneLight, { segs: 10 });
      mb.cyl(0.5, 0.08, 0.5, 0.07, 0.06, PAL.brick, { segs: 12, rTop: 0.15 });
      mb.cyl(0.5, 0.14, 0.5, 0.15, 0.16, PAL.brick, { segs: 12, rTop: 0.12 });
      mb.cyl(0.5, 0.24, 0.5, 0.152, 0.03, '#2e2420', { segs: 12 });
      mb.cyl(0.5, 0.3, 0.5, 0.12, 0.08, PAL.brick, { segs: 12, rTop: 0.06 });
      mb.cyl(0.5, 0.38, 0.5, 0.06, 0.03, PAL.brick, { segs: 10, rTop: 0.09 });
      break;
    // ---- кисти россыпью (модель — только для значка)
    case 'grovebrush':
      treeCypress(mb, 0.3, 0.35, 0.8); treePine(mb, 0.7, 0.4, 0.75); treeOlive(mb, 0.5, 0.75, 0.7);
      break;
    case 'flowerbrush':
      bush(mb, 0.3, 0.4, 1, PAL.leaf); pot(mb, 0.7, 0.35, 1.2, PAL.flowers[0]);
      for (let i = 0; i < 6; i++) mb.blob(0.35 + i * 0.07, 0.08, 0.7 + (i % 2) * 0.08, 0.04, 0.04, 0.04, PAL.flowers[i % 6]);
      break;
    // ---- на стены: стена — плоскость z = 0.44, вещь выступает к +z; высота y = 0 — там, куда указали на стене
    case 'flowerbox':
      mb.box(0.28, -0.05, 0.44, 0.72, 0.03, 0.56, PAL.brickLight);
      mb.box(0.27, 0.02, 0.43, 0.73, 0.035, 0.57, PAL.brick);
      for (let i = 0; i < 6; i++) {
        mb.blob(0.32 + i * 0.072, 0.07, 0.5, 0.045, 0.04, 0.045, i % 2 ? PAL.leaf : PAL.leafLight, { jitter: 0.25 });
        mb.blob(0.32 + i * 0.072, 0.1, 0.52, 0.025, 0.025, 0.025, PAL.flowers[(b.id + i) % 6], { jitter: 0.1 });
      }
      for (let i = 0; i < 3; i++) mb.blob(0.36 + i * 0.14, -0.08, 0.56, 0.03, 0.06, 0.02, PAL.leaf, { jitter: 0.3 });
      break;
    case 'wallawning':
      for (const x of [0.22, 0.78]) mb.box(x - 0.008, 0.02, 0.44, x + 0.008, 0.03, 0.7, PAL.woodDark);
      awning(mb, 'z+', 0.44, 0.2, 0.8, 0.12, 0.28, PAL.awning[b.id % PAL.awning.length]);
      break;
    case 'wallbanner':
      mb.box(0.3, 0.06, 0.44, 0.7, 0.085, 0.5, PAL.bronze);
      mb.box(0.33, -0.42, 0.475, 0.67, 0.06, 0.49, PAL.red, { ao: 1 });
      mb.box(0.33, -0.42, 0.474, 0.67, -0.39, 0.491, PAL.gold, { ao: 1 });
      mb.blob(0.5, -0.12, 0.492, 0.08, 0.06, 0.006, PAL.gold, { jitter: 0.1, detail: 1 });
      for (const x of [0.36, 0.5, 0.64]) mb.cone(x, -0.47, 0.482, 0.03, 0.06, PAL.gold, 4);
      break;
    case 'walllamp':
      mb.box(0.47, -0.04, 0.44, 0.53, 0.04, 0.47, PAL.iron);
      mb.box(0.49, 0.0, 0.46, 0.51, 0.02, 0.62, PAL.iron);
      mb.box(0.45, -0.1, 0.56, 0.55, -0.08, 0.66, PAL.bronze);
      mb.glow = true; mb.box(0.46, -0.08, 0.57, 0.54, 0.0, 0.65, '#ffd27a'); mb.glow = false;
      mb.cone(0.5, 0.0, 0.61, 0.07, 0.05, PAL.bronze, 4);
      addLight(mb, 0.5, -0.05, 0.75, 1.2);
      break;
    case 'ivy':
      for (let i = 0; i < 16; i++) {
        const x = 0.3 + hash2(b.id, i, 3) * 0.4, y = -0.35 + i / 16 * 0.55;
        mb.blob(x, y, 0.455, 0.06, 0.05, 0.02, i % 3 ? PAL.leaf : PAL.leafDark, { jitter: 0.3 });
      }
      for (let i = 0; i < 4; i++) mb.blob(0.35 + i * 0.1, -0.1 + (i % 2) * 0.2, 0.47, 0.018, 0.018, 0.01, PAL.flowers[b.id % 2 ? 2 : 0]);
      break;
    // ---- статуи на постаментах
    case 'bust':
      if (!(P('Statue Base.001', 0.5, 0.5, 0, 0.3) && P('Medusa Bust', 0.5, 0.5, 0, 0.22, 0.3))) statueFigure(mb, 0.5, 0.5, 0, 1.1, PAL.marble);
      break;
    case 'lion':
      if (!(P('Statue Base.002', 0.5, 0.5, 0, 0.14) && P('Lion', 0.5, 0.5, 0, 0.32, 0.14))) statueFigure(mb, 0.5, 0.5, 0, 1.2, PAL.marble);
      break;
    case 'discobolus':
    case 'hercules':
    case 'athena':
    case 'zeus': {
      const model = { discobolus: 'Discobolo', hercules: 'Hercules', athena: 'Athenea', zeus: 'Zeus' }[b.type];
      if (!(P('Statue Base', 0.5, 0.5, 0, 0.24) && P(model, 0.5, 0.5, 0, 0.62, 0.24))) statueFigure(mb, 0.5, 0.5, 0, 1.6, PAL.marble);
      break;
    }
    case 'statue': statueFigure(mb, 0.5, 0.5, 0, 1.6, PAL.marble); break;
    case 'column':
      mb.box(0.28, 0, 0.28, 0.72, 0.12, 0.72, PAL.stone);
      mb.box(0.3, 0.12, 0.3, 0.7, 0.16, 0.7, PAL.stoneLight);
      column(mb, 0.5, 0.5, 0.16, 1.2, 0.08);
      mb.blob(0.5, 1.45, 0.5, 0.09, 0.09, 0.09, PAL.gold, { jitter: 0, detail: 2 });
      break;
    case 'obelisk':
      mb.box(0.28, 0, 0.28, 0.72, 0.1, 0.72, PAL.stone);
      mb.box(0.32, 0.1, 0.32, 0.68, 0.18, 0.68, PAL.stoneLight);
      mb.cyl(0.5, 0.18, 0.5, 0.14, 1.22, '#dcc9a2', { segs: 4, rTop: 0.085, phase: Math.PI / 4 });
      mb.cyl(0.5, 1.4, 0.5, 0.085, 0.13, PAL.gold, { segs: 4, rTop: 0, phase: Math.PI / 4, top: false });
      break;
    case 'emperor':
      mb.box(0.2, 0, 0.2, 0.8, 0.08, 0.8, PAL.stone);
      mb.box(0.24, 0.08, 0.24, 0.76, 0.34, 0.76, PAL.marble);
      mb.box(0.22, 0.34, 0.22, 0.78, 0.4, 0.78, PAL.stone);
      statueFigure(mb, 0.5, 0.5, 0.4, 2.0, PAL.gold, true);
      break;
  }
}

/* ---------- Производство ---------- */

function cropRows(mb, x0, z0, x1, z1, color, height, along) {
  const n = Math.round(((along === 'x' ? z1 - z0 : x1 - x0)) / 0.18);
  const tip = shadeHex(color, 1.12);
  for (let i = 0; i < n; i++) {
    if (along === 'x') {
      const z = z0 + (i + 0.5) * (z1 - z0) / n;
      mb.box(x0, 0.03, z - 0.055, x1, 0.03 + height, z + 0.055, color, { ao: 0.7, top: tip });
    } else {
      const x = x0 + (i + 0.5) * (x1 - x0) / n;
      mb.box(x - 0.055, 0.03, z0, x + 0.055, 0.03 + height, z1, color, { ao: 0.7, top: tip });
    }
  }
}

function shed(mb, x0, z0, x1, z1, h, wall, roof, axis) {
  mb.wall(x0, 0.025, z0, x1, h, z1, wall, { cornice: false });
  mb.gable(x0, z0, x1, z1, h, 0.26, roof, { axis: axis || 'x', end: wall });
}

function smoke(mb, x, y, z) {
  mb.smoke = mb.smoke || [];
  mb.smoke.push([x, y, z]);
}

function productionModel(mb, b) {
  switch (b.type) {
    case 'farm':
      mb.plate(0.04, 0.04, 2.96, 2.96, 0.045, PAL.soil);
      cropRows(mb, 0.15, 1.15, 2.85, 2.85, PAL.wheat, 0.15, 'x');
      cropRows(mb, 1.3, 0.15, 2.85, 1.05, PAL.wheatGreen, 0.11, 'x');
      shed(mb, 0.15, 0.15, 1.1, 0.95, 0.44, PAL.woodLight, PAL.thatch, 'x');
      for (let i = 0; i < 6; i++) mb.box(0.15 + i * 0.19, 0.025, 0.94, 0.17 + i * 0.19, 0.44, 0.97, PAL.wood, { ao: 0.9 });
      mb.door('z+', 0.95, 0.62, 0.22, 0.32, { color: '#6a4a2a' });
      for (const [x, z] of [[1.22, 1.0], [0.25, 1.06], [0.4, 1.07]]) mb.cyl(x, 0.03, z, 0.085, 0.11, PAL.wheat, { segs: 10, cap: '#d8b450' });
      fence(mb, 0.06, 2.94, 2.94, 2.94);
      break;
    case 'grove':
      mb.plate(0.04, 0.04, 2.96, 2.96, 0.045, '#b9b27c');
      for (let i = 0; i < 3; i++) for (let k = 0; k < 3; k++) {
        if (i === 0 && k === 0) continue;
        treeOlive(mb, 0.5 + i * 1.0, 0.5 + k * 1.0, 1.15 + hash2(b.id, i * 3 + k, 3) * 0.25);
      }
      shed(mb, 0.15, 0.15, 0.85, 0.75, 0.36, PAL.plaster[0], PAL.roof[0]);
      for (let i = 0; i < 3; i++) amphora(mb, 0.95 + i * 0.12, 0.9, 1.2);
      lowWall(mb, 0.08, 2.92, 2.92, 2.92, 0.12, PAL.stone);
      for (let i = 0; i < 2; i++) mb.cyl(1.3 + i * 0.2, 0.03, 0.25, 0.08, 0.1, '#a0784a', { segs: 8, cap: '#5a6a2a' });
      break;
    case 'vineyard':
      mb.plate(0.04, 0.04, 2.96, 2.96, 0.045, '#a8906a');
      for (let i = 0; i < 6; i++) {
        const z = 1.0 + i * 0.32;
        for (let k = 0; k <= 5; k++) mb.box(0.2 + k * 0.52, 0.03, z - 0.015, 0.23 + k * 0.52, 0.4, z + 0.015, PAL.woodDark);
        mb.box(0.2, 0.36, z - 0.006, 2.83, 0.375, z + 0.006, '#7a6a5a', { ao: 1 });
        for (let k = 0; k < 9; k++) mb.blob(0.32 + k * 0.29, 0.31, z, 0.17, 0.1, 0.09, k % 2 ? PAL.leaf : PAL.leafLight, { jitter: 0.25, detail: 1 });
        for (let k = 0; k < 7; k++) mb.blob(0.45 + k * 0.36, 0.22, z + 0.08, 0.035, 0.055, 0.03, PAL.grape, { jitter: 0.1, detail: 1 });
      }
      shed(mb, 0.2, 0.15, 1.1, 0.8, 0.42, PAL.plaster[1], PAL.roof[1]);
      mb.door('z+', 0.8, 0.65, 0.2, 0.3);
      for (let i = 0; i < 3; i++) { mb.cyl(1.4 + i * 0.25, 0.03, 0.5, 0.1, 0.18, PAL.woodLight, { segs: 10 }); mb.cyl(1.4 + i * 0.25, 0.21, 0.5, 0.085, 0.004, PAL.grape, { segs: 10 }); }
      break;
    case 'fishery':
      mb.patch(1, 1, 0.92, 0.86, 0.042, PAL.sand);
      for (const [x, z] of [[0.35, 0.35], [1.25, 0.35], [0.35, 1.05], [1.25, 1.05]]) mb.cyl(x, 0, z, 0.035, 0.22, PAL.woodDark, { segs: 6 });
      mb.box(0.28, 0.2, 0.28, 1.32, 0.25, 1.12, PAL.wood);
      mb.wall(0.4, 0.25, 0.4, 1.2, 0.62, 1.0, PAL.woodLight, { plinth: false, cornice: false });
      for (let i = 0; i < 6; i++) mb.rect('z+', 1.0, 0.4 + i * 0.135, 0.405 + i * 0.135, 0.25, 0.62, PAL.wood);
      mb.gable(0.4, 0.4, 1.2, 1.0, 0.62, 0.3, PAL.thatch, { axis: 'x', end: PAL.woodLight, ridges: false });
      mb.door('z+', 1.0, 0.8, 0.16, 0.25);
      for (let i = 0; i < 2; i++) { const x = 1.45 + i * 0.28; mb.box(x - 0.015, 0.025, 0.35, x + 0.015, 0.5, 0.39, PAL.woodDark); }
      for (let i = 0; i < 6; i++) mb.box(1.45, 0.48 - i * 0.04, 0.368, 1.73, 0.485 - i * 0.04, 0.372, '#b8b09a', { ao: 1 });
      // лодка
      mb.cyl(1.2, 0.025, 1.55, 0.2, 0.1, PAL.wood, { segs: 10, sz: 2.6, rTop: 0.22 });
      mb.cyl(1.2, 0.03, 1.55, 0.16, 0.09, PAL.woodDark, { segs: 10, sz: 2.6 });
      mb.box(0.96, 0.08, 1.53, 1.44, 0.1, 1.57, PAL.woodLight);
      for (let i = 0; i < 4; i++) mb.blob(0.3 + i * 0.1, 0.04, 1.68, 0.05, 0.02, 0.025, '#9ab0b8', { jitter: 0.1 });
      mb.cyl(0.6, 0.025, 1.7, 0.09, 0.11, PAL.woodLight, { segs: 8, cap: '#7f9fb0' });
      break;
    case 'lumber':
      mb.patch(1, 1, 0.9, 0.86, 0.042, PAL.dirt);
      shed(mb, 0.2, 0.2, 1.1, 0.85, 0.44, PAL.woodLight, PAL.roof[2]);
      mb.door('z+', 0.85, 0.65, 0.2, 0.3, { color: '#6a4a2a' });
      for (let i = 0; i < 5; i++) {
        const row = Math.floor(i / 3), k = i % 3;
        mb.cyl(1.25 + row * 0.07 + k * 0.0, 0.07 + row * 0.12, 1.1 + k * 0.14, 0.065, 0.62, PAL.wood, { segs: 8, cap: '#d8b68a' });
      }
      for (let i = 0; i < 3; i++) mb.box(1.3, 0.025 + i * 0.03, 0.3, 1.85, 0.05 + i * 0.03, 0.45 + i * 0.05, i % 2 ? PAL.woodLight : '#d8b68a');
      mb.box(0.35, 0.025, 1.3, 0.95, 0.26, 1.36, PAL.woodDark);
      mb.box(0.4, 0.025, 1.25, 0.46, 0.22, 1.41, PAL.woodDark);
      mb.box(0.84, 0.025, 1.25, 0.9, 0.22, 1.41, PAL.woodDark);
      mb.box(0.36, 0.26, 1.29, 0.94, 0.29, 1.37, PAL.woodLight);
      for (const [x, z] of [[0.4, 1.72], [1.72, 1.78], [1.0, 1.85]]) mb.cyl(x, 0.025, z, 0.1, 0.12, '#a07a52', { segs: 9, cap: '#d8b68a' });
      mb.box(0.98, 0.15, 1.82, 1.02, 0.36, 1.86, PAL.iron);
      break;
    case 'quarry':
    case 'marblequarry': {
      const big = b.type === 'marblequarry', S = big ? 3 : 2;
      const rock = big ? '#efece4' : '#bdb6a8', rockD = big ? '#d9d3c6' : '#a39c8e', rockL = big ? '#fbf9f4' : '#d0cabd';
      mb.patch(S / 2, S / 2, S / 2 - 0.08, S / 2 - 0.12, 0.042, big ? '#e4dfd4' : '#cbc3b2');
      // скала: неровные глыбы вдоль задней стороны, сверху — светлые валуны
      const n = big ? 7 : 5;
      for (let i = 0; i < n; i++) {
        const x = 0.26 + i * (S - 0.52) / (n - 1), j = hash2(b.id, i, 9);
        mb.blob(x, 0.2, 0.36 + j * 0.12, 0.25 + j * 0.08, 0.34 + j * 0.14, 0.24, i % 2 ? rock : rockD, { jitter: 0.22, detail: 1 });
        if (i < n - 1) mb.blob(x + 0.16, 0.52 + j * 0.12, 0.28, 0.18, 0.16, 0.16, rockL, { jitter: 0.3, detail: 1 });
      }
      // ровный срез, вырубленный в скале, — две ступени
      for (let i = 0; i < 2; i++) mb.box(0.24 + i * 0.22, 0.025, 0.58, S * 0.58 - i * 0.12, 0.2 - i * 0.08, 0.84 - i * 0.04, i ? rockL : rock, { ao: 0.85 });
      // нарезанные блоки, сложенные на земле
      for (let i = 0; i < (big ? 6 : 4); i++) {
        const x = 0.3 + (i % 3) * 0.26, z = S * 0.62 + Math.floor(i / 3) * 0.26, hgt = 0.1 + (i % 2) * 0.03;
        mb.box(x - 0.1, 0.025, z - 0.08, x + 0.1, 0.025 + hgt, z + 0.08, i % 2 ? rockL : rock, { ao: 0.85 });
        if (i % 3 === 0) mb.box(x - 0.08, 0.025 + hgt, z - 0.06, x + 0.08, 0.025 + hgt + 0.09, z + 0.06, rockL, { ao: 0.85 });
      }
      // деревянный кран с колесом-топчаком
      const cx = S - 0.52, cz = S - 0.55;
      mb.box(cx - 0.03, 0.025, cz - 0.03, cx + 0.03, 0.9, cz + 0.03, PAL.wood);
      mb.box(cx - 0.45, 0.84, cz - 0.025, cx + 0.06, 0.89, cz + 0.025, PAL.wood);
      mb.box(cx - 0.2, 0.5, cz - 0.02, cx + 0.02, 0.53, cz + 0.02, PAL.woodDark);
      mb.cyl(cx + 0.2, 0.28, cz, 0.24, 0.1, PAL.woodLight, { segs: 14 });
      mb.cyl(cx + 0.2, 0.28, cz, 0.2, 0.1, PAL.woodDark, { segs: 14 });
      mb.box(cx - 0.405, 0.48, cz - 0.004, cx - 0.4, 0.84, cz + 0.004, '#5a4a3a', { ao: 1 });
      mb.box(cx - 0.48, 0.38, cz - 0.08, cx - 0.32, 0.48, cz + 0.08, rockL);
      // инструменты у скалы
      for (let i = 0; i < 3; i++) mb.box(0.2 + i * 0.05, 0.025, S - 0.35 + i * 0.03, 0.24 + i * 0.05, 0.25, S - 0.33 + i * 0.03, PAL.woodLight);
      crate(mb, S - 0.25, 0.95, 1.1);
      break;
    }
    case 'claypit':
      mb.patch(1, 1, 0.92, 0.88, 0.042, '#b88a62');
      mb.patch(0.7, 0.7, 0.5, 0.46, 0.05, '#9c6a48', { jitter: 0.15 });
      mb.patch(0.7, 0.7, 0.38, 0.34, 0.056, '#7d9fa8', { jitter: 0.12 });
      for (let i = 0; i < 6; i++) for (let k = 0; k < 2; k++) mb.box(1.35 + (i % 2) * 0.25, 0.025 + k * 0.05, 0.3 + Math.floor(i / 2) * 0.3, 1.55 + (i % 2) * 0.25, 0.07 + k * 0.05, 0.48 + Math.floor(i / 2) * 0.3, k ? '#c98a66' : PAL.brickLight);
      shed(mb, 0.25, 1.35, 1.0, 1.85, 0.34, PAL.woodLight, PAL.thatch);
      mb.box(1.3, 0.025, 1.4, 1.85, 0.2, 1.8, PAL.wood);
      break;
    case 'brickworks':
      mb.patch(1, 1, 0.9, 0.88, 0.042, PAL.dirt);
      mb.wall(0.2, 0.025, 0.2, 1.1, 0.52, 1.0, PAL.brick, { corniceColor: PAL.brickLight });
      mb.gable(0.2, 0.2, 1.1, 1.0, 0.52, 0.28, PAL.roof[1], { axis: 'x', end: PAL.brick });
      mb.door('z+', 1.0, 0.65, 0.22, 0.32);
      mb.cyl(1.45, 0.025, 0.55, 0.33, 0.26, PAL.brickDark, { segs: 14 });
      mb.dome(1.45, 0.28, 0.55, 0.33, 0.28, PAL.brickDark, 14);
      mb.arch('z+', 0.875, 1.45, 0.18, 0.02, 0.22, '#2a1a12');
      mb.glow = true;
      mb.arch('z+', 0.88, 1.45, 0.12, 0.03, 0.12, '#ff7a2a');
      mb.glow = false;
      mb.cyl(1.45, 0.48, 0.55, 0.07, 0.44, PAL.brickDark, { segs: 8 });
      smoke(mb, 1.45, 0.95, 0.55);
      for (let i = 0; i < 4; i++) for (let k = 0; k < 3; k++) mb.box(0.3 + i * 0.22, 0.025 + k * 0.07, 1.25, 0.48 + i * 0.22, 0.09 + k * 0.07, 1.6, k % 2 ? PAL.brickLight : PAL.brick);
      break;
    case 'mine':
      mb.patch(1, 1, 0.92, 0.86, 0.042, '#9a7a62');
      mb.blob(1.0, 0.15, 0.6, 0.86, 0.68, 0.52, '#8e6a54', { jitter: 0.15, detail: 1, top: '#7f9a5a' });
      mb.box(0.73, 0.025, 0.95, 0.8, 0.52, 1.02, PAL.woodDark);
      mb.box(1.2, 0.025, 0.95, 1.27, 0.52, 1.02, PAL.woodDark);
      mb.box(0.7, 0.5, 0.93, 1.3, 0.57, 1.04, PAL.woodDark);
      mb.rect('z+', 0.97, 0.8, 1.2, 0.03, 0.5, '#20160f');
      mb.glow = true; mb.rect('z+', 0.975, 0.95, 1.05, 0.25, 0.32, '#ffb050'); mb.glow = false;
      mb.box(0.85, 0.025, 1.0, 0.89, 0.035, 1.9, PAL.iron);
      mb.box(1.11, 0.025, 1.0, 1.15, 0.035, 1.9, PAL.iron);
      for (let i = 0; i < 8; i++) mb.box(0.82, 0.025, 1.05 + i * 0.11, 1.18, 0.03, 1.08 + i * 0.11, PAL.woodDark, { ao: 1 });
      mb.box(0.82, 0.06, 1.42, 1.18, 0.24, 1.7, PAL.wood);
      rocks(mb, 1.0, 1.56, 0.42, PAL.rust, 2, 2);
      rocks(mb, 1.6, 1.5, 0.7, PAL.rust, 3, 1);
      break;
    case 'smithy':
      mb.patch(1, 1.05, 0.88, 0.82, 0.042, PAL.dirt);
      mb.wall(0.2, 0.025, 0.2, 1.8, 0.56, 1.1, PAL.stone);
      mb.gable(0.2, 0.2, 1.8, 1.1, 0.56, 0.3, PAL.roof[0], { axis: 'x', end: PAL.stone });
      mb.box(1.35, 0.5, 0.35, 1.57, 1.15, 0.57, PAL.brickDark);
      mb.box(1.32, 1.12, 0.32, 1.6, 1.16, 0.6, PAL.brick);
      smoke(mb, 1.46, 1.2, 0.46);
      mb.rect('z+', 1.1, 0.4, 1.1, 0.02, 0.42, '#2a1a12');
      mb.glow = true;
      mb.rect('z+', 1.105, 0.52, 0.88, 0.05, 0.22, '#ff7a2a');
      mb.glow = false;
      for (const x of [0.25, 1.75]) mb.box(x - 0.03, 0.025, 1.6, x + 0.03, 0.46, 1.66, PAL.wood);
      mb.box(0.18, 0.46, 1.08, 1.82, 0.49, 1.72, PAL.roof[2]);
      mb.box(0.84, 0.025, 1.34, 0.96, 0.18, 1.46, PAL.iron);
      mb.box(0.76, 0.18, 1.32, 1.06, 0.23, 1.48, '#4a4442');
      for (let i = 0; i < 4; i++) mb.box(1.35 + i * 0.08, 0.025, 1.3, 1.37 + i * 0.08, 0.34, 1.32, '#d0d2d6');
      for (let i = 0; i < 2; i++) mb.cyl(0.4 + i * 0.16, 0.03, 1.42, 0.07, 0.015, '#c25a3a', { segs: 10, sz: 1 });
      mb.cyl(0.45, 0.025, 1.6, 0.12, 0.12, PAL.wood, { segs: 10, cap: '#4a6a7a' });
      break;
    case 'bakery':
      mb.wall(0.2, 0.025, 0.2, 1.3, 0.56, 1.4, PAL.plaster[1]);
      mb.hip(0.2, 0.2, 1.3, 1.4, 0.56, 0.32, PAL.roof[0]);
      mb.door('z+', 1.4, 0.75, 0.2, 0.32);
      mb.window('x-', 0.2, 0.8, 0.36, 0.12, 0.14, PAL.shutter[2]);
      awning(mb, 'z+', 1.4, 0.25, 1.25, 0.5, 0.22, '#c58b2c');
      mb.cyl(1.6, 0.025, 0.7, 0.29, 0.2, PAL.brick, { segs: 14 });
      mb.dome(1.6, 0.22, 0.7, 0.29, 0.25, PAL.brick, 14);
      mb.arch('z+', 0.985, 1.6, 0.15, 0.05, 0.17, '#2a1a12');
      mb.glow = true;
      mb.arch('z+', 0.99, 1.6, 0.1, 0.06, 0.1, '#ff9a3a');
      mb.glow = false;
      mb.cyl(1.6, 0.4, 0.6, 0.045, 0.32, PAL.brickDark, { segs: 8 });
      smoke(mb, 1.6, 0.78, 0.6);
      for (let i = 0; i < 3; i++) {
        mb.cyl(0.4 + i * 0.25, 0.025, 1.68, 0.09, 0.08, PAL.woodLight, { segs: 10 });
        for (let k = 0; k < 3; k++) mb.blob(0.37 + i * 0.25 + k * 0.03, 0.12, 1.66 + (k % 2) * 0.03, 0.04, 0.025, 0.04, '#d9a45a', { jitter: 0.1, detail: 1 });
      }
      break;
    case 'oilpress':
      mb.wall(0.2, 0.025, 0.2, 1.2, 0.52, 1.2, PAL.plaster[0]);
      mb.hip(0.2, 0.2, 1.2, 1.2, 0.52, 0.32, PAL.roof[1]);
      mb.door('z+', 1.2, 0.7, 0.2, 0.31);
      mb.window('x+', 1.2, 0.5, 0.34, 0.12, 0.13, PAL.shutter[0]);
      mb.cyl(1.55, 0.025, 0.65, 0.32, 0.17, PAL.stone, { segs: 16 });
      mb.cyl(1.55, 0.195, 0.65, 0.27, 0.004, '#9a8a3a', { segs: 16 });
      mb.cyl(1.55, 0.19, 0.65, 0.05, 0.34, PAL.wood, { segs: 8 });
      mb.cyl(1.4, 0.19, 0.65, 0.14, 0.09, PAL.stoneDark, { segs: 12, sz: 0.4 });
      mb.box(1.3, 0.48, 0.63, 1.85, 0.52, 0.67, PAL.woodDark);
      for (let i = 0; i < 6; i++) amphora(mb, 0.32 + i * 0.22, 1.58 + (i % 2) * 0.14, 1.45, i % 2 ? '#c98a5a' : PAL.brickLight);
      break;
    case 'winery':
      mb.wall(0.2, 0.025, 0.2, 1.8, 0.56, 1.1, PAL.plaster[2]);
      mb.gable(0.2, 0.2, 1.8, 1.1, 0.56, 0.3, PAL.roof[0], { axis: 'x', end: PAL.plaster[2] });
      mb.door('z+', 1.1, 1.0, 0.26, 0.38, { color: '#5a2a2a' });
      windowRow(mb, 'z+', 1.1, 0.25, 0.75, 1, 0.36, 0.12, 0.14, PAL.shutter[3]);
      windowRow(mb, 'z+', 1.1, 1.25, 1.75, 1, 0.36, 0.12, 0.14, PAL.shutter[3]);
      for (let i = 0; i < 3; i++) {
        const x = 0.4 + i * 0.4;
        mb.cyl(x, 0.14, 1.45, 0.14, 0.34, PAL.wood, { segs: 12 });
        mb.cyl(x, 0.2, 1.45, 0.145, 0.03, PAL.iron, { segs: 12, top: false });
        mb.cyl(x, 0.4, 1.45, 0.145, 0.03, PAL.iron, { segs: 12, top: false });
        mb.box(x - 0.12, 0.025, 1.4, x - 0.1, 0.14, 1.5, PAL.woodDark); mb.box(x + 0.1, 0.025, 1.4, x + 0.12, 0.14, 1.5, PAL.woodDark);
      }
      mb.cyl(1.6, 0.025, 1.5, 0.22, 0.19, PAL.woodLight, { segs: 12 });
      mb.cyl(1.6, 0.21, 1.5, 0.19, 0.004, PAL.grape, { segs: 12 });
      for (let i = 0; i < 2; i++) amphora(mb, 1.78, 0.98 + i * 0.25, 1.3, '#b06a44');
      break;
    case 'warehouse':
      mb.wall(0.15, 0.025, 0.2, 1.85, 0.64, 1.25, PAL.plaster[3]);
      mb.gable(0.15, 0.2, 1.85, 1.25, 0.64, 0.36, PAL.roof[2], { axis: 'x', end: PAL.plaster[3] });
      for (let i = 0; i < 3; i++) { mb.arch('z+', 1.25, 0.45 + i * 0.55, 0.3, 0.02, 0.46, '#e3d7bd', 0.006); mb.arch('z+', 1.25, 0.45 + i * 0.55, 0.26, 0.02, 0.42, PAL.doorDark); }
      for (let i = 0; i < 4; i++) crate(mb, 0.3 + i * 0.16, 1.55, 1.2);
      crate(mb, 0.38, 1.55, 1.2, 0.13); crate(mb, 0.54, 1.55, 1.2, 0.13);
      for (let i = 0; i < 4; i++) amphora(mb, 1.2 + (i % 2) * 0.18, 1.45 + Math.floor(i / 2) * 0.22, 1.25);
      mb.box(1.55, 0.025, 1.4, 1.85, 0.2, 1.85, PAL.wood);
      break;
  }
}

/* ---------- Службы и культура ---------- */

function stall(mb, x, z, color, k) {
  mb.box(x, 0.03, z, x + 0.7, 0.21, z + 0.4, PAL.wood);
  mb.box(x - 0.01, 0.21, z - 0.01, x + 0.71, 0.23, z + 0.41, PAL.woodLight);
  const goods = ['#e05a3a', '#f0c040', '#7fb24a', '#a05ac0', '#d9a45a'];
  for (let i = 0; i < 5; i++) mb.blob(x + 0.1 + i * 0.125, 0.27, z + 0.2, 0.045, 0.035, 0.08, goods[(k + i) % 5], { jitter: 0.1, detail: 1 });
  mb.box(x, 0.03, z + 0.38, x + 0.03, 0.5, z + 0.41, PAL.woodDark);
  mb.box(x + 0.67, 0.03, z + 0.38, x + 0.7, 0.5, z + 0.41, PAL.woodDark);
  mb.box(x, 0.03, z - 0.02, x + 0.03, 0.6, z + 0.01, PAL.woodDark);
  mb.box(x + 0.67, 0.03, z - 0.02, x + 0.7, 0.6, z + 0.01, PAL.woodDark);
  awning(mb, 'z+', z - 0.05, x - 0.05, x + 0.75, 0.6, 0.52, color);
  amphora(mb, x + 0.78, z + 0.2, 1);
}

function serviceModel(mb, b) {
  switch (b.type) {
    case 'well':
      mb.patch(0.5, 0.5, 0.42, 0.42, 0.042, PAL.paving, { jitter: 0.05 });
      mb.cyl(0.5, 0.025, 0.5, 0.25, 0.2, PAL.stone, { segs: 14, top: false });
      mb.cyl(0.5, 0.025, 0.5, 0.2, 0.19, '#2f5f78', { segs: 14 });
      mb.cyl(0.5, 0.2, 0.5, 0.27, 0.035, PAL.stoneLight, { segs: 14, top: false });
      mb.box(0.24, 0.025, 0.48, 0.28, 0.58, 0.52, PAL.wood);
      mb.box(0.72, 0.025, 0.48, 0.76, 0.58, 0.52, PAL.wood);
      mb.box(0.22, 0.48, 0.49, 0.78, 0.51, 0.51, PAL.woodDark);
      mb.gable(0.18, 0.32, 0.82, 0.68, 0.58, 0.16, PAL.roof[0], { axis: 'x', end: PAL.wood, over: 0.03, ridges: false });
      mb.box(0.495, 0.3, 0.495, 0.505, 0.48, 0.505, '#6a5a4a');
      mb.cyl(0.5, 0.26, 0.5, 0.045, 0.06, PAL.wood, { segs: 8 });
      amphora(mb, 0.82, 0.78, 0.9);
      break;
    case 'fountain':
      mb.cyl(1, 0, 1, 0.94, 0.042, PAL.paving, { segs: 32 });
      for (let i = 0; i < 8; i++) { const a = i / 8 * Math.PI * 2; mb.plate(1 + Math.cos(a) * 0.86 - 0.06, 1 + Math.sin(a) * 0.86 - 0.06, 1 + Math.cos(a) * 0.86 + 0.06, 1 + Math.sin(a) * 0.86 + 0.06, 0.035, PAL.pavingDark); }
      mb.cyl(1, 0.03, 1, 0.76, 0.17, PAL.stone, { segs: 24, top: false });
      mb.cyl(1, 0.2, 1, 0.8, 0.035, PAL.stoneLight, { segs: 24, top: false });
      mb.cyl(1, 0.03, 1, 0.71, 0.14, PAL.water, { segs: 24 });
      mb.cyl(1, 0.03, 1, 0.09, 0.38, PAL.marble, { segs: 12, flute: 0.1 });
      mb.cyl(1, 0.41, 1, 0.22, 0.05, PAL.marble, { segs: 16, rTop: 0.3 });
      mb.cyl(1, 0.46, 1, 0.27, 0.004, PAL.water, { segs: 16 });
      mb.cyl(1, 0.46, 1, 0.045, 0.18, PAL.marble, { segs: 8 });
      mb.cyl(1, 0.64, 1, 0.08, 0.03, PAL.marble, { segs: 10, rTop: 0.1 });
      statueFigure(mb, 1, 1, 0.66, 0.35, PAL.marble);
      mb.fountain = [[1, 0.7, 1, 0.55]];
      for (const [x, z] of [[0.2, 0.2], [1.8, 0.2], [0.2, 1.8], [1.8, 1.8]]) pot(mb, x, z, 1.3, PAL.flowers[(x + z) * 3 % 6 | 0]);
      break;
    case 'temple': {
      mb.box(0.24, 0.03, 0.18, 2.76, 0.15, 2.56, PAL.stone);
      mb.box(0.34, 0.15, 0.28, 2.66, 0.27, 2.46, PAL.stoneLight);
      for (let i = 0; i < 4; i++) mb.box(0.85 - i * 0.02, 0.03, 2.46 + i * 0.08, 2.15 + i * 0.02, 0.27 - i * 0.06, 2.56 + i * 0.08, PAL.stoneLight);
      const y0 = 0.27, ch = 0.98;
      mb.wall(0.75, y0, 0.55, 2.25, y0 + ch, 1.95, PAL.plaster[0], { plinth: false, cornice: false });
      mb.door('z+', 1.95, 1.5, 0.34, 0.66, { color: '#6a4026', frame: PAL.marble });
      for (let i = 0; i < 6; i++) {
        const x = 0.5 + i * 0.4;
        column(mb, x, 2.25, y0, ch, 0.062);
        column(mb, x, 0.5, y0, ch, 0.062);
      }
      for (let k = 1; k < 4; k++) { column(mb, 0.5, 0.5 + k * 0.4375, y0, ch, 0.062); column(mb, 2.5, 0.5 + k * 0.4375, y0, ch, 0.062); }
      mb.box(0.38, y0 + ch, 0.38, 2.62, y0 + ch + 0.08, 2.37, PAL.marble);
      mb.box(0.36, y0 + ch + 0.08, 0.36, 2.64, y0 + ch + 0.13, 2.39, PAL.marbleShade);
      for (let i = 0; i < 18; i++) mb.box(0.42 + i * 0.123, y0 + ch + 0.085, 2.385, 0.47 + i * 0.123, y0 + ch + 0.125, 2.4, '#c9a050', { ao: 1 });
      mb.box(0.34, y0 + ch + 0.13, 0.34, 2.66, y0 + ch + 0.16, 2.41, PAL.marble);
      mb.gable(0.34, 0.34, 2.66, 2.41, y0 + ch + 0.16, 0.46, PAL.roof[0], { axis: 'z', end: PAL.marble, over: 0.06, endOver: 0.06 });
      // фронтон с золотым диском и акротериями
      mb.cyl(1.5, y0 + ch + 0.3, 2.475, 0.07, 0.02, PAL.gold, { segs: 14 });
      mb.blob(1.5, y0 + ch + 0.66, 2.47, 0.065, 0.065, 0.065, PAL.gold, { jitter: 0, detail: 1 });
      mb.blob(0.34, y0 + ch + 0.2, 2.47, 0.05, 0.05, 0.05, PAL.gold, { jitter: 0, detail: 1 });
      mb.blob(2.66, y0 + ch + 0.2, 2.47, 0.05, 0.05, 0.05, PAL.gold, { jitter: 0, detail: 1 });
      // алтарь с огнём
      mb.box(1.33, 0.03, 2.8, 1.67, 0.18, 2.96, PAL.marble);
      mb.box(1.31, 0.18, 2.78, 1.69, 0.21, 2.98, PAL.marbleShade);
      mb.glow = true;
      mb.cone(1.5, 0.21, 2.88, 0.07, 0.16, '#ff9a40', 8);
      mb.cone(1.5, 0.21, 2.88, 0.04, 0.22, '#ffe08a', 8);
      mb.glow = false;
      smoke(mb, 1.5, 0.45, 2.88);
      treeCypress(mb, 0.15, 2.85, 0.75);
      treeCypress(mb, 2.85, 2.85, 0.75);
      break;
    }
    case 'baths':
      mb.wall(0.2, 0.03, 0.2, 2.8, 0.78, 2.6, PAL.brickLight, { corniceColor: PAL.stoneLight });
      for (let i = 0; i < 5; i++) {
        mb.arch('z+', 2.6, 0.45 + i * 0.52, 0.28, 0.12, 0.52, PAL.stoneLight, 0.006);
        mb.arch('z+', 2.6, 0.45 + i * 0.52, 0.24, 0.12, 0.48, '#3e5f6c');
        mb.arch('x+', 2.8, 0.45 + i * 0.48, 0.24, 0.12, 0.48, '#3e5f6c');
        mb.arch('x-', 0.2, 0.45 + i * 0.48, 0.24, 0.12, 0.48, '#3e5f6c');
      }
      mb.hip(0.2, 0.2, 2.8, 2.6, 0.78, 0.22, PAL.roof[1], { over: 0.05 });
      mb.cyl(1.5, 0.92, 1.4, 0.7, 0.26, PAL.brickLight, { segs: 20 });
      mb.cyl(1.5, 1.15, 1.4, 0.73, 0.03, PAL.stoneLight, { segs: 20, top: false });
      mb.dome(1.5, 1.18, 1.4, 0.72, 0.58, '#c5d0cc', 20, true);
      mb.cyl(1.5, 1.74, 1.4, 0.12, 0.12, PAL.marble, { segs: 10 });
      mb.blob(1.5, 1.9, 1.4, 0.05, 0.05, 0.05, PAL.gold, { jitter: 0, detail: 1 });
      for (const x of [0.6, 2.4]) { mb.cyl(x, 0.85, 0.6, 0.26, 0.12, PAL.brickLight, { segs: 12 }); mb.dome(x, 0.97, 0.6, 0.27, 0.22, '#c5d0cc', 12, true); }
      mb.box(1.08, 0.03, 2.6, 1.92, 0.09, 2.92, PAL.marble);
      for (let i = 0; i < 4; i++) column(mb, 1.15 + i * 0.233, 2.82, 0.09, 0.62, 0.042);
      mb.box(1.04, 0.71, 2.6, 1.96, 0.79, 2.92, PAL.marble);
      mb.gable(1.04, 2.6, 1.96, 2.92, 0.79, 0.18, PAL.roof[1], { axis: 'z', end: PAL.marble, over: 0.03, ridges: false });
      smoke(mb, 2.4, 1.2, 0.6);
      smoke(mb, 0.6, 1.2, 0.6);
      break;
    case 'school':
      mb.wall(0.2, 0.025, 0.2, 1.8, 0.64, 1.2, PAL.plaster[3]);
      windowsAround(mb, 0.2, 0.2, 1.8, 1.2, 0.38, 0.4, 0.12, 0.17, PAL.shutter[1], true);
      mb.hip(0.2, 0.2, 1.8, 1.2, 0.64, 0.32, PAL.roof[2]);
      mb.box(0.3, 0.025, 1.2, 1.7, 0.065, 1.62, PAL.marble);
      for (let i = 0; i < 4; i++) column(mb, 0.4 + i * 0.4, 1.52, 0.065, 0.52, 0.036);
      mb.box(0.28, 0.58, 1.2, 1.72, 0.64, 1.62, PAL.marble);
      mb.door('z+', 1.2, 1.0, 0.22, 0.38);
      for (let i = 0; i < 2; i++) mb.box(0.4 + i * 0.75, 0.025, 1.76, 0.85 + i * 0.75, 0.11, 1.86, PAL.marble);
      for (let i = 0; i < 3; i++) mb.cyl(0.35 + i * 0.07, 0.07, 1.4, 0.022, 0.12, '#efe1bb', { segs: 6 });
      break;
    case 'market':
      mb.patch(1.5, 1.5, 1.42, 1.36, 0.042, PAL.paving, { jitter: 0.06 });
      for (const [x, z, c] of [[0.2, 0.25, 0], [1.15, 0.25, 1], [2.1, 0.25, 2], [0.2, 2.05, 3], [2.1, 2.05, 4]]) stall(mb, x, z, PAL.awning[(c + b.id) % PAL.awning.length], c);
      mb.cyl(1.5, 0.035, 1.5, 0.38, 0.13, PAL.stone, { segs: 18, top: false });
      mb.cyl(1.5, 0.035, 1.5, 0.33, 0.11, PAL.water, { segs: 18 });
      statueFigure(mb, 1.5, 1.5, 0.035, 0.95, PAL.marble);
      for (let i = 0; i < 4; i++) crate(mb, 0.4 + i * 0.15, 1.45, 1.1);
      for (let i = 0; i < 3; i++) amphora(mb, 2.35 + i * 0.14, 1.45, 1.25);
      treeOlive(mb, 1.5, 2.6, 0.8);
      break;
    case 'tradepost':
      mb.patch(1.5, 1.5, 1.4, 1.34, 0.042, PAL.dirt);
      mb.wall(0.2, 0.03, 0.2, 2.2, 0.78, 1.4, PAL.plaster[4]);
      windowsAround(mb, 0.2, 0.2, 2.2, 1.4, 0.48, 0.42, 0.12, 0.17, PAL.shutter[2], true);
      mb.hip(0.2, 0.2, 2.2, 1.4, 0.78, 0.36, PAL.roof[0]);
      for (let i = 0; i < 4; i++) column(mb, 0.35 + i * 0.57, 1.68, 0.03, 0.64, 0.046);
      mb.box(0.18, 0.64, 1.4, 2.22, 0.72, 1.78, PAL.marble);
      for (let i = 0; i < 3; i++) mb.arch('z+', 1.4, 0.55 + i * 0.6, 0.27, 0.03, 0.44, PAL.doorDark);
      // повозка
      mb.box(2.35, 0.15, 0.4, 2.8, 0.31, 1.1, PAL.wood);
      for (const z of [0.5, 0.95]) for (const x of [2.32, 2.83]) { mb.cyl(x, 0.14, z, 0.14, 0.035, PAL.woodDark, { segs: 12, sz: 1 }); }
      mb.box(2.5, 0.2, 1.1, 2.54, 0.24, 1.55, PAL.woodDark);
      for (let i = 0; i < 3; i++) crate(mb, 2.45 + (i % 2) * 0.17, 0.6 + i * 0.12, 1, 0.31);
      for (let i = 0; i < 6; i++) amphora(mb, 0.4 + (i % 3) * 0.16, 2.1 + Math.floor(i / 3) * 0.2, 1.35);
      for (let i = 0; i < 4; i++) crate(mb, 1.5 + (i % 2) * 0.16, 2.15 + Math.floor(i / 2) * 0.16, 1.1);
      mb.box(2.6, 0.03, 2.4, 2.64, 1.15, 2.44, PAL.wood);
      mb.box(2.64, 0.82, 2.41, 2.95, 1.08, 2.43, PAL.red, { ao: 1 });
      mb.blob(2.62, 1.18, 2.42, 0.04, 0.04, 0.04, PAL.gold, { jitter: 0 });
      break;
    case 'theatre': {
      const cx = 2, cz = 1.4;
      for (let r = 0; r < 7; r++) {
        const R0 = 0.55 + r * 0.22, R1 = R0 + 0.22, y = 0.03 + r * 0.11;
        const segs = 20;
        for (let i = 0; i < segs; i++) {
          const a0 = Math.PI * i / segs, a1 = Math.PI * (i + 1) / segs;
          const p = (R, a, yy) => [cx + Math.cos(a) * R, yy, cz - Math.sin(a) * R];
          const col = lin(r % 2 ? PAL.stone : PAL.stoneLight);
          mb.quad(p(R0, a1, y + 0.11), p(R0, a0, y + 0.11), p(R1, a0, y + 0.11), p(R1, a1, y + 0.11), col, 0, 0.03);
          mb.quad(p(R0, a0, y), p(R0, a0, y + 0.11), p(R0, a1, y + 0.11), p(R0, a1, y), lin(PAL.stoneDark), 0.82, 0.03);
          if (r === 6) mb.quad(p(R1, a1, 0.03), p(R1, a1, y + 0.11), p(R1, a0, y + 0.11), p(R1, a0, 0.03), lin(PAL.stoneDark), 0.78, 0.03);
        }
      }
      for (let i = 0; i <= 4; i++) {
        const a = Math.PI * i / 4;
        mb.box(cx + Math.cos(a) * 1.2 - 0.04, 0.03, cz - Math.sin(a) * 1.2 - 0.04, cx + Math.cos(a) * 1.2 + 0.04, 0.82, cz - Math.sin(a) * 1.2 + 0.04, PAL.stoneLight);
      }
      mb.cyl(cx, 0.03, cz, 0.55, 0.02, '#e9dcc0', { segs: 20 });
      mb.box(0.4, 0.03, 1.55, 3.6, 0.24, 2.05, PAL.stoneLight);
      mb.wall(0.5, 0.24, 2.0, 3.5, 1.2, 2.3, PAL.plaster[0], { plinth: false });
      for (let i = 0; i < 8; i++) column(mb, 0.65 + i * 0.385, 1.94, 0.24, 0.44, 0.036);
      for (let i = 0; i < 8; i++) column(mb, 0.65 + i * 0.385, 1.94, 0.71, 0.42, 0.03);
      mb.box(0.55, 0.68, 1.88, 3.45, 0.72, 2.0, PAL.marble);
      for (let i = 0; i < 3; i++) mb.arch('z-', 2.0, 1.25 + i * 0.75, 0.32, 0.24, 0.44, PAL.doorDark);
      mb.box(0.45, 1.2, 1.95, 3.55, 1.27, 2.35, PAL.marble);
      mb.box(1.2, 0.03, 2.35, 2.8, 0.08, 3.4, PAL.marbleShade);
      for (let i = 0; i < 3; i++) mb.box(1.3, 0.03, 3.4 + i * 0.07, 2.7, 0.08 - i * 0.02, 3.47 + i * 0.07, PAL.marbleShade);
      treeCypress(mb, 0.3, 3.6, 0.85); treeCypress(mb, 3.7, 3.6, 0.85);
      statueFigure(mb, 1.0, 3.2, 0.03, 0.95); statueFigure(mb, 3.0, 3.2, 0.03, 0.95);
      // маски над сценой
      for (const x of [1.2, 2.8]) mb.blob(x, 1.0, 2.31, 0.07, 0.08, 0.02, PAL.gold, { jitter: 0.05, detail: 1 });
      break;
    }
    case 'forum': {
      mb.patch(2, 2.3, 1.9, 1.6, 0.045, PAL.marbleShade, { jitter: 0.05 });
      mb.wall(0.25, 0.04, 0.2, 3.75, 1.0, 1.25, PAL.plaster[3], { cornice: false });
      for (let i = 0; i < 10; i++) column(mb, 0.35 + i * 0.367, 1.4, 0.04, 0.86, 0.05);
      mb.box(0.23, 0.86, 1.25, 3.77, 0.96, 1.5, PAL.marble);
      mb.wall(0.3, 1.0, 0.25, 3.7, 1.36, 1.2, PAL.plaster[3], { plinth: false });
      windowRow(mb, 'z+', 1.2, 0.4, 3.6, 8, 1.18, 0.14, 0.17, null);
      mb.gable(0.25, 0.2, 3.75, 1.25, 1.36, 0.36, PAL.roof[0], { axis: 'x', end: PAL.marble });
      mb.hip(0.25, 1.25, 3.75, 1.5, 0.96, 0.12, PAL.roof[0], { over: 0.02, ridges: false });
      for (let k = 0; k < 6; k++) { column(mb, 0.2, 1.75 + k * 0.4, 0.04, 0.7, 0.045); column(mb, 3.8, 1.75 + k * 0.4, 0.04, 0.7, 0.045); }
      mb.box(0.1, 0.74, 1.6, 0.35, 0.82, 3.9, PAL.marble);
      mb.box(3.65, 0.74, 1.6, 3.9, 0.82, 3.9, PAL.marble);
      mb.box(1.5, 0.04, 2.3, 2.5, 0.36, 2.75, PAL.stone);
      mb.box(1.48, 0.36, 2.28, 2.52, 0.39, 2.77, PAL.marble);
      for (let i = 0; i < 4; i++) mb.box(1.55 + i * 0.25, 0.15, 2.75, 1.65 + i * 0.25, 0.29, 2.79, PAL.bronze);
      statueFigure(mb, 2.0, 3.4, 0.04, 1.5, PAL.gold, true);
      treeCypress(mb, 0.7, 3.7, 0.75); treeCypress(mb, 3.3, 3.7, 0.75);
      for (const x of [1.0, 3.0]) mb.box(x - 0.15, 0.04, 3.2, x + 0.15, 0.14, 3.3, PAL.marble);
      break;
    }
    case 'barracks': {
      mb.patch(1.5, 1.5, 1.42, 1.38, 0.042, '#c9b48e');
      const pal = (x0, z0, x1, z1) => {
        const len = Math.hypot(x1 - x0, z1 - z0), n = Math.round(len / 0.09);
        for (let i = 0; i <= n; i++) {
          const x = x0 + (x1 - x0) * i / n, z = z0 + (z1 - z0) * i / n;
          mb.cyl(x, 0.03, z, 0.045, 0.45 + (i % 2) * 0.05, PAL.wood, { segs: 6, rTop: 0.02 });
        }
      };
      pal(0.12, 0.12, 2.88, 0.12); pal(0.12, 0.12, 0.12, 2.88); pal(2.88, 0.12, 2.88, 2.88);
      pal(0.12, 2.88, 1.15, 2.88); pal(1.85, 2.88, 2.88, 2.88);
      for (const x of [1.0, 2.0]) { mb.box(x - 0.15, 0.03, 2.75, x + 0.15, 0.82, 3.0, PAL.woodLight); mb.box(x - 0.19, 0.82, 2.71, x + 0.19, 0.88, 3.04, PAL.wood); for (let i = 0; i < 4; i++) mb.box(x - 0.17 + i * 0.1, 0.88, 2.73, x - 0.13 + i * 0.1, 0.95, 3.02, PAL.wood); }
      mb.box(1.15, 0.6, 2.8, 1.85, 0.7, 2.95, PAL.wood);
      shed(mb, 0.35, 0.35, 1.45, 0.95, 0.52, PAL.plaster[0], PAL.roof[0]);
      shed(mb, 1.6, 0.35, 2.65, 0.95, 0.52, PAL.plaster[0], PAL.roof[1]);
      for (const x of [0.9, 2.12]) mb.door('z+', 0.95, x, 0.18, 0.3);
      for (let i = 0; i < 3; i++) {
        const x = 0.55 + i * 0.4;
        mb.gable(x - 0.16, 1.3, x + 0.16, 1.72, 0.03, 0.3, '#ede3c8', { axis: 'z', over: 0, end: '#d9cdb0', ridges: false });
      }
      mb.box(2.2, 0.03, 1.6, 2.24, 1.25, 1.64, PAL.wood);
      mb.box(2.24, 0.85, 1.61, 2.62, 1.2, 1.63, PAL.red, { ao: 1 });
      mb.blob(2.22, 1.3, 1.62, 0.06, 0.06, 0.06, PAL.gold, { jitter: 0, detail: 1 });
      for (let i = 0; i < 4; i++) mb.box(1.6 + i * 0.12, 0.03, 2.2, 1.63 + i * 0.12, 0.27, 2.23, '#d0d2d6');
      for (let i = 0; i < 3; i++) { mb.cyl(0.6 + i * 0.3, 0.03, 2.35, 0.05, 0.3, PAL.woodDark, { segs: 6 }); mb.cyl(0.6 + i * 0.3, 0.2, 2.35, 0.09, 0.12, '#c9a46a', { segs: 8 }); }
      break;
    }
    case 'range': {
      // Стрельбище: навес для лучников, соломенные мишени с кругами, стойка с луками
      mb.patch(1.5, 1.5, 1.42, 1.38, 0.042, '#cdb98f');
      fence(mb, 0.1, 0.1, 2.9, 0.1); fence(mb, 0.1, 0.1, 0.1, 2.9); fence(mb, 2.9, 0.1, 2.9, 2.9);
      shed(mb, 0.25, 1.9, 1.45, 2.75, 0.55, PAL.plaster[3], PAL.roof[0]);
      mb.door('z+', 2.75, 0.85, 0.2, 0.32);
      mb.box(0.25, 0.03, 1.55, 1.45, 0.08, 1.9, PAL.woodLight);
      for (const x of [0.3, 1.4]) mb.box(x - 0.03, 0.03, 1.58, x + 0.03, 0.55, 1.64, PAL.wood);
      mb.box(0.24, 0.55, 1.5, 1.46, 0.6, 1.9, PAL.roof[1]);
      for (const [x, z] of [[1.9, 0.45], [2.45, 0.6], [2.2, 1.15]]) {
        mb.box(x - 0.03, 0.03, z + 0.02, x + 0.03, 0.42, z + 0.08, PAL.wood);
        mb.cyl(x, 0.3, z, 0.2, 0.12, '#e4c45c', { segs: 12, ao: 1 });
        mb.cyl(x, 0.3, z - 0.002, 0.14, 0.125, '#f6f1e6', { segs: 12, ao: 1 });
        mb.cyl(x, 0.3, z - 0.004, 0.08, 0.13, '#a8362a', { segs: 10, ao: 1 });
        mb.box(x + 0.02, 0.38, z + 0.06, x + 0.03, 0.39, z + 0.24, PAL.woodDark, { ao: 1 });
      }
      for (let i = 0; i < 4; i++) mb.box(1.6 + i * 0.09, 0.03, 2.55, 1.63 + i * 0.09, 0.5, 2.58, PAL.woodDark);
      mb.box(1.55, 0.42, 2.53, 1.95, 0.45, 2.6, PAL.wood);
      crate(mb, 2.5, 2.5, 1.2); crate(mb, 2.65, 2.3, 1);
      break;
    }
    case 'spearcamp': {
      // Лагерь копейщиков: палатки, стойка с копьями, чучело для учёбы и знамя
      mb.patch(1.5, 1.5, 1.42, 1.38, 0.042, '#c9b48e');
      const pal = (x0, z0, x1, z1) => {
        const len = Math.hypot(x1 - x0, z1 - z0), n = Math.round(len / 0.1);
        for (let i = 0; i <= n; i++) mb.cyl(x0 + (x1 - x0) * i / n, 0.03, z0 + (z1 - z0) * i / n, 0.04, 0.38 + (i % 2) * 0.05, PAL.wood, { segs: 6, rTop: 0.018 });
      };
      pal(0.12, 0.12, 2.88, 0.12); pal(0.12, 0.12, 0.12, 2.88); pal(2.88, 0.12, 2.88, 2.88);
      for (const [x, z] of [[0.75, 0.75], [1.65, 0.75]]) {
        mb.gable(x - 0.35, z - 0.3, x + 0.35, z + 0.38, 0.03, 0.5, '#efe6d0', { axis: 'z', over: 0, end: '#e3d8c0', ridges: false });
        mb.box(x - 0.08, 0.03, z + 0.36, x + 0.08, 0.3, z + 0.39, '#a8362a', { ao: 1 });
      }
      for (let i = 0; i < 6; i++) {
        const x = 2.3 + (i % 3) * 0.14, z = 0.55 + Math.floor(i / 3) * 0.16;
        mb.box(x - 0.012, 0.03, z - 0.012, x + 0.012, 0.95, z + 0.012, PAL.wood, { ao: 1 });
        mb.box(x - 0.022, 0.95, z - 0.012, x + 0.022, 1.06, z + 0.012, '#c3c7cc', { ao: 1 });
      }
      mb.box(2.2, 0.35, 0.45, 2.75, 0.4, 0.5, PAL.woodDark);
      mb.box(1.2, 0.03, 1.95, 1.25, 0.62, 2.0, PAL.wood);
      mb.box(1.02, 0.45, 1.95, 1.43, 0.5, 2.0, PAL.wood);
      mb.blob(1.225, 0.68, 1.975, 0.08, 0.08, 0.08, '#d9b965', { jitter: 0.1 });
      mb.cyl(1.225, 0.38, 2.04, 0.15, 0.04, '#3e5f8a', { segs: 10, ao: 1 });
      mb.box(0.55, 0.03, 2.3, 0.58, 1.35, 2.33, PAL.woodDark);
      mb.box(0.58, 0.95, 2.31, 0.98, 1.3, 2.32, PAL.red, { ao: 1 });
      mb.box(0.62, 1.07, 2.305, 0.94, 1.1, 2.325, PAL.gold, { ao: 1 });
      mb.blob(0.565, 1.4, 2.315, 0.05, 0.05, 0.05, PAL.gold, { jitter: 0, detail: 1 });
      break;
    }
    case 'ballistae':
    case 'catapults': {
      // Мастерские: дом мастеров, во дворе — готовая машина, брёвна и камни
      const bal = b.type === 'ballistae';
      mb.patch(1.5, 1.5, 1.42, 1.38, 0.042, '#c2a275');
      mb.wall(0.2, 0.025, 1.75, 2.8, 0.7, 2.8, PAL.plaster[1], { cornice: false });
      mb.gable(0.2, 1.75, 2.8, 2.8, 0.7, 0.42, PAL.roof[2], { axis: 'x', end: PAL.plaster[1] });
      mb.door('z-', 1.75, 1.0, 0.36, 0.48);
      mb.window('z-', 1.75, 0.45, 0.42, 0.18, 0.2, PAL.shutter[2]);
      mb.window('z-', 1.75, 2.3, 0.42, 0.18, 0.2, PAL.shutter[2]);
      smoke(mb, 2.4, 1.2, 2.3);
      mb.box(2.3, 0.7, 2.2, 2.5, 1.15, 2.4, PAL.brick);
      const x = 1.0, z = 0.85;
      for (const [wx, wz] of [[-0.3, -0.28], [0.3, -0.28], [-0.3, 0.28], [0.3, 0.28]]) mb.cyl(x + wx, 0.13, z + wz, 0.13, 0.04, PAL.woodDark, { segs: 10, ao: 1 });
      mb.box(x - 0.28, 0.12, z - 0.4, x - 0.2, 0.2, z + 0.4, PAL.wood);
      mb.box(x + 0.2, 0.12, z - 0.4, x + 0.28, 0.2, z + 0.4, PAL.wood);
      mb.box(x - 0.28, 0.14, z - 0.05, x + 0.28, 0.2, z + 0.05, PAL.woodDark);
      if (bal) {
        mb.box(x - 0.05, 0.2, z - 0.05, x + 0.05, 0.42, z + 0.05, PAL.wood);
        mb.box(x - 0.36, 0.42, z - 0.07, x + 0.36, 0.48, z + 0.07, PAL.wood);
        mb.box(x - 0.06, 0.48, z - 0.42, x + 0.06, 0.53, z + 0.4, PAL.woodLight);
        mb.box(x - 0.02, 0.53, z - 0.5, x + 0.02, 0.56, z + 0.32, PAL.woodDark, { ao: 1 });
        for (let i = 0; i < 5; i++) mb.box(1.9 + i * 0.1, 0.03, 0.4, 1.94 + i * 0.1, 0.07, 1.2, PAL.woodLight);
      } else {
        mb.box(x - 0.28, 0.2, z - 0.05, x - 0.2, 0.6, z + 0.05, PAL.wood);
        mb.box(x + 0.2, 0.2, z - 0.05, x + 0.28, 0.6, z + 0.05, PAL.wood);
        mb.box(x - 0.28, 0.56, z - 0.07, x + 0.28, 0.64, z + 0.07, PAL.woodDark);
        mb.box(x - 0.04, 0.2, z - 0.55, x + 0.04, 0.28, z + 0.05, PAL.wood);
        mb.box(x - 0.1, 0.18, z - 0.62, x + 0.1, 0.3, z - 0.48, PAL.woodDark);
        for (let i = 0; i < 6; i++) mb.blob(2.0 + (i % 3) * 0.22, 0.1 + Math.floor(i / 3) * 0.14, 0.7 + (i % 2) * 0.1, 0.1, 0.09, 0.1, '#a8a294', { jitter: 0.25 });
      }
      crate(mb, 2.55, 1.45, 1.2);
      fence(mb, 0.1, 0.1, 2.9, 0.1); fence(mb, 0.1, 0.1, 0.1, 1.7); fence(mb, 2.9, 0.1, 2.9, 1.7);
      break;
    }
  }
}

/* ---------- Чудеса света ---------- */

/* ---------- Центр города: растёт сам вместе со званием города ----------
   Место 4×4, фасад смотрит на +z. Без квадратной подложки: здание стоит на земле или мостовой само.
   0 — лагерь переселенцев, 1 — дом старосты, 2 — курия, 3 — базилика, 4 — большая базилика,
   5 — дворец наместника, 6 — императорский дворец. */

// источник света: ночью вокруг него на земле тёплый круг (Engine.updateLights)
function addLight(mb, x, y, z, r) { (mb.lights || (mb.lights = [])).push([x, y, z, r]); }

// огонь: два светящихся конуса и дымок
function centerFire(mb, x, y, z, s, smokeToo) {
  addLight(mb, x, y + 0.1 * s, z, 1.5 * s);
  mb.glow = true;
  mb.cone(x, y, z, 0.07 * s, 0.17 * s, '#ff9a40', 8);
  mb.cone(x, y, z, 0.04 * s, 0.24 * s, '#ffe08a', 8);
  mb.glow = false;
  if (smokeToo) smoke(mb, x, y + 0.25 * s, z);
}

// доска объявлений: сюда жители вешают просьбы
function noticeBoard(mb, x, z, rot) {
  const c = Math.cos(rot || 0), s = Math.sin(rot || 0);
  const P = (u, w) => [x + u * c + w * s, z - u * s + w * c];
  for (const u of [-0.17, 0.17]) { const [px, pz] = P(u, 0); mb.box(px - 0.018, 0, pz - 0.018, px + 0.018, 0.5, pz + 0.018, PAL.woodDark); }
  const [bx, bz] = P(0, 0);
  const hw = Math.abs(c) * 0.2 + Math.abs(s) * 0.02, hd = Math.abs(s) * 0.2 + Math.abs(c) * 0.02;
  mb.box(bx - hw, 0.22, bz - hd, bx + hw, 0.46, bz + hd, PAL.woodLight);
  // листки с просьбами
  for (let i = 0; i < 4; i++) {
    const [lx, lz] = P(-0.12 + i * 0.08, 0.025);
    mb.box(lx - 0.025, 0.27 + (i % 2) * 0.07, lz - 0.004, lx + 0.025, 0.33 + (i % 2) * 0.07, lz + 0.004, i % 3 ? '#f6eedc' : '#efe0b0', { ao: 1 });
  }
  mb.box(bx - hw - 0.03, 0.46, bz - hd - 0.03, bx + hw + 0.03, 0.5, bz + hd + 0.03, PAL.roof[1]);
}

// шатёр переселенцев (если набор моделей не загружен)
function tentShape(mb, x, z, w, d, h, color) {
  mb.gable(x - w / 2, z - d / 2, x + w / 2, z + d / 2, 0, h, color, { axis: 'z', end: shadeHex(color, 0.92), over: 0.02, endOver: 0.01, ridges: false });
}

function centerModel(mb, b) {
  const st = b.tier || 0;
  const gold = PAL.gold;
  // готовые мелочи набора (если он загружен), иначе — свои простые фигуры
  const P = (name, x, z, rot, h, y) => !!mb.prop && mb.prop(name, x, y || 0, z, rot || 0, h);

  if (st === 0) {
    // Лагерь переселенцев: шатры, костёр, повозка с пожитками, знамя и доска для просьб
    if (!P('Small Tent', 1.05, 1.1, 0.35, 0.72)) tentShape(mb, 1.05, 1.1, 0.8, 1.0, 0.6, PAL.fabric);
    if (!P('Small Tent', 2.95, 0.95, -0.5, 0.78)) tentShape(mb, 2.95, 0.95, 0.85, 1.0, 0.64, '#e9d9b6');
    if (!P('Small Tent', 0.85, 2.75, 1.5, 0.66)) tentShape(mb, 0.85, 2.75, 0.75, 0.9, 0.55, '#d9c49c');
    if (!P('Campfire', 2.2, 2.25, 0, 0.16)) {
      for (let i = 0; i < 7; i++) { const a = i / 7 * Math.PI * 2; mb.blob(2.2 + Math.cos(a) * 0.16, 0.04, 2.25 + Math.sin(a) * 0.16, 0.05, 0.04, 0.05, PAL.stoneDark); }
    }
    centerFire(mb, 2.2, 0.05, 2.25, 1.1, true);
    for (const [x, z, r] of [[1.75, 2.05, 0.4], [2.6, 2.6, -0.5], [2.15, 2.8, 1.5]]) {
      if (!P('Log', x, z, r, 0.1)) mb.cyl(x, 0.05, z, 0.05, 0.3, PAL.wood, { segs: 6 });
    }
    if (!P('Horse Cart', 3.25, 2.55, 2.4, 0.6)) { mb.box(2.95, 0.12, 2.3, 3.55, 0.3, 2.8, PAL.wood); mb.cyl(3.05, 0.12, 2.25, 0.12, 0.04, PAL.woodDark, { segs: 10 }); }
    if (!P('Hay bal', 3.5, 1.75, 0.3, 0.2)) mb.box(3.35, 0, 1.6, 3.65, 0.2, 1.9, PAL.thatch);
    if (!P('Closed Barrel', 1.75, 0.45, 0, 0.18)) mb.cyl(1.75, 0, 0.45, 0.09, 0.18, PAL.wood, { segs: 8 });
    if (!P('Basket', 1.95, 0.55, 0, 0.08)) crate(mb, 1.95, 0.55, 0.8);
    crate(mb, 3.6, 3.05, 1);
    crate(mb, 3.45, 3.25, 0.8);
    if (!P('Banner', 2.0, 3.55, 0, 0.9)) { mb.box(1.98, 0, 3.53, 2.02, 0.9, 3.57, PAL.woodDark); mb.box(2.02, 0.5, 3.54, 2.26, 0.86, 3.56, PAL.red); }
    noticeBoard(mb, 0.75, 3.55, 0);
    treeOlive(mb, 3.6, 0.35, 0.8);
    bush(mb, 0.25, 0.4, 1.1, PAL.leaf);
    return;
  }

  if (st === 1) {
    // Дом старосты: бревенчато-оштукатуренный дом с крыльцом, колокол на столбе, доска для просьб
    const x0 = 0.75, x1 = 3.25, z0 = 0.55, z1 = 2.35, H = 0.78;
    mb.wall(x0, 0, z0, x1, H, z1, PAL.plaster[1], { cornice: false });
    quoins(mb, x0, z0, x1, z1, 0.07, H, PAL.woodDark);
    mb.box(x0 - 0.02, H - 0.05, z0 - 0.02, x1 + 0.02, H, z1 + 0.02, PAL.woodDark);
    mb.box(x0 - 0.02, 0.38, z1, x1 + 0.02, 0.42, z1 + 0.02, PAL.woodDark);
    mb.gable(x0, z0, x1, z1, H, 0.55, PAL.roof[0], { axis: 'x', end: PAL.plaster[1], over: 0.1 });
    mb.door('z+', z1, 2.0, 0.3, 0.56, { color: PAL.door, frame: PAL.woodLight });
    for (const u of [1.2, 2.8]) mb.window('z+', z1, u, 0.48, 0.2, 0.22, PAL.shutter[0], { flowers: true, seed: 2 });
    for (const u of [1.0, 1.9]) mb.window('x+', x1, u, 0.48, 0.18, 0.2, PAL.shutter[0]);
    mb.window('x-', x0, 1.45, 0.48, 0.18, 0.2, PAL.shutter[0]);
    // крыльцо на столбах
    mb.box(1.25, 0, z1, 2.75, 0.06, z1 + 0.55, PAL.woodLight);
    for (const x of [1.3, 2.7]) mb.box(x - 0.03, 0.06, z1 + 0.48, x + 0.03, 0.62, z1 + 0.54, PAL.wood);
    mb.gable(1.18, z1 - 0.02, 2.82, z1 + 0.62, 0.62, 0.16, PAL.roof[1], { axis: 'z', end: PAL.wood, over: 0.03, ridges: false });
    // колокол на столбе
    mb.box(3.45, 0, 3.2, 3.5, 0.95, 3.25, PAL.woodDark);
    mb.box(3.5, 0, 3.2, 3.55, 0.95, 3.25, PAL.woodDark);
    mb.box(3.33, 0.92, 3.18, 3.67, 0.97, 3.27, PAL.woodDark);
    mb.cyl(3.5, 0.72, 3.225, 0.08, 0.18, PAL.bronze, { segs: 10, rTop: 0.035 });
    noticeBoard(mb, 0.65, 3.35, 0);
    if (!P('Banner', 0.35, 2.55, 0, 0.85)) { mb.box(0.33, 0, 2.53, 0.37, 0.85, 2.57, PAL.woodDark); mb.box(0.37, 0.48, 2.54, 0.6, 0.82, 2.56, PAL.red); }
    if (!P('Closed Barrel', 3.55, 0.75, 0, 0.18)) mb.cyl(3.55, 0, 0.75, 0.09, 0.18, PAL.wood, { segs: 8 });
    amphora(mb, 3.6, 1.05, 0.9);
    pot(mb, 1.15, 2.95, 1, PAL.flowers[0]);
    pot(mb, 2.85, 2.95, 1, PAL.flowers[2]);
    treeOlive(mb, 0.35, 0.45, 0.85);
    bush(mb, 3.65, 2.15, 1, PAL.leaf);
    return;
  }

  if (st === 2) {
    // Курия: каменный зал совета с портиком, ступени, жаровни
    const x0 = 0.7, x1 = 3.3, z0 = 0.5, z1 = 2.45, y0 = 0.16, H = 1.02;
    for (let i = 0; i < 3; i++) mb.box(x0 - 0.12 + i * 0.04, i * 0.055, z0 - 0.12 + i * 0.04, x1 + 0.12 - i * 0.04, (i + 1) * 0.055, z1 + 0.62 - i * 0.04, i % 2 ? PAL.stoneLight : PAL.stone);
    mb.wall(x0, y0, z0, x1, y0 + H, z1, PAL.plaster[3], { plinth: false, band: y0 + 0.62 });
    for (const u of [1.05, 2.95]) mb.window('z+', z1, u, y0 + 0.42, 0.16, 0.28, null, { frame: PAL.marble });
    windowsAround(mb, x0, z0, x1, z1, y0 + 0.42, 0.5, 0.14, 0.26, null, true, { frame: PAL.marble });
    mb.arch('z+', z1, 2.0, 0.36, y0, 0.62, '#e3d7bd', 0.006);
    mb.arch('z+', z1, 2.0, 0.3, y0, 0.58, PAL.door, 0.01);
    for (let i = 0; i < 4; i++) column(mb, 1.1 + i * 0.6, z1 + 0.42, y0, H - 0.08, 0.055);
    mb.box(0.92, y0 + H - 0.08, z1 - 0.02, 3.08, y0 + H, z1 + 0.52, PAL.marble);
    mb.gable(x0 - 0.04, z0 - 0.04, x1 + 0.04, z1 + 0.56, y0 + H, 0.5, PAL.roof[0], { axis: 'z', end: PAL.marble, over: 0.06, endOver: 0.04 });
    mb.cyl(2.0, y0 + H + 0.16, z1 + 0.565, 0.06, 0.015, gold, { segs: 12, phase: 0 });
    for (let i = 0; i < 3; i++) mb.box(1.35 + i * 0.05, 0, z1 + 0.56 + i * 0.09, 2.65 - i * 0.05, 0.16 - i * 0.05, z1 + 0.65 + i * 0.09, PAL.stoneLight);
    for (const x of [0.45, 3.55]) {
      if (P('Floor Torch', x, 3.15, 0, 0.42)) centerFire(mb, x, 0.4, 3.15, 0.8);
      else { mb.cyl(x, 0, 3.15, 0.05, 0.38, PAL.bronze, { segs: 8 }); centerFire(mb, x, 0.38, 3.15, 0.8); }
    }
    noticeBoard(mb, 0.55, 3.6, 0);
    statueFigure(mb, 3.45, 3.65, 0, 0.75, PAL.marble);
    treeCypress(mb, 0.2, 0.35, 0.8);
    treeCypress(mb, 3.8, 0.35, 0.8);
    pot(mb, 1.25, 3.55, 1, PAL.flowers[1]);
    pot(mb, 2.75, 3.55, 1, PAL.flowers[3]);
    return;
  }

  // 3–6: базилика → большая базилика → дворец наместника → императорский дворец
  const rich = st >= 4, palace = st >= 5, imperial = st >= 6;
  const y0 = 0.2;
  // ступенчатое основание по форме здания (не квадрат: с выступом портика)
  for (let i = 0; i < 3; i++) {
    const k = i * 0.045;
    mb.box(0.25 + k, i * 0.066, 0.45 + k, 3.75 - k, (i + 1) * 0.066, 2.75 - k, i % 2 ? PAL.stoneLight : PAL.stone);
    mb.box(0.75 + k, i * 0.066, 2.7, 3.25 - k, (i + 1) * 0.066, 3.45 - k, i % 2 ? PAL.stoneLight : PAL.stone);
  }
  const wallC = palace ? PAL.marble : PAL.plaster[3];
  if (!palace) {
    // базилика: высокий средний неф с окнами наверху и низкие боковые нефы
    const H1 = 0.78, H2 = 1.42;
    mb.wall(0.4, y0, 0.6, 3.6, y0 + H1, 2.62, wallC, { plinth: false });
    mb.wall(1.0, y0 + H1, 0.75, 3.0, y0 + H2, 2.5, wallC, { plinth: false });
    for (let i = 0; i < 4; i++) {
      mb.window('x+', 3.0, 0.95 + i * 0.42, y0 + H1 + 0.32, 0.14, 0.24, null, { frame: PAL.marble });
      mb.window('x-', 1.0, 0.95 + i * 0.42, y0 + H1 + 0.32, 0.14, 0.24, null, { frame: PAL.marble });
    }
    for (let i = 0; i < 5; i++) {
      mb.arch('x+', 3.6, 0.85 + i * 0.4, 0.2, y0 + 0.08, 0.5, '#5a4a3a');
      mb.arch('x-', 0.4, 0.85 + i * 0.4, 0.2, y0 + 0.08, 0.5, '#5a4a3a');
    }
    const roofC = rich ? '#8fa29c' : PAL.roof[0];
    mb.gable(0.33, 0.55, 1.05, 2.67, y0 + H1, 0.22, roofC, { axis: 'z', end: wallC, over: 0.04, ridges: false });
    mb.gable(2.95, 0.55, 3.67, 2.67, y0 + H1, 0.22, roofC, { axis: 'z', end: wallC, over: 0.04, ridges: false });
    mb.gable(0.94, 0.7, 3.06, 2.56, y0 + H2, 0.5, roofC, { axis: 'z', end: PAL.marble, over: 0.06, endOver: 0.04 });
    if (rich) {
      // апсида сзади — полукруглая, под медной кровлей
      mb.cyl(2.0, y0, 0.6, 0.62, H1, wallC, { segs: 16, top: false });
      mb.dome(2.0, y0 + H1, 0.6, 0.64, 0.42, '#8fa29c', 16, true);
    }
  } else {
    // дворец: два этажа аркад, барабан с куполом посередине
    const H1 = 0.62, H2 = 1.2;
    mb.wall(0.35, y0, 0.55, 3.65, y0 + H1, 2.65, wallC, { plinth: false, corniceColor: PAL.marbleShade });
    mb.wall(0.45, y0 + H1, 0.65, 3.55, y0 + H2, 2.55, wallC, { plinth: false, corniceColor: PAL.marbleShade });
    for (let i = 0; i < 7; i++) {
      const u = 0.6 + i * 0.47;
      mb.arch('z+', 2.65, u, 0.24, y0 + 0.04, 0.48, '#4e3e30');
      mb.window('z+', 2.55, u, y0 + H1 + 0.3, 0.15, 0.26, null, { frame: gold });
    }
    for (let i = 0; i < 4; i++) {
      mb.arch('x+', 3.65, 0.85 + i * 0.5, 0.24, y0 + 0.04, 0.48, '#4e3e30');
      mb.arch('x-', 0.35, 0.85 + i * 0.5, 0.24, y0 + 0.04, 0.48, '#4e3e30');
      mb.window('x+', 3.55, 0.85 + i * 0.5, y0 + H1 + 0.3, 0.15, 0.26, null, { frame: gold });
      mb.window('x-', 0.45, 0.85 + i * 0.5, y0 + H1 + 0.3, 0.15, 0.26, null, { frame: gold });
    }
    mb.hip(0.4, 0.6, 3.6, 2.6, y0 + H2, 0.32, PAL.roof[2], { over: 0.06 });
    // барабан и купол
    const dc = imperial ? gold : '#c7c2b6';
    mb.cyl(2.0, y0 + H2, 1.55, 0.72, 0.36, PAL.marble, { segs: 24 });
    for (let i = 0; i < 12; i++) { const a = i / 12 * Math.PI * 2; column(mb, 2.0 + Math.cos(a) * 0.76, 1.55 + Math.sin(a) * 0.76, y0 + H2, 0.36, 0.035); }
    mb.cyl(2.0, y0 + H2 + 0.36, 1.55, 0.8, 0.06, PAL.marbleShade, { segs: 24 });
    mb.dome(2.0, y0 + H2 + 0.42, 1.55, 0.74, 0.62, dc, 24, true);
    mb.cyl(2.0, y0 + H2 + 1.02, 1.55, 0.09, 0.14, PAL.marble, { segs: 10 });
    mb.blob(2.0, y0 + H2 + 1.2, 1.55, 0.07, 0.07, 0.07, gold, { jitter: 0, detail: 1 });
  }
  // портик во всю высоту с фронтоном
  const pc = palace ? 6 : 4, pw = palace ? 2.5 : 2.3, colH = palace ? 1.22 : 1.12;
  for (let i = 0; i < pc; i++) column(mb, 2.0 - pw / 2 + i * pw / (pc - 1), 3.2, y0, colH, palace ? 0.06 : 0.065, PAL.marble);
  mb.box(2.0 - pw / 2 - 0.12, y0 + colH, 2.6, 2.0 + pw / 2 + 0.12, y0 + colH + 0.1, 3.32, PAL.marble);
  for (let i = 0; i < 14; i++) mb.box(2.0 - pw / 2 - 0.05 + i * (pw + 0.1) / 14, y0 + colH + 0.02, 3.32, 2.0 - pw / 2 + 0.02 + i * (pw + 0.1) / 14, y0 + colH + 0.08, 3.335, gold, { ao: 1 });
  mb.gable(2.0 - pw / 2 - 0.12, 2.6, 2.0 + pw / 2 + 0.12, 3.34, y0 + colH + 0.1, 0.42, palace ? PAL.roof[2] : (rich ? '#8fa29c' : PAL.roof[0]), { axis: 'z', end: PAL.marble, over: 0.05, endOver: 0.03 });
  mb.cyl(2.0, y0 + colH + 0.25, 3.345, 0.08, 0.015, gold, { segs: 14 });
  for (const x of [2.0 - pw / 2 - 0.1, 2.0 + pw / 2 + 0.1]) mb.blob(x, y0 + colH + 0.16, 3.33, 0.05, 0.05, 0.05, gold, { jitter: 0, detail: 1 });
  // двери за колоннадой
  mb.arch('z+', 2.62, 2.0, 0.42, y0, 0.78, '#e3d7bd', 0.006);
  mb.arch('z+', 2.62, 2.0, 0.36, y0, 0.74, palace ? '#5a3a20' : PAL.door, 0.01);
  // широкие ступени
  for (let i = 0; i < 3; i++) mb.box(1.05 - i * 0.06, 0, 3.4 + i * 0.1, 2.95 + i * 0.06, 0.2 - i * 0.066, 3.5 + i * 0.1, PAL.stoneLight);
  // знамёна, огни, статуи
  for (const x of [0.35, 3.65]) {
    const th = imperial ? 0.55 : 0.42;
    if (!P('Floor Torch', x, 3.45, 0, th)) mb.cyl(x, 0, 3.45, 0.05, th - 0.02, PAL.bronze, { segs: 8 });
    centerFire(mb, x, th - 0.02, 3.45, imperial ? 1.05 : 0.8);
  }
  for (const x of [0.6, 3.4]) if (!P('Banner', x, 2.95, 0, rich ? 1.05 : 0.9)) { mb.box(x - 0.02, 0, 2.93, x + 0.02, 1, 2.97, PAL.woodDark); mb.box(x + 0.02, 0.55, 2.94, x + 0.26, 0.95, 2.96, PAL.red); }
  if (rich) {
    statueFigure(mb, 0.55, 3.75, 0, 0.85, imperial ? gold : PAL.marble, imperial);
    statueFigure(mb, 3.45, 3.75, 0, 0.85, imperial ? gold : PAL.marble, imperial);
  } else noticeBoard(mb, 0.55, 3.7, 0);
  if (imperial) {
    // квадрига на фронтоне
    mb.box(1.72, y0 + colH + 0.52, 3.05, 2.28, y0 + colH + 0.58, 3.25, PAL.bronze);
    for (let i = 0; i < 4; i++) {
      const x = 1.76 + i * 0.16;
      mb.box(x - 0.025, y0 + colH + 0.58, 3.08, x + 0.025, y0 + colH + 0.72, 3.24, gold);
      mb.box(x - 0.02, y0 + colH + 0.7, 3.2, x + 0.02, y0 + colH + 0.8, 3.27, gold);
    }
    statueFigure(mb, 2.0, 3.1, y0 + colH + 0.58, 0.45, gold, true);
  }
  treeCypress(mb, 0.15, 0.3, 0.9);
  treeCypress(mb, 3.85, 0.3, 0.9);
  if (!palace) { pot(mb, 0.25, 2.4, 1.1, PAL.flowers[0]); pot(mb, 3.75, 2.4, 1.1, PAL.flowers[2]); }
}

function wonderModel(mb, b) {
  switch (b.type) {
    case 'colosseum': {
      const cx = 3, cz = 3, RX = 2.75, RZ = 2.3, segs = 40, tiers = 3, th = 0.56;
      const pt = (k, a, y) => [cx + Math.cos(a) * RX * k, y, cz + Math.sin(a) * RZ * k];
      for (let i = 0; i < segs; i++) {
        const a0 = i / segs * Math.PI * 2, a1 = (i + 1) / segs * Math.PI * 2, am = (a0 + a1) / 2;
        for (let t = 0; t < tiers; t++) {
          const y0 = 0.03 + t * th, y1 = y0 + th;
          const col = lin(t % 2 ? '#e6d6b2' : '#dfcca6');
          mb.quad(pt(1, a0, y0), pt(1, a0, y1), pt(1, a1, y1), pt(1, a1, y0), col, t === 0 ? 0.78 : 0.95, 0.03);
          // карниз яруса
          mb.quad(pt(1.012, a0, y1 - 0.04), pt(1.012, a0, y1), pt(1.012, a1, y1), pt(1.012, a1, y1 - 0.04), lin('#efe2c4'), 0, 0.02);
          // проём арки
          const w = 0.24, ah = th * 0.72;
          const tx = -Math.sin(am), tz = Math.cos(am);
          const P0 = pt(1.004, am, 0);
          const ctr = [P0[0], y0 + ah * 0.45, P0[2]];
          const ring = [[P0[0] - tx * w / 2, y0 + 0.07, P0[2] - tz * w / 2], [P0[0] + tx * w / 2, y0 + 0.07, P0[2] + tz * w / 2]];
          for (let s = 0; s <= 6; s++) { const q = s / 6 * Math.PI; ring.push([P0[0] + tx * Math.cos(q) * w / 2, y0 + ah - w / 2 + Math.sin(q) * w / 2 + 0.07, P0[2] + tz * Math.cos(q) * w / 2]); }
          const dc = lin(t === 0 ? '#4e3e30' : '#5e4c3c');
          for (let s = 0; s < ring.length; s++) mb.tri(ctr, ring[s], ring[(s + 1) % ring.length], dc);
          // полуколонна между арками
          const pc = pt(1.0, a0, 0);
          mb.box(pc[0] - 0.025, y0 + 0.04, pc[2] - 0.025, pc[0] + 0.025, y1 - 0.04, pc[2] + 0.025, '#eadcb8', { ao: 0.95 });
        }
        const y0 = 0.03 + tiers * th;
        mb.quad(pt(1, a0, y0), pt(1, a0, y0 + 0.3), pt(1, a1, y0 + 0.3), pt(1, a1, y0), lin('#e9dbbc'), 0.95, 0.03);
        mb.quad(pt(0.93, a1, y0 + 0.3), pt(0.93, a0, y0 + 0.3), pt(1, a0, y0 + 0.3), pt(1, a1, y0 + 0.3), lin('#efe4ca'), 0, 0.03);
        for (let r = 0; r < 7; r++) {
          const k0 = 0.93 - r * 0.08, k1 = k0 - 0.08, y = y0 + 0.22 - r * 0.22;
          const sc = lin(r % 2 ? '#d9cdb2' : '#e8ddc4');
          mb.quad(pt(k1, a1, y), pt(k1, a0, y), pt(k0, a0, y), pt(k0, a1, y), sc, 0, 0.04);
          mb.quad(pt(k1, a0, y - 0.22), pt(k1, a0, y), pt(k1, a1, y), pt(k1, a1, y - 0.22), lin('#bfae8e'), 0.88, 0.03);
          if ((i + r) % 3 === 0 && r < 6) mb.box(pt(k0 - 0.04, am, 0)[0] - 0.02, y, pt(k0 - 0.04, am, 0)[2] - 0.02, pt(k0 - 0.04, am, 0)[0] + 0.02, y + 0.07, pt(k0 - 0.04, am, 0)[2] + 0.02, PAL.awning[(i + r) % 5], { ao: 1 });
        }
      }
      mb.cyl(cx, 0.03, cz, RX * 0.37, 0.07, '#e8cf94', { segs: 32, sz: RZ / RX });
      mb.cyl(cx, 0.03, cz, RX * 0.39, 0.16, '#cbb88e', { segs: 32, sz: RZ / RX, top: false });
      for (let i = 0; i < 6; i++) {
        const a = i / 6 * Math.PI * 2;
        mb.box(cx + Math.cos(a) * 0.4 - 0.03, 0.1, cz + Math.sin(a) * 0.3 - 0.03, cx + Math.cos(a) * 0.4 + 0.03, 0.22, cz + Math.sin(a) * 0.3 + 0.03, PAL.wood);
      }
      for (let i = 0; i < 16; i++) {
        const a = i / 16 * Math.PI * 2;
        const [x, , z] = pt(1.0, a, 0);
        const yy = 0.03 + tiers * th + 0.3;
        mb.box(x - 0.015, yy, z - 0.015, x + 0.015, yy + 0.5, z + 0.015, PAL.wood);
        mb.box(x - 0.015, yy + 0.3, z - 0.015, x + 0.22, yy + 0.47, z + 0.005, i % 2 ? PAL.red : PAL.gold, { ao: 1 });
      }
      break;
    }
    case 'pantheon': {
      mb.cyl(2, 0, 1.65, 1.55, 0.045, PAL.marbleShade, { segs: 32 });
      const cx = 2, cz = 1.65, R = 1.35;
      mb.cyl(cx, 0.04, cz, R, 1.0, '#e6dcc6', { segs: 32 });
      for (let i = 0; i < 3; i++) mb.cyl(cx, 0.3 + i * 0.3, cz, R + 0.02, 0.03, PAL.marble, { segs: 32, top: false });
      mb.cyl(cx, 1.0, cz, R + 0.05, 0.08, PAL.marble, { segs: 32 });
      mb.cyl(cx, 1.08, cz, R - 0.05, 0.22, '#e6dcc6', { segs: 32 });
      for (let i = 0; i < 6; i++) mb.cyl(cx, 1.08 + i * 0.04, cz, R - 0.05 - i * 0.06, 0.04, '#d8d0c0', { segs: 32, top: false });
      mb.dome(cx, 1.3, cz, R - 0.05, 0.96, '#c7c2b6', 32, true);
      mb.cyl(cx, 2.24, cz, 0.24, 0.05, PAL.marble, { segs: 16 });
      mb.cyl(cx, 2.29, cz, 0.18, 0.005, '#2a2a30', { segs: 16 });
      mb.box(0.75, 0.04, 2.6, 3.25, 0.17, 3.75, PAL.stone);
      mb.box(1.1, 0.17, 2.6, 2.9, 1.26, 3.0, '#e6dcc6');
      for (let i = 0; i < 8; i++) column(mb, 0.9 + i * 0.314, 3.6, 0.17, 1.06, 0.072);
      for (let i = 0; i < 4; i++) column(mb, 0.9 + i * 0.314 * 2.33, 3.2, 0.17, 1.06, 0.072);
      mb.box(0.8, 1.23, 2.6, 3.2, 1.33, 3.72, PAL.marble);
      mb.box(0.78, 1.33, 2.58, 3.22, 1.4, 3.74, PAL.marbleShade);
      mb.gable(0.8, 2.6, 3.2, 3.72, 1.4, 0.52, '#9fa7a8', { axis: 'z', end: PAL.marble, over: 0.04, endOver: 0.02 });
      mb.box(1.5, 1.45, 3.73, 2.5, 1.55, 3.75, '#c9a050', { ao: 1 });
      mb.arch('z+', 3.0, 2.0, 0.52, 0.17, 0.86, '#e3d7bd', 0.006);
      mb.arch('z+', 3.0, 2.0, 0.46, 0.17, 0.8, '#3a2c20');
      for (let i = 0; i < 3; i++) mb.box(1.3 - i * 0.05, 0.04, 3.75 + i * 0.07, 2.7 + i * 0.05, 0.13 - i * 0.04, 3.82 + i * 0.07, PAL.stoneLight);
      mb.cyl(2.0, 0.04, 0.2, 0.25, 0.07, PAL.stone, { segs: 14 });
      break;
    }
    case 'arch':
      mb.box(0.15, 0.03, 0.7, 0.65, 1.15, 1.3, PAL.marble);
      mb.box(1.35, 0.03, 0.7, 1.85, 1.15, 1.3, PAL.marble);
      mb.box(0.12, 0.03, 0.67, 0.68, 0.14, 1.33, PAL.marbleShade);
      mb.box(1.32, 0.03, 0.67, 1.88, 0.14, 1.33, PAL.marbleShade);
      mb.box(0.15, 1.15, 0.7, 1.85, 1.62, 1.3, PAL.marble);
      mb.box(0.12, 1.12, 0.67, 1.88, 1.17, 1.33, PAL.marbleShade);
      mb.box(0.12, 1.6, 0.67, 1.88, 1.65, 1.33, PAL.marbleShade);
      for (let i = 0; i < 14; i++) {
        const a0 = i / 14 * Math.PI, a1 = (i + 1) / 14 * Math.PI, r = 0.35, y = 0.8;
        const p = (a, z) => [1 + Math.cos(a) * r, y + Math.sin(a) * r, z];
        mb.quad(p(a0, 0.7), p(a1, 0.7), p(a1, 1.3), p(a0, 1.3), lin(PAL.marbleShade), 0);
        for (const z of [1.301, 0.699]) mb.tri([1 + Math.cos(a0) * r, y + Math.sin(a0) * r, z], [1 + Math.cos(a1) * r, y + Math.sin(a1) * r, z], [1 + Math.cos((a0 + a1) / 2) * 0.66, 1.15, z], lin(PAL.marble));
      }
      mb.box(0.65, 0.03, 0.7, 1.35, 0.8, 0.705, PAL.marbleShade);
      for (const x of [0.25, 0.55, 1.45, 1.75]) { column(mb, x, 1.38, 0.14, 1.0, 0.048); column(mb, x, 0.62, 0.14, 1.0, 0.048); }
      mb.box(0.3, 1.25, 1.3, 1.7, 1.5, 1.32, '#c9a050', { ao: 1 });
      for (let i = 0; i < 3; i++) mb.box(0.2 + i * 0.03, 0.4 + i * 0.25, 1.3, 0.6 - i * 0.03, 0.52 + i * 0.25, 1.315, '#e6d8b8', { ao: 1 });
      mb.box(0.75, 1.65, 0.85, 1.25, 1.75, 1.15, PAL.bronze);
      for (let i = 0; i < 4; i++) {
        const x = 0.76 + i * 0.16;
        mb.box(x - 0.03, 1.75, 0.9, x + 0.03, 1.91, 1.12, PAL.gold);
        mb.box(x - 0.025, 1.89, 1.08, x + 0.025, 2.0, 1.16, PAL.gold);
      }
      mb.cyl(0.78, 1.75, 1.0, 0.07, 0.02, PAL.gold, { segs: 10 });
      statueFigure(mb, 1.0, 0.95, 1.75, 0.6, PAL.gold, true);
      break;
  }
}

/* ---------- Сводная функция: модель для здания ---------- */

const VARIANTS = { house: [1, 3, 3, 3, 3], domus: [1, 1, 1, 1, 1] };

function variantOf(b) {
  const v = VARIANTS[b.type];
  if (!v) return 0;
  const n = v[b.tier || 0];
  return Math.floor(hash2(b.id, 7, 13) * n);
}

function modelKey(b) {
  const d = BUILDINGS[b.type];
  if (d.kind === 'house') return `${b.type}:${b.tier}:${variantOf(b)}:${b.id % 12}`;
  if (b.type === 'flowers' || b.type === 'mosaic') return `${b.type}:${b.id % 6}`;
  if (b.type === 'market' || b.type === 'fountain') return `${b.type}:${b.id % 5}`;
  if (b.type === 'center') return `center:${b.tier || 0}`;
  return b.type;
}

const ModelCache = new Map();

function buildModel(b, lod) {
  const key = modelKey(b) + (lod ? '#lod' : '');
  let m = ModelCache.get(key);
  if (m) return m;
  MODEL_LOD = !!lod;
  try { m = buildModelNow(b); } finally { MODEL_LOD = false; }
  // из какого здания построена модель: облегчённую строим из него же — с тем же зерном случайности
  m.src = { ...b };
  ModelCache.set(key, m);
  return m;
}

function buildModelNow(b) {
  let m;
  const d = BUILDINGS[b.type];
  const mb = new MB(b.id * 31 + 7);
  // у домов внешний вид зависит только от ключа модели — тогда одинаковые дома рисуются одной пачкой
  const info = { id: d.kind === 'house' ? b.id % 12 + 12 : b.id, type: b.type, tier: b.tier || 0, variant: variantOf(b) };
  if (b.type === 'house') plebHouse(mb, info);
  else if (b.type === 'domus') patricianHouse(mb, info);
  else if (b.type === 'center') centerModel(mb, info);
  else if (d.kind === 'decor') decorModel(mb, info);
  else if (d.kind === 'wonder') wonderModel(mb, info);
  else if (d.kind === 'producer' || d.kind === 'storage') productionModel(mb, info);
  else serviceModel(mb, info);
  m = mb.build(d.w / 2, d.h / 2);
  m.smoke = (mb.smoke || []).map(([x, y, z]) => [x - d.w / 2, y, z - d.h / 2]);
  m.lights = (mb.lights || []).map(([x, y, z, r]) => [x - d.w / 2, y, z - d.h / 2, r]);
  m.fountain = (mb.fountain || []).map(([x, y, z, r]) => [x - d.w / 2, y, z - d.h / 2, r]);
  return m;
}
