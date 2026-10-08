'use strict';
/* Армия по мотивам Hustle Castle: пять родов войск из военных зданий города, прокачка зданий,
   оружия и брони по настоящим часам, Военное дело, умения в бою и карта походов против варваров,
   зверей и чудовищ. Здесь — данные и правила. Бой считает BattleSim (без графики), рисует battle.js. */

/* ---------- Рода войск ----------
   Числа — на 1 уровне оружия и брони. range — дальность удара, rate — секунд между ударами,
   speed — шаг в секунду (0 — машина стоит в тылу). vs — против кого бьют сильнее. */
const UNITS = {
  legionary: { name: 'Легионер', many: 'Легионеры', gen: 'легионеров', building: 'barracks',
    role: 'Щит и меч. Держит строй и принимает удар на себя.',
    hp: 270, atk: 22, armor: 32, range: 1.0, rate: 1.0, speed: 1.6, vs: { human: 1.3 }, strong: 'людей ближнего боя' },
  spearman: { name: 'Копейщик', many: 'Копейщики', gen: 'копейщиков', building: 'spearcamp',
    role: 'Тяжёлая броня и длинное копьё: бьёт первым, но ходит медленно.',
    hp: 330, atk: 19, armor: 48, range: 1.7, rate: 1.3, speed: 1.1, vs: { beast: 1.6, giant: 1.6 }, strong: 'зверей и великанов' },
  archer: { name: 'Лучник', many: 'Лучники', gen: 'лучников', building: 'range',
    role: 'Стреляет издалека, но сам хрупкий — держится за спинами.',
    hp: 150, atk: 19, armor: 10, range: 7.5, rate: 1.15, speed: 1.5, shot: 'arrow', vs: { ranged: 1.35, swift: 1.35 }, strong: 'стрелков и быстрых зверей' },
  ballista: { name: 'Баллиста', many: 'Баллисты', gen: 'баллист', building: 'ballistae',
    role: 'Тяжёлый болт пробивает строй врагов насквозь. Стоит в тылу.',
    hp: 220, atk: 50, armor: 22, range: 13, rate: 3.0, speed: 0, shot: 'bolt', pierce: true, vs: { armored: 1.6, giant: 1.5 }, strong: 'бронированных и чудовищ' },
  catapult: { name: 'Катапульта', many: 'Катапульты', gen: 'катапульт', building: 'catapults',
    role: 'Камень по площади: бьёт редко, но накрывает толпу. Стоит в тылу.',
    hp: 240, atk: 40, armor: 22, range: 14, minRange: 2.5, rate: 4.0, speed: 0, shot: 'stone', splash: 1.6, vs: { swarm: 1.4, human: 1.15 }, strong: 'толпу' },
};
const UNIT_IDS = Object.keys(UNITS);
const UNIT_BY_BUILDING = Object.fromEntries(UNIT_IDS.map(k => [UNITS[k].building, k]));

/* ---------- Враги ----------
   tags: human — люди, beast — звери, giant — великаны, ranged — стрелки, armored — в броне,
   swift — быстрые, swarm — стаей. prefer: 'ranged' — сначала бросаются на стрелков. */
const ENEMIES = {
  bandit: { name: 'Разбойник', hp: 120, atk: 12, armor: 5, range: 0.95, rate: 1.0, speed: 1.7, tags: ['human'] },
  slinger: { name: 'Пращник', hp: 85, atk: 11, armor: 0, range: 6.5, rate: 1.3, speed: 1.6, shot: 'sling', tags: ['human', 'ranged'] },
  wolf: { name: 'Волк', hp: 85, atk: 10, armor: 0, range: 0.85, rate: 0.75, speed: 2.8, prefer: 'ranged', tags: ['beast', 'swift', 'swarm'] },
  boar: { name: 'Вепрь', hp: 170, atk: 15, armor: 18, range: 0.9, rate: 1.1, speed: 2.1, tags: ['beast'] },
  bear: { name: 'Медведь', hp: 380, atk: 26, armor: 20, range: 1.1, rate: 1.4, speed: 1.4, size: 1.25, tags: ['beast', 'giant'] },
  gaul: { name: 'Галл', hp: 200, atk: 18, armor: 14, range: 1.0, rate: 1.05, speed: 1.6, tags: ['human'] },
  gaulArcher: { name: 'Галльский лучник', hp: 115, atk: 16, armor: 6, range: 7, rate: 1.25, speed: 1.5, shot: 'arrow', tags: ['human', 'ranged'] },
  berserker: { name: 'Берсерк', hp: 240, atk: 27, armor: 4, range: 1.0, rate: 0.8, speed: 2.1, tags: ['human', 'swift'] },
  bull: { name: 'Бешеный бык', hp: 300, atk: 22, armor: 25, range: 1.0, rate: 1.3, speed: 2.3, size: 1.1, tags: ['beast'] },
  pirate: { name: 'Пират', hp: 190, atk: 20, armor: 10, range: 1.0, rate: 0.95, speed: 1.8, tags: ['human', 'swift'] },
  mercenary: { name: 'Наёмник Карфагена', hp: 260, atk: 20, armor: 38, range: 1.0, rate: 1.1, speed: 1.4, tags: ['human', 'armored'] },
  shade: { name: 'Тень Аида', hp: 240, atk: 23, armor: 32, range: 1.0, rate: 1.0, speed: 1.6, tags: ['human', 'armored'] },
  hellhound: { name: 'Адский пёс', hp: 130, atk: 15, armor: 8, range: 0.85, rate: 0.7, speed: 3.0, prefer: 'ranged', tags: ['beast', 'swift', 'swarm'] },
  // боссы — последний бой каждой провинции
  chief: { name: 'Атаман разбойников', boss: true, hp: 620, atk: 26, armor: 18, range: 1.1, rate: 1.0, speed: 1.6, size: 1.3, tags: ['human'] },
  greatbear: { name: 'Медведь-шатун', boss: true, hp: 1050, atk: 36, armor: 25, range: 1.3, rate: 1.4, speed: 1.5, size: 1.7, cleave: 1.2, tags: ['beast', 'giant'] },
  gaulKing: { name: 'Вождь галлов', boss: true, hp: 1150, atk: 34, armor: 32, range: 1.2, rate: 1.0, speed: 1.6, size: 1.35, cleave: 1.0, tags: ['human', 'armored'] },
  giant: { name: 'Германский великан', boss: true, hp: 1700, atk: 46, armor: 22, range: 1.6, rate: 1.6, speed: 1.2, size: 1.9, cleave: 1.5, tags: ['human', 'giant'] },
  minotaur: { name: 'Минотавр', boss: true, hp: 2300, atk: 56, armor: 40, range: 1.5, rate: 1.4, speed: 1.6, size: 1.75, cleave: 1.3, charge: true, tags: ['beast', 'giant', 'armored'] },
  cyclops: { name: 'Циклоп', boss: true, hp: 3000, atk: 62, armor: 30, range: 8, rate: 2.6, speed: 1.1, size: 2.1, shot: 'boulder', splash: 1.8, tags: ['giant'] },
  elephant: { name: 'Боевой слон Ганнибала', boss: true, hp: 4000, atk: 70, armor: 50, range: 1.7, rate: 1.8, speed: 1.2, size: 1.45, cleave: 1.8, tags: ['beast', 'giant', 'armored'] },
  cerberus: { name: 'Цербер', boss: true, hp: 4600, atk: 80, armor: 40, range: 1.5, rate: 1.1, speed: 1.9, size: 1.9, bites: 3, tags: ['beast', 'giant'] },
};

/* ---------- Провинции карты походов ---------- */
const REGIONS = [
  { id: 'forest', name: 'Лес разбойников', biome: 'forest', foes: ['bandit', 'bandit', 'slinger', 'wolf'], boss: 'chief',
    desc: 'Шайки на лесной дороге. Хватит трёх легионеров.' },
  { id: 'hills', name: 'Дикие холмы', biome: 'hills', foes: ['wolf', 'wolf', 'boar', 'bear'], boss: 'greatbear',
    desc: 'Волчьи стаи и медведи. Копейщики держат зверя на расстоянии.' },
  { id: 'gaul', name: 'Галльская чаща', biome: 'darkforest', foes: ['gaul', 'gaul', 'gaulArcher', 'boar'], boss: 'gaulKing',
    desc: 'Галлы бьются отчаянно, их лучники прячутся за деревьями.' },
  { id: 'germania', name: 'Германские болота', biome: 'swamp', foes: ['berserker', 'wolf', 'gaulArcher', 'berserker'], boss: 'giant',
    desc: 'Берсерки не знают страха. В тумане ждёт великан.' },
  { id: 'crete', name: 'Лабиринт Минотавра', biome: 'labyrinth', foes: ['bull', 'pirate', 'bull', 'slinger'], boss: 'minotaur',
    desc: 'Каменные коридоры Крита и бешеные быки.' },
  { id: 'sicily', name: 'Скалы циклопов', biome: 'rocks', foes: ['pirate', 'slinger', 'pirate', 'boar'], boss: 'cyclops',
    desc: 'Пираты на берегу, а наверху — циклоп с камнями.' },
  { id: 'carthage', name: 'Пески Карфагена', biome: 'desert', foes: ['mercenary', 'slinger', 'mercenary', 'pirate'], boss: 'elephant',
    desc: 'Наёмники в броне и боевые слоны Ганнибала.' },
  { id: 'hades', name: 'Врата Аида', biome: 'hades', foes: ['shade', 'hellhound', 'shade', 'hellhound'], boss: 'cerberus',
    desc: 'Тени и адские псы стерегут вход. За ними — Цербер.' },
];
const STAGES_PER_REGION = 8;

/* ---------- Умения в бою ---------- */
const PERKS = {
  oil: { name: 'Кипящее масло', cd: 14, desc: 'Котёл опрокидывают на самую плотную толпу врагов: сильный урон и ожог.' },
  testudo: { name: 'Черепаха', cd: 20, desc: 'Отряд смыкает щиты: урон по бойцам заметно меньше.' },
  bandage: { name: 'Перевязка', cd: 22, desc: 'Лекари перевязывают раненых: отряд лечится.' },
  volley: { name: 'Залп', cd: 18, desc: 'Лучники из тыла бьют по всем врагам разом.' },
  horn: { name: 'Боевой рог', cd: 25, desc: 'Отряд бьёт и двигается быстрее.' },
};
const PERK_IDS = Object.keys(PERKS);
const PERK_MAX = 5;

/* ---------- Военное дело — своя ветка знаний (за Славу и денарии) ---------- */
const MIL_TECHS = [
  { id: 'archery', name: 'Стрельба из лука', col: 0, req: [], glory: 5, money: 300, unlocks: 'range', desc: 'Стрельбище: лучники.' },
  { id: 'oil', name: 'Кипящее масло', col: 0, req: [], glory: 4, money: 200, perk: 'oil', desc: 'Умение в бою: котёл масла на толпу.' },
  { id: 'drill', name: 'Строевая подготовка', col: 0, req: [], glory: 8, money: 400, bonus: { hp: 0.1 }, desc: '+10% здоровья всем бойцам.' },
  { id: 'spears', name: 'Длинные копья', col: 1, req: ['drill'], glory: 12, money: 600, unlocks: 'spearcamp', desc: 'Лагерь копейщиков: копейщики.' },
  { id: 'testudo', name: 'Черепаха', col: 1, req: ['oil'], glory: 12, money: 500, perk: 'testudo', desc: 'Умение в бою: отряд смыкает щиты.' },
  { id: 'steel', name: 'Закалённая сталь', col: 1, req: ['drill'], glory: 15, money: 700, bonus: { atk: 0.1 }, desc: '+10% урона всем бойцам.' },
  { id: 'torsion', name: 'Торсион', col: 2, req: ['archery', 'steel'], glory: 20, money: 900, unlocks: 'ballistae', desc: 'Мастерская баллист: баллисты.' },
  { id: 'medicus', name: 'Медики', col: 2, req: ['testudo'], glory: 18, money: 800, perk: 'bandage', desc: 'Умение в бою: перевязка раненых.' },
  { id: 'kitchen', name: 'Полевая кухня', col: 2, req: ['drill'], glory: 16, money: 600, bonus: { food: 0.3 }, desc: 'Походы едят на 30% меньше провизии.' },
  { id: 'onager', name: 'Онагр', col: 3, req: ['torsion'], glory: 28, money: 1300, unlocks: 'catapults', desc: 'Мастерская катапульт: катапульты.' },
  { id: 'volley', name: 'Залп', col: 3, req: ['archery', 'medicus'], glory: 25, money: 1100, perk: 'volley', desc: 'Умение в бою: залп по всем врагам.' },
  { id: 'veterans', name: 'Ветераны', col: 3, req: ['steel', 'spears'], glory: 30, money: 1500, bonus: { hp: 0.15, atk: 0.15 }, desc: '+15% здоровья и урона всем бойцам.' },
  { id: 'horn', name: 'Боевой рог', col: 4, req: ['volley'], glory: 35, money: 1800, perk: 'horn', desc: 'Умение в бою: отряд быстрее бьёт и бежит.' },
  { id: 'legat', name: 'Легат', col: 4, req: ['veterans'], glory: 40, money: 2500, bonus: { slot: 1 }, desc: '+1 место в отряде.' },
  { id: 'spoils', name: 'Трофеи', col: 4, req: ['kitchen'], glory: 30, money: 1500, bonus: { loot: 0.3 }, desc: '+30% добычи в походах.' },
];
const MIL_BY_ID = Object.fromEntries(MIL_TECHS.map(t => [t.id, t]));
const MIL_DAYS = [8, 18, 30, 45, 60];   // дней изучения по колонке дерева

/* ---------- Прокачка военных зданий ---------- */
const ARMY_MAX_LEVEL = 10;
// Секунд настоящего времени на улучшение до уровня n: от минуты до двух суток
const UPGRADE_TIME = [0, 0, 60, 300, 1200, 3600, 7200, 14400, 28800, 86400, 172800];
// Предел уровня военных зданий от размера города: растите город, чтобы растить армию
const ARMY_CAP = [[0, 3], [1500, 5], [2500, 7], [4000, 9], [6000, 10]];
const SQUAD_BASE = 3;
const SQUAD_BY_LEVEL = [3, 6, 9];        // уровни Казарм, на которых открывается ещё одно место
const FOOD_PER_SOLDIER = 6;              // провизии (зерно, рыба) на бойца за поход
const FESTIVAL = { glory: 15, days: 60, happy: 12 };

const UPGRADE_KINDS = {
  level: { name: 'Уровень здания', what: 'открывает новые уровни оружия и брони' },
  weapon: { name: 'Оружие', what: '+18% урона за уровень' },
  armor: { name: 'Броня', what: '+6 брони и +15% здоровья за уровень' },
};

function upgradeCost(kind, to) {
  const k = to - 1;
  if (kind === 'level') {
    const c = { money: Math.round(260 * Math.pow(1.55, k)), bricks: Math.round(20 * Math.pow(1.4, k)), iron: Math.round(8 * Math.pow(1.45, k)) };
    if (to >= 6) c.marble = Math.round(10 * Math.pow(1.4, to - 6));
    return c;
  }
  if (kind === 'weapon') return { money: Math.round(160 * Math.pow(1.5, k)), weapons: Math.round(6 * Math.pow(1.38, k)), iron: Math.round(8 * Math.pow(1.38, k)) };
  return { money: Math.round(160 * Math.pow(1.5, k)), iron: Math.round(14 * Math.pow(1.38, k)), wood: Math.round(12 * Math.pow(1.3, k)) };
}

function fmtDuration(sec) {
  sec = Math.max(0, Math.ceil(sec));
  if (sec < 60) return `${sec} с`;
  if (sec < 3600) return `${Math.floor(sec / 60)} мин${sec % 60 && sec < 600 ? ` ${sec % 60} с` : ''}`;
  if (sec < 86400) return `${Math.floor(sec / 3600)} ч${sec % 3600 >= 60 ? ` ${Math.floor(sec % 3600 / 60)} мин` : ''}`;
  return `${Math.floor(sec / 86400)} сут${sec % 86400 >= 3600 ? ` ${Math.floor(sec % 86400 / 3600)} ч` : ''}`;
}

/* Детерминированный генератор случайных чисел: один и тот же бой с тем же зерном идёт одинаково */
function mulberry32(a) {
  return () => {
    a |= 0; a = a + 0x6D2B79F5 | 0;
    let t = Math.imul(a ^ a >>> 15, 1 | a);
    t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
    return ((t ^ t >>> 14) >>> 0) / 4294967296;
  };
}

/* ---------- Армия игрока ---------- */

const Army = {
  ensure() {
    const A = state.army || (state.army = {});
    A.levels = A.levels || {};          // уровень здания по роду войск
    A.gear = A.gear || {};              // { weapon, armor } по роду войск
    A.upg = A.upg || {};                // идущее улучшение по роду: { kind, to, end }
    A.squad = A.squad || ['legionary', 'legionary', 'legionary'];
    A.perks = A.perks || {};
    A.techs = A.techs || [];
    A.research = A.research || null;
    A.stars = A.stars || {};            // "круг-провинция-бой" → звёзды
    A.progress = A.progress || 0;       // сколько боёв первого прохода пройдено подряд
    A.wins = A.wins || 0;
    for (const k of UNIT_IDS) {
      if (!A.levels[k]) A.levels[k] = 1;
      if (!A.gear[k]) A.gear[k] = { weapon: 1, armor: 1 };
    }
    for (const p of PERK_IDS) if (A.perks[p] === undefined) A.perks[p] = 0;
    return A;
  },

  get A() { return state.army; },

  unlocked() { return hasTech('legion'); },

  // Род войск доступен, если его здание стоит в городе
  available(type) {
    const b = UNITS[type].building;
    return isUnlocked(b) && countType(b) > 0;
  },

  bonus(key) {
    let v = 0;
    for (const id of this.A.techs) { const b = MIL_BY_ID[id].bonus; if (b && b[key]) v += b[key]; }
    return v;
  },

  cap() {
    if (TEST_MODE) return ARMY_MAX_LEVEL;
    const pop = state.stats.pop || 0;
    let c = 1;
    for (const [p, l] of ARMY_CAP) if (pop >= p) c = l;
    return c;
  },

  nextCapPop() {
    const lvl = this.cap();
    const next = ARMY_CAP.find(([, l]) => l > lvl);
    return next ? next[0] : null;
  },

  slots() {
    const lvl = this.A.levels.legionary;      // места в отряде открывает уровень Казарм
    let n = SQUAD_BASE;
    for (const l of SQUAD_BY_LEVEL) if (lvl >= l) n++;
    return n + (this.bonus('slot') || 0);
  },

  // Боевые числа бойца с учётом прокачки и Военного дела
  stats(type) {
    const U = UNITS[type], A = this.A, g = A.gear[type], lvl = A.levels[type];
    const hpK = 1 + 0.15 * (g.armor - 1) + 0.04 * (lvl - 1) + this.bonus('hp');
    const atkK = 1 + 0.18 * (g.weapon - 1) + 0.04 * (lvl - 1) + this.bonus('atk');
    return {
      key: type, def: U, name: U.name,
      hp: Math.round(U.hp * hpK), atk: Math.round(U.atk * atkK), armor: U.armor + 6 * (g.armor - 1),
      range: U.range, minRange: U.minRange || 0, rate: U.rate, speed: U.speed,
      shot: U.shot, pierce: U.pierce, splash: U.splash, vs: U.vs, tags: ['roman'], size: 1,
    };
  },

  // «Сила» бойца для сравнения с врагом: живучесть × урон в секунду
  power(s) {
    const ehp = s.hp / (1 - s.armor / (s.armor + 100));
    const mult = (s.splash ? 1.5 : 1) * (s.pierce ? 1.3 : 1) * (s.range > 3 ? 1.15 : 1);
    return Math.round(Math.sqrt(ehp * s.atk / s.rate * mult) * 1.6);
  },

  squadStats() {
    const slots = this.slots();
    return this.A.squad.slice(0, slots).filter(t => this.available(t)).map(t => this.stats(t));
  },

  squadPower() { return this.squadStats().reduce((s, u) => s + this.power(u), 0); },

  foodCost() {
    return Math.ceil(this.squadStats().length * FOOD_PER_SOLDIER * (1 - this.bonus('food')));
  },

  food() { return (state.goods.wheat || 0) + (state.goods.fish || 0) + (state.goods.bread || 0); },

  payFood(n) {
    for (const g of ['wheat', 'fish', 'bread']) {
      const take = Math.min(state.goods[g] || 0, n);
      state.goods[g] -= take;
      n -= take;
      if (n <= 0) break;
    }
  },

  /* ---------- Прокачка в зданиях ---------- */

  upgradeInfo(type, kind) {
    const A = this.A;
    const cur = kind === 'level' ? A.levels[type] : A.gear[type][kind];
    const to = cur + 1;
    const limit = kind === 'level' ? Math.min(ARMY_MAX_LEVEL, this.cap()) : A.levels[type];
    return { cur, to, max: cur >= ARMY_MAX_LEVEL, blocked: to > limit, limit, cost: upgradeCost(kind, to), time: UPGRADE_TIME[Math.min(to, ARMY_MAX_LEVEL)] * (TEST_MODE ? 0.01 : 1) };
  },

  canUpgrade(type, kind) {
    const i = this.upgradeInfo(type, kind);
    return !this.A.upg[type] && !i.max && !i.blocked && canAfford(i.cost);
  },

  startUpgrade(type, kind) {
    if (!this.canUpgrade(type, kind)) return false;
    const i = this.upgradeInfo(type, kind);
    pay(i.cost);
    this.A.upg[type] = { kind, to: i.to, end: Date.now() + i.time * 1000, total: i.time };
    UI.log(`${BUILDINGS[UNITS[type].building].name}: начато улучшение «${UPGRADE_KINDS[kind].name}» до ${i.to} уровня.`, 'info');
    return true;
  },

  finishUpgrade(type) {
    const u = this.A.upg[type];
    if (!u) return;
    if (u.kind === 'level') this.A.levels[type] = u.to;
    else this.A.gear[type][u.kind] = u.to;
    delete this.A.upg[type];
    UI.log(`${BUILDINGS[UNITS[type].building].name}: «${UPGRADE_KINDS[u.kind].name}» теперь ${u.to} уровня. ${UNITS[type].many} стали сильнее!`, 'good', true);
    UI.refreshPanel();
  },

  // Проверка таймеров по настоящим часам — улучшения идут, даже когда игра закрыта
  tick() {
    if (!state.army) return;
    const now = Date.now();
    for (const [type, u] of Object.entries(this.A.upg)) if (now >= u.end) this.finishUpgrade(type);
  },

  /* ---------- Военное дело ---------- */

  techState(t) {
    const A = this.A;
    if (A.techs.includes(t.id)) return 'done';
    if (A.research && A.research.id === t.id) return 'active';
    if (!t.req.every(r => A.techs.includes(r))) return 'locked';
    return 'open';
  },

  canResearch(t) {
    return this.techState(t) === 'open' && !this.A.research && state.glory >= t.glory && state.money >= t.money;
  },

  research(id) {
    const t = MIL_BY_ID[id];
    if (!this.canResearch(t)) return false;
    state.glory -= t.glory;
    state.money -= t.money;
    const days = MIL_DAYS[t.col];
    this.A.research = { id, left: days, total: days };
    UI.log(`Военное дело: начали изучать «${t.name}». Будет готово через ${days} ${plural(days, 'день', 'дня', 'дней')}.`, 'info');
    return true;
  },

  daily() {
    if (!state.army) return;
    const r = this.A.research;
    if (!r || --r.left > 0) return;
    this.A.research = null;
    const t = MIL_BY_ID[r.id];
    this.A.techs.push(t.id);
    if (t.perk && !this.A.perks[t.perk]) this.A.perks[t.perk] = 1;
    const what = t.unlocks ? ` Открыто: ${BUILDINGS[t.unlocks].name}.` : t.perk ? ` Новое умение в бою: ${PERKS[t.perk].name}.` : '';
    UI.log(`Военное дело: изучено «${t.name}».${what}`, 'good', true);
    UI.buildToolbar();
    if (UI.winOpen && UI.winTab === 'research') UI.renderWindow();
  },

  perkCost(id) { return 6 + 6 * this.A.perks[id]; },

  upgradePerk(id) {
    const lvl = this.A.perks[id];
    if (!lvl || lvl >= PERK_MAX || state.glory < this.perkCost(id)) return false;
    state.glory -= this.perkCost(id);
    this.A.perks[id]++;
    return true;
  },

  festival() {
    if (state.glory < FESTIVAL.glory || state.day < state.festivalUntil) return false;
    state.glory -= FESTIVAL.glory;
    state.festivalUntil = state.day + FESTIVAL.days;
    UI.log(`Триумф! Город празднует ${FESTIVAL.days} дней, все жители счастливее.`, 'good', true);
    return true;
  },

  /* ---------- Карта походов ---------- */

  stageKey(cycle, r, s) { return `${cycle}-${r}-${s}`; },

  // Номер боя по порядку: 0, 1, 2… сквозь провинции и круги
  stageIndex(cycle, r, s) { return (cycle * REGIONS.length + r) * STAGES_PER_REGION + s; },

  isOpen(cycle, r, s) { return this.stageIndex(cycle, r, s) <= this.A.progress; },

  // Состав и награда боя — одинаковые при каждом заходе
  stage(cycle, r, s) {
    const R = REGIONS[r], D = this.stageIndex(cycle, r, s);
    const rnd = mulberry32(D * 7919 + 13);
    const boss = s === STAGES_PER_REGION - 1;
    const nWaves = boss ? 2 : s < 3 ? 1 : s < 6 ? 2 : 3;
    const scale = Math.pow(1.02, D) * (1 + cycle * 0.6);
    const waves = [];
    for (let w = 0; w < nWaves; w++) {
      const n = Math.min(6, 2 + Math.floor((s + r) / 3) + (w === nWaves - 1 && !boss ? 1 : 0));
      const wave = [];
      for (let i = 0; i < n; i++) wave.push(R.foes[Math.floor(rnd() * R.foes.length)]);
      if (boss && w === nWaves - 1) { wave.length = Math.min(wave.length, 2); wave.unshift(R.boss); }
      waves.push(wave);
    }
    const reward = {
      money: Math.round(45 * Math.pow(1.085, D)),
      glory: 1 + Math.floor(D / 5) + (boss ? 3 : 0),
    };
    const extra = boss ? ['iron', 'weapons', 'marble'][r % 3] : rnd() < 0.3 ? ['iron', 'weapons', 'bricks'][Math.floor(rnd() * 3)] : null;
    if (extra) reward[extra] = Math.round((boss ? 25 : 10) * (1 + D * 0.08));
    const title = `${R.name}${cycle ? ' ' + roman(cycle + 1) : ''}`;
    return { cycle, r, s, D, R, boss, waves, scale, reward, title, name: boss ? ENEMIES[R.boss].name : `Бой ${s + 1}`, key: this.stageKey(cycle, r, s) };
  },

  // Следующий бой после этого, если он уже открыт
  nextStage(st) {
    let { cycle, r, s } = st;
    if (++s >= STAGES_PER_REGION) { s = 0; if (++r >= REGIONS.length) { r = 0; cycle++; } }
    return this.isOpen(cycle, r, s) ? this.stage(cycle, r, s) : null;
  },

  enemyStats(key, scale) {
    const E = ENEMIES[key];
    return {
      key, def: E, name: E.name,
      hp: Math.round(E.hp * scale), atk: Math.round(E.atk * Math.pow(scale, 0.92)), armor: Math.min(85, E.armor + Math.log(scale) * 6),
      range: E.range, minRange: 0, rate: E.rate, speed: E.speed, shot: E.shot, splash: E.splash, cleave: E.cleave,
      charge: E.charge, bites: E.bites, prefer: E.prefer, tags: E.tags, boss: !!E.boss, size: E.size || 1,
    };
  },

  stagePower(st) {
    let p = 0;
    for (const w of st.waves) for (const k of w) p += this.power(this.enemyStats(k, st.scale));
    return p;
  },

  // Награда с учётом первой победы и знания «Трофеи»
  rewardFor(st, first) {
    const k = (first ? 2.5 : 1) * (1 + this.bonus('loot'));
    const out = {};
    for (const [res, v] of Object.entries(st.reward)) out[res] = Math.max(1, Math.round(v * k));
    return out;
  },

  canFight() {
    const sq = this.squadStats();
    if (!sq.length) return 'В отряде нет бойцов — постройте Казармы.';
    if (this.food() < this.foodCost()) return `Не хватает провизии: нужно ${this.foodCost()} зерна или рыбы.`;
    return null;
  },

  // Итог боя: звёзды, добыча, открытие следующего
  finish(st, result) {
    const A = this.A;
    const first = result.win && this.stageIndex(st.cycle, st.r, st.s) === A.progress;
    let reward = null;
    if (result.win) {
      const stars = result.alive === result.total ? 3 : result.alive * 2 >= result.total ? 2 : 1;
      A.stars[st.key] = Math.max(A.stars[st.key] || 0, stars);
      reward = this.rewardFor(st, first);
      giveReward(reward);
      A.wins++;
      if (first) A.progress++;
      result.stars = stars;
    }
    result.first = first;
    result.reward = reward;
    checkGoals();
    UI.updateHud(true);
    return result;
  },
};

/* ---------- Бой без графики ----------
   Отряды стоят по краям поля (ось x), враги идут волнами справа. Каждый боец сам выбирает цель,
   подходит на дистанцию удара и бьёт. Игрок только жмёт умения. Все события — в this.events
   для отрисовки. Шаг времени фиксированный, поэтому бой с тем же зерном всегда одинаков. */

class BattleSim {
  constructor(squad, stage, perks, seed) {
    this.rnd = mulberry32(seed || 1);
    this.t = 0;
    this.units = [];
    this.shots = [];
    this.events = [];
    this.stage = stage;
    this.waveIdx = -1;
    this.waveDelay = 0;
    this.result = null;
    this.uid = 1;
    this.perks = {};
    for (const [id, lvl] of Object.entries(perks || {})) if (lvl > 0) this.perks[id] = { lvl, ready: PERKS[id].cd * 0.5 };
    // строй: ближний бой впереди, стрелки за ними, машины в тылу
    const lanes = [0, -1.1, 1.1, -2.1, 2.1, -0.55, 0.55];
    const order = squad.slice().sort((a, b) => (a.range > 3) - (b.range > 3) || (a.speed === 0) - (b.speed === 0));
    order.forEach((s, i) => {
      const x = s.speed === 0 ? -7.4 : s.range > 3 ? -6.0 : -4.6;
      const u = this.add('ally', s, x - (i % 2) * 0.5, lanes[i % lanes.length]);
      u.homeX = u.x; u.homeZ = u.z;
    });
    this.total = this.units.length;
    this.avgAtk = squad.reduce((a, s) => a + s.atk, 0) / Math.max(1, squad.length);
    this.nextWave();
  }

  add(side, s, x, z) {
    const u = Object.assign({}, s, { id: this.uid++, side, x, z, maxHp: s.hp, alive: true, timer: 0.3 + this.rnd() * 0.6, target: null, retarget: 0,
      testudo: 0, horn: 0, burn: 0, burnDps: 0, chargeCd: 4, moving: false, attackT: 0, hitT: 0 });
    this.units.push(u);
    return u;
  }

  nextWave() {
    this.waveIdx++;
    const wave = this.stage.waves[this.waveIdx];
    if (!wave) return false;
    const lanes = [0, -1.2, 1.2, -2.2, 2.2, -0.6, 0.6];
    wave.forEach((k, i) => {
      const s = Army.enemyStats(k, this.stage.scale);
      const ranged = s.range > 3;
      const u = this.add('enemy', s, 12 + (ranged ? 1.5 : 0) + (i % 3) * 0.7 + (s.boss ? 1 : 0), s.boss ? 0 : lanes[i % lanes.length]);
      u.entering = true;
    });
    this.events.push({ type: 'wave', n: this.waveIdx + 1, total: this.stage.waves.length });
    return true;
  }

  foes(u) { return this.units.filter(o => o.alive && o.side !== u.side); }

  dist(a, b) { return Math.hypot(a.x - b.x, (a.z - b.z) * 0.8); }

  pickTarget(u) {
    const foes = this.foes(u);
    if (!foes.length) return null;
    let pool = foes;
    if (u.prefer === 'ranged') { const r = foes.filter(o => o.range > 3); if (r.length) pool = r; }
    if (u.pierce) { const big = foes.filter(o => o.boss || o.tags.includes('armored') || o.tags.includes('giant')); if (big.length) pool = big; }
    if (u.splash && u.side === 'ally') {
      // катапульта метит в гущу врагов
      let best = null, bn = -1;
      for (const o of foes) {
        const n = foes.filter(p => this.dist(o, p) < u.splash).length;
        if (n > bn) { bn = n; best = o; }
      }
      return best;
    }
    let best = null, bd = Infinity;
    for (const o of pool) { const d = this.dist(u, o); if (d < bd) { bd = d; best = o; } }
    return best;
  }

  mult(u, t) {
    let m = 1;
    if (u.vs) for (const tag of t.tags) if (u.vs[tag]) m = Math.max(m, u.vs[tag]);
    return m;
  }

  damage(u, t, k) {
    if (!t.alive) return;
    const crit = this.rnd() < 0.08;
    let d = u.atk * this.mult(u, t) * (0.9 + this.rnd() * 0.2) * (k || 1) * (crit ? 1.6 : 1);
    d *= 1 - t.armor / (t.armor + 100);
    if (t.testudo > this.t) d *= 1 - (0.4 + 0.05 * (this.perks.testudo ? this.perks.testudo.lvl : 1));
    d = Math.max(1, Math.round(d));
    t.hp -= d;
    t.hitT = 0.25;
    this.events.push({ type: 'hit', unit: t, dmg: d, crit, from: u });
    if (t.hp <= 0) this.kill(t);
  }

  kill(t) {
    t.alive = false;
    t.hp = 0;
    this.events.push({ type: 'death', unit: t });
  }

  attack(u, t) {
    u.attackT = 0.35;
    if (u.shot) {
      const d = Math.abs(t.x - u.x);
      const speed = u.shot === 'stone' || u.shot === 'boulder' ? 9 : u.shot === 'bolt' ? 24 : 16;
      const shot = { kind: u.shot, from: u, target: t, x0: u.x, z0: u.z, x1: t.x, z1: t.z, t: 0, dur: Math.max(0.25, d / speed), side: u.side };
      this.shots.push(shot);
      this.events.push({ type: 'shoot', shot });
      return;
    }
    if (u.bites) {
      // Цербер кусает тремя головами сразу трёх ближайших
      const near = this.foes(u).sort((a, b) => this.dist(u, a) - this.dist(u, b)).slice(0, u.bites);
      for (const o of near) if (this.dist(u, o) < u.range + 1.2) this.damage(u, o, 0.75);
      return;
    }
    if (u.cleave) {
      // удар великана задевает всех рядом с целью
      for (const o of this.foes(u)) if (o === t || this.dist(o, t) < u.cleave) this.damage(u, o, o === t ? 1 : 0.6);
      this.events.push({ type: 'slam', x: t.x, z: t.z, r: u.cleave });
      return;
    }
    this.damage(u, t);
  }

  land(s) {
    const u = s.from;
    if (s.kind === 'bolt') {
      // болт летит дальше и пробивает всех на линии
      let k = 1;
      const hit = this.units.filter(o => o.alive && o.side !== s.side && Math.abs(o.z - s.z1) < 0.7 && (s.side === 'ally' ? o.x >= s.x0 : o.x <= s.x0))
        .sort((a, b) => Math.abs(a.x - s.x0) - Math.abs(b.x - s.x0)).slice(0, 4);
      for (const o of hit) { this.damage(u, o, k); k *= 0.7; }
      return;
    }
    if (s.kind === 'stone' || s.kind === 'boulder') {
      const r = u.splash || 1.4;
      for (const o of this.units) if (o.alive && o.side !== s.side && Math.hypot(o.x - s.x1, o.z - s.z1) < r) this.damage(u, o, o === s.target ? 1 : 0.7);
      this.events.push({ type: 'boom', x: s.x1, z: s.z1, r });
      return;
    }
    if (s.target.alive) this.damage(u, s.target);
  }

  usePerk(id) {
    const p = this.perks[id];
    if (!p || p.ready > 0 || this.result) return false;
    const foes = this.units.filter(o => o.alive && o.side === 'enemy');
    const allies = this.units.filter(o => o.alive && o.side === 'ally');
    const lvl = p.lvl;
    if (id === 'oil') {
      if (!foes.length) return false;
      let c = foes[0], bn = -1;
      for (const o of foes) { const n = foes.filter(q => Math.hypot(q.x - o.x, q.z - o.z) < 2).length; if (n > bn) { bn = n; c = o; } }
      const src = { atk: this.avgAtk * (4 + lvl), vs: null };
      for (const o of foes) if (Math.hypot(o.x - c.x, o.z - c.z) < 2.2) { this.damage(src, o); o.burn = this.t + 4; o.burnDps = this.avgAtk * 0.5 * (1 + lvl * 0.25); }
      this.events.push({ type: 'perk', id, x: c.x, z: c.z });
    } else if (id === 'volley') {
      if (!foes.length) return false;
      const src = { atk: this.avgAtk * (1.6 + 0.5 * lvl), vs: null };
      for (const o of foes) this.damage(src, o);
      this.events.push({ type: 'perk', id });
    } else if (id === 'testudo') {
      for (const a of allies) a.testudo = this.t + 5 + lvl;
      this.events.push({ type: 'perk', id });
    } else if (id === 'bandage') {
      for (const a of allies) {
        const h = Math.round(a.maxHp * (0.2 + 0.05 * lvl));
        a.hp = Math.min(a.maxHp, a.hp + h);
        this.events.push({ type: 'heal', unit: a, amount: h });
      }
      this.events.push({ type: 'perk', id });
    } else if (id === 'horn') {
      for (const a of allies) a.horn = this.t + 8;
      this.events.push({ type: 'perk', id });
    }
    p.ready = PERKS[id].cd;
    return true;
  }

  step(dt) {
    if (this.result) return;
    this.t += dt;
    for (const p of Object.values(this.perks)) p.ready = Math.max(0, p.ready - dt);
    const hornK = 1.4 + 0.1 * (this.perks.horn ? this.perks.horn.lvl : 1);

    for (const u of this.units) {
      if (!u.alive) continue;
      u.attackT = Math.max(0, u.attackT - dt);
      u.hitT = Math.max(0, u.hitT - dt);
      if (u.burn > this.t) {
        u.hp -= u.burnDps * dt;
        if (u.hp <= 0) { this.kill(u); continue; }
      }
      // враги новой волны сначала выходят на поле
      if (u.entering) {
        u.x -= u.speed * 1.4 * dt;
        u.moving = true;
        if (u.x < 3.5 + (u.range > 3 ? 1.8 : 0)) u.entering = false;
        continue;
      }
      u.retarget -= dt;
      if (!u.target || !u.target.alive || u.retarget <= 0) { u.target = this.pickTarget(u); u.retarget = 0.6; }
      const t = u.target;
      if (!t) {
        // врагов нет — отряд возвращается в строй и ждёт следующую волну
        if (u.side === 'ally' && u.homeX !== undefined && u.speed > 0 && Math.abs(u.x - u.homeX) > 0.15) {
          u.x += Math.sign(u.homeX - u.x) * Math.min(u.speed * 1.3 * dt, Math.abs(u.homeX - u.x));
          u.z += (u.homeZ - u.z) * dt * 2;
          u.moving = true;
        } else u.moving = false;
        continue;
      }
      const fast = u.side === 'ally' && u.horn > this.t ? hornK : 1;
      const reach = u.range + 0.35 * ((u.size || 1) + (t.size || 1) - 2);
      const d = this.dist(u, t);
      if (d > reach && u.speed > 0) {
        const dir = Math.sign(t.x - u.x) || 1;
        u.x += dir * Math.min(u.speed * fast * dt, d - reach + 0.01);
        u.z += clamp(t.z - u.z, -1, 1) * dt * 0.8;
        u.moving = true;
        // Минотавр с разбега бьёт сильнее и отбрасывает
        if (u.charge && d < 4 && u.chargeCd <= 0) { u.chargeCd = 7; this.damage(u, t, 1.8); t.x += Math.sign(t.x - u.x) * 1.2; this.events.push({ type: 'slam', x: t.x, z: t.z, r: 1 }); }
      } else {
        u.moving = false;
        if (u.minRange && d < u.minRange) { u.timer = Math.max(u.timer, 0.2); }
        u.timer -= dt * fast;
        if (u.timer <= 0 && d <= reach + 0.05) { this.attack(u, t); u.timer = u.rate * (0.92 + this.rnd() * 0.16); }
      }
      u.chargeCd -= dt;
    }

    // бойцы одной стороны не стоят друг в друге
    for (const a of this.units) {
      if (!a.alive) continue;
      for (const b of this.units) {
        if (b === a || !b.alive || b.side !== a.side) continue;
        const dx = a.x - b.x, dz = a.z - b.z, min = 0.7 * ((a.size || 1) + (b.size || 1)) / 2;
        if (Math.abs(dx) < min && Math.abs(dz) < min) a.z += (dz >= 0 ? 1 : -1) * dt * 1.2;
      }
      a.z = clamp(a.z, -2.6, 2.6);
      a.x = clamp(a.x, -9.5, 14);
    }

    for (const s of this.shots) {
      s.t += dt;
      if (s.target.alive) { s.x1 = s.target.x; s.z1 = s.target.z; }
      if (s.t >= s.dur) { s.done = true; this.land(s); }
    }
    this.shots = this.shots.filter(s => !s.done);

    const allies = this.units.filter(u => u.alive && u.side === 'ally').length;
    const foes = this.units.filter(u => u.alive && u.side === 'enemy').length;
    if (!allies) { this.result = { win: false, alive: 0, total: this.total }; this.events.push({ type: 'end' }); return; }
    if (!foes && !this.shots.length) {
      if (this.waveIdx + 1 < this.stage.waves.length) {
        this.waveDelay += dt;
        if (this.waveDelay > 2.2) { this.waveDelay = 0; this.nextWave(); }
      } else {
        this.result = { win: true, alive: allies, total: this.total };
        this.events.push({ type: 'end' });
      }
    }
    if (this.t > 180) { this.result = { win: false, alive: allies, total: this.total, timeout: true }; this.events.push({ type: 'end' }); }
  }
}
