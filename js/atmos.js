'use strict';
/* Атмосфера: небо с облаками, смена дня и ночи, тени от облаков, ветер в листве,
   рябь на воде, птицы. Плюс «заплатки» для стандартных материалов Three.js. */

const Shared = {
  time: { value: 0 },
  cloud: { value: 1 },
};

const NOISE_GLSL = `
float h21(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float vnoise(vec2 p) {
  vec2 i = floor(p), f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), u.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm3(vec2 p) { return vnoise(p) * 0.55 + vnoise(p * 2.03 + 7.1) * 0.3 + vnoise(p * 4.1 + 3.3) * 0.15; }
`;

/* Добавляет в материал: тени от облаков, зерно на земле, качание листвы на ветру */
function patchMaterial(mat, opts) {
  opts = opts || {};
  mat.onBeforeCompile = (sh) => {
    sh.uniforms.uTime = Shared.time;
    sh.uniforms.uCloud = Shared.cloud;
    sh.vertexShader = sh.vertexShader
      .replace('#include <common>', '#include <common>\nvarying vec3 vWPos;\nuniform float uTime;')
      .replace('#include <begin_vertex>', `#include <begin_vertex>
        ${opts.sway ? `
        #ifdef USE_INSTANCING
          vec2 _ip = vec2(instanceMatrix[3][0], instanceMatrix[3][2]);
        #else
          vec2 _ip = vec2(0.0);
        #endif
        float _h = max(transformed.y - 0.1, 0.0);
        float _ph = uTime * 1.5 + _ip.x * 0.7 + _ip.y * 0.45;
        float _g = 0.6 + 0.4 * sin(uTime * 0.37 + _ip.x * 0.05);
        transformed.x += sin(_ph) * 0.045 * _h * _h * _g;
        transformed.z += cos(_ph * 0.83) * 0.03 * _h * _h * _g;` : ''}`)
      .replace('#include <project_vertex>', `#include <project_vertex>
        vec4 _wp = vec4(transformed, 1.0);
        #ifdef USE_INSTANCING
          _wp = instanceMatrix * _wp;
        #endif
        vWPos = (modelMatrix * _wp).xyz;`);
    sh.fragmentShader = sh.fragmentShader
      .replace('#include <common>', `#include <common>\nvarying vec3 vWPos;\nuniform float uTime;\nuniform float uCloud;\n${NOISE_GLSL}`)
      .replace('#include <color_fragment>', `#include <color_fragment>
        float _c = fbm3(vWPos.xz * 0.035 + vec2(uTime * 0.012, uTime * 0.006));
        diffuseColor.rgb *= 1.0 - smoothstep(0.5, 0.72, _c) * 0.3 * uCloud;
        ${opts.grain ? `
        float _n = vnoise(vWPos.xz * 2.7) * 0.6 + vnoise(vWPos.xz * 9.0) * 0.4;
        float _m = vnoise(vWPos.xz * 0.35);
        diffuseColor.rgb *= 0.9 + _n * 0.14;
        diffuseColor.rgb = mix(diffuseColor.rgb, diffuseColor.rgb * vec3(1.06, 1.03, 0.9), smoothstep(0.55, 0.8, _m) * 0.6);` : ''}`);
  };
  mat.customProgramCacheKey = () => 'patch' + (opts.sway ? 's' : '') + (opts.grain ? 'g' : '');
  return mat;
}

/* Вода: бирюза на мели и синева в глубине, прозрачная у берега, пена по кромке колышется,
   по глади бегут тени облаков и вспыхивают блёстки. Глубина приходит атрибутом aDepth. */
function makeWaterMaterial(normals) {
  const mat = new THREE.MeshPhongMaterial({
    color: '#ffffff', transparent: true, shininess: 300, specular: new THREE.Color(0.32, 0.32, 0.3),
    normalMap: normals, normalScale: new THREE.Vector2(0.3, 0.3), emissive: '#0a2c38', emissiveIntensity: 0.25,
  });
  mat.onBeforeCompile = (sh) => {
    sh.uniforms.uTime = Shared.time;
    sh.uniforms.uCloud = Shared.cloud;
    sh.vertexShader = sh.vertexShader
      .replace('#include <common>', '#include <common>\nattribute float aDepth;\nvarying float vDepth;\nvarying vec3 vWPos;')
      .replace('#include <project_vertex>', `#include <project_vertex>
        vDepth = aDepth;
        vWPos = (modelMatrix * vec4(transformed, 1.0)).xyz;`);
    sh.fragmentShader = sh.fragmentShader
      .replace('#include <common>', `#include <common>\nvarying float vDepth;\nvarying vec3 vWPos;\nuniform float uTime;\nuniform float uCloud;\n${NOISE_GLSL}`)
      .replace('#include <color_fragment>', `#include <color_fragment>
        float _d = vDepth;
        if (_d < -0.005) discard;
        diffuseColor.rgb = mix(vec3(0.50, 0.86, 0.80), vec3(0.10, 0.37, 0.58), smoothstep(0.03, 0.3, _d));
        diffuseColor.a = mix(0.42, 0.9, smoothstep(0.0, 0.24, _d));
        // пена — полоса у самой кромки: глубину делим на крутизну дна и получаем расстояние до берега,
        // поэтому пологие отмели не белеют целиком
        float _gx = dFdx(_d) / max(length(dFdx(vWPos.xz)), 1e-5);
        float _gy = dFdy(_d) / max(length(dFdy(vWPos.xz)), 1e-5);
        float _dist = _d / max(length(vec2(_gx, _gy)), 0.03);
        float _w = 0.075 + 0.035 * sin(uTime * 1.2 + vWPos.x * 2.3 + vWPos.z * 1.7);
        float _f = (1.0 - smoothstep(_w * 0.4, _w, _dist)) * (0.7 + 0.3 * vnoise(vWPos.xz * 7.0 + uTime * 0.5));
        diffuseColor.rgb = mix(diffuseColor.rgb, vec3(0.97, 0.98, 0.95), _f * 0.85);
        diffuseColor.a = max(diffuseColor.a, _f * 0.8);
        float _c = fbm3(vWPos.xz * 0.035 + vec2(uTime * 0.012, uTime * 0.006));
        diffuseColor.rgb *= 1.0 - smoothstep(0.5, 0.72, _c) * 0.25 * uCloud;
        float _sp = pow(vnoise(vWPos.xz * 9.0 + vec2(uTime * 0.7, uTime * 0.45)) * vnoise(vWPos.xz * 5.3 - uTime * 0.35), 18.0) * 2.5;`)
      .replace('#include <emissivemap_fragment>', `#include <emissivemap_fragment>
        totalEmissiveRadiance += vec3(1.0, 0.97, 0.88) * _sp * step(0.08, _d);`)
      // солнечная дорожка — не сплошная белая клякса, а россыпь мерцающих искр
      .replace('#include <lights_fragment_end>', `#include <lights_fragment_end>
        float _gl = smoothstep(0.95, 1.25, vnoise(vWPos.xz * 15.0 + vec2(uTime * 0.7, -uTime * 0.5)) * vnoise(vWPos.xz * 9.0 - uTime * 0.4) * 1.6);
        reflectedLight.directSpecular *= 0.1 + _gl * 1.4;`);
  };
  mat.customProgramCacheKey = () => 'water';
  return mat;
}

/* Процедурная карта нормалей для ряби на воде */
function makeWaterNormals() {
  const S = 256, cv = document.createElement('canvas');
  cv.width = cv.height = S;
  const ctx = cv.getContext('2d');
  const img = ctx.createImageData(S, S);
  const hgt = new Float32Array(S * S);
  const waves = [];
  // целое число волн на текстуру — тогда она повторяется без швов
  for (let i = 0; i < 12; i++) {
    const kx = Math.round(Math.cos(i * 2.4) * (2 + i % 4)), ky = Math.round(Math.sin(i * 2.4) * (2 + i % 3));
    waves.push([kx || 1, ky, Math.random() * 6.28, 1 / (1 + i * 0.35)]);
  }
  for (let y = 0; y < S; y++) for (let x = 0; x < S; x++) {
    let h = 0;
    for (const [kx, ky, ph, a] of waves) h += Math.sin((kx * x + ky * y) / S * Math.PI * 2 + ph) * a;
    hgt[y * S + x] = h;
  }
  for (let y = 0; y < S; y++) for (let x = 0; x < S; x++) {
    const hx = hgt[y * S + (x + 1) % S] - hgt[y * S + (x + S - 1) % S];
    const hy = hgt[((y + 1) % S) * S + x] - hgt[((y + S - 1) % S) * S + x];
    let nx = -hx * 0.9, ny = -hy * 0.9, nz = 1;
    const l = Math.hypot(nx, ny, nz);
    const k = (y * S + x) * 4;
    img.data[k] = (nx / l * 0.5 + 0.5) * 255;
    img.data[k + 1] = (ny / l * 0.5 + 0.5) * 255;
    img.data[k + 2] = (nz / l * 0.5 + 0.5) * 255;
    img.data[k + 3] = 255;
  }
  ctx.putImageData(img, 0, 0);
  const t = new THREE.CanvasTexture(cv);
  t.wrapS = t.wrapT = THREE.RepeatWrapping;
  return t;
}

/* ---------- Время суток ---------- */

// t: 0 — полночь, 0.25 — рассвет, 0.5 — полдень, 0.75 — закат
const DAY_KEYS = [
  { t: 0.00, sun: '#8ea2d8', sunI: 0.75, zen: '#16213d', hor: '#33456b', hs: '#6f82b8', hg: '#262e48', hi: 0.75, glow: 1, elev: 0.75, exp: 1.25 },
  { t: 0.19, sun: '#8ea2d8', sunI: 0.75, zen: '#16213d', hor: '#33456b', hs: '#6f82b8', hg: '#262e48', hi: 0.75, glow: 1, elev: 0.75, exp: 1.25 },
  { t: 0.25, sun: '#ffad7a', sunI: 1.5, zen: '#6d8cc4', hor: '#f2b993', hs: '#ffd6b8', hg: '#5e6150', hi: 0.85, glow: 0.55, elev: 0.18, exp: 1.1 },
  { t: 0.32, sun: '#ffeccf', sunI: 2.6, zen: '#86b5e2', hor: '#dce8e2', hs: '#fff2df', hg: '#6f7f52', hi: 1.0, glow: 0, elev: 0.55, exp: 1.05 },
  { t: 0.5, sun: '#fff6e8', sunI: 3.0, zen: '#78b0e2', hor: '#d6e6e6', hs: '#fff6e8', hg: '#6f7f52', hi: 1.05, glow: 0, elev: 1.0, exp: 1.0 },
  { t: 0.66, sun: '#ffefd4', sunI: 2.8, zen: '#80aedc', hor: '#e2e4d8', hs: '#fff0dc', hg: '#6f7a50', hi: 1.0, glow: 0, elev: 0.6, exp: 1.02 },
  { t: 0.72, sun: '#ffc07a', sunI: 2.5, zen: '#7f9fcf', hor: '#f4cf9c', hs: '#ffe0c0', hg: '#6a6448', hi: 0.95, glow: 0.1, elev: 0.32, exp: 1.05 },
  { t: 0.77, sun: '#ff8a5c', sunI: 1.7, zen: '#56659e', hor: '#f0957a', hs: '#f2b8a2', hg: '#4c4448', hi: 0.8, glow: 0.6, elev: 0.13, exp: 1.12 },
  { t: 0.82, sun: '#9a9ad8', sunI: 0.8, zen: '#25315c', hor: '#6f6696', hs: '#8a8cc0', hg: '#2e3048', hi: 0.7, glow: 1, elev: 0.6, exp: 1.22 },
  { t: 1.00, sun: '#8ea2d8', sunI: 0.75, zen: '#16213d', hor: '#33456b', hs: '#6f82b8', hg: '#262e48', hi: 0.75, glow: 1, elev: 0.75, exp: 1.25 },
];
// Новый вид — свет как у Synty: тёплое яркое солнце, небо синее, тени с холодным голубым отливом,
// снизу тёплый отражённый свет от земли
if (NEW_LOOK) {
  const SYNTY_DAY = {
    0.32: { sun: '#ffe0b4', sunI: 3.0, zen: '#5a9de2', hor: '#cfe3ec', hs: '#e4eeff', hg: '#7c6a48', hi: 0.82, exp: 1.06 },
    0.5: { sun: '#fff0d4', sunI: 3.35, zen: '#4b95e0', hor: '#cbe2ef', hs: '#e2ecff', hg: '#806e4a', hi: 0.84, exp: 1.03 },
    0.66: { sun: '#ffe2b2', sunI: 3.15, zen: '#5797dc', hor: '#d6e3e2', hs: '#eaeeff', hg: '#7c6846', hi: 0.84, exp: 1.05 },
    0.72: { sun: '#ffb66c', sunI: 2.85, zen: '#6c92cf', hor: '#f6c78e', hs: '#ffd8b2', hg: '#705c3e', hi: 0.86, exp: 1.07 },
  };
  for (const k of DAY_KEYS) if (SYNTY_DAY[k.t]) Object.assign(k, SYNTY_DAY[k.t]);
}

const Atmos = {
  t: 0.42,
  period: 600,      // секунд реального времени на сутки при скорости ×1
  cycle: true,
  c: {},

  init(scene) {
    this.scene = scene;
    // небо
    this.skyMat = new THREE.ShaderMaterial({
      side: THREE.BackSide, depthWrite: false, fog: false,
      uniforms: { uZen: { value: new THREE.Color() }, uHor: { value: new THREE.Color() }, uSunDir: { value: new THREE.Vector3(0, 1, 0) },
        uSun: { value: new THREE.Color() }, uTime: Shared.time, uNight: { value: 0 } },
      vertexShader: `varying vec3 vDir; void main() { vDir = normalize(position); gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }`,
      fragmentShader: `
        varying vec3 vDir;
        uniform vec3 uZen, uHor, uSun, uSunDir;
        uniform float uTime, uNight;
        ${NOISE_GLSL}
        void main() {
          vec3 d = normalize(vDir);
          float h = clamp(d.y, 0.0, 1.0);
          vec3 col = mix(uHor, uZen, pow(h, 0.5));
          float s = max(dot(d, normalize(uSunDir)), 0.0);
          col += uSun * (pow(s, 900.0) * 6.0 + pow(s, 12.0) * 0.35) * (1.0 - uNight * 0.7);
          vec2 p = d.xz / max(d.y, 0.06) * 0.9 + vec2(uTime * 0.008, uTime * 0.004);
          ${NEW_LOOK ? `
          // пышные «нарисованные» облака: плотные белые шапки с мягкой тенью снизу
          float n = fbm3(p * 1.25);
          float c = smoothstep(0.47, 0.6, n);
          float shade = smoothstep(0.47, 0.72, fbm3(p * 1.25 + vec2(0.06, -0.08)));
          vec3 cc = mix(mix(uHor, vec3(0.86, 0.88, 0.95), 0.5), vec3(1.0, 0.99, 0.96), shade) * (1.0 - uNight * 0.75);
          col = mix(col, cc, c * smoothstep(0.0, 0.22, d.y) * 0.95);` : `
          float c = smoothstep(0.52, 0.85, fbm3(p * 1.4));
          vec3 cc = mix(vec3(1.0, 0.98, 0.95), uHor * 1.1, 0.35) * (1.0 - uNight * 0.75);
          col = mix(col, cc, c * smoothstep(0.0, 0.25, d.y) * 0.85);`}
          float stars = step(0.997, h21(floor(d.xz / max(d.y, 0.1) * 160.0))) * uNight * smoothstep(0.1, 0.4, d.y);
          col += vec3(stars) * 1.5;
          gl_FragColor = vec4(col, 1.0);
        }`,
    });
    this.sky = new THREE.Mesh(new THREE.SphereGeometry(1, 32, 16), this.skyMat);
    this.sky.renderOrder = -10;
    this.sky.frustumCulled = false;
    scene.add(this.sky);

    // бесконечная земля под участками — горизонт без обрыва
    const fg = new THREE.PlaneGeometry(1, 1).rotateX(-Math.PI / 2);
    // рисуется первой и не пишет глубину: участки с озёрами (дно ниже нуля) просто рисуются поверх
    this.farGround = new THREE.Mesh(fg, patchMaterial(new THREE.MeshLambertMaterial({ color: '#a2c46c', depthWrite: false }), { grain: true }));
    this.farGround.position.y = -0.03;
    this.farGround.renderOrder = -5;
    this.farGround.receiveShadow = true;
    scene.add(this.farGround);

    this.initBirds(scene);
    this.initLife(scene);
    this.apply();
  },

  sample() {
    const t = this.t;
    let a = DAY_KEYS[0], b = DAY_KEYS[DAY_KEYS.length - 1];
    for (let i = 0; i < DAY_KEYS.length - 1; i++) {
      if (t >= DAY_KEYS[i].t && t <= DAY_KEYS[i + 1].t) { a = DAY_KEYS[i]; b = DAY_KEYS[i + 1]; break; }
    }
    const k = b.t > a.t ? (t - a.t) / (b.t - a.t) : 0;
    const col = (x, y) => new THREE.Color(x).lerp(new THREE.Color(y), k);
    return {
      sun: col(a.sun, b.sun), sunI: lerp(a.sunI, b.sunI, k), zen: col(a.zen, b.zen), hor: col(a.hor, b.hor),
      hs: col(a.hs, b.hs), hg: col(a.hg, b.hg), hi: lerp(a.hi, b.hi, k), glow: lerp(a.glow, b.glow, k),
      elev: lerp(a.elev, b.elev, k), exp: lerp(a.exp, b.exp, k),
    };
  },

  // dt — игровое время (на паузе стоит), realDt — настоящее (ветер и облака не замирают)
  update(dt, realDt) {
    if (this.cycle) this.t = (this.t + dt / this.period) % 1;
    Shared.time.value += realDt;
    this.apply();
  },

  apply() {
    const s = this.c = this.sample();
    const night = s.glow;
    const E = Engine;
    if (!E.sun) return;
    E.sun.color.copy(s.sun);
    E.sun.intensity = s.sunI;
    E.hemi.color.copy(s.hs);
    E.hemi.groundColor.copy(s.hg);
    E.hemi.intensity = s.hi;
    if (E.fill) {
      E.fill.color.copy(s.hs).lerp(new THREE.Color('#9fb6ff'), 0.6);
      E.fill.intensity = 0.55 * s.hi;
    }
    E.renderer.toneMappingExposure = s.exp;
    E.scene.fog.color.copy(s.hor);
    E.scene.background = s.hor;
    this.skyMat.uniforms.uZen.value.copy(s.zen);
    this.skyMat.uniforms.uHor.value.copy(s.hor);
    this.skyMat.uniforms.uSun.value.copy(s.sun);
    this.skyMat.uniforms.uNight.value = night;
    Shared.cloud.value = 1 - night * 0.8;
    // солнце (ночью — луна) идёт по небу с востока на запад
    const isNight = this.t < 0.22 || this.t > 0.8;
    const az = isNight ? 2.2 : (this.t - 0.5) * Math.PI * 1.1 + 0.25;
    const el = s.elev;
    this.sunDir = new THREE.Vector3(-Math.cos(az) * Math.cos(el), Math.sin(el), Math.sin(az) * Math.cos(el)).normalize();
    this.skyMat.uniforms.uSunDir.value.copy(isNight ? new THREE.Vector3(0.3, 0.6, -0.5) : this.sunDir);
    // окна и огни ночью
    E.matWin.color.setScalar(lerp(0.06, 3.2, night));
    E.matGlow.color.setScalar(lerp(1.6, 3.5, night));
    E.matWater.specular.setScalar(lerp(0.9, 0.35, night));
    this.night = night;
  },

  // Вызывается каждый кадр из движка: небо и земля следуют за камерой
  follow(cam, c) {
    const far = cam.far * 0.92;
    this.sky.position.copy(cam.position);
    this.sky.scale.setScalar(far);
    this.farGround.position.x = c.x;
    this.farGround.position.z = c.z;
    this.farGround.scale.set(cam.far * 3, 1, cam.far * 3);
  },

  /* ---------- Бабочки днём и светлячки ночью ---------- */

  initLife(scene) {
    const wing = new THREE.BufferGeometry();
    wing.setAttribute('position', new THREE.Float32BufferAttribute([0, 0, 0, -0.06, 0.005, -0.03, -0.05, 0, 0.04, 0, 0, 0, 0.06, 0.005, -0.03, 0.05, 0, 0.04], 3));
    wing.computeVertexNormals();
    const N = 36;
    this.flies = new THREE.InstancedMesh(wing, new THREE.MeshBasicMaterial({ side: THREE.DoubleSide }), N);
    this.flies.instanceColor = new THREE.InstancedBufferAttribute(new Float32Array(N * 3), 3);
    const cols = ['#ffffff', '#f6d24a', '#f39a3a', '#7ab0f0', '#f08ab8'];
    const c = new THREE.Color();
    for (let i = 0; i < N; i++) this.flies.setColorAt(i, c.set(cols[i % cols.length]));
    this.flies.frustumCulled = false;
    this.flies.count = 0;
    scene.add(this.flies);

    const M = 70;
    this.bugs = new THREE.InstancedMesh(new THREE.IcosahedronGeometry(0.025, 1), new THREE.MeshBasicMaterial({ color: new THREE.Color(2.4, 2.6, 0.9), toneMapped: false }), M);
    this.bugs.frustumCulled = false;
    this.bugs.count = 0;
    scene.add(this.bugs);
    this.lifeSeed = Array.from({ length: Math.max(N, M) }, (_, i) => [hash2(i, 1, 5) - 0.5, hash2(i, 2, 5) - 0.5, hash2(i, 3, 5), hash2(i, 4, 5)]);
  },

  updateLife(T, c) {
    const m = this._m, R = 14;
    // бабочки — только днём и вблизи, иначе их всё равно не разглядеть
    const day = this.night < 0.4 && c.dist < 30;
    let n = 0;
    if (day) {
      for (let i = 0; i < 36; i++) {
        const [a, b, h, ph] = this.lifeSeed[i];
        const bx = c.x + a * R * 2, bz = c.z + b * R * 2;
        const x = bx + Math.sin(T * 0.7 + ph * 9) * 0.8 + Math.sin(T * 2.3 + i) * 0.15;
        const z = bz + Math.cos(T * 0.6 + ph * 7) * 0.8;
        const y = 0.35 + h * 0.6 + Math.sin(T * 3 + i) * 0.08;
        const flap = 0.25 + Math.abs(Math.sin(T * 18 + i * 3)) * 0.9;
        this._e.set(0, T * 0.5 + ph * 6, 0);
        this._q.setFromEuler(this._e);
        m.compose(new THREE.Vector3(x, y, z), this._q, new THREE.Vector3(flap * 1.2, 1, 1.2));
        this.flies.setMatrixAt(n++, m);
      }
    }
    this.flies.count = n;
    this.flies.instanceMatrix.needsUpdate = true;
    // светлячки — ночью, мерцают у травы и деревьев
    n = 0;
    if (this.night > 0.5) {
      for (let i = 0; i < 70; i++) {
        const [a, b, h, ph] = this.lifeSeed[i];
        const x = c.x + a * R * 2.4 + Math.sin(T * 0.3 + ph * 11) * 0.6;
        const z = c.z + b * R * 2.4 + Math.cos(T * 0.25 + ph * 13) * 0.6;
        const y = 0.2 + h * 0.7 + Math.sin(T * 0.8 + i) * 0.1;
        const blink = Math.max(0, Math.sin(T * (1.2 + h) + ph * 20)) * (this.night - 0.5) * 2;
        m.makeScale(blink, blink, blink);
        m.setPosition(x, y, z);
        this.bugs.setMatrixAt(n++, m);
      }
    }
    this.bugs.count = n;
    this.bugs.instanceMatrix.needsUpdate = true;
  },

  /* ---------- Птицы ---------- */

  initBirds(scene) {
    const g = new THREE.BufferGeometry();
    const v = [0, 0, 0, -0.22, 0.04, -0.08, -0.05, 0, 0.05, 0, 0, 0, 0.22, 0.04, -0.08, 0.05, 0, 0.05];
    g.setAttribute('position', new THREE.Float32BufferAttribute(v, 3));
    g.computeVertexNormals();
    this.birdMesh = new THREE.InstancedMesh(g, new THREE.MeshBasicMaterial({ color: '#3b3632', side: THREE.DoubleSide, fog: true }), 30);
    this.birdMesh.frustumCulled = false;
    scene.add(this.birdMesh);
    this.birds = [];
    for (let f = 0; f < 3; f++) {
      const n = 6 + f * 2;
      for (let i = 0; i < n; i++) this.birds.push({ f, i, ph: Math.random() * 6.28, off: [(Math.random() - 0.5) * 1.6, (Math.random() - 0.5) * 0.6, (Math.random() - 0.5) * 1.6] });
    }
    this._m = new THREE.Matrix4();
    this._q = new THREE.Quaternion();
    this._e = new THREE.Euler();
  },

  updateBirds(T, c) {
    const m = this._m;
    let n = 0;
    const show = this.night < 0.6;
    for (const b of this.birds) {
      if (!show) break;
      const R = 9 + b.f * 5, sp = 0.12 + b.f * 0.03;
      const a = T * sp + b.f * 2.1;
      const cx = c.x + Math.cos(a) * R + b.off[0], cz = c.z + Math.sin(a * 1.3) * R * 0.7 + b.off[2];
      const y = 6 + b.f * 1.5 + b.off[1] + Math.sin(T * 0.7 + b.i) * 0.3;
      const dx = -Math.sin(a) * R, dz = Math.cos(a * 1.3) * R * 0.7 * 1.3;
      const yaw = Math.atan2(dx, dz);
      const flap = 0.55 + Math.abs(Math.sin(T * 9 + b.ph)) * 0.9;
      this._e.set(0, yaw, 0);
      this._q.setFromEuler(this._e);
      m.compose(new THREE.Vector3(cx, y, cz), this._q, new THREE.Vector3(0.85, flap * 0.85, 0.85));
      this.birdMesh.setMatrixAt(n++, m);
    }
    this.birdMesh.count = n;
    this.birdMesh.instanceMatrix.needsUpdate = true;
  },
};
