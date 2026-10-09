'use strict';
/* Режим фото (как в Town to City): интерфейс прячется, камеру можно опустить к самой земле, выбрать время суток,
   пойти следом за жителем по улице и сохранить снимок. Клавиша P или меню ☰ → «Режим фото»; Esc — выйти. */

const Photo = {
  on: false,
  follow: null,        // житель, за которым идёт камера
  saved: null,

  init() {
    const bar = document.createElement('div');
    bar.id = 'photo-bar';
    bar.className = 'panel photo-bar';
    bar.hidden = true;
    bar.innerHTML = `
      <label class="pb-slider">Наклон<input type="range" id="pb-pitch" min="4" max="75" step="1"></label>
      <label class="pb-slider">Время суток<input type="range" id="pb-time" min="0" max="100" step="1"></label>
      <button type="button" class="btn small ghost" id="pb-follow">За жителем</button>
      <button type="button" class="btn small ghost" id="pb-next" hidden>Другой житель</button>
      <button type="button" class="btn small" id="pb-snap">Снимок</button>
      <button type="button" class="btn small ghost" id="pb-exit">Выйти <kbd>Esc</kbd></button>
      <span class="pb-hint">Колёсико — ближе, правая кнопка — двигать, средняя — вращать</span>`;
    document.body.append(bar);
    const flash = document.createElement('div');
    flash.id = 'photo-flash';
    document.body.append(flash);
    $('pb-pitch').oninput = e => { Engine.cam.pitch = +e.target.value * Math.PI / 180; };
    $('pb-time').oninput = e => { Atmos.t = +e.target.value / 100; };
    $('pb-follow').onclick = () => this.setFollow(this.follow ? null : this.pickWalker());
    $('pb-next').onclick = () => this.setFollow(this.pickWalker());
    $('pb-snap').onclick = () => this.snap();
    $('pb-exit').onclick = () => this.close();
  },

  toggle() { if (this.on) this.close(); else this.open(); },

  open() {
    if (this.on || Battle.active) return;
    if (!$('photo-bar')) this.init();
    this.on = true;
    Input.setTool(null);
    UI.closePanel();
    UI.closeTray();
    UI.closeMenu();
    const c = Engine.cam;
    this.saved = { cycle: Atmos.cycle, t: Atmos.t, dist: c.distTarget };
    Atmos.cycle = false;
    // начальный наклон — как был у камеры
    const tt = clamp((c.dist - DIST_MIN) / (DIST_LOOK - DIST_MIN), 0, 1);
    c.pitch = lerp(PITCH_NEAR, PITCH_FAR, Math.pow(tt, 0.4));
    $('pb-pitch').value = Math.round(c.pitch * 180 / Math.PI);
    $('pb-time').value = Math.round(Atmos.t * 100);
    document.body.classList.add('photo-mode');
    Engine.setCleanView(true);
    $('photo-bar').hidden = false;
  },

  close() {
    if (!this.on) return;
    this.on = false;
    this.setFollow(null);
    const c = Engine.cam;
    c.pitch = null;
    c.lookY = 0;
    c.distTarget = clamp(Math.max(c.distTarget, DIST_MIN), DIST_MIN, DIST_MAX);
    Atmos.cycle = this.saved ? this.saved.cycle : Settings.dayCycle;
    if (this.saved) Atmos.t = this.saved.t;
    document.body.classList.remove('photo-mode');
    Engine.setCleanView(false);
    $('photo-bar').hidden = true;
  },

  // ближайший к центру экрана житель, который идёт
  pickWalker() {
    const c = Engine.cam, list = Walkers.list.filter(w => w.alpha > 0.5 && !w.settler && w !== this.follow);
    if (!list.length) return null;
    list.sort((a, b) => Math.hypot(a.wx - c.x, a.wy - c.z) - Math.hypot(b.wx - c.x, b.wy - c.z));
    return list[Math.floor(Math.random() * Math.min(4, list.length))];
  },

  setFollow(w) {
    this.follow = w;
    const c = Engine.cam;
    if (w) {
      // житель не исчезает, пока за ним идут
      w.life = Math.max(w.life, 600);
      c.distTarget = 3.2;
      c.pitch = 0.32;
      $('pb-pitch').value = Math.round(c.pitch * 180 / Math.PI);
    } else c.lookY = 0;
    if ($('pb-follow')) {
      $('pb-follow').textContent = w ? 'Остановиться' : 'За жителем';
      $('pb-next').hidden = !w;
    }
  },

  // каждый кадр: камера идёт за жителем, сзади-сбоку
  update(realDt) {
    if (!this.on || !this.follow) return;
    const w = this.follow, c = Engine.cam;
    if (!Walkers.list.includes(w)) { this.setFollow(this.pickWalker()); return; }
    const k = 1 - Math.pow(0.002, realDt);
    c.tx = c.x = c.x + (w.wx - c.x) * k;
    c.tz = c.z = c.z + (w.wy - c.z) * k;
    c.lookY = 0.22;
    // камера сзади-сбоку от жителя; если там стена дома — заходим с другой стороны
    const base = w.yaw + Math.PI - 0.5, cp = Math.cos(c.pitch || 0.3) * c.dist;
    const clear = a => {
      for (const k of [0.45, 1]) if (buildingAtPoint(w.wx + Math.sin(a) * cp * k, w.wy + Math.cos(a) * cp * k)) return false;
      return true;
    };
    let want = base;
    for (const da of [0, 0.7, -0.7, 1.4, -1.4, 2.2, -2.2, Math.PI]) if (clear(base + da)) { want = base + da; break; }
    let d = want - c.yawTarget;
    d = Math.atan2(Math.sin(d), Math.cos(d));
    c.yawTarget += d * Math.min(1, realDt * 1.5);
  },

  // Снимок: кадр рисуется заново и сразу сохраняется картинкой
  snap() {
    Engine.render();
    const cv = Engine.renderer.domElement;
    const d = new Date(), pad = n => String(n).padStart(2, '0');
    const name = `CivCity — ${state.cityName} ${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}-${pad(d.getMinutes())}-${pad(d.getSeconds())}.png`;
    // картинка читается сразу после отрисовки (позже буфер кадра уже очищен)
    const url = cv.toDataURL('image/png');
    const bin = atob(url.split(',')[1]), buf = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) buf[i] = bin.charCodeAt(i);
    const a = document.createElement('a');
    a.href = URL.createObjectURL(new Blob([buf], { type: 'image/png' }));
    a.download = name;
    document.body.append(a);
    a.click();
    a.remove();
    setTimeout(() => URL.revokeObjectURL(a.href), 5000);
    this.lastSize = buf.length;
    const f = $('photo-flash');
    f.classList.remove('go');
    void f.offsetWidth;
    f.classList.add('go');
    Sound.click();
  },
};
