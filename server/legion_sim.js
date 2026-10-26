'use strict';
/* Бой Легиона на сервере — точная копия LegionSim (godot/scripts/legion_sim.gd) для проверки боёв с городами.
   Игрок присылает итог боя и свои нажатия ([шаг, умение] и [шаг, "auto", вкл]); сервер повторяет бой с тем же
   зерном, теми же отрядами и нажатиями и засчитывает итог повтора, а не слова клиента (server/pvp.js).

   Совпадение — до бита, поэтому здесь повторены и мелочи движка Godot:
   - числа боя — double (как float в GDScript), а Vector2(…).length() считается во float32 (real_t движка):
     vlen() округляет как он (Math.fround на каждом шаге);
   - RandomNumberGenerator Godot: PCG32 (зерно — rng.seed = N, inc по умолчанию) и randf() — два rand() на число:
     первый задаёт порядок (count_leading_zeros), второй — мантиссу (| 0x80000001, во float32);
   - sort_custom на массивах короче 16 — сортировка вставками (устойчивая), как Array.prototype.sort.
   Меняете legion_sim.gd или числа бойцов в legion.gd — меняйте и здесь; сверка: node server/test_sim.js
   (сравнивает с боями, которые посчитал сам Godot: godot/scripts/test_sim_dump.gd). */

const DT = 1.0 / 30.0;
const TIME_LIMIT = 180.0;
const WAVE_DELAY = 2.2;
const FIELD_X0 = -9.5, FIELD_X1 = 14.0;     // Vector2 во float32 — оба числа точные
const FIELD_Z = 2.6;
const LANES = [0.0, -1.1, 1.1, -2.1, 2.1, -0.55, 0.55];
const ENEMY_LANES = [0.0, -1.2, 1.2, -2.2, 2.2, -0.6, 0.6];
const PERK_K = { oil: [3.0, 0.15], burn: [0.4, 0.15], volley: [1.2, 0.15], testudo: [0.35, 0.04], bandage: [0.18, 0.03], horn: [1.3, 0.05] };
const PERKS = { oil: { cd: 14.0 }, testudo: { cd: 20.0 }, bandage: { cd: 22.0 }, volley: { cd: 18.0 }, horn: { cd: 25.0 } };
const PERK_MAX = 5, MAX_LEVEL = 40;

// бойцы Легиона — как Legion.UNITS (только то, что нужно бою)
const UNITS = {
  legionary: { hp: 270, atk: 22, armor: 32, range: 1.0, rate: 1.0, speed: 1.6, vs: { human: 1.3 }, tags: ['human'] },
  spearman: { hp: 330, atk: 19, armor: 48, range: 1.7, rate: 1.3, speed: 1.1, vs: { beast: 1.6, giant: 1.6 }, tags: ['human', 'armored'] },
  archer: { hp: 150, atk: 19, armor: 10, range: 7.5, rate: 1.15, speed: 1.5, shot: 'arrow', vs: { ranged: 1.35, swift: 1.35 }, tags: ['human', 'ranged'] },
  ballista: { hp: 220, atk: 50, armor: 22, range: 13.0, rate: 3.0, speed: 0.0, shot: 'bolt', pierce: true, vs: { armored: 1.6, giant: 1.5 }, tags: ['machine', 'armored'] },
  catapult: { hp: 240, atk: 40, armor: 22, range: 14.0, min_range: 2.5, rate: 4.0, speed: 0.0, shot: 'stone', splash: 1.6, vs: { swarm: 1.4, human: 1.15 }, tags: ['machine'] },
};

// свой герой (Д11) — как Legion.HERO, Legion.HERO_CITY, Hero.KIT_ATK, Hero.KIT_ARMOR; уровень города и Склада оружия
// в снимке — не выше CITY_MAX, KIT_MAX (Legion.HERO_CITY_MAX, HERO_KIT_MAX)
const HERO = { hp: 285, atk: 23, armor: 34, range: 1.0, rate: 1.0, speed: 1.7, vs: { human: 1.3 }, tags: ['human'] };
const HERO_CITY = 0.03, KIT_ATK = 0.02, KIT_ARMOR = 3.0, CITY_MAX = 7, KIT_MAX = 10;

const f32 = Math.fround;
// Vector2(x, y).length() движка: компоненты во float32, x*x + y*y и корень — тоже
function vlen(x, y) {
  const fx = f32(x), fy = f32(y);
  return f32(Math.sqrt(f32(f32(fx * fx) + f32(fy * fy))));
}
const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
const roundi = x => (x < 0 ? -Math.round(-x) : Math.round(x));      // Math::round — половина от нуля
const sign = x => (x > 0 ? 1.0 : x < 0 ? -1.0 : 0.0);

/* ---------- RandomNumberGenerator (PCG32) ---------- */

const M64 = (1n << 64n) - 1n;
const MULT = 6364136223846793005n;
const INC_DEFAULT = 1442695040888963407n;        // PCG_DEFAULT_INC_64
class Rng {
  constructor(seed) {
    // pcg32_srandom_r(state, seed, inc)
    this.inc = ((INC_DEFAULT << 1n) | 1n) & M64;
    this.state = 0n;
    this.next();
    this.state = (this.state + (BigInt.asUintN(64, BigInt(seed)))) & M64;
    this.next();
  }
  next() {
    const old = this.state;
    this.state = (old * MULT + this.inc) & M64;
    const xs = Number(((old >> 18n) ^ old) >> 27n & 0xffffffffn) >>> 0;
    const rot = Number(old >> 59n);
    return ((xs >>> rot) | (xs << ((-rot) & 31))) >>> 0;
  }
  randf() {
    const e = this.next();
    if (e === 0) return 0;
    const sig = (this.next() | 0x80000001) >>> 0;
    return f32(sig) * Math.pow(2, -32 - Math.clz32(e));
  }
}

/* ---------- бойцы ---------- */

// Legion.unit_stats
function unitStats(type, lvl, atkB = 0, hpB = 0) {
  const U = UNITS[type];
  const hpK = 1.0 + 0.19 * (lvl - 1) + hpB;
  const atkK = 1.0 + 0.22 * (lvl - 1) + atkB;
  return { key: type, level: lvl, hp: roundi(U.hp * hpK), atk: roundi(U.atk * atkK), armor: U.armor + 6.0 * (lvl - 1),
    range: U.range, min_range: U.min_range || 0.0, rate: U.rate, speed: U.speed, shot: U.shot || '', pierce: !!U.pierce,
    splash: U.splash || 0.0, vs: U.vs, tags: U.tags, size: 1.0, boss: false };
}

// Legion.hero_unit_stats в бою с городом (Legion.snap_hero): уровень — Казармы, город прибавляет HERO_CITY урона
// и здоровья за уровень после «Хутора», Склад оружия — снаряжение (KIT_ATK урона, KIT_ARMOR брони за уровень);
// общей брони Склада нет (armor_b = 0, как в снимках отряда)
function heroStats(lvl, cityLvl, kit, atkB = 0, hpB = 0) {
  const ck = HERO_CITY * Math.max(0, cityLvl - 1);
  const hpK = 1.0 + 0.19 * (lvl - 1) + hpB + ck;
  const atkK = 1.0 + 0.22 * (lvl - 1) + atkB + ck + KIT_ATK * kit;
  return { key: 'hero', level: lvl, hp: roundi(HERO.hp * hpK), atk: roundi(HERO.atk * atkK), armor: HERO.armor + 6.0 * (lvl - 1) + 0.0 + KIT_ARMOR * kit,
    range: HERO.range, min_range: 0.0, rate: HERO.rate, speed: HERO.speed, shot: '', pierce: false, splash: 0.0, vs: HERO.vs, tags: HERO.tags,
    size: 1.0, boss: false };
}
const own = (o, k) => Object.prototype.hasOwnProperty.call(o, k);

class Unit {
  constructor() {
    Object.assign(this, { id: 0, side: 'ally', key: '', level: 0, x: 0.0, z: 0.0, hp: 0.0, max_hp: 0.0, atk: 0.0, armor: 0.0,
      range_m: 1.0, min_range: 0.0, rate: 1.0, speed: 1.0, shot: '', pierce: false, splash: 0.0, cleave: 0.0, charge: false,
      bites: 0, prefer: '', vs: {}, tags: [], boss: false, size: 1.0, alive: true, timer: 0.0, target: null, retarget: 0.0,
      testudo: 0.0, testudo_k: 0.0, horn: 0.0, horn_k: 1.0, burn: 0.0, burn_dps: 0.0, charge_cd: 4.0, home_x: 0.0, home_z: 0.0,
      has_home: false, entering: false, wave: -1 });
  }
  ranged() { return this.range_m > 3.0; }
  hpFrac() { return clamp(this.hp / Math.max(1.0, this.max_hp), 0.0, 1.0); }
}

const dist = (a, b) => vlen(a.x - b.x, (a.z - b.z) * 0.8);
const other = side => (side === 'ally' ? 'enemy' : 'ally');
const num = v => (typeof v === 'number' ? v : +v || 0);

class Sim {
  constructor(s) {
    this.setup = s;
    this.rng = new Rng(Math.trunc(num(s.seed === undefined ? 1 : s.seed)));
    this.t = 0.0;
    this.units = [];
    this.shots = [];
    this.waves = s.waves || [];
    this.wave_idx = -1;
    this.wave_delay = 0.0;
    this.result = null;
    this.total = 0;
    this.steps = 0;
    this.perks = { ally: {}, enemy: {} };
    this.auto = { ally: false, enemy: false };
    this.avg_atk = { ally: 1.0, enemy: 1.0 };
    this._uid = 1;
    this._formation = !!s.enemy_formation;
    for (const id of Object.keys(s.perks || {})) {
      if (Math.trunc(num(s.perks[id])) > 0 && PERKS[id]) this.perks.ally[id] = { lvl: Math.trunc(num(s.perks[id])), ready: PERKS[id].cd * 0.5 };
    }
    for (const id of Object.keys(s.enemy_perks || {})) {
      if (Math.trunc(num(s.enemy_perks[id])) > 0 && PERKS[id]) this.perks.enemy[id] = { lvl: Math.trunc(num(s.enemy_perks[id])), ready: PERKS[id].cd * 0.5 };
    }
    this.auto.ally = !!s.auto;
    this.auto.enemy = !!s.enemy_auto;
    const squad = s.squad || [];
    this._placeFormation(squad, 'ally');
    this.total = this.units.length;
    this.avg_atk.ally = Sim._avg(squad);
    if (this._formation) {
      this.wave_idx = 0;
      const foes = this.waves.length ? this.waves[0] : [];
      this._placeFormation(foes, 'enemy');
      this.avg_atk.enemy = Sim._avg(foes);
    } else {
      this._nextWave();
    }
  }

  static _avg(list) {
    let a = 0.0;
    for (const s of list) a += num(s.atk);
    return a / Math.max(1.0, list.length);
  }

  _placeFormation(list, side) {
    const key = s => (num(s.range) > 3.0 ? 1 : 0) * 2 + (num(s.speed) === 0.0 ? 1 : 0);
    const order = list.slice().sort((a, b) => key(a) - key(b));      // устойчивая, как вставки Godot
    const sgn = side === 'ally' ? -1.0 : 1.0;
    for (let i = 0; i < order.length; i++) {
      const s = order[i];
      let x = num(s.speed) === 0.0 ? 7.4 : (num(s.range) > 3.0 ? 6.0 : 4.6);
      x += (i % 2) * 0.5;
      const u = this._add(side, s, sgn * x, LANES[i % LANES.length]);
      u.home_x = u.x;
      u.home_z = u.z;
      u.has_home = true;
      u.wave = side === 'ally' ? -1 : 0;
    }
  }

  _add(side, s, x, z) {
    const u = new Unit();
    u.id = this._uid++;
    u.side = side;
    u.key = String(s.key);
    u.level = Math.trunc(num(s.level));
    u.x = x;
    u.z = z;
    u.hp = num(s.hp);
    u.max_hp = u.hp;
    u.atk = num(s.atk);
    u.armor = num(s.armor);
    u.range_m = num(s.range);
    u.min_range = num(s.min_range);
    u.rate = num(s.rate);
    u.speed = num(s.speed);
    u.shot = String(s.shot || '');
    u.pierce = !!s.pierce;
    u.splash = num(s.splash);
    u.cleave = num(s.cleave);
    u.charge = !!s.charge;
    u.bites = Math.trunc(num(s.bites));
    u.prefer = String(s.prefer || '');
    u.vs = s.vs || {};
    u.tags = s.tags || [];
    u.boss = !!s.boss;
    u.size = s.size === undefined ? 1.0 : num(s.size);
    u.timer = 0.3 + this.rng.randf() * 0.6;
    this.units.push(u);
    return u;
  }

  _nextWave() {
    this.wave_idx += 1;
    if (this.wave_idx >= this.waves.length) return false;
    const wave = this.waves[this.wave_idx];
    let sum = 0.0;
    for (let i = 0; i < wave.length; i++) {
      const s = wave[i];
      sum += num(s.atk);
      const rg = num(s.range) > 3.0;
      const u = this._add('enemy', s, 12.0 + (rg ? 1.5 : 0.0) + (i % 3) * 0.7 + (s.boss ? 1.0 : 0.0), s.boss ? 0.0 : ENEMY_LANES[i % ENEMY_LANES.length]);
      u.entering = true;
      u.wave = this.wave_idx;
    }
    this.avg_atk.enemy = sum / Math.max(1.0, wave.length);
    return true;
  }

  foesOf(u) { return this.units.filter(o => o.alive && o.side !== u.side); }
  aliveOf(side) { return this.units.filter(o => o.alive && o.side === side); }

  _pickTarget(u) {
    const foes = this.foesOf(u);
    if (!foes.length) return null;
    let pool = foes;
    if (u.prefer === 'ranged') {
      const r = foes.filter(o => o.ranged());
      if (r.length) pool = r;
    }
    if (u.pierce) {
      const big = foes.filter(o => o.boss || o.tags.includes('armored') || o.tags.includes('giant'));
      if (big.length) pool = big;
    }
    if (u.splash > 0.0 && u.shot === 'stone') {
      let best = null, bn = -1;
      for (const o of foes) {
        let n = 0;
        for (const p of foes) if (dist(o, p) < u.splash) n++;
        if (n > bn) { bn = n; best = o; }
      }
      return best;
    }
    let best2 = null, bd = Infinity;
    for (const o of pool) {
      const d = dist(u, o);
      if (d < bd) { bd = d; best2 = o; }
    }
    return best2;
  }

  static _mult(vs, tg) {
    let m = 1.0;
    for (const tag of tg.tags) if (Object.prototype.hasOwnProperty.call(vs, tag)) m = Math.max(m, num(vs[tag]));
    return m;
  }

  _damage(atk, vs, from, tg, k = 1.0) {
    if (!tg.alive) return;
    const crit = this.rng.randf() < 0.08;
    let d = atk * Sim._mult(vs, tg) * (0.9 + this.rng.randf() * 0.2) * k * (crit ? 1.6 : 1.0);
    d *= 1.0 - tg.armor / (tg.armor + 100.0);
    if (tg.testudo > this.t) d *= 1.0 - tg.testudo_k;
    const dmg = Math.max(1, roundi(d));
    tg.hp -= dmg;
    if (tg.hp <= 0.0) this._kill(tg);
  }

  _kill(tg) {
    if (!tg.alive) return;
    tg.alive = false;
    tg.hp = 0.0;
    tg.target = null;
  }

  _attack(u, tg) {
    if (u.shot !== '') {
      const d = Math.abs(tg.x - u.x);
      const speed = u.shot === 'stone' || u.shot === 'boulder' ? 9.0 : (u.shot === 'bolt' ? 24.0 : 16.0);
      this.shots.push({ kind: u.shot, from: u, target: tg, x0: u.x, z0: u.z, x1: tg.x, z1: tg.z, t: 0.0,
        dur: Math.max(0.25, d / speed), side: u.side, done: false });
      return;
    }
    if (u.bites > 0) {
      const near = this.foesOf(u);
      near.sort((a, b) => { const da = dist(u, a), db = dist(u, b); return da < db ? -1 : db < da ? 1 : 0; });
      for (let i = 0; i < Math.min(u.bites, near.length); i++) {
        if (dist(u, near[i]) < u.range_m + 1.2) this._damage(u.atk, u.vs, u, near[i], 0.75);
      }
      return;
    }
    if (u.cleave > 0.0) {
      for (const o of this.foesOf(u)) {
        if (o === tg || dist(o, tg) < u.cleave) this._damage(u.atk, u.vs, u, o, o === tg ? 1.0 : 0.6);
      }
      return;
    }
    this._damage(u.atk, u.vs, u, tg);
  }

  _land(s) {
    const u = s.from;
    if (s.kind === 'bolt') {
      const hit = this.units.filter(o => o.alive && o.side !== s.side && Math.abs(o.z - s.z1) < 0.7 && (s.side === 'ally' ? o.x >= s.x0 : o.x <= s.x0));
      hit.sort((a, b) => { const da = Math.abs(a.x - s.x0), db = Math.abs(b.x - s.x0); return da < db ? -1 : db < da ? 1 : 0; });
      let k = 1.0;
      for (let i = 0; i < Math.min(4, hit.length); i++) {
        this._damage(u.atk, u.vs, u, hit[i], k);
        k *= 0.7;
      }
      return;
    }
    if (s.kind === 'stone' || s.kind === 'boulder') {
      const r = u.splash > 0.0 ? u.splash : 1.4;
      for (const o of this.units) {
        if (o.alive && o.side !== s.side && vlen(o.x - s.x1, o.z - s.z1) < r) this._damage(u.atk, u.vs, u, o, o === s.target ? 1.0 : 0.7);
      }
      return;
    }
    if (s.target.alive) this._damage(u.atk, u.vs, u, s.target);
  }

  usePerk(id, side = 'ally') {
    const p = this.perks[side][id];
    if (!p || p.ready > 0.0 || this.result) return false;
    const foes = this.aliveOf(other(side));
    const allies = this.aliveOf(side);
    const lvl = p.lvl;
    const a = this.avg_atk[side];
    switch (id) {
      case 'oil': {
        if (!foes.length) return false;
        let c = foes[0], bn = -1;
        for (const o of foes) {
          let n = 0;
          for (const q of foes) if (vlen(q.x - o.x, q.z - o.z) < 2.0) n++;
          if (n > bn) { bn = n; c = o; }
        }
        const cx = c.x, cz = c.z;
        for (const o of foes) {
          if (vlen(o.x - cx, o.z - cz) < 2.2) {
            this._damage(a * PERK_K.oil[0] * (1.0 + PERK_K.oil[1] * (lvl - 1)), {}, null, o);
            o.burn = this.t + 4.0;
            o.burn_dps = a * PERK_K.burn[0] * (1.0 + PERK_K.burn[1] * (lvl - 1));
          }
        }
        break;
      }
      case 'volley':
        if (!foes.length) return false;
        for (const o of foes) this._damage(a * PERK_K.volley[0] * (1.0 + PERK_K.volley[1] * (lvl - 1)), {}, null, o);
        break;
      case 'testudo':
        for (const u of allies) {
          u.testudo = this.t + 5.0 + lvl;
          u.testudo_k = PERK_K.testudo[0] + PERK_K.testudo[1] * (lvl - 1);
        }
        break;
      case 'bandage':
        for (const u of allies) {
          const h = roundi(u.max_hp * (PERK_K.bandage[0] + PERK_K.bandage[1] * (lvl - 1)));
          u.hp = Math.min(u.max_hp, u.hp + h);
        }
        break;
      case 'horn':
        for (const u of allies) {
          u.horn = this.t + 8.0;
          u.horn_k = PERK_K.horn[0] + PERK_K.horn[1] * (lvl - 1);
        }
        break;
      default:
        return false;
    }
    p.ready = PERKS[id].cd;
    return true;
  }

  _autoPerks(side) {
    const ps = this.perks[side];
    if (!Object.keys(ps).length) return;
    const foes = this.aliveOf(other(side));
    const allies = this.aliveOf(side);
    if (!foes.length || !allies.length) return;
    let boss = false;
    for (const o of foes) if (o.boss) boss = true;
    let engaged = false, low = 1.0, avg = 0.0;
    for (const u of allies) {
      low = Math.min(low, u.hpFrac());
      avg += u.hpFrac();
      if (u.target !== null && u.target.alive && dist(u, u.target) <= u.range_m + 0.6) engaged = true;
    }
    avg /= allies.length;
    if (ps.bandage && ps.bandage.ready <= 0.0 && (avg < 0.6 || low < 0.35)) this.usePerk('bandage', side);
    if (ps.testudo && ps.testudo.ready <= 0.0 && engaged && (boss || low < 0.55 || foes.length >= 4)) this.usePerk('testudo', side);
    if (ps.horn && ps.horn.ready <= 0.0 && engaged) this.usePerk('horn', side);
    if (ps.volley && ps.volley.ready <= 0.0 && (foes.length >= 3 || boss)) this.usePerk('volley', side);
    if (ps.oil && ps.oil.ready <= 0.0) {
      let bn = 0;
      for (const o of foes) {
        let n = 0;
        for (const q of foes) if (vlen(q.x - o.x, q.z - o.z) < 2.0) n++;
        bn = Math.max(bn, n);
      }
      if (bn >= 3 || boss || foes.length === 1) this.usePerk('oil', side);
    }
  }

  step(dt = DT) {
    if (this.result) return;
    this.t += dt;
    this.steps += 1;
    for (const side of ['ally', 'enemy']) {
      for (const id of Object.keys(this.perks[side])) {
        const p = this.perks[side][id];
        p.ready = Math.max(0.0, p.ready - dt);
      }
    }
    for (const side of ['ally', 'enemy']) if (this.auto[side]) this._autoPerks(side);

    for (const u of this.units) {
      if (!u.alive) continue;
      if (u.burn > this.t) {
        u.hp -= u.burn_dps * dt;
        if (u.hp <= 0.0) { this._kill(u); continue; }
      }
      if (u.entering) {
        u.x -= u.speed * 1.4 * dt;
        if (u.x < 3.5 + (u.ranged() ? 1.8 : 0.0)) u.entering = false;
        continue;
      }
      u.retarget -= dt;
      if (u.target === null || !u.target.alive || u.retarget <= 0.0) {
        u.target = this._pickTarget(u);
        u.retarget = 0.6;
      }
      const tg = u.target;
      if (tg === null) {
        if (u.has_home && u.speed > 0.0 && Math.abs(u.x - u.home_x) > 0.15) {
          u.x += sign(u.home_x - u.x) * Math.min(u.speed * 1.3 * dt, Math.abs(u.home_x - u.x));
          u.z += (u.home_z - u.z) * dt * 2.0;
        }
        continue;
      }
      const fast = u.horn > this.t ? u.horn_k : 1.0;
      const reach = u.range_m + 0.35 * (u.size + tg.size - 2.0);
      const d = dist(u, tg);
      if (d > reach && u.speed > 0.0) {
        let dir = sign(tg.x - u.x);
        if (dir === 0.0) dir = 1.0;
        u.x += dir * Math.min(u.speed * fast * dt, d - reach + 0.01);
        u.z += clamp(tg.z - u.z, -1.0, 1.0) * dt * 0.8;
        if (u.charge && d < 4.0 && u.charge_cd <= 0.0) {
          u.charge_cd = 7.0;
          this._damage(u.atk, u.vs, u, tg, 1.8);
          tg.x += sign(tg.x - u.x) * 1.2;
        }
      } else {
        if (u.min_range > 0.0 && d < u.min_range) u.timer = Math.max(u.timer, 0.2);
        u.timer -= dt * fast;
        if (u.timer <= 0.0 && d <= reach + 0.05) {
          this._attack(u, tg);
          u.timer = u.rate * (0.92 + this.rng.randf() * 0.16);
        }
      }
      u.charge_cd -= dt;
    }

    for (const a of this.units) {
      if (!a.alive) continue;
      for (const b of this.units) {
        if (b === a || !b.alive || b.side !== a.side) continue;
        const dx = a.x - b.x, dz = a.z - b.z;
        const mn = 0.7 * (a.size + b.size) / 2.0;
        if (Math.abs(dx) < mn && Math.abs(dz) < mn) a.z += (dz >= 0.0 ? 1.0 : -1.0) * dt * 1.2;
      }
      a.z = clamp(a.z, -FIELD_Z, FIELD_Z);
      a.x = clamp(a.x, FIELD_X0, FIELD_X1);
    }

    for (const s of this.shots) {
      s.t += dt;
      if (s.target.alive) { s.x1 = s.target.x; s.z1 = s.target.z; }
      if (s.t >= s.dur) { s.done = true; this._land(s); }
    }
    this.shots = this.shots.filter(s => !s.done);

    const allies = this.aliveOf('ally').length;
    const foes = this.aliveOf('enemy').length;
    if (allies === 0) { this._end(false, 0); return; }
    if (foes === 0 && !this.shots.length) {
      if (!this._formation && this.wave_idx + 1 < this.waves.length) {
        this.wave_delay += dt;
        if (this.wave_delay > WAVE_DELAY) { this.wave_delay = 0.0; this._nextWave(); }
      } else {
        this._end(true, allies);
        return;
      }
    }
    if (this.t > TIME_LIMIT) this._end(false, allies, true);
  }

  _end(win, alive, timeout = false) {
    let hp = 0.0, mx = 0.0;
    for (const u of this.units) {
      if (u.side === 'ally') {
        mx += u.max_hp;
        if (u.alive) hp += u.hp;
      }
    }
    this.result = { win, alive, total: this.total, timeout, time: this.t, hp_left: hp / Math.max(1.0, mx), steps: this.steps };
  }

  /* Досчитать бой, применяя нажатия игрока: [шаг, умение] — умение нажато, когда сделано столько шагов;
     [шаг, "auto", вкл] — «Авто» включили/выключили. Нажатия идут по порядку записи. */
  run(inputs = []) {
    let i = 0;
    const MAX_STEPS = Math.ceil(TIME_LIMIT / DT) + 10;
    while (!this.result && this.steps <= MAX_STEPS) {
      while (i < inputs.length && inputs[i][0] <= this.steps) {
        const e = inputs[i++];
        if (e[1] === 'auto') this.auto.ally = !!e[2];
        else this.usePerk(e[1], 'ally');
      }
      this.step(DT);
    }
    return this.result;
  }
}

// Нажатия от клиента → проверенный список (или null, если записан не по порядку / неверно)
function cleanInputs(list) {
  if (list === undefined || list === null) return [];
  if (!Array.isArray(list) || list.length > 2000) return null;
  const out = [];
  let last = 0;
  for (const e of list) {
    if (!Array.isArray(e) || e.length < 2) return null;
    const st = e[0];
    if (!Number.isInteger(st) || st < 0 || st < last || st > 6000) return null;
    last = st;
    if (e[1] === 'auto') out.push([st, 'auto', !!e[2]]);
    else if (typeof e[1] === 'string' && PERKS[e[1]]) out.push([st, e[1]]);
    else return null;
  }
  return out;
}

// Бойцы снимка отряда — как Legion.snapshot_stats: герой — только на первом месте (на других не в счёт)
function snapStats(snap) {
  const ab = clamp(num(snap.atk_b), 0.0, 0.6), hb = clamp(num(snap.hp_b), 0.0, 0.6);
  const out = [];
  (Array.isArray(snap.squad) ? snap.squad : []).forEach((e, i) => {
    if (!e || typeof e !== 'object' || Array.isArray(e)) return;
    if (e.type === 'hero') {
      if (i === 0) out.push(heroStats(clamp(Math.trunc(num(e.level)) || 1, 1, MAX_LEVEL), clamp(Math.trunc(num(e.city)), 0, CITY_MAX), clamp(Math.trunc(num(e.kit)), 0, KIT_MAX), ab, hb));
    } else if (typeof e.type === 'string' && own(UNITS, e.type)) {
      out.push(unitStats(e.type, clamp(Math.trunc(num(e.level)) || 1, 1, MAX_LEVEL), ab, hb));
    }
  });
  return out;
}

// Настройка боя с городом — как Legion.make_pvp_battle: наш отряд и умения — из проверенного снимка нападения
// (его же сервер отдал клиенту, и клиент воюет ровно им), соперник — из снимка обороны
function pvpSetup(att, def, seed) {
  const stats = snapStats;
  const perks = p => {
    const o = {};
    for (const id of Object.keys(p && typeof p === 'object' ? p : {})) if (PERKS[id]) o[id] = clamp(Math.trunc(num(p[id])), 0, PERK_MAX);
    return o;
  };
  return { squad: stats(att), waves: [stats(def)], perks: perks(att.perks), enemy_perks: perks(def.perks), enemy_auto: true,
    enemy_formation: true, seed };
}

function replayPvp(att, def, seed, inputs) {
  const sim = new Sim(pvpSetup(att, def, seed));
  return sim.run(inputs);
}

module.exports = { Sim, Rng, unitStats, heroStats, snapStats, vlen, cleanInputs, pvpSetup, replayPvp, DT, TIME_LIMIT, CITY_MAX, KIT_MAX };
