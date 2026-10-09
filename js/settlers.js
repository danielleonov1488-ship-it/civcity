'use strict';
/* Переселенцы — как в Civ City Rome и Town to City. По мостовой к центру города приезжает повозка с семьями,
   из неё семьи расходятся по свободным домам и заселяют их, когда дойдут. Сколько идти — считается в днях
   по длине пути, поэтому дом заселяется, даже если вкладка свёрнута и картинки нет. Работники сами занимают
   рабочие места (computeCoverage). Без центра города дома заселяются, как раньше, понемногу каждый день. */

const SETTLER_WALK = 3.2;      // сколько клеток семья проходит за игровой день
const CART_SPEED = 1.1;        // повозка, клеток в секунду игрового времени
const WALK_SPEED = 0.75;       // идущие к дому переселенцы, клеток в секунду

const Settlers = {
  waiting: [],                 // семьи ждут повозку (только для картинки): { id, n }
  carts: [],                   // повозки в пути: { pts, s, L, families, alpha, done }
  field: null,                 // расстояния по мостовой от центра города (поиск в ширину по клеткам)

  center() {
    for (const b of state.buildings.values()) if (b.type === 'center' && !b.lifted) return b;
    return null;
  },

  /* ---------- Город: кто и когда въезжает ---------- */

  // Раз в день для дома, где есть место: если к нему ещё никто не идёт — отправить семью
  request(h, capPop) {
    const arr = state.arrivals || (state.arrivals = []);
    if (arr.some(a => a.id === h.id)) return;
    const c = this.center();
    if (!c) return;
    const n = Math.max(1, Math.min(capPop - h.pop, Math.ceil(capPop / 3)));
    // сколько идти: по полю расстояний (сам путь строится только для картинки, когда семья выходит из повозки)
    const steps = this.distTo(h);
    const len = steps !== null ? steps * 0.85 : Math.hypot(h.x - c.x, h.y - c.y) * 1.4;
    arr.push({ id: h.id, n, day: state.day + 1 + Math.ceil(len / SETTLER_WALK) });
    // картинка: семья ждёт повозку (во вкладке на заднем плане — не копим)
    if (!document.hidden && this.waiting.length < 16) this.waiting.push({ id: h.id, n });
  },

  // Раз в день: дошедшие семьи заселяются
  daily() {
    const arr = state.arrivals || [];
    if (!arr.length) return;
    state.arrivals = arr.filter(a => {
      if (a.day > state.day) return true;
      const h = state.buildings.get(a.id);
      if (h && BUILDINGS[h.type].kind === 'house') h.pop = Math.min(tiersOf(h)[h.tier].cap, h.pop + a.n);
      return false;
    });
  },

  // сколько людей сейчас в пути
  onTheWay() { return (state.arrivals || []).reduce((s, a) => s + a.n, 0); },

  /* ---------- Пути по мостовой ---------- */

  // клетка проходима: середина замощена и клетку целиком не занимает постройка
  walk(tx, ty) { return Paving.at(tx + 0.5, ty + 0.5) > 0 && !World.occ.has(tkey(tx, ty)); },

  // Расстояния от центра по клеткам мостовой — пересчитываются, только когда менялась мостовая или постройки
  ensureField() {
    const c = this.center();
    if (!c) { this.field = null; return null; }
    const key = Paving.version + ':' + state.buildings.size + ':' + c.id + ':' + c.x.toFixed(2) + ':' + c.y.toFixed(2) + ':' + state.plots.size;
    if (this.field && this.field.key === key) return this.field;
    let px0 = Infinity, py0 = Infinity, px1 = -Infinity, py1 = -Infinity;
    for (const k of state.plots) { const [px, py] = k.split(',').map(Number); px0 = Math.min(px0, px); py0 = Math.min(py0, py); px1 = Math.max(px1, px); py1 = Math.max(py1, py); }
    const x0 = (px0 - 1) * PLOT, y0 = (py0 - 1) * PLOT, W = (px1 - px0 + 3) * PLOT, H = (py1 - py0 + 3) * PLOT;
    const D = new Int32Array(W * H).fill(-1);
    const start = Paving.contact(c);
    const F = { key, x0, y0, W, H, D, start };
    this.field = F;
    if (!start) return F;
    const sx = Math.floor(start.x) - x0, sy = Math.floor(start.y) - y0;
    if (sx < 0 || sy < 0 || sx >= W || sy >= H) return F;
    const q = new Int32Array(W * H);
    let qh = 0, qt = 0;
    D[sy * W + sx] = 0;
    q[qt++] = sy * W + sx;
    while (qh < qt) {
      const i = q[qh++], x = i % W, y = (i - x) / W, d = D[i] + 1;
      for (const [nx, ny] of [[x + 1, y], [x - 1, y], [x, y + 1], [x, y - 1]]) {
        if (nx < 0 || ny < 0 || nx >= W || ny >= H) continue;
        const j = ny * W + nx;
        if (D[j] >= 0 || !this.walk(nx + x0, ny + y0)) continue;
        D[j] = d;
        q[qt++] = j;
      }
    }
    return F;
  },

  // Путь от центра до точки (x, y) по мостовой: клетки вниз по расстоянию, потом спрямление. null — не дойти
  pathFromCenter(x, y) {
    const F = this.ensureField();
    if (!F || !F.start) return null;
    let cx = Math.floor(x) - F.x0, cy = Math.floor(y) - F.y0;
    const at = (a, b) => (a < 0 || b < 0 || a >= F.W || b >= F.H) ? -1 : F.D[b * F.W + a];
    // точка может быть у самого края мостовой — ищем ближайшую клетку, до которой доходит путь
    if (at(cx, cy) < 0) {
      let best = null;
      for (let dy = -2; dy <= 2; dy++) for (let dx = -2; dx <= 2; dx++) {
        const v = at(cx + dx, cy + dy);
        if (v >= 0 && (!best || Math.hypot(dx, dy) < best[2])) best = [cx + dx, cy + dy, Math.hypot(dx, dy)];
      }
      if (!best) return null;
      cx = best[0]; cy = best[1];
    }
    const pts = [[x, y]];
    let guard = 0;
    while (at(cx, cy) > 0 && guard++ < 5000) {
      const d = at(cx, cy);
      let nx = cx, ny = cy;
      for (const [ax, ay] of [[cx + 1, cy], [cx - 1, cy], [cx, cy + 1], [cx, cy - 1]]) if (at(ax, ay) === d - 1) { nx = ax; ny = ay; break; }
      if (nx === cx && ny === cy) break;
      cx = nx; cy = ny;
      pts.push([cx + F.x0 + 0.5, cy + F.y0 + 0.5]);
    }
    pts.push([F.start.x, F.start.y]);
    pts.reverse();
    return this.smooth(pts);
  },

  // сколько клеток мостовой от центра до двери дома (null — не дойти по мостовой)
  distTo(h) {
    const F = this.ensureField(), p = Paving.contact(h);
    if (!F || !F.start || !p) return null;
    const cx = Math.floor(p.x) - F.x0, cy = Math.floor(p.y) - F.y0;
    let best = null;
    for (let dy = -2; dy <= 2; dy++) for (let dx = -2; dx <= 2; dx++) {
      const x = cx + dx, y = cy + dy;
      if (x < 0 || y < 0 || x >= F.W || y >= F.H) continue;
      const v = F.D[y * F.W + x];
      if (v >= 0 && (best === null || v + Math.abs(dx) + Math.abs(dy) < best)) best = v + Math.abs(dx) + Math.abs(dy);
    }
    return best;
  },

  // путь от центра до дома (до его двери на мостовой)
  pathTo(h) {
    const p = Paving.contact(h);
    if (!p) return null;
    return this.pathFromCenter(p.x, p.y);
  },

  // Спрямление: от точки сразу к самой дальней, до которой видно по мостовой
  smooth(pts) {
    if (pts.length < 3) return pts;
    const clear = (a, b) => {
      const L = Math.hypot(b[0] - a[0], b[1] - a[1]), n = Math.ceil(L / 0.2);
      for (let i = 1; i < n; i++) { const t = i / n; if (!Paving.walkable(a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)) return false; }
      return true;
    };
    const out = [pts[0]];
    let i = 0;
    while (i < pts.length - 1) {
      let j = Math.min(pts.length - 1, i + 24);
      while (j > i + 1 && !clear(pts[i], pts[j])) j--;
      out.push(pts[j]);
      i = j;
    }
    return out;
  },

  length(pts) { let L = 0; for (let i = 1; i < pts.length; i++) L += Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]); return L; },

  // точка на пути через s клеток от начала и направление
  pointAt(pts, s) {
    for (let i = 1; i < pts.length; i++) {
      const a = pts[i - 1], b = pts[i], l = Math.hypot(b[0] - a[0], b[1] - a[1]);
      if (s <= l || i === pts.length - 1) {
        const t = l ? Math.min(1, s / l) : 1;
        return { x: a[0] + (b[0] - a[0]) * t, y: a[1] + (b[1] - a[1]) * t, yaw: Math.atan2(b[0] - a[0], b[1] - a[1]) };
      }
      s -= l;
    }
    const p = pts[pts.length - 1];
    return { x: p[0], y: p[1], yaw: 0 };
  },

  // Откуда приезжает повозка: самая дальняя от центра клетка мостовой у края своей земли
  entry() {
    const F = this.ensureField();
    if (!F || !F.start) return null;
    let best = -1, bi = -1, far = -1, fi = -1;
    for (let i = 0; i < F.D.length; i++) {
      const d = F.D[i];
      if (d < 0) continue;
      const x = i % F.W + F.x0, y = Math.floor(i / F.W) + F.y0;
      if (d > far) { far = d; fi = i; }
      // у края: рядом чужая земля
      const own = (a, b) => isOwnedTile(a, b);
      if ((!own(x + 1, y) || !own(x - 1, y) || !own(x, y + 1) || !own(x, y - 1)) && d > best) { best = d; bi = i; }
    }
    const i = bi >= 0 ? bi : fi;
    if (i < 0 || F.D[i] < 4) return null;
    return this.pathFromCenter(i % F.W + F.x0 + 0.5, Math.floor(i / F.W) + F.y0 + 0.5);
  },

  /* ---------- Картинка: повозки и идущие к домам семьи ---------- */

  update(dt, realDt) {
    if (PROMO_MODE) return;
    // новая повозка, когда есть ждущие семьи и на дороге не больше двух повозок
    if (this.waiting.length && this.carts.length < 2 && dt > 0 && this.center()) {
      const path = this.entry();
      const fam = this.waiting.splice(0, 6);
      if (path) {
        path.reverse();
        this.carts.push({ pts: path, s: 0, L: this.length(path), families: fam, alpha: 0, done: false, yaw: 0 });
      } else this.unload(fam);
    }
    for (const c of this.carts) {
      if (!c.done) {
        c.s += dt * CART_SPEED;
        c.alpha = Math.min(1, c.alpha + realDt * 2);
        if (c.s >= c.L) { c.s = c.L; c.done = true; this.unload(c.families); }
      } else c.alpha -= realDt * 0.8;
      const p = this.pointAt(c.pts, c.s);
      c.x = p.x; c.y = p.y;
      let d = p.yaw - c.yaw;
      d = Math.atan2(Math.sin(d), Math.cos(d));
      c.yaw += d * Math.min(1, realDt * 5);
    }
    this.carts = this.carts.filter(c => c.alpha > 0);
    this.draw();
  },

  // семьи выходят из повозки у центра и идут к своим домам
  unload(families) {
    for (const f of families) {
      const h = state.buildings.get(f.id);
      if (!h) continue;
      const path = this.pathTo(h);
      const c = this.center();
      const pts = path || (c ? [[c.x + c.w / 2, c.y + c.h + 0.2], [h.x + h.w / 2, h.y + h.h / 2]] : null);
      if (!pts) continue;
      const k = Math.min(3, Math.max(1, f.n));
      for (let i = 0; i < k; i++) {
        const head = Math.random() * 6.28;
        const w = {
          wx: pts[0][0], wy: pts[0][1], head, want: head, dist: 0, lane: 0,
          speed: WALK_SPEED * (NEW_LOOK ? 0.6 : 1), life: 999, age: 0, alpha: 0, moving: true,
          seed: Math.random(), pause: 0, yaw: head, walkPh: Math.random() * 6.28,
          path: pts, ps: -i * 0.45, settler: true,
        };
        Walkers.dress(w, h);
        if (i === 2 || (k === 1 && Math.random() < 0.3)) { w.role = 'child'; }
        Walkers.list.push(w);
      }
    }
  },

  // шаг переселенца по пути; дошёл — растворяется у двери
  step(w, dt, realDt) {
    if (dt > 0) {
      w.ps += dt * w.speed;
      w.walkPh += dt * w.speed * (w.stride || 11);
    }
    const L = w.pathL || (w.pathL = this.length(w.path));
    if (w.ps >= L) { w.moving = false; w.life = Math.min(w.life, 0); }
    else w.moving = w.ps > 0 && dt > 0;
    const p = this.pointAt(w.path, Math.max(0, w.ps));
    w.wx = p.x; w.wy = p.y;
    let d = p.yaw - w.yaw;
    d = Math.atan2(Math.sin(d), Math.cos(d));
    w.yaw += d * Math.min(1, realDt * 8);
  },

  // повозка — модель «Horse Cart» из набора (или простая коробка, пока набор не загружен)
  draw() {
    if (!this.mesh) {
      if (!Engine.scene) return;
      let geo = null;
      if (typeof Look2 !== 'undefined' && Look2.ready) {
        geo = Look2.propGeometry('Horse Cart');
        if (geo) {
          geo.computeBoundingBox();
          const bb = geo.boundingBox, s = 0.52 / Math.max(1e-6, bb.max.y - bb.min.y);
          geo.translate(-(bb.min.x + bb.max.x) / 2, -bb.min.y, -(bb.min.z + bb.max.z) / 2);
          geo.scale(s, s, s);
        }
      }
      if (!geo) {
        if (NEW_LOOK && !(typeof Look2 !== 'undefined' && Look2.ready)) return;   // набор ещё грузится
        geo = new THREE.BoxGeometry(0.45, 0.3, 0.8).translate(0, 0.2, 0);
        const col = new Float32Array(geo.attributes.position.count * 3).fill(0.55);
        geo.setAttribute('color', new THREE.BufferAttribute(col, 3));
      }
      this.mesh = new THREE.InstancedMesh(geo, patchMaterial(new THREE.MeshLambertMaterial({ vertexColors: true, flatShading: true })), 4);
      this.mesh.castShadow = true;
      this.mesh.receiveShadow = true;
      this.mesh.frustumCulled = false;
      this.mesh.count = 0;
      Engine.scene.add(this.mesh);
      this._m = new THREE.Matrix4(); this._q = new THREE.Quaternion(); this._p = new THREE.Vector3(); this._s = new THREE.Vector3(); this._up = new THREE.Vector3(0, 1, 0);
    }
    let n = 0;
    for (const c of this.carts) {
      if (n >= 4) break;
      const a = Math.max(0, Math.min(1, c.alpha));
      this._q.setFromAxisAngle(this._up, c.yaw + CART_YAW);
      this._p.set(c.x, Paving.surfY(c.x, c.y), c.y);
      this._s.set(a, a, a);
      this.mesh.setMatrixAt(n++, this._m.compose(this._p, this._q, this._s));
    }
    this.mesh.count = n;
    if (n) this.mesh.instanceMatrix.needsUpdate = true;
  },
};

const CART_YAW = 0;            // поворот модели повозки относительно направления движения
