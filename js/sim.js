'use strict';
/* Симуляция города: раз в игровой день считаем работников, производство, склады,
   потребности домов, налоги, свитки, просьбы жителей и задачи. */

let state = null;

function newState(seed) {
  const goods = {};
  for (const g of GOOD_IDS) goods[g] = START_GOODS[g] || 0;
  return {
    v: 2,
    seed,
    cityName: 'Нова Рома',
    day: 0,
    money: START_MONEY,
    goods,
    scrolls: START_SCROLLS,
    research: null,
    glory: 0,
    plots: new Set(['0,0']),
    cleared: new Set(),
    buildings: new Map(),
    nextId: 1,
    techs: [],
    goalIndex: 0,
    firsts: [],
    nextRequestDay: 25,
    speed: 1,
    lastSpeed: 1,
    taxLevel: 1,
    trade: { sell: {}, buy: {} },
    nextTradeDay: TRADE_INTERVAL,
    army: null,
    festivalUntil: 0,
    camera: null,
    journal: [],
    tipsSeen: [],
    tipQueue: ['welcome'],
    stats: {},
  };
}

function hasTech(id) { return state.techs.includes(id); }

function tiersOf(b) { return BUILDINGS[b.type].tiers; }

function countType(type) {
  let n = 0;
  for (const b of state.buildings.values()) if (b.type === type) n++;
  return n;
}

function housesAtLeast(type, tier) {
  let n = 0;
  for (const b of state.buildings.values()) if (b.type === type && b.tier >= tier) n++;
  return n;
}

function decorCount() {
  let n = 0;
  for (const b of state.buildings.values()) if (BUILDINGS[b.type].kind === 'decor') n++;
  return n;
}

function storageCap() {
  let n = 0;
  for (const b of state.buildings.values()) if (b.type === 'warehouse' && b.active) n++;
  return BASE_STORAGE + n * WAREHOUSE_STORAGE;
}

/* Задачи советника. hint — объяснение «зачем и как», act — что сделать по кнопке «Показать»:
   tool — выбрать постройку, cat — открыть категорию, open — открыть раздел, plot — показать участок. */
const GOALS = [
  { text: 'Поставьте 3 дома у дороги', need: 3, reward: { money: 150 }, act: { tool: 'house' },
    hint: 'Дома ставятся вплотную к дороге. В них заселятся плебеи и начнут платить налоги.',
    prog: () => [...state.buildings.values()].filter(b => b.type === 'house' && b.road).length },
  { text: 'Постройте колодец рядом с домами', need: 1, reward: { money: 100 }, act: { tool: 'well' },
    hint: 'Без воды хижины не растут. Колодец поит дома внутри круга, который виден при установке.',
    prog: () => countType('well') },
  { text: 'Пшеничное поле и рынок', need: 2, reward: { money: 200 }, act: { tool: 'farm' },
    hint: 'Поле растит пшеницу, рынок раздаёт её домам вокруг. Оба ставьте у дороги.',
    prog: () => Math.min(1, countType('farm')) + Math.min(1, countType('market')) },
  { text: 'Дождитесь трёх Домиков', need: 3, reward: { money: 200 },
    hint: 'Хижина станет Домиком, когда у неё есть вода и еда. Нажмите на дом — он покажет, чего не хватает.',
    prog: () => housesAtLeast('house', 2) },
  { text: 'Лесопилка у рощи и каменоломня у скал', need: 2, reward: { money: 200, wood: 30 }, act: { tool: 'lumber' },
    hint: 'Дерево и камень нужны для стройки. При установке видно, сколько деревьев или скал рядом — ставьте туда, где 100%.',
    prog: () => Math.min(1, countType('lumber')) + Math.min(1, countType('quarry')) },
  { text: 'Постройте Храм Юпитера', need: 1, reward: { money: 250 }, act: { tool: 'temple' },
    hint: 'Храм нужен для роста домов и пишет свитки — знания Рима. За свитки открываются новые здания.',
    prog: () => countType('temple') },
  { text: 'Изучите «Оливководство»', need: 1, reward: { scrolls: 5 }, act: { open: 'research', focus: 'olives' }, techGoal: 'olives',
    hint: 'Первое знание — бесплатно! Откройте «Знания» слева и нажмите «Изучить» на подсвеченной карточке «Оливководство». Оно откроет оливковые рощи и масло для инсул.',
    prog: () => hasTech('olives') ? 1 : 0 },
  { text: 'Оливковая роща и маслодавильня', need: 2, reward: { money: 250 }, act: { tool: 'grove' },
    hint: 'Роща растит оливки, маслодавильня делает из них масло. Дома получают масло через рынок.',
    prog: () => Math.min(1, countType('grove')) + Math.min(1, countType('oilpress')) },
  { text: 'Вырастите первую Инсулу', need: 1, reward: { money: 300 }, act: { cat: 'decor' },
    hint: 'Инсуле нужны вода, еда, храм, масло и немного красоты: клумбы и кипарисы рядом.',
    prog: () => housesAtLeast('house', 3) },
  { text: 'Соберите 100 жителей', need: 100, reward: { money: 400 }, act: { tool: 'house' },
    hint: 'Больше домов — больше налогов. Следите, чтобы хватало еды: смотрите «Товары» слева.',
    prog: () => state.stats.pop || 0 },
  { text: 'Постройте склад', need: 1, reward: { money: 150 }, act: { tool: 'warehouse' },
    hint: 'Склад добавляет место для всех товаров. Когда склады полны, производство встаёт.',
    prog: () => countType('warehouse') },
  { text: 'Купите соседний участок', need: 1, reward: { money: 300 }, act: { plot: true },
    hint: 'Нажмите на табличку «Купить землю». На новых землях бывают мрамор, железо и озёра с рыбой.',
    prog: () => state.plots.size - 1 },
  { text: 'Постройте термы', need: 1, reward: { money: 400 }, act: { open: 'research' },
    hint: 'Термам нужен кирпич. Изучите «Обжиг кирпича» и «Римские бани», поставьте глиняный карьер у воды.',
    prog: () => countType('baths') },
  { text: 'Вырастите Большую инсулу', need: 1, reward: { money: 500 }, act: { tool: 'bakery' },
    hint: 'Большой инсуле нужны хлеб и термы рядом. Пекарня печёт хлеб из пшеницы.',
    prog: () => housesAtLeast('house', 4) },
  { text: 'Поселите патрициев', need: 1, reward: { money: 600 }, act: { open: 'research' },
    hint: 'Изучите «Патрициат» и поставьте участок патриция 3×3. Патриции любят красоту и простор и платят много налогов.',
    prog: () => housesAtLeast('domus', 1) },
  { text: 'Соберите 400 жителей', need: 400, reward: { money: 1000 },
    hint: 'Город растёт — покупайте новые участки и украшайте улицы.',
    prog: () => state.stats.pop || 0 },
  { text: 'Постройте виллу патриция', need: 1, reward: { money: 1500 },
    hint: 'Вилле нужны вино, театр, красота 10 и простор вокруг.',
    prog: () => housesAtLeast('domus', 3) },
  { text: 'Станьте Большим городом', need: 900, reward: { money: 1500 },
    hint: 'С 900 жителей открываются «Легион» и знания пятой колонки.',
    prog: () => state.stats.pop || 0 },
  { text: 'Постройте Казармы', need: 1, reward: { money: 500, glory: 5 }, act: { tool: 'barracks' },
    hint: 'Изучите «Легион» в «Знаниях» и поставьте Казармы у дороги. В отряде появятся легионеры.',
    prog: () => countType('barracks') },
  { text: 'Первая победа в походе', need: 1, reward: { money: 600 }, act: { open: 'legion' },
    hint: 'Откройте «Легион» слева, выберите первый бой на карте походов и нажмите «В бой!».',
    prog: () => state.army ? state.army.wins : 0 },
  { text: 'Победите Атамана разбойников', need: 1, reward: { money: 800, glory: 10 }, act: { open: 'legion' },
    hint: 'Последний бой Леса разбойников — босс. Победа откроет «Кипящее масло», Лагерь копейщиков и ещё одно место в отряде. Улучшайте войска во вкладке «Войска».',
    prog: () => state.army ? Math.floor(state.army.progress / STAGES_PER_REGION) : 0 },
  { text: 'Соберите 1500 жителей', need: 1500, reward: { money: 5000 },
    hint: 'Большой город растит и армию: предел уровня войск поднимается до 5.',
    prog: () => state.stats.pop || 0 },
  { text: 'Возведите чудо света', need: 1, reward: { money: 3000, glory: 20 }, act: { open: 'wonders' },
    hint: 'Чудеса открывает рейтинг легиона — он растёт с каждой победой в походах. Откройте «Чудеса» слева: первой будет Триумфальная арка.',
    prog: () => countType('arch') + countType('colosseum') + countType('pantheon') },
];

function cityRank(pop) {
  let r = CITY_RANKS[0][1];
  for (const [n, name] of CITY_RANKS) if (pop >= n) r = name;
  return r;
}

function dateText(day) {
  const year = Math.floor(day / (DAYS_PER_SEASON * 4)) + 1;
  const season = SEASONS[Math.floor(day / DAYS_PER_SEASON) % 4];
  return `Год ${roman(year)} · ${season}`;
}

// Красота от живой природы рядом с домом: деревья и вода
function natureBeauty(h) {
  const cx = h.x + h.w / 2, cy = h.y + h.h / 2, R = 3.5;
  let trees = 0, water = 0;
  for (let ty = Math.floor(cy - R); ty <= cy + R; ty++) {
    for (let tx = Math.floor(cx - R); tx <= cx + R; tx++) {
      const dx = tx + 0.5 - cx, dy = ty + 0.5 - cy;
      if (dx * dx + dy * dy > R * R) continue;
      const n = natureAt(tx, ty);
      if (n >= N_OAK && n <= N_CYPRESS) trees++;
      if (isWater(groundAt(tx, ty))) water++;
    }
  }
  return Math.min(2, trees * 0.25) + Math.min(1.5, water * 0.15);
}

function meetsTier(h, t) {
  const T = tiersOf(h)[t];
  for (const need of T.needs) if (!h.needs[need]) return false;
  if (T.beauty && h.beauty < T.beauty) return false;
  if (T.maxCrowd !== undefined && h.crowd > T.maxCrowd) return false;
  return true;
}

const NEED_HAPPY = { water: 6, food: 8, temple: 5, oil: 4, bread: 4, baths: 5, wine: 4, theatre: 5, forum: 4 };

/* Пересчёт «кто кого обслуживает». Ничего не меняет в развитии —
   вызывается и каждый день, и сразу после стройки для отзывчивого интерфейса. */
function computeCoverage() {
  const S = state.stats;
  const houses = [], beautySrc = [], happySrc = [];
  const residents = { plebs: 0, citizens: 0, patricians: 0 };
  const jobs = { plebs: 0, citizens: 0, patricians: 0 };
  const providers = { water: [], market: [], temple: [], baths: [], theatre: [], forum: [] };

  for (const b of state.buildings.values()) {
    const d = BUILDINGS[b.type];
    if (d.kind === 'road') continue;
    b.road = d.kind === 'decor' ? true : (d.kind === 'house' || d.needsRoad) ? hasRoadAccess(b) : true;
    if (d.kind === 'house') {
      houses.push(b);
      const T = d.tiers[b.tier];
      if (T.cls) residents[T.cls] += b.pop;
      continue;
    }
    if (d.jobs && b.road) for (const [cls, n] of Object.entries(d.jobs)) jobs[cls] += n;
    if (d.beauty) beautySrc.push(b);
    if (d.happy) happySrc.push(b);
  }

  // Каждый класс сначала занимает свои места; лишние граждане идут на работу плебеев,
  // лишние патриции — на работу граждан. Наоборот нельзя: плебей не встанет к печи пекарни.
  const workers = {}, staff = {}, filled = {}, spare = {};
  for (const cls of Object.keys(CLASSES)) {
    workers[cls] = Math.floor(residents[cls] * WORKER_SHARE);
    filled[cls] = Math.min(jobs[cls], workers[cls]);
    spare[cls] = workers[cls] - filled[cls];
  }
  const help = (from, to) => {
    const take = Math.min(jobs[to] - filled[to], spare[from]);
    if (take > 0) { filled[to] += take; spare[from] -= take; }
  };
  help('patricians', 'citizens');
  help('citizens', 'plebs');
  for (const cls of Object.keys(CLASSES)) staff[cls] = jobs[cls] > 0 ? filled[cls] / jobs[cls] : 1;

  for (const b of state.buildings.values()) {
    const d = BUILDINGS[b.type];
    if (d.kind === 'road' || d.kind === 'house' || d.kind === 'decor') continue;
    let st = 1;
    if (d.jobs) for (const cls of Object.keys(d.jobs)) st = Math.min(st, staff[cls]);
    b.staff = b.road ? st : 0;
    let eff = b.staff;
    if (d.deposit) { b.dep = depositFactor(b.type, b.x, b.y); eff *= b.dep.factor; }
    if (d.farmland && hasTech('irrigation')) eff *= 1.33;
    b.eff = eff;
    b.active = b.road && (!d.jobs || b.staff >= 0.25);
    if (d.provides && b.active) providers[d.provides].push(b);
  }

  const foodStock = state.goods.wheat + state.goods.fish;
  const taxHappy = TAX_LEVELS[state.taxLevel].happy;
  const festival = state.day < state.festivalUntil ? FESTIVAL.happy : 0;
  let happySum = 0;
  const happyCls = { plebs: 0, citizens: 0, patricians: 0 };
  for (const h of houses) {
    const n = h.needs = { road: h.road };
    for (const kind of Object.keys(providers)) {
      n[kind] = false;
      for (const p of providers[kind]) {
        const r = BUILDINGS[p.type].radius;
        if (dist2(h, p) <= r * r) { n[kind] = true; break; }
      }
    }
    h.market = n.market;
    n.food = n.market && foodStock > 0.5;
    for (const g of GOOD_NEEDS) n[g] = n.market && state.goods[g] > 0.5;

    let beauty = 0;
    for (const s of beautySrc) if (dist2(h, s) <= BEAUTY_RADIUS * BEAUTY_RADIUS) beauty += BUILDINGS[s.type].beauty;
    h.beauty = Math.round((beauty + natureBeauty(h)) * 10) / 10;

    let crowd = 0;
    for (const o of houses) if (o !== h && o.tier > 0 && dist2(h, o) <= CROWD_RADIUS * CROWD_RADIUS) crowd++;
    h.crowd = crowd;

    const tiers = tiersOf(h);
    let target = 0;
    for (let t = 1; t < tiers.length; t++) { if (meetsTier(h, t)) target = t; else break; }
    h.target = target;

    let hp = 40 + taxHappy + festival;
    for (const [need, v] of Object.entries(NEED_HAPPY)) if (n[need]) hp += v;
    hp += Math.min(20, h.beauty * 2);
    hp -= h.type === 'domus' ? Math.max(0, crowd - 2) * 6 : Math.max(0, crowd - 4) * 3;
    for (const s of happySrc) { const r = BUILDINGS[s.type].radius; if (dist2(h, s) <= r * r) hp += BUILDINGS[s.type].happy; }
    if (h.bonusUntil && state.day < h.bonusUntil) hp += 12;
    h.happy = clamp(Math.round(hp), 0, 100);
    happySum += h.happy * h.pop;
    const cls = h.type === 'house' || h.type === 'domus' ? tiersOf(h)[h.tier].cls : null;
    if (cls) { happyCls[cls] += h.happy * h.pop; }
  }

  let pop = 0;
  for (const cls of Object.keys(residents)) pop += residents[cls];
  S.pop = pop;
  S.residents = residents;
  S.workers = workers;
  S.jobs = jobs;
  S.filled = filled;
  S.spare = spare;
  S.staff = staff;
  S.happy = pop > 0 ? Math.round(happySum / pop) : 0;
  S.happyCls = {};
  for (const c of Object.keys(residents)) S.happyCls[c] = residents[c] ? Math.round(happyCls[c] / residents[c]) : 0;
  S.connectedHouses = houses.filter(h => h.road && h.tier > 0);
  S.cap = storageCap();
}

function taxMult() {
  return TAX_LEVELS[state.taxLevel].mult * (hasTech('taxreform') ? 1.15 : 1);
}

function dailyProgress() {
  const S = state.stats;
  const now = performance.now();
  const cap = S.cap = storageCap();
  const prod = {}, cons = {};
  let scrolls = 0, glory = 0, upkeep = 0;

  // Производство: входные товары → выходные, с учётом штата, залежей и места на складах
  for (const b of state.buildings.values()) {
    const d = BUILDINGS[b.type];
    if (d.upkeep) upkeep += d.upkeep;
    if (d.scrolls && b.active) scrolls += d.scrolls * (d.jobs ? b.staff : 1);
    if (d.glory && b.active) glory += d.glory;
    if (!d.produces) continue;
    let k = b.eff || 0;
    if (d.consumes) for (const [g, r] of Object.entries(d.consumes)) k = Math.min(k, state.goods[g] / r);
    for (const [g, r] of Object.entries(d.produces)) k = Math.min(k, Math.max(0, cap - state.goods[g]) / r);
    k = Math.max(0, k);
    if (d.consumes) for (const [g, r] of Object.entries(d.consumes)) { state.goods[g] -= r * k; cons[g] = (cons[g] || 0) + r * k; }
    for (const [g, r] of Object.entries(d.produces)) { state.goods[g] += r * k; prod[g] = (prod[g] || 0) + r * k; }
    b.output = k;
    b.working = k > 0.01;
  }

  // Потребление домами через рынки
  let taxes = 0;
  const short = {};
  for (const h of state.buildings.values()) {
    if (BUILDINGS[h.type].kind !== 'house') continue;
    const T = tiersOf(h)[h.tier];
    if (h.market && h.pop > 0) {
      const need = h.pop * CONSUMPTION.food;
      const total = state.goods.wheat + state.goods.fish;
      if (total > 0) {
        const take = Math.min(need, total);
        const fw = state.goods.wheat / total;
        state.goods.wheat -= take * fw;
        state.goods.fish -= take * (1 - fw);
        cons.wheat = (cons.wheat || 0) + take * fw;
        cons.fish = (cons.fish || 0) + take * (1 - fw);
        if (take < need) short.food = true;
      } else short.food = true;
      for (const g of GOOD_NEEDS) {
        if (!T.needs.includes(g)) continue;
        const want = h.pop * CONSUMPTION[g];
        const take = Math.min(want, state.goods[g]);
        state.goods[g] -= take;
        cons[g] = (cons[g] || 0) + take;
        if (take < want) short[g] = true;
      }
    }
    taxes += h.pop * T.tax * (0.7 + h.happy / 200);
  }
  taxes *= taxMult();

  for (const g of GOOD_IDS) state.goods[g] = clamp(state.goods[g], 0, cap);

  state.money += taxes - upkeep;
  state.scrolls += scrolls;
  state.glory += glory;
  S.taxes = taxes;
  S.upkeep = upkeep;
  S.income = taxes - upkeep;
  S.prod = prod;
  S.cons = cons;
  S.scrollRate = scrolls;
  S.gloryRate = glory;

  // Нехватки не всплывают на экран: они видны «тревогами» под верхней панелью и пишутся в журнал
  S.short = short;
  state.warnDays = state.warnDays || {};
  for (const g of Object.keys(short)) {
    if (state.day < (state.warnDays[g] || 0)) continue;
    state.warnDays[g] = state.day + 60;
    UI.log(SHORTAGE[g].journal, 'warn');
  }

  // Рост и упадок домов
  for (const h of state.buildings.values()) {
    if (BUILDINGS[h.type].kind !== 'house') continue;
    const tiers = tiersOf(h);
    if (h.tier === 0) {
      if (h.target >= 1) {
        h.up++;
        if (h.up >= 2) { h.tier = 1; h.up = 0; onHouseChanged(h, true, now); }
      } else h.up = 0;
    } else if (h.target > h.tier && !h.lock) {
      h.up++; h.down = 0;
      if (h.up >= 3) { h.tier++; h.up = 0; onHouseChanged(h, true, now); }
    } else if (h.target < h.tier) {
      h.down++; h.up = 0;
      if (h.down >= 12) { h.tier--; h.down = 0; onHouseChanged(h, false, now); }
    } else { h.up = 0; h.down = 0; }

    const capPop = tiers[h.tier].cap;
    if (h.pop < capPop) h.pop = Math.min(capPop, h.pop + (h.tier >= 3 ? 2 : 1));
    else if (h.pop > capPop) h.pop = Math.max(capPop, h.pop - 2);
  }

  if (state.money < 0 && state.day >= (state.debtWarnDay || 0)) {
    state.debtWarnDay = state.day + 30;
    UI.log('Казна ушла в минус: содержание построек дороже налогов.', 'warn');
  }
}

const SHORTAGE = {
  food: { label: 'Нет еды', journal: 'Еда на складах кончилась.', tip: 'Еда кончилась: рынки не могут кормить дома. Постройте ещё пшеничное поле или рыбацкую хижину у воды.', tool: 'farm' },
  oil: { label: 'Нет масла', journal: 'Масло кончилось.', tip: 'Масло кончилось — инсулы начнут пустеть. Нужны ещё оливковая роща и маслодавильня.', tool: 'oilpress' },
  bread: { label: 'Нет хлеба', journal: 'Хлеб кончился.', tip: 'Хлеб кончился. Постройте ещё пекарню, а для неё — пшеничное поле.', tool: 'bakery' },
  wine: { label: 'Нет вина', journal: 'Вино кончилось.', tip: 'Вино кончилось. Нужны ещё виноградник и винодельня.', tool: 'winery' },
};

function onHouseChanged(h, up, now) {
  h.animAt = now;
  h.rot = orientToRoad(h);
  Engine.buildingsChanged(h);
  const T = tiersOf(h)[h.tier];
  if (up) {
    UI.floatText(h.x + h.w / 2, T.height + 0.4, h.y + h.h / 2, `↑ ${T.name}`, 'good');
    Engine.sparkle(h, T.height);
  }
  const key = h.type + h.tier;
  if (up && h.tier >= 2 && !state.firsts.includes(key)) {
    state.firsts.push(key);
    UI.log(`Первый дом уровня «${T.name}» в городе!`, 'good', true);
  }
  if (!up) UI.log(`Дом опустился до уровня «${T.name}».`, 'warn', false, h);
}

/* ---------- Просьбы жителей ---------- */

function requestSatisfied(h, type) {
  for (const b of state.buildings.values()) {
    if (b.type === type && dist2(h, b) <= REQUEST_RADIUS * REQUEST_RADIUS) return true;
  }
  return false;
}

function requestReward(type) {
  return Math.round((40 + (BUILDINGS[type].cost.money || 0) * 0.6) / 5) * 5;
}

function updateRequests() {
  for (const h of state.buildings.values()) {
    if (!h.req) continue;
    if (requestSatisfied(h, h.req.type)) {
      const reward = requestReward(h.req.type);
      state.money += reward;
      h.bonusUntil = state.day + 90;
      const T = tiersOf(h)[h.tier];
      UI.floatText(h.x + h.w / 2, T.height + 0.7, h.y + h.h / 2, `Спасибо! +${reward}`, 'gold');
      Engine.sparkle(h, T.height);
      UI.log(`Просьба выполнена: ${BUILDINGS[h.req.type].name.toLowerCase()} рядом с домом. +${reward} денариев`, 'good', true);
      h.req = null;
    } else if (state.day > h.req.until) {
      h.req = null;
    }
  }

  if (state.day < state.nextRequestDay || (state.stats.pop || 0) < 12) return;
  state.nextRequestDay = state.day + 20 + Math.floor(Math.random() * 30);
  const candidates = state.stats.connectedHouses.filter(h => !h.req);
  if (!candidates.length) return;
  const h = pick(candidates);
  const options = REQUEST_POOL.filter(r => r.minTier <= h.tier && isUnlocked(r.type) && !requestSatisfied(h, r.type));
  if (!options.length) return;
  h.req = { type: pick(options).type, until: state.day + 150 };
}

/* ---------- Задачи ---------- */

function giveReward(r) {
  for (const [k, v] of Object.entries(r)) {
    if (k === 'money') state.money += v;
    else if (k === 'glory') state.glory += v;
    else if (k === 'scrolls') state.scrolls += v;
    else state.goods[k] = (state.goods[k] || 0) + v;
  }
}

function rewardText(r) {
  return Object.entries(r).map(([k, v]) => `${fmt(v)} ${k === 'money' ? 'ден.' : k === 'glory' ? 'Славы' : k === 'scrolls' ? 'свитков' : GOODS[k].name.toLowerCase()}`).join(', ');
}

function checkGoals() {
  const g = GOALS[state.goalIndex];
  if (!g) return;
  if (g.prog() >= g.need) {
    giveReward(g.reward);
    UI.log(`Задача «${g.text}» выполнена. Награда: ${rewardText(g.reward)}`, 'good', true);
    state.goalIndex++;
    Advisor.goalDone();
  }
}

function simDay() {
  state.day++;
  computeCoverage();
  dailyProgress();
  Army.daily();
  Trade.daily();
  researchDay();
  computeCoverage();
  updateRequests();
  checkGoals();
  Advisor.daily();
  UI.refreshPanel();
}

// После любой стройки или сноса — сразу обновить подсказки
function afterCityChanged() {
  computeCoverage();
  checkGoals();
  UI.refreshPanel();
}

/* ---------- Исследования ---------- */

// done — изучено, active — изучается, locked — сначала другие знания, pop — мало жителей, open — можно начать
function techState(t) {
  if (hasTech(t.id)) return 'done';
  if (state.research && state.research.id === t.id) return 'active';
  if (!t.req.every(hasTech)) return 'locked';
  if ((state.stats.pop || 0) < t.pop) return 'pop';
  return 'open';
}

// Первое знание — в подарок: город только учится
function techCost(t) {
  return !state.techs.length && !state.research ? { scrolls: 0, money: 0, free: true } : { scrolls: t.scrolls, money: t.money };
}

// Какое знание советник подсвечивает: «Оливководство», пока его ждут задачи
function recommendedTech() {
  if (hasTech('olives') || (state.research && state.research.id === 'olives')) return null;
  const g = GOALS[state.goalIndex];
  return !state.techs.length || (g && g.techGoal === 'olives') || (g && g.act && g.act.tool === 'grove') ? 'olives' : null;
}

function canResearch(t) {
  const c = techCost(t);
  return techState(t) === 'open' && !state.research && state.scrolls >= c.scrolls && state.money >= c.money;
}

// Начать изучение: свитки и денарии списываются сразу, знание приходит через t.days дней
function research(id) {
  const t = TECH_BY_ID[id];
  if (!canResearch(t)) return false;
  const c = techCost(t);
  state.scrolls -= c.scrolls;
  state.money -= c.money;
  state.research = { id, left: t.days };
  UI.log(`Начали изучать «${t.name}»${c.free ? ' — первое знание в подарок' : ''}. Будет готово через ${t.days} ${plural(t.days, 'день', 'дня', 'дней')}.`, 'info');
  UI.updateHud(true);
  return true;
}

function researchDay() {
  const r = state.research;
  if (!r || --r.left > 0) return;
  state.research = null;
  const t = TECH_BY_ID[r.id];
  state.techs.push(t.id);
  const opened = Object.entries(BUILDINGS).filter(([, d]) => d.tech === t.id).map(([, d]) => d.name);
  UI.log(opened.length ? `Изучено «${t.name}». Открыто: ${opened.join(', ')}` : `Изучено «${t.name}»`, 'good', true);
  UI.buildToolbar();
  afterCityChanged();
  if (UI.winOpen && UI.winTab === 'research') UI.renderWindow();
}

/* ---------- Торговля ---------- */

const Trade = {
  active() {
    for (const b of state.buildings.values()) if (b.type === 'tradepost' && b.active) return true;
    return false;
  },

  daily() {
    if (state.day < state.nextTradeDay) return;
    state.nextTradeDay = state.day + TRADE_INTERVAL;
    if (!this.active()) return;
    const cap = storageCap();
    let earned = 0, spent = 0;
    for (const g of GOOD_IDS) {
      const price = GOODS[g].price;
      if (state.trade.sell[g] && state.goods[g] > cap * 0.6) {
        const n = Math.floor(Math.min(40, state.goods[g] - cap * 0.6));
        state.goods[g] -= n;
        earned += n * price;
      }
      if (state.trade.buy[g] && state.goods[g] < cap * 0.15) {
        const n = Math.floor(Math.min(30, cap * 0.3 - state.goods[g], (state.money - spent) / (price * 1.6)));
        if (n > 0) { state.goods[g] += n; spent += n * price * 1.6; }
      }
    }
    state.money += earned - spent;
    if (earned || spent) UI.log(`Пришёл караван: продано на ${fmt(earned)}, куплено на ${fmt(spent)} денариев.`, 'info');
  },
};
