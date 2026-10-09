'use strict';
/* 3D-движок на Three.js: сцена, камера, земля участков, здания, природа (инстансинг),
   жители, частицы, подсказки стройки. Картинку дорисовывают post.js и atmos.js. */

const GROUND_HEX = ['#9fc46a', '#a6c870', '#aecd78', '#98bd62', '#e3d2a0', '#8fb7a6', '#6f9f9a'];
const LOCK_TINT = new THREE.Color('#b7b29a');
const WATER_Y = -0.07;     // гладь воды
const GROUND_RES = 4;      // у воды рельеф мельче клетки (4×4), чтобы берега были круглыми; суша — по клетке
const BED_SAND = new THREE.Color('#dccb98'), BED_SHALLOW = new THREE.Color('#86b9a2'), BED_DEEP = new THREE.Color('#3d7a84');

// Сплайн Катмулла — Рома: плавная кривая через четыре значения
function catmull(p0, p1, p2, p3, t) {
  return p1 + 0.5 * t * (p2 - p0 + t * (2 * p0 - 5 * p1 + 4 * p2 - p3 + t * (3 * (p1 - p2) + p3 - p0)));
}
const PITCH_NEAR = 0.3, PITCH_FAR = 0.98;
const DIST_MIN = 6, DIST_MAX = 75;

const QUALITY = {
  low: { dpr: 1, shadow: 1024, grass: 0.15 },
  medium: { dpr: 1.25, shadow: 2048, grass: 0.5 },
  high: { dpr: 2, shadow: 4096, grass: 1 },
};

const Engine = {
  renderer: null, scene: null, camera: null, sun: null, hemi: null,
  cam: { x: PLOT / 2, z: PLOT / 2, yaw: Math.PI / 4, yawTarget: Math.PI / 4, dist: 26, distTarget: 26 },
  plots: new Map(),
  bGroups: new Map(),
  bIndex: new Map(),
  animIds: new Set(),
  dirty: new Set(),
  emitters: [],
  W: 0, H: 0,
  T: 0,
  quality: 'high',

  init(canvas, quality) {
    const r = this.renderer = new THREE.WebGLRenderer({ canvas, antialias: true, powerPreference: 'high-performance' });
    r.shadowMap.enabled = true;
    r.shadowMap.type = THREE.PCFSoftShadowMap;
    r.toneMapping = THREE.ACESFilmicToneMapping;
    r.toneMappingExposure = 1.0;
    r.outputColorSpace = THREE.SRGBColorSpace;

    const s = this.scene = new THREE.Scene();
    s.background = new THREE.Color('#d6e6e6');
    s.fog = new THREE.Fog('#d6e6e6', 40, 120);
    this.camera = new THREE.PerspectiveCamera(32, 1, 0.5, 400);

    this.hemi = new THREE.HemisphereLight('#fff4e2', '#6f7f52', 1.05);
    s.add(this.hemi);
    const sun = this.sun = new THREE.DirectionalLight('#fff0d6', 2.9);
    sun.castShadow = true;
    sun.shadow.bias = -0.0003;
    sun.shadow.normalBias = 0.025;
    s.add(sun);
    s.add(sun.target);
    // мягкий заполняющий свет с другой стороны — тени не проваливаются в черноту
    this.fill = new THREE.DirectionalLight('#b8c8ff', 0.5);
    s.add(this.fill);
    s.add(this.fill.target);

    this.mat = patchMaterial(new THREE.MeshLambertMaterial({ vertexColors: true, side: THREE.DoubleSide }));
    this.matGlow = new THREE.MeshBasicMaterial({ vertexColors: true, side: THREE.DoubleSide });
    this.matWin = new THREE.MeshBasicMaterial({ vertexColors: true, side: THREE.DoubleSide });
    this.matGround = patchMaterial(new THREE.MeshLambertMaterial({ vertexColors: true }), { grain: true });
    this.waterNormals = makeWaterNormals();
    this.matWater = makeWaterMaterial(this.waterNormals);
    this.matTree = patchMaterial(new THREE.MeshLambertMaterial({ vertexColors: true, side: THREE.DoubleSide }), { sway: true });
    this.matRock = patchMaterial(new THREE.MeshLambertMaterial({ vertexColors: true }));
    // новый вид: гранёные деревья и камни, как у Synty
    if (NEW_LOOK) { this.matTree.flatShading = true; this.matRock.flatShading = true; }
    this.matGhost = new THREE.MeshLambertMaterial({ vertexColors: true, transparent: true, opacity: 0.6, side: THREE.DoubleSide, depthWrite: false });
    this.matBorder = new THREE.MeshBasicMaterial({ color: '#fffaf0', transparent: true, opacity: 0.75, depthWrite: false });
    this.matGrid = new THREE.LineBasicMaterial({ color: '#ffffff', transparent: true, opacity: 0.22, depthWrite: false });

    this.raycaster = new THREE.Raycaster();
    this.groundPlane = new THREE.Plane(new THREE.Vector3(0, 1, 0), 0);
    this._m = new THREE.Matrix4();
    this._c = new THREE.Color();
    this._q = new THREE.Quaternion();
    this._p = new THREE.Vector3();
    this._s = new THREE.Vector3();
    this._up = new THREE.Vector3(0, 1, 0);

    Post.init(r);
    Atmos.init(s);
    const far = new THREE.Color(GROUND_HEX[0]).lerp(LOCK_TINT, 0.42).multiplyScalar(0.93);
    Atmos.farGround.material.color.copy(far);
    this.initNature();
    this.initOverlays();
    this.initWalkers();
    this.initParticles();
    this.setQuality(quality || 'high');
    window.addEventListener('resize', () => this.resize());
  },

  setQuality(q) {
    this.quality = q;
    const Q = QUALITY[q];
    this.renderer.setPixelRatio(Math.min(Q.dpr, window.devicePixelRatio || 1));
    const sh = this.sun.shadow;
    if (sh.mapSize.x !== Q.shadow) {
      sh.mapSize.set(Q.shadow, Q.shadow);
      if (sh.map) { sh.map.dispose(); sh.map = null; }
    }
    Post.setQuality(q);
    this.natDirty = true;
    this.resize();
  },

  resize() {
    // forceSize — кадр для записи видео: рисуется в своём размере, окно не важно
    this.W = this.forceSize ? this.forceSize[0] : window.innerWidth;
    this.H = this.forceSize ? this.forceSize[1] : window.innerHeight;
    this.renderer.setSize(this.W, this.H, false);
    this.camera.aspect = this.W / this.H;
    this.camera.updateProjectionMatrix();
  },

  /* ---------- Камера ---------- */

  updateCamera(dt) {
    const c = this.cam;
    const k = 1 - Math.pow(0.0005, dt);
    c.yaw += (c.yawTarget - c.yaw) * k;
    c.dist += (c.distTarget - c.dist) * k;
    if (c.tx !== undefined) { c.x += (c.tx - c.x) * k; c.z += (c.tz - c.z) * k; }
    const t = clamp((c.dist - DIST_MIN) / (DIST_MAX - DIST_MIN), 0, 1);
    // наклон — по расстоянию; кинокамера задаёт свой наклон и высоту точки взгляда
    const pitch = c.pitch !== undefined && c.pitch !== null ? c.pitch : lerp(PITCH_NEAR, PITCH_FAR, Math.pow(t, 0.4));
    const cp = Math.cos(pitch), ly = c.lookY || 0;
    const cam = this.camera;
    cam.position.set(c.x + Math.sin(c.yaw) * cp * c.dist, ly + Math.sin(pitch) * c.dist, c.z + Math.cos(c.yaw) * cp * c.dist);
    cam.lookAt(c.x, ly, c.z);
    const near = Math.max(0.2, c.dist * 0.03), far = c.dist * 7 + 60;
    if (Math.abs(cam.near - near) > 0.05 || Math.abs(cam.far - far) > 1) { cam.near = near; cam.far = far; cam.updateProjectionMatrix(); }
    cam.updateMatrixWorld();
    this.scene.fog.near = c.dist * 1.2;
    this.scene.fog.far = c.dist * 3.6 + 20;

    const sun = this.sun;
    const dir = Atmos.sunDir || new THREE.Vector3(-0.5, 0.8, 0.2);
    sun.position.set(c.x + dir.x * 45, dir.y * 45, c.z + dir.z * 45);
    sun.target.position.set(c.x, 0, c.z);
    this.fill.position.set(c.x - dir.x * 30, 18, c.z - dir.z * 30);
    this.fill.target.position.set(c.x, 0, c.z);
    const half = clamp(c.dist * 0.95, 12, 60);
    const sc = sun.shadow.camera;
    if (Math.abs(sc.right - half) > 0.5) {
      sc.left = -half; sc.right = half; sc.top = half; sc.bottom = -half;
      sc.near = 1; sc.far = 120;
      sc.updateProjectionMatrix();
    }
  },

  rotate(dir) { this.cam.yawTarget += dir * Math.PI / 2; },
  zoom(factor) { this.cam.distTarget = clamp(this.cam.distTarget * factor, DIST_MIN, DIST_MAX); },

  ndc(sx, sy) { return new THREE.Vector2((sx / this.W) * 2 - 1, -(sy / this.H) * 2 + 1); },

  groundPoint(sx, sy) {
    this.raycaster.setFromCamera(this.ndc(sx, sy), this.camera);
    const p = new THREE.Vector3();
    return this.raycaster.ray.intersectPlane(this.groundPlane, p) ? [p.x, p.z] : null;
  },

  panBy(dx, dz) {
    const c = this.cam;
    c.x += dx; c.z += dz;
    c.tx = c.x; c.tz = c.z;
    this.updateCamera(0);
  },

  lookAt(x, z) { this.cam.tx = x; this.cam.tz = z; },

  project(x, y, z) {
    const v = new THREE.Vector3(x, y, z).project(this.camera);
    return [(v.x + 1) / 2 * this.W, (1 - v.y) / 2 * this.H, v.z < 1 && v.x > -1.2 && v.x < 1.2 && v.y > -1.2 && v.y < 1.3];
  },

  pickBuilding(sx, sy) {
    this.raycaster.setFromCamera(this.ndc(sx, sy), this.camera);
    const list = [];
    for (const g of this.bGroups.values()) if (g.solid && g.solid.count) list.push(g.solid);
    const hit = this.raycaster.intersectObjects(list, false)[0];
    if (!hit) return null;
    const g = hit.object.userData.group;
    const id = g && g.ids[hit.instanceId];
    return id !== undefined ? state.buildings.get(id) || null : null;
  },

  /* ---------- Участки: земля, вода, дороги, границы ---------- */

  plotChanged(px, py) {
    for (const [dx, dy] of [[0, 0], [1, 0], [-1, 0], [0, 1], [0, -1]]) {
      const p = this.plots.get((px + dx) + ',' + (py + dy));
      if (p) { p.dirty.ground = true; p.dirty.nature = true; p.dirty.border = true; }
    }
    this.gridDirty = true;
  },

  natureChanged(tx, ty) {
    const p = this.plots.get(plotOf(tx) + ',' + plotOf(ty));
    if (p) p.dirty.nature = true;
  },

  tileColor(tx, ty) {
    const g = groundAt(tx, ty);
    const c = new THREE.Color(GROUND_HEX[g]);
    if (g < G_SAND) {
      const n = rawNatureAt(tx, ty);
      if (n === N_STONE) c.lerp(new THREE.Color('#b9b3a3'), 0.5);
      else if (n === N_MARBLE) c.lerp(new THREE.Color('#e9e6dc'), 0.55);
      else if (n === N_IRON) c.lerp(new THREE.Color('#a77a5e'), 0.5);
      else if (n >= N_OAK && n <= N_CYPRESS) c.multiplyScalar(0.9);
    }
    if (!isOwnedTile(tx, ty)) { c.lerp(LOCK_TINT, 0.42); c.multiplyScalar(0.93); }
    return c;
  },

  // «Сухость» участка в центрах клеток (с запасом в 2 клетки вокруг) — из неё плавно берётся высота дна
  plotField(px, py) {
    const t = plotTerrain(px, py);
    if (t.field) return t.field;
    const S = PLOT + 4, f = new Float32Array(S * S), x0 = px * PLOT - 2, z0 = py * PLOT - 2;
    let any = false;
    for (let b = 0; b < S; b++) {
      for (let a = 0; a < S; a++) {
        const w = waterValue(x0 + a, z0 + b);
        f[b * S + a] = w;
        if (w < WATER_LEVEL + 0.05) any = true;
      }
    }
    return (t.field = { f, S, x0, z0, any });
  },

  // Высота дна в точке мира: суша — 0, у кромки плавно уходит под воду, к середине озера глубже.
  // В центре клетки поле равно её «сухости», поэтому под водой оказываются ровно водные клетки.
  bedAt(F, X, Z) {
    if (!F.any) return 0;
    const u = X - 0.5 - F.x0, v = Z - 0.5 - F.z0, i = Math.floor(u), j = Math.floor(v), tx = u - i, tz = v - j;
    const f = F.f, S = F.S;
    const row = r => catmull(f[r * S + i - 1], f[r * S + i], f[r * S + i + 1], f[r * S + i + 2], tx);
    const w = catmull(row(j - 1), row(j), row(j + 1), row(j + 2), tz) - WATER_LEVEL;
    // на суше — пологий пляж к кромке; под водой дно сразу уходит вниз, без огромных отмелей у поверхности
    return w >= 0 ? Math.min(0, WATER_Y + w * 5) : Math.max(-0.5, WATER_Y - Math.sqrt(-w) * 0.95);
  },

  // Высоты на мелкой сетке и «мокрые» клетки (сама клетка или соседняя уходит под воду) — один раз на участок
  plotBed(px, py) {
    const t = plotTerrain(px, py);
    if (t.bed) return t.bed;
    const F = this.plotField(px, py), R = GROUND_RES, N = PLOT * R + 1;
    const h = new Float32Array(N * N), neg = new Uint8Array(PLOT * PLOT), wet = new Uint8Array(PLOT * PLOT);
    let any = false;
    if (F.any) {
      for (let j = 0; j < N; j++) {
        for (let i = 0; i < N; i++) {
          const v = this.bedAt(F, px * PLOT + i / R, py * PLOT + j / R);
          h[j * N + i] = v;
          if (v >= 0) continue;
          any = true;
          const ti = Math.min(PLOT - 1, Math.floor(i / R)), tj = Math.min(PLOT - 1, Math.floor(j / R));
          neg[tj * PLOT + ti] = 1;
          if (i % R === 0 && ti > 0) neg[tj * PLOT + ti - 1] = 1;
          if (j % R === 0 && tj > 0) neg[(tj - 1) * PLOT + ti] = 1;
          if (i % R === 0 && j % R === 0 && ti > 0 && tj > 0) neg[(tj - 1) * PLOT + ti - 1] = 1;
        }
      }
      for (let tj = 0; tj < PLOT; tj++) {
        for (let ti = 0; ti < PLOT; ti++) {
          let w = 0;
          for (let dj = -1; dj <= 1 && !w; dj++) for (let di = -1; di <= 1 && !w; di++) {
            const a = ti + di, b = tj + dj;
            if (a >= 0 && b >= 0 && a < PLOT && b < PLOT && neg[b * PLOT + a]) w = 1;
          }
          wet[tj * PLOT + ti] = w;
        }
      }
    }
    return (t.bed = { R, N, h, wet, any, F });
  },

  // Обход клеток участка: у воды — мелкая сетка, на суше — одна ячейка на клетку.
  // На стыке мелких и крупных ячеек земля ровная (высота 0), поэтому щелей нет.
  eachCell(B, fn) {
    const R = B.R;
    for (let tz = 0; tz < PLOT; tz++) {
      for (let tx = 0; tx < PLOT; tx++) {
        if (B.wet[tz * PLOT + tx]) {
          for (let b = 0; b < R; b++) for (let a = 0; a < R; a++) fn(tx * R + a, tz * R + b, 1, true);
        } else fn(tx * R, tz * R, R, false);
      }
    }
  },

  buildGround(px, py) {
    const B = this.plotBed(px, py), R = B.R, N = B.N, x0 = px * PLOT, z0 = py * PLOT, owned = isOwnedPlot(px, py);
    const tc = new Map();
    const tileCol = (tx, ty) => { const k = tx + ',' + ty; let c = tc.get(k); if (!c) { c = this.tileColor(tx, ty); tc.set(k, c); } return c; };
    const c = new THREE.Color(), w = new THREE.Color();
    const vid = new Int32Array(N * N).fill(-1), pos = [], col = [], nrm = [];
    const vert = (i, j) => {
      const q = j * N + i;
      if (vid[q] >= 0) return vid[q];
      const X = x0 + i / R, Z = z0 + j / R, h = B.h[q];
      // нормаль — по самому полю высот, чтобы соседние участки сходились без шва
      if (B.any) {
        const e = 0.12, dx = this.bedAt(B.F, X + e, Z) - this.bedAt(B.F, X - e, Z), dz = this.bedAt(B.F, X, Z + e) - this.bedAt(B.F, X, Z - e);
        const l = Math.hypot(dx, 2 * e, dz);
        nrm.push(-dx / l, 2 * e / l, -dz / l);
      } else nrm.push(0, 1, 0);
      // цвет — плавная смесь четырёх ближайших клеток
      const fx = X - 0.5, fz = Z - 0.5, ix = Math.floor(fx), iz = Math.floor(fz), ax = fx - ix, az = fz - iz;
      c.setRGB(0, 0, 0);
      c.add(w.copy(tileCol(ix, iz)).multiplyScalar((1 - ax) * (1 - az)));
      c.add(w.copy(tileCol(ix + 1, iz)).multiplyScalar(ax * (1 - az)));
      c.add(w.copy(tileCol(ix, iz + 1)).multiplyScalar((1 - ax) * az));
      c.add(w.copy(tileCol(ix + 1, iz + 1)).multiplyScalar(ax * az));
      // берег и дно: мокрый песок у кромки, бирюза на мели, тёмная зелень в глубине
      if (h < 0) {
        if (h > WATER_Y) w.copy(c).lerp(BED_SAND, Math.min(1, -h / -WATER_Y) * 0.85);
        else {
          const d = WATER_Y - h;
          w.copy(BED_SAND).lerp(BED_SHALLOW, Math.min(1, d / 0.08)).lerp(BED_DEEP, clamp((d - 0.08) / 0.3, 0, 1));
        }
        c.copy(w);
        if (!owned) { c.lerp(LOCK_TINT, 0.42); c.multiplyScalar(0.93); }
      }
      pos.push(X, h, Z);
      col.push(c.r, c.g, c.b);
      return (vid[q] = pos.length / 3 - 1);
    };
    const idx = [];
    this.eachCell(B, (i, j, st) => {
      const a = vert(i, j), b = vert(i, j + st), cc = vert(i + st, j + st), d = vert(i + st, j);
      idx.push(a, b, cc, a, cc, d);
    });
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
    g.setAttribute('color', new THREE.Float32BufferAttribute(col, 3));
    g.setAttribute('normal', new THREE.Float32BufferAttribute(nrm, 3));
    g.setIndex(idx);
    const m = new THREE.Mesh(g, this.matGround);
    m.receiveShadow = true;
    return m;
  },

  // Гладь воды: мелкая сетка над «мокрыми» клетками; глубина в вершинах даёт цвет, прозрачность и пену у кромки
  buildWater(px, py) {
    const B = this.plotBed(px, py);
    if (!B.any) return null;
    const R = B.R, N = B.N, x0 = px * PLOT, z0 = py * PLOT, s = 0.09;
    const vid = new Int32Array(N * N).fill(-1), pos = [], uv = [], nrm = [], dep = [];
    const vert = (i, j) => {
      const q = j * N + i;
      if (vid[q] >= 0) return vid[q];
      const X = x0 + i / R, Z = z0 + j / R;
      pos.push(X, WATER_Y, Z);
      nrm.push(0, 1, 0);
      uv.push(X * s, Z * s);
      dep.push(WATER_Y - B.h[q]);
      return (vid[q] = dep.length - 1);
    };
    const idx = [];
    this.eachCell(B, (i, j, st, fine) => {
      if (!fine) return;
      const q = (ii, jj) => B.h[jj * N + ii];
      if (Math.min(q(i, j), q(i, j + 1), q(i + 1, j + 1), q(i + 1, j)) >= WATER_Y) return;
      const a = vert(i, j), b = vert(i, j + 1), c = vert(i + 1, j + 1), d = vert(i + 1, j);
      idx.push(a, b, c, a, c, d);
    });
    if (!idx.length) return null;
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
    g.setAttribute('normal', new THREE.Float32BufferAttribute(nrm, 3));
    g.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2));
    g.setAttribute('aDepth', new THREE.Float32BufferAttribute(dep, 1));
    g.setIndex(idx);
    const m = new THREE.Mesh(g, this.matWater);
    m.receiveShadow = true;
    return m;
  },

  // Камыши у кромки и кувшинки на мелководье. Перестраиваются вместе с природой участка,
  // поэтому не лезут на здания и дороги.
  buildShore(px, py) {
    const B = this.plotBed(px, py);
    if (!B.any) return null;
    const x0 = px * PLOT, z0 = py * PLOT, seed = state.seed;
    const mb = new MB(px * 7919 + py * 104729 + 13);
    for (let tz = 0; tz < PLOT; tz++) {
      for (let tx = 0; tx < PLOT; tx++) {
        if (!B.wet[tz * PLOT + tx] || World.occ.has(tkey(x0 + tx, z0 + tz)) || Roads.covers(x0 + tx, z0 + tz)) continue;
        for (let k2 = 0; k2 < 4; k2++) {
          const X = x0 + tx + 0.25 + (k2 % 2) * 0.5, Z = z0 + tz + 0.25 + (k2 >> 1) * 0.5;
          const d = WATER_Y - this.bedAt(B.F, X, Z);
          const r = hash2(X * 2, Z * 2, seed + 77);
          if (d > -0.03 && d < 0.05 && r < 0.3) {
            // пучок камыша, у части — коричневые «початки»
            const n = 3 + Math.floor(r * 10) % 3;
            for (let k = 0; k < n; k++) {
              const a = hash2(X * 2 + k, Z * 2, seed + 81) * 6.28, rr = 0.04 + hash2(X * 2, Z * 2 + k, seed + 83) * 0.12;
              const cx = X + Math.cos(a) * rr, cz = Z + Math.sin(a) * rr, hh = 0.16 + hash2(cx, cz, seed + 85) * 0.18;
              mb.box(cx - 0.008, WATER_Y - 0.03, cz - 0.008, cx + 0.008, hh, cz + 0.008, k % 2 ? '#7da046' : '#6a9040', { ao: 0.85 });
              if (k % 3 === 0) mb.box(cx - 0.014, hh - 0.07, cz - 0.014, cx + 0.014, hh - 0.01, cz + 0.014, '#7a4f2c', { ao: 1 });
            }
          } else if (d > 0.07 && d < 0.3 && r > 0.955) {
            // кувшинка, иногда с цветком
            const pr = 0.07 + (r - 0.955) * 2;
            mb.cyl(X, WATER_Y + 0.002, Z, pr, 0.006, (r * 1000) % 2 < 1 ? '#5f9a3a' : '#6aa344', { segs: 9, ao: 1 });
            if ((r * 1000) % 3 < 1) {
              mb.box(X - 0.025, WATER_Y + 0.008, Z - 0.025, X + 0.025, WATER_Y + 0.04, Z + 0.025, '#f4b3cc', { ao: 1 });
              mb.box(X - 0.01, WATER_Y + 0.04, Z - 0.01, X + 0.01, WATER_Y + 0.05, Z + 0.01, '#ffe08a', { ao: 1 });
            }
          }
        }
      }
    }
    const g = mb.build(0, 0).solid;
    if (!g) return null;
    const m = new THREE.Mesh(g, this.matTree);
    m.castShadow = true;
    m.receiveShadow = true;
    return m;
  },

  buildBorder(px, py) {
    if (!isOwnedPlot(px, py)) return null;
    const x0 = px * PLOT, z0 = py * PLOT, x1 = x0 + PLOT, z1 = z0 + PLOT;
    const pos = [], F = this.plotField(px, py);
    const dash = (ax, az, bx, bz) => {
      const len = Math.hypot(bx - ax, bz - az), n = Math.floor(len / 0.8);
      const ux = (bx - ax) / len, uz = (bz - az) / len, w = 0.06;
      for (let i = 0; i < n; i++) {
        const s = i * 0.8, e = s + 0.45;
        // над водой пунктир не рисуем — он висел бы над гладью
        if (this.bedAt(F, ax + ux * (s + e) / 2, az + uz * (s + e) / 2) < WATER_Y + 0.02) continue;
        const p = (t, side) => [ax + ux * t - uz * w * side, 0.06, az + uz * t + ux * w * side];
        const a = p(s, -1), b = p(s, 1), c = p(e, 1), d = p(e, -1);
        pos.push(...a, ...b, ...c, ...a, ...c, ...d);
      }
    };
    if (!isOwnedPlot(px, py - 1)) dash(x0, z0, x1, z0);
    if (!isOwnedPlot(px + 1, py)) dash(x1, z0, x1, z1);
    if (!isOwnedPlot(px, py + 1)) dash(x0, z1, x1, z1);
    if (!isOwnedPlot(px - 1, py)) dash(x0, z0, x0, z1);
    if (!pos.length) return null;
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
    return new THREE.Mesh(g, this.matBorder);
  },

  buildSign(px, py) {
    if (isOwnedPlot(px, py) || !canBuyPlot(px, py)) return null;
    const mb = new MB(3);
    const x = px * PLOT + PLOT / 2, z = py * PLOT + PLOT / 2;
    mb.box(x - 0.06, 0, z - 0.06, x + 0.06, 1.3, z + 0.06, PAL.wood);
    mb.box(x - 0.7, 0.85, z - 0.04, x + 0.7, 1.35, z + 0.04, '#e8d7a8');
    mb.box(x - 0.75, 0.82, z - 0.05, x + 0.75, 0.86, z + 0.05, PAL.woodDark);
    mb.box(x - 0.75, 1.34, z - 0.05, x + 0.75, 1.38, z + 0.05, PAL.woodDark);
    const m = new THREE.Mesh(mb.build(0, 0).solid, this.mat);
    m.castShadow = true;
    return m;
  },

  ensurePlots(maxBuild) {
    const c = this.cam;
    const R = clamp(Math.ceil(c.dist * 1.9 / PLOT), 1, 5);
    const cpx = plotOf(Math.floor(c.x)), cpy = plotOf(Math.floor(c.z));
    let built = 0;
    const order = [];
    for (let dy = -R; dy <= R; dy++) for (let dx = -R; dx <= R; dx++) order.push([dx, dy, dx * dx + dy * dy]);
    order.sort((a, b) => a[2] - b[2]);
    for (const [dx, dy] of order) {
      const px = cpx + dx, py = cpy + dy, key = px + ',' + py;
      let p = this.plots.get(key);
      if (!p) {
        if (built >= maxBuild) continue;
        p = { px, py, group: new THREE.Group(), parts: {}, nat: [], dirty: { ground: true, nature: true, border: true } };
        this.scene.add(p.group);
        this.plots.set(key, p);
      }
      for (const part of ['ground', 'nature', 'border']) {
        if (!p.dirty[part] || built >= maxBuild) continue;
        this.rebuildPart(p, part);
        built += part === 'ground' ? 0.6 : 0.2;
      }
    }
    for (const [key, p] of this.plots) {
      if (Math.abs(p.px - cpx) > R + 1 || Math.abs(p.py - cpy) > R + 1) {
        this.disposePlot(p);
        this.plots.delete(key);
        this.natDirty = true;
      }
    }
  },

  rebuildPart(p, part) {
    const set = (name, obj) => {
      const old = p.parts[name];
      if (old) { p.group.remove(old); old.geometry.dispose(); }
      p.parts[name] = obj;
      if (obj) p.group.add(obj);
    };
    if (part === 'ground') { set('ground', this.buildGround(p.px, p.py)); set('water', this.buildWater(p.px, p.py)); }
    if (part === 'nature') { p.nat = this.natureList(p.px, p.py); this.natDirty = true; set('shore', this.buildShore(p.px, p.py)); }
    if (part === 'border') {
      set('border', this.buildBorder(p.px, p.py));
      set('sign', this.buildSign(p.px, p.py));
      for (const k of ['border', 'sign']) if (p.parts[k]) p.parts[k].visible = !this.cleanView;
    }
    p.dirty[part] = false;
  },

  // Чистый вид (интерфейс спрятан): без пунктира границ участков и табличек продажи земли
  setCleanView(on) {
    this.cleanView = on;
    for (const p of this.plots.values()) for (const k of ['border', 'sign']) if (p.parts[k]) p.parts[k].visible = !on;
  },

  disposePlot(p) {
    this.scene.remove(p.group);
    for (const obj of Object.values(p.parts)) if (obj) obj.geometry.dispose();
  },

  /* ---------- Улицы: мостовая вдоль кривой ----------
     Каждая улица (цепочка через узлы, где сходятся две) — своя сетка: подложка, ряды камней поперёк, бордюры.
     Где улицы перекрываются на перекрёстке, камни кладёт старшая, а бордюры внутри чужой мостовой не ставятся. */

  syncRoads() {
    if (this.roadVersion === Roads.version) return;
    this.roadVersion = Roads.version;
    if (!this.roadGroup) { this.roadGroup = new THREE.Group(); this.scene.add(this.roadGroup); }
    for (const m of [...this.roadGroup.children]) { this.roadGroup.remove(m); m.geometry.dispose(); }
    const strokes = Roads.strokes();
    const strokeOf = new Map();
    for (const st of strokes) for (const id of st.ids) strokeOf.set(id, st);
    for (const st of strokes) {
      const geo = this.roadGeometry(st, strokeOf);
      if (!geo) continue;
      const m = new THREE.Mesh(geo, this.mat);
      m.receiveShadow = true;
      this.roadGroup.add(m);
    }
    for (const g of [this.junctionGeometry(), this.plazaGeometry()]) {
      if (!g) continue;
      const m = new THREE.Mesh(g, this.mat);
      m.receiveShadow = true;
      this.roadGroup.add(m);
    }
  },

  roadGeometry(st, strokeOf) {
    const P = st.xy, n = P.length / 2;
    if (n < 2) return null;
    const mb = new MB(st.rank * 13 + 5);
    // направления и нормали; на острых изломах нормаль удлиняется, чтобы ширина не проседала
    const N = new Float32Array(n * 2), cum = new Float32Array(n);
    for (let i = 0; i < n; i++) {
      if (i) cum[i] = cum[i - 1] + Math.hypot(P[i * 2] - P[i * 2 - 2], P[i * 2 + 1] - P[i * 2 - 1]);
      const a = Math.max(0, i - 1), b = Math.min(n - 1, i + 1);
      let tx = P[b * 2] - P[a * 2], ty = P[b * 2 + 1] - P[a * 2 + 1];
      const l = Math.hypot(tx, ty) || 1;
      tx /= l; ty /= l;
      let k = 1;
      if (i > 0 && i < n - 1) {
        let ax = P[i * 2] - P[a * 2], ay = P[i * 2 + 1] - P[a * 2 + 1], bx = P[b * 2] - P[i * 2], by = P[b * 2 + 1] - P[i * 2 + 1];
        const la = Math.hypot(ax, ay) || 1, lb = Math.hypot(bx, by) || 1;
        ax /= la; ay /= la; bx /= lb; by /= lb;
        k = 1 / Math.max(0.55, Math.sqrt(Math.max(0, (1 + ax * bx + ay * by) / 2)));
      }
      N[i * 2] = -ty * k; N[i * 2 + 1] = tx * k;
    }
    const L = cum[n - 1];
    // точка и нормаль на расстоянии s вдоль улицы
    let hint = 0;
    const frame = s => {
      s = clamp(s, 0, L);
      if (cum[hint] > s) hint = 0;
      while (hint < n - 2 && cum[hint + 1] < s) hint++;
      const i = hint, len = cum[i + 1] - cum[i] || 1e-9, t = (s - cum[i]) / len;
      return [P[i * 2] + (P[i * 2 + 2] - P[i * 2]) * t, P[i * 2 + 1] + (P[i * 2 + 3] - P[i * 2 + 1]) * t,
        N[i * 2] + (N[i * 2 + 2] - N[i * 2]) * t, N[i * 2 + 1] + (N[i * 2 + 3] - N[i * 2 + 1]) * t];
    };
    const at = (f, l, y) => [f[0] + f[2] * l, y, f[1] + f[3] * l];
    const mine = id => strokeOf.get(id) === st;
    const older = id => { const o = strokeOf.get(id); return !o || o.rank >= st.rank; };
    const yb = 0.03 + (st.rank % 5) * 0.0015;
    const base = lin('#a2937a'), curb = lin('#ede5d2');
    const stones = ['#dbcfb2', '#d2c5a6', '#e0d5b9', '#cdbf9e', '#d6caa9'].map(lin);
    // подложка
    for (let i = 0; i < n - 1; i++) {
      const a = [P[i * 2], P[i * 2 + 1], N[i * 2], N[i * 2 + 1]], b = [P[i * 2 + 2], P[i * 2 + 3], N[i * 2 + 2], N[i * 2 + 3]];
      if (Roads.inPlaza(a[0], a[1]) && Roads.inPlaza(b[0], b[1])) continue;
      mb.quad(at(a, -ROAD_HALF, yb), at(b, -ROAD_HALF, yb), at(b, ROAD_HALF, yb), at(a, ROAD_HALF, yb), base, 1, 0);
    }
    // камни: ряды поперёк улицы со сдвигом швов, как в римской мостовой
    const box = (f0, f1, l0, l1, y, col) => {
      const A = at(f0, l0, y), B = at(f1, l0, y), C = at(f1, l1, y), D = at(f0, l1, y);
      const A0 = at(f0, l0, yb), B0 = at(f1, l0, yb), C0 = at(f1, l1, yb), D0 = at(f0, l1, yb);
      mb.quad(A, B, C, D, col, 1);
      mb.quad(A0, A, B, B0, col, 0.72);
      mb.quad(B0, B, C, C0, col, 0.72);
      mb.quad(C0, C, D, D0, col, 0.72);
      mb.quad(D0, D, A, A0, col, 0.72);
    };
    const W = ROAD_HALF - 0.03;
    // у перекрёстков камни кладёт круглая площадка (junctionGeometry)
    const junctions = [st.start, st.end].filter(e => e.deg >= 3).map(e => Roads.nodes.get(e.id)).filter(Boolean);
    for (let r = 0, s0 = 0.02; s0 + 0.28 <= L - 0.01; r++, s0 += 0.32) {
      const f0 = frame(s0), f1 = frame(s0 + 0.28), fm = frame(s0 + 0.14);
      const split = -W + 2 * W * (0.5 - (r % 2) * 0.17);
      for (const [l0, l1] of [[-W, split - 0.02], [split + 0.02, W]]) {
        const lm = (l0 + l1) / 2, cx = fm[0] + fm[2] * lm, cy = fm[1] + fm[3] * lm;
        if (Roads.nearest(cx, cy, ROAD_HALF - 0.02, older)) continue;
        if (junctions.some(j => Math.hypot(j.x - cx, j.y - cy) < ROAD_HALF + 0.05) || Roads.inPlaza(cx, cy)) continue;
        const h = hash2(Math.floor(cx * 7), Math.floor(cy * 7), 77);
        box(f0, f1, l0, l1, 0.046 + h * 0.012, stones[(h * 5) | 0]);
      }
    }
    // бордюры по краям — кроме мест, где край лежит на другой улице
    const curbAt = (f0, f1, side) => {
      const lo = side * (ROAD_HALF - 0.06), hi = side * ROAD_HALF;
      const A = at(f0, lo, 0.075), B = at(f1, lo, 0.075), C = at(f1, hi, 0.075), D = at(f0, hi, 0.075);
      mb.quad(A, B, C, D, curb, 1, 0.03);
      mb.quad(at(f0, lo, yb), A, B, at(f1, lo, yb), curb, 0.82, 0.03);
      mb.quad(at(f0, hi, 0), D, C, at(f1, hi, 0), curb, 0.82, 0.03);
    };
    for (let i = 0; i < n - 1; i++) {
      const a = [P[i * 2], P[i * 2 + 1], N[i * 2], N[i * 2 + 1]], b = [P[i * 2 + 2], P[i * 2 + 3], N[i * 2 + 2], N[i * 2 + 3]];
      for (const side of [-1, 1]) {
        const mx = (a[0] + b[0]) / 2 + (a[2] + b[2]) / 2 * side * (ROAD_HALF - 0.03), my = (a[1] + b[1]) / 2 + (a[3] + b[3]) / 2 * side * (ROAD_HALF - 0.03);
        if (Roads.inPlaza(mx, my) || Roads.nearest(mx, my, ROAD_HALF - 0.04, id => mine(id))) continue;
        curbAt(a, b, side);
      }
    }
    // тупик — круглый край с бордюром
    const cap = (f, dir) => {
      const tx = f[3] * dir, ty = -f[2] * dir;   // наружу от улицы
      const nl = Math.hypot(f[2], f[3]) || 1, ox = tx / nl, oy = ty / nl;
      const nx = f[2] / nl, ny = f[3] / nl, K = 10;
      const pt = (a, r, y) => [f[0] + (nx * Math.cos(a) + ox * Math.sin(a)) * r, y, f[1] + (ny * Math.cos(a) + oy * Math.sin(a)) * r];
      for (let k = 0; k < K; k++) {
        const a0 = Math.PI * k / K, a1 = Math.PI * (k + 1) / K;
        mb.tri([f[0], yb, f[1]], pt(a0, ROAD_HALF, yb), pt(a1, ROAD_HALF, yb), base);
        mb.tri([f[0], 0.05, f[1]], pt(a0, ROAD_HALF - 0.08, 0.05), pt(a1, ROAD_HALF - 0.08, 0.05), stones[k % 5]);
        mb.quad(pt(a0, ROAD_HALF - 0.06, 0.075), pt(a1, ROAD_HALF - 0.06, 0.075), pt(a1, ROAD_HALF, 0.075), pt(a0, ROAD_HALF, 0.075), curb, 1, 0.03);
        mb.quad(pt(a0, ROAD_HALF, 0), pt(a0, ROAD_HALF, 0.075), pt(a1, ROAD_HALF, 0.075), pt(a1, ROAD_HALF, 0), curb, 0.82, 0.03);
      }
    };
    if (!st.closed && st.start.deg === 1 && !Roads.inPlaza(P[0], P[1])) cap(frame(0), -1);
    if (!st.closed && st.end.deg === 1 && !Roads.inPlaza(P[n * 2 - 2], P[n * 2 - 1])) cap(frame(L), 1);
    return mb.build(0, 0).solid;
  },

  // Перекрёстки: круглая мощёная площадка на стыке улиц — камень в середине и венец клиньев вокруг
  junctionGeometry() {
    const mb = new MB(91);
    const base = lin('#a2937a');
    const stones = ['#dbcfb2', '#d2c5a6', '#e0d5b9', '#cdbf9e', '#d6caa9'].map(lin);
    for (const nd of Roads.nodes.values()) {
      if (nd.edges.size < 3 || Roads.inPlaza(nd.x, nd.y)) continue;
      const K = 24, y0 = 0.028, R = ROAD_HALF + 0.08;
      const pt = (a, r, y) => [nd.x + Math.cos(a) * r, y, nd.y + Math.sin(a) * r];
      for (let k = 0; k < K; k++) {
        const a0 = Math.PI * 2 * k / K, a1 = Math.PI * 2 * (k + 1) / K;
        mb.tri([nd.x, y0, nd.y], pt(a0, R, y0), pt(a1, R, y0), base);
      }
      const h = 0.05;
      // середина
      for (let k = 0; k < 8; k++) {
        const a0 = Math.PI * 2 * k / 8, a1 = Math.PI * 2 * (k + 1) / 8;
        mb.tri([nd.x, h, nd.y], pt(a0, 0.17, h), pt(a1, 0.17, h), stones[0]);
        mb.quad(pt(a0, 0.17, y0), pt(a0, 0.17, h), pt(a1, 0.17, h), pt(a1, 0.17, y0), stones[0], 0.72, 0);
      }
      // два венца клиньев со сдвигом швов
      for (const [r0, r1, n, off] of [[0.2, 0.37, 7, 0], [0.4, R - 0.03, 11, 0.5]]) {
        for (let k = 0; k < n; k++) {
          const a0 = Math.PI * 2 * (k + off) / n + 0.03, a1 = Math.PI * 2 * (k + 1 + off) / n - 0.03;
          const col = stones[(k + n) % 5], hh = h - 0.002 + ((k * 7) % 3) * 0.003;
          const A = pt(a0, r0, hh), B = pt(a1, r0, hh), C = pt(a1, r1, hh), D = pt(a0, r1, hh);
          mb.quad(A, B, C, D, col, 1, 0.04);
          mb.quad(pt(a0, r1, y0), D, C, pt(a1, r1, y0), col, 0.72, 0);
          mb.quad(pt(a0, r0, y0), A, D, pt(a0, r1, y0), col, 0.72, 0);
          mb.quad(pt(a1, r0, y0), B, C, pt(a1, r1, y0), col, 0.72, 0);
        }
      }
    }
    return mb.build(0, 0).solid;
  },

  // Площади: мощёные клетки, как прежние дороги — три ряда камней со сдвигом швов, бордюр по краю площади
  plazaGeometry() {
    if (!Roads.plaza.size) return null;
    const mb = new MB(37);
    const stones = ['#dbcfb2', '#d2c5a6', '#e0d5b9', '#cdbf9e', '#d6caa9'];
    const open = (x, z) => !Roads.plaza.has(x + ',' + z) && !Roads.tiles.has(x + ',' + z);
    for (const k of Roads.plaza) {
      const [x, z] = k.split(',').map(Number);
      mb.box(x, 0, z, x + 1, 0.03, z + 1, '#a2937a', { ao: 1 });
      for (let a = 0; a < 3; a++) {
        const split = 0.5 - (a % 2) * 0.17, z0 = z + 0.03 + a * 0.32;
        for (let b = 0; b < 2; b++) {
          const h = hash2(x * 3 + a, z * 2 + b, 77);
          const xs = b ? x + split + 0.02 : x + 0.03, xe = b ? x + 0.97 : x + split - 0.02;
          mb.box(xs, 0.03, z0, xe, 0.046 + h * 0.012, z0 + 0.28, stones[(h * 5) | 0], { ao: 0.72 });
        }
      }
      const curb = '#ede5d2';
      if (open(x, z - 1)) mb.box(x, 0, z, x + 1, 0.075, z + 0.06, curb, { ao: 0.82 });
      if (open(x, z + 1)) mb.box(x, 0, z + 0.94, x + 1, 0.075, z + 1, curb, { ao: 0.82 });
      if (open(x - 1, z)) mb.box(x, 0, z, x + 0.06, 0.075, z + 1, curb, { ao: 0.82 });
      if (open(x + 1, z)) mb.box(x + 0.94, 0, z, x + 1, 0.075, z + 1, curb, { ao: 0.82 });
    }
    return mb.build(0, 0).solid;
  },

  // Прокладываемая дорога или кусок под сносом — полупрозрачная лента
  setRoadPreview(xy, color) {
    if (!this.roadPreview) {
      this.roadPreview = new THREE.Mesh(new THREE.BufferGeometry(), new THREE.MeshBasicMaterial({ color: '#f3e7c4', transparent: true, opacity: 0.55, depthWrite: false, side: THREE.DoubleSide }));
      this.roadPreview.renderOrder = 2;
      this.scene.add(this.roadPreview);
    }
    const m = this.roadPreview;
    if (!xy || xy.length < 4) { m.visible = false; this.previewKey = null; return; }
    const key = xy.length + ':' + xy[0] + ':' + xy[xy.length - 1] + ':' + xy[(xy.length >> 2) * 2] + ':' + color;
    m.visible = true;
    m.material.color.set(color || '#f3e7c4');
    if (key === this.previewKey) return;
    this.previewKey = key;
    const n = xy.length / 2, pos = [];
    const nrm = i => {
      const a = Math.max(0, i - 1), b = Math.min(n - 1, i + 1);
      const tx = xy[b * 2] - xy[a * 2], ty = xy[b * 2 + 1] - xy[a * 2 + 1], l = Math.hypot(tx, ty) || 1;
      return [-ty / l * ROAD_HALF, tx / l * ROAD_HALF];
    };
    for (let i = 0; i < n - 1; i++) {
      const [ax, ay] = nrm(i), [bx, by] = nrm(i + 1);
      const p = (k, s, y) => [xy[k * 2] + s[0], y, xy[k * 2 + 1] + s[1]];
      const A = p(i, [-ax, -ay], 0.09), B = p(i + 1, [-bx, -by], 0.09), C = p(i + 1, [bx, by], 0.09), D = p(i, [ax, ay], 0.09);
      pos.push(...A, ...B, ...C, ...A, ...C, ...D);
    }
    m.geometry.dispose();
    m.geometry = new THREE.BufferGeometry();
    m.geometry.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
  },

  /* ---------- Природа: тысячи деревьев, камней, цветов и трав одним вызовом ---------- */

  initNature() {
    this.natMeshes = new Map();
    for (const [kind, def] of Object.entries(NATURE_KINDS)) {
      for (let v = 0; v < def.variants; v++) {
        const k2 = kind === 'grass' ? 'grass' : +kind;
        const geo = (NEW_LOOK && Look2.natureGeometry(k2, v)) || natureGeometry(k2, v);
        const cap = kind === 'grass' ? 14000 : 7000;
        const mesh = new THREE.InstancedMesh(geo, def.mat === 'rock' ? this.matRock : this.matTree, cap);
        mesh.count = 0;
        mesh.frustumCulled = false;
        mesh.castShadow = kind !== 'grass';
        mesh.receiveShadow = true;
        mesh.instanceColor = new THREE.InstancedBufferAttribute(new Float32Array(cap * 3), 3);
        this.scene.add(mesh);
        this.natMeshes.set(kind + ':' + v, { mesh, cap });
      }
    }
  },

  natureList(px, py) {
    const t = plotTerrain(px, py);
    const locked = !isOwnedPlot(px, py);
    const out = [];
    for (let j = 0; j < PLOT; j++) {
      for (let i = 0; i < PLOT; i++) {
        const k = j * PLOT + i, x = px * PLOT + i, z = py * PLOT + j, v = t.vari[k];
        const n = t.nature[k];
        if (n && !state.cleared.has(tkey(x, z)) && !Roads.covers(x, z)) {
          const def = NATURE_KINDS[n];
          const ox = ((v & 15) / 15 - 0.5) * 0.35, oz = (((v >> 4) & 15) / 15 - 0.5) * 0.35;
          const center = n === N_STONE || n === N_MARBLE || n === N_IRON;
          out.push([n + ':' + (v % def.variants), x + 0.5 + (center ? 0 : ox), z + 0.5 + (center ? 0 : oz), v * 0.0246, 0.82 + (v % 13) / 30, locked]);
        }
        if (!n && t.ground[k] < G_SAND && !World.occ.has(tkey(x, z)) && !Roads.covers(x, z)) {
          // пучки травы, гуще у кромки леса и воды
          const dens = v / 255;
          if (dens < 0.42) out.push(['grass:' + (v % 2), x + 0.15 + (v % 7) / 10, z + 0.15 + ((v >> 3) % 7) / 10, v * 0.05, 0.8 + (v % 5) * 0.1, locked, 1]);
          if (dens < 0.18) out.push(['grass:' + ((v + 1) % 2), x + 0.85 - (v % 5) / 10, z + 0.8 - ((v >> 2) % 5) / 10, v * 0.09, 0.7 + (v % 3) * 0.1, locked, 1]);
        }
      }
    }
    return out;
  },

  rebuildNature() {
    if (!this.natDirty) return;
    this.natDirty = false;
    const counts = new Map();
    const m = this._m, c = this._c;
    const q = new THREE.Quaternion(), e = new THREE.Euler(), pos = new THREE.Vector3(), sc = new THREE.Vector3();
    const grassShare = QUALITY[this.quality].grass;
    for (const p of this.plots.values()) {
      for (const [key, x, z, rot, s, locked, isGrass] of p.nat) {
        if (isGrass && hash2(Math.floor(x * 7), Math.floor(z * 7), 3) > grassShare) continue;
        const rec = this.natMeshes.get(key);
        if (!rec) continue;
        const n = counts.get(key) || 0;
        if (n >= rec.cap) continue;
        e.set(0, rot, 0);
        q.setFromEuler(e);
        pos.set(x, 0, z);
        sc.setScalar(s);
        m.compose(pos, q, sc);
        rec.mesh.setMatrixAt(n, m);
        if (locked) c.setRGB(0.8, 0.8, 0.76); else c.setRGB(1, 1, 1);
        rec.mesh.setColorAt(n, c);
        counts.set(key, n + 1);
      }
    }
    for (const [key, rec] of this.natMeshes) {
      rec.mesh.count = counts.get(key) || 0;
      rec.mesh.instanceMatrix.needsUpdate = true;
      rec.mesh.instanceColor.needsUpdate = true;
    }
  },

  /* ---------- Здания: все копии одной модели рисуются одним InstancedMesh ---------- */

  buildingsChanged(b, removed) {
    this.dirty.add(b.id);
    void removed;
  },

  rebuildAll() {
    for (const g of this.bGroups.values()) this.disposeGroup(g);
    this.bGroups.clear();
    this.bIndex.clear();
    this.animIds.clear();
    for (const p of this.plots.values()) this.disposePlot(p);
    this.plots.clear();
    this.roadVersion = -1;
    for (const b of state.buildings.values()) this.dirty.add(b.id);
    this.gridDirty = true;
    this.natDirty = true;
  },

  makeGroupMeshes(g, cap) {
    this.disposeGroup(g);
    const mk = (geo, mat, shadow) => {
      if (!geo) return null;
      const m = new THREE.InstancedMesh(geo, mat, cap);
      m.count = 0;
      m.frustumCulled = false;
      m.castShadow = shadow;
      m.receiveShadow = shadow;
      this.scene.add(m);
      return m;
    };
    g.cap = cap;
    g.solid = mk(g.model.solid, this.mat, true);
    g.glow = mk(g.model.glow, this.matGlow, false);
    g.win = mk(g.model.win, this.matWin, false);
    if (g.solid) g.solid.userData.group = g;
  },

  disposeGroup(g) {
    for (const k of ['solid', 'glow', 'win']) if (g[k]) { this.scene.remove(g[k]); g[k].dispose(); g[k] = null; }
  },

  groupFor(key, b) {
    let g = this.bGroups.get(key);
    if (!g) {
      g = { key, model: buildModel(b), ids: [], slot: new Map(), dirty: true };
      this.makeGroupMeshes(g, 8);
      this.bGroups.set(key, g);
    }
    return g;
  },

  syncBuildings() {
    if (!this.dirty.size) return;
    const now = performance.now();
    for (const id of this.dirty) {
      const b = state.buildings.get(id);
      const oldKey = this.bIndex.get(id);
      const key = b && b.type !== 'road' && !b.lifted ? modelKey(b) : null;
      if (oldKey && oldKey !== key) {
        const og = this.bGroups.get(oldKey);
        if (og) { og.ids = og.ids.filter(x => x !== id); og.dirty = true; }
      }
      if (key) {
        const g = this.groupFor(key, b);
        if (!g.ids.includes(id)) g.ids.push(id);
        g.dirty = true;
        this.bIndex.set(id, key);
        if (now - Math.max(b.born || 0, b.animAt || 0) < 700) this.animIds.add(id);
      } else this.bIndex.delete(id);
    }
    this.dirty.clear();
    for (const g of this.bGroups.values()) if (g.dirty) this.fillGroup(g);
    this.rebuildEmitters();
  },

  buildingMatrix(b, sy, sxz) {
    this._q.setFromAxisAngle(this._up, bAng(b));
    this._p.set(b.x + b.w / 2, 0, b.y + b.h / 2);
    this._s.set(sxz || 1, sy || 1, sxz || 1);
    return this._m.compose(this._p, this._q, this._s);
  },

  fillGroup(g) {
    g.dirty = false;
    if (g.ids.length > g.cap) this.makeGroupMeshes(g, Math.max(g.ids.length + 8, g.cap * 2));
    g.slot.clear();
    g.ids.forEach((id, i) => {
      const b = state.buildings.get(id);
      if (!b) return;
      g.slot.set(id, i);
      const m = this.buildingMatrix(b);
      for (const k of ['solid', 'glow', 'win']) if (g[k]) g[k].setMatrixAt(i, m);
    });
    for (const k of ['solid', 'glow', 'win']) {
      if (!g[k]) continue;
      g[k].count = g.ids.length;
      g[k].instanceMatrix.needsUpdate = true;
      g[k].boundingSphere = null;
    }
  },

  rebuildEmitters() {
    this.emitters = [];
    for (const g of this.bGroups.values()) {
      if (!g.model.smoke.length && !g.model.fountain.length) continue;
      for (const id of g.ids) {
        const b = state.buildings.get(id);
        if (!b) continue;
        const a = bAng(b), ca = Math.cos(a), sa = Math.sin(a);
        const cx = b.x + b.w / 2, cz = b.y + b.h / 2;
        const toWorld = ([x, y, z]) => [cx + x * ca + z * sa, y, cz - x * sa + z * ca];
        for (const p of g.model.smoke) this.emitters.push({ b, kind: 'smoke', p: toWorld(p), t: Math.random() });
        for (const p of g.model.fountain) this.emitters.push({ b, kind: 'fountain', p: toWorld(p), r: p[3], t: Math.random() });
      }
    }
  },

  // «Вырастание» здания при постройке и смене уровня
  animateBuildings(now) {
    for (const id of this.animIds) {
      const b = state.buildings.get(id);
      const g = b && this.bGroups.get(this.bIndex.get(id));
      if (!g || !g.slot.has(id)) { this.animIds.delete(id); continue; }
      const age = (now - Math.max(b.born || 0, b.animAt || 0)) / 1000;
      let m;
      if (age >= 0.6 || age < 0) { m = this.buildingMatrix(b); this.animIds.delete(id); }
      else { const k = easeOutBack(clamp(age / 0.6, 0, 1)); m = this.buildingMatrix(b, Math.max(0.02, k), 1 + (1 - k) * 0.12); }
      const i = g.slot.get(id);
      for (const kk of ['solid', 'glow', 'win']) if (g[kk]) { g[kk].setMatrixAt(i, m); g[kk].instanceMatrix.needsUpdate = true; }
    }
  },

  /* ---------- Жители-фигурки (как игрушечные человечки из кубиков) ---------- */

  // Фигурки из кубиков стоят на камнях мостовой (ROAD_TOP); каждая часть — свой InstancedMesh с цветом на экземпляр
  figGeo(fn) { const mb = new MB(5); fn(mb); const g = mb.build(0, 0).solid; g.deleteAttribute('color'); return g; },

  figMeshes(shapes, counts, max) {
    const mat = this.figMat || (this.figMat = new THREE.MeshLambertMaterial());
    const out = {};
    for (const [k, g] of Object.entries(shapes)) {
      const n = max * (counts[k] || 1);
      const m = new THREE.InstancedMesh(g, mat, n);
      m.castShadow = true;
      m.count = 0;
      m.frustumCulled = false;
      m.instanceMatrix.setUsage(THREE.DynamicDrawUsage);
      m.instanceColor = new THREE.InstancedBufferAttribute(new Float32Array(n * 3), 3);
      this.scene.add(m);
      out[k] = m;
    }
    return out;
  },

  // Часть фигурки: поворот по X, масштаб и сдвиг относительно базовой матрицы this._mb
  figPart(F, idx, part, color, sx, sy, sz, rx, px, py, pz) {
    const loc = this._ml, out = this._mo;
    loc.makeRotationX(rx || 0);
    if (sx !== 1 || sy !== 1 || sz !== 1) loc.scale(this._s.set(sx, sy, sz));
    loc.setPosition(px, py, pz);
    out.multiplyMatrices(this._mb, loc);
    const i = idx[part]++;
    F[part].setMatrixAt(i, out);
    F[part].setColorAt(i, this._c.set(color));
  },

  figBase(x, y, z, yaw, s) {
    this._q.setFromAxisAngle(this._up, yaw || 0);
    this._p.set(x, y, z);
    this._s.set(s, s, s);
    this._mb.compose(this._p, this._q, this._s);
  },

  figFlush(F, idx) {
    for (const [k, m] of Object.entries(F)) {
      m.count = idx[k];
      m.instanceMatrix.needsUpdate = true;
      if (idx[k]) m.instanceColor.needsUpdate = true;
    }
  },

  initWalkers() {
    this._mb = new THREE.Matrix4();
    this._ml = new THREE.Matrix4();
    this._mo = new THREE.Matrix4();
    if (NEW_LOOK) { Look2.initCrowd(this.scene, 400); this.initCats(); return; }
    const geo = fn => this.figGeo(fn);
    this.wMax = 400;
    this.fig = this.figMeshes({
      leg: geo(mb => mb.box(-0.019, -0.1, -0.022, 0.019, 0, 0.022, '#fff', { ao: 1 })),
      arm: geo(mb => mb.box(-0.016, -0.1, -0.018, 0.016, 0, 0.018, '#fff', { ao: 1 })),
      torso: geo(mb => {
        mb.box(-0.058, 0, -0.04, 0.058, 0.135, 0.04, '#fff', { ao: 1 });
        mb.box(-0.064, 0, -0.045, 0.064, 0.045, 0.045, '#fff', { ao: 1 });
      }),
      head: geo(mb => mb.box(-0.042, 0, -0.04, 0.042, 0.08, 0.042, '#fff', { ao: 1 })),
      hair: geo(mb => {
        mb.box(-0.046, 0.06, -0.046, 0.046, 0.092, 0.046, '#fff', { ao: 1 });
        mb.box(-0.046, 0.02, -0.048, 0.046, 0.08, -0.026, '#fff', { ao: 1 });
      }),
      acc: geo(mb => mb.box(-0.05, 0, -0.05, 0.05, 0.05, 0.05, '#fff', { ao: 1 })),
      eyes: geo(mb => {
        mb.box(-0.027, 0.032, 0.04, -0.011, 0.05, 0.046, '#fff', { ao: 1 });
        mb.box(0.011, 0.032, 0.04, 0.027, 0.05, 0.046, '#fff', { ao: 1 });
      }),
    }, { leg: 2, arm: 2 }, this.wMax);
    this._mb = new THREE.Matrix4();
    this._ml = new THREE.Matrix4();
    this._mo = new THREE.Matrix4();
    this.initCats();
  },

  initCats() {
    const geo = fn => this.figGeo(fn);
    this.cMax = 90;
    this.catFig = this.figMeshes({
      cbody: geo(mb => mb.box(-0.021, -0.019, -0.045, 0.021, 0.019, 0.045, '#fff', { ao: 1 })),
      chest: geo(mb => mb.box(-0.016, -0.016, -0.004, 0.016, 0.016, 0.004, '#fff', { ao: 1 })),
      chead: geo(mb => {
        mb.box(-0.024, 0, -0.02, 0.024, 0.036, 0.022, '#fff', { ao: 1 });
        mb.box(-0.022, 0.036, -0.006, -0.008, 0.054, 0.007, '#fff', { ao: 1 });
        mb.box(0.008, 0.036, -0.006, 0.022, 0.054, 0.007, '#fff', { ao: 1 });
      }),
      ceyes: geo(mb => {
        mb.box(-0.016, 0.016, 0.021, -0.007, 0.025, 0.025, '#fff', { ao: 1 });
        mb.box(0.007, 0.016, 0.021, 0.016, 0.025, 0.025, '#fff', { ao: 1 });
      }),
      cleg: geo(mb => mb.box(-0.007, -0.042, -0.007, 0.007, 0, 0.007, '#fff', { ao: 1 })),
      ctail: geo(mb => mb.box(-0.006, 0, -0.006, 0.006, 0.07, 0.006, '#fff', { ao: 1 })),
    }, { cleg: 4 }, this.cMax);
  },

  drawCats() {
    const list = Cats.list, F = this.catFig;
    const n = Math.min(list.length, this.cMax);
    const idx = { cbody: 0, chest: 0, chead: 0, ceyes: 0, cleg: 0, ctail: 0 };
    const put = (...a) => this.figPart(F, idx, ...a);
    for (let i = 0; i < n; i++) {
      const c = list[i], a = c.anim;
      this.figBase(c.wx, ROAD_TOP, c.wy, c.yaw, c.alpha * 1.15);
      if (c.moving) {
        // идёт: лапы попарно накрест, хвост трубой
        const sw = Math.sin(c.walkPh) * 0.6, bob = Math.abs(Math.cos(c.walkPh)) * 0.004;
        put('cbody', c.cBody, 1, 1, 1, 0, 0, 0.06 + bob, 0);
        put('chest', c.cChest, 1, 1, 1, 0, 0, 0.056 + bob, 0.044);
        put('chead', c.cBody, 1, 1, 1, 0, 0, 0.062 + bob, 0.055);
        put('ceyes', c.cEye, 1, 1, 1, 0, 0, 0.062 + bob, 0.055);
        put('cleg', c.cBody, 1, 1, 1, sw, -0.013, 0.043, 0.03);
        put('cleg', c.cBody, 1, 1, 1, -sw, 0.013, 0.043, 0.03);
        put('cleg', c.cBody, 1, 1, 1, -sw, -0.013, 0.043, -0.03);
        put('cleg', c.cBody, 1, 1, 1, sw, 0.013, 0.043, -0.03);
        put('ctail', c.cBody, 1, 1, 1, -0.3 + Math.sin(a * 3) * 0.12, 0, 0.07, -0.042);
      } else {
        // сидит у края дороги: спина наклонена, хвост лежит и подёргивается; иногда умывается
        const groom = c.groom ? Math.max(0, Math.sin(a * 5)) : 0;
        put('cbody', c.cBody, 1, 1, 1, -0.75, 0, 0.045, -0.01);
        put('chest', c.cChest, 1, 1, 1, -0.75, 0, 0.0756, 0.0258);
        put('chead', c.cBody, 1, 1, 1, groom * 0.45, 0, 0.08, 0.03 + groom * 0.006);
        put('ceyes', c.cEye, 1, 1, 1, groom * 0.45, 0, 0.08, 0.03 + groom * 0.006);
        put('cleg', c.cChest, 1, 1.4, 1, 0, -0.012, 0.06, 0.03);
        put('cleg', c.cChest, 1, 1.4, 1, c.groom ? -groom * 1.2 : 0, 0.012, 0.06, 0.03);
        put('cleg', c.cBody, 1.3, 0.55, 2.2, 0, -0.02, 0.023, -0.02);
        put('cleg', c.cBody, 1.3, 0.55, 2.2, 0, 0.02, 0.023, -0.02);
        put('ctail', c.cBody, 1, 1, 1, -1.45 + Math.max(0, Math.sin(a * 2.2)) * 0.45, 0, 0.008, -0.045);
      }
    }
    this.figFlush(F, idx);
  },

  drawWalkers(T, realDt) {
    if (NEW_LOOK) { Look2.drawWalkers(Walkers.list, realDt || 0); this.drawCats(); return; }
    const list = Walkers.list;
    const n = Math.min(list.length, this.wMax);
    const F = this.fig;
    const idx = { leg: 0, arm: 0, torso: 0, head: 0, hair: 0, acc: 0, eyes: 0 };
    const put = (...a) => this.figPart(F, idx, ...a);
    for (let i = 0; i < n; i++) {
      const w = list[i];
      const ph = w.walkPh || 0;
      const sw = w.moving ? Math.sin(ph) * 0.65 : 0;
      const bob = w.moving ? Math.abs(Math.cos(ph)) * 0.012 : 0;
      this.figBase(w.wx, ROAD_TOP + bob, w.wy, w.yaw, w.alpha * (w.role === 'child' ? 0.72 : 1) * 1.05);
      const dress = w.role === 'woman';
      put('leg', w.cLegs, 1, 1, 1, sw, -0.021, 0.1, 0);
      put('leg', w.cLegs, 1, 1, 1, -sw, 0.021, 0.1, 0);
      put('torso', w.cTorso, dress ? 1.08 : 1, dress ? 1.72 : 1, dress ? 1.08 : 1, 0, 0, dress ? 0 : 0.098, 0);
      put('arm', w.cArms, 1, 1, 1, -sw * 0.85, -0.075, 0.226, 0);
      put('arm', w.cArms, 1, 1, 1, sw * 0.85, 0.075, 0.226, 0);
      put('head', w.cSkin, 1, 1, 1, 0, 0, 0.232, 0);
      put('eyes', '#2b1d14', 1, 1, 1, 0, 0, 0.232, 0);
      put('hair', w.cHair, 1, w.longHair ? 1.25 : 1, 1, 0, 0, w.longHair ? 0.214 : 0.232, 0);
      if (w.role === 'merchant') put('acc', w.cAcc, 1.1, 0.7, 1.1, 0, 0, 0.33, 0);
      else if (w.role === 'soldier') put('acc', w.cAcc, 0.95, 0.45, 0.95, 0, 0, 0.3, 0);
      else if (w.role === 'patrician') put('acc', w.cAcc, 1.2, 0.2, 0.9, 0, 0, 0.19, 0);
    }
    this.figFlush(F, idx);
    this.drawCats();
  },

  /* ---------- Частицы: дым, пыль, брызги, искры ---------- */

  initParticles() {
    const MAX = 1200;
    const g = new THREE.IcosahedronGeometry(0.5, 1);
    this.pMesh = new THREE.InstancedMesh(g, new THREE.MeshLambertMaterial({ transparent: true, opacity: 0.72, depthWrite: false }), MAX);
    this.pMesh.count = 0;
    this.pMesh.frustumCulled = false;
    this.pMesh.instanceMatrix.setUsage(THREE.DynamicDrawUsage);
    this.scene.add(this.pMesh);
    this.pMax = MAX;
    this.particles = [];
  },

  emit(p) { if (this.particles.length < this.pMax) this.particles.push(p); },

  puff(x, y, z, color, n, spread, up, size, life) {
    for (let i = 0; i < n; i++) {
      this.emit({ x: x + (Math.random() - 0.5) * spread, y, z: z + (Math.random() - 0.5) * spread,
        vx: (Math.random() - 0.5) * 0.6, vy: up * (0.6 + Math.random() * 0.6), vz: (Math.random() - 0.5) * 0.6,
        s: size * (0.6 + Math.random() * 0.6), t: 0, life: life * (0.7 + Math.random() * 0.6), color, grow: 1.4, g: 0 });
    }
  },

  dust(b) {
    this.puff(b.x + b.w / 2, 0.05, b.y + b.h / 2, '#f4ecdb', 6 + b.w * 3, b.w * 0.9, 0.7, 0.09, 0.6);
  },

  sparkle(b, h) {
    for (let i = 0; i < 16; i++) {
      const a = Math.random() * Math.PI * 2;
      this.emit({ x: b.x + b.w / 2, y: h * Math.random() + 0.2, z: b.y + b.h / 2, vx: Math.cos(a) * 1.4, vy: 1.6 + Math.random(), vz: Math.sin(a) * 1.4,
        s: 0.06, t: 0, life: 0.9 + Math.random() * 0.4, color: Math.random() < 0.5 ? '#fff3b0' : '#ffd24a', grow: 0, g: -3.5 });
    }
  },

  updateParticles(dt, realDt) {
    for (const e of this.emitters) {
      if (e.kind === 'smoke') {
        if (!(e.b.working || (e.b.active && !BUILDINGS[e.b.type].produces))) continue;
        e.t -= dt;
        if (e.t <= 0) {
          e.t = 0.5 + Math.random() * 0.4;
          this.emit({ x: e.p[0], y: e.p[1], z: e.p[2], vx: 0.12, vy: 0.35, vz: -0.05, s: 0.09, t: 0, life: 2.8, color: '#efeae2', grow: 2.4, g: 0 });
        }
      } else {
        e.t -= realDt;
        if (e.t <= 0) {
          e.t = 0.05;
          const a = Math.random() * Math.PI * 2;
          this.emit({ x: e.p[0], y: e.p[1], z: e.p[2], vx: Math.cos(a) * e.r * 0.9, vy: 1.15, vz: Math.sin(a) * e.r * 0.9, s: 0.03, t: 0, life: 0.65, color: '#e8f6ff', grow: 0, g: -4 });
        }
      }
    }
    const m = this._m, c = this._c;
    let n = 0;
    const alive = [];
    for (const p of this.particles) {
      p.t += realDt;
      if (p.t >= p.life) continue;
      p.vy += p.g * realDt;
      p.x += p.vx * realDt; p.y += p.vy * realDt; p.z += p.vz * realDt;
      const k = p.t / p.life;
      const s = p.s * (1 + p.grow * k) * (k > 0.7 ? (1 - k) / 0.3 : 1);
      m.makeScale(s, s, s);
      m.setPosition(p.x, p.y, p.z);
      this.pMesh.setMatrixAt(n, m);
      this.pMesh.setColorAt(n, c.set(p.color));
      n++;
      alive.push(p);
    }
    this.particles = alive;
    this.pMesh.count = n;
    this.pMesh.instanceMatrix.needsUpdate = true;
    if (n && this.pMesh.instanceColor) this.pMesh.instanceColor.needsUpdate = true;
  },

  /* ---------- Подсказки стройки ---------- */

  initOverlays() {
    this.ghost = new THREE.Group();
    this.ghost.visible = false;
    this.scene.add(this.ghost);
    this.ghostPlate = new THREE.Mesh(new THREE.PlaneGeometry(1, 1).rotateX(-Math.PI / 2), new THREE.MeshBasicMaterial({ color: '#78d26e', transparent: true, opacity: 0.4, depthWrite: false }));
    this.ghostPlate.position.y = 0.05;
    this.ghost.add(this.ghostPlate);
    this.ghostPos = null;

    const MAXQ = 600;
    this.quads = new THREE.InstancedMesh(new THREE.PlaneGeometry(1, 1).rotateX(-Math.PI / 2), new THREE.MeshBasicMaterial({ transparent: true, opacity: 0.45, depthWrite: false }), MAXQ);
    this.quads.count = 0;
    this.quads.frustumCulled = false;
    this.scene.add(this.quads);
    this.quadMax = MAXQ;

    this.ringFill = new THREE.Mesh(new THREE.CircleGeometry(1, 64).rotateX(-Math.PI / 2), new THREE.MeshBasicMaterial({ color: '#fff3c4', transparent: true, opacity: 0.16, depthWrite: false }));
    this.ringLine = new THREE.Mesh(new THREE.RingGeometry(0.985, 1, 96).rotateX(-Math.PI / 2), new THREE.MeshBasicMaterial({ color: '#fffaf0', transparent: true, opacity: 0.85, depthWrite: false }));
    this.ringFill.position.y = 0.04; this.ringLine.position.y = 0.05;
    this.ringFill.visible = this.ringLine.visible = false;
    this.scene.add(this.ringFill, this.ringLine);

    this.grid = null;
    this.gridDirty = true;
  },

  setQuads(list) {
    const m = this._m, c = this._c;
    const n = Math.min(list.length, this.quadMax);
    for (let i = 0; i < n; i++) {
      // [x, z, w, h, цвет] — квадрат по клеткам от угла; [cx, cz, w, h, цвет, угол] — повёрнутый, от центра
      const [x, z, w, h, color, ang] = list[i];
      if (ang === undefined) { m.makeScale(w, 1, h); m.setPosition(x + w / 2, 0.06, z + h / 2); }
      else { this._q.setFromAxisAngle(this._up, ang); this._p.set(x, 0.06, z); this._s.set(w, 1, h); m.compose(this._p, this._q, this._s); }
      this.quads.setMatrixAt(i, m);
      this.quads.setColorAt(i, c.set(color));
    }
    this.quads.count = n;
    this.quads.instanceMatrix.needsUpdate = true;
    if (n && this.quads.instanceColor) this.quads.instanceColor.needsUpdate = true;
  },

  setRadius(cx, cz, r) {
    const on = r > 0;
    this.ringFill.visible = this.ringLine.visible = on;
    if (!on) return;
    for (const m of [this.ringFill, this.ringLine]) { m.position.x = cx; m.position.z = cz; m.scale.set(r, 1, r); }
  },

  // Призрак постройки: центр (cx, cy) и поворот ang; src — переносимое здание (призрак — его же вид)
  setGhost(type, cx, cy, ok, ang, src) {
    if (!type) { this.ghost.visible = false; this.ghostKey = null; this.ghostPos = null; return; }
    const d = BUILDINGS[type];
    const fake = src ? Object.assign({}, src, { rot: 0, ang: 0 }) : { id: 1, type, x: cx - d.w / 2, y: cy - d.h / 2, w: d.w, h: d.h, tier: d.kind === 'house' ? 1 : 0, rot: 0 };
    const gkey = src ? 'move:' + modelKey(src) : type;
    if (this.ghostKey !== gkey) {
      if (this.ghostMesh) this.ghost.remove(this.ghostMesh);
      this.ghostMesh = null;
      if (type !== 'road' && type !== 'bulldoze') {
        const m = buildModel(fake);
        this.ghostMesh = new THREE.Mesh(m.solid, this.matGhost);
        this.ghost.add(this.ghostMesh);
      }
      this.ghostKey = gkey;
    }
    this.ghost.visible = true;
    if (!this.ghostPos) this.ghostPos = [cx, cy];
    this.ghostTarget = [cx, cy];
    this.ghostPlate.scale.set(d.w, 1, d.h);
    this.ghostPlate.material.color.set(ok ? '#78d26e' : '#e0583e');
    // поворот — плавно, кратчайшим путём
    const want = ang || 0, cur = this.ghost.rotation.y;
    this.ghostAng = cur + Math.atan2(Math.sin(want - cur), Math.cos(want - cur));
  },

  updateGhost(dt) {
    if (!this.ghost.visible || !this.ghostTarget) return;
    const k = 1 - Math.pow(0.0000005, dt);
    this.ghostPos[0] += (this.ghostTarget[0] - this.ghostPos[0]) * k;
    this.ghostPos[1] += (this.ghostTarget[1] - this.ghostPos[1]) * k;
    this.ghost.position.set(this.ghostPos[0], 0.01 + Math.sin(this.T * 4) * 0.02, this.ghostPos[1]);
    if (this.ghostAng !== undefined) this.ghost.rotation.y += (this.ghostAng - this.ghost.rotation.y) * k;
  },

  updateGrid(show) {
    if (!show) { if (this.grid) this.grid.visible = false; return; }
    if (this.gridDirty || !this.grid) {
      if (this.grid) { this.scene.remove(this.grid); this.grid.geometry.dispose(); }
      const pos = [];
      for (const key of state.plots) {
        const [px, py] = key.split(',').map(Number);
        const x0 = px * PLOT, z0 = py * PLOT;
        for (let i = 1; i < PLOT; i++) {
          pos.push(x0 + i, 0.05, z0, x0 + i, 0.05, z0 + PLOT);
          pos.push(x0, 0.05, z0 + i, x0 + PLOT, 0.05, z0 + i);
        }
      }
      const g = new THREE.BufferGeometry();
      g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
      this.grid = new THREE.LineSegments(g, this.matGrid);
      this.scene.add(this.grid);
      this.gridDirty = false;
    }
    this.grid.visible = true;
  },

  /* ---------- Иконки построек для интерфейса ---------- */

  renderIcons(types, size) {
    const out = {};
    const canvas = document.createElement('canvas');
    let r;
    try {
      r = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: true, preserveDrawingBuffer: true });
    } catch (e) { return out; }
    r.setSize(size, size, false);
    r.setPixelRatio(1);
    r.outputColorSpace = THREE.SRGBColorSpace;
    r.toneMapping = THREE.ACESFilmicToneMapping;
    r.setClearColor(0x000000, 0);
    const scene = new THREE.Scene();
    scene.add(new THREE.HemisphereLight('#fff6e6', '#8d9a70', 2.0));
    const sun = new THREE.DirectionalLight('#fff0d6', 2.6);
    sun.position.set(-3, 6, 4);
    scene.add(sun);
    const matWin = new THREE.MeshBasicMaterial({ vertexColors: true, side: THREE.DoubleSide, color: new THREE.Color(0.06, 0.06, 0.06) });
    const matGlow = new THREE.MeshBasicMaterial({ vertexColors: true, side: THREE.DoubleSide });
    const mat = new THREE.MeshLambertMaterial({ vertexColors: true, side: THREE.DoubleSide });
    const cam = new THREE.PerspectiveCamera(30, 1, 0.1, 100);
    for (const key of types) {
      const [type, tierStr] = key.split(':');
      const d = BUILDINGS[type];
      const tier = tierStr !== undefined ? +tierStr : d.kind === 'house' ? 3 : 0;
      const fake = { id: 4, type, x: 0, y: 0, w: d.w, h: d.h, tier, rot: 0 };
      const mesh = new THREE.Group();
      if (type === 'road') {
        const mb = new MB(2);
        mb.box(0, 0, 0, 1, 0.03, 1, '#a99a7a');
        for (let a = 0; a < 2; a++) for (let b = 0; b < 2; b++) mb.box(a * 0.5 + 0.03, 0.03, b * 0.5 + 0.03, a * 0.5 + 0.47, 0.05, b * 0.5 + 0.47, ['#d9cdb0', '#d2c5a6', '#ddd2b6', '#cdbf9e'][a * 2 + b]);
        mb.box(0, 0, 0, 1, 0.07, 0.06, '#ebe3cf'); mb.box(0, 0, 0.94, 1, 0.07, 1, '#ebe3cf');
        mesh.add(new THREE.Mesh(mb.build(0.5, 0.5).solid, mat));
      } else {
        const m = buildModel(fake);
        mesh.add(new THREE.Mesh(m.solid, mat));
        if (m.glow) mesh.add(new THREE.Mesh(m.glow, matGlow));
        if (m.win) mesh.add(new THREE.Mesh(m.win, matWin));
      }
      scene.add(mesh);
      const box = new THREE.Box3().setFromObject(mesh);
      const sphere = box.getBoundingSphere(new THREE.Sphere());
      const dist = sphere.radius / Math.sin(THREE.MathUtils.degToRad(15)) * 1.0;
      const yaw = Math.PI / 4, pitch = 0.6;
      cam.position.set(sphere.center.x + Math.sin(yaw) * Math.cos(pitch) * dist, sphere.center.y + Math.sin(pitch) * dist, sphere.center.z + Math.cos(yaw) * Math.cos(pitch) * dist);
      cam.lookAt(sphere.center);
      r.render(scene, cam);
      out[key] = canvas.toDataURL('image/png');
      scene.remove(mesh);
    }
    r.dispose();
    r.forceContextLoss();
    return out;
  },

  /* ---------- Кадр ---------- */

  frame(dt, realDt) {
    this.T += realDt;
    Atmos.update(dt, realDt);
    this.updateCamera(realDt);
    this.ensurePlots(2);
    this.rebuildNature();
    this.syncRoads();
    this.syncBuildings();
    this.animateBuildings(performance.now());
    this.drawWalkers(this.T, realDt);
    this.updateParticles(dt, realDt);
    this.updateGhost(realDt);
    Atmos.updateBirds(this.T, this.cam);
    Atmos.updateLife(this.T, this.cam);
    Atmos.follow(this.camera, this.cam);
    this.waterNormals.offset.set(this.T * 0.012, this.T * 0.008);
    const t = clamp((this.cam.dist - DIST_MIN) / (DIST_MAX - DIST_MIN), 0, 1);
    Post.render(this.scene, this.camera, { focus: this.cam.dist, dof: lerp(0.8, 0.3, t), bloom: 0.5 + Atmos.night * 0.5 });
  },
};
