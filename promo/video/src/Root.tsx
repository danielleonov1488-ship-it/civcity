import React from "react";
import { Composition } from "remotion";
import { Promo, PROMO_FRAMES } from "./Promo";
import { Tiktok, THUNDER, tiktokFrames } from "./Tiktok";
import { Cozy, COZY_FRAMES } from "./Cozy";
import { FPS } from "./theme";
import { Promo2, PROMO2_FRAMES, Vertical2, VERTICAL2_FRAMES } from "./Promo2";

export const RemotionRoot: React.FC = () => (
  <>
    <Composition id="Promo" component={Promo} durationInFrames={PROMO_FRAMES} fps={FPS} width={1920} height={1080} />
    <Composition id="Cozy" component={Cozy} durationInFrames={COZY_FRAMES} fps={FPS} width={1080} height={1920} />
    <Composition id="Promo2" component={Promo2} durationInFrames={PROMO2_FRAMES} fps={FPS} width={2560} height={1440} />
    <Composition id="Vertical2" component={Vertical2} durationInFrames={VERTICAL2_FRAMES} fps={FPS} width={1080} height={1920} />
    <Composition id="Tiktok" component={Tiktok} defaultProps={{ track: THUNDER }} durationInFrames={tiktokFrames(THUNDER)} fps={FPS} width={1080} height={1920} />
  </>
);
