// Римский квартал: здания, статуи и деревья Artisau (CC0, куплен), природа и предметы Quaternius (CC0),
// животные Quaternius (CC0), жители и легионеры из people.js.
import * as THREE from 'three';
import { FBXLoader } from '../vendor/three-module/examples/jsm/loaders/FBXLoader.js';
import { GLTFLoader } from '../vendor/three-module/examples/jsm/loaders/GLTFLoader.js';
import { OrbitControls } from '../vendor/three-module/examples/jsm/controls/OrbitControls.js';
import * as SkeletonUtils from '../vendor/three-module/examples/jsm/utils/SkeletonUtils.js';
import { RoomEnvironment } from '../vendor/three-module/examples/jsm/environments/RoomEnvironment.js';
import { setScene, makePerson, makeFighter, arm, lockGuard, play } from './people.js';

const status = document.getElementById('status');
const canvas = document.getElementById('c');
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true });
renderer.setPixelRatio(Math.min(2, devicePixelRatio));
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.0;
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;

const scene = new THREE.Scene();
setScene(scene);
const pmrem = new THREE.PMREMGenerator(renderer);
scene.environment = pmrem.fromScene(new RoomEnvironment(renderer), 0.04).texture;

const skyCanvas = document.createElement('canvas'); skyCanvas.width = 2; skyCanvas.height = 256;
const skyTex = new THREE.CanvasTexture(skyCanvas); skyTex.colorSpace = THREE.SRGBColorSpace;
scene.background = skyTex;
scene.fog = new THREE.Fog('#dfe8e6', 170, 460);

const hemi = new THREE.HemisphereLight('#e3f1ff', '#8a8662', 0.9);
scene.add(hemi);
const sun = new THREE.DirectionalLight('#fff0d4', 2.7);
sun.castShadow = true;
sun.shadow.mapSize.set(4096, 4096);
Object.assign(sun.shadow.camera, { left: -55, right: 55, top: 55, bottom: -55, near: 1, far: 220 });
sun.shadow.bias = -0.0003;
sun.shadow.normalBias = 0.04;
scene.add(sun, sun.target);

const SUNS = {
  day: { dir: [-0.45, 0.8, 0.4], color: '#fff0d4', k: 2.8, hemi: 1.15, sky: ['#6aa8de', '#c4def0', '#e8ecdf'], fog: '#d9e5e6', exp: 1.0 },
  evening: { dir: [-0.8, 0.3, 0.5], color: '#ffbf80', k: 2.8, hemi: 0.7, sky: ['#5878b0', '#eab088', '#ffd6a8'], fog: '#eac6a4', exp: 0.92 },
};
function setSun(name) {
  const s = SUNS[name];
  sun.userData.dir = new THREE.Vector3(...s.dir).normalize();
  sun.color.set(s.color); sun.intensity = s.k; hemi.intensity = s.hemi;
  const g = skyCanvas.getContext('2d'), gr = g.createLinearGradient(0, 0, 0, 256);
  gr.addColorStop(0, s.sky[0]); gr.addColorStop(0.6, s.sky[1]); gr.addColorStop(1, s.sky[2]);
  g.fillStyle = gr; g.fillRect(0, 0, 2, 256); skyTex.needsUpdate = true;
  scene.fog.color.set(s.fog); renderer.toneMappingExposure = s.exp;
}
setSun('day');

const camera = new THREE.PerspectiveCamera(38, 1, 0.5, 600);
const controls = new OrbitControls(camera, canvas);
controls.enableDamping = true;
controls.maxPolarAngle = 1.38;
controls.minDistance = 6;
controls.maxDistance = 170;
controls.screenSpacePanning = false;

const rnd = (() => { let s = 12345; return () => (s = (s * 16807) % 2147483647) / 2147483647; })();
const R = (a, b) => a + rnd() * (b - a);

/* ---------- Земля: трава с пятнами, мощёные площади и улицы ---------- */
{
  const geo = new THREE.PlaneGeometry(320, 320, 160, 160).rotateX(-Math.PI / 2);
  const pos = geo.attributes.position, col = [], c = new THREE.Color();
  const g1 = new THREE.Color('#6a8f40'), g2 = new THREE.Color('#4f7432'), g3 = new THREE.Color('#8f9752');
  for (let i = 0; i < pos.count; i++) {
    const x = pos.getX(i), z = pos.getZ(i);
    const n = Math.sin(x * 0.11 + z * 0.07) * 0.5 + Math.sin(x * 0.043 - z * 0.13 + 1.3) * 0.35 + Math.sin(x * 0.31 + z * 0.27) * 0.15;
    c.copy(g1).lerp(g2, THREE.MathUtils.clamp(0.5 + n * 0.6, 0, 1));
    c.lerp(g3, THREE.MathUtils.clamp(Math.sin(x * 0.02 + 2) * Math.sin(z * 0.025) * 0.6, 0, 0.45));
    col.push(c.r, c.g, c.b);
    const d = Math.max(Math.abs(x) - 70, -z - 70, 0);
    pos.setY(i, d > 0 ? Math.pow(d / 40, 1.6) * 14 * (0.7 + 0.3 * Math.sin(x * 0.05 + z * 0.04)) : 0);
  }
  geo.setAttribute('color', new THREE.Float32BufferAttribute(col, 3));
  geo.computeVertexNormals();
  const ground = new THREE.Mesh(geo, new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.95 }));
  ground.receiveShadow = true;
  scene.add(ground);
}

// Мостовая: светлые неровные плиты с тёмными швами
function stoneTexture(base, rows, seed) {
  const cv = document.createElement('canvas'); cv.width = cv.height = 512;
  const g = cv.getContext('2d');
  let s = seed; const r = () => (s = (s * 16807) % 2147483647) / 2147483647;
  g.fillStyle = '#7d7466'; g.fillRect(0, 0, 512, 512);
  const h = 512 / rows;
  for (let y = 0; y < rows; y++) {
    let x = -r() * 60;
    while (x < 512) {
      const w = 40 + r() * 70;
      const b = base[Math.floor(r() * base.length)];
      g.fillStyle = b;
      const pad = 3;
      g.beginPath();
      g.roundRect(x + pad, y * h + pad, w - pad * 2, h - pad * 2, 6);
      g.fill();
      g.fillStyle = 'rgba(255,255,255,0.08)';
      g.fillRect(x + pad + 3, y * h + pad + 2, w - pad * 2 - 6, 4);
      x += w;
    }
  }
  const t = new THREE.CanvasTexture(cv);
  t.colorSpace = THREE.SRGBColorSpace; t.wrapS = t.wrapT = THREE.RepeatWrapping; t.anisotropy = 8;
  return t;
}
const paveTex = stoneTexture(['#d9cfbd', '#cfc3ad', '#e3dac8', '#c7baa2', '#d4c8b0'], 8, 7);
const roadTex = stoneTexture(['#b9ae9b', '#a99e8a', '#c2b8a5', '#9f9481'], 10, 3);
function pave(x0, z0, x1, z1, tex, scale, y) {
  const w = x1 - x0, d = z1 - z0;
  const t = tex.clone(); t.needsUpdate = true; t.repeat.set(w / scale, d / scale);
  const m = new THREE.Mesh(new THREE.PlaneGeometry(w, d).rotateX(-Math.PI / 2), new THREE.MeshStandardMaterial({ map: t, roughness: 0.9 }));
  m.position.set((x0 + x1) / 2, y || 0.03, (z0 + z1) / 2);
  m.receiveShadow = true;
  scene.add(m);
  // бордюр
  const curb = new THREE.MeshStandardMaterial({ color: '#b8ab92', roughness: 0.9 });
  for (const [cx, cz, cw, cd] of [[(x0 + x1) / 2, z0, w + 0.5, 0.5], [(x0 + x1) / 2, z1, w + 0.5, 0.5], [x0, (z0 + z1) / 2, 0.5, d], [x1, (z0 + z1) / 2, 0.5, d]]) {
    const b = new THREE.Mesh(new THREE.BoxGeometry(cw, 0.14, cd), curb);
    b.position.set(cx, 0.07, cz); b.receiveShadow = true; b.castShadow = true; scene.add(b);
  }
}
pave(-17, -15, 17, 11, paveTex, 6);         // форум
pave(-3, 11, 3, 72, roadTex, 4.5, 0.025);   // главная улица на юг
pave(-62, 36, 62, 42, roadTex, 4.5, 0.028); // поперечная улица
pave(-3, -40, 3, -15, roadTex, 4.5, 0.025); // к храму

/* ---------- Загрузчики ---------- */
const fbx = new FBXLoader(), gltf = new GLTFLoader();
const ART = '../assets/incoming/artisau/unpacked/AncientGrecce/';
const NAT = '../assets/incoming/stylized-nature-megakit/unpacked/glTF/';
const PROP = '../assets/incoming/fantasy-props-megakit/unpacked/Exports/glTF/';
const ANI = '../assets/incoming/animals-polypizza/';
const ART_K = 0.0052;  // у Artisau человек ростом 350 единиц → 1,82 м
const cache = {};
// Палитра Artisau 16×16: перекрашиваем греческие цвета в римские (черепица, помпейский красный, тёплая штукатурка)
const ROMAN = { '52d2ff': '#a33a2c', 'ecc581': '#c8693f', 'b63c35': '#b5543a', 'fff3d6': '#f2e6cc', 'f5f7fa': '#eee8dc' };
const artMat = await new Promise((res, rej) => {
  const img = new Image();
  img.onload = () => {
    const cv = document.createElement('canvas'); cv.width = img.width; cv.height = img.height;
    const g = cv.getContext('2d'); g.drawImage(img, 0, 0);
    const d = g.getImageData(0, 0, cv.width, cv.height);
    for (let i = 0; i < d.data.length; i += 4) {
      const hex = [0, 1, 2].map(k => d.data[i + k].toString(16).padStart(2, '0')).join('');
      const to = ROMAN[hex];
      if (to) { const c = parseInt(to.slice(1), 16); d.data[i] = c >> 16; d.data[i + 1] = (c >> 8) & 255; d.data[i + 2] = c & 255; }
    }
    g.putImageData(d, 0, 0);
    const map = new THREE.CanvasTexture(cv);
    map.colorSpace = THREE.SRGBColorSpace; map.magFilter = map.minFilter = THREE.NearestFilter; map.generateMipmaps = false;
    res(new THREE.MeshStandardMaterial({ map, roughness: 0.85, metalness: 0 }));
  };
  img.onerror = rej;
  img.src = encodeURI(ART + 'TexturaLowPoly.png');
});
function loadArt(name) {
  return cache['a:' + name] ??= new Promise((res, rej) => fbx.load(encodeURI(ART + name + '.fbx'), res, undefined, rej)).then(obj => {
    obj.traverse(o => {
      if (!o.isMesh) return;
      [].concat(o.material).forEach(m => { m.map?.dispose(); m.dispose(); });
      o.material = artMat;
      o.castShadow = true; o.receiveShadow = true;
    });
    return obj;
  });
}
function loadGltf(url) {
  return cache['g:' + url] ??= new Promise((res, rej) => gltf.load(encodeURI(url), res, undefined, rej)).then(g => {
    g.scene.traverse(o => { if (o.isMesh) { o.castShadow = true; o.receiveShadow = true; } });
    return g;
  });
}
const pending = [];
function art(name, x, z, rot = 0, k = 1) {
  const p = loadArt(name).then(src => {
    const o = src.clone();
    o.scale.multiplyScalar(ART_K * k);
    o.position.set(x, 0, z); o.rotation.y = rot;
    scene.add(o);
    return o;
  });
  pending.push(p.catch(e => console.warn("не загрузилось", name, e)));
  return p;
}
function nat(name, x, z, rot = 0, k = 1, dir = NAT) {
  const p = loadGltf(dir + name + '.gltf').then(g => {
    const o = g.scene.clone();
    o.scale.setScalar(k);
    o.position.set(x, 0, z); o.rotation.y = rot;
    scene.add(o);
    return o;
  });
  pending.push(p.catch(e => console.warn("не загрузилось", name, e)));
  return p;
}
const prop = (name, x, z, rot, k) => nat(name, x, z, rot, k, PROP);

/* ---------- Форум: храм, фонтан, статуи, лавки и прилавки ---------- */
art('Tenple', 0, -27, 0);
art('Fountain.002', 0, -2, 0, 0.75).then(f => {
  // вода в бассейне фонтана
  const box = new THREE.Box3().setFromObject(f), size = box.getSize(new THREE.Vector3());
  const water = new THREE.Mesh(new THREE.PlaneGeometry(size.x * 0.8, size.z * 0.8).rotateX(-Math.PI / 2),
    new THREE.MeshStandardMaterial({ color: '#4f9fb8', roughness: 0.15, metalness: 0.1, transparent: true, opacity: 0.85 }));
  water.position.set(f.position.x, box.min.y + size.y * 0.42, f.position.z);
  water.receiveShadow = true;
  scene.add(water);
});
art('Statue Base', -11, -11, 0); art('Zeus', -11, -11, 0, 0.9);
art('Statue Base', 11, -11, 0); art('Athenea', 11, -11, 0, 0.9);
art('Lion', -5, -15.8, 0, 0.8); art('Lion', 5, -15.8, 0, 0.8);
art('Shop', -15, -7, Math.PI / 2); art('Shop.001', -15, -1, Math.PI / 2); art('Shop', -15, 5, Math.PI / 2);
art('Shop.001', 15, -7, -Math.PI / 2); art('Shop', 15, -1, -Math.PI / 2); art('Shop.001', 15, 5, -Math.PI / 2);
art('Streetlight', -16.5, 10, 0); art('Streetlight', 16.5, 10, 0);
art('Sun Clock', 9, 7, 0);
art('Statue Base.001', -6, 6.5, 0); art('Hercules', -6, 6.5, 0.4, 0.9);
art('Big Torch', -3.2, -16.6, 0, 1.1); art('Big Torch', 3.2, -16.6, 0, 1.1);
for (const x of [-15.5, 15.5]) for (const z of [-13, 9]) art('Jardinera', x, z, 0, 1.3);
for (const [x, z] of [[-16, -4], [16, 2], [-16, 8.5], [16, -9]]) art('Flower Bush', x, z, 0, 1.0);
art('Horse Cart', 1.5, 20, Math.PI, 0.8);
// рынок у западной стороны
prop('Stall_Empty', -8, 2, Math.PI / 2, 1.1); prop('FarmCrate_Apple', -7.3, 1.4, 0.3); prop('FarmCrate_Carrot', -7.4, 2.6, -0.2);
prop('Stall_Cart_Empty', -8, 7, Math.PI / 2, 1.0); prop('Barrel_Apples', -6.6, 6.2, 0); prop('Barrel', -6.5, 8.1, 0.5);
prop('Stall_Empty', 8.5, -5, -Math.PI / 2, 1.1); prop('Vase_2', 7.4, -5.6, 0); prop('Vase_4', 7.5, -4.4, 0);
art('Jar.002', 6.6, -3.2, 0, 1.4); art('Jar.004', 7.1, -2.6, 0, 1.4); art('Basket.002', 6.4, -6.4, 0, 1.4);
art('Monumental Jar', -4, -12.5, 0, 0.9); art('Monumental Jar', 4, -12.5, 0, 0.9);
prop('Bench', -4, 9, 0); prop('Bench', 4, 9, 0);

/* ---------- Главная улица и кварталы ---------- */
const westRow = [['House.002', 16], ['Two Floored House', 24], ['House.004', 31], ['House.005', 50], ['Two Floored House', 58], ['House.002', 66]];
const eastRow = [['House.004', 16], ['House.005', 24], ['Two Floored House', 31], ['House.002', 50], ['House.004', 58], ['Two Floored House', 66]];
for (const [n, z] of westRow) art(n, -9, z, Math.PI / 2);
for (const [n, z] of eastRow) art(n, 9, z, -Math.PI / 2);
for (let z = 14; z < 72; z += 7) { if (Math.abs(z - 39) < 5) continue; art('Pine', -4.4, z, R(0, 6), 0.75); art('Pine', 4.4, z + 3.5, R(0, 6), 0.75); }
// поперечная улица
for (const [n, x] of [['House.003', -24], ['House with vegetable garden', -36], ['Two Floored House', -48]]) art(n, x, 31, 0);
for (const [n, x] of [['Long house with sunshade', 22], ['House.005', 34], ['House.002', 44], ['House.001', 56]]) art(n, x, 31, 0);
for (const [n, x, k] of [['House.004', -22], ['House.002', -32], ['University', 26, 0.8], ['Two Floored House', 40]]) art(n, x, 50, Math.PI, k || 1);
art('Well', -13, 44, 0, 1.2);
art('Titus Arch', 0, 78, Math.PI / 2, 0.55);
// оливы и пальмы у домов
for (const [x, z] of [[-17, 20], [17, 21], [-16, 56], [16, 60], [-28, 22], [30, 56]]) art('Tree', x, z, R(0, 6), R(0.65, 0.85));
for (const [x, z] of [[-18, 6], [18, -12], [-19, -14]]) art('Palm', x, z, R(0, 6), 0.7);
// кусты и цветы вдоль домов
for (let i = 0; i < 26; i++) {
  const side = i % 2 ? 1 : -1, z = 14 + (i >> 1) * 4.4;
  if (Math.abs(z - 39) < 4) continue;
  nat(rnd() < 0.5 ? 'Bush_Common_Flowers' : 'Bush_Common', side * R(6, 6.6), z + R(-1, 1), R(0, 6), R(0.45, 0.6));
}
for (let i = 0; i < 14; i++) nat(rnd() < 0.5 ? 'Flower_3_Group' : 'Flower_4_Group', R(-16, 16) + (rnd() < 0.5 ? -20 : 20), R(-22, -16), R(0, 6), R(0.5, 0.8));

/* ---------- Окраины: храм-ротонда, амфитеатр, акведук, ферма ---------- */
art('Amphitheatre', 62, -38, 0.3, 0.9);
for (let i = 0; i < 18; i++) art('Aqueduct', -70 + i * 4.24 * 1.0, -62, 0, 1.0);
art('Farm', -38, 14, 0, 0.9);
art('Granary', -54, 2, 0.4, 0.8);
// загон: простая деревянная изгородь
{
  const wood = new THREE.MeshStandardMaterial({ color: '#8a6440', roughness: 0.9, flatShading: true });
  const fence = (x0, z0, x1, z1) => {
    const L = Math.hypot(x1 - x0, z1 - z0), n = Math.ceil(L / 2.2), ang = Math.atan2(x1 - x0, z1 - z0);
    for (let i = 0; i <= n; i++) {
      const p = new THREE.Mesh(new THREE.BoxGeometry(0.16, 1.15, 0.16), wood);
      p.position.set(x0 + (x1 - x0) * i / n, 0.57, z0 + (z1 - z0) * i / n); p.castShadow = true; scene.add(p);
    }
    for (const y of [0.45, 0.9]) {
      const r = new THREE.Mesh(new THREE.BoxGeometry(0.08, 0.1, L), wood);
      r.position.set((x0 + x1) / 2, y, (z0 + z1) / 2); r.rotation.y = ang; r.castShadow = true; scene.add(r);
    }
  };
  fence(-33, 9.5, -16, 9.5); fence(-16, 9.5, -16, 28); fence(-16, 28, -33, 28); fence(-33, 28, -33, 20);
}
art('Hay bal', -32, 8, 0.5, 1.2); art('Hay bal', -30, 9.5, 1.4, 1.2); art('straw bale', -33.5, 10, 0, 1.2);
art('Stable', 40, 8, -Math.PI / 2, 0.7);
art('Mill', -48, 60, 0.6, 0.6);
// оливковая роща и лес за городом
for (let i = 0; i < 26; i++) art('Tree', R(-75, -40), R(40, 90), R(0, 6), R(0.6, 0.85));
for (let i = 0; i < 30; i++) { const a = R(0, Math.PI * 2), r = R(85, 130); nat(['CommonTree_1', 'CommonTree_2', 'CommonTree_3', 'Pine_1', 'Pine_2', 'Pine_3'][i % 6], Math.cos(a) * r, -Math.abs(Math.sin(a)) * r * 0.9 - 10, R(0, 6), R(0.9, 1.3)); }
for (let i = 0; i < 18; i++) art('Pine', R(20, 60), R(-25, -8), R(0, 6), R(0.6, 0.8));
for (let i = 0; i < 12; i++) nat(['Rock_Medium_1', 'Rock_Medium_2', 'Rock_Medium_3'][i % 3], R(-90, 90), R(-80, -45), R(0, 6), R(0.6, 1.2));
for (let i = 0; i < 60; i++) nat(['Grass_Common_Tall', 'Grass_Wispy_Tall', 'Grass_Common_Short'][i % 3], R(-70, 70), R(-50, 90), R(0, 6), R(0.6, 0.9)).then(o => { const x = o.position.x, z = o.position.z; if ((Math.abs(x) < 18 && z > -42 && z < 74) || (z > 34 && z < 44)) o.visible = false; });

/* ---------- Животные ---------- */
const animals = [];
async function animal(file, x, z, rot, height, clip, wander) {
  const g = await loadGltf(ANI + file + '.glb');
  const o = SkeletonUtils.clone(g.scene);
  g.scene.updateMatrixWorld(true);
  const box = new THREE.Box3().setFromObject(g.scene);
  o.scale.setScalar(height / (box.max.y - box.min.y));
  o.position.set(x, 0, z); o.rotation.y = rot;
  o.traverse(m => { if (m.isMesh) { m.castShadow = true; m.receiveShadow = true; } });
  scene.add(o);
  const mixer = new THREE.AnimationMixer(o);
  const clips = Object.fromEntries(g.animations.map(c => [c.name.replace(/^.*\|/, ''), c]));
  const a = { o, mixer, clips, home: new THREE.Vector3(x, 0, z), wander, t: R(0, 4), cur: null, speed: 0 };
  a.set = (n) => { const c = clips[n] || clips.Idle; if (!c) return; const act = mixer.clipAction(c); if (a.cur === act) return; act.reset().play(); if (a.cur) act.crossFadeFrom(a.cur, 0.4, false); a.cur = act; };
  a.set(clip);
  mixer.update(R(0, 3));
  animals.push(a);
}
pending.push(
  animal('Cow', -26, 16, 0.6, 1.5, 'Eating', 5), animal('Cow', -22, 21, 2.2, 1.45, 'Idle', 5), animal('Bull', -29, 22, 4, 1.6, 'Idle_2', 4),
  animal('Sheep_a', -20, 13, 1, 0.95, 'Idle_Eating', 4), animal('Sheep_a', -18.5, 16, 3, 0.9, 'Idle_Eating', 4), animal('Sheep_a', -23, 12, 5, 0.95, 'Idle', 4),
  animal('Pig_b', -30, 26, 0.5, 0.8, 'Idle_Eating', 3),
  animal('Horse_b', 34, 2, -1.2, 2.0, 'Idle', 5), animal('Horse_White', 37, 14, 2.4, 2.0, 'Eating', 5), animal('Donkey', 8, 30, 1.5, 1.5, 'Idle', 3),
  );
function stepAnimals(dt) {
  for (const a of animals) {
    a.mixer.update(dt);
    if (!a.wander) continue;
    a.t -= dt;
    if (a.t <= 0) {
      if (a.speed > 0) { a.speed = 0; a.set(rnd() < 0.6 ? (a.clips.Eating ? 'Eating' : 'Idle_Eating') : 'Idle'); a.t = R(4, 9); }
      else {
        const tx = a.home.x + R(-a.wander, a.wander), tz = a.home.z + R(-a.wander, a.wander);
        a.goal = new THREE.Vector3(tx, 0, tz); a.speed = 0.7; a.set('Walk'); a.t = 20;
      }
    }
    if (a.speed > 0 && a.goal) {
      const d = a.goal.clone().sub(a.o.position); const L = d.length();
      if (L < 0.2) { a.t = 0; continue; }
      const want = Math.atan2(d.x, d.z);
      let dy = want - a.o.rotation.y; dy = Math.atan2(Math.sin(dy), Math.cos(dy));
      a.o.rotation.y += dy * Math.min(1, dt * 2.5);
      if (Math.abs(dy) < 0.6) a.o.position.addScaledVector(d.normalize(), a.speed * dt);
    }
  }
}

/* ---------- Жители: ходят по улицам, болтают на форуме; легионеры у храма ---------- */
const TUNICS = ['#c9b48a', '#8a5a3a', '#7d8fae', '#a5523a', '#9a8e5e', '#b88f63', '#6f7f5a'];
const DRESSES = ['#d9c7a4', '#8fae9a', '#c97b6a', '#b9a3c4', '#d8b46a', '#9ab0c8'];
const HAIRC = ['#2e2018', '#4a2f1e', '#6b4226', '#1d1714', '#8a6a3a', '#a07a4a'];
function citizenLook(i) {
  const hair = HAIRC[i % HAIRC.length];
  if (i % 3 === 2) {
    const c = DRESSES[i % DRESSES.length];
    return { body: 'f', paint: { top: c, sleeve: 0.3, topBottom: 0.06, trim: i % 2 ? '#b3302a' : '#e2b850', neck: 1.47, foot: '#6a4a2e', footTop: 0.07 },
      skirt: { color: c, bottom: 0.42, flare: 1.4, hem: i % 2 ? '#b3302a' : '#e2b850' }, belt: '#e2b850', hair: [['Hair_Buns', hair], ['Eyebrows_Female', hair]] };
  }
  if (i % 7 === 0) {
    // сенатор в белой тоге с пурпурной каймой
    return { body: 'm', paint: { top: '#efe8d8', sleeve: 0.36, topBottom: 0.3, trim: '#7a3170', foot: '#5a3a22', footTop: 0.11 },
      skirt: { color: '#efe8d8', bottom: 0.32, flare: 1.3, hem: '#7a3170' }, sash: '#e6dfcf', hair: [['Hair_SimpleParted', '#bdb6aa'], ['Eyebrows_Regular', '#9c958a']] };
  }
  const t = TUNICS[i % TUNICS.length];
  const hairs = [['Hair_SimpleParted', hair], ['Eyebrows_Regular', hair]];
  if (i % 4 === 1) hairs.push(['Hair_Beard', hair]);
  return { body: 'm', paint: { top: t, sleeve: 0.31, topBottom: 0.66, trim: i % 2 ? '#e2b850' : '#5a3a22', foot: '#6a4a2e', footTop: 0.11 },
    skirt: { color: t, bottom: 0.62, flare: 1.25 }, belt: i % 2 ? '#5a3a22' : '#3b2a1e', hair: i % 5 === 3 ? [['Hair_Buzzed', hair], ['Eyebrows_Regular', hair]] : hairs };
}
// маршруты: петли по улицам и форуму
const ROUTES = [
  [[-1.6, 70], [-1.6, 12], [-10, 6], [-10, -10], [-1.6, -12], [-1.6, 12]],
  [[1.6, 12], [1.6, 70]],
  [[-60, 38], [60, 38]],
  [[60, 40], [-60, 40]],
  [[-12, -12], [12, -12], [12, 8], [-12, 8]],
  [[10, 7], [-10, 7], [-10, -9], [10, -9]],
  [[1.2, -14], [1.2, -38]],
];
const walkers = [];
function routeLen(r) { let L = 0; for (let i = 0; i < r.length; i++) { const a = r[i], b = r[(i + 1) % r.length]; L += Math.hypot(b[0] - a[0], b[1] - a[1]); } return L; }
function routeAt(r, d) {
  for (let i = 0; i < r.length; i++) {
    const a = r[i], b = r[(i + 1) % r.length], L = Math.hypot(b[0] - a[0], b[1] - a[1]);
    if (d <= L) { const t = d / L; return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, Math.atan2(b[0] - a[0], b[1] - a[1])]; }
    d -= L;
  }
  return [r[0][0], r[0][1], 0];
}
let ci = 0;
for (let k = 0; k < ROUTES.length; k++) {
  const r = ROUTES[k], L = routeLen(r), n = k < 2 ? 5 : k < 4 ? 4 : 3;
  for (let j = 0; j < n; j++) {
    const f = makePerson(citizenLook(ci++));
    const w = { f, r, L, d: (j / n) * L + R(0, 3), speed: R(0.9, 1.15) };
    w.f.actions.Walk_Loop.timeScale = w.speed / 0.97;
    play(f, 'Walk_Loop');
    f.mixer.update(R(0, 1.3));
    walkers.push(w);
  }
}
// беседующие на форуме
const idlers = [];
for (const [x, z, rot, clip] of [[-3, 3, 2.2, 'Idle_Talking_Loop'], [-4.4, 1.9, -0.9, 'Idle_Loop'], [6, 2, 4, 'Idle_Talking_Loop'], [5, 3.2, 0.8, 'Idle_Loop'], [-7.2, 2, -Math.PI / 2, 'Idle_Loop'], [7.6, -6.4, Math.PI / 2, 'Idle_Talking_Loop']]) {
  const f = makePerson(citizenLook(ci++));
  f.root.position.set(x, 0, z); f.root.rotation.y = rot - f.yaw0;
  play(f, clip); f.mixer.update(R(0, 3));
  idlers.push(f);
}
// легионеры: стража у храма и патруль
const guards = [];
for (const [x, z] of [[-4.2, -17.5], [4.2, -17.5]]) {
  const f = makeFighter('legionary'); arm(f);
  f.root.position.set(x, 0, z); f.root.rotation.y = -f.yaw0;
  play(f, 'Idle_Loop'); f.mixer.update(R(0, 2));
  guards.push(f);
}
for (let j = 0; j < 2; j++) {
  const f = makeFighter('legionary'); arm(f);
  const r = [[-0.6 + j * 1.2, 66], [-0.6 + j * 1.2, 14]];
  const w = { f, r, L: routeLen(r), d: 6, speed: 0.97 };
  play(f, 'Walk_Loop');
  walkers.push(w);
}

function stepPeople(dt) {
  for (const w of walkers) {
    w.d = (w.d + w.speed * dt) % w.L;
    const [x, z, h] = routeAt(w.r, w.d);
    w.f.root.position.set(x, 0, z);
    let dy = h - w.f.yaw0 - w.f.root.rotation.y; dy = Math.atan2(Math.sin(dy), Math.cos(dy));
    w.f.root.rotation.y += dy * Math.min(1, dt * 5);
    w.f.mixer.update(dt); lockGuard(w.f);
  }
  for (const f of idlers) f.mixer.update(dt);
  for (const f of guards) { f.mixer.update(dt); lockGuard(f); }
}

/* ---------- Камера и кнопки ---------- */
const VIEWS = {
  city: { pos: [58, 52, 92], tgt: [0, 0, 18] },
  forum: { pos: [14, 9, 24], tgt: [0, 2, -6] },
  street: { pos: [6, 2.6, 74], tgt: [0, 2, 40] },
  farm: { pos: [-10, 8, 34], tgt: [-26, 1, 17] },
};
let fly = null;
function view(name, instant) {
  const v = VIEWS[name];
  document.querySelectorAll('#views [data-v]').forEach(b => b.classList.toggle('on', b.dataset.v === name));
  const to = { pos: new THREE.Vector3(...v.pos), tgt: new THREE.Vector3(...v.tgt) };
  if (instant) { camera.position.copy(to.pos); controls.target.copy(to.tgt); controls.update(); return; }
  fly = { t: 0, from: { pos: camera.position.clone(), tgt: controls.target.clone() }, to };
}
document.querySelectorAll('#views [data-v]').forEach(b => b.onclick = () => view(b.dataset.v));
let evening = false;
document.getElementById('sun').onclick = e => { evening = !evening; setSun(evening ? 'evening' : 'day'); e.target.textContent = evening ? 'День' : 'Вечер'; };

function resize() {
  renderer.setSize(innerWidth, innerHeight, false);
  camera.aspect = innerWidth / innerHeight;
  camera.updateProjectionMatrix();
}
addEventListener('resize', resize);
resize();
view('city', true);

await Promise.all(pending);
// В этой версии three нет scene.environmentIntensity: отражения неба оставляем металлу, остальным — чуть-чуть,
// иначе рассеянный свет забивает солнце и тени пропадают
const tuned = new Set();
scene.traverse(o => { if (!o.isMesh) return; for (const m of [].concat(o.material)) { if (tuned.has(m)) continue; tuned.add(m); m.envMapIntensity = m.metalness > 0.4 ? 0.9 : 0.12; } });
status.textContent = `Готово: ${scene.children.length} объектов, жителей ${walkers.length + idlers.length + guards.length}`;
window.LAB = { scene, camera, controls, renderer, view, setSun, walkers, animals };

const clock = new THREE.Clock();
function tick(dt) {
  if (fly) {
    fly.t = Math.min(1, fly.t + dt / 1.6);
    const e = fly.t < 0.5 ? 2 * fly.t * fly.t : 1 - Math.pow(-2 * fly.t + 2, 2) / 2;
    camera.position.lerpVectors(fly.from.pos, fly.to.pos, e);
    controls.target.lerpVectors(fly.from.tgt, fly.to.tgt, e);
    if (fly.t >= 1) fly = null;
  }
  controls.update();
  // тень следует за тем, куда смотрит камера
  const tg = controls.target;
  sun.target.position.set(tg.x, 0, tg.z);
  sun.position.copy(sun.target.position).addScaledVector(sun.userData.dir, 120);
  stepPeople(dt);
  stepAnimals(dt);
  renderer.render(scene, camera);
}
renderer.setAnimationLoop(() => tick(Math.min(clock.getDelta(), 0.05)));
LAB.advance = sec => { for (let t = 0; t < sec; t += 1 / 30) tick(1 / 30); };
