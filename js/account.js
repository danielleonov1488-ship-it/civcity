'use strict';
/* Аккаунт: вход обязателен — без него видно только окно входа и регистрации. Город у игрока один и живёт
   на сервере; на компьютере лежит его копия (сохраняется каждые 15 секунд, в облако — раз в минуту, если
   что-то изменилось, и при сворачивании). Пропал интернет после входа — играем дальше, облако догонит.
   У копии на компьютере есть хозяин (owner): если войдёт другой человек, он получит свой город, а не чужой.
   В программе для ПК вход общий с лаунчером (window.civDesktop). Тестовый город (#test) — без входа и облака. */

const ACCOUNT_KEY = 'civcity.account';

const Account = {
  // адрес сервера: на самом сайте — он же; в программе для ПК и на запасном сайте — civcity.ru
  api: (() => {
    if (typeof window.civDesktop === 'object' && window.civDesktop) return civDesktop.api();
    try { const o = localStorage.getItem('civcity.api'); if (o) return o; } catch (e) { /* нет хранилища */ }
    const h = location.hostname;
    if (/^https?:$/.test(location.protocol) && (/(^|\.)civcity\.ru$/.test(h) || /^\d+\.\d+\.\d+\.\d+$/.test(h))) return location.origin + '/api';
    return 'https://civcity.ru/api';
  })(),
  email: null,
  token: null,
  base: null,        // номер облачного сохранения, от которого идёт этот город
  lastData: null,
  lastUp: 0,
  upAt: 0,           // когда город последний раз ушёл в облако
  busy: false,
  conflict: false,
  owner: null,       // чей город лежит на этом компьютере (почта)

  get on() { return !!this.token && !TEST_MODE; },
  // нужен вход: окно входа обязательное и не закрывается
  get gated() { return !TEST_MODE && !this.token; },
  get desktop() { return typeof window.civDesktop === 'object' && !!window.civDesktop; },

  init() {
    if (TEST_MODE) return;
    try { Object.assign(this, JSON.parse(localStorage.getItem(ACCOUNT_KEY) || '{}')); } catch (e) { /* пусто */ }
    // в программе для ПК вход хранит программа (общий с лаунчером)
    if (this.desktop) {
      const s = civDesktop.session();
      this.token = s && s.token || null;
      if (s && s.email) this.email = s.email;
    }
    const m = /^#reset=([\w-]+)$/.exec(location.hash);
    if (m) {
      history.replaceState(null, '', location.pathname + location.search);
      this.showReset(m[1]);
    } else if (this.token) this.syncOnStart();
    else this.showLogin();
    setInterval(() => this.upload(false), 20000);
    document.addEventListener('visibilitychange', () => { if (document.hidden) this.upload(true); });
  },

  remember() {
    try { localStorage.setItem(ACCOUNT_KEY, JSON.stringify({ email: this.email, token: this.desktop ? null : this.token, base: this.base, upAt: this.upAt, owner: this.owner })); } catch (e) { /* нет хранилища */ }
    if (this.desktop) civDesktop.setSession(this.token ? { email: this.email, token: this.token } : null);
  },

  // окна входа: пока игрок не вошёл, они обязательные
  modal(html) { UI.showModal(html, null, this.gated); },

  async call(method, path, body) {
    let r;
    try {
      r = await fetch(this.api + path, {
        method,
        headers: Object.assign(body ? { 'Content-Type': 'application/json' } : {}, this.token ? { Authorization: 'Bearer ' + this.token } : {}),
        body: body ? JSON.stringify(body) : undefined,
      });
    } catch (e) { throw Object.assign(new Error('Нет связи с сервером. Проверьте интернет и попробуйте ещё раз.'), { status: 0 }); }
    let data = {};
    try { data = await r.json(); } catch (e) { /* не JSON */ }
    if (!r.ok) throw Object.assign(new Error(data.error || 'Сервер не ответил, попробуйте позже'), { status: r.status, data });
    return data;
  },

  signedIn(res) {
    // тот же игрок снова вошёл — город на этом компьютере уже связан с его облаком
    if (this.email !== res.email) this.base = null;
    this.email = res.email;
    this.token = res.token;
    this.remember();
    UI.closeModal(true);
    this.syncOnStart();
  },

  logout() {
    if (this.token) this.call('POST', '/logout').catch(() => {});
    this.token = null;
    this.remember();
    this.showLogin('Вы вышли. Войдите, чтобы продолжить.');
  },

  // Город заменили (уничтожили и начали заново) — новый сразу уходит в облако
  cityReplaced() {
    this.lastData = null;
    if (this.on) { this.owner = this.email; this.upload(true, true); }
  },

  // Мета для списка сохранений: название, жители, день
  meta() { return { city: state.cityName, pop: state.stats.pop || 0, day: state.day }; },

  // Город на этом компьютере только что начат — его не жалко заменить облачным
  freshLocal() { return (state.stats.pop || 0) === 0 && state.day < 5; },

  /* ---------- Сверка с облаком при входе и запуске ---------- */

  async syncOnStart() {
    let me;
    try { me = await this.call('GET', '/me'); } catch (e) {
      if (e.status === 401) { this.token = null; this.remember(); this.showLogin('Вход устарел — войдите снова.'); }
      return;      // нет связи — играем дальше, облако догонит
    }
    this.email = me.email;
    const foreign = this.owner && this.owner !== me.email;    // город на компьютере — чужой
    if (!me.save) {
      // у этого игрока города ещё нет: свой (или ничей) город с компьютера переезжает в аккаунт, чужой — нет
      if (foreign) { this.startFresh(); return; }
      this.owner = me.email;
      this.remember();
      this.upload(true);
      return;
    }
    if (foreign) { this.loadCloud(); return; }
    this.remember();
    if (this.base === me.save.id) { this.owner = me.email; this.remember(); return; }
    if (this.base === null && this.freshLocal()) { this.loadCloud(); return; }
    this.askConflict(me.save);
  },

  // У вошедшего игрока ещё нет города, а на компьютере — чужой: начинаем ему чистое поле
  startFresh() {
    this.owner = this.email;
    this.base = null;
    this.remember();
    Game.newGame();
    saveGame();
    this.upload(true, true);
  },

  askConflict(cloud) {
    if (this.conflict) return;
    this.conflict = true;
    const m = cloud.meta || {};
    const when = new Date(cloud.created).toLocaleString('ru-RU', { day: 'numeric', month: 'long', hour: '2-digit', minute: '2-digit' });
    UI.showModal(`
      <p class="eyebrow">Город в облаке</p>
      <h2>Какой город оставить?</h2>
      <p>В облаке — <b>«${escapeHtml(m.city || 'город')}»</b>, жителей ${fmt(m.pop || 0)}, сохранён ${when}.</p>
      <p>На этом компьютере — <b>«${escapeHtml(state.cityName)}»</b>, жителей ${fmt(state.stats.pop || 0)}.</p>
      <div class="actions">
        <button type="button" class="btn" id="acc-cloud">Взять из облака</button>
        <button type="button" class="btn ghost" id="acc-local">Оставить этот</button>
      </div>
      <p class="sub">Второй город не пропадёт: сервер хранит 10 последних сохранений.</p>`);
    $('acc-cloud').onclick = () => { this.conflict = false; this.loadCloud(); };
    $('acc-local').onclick = () => { this.conflict = false; UI.closeModal(); this.upload(true, true); };
  },

  async loadCloud() {
    try {
      const r = await this.call('GET', '/save');
      if (!r.save) return;
      JSON.parse(r.save.data);
      this.base = r.save.id;
      this.owner = this.email;
      this.lastData = null;
      this.remember();
      this.reloading = true;
      localStorage.setItem(SAVE_KEY, r.save.data);
      location.reload();
    } catch (e) { UI.toast(e.message, 'warn'); }
  },

  /* ---------- Отправка города ---------- */

  async upload(now, force) {
    if (!this.on || this.busy || this.conflict || this.reloading) return;
    if (!now && Date.now() - this.lastUp < 60000) return;
    let data;
    try { data = JSON.stringify(serialize()); } catch (e) { return; }
    if (!force && data === this.lastData) return;
    this.busy = true;
    try {
      const r = await this.call('PUT', '/save', { data, base: this.base, meta: this.meta(), force: !!force });
      this.base = r.id;
      this.owner = this.email;
      this.lastData = data;
      this.upAt = Date.now();
      this.remember();
    } catch (e) {
      if (e.status === 409 && e.data && e.data.latest) this.askConflict(e.data.latest);
      else if (e.status === 401) { this.token = null; this.remember(); this.showLogin('Вход устарел — войдите снова.'); }
    } finally {
      this.lastUp = Date.now();
      this.busy = false;
    }
  },

  // Перед закрытием программы для ПК: сохранить у себя и отправить в облако
  async flush() {
    saveGame();
    if (this.on) { this.lastUp = 0; await this.upload(true); }
    return true;
  },

  /* ---------- Окна ---------- */

  showLogin(note, mode) {
    mode = mode || 'login';
    this.modal(`
      <p class="eyebrow">CivCity</p>
      <h2>${mode === 'login' ? 'Вход' : 'Регистрация'}</h2>
      <p class="sub">${note || 'Ваш город хранится на сервере: не потеряется, и играть можно с любого компьютера — на сайте и в программе для ПК.'}</p>
      <div class="seg wide" role="group">
        <button type="button" data-amode="login" class="${mode === 'login' ? 'on' : ''}">Вход</button>
        <button type="button" data-amode="reg" class="${mode === 'reg' ? 'on' : ''}">Регистрация</button>
      </div>
      <form id="acc-form" class="acc-form" autocomplete="on">
        <label class="field">Почта<input id="acc-email" type="email" autocomplete="email" required value="${escapeHtml(this.email || '')}"></label>
        <label class="field">Пароль${mode === 'reg' ? ' <small>(не короче 6 знаков)</small>' : ''}<input id="acc-pass" type="password" autocomplete="${mode === 'login' ? 'current-password' : 'new-password'}" required minlength="6"></label>
        <p class="note bad" id="acc-err" hidden></p>
        <div class="actions">
          <button type="submit" class="btn" id="acc-go">${mode === 'login' ? 'Войти' : 'Создать аккаунт'}</button>
        </div>
      </form>
      ${mode === 'login' ? '<p class="sub"><button type="button" class="linkish" id="acc-forgot">Забыли пароль?</button></p>' : '<p class="sub">Подтверждать почту не нужно — она понадобится, только если забудете пароль.</p>'}
      ${this.downloadHtml()}`);
    document.querySelectorAll('[data-amode]').forEach(b => b.onclick = () => this.showLogin(note, b.dataset.amode));
    const fg = $('acc-forgot');
    if (fg) fg.onclick = () => this.showForgot($('acc-email').value);
    $('acc-form').onsubmit = async e => {
      e.preventDefault();
      const err = $('acc-err'), go = $('acc-go');
      err.hidden = true;
      go.disabled = true;
      try {
        const res = await this.call('POST', mode === 'login' ? '/login' : '/register', { email: $('acc-email').value, password: $('acc-pass').value });
        this.signedIn(res);
        UI.toast(mode === 'login' ? 'Вы вошли — город сохраняется в облаке' : 'Аккаунт создан — город сохраняется в облаке', 'good');
      } catch (ex) {
        err.textContent = ex.message;
        err.hidden = false;
        go.disabled = false;
      }
    };
    setTimeout(() => { const i = $(this.email ? 'acc-pass' : 'acc-email'); if (i) i.focus(); }, 50);
  },

  showForgot(email) {
    this.modal(`
      <p class="eyebrow">CivCity</p>
      <h2>Забыли пароль?</h2>
      <p class="sub">Пришлём на почту ссылку — по ней можно задать новый пароль. Ссылка действует час.</p>
      <form id="acc-form" class="acc-form">
        <label class="field">Почта<input id="acc-email" type="email" autocomplete="email" required value="${escapeHtml(email || this.email || '')}"></label>
        <p class="note" id="acc-err" hidden></p>
        <div class="actions">
          <button type="submit" class="btn" id="acc-go">Прислать ссылку</button>
          <button type="button" class="btn ghost" id="acc-back">Назад</button>
        </div>
      </form>`);
    $('acc-back').onclick = () => this.showLogin();
    $('acc-form').onsubmit = async e => {
      e.preventDefault();
      const msg = $('acc-err');
      try {
        await this.call('POST', '/forgot', { email: $('acc-email').value });
        msg.className = 'note good';
        msg.textContent = 'Если такая почта есть в игре, письмо уже летит. Проверьте и папку «Спам».';
      } catch (ex) {
        msg.className = 'note bad';
        msg.textContent = ex.message;
      }
      msg.hidden = false;
    };
  },

  showReset(token) {
    this.modal(`
      <p class="eyebrow">CivCity</p>
      <h2>Новый пароль</h2>
      <form id="acc-form" class="acc-form">
        <label class="field">Новый пароль <small>(не короче 6 знаков)</small><input id="acc-pass" type="password" autocomplete="new-password" required minlength="6"></label>
        <p class="note bad" id="acc-err" hidden></p>
        <div class="actions"><button type="submit" class="btn" id="acc-go">Сохранить и войти</button></div>
      </form>`);
    $('acc-form').onsubmit = async e => {
      e.preventDefault();
      const err = $('acc-err');
      try {
        const res = await this.call('POST', '/reset', { token, password: $('acc-pass').value });
        this.signedIn(res);
        UI.toast('Пароль изменён — вы вошли', 'good');
      } catch (ex) { err.textContent = ex.message; err.hidden = false; }
    };
    setTimeout(() => { const i = $('acc-pass'); if (i) i.focus(); }, 50);
  },

  // Ссылка на программу для Windows — на сайте игры (в самой программе не нужна)
  downloadHtml() {
    if (/[?&]desktop\b/.test(location.search) || !/^https?:$/.test(location.protocol)) return '';
    const base = /(^|\.)civcity\.ru$/.test(location.hostname) || /^\d+\.\d+\.\d+\.\d+$/.test(location.hostname) ? '' : 'https://civcity.ru';
    return `<p class="sub">Есть программа для Windows: <a href="${base}/download/CivCity-setup.exe">скачать CivCity для ПК</a> (около 100 МБ).</p>`;
  },

  // Блок для окна настроек
  menuHtml() {
    if (TEST_MODE || !this.on) return '';
    const when = this.upAt ? new Date(this.upAt).toLocaleTimeString('ru-RU', { hour: '2-digit', minute: '2-digit' }) : null;
    return `<div class="note good acc-box">Вы вошли как <b>${escapeHtml(this.email || '')}</b>. ${when ? `В облаке сохранено в ${when}.` : 'Город сохраняется в облаке раз в минуту.'}
      <div class="actions"><button type="button" class="btn small" id="acc-now">Сохранить в облако сейчас</button><button type="button" class="btn small ghost" id="acc-out">Выйти</button></div></div>`;
  },

  bindMenu() {
    const n = $('acc-now');
    if (n) n.onclick = async () => { this.lastData = null; await this.upload(true); UI.toast(this.upAt && Date.now() - this.upAt < 5000 ? 'Город сохранён в облаке' : 'Не получилось — проверьте интернет', this.upAt && Date.now() - this.upAt < 5000 ? 'good' : 'warn'); UI.closeModal(); };
    const out = $('acc-out');
    if (out) out.onclick = () => { UI.closeModal(); this.logout(); };
  },
};
