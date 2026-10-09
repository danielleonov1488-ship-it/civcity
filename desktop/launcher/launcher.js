'use strict';
/* Лаунчер: вход и регистрация, новости и ссылки с сервера, настройки, ход обновления и кнопка «Играть».
   Всё, что касается сети и файлов, делает сама программа (main.js) — здесь только окно; связь — window.civ. */
const $ = id => document.getElementById(id);
const esc = s => String(s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);

const L = {
  email: null,
  update: { done: false },
  mode: 'login',

  async init() {
    $('tb-min').onclick = () => civ.win('min');
    $('tb-close').onclick = () => civ.win('close');
    const info = await civ.info();
    this.email = info.email;
    $('ver').textContent = `Программа ${info.version}${info.build ? ` · игра ${info.build}` : ''}`;
    $('quality').value = info.prefs.quality || 'auto';
    $('fullscreen').checked = !!info.prefs.fullscreen;
    $('autostart').checked = !!info.prefs.autostart;
    $('quality').onchange = () => civ.setPref('quality', $('quality').value);
    $('fullscreen').onchange = () => civ.setPref('fullscreen', $('fullscreen').checked);
    $('autostart').onchange = () => civ.setPref('autostart', $('autostart').checked);
    $('play').onclick = () => { $('play').disabled = true; $('play').textContent = 'Запускаю…'; civ.play(); };
    $('shell-dl').onclick = () => civ.downloadShell();
    civ.onUpdate(s => this.onUpdate(s));
    this.drawAccount();
    this.loadContent();
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
    if (this.email) {
      box.innerHTML = `<div class="signed"><h3>Аккаунт</h3><span>Вы вошли как <b>${esc(this.email)}</b></span>
        <span><button type="button" class="linkish" id="a-out">Выйти</button></span></div>`;
      $('a-out').onclick = async () => { await civ.logout(); this.email = null; this.drawAccount(); this.refreshPlay(); };
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
        ${reg ? '' : ' <button type="button" class="linkish" id="a-forgot">Забыли пароль?</button>'}
      </form>`;
    box.querySelectorAll('[data-m]').forEach(b => b.onclick = () => { this.mode = b.dataset.m; this.drawAccount(); });
    const fg = $('a-forgot');
    if (fg) fg.onclick = () => { this.mode = 'forgot'; this.drawAccount(); };
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

  /* ---------- Обновление и «Играть» ---------- */

  onUpdate(s) {
    this.update = s;
    $('upd-text').textContent = s.text || '';
    const bar = $('upd-bar');
    bar.classList.toggle('wait', s.p === null || s.p === undefined);
    $('upd-fill').style.width = s.p == null ? '' : Math.round(s.p * 100) + '%';
    $('shell-note').hidden = !s.shell;
    if (s.build) $('ver').textContent = $('ver').textContent.replace(/ · игра \d+|$/, ` · игра ${s.build}`);
    this.refreshPlay();
  },

  refreshPlay() {
    const b = $('play');
    if (b.textContent === 'Запускаю…') return;
    const ready = this.update.done;
    b.disabled = !ready || !this.email;
    b.textContent = !this.email ? 'Войдите, чтобы играть' : !ready ? 'Обновляю…' : 'Играть';
  },
};

L.init();
