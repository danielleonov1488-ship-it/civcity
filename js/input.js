'use strict';
/* Управление: камера (сдвиг, масштаб, поворот), выбор инструмента, стройка мышью и пальцами.
   Стройка без клеток: дорогу рисуют мышью (с Shift — по линейке), дом у дороги сам встаёт фасадом к ней,
   вдали от дорог и украшения поворачиваются клавишами Z / C или колёсиком с Shift. */

const ROT_STEP = Math.PI / 12;   // поворот постройки за одно нажатие — 15°

const Input = {
  tool: null,          // тип постройки, 'bulldoze' или null
  hover: null,         // точка земли под курсором (в клетках, дробная)
  mouse: [0, 0],
  pointers: new Map(),
  mode: null,          // pan | rotate | maybe | road | paint | place | pinch
  start: null,
  anchor: null,
  moved: false,
  roadRaw: [],         // путь мыши при прокладке дороги
  roadPlan: null,      // готовая к постройке дорога
  shift: false,
  angle: 0,            // поворот постройки вдали от дорог
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
      if (Battle.active) return;
      // колёсико с Shift поворачивает постройку
      if (e.shiftKey && this.tool && this.tool !== 'road' && this.tool !== 'bulldoze') { this.rotate(e.deltaY > 0 ? 1 : -1); return; }
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
    window.addEventListener('keyup', e => { this.keys.delete(e.key.toLowerCase()); this.shift = e.shiftKey; });
    window.addEventListener('blur', () => { this.keys.clear(); this.shift = false; });
  },

  setTool(tool) {
    this.tool = tool;
    this.mode = null;
    this.roadRaw = [];
    this.roadPlan = null;
    this.lastGhostKey = '';
    if (!tool) Engine.setGhost(null);
    Engine.setRoadPreview(null);
    Engine.canvasCursor = tool ? 'crosshair' : 'default';
    Engine.renderer.domElement.style.cursor = Engine.canvasCursor;
    UI.onToolChanged();
  },

  rotate(dir) {
    this.angle = normAng(this.angle + dir * ROT_STEP);
    this.lastGhostKey = '';
  },

  tileUnder(x, y) { return Engine.groundPoint(x, y); },

  // Куда встанет выбранная постройка под курсором
  placement(type, fx, fy) { return snapPlace(type, fx, fy, this.angle); },

  down(e) {
    if (Battle.active) return;
    Engine.renderer.domElement.setPointerCapture(e.pointerId);
    this.pointers.set(e.pointerId, [e.clientX, e.clientY]);
    this.mouse = [e.clientX, e.clientY];
    this.shift = e.shiftKey;
    this.hover = this.tileUnder(e.clientX, e.clientY);

    if (this.pointers.size === 2) {
      const [a, b] = [...this.pointers.values()];
      this.mode = 'pinch';
      this.roadRaw = [];
      this.roadPlan = null;
      Engine.setRoadPreview(null);
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
      this.roadRaw = [[fx, fy]];
      this.roadPlan = null;
    } else if (tool === 'bulldoze' || BUILDINGS[tool].w === 1) {
      this.mode = 'paint';
      this.lastPaint = null;
      this.paint(fx, fy);
    } else {
      this.mode = 'place';
    }
  },

  move(e) {
    if (Battle.active) return;
    if (this.pointers.has(e.pointerId)) this.pointers.set(e.pointerId, [e.clientX, e.clientY]);
    const prev = this.mouse;
    this.mouse = [e.clientX, e.clientY];
    this.shift = e.shiftKey;

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
      const last = this.roadRaw[this.roadRaw.length - 1];
      if (Math.hypot(this.hover[0] - last[0], this.hover[1] - last[1]) >= 0.2) this.roadRaw.push(this.hover.slice());
      this.planRoad();
    } else if (this.mode === 'paint') {
      this.paint(this.hover[0], this.hover[1]);
    }
  },

  planRoad() {
    const raw = this.roadRaw.length > 1 ? this.roadRaw : null;
    this.roadPlan = raw ? Roads.plan(raw, this.shift) : null;
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
    if (cancelled || mode === 'pinched' || mode === 'pinch') { this.roadRaw = []; this.roadPlan = null; Engine.setRoadPreview(null); return; }

    if (mode === 'pan' && e.button === 2 && !this.moved) { this.setTool(null); return; }
    if (mode === 'road') { this.commitRoad(); return; }
    if (mode === 'place' && this.hover) {
      this.tryPlace(this.tool, this.placement(this.tool, this.hover[0], this.hover[1]), true);
      return;
    }
    if (mode === 'maybe' && !this.moved) this.click(e.clientX, e.clientY);
  },

  keyDown(e) {
    if (Battle.active) return;
    if (e.target && (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA')) return;
    const k = e.key.toLowerCase();
    this.shift = e.shiftKey;
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
    if (k === 'shift' && this.mode === 'road') this.planRoad();
    if (k === 'q' || k === 'й') Engine.rotate(-1);
    if (k === 'e' || k === 'у') Engine.rotate(1);
    if (k === 'z' || k === 'я') this.rotate(-1);
    if (k === 'c' || k === 'с') this.rotate(1);
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

  tryPlace(type, p, loud) {
    const err = checkPlace(type, p.cx, p.cy, p.ang);
    if (err) { if (loud || err.startsWith('Не хватает')) this.warn(err); return null; }
    const b = placeBuilding(type, p.cx, p.cy, p.ang);
    Engine.dust(b);
    afterCityChanged();
    return b;
  },

  paint(fx, fy) {
    const last = this.lastPaint;
    if (this.tool === 'bulldoze') {
      if (last && Math.hypot(fx - last[0], fy - last[1]) < 0.35) return;
      this.lastPaint = [fx, fy];
      const b = buildingAtPoint(fx, fy);
      if (b) {
        removeBuilding(b, true);
        Engine.dust(b);
        afterCityChanged();
        return;
      }
      if (Roads.inPlaza(fx, fy)) {
        Roads.removePlaza(Math.floor(fx), Math.floor(fy));
        Roads.removeAt(fx, fy);
        Engine.puff(fx, 0.2, fy, '#d8cdb2', 10, 0.6, 1, 0.12, 0.6);
        afterCityChanged();
        return;
      }
      if (Roads.nearest(fx, fy, ROAD_HALF)) {
        const len = Roads.removeAt(fx, fy);
        if (len) {
          for (const [res, v] of Object.entries(BUILDINGS.road.cost)) if (res === 'money') state.money += Math.floor(v * len * REFUND_SHARE);
          Engine.puff(fx, 0.2, fy, '#d8cdb2', 10, 0.6, 1, 0.12, 0.6);
          afterCityChanged();
        }
        return;
      }
      const tx = Math.floor(fx), ty = Math.floor(fy), key = tkey(tx, ty);
      if (isOwnedTile(tx, ty) && natureAt(tx, ty)) {
        state.cleared.add(key);
        Engine.natureChanged(tx, ty);
        Engine.puff(tx + 0.5, 0.3, ty + 0.5, '#7fa64e', 8, 0.5, 1, 0.12, 0.7);
      }
      return;
    }
    // мелкие постройки и украшения рисуются мазком: следующая — на шаг дальше предыдущей
    if (last && Math.hypot(fx - last[0], fy - last[1]) < 0.85) return;
    if (this.tryPlace(this.tool, this.placement(this.tool, fx, fy), false)) this.lastPaint = [fx, fy];
  },

  commitRoad() {
    this.planRoad();
    const plan = this.roadPlan;
    this.roadRaw = [];
    this.roadPlan = null;
    Engine.setRoadPreview(null);
    if (!plan || plan.L < 0.6) return;
    if (plan.err) { this.warn(plan.err); return; }
    pay(plan.cost);
    Roads.build(plan);
    afterCityChanged();
  },

  click(sx, sy) {
    const b = Engine.pickBuilding(sx, sy);
    if (b) { UI.openPanel(b); return; }
    const p = Engine.groundPoint(sx, sy);
    if (!p) return;
    const r = buildingAtPoint(p[0], p[1]);
    if (r) { UI.openPanel(r); return; }
    const px = plotOf(Math.floor(p[0])), py = plotOf(Math.floor(p[1]));
    if (canBuyPlot(px, py)) { UI.openBuyPlot(px, py); return; }
    UI.closePanel();
  },

  /* ---------- Подсказки стройки: призрак, радиус, подсветка ---------- */

  updateOverlays() {
    const tool = this.tool;
    const quads = [];
    let ring = null, preview = null;
    Engine.updateGrid(false);

    if (tool && this.hover && this.mode !== 'pan' && this.mode !== 'pinch' && this.mode !== 'rotate') {
      const [fx, fy] = this.hover;
      if (tool === 'bulldoze') {
        Engine.setGhost(null);
        const b = buildingAtPoint(fx, fy);
        const q = !b && Roads.nearest(fx, fy, ROAD_HALF);
        if (b) quads.push([b.x + b.w / 2, b.y + b.h / 2, b.w, b.h, '#e0583e', bAng(b)]);
        else if (q) {
          const pts = [];
          for (let s = Math.max(0, q.s - 0.6); s <= Math.min(q.e.L, q.s + 0.6) + 1e-6; s += 0.2) { const p = Roads.pointAt(q.e, s); pts.push(p.x, p.y); }
          preview = [pts, '#e0583e'];
        } else quads.push([Math.floor(fx), Math.floor(fy), 1, 1, '#e0583e']);
      } else if (tool === 'road') {
        Engine.setGhost(null);
        const plan = this.mode === 'road' ? this.roadPlan : null;
        if (plan) {
          preview = [plan.path.xy, plan.err ? '#e0583e' : '#f3e7c4'];
          const key = `road:${plan.L.toFixed(1)}:${plan.err}`;
          if (key !== this.lastGhostKey) {
            this.lastGhostKey = key;
            UI.setToolStatus('road', 0, 0, plan.err, plan.err ? '' : `Длина ${plan.L.toFixed(1)} · ${fmt(plan.cost.money || 0)} денариев`);
          }
        } else {
          // куда зацепится начало дороги
          const n = Roads.nodeNear(fx, fy, ROAD_SNAP), q = !n && Roads.nearest(fx, fy, ROAD_SNAP);
          const at = n ? [n.x, n.y] : q ? [q.x, q.y] : [fx, fy];
          quads.push([at[0], at[1], 0.6, 0.6, n || q ? '#9fe08a' : '#f3e7c4', 0]);
        }
      } else {
        const d = BUILDINGS[tool];
        const p = this.placement(tool, fx, fy);
        const err = checkPlace(tool, p.cx, p.cy, p.ang);
        Engine.setGhost(tool, p.cx, p.cy, !err, p.ang);
        const x = p.cx - d.w / 2, y = p.cy - d.h / 2;
        if (d.radius) ring = [p.cx, p.cy, d.radius, { x, y, w: d.w, h: d.h }];
        const key = `${tool}:${p.cx.toFixed(2)}:${p.cy.toFixed(2)}:${p.ang.toFixed(2)}:${err}`;
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
        quads.push([h.x + h.w / 2, h.y + h.h / 2, h.w - 0.1, h.h - 0.1, '#7ccf6a', bAng(h)]);
      }
    } else Engine.setRadius(0, 0, 0);
    Engine.setQuads(quads);
    Engine.setRoadPreview(preview ? preview[0] : null, preview && preview[1]);
  },
};
