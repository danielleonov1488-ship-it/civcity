import React from "react";
import { AbsoluteFill, Audio, interpolate, Sequence, spring, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { theme, bar } from "./theme";
import { BgMesh, Caption, Clip, ClipProps, Grade, Grain, Rule, Vignette, WordReveal, Wordmark } from "./components";

const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;
const XF = 6; // сцены перекрываются на 6 кадров — мягкая смена кадра

type CaptionProps = Omit<React.ComponentProps<typeof Caption>, "dur">;
type Scene = { from: number; to: number; clip?: Omit<ClipProps, "dur">; caption?: CaptionProps; render?: () => React.ReactNode };

// Сцены по тактам музыки (такт ≈ 3,3 с)
const SCENES: Scene[] = [
  { from: 0, to: bar(1), clip: { src: "shots/aerial.mp4", zoom: [1.06, 1.0] },
    render: () => <ColdOpen /> },
  { from: bar(1), to: bar(3), clip: { src: "shots/aerial.mp4", startFrom: 99, rate: 0.75, dim: 0.55, blur: 6, zoom: [1.08, 1.02] },
    render: () => <LogoCard /> },
  { from: bar(3), to: bar(5), clip: { src: "shots/forum.mp4", startFrom: 20 },
    caption: { eyebrow: "Сердце города", title: "Форум, храмы и Пантеон.", hero: "Форум" } },
  { from: bar(5), to: bar(6), clip: { src: "shots/colosseum.mp4", startFrom: 60 },
    caption: { title: "Чудеса света.", hero: "Чудеса", delay: 6 } },
  { from: bar(6), to: bar(8), clip: { src: "shots/street.mp4", startFrom: 20 },
    caption: { eyebrow: "Свободная стройка", title: "Улицы — как нарисуешь.", hero: "нарисуешь", sub: "Без клеток. Плавные, живые, твои." } },
  { from: bar(8), to: bar(10), clip: { src: "shots/build.mp4", startFrom: 5 },
    caption: { title: "Дома растут сами.", hero: "сами", sub: "Проведи дорогу — вдоль неё вырастет квартал." } },
  { from: bar(10), to: bar(11), clip: { src: "shots/garden.mp4", startFrom: 20 },
    caption: { title: "Город живёт.", hero: "живёт", delay: 6 } },
  { from: bar(11), to: bar(12), clip: { src: "shots/cat.mp4", startFrom: 10, zoom: [1.3, 1.42] },
    caption: { title: "Даже кошки.", hero: "кошки", delay: 6 } },
  { from: bar(12), to: bar(13), clip: { src: "shots/pond.mp4", startFrom: 30 } },
  { from: bar(13), to: bar(15), clip: { src: "shots/sunset.mp4", startFrom: 20, look: "contrast(1.06) saturate(1.08)" },
    caption: { title: "Закаты над Римом.", hero: "Закаты" } },
  { from: bar(15), to: bar(17), clip: { src: "shots/night.mp4", startFrom: 20, look: "brightness(1.12) contrast(1.05) hue-rotate(-8deg)" },
    caption: { title: "Ночью зажигаются огни.", hero: "огни" } },
  { from: bar(17), to: bar(18), clip: { src: "shots/battle.mp4", startFrom: 40, zoom: [1.28, 1.36] },
    caption: { eyebrow: "Походы", title: "Собери легион.", hero: "легион", delay: 6 } },
  { from: bar(18), to: bar(19), clip: { src: "shots/elephant.mp4", startFrom: 150, zoom: [1.22, 1.32] },
    caption: { title: "Сразись с легендами.", hero: "легендами", sub: "Минотавр, циклоп, Цербер и слон Ганнибала.", delay: 4 } },
  { from: bar(19), to: bar(21), clip: { src: "shots/finale.mp4", startFrom: 10 },
    caption: { title: "Играй бесплатно.", hero: "бесплатно", sub: "В браузере и на ПК.", align: "center" } },
  { from: bar(21), to: bar(23), render: () => <EndCard /> },
];

export const PROMO_FRAMES = bar(23);

const SceneView: React.FC<{ s: Scene; dur: number }> = ({ s, dur }) => (
  <AbsoluteFill>
    {s.clip && <Clip {...s.clip} dur={dur} />}
    {s.caption && <Caption {...s.caption} dur={dur} />}
    {s.render && s.render()}
  </AbsoluteFill>
);

// Первые секунды: город сверху и крупно — «Построй свой Рим.»
const ColdOpen: React.FC = () => {
  const frame = useCurrentFrame();
  const exit = interpolate(frame, [bar(1) - 14, bar(1) - 4], [1, 0], { ...clamp, easing: theme.ease.in });
  return (
    <AbsoluteFill style={{ justifyContent: "center", alignItems: "center", opacity: exit }}>
      <AbsoluteFill style={{ background: "radial-gradient(ellipse at center, rgba(10,6,3,0.45), transparent 70%)" }} />
      <WordReveal text="Построй свой Рим." hero="Рим" size={150} delay={12} per={6} />
    </AbsoluteFill>
  );
};

// Титр с названием: CIVCITY, золотая линия, подзаголовок
const LogoCard: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const sub = spring({ frame: frame - 34, fps, config: theme.spring.smooth });
  const exit = interpolate(frame, [bar(2) - 12, bar(2) - 3], [1, 0], { ...clamp, easing: theme.ease.in });
  const breathe = 1 + Math.sin(frame / 22) * 0.008;
  return (
    <AbsoluteFill style={{ justifyContent: "center", alignItems: "center", opacity: exit }}>
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 30, transform: `scale(${breathe})` }}>
        <Wordmark size={210} delay={6} />
        <Rule width={760} delay={22} />
        <div style={{ fontFamily: theme.fonts.body, fontWeight: 500, fontSize: 40, color: theme.colors.textDim, letterSpacing: "0.02em",
          opacity: sub, transform: `translateY(${interpolate(sub, [0, 1], [20, 0])}px)` }}>Уютный градостроитель про Древний Рим</div>
      </div>
    </AbsoluteFill>
  );
};

// Финал: название, адрес сайта и две «кнопки»
const EndCard: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const site = spring({ frame: frame - 26, fps, config: theme.spring.smooth });
  const pills = [0, 1].map(i => spring({ frame: frame - 40 - i * 5, fps, config: theme.spring.snappy }));
  const fadeOut = interpolate(frame, [bar(2) - 24, bar(2)], [1, 0], { ...clamp, easing: theme.ease.in });
  const pill = (p: number, label: string, solid: boolean) => (
    <div style={{ opacity: p, transform: `translateY(${interpolate(p, [0, 1], [24, 0])}px) scale(${interpolate(p, [0, 1], [0.94, 1])})`,
      padding: "18px 38px", borderRadius: 999, fontFamily: theme.fonts.body, fontWeight: 600, fontSize: 30,
      background: solid ? theme.colors.text : "transparent", color: solid ? theme.colors.bg : theme.colors.text,
      border: `2px solid ${solid ? theme.colors.text : "rgba(251,245,233,0.45)"}` }}>{label}</div>
  );
  return (
    <AbsoluteFill style={{ opacity: fadeOut }}>
      <BgMesh />
      <AbsoluteFill style={{ justifyContent: "center", alignItems: "center" }}>
        <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 34 }}>
          <Wordmark size={170} delay={4} />
          <div style={{ fontFamily: theme.fonts.display, fontWeight: 800, fontSize: 92, letterSpacing: "-0.03em", color: theme.colors.text,
            opacity: site, transform: `translateY(${interpolate(site, [0, 1], [30, 0])}px)` }}>civcity.ru</div>
          <div style={{ display: "flex", gap: 22 }}>
            {pill(pills[0], "Играть в браузере", true)}
            {pill(pills[1], "Скачать для Windows", false)}
          </div>
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};

// Звук: музыка всё время, перед каждой сменой кадра — свист, на титрах — удар и звон, в бою — барабаны и мечи
const Sound: React.FC = () => {
  const total = PROMO_FRAMES;
  return (
    <>
      <Audio src={staticFile("audio/music.wav")} volume={f => interpolate(f, [0, 12, bar(17), bar(17) + 10, bar(19) - 10, bar(19), total - 70, total], [0, 0.9, 0.9, 0.6, 0.6, 0.9, 0.9, 0], clamp)} />
      {SCENES.slice(1).map((s, i) => (
        <Sequence key={i} from={Math.max(0, s.from - 8)} durationInFrames={40}><Audio src={staticFile("audio/whoosh.wav")} volume={0.55} /></Sequence>
      ))}
      <Sequence from={bar(1) + 6} durationInFrames={60}><Audio src={staticFile("audio/hit.wav")} volume={0.9} /></Sequence>
      <Sequence from={bar(1) + 22} durationInFrames={60}><Audio src={staticFile("audio/shimmer.wav")} volume={0.7} /></Sequence>
      <Sequence from={bar(11) + 8} durationInFrames={60}><Audio src={staticFile("audio/shimmer.wav")} volume={0.45} /></Sequence>
      <Sequence from={bar(17)} durationInFrames={bar(2)}><Audio src={staticFile("audio/drums.wav")} volume={1} /></Sequence>
      {[20, 64, 110, 150].map(f => (
        <Sequence key={f} from={bar(17) + f} durationInFrames={60}><Audio src={staticFile("audio/swords.wav")} volume={0.75} /></Sequence>
      ))}
      <Sequence from={bar(19) - 30} durationInFrames={90}><Audio src={staticFile("audio/cheer.wav")} volume={0.7} /></Sequence>
      <Sequence from={bar(21) + 4} durationInFrames={60}><Audio src={staticFile("audio/hit.wav")} volume={0.8} /></Sequence>
      <Sequence from={bar(21) + 26} durationInFrames={60}><Audio src={staticFile("audio/shimmer.wav")} volume={0.6} /></Sequence>
    </>
  );
};

export const Promo: React.FC = () => (
  <AbsoluteFill style={{ background: theme.colors.bg }}>
    {SCENES.map((s, i) => {
      const from = Math.max(0, s.from - (i ? XF : 0)), dur = s.to - from;
      return <Sequence key={i} from={from} durationInFrames={dur}><SceneView s={s} dur={dur} /></Sequence>;
    })}
    <Grade />
    <Grain />
    <Vignette />
    <Sound />
  </AbsoluteFill>
);
