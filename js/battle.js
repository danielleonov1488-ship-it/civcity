'use strict';
/* Бой в 3D: поле провинции, фигурки римлян и врагов с руками и ногами, снаряды, умения,
   полоски здоровья и цифры урона. Правила боя — в BattleSim (army.js); здесь только картинка и экран. */

/* ---------- Фигурки ----------
   Модель смотрит вдоль +z, правая рука — на стороне −x. Части — отдельные группы с поворотом
   в суставе (бедро, плечо, шея), чтобы шагать и бить. */

const FIG = {
  skin: '#e7b48a', skinDark: '#c98e64', skinPale: '#f1cba6',
  red: '#b3352a', redDark: '#8c2a22', gold: '#e3b445', steel: '#c3c7cc', steelDark: '#8d939b', bronze: '#b58a4a',
  leather: '#8a5a36', leatherDark: '#5e3c24', wood: '#9a6b44', woodDark: '#6e4a2f', rope: '#cdb88f', cloth: '#efe6d2',
};

function figPart(parent, fn, mat, glowMat, x, y, z) {
  const g = new THREE.Group();
  g.position.set(x || 0, y || 0, z || 0);
  if (fn) {
    const mb = new MB(11);
    fn(mb);
    const geo = mb.build(0, 0);
    if (geo.solid) { const m = new THREE.Mesh(geo.solid, mat); m.castShadow = true; g.add(m); }
    if (geo.glow) g.add(new THREE.Mesh(geo.glow, glowMat));
  }
  parent.add(g);
  return g;
}

const NOAO = { ao: 1 };

// Человечек: ноги, туловище с юбкой туники, голова, руки; оружие в правой руке, щит или лук — в левой
function humanoid(mat, glow, o) {
  const B = o.bulk || 1, root = new THREE.Group();
  const fig = { root, kind: 'human', mat };
  const legW = 0.055 * B;
  const leg = mb => {
    mb.box(-legW, -0.42, -0.06, legW, 0, 0.06, o.legs || o.skin, NOAO);
    mb.box(-legW - 0.01, -0.42, -0.07, legW + 0.01, -0.36, 0.09, o.boots || FIG.leatherDark, NOAO);
    if (o.greaves) mb.box(-legW - 0.012, -0.34, 0.0, legW + 0.012, -0.12, 0.07, o.greaves, NOAO);
  };
  fig.legL = figPart(root, leg, mat, glow, 0.075 * B, 0.42, 0);
  fig.legR = figPart(root, leg, mat, glow, -0.075 * B, 0.42, 0);
  fig.body = figPart(root, null, mat, glow, 0, 0.42, 0);
  figPart(fig.body, mb => {
    mb.box(-0.15 * B, 0.02, -0.09 * B, 0.15 * B, 0.36, 0.09 * B, o.tunic, NOAO);
    mb.box(-0.17 * B, -0.07, -0.11 * B, 0.17 * B, 0.1, 0.11 * B, o.skirt || o.tunic, NOAO);
    if (o.belt) mb.box(-0.155 * B, 0.08, -0.095 * B, 0.155 * B, 0.12, 0.095 * B, o.belt, NOAO);
    if (o.torso) o.torso(mb, B);
  }, mat, glow);
  fig.head = figPart(fig.body, mb => {
    const hs = o.headScale || 1, w = 0.1 * hs;
    mb.box(-w, 0, -w, w, 0.2 * hs, w, o.skin, NOAO);
    if (!o.noEyes) {
      mb.box(-0.06 * hs, 0.1 * hs, w, -0.025 * hs, 0.13 * hs, w + 0.008, o.eyes || '#2b1d14', NOAO);
      mb.box(0.025 * hs, 0.1 * hs, w, 0.06 * hs, 0.13 * hs, w + 0.008, o.eyes || '#2b1d14', NOAO);
    }
    if (o.hair) {
      mb.box(-w - 0.01, 0.15 * hs, -w - 0.01, w + 0.01, 0.22 * hs, w + 0.01, o.hair, NOAO);
      mb.box(-w - 0.01, 0.04 * hs, -w - 0.012, w + 0.01, 0.2 * hs, -w + 0.04, o.hair, NOAO);
    }
    if (o.beard) mb.box(-w + 0.01, -0.03, w - 0.03, w - 0.01, 0.08 * hs, w + 0.025, o.beard, NOAO);
    if (o.head) o.head(mb, hs);
  }, mat, glow, 0, 0.36, 0);
  const arm = side => mb => {
    mb.box(-0.045, -0.15, -0.045, 0.045, 0.02, 0.045, o.sleeve || o.tunic, NOAO);
    mb.box(-0.04, -0.3, -0.04, 0.04, -0.15, 0.04, o.arms || o.skin, NOAO);
    mb.box(-0.045, -0.35, -0.045, 0.045, -0.29, 0.045, o.hands || o.skin, NOAO);
    if (o.bracer) mb.box(-0.047, -0.27, -0.047, 0.047, -0.18, 0.047, o.bracer, NOAO);
  };
  fig.armL = figPart(fig.body, arm('L'), mat, glow, 0.2 * B, 0.33, 0);
  fig.armR = figPart(fig.body, arm('R'), mat, glow, -0.2 * B, 0.33, 0);
  if (o.weapon) fig.weapon = figPart(fig.armR, o.weapon, mat, glow, 0, -0.33, 0);
  if (o.offhand) fig.offhand = figPart(fig.armL, o.offhand, mat, glow, 0, -0.33, 0);
  if (o.shield) fig.shield = figPart(fig.body, o.shield, mat, glow, 0.16 * B, 0.04, 0.17 * B);
  if (o.back) figPart(fig.body, o.back, mat, glow, 0, 0, -0.1 * B);
  fig.pose = o.pose || 'sword';
  return fig;
}

// Четвероногий зверь: туловище, голова на шее, четыре ноги, хвост
function quadruped(mat, glow, o) {
  const root = new THREE.Group(), fig = { root, kind: 'beast', mat };
  const L = o.len, H = o.legLen, W = o.wide;
  fig.body = figPart(root, mb => {
    mb.box(-W, 0, -L / 2, W, o.bodyH, L / 2, o.color, NOAO);
    if (o.belly) mb.box(-W + 0.02, -0.02, -L / 2 + 0.08, W - 0.02, 0.05, L / 2 - 0.08, o.belly, NOAO);
    if (o.mane) mb.box(-W - 0.02, o.bodyH * 0.45, L / 2 - 0.3, W + 0.02, o.bodyH + 0.06, L / 2 + 0.02, o.mane, NOAO);
    if (o.ridge) mb.box(-0.03, o.bodyH, -L / 2 + 0.05, 0.03, o.bodyH + 0.05, L / 2 - 0.05, o.ridge, NOAO);
    if (o.extra) o.extra(mb);
  }, mat, glow, 0, H, 0);
  const leg = mb => {
    mb.box(-o.legW, -H, -o.legW, o.legW, 0.04, o.legW, o.legColor || o.color, NOAO);
    mb.box(-o.legW - 0.005, -H, -o.legW - 0.005, o.legW + 0.005, -H + 0.05, o.legW + 0.01, o.paw || o.legColor || o.color, NOAO);
  };
  const lx = W - o.legW, lz = L / 2 - o.legW - 0.03;
  fig.legs = [[lx, lz], [-lx, lz], [lx, -lz], [-lx, -lz]].map(([x, z]) => figPart(root, leg, mat, glow, x, H + 0.02, z));
  fig.heads = (o.heads || [0]).map((hx, i) => figPart(fig.body, mb => o.head(mb, i), mat, glow, hx, o.headY, L / 2 + (o.neck || 0)));
  fig.head = fig.heads[0];
  if (o.tail) fig.tail = figPart(fig.body, o.tail, mat, glow, 0, o.bodyH * 0.8, -L / 2);
  return fig;
}

/* Детали снаряжения */
const GEAR = {
  gladius: mb => {
    mb.box(-0.018, -0.03, -0.02, 0.018, 0.03, 0.06, FIG.leatherDark, NOAO);
    mb.box(-0.04, -0.02, 0.05, 0.04, 0.02, 0.075, FIG.gold, NOAO);
    mb.box(-0.022, -0.012, 0.075, 0.022, 0.012, 0.36, FIG.steel, NOAO);
  },
  longsword: mb => {
    mb.box(-0.018, -0.03, -0.02, 0.018, 0.03, 0.07, FIG.leatherDark, NOAO);
    mb.box(-0.06, -0.02, 0.06, 0.06, 0.02, 0.085, FIG.steelDark, NOAO);
    mb.box(-0.02, -0.012, 0.085, 0.02, 0.012, 0.55, FIG.steel, NOAO);
  },
  club: mb => {
    mb.box(-0.025, -0.025, -0.04, 0.025, 0.025, 0.2, FIG.wood, NOAO);
    mb.box(-0.05, -0.05, 0.2, 0.05, 0.05, 0.4, FIG.woodDark, NOAO);
  },
  axe: (mb, s) => {
    s = s || 1;
    mb.box(-0.02 * s, -0.02 * s, -0.08 * s, 0.02 * s, 0.02 * s, 0.5 * s, FIG.wood, NOAO);
    mb.box(-0.012 * s, -0.02 * s, 0.32 * s, 0.012 * s, 0.17 * s, 0.48 * s, FIG.steel, NOAO);
  },
  spear: mb => {
    mb.box(-0.016, -0.016, -0.45, 0.016, 0.016, 1.05, FIG.wood, NOAO);
    mb.box(-0.03, -0.012, 1.05, 0.03, 0.012, 1.22, FIG.steel, NOAO);
    mb.box(-0.02, -0.02, -0.5, 0.02, 0.02, -0.44, FIG.bronze, NOAO);
  },
  bow: mb => {
    const segs = [[-0.36, -0.2, 0.07], [-0.2, -0.06, 0.11], [-0.06, 0.06, 0.12], [0.06, 0.2, 0.11], [0.2, 0.36, 0.07]];
    for (const [y0, y1, z] of segs) mb.box(-0.017, y0, z - 0.02, 0.017, y1, z + 0.02, FIG.woodDark, NOAO);
    mb.box(-0.004, -0.34, 0.03, 0.004, 0.34, 0.036, FIG.cloth, NOAO);
  },
  sling: mb => {
    mb.box(-0.008, -0.008, 0, 0.008, 0.008, 0.18, FIG.rope, NOAO);
    mb.box(-0.03, -0.03, 0.17, 0.03, 0.03, 0.22, FIG.leather, NOAO);
  },
  scutum: mb => {
    // выпуклый щит из трёх досок: красный, с золотым умбоном и кантом
    const parts = [[-0.22, -0.08, 0.025], [-0.08, 0.08, 0.04], [0.08, 0.22, 0.025]];
    for (const [x0, x1, z] of parts) {
      mb.box(x0, 0, z - 0.03, x1, 0.5, z, FIG.red, NOAO);
      mb.box(x0, 0.0, z - 0.032, x1, 0.025, z + 0.003, FIG.gold, NOAO);
      mb.box(x0, 0.475, z - 0.032, x1, 0.5, z + 0.003, FIG.gold, NOAO);
    }
    mb.box(-0.06, 0.2, 0.035, 0.06, 0.31, 0.07, FIG.gold, NOAO);
    mb.box(-0.012, 0.03, 0.04, 0.012, 0.47, 0.05, FIG.gold, NOAO);
    mb.box(-0.2, 0.245, 0.03, 0.2, 0.265, 0.045, FIG.gold, NOAO);
  },
  roundShield: color => mb => {
    mb.cyl(0, 0.24, 0, 0.21, 0.04, color, { segs: 12, ao: 1 });
    mb.cyl(0, 0.24, 0.0, 0.07, 0.07, FIG.bronze, { segs: 8, ao: 1 });
  },
  ovalShield: color => mb => {
    mb.box(-0.15, 0, -0.03, 0.15, 0.55, 0.01, color, NOAO);
    mb.box(-0.11, -0.04, -0.03, 0.11, 0.0, 0.01, color, NOAO);
    mb.box(-0.11, 0.55, -0.03, 0.11, 0.59, 0.01, color, NOAO);
    mb.box(-0.025, 0.05, 0.01, 0.025, 0.5, 0.04, FIG.wood, NOAO);
    mb.box(-0.05, 0.24, 0.01, 0.05, 0.32, 0.05, FIG.steelDark, NOAO);
  },
};

// Шлем легионера: железный купол, нащёчники, назатыльник и красный гребень
function galea(mb, hs, crest) {
  const w = 0.1 * hs;
  mb.box(-w - 0.02, 0.14 * hs, -w - 0.02, w + 0.02, 0.25 * hs, w + 0.02, FIG.steel, NOAO);
  mb.box(-w - 0.02, 0.0, -w - 0.03, w + 0.02, 0.16 * hs, -w + 0.02, FIG.steel, NOAO);
  mb.box(-w - 0.025, 0.02, -w - 0.07, w + 0.025, 0.06, -w - 0.01, FIG.steelDark, NOAO);
  mb.box(-w - 0.022, 0.02, w - 0.08, -w + 0.01, 0.16 * hs, w + 0.005, FIG.steel, NOAO);
  mb.box(w - 0.01, 0.02, w - 0.08, w + 0.022, 0.16 * hs, w + 0.005, FIG.steel, NOAO);
  mb.box(-w - 0.025, 0.17 * hs, w, w + 0.025, 0.19 * hs, w + 0.03, FIG.bronze, NOAO);
  if (crest) for (let i = 0; i < 5; i++) mb.box(-0.025, 0.25 * hs, -w + i * 0.045, 0.025, 0.25 * hs + 0.08 + Math.sin(i / 4 * Math.PI) * 0.03, -w + i * 0.045 + 0.05, crest, NOAO);
}

// Сегментный доспех легионера поверх туники
function lorica(mb, B) {
  for (let i = 0; i < 4; i++) {
    const y = 0.1 + i * 0.065;
    mb.box(-0.16 * B, y, -0.1 * B, 0.16 * B, y + 0.055, 0.1 * B, i % 2 ? FIG.steel : '#d3d6da', NOAO);
  }
  mb.box(-0.19 * B, 0.29, -0.1 * B, -0.1 * B, 0.37, 0.1 * B, FIG.steel, NOAO);
  mb.box(0.1 * B, 0.29, -0.1 * B, 0.19 * B, 0.37, 0.1 * B, FIG.steel, NOAO);
  for (let i = 0; i < 5; i++) mb.box(-0.13 * B + i * 0.06, -0.12, 0.1 * B, -0.11 * B + i * 0.06, 0.08, 0.115 * B, FIG.leather, NOAO);
}

/* ---------- Модели по видам ---------- */
const MODELS = {
  legionary: (m, g) => humanoid(m, g, {
    skin: FIG.skin, tunic: FIG.red, legs: FIG.skin, boots: FIG.leatherDark, belt: FIG.leather,
    torso: lorica, head: (mb, hs) => galea(mb, hs, FIG.red), weapon: GEAR.gladius, shield: GEAR.scutum, pose: 'sword',
  }),
  spearman: (m, g) => humanoid(m, g, {
    skin: FIG.skin, tunic: '#7c3a2c', legs: FIG.skin, greaves: FIG.bronze, belt: FIG.leatherDark, bulk: 1.12,
    torso: (mb, B) => {
      mb.box(-0.165 * B, 0.08, -0.1 * B, 0.165 * B, 0.37, 0.1 * B, '#9aa0a8', NOAO);
      for (let i = 0; i < 6; i++) mb.box(-0.165 * B, 0.1 + i * 0.045, 0.1 * B, 0.165 * B, 0.115 + i * 0.045, 0.106 * B, '#7d838c', NOAO);
    },
    head: (mb, hs) => {
      const w = 0.1 * hs;
      mb.box(-w - 0.02, 0.13 * hs, -w - 0.02, w + 0.02, 0.26 * hs, w + 0.02, FIG.bronze, NOAO);
      mb.box(-w - 0.02, 0.0, -w - 0.02, w + 0.02, 0.14 * hs, -w + 0.03, FIG.bronze, NOAO);
      for (let i = 0; i < 4; i++) mb.box(-0.018, 0.26 * hs, -w + 0.02 + i * 0.04, 0.018, 0.36 * hs - i * 0.012, -w + 0.06 + i * 0.04, '#f2ead8', NOAO);
    },
    weapon: GEAR.spear, shield: GEAR.roundShield('#3e5f8a'), pose: 'spear',
  }),
  archer: (m, g) => humanoid(m, g, {
    skin: FIG.skin, tunic: '#5f7d3a', legs: FIG.skin, belt: FIG.leather, sleeve: '#5f7d3a', bracer: FIG.leather,
    torso: (mb, B) => { mb.box(-0.155 * B, 0.12, -0.095 * B, 0.155 * B, 0.34, 0.095 * B, FIG.leather, NOAO); mb.box(0.06, 0.12, 0.095 * B, 0.1, 0.34, 0.1 * B, FIG.leatherDark, NOAO); },
    hair: '#5a3a24',
    head: (mb, hs) => { const w = 0.1 * hs; mb.box(-w - 0.02, 0.15 * hs, -w - 0.02, w + 0.02, 0.24 * hs, w + 0.02, '#8a6a3c', NOAO); mb.box(-0.03, 0.24 * hs, -0.03, 0.03, 0.29 * hs, 0.03, '#8a6a3c', NOAO); },
    offhand: GEAR.bow,
    back: mb => { mb.box(-0.05, 0.05, -0.05, 0.05, 0.38, 0.03, FIG.leatherDark, NOAO); for (let i = 0; i < 4; i++) mb.box(-0.04 + i * 0.025, 0.38, -0.03, -0.03 + i * 0.025, 0.46, -0.01, '#f2ede2', NOAO); },
    pose: 'bow',
  }),
  bandit: (m, g) => humanoid(m, g, {
    skin: FIG.skinDark, tunic: '#6e5236', legs: '#4e3d2c', belt: '#3a2a1c', beard: '#3a2a1e', pose: 'sword',
    head: (mb, hs) => { const w = 0.1 * hs; mb.box(-w - 0.025, 0.12 * hs, -w - 0.025, w + 0.025, 0.25 * hs, w + 0.02, '#5a4128', NOAO); mb.box(-w - 0.025, 0.0, -w - 0.03, w + 0.025, 0.2 * hs, -w + 0.04, '#5a4128', NOAO); },
    weapon: GEAR.club,
  }),
  slinger: (m, g) => humanoid(m, g, {
    skin: FIG.skinDark, tunic: '#a8916a', legs: '#5e4a34', belt: FIG.leatherDark, hair: '#3a2a1e', pose: 'sling', weapon: GEAR.sling,
  }),
  gaul: (m, g) => humanoid(m, g, {
    skin: FIG.skinPale, tunic: '#3f6694', skirt: '#2f527a', legs: '#a4572f', belt: '#c9a050', hair: '#d8b45a', bulk: 1.05,
    beard: null, head: (mb, hs) => { mb.box(-0.09, 0.06 * hs, 0.1 * hs, 0.09, 0.09 * hs, 0.115 * hs, '#c9a14e', NOAO); mb.box(-0.11, 0.0, 0.1 * hs - 0.02, -0.07, 0.07 * hs, 0.115 * hs, '#c9a14e', NOAO); mb.box(0.07, 0.0, 0.1 * hs - 0.02, 0.11, 0.07 * hs, 0.115 * hs, '#c9a14e', NOAO); },
    torso: (mb, B) => { for (let i = 0; i < 3; i++) mb.box(-0.152 * B, 0.08 + i * 0.1, -0.092 * B, 0.152 * B, 0.11 + i * 0.1, 0.092 * B, '#2b4c73', NOAO); },
    weapon: GEAR.longsword, shield: GEAR.ovalShield('#4d7a3a'), pose: 'sword',
  }),
  gaulArcher: (m, g) => humanoid(m, g, {
    skin: FIG.skinPale, tunic: '#5a7a9a', legs: '#a4572f', belt: '#c9a050', hair: '#d8b45a', offhand: GEAR.bow, pose: 'bow',
    back: mb => { mb.box(-0.05, 0.05, -0.05, 0.05, 0.38, 0.03, FIG.leatherDark, NOAO); },
  }),
  berserker: (m, g) => humanoid(m, g, {
    skin: '#eab48c', tunic: '#eab48c', skirt: '#6b5a48', legs: '#5a4a3a', belt: '#3a2a1c', hair: '#b4512a', beard: '#b4512a', bulk: 1.1,
    torso: (mb, B) => { mb.box(-0.2 * B, 0.28, -0.12 * B, 0.2 * B, 0.4, 0.12 * B, '#8d8478', NOAO); mb.box(-0.2 * B, 0.0, -0.13 * B, 0.2 * B, 0.4, -0.08 * B, '#7a7166', NOAO); },
    weapon: mb => GEAR.axe(mb, 1.1), pose: 'sword',
  }),
  pirate: (m, g) => humanoid(m, g, {
    skin: FIG.skinDark, tunic: '#e9e1cf', legs: '#3d4a62', belt: '#a23a2a', beard: '#2a211b', pose: 'sword',
    torso: (mb, B) => { for (let i = 0; i < 4; i++) mb.box(-0.152 * B, 0.06 + i * 0.08, -0.092 * B, 0.152 * B, 0.1 + i * 0.08, 0.092 * B, '#a23a2a', NOAO); },
    head: (mb, hs) => { const w = 0.1 * hs; mb.box(-w - 0.015, 0.15 * hs, -w - 0.015, w + 0.015, 0.23 * hs, w + 0.015, '#b8392b', NOAO); mb.box(w - 0.01, 0.06, 0.0, w + 0.02, 0.09, 0.03, FIG.gold, NOAO); },
    weapon: GEAR.longsword,
  }),
  mercenary: (m, g) => humanoid(m, g, {
    skin: '#c58b5e', tunic: '#6a3a72', legs: '#c58b5e', greaves: FIG.bronze, belt: FIG.bronze, bulk: 1.08,
    torso: (mb, B) => { mb.box(-0.165 * B, 0.12, -0.1 * B, 0.165 * B, 0.37, 0.1 * B, FIG.bronze, NOAO); mb.box(-0.04, 0.2, 0.1 * B, 0.04, 0.3, 0.11 * B, FIG.gold, NOAO); },
    head: (mb, hs) => { const w = 0.1 * hs; mb.box(-w - 0.02, 0.12 * hs, -w - 0.02, w + 0.02, 0.27 * hs, w + 0.02, FIG.bronze, NOAO); mb.box(-0.03, 0.27 * hs, -0.02, 0.03, 0.34 * hs, 0.08, FIG.bronze, NOAO); },
    weapon: GEAR.spear, shield: GEAR.roundShield('#6a3a72'), pose: 'spear',
  }),
  shade: (m, g) => humanoid(m, g, {
    skin: '#5c5866', tunic: '#2e2b36', legs: '#2e2b36', boots: '#1d1b22', belt: '#4a4555', eyes: '#ff6a3a', bulk: 1.08,
    torso: (mb, B) => { mb.box(-0.165 * B, 0.1, -0.1 * B, 0.165 * B, 0.37, 0.1 * B, '#45414f', NOAO); mb.box(-0.2 * B, 0.3, -0.11 * B, 0.2 * B, 0.38, 0.11 * B, '#3a3644', NOAO); },
    head: (mb, hs) => { const w = 0.1 * hs; mb.box(-w - 0.02, 0.0, -w - 0.02, w + 0.02, 0.26 * hs, w - 0.06, '#3a3644', NOAO); mb.box(-w - 0.02, 0.15 * hs, -w - 0.02, w + 0.02, 0.26 * hs, w + 0.02, '#3a3644', NOAO); mb.glow = true; mb.box(-0.06, 0.1 * hs, w + 0.004, -0.025, 0.13 * hs, w + 0.014, '#ff7a3a', NOAO); mb.box(0.025, 0.1 * hs, w + 0.004, 0.06, 0.13 * hs, w + 0.014, '#ff7a3a', NOAO); mb.glow = false; },
    noEyes: true, weapon: GEAR.longsword, shield: GEAR.roundShield('#3a3644'), pose: 'sword',
  }),
  chief: (m, g) => humanoid(m, g, {
    skin: FIG.skinDark, tunic: '#7a2a22', legs: '#3d2d22', belt: FIG.gold, beard: '#1e1a18', hair: '#1e1a18', bulk: 1.15,
    back: mb => { mb.box(-0.2, -0.1, -0.03, 0.2, 0.38, 0.0, '#a8362a', NOAO); },
    torso: (mb, B) => { mb.box(-0.17 * B, 0.3, -0.11 * B, 0.17 * B, 0.38, 0.11 * B, '#6b5a48', NOAO); },
    weapon: mb => GEAR.axe(mb, 1.25), pose: 'sword',
  }),
  gaulKing: (m, g) => humanoid(m, g, {
    skin: FIG.skinPale, tunic: '#2f527a', skirt: '#a4572f', legs: '#a4572f', belt: FIG.gold, hair: '#e3c46a', bulk: 1.15,
    head: (mb, hs) => {
      const w = 0.1 * hs;
      mb.box(-w - 0.02, 0.14 * hs, -w - 0.02, w + 0.02, 0.24 * hs, w + 0.02, FIG.bronze, NOAO);
      mb.box(-w - 0.09, 0.2 * hs, -0.02, -w - 0.02, 0.36 * hs, 0.02, '#f2ead8', NOAO);
      mb.box(w + 0.02, 0.2 * hs, -0.02, w + 0.09, 0.36 * hs, 0.02, '#f2ead8', NOAO);
      mb.box(-0.1, 0.05 * hs, 0.1 * hs, 0.1, 0.09 * hs, 0.12 * hs, '#d8b45a', NOAO);
    },
    torso: (mb, B) => { mb.box(-0.1 * B, 0.33, 0.08 * B, 0.1 * B, 0.37, 0.12 * B, FIG.gold, NOAO); mb.box(-0.17 * B, 0.1, -0.1 * B, 0.17 * B, 0.33, 0.1 * B, '#8d939b', NOAO); },
    weapon: GEAR.longsword, shield: GEAR.ovalShield('#a8362a'), pose: 'sword',
  }),
  giant: (m, g) => humanoid(m, g, {
    skin: '#e3b08a', tunic: '#e3b08a', skirt: '#6b5a48', legs: '#5a4a3a', belt: '#3a2a1c', hair: '#8a5a2e', beard: '#8a5a2e', bulk: 1.25,
    torso: (mb, B) => { mb.box(-0.21 * B, 0.27, -0.13 * B, 0.21 * B, 0.4, 0.13 * B, '#7a6b5a', NOAO); },
    weapon: mb => { mb.box(-0.035, -0.035, -0.05, 0.035, 0.035, 0.35, FIG.wood, NOAO); mb.box(-0.08, -0.08, 0.35, 0.08, 0.08, 0.68, FIG.woodDark, NOAO); }, pose: 'sword',
  }),
  minotaur: (m, g) => humanoid(m, g, {
    skin: '#7a4f33', tunic: '#7a4f33', skirt: '#4a3324', legs: '#5e3c26', boots: '#2e2018', belt: FIG.bronze, bulk: 1.25, noEyes: true,
    head: (mb, hs) => {
      const w = 0.12 * hs;
      mb.box(-w, 0, -w, w, 0.22 * hs, w + 0.02, '#6a4229', NOAO);
      mb.box(-0.07, 0.0, w, 0.07, 0.1 * hs, w + 0.1, '#8a5f43', NOAO);
      mb.box(-0.05, 0.03, w + 0.1, -0.02, 0.06, w + 0.105, '#2b1d14', NOAO); mb.box(0.02, 0.03, w + 0.1, 0.05, 0.06, w + 0.105, '#2b1d14', NOAO);
      mb.box(-0.08, 0.13 * hs, w, -0.04, 0.16 * hs, w + 0.008, '#ffcf6a', NOAO); mb.box(0.04, 0.13 * hs, w, 0.08, 0.16 * hs, w + 0.008, '#ffcf6a', NOAO);
      mb.box(-w - 0.16, 0.18 * hs, -0.03, -w, 0.22 * hs, 0.03, '#efe6d2', NOAO); mb.box(-w - 0.2, 0.18 * hs, -0.03, -w - 0.15, 0.32 * hs, 0.03, '#efe6d2', NOAO);
      mb.box(w, 0.18 * hs, -0.03, w + 0.16, 0.22 * hs, 0.03, '#efe6d2', NOAO); mb.box(w + 0.15, 0.18 * hs, -0.03, w + 0.2, 0.32 * hs, 0.03, '#efe6d2', NOAO);
      mb.box(-0.05, -0.02, w + 0.06, 0.05, 0.0, w + 0.08, FIG.gold, NOAO);
    },
    weapon: mb => { GEAR.axe(mb, 1.3); mb.box(-0.012 * 1.3, -0.19 * 1.3, 0.32 * 1.3, 0.012 * 1.3, 0.0, 0.48 * 1.3, FIG.steel, NOAO); }, pose: 'sword',
  }),
  cyclops: (m, g) => humanoid(m, g, {
    skin: '#d9a07a', tunic: '#d9a07a', skirt: '#8a6a4a', legs: '#d9a07a', boots: '#b98a64', belt: '#5e3c24', bulk: 1.3, noEyes: true, headScale: 1.2,
    head: (mb, hs) => {
      const w = 0.1 * hs;
      mb.box(-0.06, 0.08 * hs, w, 0.06, 0.16 * hs, w + 0.012, '#ffffff', NOAO);
      mb.box(-0.025, 0.1 * hs, w + 0.01, 0.025, 0.145 * hs, w + 0.02, '#3a5a8a', NOAO);
      mb.box(-0.09, 0.17 * hs, w, 0.09, 0.19 * hs, w + 0.015, '#5e3c24', NOAO);
      mb.box(-w - 0.01, 0.19 * hs, -w - 0.01, w + 0.01, 0.23 * hs, w + 0.01, '#5e3c24', NOAO);
      mb.box(-0.05, 0.0, w - 0.01, 0.05, 0.03, w + 0.01, '#8a4a3a', NOAO);
    },
    weapon: mb => { mb.box(-0.04, -0.04, -0.05, 0.04, 0.04, 0.3, '#8a6a4a', NOAO); mb.box(-0.09, -0.09, 0.3, 0.09, 0.09, 0.7, '#6e5238', NOAO); }, pose: 'throw',
  }),
  wolf: (m, g) => quadruped(m, g, {
    len: 0.62, legLen: 0.26, wide: 0.11, bodyH: 0.22, legW: 0.035, color: '#7d7a76', belly: '#a8a49e', headY: 0.12,
    head: mb => { mb.box(-0.09, -0.05, -0.04, 0.09, 0.12, 0.12, '#7d7a76', NOAO); mb.box(-0.05, -0.04, 0.12, 0.05, 0.04, 0.24, '#8f8b86', NOAO); mb.box(-0.025, 0.0, 0.24, 0.025, 0.035, 0.255, '#1e1a18', NOAO);
      mb.box(-0.08, 0.12, -0.02, -0.03, 0.2, 0.03, '#6a6763', NOAO); mb.box(0.03, 0.12, -0.02, 0.08, 0.2, 0.03, '#6a6763', NOAO);
      mb.box(-0.07, 0.05, 0.12, -0.035, 0.08, 0.125, '#e8c43a', NOAO); mb.box(0.035, 0.05, 0.12, 0.07, 0.08, 0.125, '#e8c43a', NOAO); },
    tail: mb => mb.box(-0.03, -0.12, -0.25, 0.03, -0.04, 0.0, '#6a6763', NOAO),
  }),
  hellhound: (m, g) => quadruped(m, g, {
    len: 0.66, legLen: 0.28, wide: 0.12, bodyH: 0.23, legW: 0.038, color: '#2b2626', belly: '#3d3434', headY: 0.12, ridge: '#7a2a1e',
    head: mb => { mb.box(-0.09, -0.05, -0.04, 0.09, 0.12, 0.12, '#2b2626', NOAO); mb.box(-0.05, -0.04, 0.12, 0.05, 0.04, 0.24, '#3d3434', NOAO);
      mb.box(-0.08, 0.12, -0.02, -0.03, 0.2, 0.03, '#1e1a18', NOAO); mb.box(0.03, 0.12, -0.02, 0.08, 0.2, 0.03, '#1e1a18', NOAO);
      mb.glow = true; mb.box(-0.07, 0.05, 0.12, -0.035, 0.08, 0.128, '#ff4a1a', NOAO); mb.box(0.035, 0.05, 0.12, 0.07, 0.08, 0.128, '#ff4a1a', NOAO); mb.glow = false; },
    tail: mb => mb.box(-0.03, -0.12, -0.25, 0.03, -0.04, 0.0, '#1e1a18', NOAO),
  }),
  boar: (m, g) => quadruped(m, g, {
    len: 0.62, legLen: 0.18, wide: 0.15, bodyH: 0.27, legW: 0.04, color: '#5a4030', belly: '#6e5240', ridge: '#2e2018', headY: 0.06,
    head: mb => { mb.box(-0.11, -0.06, -0.04, 0.11, 0.16, 0.14, '#5a4030', NOAO); mb.box(-0.06, -0.05, 0.14, 0.06, 0.05, 0.22, '#c98e7a', NOAO);
      mb.box(-0.09, -0.04, 0.14, -0.065, 0.06, 0.18, '#f2ead8', NOAO); mb.box(0.065, -0.04, 0.14, 0.09, 0.06, 0.18, '#f2ead8', NOAO);
      mb.box(-0.08, 0.06, 0.14, -0.045, 0.09, 0.145, '#1e1a18', NOAO); mb.box(0.045, 0.06, 0.14, 0.08, 0.09, 0.145, '#1e1a18', NOAO);
      mb.box(-0.09, 0.16, 0.0, -0.04, 0.22, 0.04, '#4a3324', NOAO); mb.box(0.04, 0.16, 0.0, 0.09, 0.22, 0.04, '#4a3324', NOAO); },
    tail: mb => mb.box(-0.015, 0.0, -0.08, 0.015, 0.03, 0.0, '#2e2018', NOAO),
  }),
  bear: (m, g) => quadruped(m, g, {
    len: 0.8, legLen: 0.28, wide: 0.2, bodyH: 0.36, legW: 0.065, color: '#6b4a30', belly: '#7d5a3c', paw: '#3d2a1c', headY: 0.14,
    head: mb => { mb.box(-0.13, -0.06, -0.06, 0.13, 0.17, 0.14, '#6b4a30', NOAO); mb.box(-0.07, -0.05, 0.14, 0.07, 0.06, 0.24, '#8a6a4a', NOAO); mb.box(-0.03, 0.0, 0.24, 0.03, 0.04, 0.25, '#1e1a18', NOAO);
      mb.box(-0.13, 0.15, -0.02, -0.07, 0.22, 0.03, '#5a3c26', NOAO); mb.box(0.07, 0.15, -0.02, 0.13, 0.22, 0.03, '#5a3c26', NOAO);
      mb.box(-0.09, 0.06, 0.14, -0.05, 0.09, 0.145, '#1e1a18', NOAO); mb.box(0.05, 0.06, 0.14, 0.09, 0.09, 0.145, '#1e1a18', NOAO); },
    tail: mb => mb.box(-0.03, 0.0, -0.06, 0.03, 0.05, 0.0, '#5a3c26', NOAO),
  }),
  bull: (m, g) => quadruped(m, g, {
    len: 0.8, legLen: 0.32, wide: 0.17, bodyH: 0.34, legW: 0.05, color: '#3a2a22', belly: '#4e3a2e', paw: '#1e1a18', headY: 0.12, mane: '#2e2018',
    head: mb => { mb.box(-0.11, -0.08, -0.04, 0.11, 0.15, 0.16, '#3a2a22', NOAO); mb.box(-0.08, -0.08, 0.16, 0.08, 0.04, 0.23, '#6e5240', NOAO);
      mb.box(-0.26, 0.11, 0.0, -0.11, 0.15, 0.05, '#efe6d2', NOAO); mb.box(-0.3, 0.11, 0.0, -0.25, 0.24, 0.05, '#efe6d2', NOAO);
      mb.box(0.11, 0.11, 0.0, 0.26, 0.15, 0.05, '#efe6d2', NOAO); mb.box(0.25, 0.11, 0.0, 0.3, 0.24, 0.05, '#efe6d2', NOAO);
      mb.box(-0.09, 0.05, 0.16, -0.05, 0.08, 0.165, '#c03a2a', NOAO); mb.box(0.05, 0.05, 0.16, 0.09, 0.08, 0.165, '#c03a2a', NOAO); },
    tail: mb => mb.box(-0.015, -0.25, -0.03, 0.015, 0.0, 0.0, '#2e2018', NOAO),
  }),
  greatbear: (m, g) => MODELS.bear(m, g),
  elephant: (m, g) => quadruped(m, g, {
    len: 1.1, legLen: 0.5, wide: 0.3, bodyH: 0.55, legW: 0.1, color: '#8d8a86', belly: '#7d7a76', paw: '#6a6763', headY: 0.22, neck: -0.05,
    extra: mb => {
      // башня с лучником-наёмником на спине
      mb.box(-0.32, 0.5, -0.4, 0.32, 0.53, 0.3, '#a8362a', NOAO);
      mb.box(-0.22, 0.53, -0.25, 0.22, 0.8, 0.2, FIG.wood, NOAO);
      mb.box(-0.24, 0.8, -0.27, 0.24, 0.84, 0.22, FIG.woodDark, NOAO);
      mb.box(-0.06, 0.84, -0.06, 0.06, 1.0, 0.06, '#6a3a72', NOAO);
      mb.box(-0.05, 1.0, -0.05, 0.05, 1.1, 0.05, FIG.bronze, NOAO);
      mb.box(-0.33, 0.25, 0.1, 0.33, 0.33, 0.35, FIG.gold, NOAO);
    },
    head: mb => {
      mb.box(-0.2, -0.15, -0.08, 0.2, 0.25, 0.22, '#8d8a86', NOAO);
      mb.box(-0.33, -0.1, -0.02, -0.2, 0.25, 0.14, '#7d7a76', NOAO); mb.box(0.2, -0.1, -0.02, 0.33, 0.25, 0.14, '#7d7a76', NOAO);
      mb.box(-0.06, -0.55, 0.16, 0.06, -0.1, 0.26, '#8d8a86', NOAO); mb.box(-0.05, -0.7, 0.2, 0.05, -0.55, 0.3, '#8d8a86', NOAO);
      mb.box(-0.15, -0.3, 0.18, -0.11, -0.12, 0.38, '#f2ead8', NOAO); mb.box(0.11, -0.3, 0.18, 0.15, -0.12, 0.38, '#f2ead8', NOAO);
      mb.box(-0.14, 0.1, 0.22, -0.09, 0.14, 0.225, '#1e1a18', NOAO); mb.box(0.09, 0.1, 0.22, 0.14, 0.14, 0.225, '#1e1a18', NOAO);
    },
    tail: mb => mb.box(-0.02, -0.35, -0.03, 0.02, 0.0, 0.0, '#6a6763', NOAO),
  }),
  cerberus: (m, g) => quadruped(m, g, {
    len: 0.85, legLen: 0.36, wide: 0.19, bodyH: 0.34, legW: 0.06, color: '#2b2626', belly: '#3d3434', headY: 0.2, ridge: '#a83a1e', heads: [-0.17, 0, 0.17], neck: 0.02,
    head: (mb, i) => { const s = i === 1 ? 1.1 : 0.9; mb.box(-0.09 * s, -0.05 * s, -0.04, 0.09 * s, 0.13 * s, 0.13 * s, '#2b2626', NOAO); mb.box(-0.05 * s, -0.04 * s, 0.13 * s, 0.05 * s, 0.04 * s, 0.26 * s, '#3d3434', NOAO);
      mb.box(-0.08 * s, 0.13 * s, -0.02, -0.03 * s, 0.22 * s, 0.03, '#1e1a18', NOAO); mb.box(0.03 * s, 0.13 * s, -0.02, 0.08 * s, 0.22 * s, 0.03, '#1e1a18', NOAO);
      mb.glow = true; mb.box(-0.07 * s, 0.05 * s, 0.13 * s, -0.035 * s, 0.08 * s, 0.14 * s, '#ff4a1a', NOAO); mb.box(0.035 * s, 0.05 * s, 0.13 * s, 0.07 * s, 0.08 * s, 0.14 * s, '#ff4a1a', NOAO); mb.glow = false; },
    tail: mb => { mb.box(-0.03, -0.05, -0.32, 0.03, 0.02, 0.0, '#1e1a18', NOAO); mb.glow = true; mb.box(-0.035, -0.06, -0.36, 0.035, 0.03, -0.31, '#ff6a2a', NOAO); mb.glow = false; },
  }),
};

// Баллиста и катапульта: деревянная машина с расчётом из одного легионера
function siege(mat, glow, kind) {
  const root = new THREE.Group(), fig = { root, kind: 'siege', mat, machine: kind };
  figPart(root, mb => {
    mb.box(-0.3, 0.12, -0.45, -0.22, 0.2, 0.45, FIG.wood, NOAO);
    mb.box(0.22, 0.12, -0.45, 0.3, 0.2, 0.45, FIG.wood, NOAO);
    mb.box(-0.3, 0.14, -0.05, 0.3, 0.2, 0.05, FIG.woodDark, NOAO);
    for (const [x, z] of [[-0.33, -0.3], [0.33, -0.3], [-0.33, 0.3], [0.33, 0.3]]) {
      mb.cyl(x, 0.14, z, 0.14, 0.04, FIG.woodDark, { segs: 10, ao: 1 });
    }
    if (kind === 'ballista') {
      mb.box(-0.05, 0.2, -0.05, 0.05, 0.42, 0.05, FIG.wood, NOAO);
      mb.box(-0.07, 0.42, -0.4, 0.07, 0.48, 0.45, FIG.wood, NOAO);
      mb.box(-0.1, 0.4, 0.3, 0.1, 0.52, 0.38, FIG.bronze, NOAO);
    } else {
      mb.box(-0.3, 0.2, -0.05, -0.22, 0.62, 0.05, FIG.wood, NOAO);
      mb.box(0.22, 0.2, -0.05, 0.3, 0.62, 0.05, FIG.wood, NOAO);
      mb.box(-0.3, 0.58, -0.07, 0.3, 0.66, 0.07, FIG.woodDark, NOAO);
      mb.box(-0.2, 0.18, -0.28, 0.2, 0.26, -0.18, FIG.rope, NOAO);
    }
  }, mat, glow);
  if (kind === 'ballista') {
    // плечи лука и болт
    fig.arm = figPart(root, mb => {
      mb.box(-0.42, -0.02, 0.24, -0.06, 0.03, 0.3, FIG.woodDark, NOAO);
      mb.box(0.06, -0.02, 0.24, 0.42, 0.03, 0.3, FIG.woodDark, NOAO);
      mb.box(-0.42, 0.0, -0.1, -0.4, 0.01, 0.26, FIG.cloth, NOAO);
      mb.box(0.4, 0.0, -0.1, 0.42, 0.01, 0.26, FIG.cloth, NOAO);
    }, mat, glow, 0, 0.5, 0);
    fig.bolt = figPart(root, mb => { mb.box(-0.018, -0.018, -0.3, 0.018, 0.018, 0.42, FIG.wood, NOAO); mb.box(-0.03, -0.025, 0.42, 0.03, 0.025, 0.52, FIG.steel, NOAO); }, mat, glow, 0, 0.52, 0);
  } else {
    // рычаг с ложкой: вращается вокруг оси на перекладине
    fig.arm = figPart(root, mb => {
      mb.box(-0.04, -0.04, -0.62, 0.04, 0.04, 0.05, FIG.wood, NOAO);
      mb.box(-0.1, -0.08, -0.7, 0.1, 0.04, -0.56, FIG.woodDark, NOAO);
      mb.blob(0, 0.04, -0.63, 0.08, 0.07, 0.08, '#9a958c', { jitter: 0.2 });
    }, mat, glow, 0, 0.36, 0.0);
    fig.arm.rotation.x = 0.35;
  }
  const crew = humanoid(mat, glow, { skin: FIG.skin, tunic: FIG.red, legs: FIG.skin, belt: FIG.leather, head: (mb, hs) => galea(mb, hs, null) });
  crew.root.position.set(0.45, 0, -0.35);
  crew.root.scale.setScalar(0.85);
  root.add(crew.root);
  fig.crew = crew;
  return fig;
}

function buildFigure(key) {
  const mat = new THREE.MeshLambertMaterial({ vertexColors: true, transparent: false });
  const glow = new THREE.MeshBasicMaterial({ vertexColors: true });
  if (key === 'ballista' || key === 'catapult') return siege(mat, glow, key);
  const fig = MODELS[key](mat, glow);
  if (key === 'greatbear') fig.big = true;
  return fig;
}

/* ---------- Поле боя по провинциям ---------- */
const BIOMES = {
  forest: { ground: '#9cc066', path: '#c8ae78', sky: ['#8fc6e6', '#eaf2e6'], fog: '#dce8d8', light: 1 },
  hills: { ground: '#b5c26a', path: '#d3ba88', sky: ['#9ccfee', '#f3eed8'], fog: '#ece6cf', light: 1.05 },
  darkforest: { ground: '#6c9650', path: '#998760', sky: ['#78aac2', '#cddfd0'], fog: '#bfd2c2', light: 0.9 },
  swamp: { ground: '#7c8f58', path: '#86795a', sky: ['#97b2b4', '#d5dccf'], fog: '#c4cfc2', light: 0.85 },
  labyrinth: { ground: '#cdbfa2', path: '#bcae90', sky: ['#a2c9e4', '#efe5d0'], fog: '#e4d9c6', light: 1 },
  rocks: { ground: '#c2ba92', path: '#d6c79e', sky: ['#86c3ea', '#e8f1ee'], fog: '#d8e6e8', light: 1.05 },
  desert: { ground: '#dfc68b', path: '#d2b476', sky: ['#9fcfee', '#f6e8cc'], fog: '#f0e0c0', light: 1.1 },
  hades: { ground: '#7a5646', path: '#644636', sky: ['#4a2628', '#c8704a'], fog: '#8a4a38', light: 1.0 },
};

function skyTexture(top, bottom) {
  const c = document.createElement('canvas');
  c.width = 4; c.height = 256;
  const g = c.getContext('2d'), gr = g.createLinearGradient(0, 0, 0, 256);
  gr.addColorStop(0, top); gr.addColorStop(0.7, bottom); gr.addColorStop(1, bottom);
  g.fillStyle = gr; g.fillRect(0, 0, 4, 256);
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  return t;
}

// Земля: пятнистая трава, утоптанная полоса поля боя, холмы на заднем плане
function arenaGround(B, rnd) {
  const geo = new THREE.PlaneGeometry(90, 50, 90, 50).rotateX(-Math.PI / 2);
  const pos = geo.attributes.position, col = new Float32Array(pos.count * 3);
  const g = new THREE.Color(B.ground), p = new THREE.Color(B.path), c = new THREE.Color();
  for (let i = 0; i < pos.count; i++) {
    const x = pos.getX(i), z = pos.getZ(i);
    const n = Math.sin(x * 0.7 + z * 0.4) * 0.5 + Math.sin(x * 0.23 - z * 0.9) * 0.5;
    const band = clamp(1 - (Math.abs(z) - 2.4 + n * 0.5) / 1.6, 0, 1);
    c.copy(g).multiplyScalar(0.93 + n * 0.06 + rnd() * 0.04).lerp(p, band * 0.8);
    col[i * 3] = c.r; col[i * 3 + 1] = c.g; col[i * 3 + 2] = c.b;
    if (z < -9) pos.setY(i, Math.pow((-9 - z) / 16, 1.6) * 6 * (0.6 + 0.4 * Math.sin(x * 0.15 + 1.3)));
  }
  geo.setAttribute('color', new THREE.BufferAttribute(col, 3));
  geo.computeVertexNormals();
  const m = new THREE.Mesh(geo, patchMaterial(new THREE.MeshLambertMaterial({ vertexColors: true }), { grain: true }));
  m.receiveShadow = true;
  return m;
}

// Деревья, скалы и постройки вокруг поля — по провинции
function arenaProps(biome, rnd) {
  const mb = new MB(5);
  const glows = [];
  const around = (n, fn, zMin, zMax) => {
    for (let i = 0; i < n; i++) fn(-20 + rnd() * 42, zMin + rnd() * (zMax - zMin), i);
  };
  const back = (n, fn) => around(n, fn, -16, -4.2);
  const front = (n, fn) => around(n, fn, 4.2, 6.5);
  const palm = (x, z, s) => {
    for (let i = 0; i < 6; i++) mb.cyl(x + i * 0.04 * s, i * 0.5 * s, z, (0.12 - i * 0.01) * s, 0.52 * s, '#8a6a46', { segs: 6, rTop: (0.11 - i * 0.01) * s });
    for (let i = 0; i < 7; i++) { const a = i / 7 * Math.PI * 2; mb.blob(x + 0.25 * s + Math.cos(a) * 0.55 * s, 2.9 * s, z + Math.sin(a) * 0.55 * s, 0.55 * s, 0.08 * s, 0.2 * s, i % 2 ? '#5f8f3a' : '#4f7d32', { jitter: 0.1 }); }
  };
  const deadTree = (x, z, s) => {
    mb.cyl(x, 0, z, 0.12 * s, 1.6 * s, '#4a3a2e', { segs: 6, rTop: 0.06 * s });
    mb.box(x, 1.0 * s, z - 0.03 * s, x + 0.6 * s, 1.08 * s, z + 0.03 * s, '#4a3a2e');
    mb.box(x - 0.45 * s, 1.3 * s, z - 0.03 * s, x, 1.37 * s, z + 0.03 * s, '#4a3a2e');
  };
  const wall = (x, z, w, h) => {
    mb.box(x - w / 2, 0, z - 0.4, x + w / 2, h, z + 0.4, '#d8ccb0');
    mb.box(x - w / 2 - 0.1, h, z - 0.5, x + w / 2 + 0.1, h + 0.2, z + 0.5, '#c7b998');
    for (let i = 0; i < w / 0.9; i++) mb.box(x - w / 2 + i * 0.9, 0.6, z + 0.4, x - w / 2 + i * 0.9 + 0.04, h - 0.2, z + 0.42, '#bfb090');
  };
  const torch = (x, z) => { mb.box(x - 0.05, 0, z - 0.05, x + 0.05, 1.6, z + 0.05, '#5e3c24'); glows.push([x, 1.7, z, '#ffb03a']); };
  const T = s => 3.2 + s;
  switch (biome) {
    case 'forest':
      back(26, (x, z, i) => i % 3 ? treeOak(mb, x, z, T(rnd()), 1) : treePine(mb, x, z, T(rnd() * 1.4), 1));
      front(6, (x, z) => bush(mb, x, z, 2.2, PAL.leaf));
      around(8, (x, z) => rocks(mb, x, z, 1.2, '#b7b09e', 2, rnd()), -8, 6);
      break;
    case 'hills':
      back(10, (x, z) => treeOlive(mb, x, z, T(rnd()), 1));
      back(14, (x, z) => rocks(mb, x, z, 2.2 + rnd() * 1.5, '#c9bd9c', 3, rnd()));
      front(5, (x, z) => rocks(mb, x, z, 1.4, '#c9bd9c', 2, rnd()));
      break;
    case 'darkforest':
      back(40, (x, z) => treePine(mb, x, z, T(rnd() * 1.6), 1));
      front(8, (x, z) => bush(mb, x, z, 2.4, PAL.leafDark));
      mb.box(-3, 0, -6.2, -2.4, 2.6, -5.6, '#a8a294'); mb.box(5, 0, -7.5, 5.6, 3.1, -6.9, '#a8a294');
      break;
    case 'swamp':
      back(14, (x, z) => deadTree(x, z, 1.6 + rnd()));
      back(10, (x, z) => treePine(mb, x, z, T(rnd()), 1));
      around(30, (x, z) => { if (Math.abs(z) < 3.2) return; for (let k = 0; k < 4; k++) mb.box(x + k * 0.08, 0, z, x + k * 0.08 + 0.04, 0.8 + rnd() * 0.6, z + 0.04, '#6f8a3e'); }, -9, 6);
      break;
    case 'labyrinth':
      for (let i = 0; i < 6; i++) wall(-18 + i * 7.5, -7 - (i % 2) * 3.5, 5 + rnd() * 2, 2.6);
      for (let i = 0; i < 6; i++) column(mb, -14 + i * 5.6, -4.6, 0, 3.2, 0.28, PAL.marble);
      for (let i = 0; i < 5; i++) torch(-12 + i * 6, -4.2);
      break;
    case 'rocks':
      back(16, (x, z) => rocks(mb, x, z, 3 + rnd() * 3, '#b9b4a6', 3, rnd()));
      front(5, (x, z) => rocks(mb, x, z, 1.5, '#b9b4a6', 2, rnd()));
      back(5, (x, z) => treeCypress(mb, x, z, T(rnd()), 1));
      break;
    case 'desert':
      back(10, (x, z) => palm(x, z, 1 + rnd() * 0.4));
      back(8, (x, z) => mb.blob(x, 0, z, 2.5 + rnd() * 2, 0.9, 1.6, '#e6cc8e', { jitter: 0.05 }));
      for (let i = 0; i < 4; i++) column(mb, -10 + i * 7, -5.5, 0, 1.2 + rnd() * 2, 0.26, '#efe2c4');
      break;
    case 'hades':
      back(18, (x, z) => rocks(mb, x, z, 2.5 + rnd() * 3, '#3a2c28', 3, rnd()));
      back(8, (x, z) => deadTree(x, z, 1.4 + rnd()));
      for (let i = 0; i < 8; i++) glows.push([-16 + i * 4.5 + rnd() * 2, 0.04, -3.6 - rnd() * 6, '#ff5a1a', true]);
      break;
  }
  const geo = mb.build(0, 0);
  const g = new THREE.Group();
  if (geo.solid) {
    const m = new THREE.Mesh(geo.solid, patchMaterial(new THREE.MeshLambertMaterial({ vertexColors: true })));
    m.castShadow = true; m.receiveShadow = true;
    g.add(m);
  }
  // огни факелов и трещины с лавой
  for (const [x, y, z, c, crack] of glows) {
    const mesh = new THREE.Mesh(crack ? new THREE.BoxGeometry(2.2, 0.04, 0.12) : new THREE.IcosahedronGeometry(0.16, 1), new THREE.MeshBasicMaterial({ color: new THREE.Color(c).multiplyScalar(2.2) }));
    mesh.position.set(x, y, z);
    if (crack) mesh.rotation.y = rnd() * 3;
    g.add(mesh);
  }
  if (biome === 'swamp' || biome === 'rocks') {
    // лужи болота или море за скалами
    const sea = biome === 'rocks';
    const water = new THREE.Mesh(sea ? new THREE.PlaneGeometry(140, 40).rotateX(-Math.PI / 2) : new THREE.CircleGeometry(1, 24).rotateX(-Math.PI / 2).scale(2.2, 1, 1.1),
      new THREE.MeshPhongMaterial({ color: sea ? '#4c9ec4' : '#7a9a8e', shininess: 90, specular: '#cfe0d8', transparent: true, opacity: sea ? 0.88 : 0.75 }));
    if (sea) { water.position.set(0, 2.2, -40); g.add(water); }
    else for (let i = 0; i < 5; i++) { const w = water.clone(); w.position.set(-14 + i * 7 + rnd() * 2, 0.02, rnd() < 0.5 ? -3.8 : 4.8); g.add(w); }
  }
  return g;
}

/* ---------- Частицы боя: пыль, искры, огонь, брызги масла ---------- */
class BattleParticles {
  constructor(scene) {
    this.max = 700;
    this.mesh = new THREE.InstancedMesh(new THREE.IcosahedronGeometry(0.5, 1), new THREE.MeshBasicMaterial({ transparent: true, opacity: 0.9, depthWrite: false }), this.max);
    this.mesh.instanceColor = new THREE.InstancedBufferAttribute(new Float32Array(this.max * 3), 3);
    this.mesh.frustumCulled = false;
    this.mesh.count = 0;
    scene.add(this.mesh);
    this.list = [];
    this._m = new THREE.Matrix4();
    this._c = new THREE.Color();
  }

  add(p) { if (this.list.length < this.max) this.list.push(Object.assign({ t: 0, g: -2, grow: 0.5 }, p)); }

  burst(x, y, z, color, n, spread, up, size, life) {
    for (let i = 0; i < n; i++) {
      const a = Math.random() * Math.PI * 2, s = Math.random() * spread;
      this.add({ x, y, z, vx: Math.cos(a) * s, vy: up * (0.5 + Math.random()), vz: Math.sin(a) * s * 0.6, s: size * (0.6 + Math.random() * 0.6), life: life * (0.7 + Math.random() * 0.6), color });
    }
  }

  update(dt) {
    let n = 0;
    for (const p of this.list) {
      p.t += dt;
      p.x += p.vx * dt; p.y += p.vy * dt; p.z += p.vz * dt; p.vy += p.g * dt;
      if (p.y < 0.02) { p.y = 0.02; p.vy *= -0.2; p.vx *= 0.7; p.vz *= 0.7; }
      const k = p.t / p.life;
      if (k >= 1) continue;
      const s = p.s * Math.max(0.05, 1 + p.grow * k) * (k > 0.7 ? (1 - k) / 0.3 : 1);
      this._m.makeScale(s, s, s).setPosition(p.x, p.y, p.z);
      this.mesh.setMatrixAt(n, this._m);
      this.mesh.setColorAt(n, this._c.set(p.color));
      n++;
    }
    this.list = this.list.filter(p => p.t < p.life);
    this.mesh.count = n;
    this.mesh.instanceMatrix.needsUpdate = true;
    if (n) this.mesh.instanceColor.needsUpdate = true;
  }
}

/* ---------- Бой: сцена, отрисовка, экран ---------- */
const FACE = Math.PI / 2 - 0.4;   // бойцы стоят вполоборота к зрителю
const SHOT_GEO = {};

function shotGeometries() {
  if (SHOT_GEO.arrow) return;
  const make = fn => { const mb = new MB(1); fn(mb); return mb.build(0, 0).solid; };
  SHOT_GEO.arrow = make(mb => { mb.box(-0.012, -0.012, -0.3, 0.012, 0.012, 0.25, FIG.wood, NOAO); mb.box(-0.025, -0.02, 0.25, 0.025, 0.02, 0.32, FIG.steel, NOAO); mb.box(-0.004, -0.04, -0.32, 0.004, 0.04, -0.2, '#f2ede2', NOAO); });
  SHOT_GEO.bolt = make(mb => { mb.box(-0.025, -0.025, -0.5, 0.025, 0.025, 0.4, FIG.wood, NOAO); mb.box(-0.045, -0.04, 0.4, 0.045, 0.04, 0.55, FIG.steel, NOAO); mb.box(-0.006, -0.07, -0.52, 0.006, 0.07, -0.34, '#f2ede2', NOAO); });
  SHOT_GEO.stone = make(mb => mb.blob(0, 0, 0, 0.2, 0.18, 0.2, '#9a958c', { jitter: 0.25 }));
  SHOT_GEO.boulder = make(mb => mb.blob(0, 0, 0, 0.36, 0.32, 0.36, '#8a8478', { jitter: 0.3 }));
  SHOT_GEO.sling = make(mb => mb.blob(0, 0, 0, 0.06, 0.06, 0.06, '#7d786e', { jitter: 0.2 }));
}

const Battle = {
  active: false,
  speed: 1,
  lastSpeed: 1,

  start(stage) {
    const err = Army.canFight();
    if (err) { UI.toast(err, 'warn'); return false; }
    Army.payFood(Army.foodCost());
    this.stage = stage;
    this.sim = new BattleSim(Army.squadStats(), stage, state.army.perks, (Date.now() & 0xffffff) + 1);
    this.views = new Map();
    this.shotViews = new Map();
    this.effects = [];
    this.ended = false;
    this.resultShown = false;
    this.endT = 0;
    this.acc = 0;
    this.T = 0;
    this.camX = 0;
    this.speed = this.lastSpeed;
    UI.closeModal();
    UI.closeWindow();
    UI.closePanel();
    UI.closeTray();
    Input.setTool(null);
    this.buildScene(stage);
    this.buildHud();
    Sound.battleStart();
    document.body.classList.add('battle-mode');
    this.active = true;
    return true;
  },

  buildScene(stage) {
    shotGeometries();
    const B = BIOMES[stage.R.biome];
    const rnd = mulberry32(stage.D * 31 + 7);
    const s = this.scene = new THREE.Scene();
    s.background = skyTexture(B.sky[0], B.sky[1]);
    s.fog = new THREE.Fog(B.fog, 24, 75);
    s.add(new THREE.HemisphereLight(B.sky[0], B.ground, 1.15 * B.light));
    const sun = new THREE.DirectionalLight(stage.R.biome === 'hades' ? '#ffb48a' : '#fff1d8', 2.7 * B.light);
    sun.position.set(-8, 16, 10);
    sun.castShadow = true;
    sun.shadow.mapSize.set(2048, 2048);
    const sc = sun.shadow.camera;
    sc.left = -18; sc.right = 18; sc.top = 12; sc.bottom = -12; sc.near = 1; sc.far = 60;
    sun.shadow.bias = -0.0005;
    s.add(sun);
    const fill = new THREE.DirectionalLight('#c8d4ff', 0.45 * B.light);
    fill.position.set(10, 6, -8);
    s.add(fill);
    s.add(arenaGround(B, rnd));
    s.add(arenaProps(stage.R.biome, rnd));
    this.parts = new BattleParticles(s);
    this.camera = new THREE.PerspectiveCamera(30, 1, 0.5, 220);
    this._w = 0;
    this.ringGeo = new THREE.RingGeometry(0.42, 0.55, 28).rotateX(-Math.PI / 2);
    this.shotMat = new THREE.MeshLambertMaterial({ vertexColors: true });
  },

  fitCamera() {
    const aspect = Engine.W / Engine.H, cam = this.camera;
    cam.aspect = aspect;
    // на узком экране отъезжаем, чтобы влезло всё поле
    const k = Math.max(1, 1.75 / aspect);
    this.camK = k;
    this.camX = this.camX === undefined ? 0 : this.camX;
    cam.position.set(this.camX, 4.4 * k, 19.5 * k);
    cam.lookAt(this.camX, 1.0, 0);
    cam.updateProjectionMatrix();
    this.focus = Math.hypot(cam.position.y - 1.0, cam.position.z);
  },

  view(u) {
    let v = this.views.get(u.id);
    if (v) return v;
    // настоящие бойцы со скелетом (js/battle3d.js), пока он не загрузился — прежние фигурки
    const fig = (window.Battle3D && Battle3D.makeUnit(u.key)) || buildFigure(u.key);
    const root = fig.root;
    root.rotation.order = 'YXZ';
    const sc = (u.size || 1) * (fig.real ? 1 : fig.kind === 'beast' ? 1.7 : 1.5);
    root.scale.setScalar(sc);
    this.scene.add(root);
    const hp = document.createElement('div');
    hp.className = `bhp ${u.side}`;
    hp.innerHTML = '<i></i>';
    $('battle-labels').appendChild(hp);
    v = { u, fig, root, sc, hp, phase: Math.random() * 6, dead: 0, testudo: null, horn: null };
    this.views.set(u.id, v);
    return v;
  },

  buildHud() {
    const st = this.stage;
    const el = document.createElement('div');
    el.id = 'battle-ui';
    el.innerHTML = `
      <div id="battle-labels"></div>
      <div class="b-top">
        <div class="b-title panel"><small>${st.title}</small><b>${st.boss ? st.name : `Бой ${st.s + 1} из ${STAGES_PER_REGION}`}</b><span id="b-wave"></span></div>
        <div class="b-ctrl panel">
          <div class="seg"><button type="button" data-bspeed="1">×1</button><button type="button" data-bspeed="2">×2</button><button type="button" data-bspeed="3">×3</button></div>
          <button type="button" class="btn small ghost" id="b-retreat">Отступить</button>
        </div>
      </div>
      <div id="b-boss" class="b-boss panel" hidden><b></b><div class="bar"><div></div></div></div>
      <div id="b-banner" class="b-banner"></div>
      <div class="b-perks" id="b-perks"></div>`;
    document.body.appendChild(el);
    el.querySelectorAll('[data-bspeed]').forEach(b => b.onclick = () => this.setSpeed(+b.dataset.bspeed));
    $('b-retreat').onclick = () => this.retreat();
    const perks = Object.entries(this.sim.perks);
    $('b-perks').innerHTML = perks.length ? perks.map(([id, p]) => `
      <button type="button" class="b-perk" data-perk="${id}" title="${PERKS[id].desc}">
        <span class="ring">${ArmyUI.perkIcon(id)}<i class="cd"></i></span><small>${PERKS[id].name}</small><em>${'★'.repeat(p.lvl)}</em>
      </button>`).join('') : '<p class="b-noperks panel">Умения открываются победами над боссами (окно «Легион» → «Войска»)</p>';
    el.querySelectorAll('[data-perk]').forEach(b => b.onclick = () => this.sim.usePerk(b.dataset.perk));
    this.setSpeed(this.speed);
    this.banner(st.boss ? `Босс: ${st.name}` : st.title, 2.2);
  },

  setSpeed(s) {
    this.speed = this.lastSpeed = s;
    document.querySelectorAll('[data-bspeed]').forEach(b => b.classList.toggle('on', +b.dataset.bspeed === s));
  },

  banner(text, dur) {
    const b = $('b-banner');
    if (!b) return;
    b.textContent = text;
    b.classList.remove('show');
    void b.offsetWidth;
    b.classList.add('show');
    clearTimeout(this._bt);
    this._bt = setTimeout(() => b.classList.remove('show'), (dur || 1.6) * 1000);
  },

  retreat() {
    if (this.ended) return;
    UI.showModal(`<h2>Отступить?</h2><p>Бой будет проигран, провизия не вернётся.</p>
      <div class="actions"><button type="button" class="btn danger" id="ret-yes">Отступить</button><button type="button" class="btn ghost" id="ret-no">Продолжить бой</button></div>`);
    $('ret-no').onclick = () => UI.closeModal();
    $('ret-yes').onclick = () => {
      UI.closeModal();
      this.sim.result = { win: false, alive: this.sim.units.filter(u => u.alive && u.side === 'ally').length, total: this.sim.total, retreat: true };
      this.ended = true;
      this.endT = 0.2;
    };
  },

  /* ---------- Кадр ---------- */

  frame(realDt) {
    const dt = Math.min(realDt, 0.1);
    this.T += dt;
    if (Engine.W !== this._w || Engine.H !== this._h) { this._w = Engine.W; this._h = Engine.H; this.fitCamera(); }
    const paused = UI.modalOpen && !this.resultShown;
    const gdt = paused ? 0 : dt * this.speed;
    if (!paused) {
      this.acc += gdt;
      let n = 0;
      while (this.acc >= 1 / 30 && n++ < 12) { this.sim.step(1 / 30); this.acc -= 1 / 30; }
    }
    this.handleEvents();
    // камера мягко следует за серединой схватки
    const alive = this.sim.units.filter(u => u.alive && !u.entering && u.speed > 0);
    const mid = alive.length ? alive.reduce((a, u) => a + u.x, 0) / alive.length : 0;
    const want = clamp(mid, -1.2, 2.2);
    this.camX += (want - this.camX) * Math.min(1, dt * 1.2);
    this.camera.position.x = this.camX;
    this.camera.lookAt(this.camX, 1.0, 0);
    for (const u of this.sim.units) this.animate(this.view(u), gdt);
    this.updateShots();
    this.updateEffects(gdt);
    this.parts.update(gdt);
    this.updateHud();
    if (this.sim.result && !this.ended) { this.ended = true; this.endT = 1.4; }
    if (this.ended && !this.resultShown) {
      this.endT -= dt;
      if (this.endT <= 0) this.showResult();
    }
    Engine.renderer.toneMappingExposure = 1.05;
    if (this.camHook) this.camHook(this.camera);   // съёмка ролика ведёт камеру сама
    Post.render(this.scene, this.camera, { focus: this.focus, dof: 0.25, bloom: this.stage.R.biome === 'hades' ? 0.8 : 0.5 });
  },

  handleEvents() {
    for (const e of this.sim.events.splice(0)) {
      if (e.type === 'hit') {
        this.floatText(e.unit, `${e.dmg}${e.crit ? '!' : ''}`, e.unit.side === 'ally' ? 'hurt' : e.crit ? 'crit' : 'dmg');
        // мечи звенят, когда бьются люди; звери и великаны бьют глухо
        const beast = t => t && t.tags && (t.tags.includes('beast') || t.tags.includes('giant'));
        if (e.from && e.from.shot) Sound.thud(0.5);
        else if (beast(e.from) || beast(e.unit)) Sound.thud(0.8);
        else Sound.clash(e.crit ? 1 : 0.75);
      }
      else if (e.type === 'heal') this.floatText(e.unit, `+${e.amount}`, 'heal');
      else if (e.type === 'death') { this.parts.burst(e.unit.x, 0.3, e.unit.z, '#d8c8a8', 10, 1.2, 1.2, 0.18, 0.7); if (e.unit.tags && e.unit.tags.includes('beast')) Sound.thud(1); else Sound.grunt(); }
      else if (e.type === 'wave') { if (e.n > 1) { this.banner(`Волна ${e.n} из ${e.total}`, 1.6); Sound.shout(); } }
      else if (e.type === 'boom') { Sound.boom(); this.parts.burst(e.x, 0.2, e.z, '#cbb994', 22, e.r * 2.2, 2.5, 0.26, 0.9); this.ringFx(e.x, e.z, e.r, '#f4e3c0'); }
      else if (e.type === 'slam') { Sound.thud(1); this.parts.burst(e.x, 0.15, e.z, '#cbb994', 14, e.r * 2, 1.5, 0.22, 0.7); this.ringFx(e.x, e.z, e.r, '#f4e3c0'); }
      else if (e.type === 'shoot') { this.shotViews.set(e.shot, null); Sound.whoosh(e.shot.kind); }
      else if (e.type === 'perk') { this.perkFx(e); if (e.id === 'horn') Sound.horn(); else if (e.id === 'testudo') Sound.shout(); else if (e.id === 'oil') Sound.demolish(); }
    }
  },

  floatText(u, text, cls) {
    const p = this.screen(u.x + (Math.random() - 0.5) * 0.4, (u.size || 1) * 1.95 + 0.2, u.z);
    if (!p) return;
    const el = document.createElement('div');
    el.className = `bnum ${cls}`;
    el.textContent = text;
    el.style.left = p[0] + 'px';
    el.style.top = p[1] + 'px';
    $('battle-labels').appendChild(el);
    setTimeout(() => el.remove(), 950);
  },

  screen(x, y, z) {
    const v = new THREE.Vector3(x, y, z).project(this.camera);
    if (v.z > 1) return null;
    return [(v.x + 1) / 2 * Engine.W, (1 - v.y) / 2 * Engine.H];
  },

  // Поза и движение фигурки по состоянию бойца
  animate(v, dt) {
    const u = v.u, f = v.fig, r = v.root;
    if (f.real) {
      Battle3D.animate(v, dt, this.sim);
      if (!u.alive) {
        v.hp.style.display = 'none';
        this.ring(v, 'testudo', false);
        this.ring(v, 'horn', false);
        return;
      }
      this.status(v, dt, f.h + 0.15);
      return;
    }
    if (!u.alive) {
      v.dead += dt;
      const k = Math.min(1, v.dead / 0.45);
      r.rotation.x = -k * Math.PI / 2 * (f.kind === 'siege' ? 0.15 : 1);
      if (v.dead > 1.1) {
        r.position.y -= dt * 0.4;
        f.mat.transparent = true;
        f.mat.opacity = Math.max(0, 1 - (v.dead - 1.1) / 1.2);
        if (f.mat.opacity <= 0) r.visible = false;
      }
      v.hp.style.display = 'none';
      this.ring(v, 'testudo', false);
      this.ring(v, 'horn', false);
      return;
    }
    r.position.set(u.x, 0, u.z);
    r.rotation.y = u.side === 'ally' ? FACE : -FACE;
    const t = this.sim.t;
    const atk = u.attackT > 0 ? 1 - u.attackT / 0.35 : -1;
    // вспышка при ударе
    const hit = Math.max(0, u.hitT - 0.13) * 8;
    f.mat.emissive.setRGB(hit * 0.32, hit * 0.07, hit * 0.03);
    const h = f.kind === 'human' ? f : f.crew;
    if (h) {
      if (u.moving) v.phase += dt * (u.speed || 1.5) * 5.5;
      const sw = u.moving ? Math.sin(v.phase) * 0.6 : 0;
      h.legL.rotation.x = sw;
      h.legR.rotation.x = -sw;
      h.body.position.y = 0.42 + (u.moving ? Math.abs(Math.cos(v.phase)) * 0.03 : Math.sin(this.T * 2 + v.phase) * 0.006);
      h.armL.rotation.x = -sw * 0.6;
      h.armR.rotation.x = sw * 0.6;
      if (f.kind === 'human') {
        this.armPose(h, u, atk);
        h.body.rotation.x = atk >= 0 && h.pose !== 'bow' ? Math.sin(atk * Math.PI) * 0.25 : 0;
      }
    }
    if (f.kind === 'beast') {
      if (u.moving) v.phase += dt * (u.speed || 2) * 4.5;
      const sw = u.moving ? Math.sin(v.phase) * 0.55 : 0;
      f.legs[0].rotation.x = sw; f.legs[3].rotation.x = sw; f.legs[1].rotation.x = -sw; f.legs[2].rotation.x = -sw;
      for (const hd of f.heads) hd.rotation.x = atk >= 0 ? -Math.sin(atk * Math.PI) * 0.5 : Math.sin(this.T * 1.5 + v.phase) * 0.05;
      f.body.rotation.x = atk >= 0 ? Math.sin(atk * Math.PI) * 0.12 : 0;
      if (f.tail) f.tail.rotation.y = Math.sin(this.T * 6 + v.phase) * 0.3;
    }
    if (f.kind === 'siege') {
      if (f.machine === 'catapult') f.arm.rotation.x = atk >= 0 ? 0.35 - Math.sin(Math.min(1, atk * 2) * Math.PI / 2) * 1.9 : Math.min(0.35, f.arm.rotation.x + dt * 0.8);
      else { f.bolt.visible = !(atk >= 0 && atk < 0.8); f.arm.scale.x = atk >= 0 ? 0.85 + atk * 0.15 : 1; }
    }
    this.status(v, dt, (f.kind === 'beast' ? 1.4 : 1.8) + 0.1 / (u.size || 1));
  },

  // Общее для любых фигур: круги умений, огонь, полоска здоровья
  status(v, dt, top) {
    const u = v.u, t = this.sim.t;
    this.ring(v, 'testudo', u.testudo > t);
    this.ring(v, 'horn', u.horn > t);
    if (u.burn > t && dt > 0 && Math.random() < 0.35) this.parts.add({ x: u.x + (Math.random() - 0.5) * 0.4, y: 0.4 + Math.random() * 0.6, z: u.z, vx: 0, vy: 1.2, vz: 0, g: 0.5, s: 0.12, life: 0.5, color: Math.random() < 0.5 ? '#ff9a2a' : '#ffd25a', grow: -0.6 });
    // полоска здоровья над головой
    const p = u.boss ? null : this.screen(u.x, (u.size || 1) * top, u.z);
    if (p) {
      v.hp.style.display = '';
      v.hp.style.transform = `translate(${p[0]}px, ${p[1]}px)`;
      v.hp.firstChild.style.width = `${Math.max(0, u.hp / u.maxHp) * 100}%`;
    } else v.hp.style.display = 'none';
  },

  armPose(h, u, atk) {
    const pose = h.pose;
    if (pose === 'sword') {
      h.armR.rotation.x = atk >= 0 ? -2.5 + atk * 2.9 : -0.55;
      h.armL.rotation.x = -0.35;
    } else if (pose === 'spear') {
      h.armR.rotation.x = -1.25 - (atk >= 0 ? Math.sin(atk * Math.PI) * 0.35 : 0);
      if (h.weapon) h.weapon.position.z = atk >= 0 ? Math.sin(atk * Math.PI) * 0.25 : 0;
      h.armL.rotation.x = -0.4;
    } else if (pose === 'bow') {
      const aiming = u.target && u.target.alive && !u.moving;
      h.armL.rotation.x = aiming ? -1.5 : -0.25;
      h.armR.rotation.x = aiming ? (atk >= 0 ? -1.2 + atk * 0.4 : -1.45) : 0.1;
    } else if (pose === 'sling') {
      h.armR.rotation.x = atk >= 0 ? -atk * Math.PI * 4 : -0.3;
    } else if (pose === 'throw') {
      h.armR.rotation.x = atk >= 0 ? -2.8 + atk * 3.2 : -0.5;
      h.armL.rotation.x = -0.3;
    }
  },

  ring(v, kind, on) {
    if (on && !v[kind]) {
      const m = new THREE.Mesh(this.ringGeo, new THREE.MeshBasicMaterial({ color: kind === 'testudo' ? '#ffd76a' : '#ff6a4a', transparent: true, opacity: 0.75, depthWrite: false }));
      m.position.y = 0.03;
      v.root.add(m);
      v[kind] = m;
    } else if (!on && v[kind]) {
      v.root.remove(v[kind]);
      v[kind].material.dispose();
      v[kind] = null;
    }
    if (v[kind]) v[kind].scale.setScalar(1 + Math.sin(this.T * 6) * 0.06);
  },

  updateShots() {
    for (const [s, m0] of this.shotViews) {
      let m = m0;
      if (!m) {
        m = new THREE.Mesh(SHOT_GEO[s.kind] || SHOT_GEO.arrow, this.shotMat);
        m.castShadow = true;
        this.scene.add(m);
        this.shotViews.set(s, m);
      }
      if (s.done) {
        this.scene.remove(m);
        this.shotViews.delete(s);
        if (s.kind === 'arrow' || s.kind === 'bolt') this.parts.burst(s.x1, 0.5, s.z1, '#e8dcc0', 3, 0.5, 0.6, 0.06, 0.3);
        continue;
      }
      const k = Math.min(1, s.t / s.dur);
      const pos = this.shotPos(s, k), next = this.shotPos(s, Math.min(1, k + 0.02));
      m.position.set(pos[0], pos[1], pos[2]);
      if (s.kind === 'stone' || s.kind === 'boulder' || s.kind === 'sling') m.rotation.set(k * 9, k * 7, 0);
      else m.lookAt(next[0] + (Math.abs(next[0] - pos[0]) < 1e-4 ? (s.x1 > s.x0 ? 0.01 : -0.01) : 0), next[1], next[2]);
    }
  },

  shotPos(s, k) {
    const y0 = s.kind === 'bolt' ? 0.8 : s.kind === 'stone' ? 1.3 : 1.2 * (s.from.size || 1), y1 = 0.75 * (s.target.size || 1);
    const d = Math.abs(s.x1 - s.x0);
    const arc = s.kind === 'stone' || s.kind === 'boulder' ? 2.6 + d * 0.15 : s.kind === 'bolt' ? 0.15 : 0.6 + d * 0.08;
    return [s.x0 + (s.x1 - s.x0) * k, y0 + (y1 - y0) * k + Math.sin(k * Math.PI) * arc, s.z0 + (s.z1 - s.z0) * k];
  },

  ringFx(x, z, r, color) {
    const m = new THREE.Mesh(new THREE.RingGeometry(0.85, 1, 32).rotateX(-Math.PI / 2), new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 0.8, depthWrite: false }));
    m.position.set(x, 0.05, z);
    this.scene.add(m);
    this.effects.push({ mesh: m, t: 0, life: 0.6, grow: r * 1.4, kind: 'ring' });
  },

  // Умения: котёл масла, дождь стрел, вспышки над отрядом
  perkFx(e) {
    const allies = this.sim.units.filter(u => u.alive && u.side === 'ally');
    if (e.id === 'oil') {
      const mb = new MB(4);
      mb.cyl(0, -0.35, 0, 0.55, 0.6, '#3a3330', { segs: 12, ao: 1, rTop: 0.65 });
      mb.box(-0.75, 0.15, -0.05, 0.75, 0.22, 0.05, FIG.woodDark, NOAO);
      const pot = new THREE.Mesh(mb.build(0, 0).solid, new THREE.MeshLambertMaterial({ vertexColors: true }));
      pot.position.set(e.x, 4.2, e.z);
      this.scene.add(pot);
      this.effects.push({ mesh: pot, t: 0, life: 1.6, kind: 'pot', x: e.x, z: e.z });
      this.banner('Кипящее масло!', 1.2);
    } else if (e.id === 'volley') {
      for (const u of this.sim.units.filter(o => o.alive && o.side === 'enemy')) {
        for (let i = 0; i < 3; i++) {
          const fake = { kind: 'arrow', from: { size: 1 }, target: u, x0: -16 - Math.random() * 4, z0: u.z + (Math.random() - 0.5), x1: u.x + (Math.random() - 0.5) * 0.6, z1: u.z, t: -Math.random() * 0.4, dur: 0.9 };
          this.effects.push({ shot: fake, kind: 'volley' });
        }
      }
      this.banner('Залп!', 1.2);
    } else if (e.id === 'testudo') {
      for (const a of allies) this.parts.burst(a.x, 0.9, a.z, '#ffd76a', 6, 0.5, 1, 0.08, 0.6);
      this.banner('Черепаха!', 1.2);
    } else if (e.id === 'bandage') {
      for (const a of allies) for (let i = 0; i < 5; i++) this.parts.add({ x: a.x + (Math.random() - 0.5) * 0.5, y: 0.6, z: a.z, vx: 0, vy: 1.4, vz: 0, g: 0, s: 0.09, life: 0.9, color: '#7fe08a', grow: 0.3 });
      this.banner('Перевязка!', 1.2);
    } else if (e.id === 'horn') {
      const cx = allies.reduce((s, a) => s + a.x, 0) / Math.max(1, allies.length);
      this.ringFx(cx, 0, 4, '#ffb04a');
      this.banner('Боевой рог!', 1.2);
    }
  },

  updateEffects(dt) {
    for (const fx of this.effects) {
      if (fx.kind === 'ring') {
        fx.t += dt;
        const k = fx.t / fx.life;
        fx.mesh.scale.setScalar(0.3 + k * fx.grow);
        fx.mesh.material.opacity = 0.8 * (1 - k);
        if (k >= 1) { this.scene.remove(fx.mesh); fx.done = true; }
      } else if (fx.kind === 'pot') {
        fx.t += dt;
        fx.mesh.rotation.z = Math.min(2.2, fx.t * 3);
        if (dt > 0 && fx.t > 0.35 && fx.t < 1.2) for (let i = 0; i < 6; i++) this.parts.add({ x: fx.x + (Math.random() - 0.5) * 0.6, y: 3.7, z: fx.z + (Math.random() - 0.5) * 0.6, vx: (Math.random() - 0.5) * 1.5, vy: -1, vz: (Math.random() - 0.5) * 1.2, g: -9, s: 0.12, life: 0.8, color: Math.random() < 0.6 ? '#c9822a' : '#f2c25a', grow: 0.4 });
        if (dt > 0 && fx.t > 0.6 && fx.t < 1.5 && Math.random() < 0.5) this.parts.add({ x: fx.x + (Math.random() - 0.5) * 2.5, y: 0.2, z: fx.z + (Math.random() - 0.5) * 1.5, vx: 0, vy: 0.8, vz: 0, g: 0.3, s: 0.3, life: 1.2, color: '#e8e2d6', grow: 1.5 });
        if (fx.t > fx.life) { this.scene.remove(fx.mesh); fx.done = true; }
      } else if (fx.kind === 'volley') {
        const s = fx.shot;
        s.t += dt;
        if (s.t < 0) continue;
        if (!fx.mesh) { fx.mesh = new THREE.Mesh(SHOT_GEO.arrow, this.shotMat); this.scene.add(fx.mesh); }
        const k = Math.min(1, s.t / s.dur), k2 = Math.min(1, k + 0.03);
        const p = this.shotPos(s, k), n = this.shotPos(s, k2);
        fx.mesh.position.set(p[0], p[1] + Math.sin(k * Math.PI) * 4, p[2]);
        fx.mesh.lookAt(n[0], n[1] + Math.sin(k2 * Math.PI) * 4, n[2]);
        if (k >= 1) { this.scene.remove(fx.mesh); fx.done = true; }
      }
    }
    this.effects = this.effects.filter(f => !f.done);
  },

  updateHud() {
    const sim = this.sim;
    const w = $('b-wave');
    if (w) w.textContent = sim.stage.waves.length > 1 ? `Волна ${Math.max(1, sim.waveIdx + 1)} из ${sim.stage.waves.length}` : '';
    for (const [id, p] of Object.entries(sim.perks)) {
      const b = document.querySelector(`[data-perk="${id}"]`);
      if (!b) continue;
      const k = p.ready / PERKS[id].cd;
      b.classList.toggle('ready', p.ready <= 0 && !sim.result);
      b.style.setProperty('--cd', `${k * 100}%`);
      b.querySelector('.cd').textContent = p.ready > 0 ? Math.ceil(p.ready) : '';
    }
    const boss = sim.units.find(u => u.boss && u.side === 'enemy' && u.alive);
    const bb = $('b-boss');
    if (bb) {
      bb.hidden = !boss;
      if (boss) {
        bb.querySelector('b').textContent = boss.name;
        bb.querySelector('.bar > div').style.width = `${Math.max(0, boss.hp / boss.maxHp) * 100}%`;
      }
    }
  },

  showResult() {
    this.resultShown = true;
    const res = Army.finish(this.stage, this.sim.result);
    Sound.battleEnd(res.win);
    const st = this.stage;
    const stars = res.win ? `<div class="stars">${[1, 2, 3].map(i => `<span class="${i <= res.stars ? 'on' : ''}">★</span>`).join('')}</div>` : '';
    const loot = res.reward ? `<div class="loot">${Object.entries(res.reward).map(([k, n]) => `<span class="good-pill out">${Icons.img(k)}+${fmt(n)}</span>`).join('')}</div>` : '';
    const next = res.win ? Army.nextStage(st) : null;
    UI.showModal(`
      <div class="b-result ${res.win ? 'win' : 'lose'}">
        <p class="eyebrow">${st.title}</p>
        <h2>${res.win ? 'Победа!' : res.retreat ? 'Отступили' : 'Поражение'}</h2>
        ${stars}
        <p>${res.win ? `Уцелело бойцов: ${res.alive} из ${res.total}.${res.first ? ' Первая победа здесь — добыча больше.' : ''}` : 'Отряд вернулся домой. Улучшите войска в окне «Легион» → «Войска» или возьмите другой состав.'}</p>
        ${loot}
        ${res.win ? `<p class="b-rating">${Icons.svg('laurel')} +${res.rating} рейтинга легиона</p>` : ''}
        ${res.unlocks && res.unlocks.length ? `<div class="b-unlocks"><small>Открыто</small><b>${res.unlocks.join(' · ')}</b></div>` : ''}
        <div class="actions">
          ${next ? `<button type="button" class="btn" id="res-next">${res.bossBeaten ? `Дальше: ${next.R.name}` : `Дальше: ${next.boss ? next.name : `бой ${next.s + 1}`}`}</button>` : ''}
          <button type="button" class="btn ${next ? 'ghost' : ''}" id="res-again">${res.win ? 'Ещё раз' : 'Попробовать снова'}</button>
          <button type="button" class="btn ghost" id="res-map">На карту</button>
        </div>
      </div>`);
    $('res-map').onclick = () => { UI.closeModal(); this.exit(true); };
    $('res-again').onclick = () => { UI.closeModal(); this.exit(false); ArmyUI.openStage(st.cycle, st.r, st.s); };
    // после босса — на карту: она перелистнётся на новую провинцию
    if (next) $('res-next').onclick = () => { UI.closeModal(); if (res.bossBeaten) { ArmyUI.tab = 'camp'; this.exit(true); } else { this.exit(false); ArmyUI.openStage(next.cycle, next.r, next.s); } };
  },

  exit(toMap) {
    this.active = false;
    if (Sound.drums) Sound.battleEnd(false);
    this.resultShown = false;
    for (const v of this.views.values()) {
      v.hp.remove();
      // у настоящих бойцов общие с другими боями формы и текстуры — их не освобождаем
      if (v.fig.real) { this.scene.remove(v.root); Battle3D.dispose(v.fig); }
    }
    this.scene.traverse(o => {
      if (o.geometry && !Object.values(SHOT_GEO).includes(o.geometry)) o.geometry.dispose();
      if (o.material && o.material.dispose) o.material.dispose();
    });
    if (this.scene.background && this.scene.background.dispose) this.scene.background.dispose();
    this.scene = null;
    this.views = null;
    const ui = $('battle-ui');
    if (ui) ui.remove();
    document.body.classList.remove('battle-mode');
    UI.updateHud(true);
    if (toMap) { ArmyUI.tab = 'camp'; UI.openWindow('legion'); }
  },

  /* ---------- Портреты для меню ---------- */

  portraits: {},

  portrait(key) {
    if (window.Battle3D) return Battle3D.portrait(key) || '';
    if (!this.portraits[key]) this.renderPortraits([key]);
    return this.portraits[key] || '';
  },

  renderPortraits(keys) {
    keys = keys.filter(k => !this.portraits[k]);
    if (!keys.length) return;
    const canvas = document.createElement('canvas');
    let r;
    try { r = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: true, preserveDrawingBuffer: true }); } catch (e) { return; }
    const size = 160;
    r.setSize(size, size, false);
    r.setPixelRatio(1);
    r.outputColorSpace = THREE.SRGBColorSpace;
    r.toneMapping = THREE.ACESFilmicToneMapping;
    r.setClearColor(0x000000, 0);
    const scene = new THREE.Scene();
    scene.add(new THREE.HemisphereLight('#fff6e6', '#8d9a70', 2.0));
    const sun = new THREE.DirectionalLight('#fff0d6', 2.4);
    sun.position.set(3, 5, 6);
    scene.add(sun);
    const cam = new THREE.PerspectiveCamera(28, 1, 0.1, 50);
    for (const key of keys) {
      const fig = buildFigure(key);
      const root = fig.root;
      root.rotation.y = 0.55;
      if (fig.kind === 'human') {
        fig.armR.rotation.x = fig.pose === 'spear' ? -1.25 : -0.6;
        if (fig.pose === 'bow') fig.armL.rotation.x = -0.9;
      }
      scene.add(root);
      root.updateMatrixWorld(true);
      const sph = new THREE.Box3().setFromObject(root).getBoundingSphere(new THREE.Sphere());
      const dist = sph.radius / Math.sin(THREE.MathUtils.degToRad(14)) * 0.95;
      cam.position.set(sph.center.x + dist * 0.1, sph.center.y + dist * 0.28, sph.center.z + dist * 0.95);
      cam.lookAt(sph.center.x, sph.center.y - sph.radius * 0.05, sph.center.z);
      r.render(scene, cam);
      this.portraits[key] = canvas.toDataURL('image/png');
      scene.remove(root);
      root.traverse(o => { if (o.geometry) o.geometry.dispose(); });
      fig.mat.dispose();
    }
    r.dispose();
    r.forceContextLoss();
  },
};
