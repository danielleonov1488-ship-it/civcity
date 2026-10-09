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
    Engine.init($('game'), Settings.quality);
    Atmos.cycle = Settings.dayCycle;
    if (!loadGame()) this.setupNewCity();
    Army.ensure();
    if (state.camera) Object.assign(Engine.cam, { x: state.camera.x, z: state.camera.z, tx: state.camera.x, tz: state.camera.z, yaw: state.camera.yaw, yawTarget: state.camera.yaw, dist: state.camera.dist, distTarget: state.camera.dist });
    Engine.rebuildAll();
    Input.init(Engine.renderer.domElement);
    computeCoverage();
    UI.init();
    if (TEST_MODE && !state.testReady) Test.setup();
    UI.updateHud(true);
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
    for (let x = 0; x < PLOT; x++) placeBuilding('road', x, 11, true);
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
    if (TEST_MODE) Test.setup();
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
    const realDt = Math.min(0.1, (t - this.last) / 1000);
    this.last = t;
    this.lastTick = performance.now();
    // во время боя город стоит на паузе, а на экране — поле боя
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
    requestAnimationFrame(n => this.frame(n));
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

// Новый вид сначала подгружает запечённые модели; не вышло — запускаемся в прежнем виде
// Скрипты игры подключает js/boot.js уже после загрузки страницы — тогда стартуем сразу
function startGame() {
  if (!NEW_LOOK) return Game.boot();
  Look2.load().then(() => Game.boot(), e => { console.warn('Новый вид не загрузился', e); location.replace(location.pathname + location.hash); });
}
if (document.readyState === 'loading') window.addEventListener('DOMContentLoaded', startGame);
else startGame();
