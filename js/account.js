'use strict';
/* Аккаунт: вход по почте и паролю, город в облаке, восстановление пароля по ссылке из письма.
   Город по-прежнему сохраняется в браузере каждые 15 секунд, а при входе ещё и на сервер — раз в минуту,
   если что-то изменилось, и при сворачивании. Если город менялся на другом устройстве, игрок выбирает,
   какой оставить. Тестовый город (#test) в облако не попадает. */

const ACCOUNT_KEY = 'civcity.account';

const Account = {
  // адрес сервера: на самом сайте — он же; в программе для ПК и на запасном сайте — civcity.ru
  api: (() => {
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

  get on() { return !!this.token && !TEST_MODE; },

  init() {
    if (TEST_MODE) return;
    try { Object.assign(this, JSON.parse(localStorage.getItem(ACCOUNT_KEY) || '{}')); } catch (e) { /* пусто */ }
    const m = /^#reset=([\w-]+)$/.exec(location.hash);
    if (m) {
      history.replaceState(null, '', location.pathname + location.search);
      this.showReset(m[1]);
    } else if (this.token) this.syncOnStart();
    else if (!this.skipped()) this.showLogin();
    setInterval(() => this.upload(false), 20000);
    document.addEventListener('visibilitychange', () => { if (document.hidden) this.upload(true); });
  },

  remember() {
    try { localStorage.setItem(ACCOUNT_KEY, JSON.stringify({ email: this.email, token: this.token, base: this.base, upAt: this.upAt })); } catch (e) { /* нет хранилища */ }
  },

  skipped() { try { return localStorage.getItem(ACCOUNT_KEY + '.skip') === '1'; } catch (e) { return false; } },

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
    UI.closeModal();
    this.syncOnStart();
  },

  logout() {
    if (this.token) this.call('POST', '/logout').catch(() => {});
    this.token = null;
    this.base = null;
    this.remember();
    UI.toast('Вы вышли. Город остался на этом компьютере.', 'good');
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
      return;
    }
    this.email = me.email;
    this.remember();
    if (!me.save) { this.upload(true); return; }
    if (this.base === me.save.id) return;
    if (this.base === null && this.freshLocal()) { this.loadCloud(); return; }
    this.askConflict(me.save);
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
      this.lastData = data;
      this.upAt = Date.now();
      this.remember();
    } catch (e) {
      if (e.status === 409 && e.data && e.data.latest) this.askConflict(e.data.latest);
      else if (e.status === 401) { this.token = null; this.remember(); }
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
    UI.showModal(`
      <p class="eyebrow">CivCity</p>
      <h2>${mode === 'login' ? 'Вход' : 'Регистрация'}</h2>
      <p class="sub">${note || 'Город хранится на сервере: не потеряется, и играть можно с любого компьютера — на сайте и в программе.'}</p>
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
          <button type="button" class="btn ghost" id="acc-skip">Играть без входа</button>
        </div>
      </form>
      ${mode === 'login' ? '<p class="sub"><button type="button" class="linkish" id="acc-forgot">Забыли пароль?</button></p>' : '<p class="sub">Подтверждать почту не нужно — она понадобится, только если забудете пароль.</p>'}`);
    document.querySelectorAll('[data-amode]').forEach(b => b.onclick = () => this.showLogin(note, b.dataset.amode));
    $('acc-skip').onclick = () => { try { localStorage.setItem(ACCOUNT_KEY + '.skip', '1'); } catch (e) { /* нет хранилища */ } UI.closeModal(); };
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
    UI.showModal(`
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
    UI.showModal(`
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
    if (TEST_MODE) return '';
    if (!this.on) return `<div class="note acc-box"><b>Город хранится только на этом компьютере.</b> Войдите, чтобы он хранился и на сервере.
      <div class="actions"><button type="button" class="btn small" id="acc-open">Войти или зарегистрироваться</button></div></div>`;
    const when = this.upAt ? new Date(this.upAt).toLocaleTimeString('ru-RU', { hour: '2-digit', minute: '2-digit' }) : null;
    return `<div class="note good acc-box">Вы вошли как <b>${escapeHtml(this.email || '')}</b>. ${when ? `В облаке сохранено в ${when}.` : 'Город сохраняется в облаке раз в минуту.'}
      <div class="actions"><button type="button" class="btn small" id="acc-now">Сохранить в облако сейчас</button><button type="button" class="btn small ghost" id="acc-out">Выйти</button></div></div>`;
  },

  bindMenu() {
    const o = $('acc-open');
    if (o) o.onclick = () => this.showLogin();
    const n = $('acc-now');
    if (n) n.onclick = async () => { this.lastData = null; await this.upload(true); UI.toast(this.upAt && Date.now() - this.upAt < 5000 ? 'Город сохранён в облаке' : 'Не получилось — проверьте интернет', this.upAt && Date.now() - this.upAt < 5000 ? 'good' : 'warn'); UI.closeModal(); };
    const out = $('acc-out');
    if (out) out.onclick = () => { this.logout(); UI.closeModal(); };
  },
};
