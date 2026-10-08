'use strict';
/* Меню армии: окно «Легион» (отряд, умения, карта походов), окно перед боем,
   карточка военного здания с прокачкой и вкладка «Военное дело» в окне «Знания». */

const PERK_SVG = {
  oil: '<path d="M4.5 10h15l-1.6 7.2a3 3 0 0 1-2.9 2.3H9a3 3 0 0 1-2.9-2.3z"/><path d="M3 10h18"/><path d="M9 3.5c1.2 1.2-1 2.3 0 3.6M13 3c1.2 1.2-1 2.3 0 3.6M17 3.8c1 1-.8 2 0 3"/>',
  testudo: '<path d="M12 3l7.5 3v5.2c0 4.6-3.1 8.2-7.5 9.8-4.4-1.6-7.5-5.2-7.5-9.8V6z"/><path d="M12 3v18M4.5 11h15"/>',
  bandage: '<path d="M9.5 4h5v5.5H20v5h-5.5V20h-5v-5.5H4v-5h5.5z"/>',
  volley: '<path d="M4 20L14 10M8 20l10-10M12 20l8-8"/><path d="M14 10h-4M14 10v4M18 10h-4M18 10v4M20 12h-3M20 12v3"/>',
  horn: '<path d="M4 15c4 0 9-3 12-8l3 1.5c-2 6-7 10-14 10.5z"/><path d="M4 15l1 3.8M16 7l1.5-3"/>',
};

const ArmyUI = {
  cycle: 0,

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
    const cycles = Math.floor(A.progress / (REGIONS.length * STAGES_PER_REGION)) + 1;
    this.cycle = Math.min(this.cycle, cycles - 1);
    el.innerHTML = `
      <div class="army-top">
        <section class="squad-box">
          <div class="squad-head"><h3>Отряд</h3><span class="power">${Icons.svg('people')}Сила <b>${fmt(Army.squadPower())}</b></span>
            <span class="food ${Army.food() < Army.foodCost() ? 'short' : ''}">${Icons.img('wheat')}На поход <b>${Army.foodCost()}</b> из ${fmt(Army.food())}</span></div>
          <div class="squad" id="squad">${this.squadHtml()}</div>
        </section>
        <section class="perks-box">
          <div class="squad-head"><h3>Умения в бою</h3><span class="power">${Icons.img('glory')}<b>${fmt(state.glory)}</b> Славы</span></div>
          <div class="perk-list">${PERK_IDS.map(id => this.perkCard(id)).join('')}</div>
        </section>
      </div>
      <div class="map-head">
        <h3 class="grp">Карта походов</h3>
        ${cycles > 1 ? `<div class="seg">${Array.from({ length: cycles }, (_, i) => `<button type="button" data-cycle="${i}" class="${i === this.cycle ? 'on' : ''}">Поход ${roman(i + 1)}</button>`).join('')}</div>` : ''}
        <button type="button" class="btn small ghost" id="fest-btn" ${state.glory < FESTIVAL.glory || state.day < state.festivalUntil ? 'disabled' : ''}>${Icons.img('glory')} Триумф: ${FESTIVAL.glory} Славы → +${FESTIVAL.happy} к счастью на ${FESTIVAL.days} дней</button>
      </div>
      <div class="camp-wrap" id="camp-wrap">${this.mapSvg(this.cycle)}</div>
      <p class="sub">Звёзды — сколько бойцов уцелело. Пройденные бои можно повторять ради добычи. Победа над боссом открывает следующую провинцию.</p>`;
    this.bind(el);
    const cur = el.querySelector('.node.current');
    if (cur) {
      const wrap = $('camp-wrap'), box = cur.getBoundingClientRect(), wb = wrap.getBoundingClientRect();
      wrap.scrollLeft += box.left - wb.left - wb.width / 2;
    }
  },

  squadHtml() {
    const A = state.army, slots = Army.slots();
    let html = '';
    for (let i = 0; i < Math.max(slots, 3); i++) {
      const t = A.squad[i];
      if (i >= slots) { html += `<div class="slot locked">${Icons.svg('pick')}<small>место на ${SQUAD_BY_LEVEL[i - SQUAD_BASE] || '—'} ур. Казарм</small></div>`; continue; }
      if (t && Army.available(t)) {
        const s = Army.stats(t);
        html += `<button type="button" class="slot" data-slot="${i}">${this.unitImg(t)}<b>${UNITS[t].name}</b><small>Сила ${Army.power(s)}</small></button>`;
      } else html += `<button type="button" class="slot empty" data-slot="${i}"><span class="plus">+</span><small>Свободно</small></button>`;
    }
    return html;
  },

  perkCard(id) {
    const lvl = state.army.perks[id], P = PERKS[id];
    if (!lvl) {
      const t = MIL_TECHS.find(x => x.perk === id);
      return `<div class="perk locked" title="${P.desc}"><span class="ring">${this.perkIcon(id)}</span><b>${P.name}</b><small>Военное дело: «${t.name}»</small></div>`;
    }
    const cost = Army.perkCost(id);
    return `<div class="perk" title="${P.desc}"><span class="ring">${this.perkIcon(id)}</span><b>${P.name}</b><small>${'★'.repeat(lvl)}${'☆'.repeat(PERK_MAX - lvl)} · раз в ${P.cd} с</small>
      ${lvl < PERK_MAX ? `<button type="button" class="btn tiny" data-perk-up="${id}" ${state.glory < cost ? 'disabled' : ''}>Усилить: ${cost} ${Icons.img('glory')}</button>` : '<small class="maxed">Максимум</small>'}</div>`;
  },

  bind(el) {
    el.querySelectorAll('[data-slot]').forEach(b => b.onclick = () => this.pickUnit(+b.dataset.slot));
    el.querySelectorAll('[data-perk-up]').forEach(b => b.onclick = () => { if (Army.upgradePerk(b.dataset.perkUp)) { UI.toast(`${PERKS[b.dataset.perkUp].name}: умение усилено`, 'good'); this.render(el); } });
    el.querySelectorAll('[data-cycle]').forEach(b => b.onclick = () => { this.cycle = +b.dataset.cycle; this.render(el); });
    el.querySelectorAll('[data-node]').forEach(n => n.addEventListener('click', () => {
      const [r, s] = n.dataset.node.split('-').map(Number);
      this.openStage(this.cycle, r, s);
    }));
    $('fest-btn').onclick = () => { if (Army.festival()) this.render(el); };
  },

  // Выбор бойца в место отряда
  pickUnit(i) {
    const A = state.army;
    const opts = UNIT_IDS.map(k => {
      const ok = Army.available(k), s = Army.stats(k);
      const why = ok ? `Сила ${Army.power(s)} · сильнее против: ${UNITS[k].strong}` : this.lockText(k);
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
    if (!isUnlocked(b)) return d.milTech ? `Военное дело: «${MIL_BY_ID[d.milTech].name}»` : `Нужно знание «${TECH_BY_ID[d.tech].name}»`;
    return `Постройте: ${d.name}`;
  },

  /* ---------- Карта походов ---------- */

  // Точки боёв на равном расстоянии вдоль извилистой дороги (по длине пути, а не по x)
  layout() {
    if (this._layout) return this._layout;
    const N = REGIONS.length * STAGES_PER_REGION, dense = [];
    const curve = t => [80 + t * 1480, 235 + Math.sin(t * Math.PI * 5.2 + 0.4) * 125];
    let len = 0, prev = curve(0);
    for (let i = 0; i <= 2000; i++) {
      const p = curve(i / 2000);
      len += Math.hypot(p[0] - prev[0], p[1] - prev[1]);
      dense.push([p[0], p[1], len]);
      prev = p;
    }
    const pts = [];
    let j = 0;
    for (let k = 0; k < N; k++) {
      const want = len * k / (N - 1);
      while (j < dense.length - 1 && dense[j][2] < want) j++;
      pts.push([dense[j][0], dense[j][1]]);
    }
    return (this._layout = pts);
  },

  nodePos(r, s) { return this.layout()[r * STAGES_PER_REGION + s]; },

  mapSvg(cycle) {
    const A = state.army, W = 1640, H = 470;
    const pts = this.layout();
    const nodes = [];
    let svg = `<svg class="camp-map" viewBox="0 0 ${W} ${H}" width="${W}" height="${H}" role="img" aria-label="Карта походов">
      <defs>
        <filter id="paper"><feTurbulence type="fractalNoise" baseFrequency="0.8" numOctaves="2"/><feColorMatrix values="0 0 0 0 0.5 0 0 0 0 0.38 0 0 0 0 0.2 0 0 0 0.09 0"/></filter>
        <radialGradient id="vign" cx="50%" cy="50%" r="75%"><stop offset="60%" stop-color="#000" stop-opacity="0"/><stop offset="100%" stop-color="#5a3a1a" stop-opacity="0.22"/></radialGradient>
      </defs>
      <rect width="${W}" height="${H}" fill="#efe0bd"/>
      <path d="M0 ${H - 28} C 220 ${H - 52}, 430 ${H - 10}, 650 ${H - 36} S 1100 ${H - 14}, 1310 ${H - 44} S 1560 ${H - 22}, ${W} ${H - 34} V ${H} H 0 Z" fill="#a9cfd6" opacity="0.85"/>
      <path d="M0 ${H - 28} C 220 ${H - 52}, 430 ${H - 10}, 650 ${H - 36} S 1100 ${H - 14}, 1310 ${H - 44} S 1560 ${H - 22}, ${W} ${H - 34}" fill="none" stroke="#7aa9b4" stroke-width="2" stroke-dasharray="6 6"/>`;
    // провинция — широкая цветная полоса вдоль своего участка дороги, вокруг — значки местности
    REGIONS.forEach((R, r) => {
      const seg = pts.slice(r * STAGES_PER_REGION, (r + 1) * STAGES_PER_REGION + (r < REGIONS.length - 1 ? 1 : 0));
      const d = 'M' + seg.map(p => p.join(',')).join(' L');
      const open = Army.stageIndex(cycle, r, 0) <= A.progress;
      // подпись — у середины провинции, со стороны от дороги
      const mid = seg[Math.floor(STAGES_PER_REGION / 2)], up = mid[1] > 235;
      const lx = clamp(mid[0], 110, W - 110), ly = clamp(mid[1] + (up ? -72 : 82), 34, H - 48);
      svg += `<g class="region ${open ? '' : 'fog'}">
        <path d="${d}" fill="none" stroke="${this.biomeColor(R.biome)}" stroke-width="118" stroke-linecap="round" stroke-linejoin="round" opacity="0.6"/>
        ${this.terrain(R.biome, seg, r)}
        <text x="${lx}" y="${ly}" class="reg-name">${R.name}</text>
      </g>`;
    });
    // дорога: пройденная часть — золотая
    const done = Math.min(pts.length - 1, A.progress - cycle * pts.length);
    svg += `<polyline points="${pts.map(p => p.join(',')).join(' ')}" class="road"/>`;
    if (done > 0) svg += `<polyline points="${pts.slice(0, done + 1).map(p => p.join(',')).join(' ')}" class="road done"/>`;
    for (let r = 0; r < REGIONS.length; r++) {
      for (let s = 0; s < STAGES_PER_REGION; s++) {
        const [x, y] = this.nodePos(r, s), idx = Army.stageIndex(cycle, r, s), key = Army.stageKey(cycle, r, s);
        const boss = s === STAGES_PER_REGION - 1, stars = A.stars[key] || 0;
        const cls = idx < A.progress ? 'done' : idx === A.progress ? 'current' : 'locked';
        const rad = boss ? 20 : 13;
        nodes.push(`<g class="node ${cls} ${boss ? 'boss' : ''}" ${cls !== 'locked' ? `data-node="${r}-${s}" tabindex="0" role="button"` : ''} transform="translate(${x},${y})">
          <title>${boss ? ENEMIES[REGIONS[r].boss].name : `${REGIONS[r].name}: бой ${s + 1}`}</title>
          <circle r="${rad + 5}" class="halo"/>
          <circle r="${rad}" class="disc"/>
          ${boss ? '<path d="M-9 4 L-11 -7 L-4 -2 L0 -10 L4 -2 L11 -7 L9 4 Z" class="crown"/>' : `<text y="4.5" class="num">${s + 1}</text>`}
          ${stars ? `<text y="${rad + 14}" class="stars">${'★'.repeat(stars)}${'☆'.repeat(3 - stars)}</text>` : ''}
        </g>`);
      }
    }
    svg += nodes.join('');
    svg += `<rect width="${W}" height="${H}" fill="url(#vign)" pointer-events="none"/><rect width="${W}" height="${H}" filter="url(#paper)" opacity="0.7" pointer-events="none"/></svg>`;
    return svg;
  },

  biomeColor(b) {
    return { forest: '#a9c97a', hills: '#d6cf8a', darkforest: '#7fa66a', swamp: '#9aaa7a', labyrinth: '#d9c9a2', rocks: '#c9c2a6', desert: '#ecd59a', hades: '#9a6a5a' }[b];
  },

  // Значки местности по обе стороны дороги: деревья, горы, болота, стены лабиринта, пальмы, вулканы
  terrain(b, seg, seed) {
    const rnd = mulberry32(seed * 101 + 5);
    let g = '';
    for (let i = 0; i < 12; i++) {
      const p = seg[Math.floor(rnd() * seg.length)], side = rnd() < 0.5 ? -1 : 1;
      const x = p[0] + (rnd() - 0.5) * 50, y = p[1] + side * (34 + rnd() * 24);
      if (b === 'forest' || b === 'darkforest') g += `<path d="M${x} ${y - 15} l8 12 h-4 l6 9 h-20 l6 -9 h-4 z" fill="${b === 'forest' ? '#5f8f45' : '#3f6a3a'}"/><rect x="${x - 1.5}" y="${y + 6}" width="3" height="4" fill="#6e4a2f"/>`;
      else if (b === 'hills' || b === 'rocks') g += `<path d="M${x - 15} ${y + 7} L${x} ${y - 12} L${x + 15} ${y + 7} Z" fill="${b === 'hills' ? '#b7a46a' : '#9a958c'}"/><path d="M${x - 4} ${y - 7} L${x} ${y - 12} L${x + 4} ${y - 7} Z" fill="#f2ead8"/>`;
      else if (b === 'swamp') g += `<ellipse cx="${x}" cy="${y}" rx="13" ry="4.5" fill="#6f8f8a"/><path d="M${x - 4} ${y} v-10 M${x} ${y} v-13 M${x + 4} ${y} v-9" stroke="#5f7a3a" stroke-width="2"/>`;
      else if (b === 'labyrinth') g += `<path d="M${x - 11} ${y - 9} h22 v18 h-18 v-12 h12 v6 h-5" fill="none" stroke="#9a8a6a" stroke-width="2.5"/>`;
      else if (b === 'desert') g += `<path d="M${x} ${y + 9} q-2 -11 2 -18" stroke="#8a6a46" stroke-width="2.5" fill="none"/><path d="M${x + 2} ${y - 9} q-9 -2 -13 4 M${x + 2} ${y - 9} q9 -3 12 4 M${x + 2} ${y - 9} q2 -8 -5 -10" stroke="#5f8f3a" stroke-width="3" fill="none"/>`;
      else if (b === 'hades') g += `<path d="M${x - 13} ${y + 7} L${x - 4} ${y - 11} L${x + 4} ${y - 11} L${x + 13} ${y + 7} Z" fill="#4a3530"/><path d="M${x - 3} ${y - 11} q3 -8 6 0" fill="#ff7a3a"/>`;
    }
    return g;
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
          <div class="row"><span>${Icons.img('wheat')} Провизия на поход</span><b class="${Army.food() < Army.foodCost() ? 'short' : ''}">${Army.foodCost()} из ${fmt(Army.food())}</b></div>
          ${state.army.stars[st.key] ? `<div class="row"><span>Лучший результат</span><b class="stars">${'★'.repeat(state.army.stars[st.key])}</b></div>` : ''}
        </div>
        ${err ? `<p class="note bad">${err}</p>` : ''}
        <div class="actions">
          <button type="button" class="btn" id="go-battle" ${err ? 'disabled' : ''}>В бой!</button>
          <button type="button" class="btn ghost" id="go-squad">Изменить отряд</button>
          <button type="button" class="btn ghost" id="go-cancel">Отмена</button>
        </div>
      </div>`, 'wide');
    $('go-battle').onclick = () => Battle.start(st);
    $('go-squad').onclick = () => { UI.closeModal(); UI.openWindow('legion'); };
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

  /* ---------- Военное здание: боец и прокачка ---------- */

  buildingPanel(b) {
    Army.ensure();
    const key = UNIT_BY_BUILDING[b.type];
    if (!key) return '';
    const U = UNITS[key], s = Army.stats(key), A = state.army;
    Battle.renderPortraits([key]);
    let html = `<div class="unit-card">${this.unitImg(key, 'uc-img')}<div><b>${U.name}</b><p>${U.role}</p><p class="strong">Сильнее против: ${U.strong}</p></div></div>
      <div class="rows">
        <div class="row"><span>Здоровье</span><b>${fmt(s.hp)}</b></div>
        <div class="row"><span>Урон</span><b>${fmt(s.atk)} раз в ${s.rate} с</b></div>
        <div class="row"><span>Броня</span><b>${s.armor} (−${Math.round(s.armor / (s.armor + 100) * 100)}% урона)</b></div>
        <div class="row"><span>Дальность</span><b>${s.range > 3 ? `${s.range} шагов` : 'ближний бой'}</b></div>
        <div class="row"><span>Сила бойца</span><b>${Army.power(s)}</b></div>
      </div>`;
    if (b.type === 'barracks') {
      const nextSlot = SQUAD_BY_LEVEL.find(l => l > A.levels.legionary);
      html += `<p class="note">Мест в отряде: <b>${Army.slots()}</b>${nextSlot ? `. Следующее место — на ${nextSlot} уровне Казарм.` : '.'}</p>`;
    }
    html += `<h3>Прокачка</h3><div class="upg-list" id="upg-list">${this.upgradeRows(key)}</div>`;
    const cap = Army.cap(), pop = Army.nextCapPop();
    if (!TEST_MODE && pop && A.levels[key] >= cap) html += `<p class="note">Предел уровня для вашего города — ${cap}. Чтобы качать дальше, вырастите город до ${fmt(pop)} жителей.</p>`;
    html += `<button type="button" class="btn" id="open-legion">${Icons.img('legion')} Отряд и карта походов</button>`;
    return html;
  },

  upgradeRows(key) {
    const A = state.army, u = A.upg[key];
    return ['level', 'weapon', 'armor'].map(kind => {
      const K = UPGRADE_KINDS[kind], i = Army.upgradeInfo(key, kind);
      let right;
      if (u && u.kind === kind) {
        const left = (u.end - Date.now()) / 1000, k = 1 - left / Math.max(1, u.total);
        right = `<div class="upg-run" data-run="${key}"><div class="bar"><div style="width:${clamp(k, 0, 1) * 100}%"></div></div><small>до ${u.to} ур. · осталось <b>${fmtDuration(left)}</b></small>
          ${TEST_MODE ? `<button type="button" class="btn tiny ghost" data-finish="${key}">Завершить (тест)</button>` : ''}</div>`;
      } else if (i.max) right = '<small class="maxed">Максимум</small>';
      else if (i.blocked) right = `<small class="why">${kind === 'level' ? `Предел города: ${i.limit}` : `Сначала уровень здания ${i.to}`}</small>`;
      else {
        const can = Army.canUpgrade(key, kind);
        right = `<div class="upg-buy"><span class="card-cost">${UI.costHtml(i.cost)}</span><small>${fmtDuration(i.time)}</small>
          <button type="button" class="btn tiny" data-upg="${key}:${kind}" ${can ? '' : 'disabled'} title="${u ? 'В здании уже идёт улучшение' : ''}">До ${i.to} ур.</button></div>`;
      }
      return `<div class="upg"><div class="upg-name"><b>${K.name}</b><span class="lvl">${i.cur}</span><small>${K.what}</small></div>${right}</div>`;
    }).join('');
  },

  bindBuilding(b) {
    const key = UNIT_BY_BUILDING[b.type];
    if (!key) return;
    document.querySelectorAll('[data-upg]').forEach(btn => btn.onclick = () => {
      const [k, kind] = btn.dataset.upg.split(':');
      if (Army.startUpgrade(k, kind)) UI.refreshPanel();
    });
    document.querySelectorAll('[data-finish]').forEach(btn => btn.onclick = () => { Army.finishUpgrade(btn.dataset.finish); });
    const ol = $('open-legion');
    if (ol) ol.onclick = () => UI.openWindow('legion');
  },

  // Каждые четверть секунды: обратный отсчёт улучшений в открытой карточке
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

  /* ---------- Военное дело ---------- */

  renderMilResearch(el) {
    Army.ensure();
    const A = state.army, busy = A.research ? MIL_BY_ID[A.research.id] : null;
    const cols = [];
    for (const t of MIL_TECHS) (cols[t.col] = cols[t.col] || []).push(t);
    const card = t => {
      const st = Army.techState(t), afford = state.glory >= t.glory && state.money >= t.money;
      const days = MIL_DAYS[t.col];
      const opens = t.unlocks ? `<div class="opens"><img src="${UI.icons[t.unlocks]}" alt="" data-card="${t.unlocks}"></div>` : t.perk ? `<div class="opens perk-open">${this.perkIcon(t.perk)}</div>` : '';
      let foot;
      if (st === 'done') foot = '<span class="tech-done">✓ Изучено</span>';
      else if (st === 'active') foot = `<div class="tech-prog"><div class="bar"><div style="width:${(1 - A.research.left / A.research.total) * 100}%"></div></div><span>Изучается · осталось <b>${A.research.left}</b> ${plural(A.research.left, 'день', 'дня', 'дней')}</span></div>`;
      else if (st === 'locked') foot = `<span class="tech-lock">Сначала: ${t.req.filter(r => !A.techs.includes(r)).map(r => MIL_BY_ID[r].name).join(', ')}</span>`;
      else foot = `<button type="button" class="btn small" data-mtech="${t.id}" ${afford && !busy ? '' : 'disabled'}>${Icons.img('glory')}${t.glory} ${Icons.img('money')}${fmt(t.money)}</button><span class="tech-time">${busy ? 'После текущего' : `${days} ${plural(days, 'день', 'дня', 'дней')}`}</span>`;
      return `<div class="tech mil ${st}${st === 'open' && afford && !busy ? ' ready' : ''}" data-tech-id="m-${t.id}"><h4>${t.name}</h4><p>${t.desc}</p>${opens}${foot}</div>`;
    };
    el.innerHTML = `
      <div class="explain">${Icons.img('glory', 'big')}<div><b>Военное дело изучается за Славу и денарии.</b> У вас ${fmt(state.glory)} Славы.
        <p>Слава даётся за победы в походах. Военное дело открывает новые военные здания, умения в бою и бонусы всем бойцам. Изучается одно знание за раз, несколько дней.</p>
        ${busy ? `<p class="now">Сейчас изучается «${busy.name}» — осталось ${A.research.left} ${plural(A.research.left, 'день', 'дня', 'дней')}.</p>` : ''}</div></div>
      <div class="tree-wrap"><svg class="tree-lines" id="tree-lines"></svg><div class="tree mil-tree">${cols.map(c => `<div class="tcol">${c.map(card).join('')}</div>`).join('')}</div></div>`;
    el.querySelectorAll('[data-mtech]').forEach(b => b.onclick = () => { if (Army.research(b.dataset.mtech)) UI.renderWindow(); });
    requestAnimationFrame(() => this.drawMilLines());
  },

  drawMilLines() {
    const svg = $('tree-lines');
    if (!svg) return;
    const wrap = svg.parentElement, box = wrap.getBoundingClientRect();
    svg.setAttribute('width', wrap.scrollWidth);
    svg.setAttribute('height', wrap.scrollHeight);
    let d = '';
    for (const t of MIL_TECHS) {
      const to = wrap.querySelector(`[data-tech-id="m-${t.id}"]`);
      if (!to) continue;
      const b = to.getBoundingClientRect();
      for (const r of t.req) {
        const from = wrap.querySelector(`[data-tech-id="m-${r}"]`);
        if (!from) continue;
        const a = from.getBoundingClientRect();
        const x1 = a.right - box.left + wrap.scrollLeft, y1 = a.top + a.height / 2 - box.top + wrap.scrollTop;
        const x2 = b.left - box.left + wrap.scrollLeft, y2 = b.top + 22 - box.top + wrap.scrollTop;
        const mx = (x1 + x2) / 2;
        d += `<path d="M${x1},${y1} C${mx},${y1} ${mx},${y2} ${x2},${y2}" class="${state.army.techs.includes(r) ? 'done' : ''}"/>`;
      }
    }
    svg.innerHTML = d;
  },
};
