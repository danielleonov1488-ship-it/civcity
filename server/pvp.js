'use strict';
/* Бои с городами (асинхронно) для новой игры (Легион, вкладка «Против городов»).

   Как устроено. Каждый игрок выставляет отряд обороны (PUT /api/pvp/defense — снимок: рода войск и уровни,
   умения, бонусы чудес). Другие игроки получают список соперников близкого рейтинга (GET /api/pvp/opponents),
   нападают (POST /api/pvp/attack — сервер тратит заряд атаки, выдаёт номер боя и отряд соперника), бой идёт
   у нападающего (LegionSim, автобой с умениями), итог приходит на POST /api/pvp/result. Сервер меняет рейтинг
   обоим, записывает отчёт для защитника (GET /api/pvp/state — «На вас напали…», POST /api/pvp/ack), ведёт
   таблицу лучших (GET /api/pvp/top). Если живых соперников мало, список добирают «вольные города» —
   отряды, которые сервер собирает сам под силу игрока (за них рейтинг вдвое меньше, отчётов нет).

   Название города — одно на всё (табличка в игре, сохранение, таблица лучших, летописи соперников) и хранится
   здесь (pvp_players.name, единственное на сервере). Сначала у каждого имя от сервера («Колония Юлия»), игрок
   меняет его через PUT /api/pvp/name — и без Легиона. Правила (длина, знаки, грубые слова) — server/names.js.

   Добыча лёгкая и ни у кого не отнимается: нападающий за победу получает денарии и немного Славы (считает
   сервер), защитник за отбитый натиск — 1 Славу (отнимать Славу у проигравшей обороны можно включить: DEF_LOOT).
   Рейтинг не уходит ниже нуля.

   Защита от подделок:
   - победу сервер ПОВТОРЯЕТ сам (server/legion_sim.js — точная копия LegionSim игры): то же зерно, отряд нападения
     в том виде, в каком его проверил сервер (его же получает клиент в ответе /attack и воюет ровно им), отряд
     обороны и нажатия умений игрока ([шаг, умение], [шаг, "auto", вкл] — поле inputs итога). Засчитывается итог
     повтора (живые, время), а не слова клиента; повтор проиграл — победа не засчитана (rejected);
   - номер боя одноразовый и живёт BATTLE_TTL; брошенный бой (игру закрыли, бой не доложили) — поражение;
   - рейтинг меняется только по таблице (ставки считаются при нападении), добыча — по формуле сервера;
   - заряды атак (5, один копится полчаса) и лимиты запросов — на сервере; на один город — не чаще раза в 6 часов,
     город, только что проигравший оборону, полчаса под защитой;
   - отряды (оборона и нападение) сверяются с последним сохранением города в облаке: уровни не выше, чем там
     (с учётом идущего улучшения), мест не больше открытых (+1 на запаздывание облака), умения и бонусы чудес —
     не выше; силу отряда сервер считает сам (та же формула, что Legion.power в godot/scripts/legion.gd);
   - победа отряда, который слабее соперника больше чем вчетверо (MIN_RATIO), или бой, закончившийся быстрее,
     чем его можно досмотреть на скорости ×3 (по времени повтора), не засчитываются (status rejected, рейтинг не меняется);
   - рейтинг, который живой защитник теряет за сутки, ограничен (DEF_DAY_LOSS): толпой учёток одного не утопить.
   Свой герой (Д11) — первое место отряда (нападения и обороны): {type: "hero", level, city, kit}. Сервер берёт его только
   на первом месте и только если герой есть в сохранении города в облаке (d.hero), уровень — не выше Казарм (с идущим
   улучшением), город — не выше уровня города, kit — не выше Склада оружия (если он построен); имя и облик героя (для 3D-боя
   у соперника) сервер кладёт в снимок сам, из сохранения. Числа бойца — heroStats (legion_sim.js, как Legion.snap_hero).
   Старая игра героя не знает: она не шлёт hero=1 (список соперников) и hero: true (нападение) — её соперники идут без героя,
   и бой повторяется ровно так, как его видела она. Новая игра узнаёт, что сервер знает героя, по me.hero (state).
   Числа бойцов и правила рейтинга — копия legion.gd (UNITS, PVP, WONDERS, SLOT_BOSSES, SLOT_BARRACKS): меняете там — меняйте тут. */

const crypto = require('crypto');
const { replayPvp, cleanInputs, heroStats, CITY_MAX, KIT_MAX } = require('./legion_sim');
const names = require('./names');

const UNITS = {
  legionary: { hp: 270, atk: 22, armor: 32, range: 1.0, rate: 1.0 },
  spearman: { hp: 330, atk: 19, armor: 48, range: 1.7, rate: 1.3 },
  archer: { hp: 150, atk: 19, armor: 10, range: 7.5, rate: 1.15 },
  ballista: { hp: 220, atk: 50, armor: 22, range: 13.0, rate: 3.0, pierce: true },
  catapult: { hp: 240, atk: 40, armor: 22, range: 14.0, rate: 4.0, splash: 1.6 },
};
const UNIT_IDS = Object.keys(UNITS);
const BUILDING_UNIT = { barracks: 'legionary', spearcamp: 'spearman', range: 'archer', ballistae: 'ballista', catapults: 'catapult' };
const PERK_IDS = ['oil', 'testudo', 'bandage', 'volley', 'horn'];
const PERK_MAX = 5, MAX_LEVEL = 40, SQUAD_BASE = 3, SQUAD_MAX = 7, STAGES = 10;
const SLOT_BOSSES = [1, 3, 5, 7];
// каждое новое место — ещё и с Казармами этого уровня (здания Легиона, сохранение Легиона v3); места, открытые
// до зданий (flags.slots0 — перенос старого сохранения), не отнимаются
const SLOT_BARRACKS = [2, 3, 5, 7];
// чудеса, что усиливают армию: памятники в городе (building) и чудеса, возведённые в окне Легиона (id)
const ARMY_WONDERS = [
  { building: 'arch', atk: 0.05 }, { building: 'colosseum', hp: 0.10 }, { building: 'pantheon', atk: 0.10 },
  { id: 'trajan', atk: 0.15, hp: 0.15 }, { id: 'jupiter', atk: 0.05, hp: 0.05 },
];
const PVP = { charges: 5, regen: 1800e3, win_base: 20, win_min: 8, win_max: 40, loss_base: 10, loss_min: 3, loss_max: 20,
  loot_money: 2.0, loot_base: 150, glory: 2 };
// бои с городами — с «Посёлка» (как в игре: Legion.PVP_MIN_LEVEL): Легион теперь с «Хутора», а добыча рассчитана на казну «Посёлка»
const PVP_MIN_LEVEL = 3;

const BATTLE_TTL = +process.env.PVP_TTL_MS || 30 * 60e3;   // за сколько надо доложить бой
const BATTLE_BUSY = Math.min(BATTLE_TTL, 5 * 60e3);         // самый долгий бой (181 с на ×1) с запасом на доклад
const ATTACK_GAP = 6 * 3600e3;                              // на один и тот же город — не чаще
const SHIELD = 30 * 60e3;                                   // защита города после проигранной обороны
const OFFER_TTL = 30 * 60e3;                                // сколько живёт выданный список соперников
const STALE = 30 * 864e5;                                   // отряды, не обновлявшиеся месяц, в список не попадают
const MIN_RATIO = 0.25;   // победа отряда слабее соперника больше чем вчетверо — подделка (проверки: худшая честная ≈0,33)
const MAX_SPEED = 3;      // бой смотрят на скорости ×1…×3
const LIST_REAL = 6;      // живых соперников в списке
const LIST_MIN = 4;       // если подходящих по силе меньше — добираем вольными городами
const FAIR = 1.6;         // «подходящий» соперник — не сильнее нашей силы в столько раз
const DEF_GLORY = 1;      // Славы защитнику за отбитый натиск
const DEF_LOOT = 0;       // сколько Славы теряет проигравший оборону (0 — ни у кого ничего не отнимают; клиент понимает и минус)
const DEF_DAY_LOSS = 40;  // больше этого рейтинга за сутки защитник от нападений не теряет

const BOT_NAMES = ['Капуя', 'Тарент', 'Неаполь', 'Помпеи', 'Остия', 'Кумы', 'Брундизий', 'Анций', 'Вейи', 'Тибур', 'Пренесте',
  'Сиракузы', 'Массилия', 'Аквилея', 'Равенна', 'Медиолан', 'Верона', 'Генуя', 'Аримин', 'Анкона', 'Регий', 'Пестум', 'Сполеций',
  'Арреций', 'Пиза', 'Кремона', 'Плацентия', 'Мутина', 'Бононья', 'Луцерия', 'Беневент', 'Сатрик', 'Ардея', 'Лавиний', 'Альба Фуценская'];
// имя города по умолчанию (пока игрок не назвал город сам): «Колония Юлия», «Форум Клавдия»…
const NAME_A = ['Колония', 'Форум', 'Кастра', 'Муниципий'];
const NAME_B = ['Юлия', 'Клавдия', 'Флавия', 'Аврелия', 'Ульпия', 'Элия', 'Августа', 'Валерия', 'Корнелия', 'Фабия', 'Помпея',
  'Антония', 'Сервилия', 'Туллия', 'Лициния', 'Эмилия', 'Сульпиция', 'Домиция', 'Марция', 'Кассия'];
const NAME_RE = /^[\p{L}\p{N} '’\-«»".]+$/u;
const RESERVED_RE = /^город \d+(-\d+)?$/;     // «Город 123» — запасные имена сервера (по nameKey), игрокам не даём

const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const int = v => (Number.isFinite(+v) ? Math.trunc(+v) : 0);
const num = v => (Number.isFinite(+v) ? +v : 0);
const roundi = x => Math.sign(x) * Math.round(Math.abs(x));      // как roundi в Godot: половина — от нуля
const tdiv = (a, b) => Math.trunc(a / b);                        // целое деление Godot (к нулю)
const nameKey = s => String(s).toLowerCase().replace(/ё/g, 'е').replace(/\s+/g, ' ').trim();
const ROMAN = ['', 'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X'];

/* ---------- боевые числа (как в legion.gd) ---------- */

function unitStats(type, lvl, atkB, hpB) {
  const U = UNITS[type];
  const hpK = 1 + 0.19 * (lvl - 1) + hpB;
  const atkK = 1 + 0.22 * (lvl - 1) + atkB;
  return { hp: roundi(U.hp * hpK), atk: roundi(U.atk * atkK), armor: U.armor + 6 * (lvl - 1), range: U.range, rate: U.rate,
    splash: U.splash || 0, pierce: !!U.pierce };
}
function power(s) {
  const ehp = s.hp / (1 - s.armor / (s.armor + 100));
  const mult = (s.splash > 0 ? 1.5 : 1) * (s.pierce ? 1.3 : 1) * (s.range > 3 ? 1.15 : 1);
  return roundi(Math.sqrt(ehp * s.atk / s.rate * mult) * 1.6);
}
// герой снимка — только на первом месте (как Legion.snapshot_stats и legion_sim.js snapStats)
function heroOf(snap, e, i) {
  return i === 0 && e && e.type === 'hero' ? heroStats(clamp(int(e.level) || 1, 1, MAX_LEVEL), clamp(int(e.city), 0, CITY_MAX), clamp(int(e.kit), 0, KIT_MAX),
    snap.atk_b || 0, snap.hp_b || 0) : null;
}
function snapPower(snap) {
  let p = 0;
  (snap.squad || []).forEach((e, i) => {
    const h = heroOf(snap, e, i);
    if (h) p += power(h);
    else if (e && Object.prototype.hasOwnProperty.call(UNITS, e.type)) p += power(unitStats(e.type, e.level, snap.atk_b || 0, snap.hp_b || 0));
  });
  return p;
}
// снимок без героя — для старых игр (они героя не знают и воюют без него: бой повторяется так же)
function noHero(snap) {
  if (!snap || !Array.isArray(snap.squad) || !snap.squad.some(e => e && e.type === 'hero')) return snap;
  return Object.assign({}, snap, { squad: snap.squad.filter(e => !(e && e.type === 'hero')) });
}

/* ---------- свой герой из сохранения ---------- */

const HEX6 = /^[0-9a-fA-F]{6}$/;
const HERO_NAME_RE = /^[\p{L} '’\-.]+$/u;
// имя героя для соперников: те же правила, что Hero.check_name (буквы, 2–24 знака, без грубых слов); не подходит — без имени
function heroName(v) {
  const t = String(typeof v === 'string' ? v : '').replace(/[\u0000-\u001f\u007f]/g, '').replace(/\s+/g, ' ').trim();
  if (t.length < 2 || t.length > 24 || !HERO_NAME_RE.test(t) || names.rude(t)) return '';
  return t;
}
// облик героя для 3D-боя у соперника: только известные поля и значения (игра ещё и сама приводит его к правилам: Hero.fix_look)
function heroLook(m) {
  const lk = m.look && typeof m.look === 'object' && !Array.isArray(m.look) ? m.look : {};
  const o = { sx: int(m.sx) === 1 ? 1 : 0 };
  if (typeof lk.mdl === 'string' && /^SK_Chr_[A-Za-z0-9_]{1,40}$/.test(lk.mdl)) o.mdl = lk.mdl;
  for (const k of ['skin', 'hc']) if (typeof lk[k] === 'string' && /^[ABCS]$/.test(lk[k])) o[k] = lk[k];
  for (const [k, mx] of [['hair', 7], ['beard', 4], ['crown', 2]]) o[k] = clamp(int(lk[k]), 0, mx);
  for (const k of ['main', 'second', 'trim', 'cape']) if (typeof lk[k] === 'string' && HEX6.test(lk[k])) o[k] = lk[k].toLowerCase();
  return o;
}
function delta(win, me, opp) {
  if (win) return clamp(PVP.win_base + tdiv(opp - me, 25), PVP.win_min, PVP.win_max);
  return -clamp(PVP.loss_base + tdiv(me - opp, 50), PVP.loss_min, PVP.loss_max);
}

function install({ db, routes, auth, json, limited, Fail, latestSave }) {
  db.exec(`
    CREATE TABLE IF NOT EXISTS pvp_players (
      user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
      name TEXT NOT NULL,
      name_key TEXT NOT NULL UNIQUE,
      custom INTEGER NOT NULL DEFAULT 0,
      city_level INTEGER NOT NULL DEFAULT 0,
      rating INTEGER NOT NULL DEFAULT 0,
      wins INTEGER NOT NULL DEFAULT 0,
      losses INTEGER NOT NULL DEFAULT 0,
      def_wins INTEGER NOT NULL DEFAULT 0,
      def_losses INTEGER NOT NULL DEFAULT 0,
      snapshot TEXT,
      power INTEGER NOT NULL DEFAULT 0,
      published INTEGER NOT NULL DEFAULT 0,
      charges INTEGER NOT NULL DEFAULT ${PVP.charges},
      charge_t INTEGER NOT NULL DEFAULT 0,
      shield_until INTEGER NOT NULL DEFAULT 0,
      created INTEGER NOT NULL
    );
    CREATE INDEX IF NOT EXISTS pvp_players_rating ON pvp_players(rating);
    CREATE TABLE IF NOT EXISTS pvp_battles (
      n INTEGER PRIMARY KEY,
      token TEXT NOT NULL UNIQUE,
      attacker INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      defender INTEGER REFERENCES users(id) ON DELETE SET NULL,
      bot INTEGER NOT NULL DEFAULT 0,
      att_name TEXT, def_name TEXT,
      att_rating INTEGER, def_rating INTEGER, def_level INTEGER,
      att_snap TEXT NOT NULL, def_snap TEXT NOT NULL,
      att_n INTEGER NOT NULL, att_power INTEGER NOT NULL, def_power INTEGER NOT NULL,
      seed INTEGER NOT NULL,
      s_win INTEGER NOT NULL, s_loss INTEGER NOT NULL, sd_win INTEGER NOT NULL, sd_loss INTEGER NOT NULL,
      money INTEGER NOT NULL, glory INTEGER NOT NULL,
      created INTEGER NOT NULL,
      status TEXT NOT NULL DEFAULT 'open',
      finished INTEGER,
      win INTEGER, alive INTEGER, total INTEGER, time REAL,
      d_att INTEGER, d_def INTEGER, def_glory INTEGER NOT NULL DEFAULT 0,
      note TEXT,
      seen INTEGER NOT NULL DEFAULT 0
    );
    CREATE INDEX IF NOT EXISTS pvp_battles_att ON pvp_battles(attacker, created);
    CREATE INDEX IF NOT EXISTS pvp_battles_def ON pvp_battles(defender, n);
    CREATE INDEX IF NOT EXISTS pvp_battles_open ON pvp_battles(status, created);
  `);

  const q = {
    player: db.prepare('SELECT * FROM pvp_players WHERE user_id = ?'),
    byKey: db.prepare('SELECT user_id FROM pvp_players WHERE name_key = ?'),
    addPlayer: db.prepare('INSERT OR IGNORE INTO pvp_players (user_id, name, name_key, created, charge_t) VALUES (?, ?, ?, ?, ?)'),
    setName: db.prepare('UPDATE pvp_players SET name = ?, name_key = ?, custom = 1 WHERE user_id = ?'),
    setDefense: db.prepare('UPDATE pvp_players SET snapshot = ?, power = ?, city_level = ?, published = ? WHERE user_id = ?'),
    setCharges: db.prepare('UPDATE pvp_players SET charges = ?, charge_t = ? WHERE user_id = ?'),
    attResult: db.prepare('UPDATE pvp_players SET rating = MAX(0, rating + ?), wins = wins + ?, losses = losses + ? WHERE user_id = ?'),
    defResult: db.prepare('UPDATE pvp_players SET rating = MAX(0, rating + ?), def_wins = def_wins + ?, def_losses = def_losses + ?, shield_until = MAX(shield_until, ?) WHERE user_id = ?'),
    candidates: db.prepare(`SELECT user_id, name, rating, city_level, snapshot, power FROM pvp_players
      WHERE user_id != ? AND power > 0 AND snapshot IS NOT NULL AND published > ? AND shield_until < ?
      ORDER BY ABS(rating - ?) ASC, published DESC LIMIT 60`),
    recentTargets: db.prepare('SELECT DISTINCT defender FROM pvp_battles WHERE attacker = ? AND defender IS NOT NULL AND created > ?'),
    addBattle: db.prepare(`INSERT INTO pvp_battles (token, attacker, defender, bot, att_name, def_name, att_rating, def_rating, def_level,
      att_snap, def_snap, att_n, att_power, def_power, seed, s_win, s_loss, sd_win, sd_loss, money, glory, created)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`),
    battle: db.prepare('SELECT * FROM pvp_battles WHERE token = ?'),
    openOf: db.prepare("SELECT * FROM pvp_battles WHERE attacker = ? AND status = 'open' ORDER BY n"),
    stale: db.prepare("SELECT * FROM pvp_battles WHERE status = 'open' AND created < ? LIMIT 200"),
    finish: db.prepare(`UPDATE pvp_battles SET status = ?, finished = ?, win = ?, alive = ?, total = ?, time = ?, d_att = ?, d_def = ?,
      def_glory = ?, note = ? WHERE n = ? AND status = 'open'`),
    reports: db.prepare(`SELECT n, finished, att_name, win, d_def, def_glory, status FROM pvp_battles
      WHERE defender = ? AND status IN ('done', 'expired') AND seen = 0 AND n > ? ORDER BY n ASC LIMIT 30`),
    ack: db.prepare('UPDATE pvp_battles SET seen = 1 WHERE defender = ? AND n <= ? AND seen = 0'),
    top: db.prepare(`SELECT user_id, name, rating, city_level, wins, losses, def_wins, def_losses FROM pvp_players
      WHERE power > 0 OR wins + losses > 0 ORDER BY rating DESC, wins DESC, user_id ASC LIMIT 50`),
    place: db.prepare(`SELECT COUNT(*) AS n FROM pvp_players WHERE (power > 0 OR wins + losses > 0)
      AND (rating > ? OR (rating = ? AND (wins > ? OR (wins = ? AND user_id < ?))))`),
    total: db.prepare('SELECT COUNT(*) AS n FROM pvp_players WHERE power > 0 OR wins + losses > 0'),
    defLossDay: db.prepare('SELECT COALESCE(SUM(d_def), 0) AS s FROM pvp_battles WHERE defender = ? AND finished > ? AND d_def < 0'),
  };

  function tx(fn) {
    db.exec('BEGIN IMMEDIATE');
    try { const r = fn(); db.exec('COMMIT'); return r; } catch (e) { try { db.exec('ROLLBACK'); } catch (e2) { /* */ } throw e; }
  }

  /* ---------- игрок ---------- */

  function defaultName(uid) {
    const n = NAME_A.length * NAME_B.length;
    for (let k = 0; k < 11; k++) {
      for (let j = 0; j < n; j++) {
        const i = (uid * 37 + j) % n;
        const base = `${NAME_A[i % NAME_A.length]} ${NAME_B[Math.floor(i / NAME_A.length) % NAME_B.length]}`;
        const nm = k ? `${base} ${ROMAN[k]}` : base;
        if (!q.byKey.get(nameKey(nm))) return nm;
        if (k === 0 && j > 4) break;            // занято несколько подряд — дальше с номерами
      }
    }
    // все имена заняты — «Город <номер>» (такие игрокам брать нельзя, см. RESERVED_RE), но и его проверяем
    for (let s = 0; ; s++) {
      const nm = s ? `Город ${uid}-${s}` : `Город ${uid}`;
      if (!q.byKey.get(nameKey(nm))) return nm;
    }
  }

  function player(uid) {
    let p = q.player.get(uid);
    // имя могли занять между выбором и записью (INSERT OR IGNORE тогда ничего не пишет) — выбрать другое
    for (let i = 0; !p && i < 5; i++) {
      const nm = defaultName(uid);
      q.addPlayer.run(uid, nm, nameKey(nm), Date.now(), 0);
      p = q.player.get(uid);
    }
    if (!p) throw new Fail(500, 'не удалось завести игрока для боёв: ' + uid);
    return p;
  }

  function regen(p, now) {
    if (p.charges >= PVP.charges) { p.charge_t = now; return; }
    if (p.charge_t <= 0) p.charge_t = now;
    const n = Math.floor((now - p.charge_t) / PVP.regen);
    if (n > 0) {
      p.charges = Math.min(PVP.charges, p.charges + n);
      p.charge_t += n * PVP.regen;
      if (p.charges >= PVP.charges) p.charge_t = now;
    }
  }

  function state(p) {
    const now = Date.now();
    regen(p, now);
    return {
      // rename: сервер умеет PUT /pvp/name (игра зовёт назвать город только тогда — старый сервер его не шлёт)
      // hero: сервер знает героя в отрядах (игра ставит его в бои с городами только тогда — старый сервер его не шлёт)
      name: p.name, custom: !!p.custom, rename: true, hero: true, rating: p.rating, wins: p.wins, losses: p.losses, def_wins: p.def_wins, def_losses: p.def_losses,
      charges: p.charges, max_charges: PVP.charges, next_in: p.charges >= PVP.charges ? 0 : Math.max(0, Math.ceil((p.charge_t + PVP.regen - now) / 1000)),
      regen: PVP.regen / 1000, power: p.power, published: !!p.snapshot && p.power > 0,
      shield_in: Math.max(0, Math.ceil((p.shield_until - now) / 1000)),
    };
  }

  function cleanName(s) {
    const t = String(s || '').replace(/[\u0000-\u001f\u007f]/g, '').replace(/\s+/g, ' ').trim();
    if (t.length < 3 || t.length > 24) throw new Fail(400, 'Название — от 3 до 24 знаков');
    if (!NAME_RE.test(t) || !/\p{L}/u.test(t)) throw new Fail(400, 'В названии — только буквы, цифры, пробел и дефис');
    if (names.rude(t)) throw new Fail(400, 'Такое название не подойдёт — придумайте другое');
    return t;
  }

  // новое название игрока p: проверено, не запасное «Город 123» (своё запасное оставить можно), не занято другим
  function pickName(p, raw) {
    const nm = cleanName(raw);
    if (nameKey(nm) !== nameKey(p.name) && RESERVED_RE.test(nameKey(nm))) throw new Fail(400, 'Такие названия («Город 123») даёт сам сервер — придумайте своё');
    const other = q.byKey.get(nameKey(nm));
    if (other && other.user_id !== p.user_id) throw new Fail(409, 'Такое название уже занято — придумайте другое');
    return nm;
  }

  // записать название (игрок выбрал его сам — custom); заняли в ту же секунду (UNIQUE name_key) — тоже 409
  function setName(uid, nm) {
    try {
      q.setName.run(nm, nameKey(nm), uid);
    } catch (e) {
      if (/UNIQUE|constraint/i.test(String(e && e.message))) throw new Fail(409, 'Такое название уже занято — придумайте другое');
      throw e;
    }
  }

  /* ---------- что знаем о городе из облака (последнее сохранение rome2) ---------- */

  const factsCache = new Map();      // user → {id, facts}
  function facts(uid) {
    const s = latestSave(uid);
    if (!s) return null;
    const c = factsCache.get(uid);
    if (c && c.id === s.id) return c.facts;
    let d = null;
    try { d = JSON.parse(s.load()); } catch (e) { d = null; }
    let f = null;
    if (d && typeof d === 'object' && !Array.isArray(d)) {
      const L = d.legion && typeof d.legion === 'object' ? d.legion : {};
      const lv = L.levels && typeof L.levels === 'object' ? L.levels : {};
      const up = L.upg && typeof L.upg === 'object' ? L.upg : {};
      const pk = L.perks && typeof L.perks === 'object' ? L.perks : {};
      const levels = {};
      for (const t of UNIT_IDS) {
        let l = int(lv[t]) || 1;
        if (up[t] && typeof up[t] === 'object') l = Math.max(l, int(up[t].to));
        levels[t] = clamp(l, 1, MAX_LEVEL);
      }
      const bosses = Math.floor(Math.max(0, int(L.progress)) / STAGES);
      // места в отряде — как Legion.slots(): босс и Казармы нужного уровня (уровень с идущим улучшением — с запасом,
      // как и +1 на запаздывание облака); сохранение до v3 ещё не перенесено — по-старому, только боссы
      const fl = L.flags && typeof L.flags === 'object' ? L.flags : {};
      const v3 = int(L.v) >= 3;
      let slots = SQUAD_BASE;
      SLOT_BOSSES.forEach((b, i) => { if (bosses >= b && (!v3 || levels.legionary >= SLOT_BARRACKS[i])) slots++; });
      slots = clamp(Math.max(slots, int(fl.slots0)), SQUAD_BASE, SQUAD_MAX);
      const perks = {};
      for (const p of PERK_IDS) perks[p] = clamp(int(pk[p]), 0, PERK_MAX);
      const btypes = new Set();
      for (const b of Array.isArray(d.buildings) ? d.buildings : []) if (b && typeof b.type === 'string') btypes.add(b.type);
      const types = new Set();
      for (const [b, u] of Object.entries(BUILDING_UNIT)) if (btypes.has(b)) types.add(u);
      const built = new Set(Array.isArray(L.built) ? L.built.map(String) : []);
      let atkB = 0, hpB = 0;
      for (const w of ARMY_WONDERS) {
        if (w.building ? btypes.has(w.building) : built.has(w.id)) { atkB += w.atk || 0; hpB += w.hp || 0; }
      }
      // свой герой (Д11): запись героя в сохранении (Hero.norm: {m: {pn, sx, look…}}) и Склад оружия (его снаряжение):
      // уровень Склада — только если он построен (с идущим улучшением — с запасом, как у бойцов)
      const H = d.hero && typeof d.hero === 'object' && d.hero.m && typeof d.hero.m === 'object' && !Array.isArray(d.hero.m) ? d.hero.m : null;
      const bl = L.blevels && typeof L.blevels === 'object' ? L.blevels : {};
      let armory = 0;
      if (btypes.has('armory')) {
        armory = clamp(int(bl.armory) || 1, 1, KIT_MAX);
        if (up.armory && typeof up.armory === 'object') armory = clamp(Math.max(armory, int(up.armory.to)), 1, KIT_MAX);
      }
      f = { levels, bosses, slots, perks, types, atkB, hpB,
        cityLevel: clamp(int(d.level), 0, 7), legion: Array.isArray(d.research) && d.research.includes('legion'),
        hero: H ? { name: heroName(H.pn), look: heroLook(H) } : null, armory };
    }
    factsCache.set(uid, { id: s.id, facts: f });
    if (factsCache.size > 5000) factsCache.delete(factsCache.keys().next().value);
    return f;
  }

  // Отряд от клиента → проверенный снимок: уровни, места, умения и бонусы не выше, чем в облачном сохранении
  function checkSquad(f, snap) {
    if (!snap || typeof snap !== 'object' || !Array.isArray(snap.squad)) throw new Fail(400, 'Неверный отряд');
    const squad = [];
    let clamped = false;
    for (const [i, e] of snap.squad.slice(0, SQUAD_MAX).entries()) {
      if (e && typeof e === 'object' && e.type === 'hero') {
        // герой — только первым и только если он есть в сохранении; числа — не выше, чем в облаке
        if (i !== 0 || !f || !f.hero) { clamped = true; continue; }
        const h = { type: 'hero', level: clamp(int(e.level) || 1, 1, MAX_LEVEL), city: clamp(int(e.city), 0, CITY_MAX), kit: clamp(int(e.kit), 0, KIT_MAX) };
        const lim = { level: f.levels.legionary, city: Math.min(CITY_MAX, f.cityLevel), kit: f.armory };
        for (const k of ['level', 'city', 'kit']) if (h[k] > lim[k]) { h[k] = lim[k]; clamped = true; }
        if (f.hero.name) h.name = f.hero.name;
        h.look = f.hero.look;
        squad.push(h);
        continue;
      }
      if (!e || typeof e !== 'object' || !Object.prototype.hasOwnProperty.call(UNITS, e.type)) { clamped = true; continue; }
      let lvl = clamp(int(e.level) || 1, 1, MAX_LEVEL);
      const max = f ? (f.types.has(e.type) ? f.levels[e.type] : 1) : 10;
      if (lvl > max) { lvl = max; clamped = true; }
      squad.push({ type: e.type, level: lvl });
    }
    const n = squad.length;
    const lim = f ? Math.min(SQUAD_MAX, f.slots + 1) : 4;
    if (squad.length > lim) { squad.length = lim; clamped = true; }
    const perks = {};
    const sp = snap.perks && typeof snap.perks === 'object' ? snap.perks : {};
    for (const p of PERK_IDS) {
      let v = clamp(int(sp[p]), 0, PERK_MAX);
      const max = f ? Math.min(PERK_MAX, f.perks[p] + 1) : 1;
      if (v > max) { v = max; clamped = true; }
      if (v > 0) perks[p] = v;
    }
    const cap = (v, m) => { const x = clamp(num(v), 0, 0.6); if (x > m + 1e-6) clamped = true; return Math.round(Math.min(x, m) * 1000) / 1000; };
    const out = { v: 1, squad, perks, atk_b: cap(snap.atk_b, f ? f.atkB : 0), hp_b: cap(snap.hp_b, f ? f.hpB : 0) };
    return { snap: out, power: snapPower(out), n, clamped };
  }

  // Сила, которую игрок может выставить: лучшие доступные рода войск на его уровнях по числу мест (для вольных городов)
  function potential(f, p) {
    if (!f) return Math.max(p.power, 3 * power(unitStats('legionary', 1, 0, 0)));
    const avail = [...f.types];
    if (!avail.length) avail.push('legionary');
    const pw = avail.map(t => power(unitStats(t, f.levels[t], f.atkB, f.hpB))).sort((a, b) => b - a);
    let s = 0;
    // герой — первое место (если он есть в сохранении), остальные — лучшие рода войск
    const h = f.hero ? power(heroStats(f.levels.legionary, f.cityLevel, f.armory, f.atkB, f.hpB)) : 0;
    if (h) s += h;
    for (let i = h ? 1 : 0; i < f.slots; i++) s += pw[(h ? i - 1 : i) % pw.length];
    return Math.max(p.power, Math.round(s * 0.9));
  }

  /* ---------- вольные города ---------- */

  function rng(seed) {
    let s = seed >>> 0 || 1;
    return () => { s ^= s << 13; s >>>= 0; s ^= s >>> 17; s ^= s << 5; s >>>= 0; return s / 4294967296; };
  }

  function makeBot(rnd, p, f, k, used) {
    const bosses = f ? f.bosses : 0;
    const pool = ['legionary', 'legionary', 'archer'];
    if (bosses >= 1) pool.push('spearman');
    if (bosses >= 3) pool.push('ballista');
    if (bosses >= 5) pool.push('catapult');
    const n = clamp(f ? f.slots : 3, 3, SQUAD_MAX);
    const types = Array.from({ length: n }, () => pool[Math.floor(rnd() * pool.length)]);
    const target = Math.max(120, potential(f, p) * k);
    const pw = (t, l) => power(unitStats(t, l, 0, 0));
    let best = 1, diff = Infinity;
    for (let L = 1; L <= MAX_LEVEL; L++) {
      const d = Math.abs(types.reduce((a, t) => a + pw(t, L), 0) - target);
      if (d < diff) { diff = d; best = L; }
    }
    const lv = types.map(() => best);
    let sum = types.reduce((a, t, i) => a + pw(t, lv[i]), 0);
    for (let i = 0; i < n; i++) {        // подровнять по одному бойцу на уровень вверх или вниз
      const dir = sum < target ? 1 : -1;
      const l2 = clamp(lv[i] + dir, 1, MAX_LEVEL);
      const s2 = sum - pw(types[i], lv[i]) + pw(types[i], l2);
      if (Math.abs(s2 - target) < Math.abs(sum - target)) { sum = s2; lv[i] = l2; }
    }
    const perks = {};
    for (const pk of PERK_IDS) { const v = Math.max(0, (f ? f.perks[pk] : 0) - 1); if (v > 0) perks[pk] = v; }
    let name;
    for (let i = 0; i < 50; i++) { name = BOT_NAMES[Math.floor(rnd() * BOT_NAMES.length)]; if (!used.has(name)) break; }
    used.add(name);
    const snap = { v: 1, squad: types.map((t, i) => ({ type: t, level: lv[i] })), perks, atk_b: 0, hp_b: 0 };
    return { kind: 'bot', name, rating: Math.max(0, p.rating + Math.round((rnd() - 0.5) * 60)), city_level: f ? f.cityLevel : p.city_level,
      snap, power: snapPower(snap) };
  }

  /* ---------- бои ---------- */

  const offers = new Map();          // user → {t, items: Map(id → соперник)}
  setInterval(() => { const now = Date.now(); for (const [k, o] of offers) if (now - o.t > OFFER_TTL) offers.delete(k); }, 600e3).unref();

  // Закрыть бой: рейтинг обоим, победы, защита проигравшему обороняющемуся, отчёт защитнику
  function finalize(b, res) {
    const now = Date.now();
    const status = res.status || 'done';
    const win = status === 'done' && !!res.win;
    let dAtt = 0, dDef = 0, defGlory = 0;
    if (status !== 'rejected') {
      dAtt = win ? b.s_win : b.s_loss;
      if (!b.bot) { dDef = win ? b.sd_win : b.sd_loss; defGlory = win ? -DEF_LOOT : DEF_GLORY; }
    }
    if (dDef < 0 && b.defender) {
      // за сутки защитник теряет не больше DEF_DAY_LOSS рейтинга, сколько бы на него ни нападали
      const lost = -Number(q.defLossDay.get(b.defender, now - 864e5).s || 0);
      dDef = Math.min(0, Math.max(dDef, lost - DEF_DAY_LOSS));
    }
    return tx(() => {
      const r = q.finish.run(status, now, win ? 1 : 0, res.alive ?? null, res.total ?? null, res.time ?? null, dAtt, dDef, defGlory, res.note || null, b.n);
      if (!Number(r.changes)) return false;              // бой уже закрыли
      if (status !== 'rejected') {
        q.attResult.run(dAtt, win ? 1 : 0, win ? 0 : 1, b.attacker);
        if (!b.bot && b.defender) q.defResult.run(dDef, win ? 0 : 1, win ? 1 : 0, win ? now + SHIELD : 0, b.defender);
      }
      return true;
    });
  }

  // Брошенные бои (не доложены вовремя) — поражение нападающего
  function expire(uid) {
    const old = Date.now() - BATTLE_TTL;
    const rows = uid ? q.openOf.all(uid).filter(b => b.created < old) : q.stale.all(old);
    for (const b of rows) finalize(b, { status: 'expired', win: false, note: 'не доложен вовремя' });
  }
  setInterval(() => { try { expire(0); } catch (e) { console.error('pvp expire:', e); } }, 300e3).unref();

  function outcome(b) {
    const o = { battle: b.token, status: b.status, accepted: b.status === 'done', win: !!b.win, delta: b.d_att || 0 };
    if (b.win && b.status === 'done') o.reward = { money: b.money, glory: b.glory };
    else o.reward = {};
    if (b.status === 'rejected') o.reason = 'Бой не засчитан: ' + (b.note || 'итог не сходится');
    if (b.status === 'expired') o.reason = 'Бой не засчитан вовремя — это поражение';
    return o;
  }

  function reports(uid, after) {
    return q.reports.all(uid, after).map(r => ({ id: r.n, t: Math.floor((r.finished || 0) / 1000), name: r.att_name || '?', win: !!r.win,
      delta: r.d_def || 0, glory: r.def_glory || 0, forfeit: r.status === 'expired' }));
  }

  function place(p) {
    return q.place.get(p.rating, p.rating, p.wins, p.wins, p.user_id).n + 1;
  }

  /* ---------- адреса ---------- */

  // моё состояние и отчёты о нападениях на мой город; ?ack=N — отчёты до N прочитаны
  routes['GET /api/pvp/state'] = (req, url) => {
    const a = auth(req);
    if (limited(`pvp:state:${a.userId}`, 60, 600e3)) throw new Fail(429, 'Слишком часто');
    const ack = int(url.searchParams.get('ack'));
    if (ack > 0) q.ack.run(a.userId, ack);
    expire(a.userId);
    const p = player(a.userId);
    return { me: state(p), reports: reports(a.userId, ack) };
  };

  routes['POST /api/pvp/ack'] = async (req) => {
    const a = auth(req);
    const b = await json(req);
    q.ack.run(a.userId, int(b.upto));
    return { ok: true };
  };

  // название города (табличка в игре, таблица лучших, летописи соперников) — и без Легиона
  routes['PUT /api/pvp/name'] = async (req) => {
    const a = auth(req);
    if (limited(`pvp:name:${a.userId}`, 10, 600e3)) throw new Fail(429, 'Слишком часто — подождите несколько минут');
    const b = await json(req);
    const p = player(a.userId);
    const nm = pickName(p, b.name);
    if (nm !== p.name || !p.custom) setName(a.userId, nm);
    return { me: state(q.player.get(a.userId)) };
  };

  // выставить отряд обороны (снимок) и, если прислали, — название (так переименовывают версии игры до PUT /pvp/name).
  // Сначала все проверки, потом запись: без Легиона не меняется ничего (раньше название успевало сохраниться до 409)
  routes['PUT /api/pvp/defense'] = async (req) => {
    const a = auth(req);
    if (limited(`pvp:def:${a.userId}`, 30, 600e3)) throw new Fail(429, 'Слишком часто');
    const b = await json(req);
    const p = player(a.userId);
    const nm = b.name !== undefined && b.name !== null && b.name !== '' ? pickName(p, b.name) : null;
    const f = facts(a.userId);
    if (f && !f.legion) throw new Fail(409, 'Легион ещё не собран');
    const c = checkSquad(f, b.snapshot);
    const lvl = f ? f.cityLevel : clamp(int(b.city_level), 0, 7);
    if (nm !== null && nm !== p.name) setName(a.userId, nm);
    q.setDefense.run(JSON.stringify(c.snap), c.snap.squad.length ? c.power : 0, lvl, Date.now(), a.userId);
    return { me: state(q.player.get(a.userId)), power: c.power, clamped: c.clamped };
  };

  // соперники близкого рейтинга (без себя, без тех, на кого нападали недавно, без только что проигравших оборону)
  routes['GET /api/pvp/opponents'] = (req, url) => {
    const a = auth(req);
    const heroOk = !!url && url.searchParams.get('hero') === '1';   // игра знает героя (старой — отряды без него)
    if (limited(`pvp:list:${a.userId}`, 40, 600e3)) throw new Fail(429, 'Слишком часто — подождите минуту');
    expire(a.userId);
    const p = player(a.userId);
    const now = Date.now();
    const recent = new Set(q.recentTargets.all(a.userId, now - ATTACK_GAP).map(r => r.defender));
    const f = facts(a.userId);
    if (f && f.cityLevel < PVP_MIN_LEVEL) throw new Fail(409, 'Бои с городами — с «Посёлка»');
    const mine = potential(f, p);
    const real = q.candidates.all(a.userId, now - STALE, now, p.rating).filter(r => !recent.has(r.user_id));
    // ближние по рейтингу; из них — ближние по силе
    const pick = real.slice(0, 20).sort((x, y) => Math.abs(Math.log((x.power + 1) / (mine + 1))) - Math.abs(Math.log((y.power + 1) / (mine + 1))))
      .slice(0, LIST_REAL);
    const items = new Map();
    const list = [];
    for (const r of pick) {
      let snap;
      try { snap = JSON.parse(r.snapshot); } catch (e) { continue; }
      let pw = r.power;
      if (!heroOk && snap.squad && snap.squad.some(e => e && e.type === 'hero')) {
        snap = noHero(snap);
        pw = snapPower(snap);
        if (!snap.squad.length) continue;      // в обороне один герой — старой игре такого соперника не показываем
      }
      const id = crypto.randomBytes(9).toString('base64url');
      items.set(id, { kind: 'user', uid: r.user_id });
      list.push({ id, name: r.name, rating: r.rating, city_level: r.city_level, power: pw, snapshot: snap, bot: false });
    }
    // вольные города — если по силе подходящих живых соперников (не сильнее в 1,6 раза) меньше LIST_MIN
    const fair = list.filter(o => o.power <= mine * FAIR).length;
    if (fair < LIST_MIN) {
      const rnd = rng(crypto.randomBytes(4).readUInt32LE(0));
      const used = new Set(list.map(o => o.name));
      const ks = [0.7, 0.85, 1.0, 1.15];
      for (let i = 0; i < LIST_MIN - fair; i++) {
        const bt = makeBot(rnd, p, f, ks[i % ks.length], used);
        const id = crypto.randomBytes(9).toString('base64url');
        items.set(id, bt);
        list.push({ id, name: bt.name, rating: bt.rating, city_level: bt.city_level, power: bt.power, snapshot: bt.snap, bot: true });
      }
    }
    list.sort((x, y) => x.power - y.power);
    offers.set(a.userId, { t: now, items });
    return { opponents: list, me: state(p), reports: reports(a.userId, 0) };
  };

  // нападение: заряд, номер боя, отряд соперника, ставки рейтинга и добыча за победу
  routes['POST /api/pvp/attack'] = async (req) => {
    const a = auth(req);
    if (limited(`pvp:attack:${a.userId}`, 20, 600e3)) throw new Fail(429, 'Слишком часто');
    const b = await json(req);
    const now = Date.now();
    expire(a.userId);
    const off = offers.get(a.userId);
    const target = off && now - off.t < OFFER_TTL ? off.items.get(String(b.target || '')) : null;
    if (!target) throw new Fail(409, 'Список соперников устарел — обновите его');
    let p = player(a.userId);
    if (target.used) {
      // повтор того же нападения (ответ не дошёл) — тот же бой, заряд второй раз не тратится
      const ob = q.battle.get(target.used);
      if (ob && ob.status === 'open' && now - ob.created < 120e3) return attackOut(ob, p);
      throw new Fail(409, 'С этим городом вы уже сражались — обновите список');
    }
    regen(p, now);
    if (p.charges <= 0) {
      const s = state(p);
      throw Object.assign(new Fail(429, `Отряд отдыхает: следующая атака через ${Math.ceil(s.next_in / 60)} мин`), { extra: { me: s } });
    }
    const f = facts(a.userId);
    if (f && !f.legion) throw new Fail(409, 'Легион ещё не собран');
    if (f && f.cityLevel < PVP_MIN_LEVEL) throw new Fail(409, 'Бои с городами — с «Посёлка»');
    const att = checkSquad(f, b.squad);
    if (!att.snap.squad.length) throw new Fail(400, 'В отряде нет бойцов');
    let def, defUid = null, defName, defRating, defLevel;
    if (target.kind === 'user') {
      const d = q.player.get(target.uid);
      if (!d || !d.snapshot || d.power <= 0) throw new Fail(409, 'Этот город распустил оборону — выберите другой');
      if (d.shield_until > now) throw new Fail(409, 'Этот город только что отбивался — выберите другой');
      if (q.recentTargets.all(a.userId, now - ATTACK_GAP).some(r => r.defender === d.user_id)) throw new Fail(409, 'На этот город вы уже нападали недавно');
      try { def = JSON.parse(d.snapshot); } catch (e) { throw new Fail(409, 'Этот город распустил оборону — выберите другой'); }
      if (!b.hero) def = noHero(def);          // старая игра героя не знает: соперник для неё — без героя (и повтор боя тоже)
      if (!Array.isArray(def.squad) || !def.squad.length) throw new Fail(409, 'Этот город распустил оборону — выберите другой');
      defUid = d.user_id; defName = d.name; defRating = d.rating; defLevel = d.city_level;
    } else {
      def = target.snap; defName = target.name; defRating = target.rating; defLevel = target.city_level;
    }
    // недоигранный прежний бой (игру закрыли посреди боя) засчитывается поражением — но только если он идёт дольше,
    // чем длится самый долгий бой: свежий мог закончиться, а его итог ещё в пути (связь мигнула) — его ждём до BATTLE_TTL
    for (const ob of q.openOf.all(a.userId)) {
      if (now - ob.created > BATTLE_BUSY) finalize(ob, { status: 'expired', win: false, note: 'брошен ради нового боя' });
    }
    p = player(a.userId);
    regen(p, now);
    const defPower = snapPower(def);
    const bot = target.kind === 'bot';
    let sWin = delta(true, p.rating, defRating), sLoss = delta(false, p.rating, defRating);
    if (bot) { sWin = Math.max(4, Math.round(sWin / 2)); sLoss = -Math.max(2, Math.round(-sLoss / 2)); }
    const sdWin = bot ? 0 : -clamp(Math.round(sWin / 2), 1, 10);
    const sdLoss = bot ? 0 : clamp(Math.round(-sLoss / 2), 1, 10);
    const money = roundi(PVP.loot_base + PVP.loot_money * defPower);
    const glory = PVP.glory + tdiv(clamp(int(defLevel), 0, 7), 2);
    const token = crypto.randomBytes(18).toString('base64url');
    const seed = 1 + crypto.randomBytes(3).readUIntLE(0, 3) % 0xfffffe;
    if (p.charges >= PVP.charges) p.charge_t = now;
    p.charges -= 1;
    tx(() => {
      q.setCharges.run(p.charges, p.charge_t, a.userId);
      // в бой идёт ровно проверенный отряд (клиент получает его в ответе), поэтому att_n — его число бойцов
      q.addBattle.run(token, a.userId, defUid, bot ? 1 : 0, p.name, defName, p.rating, defRating, defLevel, JSON.stringify(att.snap), JSON.stringify(def),
        att.snap.squad.length, att.power, defPower, seed, sWin, sLoss, sdWin, sdLoss, money, glory, now);
    });
    target.used = token;
    return attackOut(q.battle.get(token), p);
  };

  function attackOut(bt, p) {
    let snap = {}, mine = {};
    try { snap = JSON.parse(bt.def_snap); } catch (e) { /* */ }
    try { mine = JSON.parse(bt.att_snap); } catch (e) { /* */ }
    // attack — наш отряд, каким его проверил сервер: клиент воюет им, и сервер потом повторит этот бой
    return { battle: bt.token, seed: bt.seed, expires_in: Math.max(0, Math.floor((bt.created + BATTLE_TTL - Date.now()) / 1000)),
      attack: mine,
      opponent: { name: bt.def_name, rating: bt.def_rating, city_level: bt.def_level, snapshot: snap, power: bt.def_power, bot: !!bt.bot },
      stakes: { win: bt.s_win, loss: bt.s_loss }, reward: { money: bt.money, glory: bt.glory }, me: state(p) };
  }

  // итог боя (номер одноразовый: повтор того же номера возвращает уже записанный итог)
  routes['POST /api/pvp/result'] = async (req) => {
    const a = auth(req);
    if (limited(`pvp:result:${a.userId}`, 30, 600e3)) throw new Fail(429, 'Слишком часто');
    const b = await json(req);
    let bt = q.battle.get(String(b.battle || ''));
    if (!bt || bt.attacker !== a.userId) throw new Fail(404, 'Такого боя нет');
    const now = Date.now();
    if (bt.status === 'open' && now - bt.created > BATTLE_TTL) {
      finalize(bt, { status: 'expired', win: false, note: 'не доложен вовремя' });
      bt = q.battle.get(bt.token);
    }
    if (bt.status !== 'open') {
      const p = player(a.userId);
      return Object.assign(outcome(bt), { repeat: true, rating: p.rating, me: state(p) });
    }
    let alive = int(b.alive), total = int(b.total), time = num(b.time);
    let win = !!b.win && !b.retreat;
    let note = null, status = 'done';
    if (win) {
      // победу повторяем сами: то же зерно, те же отряды, нажатия игрока — засчитывается итог повтора
      const inputs = cleanInputs(b.inputs);
      let att = null, def = null;
      try { att = JSON.parse(bt.att_snap); def = JSON.parse(bt.def_snap); } catch (e) { att = null; }
      const rp = inputs && att && def ? replayPvp(att, def, bt.seed, inputs) : null;
      if (!inputs) note = 'нажатия умений не читаются';
      else if (!rp) note = 'бой не повторить';
      else if (!rp.win) note = 'итог не сходится с боем';
      else {
        alive = rp.alive; total = rp.total; time = rp.time;
        if (now - bt.created < (time / MAX_SPEED - 2) * 1000) note = 'бой закончился быстрее, чем его можно досмотреть';
        else if (bt.att_power < bt.def_power * MIN_RATIO) note = 'отряд намного слабее соперника';
      }
      if (note) status = 'rejected';
    }
    if (status === 'rejected') win = false;
    finalize(bt, { status, win, alive, total, time: Math.round(time * 10) / 10, note });
    bt = q.battle.get(bt.token);
    const p = player(a.userId);
    return Object.assign(outcome(bt), { rating: p.rating, me: state(p) });
  };

  // лучшие города по рейтингу побед (50) и моё место
  routes['GET /api/pvp/top'] = (req) => {
    const a = auth(req);
    if (limited(`pvp:top:${a.userId}`, 40, 600e3)) throw new Fail(429, 'Слишком часто');
    const p = player(a.userId);
    const top = q.top.all().map((r, i) => ({ place: i + 1, name: r.name, rating: r.rating, city_level: r.city_level, wins: r.wins, losses: r.losses,
      def_wins: r.def_wins, def_losses: r.def_losses, me: r.user_id === a.userId }));
    const listed = p.power > 0 || p.wins + p.losses > 0;
    return { top, me: Object.assign(state(p), { place: listed ? place(p) : 0 }), total: q.total.get().n };
  };

  return { unitStats, power, snapPower, delta, facts, checkSquad };
}

module.exports = { install, unitStats, power, snapPower, noHero, heroName, heroLook, delta, MIN_RATIO };
