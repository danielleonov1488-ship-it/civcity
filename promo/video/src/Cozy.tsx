// Спокойный вертикальный ролик (~41 с): один день в городе под своё тихое фортепиано игры.
// Музыка — 72 удара в минуту, такт ровно 100 кадров; каждый кадр живёт такт и мягко перетекает в следующий.
import React from "react";
import { AbsoluteFill, Audio, Easing, interpolate, OffthreadVideo, Sequence, staticFile, useCurrentFrame } from "remotion";
import { theme } from "./theme";
import { Grain, Wordmark } from "./components";

const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;
const BAR = 100;
const LEAD = 4;          // в музыке первая нота через 0,12 с
const XF = 24;           // длина наплыва между кадрами
const soft = Easing.bezier(0.33, 0, 0.2, 1);
export const COZY_FRAMES = 1245;

type Scene = { k: number; n?: number; src: string; from: number; rate?: number; zoom?: [number, number]; origin?: string; look?: string; blur?: number; dim?: number };
const at = (k: number) => LEAD + k * BAR;

const SCENES: Scene[] = [
  { k: 0, src: "street_c", from: 0 },
  { k: 1, src: "build_v", from: 30, rate: 1.7 },
  { k: 2, src: "garden_c", from: 10 },
  { k: 3, src: "catsit_c", from: 20, zoom: [1.12, 1.2], origin: "47% 56%" },
  { k: 4, src: "forum_c", from: 20 },
  { k: 5, src: "pond_c", from: 30 },
  { k: 6, src: "sunset_c", from: 40, look: "saturate(1.08)" },
  { k: 7, src: "dusk_c", from: 120 },
  { k: 8, src: "night_c", from: 40, look: "brightness(1.1) hue-rotate(-6deg)" },
  { k: 9, n: 2, src: "finale_c", from: 10 },
  { k: 11, n: 1.45, src: "finale_c", from: 236, blur: 10, dim: 0.5, zoom: [1.1, 1.16] },
];

type Line = { text: string; gold?: string };
type Cap = { k: number; n?: number; lines: Line[]; stagger?: number };
const CAPS: Cap[] = [
  { k: 0, lines: [{ text: "Улицы —" }, { text: "как нарисуешь.", gold: "нарисуешь." }] },
  { k: 1, lines: [{ text: "Дома вырастают" }, { text: "сами.", gold: "сами." }] },
  { k: 2, lines: [{ text: "Сады, фонтаны," }, { text: "тишина.", gold: "тишина." }] },
  { k: 3, lines: [{ text: "Кошки греются" }, { text: "на солнце.", gold: "солнце." }] },
  { k: 4, lines: [{ text: "Неспешная жизнь" }, { text: "Рима.", gold: "Рима." }] },
  { k: 6, lines: [{ text: "Тёплые закаты.", gold: "закаты." }] },
  { k: 7, lines: [{ text: "В окнах" }, { text: "зажигается свет.", gold: "свет." }] },
  { k: 8, lines: [{ text: "Спокойной ночи," }, { text: "Рим.", gold: "Рим." }] },
  { k: 9, n: 2, stagger: 40, lines: [{ text: "Строй." }, { text: "Украшай." }, { text: "Отдыхай.", gold: "Отдыхай." }] },
];

const Shot: React.FC<Scene & { dur: number }> = ({ src, from, rate = 1, zoom = [1, 1.05], origin = "50% 50%", look, blur, dim, dur }) => {
  const frame = useCurrentFrame();
  const fade = Math.min(interpolate(frame, [0, XF], [0, 1], { ...clamp, easing: soft }), interpolate(frame, [dur - XF, dur], [1, 0], { ...clamp, easing: soft }));
  const scale = interpolate(frame, [0, dur], zoom, { ...clamp, easing: soft });
  const filter = [blur ? `blur(${blur}px)` : "", look || ""].join(" ").trim() || undefined;
  return (
    <AbsoluteFill style={{ opacity: fade }}>
      <AbsoluteFill style={{ transform: `scale(${scale})`, transformOrigin: origin, filter }}>
        <OffthreadVideo src={staticFile(`shots/${src}.mp4`)} trimBefore={from} playbackRate={rate} muted style={{ width: "100%", height: "100%", objectFit: "cover" }} />
      </AbsoluteFill>
      {dim ? <AbsoluteFill style={{ background: `rgba(14,9,5,${dim})` }} /> : null}
    </AbsoluteFill>
  );
};

// Подпись проявляется из лёгкой дымки, строка за строкой, и так же тихо уходит
const Caption: React.FC<Cap & { dur: number }> = ({ lines, dur, stagger = 12 }) => {
  const frame = useCurrentFrame();
  const out = interpolate(frame, [dur - 30, dur - 8], [1, 0], { ...clamp, easing: soft });
  return (
    <AbsoluteFill style={{ alignItems: "center", paddingTop: 470, opacity: out }}>
      <AbsoluteFill style={{ background: "radial-gradient(ellipse 85% 22% at 50% 31%, rgba(20,12,6,0.42), transparent 75%)" }} />
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 4, padding: "0 80px", textAlign: "center" }}>
        {lines.map((ln, i) => {
          const p = interpolate(frame, [18 + i * stagger, 18 + i * stagger + 26], [0, 1], { ...clamp, easing: soft });
          const parts = ln.gold ? ln.text.split(ln.gold) : [ln.text];
          return (
            <div key={i} style={{ fontFamily: theme.fonts.display, fontWeight: 700, fontSize: 92, lineHeight: 1.1, letterSpacing: "-0.025em", color: "#fffaf0",
              opacity: p, filter: `blur(${(1 - p) * 10}px)`, transform: `translateY(${(1 - p) * 18}px)`, textShadow: "0 3px 24px rgba(30,18,8,0.55)" }}>
              {parts[0]}{ln.gold ? <span style={{ color: "#f6cf74", textShadow: "0 0 30px rgba(246,207,116,0.45), 0 3px 24px rgba(30,18,8,0.5)" }}>{ln.gold}</span> : null}{parts[1] || ""}
            </div>
          );
        })}
      </div>
    </AbsoluteFill>
  );
};

// Золотые пылинки в солнечном свете; ночью — светлячки
const rnd = (i: number) => { const x = Math.sin(i * 127.1 + 311.7) * 43758.5453; return x - Math.floor(x); };
const Motes: React.FC = () => {
  const frame = useCurrentFrame();
  const night = interpolate(frame, [at(7) + 40, at(8), at(9), at(9) + 20], [0, 1, 1, 0], clamp);
  const day = 1 - night;
  return (
    <AbsoluteFill style={{ pointerEvents: "none", mixBlendMode: "screen" }}>
      {Array.from({ length: 34 }, (_, i) => {
        const x0 = rnd(i) * 1080, y0 = rnd(i + 50) * 1920, sp = 0.15 + rnd(i + 99) * 0.35, sz = 4 + rnd(i + 7) * 10;
        const x = x0 + Math.sin(frame / (40 + rnd(i + 3) * 40) + i) * 30;
        const y = ((y0 - frame * sp * 2) % 1920 + 1920) % 1920;
        const tw = 0.4 + 0.6 * Math.abs(Math.sin(frame / (18 + rnd(i + 11) * 20) + i * 2));
        const col = night > 0.5 ? "rgba(214,240,140,1)" : "rgba(255,226,160,1)";
        return <div key={i} style={{ position: "absolute", left: x, top: y, width: sz, height: sz, borderRadius: "50%", background: col,
          opacity: tw * (0.22 * day + 0.55 * night), filter: `blur(${sz * 0.35}px)`, boxShadow: `0 0 ${sz * 2}px ${col}` }} />;
      })}
    </AbsoluteFill>
  );
};

// Финал: название, тихая строка, адрес
const EndCard: React.FC = () => {
  const frame = useCurrentFrame();
  const p = (f0: number) => interpolate(frame, [f0, f0 + 28], [0, 1], { ...clamp, easing: soft });
  const a = p(30), b = p(48), c = p(62);
  return (
    <AbsoluteFill style={{ justifyContent: "center", alignItems: "center", paddingBottom: 260 }}>
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 34 }}>
        <Wordmark size={170} delay={6} />
        <div style={{ fontFamily: theme.fonts.body, fontWeight: 600, fontSize: 46, color: "#f3e9d6", textAlign: "center", lineHeight: 1.25,
          opacity: a, filter: `blur(${(1 - a) * 8}px)` }}>Уютный градостроитель<br />про Древний Рим</div>
        <div style={{ opacity: b, transform: `translateY(${(1 - b) * 14}px)`, padding: "20px 50px", borderRadius: 999, background: "rgba(255,248,232,0.94)",
          color: theme.colors.bg, fontFamily: theme.fonts.display, fontWeight: 800, fontSize: 66, letterSpacing: "-0.03em" }}>civcity.ru</div>
        <div style={{ opacity: c, fontFamily: theme.fonts.body, fontWeight: 500, fontSize: 38, color: "#e6dac2" }}>бесплатно · в браузере и на ПК</div>
      </div>
    </AbsoluteFill>
  );
};

export const Cozy: React.FC = () => {
  const frame = useCurrentFrame();
  const end = at(11);
  return (
    <AbsoluteFill style={{ background: "#120c08" }}>
      {SCENES.map((s, i) => {
        const a = Math.max(0, at(s.k) - XF / 2), b = Math.min(COZY_FRAMES, at(s.k + (s.n || 1)) + XF / 2);
        return <Sequence key={i} from={a} durationInFrames={b - a}><Shot {...s} dur={b - a} /></Sequence>;
      })}
      {/* тёплый свет поверх всего: мягкий тон, лёгкое затемнение к краям */}
      <AbsoluteFill style={{ backgroundColor: "#f2b552", mixBlendMode: "soft-light", opacity: 0.14, pointerEvents: "none" }} />
      <Motes />
      <AbsoluteFill style={{ background: "radial-gradient(ellipse at 50% 45%, transparent 55%, rgba(25,14,6,0.42) 100%)", pointerEvents: "none" }} />
      {CAPS.map((c, i) => {
        const a = at(c.k), d = (c.n || 1) * BAR;
        return <Sequence key={i} from={a} durationInFrames={d}><Caption {...c} dur={d} /></Sequence>;
      })}
      <Sequence from={end} durationInFrames={COZY_FRAMES - end}><EndCard /></Sequence>
      <Grain />
      <AbsoluteFill style={{ background: "#000", opacity: interpolate(frame, [COZY_FRAMES - 30, COZY_FRAMES], [0, 1], clamp), pointerEvents: "none" }} />
      <Audio src={staticFile("music/cozy_music.wav")} volume={f => interpolate(f, [COZY_FRAMES - 45, COZY_FRAMES], [1, 0], clamp)} />
      <Audio src={staticFile("music/cozy_amb.wav")} volume={f => interpolate(f, [COZY_FRAMES - 45, COZY_FRAMES], [1, 0], clamp)} />
    </AbsoluteFill>
  );
};
