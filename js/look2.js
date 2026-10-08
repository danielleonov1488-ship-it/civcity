'use strict';
/* Новый вид (адрес с ?new): жители, деревья, камни и мелочи в стиле Synty POLYGON Ancient Empire.
   Модели — из набора Artisau (CC0), запечены в assets/look2/ страницей lab/bake.html:
   people.* — жители на общем скелете и кадры движений, props.* — неподвижные модели.
   Всех жителей одного вида видеокарта рисует одной пачкой: позы берутся из таблицы костей. */

const NEW_LOOK = /[?&]new\b/.test(location.search);
const GAME_M = 0.187;          // один метр в клетках игры: житель 1,82 м ≈ 0,34 клетки
const TILE_M = 1 / GAME_M;     // метров в клетке

// Вода, трава и камни — какие модели набора идут на каждый вид природы и какой они высоты (в клетках)
const LOOK2_NATURE = {
  [N_OAK]: { models: ['Tree', 'Trre', 'Tree Fruits'], h: 1.0 },
  [N_PINE]: { models: ['Pine.002', 'Pine.001', 'Pine.002'], h: 1.15 },
  [N_CYPRESS]: { models: ['Pine', 'Pine.001'], h: 1.25 },
  [N_BUSH]: { models: ['Bush', 'Flower Bush'], h: 0.3 },
  [N_ROCK]: { models: ['rock.002', 'rock.010'], h: 0.2 },
  [N_STONE]: { models: ['rock', 'rock.008'], h: 0.26, cluster: 3 },
  [N_MARBLE]: { models: ['rock.005', 'rock.013'], h: 0.26, cluster: 3, tint: '#f6f3ec' },
  [N_IRON]: { models: ['rock.015', 'rock'], h: 0.26, cluster: 3, tint: '#9a5638' },
  [N_FLOWERS]: { models: ['Daisy Pack', 'Tulip Pack', 'Blue Jazz Pack'], h: 0.12 },
  grass: { models: ['Grass', 'Fern'], h: 0.1 },
};

// Кого из запечённых жителей выпускать на улицу, в зависимости от роли и класса дома
const LOOK2_ROLES = {
  woman: ['woman'],
  patrician: ['senator', 'rich'],
  merchant: ['rich', 'common'],
  soldier: ['rich'],
  child: ['common', 'woman', 'poor'],
  plebs: ['common', 'poor', 'poor', 'common'],
  citizens: ['common', 'rich', 'common'],
  patricians: ['rich', 'senator'],
};

const CROWD_GLSL = `
attribute vec4 aSkinIdx;
attribute vec4 aSkinW;
attribute vec4 aAnim;          // строка начала движения, число кадров, фаза 0..1, —
uniform sampler2D uBones;
uniform vec2 uBonesSize;
mat4 l2Bone(float b, float row) {
  float x = b * 3.0;
  float v = (row + 0.5) / uBonesSize.y;
  vec4 r0 = texture2D(uBones, vec2((x + 0.5) / uBonesSize.x, v));
  vec4 r1 = texture2D(uBones, vec2((x + 1.5) / uBonesSize.x, v));
  vec4 r2 = texture2D(uBones, vec2((x + 2.5) / uBonesSize.x, v));
  return mat4(r0.x, r1.x, r2.x, 0.0, r0.y, r1.y, r2.y, 0.0, r0.z, r1.z, r2.z, 0.0, r0.w, r1.w, r2.w, 1.0);
}
mat4 l2Skin() {
  float fr = fract(aAnim.z) * aAnim.y;
  float f0 = floor(fr), t = fr - f0;
  float row0 = aAnim.x + f0, row1 = aAnim.x + mod(f0 + 1.0, aAnim.y);
  mat4 m = mat4(0.0);
  for (int k = 0; k < 4; k++) {
    float w = aSkinW[k];
    if (w > 0.0) m += (l2Bone(aSkinIdx[k], row0) * (1.0 - t) + l2Bone(aSkinIdx[k], row1) * t) * w;
  }
  return m;
}`;

const Look2 = {
  ready: false,
  time: { value: 0 },

  async load() {
    const get = async n => {
      const r = await fetch('assets/look2/' + n);
      if (!r.ok) throw new Error('нет ' + n);
      return n.endsWith('.json') ? r.json() : r.arrayBuffer();
    };
    const [pj, pb, sj, sb] = await Promise.all([get('people.json'), get('people.bin'), get('props.json'), get('props.bin')]);
    this.people = { meta: pj, buf: pb };
    this.props = { meta: sj, buf: sb };
    this.geoCache = new Map();
    this.ready = true;
  },

  view(buf, ref, Type) { return new Type(buf, ref[0], ref[1]); },

  // Палитра набора хранится в sRGB, а три.js считает цвета вершин линейными
  colorAttr(u8, tint, k) {
    const f = new Float32Array(u8.length);
    const t = tint ? new THREE.Color(tint) : null;
    for (let i = 0; i < u8.length; i++) {
      const c = u8[i] / 255;
      let lin = c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
      if (t) lin = lin * (1 - k) + [t.r, t.g, t.b][i % 3] * k * (0.6 + lin);
      f[i] = lin;
    }
    return new THREE.BufferAttribute(f, 3);
  },

  // Неподвижная модель набора: геометрия в метрах, с цветами вершин
  propGeometry(name, tint, tintK) {
    const key = name + '|' + (tint || '');
    if (this.geoCache.has(key)) return this.geoCache.get(key).clone();
    const m = this.props.meta.models[name];
    if (!m) return null;
    const buf = this.props.buf;
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.BufferAttribute(this.view(buf, m.pos, Float32Array).slice(), 3));
    g.setAttribute('color', this.colorAttr(this.view(buf, m.col, Uint8Array), tint, tintK || 0.65));
    g.setIndex(new THREE.BufferAttribute(this.view(buf, m.idx, m.i32 ? Uint32Array : Uint16Array).slice(), 1));
    this.geoCache.set(key, g);
    return g.clone();
  },

  // Природа: модель, приведённая к нужной высоте (в клетках), без индексов — для плоских граней
  natureGeometry(kind, v) {
    const def = LOOK2_NATURE[kind];
    if (!def || !this.ready) return null;
    const name = def.models[v % def.models.length];
    const meta = this.props.meta.models[name];
    if (!meta) return null;
    const h = meta.max[1] - meta.min[1];
    const s = def.h / Math.max(0.01, h) * (1 + (v % 3) * 0.08);
    const parts = [];
    const n = def.cluster || 1;
    for (let i = 0; i < n; i++) {
      const g = this.propGeometry(i ? def.models[(v + i) % def.models.length] : name, def.tint);
      const a = i * 2.2 + v, r = i ? 0.2 : 0, k = i ? 0.75 - i * 0.1 : 1;
      g.applyMatrix4(new THREE.Matrix4().makeRotationY(a).scale(new THREE.Vector3(s * k, s * k, s * k)).setPosition(Math.cos(a) * r, 0, Math.sin(a) * r));
      parts.push(g);
    }
    return this.merge(parts).toNonIndexed();
  },

  merge(list) {
    if (list.length === 1) return list[0];
    let nv = 0, ni = 0;
    for (const g of list) { nv += g.attributes.position.count; ni += g.index.count; }
    const P = new Float32Array(nv * 3), C = new Float32Array(nv * 3), I = new Uint32Array(ni);
    let ov = 0, oi = 0;
    for (const g of list) {
      P.set(g.attributes.position.array, ov * 3);
      C.set(g.attributes.color.array, ov * 3);
      const idx = g.index.array;
      for (let i = 0; i < idx.length; i++) I[oi + i] = idx[i] + ov;
      ov += g.attributes.position.count; oi += idx.length;
    }
    const out = new THREE.BufferGeometry();
    out.setAttribute('position', new THREE.BufferAttribute(P, 3));
    out.setAttribute('color', new THREE.BufferAttribute(C, 3));
    out.setIndex(new THREE.BufferAttribute(I, 1));
    return out;
  },

  /* ---------- Толпа ---------- */

  crowdMaterial(tex, depth) {
    const m = depth ? new THREE.MeshDepthMaterial({ depthPacking: THREE.RGBADepthPacking }) : new THREE.MeshLambertMaterial({ vertexColors: true, flatShading: true });
    const size = new THREE.Vector2(tex.image.width, tex.image.height);
    m.onBeforeCompile = sh => {
      sh.uniforms.uBones = { value: tex };
      sh.uniforms.uBonesSize = { value: size };
      sh.vertexShader = sh.vertexShader
        .replace('#include <common>', '#include <common>\n' + CROWD_GLSL)
        .replace('#include <beginnormal_vertex>', 'vec3 objectNormal = vec3(0.0, 1.0, 0.0);')
        .replace('#include <begin_vertex>', 'vec3 transformed = (l2Skin() * vec4(position, 1.0)).xyz;');
    };
    m.customProgramCacheKey = () => 'crowd' + (depth ? 'd' : '');
    return m;
  },

  initCrowd(scene, cap) {
    const meta = this.people.meta, buf = this.people.buf;
    this.boneTex = {};
    for (const [b, bd] of Object.entries(meta.bodies)) {
      const t = new THREE.DataTexture(this.view(buf, bd.tex, Float32Array).slice(), meta.bones * 3, bd.rows, THREE.RGBAFormat, THREE.FloatType);
      t.magFilter = t.minFilter = THREE.NearestFilter;
      t.needsUpdate = true;
      this.boneTex[b] = { tex: t, mat: this.crowdMaterial(t), depth: this.crowdMaterial(t, true) };
    }
    this.crowd = meta.variants.map(v => {
      const g = new THREE.BufferGeometry();
      g.setAttribute('position', new THREE.BufferAttribute(this.view(buf, v.pos, Float32Array).slice(), 3));
      g.setAttribute('color', this.colorAttr(this.view(buf, v.col, Uint8Array)));
      g.setAttribute('aSkinIdx', new THREE.BufferAttribute(this.view(buf, v.si, Uint8Array).slice(), 4));
      g.setAttribute('aSkinW', new THREE.BufferAttribute(this.view(buf, v.sw, Uint8Array).slice(), 4, true));
      g.setIndex(new THREE.BufferAttribute(this.view(buf, v.idx, Uint16Array).slice(), 1));
      const anim = new THREE.InstancedBufferAttribute(new Float32Array(cap * 4), 4);
      anim.setUsage(THREE.DynamicDrawUsage);
      g.setAttribute('aAnim', anim);
      const bt = this.boneTex[v.body];
      const mesh = new THREE.InstancedMesh(g, bt.mat, cap);
      mesh.customDepthMaterial = bt.depth;
      mesh.instanceMatrix.setUsage(THREE.DynamicDrawUsage);
      mesh.castShadow = true;
      mesh.receiveShadow = true;
      mesh.frustumCulled = false;
      mesh.count = 0;
      scene.add(mesh);
      return { v, mesh, anim, cap, n: 0 };
    });
    this.byRole = {};
    this.crowd.forEach((c, i) => (this.byRole[c.v.role] ||= []).push(i));
    this._m = new THREE.Matrix4(); this._q = new THREE.Quaternion(); this._p = new THREE.Vector3(); this._s = new THREE.Vector3(); this._up = new THREE.Vector3(0, 1, 0);
  },

  pickVariant(w, cls) {
    const roles = LOOK2_ROLES[w.role] || LOOK2_ROLES[cls] || ['common'];
    const role = roles[Math.floor(w.seed * 97) % roles.length];
    const list = this.byRole[role] || this.byRole.common;
    return list[Math.floor(w.seed * 7919) % list.length];
  },

  drawWalkers(list, realDt) {
    this.time.value += realDt;
    for (const c of this.crowd) c.n = 0;
    const body = this.people.meta.bodies;
    for (const w of list) {
      if (w.v2 === undefined) w.v2 = this.pickVariant(w, w.cls);
      const c = this.crowd[w.v2];
      if (c.n >= c.cap) continue;
      const clips = body[c.v.body].clips;
      // шаг анимации привязан к скорости: длина шага у этих тел ≈ 1,3 м за цикл
      let clip, rate;
      if (w.moving) { clip = clips.Walk_Loop; rate = Math.min(2.4, (w.speed * TILE_M / 1.3) * (w.gameRate || 1)); }
      else { clip = w.seed < 0.35 ? clips.Idle_Talking_Loop : clips.Idle_Loop; rate = 1 / clip.dur; }
      if (w.clip2 !== clip) { w.clip2 = clip; w.ph2 = w.seed; }
      w.ph2 = (w.ph2 + realDt * rate) % 1;
      const i = c.n++;
      const s = GAME_M * w.alpha * (w.role === 'child' ? 0.72 : 1);
      this._q.setFromAxisAngle(this._up, w.yaw);
      this._p.set(w.wx, ROAD_TOP, w.wy);
      this._s.set(s, s, s);
      c.mesh.setMatrixAt(i, this._m.compose(this._p, this._q, this._s));
      c.anim.setXYZW(i, clip.row, clip.frames, w.ph2, 0);
    }
    for (const c of this.crowd) {
      c.mesh.count = c.n;
      if (c.n) { c.mesh.instanceMatrix.needsUpdate = true; c.anim.needsUpdate = true; }
    }
  },

  // Сырые массивы модели (без копий) для вклейки в здания
  raw(name) {
    const m = this.props.meta.models[name];
    if (!m) return null;
    if (!m._raw) {
      const buf = this.props.buf;
      m._raw = { P: this.view(buf, m.pos, Float32Array), C: this.colorAttr(this.view(buf, m.col, Uint8Array)).array, I: this.view(buf, m.idx, m.i32 ? Uint32Array : Uint16Array) };
    }
    return m;
  },
};

/* Украшения зданий в новом виде: амфоры, ящики, статуи, деревья и кусты внутри участков
   берутся из набора, а не строятся из кубиков. Модель ставится на y, поворот rot, высота h (в клетках). */
if (NEW_LOOK) {
  MB.prototype.prop = function (name, x, y, z, rot, h, tint) {
    const m = Look2.ready && Look2.raw(name);
    if (!m) return false;
    const { P, C, I } = m._raw;
    const s = h / Math.max(1e-6, m.max[1] - m.min[1]);
    const ca = Math.cos(rot || 0), sa = Math.sin(rot || 0);
    const t = tint ? lin(tint) : null;
    const B = this.buckets[this.bucket];
    for (let k = 0; k < I.length; k++) {
      const i = I[k] * 3;
      const px = P[i] * s, py = (P[i + 1] - m.min[1]) * s, pz = P[i + 2] * s;
      B.p.push(x + px * ca + pz * sa, y + py, z - px * sa + pz * ca);
      if (t) B.c.push(C[i] * 0.35 + t[0] * 0.65 * (0.6 + C[i]), C[i + 1] * 0.35 + t[1] * 0.65 * (0.6 + C[i + 1]), C[i + 2] * 0.35 + t[2] * 0.65 * (0.6 + C[i + 2]));
      else B.c.push(C[i], C[i + 1], C[i + 2]);
    }
    return true;
  };
  const h3 = (x, z, k) => Math.abs(Math.sin(x * 127.1 + z * 311.7 + k * 74.7) * 43758.5453) % 1;
  const pickBy = (list, x, z) => list[Math.floor(h3(x, z, 1) * list.length) % list.length];
  const wrap = (fn, impl) => function (...a) { return impl(...a) === false ? fn(...a) : undefined; };
  const JARS = ['Jar', 'Jar.001', 'Jar.002', 'Jar.003', 'Jar.004', 'Jar.005'];
  const GODS = ['Zeus', 'Athenea', 'Hermes', 'Hercules', 'Poseidon', 'Hera', 'Demeter', 'Artemisa'];
  amphora = wrap(amphora, (mb, x, z, s, color, y) => mb.prop(pickBy(JARS, x, z), x, y || 0, z, h3(x, z, 2) * 6.28, 0.2 * (s || 1)));
  crate = wrap(crate, (mb, x, z, s, y) => mb.prop('Shop Box', x, y || 0, z, h3(x, z, 3) * 6.28, 0.12 * (s || 1)));
  pot = wrap(pot, (mb, x, z, s, flower, y) => mb.prop('Bush for Pot', x, y || 0, z, h3(x, z, 4) * 6.28, 0.22 * (s || 1)));
  bush = wrap(bush, (mb, x, z, s) => mb.prop('Bush', x, 0, z, h3(x, z, 5) * 6.28, 0.24 * (s || 1)));
  treeCypress = wrap(treeCypress, (mb, x, z, s) => mb.prop('Pine', x, 0, z, h3(x, z, 6) * 6.28, 0.95 * (s || 1)));
  treePine = wrap(treePine, (mb, x, z, s) => mb.prop('Pine.002', x, 0, z, h3(x, z, 7) * 6.28, 0.9 * (s || 1)));
  treeOlive = wrap(treeOlive, (mb, x, z, s) => mb.prop(pickBy(['Tree', 'Trre'], x, z), x, 0, z, h3(x, z, 8) * 6.28, 0.6 * (s || 1)));
  treeOak = wrap(treeOak, (mb, x, z, s) => mb.prop('Tree Fruits', x, 0, z, h3(x, z, 9) * 6.28, 0.85 * (s || 1)));
  statueFigure = wrap(statueFigure, (mb, x, z, y0, s, color, gold) => {
    if (!mb.prop('Statue Base', x, y0, z, 0, 0.2 * s)) return false;
    return mb.prop(gold ? 'Zeus' : pickBy(GODS, x, z), x, y0 + 0.2 * s, z, 0, 0.42 * s);
  });
}
