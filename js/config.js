'use strict';
/* =========================================================
   CivCity — настройки игры: ресурсы, постройки, дома, исследования, походы.
   Все числа баланса живут здесь, чтобы их было легко крутить.
   ========================================================= */

const PLOT = 24;                 // участок земли — 24×24 клетки
// Тестовый город: адрес с #test — отдельное сохранение, всё открыто (js/test.js)
function isTestUrl() { return ['#test', '?test', '#promo'].some(k => (location.hash + location.search).includes(k)); }
const TEST_MODE = isTestUrl();
// город для съёмок рекламного ролика (js/promo.js): своё сохранение, дни не идут, жители гуляют
const PROMO_MODE = (location.hash + location.search).includes('#promo');

const DAY_SECONDS = 4;           // длина игрового дня при скорости ×1
const DAYS_PER_SEASON = 30;
const ROAD_TOP = 0.05;           // высота камней мостовой: на ней стоят жители и кошки
const SEASONS = ['весна', 'лето', 'осень', 'зима'];

const START_MONEY = 3000;
const START_GOODS = { wheat: 40 };
const START_SCROLLS = 8;
const BASE_STORAGE = 200;        // сколько каждого товара помещается без складов
const WAREHOUSE_STORAGE = 300;   // +к вместимости за каждый склад
const WORKER_SHARE = 0.5;        // доля жителей, которые работают
const REFUND_SHARE = 0.5;        // сколько возвращается при сносе
const REQUEST_RADIUS = 7;        // в каком радиусе от дома должна стоять просьба
const BEAUTY_RADIUS = 6;         // украшения в этом радиусе радуют дом
const CROWD_RADIUS = 3.5;        // дома ближе этого считаются соседями (теснота)
const TRADE_INTERVAL = 10;       // раз в сколько дней приходит караван (докупает нехватку — нужен торговый пост)
const TRADE_RESERVE = 40;        // столько каждого товара купцы оставляют на складе, остальное покупают
const TRADE_PRICE_LOCAL = 0.75;  // без торгового поста купцы платят три четверти цены
// что купцы покупают, пока игрок не решил иначе: стройматериалы и сырьё — городу они больше не нужны для стройки
const SELL_DEFAULT = ['wood', 'stone', 'clay', 'bricks', 'marble', 'iron'];
const WATER_LEVEL = 0.3;         // порог шума, ниже которого — озеро

// Сколько товара съедает один житель в день
const CONSUMPTION = { food: 0.06, oil: 0.03, bread: 0.04, wine: 0.04 };

const TAX_LEVELS = [
  { name: 'Низкие', mult: 0.7, happy: 8 },
  { name: 'Обычные', mult: 1, happy: 0 },
  { name: 'Высокие', mult: 1.35, happy: -12 },
];

// Типы земли: 0–3 — оттенки травы
const G_SAND = 4, G_WATER = 5, G_DEEP = 6;
// Природа и залежи на клетке
const N_OAK = 1, N_PINE = 2, N_CYPRESS = 3, N_BUSH = 4, N_ROCK = 5, N_FLOWERS = 6,
  N_STONE = 7, N_MARBLE = 8, N_IRON = 9;
const DEPOSIT_OF = { trees: [N_OAK, N_PINE, N_CYPRESS], stone: [N_STONE, N_ROCK], marble: [N_MARBLE], iron: [N_IRON] };

/* ---------- Товары ---------- */

const GOODS = {
  wheat: { name: 'Пшеница', price: 2, food: true },
  fish: { name: 'Рыба', price: 3, food: true },
  olives: { name: 'Оливки', price: 3 },
  grapes: { name: 'Виноград', price: 3 },
  bread: { name: 'Хлеб', price: 6 },
  oil: { name: 'Масло', price: 7 },
  wine: { name: 'Вино', price: 9 },
  wood: { name: 'Дерево', price: 3 },
  stone: { name: 'Камень', price: 4 },
  clay: { name: 'Глина', price: 2 },
  bricks: { name: 'Кирпич', price: 6 },
  marble: { name: 'Мрамор', price: 16 },
  iron: { name: 'Железо', price: 8 },
  weapons: { name: 'Оружие', price: 18 },
};
const GOOD_IDS = Object.keys(GOODS);

// color — цвет класса в интерфейсе: карточки построек, жители, подсказки
const CLASSES = {
  plebs: { name: 'Плебеи', gen: 'плебеев', one: 'плебей', color: '#6b8a2f', soft: '#e7efd2', work: 'поля, рощи, карьеры, рынки, храмы' },
  citizens: { name: 'Граждане', gen: 'граждан', one: 'гражданин', color: '#2f6f9a', soft: '#dcebf5', work: 'пекарни, кузницы, винодельни, термы, школы, казармы' },
  patricians: { name: 'Патриции', gen: 'патрициев', one: 'патриций', color: '#7a3f8c', soft: '#efe1f3', work: 'театр и форум' },
};

/* ---------- Дома ----------
   Дом поднимается на следующий уровень, когда выполнены все needs,
   красота ≥ beauty и соседних домов не больше maxCrowd. */

const PLEB_TIERS = [
  { name: 'Пустой участок', cap: 0, tax: 0, needs: [], height: 0.3 },
  { name: 'Хижина', cls: 'plebs', cap: 4, tax: 0.12, needs: ['road'], height: 1.0 },
  { name: 'Домик', cls: 'plebs', cap: 8, tax: 0.16, needs: ['road', 'water', 'food'], height: 1.1 },
  { name: 'Инсула', cls: 'citizens', cap: 16, tax: 0.3, needs: ['road', 'water', 'food', 'temple', 'oil'], beauty: 2, height: 1.5 },
  { name: 'Большая инсула', cls: 'citizens', cap: 26, tax: 0.36, needs: ['road', 'water', 'food', 'temple', 'oil', 'bread', 'baths'], beauty: 5, height: 2.4 },
];

const PATRICIAN_TIERS = [
  { name: 'Участок патриция', cap: 0, tax: 0, needs: [], height: 0.3 },
  { name: 'Домус', cls: 'patricians', cap: 6, tax: 1.2, needs: ['road', 'water', 'food', 'temple'], beauty: 3, height: 1.2 },
  { name: 'Богатый домус', cls: 'patricians', cap: 9, tax: 1.4, needs: ['road', 'water', 'food', 'temple', 'oil', 'bread', 'baths'], beauty: 6, height: 1.3 },
  { name: 'Вилла', cls: 'patricians', cap: 12, tax: 1.7, needs: ['road', 'water', 'food', 'temple', 'oil', 'bread', 'baths', 'wine', 'theatre'], beauty: 10, maxCrowd: 3, height: 1.4 },
  { name: 'Дворец', cls: 'patricians', cap: 16, tax: 2.2, needs: ['road', 'water', 'food', 'temple', 'oil', 'bread', 'baths', 'wine', 'theatre', 'forum'], beauty: 16, maxCrowd: 2, height: 2.0 },
];

const NEED_LABELS = {
  road: 'Дорога вплотную к дому',
  water: 'Вода: колодец или фонтан',
  food: 'Еда: рынок и пшеница или рыба',
  temple: 'Храм поблизости',
  oil: 'Оливковое масло на рынке',
  bread: 'Хлеб на рынке',
  baths: 'Термы поблизости',
  wine: 'Вино на рынке',
  theatre: 'Театр поблизости',
  forum: 'Форум поблизости',
};
// «Не хватает …» — родительный падеж
const NEED_GENITIVE = {
  road: 'дороги', water: 'воды', food: 'еды', temple: 'храма', oil: 'масла', bread: 'хлеба', baths: 'терм',
  wine: 'вина', theatre: 'театра', forum: 'форума', beauty: 'красоты', crowd: 'простора',
};
const GOOD_NEEDS = ['oil', 'bread', 'wine'];   // эти потребности берутся со склада через рынок

/* ---------- Постройки ----------
   kind: road | house | producer | service | storage | military | wonder | decor
   cost — денарии (money), у чудес — ещё материалы со складов и Слава; jobs — сколько работников какого класса нужно;
   produces / consumes — товаров в день при полном штате;
   provides — какую потребность дома закрывает в радиусе radius;
   deposit — от чего зависит добыча (деревья, камень, мрамор, железо рядом);
   tech — какое исследование открывает постройку. */

const BUILDINGS = {
  road: { kind: 'road', cat: 'roads', name: 'Дорога', acc: 'дорогу', cost: { money: 3 }, w: 1, h: 1,
    desc: 'Мостовая кистью: тропинка, гравий, камень или площадь — сколько угодно и где угодно. Дома и мастерские встают вдоль неё сами и прямо на неё.' },

  // Центр города: один на город, ставится сам и растёт вместе со званием города (CENTER_STAGES).
  // Сюда приходят переселенцы, отсюда расходятся по свободным домам; здесь жители оставляют просьбы
  center: { kind: 'service', name: 'Центр города', acc: 'центр города', cost: { money: 0 }, w: 4, h: 4, unique: true, center: true,
    beauty: 3, needsRoad: true,
    desc: 'Сердце города: сюда приходят переселенцы и отсюда расходятся по свободным домам, здесь жители оставляют просьбы. Растёт сам вместе со званием города, а с ним растёт и казна.' },

  house: { kind: 'house', cat: 'housing', name: 'Дом плебеев', acc: 'дом', cost: { money: 20 }, w: 2, h: 2, tiers: PLEB_TIERS,
    desc: 'Растёт из хижины в многоэтажную инсулу. Хижины и домики дают плебеев, инсулы — граждан.' },
  domus: { kind: 'house', cat: 'housing', name: 'Участок патриция', acc: 'домус', cost: { money: 310 }, w: 3, h: 3, tiers: PATRICIAN_TIERS, tech: 'patricians',
    desc: 'Богатые семьи строят домус, виллу, а потом и дворец. Платят много налогов, любят простор и красоту.' },

  farm: { kind: 'producer', cat: 'food', name: 'Пшеничное поле', acc: 'поле', cost: { money: 110 }, w: 3, h: 3,
    jobs: { plebs: 4 }, upkeep: 0.5, produces: { wheat: 6 }, needsRoad: true, farmland: true,
    desc: 'Выращивает пшеницу — основную еду и сырьё для пекарен.' },
  fishery: { kind: 'producer', cat: 'food', name: 'Рыбацкая хижина', acc: 'рыбацкую хижину', cost: { money: 95 }, w: 2, h: 2,
    jobs: { plebs: 2 }, upkeep: 0.4, produces: { fish: 4 }, needsRoad: true, needsWater: true,
    desc: 'Ловит рыбу. Ставится у берега озера.' },
  grove: { kind: 'producer', cat: 'food', name: 'Оливковая роща', acc: 'оливковую рощу', cost: { money: 95 }, w: 3, h: 3,
    jobs: { plebs: 3 }, upkeep: 0.5, produces: { olives: 4 }, needsRoad: true, farmland: true, tech: 'olives',
    desc: 'Даёт оливки для маслодавильни.' },
  vineyard: { kind: 'producer', cat: 'food', name: 'Виноградник', acc: 'виноградник', cost: { money: 130 }, w: 3, h: 3,
    jobs: { plebs: 3 }, upkeep: 0.5, produces: { grapes: 4 }, needsRoad: true, farmland: true, tech: 'wine',
    desc: 'Даёт виноград для винодельни.' },
  bakery: { kind: 'producer', cat: 'food', name: 'Пекарня', acc: 'пекарню', cost: { money: 260 }, w: 2, h: 2,
    jobs: { citizens: 3 }, upkeep: 0.8, consumes: { wheat: 4 }, produces: { bread: 4 }, needsRoad: true, tech: 'baking',
    desc: 'Печёт хлеб из пшеницы. Хлеб нужен большим инсулам и патрициям.' },
  oilpress: { kind: 'producer', cat: 'food', name: 'Маслодавильня', acc: 'маслодавильню', cost: { money: 230 }, w: 2, h: 2,
    jobs: { plebs: 3 }, upkeep: 0.8, consumes: { olives: 3 }, produces: { oil: 3 }, needsRoad: true, tech: 'olives',
    desc: 'Давит оливки в масло. Без масла дом не станет инсулой.' },
  winery: { kind: 'producer', cat: 'food', name: 'Винодельня', acc: 'винодельню', cost: { money: 330 }, w: 2, h: 2,
    jobs: { citizens: 3 }, upkeep: 1, consumes: { grapes: 3 }, produces: { wine: 3 }, needsRoad: true, tech: 'wine',
    desc: 'Делает вино. Без вина патриции не построят виллу.' },
  market: { kind: 'service', cat: 'food', name: 'Рынок', acc: 'рынок', cost: { money: 190 }, w: 3, h: 3,
    jobs: { plebs: 3 }, upkeep: 1, radius: 14, provides: 'market', needsRoad: true, beauty: 1,
    desc: 'Раздаёт еду, масло, хлеб и вино домам вокруг.' },

  lumber: { kind: 'producer', cat: 'industry', name: 'Лесопилка', acc: 'лесопилку', cost: { money: 40 }, w: 2, h: 2,
    jobs: { plebs: 3 }, upkeep: 0.3, produces: { wood: 4 }, needsRoad: true, deposit: 'trees', depositRadius: 5, depositNeed: 10,
    desc: 'Пилит дерево — на продажу купцам и для кузницы. Чем больше деревьев вокруг, тем больше досок. Деревья не вырубаются.' },
  quarry: { kind: 'producer', cat: 'industry', name: 'Каменоломня', acc: 'каменоломню', cost: { money: 85 }, w: 2, h: 2,
    jobs: { plebs: 4 }, upkeep: 0.4, produces: { stone: 3 }, needsRoad: true, deposit: 'stone', depositRadius: 3, depositNeed: 5,
    desc: 'Добывает камень — его покупают купцы. Ставьте рядом с серыми скалами.' },
  claypit: { kind: 'producer', cat: 'industry', name: 'Глиняный карьер', acc: 'глиняный карьер', cost: { money: 75 }, w: 2, h: 2,
    jobs: { plebs: 3 }, upkeep: 0.4, produces: { clay: 4 }, needsRoad: true, needsWater: true, tech: 'bricks',
    desc: 'Копает глину у воды.' },
  brickworks: { kind: 'producer', cat: 'industry', name: 'Кирпичная мастерская', acc: 'кирпичную мастерскую', cost: { money: 290 }, w: 2, h: 2,
    jobs: { plebs: 3 }, upkeep: 0.8, consumes: { clay: 3 }, produces: { bricks: 3 }, needsRoad: true, tech: 'bricks',
    desc: 'Обжигает глину в кирпич — для чудес света и на продажу купцам.' },
  marblequarry: { kind: 'producer', cat: 'industry', name: 'Мраморный карьер', acc: 'мраморный карьер', cost: { money: 290 }, w: 3, h: 3,
    jobs: { plebs: 5 }, upkeep: 1, produces: { marble: 2 }, needsRoad: true, deposit: 'marble', depositRadius: 4, depositNeed: 6, tech: 'marble',
    desc: 'Добывает мрамор — для чудес света, купцы платят за него дорого. Белые скалы встречаются редко — ищите их на новых участках.' },
  mine: { kind: 'producer', cat: 'industry', name: 'Железный рудник', acc: 'рудник', cost: { money: 240 }, w: 2, h: 2,
    jobs: { plebs: 4 }, upkeep: 0.8, produces: { iron: 2 }, needsRoad: true, deposit: 'iron', depositRadius: 3, depositNeed: 4, tech: 'metal',
    desc: 'Добывает железо из рыжих скал.' },
  smithy: { kind: 'producer', cat: 'industry', name: 'Кузница', acc: 'кузницу', cost: { money: 440 }, w: 2, h: 2,
    jobs: { citizens: 3 }, upkeep: 1, consumes: { iron: 2, wood: 1 }, produces: { weapons: 2 }, needsRoad: true, tech: 'metal',
    desc: 'Куёт мечи и щиты для легиона.' },
  warehouse: { kind: 'storage', cat: 'industry', name: 'Склад', acc: 'склад', cost: { money: 170 }, w: 2, h: 2,
    jobs: { plebs: 2 }, upkeep: 0.5, storage: WAREHOUSE_STORAGE, needsRoad: true,
    desc: `Хранилище. Каждый склад вмещает ещё ${WAREHOUSE_STORAGE} каждого товара, а купцы покупают здесь излишки.` },
  tradepost: { kind: 'service', cat: 'industry', name: 'Торговый пост', acc: 'торговый пост', cost: { money: 620 }, w: 3, h: 3,
    jobs: { plebs: 3 }, upkeep: 1.5, needsRoad: true, tech: 'trade',
    desc: 'Купцы платят полную цену за излишки, а раз в 10 дней караван докупает то, чего не хватает.' },

  well: { kind: 'service', cat: 'services', name: 'Колодец', acc: 'колодец', cost: { money: 70 }, w: 1, h: 1,
    radius: 7, provides: 'water', upkeep: 0.1,
    desc: 'Даёт воду домам поблизости. Дорога не нужна.' },
  fountain: { kind: 'service', cat: 'services', name: 'Фонтан', acc: 'фонтан', cost: { money: 270 }, w: 2, h: 2,
    radius: 11, provides: 'water', beauty: 3, upkeep: 0.3, tech: 'gardens',
    desc: 'Вода для целого квартала и украшение площади.' },
  temple: { kind: 'service', cat: 'services', name: 'Храм Юпитера', acc: 'храм', cost: { money: 520 }, w: 3, h: 3,
    jobs: { plebs: 2 }, upkeep: 1, radius: 16, provides: 'temple', beauty: 2, scrolls: 0.5, needsRoad: true,
    desc: 'Жрецы благословляют дома и пишут свитки для исследований.' },
  school: { kind: 'service', cat: 'services', name: 'Школа', acc: 'школу', cost: { money: 430 }, w: 2, h: 2,
    jobs: { citizens: 3 }, upkeep: 1, scrolls: 2, needsRoad: true, tech: 'schooling',
    desc: 'Учителя-грамматики пишут свитки для исследований.' },

  baths: { kind: 'service', cat: 'culture', name: 'Термы', acc: 'термы', cost: { money: 880 }, w: 3, h: 3,
    jobs: { citizens: 4 }, upkeep: 2, radius: 15, provides: 'baths', beauty: 2, needsRoad: true, tech: 'baths',
    desc: 'Римские бани с куполами. Нужны большим инсулам и патрициям.' },
  theatre: { kind: 'service', cat: 'culture', name: 'Театр', acc: 'театр', cost: { money: 1000 }, w: 4, h: 4,
    jobs: { patricians: 2 }, upkeep: 2, radius: 16, provides: 'theatre', beauty: 3, needsRoad: true, tech: 'theatre',
    desc: 'Комедии и трагедии. Без театра патриции не построят виллу.' },
  forum: { kind: 'service', cat: 'culture', name: 'Форум', acc: 'форум', cost: { money: 3200 }, w: 4, h: 4,
    jobs: { patricians: 4 }, upkeep: 3, radius: 20, provides: 'forum', beauty: 5, scrolls: 4, needsRoad: true, tech: 'forum',
    desc: 'Сердце города: базилика, колоннада и трибуна. Даёт свитки, нужен для дворцов.' },
  colosseum: { kind: 'wonder', cat: 'culture', name: 'Колизей', acc: 'Колизей', cost: { money: 4000, bricks: 200, marble: 150, glory: 50 }, w: 6, h: 6,
    upkeep: 4, radius: 26, provides: 'theatre', beauty: 15, happy: 10, glory: 0.3, needsRoad: true, rating: 120, unique: true,
    desc: 'Чудо света. Гладиаторские игры радуют весь город и приносят Славу.' },
  pantheon: { kind: 'wonder', cat: 'culture', name: 'Пантеон', acc: 'Пантеон', cost: { money: 3000, marble: 120, bricks: 80, glory: 30 }, w: 4, h: 4,
    upkeep: 3, radius: 24, provides: 'temple', beauty: 12, scrolls: 3, glory: 0.2, needsRoad: true, rating: 250, unique: true,
    desc: 'Чудо света. Храм всех богов с огромным куполом.' },
  arch: { kind: 'wonder', cat: 'culture', name: 'Триумфальная арка', acc: 'триумфальную арку', cost: { money: 800, marble: 40, glory: 25 }, w: 2, h: 2,
    upkeep: 0.5, beauty: 8, happy: 4, radius: 10, rating: 30, unique: true,
    desc: 'Память о победах легиона. Очень красиво.' },

  // VIP-постройки: открываются рейтингом легиона, стоят денарии и Славу (решение владельца) — роскошь для богатого города
  nymphaeum: { kind: 'service', cat: 'culture', name: 'Нимфей', acc: 'нимфей', cost: { money: 1800, glory: 15 }, w: 3, h: 3, vip: true,
    radius: 16, provides: 'water', beauty: 9, happy: 3, upkeep: 1.5, rating: 20, unique: true,
    desc: 'Огромный фонтан-святилище нимф: полукруг ниш со статуями, каскады и бассейн. Вода и радость для большого квартала.' },
  greattemple: { kind: 'service', cat: 'culture', name: 'Храм Венеры и Ромы', acc: 'храм Венеры и Ромы', cost: { money: 2600, glory: 25 }, w: 4, h: 4, vip: true,
    jobs: { citizens: 3 }, radius: 26, provides: 'temple', beauty: 12, scrolls: 2, upkeep: 2.5, rating: 60, unique: true, needsRoad: true,
    desc: 'Самый большой храм Рима: колоннада со всех сторон, золото на крыше. Благословляет полгорода и пишет свитки.' },
  thermae: { kind: 'service', cat: 'culture', name: 'Большие термы', acc: 'большие термы', cost: { money: 4500, glory: 40 }, w: 5, h: 5, vip: true,
    jobs: { citizens: 6 }, radius: 28, provides: 'baths', beauty: 12, happy: 6, upkeep: 4, rating: 150, unique: true, needsRoad: true,
    desc: 'Термы императоров: залы под куполами, бассейн под открытым небом и палестра с колоннадой. Счастье всего города.' },

  barracks: { kind: 'military', cat: 'army', name: 'Казармы', acc: 'казармы', cost: { money: 950 }, w: 3, h: 3,
    upkeep: 2, needsRoad: true, tech: 'legion', unique: true,
    desc: 'Открывает легионеров. Отряд, прокачка и походы — в окне «Легион».' },
  range: { kind: 'military', cat: 'army', name: 'Стрельбище', acc: 'стрельбище', cost: { money: 720 }, w: 3, h: 3,
    upkeep: 2, needsRoad: true, tech: 'legion', unique: true,
    desc: 'Мишени и навесы: открывает лучников. Прокачка — в окне «Легион».' },
  spearcamp: { kind: 'military', cat: 'army', name: 'Лагерь копейщиков', acc: 'лагерь копейщиков', cost: { money: 1050 }, w: 3, h: 3,
    upkeep: 2, needsRoad: true, tech: 'legion', boss: 1, unique: true,
    desc: 'Палатки и чучела для учёбы: открывает копейщиков в тяжёлой броне.' },
  ballistae: { kind: 'military', cat: 'army', name: 'Мастерская баллист', acc: 'мастерскую баллист', cost: { money: 1450 }, w: 3, h: 3,
    upkeep: 3, needsRoad: true, tech: 'legion', boss: 3, unique: true,
    desc: 'Мастера собирают баллисты: болт пробивает строй врагов насквозь.' },
  catapults: { kind: 'military', cat: 'army', name: 'Мастерская катапульт', acc: 'мастерскую катапульт', cost: { money: 1750 }, w: 3, h: 3,
    upkeep: 3, needsRoad: true, tech: 'legion', boss: 5, unique: true,
    desc: 'Здесь строят онагры: камень накрывает толпу врагов.' },

  flowers: { kind: 'decor', cat: 'decor', name: 'Клумба', acc: 'клумбу', cost: { money: 10 }, w: 1, h: 1, beauty: 1, desc: 'Цветы у порога.' },
  cypress: { kind: 'decor', cat: 'decor', name: 'Кипарис', acc: 'кипарис', cost: { money: 8 }, w: 1, h: 1, beauty: 1, desc: 'Стройное дерево Средиземноморья.' },
  pine: { kind: 'decor', cat: 'decor', name: 'Пиния', acc: 'пинию', cost: { money: 10 }, w: 1, h: 1, beauty: 1, desc: 'Итальянская сосна-зонтик.' },
  bench: { kind: 'decor', cat: 'decor', name: 'Скамья', acc: 'скамью', cost: { money: 25 }, w: 1, h: 1, beauty: 1, desc: 'Мраморная скамья для отдыха.' },
  amphorae: { kind: 'decor', cat: 'decor', name: 'Амфоры', acc: 'амфоры', cost: { money: 12 }, w: 1, h: 1, beauty: 1, desc: 'Глиняные кувшины у стены.' },
  olive: { kind: 'decor', cat: 'decor', name: 'Олива', acc: 'оливу', cost: { money: 12 }, w: 1, h: 1, beauty: 1, tech: 'gardens', desc: 'Серебристое оливковое дерево.' },
  lamp: { kind: 'decor', cat: 'decor', name: 'Жаровня', acc: 'жаровню', cost: { money: 25 }, w: 1, h: 1, beauty: 1, tech: 'gardens', desc: 'Бронзовая жаровня с огнём.' },
  pergola: { kind: 'decor', cat: 'decor', name: 'Пергола', acc: 'перголу', cost: { money: 55 }, w: 1, h: 1, beauty: 2, tech: 'gardens', desc: 'Навес, увитый виноградом.' },
  mosaic: { kind: 'decor', cat: 'decor', name: 'Мозаика', acc: 'мозаику', cost: { money: 45 }, w: 1, h: 1, beauty: 2, tech: 'gardens', desc: 'Узорная мостовая из цветных камешков.' },
  statue: { kind: 'decor', cat: 'decor', name: 'Статуя', acc: 'статую', cost: { money: 290 }, w: 1, h: 1, beauty: 4, tech: 'marble', desc: 'Мраморный гражданин на постаменте.' },
  column: { kind: 'decor', cat: 'decor', name: 'Колонна', acc: 'колонну', cost: { money: 220 }, w: 1, h: 1, beauty: 3, tech: 'marble', desc: 'Памятная колонна с золотым шаром.' },
  obelisk: { kind: 'decor', cat: 'decor', name: 'Обелиск', acc: 'обелиск', cost: { money: 270, glory: 10 }, w: 1, h: 1, beauty: 6, tech: 'triumph', desc: 'Трофей из Египта.' },
  // ---- свет: светят ночью
  lantern: { kind: 'decor', cat: 'decor', name: 'Фонарь', acc: 'фонарь', cost: { money: 40 }, w: 1, h: 1, beauty: 1, fp: 0.4, desc: 'Бронзовый фонарь на столбе — светит всю ночь.' },
  torch: { kind: 'decor', cat: 'decor', name: 'Факел', acc: 'факел', cost: { money: 20 }, w: 1, h: 1, beauty: 1, fp: 0.35, desc: 'Факел на кованой стойке.' },
  bigtorch: { kind: 'decor', cat: 'decor', name: 'Большая жаровня', acc: 'большую жаровню', cost: { money: 90 }, w: 1, h: 1, beauty: 2, fp: 0.6, tech: 'gardens', desc: 'Высокая бронзовая чаша с огнём — для площадей и ворот.' },
  lamps: { kind: 'decor', cat: 'decor', name: 'Гирлянда лампад', acc: 'гирлянду лампад', cost: { money: 60 }, w: 1, h: 1, beauty: 2, fp: 0.95, tech: 'gardens', desc: 'Масляные лампы на верёвке между столбами — праздник на улице.' },
  campfire: { kind: 'decor', cat: 'decor', name: 'Костёр', acc: 'костёр', cost: { money: 15 }, w: 1, h: 1, beauty: 1, fp: 0.6, desc: 'Огонь в кругу камней, у которого греются по вечерам.' },
  // ---- улица
  barrels: { kind: 'decor', cat: 'decor', name: 'Бочки', acc: 'бочки', cost: { money: 15 }, w: 1, h: 1, beauty: 1, fp: 0.5, desc: 'Бочки с вином и маслом у лавки.' },
  crates: { kind: 'decor', cat: 'decor', name: 'Ящики', acc: 'ящики', cost: { money: 12 }, w: 1, h: 1, beauty: 1, fp: 0.5, desc: 'Ящики с товаром.' },
  sacks: { kind: 'decor', cat: 'decor', name: 'Мешки и корзины', acc: 'мешки и корзины', cost: { money: 15 }, w: 1, h: 1, beauty: 1, fp: 0.5, desc: 'Пряности, зерно и фрукты.' },
  hay: { kind: 'decor', cat: 'decor', name: 'Сено', acc: 'сено', cost: { money: 10 }, w: 1, h: 1, beauty: 1, fp: 0.6, desc: 'Тюки сена для лошадей.' },
  cart: { kind: 'decor', cat: 'decor', name: 'Телега', acc: 'телегу', cost: { money: 45 }, w: 1, h: 1, beauty: 1, fp: 0.9, desc: 'Деревянная телега с колёсами.' },
  stall: { kind: 'decor', cat: 'decor', name: 'Прилавок', acc: 'прилавок', cost: { money: 60 }, w: 1, h: 1, beauty: 2, fp: 0.95, desc: 'Торговый прилавок под полосатым навесом.' },
  banner: { kind: 'decor', cat: 'decor', name: 'Знамя', acc: 'знамя', cost: { money: 40 }, w: 1, h: 1, beauty: 2, fp: 0.35, desc: 'Красное знамя Рима.' },
  sundial: { kind: 'decor', cat: 'decor', name: 'Солнечные часы', acc: 'солнечные часы', cost: { money: 120 }, w: 1, h: 1, beauty: 3, fp: 0.5, tech: 'gardens', desc: 'Римские часы, что показывают время по тени.' },
  roundbench: { kind: 'decor', cat: 'decor', name: 'Круглая скамья', acc: 'круглую скамью', cost: { money: 50 }, w: 1, h: 1, beauty: 2, fp: 0.9, tech: 'gardens', desc: 'Каменная скамья кольцом — посидеть в тени.' },
  // ---- сад
  flowerbush: { kind: 'decor', cat: 'decor', name: 'Цветущий куст', acc: 'цветущий куст', cost: { money: 10 }, w: 1, h: 1, beauty: 1, fp: 0.5, desc: 'Куст в цветах.' },
  planter: { kind: 'decor', cat: 'decor', name: 'Вазон', acc: 'вазон', cost: { money: 18 }, w: 1, h: 1, beauty: 1, fp: 0.45, desc: 'Каменный вазон с зеленью.' },
  palm: { kind: 'decor', cat: 'decor', name: 'Пальма', acc: 'пальму', cost: { money: 20 }, w: 1, h: 1, beauty: 1, fp: 0.6, tech: 'gardens', desc: 'Финиковая пальма из Африки.' },
  bigjar: { kind: 'decor', cat: 'decor', name: 'Большая ваза', acc: 'большую вазу', cost: { money: 60 }, w: 1, h: 1, beauty: 2, fp: 0.5, tech: 'gardens', desc: 'Высокая расписная ваза.' },
  // ---- кисти россыпью: каждое движение ставит одно из нескольких украшений вразброс, разного размера
  grovebrush: { kind: 'decor', cat: 'decor', name: 'Роща россыпью', acc: 'рощу', cost: { money: 10 }, w: 1, h: 1, beauty: 1, fp: 0.6, scatter: ['cypress', 'pine', 'olive'], desc: 'Кисть: ведите с зажатой кнопкой — кипарисы, пинии и оливы встанут вразброс, разного размера. Платится за каждое дерево.' },
  flowerbrush: { kind: 'decor', cat: 'decor', name: 'Цветы россыпью', acc: 'цветы', cost: { money: 10 }, w: 1, h: 1, beauty: 1, fp: 0.5, scatter: ['flowerbush', 'flowers', 'planter'], desc: 'Кисть: ведите с зажатой кнопкой — кусты, клумбы и вазоны встанут вразброс. Платится за каждое.' },
  // ---- на стены домов: вешаются в точку на стене под курсором, переезжают и сносятся вместе с домом
  flowerbox: { kind: 'decor', cat: 'decor', name: 'Ящик с цветами', acc: 'ящик с цветами', cost: { money: 15 }, w: 1, h: 1, beauty: 1, fp: 0.4, wall: true, desc: 'Цветы под окном.' },
  wallawning: { kind: 'decor', cat: 'decor', name: 'Навес', acc: 'навес', cost: { money: 25 }, w: 1, h: 1, beauty: 1, fp: 0.5, wall: true, desc: 'Полосатый навес над дверью или лавкой.' },
  wallbanner: { kind: 'decor', cat: 'decor', name: 'Знамя на стене', acc: 'знамя на стене', cost: { money: 35 }, w: 1, h: 1, beauty: 2, fp: 0.35, wall: true, desc: 'Красное полотнище с золотым орлом.' },
  walllamp: { kind: 'decor', cat: 'decor', name: 'Фонарь на стене', acc: 'фонарь на стене', cost: { money: 30 }, w: 1, h: 1, beauty: 1, fp: 0.3, wall: true, desc: 'Лампа на кованом кронштейне — ночью освещает улицу.' },
  ivy: { kind: 'decor', cat: 'decor', name: 'Плющ', acc: 'плющ', cost: { money: 12 }, w: 1, h: 1, beauty: 1, fp: 0.45, wall: true, desc: 'Зелень, вьющаяся по стене.' },
  // ---- статуи
  bust: { kind: 'decor', cat: 'decor', name: 'Бюст на постаменте', acc: 'бюст', cost: { money: 120 }, w: 1, h: 1, beauty: 3, fp: 0.4, tech: 'marble', desc: 'Мраморный бюст на колонне.' },
  lion: { kind: 'decor', cat: 'decor', name: 'Мраморный лев', acc: 'мраморного льва', cost: { money: 200 }, w: 1, h: 1, beauty: 4, fp: 0.7, tech: 'marble', desc: 'Лев-страж у ворот и лестниц.' },
  discobolus: { kind: 'decor', cat: 'decor', name: 'Дискобол', acc: 'дискобола', cost: { money: 250 }, w: 1, h: 1, beauty: 4, fp: 0.6, tech: 'marble', desc: 'Атлет, метающий диск.' },
  hercules: { kind: 'decor', cat: 'decor', name: 'Статуя Геракла', acc: 'статую Геракла', cost: { money: 300 }, w: 1, h: 1, beauty: 5, fp: 0.6, tech: 'marble', desc: 'Герой с палицей на постаменте.' },
  athena: { kind: 'decor', cat: 'decor', name: 'Статуя Минервы', acc: 'статую Минервы', cost: { money: 300 }, w: 1, h: 1, beauty: 5, fp: 0.6, tech: 'marble', desc: 'Богиня мудрости в шлеме.' },
  zeus: { kind: 'decor', cat: 'decor', name: 'Статуя Юпитера', acc: 'статую Юпитера', cost: { money: 350 }, w: 1, h: 1, beauty: 5, fp: 0.6, tech: 'marble', desc: 'Отец богов на троне.' },
  emperor: { kind: 'decor', cat: 'decor', name: 'Статуя императора', acc: 'статую императора', cost: { money: 780, glory: 20 }, w: 1, h: 1, beauty: 10, tech: 'triumph', desc: 'Золотой император на высоком постаменте.' },
};

// Наборы украшений — вкладки в разделе «Красота»
const DECOR_SETS = [['light', 'Свет'], ['street', 'Улица'], ['garden', 'Сад'], ['wall', 'На стены'], ['statue', 'Статуи']];
const DECOR_SET_OF = {
  lamp: 'light', lantern: 'light', torch: 'light', bigtorch: 'light', lamps: 'light', campfire: 'light',
  bench: 'street', amphorae: 'street', mosaic: 'street', barrels: 'street', crates: 'street', sacks: 'street', hay: 'street',
  cart: 'street', stall: 'street', banner: 'street', sundial: 'street', roundbench: 'street',
  grovebrush: 'garden', flowerbrush: 'garden', flowerbox: 'wall', wallawning: 'wall', wallbanner: 'wall', walllamp: 'wall', ivy: 'wall',
  flowers: 'garden', cypress: 'garden', pine: 'garden', olive: 'garden', pergola: 'garden', flowerbush: 'garden', planter: 'garden', palm: 'garden', bigjar: 'garden',
  statue: 'statue', column: 'statue', obelisk: 'statue', emperor: 'statue', bust: 'statue', lion: 'statue', discobolus: 'statue', hercules: 'statue', athena: 'statue', zeus: 'statue',
};
for (const [k, s] of Object.entries(DECOR_SET_OF)) if (BUILDINGS[k]) BUILDINGS[k].set = s;

const CATEGORIES = [
  { id: 'roads', name: 'Дороги' },
  { id: 'housing', name: 'Жильё' },
  { id: 'food', name: 'Еда' },
  { id: 'industry', name: 'Ремёсла' },
  { id: 'services', name: 'Службы' },
  { id: 'culture', name: 'Культура' },
  { id: 'army', name: 'Армия' },
  { id: 'decor', name: 'Красота' },
];
for (const c of CATEGORIES) c.items = Object.keys(BUILDINGS).filter(k => BUILDINGS[k].cat === c.id);

/* ---------- Исследования ----------
   Стоят свитки (их пишут храмы, школы и форум) и денарии. */

const TECHS = [
  { id: 'gardens', name: 'Садовое искусство', scrolls: 6, money: 100, req: [], col: 0,
    desc: 'Фонтаны, оливы, жаровни, перголы и мозаики.' },
  { id: 'olives', name: 'Оливководство', scrolls: 8, money: 150, req: [], col: 0,
    desc: 'Оливковые рощи и маслодавильни. Масло нужно инсулам.' },
  { id: 'bricks', name: 'Обжиг кирпича', scrolls: 12, money: 200, req: [], col: 0,
    desc: 'Глиняные карьеры и кирпичные мастерские.' },
  { id: 'baking', name: 'Хлебопечение', scrolls: 14, money: 200, req: ['olives'], col: 1,
    desc: 'Пекарни: хлеб из пшеницы.' },
  { id: 'schooling', name: 'Школы', scrolls: 16, money: 250, req: ['bricks'], col: 1,
    desc: 'Школы пишут больше свитков.' },
  { id: 'baths', name: 'Римские бани', scrolls: 20, money: 300, req: ['bricks'], col: 1,
    desc: 'Термы — для больших инсул и патрициев.' },
  { id: 'irrigation', name: 'Ирригация', scrolls: 20, money: 300, req: ['olives'], col: 1,
    desc: 'Поля, рощи и виноградники дают на треть больше.', bonus: true },
  { id: 'trade', name: 'Торговля', scrolls: 25, money: 400, req: ['schooling'], col: 2,
    desc: 'Торговый пост: продажа излишков и покупка нехватки.' },
  { id: 'patricians', name: 'Патрициат', scrolls: 30, money: 500, req: ['schooling', 'baths'], col: 2,
    desc: 'Участки патрициев: домусы, виллы, дворцы.' },
  { id: 'wine', name: 'Виноделие', scrolls: 30, money: 400, req: ['baking'], col: 2,
    desc: 'Виноградники и винодельни.' },
  { id: 'marble', name: 'Мрамор', scrolls: 35, money: 500, req: ['bricks'], col: 2,
    desc: 'Мраморные карьеры, статуи и колонны.' },
  { id: 'taxreform', name: 'Налоговая реформа', scrolls: 35, money: 500, req: ['trade'], col: 3,
    desc: 'Налоги приносят на 15% больше.', bonus: true },
  { id: 'theatre', name: 'Театр', scrolls: 40, money: 600, req: ['patricians'], col: 3,
    desc: 'Театры — для вилл патрициев.' },
  { id: 'metal', name: 'Металлургия', scrolls: 40, money: 600, req: ['marble'], col: 3,
    desc: 'Железные рудники и кузницы.' },
  { id: 'legion', name: 'Легион', scrolls: 50, money: 800, req: ['metal'], col: 4,
    desc: 'Казармы и Стрельбище, отряд и карта походов. Победы открывают чудеса света.' },
  { id: 'forum', name: 'Форум', scrolls: 60, money: 1000, req: ['theatre', 'marble'], col: 4,
    desc: 'Форум — для дворцов патрициев. Даёт много свитков.' },
  { id: 'triumph', name: 'Триумф', scrolls: 60, money: 800, req: ['legion'], col: 5,
    desc: 'Обелиск и статуя императора. Чудеса света открывает рейтинг легиона.' },
];
// Знания открываются по мере роста города и изучаются не мгновенно, по одному.
// Колонка дерева → сколько нужно жителей и сколько игровых дней идёт изучение (день = 4 с при ×1).
const TECH_POP = [0, 60, 150, 400, 900, 1500];
const TECH_DAYS = [10, 25, 45, 75, 110, 150];
for (const t of TECHS) { t.pop = TECH_POP[t.col]; t.days = TECH_DAYS[t.col]; }
const TECH_BY_ID = Object.fromEntries(TECHS.map(t => [t.id, t]));


// Центр города по званиям: каким он становится (растёт сам)
const CENTER_STAGES = ['Лагерь переселенцев', 'Дом старосты', 'Курия', 'Базилика', 'Большая базилика', 'Дворец наместника', 'Императорский дворец'];
// Предел казны по званию города: больше не помещается — доход пропадает (как в Town to City)
const TREASURY_CAPS = [4000, 6000, 10000, 20000, 40000, 80000, 200000];
const CITY_RANKS = [
  [0, 'Деревня'],
  [50, 'Посёлок'],
  [150, 'Городок'],
  [400, 'Город'],
  [900, 'Большой город'],
  [2000, 'Столица провинции'],
  [5000, 'Второй Рим'],
];

// Что жители могут попросить построить рядом с домом
const REQUEST_POOL = [
  { type: 'flowers', minTier: 1 },
  { type: 'cypress', minTier: 1 },
  { type: 'bench', minTier: 1 },
  { type: 'well', minTier: 1 },
  { type: 'amphorae', minTier: 1 },
  { type: 'pine', minTier: 2 },
  { type: 'olive', minTier: 2 },
  { type: 'lamp', minTier: 2 },
  { type: 'pergola', minTier: 2 },
  { type: 'fountain', minTier: 3 },
  { type: 'mosaic', minTier: 3 },
  { type: 'statue', minTier: 3 },
  { type: 'column', minTier: 4 },
  { type: 'obelisk', minTier: 4 },
];
