/* Музыка для спокойного вертикального ролика: своё фортепиано игры (js/audio.js), пьеса написана нотами.
   72 удара в минуту → такт ровно 100 кадров при 30 к/с; 12 тактов = 40 с, потом звенит последний аккорд.
   Рендерится в OfflineAudioContext и уходит в приёмник (promo/capture.py → promo/audio/<имя>.wav).
   Запуск в странице игры: (0, eval)(await (await fetch('/promo/cozy-music.js')).text()); await CozyMusic.render(); */
window.CozyMusic = {
  BPM: 72,
  T0: 0.12,          // крошечный зазор перед первой нотой
  LENGTH: 44,        // секунд в файле (с хвостом зала)

  // Аккорды по тактам: название → голоса (MIDI), от баса вверх. «|» — два аккорда в такте
  CHORDS: [
    ['Dmaj9'], ['Bm7'], ['Gmaj7'], ['Asus4', 'A'], ['Dmaj9'], ['F#m7'], ['Gmaj7'], ['Em7', 'A7sus'], ['Gmaj7'], ['A6'], ['Bm7', 'Gmaj7'], ['Dmaj9'],
  ],
  VOICE: {
    Dmaj9: [50, 57, 64, 66, 69], Bm7: [47, 54, 57, 62, 66], Gmaj7: [43, 50, 54, 59, 62], Asus4: [45, 52, 57, 62, 64], A: [45, 52, 57, 61, 64],
    'F#m7': [42, 49, 52, 57, 61], Em7: [40, 47, 50, 55, 59], A7sus: [45, 52, 55, 57, 62], A6: [45, 52, 54, 57, 61],
  },
  // Мелодия: [такт, доля, нота, длина в долях, сила]
  MELODY: [
    [1, 2, 78, 2, 0.26],
    [2, 0, 71, 1.5, 0.4], [2, 1.5, 69, 0.5, 0.32], [2, 2, 66, 2, 0.36],
    [3, 0, 74, 1.5, 0.4], [3, 1.5, 73, 2.5, 0.34],
    [4, 0, 78, 1.5, 0.44], [4, 1.5, 76, 0.5, 0.34], [4, 2, 74, 1, 0.38], [4, 3, 69, 1, 0.32],
    [5, 0, 73, 1.5, 0.42], [5, 1.5, 76, 0.5, 0.34], [5, 2, 69, 2, 0.36],
    [6, 0, 71, 1, 0.4], [6, 1, 74, 1, 0.38], [6, 2, 78, 1.5, 0.44], [6, 3.5, 76, 0.5, 0.3],
    [7, 0, 74, 2, 0.42], [7, 2, 76, 1, 0.36], [7, 3, 74, 1, 0.32],
    [8, 0, 83, 1.5, 0.42], [8, 1.5, 81, 0.5, 0.32], [8, 2, 78, 2, 0.38],
    [9, 0, 76, 1.5, 0.42], [9, 1.5, 78, 0.5, 0.34], [9, 2, 73, 2, 0.38],
    [10, 0, 78, 1.5, 0.44], [10, 1.5, 74, 0.5, 0.34], [10, 2, 71, 1, 0.38], [10, 3, 69, 1, 0.34],
    [11, 0, 74, 6, 0.4], [11, 2, 81, 3, 0.22],
  ],

  notes() {
    const beat = 60 / this.BPM, bar = beat * 4, out = [];
    const at = (k, b) => this.T0 + k * bar + b * beat;
    this.CHORDS.forEach((ch, k) => {
      const last = k === this.CHORDS.length - 1;
      if (last) {
        // последний аккорд — мягко «прокатить» снизу вверх и оставить звенеть
        this.VOICE[ch[0]].forEach((m, i) => out.push({ t: at(k, 0) + i * 0.07, m, v: i ? 0.26 : 0.36, l: 7 }));
        out.push({ t: at(k, 0), pad: [62, 66, 69], l: 5 });
        return;
      }
      const halves = ch.length === 2;
      ch.forEach((name, h) => {
        const v = this.VOICE[name], b0 = halves ? h * 2 : 0;
        out.push({ t: at(k, b0), m: v[0], v: 0.36, l: (halves ? 2 : 4) * beat });
        // перебор восьмыми; в первом такте — четвертями, тише
        const pat = k === 0 ? [[1, 1], [2, 2], [3, 3]] : halves ? [[1, 0.5], [2, 1], [3, 1.5]] : [[1, 0.5], [2, 1], [3, 1.5], [4, 2], [3, 2.5], [2, 3], [1, 3.5]];
        for (const [i, b] of pat) out.push({ t: at(k, b0 + b), m: v[i], v: (k === 0 ? 0.2 : 0.23) + Math.random() * 0.05, l: beat * 1.4 });
      });
      // мягкая подложка — со второй половины, по два такта; на 9–11 такте чуть гуще
      if (k === 4 || k === 6 || k >= 8) out.push({ t: at(k, 0), pad: this.VOICE[ch[0]].slice(2, 5), l: k >= 8 ? bar : bar * 2 });
    });
    for (const [k, b, m, l, v] of this.MELODY) out.push({ t: at(k, b), m, v, l: l * beat * 1.1 });
    return out.sort((a, b) => a.t - b.t);
  },

  // Птицы днём (такты 0–6) и сверчки вечером и ночью (такты 7–10) — тихо, как в игре
  ambience() {
    const beat = 60 / this.BPM, bar = beat * 4, out = [];
    const R = mulberry32(2026);
    for (let t = 0.6; t < bar * 6.6; t += 1.4 + R() * 2.2) out.push({ t, bird: 0.35 + R() * 0.45, R: R() });
    for (let t = bar * 7.4; t < bar * 11; t += 0.9 + R() * 1.3) out.push({ t, cricket: 0.4 + R() * 0.4 });
    return out;
  },

  bird(S, t, k, r) {
    const base = 2600 + r * 2400, n = 2 + Math.floor(r * 4);
    for (let i = 0; i < n; i++) {
      const s = t + i * (0.09 + ((r * 7 + i) % 1) * 0.07);
      S.tone(s, base * (0.9 + ((r * 13 + i) % 1) * 0.25), S.ambBus, { peak: 0.05 * k, attack: 0.008, tau: 0.03, to: base * (1.1 + ((r * 3 + i) % 1) * 0.4), glide: 0.06, dur: 0.14 });
    }
  },

  cricket(S, t, k) {
    for (let i = 0; i < 3; i++) for (let j = 0; j < 4; j++) S.tone(t + i * 0.32 + j * 0.035, 4400 + Math.random() * 200, S.ambBus, { peak: 0.022 * k, attack: 0.004, tau: 0.008, dur: 0.04 });
  },

  async renderStem(fill) {
    const S = Sound, keep = { ctx: S.ctx, ready: S.ready, music: S.music, sfx: S.sfx };
    const ctx = new OfflineAudioContext(2, Math.round(44100 * this.LENGTH), 44100);
    S.music = 0.8; S.sfx = 0.8;
    S.setup(ctx);
    fill(S);
    const buf = await ctx.startRendering();
    Object.assign(S, keep);
    return buf;
  },

  wav(buf) {
    const n = buf.length, ch = buf.numberOfChannels, sr = buf.sampleRate;
    const dv = new DataView(new ArrayBuffer(44 + n * ch * 2));
    const str = (o, s) => [...s].forEach((c, i) => dv.setUint8(o + i, c.charCodeAt(0)));
    str(0, 'RIFF'); dv.setUint32(4, 36 + n * ch * 2, true); str(8, 'WAVE'); str(12, 'fmt ');
    dv.setUint32(16, 16, true); dv.setUint16(20, 1, true); dv.setUint16(22, ch, true); dv.setUint32(24, sr, true);
    dv.setUint32(28, sr * ch * 2, true); dv.setUint16(32, ch * 2, true); dv.setUint16(34, 16, true); str(36, 'data'); dv.setUint32(40, n * ch * 2, true);
    const data = [...Array(ch)].map((_, c) => buf.getChannelData(c));
    let o = 44;
    for (let i = 0; i < n; i++) for (let c = 0; c < ch; c++) { dv.setInt16(o, Math.max(-1, Math.min(1, data[c][i])) * 32767, true); o += 2; }
    return dv.buffer;
  },

  async render(sink = 'http://localhost:5192') {
    const music = await this.renderStem(S => { for (const n of this.notes()) n.pad ? S.pad(n.t, n.pad, n.l) : S.piano(n.t, n.m, n.v, n.l); });
    await fetch(`${sink}/wav?shot=cozy_music`, { method: 'POST', body: this.wav(music) });
    const amb = await this.renderStem(S => { for (const a of this.ambience()) a.bird ? this.bird(S, a.t, a.bird, a.R) : this.cricket(S, a.t, a.cricket); });
    await fetch(`${sink}/wav?shot=cozy_amb`, { method: 'POST', body: this.wav(amb) });
    return 'ok';
  },
};
