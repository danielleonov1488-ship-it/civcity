'use strict';
/* Постобработка своими шейдерами на ядре Three.js:
   мягкие тени в углах (AO), свечение огней (bloom), «миниатюрная» размытость вдали (tilt-shift),
   сглаживание (FXAA), цветокоррекция и виньетка. */

const FS_VERT = `
varying vec2 vUv;
void main() { vUv = uv; gl_Position = vec4(position.xy, 0.0, 1.0); }`;

const DEPTH_GLSL = `
uniform float uNear;
uniform float uFar;
float linDepth(float d) {
  float z = d * 2.0 - 1.0;
  return 2.0 * uNear * uFar / (uFar + uNear - z * (uFar - uNear));
}`;

const Post = {
  enabled: false,
  quality: 'high',

  init(renderer) {
    this.r = renderer;
    this.quad = new THREE.Mesh(new THREE.PlaneGeometry(2, 2));
    this.quad.frustumCulled = false;
    this.qScene = new THREE.Scene();
    this.qScene.add(this.quad);
    this.qCam = new THREE.OrthographicCamera(-1, 1, 1, -1, 0, 1);
    const gl2 = renderer.capabilities.isWebGL2;
    const hf = gl2 && (renderer.extensions.has('EXT_color_buffer_float') || renderer.extensions.has('EXT_color_buffer_half_float'));
    this.type = hf ? THREE.HalfFloatType : THREE.UnsignedByteType;
    this.supported = gl2;

    const common = { uNear: { value: 1 }, uFar: { value: 100 } };

    this.matAO = new THREE.ShaderMaterial({
      vertexShader: FS_VERT,
      uniforms: { ...THREE.UniformsUtils.clone(common), tDepth: { value: null }, uSize: { value: new THREE.Vector2() },
        uProjInv: { value: new THREE.Matrix4() }, uProjScale: { value: 500 }, uRadius: { value: 0.42 }, uIntensity: { value: 0.5 }, uBias: { value: 0.03 } },
      extensions: { derivatives: true },
      depthTest: false, depthWrite: false,
      fragmentShader: `
        varying vec2 vUv;
        uniform sampler2D tDepth;
        uniform vec2 uSize;
        uniform mat4 uProjInv;
        uniform float uProjScale, uRadius, uIntensity, uBias;
        vec3 viewPos(vec2 uv) {
          float d = texture2D(tDepth, uv).x;
          vec4 c = vec4(uv * 2.0 - 1.0, d * 2.0 - 1.0, 1.0);
          vec4 v = uProjInv * c;
          return v.xyz / v.w;
        }
        float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
        void main() {
          float d = texture2D(tDepth, vUv).x;
          if (d >= 0.99999) { gl_FragColor = vec4(1.0); return; }
          vec3 P = viewPos(vUv);
          vec3 N = normalize(cross(dFdx(P), dFdy(P)));
          float rPx = min(uProjScale * uRadius / -P.z, 90.0);
          float ang = hash(vUv * uSize) * 6.2831853;
          float occ = 0.0;
          const int S = 14;
          float r2 = uRadius * uRadius;
          for (int i = 0; i < S; i++) {
            float t = (float(i) + 0.5) / float(S);
            float a = ang + t * 6.2831853 * 3.7;
            vec2 off = vec2(cos(a), sin(a)) * t * rPx / uSize;
            vec3 v = viewPos(vUv + off) - P;
            float vv = dot(v, v);
            float vn = dot(v, N);
            float f = max(r2 - vv, 0.0);
            occ += f * f * f * max((vn - uBias) / (0.01 + vv), 0.0);
          }
          float ao = max(0.0, 1.0 - occ * uIntensity / (r2 * r2 * r2) * (5.0 / float(S)));
          gl_FragColor = vec4(vec3(ao), 1.0);
        }`,
    });

    this.matBright = new THREE.ShaderMaterial({
      vertexShader: FS_VERT,
      uniforms: { tColor: { value: null }, uTexel: { value: new THREE.Vector2() }, uThreshold: { value: 1.25 } },
      depthTest: false, depthWrite: false,
      fragmentShader: `
        varying vec2 vUv;
        uniform sampler2D tColor;
        uniform vec2 uTexel;
        uniform float uThreshold;
        void main() {
          vec3 c = texture2D(tColor, vUv + uTexel * vec2(-1.0, -1.0)).rgb + texture2D(tColor, vUv + uTexel * vec2(1.0, -1.0)).rgb
                 + texture2D(tColor, vUv + uTexel * vec2(-1.0, 1.0)).rgb + texture2D(tColor, vUv + uTexel * vec2(1.0, 1.0)).rgb;
          c *= 0.25;
          float l = max(c.r, max(c.g, c.b));
          gl_FragColor = vec4(c * smoothstep(uThreshold, uThreshold * 1.8, l), 1.0);
        }`,
    });

    this.matBlur = new THREE.ShaderMaterial({
      vertexShader: FS_VERT,
      uniforms: { tColor: { value: null }, uDir: { value: new THREE.Vector2() } },
      depthTest: false, depthWrite: false,
      fragmentShader: `
        varying vec2 vUv;
        uniform sampler2D tColor;
        uniform vec2 uDir;
        void main() {
          vec3 c = texture2D(tColor, vUv).rgb * 0.227027;
          c += (texture2D(tColor, vUv + uDir * 1.3846153).rgb + texture2D(tColor, vUv - uDir * 1.3846153).rgb) * 0.3162162;
          c += (texture2D(tColor, vUv + uDir * 3.2307692).rgb + texture2D(tColor, vUv - uDir * 3.2307692).rgb) * 0.0702702;
          gl_FragColor = vec4(c, 1.0);
        }`,
    });

    this.matFinal = new THREE.ShaderMaterial({
      vertexShader: FS_VERT,
      uniforms: {
        ...THREE.UniformsUtils.clone(common),
        tColor: { value: null }, tAO: { value: null }, tBloom: { value: null }, tDepth: { value: null },
        uTexel: { value: new THREE.Vector2() }, uAOTexel: { value: new THREE.Vector2() },
        uFocus: { value: 20 }, uDof: { value: 0.6 }, uAOStrength: { value: 1 }, uBloom: { value: 0.8 },
        uVignette: { value: 0.32 }, uSat: { value: NEW_LOOK ? 1.2 : 1.08 }, uTint: { value: new THREE.Vector3(1.02, 1.0, 0.97) },
        uSplit: { value: NEW_LOOK ? 1 : 0 },
        uUseAO: { value: 1 }, uUseBloom: { value: 1 },
      },
      depthTest: false, depthWrite: false,
      fragmentShader: `
        varying vec2 vUv;
        uniform sampler2D tColor, tAO, tBloom, tDepth;
        uniform vec2 uTexel, uAOTexel;
        uniform float uFocus, uDof, uAOStrength, uBloom, uVignette, uSat, uUseAO, uUseBloom, uSplit;
        uniform vec3 uTint;
        ${DEPTH_GLSL}
        vec3 tex(vec2 uv) { return texture2D(tColor, uv).rgb; }
        float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }
        vec3 fxaa(vec2 uv) {
          vec3 rgbNW = tex(uv + vec2(-1.0, -1.0) * uTexel), rgbNE = tex(uv + vec2(1.0, -1.0) * uTexel);
          vec3 rgbSW = tex(uv + vec2(-1.0, 1.0) * uTexel), rgbSE = tex(uv + vec2(1.0, 1.0) * uTexel);
          vec3 rgbM = tex(uv);
          float lNW = luma(rgbNW), lNE = luma(rgbNE), lSW = luma(rgbSW), lSE = luma(rgbSE), lM = luma(rgbM);
          float lMin = min(lM, min(min(lNW, lNE), min(lSW, lSE)));
          float lMax = max(lM, max(max(lNW, lNE), max(lSW, lSE)));
          vec2 dir = vec2(-((lNW + lNE) - (lSW + lSE)), ((lNW + lSW) - (lNE + lSE)));
          float red = max((lNW + lNE + lSW + lSE) * 0.03125, 0.0078125);
          float rcp = 1.0 / (min(abs(dir.x), abs(dir.y)) + red);
          dir = clamp(dir * rcp, -8.0, 8.0) * uTexel;
          vec3 a = 0.5 * (tex(uv + dir * (1.0 / 3.0 - 0.5)) + tex(uv + dir * (2.0 / 3.0 - 0.5)));
          vec3 b = a * 0.5 + 0.25 * (tex(uv - dir * 0.5) + tex(uv + dir * 0.5));
          float lB = luma(b);
          return (lB < lMin || lB > lMax) ? a : b;
        }
        void main() {
          float d = texture2D(tDepth, vUv).x;
          float z = linDepth(d);
          // размытие вне фокуса: дальний план и самый ближний — как у игрушечной диорамы
          float coc = clamp((abs(z - uFocus) - uFocus * 0.3) / (uFocus * 1.25), 0.0, 1.0) * uDof;
          vec3 col;
          if (coc > 0.03) {
            // яркие точки (блики на воде, искры) ограничиваем, иначе размытие растекает их в белую дымку
            col = min(tex(vUv), vec3(1.4));
            float wsum = 1.0;
            for (int i = 0; i < 14; i++) {
              float t = (float(i) + 0.5) / 14.0;
              float a = float(i) * 2.39996;
              vec2 o = vec2(cos(a), sin(a)) * sqrt(t) * coc * 6.5 * uTexel;
              col += min(tex(vUv + o), vec3(1.4));
              wsum += 1.0;
            }
            col /= wsum;
          } else {
            col = fxaa(vUv);
          }
          if (uUseAO > 0.5) {
            float ao = 0.0, ws = 0.0;
            for (int x = -1; x <= 1; x++) for (int y = -1; y <= 1; y++) {
              vec2 o = vec2(float(x), float(y)) * uAOTexel * 1.5;
              float zz = linDepth(texture2D(tDepth, vUv + o).x);
              float w = exp(-abs(zz - z) / (z * 0.04 + 0.01));
              ao += texture2D(tAO, vUv + o).r * w;
              ws += w;
            }
            ao /= max(ws, 0.0001);
            col *= mix(1.0, ao, uAOStrength);
          }
          if (uUseBloom > 0.5) col += texture2D(tBloom, vUv).rgb * uBloom;
          float l = dot(col, vec3(0.2126, 0.7152, 0.0722));
          col = mix(vec3(l), col, uSat) * uTint;
          if (uSplit > 0.5) {
            // как у Synty: тени чуть холоднее, свет теплее, немного больше контраста
            float k = smoothstep(0.08, 0.9, l);
            col *= mix(vec3(0.93, 0.98, 1.07), vec3(1.05, 1.01, 0.95), k);
            col = (col - 0.5 * l) * 1.06 + 0.5 * l;
          }
          vec2 q = vUv - 0.5;
          col *= 1.0 - uVignette * dot(q, q) * 1.7;
          gl_FragColor = vec4(max(col, 0.0), 1.0);
          #include <tonemapping_fragment>
          #include <colorspace_fragment>
        }`,
    });
  },

  setQuality(q) {
    this.quality = q;
    this.enabled = this.supported && q !== 'low';
    this.sizeKey = '';
  },

  ensureTargets(w, h) {
    const key = w + 'x' + h + this.quality;
    if (this.sizeKey === key) return;
    this.sizeKey = key;
    for (const k of ['rtScene', 'rtAO', 'rtB1', 'rtB2']) if (this[k]) { this[k].dispose(); if (this[k].depthTexture) this[k].depthTexture.dispose(); }
    const opts = { type: this.type, minFilter: THREE.LinearFilter, magFilter: THREE.LinearFilter };
    this.rtScene = new THREE.WebGLRenderTarget(w, h, { ...opts, depthBuffer: true });
    this.rtScene.depthTexture = new THREE.DepthTexture(w, h);
    this.rtScene.depthTexture.type = THREE.UnsignedIntType;
    const aoDiv = this.quality === 'high' ? 2 : 3;
    this.rtAO = new THREE.WebGLRenderTarget(Math.max(1, Math.floor(w / aoDiv)), Math.max(1, Math.floor(h / aoDiv)), { type: THREE.UnsignedByteType, depthBuffer: false });
    const bw = Math.max(1, Math.floor(w / 4)), bh = Math.max(1, Math.floor(h / 4));
    this.rtB1 = new THREE.WebGLRenderTarget(bw, bh, { ...opts, depthBuffer: false });
    this.rtB2 = new THREE.WebGLRenderTarget(bw, bh, { ...opts, depthBuffer: false });
  },

  pass(mat, target) {
    this.quad.material = mat;
    this.r.setRenderTarget(target);
    this.r.render(this.qScene, this.qCam);
  },

  render(scene, camera, o) {
    const r = this.r;
    if (!this.enabled) { r.setRenderTarget(null); r.render(scene, camera); return; }
    const size = r.getDrawingBufferSize(new THREE.Vector2());
    const w = size.x, h = size.y;
    if (!w || !h) return;      // окно свёрнуто — рисовать некуда
    this.ensureTargets(w, h);
    r.setRenderTarget(this.rtScene);
    r.render(scene, camera);

    const near = camera.near, far = camera.far;
    const useAO = o.ao !== false;
    if (useAO) {
      const m = this.matAO.uniforms;
      m.tDepth.value = this.rtScene.depthTexture;
      m.uSize.value.set(this.rtAO.width, this.rtAO.height);
      m.uProjInv.value.copy(camera.projectionMatrixInverse);
      m.uProjScale.value = this.rtAO.height / (2 * Math.tan(THREE.MathUtils.degToRad(camera.fov) / 2));
      this.pass(this.matAO, this.rtAO);
    }
    const b = this.matBright.uniforms;
    b.tColor.value = this.rtScene.texture;
    b.uTexel.value.set(1 / w, 1 / h);
    this.pass(this.matBright, this.rtB1);
    const bl = this.matBlur.uniforms;
    for (let i = 0; i < 2; i++) {
      bl.tColor.value = this.rtB1.texture; bl.uDir.value.set(1.6 / this.rtB1.width, 0); this.pass(this.matBlur, this.rtB2);
      bl.tColor.value = this.rtB2.texture; bl.uDir.value.set(0, 1.6 / this.rtB1.height); this.pass(this.matBlur, this.rtB1);
    }
    const f = this.matFinal.uniforms;
    f.tColor.value = this.rtScene.texture;
    f.tDepth.value = this.rtScene.depthTexture;
    f.tAO.value = this.rtAO.texture;
    f.tBloom.value = this.rtB1.texture;
    f.uNear.value = near; f.uFar.value = far;
    f.uTexel.value.set(1 / w, 1 / h);
    f.uAOTexel.value.set(1 / this.rtAO.width, 1 / this.rtAO.height);
    f.uFocus.value = o.focus;
    f.uDof.value = o.dof;
    f.uUseAO.value = useAO ? 1 : 0;
    f.uBloom.value = o.bloom;
    this.matAO.uniforms.uNear.value = near;
    this.matAO.uniforms.uFar.value = far;
    this.pass(this.matFinal, null);
  },
};
