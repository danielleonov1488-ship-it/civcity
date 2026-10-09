'use strict';
/* Мини-карта — круглый «медальон» в правом нижнем углу: своя земля (трава, лес, вода, песок), дороги и площади,
   дома точками, чужие участки приглушены, рамка — что сейчас видит камера. Карта повёрнута вместе с камерой:
   «вверх» на ней — это «вперёд» на экране. Клик или перетаскивание по карте переносит камеру туда. */
const Minimap = {
  size: 172,
  dirty: true,         // перерисовать подложку (земля, дороги, дома)
  sig: '',
  next: 0,
  drawnAt: 0,
  view: null,          // { cx, cz, scale } — как клетки мира ложатся на подложку

  init() {
    this.el = $('minimap');
    this.cv = $('mm-canvas');
    if (!this.el || !this.cv) return;
    const dpr = Math.min(2, window.devicePixelRatio || 1);
    this.cv.width = this.cv.height = Math.round(this.size * dpr);
    this.dpr = dpr;
    this.ctx = this.cv.getContext('2d');
    this.base = document.createElement('canvas');
    let collapsed = false;
    try { collapsed = localStorage.getItem('civcity.minimap') === '0'; } catch (e) { /* нет хранилища */ }
    this.setCollapsed(collapsed);
    $('mm-toggle').onclick = () => this.setCollapsed(!this.el.classList.contains('collapsed'));
    // клик и перетаскивание — перелёт камеры
    let drag = false;
    const go = (e, smooth) => {
      const w = this.toWorld(e);
      if (!w) return;
      if (smooth) Engine.lookAt(w[0], w[1]);
      else { const c = Engine.cam; c.x = c.tx = w[0]; c.z = c.tz = w[1]; }
    };
    this.cv.addEventListener('pointerdown', e => { e.preventDefault(); e.stopPropagation(); drag = true; this.cv.setPointerCapture && this.cv.setPointerCapture(e.pointerId); go(e, true); });
    this.cv.addEventListener('pointermove', e => { if (drag) go(e, false); });
    this.cv.addEventListener('pointerup', () => { drag = false; });
    this.cv.addEventListener('pointercancel', () => { drag = false; });
    this.cv.addEventListener('wheel', e => { e.preventDefault(); Engine.zoom(e.deltaY > 0 ? 1.12 : 1 / 1.12); }, { passive: false });
  },

  setCollapsed(on) {
    this.el.classList.toggle('collapsed', on);
    $('mm-toggle').setAttribute('aria-label', on ? 'Показать карту' : 'Свернуть карту');
    try { localStorage.setItem('civcity.minimap', on ? '0' : '1'); } catch (e) { /* нет хранилища */ }
    this.drawnAt = 0;
  },

  // Какую часть мира показывать: свои участки и по одному соседнему вокруг
  extent() {
    let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
    for (const k of state.plots) {
      const [px, py] = k.split(',').map(Number);
      x0 = Math.min(x0, px); y0 = Math.min(y0, py); x1 = Math.max(x1, px); y1 = Math.max(y1, py);
    }
    if (x0 === Infinity) { x0 = y0 = x1 = y1 = 0; }
    return { tx0: (x0 - 1) * PLOT, ty0: (y0 - 1) * PLOT, tx1: (x1 + 2) * PLOT, ty1: (y1 + 2) * PLOT };
  },

  // Земля по пикселю на клетку — меняется редко (новый участок, вырубка), поэтому рисуется отдельно и хранится
  drawTerrain(ex, W, H) {
    const key = ex.tx0 + ',' + ex.ty0 + ',' + W + ',' + H + ':' + state.plots.size + ':' + state.cleared.size;
    if (this.terrain && this.terrainKey === key) return this.terrain;
    this.terrainKey = key;
    const img = new ImageData(W, H), d = img.data;
    const rgb = hex => [parseInt(hex.slice(1, 3), 16), parseInt(hex.slice(3, 5), 16), parseInt(hex.slice(5, 7), 16)];
    const GR = GROUND_HEX.map(rgb), FOREST = rgb('#5d8a45'), ROCK = rgb('#a8a294'), WATER = rgb('#78b3cf'), DEEP = rgb('#5f9fc0');
    for (let ty = 0; ty < H; ty++) {
      for (let tx = 0; tx < W; tx++) {
        const x = ex.tx0 + tx, y = ex.ty0 + ty, gt = groundAt(x, y);
        let c = gt === G_WATER ? WATER : gt === G_DEEP ? DEEP : GR[gt] || GR[0];
        if (!isWater(gt)) {
          const px = plotOf(x), py = plotOf(y), t = plotTerrain(px, py);
          const n = t.nature[(y - py * PLOT) * PLOT + (x - px * PLOT)];
          if (n && !state.cleared.has(tkey(x, y))) c = n === N_OAK || n === N_PINE || n === N_CYPRESS || n === N_BUSH ? FOREST : n === N_FLOWERS ? c : ROCK;
        }
        const o = (ty * W + tx) * 4, own = isOwnedTile(x, y);
        // чужая земля — приглушённая, как на большой карте
        d[o] = own ? c[0] : c[0] * 0.62 + 183 * 0.38; d[o + 1] = own ? c[1] : c[1] * 0.62 + 178 * 0.38; d[o + 2] = own ? c[2] : c[2] * 0.62 + 154 * 0.38; d[o + 3] = 255;
      }
    }
    const t = this.terrain || (this.terrain = document.createElement('canvas'));
    t.width = W; t.height = H;
    t.getContext('2d').putImageData(img, 0, 0);
    return t;
  },

  // Подложка: земля, сверху дороги и дома (по 3 пикселя на клетку — так они видны чётче)
  drawBase() {
    const ex = this.extent(), W = ex.tx1 - ex.tx0, H = ex.ty1 - ex.ty0;
    const k = 3;
    const b = this.base;
    if (b.width !== W * k || b.height !== H * k) { b.width = W * k; b.height = H * k; }
    const g = b.getContext('2d');
    g.setTransform(1, 0, 0, 1, 0, 0);
    g.imageSmoothingEnabled = false;
    g.drawImage(this.drawTerrain(ex, W, H), 0, 0, W * k, H * k);
    g.setTransform(k, 0, 0, k, -ex.tx0 * k, -ex.ty0 * k);
    // площади и дороги
    g.fillStyle = '#e8dcc0';
    for (const key of Roads.plaza) { const [x, y] = key.split(',').map(Number); g.fillRect(x, y, 1, 1); }
    g.strokeStyle = '#efe4c8'; g.lineCap = 'round'; g.lineJoin = 'round'; g.lineWidth = ROAD_HALF * 2 + 0.3;
    for (const e of Roads.edges.values()) {
      if (!e.xy || e.xy.length < 4) continue;
      g.beginPath();
      g.moveTo(e.xy[0], e.xy[1]);
      for (let i = 2; i < e.xy.length; i += 2) g.lineTo(e.xy[i], e.xy[i + 1]);
      g.stroke();
    }
    // дома и постройки — по цвету рода
    const COL = { house: '#c8553d', wonder: '#e9b949', producer: '#9a6a3a', storage: '#9a6a3a', decor: '#6f9a4a' };
    for (const bd of state.buildings.values()) {
      const def = BUILDINGS[bd.type];
      if (!def || bd.type === 'road') continue;
      g.save();
      g.translate(bd.x + bd.w / 2, bd.y + bd.h / 2);
      g.rotate(-bAng(bd));
      g.fillStyle = COL[def.kind] || '#d9b98a';
      const s = def.kind === 'decor' ? 0.7 : 1;
      g.fillRect(-bd.w / 2 * s, -bd.h / 2 * s, bd.w * s, bd.h * s);
      g.restore();
    }
    g.setTransform(1, 0, 0, 1, 0, 0);
    this.view = { tx0: ex.tx0, ty0: ex.ty0, W, H, k };
  },

  // Подпись того, из чего сложена подложка: поменялось — перерисовать
  signature() {
    return state.plots.size + ':' + Roads.version + ':' + state.buildings.size + ':' + state.cleared.size;
  },

  // Как точка мира ложится на круг: центр круга — середина своей земли, поворот — как у камеры
  layout() {
    const v = this.view, D = this.size;
    const scale = (D - 10) / Math.hypot(v.W, v.H) * 1.2;   // чуть крупнее — углы за краем круга не жалко
    return { cx: v.tx0 + v.W / 2, cz: v.ty0 + v.H / 2, scale, rot: Engine.cam.yaw };
  },

  toWorld(e) {
    if (!this.view) return null;
    const r = this.cv.getBoundingClientRect();
    const L = this.layout();
    const sx = (e.clientX - r.left) * this.size / r.width - this.size / 2, sy = (e.clientY - r.top) * this.size / r.height - this.size / 2;
    // обратный поворот
    const c = Math.cos(-L.rot), s = Math.sin(-L.rot);
    const wx = (sx * c - sy * s) / L.scale, wy = (sx * s + sy * c) / L.scale;
    return [L.cx + wx, L.cz + wy];
  },

  update() {
    if (!this.ctx || this.el.classList.contains('collapsed') || document.body.classList.contains('ui-hidden')) return;
    const now = performance.now();
    if (now > this.next) {
      this.next = now + 600;
      const sig = this.signature();
      if (sig !== this.sig) { this.sig = sig; this.dirty = true; }
    }
    if (this.dirty) { this.dirty = false; this.drawBase(); this.drawnAt = 0; }
    // кадр карты — не чаще 20 раз в секунду
    if (now - this.drawnAt < 50) return;
    this.drawnAt = now;
    const g = this.ctx, D = this.size, L = this.layout(), v = this.view;
    g.setTransform(this.dpr, 0, 0, this.dpr, 0, 0);
    g.clearRect(0, 0, D, D);
    g.save();
    g.beginPath(); g.arc(D / 2, D / 2, D / 2 - 1, 0, Math.PI * 2); g.clip();
    g.fillStyle = '#c9c2a4'; g.fillRect(0, 0, D, D);
    g.translate(D / 2, D / 2);
    g.rotate(L.rot);
    g.scale(L.scale, L.scale);
    g.translate(-L.cx, -L.cz);
    g.imageSmoothingEnabled = true;
    g.drawImage(this.base, v.tx0, v.ty0, v.W, v.H);
    // рамка обзора: углы экрана, опущенные на землю
    const pts = [[0, 0], [Engine.W, 0], [Engine.W, Engine.H], [0, Engine.H]].map(([x, y]) => this.ground(x, y));
    if (pts.every(Boolean)) {
      g.beginPath();
      pts.forEach(([x, z], i) => i ? g.lineTo(x, z) : g.moveTo(x, z));
      g.closePath();
      g.fillStyle = 'rgba(255, 250, 235, 0.22)'; g.fill();
      g.lineWidth = 2 / L.scale; g.strokeStyle = '#fff6dc'; g.stroke();
    }
    g.restore();
  },

  // Точка земли под точкой экрана; у горизонта луч уходит в небо — тогда берём точку подальше по лучу
  ground(sx, sy) {
    const p = Engine.groundPoint(sx, sy);
    if (p) {
      const c = Engine.cam, dx = p[0] - c.x, dz = p[1] - c.z, d = Math.hypot(dx, dz), lim = c.dist * 3;
      return d > lim ? [c.x + dx / d * lim, c.z + dz / d * lim] : p;
    }
    const r = Engine.raycaster.ray, lim = Engine.cam.dist * 3;
    return [r.origin.x + r.direction.x * lim, r.origin.z + r.direction.z * lim];
  },
};
