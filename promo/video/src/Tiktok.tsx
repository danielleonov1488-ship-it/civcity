// Короткий вертикальный ролик для TikTok / Shorts / Reels: ~40 с, монтаж в бит трека, только музыка.
import React from "react";
import { AbsoluteFill, Audio, Easing, interpolate, OffthreadVideo, Sequence, spring, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { theme } from "./theme";
import { Grain, Wordmark } from "./components";

const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;
const FPS = 30;

// Трек и его сетка: дроп (секунда трека) и длина доли. До дропа — 8 долей вступления.
export type Track = { src: string; drop: number; beat: number; lead: number };
export const THUNDER: Track = { src: "music/thunder.mp3", drop: 20.2, beat: 0.6316, lead: 8 };

// Кадр ролика по номеру доли: на доле lead вступает дроп
const useGrid = (t: Track) => {
  const B = t.beat * FPS;
  const dropF = Math.round(t.lead * B);
  return { B, dropF, f: (b: number) => Math.round(dropF + (b - t.lead) * B), start: Math.round((t.drop * FPS) - dropF) };
};

type Seg = { b0: number; b1: number; src: string; from: number; rate: number; look?: string; blur?: number; dim?: number; shake?: boolean };

// Нарезка: доля начала, доля конца, клип, кадр клипа, скорость
const half = (b0: number, list: [string, number][]): Seg[] =>
  list.map(([src, from], i) => ({ b0: b0 + i / 2, b1: b0 + (i + 1) / 2, src, from, rate: 1.5 }));

const SEGS: Seg[] = [
  { b0: 0, b1: 4, src: "street_v", from: 10, rate: 1.4 },
  { b0: 4, b1: 6, src: "build_v", from: 30, rate: 3.4 },
  { b0: 6, b1: 8, src: "build_v", from: 160, rate: 0.6, blur: 14, dim: 0.62 },
  { b0: 8, b1: 10, src: "aerial_v", from: 40, rate: 1.5 },
  { b0: 10, b1: 12, src: "forum_v", from: 30, rate: 1.6 },
  { b0: 12, b1: 13, src: "colosseum_v", from: 60, rate: 1.6 },
  { b0: 13, b1: 14, src: "street_v", from: 120, rate: 1.5 },
  { b0: 14, b1: 16, src: "garden_v", from: 20, rate: 1.5 },
  { b0: 16, b1: 17, src: "cat_v", from: 80, rate: 1 },
  { b0: 17, b1: 18, src: "pond_v", from: 40, rate: 1.6 },
  { b0: 18, b1: 20, src: "build_v", from: 150, rate: 2.5 },
  ...half(20, [["aerial_v", 150], ["forum_v", 110], ["colosseum_v", 110], ["garden_v", 100], ["sunset_v", 60], ["night_v", 60], ["street_v", 60], ["finale_v", 60]]),
  { b0: 24, b1: 28, src: "sunset_v", from: 40, rate: 1.4, look: "contrast(1.06) saturate(1.1)" },
  { b0: 28, b1: 32, src: "night_v", from: 30, rate: 1.4, look: "brightness(1.12) contrast(1.05) hue-rotate(-8deg)" },
  { b0: 32, b1: 34, src: "battle_v", from: 40, rate: 1.2, shake: true },
  { b0: 34, b1: 36, src: "battle_v", from: 160, rate: 1.2, shake: true },
  { b0: 36, b1: 40, src: "elephant_v", from: 150, rate: 1.2, shake: true },
  ...half(40, [["elephant_v", 240], ["battle_v", 220], ["forum_v", 130], ["colosseum_v", 30], ["aerial_v", 100], ["night_v", 120], ["sunset_v", 120], ["street_v", 30]]),
  { b0: 44, b1: 50, src: "finale_v", from: 20, rate: 1.5 },
  ...half(50, [["street_v", 140], ["build_v", 240], ["forum_v", 60], ["colosseum_v", 20], ["cat_v", 85], ["garden_v", 110],
    ["sunset_v", 150], ["night_v", 150], ["battle_v", 100], ["elephant_v", 200], ["pond_v", 100], ["aerial_v", 20]]),
  { b0: 56, b1: 64, src: "aerial_v", from: 120, rate: 0.6, blur: 16, dim: 0.66 },
];

type Word = { w: string; b: number; gold?: boolean; br?: boolean };
type Txt = { b0: number; b1: number; words: Word[]; size?: number; y?: number };

const TEXTS: Txt[] = [
  { b0: 0.25, b1: 4, words: [{ w: "Улицы —", b: 0.5 }, { w: "как", b: 1.5, br: true }, { w: "нарисуешь.", b: 2.5, gold: true }] },
  { b0: 4, b1: 6, y: 300, words: [{ w: "Дома", b: 4 }, { w: "растут", b: 4.5 }, { w: "сами.", b: 5, gold: true, br: true }] },
  { b0: 8, b1: 10, words: [{ w: "Построй", b: 8 }, { w: "свой", b: 9, br: true }, { w: "Рим", b: 9.5, gold: true }] },
  { b0: 10, b1: 12, words: [{ w: "Форум", b: 10, gold: true }, { w: "и храмы", b: 11, br: true }] },
  { b0: 12, b1: 13, words: [{ w: "Колизей", b: 12, gold: true }] },
  { b0: 14, b1: 16, words: [{ w: "Город", b: 14 }, { w: "живёт", b: 15, gold: true, br: true }] },
  { b0: 16, b1: 17, words: [{ w: "и кошки", b: 16 }] },
  { b0: 24, b1: 28, words: [{ w: "Закаты", b: 24, gold: true }, { w: "над Римом", b: 26, br: true }] },
  { b0: 28, b1: 32, words: [{ w: "Огни", b: 28, gold: true }, { w: "ночного", b: 30, br: true }, { w: "города", b: 30.5, br: true }] },
  { b0: 32, b1: 36, words: [{ w: "Собери", b: 32 }, { w: "легион", b: 33, gold: true, br: true }] },
  { b0: 36, b1: 40, words: [{ w: "Победи", b: 36 }, { w: "слона", b: 37, br: true }, { w: "Ганнибала", b: 38, gold: true, br: true }] },
  { b0: 44, b1: 49.7, words: [{ w: "Строй.", b: 44 }, { w: "Украшай.", b: 45.5, br: true }, { w: "Сражайся.", b: 47, gold: true, br: true }] },
];

const FLASH = [8, 20, 24, 40, 44, 50, 56];
const LOGO_B = 6; // тишина перед дропом — название игры
const END_B = 56;
export const TIKTOK_BEATS = 64;

// Приближение для клипов, где главное мелко: бой, слон, кошка (масштаб и точка, к которой приближаем)
const ZOOM: Record<string, [number, string]> = { battle_v: [1.55, "50% 62%"], elephant_v: [1.45, "52% 57%"], cat_v: [1.35, "48% 50%"] };

const VClip: React.FC<Seg & { dur: number; B: number }> = ({ src, from, rate, look, blur, dim, shake, dur, B }) => {
  const frame = useCurrentFrame();
  const [zk, origin] = ZOOM[src] || [1, "50% 50%"];
  // удар на смене кадра: картинка чуть больше и за 6 кадров садится на место
  const punch = interpolate(frame, [0, 6], [1.12, 1], { ...clamp, easing: Easing.out(Easing.cubic) });
  const drift = interpolate(frame, [0, dur], [1, 1.06], clamp);
  let sx = 0, sy = 0;
  if (shake) {
    const k = Math.max(0, 1 - ((frame % B) / 6));
    sx = Math.sin(frame * 2.7) * 14 * k;
    sy = Math.cos(frame * 3.1) * 10 * k;
  }
  const filter = [blur ? `blur(${blur}px)` : "", look || ""].join(" ").trim() || undefined;
  return (
    <AbsoluteFill style={{ overflow: "hidden", background: "#000" }}>
      <AbsoluteFill style={{ transform: `translate(${sx}px, ${sy}px) scale(${punch * drift * zk * (blur ? 1.08 : 1)})`, transformOrigin: origin, filter }}>
        <OffthreadVideo src={staticFile(`shots/${src}.mp4`)} trimBefore={from} playbackRate={rate} muted
          style={{ width: "100%", height: "100%", objectFit: "cover" }} />
      </AbsoluteFill>
      {dim ? <AbsoluteFill style={{ background: `rgba(8,5,2,${dim})` }} /> : null}
    </AbsoluteFill>
  );
};

// Слова выскакивают точно в долю: крупно, жирно, одно слово — золотом
const BeatText: React.FC<{ t: Txt; f: (b: number) => number }> = ({ t, f }) => {
  const frame = useCurrentFrame() + f(t.b0);
  const { fps } = useVideoConfig();
  const size = t.size || 148;
  const out = interpolate(frame, [f(t.b1) - 4, f(t.b1)], [1, 0], clamp);
  const lines: Word[][] = [];
  for (const w of t.words) { if (!lines.length || w.br) lines.push([]); lines[lines.length - 1].push(w); }
  return (
    <AbsoluteFill style={{ justifyContent: "flex-start", alignItems: "center", paddingTop: t.y ?? 560, opacity: out }}>
      <AbsoluteFill style={{ background: `radial-gradient(ellipse 80% 30% at 50% ${(((t.y ?? 560) + 160) / 1920 * 100).toFixed(0)}%, rgba(8,5,2,0.45), transparent 70%)` }} />
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 6, padding: "0 90px", textAlign: "center" }}>
        {lines.map((ln, i) => (
          <div key={i} style={{ display: "flex", gap: size * 0.24, justifyContent: "center", flexWrap: "wrap" }}>
            {ln.map((w, j) => {
              const p = spring({ frame: frame - f(w.b), fps, config: { damping: 12, stiffness: 260, mass: 0.5 } });
              return (
                <span key={j} style={{ display: "inline-block", fontFamily: theme.fonts.display, fontWeight: 900, fontSize: size, lineHeight: 1.02,
                  letterSpacing: "-0.04em", color: w.gold ? theme.colors.primary : "#fff", opacity: Math.min(1, p * 2),
                  transform: `scale(${interpolate(p, [0, 1], [1.45, 1])}) translateY(${interpolate(p, [0, 1], [-20, 0])}px)`,
                  textShadow: w.gold ? `0 0 40px ${theme.colors.glow}, 0 6px 30px rgba(0,0,0,0.6)` : "0 6px 30px rgba(0,0,0,0.65), 0 2px 4px rgba(0,0,0,0.4)" }}>{w.w}</span>
              );
            })}
          </div>
        ))}
      </div>
    </AbsoluteFill>
  );
};

const Flash: React.FC<{ strong?: boolean }> = ({ strong }) => {
  const frame = useCurrentFrame();
  const o = interpolate(frame, [0, strong ? 10 : 6], [strong ? 0.95 : 0.55, 0], { ...clamp, easing: Easing.out(Easing.quad) });
  return <AbsoluteFill style={{ background: "#fff8e6", opacity: o, pointerEvents: "none" }} />;
};

// Пауза перед дропом: название игры падает буквами
const LogoSlam: React.FC<{ dur: number }> = ({ dur }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const sub = spring({ frame: frame - 16, fps, config: theme.spring.smooth });
  const grow = interpolate(frame, [0, dur], [1, 1.08], clamp);
  return (
    <AbsoluteFill style={{ justifyContent: "center", alignItems: "center", paddingBottom: 260 }}>
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 28, transform: `scale(${grow})` }}>
        <Wordmark size={165} delay={0} />
        <div style={{ fontFamily: theme.fonts.body, fontWeight: 600, fontSize: 40, color: theme.colors.textDim, textAlign: "center", lineHeight: 1.25,
          opacity: sub, transform: `translateY(${interpolate(sub, [0, 1], [18, 0])}px)` }}>градостроитель<br />про Древний Рим</div>
      </div>
    </AbsoluteFill>
  );
};

// Финал: название, призыв и адрес
const EndCard: React.FC<{ f: (b: number) => number }> = ({ f }) => {
  const frame = useCurrentFrame() + f(END_B);
  const { fps } = useVideoConfig();
  const at = (b: number, cfg: { damping: number; stiffness: number; mass: number } = theme.spring.snappy) => spring({ frame: frame - f(b), fps, config: cfg });
  const play = at(END_B + 2), site = at(END_B + 4), plat = at(END_B + 5, theme.spring.smooth);
  const pulse = 1 + Math.max(0, Math.sin((frame - f(END_B + 4)) / 9)) * 0.025;
  return (
    <AbsoluteFill style={{ justifyContent: "center", alignItems: "center", paddingBottom: 300 }}>
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 40 }}>
        <Wordmark size={172} delay={0} />
        <div style={{ fontFamily: theme.fonts.display, fontWeight: 900, fontSize: 118, letterSpacing: "-0.04em", color: "#fff", textAlign: "center", lineHeight: 1.02,
          opacity: play, transform: `scale(${interpolate(play, [0, 1], [1.3, 1])})`, textShadow: "0 6px 30px rgba(0,0,0,0.6)" }}>
          Играй<br /><span style={{ color: theme.colors.primary }}>бесплатно</span>
        </div>
        <div style={{ opacity: site, transform: `translateY(${interpolate(site, [0, 1], [30, 0])}px) scale(${pulse})`, padding: "22px 54px", borderRadius: 999,
          background: theme.colors.text, color: theme.colors.bg, fontFamily: theme.fonts.display, fontWeight: 800, fontSize: 76, letterSpacing: "-0.03em" }}>civcity.ru</div>
        <div style={{ opacity: plat, fontFamily: theme.fonts.body, fontWeight: 600, fontSize: 44, color: theme.colors.textDim }}>в браузере и на ПК</div>
      </div>
    </AbsoluteFill>
  );
};

export const Tiktok: React.FC<{ track: Track }> = ({ track }) => {
  const g = useGrid(track);
  const total = g.f(TIKTOK_BEATS);
  return (
    <AbsoluteFill style={{ background: "#000" }}>
      {SEGS.map((s, i) => {
        const a = g.f(s.b0), dur = g.f(s.b1) - a;
        return <Sequence key={i} from={a} durationInFrames={dur}><VClip {...s} dur={dur} B={g.B} /></Sequence>;
      })}
      <Sequence from={g.f(LOGO_B)} durationInFrames={g.f(LOGO_B + 2) - g.f(LOGO_B)}><LogoSlam dur={g.f(LOGO_B + 2) - g.f(LOGO_B)} /></Sequence>
      {TEXTS.map((t, i) => (
        <Sequence key={i} from={g.f(t.b0)} durationInFrames={g.f(t.b1) - g.f(t.b0)}><BeatText t={t} f={g.f} /></Sequence>
      ))}
      <Sequence from={g.f(END_B)} durationInFrames={total - g.f(END_B)}><EndCard f={g.f} /></Sequence>
      {FLASH.map((b, i) => (
        <Sequence key={i} from={g.f(b)} durationInFrames={12}><Flash strong={b === track.lead} /></Sequence>
      ))}
      <AbsoluteFill style={{ background: "radial-gradient(ellipse at center, transparent 60%, rgba(0,0,0,0.35) 100%)", pointerEvents: "none" }} />
      <Grain />
      <Audio src={staticFile(track.src)} trimBefore={g.start}
        volume={fr => interpolate(fr, [0, 3, total - 36, total], [0, 1, 1, 0], clamp)} />
    </AbsoluteFill>
  );
};

export const tiktokFrames = (t: Track) => Math.round(Math.round(t.lead * t.beat * FPS) + (TIKTOK_BEATS - t.lead) * t.beat * FPS);
