'use strict';
/* Лаунчер: вход и регистрация, новости и ссылки с сервера, настройки, ход загрузки игры и кнопка «Играть».
   Всё, что касается сети, файлов и запуска игры, делает сама программа (main.js) — здесь только окно; связь — window.civ. */
const $ = id => document.getElementById(id);
const esc = s => String(s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);

const L = {
  email: null,
  version: '',
  update: { busy: true },
  mode: 'login',
  note: null,          // сообщение под кнопкой входа (например, «вход устарел»)

  async init() {
    $('tb-min').onclick = () => civ.win('min');
    $('tb-close').onclick = () => civ.win('close');
    const info = await civ.info();
    this.email = info.email;
    this.version = info.version;
    this.showVersion(info.game);
    this.showPrefs(info.prefs);
    $('quality').onchange = async () => this.showPrefs(await civ.setPref('quality', $('quality').value));
    $('fullscreen').onchange = async () => this.showPrefs(await civ.setPref('fullscreen', $('fullscreen').checked));
    $('autostart').onchange = async () => this.showPrefs(await civ.setPref('autostart', $('autostart').checked));
    $('verify').onclick = () => civ.verify();
    $('saves').onclick = () => civ.openSaves();
    $('play').onclick = () => this.play();
    $('shell-dl').onclick = () => civ.downloadShell();
    civ.onUpdate(s => this.onUpdate(s));
    this.drawAccount();
    this.loadContent();
  },

  showPrefs(p) {
    if (!p) return;
    $('quality').value = p.quality || 'high';
    $('fullscreen').checked = !!p.fullscreen;
    $('autostart').checked = !!p.autostart;
  },

  showVersion(g) {
    $('ver').textContent = `Программа ${this.version}` + (g ? ` · игра ${g.version}${g.build ? ` (сборка ${g.build})` : ''}` : '');
  },

  async loadContent() {
    const c = await civ.content();
    const news = c && c.news || [];
    $('news').innerHTML = news.length ? news.map((n, i) => `
      <li data-i="${i}"${i === 0 ? ' class="open"' : ''}>
        <div class="n-head"><span class="n-date">${esc(n.date || '')}</span><span class="n-title">${esc(n.title || '')}</span></div>
        <p class="n-text">${esc(n.text || '')}</p>
      </li>`).join('') : '<li class="muted">Новостей пока нет — или нет связи с сервером.</li>';
    $('news').querySelectorAll('li[data-i]').forEach(li => li.onclick = () => li.classList.toggle('open'));
    const links = (c && c.links || []).filter(l => l && l.url && l.title);
    $('links').innerHTML = links.map((l, i) => `<button type="button" data-l="${i}">${esc(l.title)}</button>`).join('');
    $('links').querySelectorAll('button').forEach(b => b.onclick = () => civ.open(links[+b.dataset.l].url));
  },

  /* ---------- Вход ---------- */

  drawAccount(msg, kind) {
    const box = $('acct');
    // пока заполняют регистрацию, настройки спрятаны: иначе форма с согласием не помещается в окно
    document.querySelector('.settings').hidden = !this.email && this.mode === 'reg';
    if (this.email) {
      box.innerHTML = `<div class="signed"><h3>Аккаунт</h3><span>Вы вошли как <b>${esc(this.email)}</b></span>
        <span class="muted small">Город хранится в облаке — играйте с любого компьютера.</span>
        <span><button type="button" class="linkish" id="a-out">Выйти</button></span></div>`;
      $('a-out').onclick = async () => { await civ.logout(); this.email = null; this.drawAccount(); };
      this.refreshPlay();
      return;
    }
    if (this.mode === 'forgot') {
      box.innerHTML = `<h3>Новый пароль</h3>
        <p class="msg">Пришлём на почту ссылку, по ней можно задать новый пароль.</p>
        <form id="a-form"><label class="field">Почта<input id="a-email" type="email" required autocomplete="email"></label>
        ${msg ? `<p class="msg ${kind || 'bad'}">${esc(msg)}</p>` : ''}
        <button type="submit" class="btn" id="a-go">Прислать ссылку</button> <button type="button" class="linkish" id="a-back">Назад</button></form>`;
      $('a-back').onclick = () => { this.mode = 'login'; this.drawAccount(); };
      $('a-form').onsubmit = async e => {
        e.preventDefault();
        const r = await civ.forgot($('a-email').value);
        this.drawAccount(r.error || 'Если такая почта есть в игре, письмо уже летит. Проверьте и папку «Спам».', r.error ? 'bad' : 'good');
      };
      this.refreshPlay();
      return;
    }
    const reg = this.mode === 'reg';
    box.innerHTML = `
      <div class="tabs"><button type="button" data-m="login" class="${reg ? '' : 'on'}">Вход</button><button type="button" data-m="reg" class="${reg ? 'on' : ''}">Регистрация</button></div>
      <form id="a-form">
        <label class="field">Почта<input id="a-email" type="email" required autocomplete="email"></label>
        <label class="field">Пароль${reg ? ' (не короче 6 знаков)' : ''}<input id="a-pass" type="password" required minlength="6" autocomplete="${reg ? 'new-password' : 'current-password'}"></label>
        ${msg ? `<p class="msg ${kind || 'bad'}">${esc(msg)}</p>` : ''}
        <button type="submit" class="btn" id="a-go">${reg ? 'Создать аккаунт' : 'Войти'}</button>
        ${reg ? '<p class="consent">Нажимая «Создать аккаунт», вы соглашаетесь на обработку своих данных согласно <button type="button" class="linkish" id="a-privacy">политике конфиденциальности</button>.</p>'
        : ' <button type="button" class="linkish" id="a-forgot">Забыли пароль?</button>'}
      </form>`;
    box.querySelectorAll('[data-m]').forEach(b => b.onclick = () => { this.mode = b.dataset.m; this.drawAccount(); });
    const fg = $('a-forgot');
    if (fg) fg.onclick = () => { this.mode = 'forgot'; this.drawAccount(); };
    const pv = $('a-privacy');
    if (pv) pv.onclick = () => civ.open('https://civcity.ru/privacy/');
    $('a-form').onsubmit = async e => {
      e.preventDefault();
      $('a-go').disabled = true;
      const r = await civ.login(reg ? 'register' : 'login', $('a-email').value, $('a-pass').value);
      if (r.error) { this.drawAccount(r.error); return; }
      this.email = r.email;
      this.drawAccount();
    };
    this.refreshPlay();
  },

  /* ---------- Загрузка игры и «Играть» ---------- */

  async play() {
    const r = await civ.play();
    if (r && r.relogin) { this.email = null; this.mode = 'login'; this.drawAccount(r.relogin); }
    else if (r && r.error) { $('upd-text').textContent = r.error; }
  },

  onUpdate(s) {
    this.update = s;
    $('upd-text').textContent = s.text || '';
    $('upd-sub').textContent = s.sub || '';
    const bar = $('upd-bar');
    bar.classList.toggle('wait', s.p === null || s.p === undefined);
    $('upd-fill').style.width = s.p == null ? '' : Math.round(s.p * 100) + '%';
    $('shell-note').hidden = !s.shell;
    $('verify').disabled = !!(s.busy || s.running || !s.ready);
    if (s.game !== undefined) this.showVersion(s.game);
    this.refreshPlay();
  },

  refreshPlay() {
    const b = $('play'), s = this.update;
    let text = 'Играть', on = true;
    if (!this.email) { text = 'Войдите, чтобы играть'; on = false; }
    else if (s.running) { text = 'Игра запущена'; on = false; }
    else if (s.starting) { text = 'Запускаю…'; on = false; }
    else if (s.busy) { text = s.ready ? 'Обновляю…' : 'Скачиваю…'; on = false; }
    else if (!s.ready) { text = s.shell ? 'Нужна новая версия' : 'Скачать ещё раз'; on = !s.shell; }
    b.textContent = text;
    b.disabled = !on;
    b.classList.toggle('small-text', text.length > 12);
  },
};

L.init();
