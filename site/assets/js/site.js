/* Сайт CivCity: шапка, фон-видео, живые сцены, карта Легиона, трейлер, снимки, новости, размер установщика.
   Без библиотек. Всё тяжёлое (видео) грузится только когда нужно. */
(function () {
  'use strict';

  // ссылка из письма «новый пароль» ведёт на https://civcity.ru/#reset=… (так её строит server/index.js) — это страница аккаунта
  if (/^#reset=/.test(location.hash)) {
    location.replace('account/' + location.hash);
    return;
  }

  var $ = function (s, root) { return (root || document).querySelector(s); };
  var $$ = function (s, root) { return Array.prototype.slice.call((root || document).querySelectorAll(s)); };
  var motionOK = !window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  var conn = navigator.connection || {};
  var lowData = !!conn.saveData || /(^|-)2g$/.test(conn.effectiveType || '');
  var canHover = window.matchMedia('(hover: hover) and (pointer: fine)').matches;
  var small = function () { return window.matchMedia('(max-width: 760px)').matches; };
  var probe = document.createElement('video');
  var webmOK = !!(probe.canPlayType && probe.canPlayType('video/webm; codecs="vp9"'));

  function makeVideo(webm, mp4) {
    var v = document.createElement('video');
    v.muted = true; v.defaultMuted = true; v.loop = true; v.playsInline = true;
    v.setAttribute('muted', ''); v.setAttribute('playsinline', ''); v.setAttribute('aria-hidden', 'true'); v.tabIndex = -1;
    v.preload = 'auto';
    v.src = webmOK && webm ? webm : mp4;
    return v;
  }
  function tryPlay(v) {
    var p = v.play();
    if (p && p.catch) p.catch(function () { /* автозапуск запрещён — остаётся картинка */ });
  }

  /* ---------- шапка ---------- */

  var top = $('#top');
  var menuBtn = $('.menu-btn');
  function onScroll() { top.classList.toggle('solid', window.scrollY > 40); }
  window.addEventListener('scroll', onScroll, { passive: true });
  onScroll();
  menuBtn.addEventListener('click', function () {
    var open = !top.classList.contains('open');
    top.classList.toggle('open', open);
    menuBtn.setAttribute('aria-expanded', String(open));
  });
  $$('#nav a').forEach(function (a) {
    a.addEventListener('click', function () { top.classList.remove('open'); menuBtn.setAttribute('aria-expanded', 'false'); });
  });

  /* ---------- фон первого экрана ---------- */

  var hero = $('.hero');
  var heroVideo = $('.hero-media video');
  if (heroVideo && motionOK && !lowData) {
    var startHero = function () {
      var d = heroVideo.dataset;
      heroVideo.src = small() ? (webmOK ? d.webmSmall : d.mp4Small) : (webmOK ? d.webm : d.mp4);
      heroVideo.preload = 'auto';
      heroVideo.addEventListener('playing', function () { heroVideo.classList.add('live'); }, { once: true });
      tryPlay(heroVideo);
      if ('IntersectionObserver' in window) {
        new IntersectionObserver(function (es) {
          es.forEach(function (e) { if (e.isIntersecting) tryPlay(heroVideo); else heroVideo.pause(); });
        }).observe(hero);
      }
    };
    // видео — после того, как загрузилось всё важное (картинка-заставка, шрифты)
    if (document.readyState === 'complete') setTimeout(startHero, 150);
    else window.addEventListener('load', function () { setTimeout(startHero, 150); }, { once: true });
  }

  /* ---------- живые сцены (петли) ---------- */

  var tiles = $$('[data-loops] .loop');
  var hint = $('[data-loops-hint]');
  var autoLoops = motionOK && !lowData;
  if (!autoLoops && hint) hint.textContent = 'Нажмите на сцену, чтобы она ожила.';

  tiles.forEach(function (tile) {
    var name = tile.getAttribute('data-name');
    var video = null;
    var visible = false;
    var paused = false;         // остановлено щелчком
    function ensure() {
      if (video) return video;
      video = makeVideo('media/loops/' + name + '.webm', 'media/loops/' + name + '.mp4');
      video.addEventListener('playing', function () { video.classList.add('live'); tile.classList.add('playing'); });
      video.addEventListener('pause', function () { tile.classList.remove('playing'); });
      tile.insertBefore(video, tile.querySelector('.badge'));
      return video;
    }
    function play() { tryPlay(ensure()); }
    function stop() { if (video) video.pause(); }
    tile.setAttribute('tabindex', '0');
    tile.setAttribute('role', 'button');
    tile.setAttribute('aria-label', (tile.querySelector('figcaption') || tile).textContent.trim() + ' — запустить или остановить сцену');
    function toggle() {
      if (video && !video.paused) { paused = true; stop(); } else { paused = false; play(); }
    }
    tile.addEventListener('click', toggle);
    tile.addEventListener('keydown', function (e) { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); toggle(); } });
    if (canHover) {
      tile.addEventListener('mouseenter', function () { if (motionOK && !paused) play(); });
      tile.addEventListener('mouseleave', function () { if (!autoLoops || !visible) stop(); });
    }
    var wait = 0;
    tile._vis = function (v) {
      visible = v;
      clearTimeout(wait);
      // сцена должна задержаться на экране: при быстрой прокрутке мимо (переход по меню) видео не качаем
      if (v && autoLoops && !paused) wait = setTimeout(function () { if (visible) play(); }, 350);
      else if (!v) stop();
    };
  });
  if ('IntersectionObserver' in window) {
    var io = new IntersectionObserver(function (es) {
      es.forEach(function (e) { e.target._vis(e.isIntersecting); });
    }, { threshold: 0.55 });
    tiles.forEach(function (t) { io.observe(t); });
  }
  document.addEventListener('visibilitychange', function () {
    if (document.hidden) $$('video').forEach(function (v) { if (!v.controls) v.pause(); });
    else {
      if (heroVideo && heroVideo.src && hero.getBoundingClientRect().bottom > 0) tryPlay(heroVideo);
      if (autoLoops) tiles.forEach(function (t) {
        var r = t.getBoundingClientRect();
        if (r.top < innerHeight && r.bottom > 0) t._vis(true);
      });
    }
  });

  /* ---------- Легион: карты провинций ---------- */

  var tabs = $$('[data-provinces] [role="tab"]');
  var mapImg = $('[data-map]');
  var mapBoss = $('[data-map-boss]');
  var mapName = $('[data-map-name]');
  var mapText = $('[data-map-text]');
  function mapSrc(n) { return 'assets/img/legion/map-' + n + '.webp'; }
  function selectTab(btn, focus) {
    tabs.forEach(function (b) { b.setAttribute('aria-selected', String(b === btn)); b.tabIndex = b === btn ? 0 : -1; });
    if (focus) btn.focus();
    var src = mapSrc(btn.dataset.mapN);
    if (mapImg.getAttribute('src') === src) return;
    mapImg.classList.add('fading');
    var img = new Image();
    img.onload = img.onerror = function () {
      mapImg.src = src;
      mapImg.alt = 'Карта провинции «' + btn.dataset.name + '»';
      mapImg.classList.remove('fading');
    };
    img.src = src;
    mapBoss.src = 'assets/img/legion/boss-' + btn.dataset.boss + '.webp';
    mapName.textContent = btn.dataset.name;
    mapText.textContent = btn.dataset.text;
  }
  tabs.forEach(function (b, i) {
    b.tabIndex = i === 0 ? 0 : -1;
    b.addEventListener('click', function () { selectTab(b); });
    b.addEventListener('mouseenter', function () { new Image().src = mapSrc(b.dataset.mapN); }, { once: true });
    b.addEventListener('keydown', function (e) {
      var d = e.key === 'ArrowRight' ? 1 : e.key === 'ArrowLeft' ? -1 : 0;
      if (e.key === 'Home') d = -i; else if (e.key === 'End') d = tabs.length - 1 - i;
      if (!d) return;
      e.preventDefault();
      selectTab(tabs[(i + d + tabs.length) % tabs.length], true);
    });
  });

  /* ---------- трейлер ---------- */

  var player = $('[data-trailer]');
  function playTrailer() {
    if (!player || player.querySelector('video')) return;
    var big = (screen.width || 0) * (window.devicePixelRatio || 1) >= 1500 && !lowData;
    var v = document.createElement('video');
    v.controls = true; v.playsInline = true; v.preload = 'auto';
    v.src = big ? player.dataset.src : player.dataset.srcSmall;
    v.setAttribute('aria-label', 'Трейлер CivCity');
    player.appendChild(v);
    var btn = player.querySelector('.play-btn');
    if (btn) btn.remove();
    tryPlay(v);
    if (heroVideo) heroVideo.pause();
    v.focus();
  }
  if (player) player.querySelector('.play-btn').addEventListener('click', playTrailer);
  $$('[data-play-trailer]').forEach(function (a) {
    a.addEventListener('click', function (e) {
      e.preventDefault();
      $('#trailer').scrollIntoView({ behavior: motionOK ? 'smooth' : 'auto', block: 'center' });
      playTrailer();
    });
  });

  /* ---------- снимки: просмотр на весь экран ---------- */

  var links = $$('[data-gallery] a');
  var lb = $('#lightbox');
  var lbImg = $('[data-lb-img]');
  var lbCap = $('[data-lb-caption]');
  var lbCount = $('[data-lb-count]');
  var cur = 0;
  function preload(i) { var l = links[(i + links.length) % links.length]; if (l) new Image().src = l.getAttribute('href'); }
  function show(i) {
    cur = (i + links.length) % links.length;
    var a = links[cur], alt = a.querySelector('img').alt;
    lbImg.src = a.getAttribute('href');
    lbImg.alt = alt;
    lbCap.textContent = alt;
    lbCount.textContent = (cur + 1) + ' / ' + links.length;
    preload(cur + 1); preload(cur - 1);
  }
  if (lb && typeof lb.showModal === 'function') {
    links.forEach(function (a, i) {
      a.addEventListener('click', function (e) {
        e.preventDefault();
        show(i);
        lb.showModal();
        document.documentElement.style.overflow = 'hidden';
      });
    });
    lb.addEventListener('close', function () { document.documentElement.style.overflow = ''; links[cur].focus(); });
    $('[data-lb-close]').addEventListener('click', function () { lb.close(); });
    $('[data-lb-prev]').addEventListener('click', function () { show(cur - 1); });
    $('[data-lb-next]').addEventListener('click', function () { show(cur + 1); });
    lb.addEventListener('keydown', function (e) {
      if (e.key === 'ArrowRight') show(cur + 1);
      else if (e.key === 'ArrowLeft') show(cur - 1);
    });
    // щелчок мимо снимка — закрыть
    $('[data-lb-stage]').addEventListener('click', function (e) { if (e.target === e.currentTarget) lb.close(); });
    // листание пальцем
    var x0 = null;
    lb.addEventListener('pointerdown', function (e) { if (e.pointerType !== 'mouse') x0 = e.clientX; });
    lb.addEventListener('pointerup', function (e) {
      if (x0 === null) return;
      var dx = e.clientX - x0; x0 = null;
      if (Math.abs(dx) > 50) show(cur + (dx < 0 ? 1 : -1));
    });
  }

  /* ---------- новости из /api/launcher (те же, что в лаунчере) ---------- */

  var newsBox = $('[data-news]');
  var MONTHS = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];
  function ruDate(s) {
    var m = /^(\d{4})-(\d{2})-(\d{2})/.exec(String(s || ''));
    return m ? (+m[3]) + ' ' + MONTHS[+m[2] - 1] + ' ' + m[1] : String(s || '');
  }
  if (newsBox && window.fetch) {
    fetch('/api/launcher', { cache: 'no-store' })
      .then(function (r) { if (!r.ok) throw new Error(r.status); return r.json(); })
      .then(function (d) {
        var items = (d && Array.isArray(d.news) ? d.news : []).filter(function (n) { return n && (n.title || n.text); });
        if (!items.length) return;
        newsBox.textContent = '';
        items.slice(0, 6).forEach(function (n) {
          var art = document.createElement('article');
          art.className = 'news-item card';
          if (n.date) {
            var t = document.createElement('time');
            t.dateTime = String(n.date).slice(0, 10);
            t.textContent = ruDate(n.date);
            art.appendChild(t);
          }
          var h = document.createElement('h3');
          h.textContent = String(n.title || '');
          var p = document.createElement('p');
          p.textContent = String(n.text || '');
          art.appendChild(h); art.appendChild(p);
          newsBox.appendChild(art);
        });
      })
      .catch(function () { /* сервер недоступен — остаются новости, вписанные в страницу */ });
  }

  /* ---------- установщик: размер и подсказка для не-Windows ---------- */

  var dl = $('[data-download]');
  if (dl && window.fetch && location.protocol !== 'file:') {
    fetch(dl.getAttribute('href'), { method: 'HEAD', cache: 'no-cache' })
      .then(function (r) {
        var n = r.ok && +r.headers.get('content-length');
        if (!n || n < 1e6) return;
        var mb = Math.round(n / 1048576);
        $$('[data-size]').forEach(function (s) { s.textContent = 'Установщик — ' + mb + ' МБ'; });
      })
      .catch(function () { /* оставляем «около 100 МБ» */ });
  }
  var ua = navigator.userAgent || '';
  var platform = (navigator.userAgentData && navigator.userAgentData.platform) || navigator.platform || '';
  var isWindows = /win/i.test(platform) || /Windows NT/.test(ua);
  var isMac = /mac/i.test(platform) || /Macintosh/.test(ua);
  var isMobile = /Android|iPhone|iPad|iPod|Mobile/i.test(ua) || (navigator.userAgentData && navigator.userAgentData.mobile);
  if ((!isWindows && !isMac) || isMobile) {   // на Mac подсказка не нужна: под кнопкой и так ссылка «Скачать для Mac»
    var note = $('[data-os-note]');
    if (note) {
      note.textContent = isMobile ? 'CivCity — игра для компьютера с Windows или Mac. Откройте civcity.ru на компьютере, чтобы скачать её.'
        : 'Пока CivCity работает на Windows 10 и 11 и в тестовой версии на Mac.';
      note.hidden = false;
    }
  }
})();
