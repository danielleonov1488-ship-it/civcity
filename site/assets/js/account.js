/* Страница аккаунта CivCity: новый пароль по ссылке из письма, «Забыли пароль?», город в облаке.
   Сервер — server/index.js (тот же адрес, /api/…):
     POST /api/forgot {email}            → письмо со ссылкой https://civcity.ru/#reset=<токен> (главная перекидывает сюда)
     POST /api/reset  {token, password}  → {token, email}: пароль сменён, все прежние входы сброшены
     POST /api/login  {email, password}  → {token, email}
     GET  /api/me?game=rome2, GET /api/saves?game=rome2, POST /api/logout — с заголовком Authorization: Bearer <токен>
   Токен входа хранится только до закрытия вкладки (sessionStorage). */
(function () {
  'use strict';

  var $ = function (s, root) { return (root || document).querySelector(s); };
  var $$ = function (s, root) { return Array.prototype.slice.call((root || document).querySelectorAll(s)); };
  var GAME = 'rome2';
  var LEVELS = ['Стоянка', 'Хутор', 'Деревня', 'Посёлок', 'Городок', 'Город', 'Большой город', 'Вечный город'];
  var SESSION_KEY = 'civcity.session';
  var RESET_KEY = 'civcity.reset';

  var store = {
    get: function (k) { try { return sessionStorage.getItem(k); } catch (e) { return null; } },
    set: function (k, v) { try { sessionStorage.setItem(k, v); } catch (e) { /* приватный режим — живём без памяти */ } },
    del: function (k) { try { sessionStorage.removeItem(k); } catch (e) { /* то же */ } },
  };

  function api(method, path, body, token) {
    var headers = {};
    if (body) headers['Content-Type'] = 'application/json';
    if (token) headers.Authorization = 'Bearer ' + token;
    return fetch('/api' + path, { method: method, headers: headers, body: body ? JSON.stringify(body) : undefined, cache: 'no-store', credentials: 'omit' })
      .catch(function () { throw Object.assign(new Error('Нет связи с сервером — проверьте интернет и попробуйте ещё раз'), { status: 0 }); })
      .then(function (r) {
        return r.text().then(function (t) {
          var data = {};
          try { data = t ? JSON.parse(t) : {}; } catch (e) { data = {}; }
          if (!r.ok) {
            var msg = data.error || (r.status >= 500 ? 'Сервер сейчас недоступен — попробуйте чуть позже' : 'Что-то пошло не так (' + r.status + ')');
            throw Object.assign(new Error(msg), { status: r.status });
          }
          return data;
        });
      });
  }

  function say(form, text, kind) {
    var m = $('[data-msg]', form);
    if (!m) return;
    m.textContent = text || '';
    m.className = 'msg ' + (kind || 'bad');
    m.hidden = !text;
  }
  function busy(form, on, label) {
    var b = $('button[type="submit"]', form);
    if (!b) return;
    if (on) { b.dataset.label = b.textContent; b.textContent = label || 'Минутку…'; }
    else if (b.dataset.label) b.textContent = b.dataset.label;
    b.disabled = on;
  }
  var EMAIL_RE = /^[^\s@]{1,64}@[^\s@]{1,190}\.[^\s@]{2,20}$/;
  function cleanEmail(v) { return String(v || '').trim().toLowerCase(); }

  // показать/скрыть пароль
  $$('[data-eye]').forEach(function (b) {
    b.addEventListener('click', function (e) {
      e.preventDefault();
      var input = b.parentNode.querySelector('input');
      var show = input.type === 'password';
      input.type = show ? 'text' : 'password';
      b.textContent = show ? 'Скрыть' : 'Показать';
      b.setAttribute('aria-label', show ? 'Скрыть пароль' : 'Показать пароль');
      input.focus();
    });
  });

  /* ---------- новый пароль по ссылке из письма ---------- */

  var resetPanel = $('#reset');
  var panels = $('[data-panels]');
  var token = null;
  var m = /^#reset=([A-Za-z0-9_-]{16,200})$/.exec(location.hash);
  if (m) {
    token = m[1];
    store.set(RESET_KEY, token);
    // убираем токен из адресной строки и истории браузера — им нельзя случайно поделиться
    history.replaceState(null, '', location.pathname + location.search + '#new-password');
  } else if (location.hash === '#new-password') {
    token = store.get(RESET_KEY);
  }
  if (token) {
    resetPanel.hidden = false;
    panels.hidden = true;
    var pw = $('[name="password"]', resetPanel);
    setTimeout(function () { pw.focus(); }, 50);
  } else if (location.hash === '#new-password' || /^#reset/.test(location.hash)) {
    showForgot('Ссылка из письма не сработала — запросите новую.');
  }

  function showForgot(text) {
    panels.hidden = false;
    var f = $('[data-form="forgot"]');
    if (text) say(f, text, 'bad');
    $('#forgot').scrollIntoView({ block: 'center' });
    $('[name="email"]', f).focus();
  }

  $('[data-form="reset"]').addEventListener('submit', function (e) {
    e.preventDefault();
    var form = e.currentTarget;
    var p1 = form.password.value, p2 = form.password2.value;
    if (p1.length < 6) { say(form, 'Пароль — не короче 6 знаков'); form.password.focus(); return; }
    if (p1.length > 200) { say(form, 'Слишком длинный пароль'); form.password.focus(); return; }
    if (p1 !== p2) { say(form, 'Пароли не совпадают — введите ещё раз'); form.password2.focus(); return; }
    say(form, '');
    busy(form, true, 'Сохраняю…');
    api('POST', '/reset', { token: token, password: p1 })
      .then(function (r) {
        store.del(RESET_KEY);
        token = null;
        history.replaceState(null, '', location.pathname + location.search);
        form.hidden = true;
        $('[data-done-email]').textContent = r.email || '';
        $('[data-done]', resetPanel).hidden = false;
        // сервер сразу открыл вход — покажем город из облака
        if (r.token) { saveSession(r.token, r.email); $('#forgot').hidden = true; panels.hidden = false; loadCity(); }
      })
      .catch(function (err) {
        busy(form, false);
        if (err.status === 400 && /ссылк/i.test(err.message)) {
          store.del(RESET_KEY);
          history.replaceState(null, '', location.pathname + location.search);
          resetPanel.hidden = true;
          showForgot(err.message);
        } else {
          say(form, err.message);
        }
      });
  });

  /* ---------- «Забыли пароль?» ---------- */

  $('[data-form="forgot"]').addEventListener('submit', function (e) {
    e.preventDefault();
    var form = e.currentTarget;
    var email = cleanEmail(form.email.value);
    if (!EMAIL_RE.test(email)) { say(form, 'Проверьте адрес почты'); form.email.focus(); return; }
    say(form, '');
    busy(form, true, 'Отправляю…');
    api('POST', '/forgot', { email: email })
      .then(function () {
        say(form, 'Готово. Если почта ' + email + ' зарегистрирована в CivCity, на неё уже идёт письмо со ссылкой. Нет письма за пару минут — загляните в «Спам».', 'good');
        var b = $('button[type="submit"]', form), left = 60;
        b.disabled = true;
        var t = setInterval(function () {
          left -= 1;
          b.textContent = 'Ещё раз — через ' + left + ' с';
          if (left <= 0) { clearInterval(t); b.disabled = false; b.textContent = b.dataset.label || 'Прислать ссылку'; }
        }, 1000);
      })
      .catch(function (err) { busy(form, false); say(form, err.message, err.status === 429 ? 'info' : 'bad'); });
  });

  /* ---------- город в облаке ---------- */

  var signedOut = $('[data-signed-out]');
  var signedIn = $('[data-signed-in]');
  var session = null;
  try { session = JSON.parse(store.get(SESSION_KEY) || 'null'); } catch (e) { session = null; }

  function saveSession(t, email) { session = { token: t, email: email }; store.set(SESSION_KEY, JSON.stringify(session)); }
  function dropSession() { session = null; store.del(SESSION_KEY); signedIn.hidden = true; signedOut.hidden = false; }

  function when(ms) {
    var d = new Date(Number(ms));
    if (isNaN(d)) return '';
    var opts = { day: 'numeric', month: 'long', hour: '2-digit', minute: '2-digit' };
    if (d.getFullYear() !== new Date().getFullYear()) opts.year = 'numeric';
    try { return d.toLocaleString('ru-RU', opts); } catch (e) { return d.toISOString().slice(0, 16).replace('T', ' '); }
  }
  function num(n) { return Number(n || 0).toLocaleString('ru-RU'); }
  function el(tag, cls, text) { var x = document.createElement(tag); if (cls) x.className = cls; if (text !== undefined) x.textContent = text; return x; }
  function stat(dl, name, value) {
    var d = el('div'); d.appendChild(el('dt', '', name)); d.appendChild(el('dd', '', value)); dl.appendChild(d);
  }

  function renderCity(me) {
    var box = $('[data-city]');
    box.textContent = '';
    var s = me.save;
    if (!s) {
      box.appendChild(el('p', '', 'В облаке пока нет города новой игры. Он появится, как только вы начнёте играть в CivCity 1.0.'));
      return;
    }
    var meta = s.meta || {};
    if (s.destroyed) {
      box.appendChild(el('h3', '', meta.city || 'Город уничтожен'));
      box.appendChild(el('p', '', 'Последняя запись — «город уничтожен» (' + when(s.created) + '). Новый город появится здесь после первого сохранения.'));
      return;
    }
    box.appendChild(el('h3', '', meta.city || 'Ваш город'));
    var dl = el('dl', 'stats');
    if (meta.pop !== undefined) stat(dl, 'Жители', num(meta.pop));
    if (meta.level !== undefined && LEVELS[meta.level]) stat(dl, 'Звание', LEVELS[meta.level]);
    if (meta.day !== undefined) stat(dl, 'День', num(meta.day));
    if (meta.n !== undefined) stat(dl, 'Постройки', num(meta.n));
    if (meta.money !== undefined) stat(dl, 'Денарии', num(meta.money));
    if (dl.children.length) box.appendChild(dl);
    box.appendChild(el('p', 'muted small saved-at', 'Сохранён ' + when(s.created)));
  }

  function renderHistory(list, lastId) {
    var ul = $('[data-history]');
    ul.textContent = '';
    var rest = (list || []).filter(function (s) { return s.id !== lastId; });
    $('[data-history-box]').hidden = !rest.length;
    rest.forEach(function (s) {
      var li = el('li');
      li.appendChild(el('span', '', when(s.created)));
      var meta = s.meta || {};
      li.appendChild(el('b', '', s.destroyed ? 'город уничтожен' : (meta.pop !== undefined ? num(meta.pop) + ' жит.' : (meta.city || 'город'))));
      ul.appendChild(li);
    });
  }

  function loadCity() {
    if (!session) return;
    signedOut.hidden = true;
    signedIn.hidden = false;
    $('[data-email]').textContent = session.email || '';
    $('[data-city]').textContent = 'Загружаю…';
    var t = session.token;
    api('GET', '/me?game=' + GAME, null, t)
      .then(function (me) {
        if (me.email) { session.email = me.email; $('[data-email]').textContent = me.email; }
        renderCity(me);
        return api('GET', '/saves?game=' + GAME, null, t).then(function (r) { renderHistory(r.saves, me.save && me.save.id); });
      })
      .then(function () { return api('GET', '/me', null, t); })
      .then(function (old) {
        var p = $('[data-old]');
        if (old && old.save && !old.save.destroyed) {
          p.textContent = 'Город из старой браузерной версии тоже хранится на сервере (последнее сохранение — ' + when(old.save.created) + ').';
          p.hidden = false;
        }
      })
      .catch(function (err) {
        if (err.status === 401) {
          dropSession();
          say($('[data-form="login"]'), err.message || 'Войдите снова');
        } else {
          $('[data-city]').textContent = err.message;
        }
      });
  }

  $('[data-form="login"]').addEventListener('submit', function (e) {
    e.preventDefault();
    var form = e.currentTarget;
    var email = cleanEmail(form.email.value);
    if (!EMAIL_RE.test(email)) { say(form, 'Проверьте адрес почты'); form.email.focus(); return; }
    if (!form.password.value) { say(form, 'Введите пароль'); form.password.focus(); return; }
    say(form, '');
    busy(form, true, 'Вхожу…');
    api('POST', '/login', { email: email, password: form.password.value })
      .then(function (r) {
        busy(form, false);
        form.password.value = '';
        saveSession(r.token, r.email || email);
        loadCity();
      })
      .catch(function (err) { busy(form, false); say(form, err.message); });
  });

  $('[data-logout]').addEventListener('click', function () {
    var t = session && session.token;
    dropSession();
    if (t) api('POST', '/logout', null, t).catch(function () { /* вход уже забыт на этой странице */ });
  });

  if (session && session.token) loadCity();
})();
