'use strict';
/* Точка входа: запуск, игровой цикл, новая игра. */

const Game = {
  dayTimer: 0,
  last: 0,
  saveTimer: 0,

  boot() {
    if (!window.THREE) {
      document.body.insertAdjacentHTML('beforeend', '<div class="fatal">Не удалось загрузить 3D-библиотеку. Обновите страницу.</div>');
      return;
    }
    Settings.load();
    Sound.init();
    Engine.init($('game'), Settings.quality);
    Atmos.cycle = Settings.dayCycle;
    if (!loadGame()) this.setupNewCity();
    Army.ensure();
    if (state.camera) Object.assign(Engine.cam, { x: state.camera.x, z: state.camera.z, tx: state.camera.x, tz: state.camera.z, yaw: state.camera.yaw, yawTarget: state.camera.yaw, dist: state.camera.dist, distTarget: state.camera.dist });
    Engine.rebuildAll();
    Input.init(Engine.renderer.domElement);
    computeCoverage();
    UI.init();
    if (TEST_MODE && !state.testReady) (PROMO_MODE ? Promo.setup() : Test.setup());
    else if (TEST_MODE && !PROMO_MODE) Test.update();
    UI.updateHud(true);
    Account.init();
    window.addEventListener('beforeunload', () => saveGame());
    // #test дописали или стёрли в адресной строке — перезапуск в нужный город
    window.addEventListener('hashchange', () => { if (isTestUrl() !== TEST_MODE) location.reload(); });
    document.addEventListener('visibilitychange', () => { if (document.hidden) saveGame(); });
    this.last = this.lastTick = performance.now();
    requestAnimationFrame(t => this.frame(t));
    // Во вкладке на заднем плане браузер не рисует кадры — город живёт по таймеру
    setInterval(() => this.background(), 1000);
  },

  // Новый город: свежая карта и стартовая дорога через участок
  setupNewCity() {
    state = newState(Math.floor(Math.random() * 1e9));
    World.terrain.clear();
    World.occ.clear();
    World.bgrid.clear();
    Roads.clear();
    // стартовая улица через весь участок
    const a = Roads.addNode(0.5, 11.5), b = Roads.addNode(PLOT - 0.5, 11.5);
    clearNatureAlong(Roads.addEdge(a, b, [[a.x, a.y], [b.x, b.y]]));
    const d = window.innerWidth < window.innerHeight ? 38 : 30;
    Object.assign(Engine.cam, { x: PLOT / 2, z: PLOT / 2, tx: PLOT / 2, tz: PLOT / 2, dist: d, distTarget: d, yaw: Math.PI / 4, yawTarget: Math.PI / 4 });
  },

  newGame() {
    this.setupNewCity();
    Army.ensure();
    Walkers.list = [];
    Cats.list = [];
    Engine.particles = [];
    UI.floats = [];
    UI.closePanel();
    Engine.rebuildAll();
    Input.setTool(null);
    computeCoverage();
    UI.buildToolbar();
    if (TEST_MODE) (PROMO_MODE ? Promo.setup() : Test.setup());
    UI.setSpeed(1);
    UI.closeTray();
    Advisor.render(true);
    saveGame();
    UI.updateHud(true);
  },

  // Игровое время: дни идут, пока игра не на паузе и не открыто окно
  advance(realDt) {
    const running = state.speed > 0 && !UI.blocking();
    const dt = running ? realDt * state.speed : 0;
    // в городе для съёмок дни не идут — дома не меняются, а жители гуляют
    if (PROMO_MODE) return dt;
    if (running) {
      this.dayTimer += dt;
      while (this.dayTimer >= DAY_SECONDS) {
        this.dayTimer -= DAY_SECONDS;
        simDay();
      }
    }
    this.saveTimer += realDt;
    if (this.saveTimer > 15) { this.saveTimer = 0; saveGame(); }
    return dt;
  },

  frame(t) {
    // съёмка ролика сама шагает кадрами — обычный цикл ждёт
    if (this.hold) { requestAnimationFrame(n => this.frame(n)); return; }
    // Мониторы 120–240 Гц зовут кадр чаще, чем нужно: рисуем около 60 раз в секунду,
    // чтобы видеокарта не работала впустую (на 144 Гц — каждый второй вызов)
    const gap = t - (this.prevRaf || t);
    this.prevRaf = t;
    if (gap > 0 && gap < 100) this.rafMs = this.rafMs ? this.rafMs * 0.95 + gap * 0.05 : gap;
    const every = Math.max(1, Math.round(16.67 / (this.rafMs || 16.67)));
    this.rafN = ((this.rafN || 0) + 1) % every;
    if (this.rafN) { requestAnimationFrame(n => this.frame(n)); return; }
    const realDt = Math.min(0.1, (t - this.last) / 1000);
    this.last = t;
    this.lastTick = performance.now();
    // во время боя город стоит на паузе, а на экране — поле боя
    Sound.update(realDt);
    if (Battle.active) {
      Battle.frame(realDt);
      ArmyUI.tick();
      requestAnimationFrame(n => this.frame(n));
      return;
    }
    const dt = this.advance(realDt);
    Input.update(realDt);
    Walkers.update(dt, realDt);
    Cats.update(dt, realDt);
    Engine.frame(dt, realDt);
    UI.updateLabels(realDt);
    UI.updateHud();
    this.autoQuality(realDt);
    requestAnimationFrame(n => this.frame(n));
  },

  // Пока игрок сам не выбрал качество: если два замера подряд (по 4 с) меньше 38 кадров в секунду —
  // снижаем качество на ступень. Сразу после загрузки не меряем — там бывают рывки
  autoQuality(realDt) {
    if (!Settings.qAuto || Settings.quality === 'low' || document.hidden || PROMO_MODE) { this.aq = null; return; }
    const a = this.aq || (this.aq = { t: 0, n: 0, warm: 6, slow: 0 });
    if (a.warm > 0) { a.warm -= realDt; return; }
    a.t += realDt; a.n++;
    if (a.t < 4) return;
    const fps = a.n / a.t;
    a.slow = fps < 38 ? a.slow + 1 : 0;
    a.t = 0; a.n = 0;
    if (a.slow < 2) return;
    Settings.quality = Settings.quality === 'high' ? 'medium' : 'low';
    Settings.save();
    Engine.setQuality(Settings.quality);
    this.aq = { t: 0, n: 0, warm: 3, slow: 0 };
  },

  // Вкладка свёрнута: считаем дни по настоящим часам (браузер может будить таймер и раз в минуту).
  // Сон компьютера не в счёт — за один раз догоняем не больше 10 минут.
  background() {
    const now = performance.now();
    if (!document.hidden || Battle.active) { this.lastTick = now; return; }
    const realDt = Math.min(600, (now - this.lastTick) / 1000);
    this.lastTick = now;
    this.advance(realDt);
  },
};

// Сначала подгружаются запечённые модели; не вышло — запускаемся в прежнем виде (?old)
// Скрипты игры подключает js/boot.js уже после загрузки страницы — тогда стартуем сразу
function startGame() {
  if (!NEW_LOOK) return Game.boot();
  Look2.load().then(() => Game.boot(), e => { console.warn('Новый вид не загрузился', e); location.replace(location.pathname + '?old' + location.hash); });
}
if (document.readyState === 'loading') window.addEventListener('DOMContentLoaded', startGame);
else startGame();
