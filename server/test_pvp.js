'use strict';
// Проверка боёв с городами перед выкладкой: node server/test_pvp.js   (ничего не трогает, кроме своей папки данных)
// Отряд обороны (сверка с городом в облаке), соперники и вольные города, нападение, итог (одноразовый номер,
// ставки рейтинга, защита города), подделки (слабый отряд, слишком быстрый бой), брошенный бой, заряды,
// отчёты защитнику и «прочитано», таблица лучших, названия городов (PUT /pvp/name и без Легиона: проверки, занятые,
// запасные, грубые слова с «двойниками» букв, частые попытки; списки совпадают с godot/scripts/city_name.gd).
// Победы сервер повторяет сам (legion_sim.js):
// тест считает тот же бой у себя и знает, чем он кончится.
// Данные — в TEST_DATA_DIR (по умолчанию ../.work/srvtest_pvp), порт — TEST_PORT (3012).
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const pvp = require('./pvp');
const sim = require('./legion_sim');
const names = require('./names');

const DATA = process.env.TEST_DATA_DIR || path.join(__dirname, '..', '.work', 'srvtest_pvp');
const PORT = +process.env.TEST_PORT || 3012;
const API = `http://127.0.0.1:${PORT}/api`;
const TTL = 5000;                    // бой надо доложить за 5 с (на проверке)
let fails = 0;
const ok = (c, msg, extra) => { console.log((c ? 'OK   ' : 'FAIL ') + msg + (c || extra === undefined ? '' : '  ' + JSON.stringify(extra))); if (!c) fails++; };
const sleep = ms => new Promise(r => setTimeout(r, ms));

function start() {
  return new Promise((resolve, reject) => {
    const p = spawn(process.execPath, ['--disable-warning=ExperimentalWarning', path.join(__dirname, 'index.js')], {
      env: { ...process.env, PORT: String(PORT), DATA_DIR: DATA, ORIGINS: '*', SMTP_HOST: '', SMTP_PASS: '', PVP_TTL_MS: String(TTL) },
      stdio: ['ignore', 'pipe', 'pipe'] });
    let done = false;
    p.stdout.on('data', d => { if (!done && /server on/.test(String(d))) { done = true; resolve(p); } });
    p.stderr.on('data', d => process.stderr.write('[srv] ' + d));
    p.on('exit', c => { if (!done) reject(new Error('server exit ' + c)); });
  });
}
const stop = p => new Promise(r => { p.on('exit', r); p.kill(); });

async function call(method, p, body, token) {
  const headers = {};
  if (token) headers.Authorization = 'Bearer ' + token;
  let b;
  if (body !== undefined) { headers['Content-Type'] = 'application/json'; b = JSON.stringify(body); }
  const r = await fetch(API + p, { method, headers, body: b });
  let data = null;
  try { data = await r.json(); } catch (e) { /* */ }
  return { status: r.status, data };
}

// город новой игры с легионом (как City.save_data → "legion": Legion.to_dict())
function city({ level, research = ['legion'], buildings = [], levels = {}, upg = {}, progress = 0, perks = {}, built = [] }) {
  return JSON.stringify({ version: 2, money: 9000, day: 30, level, research, next_id: buildings.length + 1,
    buildings: buildings.map((t, i) => ({ id: i + 1, type: t, tier: 1, x: 100 + i * 4, z: 90, pop: 0 })),
    legion: { v: 1, levels, upg, squad: ['legionary', 'legionary', 'legionary'], defense: [], perks, progress, built, glory: 10 } });
}
const sq = (...a) => a.map(([type, level]) => ({ type, level }));
const P = s => pvp.snapPower({ squad: s.squad, atk_b: s.atk_b || 0, hp_b: s.hp_b || 0 });

(async () => {
  fs.rmSync(DATA, { recursive: true, force: true });
  fs.mkdirSync(DATA, { recursive: true });
  const srv = await start();
  let r;
  try {
    // формула силы — та же, что Legion.power (числа сверены с Godot: test_pvp_net.gd печатает те же)
    ok(pvp.power(pvp.unitStats('legionary', 1, 0, 0)) === 142, 'power: legionary L1 = 142');
    ok(pvp.delta(true, 0, 0) === 20 && pvp.delta(false, 0, 0) === -10 && pvp.delta(true, 100, 0) === 16 && pvp.delta(false, 100, 0) === -12,
      'rating deltas like Legion.pvp_delta');
    r = await call('GET', '/health');
    ok(r.data.pvp === true, 'health: pvp');

    const tok = {};
    for (const n of ['a', 'b', 'c', 'd', 'e']) {
      r = await call('POST', '/register', { email: `${n}@pvp.test`, password: 'secret' + n });
      tok[n] = r.data.token;
    }
    ok(tok.a && tok.b && tok.c && tok.d && tok.e, 'five players registered');
    const save = async (n, c) => (await call('PUT', '/save?game=rome2', { data: c, force: true, meta: { city: 'Новый Рим' } }, tok[n])).status;
    ok(await save('a', city({ level: 4, buildings: ['barracks', 'range'], levels: { legionary: 3, archer: 2 } })) === 200 &&
       await save('b', city({ level: 6, buildings: ['barracks', 'range', 'spearcamp', 'arch'], levels: { legionary: 6, archer: 5, spearman: 4 },
         upg: { spearman: { to: 5, end: 0, total: 60 } }, progress: 12, perks: { oil: 1 } })) === 200 &&
       await save('c', city({ level: 5, buildings: ['barracks'], levels: { legionary: 1 } })) === 200 &&
       await save('d', city({ level: 2, research: [], buildings: [] })) === 200, 'cloud saves with legions uploaded');

    r = await call('GET', '/pvp/state', undefined, null);
    ok(r.status === 401, 'state without login → 401');
    r = await call('GET', '/pvp/state', undefined, tok.a);
    ok(r.status === 200 && r.data.me.rating === 0 && r.data.me.charges === 5 && /^[А-Яа-я]+ [А-Яа-я]+/.test(r.data.me.name) && !r.data.me.published,
      `state: default name «${r.data && r.data.me.name}», rating 0, 5 charges`, r.data);
    const nameA = r.data.me.name;

    // оборона: уровни не выше, чем в облаке
    r = await call('PUT', '/pvp/defense', { snapshot: { v: 1, squad: sq(['legionary', 30], ['legionary', 3], ['archer', 2], ['legionary', 3], ['archer', 2]), perks: { oil: 4 }, atk_b: 0.5, hp_b: 0 } }, tok.a);
    const defA = { squad: sq(['legionary', 3], ['legionary', 3], ['archer', 2], ['legionary', 3]) };
    ok(r.status === 200 && r.data.clamped === true && r.data.power === P(defA) && r.data.me.published, `defense A clamped to cloud levels and 3+1 slots (power ${r.data && r.data.power})`, r.data);
    r = await call('PUT', '/pvp/defense', { snapshot: { v: 1, squad: sq(['spearman', 6], ['legionary', 6], ['archer', 5], ['legionary', 6], ['archer', 5], ['catapult', 9]), perks: { oil: 2 }, atk_b: 0.05, hp_b: 0 },
      name: 'Сиракузы Великие' }, tok.b);
    const defB = { squad: sq(['spearman', 5], ['legionary', 6], ['archer', 5], ['legionary', 6], ['archer', 5]), atk_b: 0.05 };
    ok(r.status === 200 && r.data.clamped && r.data.power === P(defB) && r.data.me.name === 'Сиракузы Великие' && r.data.me.custom,
      `defense B: running upgrade counts, 4+1 slots, arch +5% (power ${r.data && r.data.power})`, r.data);
    r = await call('PUT', '/pvp/defense', { snapshot: { squad: sq(['legionary', 1]) }, name: 'сиракузы  ВЕЛИКИЕ' }, tok.c);
    ok(r.status === 409, 'name taken (case and spaces ignored) → 409');
    r = await call('PUT', '/pvp/defense', { snapshot: { squad: sq(['legionary', 1]) }, name: '<b>x</b>' }, tok.c);
    ok(r.status === 400, 'bad characters in name → 400');
    r = await call('PUT', '/pvp/defense', { snapshot: { squad: sq(['legionary', 1]) }, name: 'Ая' }, tok.c);
    ok(r.status === 400, 'too short name → 400');
    r = await call('PUT', '/pvp/defense', { snapshot: { squad: sq(['legionary', 1]) } }, tok.c);
    ok(r.status === 200 && r.data.power === 142, 'defense C published');
    r = await call('PUT', '/pvp/defense', { snapshot: { squad: sq(['legionary', 1]) } }, tok.d);
    ok(r.status === 409, 'no «Легион» research in cloud city → 409');
    // Легион с «Хутора» (история «Разбойники у арки»), а бои с городами — с «Посёлка» (PVP_MIN_LEVEL)
    ok(await save('e', city({ level: 1, buildings: ['barracks'] })) === 200, 'cloud city E: «Хутор» with the Legion');
    r = await call('GET', '/pvp/opponents', undefined, tok.e);
    ok(r.status === 409 && /Посёлка/.test(r.data.error), '«Хутор» with the Legion: no opponents until «Посёлок» → 409', r.data);
    r = await call('PUT', '/pvp/defense', { snapshot: { squad: 'x' } }, tok.a);
    ok(r.status === 400, 'broken snapshot → 400');

    // соперники
    r = await call('GET', '/pvp/opponents', undefined, tok.a);
    let opp = r.data.opponents || [];
    const real = opp.filter(o => !o.bot), bots = opp.filter(o => o.bot);
    ok(r.status === 200 && real.length === 2 && bots.length === 3 && !opp.some(o => o.name === nameA),
      `opponents for A: ${real.map(o => o.name + ' ' + o.power).join(', ')} + free cities (B is too strong, so 4 − 1 fair) ${bots.map(o => o.name + ' ' + o.power).join(', ')}`, r.data);
    ok(opp.every((o, i) => i === 0 || opp[i - 1].power <= o.power) && bots.every(o => o.snapshot.squad.length >= 3 && o.power > 0),
      'list sorted by power, free cities have squads');
    const oB = opp.find(o => o.name === 'Сиракузы Великие');
    ok(oB && oB.power === P(defB) && JSON.stringify(oB.snapshot.squad) === JSON.stringify(defB.squad), 'opponent B shows its checked defense');

    // нападение A → C (C намного слабее): сервер отдаёт проверенный отряд нападения — им и воюем
    const oC = opp.find(o => o.name !== 'Сиракузы Великие' && !o.bot);
    ok(oC && oC.power === 142, 'C offered to A');
    const attA = { v: 1, squad: sq(['legionary', 3], ['legionary', 3], ['legionary', 3]), perks: {}, atk_b: 0, hp_b: 0 };
    r = await call('POST', '/pvp/attack', { target: oC.id, squad: attA }, tok.a);
    ok(r.status === 200 && r.data.battle && r.data.seed > 0 && r.data.stakes.win === 20 && r.data.stakes.loss === -10 && r.data.me.charges === 4 &&
      r.data.reward.money === Math.round(150 + 2 * 142) && r.data.reward.glory === 4 && r.data.opponent.power === 142 &&
      JSON.stringify(r.data.attack.squad) === JSON.stringify(attA.squad),
      'attack A→C: battle id, seed, stakes +20/−10, reward, charge spent, checked attack squad returned', r.data);
    const bt1 = r.data.battle;
    const fight1 = sim.replayPvp(r.data.attack, r.data.opponent.snapshot, r.data.seed, [[0, 'auto', true]]);
    ok(fight1.win, `local replay: A beats C (${fight1.alive}/${fight1.total} alive, ${fight1.time.toFixed(1)} s)`, fight1);
    r = await call('POST', '/pvp/attack', { target: oC.id, squad: attA }, tok.a);
    ok(r.status === 200 && r.data.battle === bt1 && r.data.me.charges === 4, 'same attack repeated (lost answer) → same battle, no extra charge');
    r = await call('POST', '/pvp/result', { battle: bt1, win: true, alive: 3, total: 3, time: 9.5, inputs: [[0, 'auto', true]] }, tok.c);
    ok(r.status === 404, 'someone else\'s battle → 404');
    // досмотреть бой на ×3 — не быстрее (иначе «слишком быстро»)
    await sleep(Math.max(0, (fight1.time / 3 - 1.5) * 1000));
    // клиент врёт про живых и время — засчитывается повтор сервера
    r = await call('POST', '/pvp/result', { battle: bt1, win: true, alive: 1, total: 3, time: 99, hp_left: 0.4, inputs: [[0, 'auto', true]] }, tok.a);
    ok(r.status === 200 && r.data.accepted && r.data.win && r.data.delta === 20 && r.data.rating === 20 && r.data.reward.glory === 4,
      'result: win confirmed by server replay, rating 20', r.data);
    r = await call('POST', '/pvp/result', { battle: bt1, win: false, alive: 0, total: 3, time: 50 }, tok.a);
    ok(r.status === 200 && r.data.repeat && r.data.win && r.data.rating === 20, 'battle id is single-use (repeat returns the recorded result)');
    r = await call('GET', '/pvp/opponents', undefined, tok.a);
    opp = r.data.opponents;
    ok(!opp.some(o => o.name === oC.name), 'C not offered again (attacked recently, shielded)');

    // отчёт защитнику
    r = await call('GET', '/pvp/state', undefined, tok.c);
    const rep = r.data.reports || [];
    ok(r.data.me.rating === 0 && r.data.me.def_losses === 1 && r.data.me.shield_in > 0 && rep.length === 1 && rep[0].name === nameA && rep[0].win === true &&
      rep[0].delta === -10 && rep[0].glory === 0, 'defender C: report «A won», rating floor 0, shield', r.data);
    r = await call('GET', '/pvp/state?ack=' + rep[0].id, undefined, tok.c);
    ok(r.data.reports.length === 0, 'reports acknowledged');

    // подделка: «победа» в бою, который отряд проиграл (A против сильного B) — повтор сервера её не подтверждает
    const oB2 = opp.find(o => o.name === 'Сиракузы Великие');
    ok(!!oB2, 'B offered to A');
    r = await call('POST', '/pvp/attack', { target: oB2.id, squad: attA }, tok.a);
    const btB = r.data.battle;
    const fightB = sim.replayPvp(r.data.attack, r.data.opponent.snapshot, r.data.seed, [[0, 'auto', true]]);
    ok(!fightB.win, 'local replay: A loses to B', fightB);
    r = await call('POST', '/pvp/result', { battle: btB, win: true, alive: 2, total: 3, time: 120, inputs: [[0, 'auto', true]] }, tok.a);
    ok(r.data.status === 'rejected' && !r.data.accepted && r.data.delta === 0 && /не сходится/.test(r.data.reason) && r.data.rating === 20,
      'fake win (replay lost) rejected', r.data);

    // поражение нападающего: защитник получает рейтинг и Славу
    r = await call('GET', '/pvp/opponents', undefined, tok.c);
    const oA = r.data.opponents.find(o => o.name === nameA);
    ok(!!oA, 'A offered to C');
    r = await call('POST', '/pvp/attack', { target: oA.id, squad: { squad: sq(['legionary', 1]) } }, tok.c);
    const bt2 = r.data.battle;
    r = await call('POST', '/pvp/result', { battle: bt2, win: false, alive: 0, total: 1, time: 40 }, tok.c);
    ok(r.data.accepted && !r.data.win && r.data.delta < 0 && r.data.rating === 0, 'loss: C stays at rating 0', r.data);
    r = await call('GET', '/pvp/state', undefined, tok.a);
    ok(r.data.reports.length === 1 && r.data.reports[0].win === false && r.data.reports[0].delta > 0 && r.data.reports[0].glory === 1 &&
      r.data.me.rating === 20 + r.data.reports[0].delta && r.data.me.def_wins === 1, 'defender A held: +rating, +1 Glory in report', r.data);
    await call('GET', '/pvp/state?ack=' + r.data.reports[0].id, undefined, tok.a);

    // подделка: бой закончился быстрее, чем его можно досмотреть на ×3 (время — по повтору сервера, не по словам клиента)
    r = await call('GET', '/pvp/opponents', undefined, tok.c);
    let ob = r.data.opponents.filter(o => o.bot).sort((x, y) => x.power - y.power)[0];
    const attC = { squad: sq(['legionary', 1], ['legionary', 1], ['legionary', 1], ['legionary', 1]) };
    r = await call('POST', '/pvp/attack', { target: ob.id, squad: attC }, tok.c);
    ok(r.data.stakes.win >= 4 && r.data.stakes.win <= 20 && r.data.stakes.loss <= -2, 'free city: half stakes', r.data.stakes);
    ok(r.data.attack.squad.length === 4, 'attack squad clamped to open slots + 1 (4)', r.data.attack);
    const fightC = sim.replayPvp(r.data.attack, r.data.opponent.snapshot, r.data.seed, [[0, 'auto', true]]);
    r = await call('POST', '/pvp/result', { battle: r.data.battle, win: true, alive: 4, total: 4, time: 1, inputs: [[0, 'auto', true]] }, tok.c);
    ok(r.data.status === 'rejected' && (fightC.win ? /быстрее/.test(r.data.reason) : /не сходится/.test(r.data.reason)),
      `too fast win rejected (replay ${fightC.win ? 'won' : 'lost'} in ${fightC.time.toFixed(1)} s)`, r.data);
    // подделка: нажатия умений не по порядку
    r = await call('GET', '/pvp/opponents', undefined, tok.c);
    ob = r.data.opponents.find(o => o.bot);
    r = await call('POST', '/pvp/attack', { target: ob.id, squad: attC }, tok.c);
    r = await call('POST', '/pvp/result', { battle: r.data.battle, win: true, alive: 4, total: 4, time: 10, inputs: [[50, 'oil'], [3, 'horn']] }, tok.c);
    ok(r.data.status === 'rejected' && /нажатия/.test(r.data.reason), 'broken input log rejected', r.data);
    // отступили — поражение
    r = await call('GET', '/pvp/opponents', undefined, tok.c);
    ob = r.data.opponents.find(o => o.bot);
    r = await call('POST', '/pvp/attack', { target: ob.id, squad: { squad: sq(['legionary', 1]) } }, tok.c);
    const stake = r.data.stakes.loss;
    r = await call('POST', '/pvp/result', { battle: r.data.battle, win: true, retreat: true, alive: 1, total: 1, time: 6 }, tok.c);
    ok(r.data.accepted && !r.data.win && r.data.delta === stake, 'retreat counts as a loss', r.data);
    // заряды кончились
    r = await call('GET', '/pvp/opponents', undefined, tok.c);
    ok(r.data.me.charges === 1, 'C has 1 charge left');
    ob = r.data.opponents.find(o => o.bot);
    r = await call('POST', '/pvp/attack', { target: ob.id, squad: { squad: sq(['legionary', 1]) } }, tok.c);
    const open1 = r.data.battle;
    ob = (await call('GET', '/pvp/opponents', undefined, tok.c)).data.opponents.find(o => o.bot);
    r = await call('POST', '/pvp/attack', { target: ob.id, squad: { squad: sq(['legionary', 1]) } }, tok.c);
    ok(r.status === 429 && /отдыхает/.test(r.data.error) && r.data.me.next_in > 0 && r.data.me.next_in <= 1800, 'no charges → 429 with timer', r.data);
    // брошенный бой — поражение после BATTLE_TTL
    const lossesBefore = (await call('GET', '/pvp/state', undefined, tok.c)).data.me.losses;
    await sleep(TTL + 300);
    r = await call('GET', '/pvp/state', undefined, tok.c);
    ok(r.data.me.losses === lossesBefore + 1, 'abandoned battle expired as a loss', r.data.me);
    r = await call('POST', '/pvp/result', { battle: open1, win: true, alive: 1, total: 1, time: 10 }, tok.c);
    ok(r.data.status === 'expired' && !r.data.win && r.data.repeat, 'late report of an expired battle → not counted');
    // старый список
    r = await call('POST', '/pvp/attack', { target: 'nope', squad: attA }, tok.a);
    ok(r.status === 409 && /устарел/.test(r.data.error), 'unknown target → 409 «список устарел»');

    // свежий недоложенный бой не сгорает от нового нападения (итог мог задержаться: связь мигнула)
    r = await call('GET', '/pvp/opponents', undefined, tok.a);
    const freeA = r.data.opponents.filter(o => o.bot);
    const x1 = await call('POST', '/pvp/attack', { target: freeA[0].id, squad: attA }, tok.a);
    const x2 = await call('POST', '/pvp/attack', { target: freeA[1].id, squad: attA }, tok.a);
    r = await call('POST', '/pvp/result', { battle: x1.data.battle, win: false, alive: 0, total: 3, time: 30 }, tok.a);
    ok(x1.status === 200 && x2.status === 200 && r.data.status === 'done' && !r.data.repeat, 'fresh unreported battle survives a new attack', r.data);
    r = await call('POST', '/pvp/result', { battle: x2.data.battle, win: false, alive: 0, total: 3, time: 30 }, tok.a);
    const ratingA = r.data.rating;

    // таблица лучших
    r = await call('GET', '/pvp/top', undefined, tok.c);
    const top = r.data.top || [];
    ok(r.status === 200 && top.length === 3 && top[0].name === nameA && top[0].rating === ratingA && ratingA > 0 && top.some(t => t.me && t.name === r.data.me.name) &&
      r.data.me.place === top.find(t => t.me).place && r.data.total === 3, `leaderboard: A first (${ratingA}), my place`, r.data);
    ok(!JSON.stringify(r.data).includes('@'), 'leaderboard has no e-mails');

    // название города: PUT /pvp/name — и без Легиона (D: в облаке город без «Легиона»)
    r = await call('PUT', '/pvp/name', { name: 'Аквилея Новая' }, null);
    ok(r.status === 401, 'name without login → 401');
    r = await call('GET', '/pvp/state', undefined, tok.d);
    const nameD = r.data.me.name;
    ok(r.status === 200 && !r.data.me.custom && r.data.me.rename === true, `D: server name «${nameD}», not chosen by the player (custom false), rename: true`, r.data.me);
    r = await call('PUT', '/pvp/defense', { snapshot: { squad: sq(['legionary', 1]) }, name: 'Тибур Золотой' }, tok.d);
    const st409 = await call('GET', '/pvp/state', undefined, tok.d);
    ok(r.status === 409 && /Легион/.test(r.data.error) && st409.data.me.name === nameD && !st409.data.me.custom,
      'old rename via /defense without a Legion → 409 and the name is NOT changed', [r.data, st409.data.me]);
    r = await call('PUT', '/pvp/name', { name: '  Тибур   Золотой ' }, tok.d);
    ok(r.status === 200 && r.data.me.name === 'Тибур Золотой' && r.data.me.custom === true, 'D (no Legion) renamed: spaces trimmed, custom true', r.data);
    r = await call('GET', '/pvp/state', undefined, tok.d);
    ok(r.data.me.name === 'Тибур Золотой', 'D: state shows the new name');
    r = await call('PUT', '/pvp/name', { name: 'Тибур Золотой' }, tok.d);
    ok(r.status === 200 && r.data.me.name === 'Тибур Золотой', 'same name again → 200');
    r = await call('PUT', '/pvp/name', { name: 'сиракузы  ВЕЛИКИЕ' }, tok.d);
    ok(r.status === 409 && r.data.error === 'Такое название уже занято — придумайте другое', 'taken name (case, spaces) → 409 with the text', r.data);
    r = await call('PUT', '/pvp/name', { name: 'Ая' }, tok.c);
    ok(r.status === 400 && /от 3 до 24/.test(r.data.error), 'too short → 400', r.data);
    r = await call('PUT', '/pvp/name', { name: 'Очень длинное название города' }, tok.c);
    ok(r.status === 400 && /от 3 до 24/.test(r.data.error), 'too long (25+) → 400', r.data);
    r = await call('PUT', '/pvp/name', { name: 'Рим_2' }, tok.c);
    ok(r.status === 400 && /только буквы/.test(r.data.error), 'bad characters → 400', r.data);
    r = await call('PUT', '/pvp/name', { name: 'Город 4242' }, tok.c);
    ok(r.status === 400 && /даёт сам сервер/.test(r.data.error), 'reserved «Город 4242» → 400', r.data);
    const RUDE_TXT = 'Такое название не подойдёт — придумайте другое';
    for (const [n, who] of [['Хуй', 'c'], ['х у й', 'c'], ['XYЙ', 'c'], ['Пиzда', 'c'], ['blyat', 'a'], ['Ёбаный Рим', 'a'], ['F u c k', 'a'], ['Sh1t', 'a'],
      ['Пиз Дец', 'd'], ['Пиз-дец', 'd'], ['Пізда', 'd'], ['П1зда', 'a'], ['Порноград', 'a']]) {
      r = await call('PUT', '/pvp/name', { name: n }, tok[who]);
      ok(r.status === 400 && r.data.error === RUDE_TXT, `rude «${n}» → 400`, r.data);
    }
    r = await call('GET', '/pvp/state', undefined, tok.c);
    ok(r.data.me.name === oC.name, 'C keeps its name after the refused ones');

    // новое название видно в таблице лучших и в списке соперников (летописи новых боёв берут имя оттуда же — pvp_players.name)
    r = await call('PUT', '/pvp/name', { name: 'Аквилея Новая' }, tok.a);
    ok(r.status === 200 && r.data.me.name === 'Аквилея Новая', 'A renamed (has a Legion) → 200', r.data);
    r = await call('GET', '/pvp/top', undefined, tok.a);
    ok(r.data.top.some(t => t.me && t.name === 'Аквилея Новая') && !r.data.top.some(t => t.name === nameA), 'leaderboard shows A\'s new name', r.data.top);
    r = await call('GET', '/pvp/opponents', undefined, tok.b);
    ok(r.status === 200 && r.data.opponents.some(o => o.name === 'Аквилея Новая'), 'opponents list (for B) shows A\'s new name',r.data.opponents && r.data.opponents.map(o => o.name));

    // частые попытки — 429 (10 за 10 минут)
    let codes = [];
    for (let i = 0; i < 11; i++) codes.push((await call('PUT', '/pvp/name', { name: `Капуя ${['Первая', 'Вторая', 'Третья'][i % 3]} ${i}` }, tok.e)).status);
    ok(codes.slice(0, 10).every(c => c === 200) && codes[10] === 429, `rate limit: 10 renames, the 11th → 429 (${codes.join(' ')})`);

    // грубые слова и правила — те же, что в игре (godot/scripts/city_name.gd): списки совпадают, примеры (names_cases.json —
    // их же проверяет игра в test_city_name.gd)
    const gd = fs.readFileSync(path.join(__dirname, '..', 'godot', 'scripts', 'city_name.gd'), 'utf8');
    for (const k of ['RUDE_RU', 'RUDE_RU_WORD', 'RUDE_EN', 'RUDE_EN_WORD', 'RUDE_RU_JOIN', 'RUDE_EN_JOIN', 'EXTRA', 'SAFE_LAT', 'LOOK', 'TRANS', 'LAT']) {
      const m = gd.match(new RegExp(`const ${k} := "([^"]*)"`));
      ok(m && m[1] === names[k], `city_name.gd ${k} = server/names.js`, m && m[1]);
    }
    const { bad, good } = JSON.parse(fs.readFileSync(path.join(__dirname, 'names_cases.json'), 'utf8'));
    const miss = bad.filter(s => !names.rude(s)), wrong = good.filter(s => names.rude(s));
    ok(!miss.length && !wrong.length, `rude filter: ${bad.length} rude caught, ${good.length} fine names pass`, { miss, wrong });
  } finally {
    await stop(srv);
  }

  // Имена по умолчанию кончились: запасное «Город <номер>» тоже проверяется на занятость, а занять его самому нельзя
  // (раньше занятое запасное имя ломало игроку все бои: INSERT OR IGNORE ничего не писал, и каждый запрос падал)
  {
    const { DatabaseSync } = require('node:sqlite');
    const db = new DatabaseSync(':memory:');
    db.exec('CREATE TABLE users (id INTEGER PRIMARY KEY, email TEXT)');
    const addU = db.prepare('INSERT INTO users (id, email) VALUES (?, ?)');
    for (let i = 1; i <= 1000; i++) addU.run(i, `u${i}@t`);
    const routes = {};
    class Fail extends Error { constructor(status, msg) { super(msg); this.status = status; } }
    pvp.install({ db, routes, auth: req => ({ userId: req.uid }), json: async req => req.body, limited: () => false, Fail, latestSave: () => null });
    const st = uid => routes['GET /api/pvp/state']({ uid }, new URL('http://x/api/pvp/state'));
    let fallback = 0;
    for (let uid = 1; uid <= 900; uid++) if (/^Город \d+$/.test(st(uid).me.name)) fallback++;
    ok(fallback > 0, `default names ran out: ${fallback} players got «Город N»`);
    let err = null;
    try { await routes['PUT /api/pvp/defense']({ uid: 5, body: { name: 'Город 950', snapshot: { squad: [] } } }); } catch (e) { err = e; }
    ok(err && err.status === 400, 'reserved name «Город 950» cannot be taken by a player', err && err.message);
    db.prepare("INSERT INTO pvp_players (user_id, name, name_key, created) VALUES (999, 'Город 960', 'город 960', 0)").run();
    let me = null;
    try { me = st(960).me; } catch (e) { me = { error: e.message }; }
    ok(me && /^Город 960-1$/.test(me.name), `squatted fallback name → «${me && (me.name || me.error)}», PvP still works`);
    db.close();
  }

  // Места в отряде (здания Легиона, Д10): сохранение v3 — босс и Казармы нужного уровня, как Legion.slots();
  // места, открытые до зданий (flags.slots0), не отнимаются; сохранение до v3 — по-старому (только боссы).
  // Сколько мест знает сервер, видно по обороне: лишние бойцы срезаются до «мест + 1»
  {
    const { DatabaseSync } = require('node:sqlite');
    const db = new DatabaseSync(':memory:');
    db.exec('CREATE TABLE users (id INTEGER PRIMARY KEY, email TEXT)');
    const saves = {};
    const legionSave = (L) => JSON.stringify({ version: 2, level: 5, research: ['legion'], buildings: [{ id: 1, type: 'barracks', tier: 0, x: 100, z: 90, pop: 0 }],
      legion: Object.assign({ squad: ['legionary', 'legionary', 'legionary'], perks: {}, glory: 0 }, L) });
    const cases = [
      [1, { v: 3, levels: { legionary: 2 }, progress: 30 }, 4, 'v3: boss 3 beaten, Казармы 2 → 4 slots'],
      [2, { v: 3, levels: { legionary: 3 }, progress: 30 }, 5, 'v3: boss 3, Казармы 3 → 5 slots'],
      [3, { v: 3, levels: { legionary: 2 }, progress: 30, flags: { slots0: 5 } }, 5, 'v3: Казармы 2 but slots0 = 5 (opened before D10) → 5'],
      [4, { v: 3, levels: { legionary: 1 }, progress: 10 }, 3, 'v3: boss 1, Казармы 1 → 3 slots'],
      [5, { v: 3, levels: { legionary: 1 }, upg: { legionary: { to: 2, end: 0, total: 60 } }, progress: 10 }, 4, 'v3: boss 1, Казармы 1→2 upgrading → 4 (cloud lag)'],
      [6, { v: 2, levels: { legionary: 1 }, progress: 30 }, 5, 'v2 (not migrated yet): bosses only → 5'],
    ];
    for (const [uid, L] of cases) { db.prepare('INSERT INTO users (id, email) VALUES (?, ?)').run(uid, `s${uid}@t`); saves[uid] = legionSave(L); }
    const routes = {};
    class Fail extends Error { constructor(status, msg) { super(msg); this.status = status; } }
    pvp.install({ db, routes, auth: req => ({ userId: req.uid }), json: async req => req.body, limited: () => false, Fail,
      latestSave: uid => (saves[uid] ? { id: 1, load: () => saves[uid] } : null) });
    for (const [uid, L, slots, msg] of cases) {
      const lvl = Math.max(L.levels.legionary || 1, L.upg ? L.upg.legionary.to : 1);
      const one = pvp.power(pvp.unitStats('legionary', lvl, 0, 0));
      let r2 = null;
      try { r2 = await routes['PUT /api/pvp/defense']({ uid, body: { snapshot: { squad: Array.from({ length: 7 }, () => ({ type: 'legionary', level: lvl })) } } }); } catch (e) { r2 = { error: e.message }; }
      ok(r2 && r2.power === one * Math.min(7, slots + 1), `${msg} (defense clamped to ${slots}+1)`, r2);
    }
    db.close();
  }

  // Свой герой (Д11) в боях с городами: первое место отряда; числа — из сохранения в облаке (Казармы, город, Склад оружия),
  // имя и облик — тоже оттуда (не со слов игры); подделки срезаются; старые сохранения без героя и старые игры (без hero=1 /
  // hero: true) — как раньше, и бой всегда повторяется так, как его видела игра
  await heroTests();
  console.log(fails ? `${fails} FAILED` : 'ALL OK');
  process.exit(fails ? 1 : 0);
})().catch(e => { console.error(e); process.exit(2); });

// Герой в боях с городами — без сети (pvp.install на базе в памяти, свои сохранения; часы — свои, чтобы бой «досмотрели»)
async function heroTests() {
  const { DatabaseSync } = require('node:sqlite');
  const db = new DatabaseSync(':memory:');
  db.exec('CREATE TABLE users (id INTEGER PRIMARY KEY, email TEXT)');
  const saves = {};
  const look = { mdl: 'SK_Chr_Upperclass_Male_01', skin: 'B', hair: 3, beard: 1, hc: 'B', main: 'a3283a', second: 'f4f1ea', trim: 'c49a4a', cape: '2F5585', crown: 1 };
  const hero = (pn, lk = look, sx = 0) => ({ v: 1, m: { pn, sx, age: 1, sd: 77, look: lk }, made: true, seen: [], kit: -1 });
  const mk = ({ level, buildings, levels, blevels = {}, upg = {}, progress = 30, h = null }) => {
    const d = { version: 2, level, research: ['legion'], buildings: buildings.map((t, i) => ({ id: i + 1, type: t, tier: 1, x: 100 + i * 4, z: 90, pop: 0 })),
      legion: { v: 3, levels, blevels, upg, squad: ['legionary', 'legionary', 'legionary'], defense: [], perks: { oil: 1 }, progress, built: [], glory: 0 } };
    if (h) d.hero = h;
    return JSON.stringify(d);
  };
  // H — герой «Гай Валерий», Казармы 6, город 5, Склад оружия 4 (улучшается до 5), 5 мест
  saves[11] = mk({ level: 5, buildings: ['barracks', 'range', 'armory'], levels: { legionary: 6, archer: 5 }, blevels: { armory: 4 }, upg: { armory: { to: 5, end: 0, total: 60 } }, h: hero('Гай Валерий') });
  saves[12] = mk({ level: 4, buildings: ['barracks'], levels: { legionary: 3 } });                       // старое сохранение: героя нет
  saves[13] = mk({ level: 4, buildings: ['barracks'], levels: { legionary: 3 },                         // имя грубое, облик испорчен
    h: hero('Хуй Иванов', { mdl: '<script>', skin: 'Q', hair: 99, beard: -3, main: 'zzzzzz', cape: 12, crown: 9 }, 1) });
  saves[14] = mk({ level: 4, buildings: ['barracks'], levels: { legionary: 3 }, blevels: { armory: 7 }, h: hero('Марк Туллий') });   // Склад «в запасе», не построен
  saves[15] = mk({ level: 6, buildings: ['barracks', 'range'], levels: { legionary: 20, archer: 20 }, h: hero('Луций Корнелий') });  // сильный нападающий (новая игра)
  saves[16] = mk({ level: 6, buildings: ['barracks', 'range'], levels: { legionary: 20, archer: 20 } });                          // нападающий старой игры
  for (const uid of Object.keys(saves)) db.prepare('INSERT INTO users (id, email) VALUES (?, ?)').run(+uid, `h${uid}@t`);
  db.prepare('INSERT INTO users (id, email) VALUES (?, ?)').run(17, 'h17@t');                        // игрок без сохранения в облаке
  const sid = {};                    // номер сохранения игрока (новое сохранение — новый номер: сервер перечитывает его)
  const routes = {};
  class Fail extends Error { constructor(status, msg) { super(msg); this.status = status; } }
  pvp.install({ db, routes, auth: req => ({ userId: req.uid }), json: async req => req.body, limited: () => false, Fail,
    latestSave: uid => (saves[uid] ? { id: sid[uid] || 1, load: () => saves[uid] } : null) });
  const realNow = Date.now;
  let clock = realNow();
  Date.now = () => clock;
  const call2 = async (route, uid, body, q = '') => { try { return await routes[route]({ uid, body }, new URL('http://x/api' + q)); } catch (e) { return { error: e.message, status: e.status }; } };
  const H = (level, city, kit, extra = {}) => Object.assign({ type: 'hero', level, city, kit }, extra);
  try {
    // формула героя — та же, что Legion.snap_hero (числа сверены с Godot: test_hero.gd проверяет те же)
    const h1 = sim.heroStats(1, 0, 0), h6 = sim.heroStats(6, 5, 5), h12 = sim.heroStats(12, 7, 10, 0.15, 0.1);
    ok(h1.hp === 285 && h1.atk === 23 && h1.armor === 34 && pvp.power(h1) === 150 && pvp.power(h6) === 379 && h6.hp === 590 && h6.atk === 53 && h6.armor === 79 &&
      pvp.power(h12) === 717, 'hero stats/power like Legion.snap_hero: L1 150, L6 city 5 kit 5 → 379, L12 city 7 kit 10 +15%/+10% → 717');
    const st = await call2('GET /api/pvp/state', 11, undefined, '/pvp/state');
    ok(st.me && st.me.hero === true, 'state: me.hero = true (the game puts the hero into city battles only then)', st);

    // оборона H: герой с подделанными числами, именем и обликом → срезан до облака, имя и облик — из сохранения
    let r = await call2('PUT /api/pvp/defense', 11, { snapshot: { squad: [H(40, 7, 10, { name: 'Взломщик', look: { mdl: 'X' } }), { type: 'legionary', level: 6 },
      { type: 'archer', level: 5 }, { type: 'legionary', level: 6 }, { type: 'archer', level: 5 }] } });
    const defH = { squad: [H(6, 5, 5), { type: 'legionary', level: 6 }, { type: 'archer', level: 5 }, { type: 'legionary', level: 6 }, { type: 'archer', level: 5 }] };
    ok(r.clamped === true && r.power === pvp.snapPower(defH), `defense H: forged hero (40/7/10) clamped to Казармы 6, city 5, Склад 4→5 (power ${r.power})`, r);
    let o = await call2('GET /api/pvp/opponents', 15, undefined, '/pvp/opponents?hero=1');
    const oH = (o.opponents || []).find(x => !x.bot);
    const h0 = oH && oH.snapshot.squad[0];
    ok(h0 && h0.type === 'hero' && h0.level === 6 && h0.city === 5 && h0.kit === 5 && h0.name === 'Гай Валерий' && h0.look.mdl === look.mdl && h0.look.cape === '2f5585' &&
      h0.look.sx === 0 && oH.power === pvp.snapPower(defH), 'new game (hero=1) sees H\'s hero first: numbers from the cloud, name and look from the save', oH);
    o = await call2('GET /api/pvp/opponents', 16, undefined, '/pvp/opponents');
    const oH2 = (o.opponents || []).find(x => !x.bot);
    ok(oH2 && !oH2.snapshot.squad.some(e => e.type === 'hero') && oH2.snapshot.squad.length === 5 && oH2.snapshot.squad[0].type === 'legionary' &&
      oH2.snapshot.squad[0].level === 6 && oH2.power === pvp.snapPower(pvp.noHero(defH)),
      'old game (no hero=1): opponent without the hero — a legionary of his level in his place (5 fighters, not 4)', oH2);

    // герой не первым, два героя, старое сохранение без героя, грубое имя, Склад не построен
    r = await call2('PUT /api/pvp/defense', 11, { snapshot: { squad: [{ type: 'legionary', level: 6 }, H(6, 5, 5)] } });
    ok(r.clamped && r.power === pvp.snapPower({ squad: [{ type: 'legionary', level: 6 }] }), 'hero not in the first place → dropped', r);
    r = await call2('PUT /api/pvp/defense', 11, { snapshot: { squad: [H(6, 5, 5), H(6, 5, 5), { type: 'legionary', level: 6 }] } });
    ok(r.clamped && r.power === pvp.snapPower({ squad: [H(6, 5, 5), { type: 'legionary', level: 6 }] }), 'second hero → dropped', r);
    r = await call2('PUT /api/pvp/defense', 12, { snapshot: { squad: [H(3, 4, 0), { type: 'legionary', level: 3 }, { type: 'legionary', level: 3 }] } });
    ok(r.clamped && r.power === 3 * pvp.power(pvp.unitStats('legionary', 3, 0, 0)), 'old save without a hero: a legionary (Казармы 3) in the hero\'s place, the rest stays', r);
    r = await call2('PUT /api/pvp/defense', 12, { snapshot: { squad: [{ type: 'legionary', level: 3 }, { type: 'legionary', level: 3 }] } });
    ok(!r.clamped && r.power === 2 * pvp.power(pvp.unitStats('legionary', 3, 0, 0)), 'old save, old squad: works as before', r);
    r = await call2('PUT /api/pvp/defense', 13, { snapshot: { squad: [H(3, 4, 0)] } });
    o = await call2('GET /api/pvp/opponents', 16, undefined, '/pvp/opponents?hero=1');
    const oR = (o.opponents || []).find(x => !x.bot && x.snapshot.squad[0] && x.snapshot.squad[0].type === 'hero' && x.snapshot.squad[0].look.sx === 1);
    const hr = oR && oR.snapshot.squad[0];
    ok(hr && !('name' in hr) && !('mdl' in hr.look) && !('skin' in hr.look) && !('main' in hr.look) && !('cape' in hr.look) && hr.look.hair === 7 && hr.look.beard === 0 &&
      hr.look.crown === 2, 'rude hero name dropped, broken look cleaned (only known fields and values)', hr);
    r = await call2('PUT /api/pvp/defense', 14, { snapshot: { squad: [H(3, 4, 7)] } });
    ok(r.clamped && r.power === pvp.snapPower({ squad: [H(3, 4, 0)] }), 'Склад оружия not built (level «в запасе») → kit 0', r);
    r = await call2('PUT /api/pvp/defense', 11, { snapshot: { squad: 'x' } });
    ok(r.status === 400, 'broken snapshot still → 400', r);
    // H снова выставляет героя (для боёв ниже)
    r = await call2('PUT /api/pvp/defense', 11, { snapshot: defH });
    ok(!r.clamped && r.power === pvp.snapPower(defH), 'defense H with the hero republished (nothing clamped)', r);

    // нападение новой игры (hero: true): герой в отряде нападения, у соперника — его герой; сервер повторяет бой с обоими
    o = await call2('GET /api/pvp/opponents', 15, undefined, '/pvp/opponents?hero=1');
    let tH = (o.opponents || []).find(x => !x.bot && x.snapshot.squad[0] && x.snapshot.squad[0].name === 'Гай Валерий');
    const att15 = { v: 1, squad: [H(20, 6, 0, { name: 'Подделка' }), { type: 'legionary', level: 20 }, { type: 'archer', level: 20 }], perks: { oil: 1 }, atk_b: 0, hp_b: 0 };
    let a = await call2('POST /api/pvp/attack', 15, { target: tH && tH.id, squad: att15, hero: true });
    ok(a.battle && a.attack.squad[0].type === 'hero' && a.attack.squad[0].name === 'Луций Корнелий' && a.attack.squad[0].level === 20 &&
      a.opponent.snapshot.squad[0].type === 'hero' && a.opponent.power === pvp.snapPower(defH),
      'attack (new game): checked attack squad has our hero (name from our save), the defender keeps his hero', a);
    const inputs = [[0, 'auto', true]];
    let rp = sim.replayPvp(a.attack, a.opponent.snapshot, a.seed, inputs);
    ok(rp.win && rp.total === 3, `local replay with both heroes: ${rp.win ? 'win' : 'loss'} ${rp.alive}/${rp.total}, ${rp.time.toFixed(1)} s`, rp);
    clock += 200e3;
    r = await call2('POST /api/pvp/result', 15, { battle: a.battle, win: rp.win, alive: rp.alive, total: rp.total, time: rp.time, inputs });
    ok(r.accepted && r.win === rp.win && r.status === 'done', 'result with heroes on both sides accepted (server replay = game)', r);

    // нападение старой игры (без hero): соперник — без героя, бой повторяется без него (H полчаса под защитой — ждём)
    clock += 31 * 60e3;
    o = await call2('GET /api/pvp/opponents', 16, undefined, '/pvp/opponents');
    ok(!(o.opponents || []).some(x => !x.bot && (!x.snapshot.squad.length || x.snapshot.squad.some(e => e.type === 'hero'))) &&
      (o.opponents || []).filter(x => !x.bot && x.snapshot.squad.length === 1 && x.snapshot.squad[0].type === 'legionary' && x.snapshot.squad[0].level === 3).length === 2,
      'old game: a defense of the hero alone is offered as one legionary of his level (cities 13 and 14)', o.opponents);
    tH = (o.opponents || []).find(x => !x.bot && x.snapshot.squad.length === 5 && x.snapshot.squad[0].type === 'legionary' && x.snapshot.squad[0].level === 6);
    const att16 = { v: 1, squad: [{ type: 'legionary', level: 20 }, { type: 'legionary', level: 20 }, { type: 'archer', level: 20 }], perks: { oil: 1 }, atk_b: 0, hp_b: 0 };
    a = await call2('POST /api/pvp/attack', 16, { target: tH && tH.id, squad: att16 });
    ok(a.battle && !a.opponent.snapshot.squad.some(e => e.type === 'hero') && a.opponent.snapshot.squad.length === 5 && a.opponent.snapshot.squad[0].type === 'legionary' &&
      a.opponent.power === pvp.snapPower(pvp.noHero(defH)), 'attack (old game): the defender\'s snapshot comes without the hero — his legionary in his place', a);
    rp = sim.replayPvp(a.attack, a.opponent.snapshot, a.seed, inputs);
    clock += 200e3;
    r = await call2('POST /api/pvp/result', 16, { battle: a.battle, win: rp.win, alive: rp.alive, total: rp.total, time: rp.time, inputs });
    ok(rp.win && r.accepted && r.win, 'old game\'s win against a hero city accepted (replayed without the hero, as the game saw it)', [rp, r]);

    // H переименовал героя и переодел его после выставления обороны: соперники видят нынешние имя и облик (из сохранения),
    // числа — прежние. Нападение с героем, но без hero: true (подделка запроса) — у защитника герой остаётся
    clock += 7 * 3600e3;
    saves[11] = mk({ level: 5, buildings: ['barracks', 'range', 'armory'], levels: { legionary: 6, archer: 5 }, blevels: { armory: 4 }, upg: { armory: { to: 5, end: 0, total: 60 } },
      h: hero('Гай Север', Object.assign({}, look, { cape: 'AA0000' })) });
    sid[11] = 2;
    o = await call2('GET /api/pvp/opponents', 15, undefined, '/pvp/opponents?hero=1');
    tH = (o.opponents || []).find(x => !x.bot && x.snapshot.squad[0] && x.snapshot.squad[0].type === 'hero' && x.snapshot.squad[0].level === 6);
    ok(tH && tH.snapshot.squad[0].name === 'Гай Север' && tH.snapshot.squad[0].look.cape === 'aa0000' && tH.power === pvp.snapPower(defH),
      'renamed and re-dressed hero: rivals see the new name and look at once (numbers unchanged)', tH);
    a = await call2('POST /api/pvp/attack', 15, { target: tH && tH.id, squad: att15 });
    ok(a.battle && a.attack.squad[0].type === 'hero' && a.opponent.snapshot.squad[0].type === 'hero' && a.opponent.snapshot.squad[0].name === 'Гай Север' &&
      a.opponent.snapshot.squad[0].look.cape === 'aa0000' && a.opponent.power === pvp.snapPower(defH),
      'attack with our hero but without hero: true — the defender keeps his hero too (no one-sided hero)', a);
    rp = sim.replayPvp(a.attack, a.opponent.snapshot, a.seed, inputs);
    clock += 200e3;
    r = await call2('POST /api/pvp/result', 15, { battle: a.battle, win: rp.win, alive: rp.alive, total: rp.total, time: rp.time, inputs });
    ok(r.accepted && r.win === rp.win, 'that battle replays with both heroes as the game saw it', [rp, r]);

    // героя в облаке ещё нет (сохранение отстаёт) — сервер убирает его из отряда нападения, игра воюет тем, что вернул сервер
    saves[12] = mk({ level: 4, buildings: ['barracks'], levels: { legionary: 3 } });
    o = await call2('GET /api/pvp/opponents', 12, undefined, '/pvp/opponents?hero=1');
    const tb = (o.opponents || []).find(x => x.bot);
    a = await call2('POST /api/pvp/attack', 12, { target: tb && tb.id, squad: { squad: [H(3, 4, 0), { type: 'legionary', level: 3 }] }, hero: true });
    ok(a.battle && a.attack.squad.length === 2 && a.attack.squad.every(e => e.type === 'legionary' && e.level === 3),
      'no hero in the cloud save: a legionary in his place (Казармы 3), the game fights the returned squad', a);

    // вольные города под силу игрока с героем — сила считается и с ним
    const fct = routes['GET /api/pvp/opponents'] && (await call2('GET /api/pvp/opponents', 14, undefined, '/pvp/opponents?hero=1'));
    ok(fct && Array.isArray(fct.opponents) && fct.opponents.filter(x => x.bot).every(x => x.power > 0 && !x.snapshot.squad.some(e => e.type === 'hero')),
      'free cities for a player with a hero: listed, without heroes', fct);

    // нет сохранения в облаке: на месте героя — легионер (не выше 10, как и остальные)
    r = await call2('PUT /api/pvp/defense', 17, { snapshot: { squad: [H(12, 7, 10), { type: 'legionary', level: 12 }] }, city_level: 4 });
    ok(r.clamped && r.power === 2 * pvp.power(pvp.unitStats('legionary', 10, 0, 0)), 'no cloud save: a legionary L10 in the hero\'s place', r);

    // откат сервера на версию без героя: pvp_nohero.js убирает героя из выставленных отрядов (старый pvp.js на нём падает)
    const n = require('./pvp_nohero').stripHeroes(db);
    const rows = db.prepare('SELECT user_id, snapshot, power FROM pvp_players WHERE snapshot IS NOT NULL').all();
    ok(n === 3 && rows.every(x => !x.snapshot.includes('"hero"') && x.power === pvp.snapPower(JSON.parse(x.snapshot))) &&
      rows.filter(x => x.user_id === 13 || x.user_id === 14).every(x => x.power === pvp.power(pvp.unitStats('legionary', 3, 0, 0))),
      `rollback helper: heroes stripped from ${n} stored defenses (a legionary in his place, power recounted)`, rows);
  } finally {
    Date.now = realNow;
    db.close();
  }
}
