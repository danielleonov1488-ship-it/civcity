/* Замер производительности: сколько миллисекунд занимает кадр и из чего он складывается.
   Работает и в скрытом окне — кадры прокручиваются вручную, конец работы видеокарты ловится чтением одного пикселя.
   В странице игры: (0, eval)(await (await fetch('/promo/perf.js')).text()); Perf.report() */
window.Perf = {
  gl() { return Engine.renderer.getContext(); },
  sync() { const gl = this.gl(), px = new Uint8Array(4); gl.readPixels(0, 0, 1, 1, gl.RGBA, gl.UNSIGNED_BYTE, px); },

  step(dt = 1 / 60) {
    Walkers.update(dt, dt); Cats.update(dt, dt);
    Engine.frame(dt, dt);
    UI.updateLabels(dt); UI.updateHud();
  },

  // Среднее время кадра (мс) вместе с видеокартой
  frameMs(N = 40) {
    Game.hold = true;
    for (let i = 0; i < 8; i++) { this.step(); this.sync(); }
    const t0 = performance.now();
    for (let i = 0; i < N; i++) { this.step(); this.sync(); }
    return (performance.now() - t0) / N;
  },

  // Время процессора по частям кадра (без ожидания видеокарты)
  parts(N = 40) {
    Game.hold = true;
    const acc = {}, wrap = (obj, name, label) => {
      const f = obj[name];
      obj[name] = function (...a) { const t = performance.now(); const r = f.apply(this, a); acc[label] = (acc[label] || 0) + performance.now() - t; return r; };
      return () => { obj[name] = f; };
    };
    const undo = [
      wrap(Walkers, 'update', 'жители'), wrap(Cats, 'update', 'кошки'), wrap(UI, 'updateLabels', 'подписи'), wrap(UI, 'updateHud', 'панель'),
      wrap(Atmos, 'update', 'небо'), wrap(Engine, 'rebuildNature', 'природа'), wrap(Paving, 'sync', 'мостовая'), wrap(Engine, 'syncBuildings', 'здания:синх'),
      wrap(Engine, 'animateBuildings', 'здания:анимация'), wrap(Engine, 'drawWalkers', 'жители:рисование'), wrap(Engine, 'updateParticles', 'частицы'),
      wrap(Atmos, 'updateBirds', 'птицы'), wrap(Atmos, 'updateLife', 'жизнь'), wrap(Post, 'render', 'отрисовка (отправка)'),
    ];
    for (let i = 0; i < N; i++) this.step();
    undo.forEach(u => u());
    const out = {};
    for (const k in acc) out[k] = +(acc[k] / N).toFixed(2);
    return out;
  },

  counts() {
    const info = Engine.renderer.info;
    info.autoReset = false; info.reset();
    this.step(); this.sync();
    const r = { calls: info.render.calls, tris: info.render.triangles, geos: info.memory.geometries, tex: info.memory.textures, programs: info.programs.length };
    info.autoReset = true;
    return r;
  },

  // Что сколько стоит: выключаем по очереди и смотрим, насколько быстрее кадр
  toggles() {
    const base = this.frameMs();
    const res = { 'всё включено': +base.toFixed(2) };
    const test = (label, on, off) => { off(); const ms = this.frameMs(); on(); res[label] = +ms.toFixed(2); };
    const S = Engine.sun;
    test('без теней', () => { S.castShadow = true; }, () => { S.castShadow = false; });
    const p = Post.enabled;
    test('без постобработки', () => { Post.enabled = p; }, () => { Post.enabled = false; });
    // группы сцены: прячем по одной
    for (const ch of Engine.scene.children) {
      if (!ch.visible || ch.isLight) continue;
      const name = ch.name || ch.type + (ch.children.length ? `(${ch.children.length})` : '');
      let tris = 0; ch.traverse(o => { if (o.geometry && o.geometry.index) tris += o.geometry.index.count / 3 * (o.count || 1); else if (o.geometry && o.geometry.attributes.position) tris += o.geometry.attributes.position.count / 3 * (o.count || 1); });
      if (tris < 20000) continue;
      test(`без «${name}» (~${Math.round(tris / 1000)}k треуг.)`, () => { ch.visible = true; }, () => { ch.visible = false; });
    }
    return res;
  },

  report() {
    const gl = this.gl(), dbg = gl.getExtension('WEBGL_debug_renderer_info');
    return {
      gpu: dbg ? gl.getParameter(dbg.UNMASKED_RENDERER_WEBGL) : '?', quality: Engine.quality, dpr: Engine.renderer.getPixelRatio(),
      size: [Engine.W, Engine.H], post: Post.enabled, buildings: state.buildings.size, walkers: Walkers.list.length, cats: Cats.list.length,
      ms: +this.frameMs().toFixed(2), ...this.counts(),
    };
  },
};
