'use strict';
/* Жители, гуляющие по мостовой. Чисто для красоты: на экономику не влияют.
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

  // Житель выходит из дома на мостовую у фасада и идёт вдоль дома в случайную сторону
  spawn() {
    const houses = state.stats.connectedHouses;
    if (!houses || !houses.length) return;
    const h = pick(houses);
    const q = roadContact(h);
    if (!q) return;
    const head = q.dir + (Math.random() < 0.5 ? 1 : -1) * Math.PI / 2;
    const w = {
      wx: q.x, wy: q.y, head, want: head, dist: 0,
      lane: (Math.random() < 0.5 ? -1 : 1) * (0.1 + Math.random() * 0.2),
      speed: 0.5 + Math.random() * 0.35,
      life: 30 + Math.random() * 50, age: 0, alpha: 0, moving: true,
      seed: Math.random(), pause: 0, yaw: head, walkPh: Math.random() * 6.28,
    };
    this.dress(w, h);
    if (w.role === 'child') w.speed *= 1.25;
    // в новом виде жители настоящего роста и шагают по-настоящему — идут медленнее
    if (NEW_LOOK) w.speed *= 0.38;
    this.list.push(w);
  },

  update(dt, realDt) {
    Settlers.update(dt, realDt);
    const pop = state.stats.pop || 0;
    const target = Math.min(360, Math.floor(pop / 3));
    if (this.list.length < target && Math.random() < 0.35) this.spawn();

    for (const w of this.list) {
      w.age += realDt;
      if (dt > 0) w.life -= dt;
      if (w.settler) Settlers.step(w, dt, realDt);
      else paveStep(w, dt, realDt);
      w.alpha = clamp(Math.min(w.age * 2, (w.life + 0.5) * 2), 0, 1);
    }
    this.list = this.list.filter(w => w.life > -0.5);
  },
};

// Шаг по мостовой — общий для жителей и кошек. Идут, куда глаза глядят, но только по камням: впереди край или
// стена — сворачивают туда, где дальше свободно; на узкой улице держатся своей стороны. Без старых линий дорог —
// гуляют по любой мостовой, площади и тропинке. onTile — примерно через каждую клетку пути: присесть или постоять.
function paveStep(w, dt, realDt, onTile) {
  if (dt > 0) {
    if (w.pause > 0) { w.pause -= dt; w.moving = false; }
    else {
      w.think = (w.think || 0) - dt;
      if (w.think <= 0) { steer(w); w.think = 0.25 + Math.random() * 0.2; }
      let d = w.want - w.head;
      d = Math.atan2(Math.sin(d), Math.cos(d));
      w.head += clamp(d, -dt * 2.4, dt * 2.4);
      const step = dt * w.speed, sx = Math.sin(w.head), sy = Math.cos(w.head);
      if (Paving.walkable(w.wx + sx * (step + 0.1), w.wy + sy * (step + 0.1))) {
        w.wx += sx * step;
        w.wy += sy * step;
        w.moving = true;
        w.stuck = 0;
        w.walkPh += step * (w.stride || 11);
        w.dist = (w.dist || 0) + step;
        if (w.dist >= 1) {
          w.dist -= 1;
          if (!onTile && Math.random() < 0.06) w.pause = 1.5 + Math.random() * 3;
          if (onTile) onTile(w);
        }
      } else {
        // упёрся: подумать сразу, а если долго некуда — развернуться
        w.moving = false;
        w.think = 0;
        w.stuck = (w.stuck || 0) + dt;
        if (w.stuck > 1.2) { w.head = w.want = w.head + Math.PI * (0.7 + Math.random() * 0.6); w.stuck = 0; }
      }
    }
  } else w.moving = false;
  // мостовую под ногами стёрли или застроили — житель уходит
  if (!Paving.walkable(w.wx, w.wy)) { w.lost = (w.lost || 0) + realDt; if (w.lost > 1) w.life = Math.min(w.life, 0); }
  else w.lost = 0;
  // плавный поворот: по ходу движения, а сидя — куда захотелось посмотреть
  const want = w.pause > 0 && w.sitYaw !== undefined ? w.sitYaw : w.head;
  let d = want - w.yaw;
  d = Math.atan2(Math.sin(d), Math.cos(d));
  w.yaw += d * Math.min(1, realDt * (w.pause > 0 ? 3 : 8));
}

// Как далеко можно пройти от жителя в направлении a (до max, шагом st)
function freeAhead(w, a, max, st) {
  const sx = Math.sin(a), sy = Math.cos(a);
  let d = 0;
  while (d < max && Paving.walkable(w.wx + sx * (d + st), w.wy + sy * (d + st))) d += st;
  return d;
}

// Куда идти дальше: чаще прямо, иногда сворачивают; где свободнее — туда охотнее; в тупике — назад
function steer(w) {
  const h = w.head;
  let best = h, bs = -1e9;
  for (const da of [0, 0.35, -0.35, 0.8, -0.8, 1.4, -1.4, 2.1, -2.1, Math.PI]) {
    const f = freeAhead(w, h + da, 1.6, 0.2);
    const s = Math.min(f, 1.2) * 1.4 - Math.abs(da) * 0.45 + Math.random() * (f > 1 ? 0.5 : 0.2);
    if (s > bs) { bs = s; best = h + da; }
  }
  // на улице (по бокам близко края) — держаться своей стороны, а не середины
  if (Math.abs(best - h) < 0.5) {
    const l = freeAhead(w, best - Math.PI / 2, 1.2, 0.1), r = freeAhead(w, best + Math.PI / 2, 1.2, 0.1);
    if (l + r < 2.2) {
      const target = clamp((l + r) / 2 + (w.lane || 0), 0.12, Math.max(0.12, l + r - 0.12));
      best += clamp((r - target) * 0.6, -0.3, 0.3);
    }
  }
  w.want = best;
}

/* Кошки: гуляют по мостовой, присаживаются, умываются и машут хвостом.
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
      paveStep(c, dt, realDt, cat => this.onTile(cat));
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
    const head = q.dir + side * Math.PI / 2;
    const c = {
      wx: q.x, wy: q.y, head, want: head, dist: 0,
      lane: side * (0.25 + Math.random() * 0.1),
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
