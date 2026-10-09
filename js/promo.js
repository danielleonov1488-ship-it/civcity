'use strict';
/* Город для съёмок (адрес с #promo): большой красивый Рим с кривыми улицами, форумом, чудесами и садами,
   и кинокамера — плавные пролёты по ключевым точкам с записью кадров в видео.
   Подключается только в этом режиме (см. boot.js); у города своё сохранение, настоящий город не трогается. */

const PROMO_SEED = 681;

const Promo = {
  rnd: mulberry32(2026),

  /* ---------- Город ---------- */

  setup() {
    Paving.noPermanent = true;     // реклама: город строится поверх природы, как раньше
    state.testReady = true;
    state.cityName = 'Нова Рома';
    state.seed = PROMO_SEED;
    state.techs = TECHS.map(t => t.id);
    state.research = null;
    state.money = 1e7;
    state.scrolls = 9999;
    state.glory = 9999;
    for (const g of GOOD_IDS) state.goods[g] = 9999;
    state.plots = new Set();
    for (let py = -2; py <= 2; py++) for (let px = -2; px <= 2; px++) state.plots.add(px + ',' + py);
    state.buildings.clear();
    World.terrain.clear(); World.occ.clear(); World.bgrid.clear();
    state.cleared = new Set();
    Roads.clear();
    const A = Army.ensure();
    A.progress = 7 * STAGES_PER_REGION;
    A.rating = 260;
    this.build();
    state.speed = 1;
    Engine.rebuildAll();
    afterCityChanged();
    UI.buildToolbar();
  },

  C: [12, 12],
  at(r, a) { return [this.C[0] + Math.cos(a) * r, this.C[1] + Math.sin(a) * r]; },

  okPoint(x, y) {
    const tx = Math.floor(x), ty = Math.floor(y);
    return isOwnedTile(tx, ty) && !isWater(groundAt(tx, ty)) && !buildingNear(x, y, ROAD_HALF);
  },

  // Улица по точкам; где путь упирается в воду или постройку — кладётся кусками
  street(pts) {
    const dense = [];
    for (let i = 0; i < pts.length - 1; i++) {
      const [ax, ay] = pts[i], [bx, by] = pts[i + 1], n = Math.max(1, Math.ceil(Math.hypot(bx - ax, by - ay) / 0.3));
      for (let k = 0; k < n; k++) dense.push([ax + (bx - ax) * k / n, ay + (by - ay) * k / n]);
    }
    dense.push(pts[pts.length - 1]);
    let run = [];
    const flush = () => {
      if (run.length > 10) {
        const plan = Roads.plan(run, false);
        if (plan && !plan.err) Roads.build(plan);
      }
      run = [];
    };
    for (const p of dense) { if (this.okPoint(p[0], p[1])) run.push(p); else flush(); }
    flush();
  },

  arc(r, a0, a1, wobble, freq) {
    const pts = [], n = Math.ceil(Math.abs(a1 - a0) * r / 1.2);
    for (let i = 0; i <= n; i++) {
      const a = a0 + (a1 - a0) * i / n;
      pts.push(this.at(r + (wobble || 0) * Math.sin(a * (freq || 3)), a));
    }
    return pts;
  },

  put(type, cx, cy, ang, tier) {
    if (checkPlace(type, cx, cy, ang)) return null;
    const b = placeBuilding(type, cx, cy, ang, true);
    if (tier !== undefined && BUILDINGS[type].kind === 'house') {
      b.tier = tier;
      b.pop = BUILDINGS[type].tiers[tier].cap;
      b.lock = true;
    }
    return b;
  },

  // Постройка у улицы: от точки p улицы в сторону side
  byRoad(type, e, s, side, tier) {
    const p = Roads.pointAt(e, s), d = BUILDINGS[type];
    const nx = -p.ty * side, ny = p.tx * side, off = ROAD_HALF + d.h / 2 + 0.1;
    const c = snapPlace(type, p.x + nx * off, p.y + ny * off, 0);
    return this.put(type, c.cx, c.cy, c.ang, tier);
  },

  build() {
    const R = this.rnd, TAU = Math.PI * 2;
    const pick = a => a[Math.floor(R() * a.length)];
    // ---- улицы: кольцо у форума, шесть изогнутых проспектов, два волнистых кольца, переулки
    this.street(this.arc(8.5, 0, Math.PI));
    this.street(this.arc(8.5, Math.PI, TAU));
    const rays = [];
    for (let k = 0; k < 6; k++) {
      const a = k * TAU / 6 + 0.26, pts = [];
      for (let r = 8.5; r <= 40; r += 1) pts.push(this.at(r, a + 0.28 * Math.sin((r - 8.5) / 30 * Math.PI) * (k % 2 ? 1 : -1)));
      rays.push(a);
      this.street(pts);
    }
    this.street(this.arc(19, 0.05, Math.PI + 0.05, 1.4, 3));
    this.street(this.arc(19, Math.PI + 0.05, TAU + 0.02, 1.4, 3));
    this.street(this.arc(24.5, 0.2, Math.PI + 0.2, 1.1, 4));
    this.street(this.arc(24.5, Math.PI + 0.2, TAU + 0.15, 1.1, 4));
    // переулки от кольца форума к среднему кольцу — в стороне от больших зданий
    for (const a0 of rays) {
      const pts = [];
      for (let r = 9.2; r <= 18.6; r += 0.8) pts.push(this.at(r, a0 + 0.17 + 0.07 * Math.sin(r * 0.7)));
      this.street(pts);
    }
    this.street(this.arc(30, 0.4, Math.PI * 0.95, 2, 2.5));
    this.street(this.arc(30, Math.PI * 1.1, TAU + 0.25, 2, 2.5));
    // переулки между проспектами — тупички с круглыми концами
    for (let k = 0; k < 6; k++) {
      const a = rays[k] + Math.PI / 6, pts = [];
      for (let r = 19.5; r <= 27; r += 1) pts.push(this.at(r, a + 0.15 * Math.sin(r)));
      this.street(pts);
    }

    // улицы — мостовой той же формы; внутри кольца форума — площадь из травертина
    const [cx, cy] = this.C;
    Paving.clear();
    Paving.fromRoads();
    Paving.stamp(cx, cy, cx, cy, 8.3, 4);

    // ---- форум: площадь в кольце
    this.put('forum', cx, cy + 2.2, Math.PI, undefined);
    this.put('temple', cx, cy - 3.6, 0);
    this.put('pantheon', cx - 4.6, cy - 0.4, Math.PI / 2);
    this.put('baths', cx + 4.4, cy - 0.6, -Math.PI / 2);
    this.put('arch', cx, cy + 6.4, 0);
    for (const [dx, dy, t] of [[-2.6, -1.2, 'fountain'], [2.6, -1.2, 'fountain'], [0, -1.2, 'emperor'], [-2, 5.4, 'statue'], [2, 5.4, 'statue']]) this.put(t, cx + dx, cy + dy, 0);
    for (let i = 0; i < 6; i++) { this.put('column', cx - 3.3 + i * 1.3, cy - 5.9, 0); }
    // ---- чудеса и большие здания между кольцами
    const big = [['colosseum', 13.5], ['theatre', 13.5], ['market', 14], ['tradepost', 14.5], ['school', 14], ['temple', 14]];
    big.forEach(([t, r], i) => {
      const a = rays[i] + Math.PI / 6 + 0.08;
      const [x, y] = this.at(r, a);
      this.put(t, x, y, Math.atan2(cx - x, cy - y));
    });

    // ---- дома вдоль всех улиц, чем ближе к форуму — тем богаче
    const services = ['market', 'well', 'fountain', 'bakery', 'school', 'baths', 'well', 'temple', 'oilpress', 'warehouse'];
    let n = 0;
    for (const e of [...Roads.edges.values()]) {
      for (let s = 1; s < e.L - 1; s += 2.15) {
        for (const side of [1, -1]) {
          const p = Roads.pointAt(e, s), r = Math.hypot(p.x - cx, p.y - cy);
          if (r < 9.8) continue;
          n++;
          if (n % 11 === 0) { this.byRoad(services[(n / 11) % services.length | 0], e, s, side); continue; }
          if (r < 22 && R() < 0.3) this.byRoad('domus', e, s, side, 2 + Math.floor(R() * 3));
          else this.byRoad('house', e, s, side, r < 16 ? 3 + Math.floor(R() * 2) : r < 28 ? 2 + Math.floor(R() * 3) : 1 + Math.floor(R() * 3));
        }
      }
    }

    // ---- фонари вдоль проспектов и сады в свободных местах
    for (const e of Roads.edges.values()) {
      for (let s = 1.5; s < e.L - 1; s += 4.2) {
        const p = Roads.pointAt(e, s), side = (Math.round(s) % 2 ? 1 : -1);
        this.put('lamp', p.x - p.ty * side * 0.95, p.y + p.tx * side * 0.95, R() * TAU);
      }
    }
    const weighted = list => { const tot = list.reduce((a, d) => a + d[1], 0); let k = R() * tot; for (const [t, w] of list) if ((k -= w) <= 0) return t; return list[0][0]; };
    // сады при домах: за домом и сбоку — кипарис, олива, клумба, амфоры, беседка
    const garden = [['cypress', 30], ['olive', 18], ['flowers', 22], ['amphorae', 8], ['pergola', 6], ['bench', 6], ['pine', 10]];
    for (const b of [...state.buildings.values()]) {
      if (BUILDINGS[b.type].kind !== 'house' || R() < 0.25) continue;
      const a = bAng(b), cx0 = b.x + b.w / 2, cy0 = b.y + b.h / 2;
      const n = 1 + Math.floor(R() * 3);
      for (let i = 0; i < n; i++) {
        // позади дома (против фасада) и по бокам
        const back = -(b.h / 2 + 0.6 + R() * 0.8), sideOff = (R() - 0.5) * (b.w + 1.2);
        const x = cx0 + Math.sin(a) * back + Math.cos(a) * sideOff, y = cy0 + Math.cos(a) * back - Math.sin(a) * sideOff;
        this.put(weighted(garden), x, y, R() * TAU);
      }
    }
    // рощи на пустырях внутри города
    for (let g = 0; g < 70; g++) {
      const a = R() * TAU, r = 9 + R() * 30, [gx, gy] = this.at(r, a);
      if (buildingNear(gx, gy, 2.5) || Roads.nearest(gx, gy, 2.5)) continue;
      const kind = weighted([['cypress', 5], ['pine', 3], ['olive', 3]]);
      for (let i = 0; i < 4 + Math.floor(R() * 5); i++) this.put(R() < 0.8 ? kind : 'flowers', gx + (R() - 0.5) * 3.5, gy + (R() - 0.5) * 3.5, R() * TAU);
    }
    // форум: аллеи кипарисов и клумбы по кругу, статуи у проспектов
    for (let i = 0; i < 28; i++) {
      const a = i / 28 * TAU, [x, y] = this.at(7.2, a);
      this.put(i % 2 ? 'cypress' : 'flowers', x, y, a);
    }
    for (const a of rays) { const [x, y] = this.at(10.2, a + 0.22); this.put('statue', x, y, Math.atan2(cx - x, cy - y)); const [x2, y2] = this.at(10.2, a - 0.22); this.put('obelisk', x2, y2, 0); }

    // ---- окраины: поля, виноградники, рощи, мастерские, рыбаки у воды, лагерь легиона
    const outer = ['farm', 'vineyard', 'grove', 'farm', 'lumber', 'quarry', 'claypit', 'brickworks', 'smithy', 'barracks', 'range', 'spearcamp', 'fishery', 'fishery', 'farm', 'vineyard', 'grove', 'mine'];
    for (let i = 0; i < 260; i++) {
      const a = R() * TAU, r = 31 + R() * 16, [x, y] = this.at(r, a), t = pick(outer);
      const c = snapPlace(t, x, y, R() * TAU);
      this.put(t, c.cx, c.cy, c.ang);
    }
  },
};

/* ---------- Кинокамера ----------
   Кадр задаётся точкой взгляда (x, z), расстоянием, поворотом, наклоном и временем суток.
   Между ключами камера идёт по гладкой кривой; каждый кадр игра делает шаг и картинка уходит на запись. */

const Cinema = {
  // Плавная кривая через ключи (Катмулл — Ром) по каждому числу
  sample(keys, u) {
    const n = keys.length - 1, f = clamp(u, 0, 1) * n, i = Math.min(n - 1, Math.floor(f)), t = f - i;
    const g = j => keys[clamp(j, 0, n)];
    const out = {};
    for (const k of Object.keys(keys[0])) {
      const p0 = g(i - 1)[k], p1 = g(i)[k], p2 = g(i + 1)[k], p3 = g(i + 2)[k];
      out[k] = 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t * t * t);
    }
    return out;
  },

  ease(u) { return u < 0.5 ? 4 * u * u * u : 1 - Math.pow(-2 * u + 2, 3) / 2; },

  apply(k) {
    const c = Engine.cam;
    c.x = c.tx = k.x; c.z = c.tz = k.z;
    c.dist = c.distTarget = k.dist;
    c.yaw = c.yawTarget = k.yaw;
    c.pitch = k.pitch;
    c.lookY = k.lookY || 0;
    if (k.t !== undefined) Atmos.t = ((k.t % 1) + 1) % 1;
  },

  // Размер кадра для записи (рисуется в памяти, окно браузера не важно)
  setSize(w, h) {
    Engine.forceSize = w ? [w, h] : null;
    Engine.resize();
  },

  // Один кадр: шаг жизни города и картинка
  step(dt) {
    Walkers.update(dt, dt);
    Cats.update(dt, dt);
    Engine.frame(dt, dt);
  },

  // Прогрев: дорисовать участки, природу и жителей вокруг первой точки
  warm(k, frames) {
    this.apply(k);
    for (let i = 0; i < (frames || 60); i++) this.step(1 / 30);
  },

  async shot(name, keys, seconds, opts) {
    opts = opts || {};
    const fps = opts.fps || 30, N = Math.round(seconds * fps), sink = opts.sink || 'http://localhost:5192';
    Atmos.cycle = false;
    Game.hold = true;
    // виртуальные часы: каждый кадр — ровно 1/fps секунды, как бы медленно ни шла запись
    const realNow = performance.now.bind(performance);
    let vt = realNow();
    performance.now = () => vt;
    const step = opts.step || (dt => this.step(dt));
    if (opts.before) opts.before();
    if (keys) this.warm(this.sample(keys, 0), opts.warm || 90);
    for (let i = 0; i < (opts.warmSteps || 0); i++) { vt += 1000 / fps; step(1 / fps); }
    // кадр читается прямо из видеокарты и сырым уходит в ffmpeg — быстро и без потерь
    const gl = Engine.renderer.getContext(), w = gl.drawingBufferWidth, h = gl.drawingBufferHeight;
    const buf = new Uint8Array(w * h * 4);
    this.progress = { name, i: 0, N };
    for (let i = 0; i < N; i++) {
      const u = opts.linear ? i / (N - 1) : this.ease(i / (N - 1));
      vt += 1000 / fps;
      if (keys) this.apply(this.sample(keys, u));
      if (opts.each) opts.each(u, i);
      step(1 / fps);
      gl.readPixels(0, 0, w, h, gl.RGBA, gl.UNSIGNED_BYTE, buf);
      await fetch(`${sink}/raw?shot=${name}&w=${w}&h=${h}&fps=${fps}`, { method: 'POST', body: buf });
      this.progress.i = i + 1;
    }
    await fetch(`${sink}/end?shot=${name}`, { method: 'POST' });
    performance.now = realNow;
    if (opts.after) opts.after();
    return N;
  },

  // Несколько клипов подряд в фоне; ход виден в Cinema.progress
  record(list) {
    this.done = [];
    this.error = null;
    (async () => {
      for (const s of list) {
        try { await this.shot(s.name, s.keys, s.seconds, s.opts); this.done.push(s.name); } catch (e) { this.error = s.name + ': ' + e.message; return; }
      }
      this.progress = null;
    })();
  },
};
