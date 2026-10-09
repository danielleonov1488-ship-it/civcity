/* Сценарий съёмки рекламного ролика CivCity. Выполняется внутри игры (город #promo) — см. promo/rec.js.
   Каждый клип — ключи камеры: точка взгляда (x, z), расстояние, поворот, наклон, высота взгляда, время суток. */
window.PromoShots = {
  finished: false,

  find(type) { return [...state.buildings.values()].find(b => b.type === type); },
  center(b) { return [b.x + b.w / 2, b.y + b.h / 2]; },

  // Жители и кошки разбредаются по улицам заранее, без рисования
  populate() {
    for (let i = 0; i < 2500; i++) { Walkers.update(0.08, 0.08); Cats.update(0.08, 0.08); }
  },

  // Улица для прогулки: длинная и в середине города. Камера идёт ровно над мостовой и смотрит
  // на точку дальше по той же улице — так она повторяет все изгибы и не задевает дома
  streetKeys() {
    const edges = [...Roads.edges.values()].filter(e => e.L > 14).map(e => {
      const m = Roads.pointAt(e, e.L / 2);
      return { e, r: Math.hypot(m.x - 12, m.y - 12) };
    }).filter(o => o.r > 14 && o.r < 24).sort((a, b) => b.e.L - a.e.L);
    const e = edges[0].e, keys = [], ahead = 4.2, pitch = 0.24;
    const span = Math.min(e.L - ahead - 2, 13);
    for (let s = 1; s <= 1 + span + 1e-6; s += span / 10) {
      const c = Roads.pointAt(e, s), t = Roads.pointAt(e, s + ahead);
      const h = Math.hypot(c.x - t.x, c.y - t.y);
      keys.push({ x: t.x, z: t.y, dist: h / Math.cos(pitch), yaw: Math.atan2(c.x - t.x, c.y - t.y), pitch, lookY: 0.5, t: 0.64 });
    }
    // поворот камеры не должен прыгать через 2π
    for (let i = 1; i < keys.length; i++) while (keys[i].yaw - keys[i - 1].yaw > Math.PI) keys[i].yaw -= Math.PI * 2;
    for (let i = 1; i < keys.length; i++) while (keys[i].yaw - keys[i - 1].yaw < -Math.PI) keys[i].yaw += Math.PI * 2;
    return keys;
  },

  list() {
    const col = this.center(this.find('colosseum')), forum = this.center(this.find('forum'));
    const domus = [...state.buildings.values()].filter(b => b.type === 'domus' && b.tier >= 3)[0] || this.find('house');
    const dh = this.center(domus);
    const cat = Cats.list[0];
    return [
      { name: 'aerial', seconds: 9, keys: [
        { x: 12, z: 18, dist: 86, yaw: 0.15, pitch: 0.9, t: 0.66 },
        { x: 12, z: 15, dist: 74, yaw: 0.6, pitch: 0.8, t: 0.66 },
        { x: 12, z: 13, dist: 64, yaw: 1.05, pitch: 0.72, t: 0.66 }] },
      { name: 'forum', seconds: 8, keys: [
        { x: forum[0], z: forum[1] - 2, dist: 34, yaw: 2.3, pitch: 0.62, t: 0.6 },
        { x: forum[0], z: forum[1] - 2, dist: 26, yaw: 2.9, pitch: 0.5, t: 0.6 },
        { x: forum[0], z: forum[1] - 2, dist: 20, yaw: 3.4, pitch: 0.42, t: 0.6 }] },
      { name: 'colosseum', seconds: 7, keys: [
        { x: col[0], z: col[1], dist: 17, yaw: -0.6, pitch: 0.5, lookY: 0.6, t: 0.68 },
        { x: col[0], z: col[1], dist: 13, yaw: 0.3, pitch: 0.36, lookY: 0.8, t: 0.68 },
        { x: col[0], z: col[1], dist: 11, yaw: 1.0, pitch: 0.3, lookY: 0.9, t: 0.68 }] },
      { name: 'street', seconds: 9, keys: this.streetKeys(), opts: { linear: true } },
      { name: 'garden', seconds: 7, keys: [
        { x: dh[0], z: dh[1], dist: 8, yaw: 0.9, pitch: 0.38, lookY: 0.3, t: 0.62 },
        { x: dh[0] + 0.5, z: dh[1], dist: 11, yaw: 1.4, pitch: 0.55, lookY: 0.2, t: 0.62 },
        { x: dh[0] + 1, z: dh[1], dist: 16, yaw: 1.8, pitch: 0.7, t: 0.62 }] },
      { name: 'pond', seconds: 7, keys: [
        { x: 19, z: 5, dist: 15, yaw: 2.6, pitch: 0.42, t: 0.7 },
        { x: 18.5, z: 5.5, dist: 12, yaw: 3.3, pitch: 0.34, t: 0.71 },
        { x: 18, z: 6, dist: 11, yaw: 3.9, pitch: 0.3, t: 0.72 }] },
      { name: 'sunset', seconds: 9, keys: [
        { x: 12, z: 26, dist: 58, yaw: 3.1, pitch: 0.3, t: 0.735 },
        { x: 12, z: 22, dist: 52, yaw: 2.85, pitch: 0.27, t: 0.755 },
        { x: 12, z: 18, dist: 48, yaw: 2.6, pitch: 0.25, t: 0.772 }] },
      { name: 'night', seconds: 9, keys: [
        { x: 12, z: 14, dist: 46, yaw: 0.8, pitch: 0.6, t: 0.9 },
        { x: 12, z: 13, dist: 36, yaw: 0.45, pitch: 0.5, t: 0.9 },
        { x: 12, z: 12, dist: 28, yaw: 0.1, pitch: 0.42, t: 0.9 }] },
      cat ? { name: 'cat', seconds: 5, keys: [
        { x: cat.wx, z: cat.wy, dist: 3.4, yaw: 0.5, pitch: 0.32, lookY: 0.1, t: 0.6 },
        { x: cat.wx, z: cat.wy, dist: 2.8, yaw: 0.9, pitch: 0.26, lookY: 0.1, t: 0.6 }],
        opts: { each() { const c = Cats.list[0]; if (c) { const k = Engine.cam; k.x = k.tx = c.wx; k.z = k.tz = c.wy; } } } } : null,
      this.battleShot('battle', 0, 6, 9, 9, 100),
      this.battleShot('elephant', 0, 6, 9, 10, 480),
      this.buildShot(),
      // Финал: от форума камера плавно поднимается и открывает весь город в золотом свете
      { name: 'finale', seconds: 10, keys: [
        { x: forum[0], z: forum[1], dist: 13, yaw: 4.1, pitch: 0.28, lookY: 0.6, t: 0.705 },
        { x: forum[0] - 1, z: forum[1] - 1, dist: 28, yaw: 4.5, pitch: 0.4, t: 0.71 },
        { x: 12, z: 12, dist: 52, yaw: 4.9, pitch: 0.55, t: 0.715 },
        { x: 12, z: 12, dist: 70, yaw: 5.15, pitch: 0.62, t: 0.72 }] },
    ].filter(Boolean);
  },

  // Бой в песках Карфагена: легион против наёмников, потом выходит боевой слон Ганнибала.
  // warm — сколько кадров боя прокрутить до начала записи; камера держится чуть выше схватки и медленно едет вбок
  battleShot(name, cycle, r, s, seconds, warm) {
    let t = 0, rec = false, origAvail = null;
    return { name, seconds, keys: null, opts: {
      warmSteps: warm,
      before() {
        const A = state.army;
        for (const u of UNIT_IDS) A.levels[u] = 10;
        A.squad = ['legionary', 'legionary', 'spearman', 'archer', 'ballista', 'catapult', 'legionary'];
        origAvail = Army.available;
        Army.available = () => true;
        state.goods.wheat = 9999;
        Battle.lastSpeed = 1;
        Battle.start(Army.stage(cycle, r, s));
        Battle.camHook = cam => {
          if (rec) t += 1 / 30;
          const x = Battle.camX;
          cam.position.set(x - 6.2 + t * 0.32, 3.4 + Math.sin(t * 0.4) * 0.15, 12.5 - t * 0.2);
          cam.lookAt(x + 0.9, 0.95, 0);
        };
      },
      each() { rec = true; },
      step(dt) { Battle.frame(dt); },
      after() {
        Battle.camHook = null;
        Army.available = origAvail;
        UI.closeModal();
        if (Battle.active) Battle.exit(false);
      },
    } };
  },

  // Стройка в ускорении: на пустой окраине тянется улица и вдоль неё один за другим вырастают дома
  buildShot() {
    const R = mulberry32(77);
    let site = null;
    for (let i = 0; i < 3000 && !site; i++) {
      const a = R() * Math.PI * 2, r = 46 + R() * 14, x = 12 + Math.cos(a) * r, y = 12 + Math.sin(a) * r;
      if (buildingsNear(x, y, 8).size || Roads.nearest(x, y, 8)) continue;
      let ok = true;
      for (let k = 0; k < 60 && ok; k++) { const px = x + (R() - 0.5) * 16, py = y + (R() - 0.5) * 16; if (isWater(groundAt(Math.floor(px), Math.floor(py))) || !isOwnedTile(Math.floor(px), Math.floor(py))) ok = false; }
      if (ok) site = [x, y];
    }
    if (!site) return null;
    // улица идёт от города наружу по дуге, камера смотрит на неё наискосок
    const [sx, sy] = site, r = Math.hypot(sx - 12, sy - 12), ux = (sx - 12) / r, uy = (sy - 12) / r, raw = [];
    for (let k = 0; k <= 40; k++) {
      const u = k / 40, along = -7 + u * 14, bend = 1.6 * Math.sin(u * Math.PI * 1.3) - 0.8;
      raw.push([sx - uy * along + ux * bend, sy + ux * along + uy * bend]);
    }
    const yaw = Math.atan2(ux, uy);
    let plan = null, placed = 0, slots = [];
    const N = 300;
    return { name: 'build', seconds: N / 30, keys: [
      { x: sx, z: sy, dist: 22, yaw: yaw + 0.35, pitch: 0.6, t: 0.66 },
      { x: sx, z: sy, dist: 19, yaw: yaw + 0.6, pitch: 0.52, t: 0.66 },
      { x: sx, z: sy, dist: 16.5, yaw: yaw + 0.85, pitch: 0.45, t: 0.66 }], opts: {
      before() { plan = Roads.plan(raw, false); },
      each(u, i) {
        if (!plan || plan.err) return;
        const xy = plan.path.xy, n = xy.length / 2;
        if (i < 45) Engine.setRoadPreview(xy.slice(0, Math.max(4, Math.floor(n * (i + 1) / 45)) * 2), '#f3e7c4');
        if (i === 48) {
          Engine.setRoadPreview(null);
          const made = Roads.build(plan);
          for (let k = 0; k < xy.length; k += 8) Engine.puff(xy[k], 0.2, xy[k + 1], '#d8cdb2', 3, 0.5, 0.8, 0.1, 0.6);
          const e = made.sort((a, b) => b.L - a.L)[0];
          for (let s = 1.2; e && s < e.L - 1; s += 2.2) for (const side of [1, -1]) slots.push([e, s, side]);
          slots.sort(() => R() - 0.5);
        }
        if (i > 60 && i % 9 === 0 && placed < slots.length) {
          const [e, s, side] = slots[placed++];
          const type = R() < 0.25 ? 'domus' : 'house';
          const b = Promo.byRoad(type, e, s, side, type === 'domus' ? 2 + Math.floor(R() * 2) : 2 + Math.floor(R() * 2));
          if (b) {
            b.born = performance.now();
            Engine.buildingsChanged(b);
            Engine.dust(b);
            const a = bAng(b), back = -(b.h / 2 + 0.7);
            Promo.put(R() < 0.5 ? 'cypress' : 'olive', b.x + b.w / 2 + Math.sin(a) * back, b.y + b.h / 2 + Math.cos(a) * back, R() * 6);
          }
        }
      },
    } };
  },

  start(only) {
    UI.setUiHidden(true);
    Cinema.setSize(2560, 1440);
    Atmos.cycle = false;
    this.populate();
    let list = this.list();
    if (only && only.length) list = list.filter(s => only.includes(s.name));
    Cinema.record(list);
    const iv = setInterval(() => { if (!Cinema.progress && Cinema.done.length + (Cinema.error ? 1 : 0) >= list.length) { this.finished = true; clearInterval(iv); } }, 500);
  },
};
