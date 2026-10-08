'use strict';
/* Интерфейс поверх 3D-карты: верхняя панель, док стройки, карточка здания,
   окно «Империя» (знания, товары, легион, справка, журнал), настройки, подсказки, метки над картой. */

const $ = id => document.getElementById(id);

// Что строить, если дому чего-то не хватает
const NEED_ACTION = {
  road: { tool: 'road', label: 'Дорога' }, water: { tool: 'well', label: 'Колодец' }, food: { tool: 'market', label: 'Рынок' },
  temple: { tool: 'temple', label: 'Храм' }, oil: { tool: 'oilpress', label: 'Маслодавильня' }, bread: { tool: 'bakery', label: 'Пекарня' },
  baths: { tool: 'baths', label: 'Термы' }, wine: { tool: 'winery', label: 'Винодельня' }, theatre: { tool: 'theatre', label: 'Театр' },
  forum: { tool: 'forum', label: 'Форум' }, beauty: { cat: 'decor', label: 'Украшения' },
};
const NEED_SHORT = { road: 'дорога', water: 'вода', food: 'еда', temple: 'храм', oil: 'масло', bread: 'хлеб', baths: 'термы', wine: 'вино', theatre: 'театр', forum: 'форум' };
const NEED_ICON = { road: 'stone', water: 'water', food: 'wheat', temple: 'temple', oil: 'oil', bread: 'bread', baths: 'baths', wine: 'wine', theatre: 'theatre', forum: 'temple', beauty: 'glory', crowd: 'people' };

const GOOD_GROUPS = [
  { name: 'Еда', goods: ['wheat', 'fish', 'bread'] },
  { name: 'Сырьё и роскошь', goods: ['olives', 'oil', 'grapes', 'wine'] },
  { name: 'Стройматериалы', goods: ['wood', 'stone', 'clay', 'bricks', 'marble'] },
  { name: 'Армия', goods: ['iron', 'weapons'] },
];
const GOOD_USE = {
  wheat: 'Еда для всех домов через рынок; сырьё для пекарни.', fish: 'Еда для всех домов через рынок.',
  bread: 'Нужен Большой инсуле и патрициям.', olives: 'Сырьё для маслодавильни.', oil: 'Нужно инсулам и патрициям.',
  grapes: 'Сырьё для винодельни.', wine: 'Нужно виллам и дворцам.', wood: 'Стройка; кузница делает из него оружие.',
  stone: 'Стройка: храмы, колодцы, термы.', clay: 'Сырьё для кирпичной мастерской.', bricks: 'Стройка: термы, школы, чудеса света.',
  marble: 'Статуи, форум, чудеса света.', iron: 'Сырьё для кузницы.', weapons: 'Казармы превращают его в легионеров.',
};

const UI = {
  selected: null,
  openCat: null,
  lastHud: 0,
  modalOpen: false,
  winOpen: false,
  winTab: 'research',
  icons: {},
  floats: [],
  labels: new Map(),

  init() {
    const tierIcons = [];
    for (const t of ['house', 'domus']) for (let i = 0; i < BUILDINGS[t].tiers.length; i++) tierIcons.push(t + ':' + i);
    this.icons = Engine.renderIcons([...Object.keys(BUILDINGS), ...tierIcons], 128);
    document.querySelectorAll('[data-icon]').forEach(img => { img.src = Icons.get(img.dataset.icon); });
    document.querySelectorAll('[data-svg]').forEach(el => el.insertAdjacentHTML('afterbegin', Icons.svg(el.dataset.svg)));
    $('emblem').src = Icons.get('emblem');
    this.buildCats();
    document.querySelectorAll('[data-speed]').forEach(btn => btn.addEventListener('click', () => this.setSpeed(+btn.dataset.speed)));
    $('menu-btn').onclick = () => this.openMenu();
    $('city-btn').onclick = () => this.openMenu();
    $('rot-left').onclick = () => Engine.rotate(-1);
    $('rot-right').onclick = () => Engine.rotate(1);
    document.querySelectorAll('#rail [data-open]').forEach(b => b.onclick = () => this.openWindow(b.dataset.open));
    $('insp-close').onclick = () => this.closePanel();
    $('hint-cancel').onclick = () => Input.setTool(null);
    $('win-close').onclick = () => this.closeWindow();
    $('win-back').addEventListener('pointerdown', e => { if (e.target.id === 'win-back') this.closeWindow(); });
    $('modal-back').addEventListener('pointerdown', e => { if (e.target.id === 'modal-back') this.closeModal(); });
    this.initTooltips();
    Advisor.init();
    this.setSpeed(state.speed);
    this.updateHud(true);
    window.addEventListener('resize', () => this.layoutHud());
    document.fonts?.ready.then(() => this.layoutHud());
  },

  blocking() { return this.modalOpen || this.winOpen; },

  /* ---------- Цена ---------- */

  have(res) { return res === 'money' ? state.money : res === 'glory' ? state.glory : res === 'scrolls' ? state.scrolls : state.goods[res]; },

  costHtml(cost) {
    return Object.entries(cost).map(([res, v]) =>
      `<span class="cost ${this.have(res) < v ? 'short' : ''}">${Icons.img(res)}${fmt(v)}</span>`).join('');
  },

  /* ---------- Верхняя панель ---------- */

  updateHud(force) {
    const t = performance.now();
    if (!force && t - this.lastHud < 250) return;
    this.lastHud = t;
    const S = state.stats;
    $('city-name').textContent = state.cityName;
    $('city-rank').textContent = cityRank(S.pop || 0) + (TEST_MODE ? ' · тест' : '');
    $('v-money').textContent = fmt(state.money);
    const inc = S.income || 0;
    $('v-income').textContent = `${inc >= 0 ? '+' : '−'}${Math.abs(inc).toFixed(1)}`;
    $('v-income').classList.toggle('neg', inc < 0);
    // прогресс до следующего звания города
    const pop = S.pop || 0;
    let lo = 0, hi = CITY_RANKS[1][0];
    for (let i = 0; i < CITY_RANKS.length; i++) if (pop >= CITY_RANKS[i][0]) { lo = CITY_RANKS[i][0]; hi = (CITY_RANKS[i + 1] || [lo * 2])[0]; }
    $('rank-bar').style.width = `${clamp((pop - lo) / Math.max(1, hi - lo), 0, 1) * 100}%`;
    // карточки классов жителей: сколько их и насколько они счастливы
    const R = S.residents || {};
    let cc = '';
    for (const [k] of Object.entries(CLASSES)) {
      if (k !== 'plebs' && !(R[k] > 0)) continue;
      const h = (S.happyCls || {})[k] || 0;
      cc += `<button type="button" class="ccard" data-tip="class:${k}">${Icons.cls(k)}<b>${fmt(R[k] || 0)}</b><span class="hp ${!R[k] ? '' : h >= 60 ? 'good' : h >= 40 ? 'mid' : 'bad'}">${R[k] ? h + '%' : '—'}</span></button>`;
    }
    if (cc !== this._ccHtml) { $('class-cards').innerHTML = cc; this._ccHtml = cc; }
    let short = false, f = 0;
    for (const k of Object.keys(CLASSES)) { const j = (S.jobs || {})[k] || 0; f += (S.filled || {})[k] || 0; if (j > ((S.filled || {})[k] || 0)) short = true; }
    let jobs = 0;
    for (const k of Object.keys(CLASSES)) jobs += (S.jobs || {})[k] || 0;
    $('v-work').textContent = `${fmt(f)}/${fmt(jobs)}`;
    $('st-work').classList.toggle('warn', short);
    $('v-date').textContent = `Год ${roman(Math.floor(state.day / (DAYS_PER_SEASON * 4)) + 1)}`;
    $('v-season').textContent = `${SEASONS[Math.floor(state.day / DAYS_PER_SEASON) % 4]}, день ${state.day % DAYS_PER_SEASON + 1}`;
    this.renderRes();
    this.layoutHud();
    Alerts.render();
    Advisor.render();
    // значки на боковом меню
    const ready = TECHS.filter(canResearch).length;
    const br = $('b-research'); br.hidden = !ready; br.textContent = ready;
    const rb = document.querySelector('#rail [data-open="research"]'), rs = state.research;
    rb.classList.toggle('researching', !!rs);
    if (rs) rb.style.setProperty('--p', `${(1 - rs.left / TECH_BY_ID[rs.id].days) * 100}%`);
    if (this.winOpen && this.winTab === 'research' && rs && t - (this.lastWin || 0) > 1000) { this.lastWin = t; this.updateResearchProgress(); }
    const shortGoods = Object.keys((S.short || {})).length;
    const bg = $('b-goods'); bg.hidden = !shortGoods; bg.textContent = '!';
    $('rail-legion').hidden = !Army.unlocked();
    const fresh = Army.unlocked() && countType('barracks') > 0 && state.army.progress === 0;
    const bl = $('b-legion'); bl.hidden = !fresh; bl.textContent = '!';
    ArmyUI.tick();
    const bj = $('b-journal'); bj.hidden = !state.journalUnread; bj.textContent = Math.min(99, state.journalUnread || 0);
    this.updateTrayAfford();
    if (this.winOpen && this.winTab === 'goods' && t - (this.lastWin || 0) > 1000) { this.lastWin = t; this.renderWindow(); }
  },

  // Сводка не помещается в строку — сначала прячем приросты ресурсов, потом переносим ресурсы ниже.
  // Советник, тревоги и карточка здания встают под нижний край сводки (--hud-b).
  layoutHud() {
    const hud = $('hud'), left = hud.querySelector('.hud-left'), res = $('res-bar'), right = hud.querySelector('.hud-right');
    const fits = () => left.scrollWidth + res.scrollWidth + right.scrollWidth + 24 <= hud.clientWidth;
    hud.classList.remove('compact', 'wrap');
    if (!fits()) { hud.classList.add('compact'); if (!fits()) hud.classList.add('wrap'); }
    const b = Math.round(hud.getBoundingClientRect().bottom);
    if (b !== this._hudB) { this._hudB = b; document.documentElement.style.setProperty('--hud-b', b + 'px'); }
  },

  renderRes() {
    const S = state.stats, cap = S.cap || BASE_STORAGE;
    const chips = [];
    const food = state.goods.wheat + state.goods.fish;
    const fd = ((S.prod || {}).wheat || 0) + ((S.prod || {}).fish || 0) - ((S.cons || {}).wheat || 0) - ((S.cons || {}).fish || 0);
    chips.push(['food', 'wheat', food, fd]);
    for (const g of ['wood', 'stone', 'bricks', 'marble', 'weapons']) {
      const v = state.goods[g];
      const known = v > 0.5 || (S.prod || {})[g] || (g === 'bricks' && hasTech('bricks')) || (g === 'marble' && hasTech('marble')) || (g === 'weapons' && hasTech('metal'));
      if (!known) continue;
      chips.push(['good:' + g, g, v, ((S.prod || {})[g] || 0) - ((S.cons || {})[g] || 0)]);
    }
    let html = chips.map(([tip, icon, v, d]) => {
      const cls = v < 0.5 && d < 0 ? 'empty' : v >= cap - 0.5 ? 'full' : '';
      return `<button type="button" class="chip ${cls}" data-tip="${tip}">${Icons.img(icon)}<b>${fmt(v)}</b>${Math.abs(d) >= 0.1 ? `<small class="${d < 0 ? 'neg' : ''}">${d > 0 ? '+' : '−'}${Math.abs(d).toFixed(1)}</small>` : ''}</button>`;
    }).join('');
    html += '<span class="vsep"></span>';
    html += `<button type="button" class="chip key" data-tip="scrolls">${Icons.img('scrolls')}<b>${fmt(state.scrolls)}</b>${S.scrollRate ? `<small>+${S.scrollRate.toFixed(1)}</small>` : ''}</button>`;
    if (state.glory > 0 || hasTech('legion')) html += `<button type="button" class="chip key" data-tip="glory">${Icons.img('glory')}<b>${fmt(state.glory)}</b></button>`;
    if (html !== this._resHtml) {
      $('res-bar').innerHTML = html;
      this._resHtml = html;
      $('res-bar').querySelectorAll('.chip').forEach(c => c.onclick = () => this.openWindow(c.dataset.tip === 'scrolls' ? 'research' : c.dataset.tip === 'glory' ? 'legion' : 'goods'));
    }
  },

  setSpeed(s) {
    if (s > 0) state.lastSpeed = s;
    state.speed = s;
    document.querySelectorAll('[data-speed]').forEach(b => b.classList.toggle('on', +b.dataset.speed === s));
  },

  togglePause() { this.setSpeed(state.speed ? 0 : (state.lastSpeed || 1)); },

  /* ---------- Док стройки ---------- */

  buildCats() {
    const cats = $('cats');
    cats.innerHTML = '';
    for (const c of CATEGORIES) {
      const btn = document.createElement('button');
      btn.className = 'cat' + (c.id === this.openCat ? ' on' : '');
      btn.type = 'button';
      btn.dataset.cat = c.id;
      const first = c.items.find(isUnlocked) || c.items[0];
      btn.innerHTML = `<img src="${this.icons[first] || ''}" alt=""><span>${c.name}</span>`;
      const fresh = c.items.some(t => isUnlocked(t) && BUILDINGS[t].tech && !(state.seenTypes || []).includes(t));
      if (fresh) btn.classList.add('fresh');
      btn.onclick = () => {
        if (this.openCat === c.id) { this.closeTray(); return; }
        this.openTray(c.id);
        if (c.items.length === 1 && isUnlocked(c.items[0])) Input.setTool(c.items[0]);
      };
      cats.append(btn);
    }
    const bd = document.createElement('button');
    bd.className = 'cat bulldoze' + (Input.tool === 'bulldoze' ? ' on' : '');
    bd.type = 'button';
    bd.dataset.tip = 'bulldoze';
    bd.innerHTML = `<span class="pick">${Icons.svg('pick')}</span><span>Снос</span>`;
    bd.onclick = () => Input.setTool(Input.tool === 'bulldoze' ? null : 'bulldoze');
    cats.append(bd);
  },

  // совместимость со старыми вызовами
  buildToolbar() { this.buildCats(); if (this.openCat) this.renderTray(); },

  openTray(cat) {
    this.openCat = cat;
    const c = CATEGORIES.find(x => x.id === cat);
    state.seenTypes = [...new Set([...(state.seenTypes || []), ...c.items.filter(isUnlocked)])];
    this.buildCats();
    this.renderTray();
    $('tray').hidden = false;
  },

  closeTray() {
    this.openCat = null;
    $('tray').hidden = true;
    if (Input.tool && Input.tool !== 'bulldoze') Input.setTool(null);
    this.buildCats();
  },

  renderTray() {
    const items = $('tray-items');
    items.innerHTML = '';
    const cat = CATEGORIES.find(c => c.id === this.openCat);
    if (!cat) return;
    for (const type of cat.items) {
      const d = BUILDINGS[type];
      const unlocked = isUnlocked(type);
      const card = document.createElement('button');
      card.type = 'button';
      card.className = 'card' + (Input.tool === type ? ' on' : '') + (unlocked ? '' : ' locked');
      card.dataset.type = type;
      card.dataset.card = type;
      const cls = this.cardClasses(type);
      if (cls.length) card.style.setProperty('--cls', CLASSES[cls[cls.length - 1]].color);
      card.innerHTML = `<span class="card-img"><img src="${this.icons[type] || ''}" alt="">${cls.length ? `<span class="card-cls">${cls.map(c => Icons.cls(c, 20)).join('')}</span>` : ''}${unlocked ? '' : '<i class="lock-badge" aria-hidden="true"></i>'}</span>
        <span class="card-name">${d.name}</span>
        <span class="card-cost">${unlocked ? this.costHtml(d.cost) : `<span class="lock">${Icons.img(d.milTech && hasTech(d.tech) ? 'glory' : 'scrolls')}${lockName(type)}</span>`}</span>`;
      card.onclick = () => {
        if (!unlocked) { this.openWindow('research', d.tech); return; }
        Input.setTool(Input.tool === type ? null : type);
      };
      items.append(card);
    }
    // подпись: кто где работает — цвет значка в углу карточки
    let legend = $('tray-legend');
    if (!legend) { legend = Object.assign(document.createElement('div'), { id: 'tray-legend', className: 'tray-legend' }); $('tray').append(legend); }
    const used = new Set(cat.items.flatMap(t => this.cardClasses(t)));
    legend.innerHTML = used.size ? `<span>${cat.id === 'housing' ? 'Кто живёт:' : 'Кто работает:'}</span>${[...used].map(c => `<span class="lg">${Icons.cls(c, 16)}${CLASSES[c].name}</span>`).join('')}` : '';
    legend.hidden = !used.size;
  },

  // Какие классы работают в постройке (или живут в доме)
  cardClasses(type) {
    const d = BUILDINGS[type];
    if (d.jobs) return Object.keys(d.jobs);
    if (d.tiers) return [...new Set(d.tiers.map(t => t.cls).filter(Boolean))];
    return [];
  },

  updateTrayAfford() {
    document.querySelectorAll('#tray-items .card').forEach(card => {
      const type = card.dataset.type;
      if (!isUnlocked(type)) return;
      const d = BUILDINGS[type];
      const html = this.costHtml(d.cost);
      const el = card.querySelector('.card-cost');
      if (el.innerHTML !== html) el.innerHTML = html;
      card.classList.toggle('poor', !canAfford(d.cost));
    });
  },

  onToolChanged() {
    const t = Input.tool;
    const cat = t && t !== 'bulldoze' && CATEGORIES.find(c => c.items.includes(t));
    if (cat && cat.id !== this.openCat) this.openTray(cat.id);
    document.querySelectorAll('#tray-items .card').forEach(c => c.classList.toggle('on', c.dataset.type === t));
    const bd = document.querySelector('.cat.bulldoze');
    if (bd) bd.classList.toggle('on', t === 'bulldoze');
    const hint = $('tool-hint');
    if (!t) { hint.hidden = true; return; }
    hint.hidden = false;
    if (t === 'bulldoze') {
      $('hint-icon').src = Icons.get('workers');
      $('hint-name').textContent = 'Снос';
      $('hint-text').textContent = 'Нажмите на здание, дорогу или дерево. Возвращается половина стоимости.';
    } else {
      const d = BUILDINGS[t];
      $('hint-icon').src = this.icons[t] || '';
      $('hint-name').textContent = d.name;
      $('hint-text').textContent = t === 'road' ? 'Зажмите кнопку мыши и тяните — дорога проложится по пути.' : d.desc;
    }
    $('hint-status').textContent = '';
    $('hint-status').className = '';
    this.closePanel();
  },

  // Строка состояния: залежи рядом, причина отказа
  setToolStatus(type, x, y, err) {
    const d = BUILDINGS[type];
    const el = $('hint-status');
    let s = '';
    el.className = '';
    if (d.deposit) {
      const r = depositFactor(type, x, y);
      const what = { trees: 'Деревьев', stone: 'Скал с камнем', marble: 'Мраморных скал', iron: 'Рыжих скал с железом' }[d.deposit];
      s = `${what} рядом: ${r.count} из ${d.depositNeed} → добыча ${Math.round(r.factor * 100)}%`;
      el.className = r.factor < 0.5 ? 'bad' : r.factor < 1 ? 'mid' : 'good';
    } else if (d.radius) {
      let n = 0;
      const probe = { x, y, w: d.w, h: d.h };
      for (const h of state.buildings.values()) if (BUILDINGS[h.type].kind === 'house' && dist2(h, probe) <= d.radius * d.radius) n++;
      s = `Домов в радиусе: ${n}`;
      el.className = n ? 'good' : 'mid';
    }
    if (err && err !== 'Место занято') { s = err; el.className = 'bad'; }
    el.textContent = s;
  },

  /* ---------- Карточка здания ---------- */

  openPanel(b) {
    if (Input.tool) Input.setTool(null);
    this.selected = b;
    $('inspector').hidden = false;
    this.refreshPanel();
  },

  closePanel() {
    this.selected = null;
    $('inspector').hidden = true;
  },

  statusOf(b) {
    const d = BUILDINGS[b.type];
    if ((d.needsRoad || d.kind === 'house') && !b.road) return ['bad', 'Нет дороги рядом'];
    if (d.kind === 'house') {
      if (b.tier === 0) return ['mid', 'Жители скоро заселятся'];
      if (b.target < b.tier) return ['bad', 'Приходит в упадок'];
      if (b.target > b.tier && !b.lock) return ['good', 'Скоро вырастет'];
      if (b.lock) return ['mid', 'Рост заморожен'];
      return ['good', 'Жители довольны'];
    }
    if (d.jobs && (b.staff || 0) < 0.25) return ['bad', `Нет работников (${CLASSES[Object.keys(d.jobs)[0]].gen})`];
    if (d.produces) {
      if (d.consumes && Object.keys(d.consumes).some(g => state.goods[g] < 0.5)) return ['bad', 'Нет сырья'];
      if (Object.keys(d.produces).every(g => state.goods[g] >= (state.stats.cap || BASE_STORAGE) - 0.5)) return ['mid', 'Склады полны'];
      if (d.deposit && b.dep && b.dep.factor < 0.3) return ['bad', 'Мало залежей рядом'];
      if ((b.staff || 0) < 1) return ['mid', 'Работает не в полную силу'];
      return ['good', 'Работает'];
    }
    if (d.jobs && b.staff < 1) return ['mid', 'Не хватает работников'];
    return ['good', d.kind === 'decor' ? 'Радует соседей' : 'Работает'];
  },

  refreshPanel() {
    const b = this.selected;
    if (!b) return;
    if (!state.buildings.has(b.id)) { this.closePanel(); return; }
    const d = BUILDINGS[b.type];
    const [st, stText] = this.statusOf(b);
    let html = '';
    const head = (eyebrow, title) => `<div class="insp-head"><img src="${this.icons[b.type + ':' + b.tier] || this.icons[b.type] || ''}" alt=""><div><p class="eyebrow">${eyebrow}</p><h2>${title}</h2></div></div><div class="status ${st}"><i></i>${stText}</div>`;

    if (d.kind === 'house') {
      const tiers = d.tiers, T = tiers[b.tier];
      html += head(T.cls ? `<span class="cls-chip" style="--c:${CLASSES[T.cls].color};--b:${CLASSES[T.cls].soft}">${Icons.cls(T.cls, 16)}${CLASSES[T.cls].name}</span>` : d.name, T.name);
      html += `<div class="rows">
        <div class="row"><span>${Icons.img('people')} Жители</span><b>${fmt(b.pop)} / ${T.cap}</b></div>
        <div class="row"><span>${Icons.img('money')} Налог в день</span><b>${(b.pop * T.tax * taxMult() * (0.7 + b.happy / 200)).toFixed(1)}</b></div>
        ${b.tier > 0 ? `<div class="row"><span>${Icons.img('glory')} Красота вокруг</span><b>${b.beauty}</b></div>
        <div class="row"><span>${Icons.img('people')} Соседних домов</span><b>${b.crowd}</b></div>` : ''}
      </div>`;
      if (b.tier > 0) html += `<div class="meter"><span>Счастье</span><b>${b.happy}%</b><div class="bar"><div style="width:${b.happy}%"></div></div></div>`;
      if (b.tier < tiers.length - 1) {
        const N = tiers[b.tier + 1];
        const rows = [];
        for (const need of N.needs) rows.push([need, b.needs[need], NEED_LABELS[need]]);
        if (N.beauty) rows.push(['beauty', b.beauty >= N.beauty, `Красота ${N.beauty}+ (сейчас ${b.beauty})`]);
        if (N.maxCrowd !== undefined) rows.push(['crowd', b.crowd <= N.maxCrowd, `Не больше ${N.maxCrowd} домов рядом (сейчас ${b.crowd})`]);
        html += `<h3>${b.tier === 0 ? 'Чтобы заселились жители' : `Чтобы вырасти до «${N.name}»`}</h3><ul class="needs">`;
        for (const [need, ok, label] of rows) {
          const a = NEED_ACTION[need];
          const can = a && (!a.tool || isUnlocked(a.tool));
          html += `<li class="${ok ? 'yes' : 'no'}">${Icons.img(NEED_ICON[need] || 'glory')}<span>${label}</span>${ok ? '<i class="ok">✓</i>' : can ? `<button type="button" class="btn tiny" data-need="${need}">${a.label}</button>` : '<i class="no">✗</i>'}</li>`;
        }
        html += '</ul>';
        if (N.cls && T.cls && N.cls !== T.cls) html += `<p class="sub">После роста здесь будут жить ${CLASSES[N.cls].name.toLowerCase()}, а не ${CLASSES[T.cls].gen}.</p>`;
        if (b.tier > 0) html += `<label class="switch"><input type="checkbox" id="lock-tier" ${b.lock ? 'checked' : ''}><span></span>Не расти дальше (оставить ${T.cls ? CLASSES[T.cls].gen : 'жильцов'})</label>`;
      } else {
        html += `<p class="note good">Это лучший дом своего рода.</p>`;
      }
      if (b.tier > 0 && b.target < b.tier) {
        const T2 = tiers[b.tier];
        const missing = T2.needs.filter(n => !b.needs[n]).map(n => NEED_GENITIVE[n]);
        if (T2.beauty && b.beauty < T2.beauty) missing.push(NEED_GENITIVE.beauty);
        if (T2.maxCrowd !== undefined && b.crowd > T2.maxCrowd) missing.push(NEED_GENITIVE.crowd);
        html += `<p class="note bad">Не хватает ${missing.join(', ')} — без этого дом опустится на уровень ниже.</p>`;
      }
      if (b.req) {
        const r = BUILDINGS[b.req.type];
        html += `<div class="request"><img src="${this.icons[b.req.type]}" alt=""><div><p class="eyebrow">Просьба жителей</p><p>«Поставьте, пожалуйста, ${r.acc} рядом с нашим домом!»</p><p class="sub">Награда: ${requestReward(b.req.type)} ден. и радость жителей</p><button type="button" class="btn small" id="req-build">Выбрать: ${r.name}</button></div></div>`;
      }
    } else {
      const kindName = { producer: 'Производство', service: 'Служба', storage: 'Склад', military: 'Армия', wonder: 'Чудо света', decor: 'Украшение' }[d.kind];
      html += head(kindName, d.name);
      if (d.produces) {
        const ins = d.consumes ? Object.entries(d.consumes).map(([g, r]) => `<span class="good-pill ${state.goods[g] < 0.5 ? 'short' : ''}">${Icons.img(g)}${r} ${GOODS[g].name.toLowerCase()}</span>`).join('') : '';
        const outs = Object.entries(d.produces).map(([g, r]) => `<span class="good-pill out">${Icons.img(g)}${(r * (b.output || 0)).toFixed(1)} из ${(r * (d.farmland && hasTech('irrigation') ? 1.33 : 1)).toFixed(1)} ${GOODS[g].name.toLowerCase()}</span>`).join('');
        html += `<div class="chain">${ins ? `<div>${ins}</div><span class="arrow">→</span>` : ''}<div>${outs}</div></div><p class="sub center">в день</p>`;
      }
      html += '<div class="rows">';
      if (d.jobs) {
        const [cls, n] = Object.entries(d.jobs)[0];
        html += `<div class="row"><span>${Icons.cls(cls, 18)} Работают ${CLASSES[cls].name.toLowerCase()}</span><b>${Math.round(n * Math.min(1, b.staff || 0))} / ${n}</b></div>`;
      }
      if (d.deposit && b.dep) {
        const what = { trees: 'Деревьев', stone: 'Скал', marble: 'Мраморных скал', iron: 'Железных скал' }[d.deposit];
        html += `<div class="row"><span>${Icons.img(d.deposit === 'trees' ? 'wood' : d.deposit)} ${what} рядом</span><b>${b.dep.count} / ${d.depositNeed}</b></div>`;
      }
      if (d.radius) {
        let n = 0;
        for (const h of state.buildings.values()) if (BUILDINGS[h.type].kind === 'house' && dist2(h, b) <= d.radius * d.radius) n++;
        html += `<div class="row"><span>${Icons.img('people')} Домов в радиусе ${d.radius}</span><b>${n}</b></div>`;
      }
      if (d.scrolls) html += `<div class="row"><span>${Icons.img('scrolls')} Свитков в день</span><b>${(d.scrolls * (d.jobs ? (b.staff || 0) : 1)).toFixed(1)}</b></div>`;
      if (d.glory) html += `<div class="row"><span>${Icons.img('glory')} Славы в день</span><b>${d.glory}</b></div>`;
      if (d.storage) html += `<div class="row"><span>${Icons.img('store')} Вместимость складов</span><b>${fmt(storageCap())}</b></div>`;
      if (d.beauty) html += `<div class="row"><span>${Icons.img('glory')} Красота для соседей</span><b>+${d.beauty}</b></div>`;
      if (d.upkeep) html += `<div class="row"><span>${Icons.img('money')} Содержание в день</span><b>${d.upkeep}</b></div>`;
      html += '</div>';
      html += `<p class="desc">${d.desc}</p>`;
      if (d.kind === 'military') html += ArmyUI.buildingPanel(b);
      if (b.type === 'tradepost') html += `<button type="button" class="btn" id="open-trade">Настроить торговлю</button>`;
    }
    html += `<button type="button" class="btn ghost small demolish" id="panel-demolish">Снести (вернётся половина)</button>`;
    $('insp-body').innerHTML = html;
    $('panel-demolish').onclick = () => {
      removeBuilding(b, true);
      Engine.dust(b);
      this.closePanel();
      afterCityChanged();
    };
    document.querySelectorAll('[data-need]').forEach(btn => btn.onclick = () => this.runAction(NEED_ACTION[btn.dataset.need]));
    const rb = $('req-build');
    if (rb) rb.onclick = () => { if (isUnlocked(b.req.type)) Input.setTool(b.req.type); else this.openWindow('research', BUILDINGS[b.req.type].tech); };
    const lk = $('lock-tier');
    if (lk) lk.onchange = () => { b.lock = lk.checked; this.refreshPanel(); };
    if (d.kind === 'military') ArmyUI.bindBuilding(b);
    const ot = $('open-trade');
    if (ot) ot.onclick = () => this.openWindow('goods');
  },

  /* ---------- Действия советника и кнопок ---------- */

  runAction(act) {
    if (!act) return;
    this.closeModal();
    if (act.open) { this.openWindow(act.open); return; }
    this.closeWindow();
    if (act.menu) { this.openMenu(); return; }
    if (act.tool) {
      if (isUnlocked(act.tool)) Input.setTool(act.tool);
      else this.openWindow('research', BUILDINGS[act.tool].tech);
      return;
    }
    if (act.cat) { this.openTray(act.cat); return; }
    if (act.plot) {
      for (const p of Engine.plots.values()) {
        if (canBuyPlot(p.px, p.py)) { Engine.lookAt(p.px * PLOT + PLOT / 2, p.py * PLOT + PLOT / 2); Engine.cam.distTarget = Math.max(Engine.cam.distTarget, 30); return; }
      }
    }
  },

  /* ---------- Окно «Империя» ---------- */

  openWindow(tab, focus) {
    if (Input.tool) Input.setTool(null);
    this.winTab = tab || this.winTab;
    this.winFocus = focus || null;
    this.winOpen = true;
    $('win-back').hidden = false;
    if (tab === 'journal') state.journalUnread = 0;
    this.renderWindow();
  },

  closeWindow() {
    if (!this.winOpen) return false;
    this.winOpen = false;
    $('win-back').hidden = true;
    return true;
  },

  renderWindow() {
    const tabs = [['research', 'Знания'], ['goods', 'Товары'], ['legion', 'Легион'], ['guide', 'Справка'], ['journal', 'Журнал']];
    $('win-tabs').innerHTML = tabs.map(([id, name]) => `<button type="button" class="${id === this.winTab ? 'on' : ''}" data-tab="${id}">${Icons.svg(id === 'goods' ? 'goods' : id)}<span>${name}</span></button>`).join('');
    $('win-tabs').querySelectorAll('[data-tab]').forEach(b => b.onclick = () => this.openWindow(b.dataset.tab));
    $('win-title').textContent = { research: 'Знания Рима', goods: 'Склады и торговля', legion: 'Легион и походы', guide: 'Справочник', journal: 'Журнал событий' }[this.winTab];
    const body = $('win-body');
    const scroll = body.scrollTop;
    if (this.winTab === 'research') this.renderResearch(body);
    else if (this.winTab === 'goods') this.renderGoods(body);
    else if (this.winTab === 'legion') ArmyUI.render(body);
    else if (this.winTab === 'guide') this.renderGuide(body);
    else this.renderJournal(body);
    body.scrollTop = scroll;
  },

  renderResearch(el) {
    if (Army.unlocked()) {
      const tabs = `<div class="seg res-tabs"><button type="button" data-rtab="civil" class="${this.resTab !== 'mil' ? 'on' : ''}">Знания Рима</button><button type="button" data-rtab="mil" class="${this.resTab === 'mil' ? 'on' : ''}">${Icons.img('glory')} Военное дело</button></div>`;
      if (this.resTab === 'mil') {
        ArmyUI.renderMilResearch(el);
        el.insertAdjacentHTML('afterbegin', tabs);
      } else {
        this.renderCivilResearch(el);
        el.insertAdjacentHTML('afterbegin', tabs);
      }
      el.querySelectorAll('[data-rtab]').forEach(b => b.onclick = () => { this.resTab = b.dataset.rtab; this.renderWindow(); });
      return;
    }
    this.renderCivilResearch(el);
  },

  renderCivilResearch(el) {
    const cols = [];
    for (const t of TECHS) (cols[t.col] = cols[t.col] || []).push(t);
    const S = state.stats;
    const busy = state.research ? TECH_BY_ID[state.research.id] : null;
    const card = t => {
      const st = techState(t);
      const afford = state.scrolls >= t.scrolls && state.money >= t.money;
      const days = `${t.days} ${plural(t.days, 'день', 'дня', 'дней')}`;
      const pop = S.pop || 0;
      const opens = Object.entries(BUILDINGS).filter(([, d]) => d.tech === t.id).map(([k]) => `<img src="${this.icons[k]}" alt="" data-card="${k}">`).join('');
      const reqs = t.req.filter(r => !hasTech(r)).map(r => TECH_BY_ID[r].name);
      const focus = this.winFocus === t.id ? ' focus' : '';
      let foot;
      if (st === 'done') foot = '<span class="tech-done">✓ Изучено</span>';
      else if (st === 'active') {
        const r = state.research;
        foot = `<div class="tech-prog"><div class="bar"><div style="width:${(1 - r.left / t.days) * 100}%"></div></div><span>Изучается · осталось <b>${r.left}</b> ${plural(r.left, 'день', 'дня', 'дней')}</span></div>`;
      } else if (st === 'locked') foot = `<span class="tech-lock">Сначала: ${reqs.join(', ')}</span>`;
      else if (st === 'pop') foot = `<span class="tech-pop">${Icons.svg('people')}Нужно ${fmt(t.pop)} жителей <small>(сейчас ${fmt(pop)})</small></span>`;
      else foot = `<button type="button" class="btn small" data-tech="${t.id}" ${afford && !busy ? '' : 'disabled'}>${Icons.img('scrolls')}${t.scrolls} ${Icons.img('money')}${fmt(t.money)}</button>
        <span class="tech-time">${busy ? 'После текущего знания' : days}</span>`;
      return `<div class="tech ${st}${focus}${st === 'open' && afford && !busy ? ' ready' : ''}" data-tech-id="${t.id}">
        <h4>${t.name}</h4>
        <p>${t.desc}</p>
        ${opens ? `<div class="opens">${opens}</div>` : ''}
        ${foot}
      </div>`;
    };
    el.innerHTML = `
      <div class="explain">
        ${Icons.img('scrolls', 'big')}
        <div><b>Свитки — это знания Рима.</b> У вас ${fmt(state.scrolls)} ${plural(Math.floor(state.scrolls), 'свиток', 'свитка', 'свитков')}${S.scrollRate ? `, +${S.scrollRate.toFixed(1)} в день` : ''}.
        <p>Их пишут жрецы в храмах (0,5 в день), учителя в школах (2 в день) и сенаторы на форуме (4 в день). Знание стоит свитков и денариев, изучается несколько дней и открывает новые постройки или даёт бонус. Изучается одно знание за раз. Дальние знания ждут, пока город вырастет: на карточке написано, сколько нужно жителей. Стрелки показывают, что нужно изучить раньше.</p>
        ${busy ? `<p class="now">Сейчас изучается «${busy.name}» — осталось <b id="now-left">${state.research.left}</b> ${plural(state.research.left, 'день', 'дня', 'дней')}.</p>` : ''}</div>
      </div>
      <div class="tree-wrap"><svg class="tree-lines" id="tree-lines"></svg><div class="tree">${cols.map(c => `<div class="tcol">${c.map(card).join('')}</div>`).join('')}</div></div>`;
    el.querySelectorAll('[data-tech]').forEach(b => b.onclick = () => { if (research(b.dataset.tech)) { this.renderWindow(); this.buildCats(); } });
    requestAnimationFrame(() => this.drawTechLines());
    if (this.winFocus) {
      const f = el.querySelector('.tech.focus');
      if (f) f.scrollIntoView({ block: 'nearest', inline: 'center' });
      this.winFocus = null;
    }
  },

  updateResearchProgress() {
    const r = state.research, el = r && document.querySelector(`.tech[data-tech-id="${r.id}"] .tech-prog`);
    if (!el) return;
    el.querySelector('.bar > div').style.width = `${(1 - r.left / TECH_BY_ID[r.id].days) * 100}%`;
    el.querySelector('b').textContent = r.left;
    const n = $('now-left');
    if (n) n.textContent = r.left;
  },

  drawTechLines() {
    const svg = $('tree-lines');
    if (!svg) return;
    const wrap = svg.parentElement, box = wrap.getBoundingClientRect();
    svg.setAttribute('width', wrap.scrollWidth);
    svg.setAttribute('height', wrap.scrollHeight);
    let d = '';
    for (const t of TECHS) {
      const to = wrap.querySelector(`[data-tech-id="${t.id}"]`);
      if (!to) continue;
      const b = to.getBoundingClientRect();
      for (const r of t.req) {
        const from = wrap.querySelector(`[data-tech-id="${r}"]`);
        if (!from) continue;
        const a = from.getBoundingClientRect();
        const x1 = a.right - box.left + wrap.scrollLeft, y1 = a.top + a.height / 2 - box.top + wrap.scrollTop;
        const x2 = b.left - box.left + wrap.scrollLeft, y2 = b.top + 22 - box.top + wrap.scrollTop;
        const mx = (x1 + x2) / 2;
        d += `<path d="M${x1},${y1} C${mx},${y1} ${mx},${y2} ${x2},${y2}" class="${hasTech(r) ? 'done' : ''}"/>`;
      }
    }
    svg.innerHTML = d;
  },

  renderGoods(el) {
    const S = state.stats, cap = storageCap();
    const trade = Trade.active();
    const producers = g => {
      const list = Object.entries(BUILDINGS).filter(([, d]) => d.produces && d.produces[g]).map(([k, d]) => `<img src="${this.icons[k]}" alt="" title="${d.name}" data-card="${k}">`);
      return list.join('');
    };
    let html = `<div class="explain">${Icons.img('store', 'big')}<div><b>Всё, что производит город, лежит на общих складах.</b>
      <p>Каждого товара помещается ${fmt(cap)}; каждый склад добавляет ${WAREHOUSE_STORAGE}. Дома получают еду, масло, хлеб и вино через ближайший рынок.</p></div></div>`;
    if (!trade) html += '<p class="note">Торговый пост (исследование «Торговля») позволит продавать излишки и докупать нехватку.</p>';
    for (const grp of GOOD_GROUPS) {
      html += `<h3 class="grp">${grp.name}</h3><div class="goods-list">`;
      for (const g of grp.goods) {
        const v = state.goods[g], p = (S.prod || {})[g] || 0, c = (S.cons || {})[g] || 0;
        const pct = Math.min(100, v / cap * 100);
        html += `<div class="good-row ${v < 0.5 && c > 0 ? 'short' : ''}">
          <div class="gname">${Icons.img(g)}<b>${GOODS[g].name}</b></div>
          <div class="gstock"><div class="bar"><div style="width:${pct}%"></div></div><span>${fmt(v)} / ${fmt(cap)}</span></div>
          <div class="gflow"><span class="pos">${p ? '+' + p.toFixed(1) : ''}</span><span class="neg">${c ? '−' + c.toFixed(1) : ''}</span></div>
          <div class="gsrc">${producers(g)}</div>
          <div class="guse">${GOOD_USE[g]}</div>
          ${trade ? `<div class="gtrade"><label class="tg"><input type="checkbox" data-sell="${g}" ${state.trade.sell[g] ? 'checked' : ''}> продавать</label><label class="tg"><input type="checkbox" data-buy="${g}" ${state.trade.buy[g] ? 'checked' : ''}> докупать</label><small>${GOODS[g].price} ден.</small></div>` : ''}
        </div>`;
      }
      html += '</div>';
    }
    if (trade) html += `<p class="sub">Караван приходит раз в ${TRADE_INTERVAL} дней: продаёт то, чего больше 60% склада, и докупает то, чего меньше 15% (в 1,6 раза дороже).</p>`;
    el.innerHTML = html;
    el.querySelectorAll('[data-sell]').forEach(i => i.onchange = () => { state.trade.sell[i.dataset.sell] = i.checked; });
    el.querySelectorAll('[data-buy]').forEach(i => i.onchange = () => { state.trade.buy[i.dataset.buy] = i.checked; });
  },

  renderGuide(el) {
    const tierTable = (tiers) => `<div class="tiers">${tiers.slice(1).map((T, i) => `
      <div class="tier"><b>${T.name}</b><small>${T.cap} жит. · ${CLASSES[T.cls].name.toLowerCase()}</small>
      <div class="need-icons">${T.needs.filter(n => n !== 'road').map(n => `<span title="${NEED_LABELS[n]}">${Icons.img(NEED_ICON[n])}</span>`).join('')}${T.beauty ? `<span title="Красота ${T.beauty}+">${Icons.img('glory')}${T.beauty}</span>` : ''}</div>
      <small class="need-text">+ ${[...T.needs.filter(n => !tiers[i].needs.includes(n)).map(n => NEED_SHORT[n]), ...(T.beauty ? [`красота ${T.beauty}`] : []), ...(T.maxCrowd !== undefined ? ['простор'] : [])].join(', ')}</small></div>`).join('<span class="arrow">→</span>')}</div>`;
    el.innerHTML = `
      <div class="guide">
        <section><h3>Как растёт город</h3>
          <ol class="steps">
            <li><b>Дорога и дома.</b> Дома у дороги заселяются и платят налоги.</li>
            <li><b>Удобства рядом.</b> Каждая служба действует в своём круге: колодец поит, рынок кормит, храм благословляет.</li>
            <li><b>Товары.</b> Поля, рощи и мастерские наполняют склады; рынки раздают товары домам.</li>
            <li><b>Знания.</b> Храмы и школы пишут свитки — на них открываются новые постройки.</li>
            <li><b>Классы.</b> Хижины дают плебеев для полей, инсулы — граждан для мастерских, домусы — патрициев для театра и форума.</li>
            <li><b>Слава.</b> Легион побеждает врагов провинции и приносит Славу для чудес света.</li>
          </ol>
        </section>
        <section><h3>Классы жителей</h3>
          <div class="classes">${Object.entries(CLASSES).map(([k, c]) => `<div class="cls-card" style="--c:${c.color};--b:${c.soft}">${Icons.cls(k, 34)}<div><b>${c.name}</b><p>Живут: ${[PLEB_TIERS, PATRICIAN_TIERS].flatMap(ts => ts.filter(t => t.cls === k).map(t => t.name.toLowerCase())).join(', ')}.</p><p>Работают: ${c.work}.</p></div></div>`).join('')}</div>
          <p class="sub">Цветной значок в углу карточки постройки показывает, кто в ней работает. Лишние граждане подменяют плебеев, лишние патриции — граждан.</p></section>
        <section><h3>Дом плебеев (2×2)</h3>${tierTable(PLEB_TIERS)}</section>
        <section><h3>Участок патриция (3×3)</h3>${tierTable(PATRICIAN_TIERS)}<p class="sub">Виллам и дворцам нужен простор: не больше 2–3 домов рядом.</p></section>
        <section><h3>Счастье и деньги</h3>
          <p>Счастье растёт от удобств рядом, красоты (украшения, деревья, вода) и праздников; падает от тесноты и высоких налогов. Счастливые платят больше. Каждая постройка стоит денег на содержание — следите за доходом рядом с монетой.</p></section>
        <section><h3>Управление</h3>
          <ul class="keys">
            <li><kbd>ЛКМ</kbd> строить и выбирать</li><li><kbd>ПКМ</kbd> двигать карту, отменить</li>
            <li><kbd>Колесо</kbd> масштаб</li><li><kbd>Средняя кнопка</kbd> вращение</li>
            <li><kbd>W A S D</kbd> камера</li><li><kbd>Q</kbd> <kbd>E</kbd> поворот</li>
            <li><kbd>R</kbd> дорога</li><li><kbd>H</kbd> дом</li><li><kbd>X</kbd> снос</li>
            <li><kbd>F</kbd> знания</li><li><kbd>L</kbd> легион</li><li><kbd>Пробел</kbd> пауза</li>
            <li><kbd>1</kbd> <kbd>2</kbd> <kbd>3</kbd> скорость</li><li><kbd>Esc</kbd> отмена</li>
          </ul>
          <p class="sub">На телефоне: одним пальцем двигайте карту или стройте, двумя — масштаб и поворот.</p></section>
      </div>`;
  },

  renderJournal(el) {
    const list = state.journal || [];
    el.innerHTML = list.length ? `<ul class="journal">${list.map((j, i) => `
      <li class="${j.kind}"><span class="jday">${dateText(j.day)}, день ${j.day % DAYS_PER_SEASON + 1}</span><span class="jtext">${escapeHtml(j.text)}</span>${j.ref ? `<button type="button" class="btn tiny ghost" data-j="${i}">Показать</button>` : ''}</li>`).join('')}</ul>`
      : '<p class="sub">Пока ничего не произошло. Здесь будут все события города.</p>';
    el.querySelectorAll('[data-j]').forEach(b => b.onclick = () => {
      const r = list[+b.dataset.j].ref;
      this.closeWindow();
      Engine.lookAt(r.x + 1, r.y + 1);
      const h = buildingAt(r.x, r.y);
      if (h) this.openPanel(h);
    });
  },

  // совместимость
  openResearch() { this.openWindow('research'); },
  openStore() { this.openWindow('goods'); },
  openHelp() { this.openWindow('guide'); },

  /* ---------- Небольшие окна ---------- */

  showModal(html, size) {
    $('modal').className = 'panel' + (size ? ' ' + size : '');
    $('modal').innerHTML = html;
    $('modal-back').hidden = false;
    this.modalOpen = true;
  },

  closeModal() {
    if (!this.modalOpen) return false;
    $('modal-back').hidden = true;
    this.modalOpen = false;
    return true;
  },

  openBuyPlot(px, py) {
    const price = plotPrice();
    const short = price - state.money;
    const f = plotFeatures(px, py);
    const feats = [];
    if (f.marble) feats.push(`<li>${Icons.img('marble')}<span>Мрамор</span><b>${f.marble}</b></li>`);
    if (f.iron) feats.push(`<li>${Icons.img('iron')}<span>Железо</span><b>${f.iron}</b></li>`);
    if (f.stone) feats.push(`<li>${Icons.img('stone')}<span>Камень</span><b>${f.stone}</b></li>`);
    if (f.trees) feats.push(`<li>${Icons.img('wood')}<span>Деревья</span><b>${f.trees}</b></li>`);
    if (f.water) feats.push(`<li>${Icons.img('fish')}<span>Вода</span><b>${f.water}</b></li>`);
    const dir = py < 0 ? 'севере' : py > 0 ? 'юге' : px > 0 ? 'востоке' : 'западе';
    this.showModal(`
      <p class="eyebrow">Новая земля</p>
      <h2>Участок на ${dir}</h2>
      <p class="sub">${PLOT} × ${PLOT} клеток. Что на нём есть:</p>
      <ul class="feats">${feats.join('') || '<li>Чистое поле</li>'}</ul>
      <p class="price">${Icons.img('money')} ${fmt(price)}</p>
      ${short > 0 ? `<p class="note bad">Не хватает ${fmt(short)} денариев.</p>` : ''}
      <div class="actions">
        <button type="button" class="btn" id="buy-yes" ${short > 0 ? 'disabled' : ''}>Купить участок</button>
        <button type="button" class="btn ghost" id="buy-no">Не сейчас</button>
      </div>`);
    $('buy-no').onclick = () => this.closeModal();
    $('buy-yes').onclick = () => {
      if (buyPlot(px, py)) {
        this.closeModal();
        this.log('Куплен новый участок земли.', 'good', true);
        afterCityChanged();
      }
    };
  },

  openMenu() {
    const seg = (name, items, cur) => `<div class="seg wide" role="group">${items.map(([v, label, sub]) => `<button type="button" data-${name}="${v}" class="${String(cur) === String(v) ? 'on' : ''}">${label}${sub ? `<small>${sub}</small>` : ''}</button>`).join('')}</div>`;
    this.showModal(`
      <p class="eyebrow">CivCity · версия 0.4</p>
      <h2>Настройки</h2>
      <label class="field" for="city-input">Название города
        <input id="city-input" maxlength="28" value="${escapeHtml(state.cityName)}">
      </label>
      <p class="field-label">Налоги</p>
      ${seg('tax', TAX_LEVELS.map((t, i) => [i, t.name, t.mult < 1 ? 'жители рады' : t.mult > 1 ? 'жители недовольны' : '×1']), state.taxLevel)}
      <p class="field-label">Качество графики</p>
      ${seg('q', [['low', 'Низкое', 'для слабых ПК'], ['medium', 'Среднее', 'телефоны'], ['high', 'Высокое', 'вау-режим']], Settings.quality)}
      <label class="switch"><input type="checkbox" id="day-cycle" ${Settings.dayCycle ? 'checked' : ''}><span></span>Смена дня и ночи</label>
      ${TEST_MODE ? `<div class="note good"><b>Это тестовый город.</b> У него своё сохранение, ваш настоящий город не трогается.
        <div class="actions"><button type="button" class="btn small" id="test-give">+30 000 денариев, товары, свитки и Слава</button>
        <a class="btn small ghost" href="./">В свой город</a></div></div>` : ''}
      <div class="actions">
        <button type="button" class="btn ghost" id="menu-help">Справка</button>
        <button type="button" class="btn ghost" id="menu-new">Новый город</button>
        <button type="button" class="btn" id="menu-close">Продолжить</button>
      </div>
      <p class="sub">Игра сохраняется сама каждые 15 секунд в этом браузере.</p>`);
    const input = $('city-input');
    input.addEventListener('input', () => { state.cityName = input.value.trim() || 'Нова Рома'; this.updateHud(true); });
    document.querySelectorAll('[data-tax]').forEach(b => b.onclick = () => {
      state.taxLevel = +b.dataset.tax;
      document.querySelectorAll('[data-tax]').forEach(x => x.classList.toggle('on', x === b));
      afterCityChanged();
    });
    document.querySelectorAll('[data-q]').forEach(b => b.onclick = () => {
      Settings.quality = b.dataset.q;
      Settings.save();
      Engine.setQuality(Settings.quality);
      document.querySelectorAll('[data-q]').forEach(x => x.classList.toggle('on', x === b));
    });
    $('day-cycle').onchange = () => {
      Settings.dayCycle = $('day-cycle').checked;
      Settings.save();
      Atmos.cycle = Settings.dayCycle;
      if (!Atmos.cycle) Atmos.t = 0.42;
    };
    $('menu-close').onclick = () => this.closeModal();
    if (TEST_MODE) $('test-give').onclick = () => { Test.give(); this.toast('Добавлено: деньги, товары, свитки и Слава', 'good'); };
    $('menu-help').onclick = () => { this.closeModal(); this.openWindow('guide'); };
    $('menu-new').onclick = () => {
      this.showModal(`
        <h2>Начать заново?</h2>
        <p>Город «${escapeHtml(state.cityName)}» будет удалён без возможности вернуть.</p>
        <div class="actions">
          <button type="button" class="btn danger" id="new-yes">Да, новый город</button>
          <button type="button" class="btn ghost" id="new-no">Отмена</button>
        </div>`);
      $('new-no').onclick = () => this.closeModal();
      $('new-yes').onclick = () => { this.closeModal(); Game.newGame(); };
    };
  },

  // Короткое уведомление — только о важном и о прямой реакции на действие игрока
  toast(msg, kind) {
    const box = $('toasts');
    for (const t of box.children) if (t.dataset.msg === msg) return;
    const el = document.createElement('div');
    el.className = 'toast ' + (kind || '');
    el.dataset.msg = msg;
    el.textContent = msg;
    box.append(el);
    while (box.children.length > 3) box.firstChild.remove();
    setTimeout(() => el.classList.add('out'), 3200);
    setTimeout(() => el.remove(), 3700);
  },

  // Запись в журнал; toast — показать ещё и всплывашкой
  log(text, kind, toast, ref) {
    Journal.add(text, kind, ref);
    if (toast) this.toast(text, kind === 'warn' ? 'warn' : 'good');
  },

  /* ---------- Подсказки при наведении ---------- */

  initTooltips() {
    const tip = $('tooltip');
    let timer = 0, cur = null;
    const show = (el) => {
      const html = this.tipHtml(el);
      if (!html) return;
      tip.innerHTML = html;
      tip.hidden = false;
      const r = el.getBoundingClientRect(), tr = tip.getBoundingClientRect();
      let x = r.left + r.width / 2 - tr.width / 2, y = r.bottom + 10;
      if (y + tr.height > window.innerHeight - 8) y = r.top - tr.height - 10;
      x = clamp(x, 8, window.innerWidth - tr.width - 8);
      tip.style.left = x + 'px';
      tip.style.top = Math.max(8, y) + 'px';
    };
    document.addEventListener('pointerover', e => {
      const el = e.target.closest('[data-tip], [data-card], [data-tip-text]');
      if (el === cur) return;
      cur = el;
      clearTimeout(timer);
      tip.hidden = true;
      if (el && e.pointerType !== 'touch') timer = setTimeout(() => show(el), 220);
    });
    document.addEventListener('pointerdown', () => { clearTimeout(timer); tip.hidden = true; cur = null; });
  },

  tipHtml(el) {
    if (el.dataset.tipText) return `<p>${escapeHtml(el.dataset.tipText)}</p>`;
    if (el.dataset.card) return this.cardTip(el.dataset.card);
    const S = state.stats, k = el.dataset.tip;
    const T = (title, text) => `<b>${title}</b><p>${text}</p>`;
    if (k.startsWith('class:')) {
      const c = k.slice(6), C = CLASSES[c], Rc = (S.residents || {})[c] || 0;
      const homes = [PLEB_TIERS, PATRICIAN_TIERS].flatMap(ts => ts.filter(t => t.cls === c).map(t => t.name.toLowerCase()));
      return `<div class="cls-tip">${Icons.cls(c, 28)}<div>${T(`${C.name}: ${fmt(Rc)}`, `Счастье: ${Rc ? (S.happyCls || {})[c] + '%' : '—'}<br>Живут: ${homes.join(', ')}<br>Работают: ${C.work}<br>Рабочих мест занято: ${fmt((S.filled || {})[c] || 0)} из ${fmt((S.jobs || {})[c] || 0)}`)}</div></div>`;
    }
    if (k.startsWith('good:')) {
      const g = k.slice(5), p = (S.prod || {})[g] || 0, c = (S.cons || {})[g] || 0;
      return T(`${GOODS[g].name}: ${fmt(state.goods[g])} из ${fmt(S.cap || BASE_STORAGE)}`, `${GOOD_USE[g]}<br>За день: +${p.toFixed(1)} / −${c.toFixed(1)}. Нажмите, чтобы открыть склады.`);
    }
    const R = S.residents || {};
    const nextRank = CITY_RANKS.find(([n]) => n > (S.pop || 0));
    switch (k) {
      case 'city': return T(`${escapeHtml(state.cityName)} — ${cityRank(S.pop || 0)}`, `${nextRank ? `Следующее звание «${nextRank[1]}» — при ${fmt(nextRank[0])} жителях.` : 'Высшее звание!'} Нажмите, чтобы открыть настройки.`);
      case 'money': return T('Денарии', `Налоги: +${(S.taxes || 0).toFixed(1)} в день<br>Содержание построек: −${(S.upkeep || 0).toFixed(1)} в день<br>Ставка: ${TAX_LEVELS[state.taxLevel].name.toLowerCase()} (меняется в настройках).`);
      case 'pop': return T(`Жители: ${fmt(S.pop || 0)}`, Object.entries(CLASSES).map(([c, v]) => `${v.name}: ${fmt(R[c] || 0)}`).join('<br>') + '<br>Половина жителей работает.');
      case 'happy': return T(`Счастье: ${S.pop ? S.happy + '%' : '—'}`, 'Растёт от удобств рядом с домом, красоты, праздников и низких налогов. Падает от тесноты и высоких налогов. Счастливые платят больше.');
      case 'workers': return T('Работники', Object.entries(CLASSES).map(([c, v]) => `${v.name}: занято ${fmt((S.filled || {})[c] || 0)} из ${fmt((S.jobs || {})[c] || 0)} мест, свободно ${fmt((S.spare || {})[c] || 0)}`).join('<br>') + '<br>Лишние граждане идут работать за плебеев.');
      case 'food': return T(`Еда: ${fmt(state.goods.wheat + state.goods.fish)}`, `Пшеница ${fmt(state.goods.wheat)} и рыба ${fmt(state.goods.fish)}. Дома получают еду через рынок. Нажмите, чтобы открыть склады.`);
      case 'scrolls': return T(`Свитки: ${fmt(state.scrolls)}`, `Знания Рима. Пишут храмы, школы и форум${S.scrollRate ? ` (+${S.scrollRate.toFixed(1)} в день)` : ''}. Тратятся в «Знаниях» на новые постройки. Нажмите, чтобы открыть.`);
      case 'glory': return T(`Слава: ${fmt(state.glory)}`, 'Даётся за победы в походах и чудеса света. Нужна для Военного дела, умений в бою, Колизея, Пантеона и праздника-триумфа.');
      case 'date': return T(dateText(state.day), `День ${state.day % DAYS_PER_SEASON + 1} из ${DAYS_PER_SEASON}. Один игровой день — около ${DAY_SECONDS} секунд на скорости ×1.`);
      case 'speed0': return T('Пауза', 'Пробел');
      case 'speed1': return T('Скорость ×1', 'Клавиша 1');
      case 'speed2': return T('Скорость ×2', 'Клавиша 2');
      case 'speed3': return T('Скорость ×3', 'Клавиша 3');
      case 'rotl': return T('Повернуть камеру', 'Клавиша Q');
      case 'rotr': return T('Повернуть камеру', 'Клавиша E');
      case 'menu': return T('Настройки', 'Налоги, графика, смена дня и ночи, новый город.');
      case 'bulldoze': return T('Снос', 'Клавиша X. Возвращается половина стоимости.');
      case 'rail-research': {
        const r = state.research;
        return T('Знания', r ? `Изучается «${TECH_BY_ID[r.id].name}»: осталось ${r.left} ${plural(r.left, 'день', 'дня', 'дней')}. Клавиша F.` : 'Знания за свитки открывают новые постройки. Изучаются по одному, несколько дней. Клавиша F.');
      }
      case 'rail-goods': return T('Товары', 'Сколько всего на складах, откуда берётся и куда уходит. Торговля.');
      case 'rail-legion': return T('Легион', 'Карта провинции, походы и Слава. Клавиша L.');
      case 'rail-guide': return T('Справка', 'Как растут дома, классы, управление.');
      case 'rail-journal': return T('Журнал', 'Все события города: рост, нехватки, победы.');
    }
    return '';
  },

  cardTip(type) {
    const d = BUILDINGS[type];
    const rows = [];
    if (d.jobs) { const [c, n] = Object.entries(d.jobs)[0]; rows.push(`${Icons.img('workers')} ${n} ${CLASSES[c].gen}`); }
    if (d.consumes) rows.push(`Тратит: ${Object.entries(d.consumes).map(([g, r]) => `${Icons.img(g)}${r}`).join(' ')}`);
    if (d.produces) rows.push(`Даёт: ${Object.entries(d.produces).map(([g, r]) => `${Icons.img(g)}${r}`).join(' ')} в день`);
    if (d.radius) rows.push(`Радиус: ${d.radius} клеток`);
    if (d.beauty) rows.push(`Красота: +${d.beauty}`);
    if (d.scrolls) rows.push(`${Icons.img('scrolls')} ${d.scrolls} в день`);
    if (d.upkeep) rows.push(`Содержание: ${d.upkeep} в день`);
    return `<div class="card-tip"><img src="${this.icons[type]}" alt=""><div><b>${d.name}</b><p>${d.desc}</p>
      ${rows.length ? `<p class="tip-rows">${rows.join(' · ')}</p>` : ''}
      <p class="tip-cost">${this.costHtml(d.cost)}</p>
      ${!isUnlocked(type) ? `<p class="tip-lock">Нужно: «${lockName(type)}»${!hasTech(d.tech) && TECH_BY_ID[d.tech].pop ? ` (с ${fmt(TECH_BY_ID[d.tech].pop)} жителей)` : ''}</p>` : ''}</div></div>`;
  },

  /* ---------- Метки над картой ---------- */

  floatText(x, y, z, text, kind) {
    this.floats.push({ x, y, z, text, kind, t: 0 });
  },

  updateLabels(dt) {
    const box = $('labels');
    const used = new Set();
    const put = (key, x, y, z, make) => {
      const [sx, sy, vis] = Engine.project(x, y, z);
      if (!vis) return null;
      let el = this.labels.get(key);
      if (!el) { el = make(); box.append(el); this.labels.set(key, el); }
      el.style.transform = `translate(${sx.toFixed(1)}px, ${sy.toFixed(1)}px)`;
      used.add(key);
      return el;
    };
    let n = 0;
    for (const b of state.buildings.values()) {
      if (n > 120) break;
      const d = BUILDINGS[b.type];
      if (d.kind === 'road' || d.kind === 'decor') continue;
      const hgt = d.kind === 'house' ? d.tiers[b.tier].height : 1.1;
      const cx = b.x + b.w / 2, cz = b.y + b.h / 2;
      if ((d.needsRoad || d.kind === 'house') && b.road === false) {
        if (put('w' + b.id, cx, hgt + 0.35, cz, () => Object.assign(document.createElement('div'), { className: 'lbl warn', textContent: '!', title: 'Нет дороги рядом' }))) n++;
      } else if (b.req) {
        const el = put('r' + b.id + b.req.type, cx, hgt + 0.35, cz, () => {
          const e = document.createElement('button');
          e.type = 'button';
          e.className = 'lbl bubble';
          e.dataset.tipText = `Жители просят: ${BUILDINGS[b.req.type].name.toLowerCase()} рядом с домом`;
          e.innerHTML = `<img src="${this.icons[b.req.type]}" alt="">`;
          e.onclick = () => this.openPanel(b);
          return e;
        });
        if (el) n++;
      } else if (d.kind === 'house' && b.down > 2) {
        if (put('d' + b.id, cx, hgt + 0.35, cz, () => {
          const e = document.createElement('button');
          e.type = 'button';
          e.className = 'lbl down';
          e.textContent = '↓';
          e.dataset.tipText = 'Дом приходит в упадок — нажмите, чтобы узнать причину';
          e.onclick = () => this.openPanel(b);
          return e;
        })) n++;
      }
    }
    const price = plotPrice();
    for (const p of Engine.plots.values()) {
      if (!canBuyPlot(p.px, p.py)) continue;
      const el = put('p' + p.px + ',' + p.py, p.px * PLOT + PLOT / 2, 1.6, p.py * PLOT + PLOT / 2, () => {
        const e = document.createElement('button');
        e.type = 'button';
        e.className = 'lbl sign';
        e.onclick = () => this.openBuyPlot(p.px, p.py);
        return e;
      });
      if (el) {
        const html = `<small>Купить землю</small><b class="${state.money < price ? 'short' : ''}">${fmt(price)}</b>`;
        if (el.innerHTML !== html) el.innerHTML = html;
      }
    }
    const alive = [];
    for (const f of this.floats) {
      f.t += dt;
      if (f.t > 2.4) continue;
      alive.push(f);
      const el = put('f' + f.x + f.z + f.text, f.x, f.y + f.t * 0.5, f.z, () => Object.assign(document.createElement('div'), { className: 'lbl float ' + f.kind, textContent: f.text }));
      if (el) el.style.opacity = f.t > 1.8 ? (2.4 - f.t) / 0.6 : 1;
    }
    this.floats = alive;
    for (const [key, el] of this.labels) if (!used.has(key)) { el.remove(); this.labels.delete(key); }
  },

  // совместимость со старыми вызовами
  refreshPanelSoon() { this.refreshPanel(); },
};
