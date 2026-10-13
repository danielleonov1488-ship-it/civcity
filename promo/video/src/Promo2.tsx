// Промо-ролик CivCity v2 (новая графика, Godot): один день города — утро, дела, золотой час, сумерки, ночь.
// Музыка — наша классика из игры: Григ, «Утро» (Peer Gynt, запись Musopen Symphony — общественное достояние).
// Широкий ролик идёт по музыке с начала до естественного затихания на 77,4 с; вертикальный берёт её с 35,25 с
// (нарастание → кульминация → то же затихание). Клипы сняты в игре: godot/scripts/promo_cam.gd → public2/shots2.
// Мягкие наплывы: новый кадр проявляется поверх старого (без провала в темноту).
// Рендер: bash promo/build_v2.sh [wide|vertical] (public2, временные файлы на диске D, без видеокарты).
import React from "react";
import { AbsoluteFill, Audio, continueRender, delayRender, Easing, Img, interpolate, OffthreadVideo, Sequence, staticFile, useCurrentFrame, useVideoConfig } from "remotion";

const FPS = 30;
const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;
const soft = Easing.bezier(0.33, 0, 0.2, 1);
const s2f = (s: number) => Math.round(s * FPS);

// ---------- шрифты игры (Philosopher — заголовки, Alegreya Sans — подписи) ----------
const FONT_TITLE = "CivPhilosopher";
const FONT_BODY = "CivAlegreya";
// грузим один раз при загрузке модуля (в каждой вкладке рендера), кадры ждут шрифтов
if (typeof window !== "undefined" && typeof FontFace !== "undefined") {
  const h = delayRender("game fonts");
  const faces = [
    new FontFace(FONT_TITLE, `url(${staticFile("fonts/Philosopher-Bold.ttf")})`, { weight: "700" }),
    new FontFace(FONT_BODY, `url(${staticFile("fonts/AlegreyaSans-Medium.ttf")})`, { weight: "500" }),
    new FontFace(FONT_BODY, `url(${staticFile("fonts/AlegreyaSans-Bold.ttf")})`, { weight: "700" }),
  ];
  Promise.all(faces.map((f) => f.load().then((ff) => (document.fonts as unknown as { add: (x: FontFace) => void }).add(ff)))).then(() => continueRender(h), () => continueRender(h));
}

// ---------- монтажный лист ----------
type Shot = { from: number; to: number; src: string; at: number; zoom?: [number, number]; origin?: string; look?: string; endcard?: boolean };
type Line = { text: string; gold?: string };
type Cap = { from: number; to: number; lines: Line[]; big?: boolean; sub?: string };
type Cut = { frames: number; music: number; fadeIn: number; shots: Shot[]; caps: Cap[]; endFrom: number; nightFrom: number; vertical: boolean };

// широкий 2560×1440, 78,6 с
const WIDE: Cut = {
  frames: s2f(78.6), music: 0, fadeIn: 0.05, vertical: false, endFrom: 72.8, nightFrom: 66.5,
  shots: [
    { from: 0.0, to: 9.6, src: "arrival", at: 0.2, zoom: [1.0, 1.03] },
    { from: 9.6, to: 16.2, src: "street", at: 1.5 },
    { from: 16.2, to: 23.6, src: "grow", at: 0.3, zoom: [1.0, 1.035] },
    { from: 23.6, to: 29.6, src: "market", at: 1.5 },
    { from: 29.6, to: 36.0, src: "cat", at: 0.6, zoom: [1.0, 1.04] },
    { from: 36.0, to: 42.3, src: "villa", at: 1.0 },
    { from: 42.3, to: 47.3, src: "forum", at: 2.0 },
    { from: 47.3, to: 58.3, src: "pullback", at: 0.0, zoom: [1.0, 1.02] },
    { from: 58.3, to: 65.2, src: "temple", at: 1.0 },
    { from: 65.2, to: 71.4, src: "dusk", at: 3.0, look: "brightness(1.04)" },
    { from: 71.4, to: 78.6, src: "night", at: 0.5, look: "brightness(1.12) saturate(1.05)", endcard: true },
  ],
  caps: [
    { from: 1.8, to: 8.6, lines: [{ text: "Новые жители" }, { text: "уже в пути.", gold: "в пути." }] },
    { from: 10.6, to: 15.6, lines: [{ text: "Улицы —" }, { text: "как нарисуешь.", gold: "нарисуешь." }] },
    { from: 17.4, to: 23.0, lines: [{ text: "Дом за домом —" }, { text: "город растёт.", gold: "растёт." }] },
    { from: 24.6, to: 29.2, lines: [{ text: "Каждый житель" }, { text: "живёт своей жизнью.", gold: "своей жизнью." }] },
    { from: 31.2, to: 35.6, lines: [{ text: "И кошкам" }, { text: "здесь хорошо.", gold: "хорошо." }] },
    { from: 37.0, to: 41.8, lines: [{ text: "Сады, виллы," }, { text: "фонтаны.", gold: "фонтаны." }] },
    { from: 48.4, to: 57.4, big: true, lines: [{ text: "Построй свой Рим.", gold: "Рим." }], sub: "Уютный градостроитель про Древний Рим" },
    { from: 59.4, to: 64.6, lines: [{ text: "Тёплые закаты.", gold: "закаты." }] },
    { from: 66.2, to: 70.9, lines: [{ text: "В окнах" }, { text: "зажигается свет.", gold: "свет." }] },
  ],
};

// вертикальный 1080×1920, 42,3 с: музыка с 35,25 с, кульминация (47,25 с) — на 12-й секунде, на отлёте камеры
const VERTICAL: Cut = {
  frames: s2f(42.3), music: 35.25, fadeIn: 0.6, vertical: true, endFrom: 38.6, nightFrom: 34.5,
  shots: [
    { from: 0.0, to: 3.4, src: "arrival_v", at: 1.0 },
    { from: 3.4, to: 7.0, src: "street_v", at: 1.0 },
    { from: 7.0, to: 12.0, src: "grow_v", at: 0.3, zoom: [1.0, 1.04] },
    { from: 12.0, to: 19.5, src: "pullback_v", at: 0.2, zoom: [1.0, 1.02] },
    { from: 19.5, to: 24.5, src: "market_v", at: 1.0 },
    { from: 24.5, to: 30.0, src: "cat_v", at: 0.8, zoom: [1.16, 1.22], origin: "42% 50%" },
    { from: 30.0, to: 34.5, src: "temple_v", at: 1.0 },
    { from: 34.5, to: 38.4, src: "dusk_v", at: 2.5, look: "brightness(1.04)" },
    { from: 38.4, to: 42.3, src: "night_v", at: 0.5, look: "brightness(1.12) saturate(1.05)", endcard: true },
  ],
  caps: [
    { from: 0.5, to: 3.2, lines: [{ text: "Новые жители" }, { text: "уже в пути.", gold: "в пути." }] },
    { from: 3.9, to: 6.8, lines: [{ text: "Улицы —" }, { text: "как нарисуешь.", gold: "нарисуешь." }] },
    { from: 7.6, to: 11.8, lines: [{ text: "Дом за домом —" }, { text: "город растёт.", gold: "растёт." }] },
    { from: 12.9, to: 19.1, big: true, lines: [{ text: "Построй" }, { text: "свой Рим.", gold: "Рим." }], sub: "Уютный градостроитель" },
    { from: 20.0, to: 24.2, lines: [{ text: "Каждый житель" }, { text: "живёт своей" }, { text: "жизнью.", gold: "жизнью." }] },
    { from: 25.0, to: 29.6, lines: [{ text: "И кошкам" }, { text: "здесь хорошо.", gold: "хорошо." }] },
    { from: 30.5, to: 34.2, lines: [{ text: "Тёплые закаты.", gold: "закаты." }] },
    { from: 35.0, to: 38.3, lines: [{ text: "В окнах" }, { text: "зажигается свет.", gold: "свет." }] },
  ],
};

const XF = 30; // наплыв — 1 секунда

// ---------- кадр из игры ----------
const ShotView: React.FC<Shot & { dur: number; first: boolean; endAt: number }> = ({ src, at, zoom = [1.0, 1.04], origin = "50% 50%", look, dur, first, endcard, endAt }) => {
  const frame = useCurrentFrame();
  // новый кадр проявляется поверх прежнего; самый первый — из темноты, чуть медленнее
  const fade = interpolate(frame, [0, first ? 40 : XF], [0, 1], { ...clamp, easing: soft });
  const scale = interpolate(frame, [0, dur], zoom, { ...clamp, easing: soft });
  // финальная заставка: город мягко уходит в размытие и тень
  const e = endcard ? interpolate(frame, [endAt, endAt + 45], [0, 1], { ...clamp, easing: soft }) : 0;
  const filter = [look || "", e > 0 ? `blur(${(e * 14).toFixed(2)}px)` : ""].join(" ").trim() || undefined;
  return (
    <AbsoluteFill style={{ opacity: fade, overflow: "hidden" }}>
      <AbsoluteFill style={{ transform: `scale(${scale * (1 + e * 0.04)})`, transformOrigin: origin, filter }}>
        <OffthreadVideo src={staticFile(`shots2/${src}.mp4`)} trimBefore={s2f(at)} muted style={{ width: "100%", height: "100%", objectFit: "cover" }} />
      </AbsoluteFill>
      {e > 0 ? <AbsoluteFill style={{ background: `rgba(14,9,5,${0.45 * e})` }} /> : null}
    </AbsoluteFill>
  );
};

// ---------- подписи: строка за строкой из лёгкой дымки, тихо уходят ----------
const Caption: React.FC<Cap & { dur: number; vertical: boolean }> = ({ lines, dur, big, sub, vertical }) => {
  const frame = useCurrentFrame();
  const { width } = useVideoConfig();
  const k = width / (vertical ? 1080 : 2560);
  const out = interpolate(frame, [dur - 30, dur - 6], [1, 0], { ...clamp, easing: soft });
  const size = (vertical ? (big ? 118 : 84) : big ? 150 : 96) * (vertical ? k : k);
  const stagger = big ? 16 : 12;
  const subP = interpolate(frame, [26 + lines.length * stagger, 56 + lines.length * stagger], [0, 1], { ...clamp, easing: soft });
  // где стоит подпись: широкий — снизу по центру (большая — в середине), вертикальный — в верхней трети
  const pos: React.CSSProperties = vertical
    ? { justifyContent: "flex-start", paddingTop: big ? 560 * k : 300 * k }
    : big ? { justifyContent: "center" } : { justifyContent: "flex-end", paddingBottom: 150 * k };
  const scrim = vertical
    ? `radial-gradient(ellipse 90% ${big ? 26 : 20}% at 50% ${big ? 36 : 23}%, rgba(20,12,6,0.46), transparent 75%)`
    : big
      ? "radial-gradient(ellipse 58% 36% at 50% 50%, rgba(20,12,6,0.52), transparent 78%)"
      : "radial-gradient(ellipse 52% 30% at 50% 84%, rgba(20,12,6,0.5), transparent 78%)";
  return (
    <AbsoluteFill style={{ opacity: out }}>
      <AbsoluteFill style={{ background: scrim, opacity: interpolate(frame, [0, 24], [0, 1], { ...clamp, easing: soft }) }} />
      <AbsoluteFill style={{ alignItems: "center", ...pos }}>
        <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 2 * k, padding: `0 ${70 * k}px`, textAlign: "center" }}>
          {lines.map((ln, i) => {
            const p = interpolate(frame, [14 + i * stagger, 14 + i * stagger + 30], [0, 1], { ...clamp, easing: soft });
            const parts = ln.gold ? ln.text.split(ln.gold) : [ln.text];
            return (
              <div key={i} style={{ fontFamily: FONT_TITLE, fontWeight: 700, fontSize: size, lineHeight: 1.12, letterSpacing: "0.005em", color: "#fffaf0",
                opacity: p, filter: `blur(${(1 - p) * 10 * k}px)`, transform: `translateY(${(1 - p) * 18 * k}px)`, textShadow: `0 ${3 * k}px ${26 * k}px rgba(30,18,8,0.6)` }}>
                {parts[0]}{ln.gold ? <span style={{ color: "#f6cf74", textShadow: `0 0 ${32 * k}px rgba(246,207,116,0.45), 0 ${3 * k}px ${24 * k}px rgba(30,18,8,0.55)` }}>{ln.gold}</span> : null}{parts[1] || ""}
              </div>
            );
          })}
          {sub ? (
            <div style={{ marginTop: 18 * k, fontFamily: FONT_BODY, fontWeight: 500, fontSize: (vertical ? 48 : 62) * k, letterSpacing: "0.02em", color: "#f3e6cc",
              opacity: subP, filter: `blur(${(1 - subP) * 6 * k}px)`, textShadow: `0 ${2 * k}px ${18 * k}px rgba(30,18,8,0.65)` }}>{sub}</div>
          ) : null}
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};

// ---------- золотые пылинки днём, светлячки ночью ----------
const rnd = (i: number) => { const x = Math.sin(i * 127.1 + 311.7) * 43758.5453; return x - Math.floor(x); };
const Motes: React.FC<{ nightFrom: number }> = ({ nightFrom }) => {
  const frame = useCurrentFrame();
  const { width, height } = useVideoConfig();
  const k = Math.max(width, height) / 1920;
  const night = interpolate(frame, [s2f(nightFrom), s2f(nightFrom) + 90], [0, 1], clamp);
  return (
    <AbsoluteFill style={{ pointerEvents: "none", mixBlendMode: "screen" }}>
      {Array.from({ length: 30 }, (_, i) => {
        const x0 = rnd(i) * width, y0 = rnd(i + 50) * height, sp = (0.15 + rnd(i + 99) * 0.35) * k, sz = (4 + rnd(i + 7) * 9) * k;
        const x = x0 + Math.sin(frame / (40 + rnd(i + 3) * 40) + i) * 30 * k;
        const y = ((y0 - frame * sp * 2) % height + height) % height;
        const tw = 0.4 + 0.6 * Math.abs(Math.sin(frame / (18 + rnd(i + 11) * 20) + i * 2));
        const col = night > 0.5 ? "rgba(214,240,140,1)" : "rgba(255,226,160,1)";
        return <div key={i} style={{ position: "absolute", left: x, top: y, width: sz, height: sz, borderRadius: "50%", background: col,
          opacity: tw * (0.16 * (1 - night) + 0.5 * night), filter: `blur(${sz * 0.35}px)`, boxShadow: `0 0 ${sz * 2}px ${col}` }} />;
      })}
    </AbsoluteFill>
  );
};

const Grain: React.FC = () => {
  const frame = useCurrentFrame();
  const noise = `url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='220' height='220'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='2'/%3E%3C/filter%3E%3Crect width='220' height='220' filter='url(%23n)' opacity='0.5'/%3E%3C/svg%3E")`;
  return <AbsoluteFill style={{ pointerEvents: "none", backgroundImage: noise, backgroundSize: "220px",
    backgroundPosition: `${(frame * 7) % 220}px ${(frame * 13) % 220}px`, opacity: 0.045, mixBlendMode: "overlay" }} />;
};

// ---------- финал: логотип, строка, адрес ----------
const EndCard: React.FC<{ vertical: boolean }> = ({ vertical }) => {
  const frame = useCurrentFrame();
  const { width } = useVideoConfig();
  const k = width / (vertical ? 1080 : 2560);
  const p = (f0: number, d = 30) => interpolate(frame, [f0, f0 + d], [0, 1], { ...clamp, easing: soft });
  const logo = p(10, 40), a = p(36), b = p(52);
  const logoW = (vertical ? 860 : 1050) * k;
  return (
    <AbsoluteFill style={{ justifyContent: "center", alignItems: "center", paddingBottom: (vertical ? 220 : 40) * k }}>
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: (vertical ? 40 : 34) * k }}>
        <Img src={staticFile("logo.png")} style={{ width: logoW, opacity: logo, transform: `scale(${0.94 + 0.06 * logo})`, filter: `blur(${(1 - logo) * 8 * k}px) drop-shadow(0 ${10 * k}px ${40 * k}px rgba(0,0,0,0.5))` }} />
        <div style={{ fontFamily: FONT_TITLE, fontWeight: 700, fontSize: (vertical ? 58 : 66) * k, color: "#f6ecd8", textAlign: "center", lineHeight: 1.2,
          opacity: a, filter: `blur(${(1 - a) * 8 * k}px)`, textShadow: `0 ${2 * k}px ${20 * k}px rgba(20,12,6,0.7)` }}>
          {vertical ? <>Уютный градостроитель<br />про Древний Рим</> : "Уютный градостроитель про Древний Рим"}
        </div>
        <div style={{ opacity: b, transform: `translateY(${(1 - b) * 14 * k}px)`, padding: `${20 * k}px ${54 * k}px`, borderRadius: 999,
          background: "linear-gradient(180deg, #fff6e2, #f1dfb8)", boxShadow: `0 ${8 * k}px ${30 * k}px rgba(0,0,0,0.35), inset 0 0 0 ${2 * k}px rgba(185,130,44,0.55)`,
          color: "#3a2412", fontFamily: FONT_BODY, fontWeight: 700, fontSize: (vertical ? 60 : 64) * k, letterSpacing: "0.01em" }}>
          Скачать на <span style={{ color: "#9a5b12" }}>civcity.ru</span>
        </div>
      </div>
    </AbsoluteFill>
  );
};

const Film: React.FC<{ cut: Cut }> = ({ cut }) => {
  const frame = useCurrentFrame();
  const end = s2f(cut.endFrom);
  return (
    <AbsoluteFill style={{ background: "#120c08" }}>
      {cut.shots.map((s, i) => {
        const a = Math.max(0, s2f(s.from) - (i === 0 ? 0 : XF / 2));
        const b = Math.min(cut.frames, s2f(s.to) + XF / 2);
        return (
          <Sequence key={i} from={a} durationInFrames={b - a}>
            <ShotView {...s} dur={b - a} first={i === 0} endAt={end - a} />
          </Sequence>
        );
      })}
      {/* тёплый свет поверх всего и мягкое затемнение к краям */}
      <AbsoluteFill style={{ backgroundColor: "#f2b552", mixBlendMode: "soft-light", opacity: 0.1, pointerEvents: "none" }} />
      <Motes nightFrom={cut.nightFrom} />
      <AbsoluteFill style={{ background: "radial-gradient(ellipse at 50% 45%, transparent 58%, rgba(25,14,6,0.38) 100%)", pointerEvents: "none" }} />
      {cut.caps.map((c, i) => {
        const a = s2f(c.from), d = s2f(c.to) - a;
        return <Sequence key={i} from={a} durationInFrames={d}><Caption {...c} dur={d} vertical={cut.vertical} /></Sequence>;
      })}
      <Sequence from={end} durationInFrames={cut.frames - end}><EndCard vertical={cut.vertical} /></Sequence>
      <Grain />
      <AbsoluteFill style={{ background: "#000", pointerEvents: "none",
        opacity: Math.max(interpolate(frame, [0, 24], [1, 0], clamp), interpolate(frame, [cut.frames - 36, cut.frames], [0, 1], clamp)) }} />
      <Audio src={staticFile("music/morning-mood.wav")} trimBefore={s2f(cut.music)}
        volume={(f) => interpolate(f, [0, Math.max(1, s2f(cut.fadeIn)), cut.frames - 40, cut.frames], [0, 1, 1, 0], clamp)} />
    </AbsoluteFill>
  );
};

export const PROMO2_FRAMES = WIDE.frames;
export const VERTICAL2_FRAMES = VERTICAL.frames;
export const Promo2: React.FC = () => <Film cut={WIDE} />;
export const Vertical2: React.FC = () => <Film cut={VERTICAL} />;
