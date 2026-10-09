// Единственный источник цветов, шрифтов, кривых и пружин ролика CivCity.
import { Easing } from "remotion";
import { loadFont as loadInter } from "@remotion/google-fonts/Inter";
import { loadFont as loadCinzel } from "@remotion/google-fonts/Cinzel";

const inter = loadInter("normal", { weights: ["500", "600", "800", "900"], subsets: ["cyrillic", "latin"] });
const cinzel = loadCinzel("normal", { weights: ["600", "800"], subsets: ["latin"] });

export const theme = {
  colors: {
    bg: "#120C08",
    bgAlt: "#1E140D",
    primary: "#E9B949", // римское золото — главный цвет, не больше одного элемента в кадре
    accent: "#C8553D", // терракота черепицы
    text: "#FBF5E9",
    textDim: "#D9CDB6",
    glow: "rgba(233, 185, 73, 0.45)",
  },
  fonts: {
    display: inter.fontFamily, // заголовки в духе Apple: плотный современный гротеск
    logo: cinzel.fontFamily, // римские капители — только для надписи CIVCITY
    body: inter.fontFamily,
  },
  ease: {
    out: Easing.bezier(0.16, 1, 0.3, 1),
    inOut: Easing.bezier(0.83, 0, 0.17, 1),
    in: Easing.bezier(0.7, 0, 0.84, 0),
  },
  spring: {
    snappy: { damping: 14, stiffness: 160, mass: 0.6 },
    smooth: { damping: 20, stiffness: 90, mass: 1 },
    bouncy: { damping: 11, stiffness: 170, mass: 0.7 },
  },
} as const;

// Музыка — наше фортепиано, 73 удара в минуту: сцены режутся по тактам
export const FPS = 30;
export const BPM = 73;
export const BAR = (FPS * 60 * 4) / BPM; // ≈ 98.6 кадра
export const bar = (n: number) => Math.round(n * BAR);
