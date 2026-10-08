'use strict';
/* Управление: камера (сдвиг, масштаб, поворот), выбор инструмента, стройка мышью и пальцами. */

const Input = {
  tool: null,          // тип постройки, 'bulldoze' или null
  hover: null,         // дробные координаты клетки под курсором
  mouse: [0, 0],
  pointers: new Map(),
  mode: null,          // pan | rotate | maybe | road | paint | place | pinch
  start: null,
  anchor: null,
  moved: false,
  roadStart: null,
  roadTiles: [],
  lastPaint: null,
  pinch: null,
  keys: new Set(),
  lastWarn: 0,
  lastGhostKey: '',

  init(canvas) {
    canvas.addEventListener('contextmenu', e => e.preventDefault());
    canvas.addEventListener('pointerdown', e => this.down(e));
    canvas.addEventListener('pointermove', e => this.move(e));
    canvas.addEventListener('pointerup', e => this.up(e));
    canvas.addEventListener('pointercancel', e => this.up(e, true));
    canvas.addEventListener('pointerleave', () => { if (!this.pointers.size) this.hover = null; });
    canvas.addEventListener('wheel', e => {
      e.preventDefault();
      const f = Math.exp(e.deltaY * 0.0012);
      const p = Engine.groundPoint(e.clientX, e.clientY);
      const before = Engine.cam.distTarget;
      Engine.zoom(f);
      const real = Engine.cam.distTarget / before;
      if (p && real < 1) {
        const c = Engine.cam, tx = c.tx === undefined ? c.x : c.tx, tz = c.tz === undefined ? c.z : c.tz;
        Engine.lookAt(tx + (p[0] - tx) * (1 - real), tz + (p[1] - tz) * (1 - real));
      }
    }, { passive: false });
    window.addEventListener('keydown', e => this.keyDown(e));
    window.addEventListener('keyup', e => this.keys.delete(e.key.toLowerCase()));
    window.addEventListener('blur', () => this.keys.clear());
  },

  setTool(tool) {
    this.tool = tool;
    this.mode = null;
    this.roadTiles = [];
    this.lastGhostKey = '';
    if (!tool) Engine.setGhost(null);
    Engine.canvasCursor = tool ? 'crosshair' : 'default';
    Engine.renderer.domElement.style.cursor = Engine.canvasCursor;
    UI.onToolChanged();
  },

  tileUnder(x, y) { return Engine.groundPoint(x, y); },

  down(e) {
    Engine.renderer.domElement.setPointerCapture(e.pointerId);
    this.pointers.set(e.pointerId, [e.clientX, e.clientY]);
    this.mouse = [e.clientX, e.clientY];
    this.hover = this.tileUnder(e.clientX, e.clientY);

    if (this.pointers.size === 2) {
      const [a, b] = [...this.pointers.values()];
      this.mode = 'pinch';
      this.roadTiles = [];
      this.pinch = {
        d: Math.hypot(a[0] - b[0], a[1] - b[1]), dist: Engine.cam.distTarget,
        ang: Math.atan2(b[1] - a[1], b[0] - a[0]), yaw: Engine.cam.yawTarget,
        mid: [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2],
      };
      return;
    }
    if (this.pointers.size > 2) return;

    this.start = [e.clientX, e.clientY];
    this.moved = false;
    this.anchor = this.hover;
    if (e.button === 2) { this.mode = 'pan'; return; }
    if (e.button === 1) { this.mode = 'rotate'; return; }

    const tool = this.tool;
    if (!tool || !this.hover) { this.mode = 'maybe'; return; }
    const [fx, fy] = this.hover;
    if (tool === 'road') {
      this.mode = 'road';
      this.roadStart = [Math.floor(fx), Math.floor(fy)];
      this.roadTiles = [this.roadStart];
    } else if (tool === 'bulldoze' || BUILDINGS[tool].w === 1) {
      this.mode = 'paint';
      this.lastPaint = null;
      this.paint(fx, fy);
    } else {
      this.mode = 'place';
    }
  },

  move(e) {
    if (this.pointers.has(e.pointerId)) this.pointers.set(e.pointerId, [e.clientX, e.clientY]);
    const prev = this.mouse;
    this.mouse = [e.clientX, e.clientY];

    if (this.mode === 'pinch' && this.pointers.size === 2) {
      const [a, b] = [...this.pointers.values()];
      const d = Math.hypot(a[0] - b[0], a[1] - b[1]);
      Engine.cam.distTarget = clamp(this.pinch.dist * this.pinch.d / d, DIST_MIN, DIST_MAX);
      const ang = Math.atan2(b[1] - a[1], b[0] - a[0]);
      Engine.cam.yawTarget = this.pinch.yaw - (ang - this.pinch.ang);
      const mid = [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2];
      const p0 = Engine.groundPoint(this.pinch.mid[0], this.pinch.mid[1]), p1 = Engine.groundPoint(mid[0], mid[1]);
      if (p0 && p1) Engine.panBy(p0[0] - p1[0], p0[1] - p1[1]);
      this.pinch.mid = mid;
      return;
    }

    if (this.start && Math.hypot(e.clientX - this.start[0], e.clientY - this.start[1]) > 6) this.moved = true;

    if (this.mode === 'rotate') {
      Engine.cam.yawTarget -= (e.clientX - prev[0]) * 0.008;
      Engine.cam.yaw = Engine.cam.yawTarget;
      return;
    }
    if (this.mode === 'pan' || (this.mode === 'maybe' && this.moved)) {
      this.mode = 'pan';
      const cur = Engine.groundPoint(e.clientX, e.clientY);
      if (this.anchor && cur) Engine.panBy(this.anchor[0] - cur[0], this.anchor[1] - cur[1]);
      return;
    }

    this.hover = this.tileUnder(e.clientX, e.clientY);
    if (!this.hover) return;
    if (this.mode === 'road') {
      const [fx, fy] = this.hover;
      this.roadTiles = roadPath(this.roadStart[0], this.roadStart[1], Math.floor(fx), Math.floor(fy));
    } else if (this.mode === 'paint') {
      this.paint(this.hover[0], this.hover[1]);
    }
  },

  up(e, cancelled) {
    this.pointers.delete(e.pointerId);
    const mode = this.mode;
    if (this.pointers.size > 0) {
      if (mode === 'pinch') this.mode = 'pinched';
      return;
    }
    this.mode = null;
    this.anchor = null;
    if (cancelled || mode === 'pinched' || mode === 'pinch') { this.roadTiles = []; return; }

    if (mode === 'pan' && e.button === 2 && !this.moved) { this.setTool(null); return; }
    if (mode === 'road') { this.commitRoad(); return; }
    if (mode === 'place' && this.hover) {
      const [x, y] = footprintOrigin(this.tool, this.hover[0], this.hover[1]);
      this.tryPlace(this.tool, x, y, true);
      return;
    }
    if (mode === 'maybe' && !this.moved) this.click(e.clientX, e.clientY);
  },

  keyDown(e) {
    if (e.target && (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA')) return;
    const k = e.key.toLowerCase();
    if (k === 'escape') {
      if (UI.closeModal()) return;
      if (UI.closeWindow()) return;
      if (this.tool) { this.setTool(null); return; }
      if (UI.selected) { UI.closePanel(); return; }
      if (UI.openCat) UI.closeTray();
      return;
    }
    if (UI.blocking()) return;
    if (k === ' ') { e.preventDefault(); UI.togglePause(); return; }
    if (['w', 'a', 's', 'd', 'arrowup', 'arrowdown', 'arrowleft', 'arrowright', 'ц', 'ф', 'ы', 'в'].includes(k)) {
      this.keys.add(k);
      if (k.startsWith('arrow')) e.preventDefault();
      return;
    }
    if (k === 'q' || k === 'й') Engine.rotate(-1);
    if (k === 'e' || k === 'у') Engine.rotate(1);
    if (k === 'r' || k === 'к') this.setTool('road');
    if (k === 'h' || k === 'р') this.setTool('house');
    if (k === 'x' || k === 'ч' || k === 'delete') this.setTool('bulldoze');
    if (k === 'f' || k === 'а') UI.openWindow('research');
    if (k === 'l' || k === 'д') UI.openWindow('legion');
    if (k === '1') UI.setSpeed(1);
    if (k === '2') UI.setSpeed(2);
    if (k === '3') UI.setSpeed(4);
    if (k === '+' || k === '=') Engine.zoom(1 / 1.2);
    if (k === '-') Engine.zoom(1.2);
  },

  // Плавная прокрутка клавишами — относительно поворота камеры
  update(dt) {
    let dx = 0, dy = 0;
    const has = (...ks) => ks.some(k => this.keys.has(k));
    if (has('w', 'ц', 'arrowup')) dy -= 1;
    if (has('s', 'ы', 'arrowdown')) dy += 1;
    if (has('a', 'ф', 'arrowleft')) dx -= 1;
    if (has('d', 'в', 'arrowright')) dx += 1;
    if (dx || dy) {
      const sp = Engine.cam.dist * 0.9 * dt;
      const yaw = Engine.cam.yaw;
      const fx = -Math.sin(yaw), fz = -Math.cos(yaw);
      const rx = Math.cos(yaw), rz = -Math.sin(yaw);
      Engine.panBy((rx * dx - fx * dy) * sp, (rz * dx - fz * dy) * sp);
    }
    this.updateOverlays();
  },

  warn(msg) {
    const t = performance.now();
    if (t - this.lastWarn < 1500) return;
    this.lastWarn = t;
    UI.toast(msg, 'warn');
  },

  tryPlace(type, x, y, loud) {
    const err = checkPlace(type, x, y);
    if (err) { if (loud || err.startsWith('Не хватает')) this.warn(err); return null; }
    const b = placeBuilding(type, x, y);
    Engine.dust(b);
    afterCityChanged();
    return b;
  },

  paint(fx, fy) {
    const tx = Math.floor(fx), ty = Math.floor(fy);
    const key = tkey(tx, ty);
    if (this.lastPaint === key) return;
    this.lastPaint = key;
    if (this.tool === 'bulldoze') {
      const b = buildingAt(tx, ty);
      if (b) {
        removeBuilding(b, true);
        Engine.dust(b);
        afterCityChanged();
      } else if (isOwnedTile(tx, ty) && natureAt(tx, ty)) {
        state.cleared.add(key);
        Engine.natureChanged(tx, ty);
        Engine.puff(tx + 0.5, 0.3, ty + 0.5, '#7fa64e', 8, 0.5, 1, 0.12, 0.7);
      }
      return;
    }
    const [x, y] = footprintOrigin(this.tool, fx, fy);
    this.tryPlace(this.tool, x, y, false);
  },

  commitRoad() {
    const tiles = this.roadTiles;
    this.roadTiles = [];
    let built = 0, blocked = false;
    for (const [x, y] of tiles) {
      if (isRoad(x, y)) continue;
      const err = checkPlace('road', x, y);
      if (err) { if (err.startsWith('Не хватает')) { this.warn(err); break; } blocked = true; continue; }
      placeBuilding('road', x, y);
      built++;
    }
    if (built) afterCityChanged();
    if (blocked && !built) this.warn('Здесь дорогу не проложить');
  },

  click(sx, sy) {
    const b = Engine.pickBuilding(sx, sy);
    if (b) { UI.openPanel(b); return; }
    const p = Engine.groundPoint(sx, sy);
    if (!p) return;
    const tx = Math.floor(p[0]), ty = Math.floor(p[1]);
    const r = buildingAt(tx, ty);
    if (r) { UI.openPanel(r); return; }
    const px = plotOf(tx), py = plotOf(ty);
    if (canBuyPlot(px, py)) { UI.openBuyPlot(px, py); return; }
    UI.closePanel();
  },

  /* ---------- Подсказки стройки: призрак, радиус, подсветка ---------- */

  updateOverlays() {
    const tool = this.tool;
    const quads = [];
    let ring = null;
    Engine.updateGrid(!!tool);

    if (tool && this.hover && this.mode !== 'pan' && this.mode !== 'pinch' && this.mode !== 'rotate') {
      const [fx, fy] = this.hover;
      if (tool === 'bulldoze') {
        Engine.setGhost(null);
        const tx = Math.floor(fx), ty = Math.floor(fy);
        const b = buildingAt(tx, ty);
        if (b) quads.push([b.x, b.y, b.w, b.h, '#e0583e']);
        else quads.push([tx, ty, 1, 1, '#e0583e']);
      } else if (tool === 'road') {
        Engine.setGhost(null);
        const tiles = this.mode === 'road' ? this.roadTiles : [[Math.floor(fx), Math.floor(fy)]];
        for (const [x, y] of tiles) {
          if (isRoad(x, y)) continue;
          const ok = isOwnedTile(x, y) && !isWater(groundAt(x, y)) && !World.occ.has(tkey(x, y));
          quads.push([x, y, 1, 1, ok ? '#e8dcb8' : '#e0583e']);
        }
      } else {
        const d = BUILDINGS[tool];
        const [x, y] = footprintOrigin(tool, fx, fy);
        const err = checkPlace(tool, x, y);
        const probe = { type: tool, x, y, w: d.w, h: d.h, rot: 0 };
        const rot = d.kind === 'decor' ? 0 : orientToRoad(probe);
        Engine.setGhost(tool, x, y, !err, rot);
        if (d.radius) ring = [x + d.w / 2, y + d.h / 2, d.radius, probe];
        const key = `${tool}:${x}:${y}`;
        if (key !== this.lastGhostKey) {
          this.lastGhostKey = key;
          UI.setToolStatus(tool, x, y, err);
        }
      }
    } else if (!tool && UI.selected && BUILDINGS[UI.selected.type].radius) {
      const b = UI.selected;
      ring = [b.x + b.w / 2, b.y + b.h / 2, BUILDINGS[b.type].radius, b];
    }

    if (ring) {
      const [cx, cz, r, src] = ring;
      Engine.setRadius(cx, cz, r);
      for (const h of state.buildings.values()) {
        if (BUILDINGS[h.type].kind !== 'house' || dist2(h, src) > r * r) continue;
        quads.push([h.x + 0.05, h.y + 0.05, h.w - 0.1, h.h - 0.1, '#7ccf6a']);
      }
    } else Engine.setRadius(0, 0, 0);
    Engine.setQuads(quads);
  },
};
