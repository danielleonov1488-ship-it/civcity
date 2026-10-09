'use strict';
/* Управление: камера (сдвиг, масштаб, поворот), выбор инструмента, стройка мышью и пальцами.
   Стройка без клеток: мостовую рисуют кистью (с Shift — прямой линией, [ ] — размер, Ctrl+Z — отменить мазок),
   дом у мостовой сам встаёт фасадом к ней, на мостовой и вдали от неё постройки и украшения поворачиваются
   клавишами Z / C или колёсиком с Shift. */

const ROT_STEP = Math.PI / 12;   // поворот постройки за одно нажатие — 15°
const BRUSH_SIZES = [0.25, 0.375, 0.5, 0.75, 1, 1.5, 2, 3, 4];   // радиусы кисти мостовой (в клетках)
// ширина кисти словами: «0,5 клетки», «1 клетка», «3 клетки», «6 клеток»
const fmtW = w => String(w).replace('.', ',') + (w === 1 ? ' клетка' : Number.isInteger(w) && w >= 5 ? ' клеток' : ' клетки');

const Input = {
  tool: null,          // тип постройки, 'bulldoze' или null
  hover: null,         // точка земли под курсором (в клетках, дробная)
  mouse: [0, 0],
  pointers: new Map(),
  mode: null,          // pan | rotate | maybe | road | paint | place | pinch
  start: null,
  anchor: null,
  moved: false,
  brush: { mode: 3, r: 0.5 },   // кисть мостовой: покрытие (PAVE; 0 — ластик, -1 — «улучшить») и радиус в клетках
  stroke: null,        // текущий мазок: { last, start, undo, cost, reason }
  undos: [],           // последние мазки — для Ctrl+Z
  shift: false,
  angle: 0,            // поворот постройки вдали от дорог
  moving: null,        // переносимое здание (снято с карты, пока его не поставят)
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
      if (e.shiftKey && this.tool === 'road') { this.brushSize(e.deltaY > 0 ? -1 : 1); return; }
      if (e.shiftKey && this.tool && this.tool !== 'bulldoze') { this.rotate(e.deltaY > 0 ? 1 : -1); return; }
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
    // смена инструмента посреди переноса — здание возвращается на место
    if (this.moving && !this.keepMove) this.cancelMove();
    this.endStroke();
    this.tool = tool;
    this.mode = null;
    this.lastGhostKey = '';
    if (!tool) Engine.setGhost(null);
    Engine.setRoadPreview(null);
    Engine.setBrush(null);
    Engine.canvasCursor = tool ? 'crosshair' : 'default';
    Engine.renderer.domElement.style.cursor = Engine.canvasCursor;
    UI.onToolChanged();
  },

  // Перенос: здание «берётся в руку», призрак — оно же; нажатие на землю — поставить, Esc или ПКМ — вернуть
  startMove(b) {
    UI.closePanel();
    liftBuilding(b);
    this.angle = bAng(b);
    this.moving = b;
    this.keepMove = true;
    this.setTool(b.type);
    this.keepMove = false;
    afterCityChanged();
  },

  cancelMove() {
    const b = this.moving;
    if (!b) return;
    this.moving = null;
    if (state.buildings.get(b.id) === b) dropBuilding(b);
    afterCityChanged();
  },

  finishMove(p) {
    const b = this.moving;
    const err = checkMove(b, p.cx, p.cy, p.ang);
    if (err) { this.warn(err); return; }
    this.moving = null;
    dropBuilding(b, p.cx, p.cy, p.ang);
    Engine.dust(b);
    Sound.build(b);
    afterCityChanged();
    this.setTool(null);
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
      this.endStroke();
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
      this.stroke = { last: [fx, fy], start: [fx, fy], undo: [], cleared: [], cost: 0, reason: null };
      if (!this.shift) this.paintTo(fx, fy);
    } else if (!this.moving && (tool === 'bulldoze' || BUILDINGS[tool].w === 1)) {
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
      // с Shift — прямая от начала мазка (кладётся, когда отпустили кнопку), иначе рисуем под курсором
      if (!this.shift) this.paintTo(this.hover[0], this.hover[1]);
    } else if (this.mode === 'paint') {
      this.paint(this.hover[0], this.hover[1]);
    }
  },

  /* ---------- Кисть мостовой ---------- */

  brushSize(dir) {
    let i = BRUSH_SIZES.findIndex(s => s >= this.brush.r - 1e-6);
    if (i < 0) i = BRUSH_SIZES.length - 1;
    this.brush.r = BRUSH_SIZES[clamp(i + dir, 0, BRUSH_SIZES.length - 1)];
    this.lastGhostKey = '';
    UI.onBrushChanged();
  },

  // мазок от прошлой точки до (x, y): кружки кисти по пути, деньги — сразу
  paintTo(x, y) {
    const st = this.stroke;
    if (!st) return;
    const [ax, ay] = st.last;
    if (st.undo.length && Math.hypot(x - ax, y - ay) < Math.max(0.08, this.brush.r * 0.3)) return;
    const r = Paving.stroke(ax, ay, x, y, this.brush.r, this.brush.mode, state.money);
    st.last = [x, y];
    if (r.changed) {
      state.money -= r.cost;
      st.cost += r.cost;
      for (const v of r.undo) st.undo.push(v);
      for (const k of r.cleared) st.cleared.push(k);
      // стук камней — не чаще трёх раз в секунду, чтобы мазок не трещал
      const now = performance.now();
      if (this.brush.mode !== 0 && now - (this.lastClack || 0) > 330) { this.lastClack = now; Sound.road(0.5); }
    }
    if (r.reason) { st.reason = r.reason; this.lastGhostKey = ''; }
  },

  // мазок закончен: запомнить для Ctrl+Z, пересчитать город
  endStroke() {
    const st = this.stroke;
    this.stroke = null;
    if (!st || !st.undo.length) return;
    this.undos.push({ undo: st.undo, cleared: st.cleared, cost: st.cost });
    if (this.undos.length > 30) this.undos.shift();
    if (this.brush.mode === 0) Sound.demolish(st.last[0], st.last[1]);
    afterCityChanged();
    if (st.reason) this.warn(st.reason);
  },

  undoStroke() {
    const u = this.undos.pop();
    if (!u) return;
    Paving.undo(u.undo, u.cleared);
    state.money += u.cost;
    afterCityChanged();
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
    if (cancelled || mode === 'pinched' || mode === 'pinch') { this.endStroke(); Engine.setRoadPreview(null); return; }

    if (mode === 'pan' && e.button === 2 && !this.moved) { this.setTool(null); return; }
    if (mode === 'road') {
      const st = this.stroke;
      if (st && this.shift && this.hover) { st.last = st.start; this.paintTo(this.hover[0], this.hover[1]); }
      this.endStroke();
      return;
    }
    if (mode === 'place' && this.hover) {
      const p = this.placement(this.tool, this.hover[0], this.hover[1]);
      if (this.moving) this.finishMove(p);
      else this.tryPlace(this.tool, p, true);
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
    if ((k === 'z' || k === 'я') && (e.ctrlKey || e.metaKey)) { e.preventDefault(); this.undoStroke(); return; }
    if (this.tool === 'road' && (k === '[' || k === 'х')) { this.brushSize(-1); return; }
    if (this.tool === 'road' && (k === ']' || k === 'ъ')) { this.brushSize(1); return; }
    if (k === 'q' || k === 'й') Engine.rotate(-1);
    if (k === 'e' || k === 'у') Engine.rotate(1);
    if (k === 'u' || k === 'г') UI.setUiHidden(!document.body.classList.contains('ui-hidden'));
    if (k === 'home') Engine.flyHome();
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
    Sound.build(b);
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
        Sound.demolish(fx, fy);
        afterCityChanged();
        return;
      }
      const tx = Math.floor(fx), ty = Math.floor(fy), key = tkey(tx, ty);
      const keep = permanentNature(tx, ty);
      if (keep) { this.warn(keep === 'deposit' ? 'Залежи вечные — их не убрать' : 'Это лес — он вечный, его не вырубить'); return; }
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
        if (b) quads.push([b.x + b.w / 2, b.y + b.h / 2, b.w, b.h, '#e0583e', bAng(b)]);
        else quads.push([Math.floor(fx), Math.floor(fy), 1, 1, permanentNature(Math.floor(fx), Math.floor(fy)) ? '#c9b48a' : '#e0583e']);
      } else if (tool === 'road') {
        Engine.setGhost(null);
        const m = this.brush.mode, st = this.stroke;
        const why = m === 0 ? null : Paving.blocked(Math.floor(fx * SUB), Math.floor(fy * SUB));
        Engine.setBrush(fx, fy, this.brush.r, m === 0 ? '#ff7a5c' : why ? '#ffb347' : '#fffaf0');
        // с Shift — прямая от начала мазка
        if (st && this.shift) preview = [[st.start[0], st.start[1], fx, fy], m === 0 ? '#e0583e' : '#ffd36b', this.brush.r];
        const reason = (st && st.reason) || why;
        const key = `road:${m}:${this.brush.r}:${reason}:${st ? Math.round(st.cost) : -1}`;
        if (key !== this.lastGhostKey) {
          this.lastGhostKey = key;
          const w = this.brush.r * 2;
          const info = m === 0 ? `Ластик · ширина ${fmtW(w)}` : m === -1 ? `Улучшить до мостовой · ширина ${fmtW(w)}`
            : `${PAVE[m].name} · ширина ${fmtW(w)} · ${String(PAVE[m].cost).replace('.', ',')} ден. за клетку${st && st.cost ? ` · мазок ${fmt(Math.ceil(st.cost))}` : ''}`;
          UI.setToolStatus('road', 0, 0, reason, info);
        }
      } else {
        const d = BUILDINGS[tool];
        const p = this.placement(tool, fx, fy);
        const err = this.moving ? checkMove(this.moving, p.cx, p.cy, p.ang) : checkPlace(tool, p.cx, p.cy, p.ang);
        Engine.setGhost(tool, p.cx, p.cy, !err, p.ang, this.moving);
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
    Engine.setRoadPreview(preview ? preview[0] : null, preview && preview[1], preview && preview[2]);
  },
};
