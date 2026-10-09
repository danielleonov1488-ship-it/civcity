'use strict';
/* Окно «Легион» (Легион 2.0): вкладки «Походы» (карта одной провинции на экран), «Войска»
   (прокачка родов войск одной кнопкой, отряд, умения) и «Против городов» (заработает с сервером).
   Ещё здесь окно перед боем, карточка военного здания и окно «Чудеса». Меню крупные — под палец тоже. */

const PERK_SVG = {
  oil: '<path d="M4.5 10h15l-1.6 7.2a3 3 0 0 1-2.9 2.3H9a3 3 0 0 1-2.9-2.3z"/><path d="M3 10h18"/><path d="M9 3.5c1.2 1.2-1 2.3 0 3.6M13 3c1.2 1.2-1 2.3 0 3.6M17 3.8c1 1-.8 2 0 3"/>',
  testudo: '<path d="M12 3l7.5 3v5.2c0 4.6-3.1 8.2-7.5 9.8-4.4-1.6-7.5-5.2-7.5-9.8V6z"/><path d="M12 3v18M4.5 11h15"/>',
  bandage: '<path d="M9.5 4h5v5.5H20v5h-5.5V20h-5v-5.5H4v-5h5.5z"/>',
  volley: '<path d="M4 20L14 10M8 20l10-10M12 20l8-8"/><path d="M14 10h-4M14 10v4M18 10h-4M18 10v4M20 12h-3M20 12v3"/>',
  horn: '<path d="M4 15c4 0 9-3 12-8l3 1.5c-2 6-7 10-14 10.5z"/><path d="M4 15l1 3.8M16 7l1.5-3"/>',
};

// Краски провинций для карты: земля сверху и снизу, тропа, подписи
const BIOME_ART = {
  forest: { top: '#cfe0a6', bot: '#9fc277', path: '#e8d6a4', ink: '#4f6a2e' },
  hills: { top: '#efe2a8', bot: '#c9b874', path: '#f3e6bd', ink: '#6e5a26' },
  darkforest: { top: '#a9c48e', bot: '#6f9358', path: '#d9c896', ink: '#2f4a26' },
  swamp: { top: '#c3cfa4', bot: '#8a9c72', path: '#d6cba0', ink: '#3f4f30' },
  labyrinth: { top: '#efe2c2', bot: '#cdb88c', path: '#f7eed8', ink: '#6a5634' },
  rocks: { top: '#e2dcc8', bot: '#a9a08a', path: '#efe6cf', ink: '#55503f' },
  desert: { top: '#f6e6b4', bot: '#e3c47e', path: '#fbf2d6', ink: '#7a5a24' },
  hades: { top: '#6a4a44', bot: '#3a2626', path: '#a8826e', ink: '#f2d2b8' },
};

const ArmyUI = {
  tab: 'camp',
  view: null,          // какая провинция открыта на карте: { cycle, r }

  perkIcon(id) {
    return `<svg class="ui-ico perk-ico" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">${PERK_SVG[id] || ''}</svg>`;
  },

  unitImg(key, cls) { return `<img class="${cls || 'u-img'}" src="${Battle.portrait(key)}" alt="">`; },

  /* ---------- Окно «Легион» ---------- */

  render(el) {
    Army.ensure();
    const A = state.army;
    if (!Army.unlocked()) {
      el.innerHTML = `<div class="explain">${Icons.img('legion', 'big')}<div><b>Легион ещё не собран.</b>
        <p>Изучите «Легион» в окне «Знания» — он открывается, когда в городе ${fmt(TECH_BY_ID.legion.pop)} жителей. Потом постройте Казармы: в отряде появятся легионеры, а здесь — карта походов против варваров и чудовищ.</p></div></div>`;
      return;
    }
    Battle.renderPortraits([...UNIT_IDS]);
    const tabs = [['camp', 'Походы'], ['troops', 'Войска'], ['pvp', 'Против городов']];
    const upgrading = Object.keys(A.upg).length;
    el.innerHTML = `
      <div class="lg-strip">
        <span class="lg-stat" data-tip="glory">${Icons.img('glory')}<b>${fmt(state.glory)}</b><small>Слава</small></span>
        <span class="lg-stat">${Icons.svg('laurel')}<b>${fmt(A.rating)}</b><small>Рейтинг</small></span>
        <span class="lg-stat ${Army.food() < Army.foodCost() ? 'short' : ''}">${Icons.img('wheat')}<b>${fmt(Army.food())}</b><small>Провизия · на поход ${Army.foodCost()}</small></span>
        <span class="lg-stat">${Icons.svg('people')}<b>${fmt(Army.squadPower())}</b><small>Сила отряда</small></span>
        <div class="seg lg-tabs">${tabs.map(([id, n]) => `<button type="button" data-lgtab="${id}" class="${this.tab === id ? 'on' : ''}">${n}${id === 'troops' && upgrading ? ` <i class="lg-dot">${upgrading}</i>` : ''}</button>`).join('')}</div>
      </div>
      <div class="lg-body" id="lg-body"></div>`;
    el.querySelectorAll('[data-lgtab]').forEach(b => b.onclick = () => { this.tab = b.dataset.lgtab; this.render(el); });
    const body = $('lg-body');
    if (this.tab === 'troops') this.renderTroops(body);
    else if (this.tab === 'pvp') this.renderPvp(body);
    else this.renderCamp(body);
  },

  /* ---------- Походы: одна провинция на экран ---------- */

  renderCamp(el) {
    const A = state.army, F = Army.frontier();
    const turn = A.turnPage;
    if (!this.view || turn) this.view = { cycle: F.cycle, r: F.r };
    A.turnPage = false;
    const { cycle, r } = this.view, R = REGIONS[r];
    const prev = r > 0 || cycle > 0 ? (r > 0 ? { cycle, r: r - 1 } : { cycle: cycle - 1, r: REGIONS.length - 1 }) : null;
    const nxt = r < REGIONS.length - 1 ? { cycle, r: r + 1 } : { cycle: cycle + 1, r: 0 };
    const nextOpen = Army.isOpen(nxt.cycle, nxt.r, 0);
    const done = Army.stageIndex(cycle, r, STAGES_PER_REGION - 1) < A.progress;
    const bossKey = R.boss;
    Battle.renderPortraits([bossKey]);
    el.innerHTML = `
      <div class="prov-head">
        <button type="button" class="icon-btn prov-arrow" id="prov-prev" ${prev ? '' : 'disabled'} aria-label="Предыдущая провинция">‹</button>
        <div class="prov-title">
          <small>${cycle ? `Поход ${roman(cycle + 1)} · ` : ''}Провинция ${r + 1} из ${REGIONS.length}</small>
          <h3>${R.name}${done ? ' <span class="prov-done">✓ пройдена</span>' : ''}</h3>
          <p>${R.desc}</p>
        </div>
        <div class="prov-boss">${this.unitImg(bossKey, 'pb-img')}<span><small>Босс провинции</small><b>${ENEMIES[bossKey].name}</b></span></div>
        <button type="button" class="icon-btn prov-arrow" id="prov-next" ${nextOpen ? '' : 'disabled'} aria-label="Следующая провинция">›</button>
      </div>
      <div class="prov-map-wrap ${turn ? 'turn-in' : ''}">
        ${this.provinceSvg(cycle, r)}
        ${turn ? `<div class="prov-banner"><small>Новая провинция открыта</small><b>${R.name}</b></div>` : ''}
      </div>
      <div class="prov-foot">
        <p class="sub">Звёзды — сколько бойцов уцелело. Пройденные бои можно повторять ради добычи. За босса — умения, места в отряде и новые рода войск.</p>
        <button type="button" class="btn small ghost" id="fest-btn" ${state.glory < FESTIVAL.glory || state.day < state.festivalUntil ? 'disabled' : ''}>${Icons.img('glory')} Триумф: ${FESTIVAL.glory} Славы → +${FESTIVAL.happy} к счастью на ${FESTIVAL.days} дней</button>
      </div>`;
    $('prov-prev').onclick = () => { if (prev) { this.view = prev; this.renderCamp(el); } };
    $('prov-next').onclick = () => { if (nextOpen) { this.view = nxt; this.renderCamp(el); } };
    $('fest-btn').onclick = () => { if (Army.festival()) UI.renderWindow(); };
    el.querySelectorAll('[data-node]').forEach(n => n.addEventListener('click', () => this.openStage(cycle, r, +n.dataset.node)));
    el.querySelectorAll('[data-node]').forEach(n => n.addEventListener('keydown', e => { if (e.key === 'Enter' || e.key === ' ') this.openStage(cycle, r, +n.dataset.node); }));
  },

  // Точки боёв вдоль извилистой тропы от лагеря (слева внизу) к логову босса (справа вверху)
  layout() {
    if (this._layout) return this._layout;
    const curve = t => [110 + t * 760, 410 - t * 250 + Math.sin(t * Math.PI * 2.4 + 0.3) * 78];
    const dense = [];
    let len = 0, prev = curve(0);
    for (let i = 0; i <= 1000; i++) {
      const p = curve(i / 1000);
      len += Math.hypot(p[0] - prev[0], p[1] - prev[1]);
      dense.push([p[0], p[1], len]);
      prev = p;
    }
    const pts = [];
    let j = 0;
    for (let k = 0; k < STAGES_PER_REGION; k++) {
      const want = len * (0.04 + 0.96 * k / (STAGES_PER_REGION - 1));
      while (j < dense.length - 1 && dense[j][2] < want) j++;
      pts.push([Math.round(dense[j][0]), Math.round(dense[j][1])]);
    }
    return (this._layout = { pts, dense: dense.filter((_, i) => i % 10 === 0).map(p => [p[0], p[1]]) });
  },

  provinceSvg(cycle, r) {
    const A = state.army, R = REGIONS[r], art = BIOME_ART[R.biome];
    const W = 1000, H = 500, { pts, dense } = this.layout();
    const path = 'M' + dense.map(p => p.join(',')).join(' L');
    let svg = `<svg class="prov-map" viewBox="0 0 ${W} ${H}" preserveAspectRatio="xMidYMid meet" role="img" aria-label="Карта: ${R.name}">
      <defs>
        <linearGradient id="pg-${r}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${art.top}"/><stop offset="1" stop-color="${art.bot}"/></linearGradient>
        <radialGradient id="pv" cx="50%" cy="50%" r="72%"><stop offset="62%" stop-color="#000" stop-opacity="0"/><stop offset="100%" stop-color="#3a2410" stop-opacity="0.3"/></radialGradient>
        <filter id="ppaper"><feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves="2"/><feColorMatrix values="0 0 0 0 0.5 0 0 0 0 0.38 0 0 0 0 0.2 0 0 0 0.08 0"/></filter>
      </defs>
      <rect width="${W}" height="${H}" fill="url(#pg-${r})"/>
      ${this.scenery(R.biome, r)}
      <path d="${path}" class="prov-road-edge"/>
      <path d="${path}" class="prov-road" style="stroke:${art.path}"/>`;
    // пройденная часть тропы — золотая
    const doneUpTo = A.progress - Army.stageIndex(cycle, r, 0);
    if (doneUpTo > 0) {
      const k = Math.min(STAGES_PER_REGION - 1, doneUpTo);
      const last = pts[k], cut = dense.findIndex(p => Math.hypot(p[0] - last[0], p[1] - last[1]) < 14);
      svg += `<path d="M${dense.slice(0, (cut > 0 ? cut : dense.length - 1) + 1).map(p => p.join(',')).join(' L')}" class="prov-road done"/>`;
    }
    // лагерь легиона в начале тропы и логово босса в конце
    svg += this.campArt(70, 448) + this.lairArt(R.biome, pts[STAGES_PER_REGION - 1]);
    for (let s = 0; s < STAGES_PER_REGION; s++) {
      const [x, y] = pts[s], idx = Army.stageIndex(cycle, r, s), key = Army.stageKey(cycle, r, s);
      const boss = s === STAGES_PER_REGION - 1, stars = A.stars[key] || 0;
      const cls = idx < A.progress ? 'done' : idx === A.progress ? 'current' : 'locked';
      const rad = boss ? 27 : 18;
      svg += `<g class="node ${cls} ${boss ? 'boss' : ''}" ${cls !== 'locked' ? `data-node="${s}" tabindex="0" role="button"` : ''} transform="translate(${x},${y})">
        <title>${boss ? ENEMIES[R.boss].name : `Бой ${s + 1}`}</title>
        <circle r="${rad + 7}" class="halo"/>
        <circle r="${rad}" class="disc"/>
        ${boss ? '<path d="M-12 6 L-15 -9 L-6 -3 L0 -14 L6 -3 L15 -9 L12 6 Z" class="crown"/>' : `<text y="6" class="num">${s + 1}</text>`}
        ${stars ? `<text y="${rad + 18}" class="stars">${'★'.repeat(stars)}${'☆'.repeat(3 - stars)}</text>` : ''}
      </g>`;
    }
    svg += `<rect width="${W}" height="${H}" fill="url(#pv)" pointer-events="none"/><rect width="${W}" height="${H}" filter="url(#ppaper)" opacity="0.8" pointer-events="none"/></svg>`;
    return svg;
  },

  campArt(x, y) {
    return `<g class="prov-camp" transform="translate(${x},${y})">
      <path d="M-26 6 L-10 -20 L6 6 Z" fill="#efe3c6" stroke="#9a7a52" stroke-width="2"/><path d="M-10 -20 V6" stroke="#9a7a52" stroke-width="1.5"/>
      <path d="M2 6 L16 -14 L30 6 Z" fill="#e6d7b4" stroke="#9a7a52" stroke-width="2"/>
      <path d="M-34 6 V-34" stroke="#6e4a2f" stroke-width="2.5"/><path d="M-34 -34 h18 v12 h-18 z" fill="#b5452e"/><circle cx="-25" cy="-28" r="3" fill="#e3b445"/>
      <text x="0" y="26" class="prov-label">Лагерь</text></g>`;
  },

  // Логово босса за последней точкой: крепость, пещера, лабиринт, вулкан
  lairArt(biome, [x, y]) {
    const fort = `<path d="M-30 18 V-14 h10 v-8 h8 v8 h8 v-8 h8 v8 h8 v-8 h8 v8 h10 V18 Z" fill="#a98f6a" stroke="#6e5638" stroke-width="2"/><path d="M-6 18 v-14 a6 6 0 0 1 12 0 v14" fill="#4a3826"/>`;
    const cave = `<path d="M-40 20 Q-34 -26 0 -30 Q34 -26 40 20 Z" fill="#8a8170" stroke="#5e5646" stroke-width="2"/><path d="M-14 20 Q-12 -6 0 -8 Q12 -6 14 20 Z" fill="#2e2620"/>`;
    const art = { hills: cave, rocks: cave, labyrinth: `<path d="M-34 18 V-18 H34 V18 M-22 18 V-6 H22 V18 M-10 18 V6 H10" fill="none" stroke="#8a7452" stroke-width="5"/>`,
      hades: `<path d="M-40 20 L-12 -32 L12 -32 L40 20 Z" fill="#3a2422" stroke="#1e1212" stroke-width="2"/><path d="M-10 -32 q10 -18 20 0" fill="#ff7a3a"/><path d="M-4 -40 q4 -10 8 0" fill="#ffd27a"/>` }[biome] || fort;
    return `<g class="prov-lair" transform="translate(${x + 52},${y - 6})">${art}</g>`;
  },

  // Местность провинции: деревья, холмы, болотца, стены, дюны, лава — по краям от тропы
  scenery(b, seed) {
    const rnd = mulberry32(seed * 131 + 7);
    const { dense } = this.layout();
    const far = (x, y) => dense.every(p => Math.hypot(p[0] - x, p[1] - y) > 48);
    let g = '';
    const put = (n, fn) => {
      for (let i = 0, tries = 0; i < n && tries < n * 12; tries++) {
        const x = 20 + rnd() * 960, y = 40 + rnd() * 440;
        if (!far(x, y) || (x < 140 && y > 380)) continue;
        g += fn(x, y, 0.75 + rnd() * 0.6, rnd());
        i++;
      }
    };
    const tree = c => (x, y, k) => `<g transform="translate(${x},${y}) scale(${k})"><path d="M0 -26 l13 18 h-6 l9 13 h-32 l9 -13 h-6 z" fill="${c}"/><rect x="-2.5" y="5" width="5" height="7" fill="#6e4a2f"/></g>`;
    if (b === 'forest') { put(26, tree('#5f8f45')); put(8, tree('#7aa85a')); }
    else if (b === 'darkforest') { put(34, tree('#3f6a3a')); put(10, tree('#2f5a30')); }
    else if (b === 'hills') {
      put(10, (x, y, k) => `<path d="M${x - 46 * k} ${y + 14} Q${x} ${y - 40 * k} ${x + 46 * k} ${y + 14} Z" fill="#c2ad6a" opacity="0.8"/>`);
      put(10, tree('#7a9a4a'));
    } else if (b === 'swamp') {
      put(10, (x, y, k) => `<ellipse cx="${x}" cy="${y}" rx="${30 * k}" ry="${11 * k}" fill="#6f8f8a" opacity="0.85"/><path d="M${x - 8} ${y} v-16 M${x} ${y - 2} v-20 M${x + 8} ${y} v-14" stroke="#4f6a2e" stroke-width="2.5"/>`);
      put(12, tree('#5a7448'));
    } else if (b === 'labyrinth') {
      put(14, (x, y, k) => `<path d="M${x - 24 * k} ${y - 16 * k} h${48 * k} v${32 * k} h-${36 * k} v-${20 * k} h${24 * k} v${10 * k}" fill="none" stroke="#a8916a" stroke-width="5"/>`);
    } else if (b === 'rocks') {
      g += `<path d="M640 0 C 700 60, 760 40, 1000 90 V 0 Z" fill="#8fc2cf"/><path d="M640 0 C 700 60, 760 40, 1000 90" fill="none" stroke="#f4f0e2" stroke-width="3" stroke-dasharray="8 8"/>`;
      put(14, (x, y, k) => `<path d="M${x - 26 * k} ${y + 12} L${x - 6} ${y - 30 * k} L${x + 22 * k} ${y + 12} Z" fill="#9a958c"/><path d="M${x - 12} ${y - 18 * k} L${x - 6} ${y - 30 * k} L${x} ${y - 18 * k} Z" fill="#f2ead8"/>`);
    } else if (b === 'desert') {
      put(10, (x, y, k) => `<path d="M${x - 50 * k} ${y + 10} Q${x - 10} ${y - 22 * k} ${x + 50 * k} ${y + 10} Z" fill="#e8cf8c"/>`);
      put(10, (x, y, k) => `<g transform="translate(${x},${y}) scale(${k})"><path d="M0 16 q-3 -16 3 -28" stroke="#8a6a46" stroke-width="3.5" fill="none"/><path d="M3 -12 q-14 -3 -20 6 M3 -12 q14 -4 18 6 M3 -12 q3 -12 -8 -15" stroke="#5f8f3a" stroke-width="4.5" fill="none" stroke-linecap="round"/></g>`);
    } else if (b === 'hades') {
      put(8, (x, y, k) => `<path d="M${x - 40 * k} ${y + 12} Q${x} ${y - 6} ${x + 40 * k} ${y + 12}" stroke="#ff7a3a" stroke-width="3" fill="none" opacity="0.8"/>`);
      put(12, (x, y, k) => `<path d="M${x - 20 * k} ${y + 12} L${x - 5} ${y - 26 * k} L${x + 5} ${y - 26 * k} L${x + 20 * k} ${y + 12} Z" fill="#2c1c1a"/>`);
    }
    return g;
  },

  /* ---------- Войска: прокачка, отряд, умения ---------- */

  renderTroops(el) {
    const A = state.army;
    el.innerHTML = `
      <div class="ucards">${UNIT_IDS.map(k => this.unitCard(k)).join('')}</div>
      <div class="lg-cols">
        <section class="lg-box">
          <div class="lg-box-head"><h3>Отряд</h3><small>${Army.squadStats().length} из ${Army.slots()} мест${Army.nextSlotBoss() ? ` · ещё место — после победы: ${Army.bossName(Army.nextSlotBoss())}` : ''}</small></div>
          <div class="squad" id="squad">${this.squadHtml()}</div>
        </section>
        <section class="lg-box">
          <div class="lg-box-head"><h3>Умения в бою</h3><small>Открываются победами над боссами, усиливаются за Славу</small></div>
          <div class="perk-list">${PERK_IDS.map(id => this.perkCard(id)).join('')}</div>
        </section>
      </div>`;
    el.querySelectorAll('[data-up]').forEach(b => b.onclick = () => { if (Army.startUpgrade(b.dataset.up)) UI.renderWindow(); });
    el.querySelectorAll('[data-finish]').forEach(b => b.onclick = () => Army.finishUpgrade(b.dataset.finish));
    el.querySelectorAll('[data-build]').forEach(b => b.onclick = () => UI.runAction({ tool: b.dataset.build }));
    el.querySelectorAll('[data-slot]').forEach(b => b.onclick = () => this.pickUnit(+b.dataset.slot));
    el.querySelectorAll('[data-perk-up]').forEach(b => b.onclick = () => { if (Army.upgradePerk(b.dataset.perkUp)) UI.renderWindow(); });
  },

  unitCard(key) {
    const U = UNITS[key], A = state.army, d = BUILDINGS[U.building];
    const s = Army.stats(key), lvl = A.levels[key];
    let foot, cls = '';
    if (!isUnlocked(U.building)) {
      cls = 'locked';
      foot = d.boss ? `<p class="uc-why">${Icons.svg('legion')}Откроется после победы над боссом: <b>${Army.bossName(d.boss)}</b></p>`
        : `<p class="uc-why">Нужно знание «${lockName(U.building)}»</p>`;
    } else if (!countType(U.building)) {
      cls = 'nobuilding';
      foot = `<p class="uc-why">Постройте в городе: <b>${d.name}</b></p><button type="button" class="btn small" data-build="${U.building}">Построить</button>`;
    } else {
      const u = A.upg[key], i = Army.upgradeInfo(key);
      if (u) {
        const left = (u.end - Date.now()) / 1000, k = 1 - left / Math.max(1, u.total);
        foot = `<div class="upg-run" data-run="${key}"><div class="bar"><div style="width:${clamp(k, 0, 1) * 100}%"></div></div>
          <small>Улучшается до ${u.to} ур. · осталось <b>${fmtDuration(left)}</b></small>
          ${TEST_MODE ? `<button type="button" class="btn tiny ghost" data-finish="${key}">Завершить (тест)</button>` : ''}</div>`;
      } else if (i.max) foot = '<p class="uc-max">Максимальный уровень</p>';
      else if (i.blocked) {
        const pop = Army.nextCapPop();
        foot = `<p class="uc-why">Предел города — ${i.limit} уровень.${pop ? ` Дальше — когда в городе будет ${fmt(pop)} жителей.` : ''}</p>`;
      } else {
        const can = Army.canUpgrade(key);
        foot = `<div class="uc-cost card-cost">${UI.costHtml(i.cost)}</div>
          <button type="button" class="btn uc-up" data-up="${key}" ${can ? '' : 'disabled'}>Улучшить до ${i.to} ур. <small>${fmtDuration(i.time)}</small></button>`;
      }
    }
    return `<div class="ucard ${cls}">
      <div class="uc-top">${this.unitImg(key, 'uc-por')}<div class="uc-name"><b>${U.name}</b><span class="uc-lvl">${lvl}<small>ур.</small></span><p>${U.role}</p></div></div>
      <div class="uc-stats"><span><small>Здоровье</small><b>${fmt(s.hp)}</b></span><span><small>Урон</small><b>${fmt(s.atk)}</b></span><span><small>Броня</small><b>${s.armor}</b></span><span><small>Сила</small><b>${Army.power(s)}</b></span></div>
      <p class="uc-strong">Сильнее против: ${U.strong}</p>
      <div class="uc-foot">${foot}</div>
    </div>`;
  },

  squadHtml() {
    const A = state.army, slots = Army.slots();
    let html = '';
    const total = SQUAD_BASE + SLOT_BOSSES.length;
    for (let i = 0; i < total; i++) {
      const t = A.squad[i];
      if (i >= slots) { html += `<div class="slot locked">${Icons.svg('pick')}<small>после победы: ${Army.bossName(SLOT_BOSSES[i - SQUAD_BASE])}</small></div>`; continue; }
      if (t && Army.available(t)) {
        const s = Army.stats(t);
        html += `<button type="button" class="slot" data-slot="${i}">${this.unitImg(t)}<b>${UNITS[t].name}</b><small>${s.level} ур. · сила ${Army.power(s)}</small></button>`;
      } else html += `<button type="button" class="slot empty" data-slot="${i}"><span class="plus">+</span><small>Свободно</small></button>`;
    }
    return html;
  },

  perkCard(id) {
    const lvl = state.army.perks[id], P = PERKS[id];
    if (!lvl) return `<div class="perk locked" title="${P.desc}"><span class="ring">${this.perkIcon(id)}</span><b>${P.name}</b><small>после победы: ${Army.bossName(P.boss)}</small></div>`;
    const cost = Army.perkCost(id);
    return `<div class="perk" title="${P.desc}"><span class="ring">${this.perkIcon(id)}</span><b>${P.name}</b><small>${'★'.repeat(lvl)}${'☆'.repeat(PERK_MAX - lvl)} · раз в ${P.cd} с</small>
      ${lvl < PERK_MAX ? `<button type="button" class="btn tiny" data-perk-up="${id}" ${state.glory < cost ? 'disabled' : ''}>Усилить: ${cost} ${Icons.img('glory')}</button>` : '<small class="maxed">Максимум</small>'}</div>`;
  },

  // Выбор бойца в место отряда
  pickUnit(i) {
    const A = state.army;
    const opts = UNIT_IDS.map(k => {
      const ok = Army.available(k), s = Army.stats(k);
      const why = ok ? `${s.level} ур. · сила ${Army.power(s)} · сильнее против: ${UNITS[k].strong}` : this.lockText(k);
      return `<button type="button" class="pick-unit ${ok ? '' : 'locked'}" data-pick="${k}" ${ok ? '' : 'disabled'}>${this.unitImg(k)}<span><b>${UNITS[k].name}</b><small>${why}</small></span></button>`;
    }).join('');
    UI.showModal(`<p class="eyebrow">Отряд · место ${i + 1}</p><h2>Кого поставить?</h2><div class="pick-list">${opts}</div>
      <div class="actions">${A.squad[i] ? '<button type="button" class="btn ghost" id="pick-clear">Убрать из отряда</button>' : ''}<button type="button" class="btn ghost" id="pick-cancel">Отмена</button></div>`);
    document.querySelectorAll('[data-pick]').forEach(b => b.onclick = () => { A.squad[i] = b.dataset.pick; UI.closeModal(); UI.renderWindow(); });
    $('pick-cancel').onclick = () => UI.closeModal();
    const cl = $('pick-clear');
    if (cl) cl.onclick = () => { A.squad[i] = null; UI.closeModal(); UI.renderWindow(); };
  },

  lockText(k) {
    const b = UNITS[k].building, d = BUILDINGS[b];
    if (!isUnlocked(b)) return d.boss ? `После победы: ${Army.bossName(d.boss)}` : `Нужно знание «${lockName(b)}»`;
    return `Постройте: ${d.name}`;
  },

  /* ---------- Против городов (заработает вместе с сервером) ---------- */

  renderPvp(el) {
    const A = state.army;
    el.innerHTML = `
      <div class="pvp-box">
        <div class="pvp-rating">${Icons.svg('laurel')}<b>${fmt(A.rating)}</b><small>рейтинг легиона</small></div>
        <div class="pvp-text">
          <h3>Бои с другими городами — скоро</h3>
          <p>Когда заработает сервер, ваш отряд сможет нападать на отряды других игроков. Бой идёт сам, как в походах, а вы жмёте умения. Победы над городами дают много рейтинга и немного добычи.</p>
          <p>Рейтинг не тратится — это ваше достижение. Сейчас он растёт с каждой победой в походах: ${RATING.first} за новый бой, ${RATING.boss} за босса, ${RATING.repeat} за повтор. За рейтинг открываются чудеса света.</p>
          <button type="button" class="btn ghost" id="pvp-wonders">${Icons.svg('wonders')} Открыть «Чудеса»</button>
          <button type="button" class="btn" disabled>${Icons.svg('swords')} Найти соперника</button>
        </div>
      </div>`;
    $('pvp-wonders').onclick = () => UI.openWindow('wonders');
  },

  /* ---------- Окно перед боем ---------- */

  openStage(cycle, r, s) {
    Army.ensure();
    if (!Army.isOpen(cycle, r, s)) return;
    const st = Army.stage(cycle, r, s);
    const mine = Army.squadPower(), theirs = Army.stagePower(st);
    const ratio = mine / Math.max(1, theirs);
    const odds = ratio >= 1.25 ? ['good', 'Шансы хорошие'] : ratio >= 0.85 ? ['mid', 'Будет тяжело'] : ['bad', 'Враг сильнее'];
    const first = Army.stageIndex(cycle, r, s) === state.army.progress;
    const reward = Army.rewardFor(st, first);
    const keys = [...new Set(st.waves.flat())];
    Battle.renderPortraits([...keys, ...UNIT_IDS]);
    const waves = st.waves.map((w, i) => {
      const counts = {};
      for (const k of w) counts[k] = (counts[k] || 0) + 1;
      return `<div class="wave"><small>Волна ${i + 1}</small><div class="foes">${Object.entries(counts).map(([k, n]) => {
        const e = Army.enemyStats(k, st.scale);
        return `<span class="foe ${e.boss ? 'boss' : ''}" title="${e.name}: здоровье ${fmt(e.hp)}, урон ${fmt(e.atk)}, броня ${Math.round(e.armor)}">${this.unitImg(k, 'f-img')}<b>${e.name}</b>${n > 1 ? `<i>×${n}</i>` : ''}</span>`;
      }).join('')}</div></div>`;
    }).join('');
    const squad = Army.squadStats();
    const err = Army.canFight();
    const tips = this.counterTips(st);
    const unlocks = st.boss && first ? Army.unlocksAt(Army.bosses() + 1) : [];
    UI.showModal(`
      <div class="stage-modal">
        <p class="eyebrow">${st.title} · ${st.boss ? 'Босс' : `бой ${s + 1} из ${STAGES_PER_REGION}`}</p>
        <h2>${st.boss ? st.name : REGIONS[r].name}</h2>
        <p class="sub">${REGIONS[r].desc}</p>
        ${waves}
        ${tips ? `<p class="note">${tips}</p>` : ''}
        <div class="vs">
          <div class="side"><small>Ваш отряд</small><div class="mini-squad">${squad.map(u => this.unitImg(u.key, 'm-img')).join('') || '—'}</div><b>Сила ${fmt(mine)}</b></div>
          <div class="odds ${odds[0]}">${odds[1]}</div>
          <div class="side"><small>Враг</small><b>Сила ${fmt(theirs)}</b></div>
        </div>
        <div class="rows">
          <div class="row"><span>${Icons.img('money')} Добыча${first ? ' (первая победа ×2,5)' : ''}</span><b class="loot-line">${Object.entries(reward).map(([k, n]) => `${Icons.img(k)} ${fmt(n)}`).join(' ')}</b></div>
          <div class="row"><span>${Icons.svg('laurel')} Рейтинг за победу</span><b>+${first ? (st.boss ? RATING.boss : RATING.first) : RATING.repeat}</b></div>
          ${unlocks.length ? `<div class="row"><span>${Icons.svg('legion')} Откроется</span><b>${unlocks.join(', ')}</b></div>` : ''}
          <div class="row"><span>${Icons.img('wheat')} Провизия на поход</span><b class="${Army.food() < Army.foodCost() ? 'short' : ''}">${Army.foodCost()} из ${fmt(Army.food())}</b></div>
          ${state.army.stars[st.key] ? `<div class="row"><span>Лучший результат</span><b class="stars">${'★'.repeat(state.army.stars[st.key])}</b></div>` : ''}
        </div>
        ${err ? `<p class="note bad">${err}</p>` : ''}
        <div class="actions">
          <button type="button" class="btn" id="go-battle" ${err ? 'disabled' : ''}>В бой!</button>
          <button type="button" class="btn ghost" id="go-squad">Отряд и прокачка</button>
          <button type="button" class="btn ghost" id="go-cancel">Отмена</button>
        </div>
      </div>`, 'wide');
    $('go-battle').onclick = () => Battle.start(st);
    $('go-squad').onclick = () => { UI.closeModal(); this.tab = 'troops'; UI.openWindow('legion'); };
    $('go-cancel').onclick = () => UI.closeModal();
  },

  // Подсказка по составу: кого брать против этих врагов
  counterTips(st) {
    const tags = new Set();
    for (const w of st.waves) for (const k of w) for (const t of ENEMIES[k].tags) tags.add(t);
    const advice = [];
    if (tags.has('beast') || tags.has('giant')) advice.push('копейщики сильнее против зверей и великанов');
    if (tags.has('ranged') || tags.has('swift')) advice.push('лучники быстро снимают стрелков и волков');
    if (tags.has('armored') || tags.has('giant')) advice.push('баллиста пробивает броню');
    if (tags.has('swarm') || st.waves.some(w => w.length >= 4)) advice.push('катапульта и «Кипящее масло» хороши против толпы');
    return advice.length ? 'Совет: ' + advice.slice(0, 2).join('; ') + '.' : '';
  },

  /* ---------- Военное здание: только открывает род войск ---------- */

  buildingPanel(b) {
    Army.ensure();
    const key = UNIT_BY_BUILDING[b.type];
    if (!key) return '';
    const U = UNITS[key], lvl = state.army.levels[key];
    Battle.renderPortraits([key]);
    return `<div class="unit-card">${this.unitImg(key, 'uc-img')}<div><small class="eyebrow">Открывает</small><b>${U.many}</b><p>${U.role}</p><p class="strong">Сильнее против: ${U.strong} · сейчас ${lvl} ур.</p></div></div>
      <p class="note">Прокачка, отряд и походы — в окне «Легион», вкладка «Войска».</p>
      <button type="button" class="btn" id="open-legion">${Icons.img('legion')} Открыть Легион</button>`;
  },

  bindBuilding(b) {
    const ol = $('open-legion');
    if (ol) ol.onclick = () => { this.tab = 'troops'; UI.openWindow('legion'); };
  },

  // Каждые четверть секунды: таймеры улучшений и обратный отсчёт на карточках
  tick() {
    Army.tick();
    for (const el of document.querySelectorAll('[data-run]')) {
      const u = state.army && state.army.upg[el.dataset.run];
      if (!u) continue;
      const left = (u.end - Date.now()) / 1000;
      el.querySelector('.bar > div').style.width = `${clamp(1 - left / Math.max(1, u.total), 0, 1) * 100}%`;
      el.querySelector('b').textContent = fmtDuration(left);
    }
  },

  /* ---------- Окно «Чудеса» ---------- */

  renderWonders(el) {
    Army.ensure();
    const A = state.army;
    if (!Army.unlocked()) {
      el.innerHTML = `<div class="explain">${Icons.svg('wonders')}<div><b>Чудеса света открывает легион.</b>
        <p>Изучите «Легион» и побеждайте в походах: с каждой победой растёт рейтинг легиона, а за рейтинг открываются Триумфальная арка, Колизей и Пантеон.</p></div></div>`;
      return;
    }
    const card = w => {
      const st = Army.wonderState(w), d = BUILDINGS[w.id];
      const name = d ? d.name : w.name;
      const pic = d && UI.icons[w.id] ? `<img class="w-pic" src="${UI.icons[w.id]}" alt="">` : `<span class="w-pic w-svg">${Icons.svg('wonders')}</span>`;
      let foot;
      if (st === 'built') foot = '<p class="w-done">✓ Построено — бонус действует</p>';
      else if (st === 'open') foot = `<div class="card-cost">${UI.costHtml(d.cost)}</div><button type="button" class="btn" data-wonder="${w.id}" ${canAfford(d.cost) ? '' : 'disabled'}>Построить</button>`;
      else if (st === 'locked') foot = `<div class="w-need"><div class="bar"><div style="width:${Math.min(100, A.rating / w.rating * 100)}%"></div></div><small>Рейтинг ${fmt(A.rating)} из ${fmt(w.rating)}</small></div>`;
      else foot = `<p class="w-pvp">${Icons.svg('swords')}Нужны бои с другими городами · рейтинг ${fmt(w.rating)}</p>`;
      return `<div class="wcard ${st}">${pic}<div class="w-body"><h4>${name}</h4>${d ? `<p>${d.desc}</p>` : ''}<p class="w-bonus">${w.bonus}</p>${foot}</div></div>`;
    };
    el.innerHTML = `
      <div class="explain">${Icons.svg('wonders')}<div><b>Чудеса света — за что воюет легион.</b> Рейтинг легиона: <b>${fmt(A.rating)}</b>, Славы: <b>${fmt(state.glory)}</b>.
        <p>Рейтинг растёт с каждой победой и не тратится. Когда его хватает, чудо можно построить: оно стоит много Славы и материалов и даёт сильный бонус городу и армии. Первые три открываются походами, старшие — боями с другими городами.</p></div></div>
      <div class="wgrid">${WONDERS.map(card).join('')}</div>`;
    el.querySelectorAll('[data-wonder]').forEach(b => b.onclick = () => UI.runAction({ tool: b.dataset.wonder }));
  },
};
