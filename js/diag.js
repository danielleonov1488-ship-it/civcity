'use strict';
/* Проверка скорости (Настройки → «Проверить скорость игры»): ~20 секунд замеров на этом компьютере
   и отчёт, который можно скопировать и прислать. Видно, на какой видеокарте идёт игра, сколько стоит
   кадр на каждом качестве вблизи и издалека и как было бы без отбора невидимого (по-старому). */
const Diag = {
  running: false,

  // Кадр вручную: жители, кошки, отрисовка — без хода времени в городе
  step(dt = 1 / 60) {
    Walkers.update(dt, dt); Cats.update(dt, dt);
    Engine.frame(dt, dt);
  },

  // Время кадра: процессор (подготовка кадра) и видеокарта (рисование) по отдельности — медианы.
  // Видеокарту меряет её собственный таймер; если браузер его не даёт — ждём конца рисования чтением пикселя
  async measure(N = 25) {
    const gl = Engine.renderer.getContext(), px = new Uint8Array(4);
    const ext = gl.getExtension('EXT_disjoint_timer_query_webgl2');
    const sync = () => gl.readPixels(0, 0, 1, 1, gl.RGBA, gl.UNSIGNED_BYTE, px);
    const med = a => { const s = a.filter(v => v > 0).sort((x, y) => x - y); return s.length ? s[s.length >> 1] : 0; };
    for (let i = 0; i < 6; i++) { this.step(); sync(); }
    const cpu = [], whole = [], qs = [];
    for (let i = 0; i < N; i++) {
      let q = null;
      if (ext) { q = gl.createQuery(); gl.beginQuery(ext.TIME_ELAPSED_EXT, q); }
      const t0 = performance.now();
      this.step();
      const t1 = performance.now();
      if (ext) { gl.endQuery(ext.TIME_ELAPSED_EXT); qs.push(q); }
      sync();
      cpu.push(t1 - t0); whole.push(performance.now() - t0);
    }
    let gpu = 0;
    if (ext) {
      for (let k = 0; k < 40 && !qs.every(q => gl.getQueryParameter(q, gl.QUERY_RESULT_AVAILABLE)); k++) await this.wait(25);
      const disjoint = gl.getParameter(ext.GPU_DISJOINT_EXT);
      if (!disjoint) gpu = med(qs.map(q => gl.getQueryParameter(q, gl.QUERY_RESULT_AVAILABLE) ? gl.getQueryParameter(q, gl.QUERY_RESULT) / 1e6 : 0));
      qs.forEach(q => gl.deleteQuery(q));
    }
    const c = med(cpu);
    if (!gpu) gpu = Math.max(0, med(whole) - c);
    return { cpu: c, gpu, timer: !!ext };
  },

  tris() {
    const info = Engine.renderer.info;
    info.autoReset = false; info.reset();
    this.step();
    const t = info.render.triangles;
    info.autoReset = true;
    return t;
  },

  // Сколько кадров в секунду на самом деле показывает экран (обычный ход игры)
  async realFps(ms) {
    const n0 = Game.drawn || 0, t0 = performance.now();
    await this.wait(ms);
    return ((Game.drawn || 0) - n0) * 1000 / (performance.now() - t0);
  },

  wait: ms => new Promise(r => setTimeout(r, ms)),

  async run() {
    if (this.running || Battle.active) return;
    this.running = true;
    const set = html => UI.showModal(`<p class="eyebrow">CivCity</p><h2>Проверка скорости</h2>${html}`);
    set('<p class="sub">Около 20 секунд. Не переключайтесь на другие окна — иначе браузер притормозит игру и замер выйдет неверным.</p><p class="sub" id="diag-step">Сейчас: обычная игра…</p>');
    const stepText = t => { const el = $('diag-step'); if (el) el.textContent = 'Сейчас: ' + t; };
    const g = Engine.gpuInfo(), cam = { ...Engine.cam }, q0 = Settings.quality, fs0 = Engine.forceSize;
    const lines = [];
    try {
      // окно свёрнуто или скрыто — рисуем в кадр 1280×720, иначе мерить нечего
      if (!innerWidth || !innerHeight) { Engine.forceSize = [1280, 720]; Engine.resize(); }
      await this.wait(400);
      const fps = await this.realFps(3000);
      Game.hold = true;
      const rows = [];
      for (const q of ['high', 'medium', 'low']) {
        stepText(`качество «${UI.qName(q)}»…`);
        await this.wait(30);
        Engine.setQuality(q);
        const r = { q };
        for (const [k, d] of [['near', 26], ['far', 70]]) {
          Engine.cam.dist = Engine.cam.distTarget = d;
          for (let i = 0; i < 40; i++) this.step();      // догрузить участки вокруг, отобрать видимое, построить облегчённые модели
          await this.measure(8);                         // прогрев: видеокарта собирает шейдеры нового качества
          r[k] = await this.measure(25);
          r[k + 'T'] = this.tris();
          await this.wait(10);
        }
        rows.push(r);
      }
      // как было до отбора невидимого: высокое качество, обычный вид
      stepText('как было раньше…');
      await this.wait(30);
      Engine.setQuality('high');
      Engine.cam.dist = Engine.cam.distTarget = 26;
      Engine.noCull = true; Engine.natView = null; Engine.cullBuildings = true;
      for (let i = 0; i < 40; i++) this.step();
      await this.measure(8);
      const old = await this.measure(15), oldT = this.tris();
      Engine.noCull = false; Engine.natView = null; Engine.cullBuildings = true;

      // кадр готов, когда закончили и процессор, и видеокарта (они работают одновременно)
      const ms = m => `видеокарта ${m.gpu.toFixed(1)} мс, процессор ${m.cpu.toFixed(1)} мс (≈${Math.min(999, Math.round(1000 / Math.max(m.gpu, m.cpu, 0.5)))} к/с)`;
      const mt = v => `${(v / 1e6).toFixed(2)} млн треуг.`;
      const app = /CivCity|Electron/i.test(navigator.userAgent) ? 'программа CivCity для ПК' : (navigator.userAgent.match(/(Edg|OPR|YaBrowser|Firefox|Chrome)\/[\d.]+/) || ['браузер'])[0];
      lines.push('CivCity — проверка скорости');
      lines.push(`Видеокарта: ${g.name || 'не удалось узнать'}${g.soft ? ' — БЕЗ ВИДЕОКАРТЫ (программная отрисовка)' : g.integrated ? ' — ВСТРОЕННАЯ графика' : ''}`);
      lines.push(`Где запущено: ${app}`);
      lines.push(`Экран: ${screen.width}×${screen.height}, окно ${innerWidth}×${innerHeight}, масштаб ${Math.round(devicePixelRatio * 100)}%`);
      lines.push(`Процессор: ${navigator.hardwareConcurrency || '?'} потоков${navigator.deviceMemory ? `, память ≥${navigator.deviceMemory} ГБ` : ''}`);
      lines.push(`Город: ${state.buildings.size} построек, ${Walkers.list.length} жителей на улицах`);
      lines.push(`На экране было: ${Math.round(fps)} кадров/с (качество «${UI.qName(q0)}»)`);
      for (const r of rows) lines.push(`«${UI.qName(r.q)}»: обычный вид ${ms(r.near)}, ${mt(r.nearT)} · издалека ${ms(r.far)}, ${mt(r.farT)}`);
      lines.push(`Как было до оптимизации (высокое, обычный вид): ${ms(old)}, ${mt(oldT)}`);
      if (g.raw) lines.push(`(${g.raw})`);
    } catch (e) {
      lines.push('Проверка прервалась: ' + e.message);
    } finally {
      Engine.noCull = false;
      if (Engine.forceSize !== fs0) { Engine.forceSize = fs0; Engine.resize(); }
      Settings.quality = q0;
      Engine.setQuality(q0);
      Object.assign(Engine.cam, cam);
      Game.hold = false;
      this.running = false;
    }
    const text = lines.join('\n');
    set(`<p class="sub">Пришлите этот отчёт (текстом или скриншотом) — по нему видно, что тормозит.</p>
      <pre class="diag-report">${escapeHtml(text)}</pre>
      <div class="actions"><button type="button" class="btn ghost" id="diag-copy">Скопировать отчёт</button><button type="button" class="btn" id="diag-close">Готово</button></div>`);
    $('diag-close').onclick = () => UI.closeModal();
    $('diag-copy').onclick = () => {
      const done = () => { $('diag-copy').textContent = 'Скопировано'; };
      if (navigator.clipboard) navigator.clipboard.writeText(text).then(done, () => this.selectReport());
      else this.selectReport();
    };
  },

  // Буфер обмена недоступен — выделяем текст, чтобы скопировать вручную (Ctrl+C)
  selectReport() {
    const pre = document.querySelector('.diag-report');
    if (!pre) return;
    const r = document.createRange(); r.selectNodeContents(pre);
    const s = getSelection(); s.removeAllRanges(); s.addRange(r);
  },
};
