'use strict';
/* Советник Марк: ведёт по задачам и объясняет механики одноразовыми подсказками.
   Тревоги — короткие плашки о проблемах города под верхней панелью (вместо всплывающих окон).
   Журнал хранит все события, чтобы ничего не пропустить. */

const TIPS = [
  { id: 'welcome', title: 'Аве! Я Марк, советник города.',
    text: 'Буду подсказывать, что строить и зачем. Карту двигайте правой кнопкой мыши или WASD, колёсико — масштаб, Q и E — поворот. Слева — задания: нажмите на задание, и я сразу выберу нужную постройку.',
    when: () => true },
  { id: 'paving', title: 'Мостовая — кистью',
    text: 'В «Дорогах» — кисть: тропинка, гравий, мостовая и площадь. Красьте с зажатой кнопкой, хоть всю землю; Shift — прямой линией, [ и ] — ширина, Ctrl+Z — отменить мазок. Дом у края мостовой сам встаёт к ней фасадом, а на площадь его можно поставить прямо на камни (повернуть — Z и C). Залежи камня, мрамора и железа и густой лес вечные: карьер и шахту ставьте рядом с ними.',
    act: { tool: 'road' }, when: () => true },
  { id: 'scrolls', title: 'Храм пишет свитки',
    text: 'Свитки — это знания Рима, они видны справа внизу, под казной. На них в разделе «Знания» открываются новые постройки: масло, кирпич, термы, легион и чудеса света.',
    act: { open: 'research' }, when: () => [...state.buildings.values()].some(b => b.type === 'temple' && b.active) },
  { id: 'citizens', title: 'В инсулах живут граждане',
    text: 'Граждане работают в пекарнях, кузницах и термах. На поля они идут, только если не хватает плебеев. Нужны рабочие руки на полях — отметьте у части домов «Не расти дальше» в карточке дома.',
    when: () => housesAtLeast('house', 3) > 0 },
  { id: 'full', title: 'Склады заполнены',
    text: 'Когда товар упирается в потолок склада, его производство встаёт. Постройте склад или торговый пост, чтобы продавать излишки.',
    act: { tool: 'warehouse' }, when: () => GOOD_IDS.some(g => state.goods[g] >= (state.stats.cap || BASE_STORAGE) - 0.5) },
  { id: 'land', title: 'Пора расширяться',
    text: 'Соседние участки продаются: нажмите на табличку «Купить землю». Перед покупкой видно, что там есть — мрамор, железо, лес или озеро.',
    act: { plot: true }, when: () => (state.stats.pop || 0) >= 70 && state.plots.size === 1 },
  { id: 'happy', title: 'Жители грустят',
    text: 'Счастье растёт от удобств рядом с домом, красоты и низких налогов, а теснота его снижает. Счастливые жители платят больше.',
    act: { cat: 'decor' }, when: () => (state.stats.pop || 0) > 40 && (state.stats.happy || 100) < 48 },
  { id: 'patricians', title: 'Открыты участки патрициев',
    text: 'Участок 3×3 растёт в домус, виллу и дворец. Патриции платят очень много налогов, но им нужны простор, красота, вино, театр и форум.',
    act: { tool: 'domus' }, when: () => hasTech('patricians') },
  { id: 'legion', title: 'Можно собирать легион',
    text: 'Постройте Казармы и Стрельбище: они открывают легионеров и лучников. Всё остальное — в окне «Легион» (кнопка справа вверху): «Походы» — карта провинции, «Войска» — прокачка одной кнопкой и отряд. Улучшения идут по настоящим часам, поход ест провизию: зерно, рыбу или хлеб.',
    act: { tool: 'barracks' }, when: () => hasTech('legion') },
  { id: 'wonders', title: 'Открыто чудо света!',
    text: 'Рейтинг легиона растёт с каждой победой. Его хватило на первое чудо света — откройте «Легион» справа вверху, вкладка «Чудеса». Чудо стоит Славы и материалов и даёт сильный бонус городу и армии.',
    act: { open: 'wonders' }, when: () => !!state.army && WONDERS.some(w => Army.wonderState(w) === 'open') },
  { id: 'night', title: 'Наступает ночь',
    text: 'В окнах зажигается свет, а жаровни освещают улицы. Смену дня и ночи можно выключить в настройках (меню справа вверху → «Настройки»).',
    when: () => Atmos.cycle && Atmos.night > 0.7 },
];
const TIP_BY_ID = Object.fromEntries(TIPS.map(t => [t.id, t]));

const Advisor = {
  shown: null,

  init() {
    $('adv-portrait').src = Icons.get('advisor');
    $('adv-action').onclick = () => {
      const t = this.currentTip();
      if (t) this.dismiss();
      if (t && t.act) UI.runAction(t.act);
    };
    $('adv-skip').onclick = () => this.dismiss();
    this.render(true);
  },

  currentTip() {
    const q = state.tipQueue || [];
    // устаревшие подсказки (например, «хватает на исследование», когда уже изучено) молча убираем
    while (q.length && q[0] !== 'welcome') {
      let ok = false;
      try { ok = TIP_BY_ID[q[0]].when(); } catch (e) { ok = false; }
      if (ok) break;
      q.shift();
    }
    return q.length ? TIP_BY_ID[q[0]] : null;
  },

  // Раз в игровой день: какие подсказки пора показать
  daily() {
    state.tipsSeen = state.tipsSeen || [];
    state.tipQueue = state.tipQueue || [];
    for (const t of TIPS) {
      if (t.id === 'welcome' || state.tipsSeen.includes(t.id) || state.tipQueue.includes(t.id)) continue;
      try { if (t.when()) state.tipQueue.push(t.id); } catch (e) { /* подсказка не готова */ }
    }
  },

  dismiss() {
    const id = state.tipQueue.shift();
    if (id) state.tipsSeen.push(id);
    this.render(true);
  },

  // Советник — облачко под заданиями, только когда есть что объяснить
  render(force) {
    const tip = this.currentTip();
    const key = tip ? tip.id : '';
    if (!force && key === this.shown) return;
    this.shown = key;
    $('advisor').hidden = !tip;
    if (!tip) return;
    $('adv-title').textContent = tip.title;
    $('adv-hint').textContent = tip.text;
    $('adv-skip').textContent = tip.act ? 'Позже' : 'Понятно';
    $('adv-action').hidden = !tip.act;
  },
};

/* ---------- Задания: три первых невыполненных, под карточкой города ---------- */

const Tasks = {
  key: '',
  flash: 0,

  render() {
    const box = $('tasks');
    const ids = activeGoals();
    const key = ids.join(',');
    if (key !== this.key) {
      this.key = key;
      box.innerHTML = '';
      const fresh = performance.now() - this.flash < 3000;
      ids.forEach((i, n) => {
        const g = GOALS[i];
        const b = document.createElement('button');
        b.type = 'button';
        b.className = 'task' + (fresh && n === ids.length - 1 ? ' fresh' : '');
        b.dataset.goal = i;
        b.dataset.tipText = `${g.hint || ''}${g.hint ? ' ' : ''}Награда: ${rewardText(g.reward)}.${g.act ? ' Нажмите — покажу, что строить.' : ''}`;
        b.innerHTML = `<span class="task-top"><i class="check"></i><span>${escapeHtml(g.text)}</span></span>
          <span class="task-foot"><span class="bar"><div></div></span><small></small></span>`;
        b.onclick = () => g.act && UI.runAction(g.act);
        box.append(b);
      });
    }
    // полоски хода
    for (const el of box.querySelectorAll('.task')) {
      const g = GOALS[+el.dataset.goal];
      const p = Math.min(g.prog(), g.need);
      el.querySelector('.bar > div').style.width = `${(p / g.need) * 100}%`;
      el.querySelector('small').textContent = `${fmt(p)}/${fmt(g.need)}`;
    }
  },
};

/* ---------- Тревоги: что сейчас не так в городе — значки рядом с карточкой города ---------- */

const Alerts = {
  last: '',

  compute() {
    const S = state.stats, out = [];
    for (const [g, info] of Object.entries(SHORTAGE)) {
      if (S.short && S.short[g]) out.push({ id: 'short-' + g, text: info.label, icon: g === 'food' ? 'wheat' : g, tip: info.tip, act: { tool: info.tool } });
    }
    let noRoad = null, nNoRoad = 0, down = null, nDown = 0, idle = null, nIdle = 0, full = [];
    for (const b of state.buildings.values()) {
      const d = BUILDINGS[b.type];
      if (d.kind === 'road' || d.kind === 'decor') continue;
      if ((d.needsRoad || d.kind === 'house') && b.road === false) { nNoRoad++; noRoad = noRoad || b; }
      else if (d.kind === 'house' && b.down > 2) { nDown++; down = down || b; }
      else if (d.jobs && b.road && b.staff < 0.25) { nIdle++; idle = idle || b; }
    }
    if (nNoRoad) out.push({ id: 'noroad', n: nNoRoad, text: `Без дороги: ${nNoRoad}`, icon: 'img:road', tip: 'Дома и мастерские работают, только если стоят вплотную к мостовой или прямо на ней. Нажмите, чтобы показать такое здание.', focus: noRoad });
    if (nDown) out.push({ id: 'down', n: nDown, text: `Дома в упадке: ${nDown}`, icon: 'happy', tip: 'Этим домам чего-то не хватает, и они могут опуститься на уровень ниже. Нажмите, чтобы показать дом — в его карточке видна причина.', focus: down });
    if (nIdle) out.push({ id: 'idle', n: nIdle, text: `Без работников: ${nIdle}`, icon: 'workers', tip: 'Не хватает жителей нужного класса. Постройте больше домов — кто где работает, видно в карточке города.', focus: idle });
    const cap = S.cap || BASE_STORAGE;
    for (const g of GOOD_IDS) if ((S.prod || {})[g] && state.goods[g] >= cap - 0.5) full.push(GOODS[g].name.toLowerCase());
    if (full.length) out.push({ id: 'full', text: 'Склады полны', icon: 'store', tip: `Некуда класть: ${full.join(', ')}. Постройте склад или продайте излишки через торговый пост.`, act: { tool: 'warehouse' } });
    if (state.money < 0) out.push({ id: 'debt', text: 'Казна в минусе', icon: 'money', tip: 'Содержание построек дороже налогов. Поднимите налоги в карточке города, растите дома или снесите лишнее.', act: { city: true } });
    return out;
  },

  render() {
    const list = this.compute();
    const key = list.map(a => a.id + a.text).join('|');
    if (key === this.last) return;
    this.last = key;
    const box = $('alerts');
    box.innerHTML = '';
    for (const a of list) {
      const b = document.createElement('button');
      b.type = 'button';
      b.className = 'alert';
      b.setAttribute('aria-label', a.text);
      const ico = a.icon.startsWith('img:') ? `<img class="ico" src="${UI.icons[a.icon.slice(4)] || ''}" alt="">` : Icons.img(a.icon);
      b.innerHTML = `${ico}${a.n ? `<i class="badge">${a.n > 99 ? '99+' : a.n}</i>` : ''}`;
      b.dataset.tipText = `${a.text}. ${a.tip}`;
      b.onclick = () => {
        if (a.focus) { Engine.lookAt(a.focus.x + a.focus.w / 2, a.focus.y + a.focus.h / 2); UI.openPanel(a.focus); }
        else if (a.act) UI.runAction(a.act);
      };
      box.append(b);
    }
  },
};

/* ---------- Журнал событий ---------- */

const Journal = {
  add(text, kind, ref) {
    state.journal = state.journal || [];
    state.journal.unshift({ day: state.day, text, kind: kind || 'info', ref: ref ? { x: ref.x, y: ref.y, id: ref.id } : null });
    if (state.journal.length > 80) state.journal.length = 80;
    state.journalUnread = (state.journalUnread || 0) + 1;
  },
};
