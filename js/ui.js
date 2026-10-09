'use strict';
/* Интерфейс поверх 3D-карты — просто, как в Town to City: слева сверху карточка города со временем и значки тревог,
   под ней задания; справа сверху «Легион», «К городу» и меню; внизу док стройки (мостовая, постройки, инструменты);
   справа внизу казна, знания и Слава. Ещё — карточка здания, окно «Империя», настройки, подсказки, метки над картой. */

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
  grapes: 'Сырьё для винодельни.', wine: 'Нужно виллам и дворцам.', wood: 'Покупают купцы; кузница делает из него оружие, мастерские — машины легиона.',
  stone: 'Покупают купцы.', clay: 'Сырьё для кирпичной мастерской.', bricks: 'Чудеса света и прокачка легиона; покупают купцы.',
  marble: 'Чудеса света и прокачка легиона; купцы платят дорого.', iron: 'Сырьё для кузницы.', weapons: 'Казармы превращают его в легионеров.',
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
    $('menu-btn').onclick = () => this.toggleMenu();
    $('home-btn').onclick = () => Engine.flyHome();
    $('show-ui').onclick = () => this.setUiHidden(false);
    for (const id of ['city-btn', 'st-pop', 'st-happy', 'st-work']) $(id).onclick = () => this.openCity();
    document.querySelector('.tr-money').onclick = () => this.openCity();
    $('legion-btn').onclick = () => this.openWindow('legion');
    $('tr-scrolls').onclick = () => this.openWindow('research');
    $('tr-glory').onclick = () => this.openWindow(Army.unlocked() ? 'legion' : 'research');
    $('tr-scrolls-ico').innerHTML = Icons.img('scrolls');
    $('tr-glory-ico').innerHTML = Icons.img('glory');
    // меню закрывается нажатием мимо него
    document.addEventListener('pointerdown', e => { if (!$('menu-pop').hidden && !e.target.closest('#menu-pop, #menu-btn')) this.closeMenu(); });
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

  // Цена на карточке: денарии крупно, остальное (пока стройка тратит и товары) — мелко рядом
  priceHtml(cost) {
    return Object.entries(cost).map(([res, v]) =>
      `<span class="cost ${res === 'money' ? 'main' : 'extra'} ${this.have(res) < v ? 'short' : ''}">${Icons.img(res)}${fmt(v)}</span>`).join('');
  },

  /* ---------- Карточка города, казна и значки ---------- */

  updateHud(force) {
    const t = performance.now();
    if (!force && t - this.lastHud < 250) return;
    this.lastHud = t;
    const S = state.stats;
    $('city-name').textContent = state.cityName;
    $('city-rank').textContent = cityRank(S.pop || 0) + (TEST_MODE ? ' · тест' : '');
    // прогресс до следующего звания города
    const pop = S.pop || 0;
    let lo = 0, hi = CITY_RANKS[1][0];
    for (let i = 0; i < CITY_RANKS.length; i++) if (pop >= CITY_RANKS[i][0]) { lo = CITY_RANKS[i][0]; hi = (CITY_RANKS[i + 1] || [lo * 2])[0]; }
    $('rank-bar').style.width = `${clamp((pop - lo) / Math.max(1, hi - lo), 0, 1) * 100}%`;
    // жители и счастье — одной цифрой; подробности по классам — в карточке города
    $('v-pop').textContent = fmt(pop);
    const h = pop ? S.happy : null;
    $('v-happy').textContent = h === null || h === undefined ? '—' : h + '%';
    $('st-happy').className = 'stat' + (h === null || h === undefined ? '' : h >= 60 ? ' good' : h >= 40 ? ' mid' : ' bad');
    // работники видны, только когда их не хватает
    let short = false, f = 0, jobs = 0;
    for (const k of Object.keys(CLASSES)) {
      const j = (S.jobs || {})[k] || 0, fl = (S.filled || {})[k] || 0;
      f += fl; jobs += j;
      if (j > fl) short = true;
    }
    $('st-work').hidden = !short;
    $('v-work').textContent = `${fmt(f)}/${fmt(jobs)}`;
    $('v-date').textContent = `Год ${roman(Math.floor(state.day / (DAYS_PER_SEASON * 4)) + 1)}`;
    $('v-season').textContent = `${SEASONS[Math.floor(state.day / DAYS_PER_SEASON) % 4]}, день ${state.day % DAYS_PER_SEASON + 1}`;
    // казна
    $('v-money').textContent = fmt(state.money);
    const tcap = treasuryCap();
    $('v-cap').textContent = `/ ${fmt(tcap)}`;
    document.querySelector('.tr-money').classList.toggle('full', state.money >= tcap - 1);
    const inc = S.income || 0;
    $('v-income').textContent = `${inc >= 0 ? '+' : '−'}${fmt(Math.abs(inc))} в день`;
    $('v-income').classList.toggle('neg', inc < 0);
    // знания: сколько свитков, можно ли что-то изучить, ход изучения
    $('v-scrolls').textContent = fmt(state.scrolls);
    const ready = TECHS.filter(canResearch).length;
    const br = $('b-research'); br.hidden = !ready; br.textContent = ready;
    const rs = state.research;
    $('tr-prog').hidden = !rs;
    if (rs) $('tr-prog').style.setProperty('--p', `${(1 - rs.left / TECH_BY_ID[rs.id].days) * 100}%`);
    if (this.winOpen && this.winTab === 'research' && rs && t - (this.lastWin || 0) > 1000) { this.lastWin = t; this.updateResearchProgress(); }
    $('tr-glory').hidden = !(state.glory > 0 || hasTech('legion'));
    $('v-glory').textContent = fmt(state.glory);
    // Легион: кнопка появляется с открытием войск; значок — пора в первый поход или открыто чудо
    $('legion-btn').hidden = !Army.unlocked();
    const fresh = Army.unlocked() && countType('barracks') > 0 && state.army.progress === 0;
    const wOpen = Army.unlocked() && state.army && WONDERS.some(w => Army.wonderState(w) === 'open');
    const bl = $('b-legion'); bl.hidden = !fresh && !wOpen; bl.textContent = '!';
    const bm = $('b-menu'); bm.hidden = !state.journalUnread; bm.textContent = Math.min(99, state.journalUnread || 0);
    Alerts.render();
    Tasks.render();
    Advisor.render();
    this.layoutHud();
    ArmyUI.tick();
    this.updateTrayAfford();
    if (this.winOpen && this.winTab === 'goods' && t - (this.lastWin || 0) > 1000) { this.lastWin = t; this.renderWindow(); }
  },

  // Задания встают под карточку города, советник — под задания, мини-карта — над казной
  layoutHud() {
    const root = document.documentElement.style;
    const set = (k, v) => { if (this['_' + k] !== v) { this['_' + k] = v; root.setProperty('--' + k, v + 'px'); } };
    set('hud-b', Math.round(document.querySelector('.hud-city').getBoundingClientRect().bottom));
    const tasks = $('tasks');
    set('tasks-b', Math.round(tasks.children.length ? tasks.getBoundingClientRect().bottom : this['_hud-b'] || 140));
    set('tr-h', Math.round($('treasury').getBoundingClientRect().height));
  },

  /* ---------- Меню ☰ ---------- */

  toggleMenu() { if ($('menu-pop').hidden) this.openMenuPop(); else this.closeMenu(); },

  openMenuPop() {
    const items = [
      ['research', 'Знания', 'F'], ['goods', 'Товары и склады', ''],
      ...(Army.unlocked() ? [['legion', 'Легион', 'L'], ['wonders', 'Чудеса света', '']] : []),
      ['guide', 'Справка', ''], ['journal', 'Журнал', state.journalUnread ? String(Math.min(99, state.journalUnread)) : ''],
      null,
      ['settings', 'Настройки', ''], ['hide', 'Спрятать интерфейс', 'U'],
    ];
    const pop = $('menu-pop');
    pop.innerHTML = items.map(it => it ? `<button type="button" data-m="${it[0]}">${Icons.svg({ settings: 'gear', hide: 'eye' }[it[0]] || it[0])}<span>${it[1]}</span>${it[2] ? `<small>${it[2]}</small>` : ''}</button>` : '<hr>').join('');
    pop.querySelectorAll('[data-m]').forEach(btn => btn.onclick = () => {
      const m = btn.dataset.m;
      this.closeMenu();
      if (m === 'settings') this.openMenu();
      else if (m === 'hide') this.setUiHidden(true);
      else this.openWindow(m);
    });
    pop.hidden = false;
  },

  closeMenu() { $('menu-pop').hidden = true; },

  /* ---------- Карточка города: классы жителей, работники, налоги, доходы и расходы ---------- */

  openCity() {
    const S = state.stats, R = S.residents || {};
    const nextRank = CITY_RANKS.find(([n]) => n > (S.pop || 0));
    const cls = Object.entries(CLASSES).map(([c, C]) => {
      const n = R[c] || 0, h = (S.happyCls || {})[c] || 0;
      return `<div class="city-cls">${Icons.cls(c, 30)}<div><b>${C.name}: ${fmt(n)}</b>
        <span>Счастье: ${n ? `<b class="hp ${h >= 60 ? 'good' : h >= 40 ? 'mid' : 'bad'}">${h}%</b>` : '—'}</span>
        <span>Работают: ${C.work}</span>
        <span>Рабочих мест занято: ${fmt((S.filled || {})[c] || 0)} из ${fmt((S.jobs || {})[c] || 0)}</span></div></div>`;
    }).join('');
    const seg = TAX_LEVELS.map((t, i) => `<button type="button" data-tax="${i}" class="${i === state.taxLevel ? 'on' : ''}">${t.name}<small>${t.mult < 1 ? 'жители рады' : t.mult > 1 ? 'жители недовольны' : '×1'}</small></button>`).join('');
    this.showModal(`
      <p class="eyebrow">Ваш город</p>
      <h2>${escapeHtml(state.cityName)} — ${cityRank(S.pop || 0)}</h2>
      <p class="sub">Жителей: ${fmt(S.pop || 0)}, счастье ${S.pop ? S.happy + '%' : '—'}. ${nextRank ? `Следующее звание «${nextRank[1]}» — при ${fmt(nextRank[0])} жителях.` : 'Это высшее звание!'}</p>
      <div class="city-classes">${cls}</div>
      <div class="rows">
        <div class="row"><span>Налоги</span><b>+${fmt(S.taxes || 0)} в день</b></div>
        <div class="row"><span>Купцы покупают излишки</span><b>+${fmt(S.trade || 0)} в день</b></div>
        <div class="row"><span>Содержание построек</span><b>−${fmt(S.upkeep || 0)} в день</b></div>
        <div class="row"><span>Итого</span><b>${(S.income || 0) >= 0 ? '+' : '−'}${fmt(Math.abs(S.income || 0))} в день</b></div>
        <div class="row"><span>Предел казны (растёт со званием города)</span><b>${fmt(treasuryCap())}</b></div>
      </div>
      <p class="field-label">Налоги</p>
      <div class="seg wide" role="group">${seg}</div>
      <div class="actions"><button type="button" class="btn" id="city-close">Закрыть</button></div>`);
    document.querySelectorAll('[data-tax]').forEach(btn => btn.onclick = () => {
      state.taxLevel = +btn.dataset.tax;
      afterCityChanged();
      this.openCity();
    });
    $('city-close').onclick = () => this.closeModal();
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
      if (c.id === 'roads') continue;   // мостовая — кисть слева
      const btn = document.createElement('button');
      btn.className = 'cat' + (c.id === this.openCat ? ' on' : '');
      btn.type = 'button';
      btn.dataset.cat = c.id;
      btn.dataset.tipText = c.name;
      btn.setAttribute('aria-label', c.name);
      const first = c.items.find(isUnlocked) || c.items[0];
      btn.innerHTML = `<img src="${this.icons[first] || ''}" alt="">`;
      const fresh = c.items.some(t => isUnlocked(t) && BUILDINGS[t].tech && !(state.seenTypes || []).includes(t));
      if (fresh) btn.classList.add('fresh');
      btn.onclick = () => {
        if (this.openCat === c.id) { this.closeTray(); return; }
        this.openTray(c.id);
      };
      cats.append(btn);
    }
    // слева — кисть мостовой, справа — копировать, перенести, снести
    const tool = (id, svg, tip, on, click) => {
      const b = document.createElement('button');
      b.type = 'button';
      b.className = 'tool' + (id === 'bulldoze' ? ' bulldoze' : '') + (on ? ' on' : '');
      b.dataset.tool = id;
      b.dataset.tip = 'tool-' + id;
      b.setAttribute('aria-label', tip);
      b.innerHTML = svg.startsWith('img:') ? `<img src="${this.icons[svg.slice(4)] || ''}" alt="">` : Icons.svg(svg);
      b.onclick = click;
      return b;
    };
    $('tools-left').replaceChildren(tool('road', 'img:road', 'Мостовая', this.openCat === 'roads', () => {
      if (this.openCat === 'roads') { this.closeTray(); return; }
      this.openTray('roads');
      Input.setTool('road');
    }));
    const flip = id => () => Input.setTool(Input.tool === id ? null : id);
    $('tools-right').replaceChildren(
      tool('copy', 'dropper', 'Копировать', Input.tool === 'copy', flip('copy')),
      tool('move', 'move', 'Перенести', Input.tool === 'move' || !!Input.moving, flip('move')),
      tool('bulldoze', 'pick', 'Снести', Input.tool === 'bulldoze', flip('bulldoze')),
    );
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
    if (Input.tool && !['bulldoze', 'copy', 'move'].includes(Input.tool)) Input.setTool(null);
    this.buildCats();
  },

  renderTray() {
    const items = $('tray-items');
    items.innerHTML = '';
    const cat = CATEGORIES.find(c => c.id === this.openCat);
    if (!cat) return;
    if (cat.id === 'roads') { this.renderBrush(items); return; }
    // карточка — только картинка и цена (как в Town to City); название и описание — при наведении
    for (const type of cat.items) {
      const d = BUILDINGS[type];
      const unlocked = isUnlocked(type);
      const card = document.createElement('button');
      card.type = 'button';
      card.className = 'card' + (Input.tool === type ? ' on' : '') + (unlocked ? '' : ' locked');
      card.dataset.type = type;
      card.dataset.card = type;
      card.setAttribute('aria-label', d.name);
      card.innerHTML = `<span class="card-img"><img src="${this.icons[type] || ''}" alt="">${unlocked ? '' : '<i class="lock-badge" aria-hidden="true"></i>'}</span>
        <span class="card-cost">${unlocked ? this.priceHtml(d.cost) : `<span class="lock">${Icons.img((d.boss || d.rating) && (!d.tech || hasTech(d.tech)) ? 'glory' : 'scrolls')}${lockName(type)}</span>`}</span>`;
      card.onclick = () => {
        if (!unlocked) { this.openWindow('research', d.tech); return; }
        Input.setTool(Input.tool === type ? null : type);
      };
      items.append(card);
    }
  },

  /* Раздел «Дороги» — кисть мостовой, как в Town to City: покрытия с ценой за клетку, ластик, «улучшить»
     (тропинку и гравий — в мостовую) и ширина кисти */
  renderBrush(items) {
    for (const m of [3, 4, 2, 1, -1, 0]) {
      const p = PAVE[m];
      const card = document.createElement('button');
      card.type = 'button';
      card.className = 'card pave';
      card.dataset.pave = m;
      card.dataset.tipText = m === 0 ? 'Стирает мостовую под кистью. Бесплатно.'
        : m === -1 ? 'Тропинки и гравий под кистью становятся мостовой — платится только разница в цене.' : p.desc + '.';
      const name = m === 0 ? 'Ластик' : m === -1 ? 'Улучшить' : p.name;
      const cost = m === 0 ? '<span class="pave-note">бесплатно</span>' : m === -1 ? '<span class="pave-note">в мостовую</span>'
        : `<span class="cost">${Icons.img('money')}${String(p.cost).replace('.', ',')}</span><span class="pave-note">за клетку</span>`;
      card.innerHTML = `<span class="card-img">${paveSwatch(m)}</span><span class="card-name">${name}</span><span class="card-cost">${cost}</span>`;
      card.onclick = () => {
        Input.brush.mode = m;
        if (Input.tool !== 'road') Input.setTool('road');
        Input.lastGhostKey = '';
        this.onBrushChanged();
      };
      items.append(card);
    }
    const size = document.createElement('div');
    size.className = 'pave-size';
    size.innerHTML = `<span class="pave-size-label">Ширина кисти</span>
      <span class="pave-size-row"><button type="button" data-d="-1" aria-label="Уже">−</button><b id="pave-w"></b><button type="button" data-d="1" aria-label="Шире">+</button></span>
      <input id="pave-r" type="range" min="0" max="${BRUSH_SIZES.length - 1}" step="1" aria-label="Ширина кисти">
      <span class="pave-keys">Shift — прямой линией<br>[ ] — ширина · Ctrl+Z — отменить</span>`;
    size.querySelectorAll('button').forEach(btn => btn.onclick = () => Input.brushSize(+btn.dataset.d));
    size.querySelector('input').oninput = e => { Input.brush.r = BRUSH_SIZES[+e.target.value]; Input.lastGhostKey = ''; this.onBrushChanged(); };
    items.append(size);
    const legend = $('tray-legend');
    if (legend) legend.hidden = true;
    this.onBrushChanged();
  },

  // кисть сменилась (покрытие или ширина): подсветка, ползунок, подсказка
  onBrushChanged() {
    const on = Input.tool === 'road';
    document.querySelectorAll('#tray-items .card.pave').forEach(c => c.classList.toggle('on', on && +c.dataset.pave === Input.brush.mode));
    const r = $('pave-r'), w = $('pave-w');
    if (r) r.value = Math.max(0, BRUSH_SIZES.indexOf(Input.brush.r));
    if (w) w.textContent = fmtW(Input.brush.r * 2);
    if (!on) return;
    const m = Input.brush.mode;
    $('hint-name').textContent = m === 0 ? 'Ластик' : m === -1 ? 'Улучшить до мостовой' : PAVE[m].name;
    $('hint-text').textContent = m === 0 ? 'Ведите с зажатой кнопкой — мостовая под кистью исчезнет.'
      : m === -1 ? 'Ведите по тропинкам и гравию — они станут мостовой.'
      : `${PAVE[m].desc}. Ведите с зажатой кнопкой — хоть всю землю замостите.`;
  },

  // Какие классы работают в постройке (или живут в доме)
  cardClasses(type) {
    const d = BUILDINGS[type];
    if (d.jobs) return Object.keys(d.jobs);
    if (d.tiers) return [...new Set(d.tiers.map(t => t.cls).filter(Boolean))];
    return [];
  },

  updateTrayAfford() {
    document.querySelectorAll('#tray-items .card[data-type]').forEach(card => {
      const type = card.dataset.type;
      if (!isUnlocked(type)) return;
      const d = BUILDINGS[type];
      const html = this.priceHtml(d.cost);
      const el = card.querySelector('.card-cost');
      if (el.innerHTML !== html) el.innerHTML = html;
      card.classList.toggle('poor', !canAfford(d.cost));
    });
  },

  onToolChanged() {
    const t = Input.tool;
    const PICK = ['bulldoze', 'copy', 'move'];
    const cat = t && !PICK.includes(t) && !Input.moving && CATEGORIES.find(c => c.items.includes(t));
    if (cat && cat.id !== this.openCat) this.openTray(cat.id);
    document.querySelectorAll('#tray-items .card[data-type]').forEach(c => c.classList.toggle('on', c.dataset.type === t));
    document.querySelectorAll('.tool[data-tool]').forEach(b => b.classList.toggle('on',
      b.dataset.tool === 'road' ? this.openCat === 'roads' : b.dataset.tool === 'move' ? (t === 'move' || !!Input.moving) : b.dataset.tool === t));
    const hint = $('tool-hint');
    if (!t) { hint.hidden = true; return; }
    hint.hidden = false;
    if (t === 'copy' || t === 'move') {
      $('hint-icon').src = '';
      $('hint-name').textContent = t === 'copy' ? 'Копировать' : 'Перенести';
      $('hint-text').textContent = t === 'copy' ? 'Нажмите на постройку — возьмёте такую же, с тем же поворотом.'
        : 'Нажмите на постройку, а потом — куда её поставить. Перенос бесплатный.';
    } else if (Input.moving) {
      $('hint-icon').src = this.icons[t] || '';
      $('hint-name').textContent = `Перенос: ${BUILDINGS[t].name.toLowerCase()}`;
      $('hint-text').textContent = 'Нажмите, куда поставить: у мостовой встанет фасадом к ней, Z / C — повернуть. Перенос бесплатный. Esc или правая кнопка — вернуть на место.';
    } else if (t === 'bulldoze') {
      $('hint-icon').src = '';
      $('hint-name').textContent = 'Снос';
      $('hint-text').textContent = 'Нажмите на здание, куст или одинокое дерево — вернётся половина стоимости здания. Мостовую стирает ластик в «Дорогах». Залежи и лес вечные.';
    } else {
      const d = BUILDINGS[t];
      $('hint-icon').src = this.icons[t] || '';
      $('hint-name').textContent = d.name;
      $('hint-text').textContent = d.kind === 'decor' ? `${d.desc} Повернуть — Z / C.`
        : `${d.desc} У мостовой встанет фасадом к ней; посреди площади и вдали — повернуть Z / C.`;
    }
    $('hint-status').textContent = '';
    $('hint-status').className = '';
    if (t === 'road') this.onBrushChanged();
    this.closePanel();
  },

  // Строка состояния: залежи рядом, причина отказа
  setToolStatus(type, x, y, err, extra) {
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
    if (extra) { s = extra; el.className = 'good'; }
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
      if (d.storage) {
        html += `<div class="row"><span>${Icons.img('store')} Вместимость складов</span><b>${fmt(storageCap())}</b></div>`;
        if (state.stats.trade) html += `<div class="row"><span>${Icons.img('money')} Купцы покупают излишки</span><b>+${fmt(state.stats.trade)} в день</b></div>`;
      }
      if (d.beauty) html += `<div class="row"><span>${Icons.img('glory')} Красота для соседей</span><b>+${d.beauty}</b></div>`;
      if (d.upkeep) html += `<div class="row"><span>${Icons.img('money')} Содержание в день</span><b>${d.upkeep}</b></div>`;
      html += '</div>';
      html += `<p class="desc">${d.desc}</p>`;
      // полки склада: что лежит в городе (зелёным — то, что купцы забирают сверх запаса)
      if (d.storage) {
        const have = GOOD_IDS.filter(g => state.goods[g] >= 0.5);
        html += `<h3>На складах</h3><div class="shelves">${have.length ? have.map(g => `<span class="good-pill ${Trade.sells(g) ? 'sell' : ''}" title="${GOODS[g].name}${Trade.sells(g) ? ' — купцы забирают всё сверх ' + fmt(Trade.reserve(g)) : ' — копится'}">${Icons.img(g)}<b>${fmt(state.goods[g])}</b></span>`).join('') : '<span class="sub">Пока пусто</span>'}</div>
          <button type="button" class="btn small" id="open-trade">Что продавать, что копить</button>`;
      }
      if (d.kind === 'military') html += ArmyUI.buildingPanel(b);
      if (b.type === 'tradepost') html += `<button type="button" class="btn" id="open-trade">Настроить торговлю</button>`;
    }
    html += `<div class="panel-actions">
      <button type="button" class="btn ghost small" id="panel-move">Переместить</button>
      <button type="button" class="btn ghost small demolish" id="panel-demolish" >Снести (вернётся половина)</button>
    </div>`;
    $('insp-body').innerHTML = html;
    $('panel-move').onclick = () => Input.startMove(b);
    $('panel-demolish').onclick = () => {
      removeBuilding(b, true);
      Engine.dust(b);
      Sound.demolish(b.x + b.w / 2, b.y + b.h / 2);
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
    if (act.open) { this.openWindow(act.open, act.focus); return; }
    this.closeWindow();
    if (act.menu) { this.openMenu(); return; }
    if (act.city) { this.openCity(); return; }
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
    const tabs = [['research', 'Знания'], ['goods', 'Товары'], ['legion', 'Легион'], ['wonders', 'Чудеса'], ['guide', 'Справка'], ['journal', 'Журнал']];
    $('win-tabs').innerHTML = tabs.map(([id, name]) => `<button type="button" class="${id === this.winTab ? 'on' : ''}" data-tab="${id}">${Icons.svg(id === 'goods' ? 'goods' : id)}<span>${name}</span></button>`).join('');
    $('win-tabs').querySelectorAll('[data-tab]').forEach(b => b.onclick = () => this.openWindow(b.dataset.tab));
    $('win-title').textContent = { research: 'Знания Рима', goods: 'Склады и торговля', legion: 'Легион', wonders: 'Чудеса света', guide: 'Справочник', journal: 'Журнал событий' }[this.winTab];
    const body = $('win-body');
    const scroll = body.scrollTop;
    if (this.winTab === 'research') this.renderResearch(body);
    else if (this.winTab === 'goods') this.renderGoods(body);
    else if (this.winTab === 'legion') ArmyUI.render(body);
    else if (this.winTab === 'wonders') ArmyUI.renderWonders(body);
    else if (this.winTab === 'guide') this.renderGuide(body);
    else this.renderJournal(body);
    body.scrollTop = scroll;
  },

  renderResearch(el) {
    this.renderCivilResearch(el);
  },

  renderCivilResearch(el) {
    const cols = [];
    for (const t of TECHS) (cols[t.col] = cols[t.col] || []).push(t);
    const S = state.stats;
    const busy = state.research ? TECH_BY_ID[state.research.id] : null;
    const rec = recommendedTech();
    const card = t => {
      const st = techState(t);
      const cost = techCost(t);
      const afford = state.scrolls >= cost.scrolls && state.money >= cost.money;
      const isRec = rec === t.id;
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
      else foot = `<button type="button" class="btn small${isRec ? ' rec' : rec ? ' ghost' : ''}" data-tech="${t.id}" ${afford && !busy ? '' : 'disabled'}>${cost.free ? 'Изучить бесплатно' : `${Icons.img('scrolls')}${t.scrolls} ${Icons.img('money')}${fmt(t.money)}`}</button>
        <span class="tech-time">${busy ? 'После текущего знания' : days}</span>`;
      // пока советник ведёт к одному знанию, золотой рамкой светится только оно
      const ready = st === 'open' && afford && !busy && (!rec || isRec);
      return `<div class="tech ${st}${focus}${ready ? ' ready' : ''}${isRec && st === 'open' ? ' recommend' : ''}" data-tech-id="${t.id}">
        ${isRec && st === 'open' ? '<span class="tech-badge">Советник: начните с этого</span>' : ''}
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
      if (f) f.scrollIntoView({ block: 'nearest', inline: f.closest('.tcol') === el.querySelector('.tcol') ? 'start' : 'center' });
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
    let html = `<div class="explain">${Icons.img('store', 'big')}<div><b>Всё, что производит город, лежит на складах.</b>
      <p>Каждого товара помещается ${fmt(cap)}; каждый склад добавляет ${WAREHOUSE_STORAGE}. Дома получают еду, масло, хлеб и вино через ближайший рынок.
      Купцы каждый день покупают со складов то, что отмечено «продавать», — всё сверх запаса. Сегодня: +${fmt(S.trade || 0)} денариев.</p></div></div>`;
    if (!Trade.hasWarehouse()) html += '<p class="note bad">Купцы приходят только на склад — постройте его (раздел «Ремёсла»).</p>';
    if (!trade) html += '<p class="note">Без торгового поста купцы платят три четверти цены. Торговый пост (знание «Торговля») — полная цена, а караван докупает то, чего не хватает.</p>';
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
          <div class="gtrade"><label class="tg ${Trade.sells(g) ? 'on' : ''}" title="Купцы забирают всё сверх ${fmt(Trade.reserve(g))}"><input type="checkbox" data-sell="${g}" ${Trade.sells(g) ? 'checked' : ''}> продавать</label>${trade ? `<label class="tg"><input type="checkbox" data-buy="${g}" ${state.trade.buy[g] ? 'checked' : ''}> докупать</label>` : ''}<small>${String(+Trade.price(g).toFixed(2)).replace('.', ',')} ден.</small></div>
        </div>`;
      }
      html += '</div>';
    }
    html += `<p class="sub">Запас, который купцы не трогают: ${TRADE_RESERVE} штук и ещё 10 дней расхода мастерскими и домами${Army.unlocked() ? ', а дерева, кирпича, железа, оружия и мрамора — ещё 150 на прокачку легиона' : ''}. Снимите «продавать», чтобы товар копился.${trade ? ` Караван приходит раз в ${TRADE_INTERVAL} дней и докупает то, чего меньше 15% склада (в 1,6 раза дороже).` : ''}</p>`;
    el.innerHTML = html;
    el.querySelectorAll('[data-sell]').forEach(i => i.onchange = () => { state.trade.sell[i.dataset.sell] = i.checked; this.renderWindow(); });
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
            <li><kbd>R</kbd> мостовая кистью</li><li><kbd>Shift</kbd> прямой линией</li><li><kbd>[</kbd> <kbd>]</kbd> ширина кисти</li><li><kbd>Ctrl</kbd>+<kbd>Z</kbd> отменить мазок</li><li><kbd>H</kbd> дом</li><li><kbd>X</kbd> снос</li><li><kbd>M</kbd> карта</li><li><kbd>Home</kbd> к городу</li><li><kbd>U</kbd> спрятать интерфейс</li>
            <li><kbd>Z</kbd> <kbd>C</kbd> повернуть постройку</li>
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
      const h = (r.id && state.buildings.get(r.id)) || buildingAtPoint(r.x + 1, r.y + 1);
      if (h) this.openPanel(h);
    });
  },

  // совместимость
  openResearch() { this.openWindow('research'); },
  openStore() { this.openWindow('goods'); },
  openHelp() { this.openWindow('guide'); },

  /* ---------- Небольшие окна ---------- */

  // locked — обязательное окно (вход в игру): его не закрыть ни Esc, ни кликом мимо, и другие окна его не перекрывают
  showModal(html, size, locked) {
    if (this.modalLocked && !locked) return;
    this.modalLocked = !!locked;
    $('modal').className = 'panel' + (size ? ' ' + size : '');
    $('modal').innerHTML = html;
    $('modal-back').hidden = false;
    this.modalOpen = true;
  },

  closeModal(force) {
    if (!this.modalOpen) return false;
    if (this.modalLocked && !force) return true;
    $('modal-back').hidden = true;
    this.modalOpen = false;
    this.modalLocked = false;
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

  qName(q) { return { low: 'Низкое', medium: 'Среднее', high: 'Высокое' }[q] || q; },

  // Под качеством графики: на какой видеокарте идёт игра и что делать, если не на той
  gpuNote() {
    const g = Engine.gpuInfo(), name = escapeHtml(g.name || 'не удалось узнать');
    let html = `<p class="sub gpu-line">Видеокарта: ${name}${Settings.qAuto ? ' · качество подбирается само' : ''}</p>`;
    if (g.soft) html += `<div class="note bad"><b>Игра рисуется без видеокарты</b>, поэтому тормозит: в браузере выключено аппаратное ускорение.
      Откройте настройки браузера → «Система» → включите «Использовать аппаратное ускорение» и перезапустите браузер.</div>`;
    else if (g.integrated) html += `<div class="note bad"><b>Игра работает на встроенной графике</b> — она в разы слабее видеокарты.
      Если в компьютере есть видеокарта NVIDIA или AMD, включите её для браузера: Параметры Windows → Система → Дисплей → Графика →
      выберите браузер → «Высокая производительность», затем перезапустите браузер. В программе CivCity для ПК это включается само.</div>`;
    return html;
  },

  openMenu() {
    const seg = (name, items, cur) => `<div class="seg wide" role="group">${items.map(([v, label, sub]) => `<button type="button" data-${name}="${v}" class="${String(cur) === String(v) ? 'on' : ''}">${label}${sub ? `<small>${sub}</small>` : ''}</button>`).join('')}</div>`;
    this.showModal(`
      <p class="eyebrow">CivCity · версия 0.9</p>
      <h2>Настройки</h2>
      <label class="field" for="city-input">Название города
        <input id="city-input" maxlength="28" value="${escapeHtml(state.cityName)}">
      </label>
      <p class="field-label">Налоги</p>
      ${seg('tax', TAX_LEVELS.map((t, i) => [i, t.name, t.mult < 1 ? 'жители рады' : t.mult > 1 ? 'жители недовольны' : '×1']), state.taxLevel)}
      <p class="field-label">Качество графики</p>
      ${seg('q', [['low', 'Низкое', 'для слабых ПК'], ['medium', 'Среднее', 'ноутбуки'], ['high', 'Высокое', 'вау-режим']], Settings.quality)}
      ${this.gpuNote()}
      <button type="button" class="btn small ghost" id="speed-test">Проверить скорость игры</button>
      <label class="switch"><input type="checkbox" id="day-cycle" ${Settings.dayCycle ? 'checked' : ''}><span></span>Смена дня и ночи</label>
      <div class="volumes">
        <label class="vol">Музыка<input type="range" id="vol-music" min="0" max="100" value="${Math.round(Settings.music * 100)}"></label>
        <label class="vol">Звуки<input type="range" id="vol-sfx" min="0" max="100" value="${Math.round(Settings.sfx * 100)}"></label>
      </div>
      ${Account.menuHtml()}
      ${Account.downloadHtml()}
      ${TEST_MODE ? `<div class="note good"><b>Это тестовый город.</b> У него своё сохранение, ваш настоящий город не трогается.
        <div class="actions"><button type="button" class="btn small" id="test-give">+30 000 денариев, товары, свитки и Слава</button>
        <a class="btn small ghost" href="./">В свой город</a></div></div>` : ''}
      <div class="actions">
        <button type="button" class="btn ghost" id="menu-help">Справка</button>
        <button type="button" class="btn" id="menu-close">Продолжить</button>
      </div>
      <p class="sub">Игра сохраняется сама каждые 15 секунд${Account.on ? ' на этом компьютере и раз в минуту — в облаке' : ' на этом компьютере'}.</p>
      <details class="danger-zone"><summary>Начать сначала</summary>
        <p class="sub">Город можно уничтожить и начать с чистого поля. Пропадёт всё: дома, жители, запасы, армия, знания, чудеса, рейтинг.</p>
        <button type="button" class="btn danger small" id="menu-destroy">Уничтожить город…</button>
      </details>`);
    Account.bindMenu();
    const input = $('city-input');
    input.addEventListener('input', () => { state.cityName = input.value.trim() || 'Нова Рома'; this.updateHud(true); });
    document.querySelectorAll('[data-tax]').forEach(b => b.onclick = () => {
      state.taxLevel = +b.dataset.tax;
      document.querySelectorAll('[data-tax]').forEach(x => x.classList.toggle('on', x === b));
      afterCityChanged();
    });
    $('speed-test').onclick = () => Diag.run();
    document.querySelectorAll('[data-q]').forEach(b => b.onclick = () => {
      Settings.quality = b.dataset.q;
      Settings.qAuto = false;
      if (window.civDesktop) civDesktop.setPref('quality', Settings.quality);
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
    const vol = (id, key) => {
      $(id).oninput = () => { Settings[key] = $(id).value / 100; Sound[key] = Settings[key]; Sound.start(); Sound.setVolumes(); };
      $(id).onchange = () => { Settings.save(); if (key === 'sfx') Sound.click(); };
    };
    vol('vol-music', 'music');
    vol('vol-sfx', 'sfx');
    $('menu-close').onclick = () => this.closeModal();
    if (TEST_MODE) $('test-give').onclick = () => { Test.give(); this.toast('Добавлено: деньги, товары, свитки и Слава', 'good'); };
    $('menu-help').onclick = () => { this.closeModal(); this.openWindow('guide'); };
    $('menu-destroy').onclick = () => this.destroyCity(1);
  },

  // «Уничтожить город»: три подтверждения, последнее — написать название города. Город у игрока один,
  // поэтому вместо него сразу появляется чистое поле (и уходит в облако)
  destroyCity(step) {
    const name = state.cityName;
    if (step === 1) {
      this.showModal(`
        <p class="eyebrow">Уничтожить город</p>
        <h2>Уничтожить «${escapeHtml(name)}»?</h2>
        <p>Пропадёт всё: дома, жители, запасы, армия, знания, чудеса, рейтинг и Слава. Вместо города будет чистое поле.</p>
        <div class="actions">
          <button type="button" class="btn ghost" id="dz-no">Нет, оставить</button>
          <button type="button" class="btn danger" id="dz-go">Продолжить</button>
        </div>`);
    } else if (step === 2) {
      this.showModal(`
        <p class="eyebrow">Уничтожить город</p>
        <h2>Точно уничтожить?</h2>
        <p>Это нельзя отменить. Город, который вы строили, исчезнет навсегда.</p>
        <div class="actions">
          <button type="button" class="btn" id="dz-no">Нет, оставить город</button>
          <button type="button" class="btn danger" id="dz-go">Да, уничтожить</button>
        </div>`);
    } else {
      this.showModal(`
        <p class="eyebrow">Последний шаг</p>
        <h2>Напишите название города</h2>
        <p>Чтобы уничтожить город, напишите его название: <b>${escapeHtml(name)}</b></p>
        <label class="field"><input id="dz-name" autocomplete="off" spellcheck="false"></label>
        <div class="actions">
          <button type="button" class="btn ghost" id="dz-no">Отмена</button>
          <button type="button" class="btn danger" id="dz-go" disabled>Уничтожить навсегда</button>
        </div>`);
      const inp = $('dz-name'), go = $('dz-go');
      const norm = s => s.trim().toLowerCase().replace(/ё/g, 'е');
      inp.oninput = () => { go.disabled = norm(inp.value) !== norm(name); };
      setTimeout(() => inp.focus(), 50);
    }
    $('dz-no').onclick = () => this.closeModal();
    $('dz-go').onclick = () => {
      if (step < 3) return this.destroyCity(step + 1);
      this.closeModal();
      Game.newGame();
      saveGame();
      Account.cityReplaced();
      this.showModal(`
        <h2>Чистое поле</h2>
        <p>Город уничтожен. Начнём заново — советник подскажет, с чего начать.</p>
        <div class="actions"><button type="button" class="btn" id="dz-ok">Начать</button></div>`);
      $('dz-ok').onclick = () => this.closeModal();
    };
  },

  // Короткое уведомление — только о важном и о прямой реакции на действие игрока
  // Интерфейс спрятан: виден только город и маленький глаз в углу, чтобы всё вернуть
  setUiHidden(on) {
    this.closeMenu();
    document.body.classList.toggle('ui-hidden', on);
    Engine.setCleanView(on);
    if (on) { this.closePanel(); Input.setTool(null); if (this.openCat) this.closeTray(); }
    const tip = $('tooltip');
    if (tip) tip.hidden = true;
  },

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
      case 'city': return T(`${escapeHtml(state.cityName)} — ${cityRank(S.pop || 0)}`, `${nextRank ? `Следующее звание «${nextRank[1]}» — при ${fmt(nextRank[0])} жителях.` : 'Высшее звание!'} Нажмите — классы жителей, работники и налоги.`);
      case 'money': return T('Казна', `Налоги: +${(S.taxes || 0).toFixed(1)} в день<br>Содержание построек: −${(S.upkeep || 0).toFixed(1)} в день<br>Ставка: ${TAX_LEVELS[state.taxLevel].name.toLowerCase()}. Нажмите, чтобы изменить.`);
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
      case 'home': return T('К городу', 'Камера вернётся к центру города. Клавиша Home');
      case 'hideui': return T('Спрятать интерфейс', 'Любоваться городом. Вернуть — кнопкой с глазом в углу или клавишей U');
      case 'rotr': return T('Повернуть камеру', 'Клавиша E');
      case 'menu': return T('Меню', 'Знания, товары, справка, журнал, настройки.');
      case 'map': return T('Карта', 'Мини-карта города. Клавиша M');
      case 'bulldoze': case 'tool-bulldoze': return T('Снести', 'Клавиша X. Возвращается половина стоимости здания. Залежи и лес вечные.');
      case 'tool-road': return T('Мостовая', 'Кисть: тропинка, гравий, мостовая и площадь. Клавиша R');
      case 'tool-copy': return T('Копировать', 'Нажмите на постройку — возьмёте такую же.');
      case 'tool-move': return T('Перенести', 'Нажмите на постройку и поставьте её в другом месте. Бесплатно.');
      case 'rail-research': {
        const r = state.research;
        return T(`Знания: ${fmt(state.scrolls)} свитков`, (r ? `Изучается «${TECH_BY_ID[r.id].name}»: осталось ${r.left} ${plural(r.left, 'день', 'дня', 'дней')}.` : 'За свитки открываются новые постройки. Изучаются по одному, несколько дней.')
          + ` Свитки пишут храмы, школы и форум${S.scrollRate ? ` (+${S.scrollRate.toFixed(1)} в день)` : ''}. Клавиша F.`);
      }
      case 'rail-goods': return T('Товары', 'Сколько всего на складах, откуда берётся и куда уходит. Торговля.');
      case 'rail-legion': return T('Легион', 'Походы по провинциям, прокачка войск, отряд и умения. Клавиша L.');
      case 'rail-wonders': return T('Чудеса света', 'Открываются рейтингом легиона, стоят Славы и материалов и дают городу и армии сильные бонусы.');
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
      if (b.lifted) continue;
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

// Образец покрытия для карточки кисти (SVG 64×64): m — номер покрытия, 0 — ластик, -1 — «улучшить»
function paveSwatch(m) {
  let s = 11 + (m + 2) * 7919;
  const rnd = () => (s = (s * 16807) % 2147483647) / 2147483647;
  const STONES = ['#dbcfb2', '#d2c5a6', '#e0d5b9', '#cdbf9e', '#d6caa9'];
  const dirt = () => {
    let o = '<rect width="64" height="64" fill="#b89a6a"/>';
    for (let i = 0; i < 22; i++) o += `<ellipse cx="${rnd() * 64}" cy="${rnd() * 64}" rx="${3 + rnd() * 7}" ry="${2 + rnd() * 4}" fill="${rnd() < 0.5 ? '#a8885a' : '#c9ab7a'}" opacity="0.55"/>`;
    for (let i = 0; i < 14; i++) o += `<circle cx="${rnd() * 64}" cy="${rnd() * 64}" r="${0.8 + rnd() * 1.2}" fill="#8a7048"/>`;
    return o;
  };
  const stone = () => {
    let o = '<rect width="64" height="64" fill="#8f8268"/>';
    for (let r = 0; r < 6; r++) {
      const y = r * 11 - 2, off = r % 2 ? -6 : 0;
      for (let c = 0; c < 6; c++) {
        const x = c * 13 + off + rnd() * 2, w = 10 + rnd() * 2.5, h = 8.5 + rnd() * 1.5;
        o += `<rect x="${x.toFixed(1)}" y="${(y + rnd()).toFixed(1)}" width="${w.toFixed(1)}" height="${h.toFixed(1)}" rx="3" fill="${STONES[(rnd() * 5) | 0]}"/>`;
      }
    }
    return o;
  };
  let body = '';
  if (m === 1) body = dirt();
  else if (m === 2) {
    body = '<rect width="64" height="64" fill="#d6cfbd"/>';
    for (let i = 0; i < 160; i++) body += `<circle cx="${(rnd() * 64).toFixed(1)}" cy="${(rnd() * 64).toFixed(1)}" r="${(0.7 + rnd() * 1.5).toFixed(1)}" fill="${['#bfb7a3', '#ebe5d6', '#a9a08c', '#f4efe3'][(rnd() * 4) | 0]}"/>`;
  } else if (m === 3) body = stone() + '<rect y="56" width="64" height="8" fill="#ede5d2"/><rect y="56" width="64" height="1.5" fill="#fff8e8"/>';
  else if (m === 4) {
    body = '<rect width="64" height="64" fill="#b9ae98"/>';
    for (let r = 0; r < 5; r++) {
      const off = r % 2 ? -11 : 0;
      for (let c = 0; c < 4; c++) body += `<rect x="${c * 22 + off + 0.8}" y="${r * 14 + 0.8}" width="20.4" height="12.4" fill="${['#ece4d2', '#e4dbc6', '#f0e9d9'][(rnd() * 3) | 0]}"/>`;
    }
  } else if (m === -1) {
    body = `<svg width="32" height="64" viewBox="0 0 32 64">${dirt()}</svg><svg x="32" width="32" height="64" viewBox="32 0 32 64">${stone()}</svg>`
      + '<circle cx="32" cy="32" r="12" fill="#fff" opacity="0.92"/><path d="M26 32h11m-4-5 5 5-5 5" stroke="#b5552e" stroke-width="3" fill="none" stroke-linecap="round" stroke-linejoin="round"/>';
  } else {
    body = '<rect width="64" height="64" fill="#8fae5a"/>';
    for (let i = 0; i < 40; i++) { const x = rnd() * 64, y = rnd() * 64; body += `<path d="M${x.toFixed(1)} ${y.toFixed(1)}l${(rnd() * 2 - 1).toFixed(1)} -4" stroke="${rnd() < 0.5 ? '#6f9440' : '#a8c46e'}" stroke-width="1.2"/>`; }
    body += '<g transform="rotate(-35 32 32)"><rect x="16" y="23" width="32" height="18" rx="3" fill="#e9826a"/><rect x="16" y="23" width="12" height="18" rx="3" fill="#f6efe2"/><rect x="16" y="38" width="32" height="3" fill="#000" opacity="0.15"/></g>';
  }
  return `<svg class="pave-sw" viewBox="0 0 64 64" aria-hidden="true">${body}</svg>`;
}
