import React from "react";
import { Composition } from "remotion";
import { Promo, PROMO_FRAMES } from "./Promo";
import { Tiktok, THUNDER, tiktokFrames } from "./Tiktok";
import { Cozy, COZY_FRAMES } from "./Cozy";
import { FPS } from "./theme";

export const RemotionRoot: React.FC = () => (
  <>
    <Composition id="Promo" component={Promo} durationInFrames={PROMO_FRAMES} fps={FPS} width={1920} height={1080} />
    <Composition id="Cozy" component={Cozy} durationInFrames={COZY_FRAMES} fps={FPS} width={1080} height={1920} />
    <Composition id="Tiktok" component={Tiktok} defaultProps={{ track: THUNDER }} durationInFrames={tiktokFrames(THUNDER)} fps={FPS} width={1080} height={1920} />
  </>
);
