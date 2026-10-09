import React from "react";
import { AbsoluteFill, interpolate, OffthreadVideo, spring, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { theme } from "./theme";

const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;

// Фон для титров: тёмное тепло с медленно плывущими пятнами золота и терракоты
export const BgMesh: React.FC = () => {
  const frame = useCurrentFrame();
  const d1 = Math.sin(frame / 55) * 50, d2 = Math.cos(frame / 70) * 40;
  return (
    <AbsoluteFill style={{ background: theme.colors.bg }}>
      <div style={{ position: "absolute", width: 1300, height: 1300, borderRadius: "50%", top: -520, left: -300 + d1, filter: "blur(60px)",
        background: `radial-gradient(circle, ${theme.colors.primary}2a, transparent 62%)` }} />
      <div style={{ position: "absolute", width: 1000, height: 1000, borderRadius: "50%", bottom: -460, right: -260 - d2, filter: "blur(80px)",
        background: `radial-gradient(circle, ${theme.colors.accent}26, transparent 65%)` }} />
    </AbsoluteFill>
  );
};

// Тёплая цветокоррекция поверх всего — сводит кадры игры и титры в одно настроение
export const Grade: React.FC<{ strength?: number }> = ({ strength = 0.12 }) => (
  <AbsoluteFill style={{ pointerEvents: "none" }}>
    <AbsoluteFill style={{ backgroundColor: theme.colors.primary, mixBlendMode: "soft-light", opacity: strength }} />
    <AbsoluteFill style={{ background: "linear-gradient(180deg, rgba(0,0,0,0.16), transparent 30%, transparent 62%, rgba(0,0,0,0.42))" }} />
  </AbsoluteFill>
);

export const Grain: React.FC = () => {
  const frame = useCurrentFrame();
  const noise = `url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='220' height='220'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='2'/%3E%3C/filter%3E%3Crect width='220' height='220' filter='url(%23n)' opacity='0.5'/%3E%3C/svg%3E")`;
  return <AbsoluteFill style={{ pointerEvents: "none", backgroundImage: noise, backgroundSize: "220px",
    backgroundPosition: `${(frame * 7) % 220}px ${(frame * 13) % 220}px`, opacity: 0.06, mixBlendMode: "overlay" }} />;
};

export const Vignette: React.FC = () => (
  <AbsoluteFill style={{ pointerEvents: "none", background: "radial-gradient(ellipse at center, transparent 55%, rgba(0,0,0,0.38) 100%)" }} />
);

// Клип из игры: мягкий вход, лёгкое «дыхание» масштаба и быстрый уход в конце сцены
export type ClipProps = { src: string; startFrom?: number; dur: number; zoom?: [number, number]; dim?: number; blur?: number; rate?: number; look?: string };
export const Clip: React.FC<ClipProps> = ({ src, startFrom = 0, dur, zoom = [1.0, 1.04], dim = 0, blur = 0, rate = 1, look }) => {
  const frame = useCurrentFrame();
  const inP = interpolate(frame, [0, 8], [0, 1], { ...clamp, easing: theme.ease.out });
  const outP = interpolate(frame, [dur - 6, dur], [1, 0], { ...clamp, easing: theme.ease.in });
  const scale = interpolate(frame, [0, dur], zoom, { ...clamp, easing: theme.ease.inOut }) * interpolate(inP, [0, 1], [1.035, 1]);
  const filter = [blur ? `blur(${blur}px)` : "", look || ""].join(" ").trim() || undefined;
  return (
    <AbsoluteFill style={{ opacity: Math.min(inP, outP), overflow: "hidden" }}>
      <AbsoluteFill style={{ transform: `scale(${scale})`, filter }}>
        <OffthreadVideo src={staticFile(src)} trimBefore={startFrom} playbackRate={rate} muted style={{ width: "100%", height: "100%", objectFit: "cover" }} />
      </AbsoluteFill>
      {dim > 0 && <AbsoluteFill style={{ background: `rgba(10,6,3,${dim})` }} />}
    </AbsoluteFill>
  );
};

// Слова появляются по одному: подъём + прозрачность + пружина; одно слово можно выделить золотом
export const WordReveal: React.FC<{ text: string; delay?: number; per?: number; size: number; weight?: number; hero?: string; color?: string; family?: string; tracking?: string }> =
  ({ text, delay = 0, per = 4, size, weight = 800, hero, color = theme.colors.text, family = theme.fonts.display, tracking = "-0.035em" }) => {
    const frame = useCurrentFrame();
    const { fps } = useVideoConfig();
    return (
      <div style={{ display: "flex", flexWrap: "wrap", columnGap: Math.round(size * 0.26), rowGap: 0, fontFamily: family, fontWeight: weight, fontSize: size,
        letterSpacing: tracking, lineHeight: 1.04, color }}>
        {text.split(" ").map((w, i) => {
          const p = spring({ frame: frame - delay - i * per, fps, config: theme.spring.snappy });
          const isHero = hero && w.replace(/[.,!—]/g, "") === hero;
          return (
            <span key={i} style={{ display: "inline-block", opacity: p, transform: `translateY(${interpolate(p, [0, 1], [34, 0])}px) scale(${interpolate(p, [0, 1], [0.96, 1])})`,
              color: isHero ? theme.colors.primary : undefined, textShadow: isHero ? `0 0 36px ${theme.colors.glow}, 0 2px 18px rgba(0,0,0,0.55)` : "0 2px 22px rgba(0,0,0,0.55), 0 1px 3px rgba(0,0,0,0.3)" }}>{w}</span>
          );
        })}
      </div>
    );
  };

// Подпись к кадру в духе презентаций Apple: маленькая золотая строка сверху, крупный заголовок, тихая подстрока
export const Caption: React.FC<{ eyebrow?: string; title: string; hero?: string; sub?: string; dur: number; align?: "left" | "center"; delay?: number }> =
  ({ eyebrow, title, hero, sub, dur, align = "left", delay = 10 }) => {
    const frame = useCurrentFrame();
    const { fps } = useVideoConfig();
    const exitO = interpolate(frame, [dur - 12, dur - 3], [1, 0], { ...clamp, easing: theme.ease.in });
    const exitY = interpolate(frame, [dur - 12, dur - 3], [0, -26], { ...clamp, easing: theme.ease.in });
    const eb = spring({ frame: frame - delay + 4, fps, config: theme.spring.smooth });
    const sb = spring({ frame: frame - delay - 14, fps, config: theme.spring.smooth });
    const drift = Math.sin(frame / 30) * 2;
    const center = align === "center";
    // мягкое затемнение под текстом: появляется вместе с подписью, чтобы буквы читались на любом кадре
    const scrimIn = interpolate(frame, [delay - 8, delay + 10], [0, 1], { ...clamp, easing: theme.ease.out });
    const scrim = center
      ? "radial-gradient(ellipse 60% 45% at 50% 50%, rgba(10,6,3,0.5), rgba(10,6,3,0.18) 60%, transparent 85%)"
      : "linear-gradient(to top, rgba(10,6,3,0.66) 0%, rgba(10,6,3,0.38) 24%, transparent 52%), radial-gradient(ellipse 55% 45% at 18% 88%, rgba(10,6,3,0.4), transparent 75%)";
    return (
      <>
      <AbsoluteFill style={{ background: scrim, opacity: scrimIn * exitO, pointerEvents: "none" }} />
      <AbsoluteFill style={{ justifyContent: center ? "center" : "flex-end", alignItems: center ? "center" : "flex-start",
        padding: center ? 0 : "0 0 120px 130px", opacity: exitO, transform: `translateY(${exitY + drift}px)` }}>
        <div style={{ display: "flex", flexDirection: "column", gap: 18, alignItems: center ? "center" : "flex-start", maxWidth: 1500, textAlign: center ? "center" : "left" }}>
          {eyebrow && <div style={{ fontFamily: theme.fonts.body, fontWeight: 600, fontSize: 26, letterSpacing: "0.28em", textTransform: "uppercase",
            color: theme.colors.primary, textShadow: "0 2px 14px rgba(0,0,0,0.6)", opacity: eb, transform: `translateY(${interpolate(eb, [0, 1], [16, 0])}px)` }}>{eyebrow}</div>}
          <WordReveal text={title} hero={hero} size={104} delay={delay} />
          {sub && <div style={{ fontFamily: theme.fonts.body, fontWeight: 500, fontSize: 38, letterSpacing: "-0.01em", color: theme.colors.textDim,
            opacity: sb, transform: `translateY(${interpolate(sb, [0, 1], [18, 0])}px)`, textShadow: "0 2px 18px rgba(0,0,0,0.6)" }}>{sub}</div>}
        </div>
      </AbsoluteFill>
      </>
    );
  };

// Надпись CIVCITY: римские капители, буквы падают по одной, по золоту пробегает блик
export const Wordmark: React.FC<{ size: number; delay?: number }> = ({ size, delay = 0 }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const letters = "CIVCITY".split("");
  const sweep = interpolate(frame - delay, [18, 70], [-30, 130], { ...clamp, easing: theme.ease.inOut });
  return (
    <div style={{ display: "flex", gap: Math.round(size * 0.06), fontFamily: theme.fonts.logo, fontWeight: 800, fontSize: size, lineHeight: 1,
      filter: `drop-shadow(0 0 ${Math.round(size * 0.28)}px ${theme.colors.glow})` }}>
      {letters.map((l, i) => {
        const p = spring({ frame: frame - delay - i * 3, fps, config: theme.spring.bouncy });
        return (
          <span key={i} style={{ display: "inline-block", opacity: Math.min(1, p * 1.3), transform: `translateY(${interpolate(p, [0, 1], [-60, 0])}px) scale(${interpolate(p, [0, 1], [1.25, 1])})`,
            backgroundImage: `linear-gradient(105deg, #b9822c 0%, ${theme.colors.primary} ${sweep - 22}%, #fff4cf ${sweep}%, ${theme.colors.primary} ${sweep + 22}%, #b9822c 100%)`,
            WebkitBackgroundClip: "text", backgroundClip: "text", color: "transparent" }}>{l}</span>
        );
      })}
    </div>
  );
};

// Тонкая золотая линия, растущая от центра
export const Rule: React.FC<{ width: number; delay?: number }> = ({ width, delay = 0 }) => {
  const frame = useCurrentFrame();
  const p = interpolate(frame - delay, [0, 26], [0, 1], { ...clamp, easing: theme.ease.out });
  return <div style={{ width: width * p, height: 2, background: `linear-gradient(90deg, transparent, ${theme.colors.primary}, transparent)`, opacity: 0.9 }} />;
};
