'use strict';
/* Звук CivCity — целиком свой: ничего не скачивается, никаких лицензий.
   Музыка сочиняется на ходу: тихое фортепиано в духе спокойных песочниц — пьеса на пару минут, потом тишина,
   потом новая пьеса в другой тональности; иногда под фортепиано ложится мягкая подложка.
   Звуки синтезируются: клик кнопки, стройка («тук-тук»), снос, мостовая, колокольчик при росте дома,
   в бою — звон мечей, свист стрел, удары камней, крики, боевой рог и барабаны.
   Днём поют птицы, ночью — сверчки (если камера близко к земле).
   Браузер разрешает звук только после первого нажатия игрока — до этого всё молчит. */

const Sound = {
  ctx: null,
  ready: false,
  music: 0.5,          // громкость музыки 0..1 (настройки)
  sfx: 0.7,            // громкость звуков 0..1
  last: {},            // когда звучал звук данного вида — чтобы не трещало
  piece: null,
  nextPiece: 0,

  /* ---------- Запуск ---------- */

  init() {
    this.music = Settings.music ?? 0.5;
    this.sfx = Settings.sfx ?? 0.7;
    const unlock = () => {
      this.start();
      if (this.ready) { window.removeEventListener('pointerdown', unlock, true); window.removeEventListener('keydown', unlock, true); }
    };
    window.addEventListener('pointerdown', unlock, true);
    window.addEventListener('keydown', unlock, true);
    // тык — у всех кнопок интерфейса
    document.addEventListener('pointerdown', e => {
      const t = e.target.closest && e.target.closest('button, .card, .cat, [data-tool], a.btn, .seg button, label.switch');
      if (t && !t.disabled) this.click();
    }, true);
  },

  start() {
    if (this.ctx) { if (this.ctx.state === 'suspended') this.ctx.resume(); return; }
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return;
    this.setup(new AC({ latencyHint: 'playback' }));
    this.nextPiece = this.ctx.currentTime + 4;
    this.startAmbience();
    setInterval(() => this.schedule(), 250);
  },

  // Шины и общие заготовки; ctx может быть и «немым» OfflineAudioContext — для проверки громкости
  setup(ctx) {
    this.ctx = ctx;
    const comp = ctx.createDynamicsCompressor();
    comp.threshold.value = -18; comp.knee.value = 12; comp.ratio.value = 3; comp.attack.value = 0.01; comp.release.value = 0.3;
    comp.connect(ctx.destination);
    this.master = ctx.createGain(); this.master.gain.value = 0.9; this.master.connect(comp);
    // шины: музыка (с большим залом), звуки и окружение (с маленьким)
    this.hall = this.reverb(3.2, 0.55);
    this.room = this.reverb(1.2, 0.25);
    this.hallOut = ctx.createGain(); this.hallOut.gain.value = 0.55; this.hall.connect(this.hallOut); this.hallOut.connect(this.master);
    this.roomOut = ctx.createGain(); this.roomOut.gain.value = 0.35; this.room.connect(this.roomOut); this.roomOut.connect(this.master);
    this.musicBus = ctx.createGain(); this.musicBus.connect(this.master); this.musicBus.connect(this.hall);
    this.sfxBus = ctx.createGain(); this.sfxBus.connect(this.master); this.sfxBus.connect(this.room);
    this.ambBus = ctx.createGain(); this.ambBus.connect(this.master); this.ambBus.connect(this.room);
    this.setVolumes();
    this.noiseBuf = this.makeNoise(2);
    this.pianoWave = ctx.createPeriodicWave(new Float32Array([0, 1, 0.42, 0.22, 0.12, 0.07, 0.045, 0.03, 0.018, 0.01]), new Float32Array(10));
    this.ready = true;
  },

  setVolumes() {
    if (!this.ctx) return;
    const t = this.ctx.currentTime;
    this.musicBus.gain.setTargetAtTime(this.music * this.music * 1.7 * (this.battleDuck || 1), t, 0.3);
    this.sfxBus.gain.setTargetAtTime(this.sfx * this.sfx * 1.0, t, 0.05);
    this.ambBus.gain.setTargetAtTime(this.sfx * this.sfx * 0.8, t, 0.3);
  },

  // Искусственный зал: стерео-шум, затухающий по экспоненте
  reverb(seconds, decay) {
    const ctx = this.ctx, n = Math.floor(ctx.sampleRate * seconds);
    const buf = ctx.createBuffer(2, n, ctx.sampleRate);
    for (let ch = 0; ch < 2; ch++) {
      const d = buf.getChannelData(ch);
      let lp = 0;
      for (let i = 0; i < n; i++) {
        const t = i / ctx.sampleRate;
        lp += (Math.random() * 2 - 1 - lp) * 0.35;      // чуть приглушить верх — зал звучит теплее
        d[i] = lp * Math.exp(-t / decay) * (i < 200 ? i / 200 : 1);
      }
    }
    const c = ctx.createConvolver();
    c.buffer = buf;
    return c;
  },

  makeNoise(seconds) {
    const ctx = this.ctx, n = Math.floor(ctx.sampleRate * seconds);
    const buf = ctx.createBuffer(1, n, ctx.sampleRate);
    const d = buf.getChannelData(0);
    for (let i = 0; i < n; i++) d[i] = Math.random() * 2 - 1;
    return buf;
  },

  // Можно ли сейчас этот звук (не чаще gap секунд)
  may(kind, gap) {
    if (!this.ready || this.ctx.state !== 'running') return false;
    const now = this.ctx.currentTime;
    if (this.last[kind] && now - this.last[kind] < gap) return false;
    this.last[kind] = now;
    return true;
  },

  // Громкость события в городе: ближе к центру экрана и при приближении — громче
  near(x, z) {
    if (!Engine.cam) return 1;
    const c = Engine.cam, d = Math.hypot(x - c.x, z - c.z);
    const reach = c.dist * 0.9 + 4;
    return clamp(1 - d / reach, 0, 1) * clamp(1.3 - c.dist / 60, 0.25, 1);
  },

  /* ---------- Кирпичики синтеза ---------- */

  env(g, t, peak, attack, tau) {
    g.gain.setValueAtTime(0, t);
    g.gain.linearRampToValueAtTime(peak, t + attack);
    g.gain.setTargetAtTime(0, t + attack, tau);
  },

  noise(t, dur, out, { type = 'bandpass', freq = 1000, q = 1, peak = 0.3, attack = 0.002, tau = 0.05, sweep } = {}) {
    const ctx = this.ctx, src = ctx.createBufferSource();
    src.buffer = this.noiseBuf;
    const f = ctx.createBiquadFilter(); f.type = type; f.frequency.value = freq; f.Q.value = q;
    if (sweep) { f.frequency.setValueAtTime(freq, t); f.frequency.exponentialRampToValueAtTime(sweep, t + dur); }
    const g = ctx.createGain(); this.env(g, t, peak, attack, tau);
    src.connect(f); f.connect(g); g.connect(out);
    src.start(t, Math.random() * 1.5); src.stop(t + dur + tau * 5);
  },

  tone(t, freq, out, { type = 'sine', peak = 0.2, attack = 0.003, tau = 0.1, to, glide = 0.1, dur } = {}) {
    const ctx = this.ctx, o = ctx.createOscillator();
    o.type = type; o.frequency.setValueAtTime(freq, t);
    if (to) o.frequency.exponentialRampToValueAtTime(to, t + glide);
    const g = ctx.createGain(); this.env(g, t, peak, attack, tau);
    o.connect(g); g.connect(out);
    o.start(t); o.stop(t + (dur || tau * 6 + attack));
  },

  /* ---------- Фортепиано и подложка ---------- */

  piano(t, midi, vel, len) {
    const ctx = this.ctx, f = 440 * Math.pow(2, (midi - 69) / 12);
    const tau = clamp(1.9 * Math.sqrt(220 / f), 0.35, 3.2);
    const out = ctx.createGain();
    out.gain.setValueAtTime(0, t);
    out.gain.linearRampToValueAtTime(vel * 0.2, t + 0.005);
    out.gain.setTargetAtTime(0, t + 0.005, tau);
    out.gain.setTargetAtTime(0, t + len, 0.18);
    const lp = ctx.createBiquadFilter();
    lp.type = 'lowpass'; lp.Q.value = 0.4;
    lp.frequency.setValueAtTime(Math.min(9000, f * (4 + vel * 8)), t);
    lp.frequency.setTargetAtTime(Math.max(f * 1.6, 350), t + 0.01, tau * 0.5);
    for (const det of [-3, 3.5]) {
      const o = ctx.createOscillator();
      o.setPeriodicWave(this.pianoWave);
      o.frequency.value = f;
      o.detune.value = det + (Math.random() - 0.5) * 2;
      o.connect(lp);
      o.start(t); o.stop(t + len + 1.2);
    }
    lp.connect(out);
    out.connect(this.musicBus);
    // мягкий удар молоточка
    this.noise(t, 0.02, this.musicBus, { freq: Math.min(5000, f * 3), q: 0.8, peak: vel * 0.025, tau: 0.012 });
  },

  pad(t, midis, len) {
    const ctx = this.ctx, out = ctx.createGain();
    out.gain.setValueAtTime(0, t);
    out.gain.linearRampToValueAtTime(0.035, t + 1.8);
    out.gain.setValueAtTime(0.035, t + Math.max(1.9, len - 0.5));
    out.gain.linearRampToValueAtTime(0, t + len + 2.2);
    const lp = ctx.createBiquadFilter(); lp.type = 'lowpass'; lp.frequency.value = 800; lp.Q.value = 0.3;
    lp.connect(out); out.connect(this.musicBus);
    for (const m of midis) for (const det of [-7, 6]) {
      const o = ctx.createOscillator();
      o.type = 'triangle';
      o.frequency.value = 440 * Math.pow(2, (m - 69) / 12);
      o.detune.value = det;
      o.connect(lp);
      o.start(t); o.stop(t + len + 2.5);
    }
  },

  /* ---------- Сочинитель: пьеса за пьесой, между ними — тишина ---------- */

  compose() {
    const SCALES = {
      major: [0, 2, 4, 5, 7, 9, 11], lydian: [0, 2, 4, 6, 7, 9, 11], dorian: [0, 2, 3, 5, 7, 9, 10], mixo: [0, 2, 4, 5, 7, 9, 10],
    };
    const PROG = {
      major: [[0, 5, 3, 4], [0, 3, 5, 4], [0, 2, 3, 4], [3, 4, 0, 0], [0, 4, 5, 3], [5, 3, 0, 4]],
      lydian: [[0, 1, 0, 1], [0, 1, 4, 0], [0, 6, 1, 0]],
      dorian: [[0, 3, 0, 6], [0, 1, 3, 0], [0, 6, 3, 0]],
      mixo: [[0, 6, 3, 0], [0, 3, 6, 0]],
    };
    const pick = a => a[Math.floor(Math.random() * a.length)];
    const mode = pick(['major', 'major', 'major', 'lydian', 'dorian', 'mixo']);
    const scale = SCALES[mode], prog = pick(PROG[mode]);
    const root = 48 + pick([0, 2, 3, 5, 7, 8, 10]);        // тоника в малой октаве
    const bpm = 58 + Math.floor(Math.random() * 18);
    const beats = Math.random() < 0.25 ? 3 : 4;
    const deg = (d, oct) => root + 12 * (oct + Math.floor(d / 7)) + scale[((d % 7) + 7) % 7];
    // мотив: ритм на два такта и шаги по ладу — будет повторяться с вариациями
    const len = beats * 2;
    const rhythm = [];
    for (let b = 0; b < len; b += 0.5) if (Math.random() < (b % 1 ? 0.18 : 0.42)) rhythm.push(b);
    if (!rhythm.length) rhythm.push(0, 2);
    const steps = [0];
    for (let i = 1; i < rhythm.length; i++) steps.push(steps[i - 1] + pick([-2, -1, -1, 1, 1, 2, 0, 3]));
    return { mode, scale, prog, root, deg, beat: 60 / bpm, beats, rhythm, steps, passes: 2 + Math.floor(Math.random() * 2), pad: Math.random() < 0.55, arp: Math.random() < 0.5 };
  },

  // Вся пьеса раскладывается на ноты с временами — проигрываются по мере подхода
  writePiece(t0) {
    const P = this.compose(), notes = [];
    const bar = P.beat * P.beats, chordLen = bar * 2;
    let t = t0;
    for (let pass = 0; pass < P.passes; pass++) {
      const last = pass === P.passes - 1;
      for (let c = 0; c < P.prog.length; c++) {
        const d = P.prog[c];
        const tones = [d, d + 2, d + 4];
        // левая рука: бас и аккорд — разложенный или вместе
        notes.push({ t, m: P.deg(d, -1), v: 0.42, l: chordLen * 0.9 });
        if (P.arp) tones.forEach((td, i) => notes.push({ t: t + P.beat * (i + 1) * 0.5, m: P.deg(td, 0), v: 0.3, l: chordLen * 0.6 }));
        else { notes.push({ t: t + P.beat, m: P.deg(d + 4, -1), v: 0.3, l: chordLen * 0.6 }); notes.push({ t: t + bar, m: P.deg(d + 2, 0), v: 0.27, l: bar }); }
        if (P.pad && pass > 0) notes.push({ t, pad: tones.map(td => P.deg(td, 0)), l: chordLen });
        // правая рука: мотив, привязанный к аккорду; в первый проход — реже
        const want = pass === 0 ? 0.45 : last ? 0.55 : 0.85;
        if (Math.random() < want) {
          const start = d + 7 + (Math.random() < 0.5 ? 2 : 0);
          P.rhythm.forEach((b, i) => {
            if (Math.random() < 0.15) return;
            // последняя нота мотива иногда возвращается к основному тону аккорда
            const step = i === P.rhythm.length - 1 && Math.random() < 0.5 ? d + 7 : start + P.steps[i];
            notes.push({ t: t + b * P.beat, m: P.deg(step, 0), v: 0.38 + Math.random() * 0.18, l: P.beat * 1.6 });
          });
        }
        t += chordLen;
      }
    }
    // финал — тоника, долго звучит
    notes.push({ t, m: P.deg(0, -1), v: 0.4, l: bar * 2 }, { t: t + 0.05, m: P.deg(4, 0), v: 0.28, l: bar * 2 }, { t: t + 0.1, m: P.deg(9, 0), v: 0.3, l: bar * 2 });
    notes.sort((a, b) => a.t - b.t);
    return { notes, i: 0, end: t + bar * 2 + 3 };
  },

  schedule() {
    if (!this.ready) return;
    const now = this.ctx.currentTime, ahead = now + 2.5;
    if (!this.piece && now >= this.nextPiece && this.music > 0.001) this.piece = this.writePiece(now + 0.3);
    const p = this.piece;
    if (p) {
      while (p.i < p.notes.length && p.notes[p.i].t < ahead) {
        const n = p.notes[p.i++];
        if (n.t < now - 0.05) continue;
        if (n.pad) this.pad(n.t, n.pad, n.l); else this.piano(n.t, n.m, n.v, n.l);
      }
      if (p.i >= p.notes.length && now > p.end) {
        this.piece = null;
        this.nextPiece = now + 35 + Math.random() * 90;   // тишина между пьесами, как в спокойных песочницах
      }
    }
    if (this.drums) this.scheduleDrums(now, ahead);
  },

  /* ---------- Окружение: птицы и сверчки ---------- */

  startAmbience() {
    this.ambT = 0;
  },

  update(realDt) {
    if (!this.ready || this.ctx.state !== 'running') return;
    const inCity = !Battle.active;
    const c = Engine.cam;
    const night = typeof Atmos !== 'undefined' ? Atmos.night || 0 : 0;
    // птицы днём и сверчки ночью — изредка и только близко к земле
    this.ambT -= realDt;
    if (inCity && this.ambT <= 0) {
      this.ambT = 2 + Math.random() * 5;
      const open = c ? clamp((45 - c.dist) / 30, 0, 1) : 0;
      if (open > 0.1) {
        if (night < 0.5 && Math.random() < 0.7) this.bird(open * (1 - night));
        else if (night > 0.5) this.cricket(open * night);
      }
    }
  },

  bird(k) {
    const t = this.ctx.currentTime + 0.05, base = 2600 + Math.random() * 2400, n = 2 + Math.floor(Math.random() * 4);
    for (let i = 0; i < n; i++) {
      const s = t + i * (0.09 + Math.random() * 0.07);
      this.tone(s, base * (0.9 + Math.random() * 0.25), this.ambBus, { peak: 0.05 * k, attack: 0.008, tau: 0.03, to: base * (1.1 + Math.random() * 0.4), glide: 0.06, dur: 0.14 });
    }
  },

  cricket(k) {
    const t = this.ctx.currentTime + 0.05;
    for (let i = 0; i < 3; i++) for (let j = 0; j < 4; j++) {
      this.tone(t + i * 0.32 + j * 0.035, 4400 + Math.random() * 200, this.ambBus, { peak: 0.022 * k, attack: 0.004, tau: 0.008, dur: 0.04 });
    }
  },

  /* ---------- Звуки интерфейса и стройки ---------- */

  click() {
    if (!this.may('click', 0.04)) return;
    const t = this.ctx.currentTime;
    this.tone(t, 820, this.sfxBus, { peak: 0.09, attack: 0.002, tau: 0.025, to: 520, glide: 0.04, dur: 0.12 });
    this.noise(t, 0.02, this.sfxBus, { freq: 3200, q: 1.5, peak: 0.04, tau: 0.008 });
  },

  // Стройка: глухой удар и пара деревянных «тук-тук», у больших зданий — ниже и дольше
  build(b) {
    if (!b || !this.may('build', 0.08)) return;
    const k = this.near(b.x + b.w / 2, b.y + b.h / 2);
    if (k <= 0.02) return;
    const t = this.ctx.currentTime, size = clamp(b.w / 3, 0.4, 1.4);
    this.tone(t, 150 / size, this.sfxBus, { peak: 0.35 * k, attack: 0.004, tau: 0.07, to: 55, glide: 0.18, dur: 0.4 });
    const knocks = 2 + Math.floor(size * 2);
    for (let i = 0; i < knocks; i++) {
      const s = t + 0.12 + i * (0.13 + Math.random() * 0.05);
      this.noise(s, 0.06, this.sfxBus, { freq: 700 + Math.random() * 500, q: 6, peak: 0.28 * k, tau: 0.03 });
      this.tone(s, 260 + Math.random() * 120, this.sfxBus, { peak: 0.08 * k, attack: 0.002, tau: 0.04, dur: 0.15 });
    }
    this.noise(t + 0.05, 0.4, this.sfxBus, { type: 'lowpass', freq: 900, q: 0.5, peak: 0.08 * k, attack: 0.03, tau: 0.15 });
  },

  // Мостовая: россыпь коротких каменных щелчков
  road(len) {
    if (!this.may('road', 0.1)) return;
    const t = this.ctx.currentTime, n = clamp(Math.round(len * 1.5), 3, 10);
    for (let i = 0; i < n; i++) this.noise(t + i * 0.055 + Math.random() * 0.03, 0.04, this.sfxBus, { freq: 1800 + Math.random() * 1500, q: 4, peak: 0.26, tau: 0.018 });
  },

  demolish(x, z) {
    if (!this.may('demolish', 0.1)) return;
    const k = x === undefined ? 1 : this.near(x, z);
    if (k <= 0.02) return;
    const t = this.ctx.currentTime;
    this.noise(t, 0.6, this.sfxBus, { type: 'lowpass', freq: 2200, sweep: 300, q: 0.7, peak: 0.25 * k, attack: 0.01, tau: 0.22 });
    for (let i = 0; i < 4; i++) this.noise(t + 0.05 + Math.random() * 0.35, 0.05, this.sfxBus, { freq: 500 + Math.random() * 800, q: 5, peak: 0.15 * k, tau: 0.03 });
  },

  // Дом вырос — тихий колокольчик, если он на виду
  chime(x, z) {
    const k = this.near(x, z);
    if (k < 0.15 || !this.may('chime', 2.5)) return;
    const t = this.ctx.currentTime, base = [1568, 1760, 2093, 2349][Math.floor(Math.random() * 4)];
    this.tone(t, base, this.sfxBus, { peak: 0.06 * k, attack: 0.003, tau: 0.35, dur: 1.6 });
    this.tone(t + 0.09, base * 1.5, this.sfxBus, { peak: 0.04 * k, attack: 0.003, tau: 0.3, dur: 1.4 });
  },

  /* ---------- Бой ---------- */

  // Звон мечей: несколько негармоничных обертонов и короткий шорох стали
  clash(k) {
    if (!this.may('clash', 0.07)) return;
    const t = this.ctx.currentTime, f0 = 520 + Math.random() * 600, v = (0.5 + Math.random() * 0.5) * (k || 1);
    for (const [r, a] of [[1, 1], [2.76, 0.6], [5.4, 0.4], [8.93, 0.25]]) {
      this.tone(t, f0 * r, this.sfxBus, { type: 'sine', peak: 0.1 * a * v, attack: 0.001, tau: 0.09 + Math.random() * 0.12, dur: 0.9 });
    }
    this.noise(t, 0.05, this.sfxBus, { type: 'highpass', freq: 3500, q: 0.7, peak: 0.12 * v, tau: 0.02 });
  },

  thud(k) {
    if (!this.may('thud', 0.06)) return;
    const t = this.ctx.currentTime;
    this.tone(t, 110, this.sfxBus, { peak: 0.25 * (k || 1), attack: 0.003, tau: 0.06, to: 60, glide: 0.12, dur: 0.3 });
    this.noise(t, 0.08, this.sfxBus, { type: 'lowpass', freq: 700, peak: 0.12 * (k || 1), tau: 0.04 });
  },

  whoosh(kind) {
    if (!this.may('whoosh', 0.05)) return;
    const t = this.ctx.currentTime;
    if (kind === 'stone' || kind === 'boulder') this.noise(t, 0.5, this.sfxBus, { type: 'bandpass', freq: 300, sweep: 120, q: 1.2, peak: 0.2, attack: 0.08, tau: 0.15 });
    else this.noise(t, 0.25, this.sfxBus, { type: 'bandpass', freq: 2600, sweep: 900, q: 2, peak: 0.14, attack: 0.03, tau: 0.08 });
  },

  boom() {
    if (!this.may('boom', 0.15)) return;
    const t = this.ctx.currentTime;
    this.tone(t, 90, this.sfxBus, { peak: 0.3, attack: 0.005, tau: 0.18, to: 38, glide: 0.4, dur: 1 });
    this.noise(t, 0.7, this.sfxBus, { type: 'lowpass', freq: 1500, sweep: 200, peak: 0.25, attack: 0.005, tau: 0.25 });
  },

  // Голос: пилообразный тон через «гласные» полосы — крик, стон, клич
  voice(t, f, to, dur, peak, vowel) {
    const ctx = this.ctx, o = ctx.createOscillator();
    o.type = 'sawtooth';
    o.frequency.setValueAtTime(f, t);
    o.frequency.exponentialRampToValueAtTime(to, t + dur);
    const vib = ctx.createOscillator(), vg = ctx.createGain();
    vib.frequency.value = 5 + Math.random() * 2; vg.gain.value = f * 0.02;
    vib.connect(vg); vg.connect(o.frequency);
    const g = ctx.createGain();
    g.gain.setValueAtTime(0, t);
    g.gain.linearRampToValueAtTime(peak, t + 0.04);
    g.gain.setValueAtTime(peak, t + dur * 0.6);
    g.gain.linearRampToValueAtTime(0, t + dur);
    const [F1, F2] = vowel || [700, 1150];          // «а»
    for (const [F, q, a] of [[F1, 6, 1], [F2, 8, 0.6]]) {
      const bp = ctx.createBiquadFilter(); bp.type = 'bandpass'; bp.frequency.value = F; bp.Q.value = q;
      const fg = ctx.createGain(); fg.gain.value = a;
      o.connect(bp); bp.connect(fg); fg.connect(g);
    }
    g.connect(this.sfxBus);
    o.start(t); vib.start(t); o.stop(t + dur + 0.05); vib.stop(t + dur + 0.05);
  },

  grunt() {
    if (!this.may('grunt', 0.25)) return;
    const t = this.ctx.currentTime, f = 130 + Math.random() * 60;
    this.voice(t, f, f * 0.7, 0.28, 0.14, [550, 950]);
  },

  shout() {
    if (!this.may('shout', 0.6)) return;
    const t = this.ctx.currentTime;
    for (let i = 0; i < 6; i++) {
      const f = 150 + Math.random() * 90;
      this.voice(t + Math.random() * 0.25, f, f * (1.15 + Math.random() * 0.15), 0.7 + Math.random() * 0.3, 0.05, [650 + Math.random() * 100, 1100 + Math.random() * 150]);
    }
  },

  horn() {
    if (!this.may('horn', 1)) return;
    const t = this.ctx.currentTime, ctx = this.ctx;
    for (const [f, dly] of [[196, 0], [294, 0.35], [392, 0.7]]) {
      const o = ctx.createOscillator(); o.type = 'sawtooth'; o.frequency.value = f;
      const lp = ctx.createBiquadFilter(); lp.type = 'lowpass'; lp.Q.value = 2;
      lp.frequency.setValueAtTime(300, t + dly); lp.frequency.linearRampToValueAtTime(1600, t + dly + 0.25);
      const g = ctx.createGain(); g.gain.setValueAtTime(0, t + dly); g.gain.linearRampToValueAtTime(0.08, t + dly + 0.12);
      g.gain.setValueAtTime(0.08, t + dly + 0.9); g.gain.linearRampToValueAtTime(0, t + dly + 1.3);
      o.connect(lp); lp.connect(g); g.connect(this.sfxBus);
      o.start(t + dly); o.stop(t + dly + 1.4);
    }
  },

  fanfare(win) {
    if (!this.ready) return;
    const t = this.ctx.currentTime + 0.1, ctx = this.ctx;
    const seq = win ? [[392, 0, 0.18], [523, 0.2, 0.18], [659, 0.4, 0.18], [784, 0.6, 0.9]] : [[294, 0, 0.6], [277, 0.55, 0.6], [220, 1.1, 1.2]];
    for (const [f, dly, len] of seq) {
      const o = ctx.createOscillator(); o.type = 'sawtooth'; o.frequency.value = f;
      const lp = ctx.createBiquadFilter(); lp.type = 'lowpass'; lp.frequency.value = win ? 2200 : 900;
      const g = ctx.createGain(); g.gain.setValueAtTime(0, t + dly); g.gain.linearRampToValueAtTime(0.13, t + dly + 0.03);
      g.gain.setValueAtTime(0.13, t + dly + len * 0.8); g.gain.linearRampToValueAtTime(0, t + dly + len);
      o.connect(lp); lp.connect(g); g.connect(this.sfxBus);
      o.start(t + dly); o.stop(t + dly + len + 0.05);
    }
  },

  // Бой начался: музыка города тише, вступают барабаны, отряд кричит
  battleStart() {
    if (!this.ready) return;
    this.battleDuck = 0.25;
    this.setVolumes();
    this.drums = { next: this.ctx.currentTime + 0.4, beat: 60 / 84, n: 0 };
    this.shout();
  },

  battleEnd(win) {
    this.drums = null;
    this.battleDuck = 1;
    this.setVolumes();
    this.fanfare(win);
  },

  scheduleDrums(now, ahead) {
    const D = this.drums;
    while (D.next < ahead) {
      const t = D.next, pos = D.n % 8;
      if (pos === 0 || pos === 4) this.drum(t, 0.3, 62);
      if (pos === 6 && Math.random() < 0.6) { this.drum(t, 0.16, 75); this.drum(t + D.beat / 2, 0.18, 70); }
      if (pos === 2 || pos === 7) this.drum(t, 0.08, 140, true);
      D.n++;
      D.next += D.beat;
    }
  },

  drum(t, peak, f, small) {
    this.tone(t, f * 1.6, this.sfxBus, { peak: peak * this.music, attack: 0.003, tau: small ? 0.05 : 0.16, to: f, glide: 0.08, dur: 0.8 });
    this.noise(t, 0.08, this.sfxBus, { type: 'lowpass', freq: small ? 2500 : 500, q: 0.6, peak: peak * 0.4 * this.music, tau: small ? 0.02 : 0.05 });
  },
};
