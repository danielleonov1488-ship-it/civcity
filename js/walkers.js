'use strict';
/* Жители, гуляющие по улицам. Чисто для красоты: на экономику не влияют.
   Каждый — фигурка из кубиков: роль, одежда по классу, походка и поворот по ходу движения. */

const SKIN = ['#eec3a0', '#d9a679', '#c58b5e', '#f3cfae', '#a8714b'];
const HAIR = ['#3b2a20', '#5a3a24', '#2a211b', '#8a5a2e', '#c9a46a', '#1e1a18', '#7a4a2a'];
const OUTFIT = {
  plebs: ['#b8875a', '#c9a36e', '#9a7b5a', '#d8c9a8', '#8f7a5a', '#a86a4a'],
  citizens: ['#5f8fbf', '#c96a4a', '#7fa35a', '#d8b26a', '#b85c5c', '#4f9a8f'],
  patricians: ['#f7f2e6', '#f2ece0', '#efe6d6'],
  women: ['#c97a8a', '#7aa0c8', '#d8b26a', '#9f7ab8', '#e6c9a0', '#8fb38a'],
};

const Walkers = {
  list: [],

  dress(w, h) {
    const cls = w.cls = BUILDINGS[h.type].tiers[h.tier].cls || 'plebs';
    const r = Math.random();
    w.cSkin = pick(SKIN);
    w.cHair = pick(HAIR);
    w.cLegs = w.cSkin;
    w.longHair = false;
    const soldiers = countType('barracks') > 0;
    if (soldiers && r < 0.08) {
      w.role = 'soldier';
      w.cTorso = '#b8452f';
      w.cAcc = '#c9a050';
      w.cHair = '#c9a050';
    } else if (r < 0.36) {
      w.role = 'woman';
      w.cTorso = cls === 'patricians' ? pick(['#f2ece0', '#c9a0d8', '#a8c8e8']) : pick(OUTFIT.women);
      w.longHair = true;
    } else if (r < 0.46) {
      w.role = 'child';
      w.cTorso = pick(OUTFIT[cls === 'patricians' ? 'women' : cls]);
    } else if (cls === 'patricians') {
      w.role = 'patrician';
      w.cTorso = pick(OUTFIT.patricians);
      w.cAcc = '#7a2f7e';
      w.cHair = pick(['#d8d2c4', '#3b2a20', '#8a7a6a']);
    } else if (r < 0.6 && cls === 'citizens') {
      w.role = 'merchant';
      w.cTorso = pick(OUTFIT.citizens);
      w.cAcc = pick(['#b8875a', '#c9a36e']);
    } else {
      w.role = 'common';
      w.cTorso = pick(OUTFIT[cls]);
    }
    w.cArms = w.role === 'patrician' ? w.cTorso : w.cSkin;
  },

  // Житель выходит из дома на ближайшую к фасаду точку улицы и идёт в случайную сторону
  spawn() {
    const houses = state.stats.connectedHouses;
    if (!houses || !houses.length) return;
    const h = pick(houses);
    const q = roadContact(h);
    if (!q) return;
    const w = {
      e: q.e.id, s: q.s, dir: Math.random() < 0.5 ? 1 : -1, dist: 0,
      wx: q.x, wy: q.y,
      lane: (Math.random() < 0.5 ? -1 : 1) * (0.17 + Math.random() * 0.12),
      speed: 0.5 + Math.random() * 0.35,
      life: 30 + Math.random() * 50, age: 0, alpha: 0, moving: true,
      seed: Math.random(), pause: 0, yaw: Math.random() * 6.28, walkPh: Math.random() * 6.28,
    };
    this.dress(w, h);
    if (w.role === 'child') w.speed *= 1.25;
    // в новом виде жители настоящего роста и шагают по-настоящему — идут медленнее
    if (NEW_LOOK) w.speed *= 0.38;
    this.list.push(w);
  },

  // Улица кончилась узлом: чаще прямо, иногда сворачивают; в тупике разворачиваются
  nextEdge(w, e, nid) {
    const node = Roads.nodes.get(nid);
    const opts = node ? [...node.edges].filter(id => id !== e.id).map(id => Roads.edges.get(id)).filter(Boolean) : [];
    if (!opts.length) return { e, dir: -w.dir };
    const end = Roads.pointAt(e, nid === e.b ? e.L : 0);
    const ix = end.tx * w.dir, iy = end.ty * w.dir;
    let best = opts[0], bd = -2;
    for (const o of opts) {
      const p = Roads.pointAt(o, o.a === nid ? 0 : o.L), k = o.a === nid ? 1 : -1;
      const d = p.tx * k * ix + p.ty * k * iy;
      if (d > bd) { bd = d; best = o; }
    }
    const next = bd > 0.5 && Math.random() < 0.65 ? best : pick(opts);
    return { e: next, dir: next.a === nid ? 1 : -1 };
  },

  update(dt, realDt) {
    const pop = state.stats.pop || 0;
    const target = Math.min(360, Math.floor(pop / 3));
    if (this.list.length < target && Math.random() < 0.35) this.spawn();

    for (const w of this.list) {
      w.age += realDt;
      if (dt > 0) w.life -= dt;
      roadStep(w, dt, realDt);
      w.alpha = clamp(Math.min(w.age * 2, (w.life + 0.5) * 2), 0, 1);
    }
    this.list = this.list.filter(w => w.life > -0.5);
  },
};

// Шаг по улицам — общий для жителей и кошек: вдоль кривой улицы, по своей стороне, лицом по ходу.
// onTile вызывается примерно через каждую клетку пути: тогда фигурка может присесть или остановиться.
function roadStep(w, dt, realDt, onTile) {
  let e = Roads.edges.get(w.e);
  if (!e) { w.life = Math.min(w.life, 0); w.moving = false; return; }
  if (dt > 0) {
    if (w.pause > 0) { w.pause -= dt; w.moving = false; }
    else {
      w.moving = true;
      const step = dt * w.speed;
      w.walkPh += step * (w.stride || 11);
      w.s += step * w.dir;
      w.dist = (w.dist || 0) + step;
      if (w.dist >= 1) {
        w.dist -= 1;
        if (!onTile && Math.random() < 0.06) w.pause = 1.5 + Math.random() * 3;
        if (onTile) onTile(w);
      }
      if (w.s < 0 || w.s > e.L) {
        const nid = w.s < 0 ? e.a : e.b, over = w.s < 0 ? -w.s : w.s - e.L;
        const next = Walkers.nextEdge(w, e, nid);
        e = next.e;
        w.e = e.id;
        w.dir = next.dir;
        w.s = clamp(w.dir > 0 ? over : e.L - over, 0, e.L);
      }
    }
  } else w.moving = false;
  const p = Roads.pointAt(e, w.s);
  const dx = p.tx * w.dir, dy = p.ty * w.dir;
  // смещение поперёк направления движения; присевшая кошка отходит к краю дороги
  const lane = w.pause > 0 && w.sitLane ? w.sitLane : w.lane;
  const tox = -dy * lane, toy = dx * lane;
  const k = Math.min(1, realDt * 6);
  w.ox = w.ox === undefined ? tox : w.ox + (tox - w.ox) * k;
  w.oy = w.oy === undefined ? toy : w.oy + (toy - w.oy) * k;
  w.wx = p.x + w.ox;
  w.wy = p.y + w.oy;
  // плавный поворот: по ходу движения, а сидя — куда захотелось посмотреть
  const want = w.pause > 0 && w.sitYaw !== undefined ? w.sitYaw : Math.atan2(dx, dy);
  if (want !== null) {
    let d = want - w.yaw;
    d = Math.atan2(Math.sin(d), Math.cos(d));
    w.yaw += d * Math.min(1, realDt * (w.pause > 0 ? 3 : 8));
  }
}

/* Кошки: гуляют по улицам, присаживаются у края дороги, умываются и машут хвостом.
   В богатых кварталах их больше. */

const CAT_COATS = [
  ['#d98a3d', '#f4e3c8'], // рыжая с белой грудкой
  ['#e0a35e', '#e0a35e'], // светло-рыжая
  ['#8d8781', '#ece7df'], // серая
  ['#2d2824', '#2d2824'], // чёрная
  ['#2d2824', '#f1ece2'], // чёрно-белая
  ['#f1ece2', '#f1ece2'], // белая
  ['#c9a172', '#f1e6d2'], // кремовая
  ['#6a5646', '#d8c8b0'], // бурая
];

const Cats = {
  list: [],

  update(dt, realDt) {
    const houses = state.stats.connectedHouses || [];
    // кошек чуть больше: примерно одна на три дома
    const target = Math.min(72, Math.floor(houses.length / 3));
    if (this.list.length < target && Math.random() < 0.06) this.spawn(houses);
    for (const c of this.list) {
      c.age += realDt;
      c.anim += realDt;
      if (dt > 0) c.life -= dt;
      roadStep(c, dt, realDt, cat => this.onTile(cat));
      c.alpha = clamp(Math.min(c.age * 2, (c.life + 0.5) * 2), 0, 1);
    }
    this.list = this.list.filter(c => c.life > -0.5);
  },

  spawn(houses) {
    // из трёх случайных домов кошка выбирает самый богатый
    let h = pick(houses);
    for (let i = 0; i < 2; i++) { const o = pick(houses); if (o.tier > h.tier) h = o; }
    const q = roadContact(h);
    if (!q) return;
    const [body, chest] = pick(CAT_COATS);
    const side = Math.random() < 0.5 ? -1 : 1;
    const c = {
      e: q.e.id, s: q.s, dir: Math.random() < 0.5 ? 1 : -1, dist: 0,
      wx: q.x, wy: q.y,
      lane: side * (0.28 + Math.random() * 0.08), sitLane: side * 0.36,
      speed: 0.32 + Math.random() * 0.22, stride: 17,
      life: 90 + Math.random() * 90, age: 0, alpha: 0, moving: false, anim: Math.random() * 10,
      yaw: Math.random() * 6.28, walkPh: Math.random() * 6.28,
      cBody: body, cChest: chest, cEye: body === '#2d2824' ? '#d9c43a' : '#2b2418',
    };
    c.pause = 2 + Math.random() * 4;
    c.sitYaw = c.yaw;
    this.list.push(c);
  },

  onTile(c) {
    if (Math.random() < 0.3) {
      c.pause = 3 + Math.random() * 8;
      c.groom = Math.random() < 0.45;
      c.sitYaw = c.yaw + (Math.random() - 0.5) * 2.5;
    } else c.sitYaw = undefined;
  },
};
