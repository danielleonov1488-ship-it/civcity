'use strict';
/* Легион: обучение в казармах, походы по карте провинции, автобитва, Слава и триумф. */

const Military = {
  capacity() {
    let n = 0;
    for (const b of state.buildings.values()) if (b.type === 'barracks' && b.active) n++;
    return n * BUILDINGS.barracks.capacity;
  },

  total() {
    const L = state.legion;
    return L.soldiers + (L.mission ? L.mission.soldiers : 0);
  },

  power() { return 1 + (hasTech('triumph') ? 0.15 : 0); },

  daily() {
    const L = state.legion;
    const barracks = [...state.buildings.values()].filter(b => b.type === 'barracks' && b.active);
    if (barracks.length && this.total() < this.capacity()) {
      L.progress += barracks.reduce((s, b) => s + b.staff, 0);
      while (L.progress >= LEGIONARY_DAYS) {
        if (this.total() >= this.capacity()) { L.progress = 0; break; }
        if (!canAfford(LEGIONARY_COST)) {
          L.progress = LEGIONARY_DAYS;
          if (state.day >= (L.warnDay || 0)) {
            L.warnDay = state.day + 40;
            UI.log('Казармам не хватает оружия или денариев для новых легионеров.', 'warn');
          }
          break;
        }
        pay(LEGIONARY_COST);
        L.soldiers++;
        L.progress -= LEGIONARY_DAYS;
      }
    }
    const m = L.mission;
    if (!m) return;
    if (m.phase === 'march' && state.day >= m.arrive) this.resolve(m);
    else if (m.phase === 'return' && state.day >= m.back) {
      L.soldiers += m.survivors;
      L.mission = null;
      UI.log(`Легион вернулся домой: ${m.survivors} ${plural(m.survivors, 'солдат', 'солдата', 'солдат')}.`, 'good', true);
    }
  },

  status(c) {
    const day = state.conquered[c.id];
    if (day === undefined) return 'open';
    if (!c.repeat) return 'done';
    return state.day >= day + c.repeat ? 'open' : 'cooldown';
  },

  send(id) {
    const L = state.legion, c = CAMPAIGNS.find(x => x.id === id);
    if (!c || L.mission || L.soldiers < 1 || this.status(c) !== 'open') return false;
    L.mission = { target: id, soldiers: L.soldiers, phase: 'march', arrive: state.day + c.days };
    L.soldiers = 0;
    UI.log(`Легион выступил в поход: ${c.name}. Дорога займёт ${c.days} дней.`, 'info', true);
    return true;
  },

  chance(soldiers, c) {
    const r = soldiers * this.power() / c.strength;
    return clamp(0.5 + (r - 1) * 1.1, 0.04, 0.97);
  },

  resolve(m) {
    const c = CAMPAIGNS.find(x => x.id === m.target);
    const r = m.soldiers * this.power() / c.strength;
    const win = Math.random() < this.chance(m.soldiers, c);
    let losses = win
      ? Math.round(m.soldiers * clamp(0.3 / r, 0.04, 0.5) * (0.7 + Math.random() * 0.6))
      : Math.round(m.soldiers * (0.45 + Math.random() * 0.25));
    losses = Math.min(m.soldiers, Math.max(win ? 0 : 1, losses));
    const record = { target: c.id, win, soldiers: m.soldiers, enemy: c.strength, losses, day: state.day };
    if (win) {
      giveReward(c.reward);
      state.conquered[c.id] = state.day;
      record.reward = c.reward;
    }
    m.phase = 'return';
    m.back = state.day + Math.ceil(c.days * 0.7);
    m.survivors = m.soldiers - losses;
    state.lastBattle = record;
    UI.battleNotice(record);
  },

  festival() {
    if (state.glory < FESTIVAL.glory || state.day < state.festivalUntil) return false;
    state.glory -= FESTIVAL.glory;
    state.festivalUntil = state.day + FESTIVAL.days;
    UI.log(`Триумф! Город празднует ${FESTIVAL.days} дней, все жители счастливее.`, 'good', true);
    afterCityChanged();
    return true;
  },
};

/* ---------- Карта провинции ---------- */

const ProvinceMap = {
  selected: null,

  open() { UI.openWindow('legion'); },

  // Рисует вкладку «Легион» в окне «Империя»
  render(el) {
    const L = state.legion;
    const cap = Military.capacity();
    this.selected = this.selected || CAMPAIGNS.find(c => Military.status(c) === 'open')?.id || CAMPAIGNS[0].id;
    const locked = !hasTech('legion');
    el.innerHTML = `
      <div class="explain">
        ${Icons.img('legion', 'big')}
        <div><b>Легион воюет сам — вы выбираете цель и смотрите битву.</b>
        <p>Казармы обучают солдат из оружия и денариев. Победы приносят золото, товары, Славу и даже постоянную дань. Слава тратится на чудеса света, особые украшения и праздник-триумф.</p></div>
      </div>
      <div class="kpis">
        <div class="kpi"><small>В казармах</small><b>${L.soldiers}</b></div>
        <div class="kpi"><small>Мест в казармах</small><b>${cap}</b></div>
        <div class="kpi"><small>В походе</small><b>${L.mission ? L.mission.soldiers : 0}</b></div>
        <div class="kpi"><small>Слава</small><b>${Icons.img('glory')} ${fmt(state.glory)}</b></div>
      </div>
      ${locked ? '<p class="note">Сначала изучите «Легион» во вкладке «Знания» и постройте казармы.</p>' : cap ? `<p class="sub">Казармы обучают солдата за ${LEGIONARY_DAYS} дней: ${LEGIONARY_COST.weapons} ${Icons.img('weapons')} оружия и ${LEGIONARY_COST.money} ${Icons.img('money')}.</p>` : '<p class="note">Постройте казармы (категория «Армия» внизу), чтобы обучать солдат.</p>'}
      <canvas id="pmap" width="900" height="460"></canvas>
      <div id="pmap-info"></div>
      <div class="actions">
        <button type="button" class="btn ghost" id="fest-btn" ${state.glory < FESTIVAL.glory || state.day < state.festivalUntil ? 'disabled' : ''}>${Icons.img('glory')} Устроить триумф: ${FESTIVAL.glory} Славы, +${FESTIVAL.happy} к счастью на ${FESTIVAL.days} дней</button>
        ${state.lastBattle ? '<button type="button" class="btn ghost" id="last-battle">Смотреть последнюю битву</button>' : ''}
      </div>`;
    $('fest-btn').onclick = () => { if (Military.festival()) this.render(el); };
    const lb = $('last-battle');
    if (lb) lb.onclick = () => Battle.show(state.lastBattle);
    this.el = el;
    const cv = $('pmap');
    cv.onclick = e => {
      const r = cv.getBoundingClientRect();
      const x = (e.clientX - r.left) / r.width, y = (e.clientY - r.top) / r.height;
      let best = null, bd = 0.06;
      for (const c of CAMPAIGNS) { const d = Math.hypot(c.x - x, (c.y - y) * 0.58); if (d < bd) { bd = d; best = c; } }
      if (best) { this.selected = best.id; this.draw(); this.info(); }
    };
    this.draw();
    this.info();
  },

  info() {
    const c = CAMPAIGNS.find(x => x.id === this.selected);
    const L = state.legion;
    const st = Military.status(c);
    const chance = L.soldiers ? Math.round(Military.chance(L.soldiers, c) * 100) : 0;
    let action = '';
    if (L.mission) {
      const t = CAMPAIGNS.find(x => x.id === L.mission.target);
      action = L.mission.phase === 'march'
        ? `<p class="note">Легион в походе: «${t.name}», битва через ${Math.max(0, L.mission.arrive - state.day)} дн.</p>`
        : `<p class="note">Легион возвращается домой, ещё ${Math.max(0, L.mission.back - state.day)} дн.</p>`;
    } else if (st === 'done') action = '<p class="note good">Покорено. Дань поступает в город.</p>';
    else if (st === 'cooldown') action = `<p class="note">Покорено недавно. Снова можно напасть через ${state.conquered[c.id] + c.repeat - state.day} дн.</p>`;
    else if (!L.soldiers) action = '<p class="note">В казармах нет солдат.</p>';
    else action = `<button type="button" class="btn" id="send-btn">Отправить легион: ${L.soldiers} ${plural(L.soldiers, 'солдат', 'солдата', 'солдат')} · шанс победы ${chance}%</button>`;
    const trib = c.tribute ? ` · дань: ${Object.entries(c.tribute).map(([g, v]) => `${v} ${GOODS[g].name.toLowerCase()} в день`).join(', ')}` : '';
    $('pmap-info').innerHTML = `
      <div class="pmap-card">
        <h3>${c.name}</h3>
        <p class="sub">${c.desc}</p>
        <p class="facts">Сила врага: <b>${c.strength}</b> · Поход: <b>${c.days} дн.</b> · Награда: <b>${rewardText(c.reward)}</b>${trib}</p>
        ${action}
      </div>`;
    const sb = $('send-btn');
    if (sb) sb.onclick = () => { if (Military.send(c.id)) this.render(this.el); };
  },

  draw() {
    const cv = $('pmap');
    if (!cv) return;
    const ctx = cv.getContext('2d'), W = cv.width, H = cv.height;
    // пергамент
    const g = ctx.createRadialGradient(W / 2, H / 2, 50, W / 2, H / 2, W * 0.7);
    g.addColorStop(0, '#f4e7c6'); g.addColorStop(1, '#dcc796');
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, W, H);
    // море
    ctx.fillStyle = '#a9c7c8';
    ctx.beginPath();
    ctx.moveTo(0, H * 0.78);
    ctx.bezierCurveTo(W * 0.2, H * 0.7, W * 0.35, H * 0.95, W * 0.5, H * 0.8);
    ctx.bezierCurveTo(W * 0.65, H * 0.7, W * 0.75, H * 0.95, W, H * 0.85);
    ctx.lineTo(W, H); ctx.lineTo(0, H); ctx.closePath(); ctx.fill();
    ctx.strokeStyle = 'rgba(70,100,110,0.4)';
    for (let i = 0; i < 18; i++) {
      const x = (i * 97) % W, y = H * 0.88 + (i % 3) * 12;
      ctx.beginPath(); ctx.arc(x, y, 6, Math.PI * 1.1, Math.PI * 1.9); ctx.stroke();
    }
    // река
    ctx.strokeStyle = '#8fb3b8'; ctx.lineWidth = 5;
    ctx.beginPath(); ctx.moveTo(W * 0.05, H * 0.08); ctx.bezierCurveTo(W * 0.3, H * 0.2, W * 0.4, H * 0.05, W, H * 0.22); ctx.stroke();
    // горы и леса
    const rnd = (i) => hash2(i, 3, 9);
    for (let i = 0; i < 26; i++) {
      const x = rnd(i) * W, y = rnd(i + 50) * H * 0.7;
      if (Math.hypot(x - W * 0.36, y - H * 0.5) < 60) continue;
      if (i % 2) {
        ctx.fillStyle = '#b7a07a';
        ctx.beginPath(); ctx.moveTo(x - 14, y + 8); ctx.lineTo(x, y - 12); ctx.lineTo(x + 14, y + 8); ctx.closePath(); ctx.fill();
        ctx.fillStyle = '#f2ead7';
        ctx.beginPath(); ctx.moveTo(x - 4, y - 6); ctx.lineTo(x, y - 12); ctx.lineTo(x + 4, y - 6); ctx.closePath(); ctx.fill();
      } else {
        ctx.fillStyle = '#93a36a';
        for (let k = 0; k < 3; k++) { ctx.beginPath(); ctx.arc(x + k * 8 - 8, y + (k % 2) * 3, 6, 0, Math.PI * 2); ctx.fill(); }
      }
    }
    // дороги от города к целям
    const city = [W * 0.36, H * 0.5];
    ctx.setLineDash([6, 6]);
    ctx.lineWidth = 2;
    for (const c of CAMPAIGNS) {
      ctx.strokeStyle = c.id === this.selected ? '#a3372a' : 'rgba(110,80,50,0.45)';
      ctx.beginPath(); ctx.moveTo(city[0], city[1]); ctx.lineTo(c.x * W, c.y * H); ctx.stroke();
    }
    ctx.setLineDash([]);
    // город
    ctx.fillStyle = '#a3372a';
    ctx.beginPath(); ctx.arc(city[0], city[1], 17, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = '#f4e7c6';
    ctx.font = '800 9.5px Nunito, sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText('SPQR', city[0], city[1] + 4);
    ctx.fillStyle = '#3a2e26';
    ctx.font = '18px Forum, serif';
    ctx.fillText(state.cityName, city[0], city[1] + 36);
    // цели
    for (const c of CAMPAIGNS) {
      const x = c.x * W, y = c.y * H, st = Military.status(c);
      const sel = c.id === this.selected;
      ctx.fillStyle = 'rgba(60,40,20,0.2)';
      ctx.beginPath(); ctx.ellipse(x, y + 12, 12, 4, 0, 0, Math.PI * 2); ctx.fill();
      ctx.fillStyle = '#6e4a2f';
      ctx.fillRect(x - 1.5, y - 16, 3, 28);
      ctx.fillStyle = st === 'done' ? '#c9a24a' : st === 'cooldown' ? '#a3a08a' : '#5a6a8a';
      ctx.beginPath(); ctx.moveTo(x + 1.5, y - 16); ctx.lineTo(x + 20, y - 11); ctx.lineTo(x + 1.5, y - 5); ctx.closePath(); ctx.fill();
      if (sel) { ctx.strokeStyle = '#a3372a'; ctx.lineWidth = 2.5; ctx.beginPath(); ctx.arc(x, y, 22, 0, Math.PI * 2); ctx.stroke(); }
      ctx.fillStyle = '#3a2e26';
      ctx.font = `${sel ? 800 : 700} 12px Nunito, sans-serif`;
      ctx.fillText(c.name, x, y + 28);
      ctx.font = '600 11px Nunito, sans-serif';
      ctx.fillStyle = '#7b6a5b';
      ctx.fillText(st === 'done' ? 'покорено' : st === 'cooldown' ? 'недавно разбиты' : `сила ${c.strength}`, x, y + 41);
    }
    // легион в пути
    const m = state.legion.mission;
    if (m) {
      const c = CAMPAIGNS.find(x => x.id === m.target);
      let k = m.phase === 'march' ? 1 - (m.arrive - state.day) / c.days : (m.back - state.day) / Math.ceil(c.days * 0.7);
      k = clamp(k, 0, 1);
      const x = lerp(city[0], c.x * W, k), y = lerp(city[1], c.y * H, k);
      ctx.fillStyle = '#a3372a';
      ctx.fillRect(x - 7, y - 9, 14, 14);
      ctx.fillStyle = '#e0b040';
      ctx.fillRect(x - 2, y - 15, 4, 6);
    }
  },
};

/* ---------- Автобитва: короткая сценка ---------- */

const Battle = {
  raf: 0,

  show(rec) {
    const c = CAMPAIGNS.find(x => x.id === rec.target);
    UI.showModal(`
      <div class="battle">
        <p class="eyebrow">Битва</p>
        <h2>${c.name}</h2>
        <canvas id="bcv" width="720" height="320"></canvas>
        <div id="bres" class="bres" hidden></div>
        <div class="actions"><button type="button" class="btn ghost" id="b-close">Закрыть</button></div>
      </div>`, 'wide');
    $('b-close').onclick = () => { cancelAnimationFrame(this.raf); UI.closeModal(); };
    this.run(rec, c);
  },

  run(rec, c) {
    const cv = $('bcv'), ctx = cv.getContext('2d'), W = cv.width, H = cv.height;
    const nR = Math.min(36, Math.max(3, rec.soldiers)), nE = Math.min(36, Math.max(3, Math.round(rec.enemy * 0.9)));
    const deadR = Math.round(nR * rec.losses / rec.soldiers);
    const deadE = rec.win ? nE : Math.round(nE * 0.45);
    const mk = (n, side) => Array.from({ length: n }, (_, i) => {
      const col = i % 8, row = Math.floor(i / 8);
      return { side, row, x0: side < 0 ? 170 - row * 30 : W - 170 + row * 30, y: 140 + col * 22 + (row % 2) * 8, die: Infinity, hue: Math.random() };
    });
    const R = mk(nR, -1), E = mk(nE, 1);
    const pickDie = (arr, n) => { const idx = arr.map((_, i) => i).sort(() => Math.random() - 0.5).slice(0, n); for (const i of idx) arr[i].die = 2.0 + Math.random() * 2.6; };
    pickDie(R, deadR); pickDie(E, deadE);
    const enemyCol = ['#5a6a8a', '#7a6a4a', '#6a7a4a', '#8a5a4a'];
    const start = performance.now();
    const T = 5.2;
    const step = () => {
      const t = (performance.now() - start) / 1000;
      // фон
      const sky = ctx.createLinearGradient(0, 0, 0, H);
      sky.addColorStop(0, '#cfe0dc'); sky.addColorStop(0.35, '#e9e2c9'); sky.addColorStop(0.36, '#a9c06e'); sky.addColorStop(1, '#8fae58');
      ctx.fillStyle = sky; ctx.fillRect(0, 0, W, H);
      ctx.fillStyle = '#9bb36a';
      ctx.beginPath(); ctx.moveTo(0, 118); ctx.bezierCurveTo(200, 90, 420, 130, W, 100); ctx.lineTo(W, 120); ctx.lineTo(0, 125); ctx.fill();
      const meet = W / 2;
      const adv = clamp(t / 1.8, 0, 1);
      const draw = (u, isR) => {
        const dead = t > u.die;
        let x = lerp(u.x0, meet + (isR ? -16 - u.row * 24 : 16 + u.row * 24), adv);
        if (t > 1.8 && !dead) x += Math.sin(t * 9 + u.hue * 10) * 3;
        const y = u.y;
        ctx.save();
        ctx.translate(x, y);
        if (dead) { ctx.rotate(isR ? -1.4 : 1.4); ctx.globalAlpha = 0.55; }
        ctx.fillStyle = 'rgba(40,40,20,0.2)';
        ctx.beginPath(); ctx.ellipse(0, 10, 7, 2.5, 0, 0, Math.PI * 2); ctx.fill();
        ctx.fillStyle = isR ? '#b8452f' : enemyCol[Math.floor(u.hue * 4)];
        ctx.fillRect(-4, -6, 8, 13);
        ctx.fillStyle = '#e9bf98';
        ctx.beginPath(); ctx.arc(0, -10, 4, 0, Math.PI * 2); ctx.fill();
        if (isR) {
          ctx.fillStyle = '#9a8a6a'; ctx.beginPath(); ctx.arc(0, -11, 4.4, Math.PI, 0); ctx.fill();
          ctx.fillStyle = '#c0392b'; ctx.fillRect(-1, -18, 2, 5);
          ctx.fillStyle = '#a3372a'; ctx.fillRect(4, -7, 6, 14);
          ctx.fillStyle = '#e0b040'; ctx.fillRect(6, -1, 2, 2);
        } else {
          ctx.fillStyle = '#7a5a3a'; ctx.beginPath(); ctx.arc(-7, 0, 6, 0, Math.PI * 2); ctx.fill();
          ctx.fillStyle = '#c9a46a'; ctx.fillRect(-2, -15, 4, 3);
        }
        ctx.strokeStyle = '#ccc'; ctx.lineWidth = 1.5;
        ctx.beginPath(); ctx.moveTo(isR ? -3 : 3, -2); ctx.lineTo(isR ? -3 + 9 * Math.cos(t * 8 + u.hue * 6) : 3 - 9 * Math.cos(t * 8 + u.hue * 6), -9); ctx.stroke();
        ctx.restore();
      };
      for (const u of R) draw(u, true);
      for (const u of E) draw(u, false);
      // пыль в схватке
      if (t > 1.6 && t < 4.8) {
        for (let i = 0; i < 14; i++) {
          const a = t * 2 + i;
          ctx.fillStyle = `rgba(225,210,170,${0.25 + 0.15 * Math.sin(a)})`;
          ctx.beginPath(); ctx.arc(meet + Math.sin(a * 1.3) * 60, 150 + Math.cos(a) * 60, 14 + 6 * Math.sin(a * 2), 0, Math.PI * 2); ctx.fill();
        }
      }
      // счёт
      const aliveR = R.filter(u => t <= u.die).length, aliveE = E.filter(u => t <= u.die).length;
      ctx.font = '800 15px Nunito, sans-serif';
      ctx.textAlign = 'left'; ctx.fillStyle = '#a3372a';
      ctx.fillText(`Рим: ${Math.round(rec.soldiers * aliveR / nR)}`, 14, 26);
      ctx.textAlign = 'right'; ctx.fillStyle = '#3a4a6a';
      ctx.fillText(`Враг: ${Math.round(rec.enemy * aliveE / nE)}`, W - 14, 26);
      if (t > T) {
        ctx.fillStyle = 'rgba(30,20,10,0.35)'; ctx.fillRect(0, H / 2 - 34, W, 68);
        ctx.textAlign = 'center';
        ctx.font = '40px Forum, serif';
        ctx.fillStyle = rec.win ? '#ffe39a' : '#f3d0c8';
        ctx.fillText(rec.win ? 'ПОБЕДА!' : 'ОТСТУПЛЕНИЕ', W / 2, H / 2 + 13);
        const res = $('bres');
        if (res && res.hidden) {
          res.hidden = false;
          res.innerHTML = rec.win
            ? `<p><b>Легион победил.</b> Потери: ${rec.losses} из ${rec.soldiers}. Добыча: ${rewardText(rec.reward)}.</p>`
            : `<p><b>Враг оказался сильнее.</b> Потери: ${rec.losses} из ${rec.soldiers}. Обучите больше солдат и попробуйте снова.</p>`;
        }
        return;
      }
      this.raf = requestAnimationFrame(step);
    };
    cancelAnimationFrame(this.raf);
    this.raf = requestAnimationFrame(step);
  },
};
