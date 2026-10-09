// Настоящие бойцы для боёв: тела и движения Quaternius (CC0) со скелетом, одежда рисуется прямо на теле,
// доспехи, щиты и оружие строятся кодом и крепятся к костям. Звери — анимированные модели Quaternius,
// слон и машины — из набора Artisau. battle.js берёт отсюда фигуры через window.Battle3D; пока модуль
// не загрузился, бой рисуется прежними фигурками.
import * as THREE from 'three';
import { GLTFLoader } from '../vendor/three-module/examples/jsm/loaders/GLTFLoader.js';
import * as SkeletonUtils from '../vendor/three-module/examples/jsm/utils/SkeletonUtils.js';
import { mergeGeometries } from '../vendor/three-module/examples/jsm/utils/BufferGeometryUtils.js';

const ROOT = new URL('../', import.meta.url).href;
const loader = new GLTFLoader();
const load = name => new Promise((res, rej) => loader.load(ROOT + 'assets/look2/' + name, res, undefined, rej));
const V = () => new THREE.Vector3();
const UP = new THREE.Vector3(0, 1, 0);
const flat = (color, o) => new THREE.MeshStandardMaterial(Object.assign({ color, roughness: 0.85, metalness: 0, flatShading: true }, o || {}));
const HUMAN_H = 1.65;       // рост человека в клетках поля боя

/* ---------- Загрузка ---------- */
const [fg, wolfG, bullG] = await Promise.all([load('fighters.glb'), load('wolf.glb'), load('bull.glb')]);
if (!Look2.ready) await Look2.load();
const BODY = fg.scene;
BODY.updateMatrixWorld(true);
const HAIR = {};
// причёски лежат рядом с телом группами «hair:Имя» (загрузчик убирает двоеточие из имён)
const hairs = [];
BODY.traverse(o => { if (/^hair:?[A-Z]/.test(o.name)) hairs.push(o); });
for (const o of hairs) { HAIR[o.name.replace(/^hair:?/, '')] = o; o.parent.remove(o); }

// Щитоносцы: левая рука держит щит (поза из Sword_Idle), остальное тело играет любое движение
const LEFT_ARM = /^(clavicle_l|upperarm_l|lowerarm_l|hand_l|(index|middle|pinky|ring|thumb)_\d+(_leaf)?_l)\./;
const CLIPS = {}, NO_LEFT = {};
for (const c of fg.animations) {
  CLIPS[c.name] = c;
  const n = c.clone(); n.tracks = n.tracks.filter(t => !LEFT_ARM.test(t.name)); NO_LEFT[c.name] = n;
}
const GUARD = CLIPS.Sword_Idle.clone();
GUARD.name = 'Guard';
GUARD.tracks = GUARD.tracks.filter(t => LEFT_ARM.test(t.name));

/* ---------- Одежда, нарисованная на теле ---------- */
function prepareRest(mesh) {
  const g = mesh.geometry;
  if (g.attributes.rest) return;
  const n = g.attributes.position.count, arr = new Float32Array(n * 3), v = V();
  for (let i = 0; i < n; i++) { mesh.getVertexPosition(i, v); arr[i * 3] = v.x; arr[i * 3 + 1] = v.y; arr[i * 3 + 2] = v.z; }
  g.setAttribute('rest', new THREE.BufferAttribute(arr, 3));
}

function paintBody(mesh, o) {
  const C = c => new THREE.Color(c || '#000');
  const U = {
    uTop: { value: C(o.top) }, uTopOn: { value: o.top ? 1 : 0 }, uTopBot: { value: o.topBottom ?? 0.8 }, uSleeve: { value: o.sleeve ?? 0.34 }, uNeck: { value: o.neck ?? 1.49 },
    uLeg: { value: C(o.leg) }, uLegOn: { value: o.leg ? 1 : 0 }, uLegTop: { value: o.legTop ?? 1.02 }, uLegBot: { value: o.legBottom ?? 0 },
    uFoot: { value: C(o.foot) }, uFootOn: { value: o.foot ? 1 : 0 }, uFootTop: { value: o.footTop ?? 0.14 },
    uWrap: { value: C(o.wrap) }, uWrapOn: { value: o.wrap ? 1 : 0 }, uWrapTop: { value: o.wrapTop ?? 0.48 },
    uTrim: { value: C(o.trim) }, uTrimOn: { value: o.trim ? 1 : 0 }, uPlaid: { value: o.plaid ? 1 : 0 },
    uSkin: { value: C(o.skin || '#ffffff') }, uStripes: { value: C(o.stripes) }, uStripesOn: { value: o.stripes ? 1 : 0 },
  };
  const mat = mesh.material;
  mat.onBeforeCompile = sh => {
    Object.assign(sh.uniforms, U);
    sh.vertexShader = sh.vertexShader
      .replace('#include <common>', '#include <common>\nattribute vec3 rest;\nvarying vec3 vRest;')
      .replace('#include <begin_vertex>', '#include <begin_vertex>\nvRest = rest;');
    sh.fragmentShader = sh.fragmentShader
      .replace('#include <common>', `#include <common>
varying vec3 vRest;
uniform vec3 uTop, uLeg, uFoot, uWrap, uTrim, uSkin, uStripes;
uniform float uTopOn, uTopBot, uSleeve, uNeck, uLegOn, uLegTop, uLegBot, uFootOn, uFootTop, uWrapOn, uWrapTop, uTrimOn, uPlaid, uStripesOn;`)
      .replace('#include <map_fragment>', `#include <map_fragment>
{
  vec3 p = vRest; float ax = abs(p.x);
  diffuseColor.rgb *= uSkin;
  float lum = dot(diffuseColor.rgb, vec3(0.2126, 0.7152, 0.0722));
  float sh = clamp(0.62 + lum * 1.1, 0.72, 1.12);
  float neck = uNeck + 0.06 * smoothstep(0.065, 0.1, ax) - 0.045 * step(0.02, p.z) * (1.0 - smoothstep(0.0, 0.07, ax));
  float top = uTopOn * step(ax, uSleeve) * step(uTopBot, p.y) * step(p.y, neck);
  float leg = uLegOn * step(ax, 0.3) * step(p.y, uLegTop) * step(max(uFootTop, uLegBot), p.y);
  float foot = uFootOn * step(ax, 0.3) * step(p.y, uFootTop);
  vec3 legC = uLeg;
  if (uPlaid > 0.5) { float a = step(0.5, fract((p.x + p.z) * 9.0)); float b = step(0.5, fract(p.y * 9.0)); legC *= 0.72 + 0.2 * (a + b); }
  if (uWrapOn > 0.5 && p.y < uWrapTop) legC = uWrap * (0.8 + 0.25 * step(0.5, fract(p.y * 26.0 + (p.x + p.z) * 3.0)));
  vec3 c = diffuseColor.rgb;
  // боевая раскраска полосами по груди и рукам
  if (uStripesOn > 0.5) c = mix(c, uStripes, step(0.62, fract(p.y * 7.0 + ax * 4.0)) * step(1.05, p.y) * step(p.y, 1.45) * (1.0 - top));
  c = mix(c, uTop * sh, top);
  c = mix(c, legC * sh, leg);
  c = mix(c, uFoot * sh, foot);
  float trim = uTrimOn * top * clamp(step(uSleeve - 0.02, ax) * step(0.24, ax) + step(p.y, uTopBot + 0.022), 0.0, 1.0);
  diffuseColor.rgb = mix(c, uTrim * sh, trim);
}`);
  };
  mat.customProgramCacheKey = () => 'civ-fighter';
}

/* ---------- Материалы снаряжения ---------- */
const MAT = {
  steel: new THREE.MeshStandardMaterial({ color: '#c3c8cf', metalness: 0.7, roughness: 0.32, flatShading: true }),
  steelDark: new THREE.MeshStandardMaterial({ color: '#8f969f', metalness: 0.65, roughness: 0.4, flatShading: true }),
  bronze: new THREE.MeshStandardMaterial({ color: '#c99a45', metalness: 0.75, roughness: 0.3, flatShading: true }),
  gold: new THREE.MeshStandardMaterial({ color: '#e7bb4c', metalness: 0.8, roughness: 0.25, flatShading: true }),
  black: new THREE.MeshStandardMaterial({ color: '#3a3a44', metalness: 0.6, roughness: 0.4, flatShading: true }),
  leather: flat('#7a4f2e'), leatherDark: flat('#4e3320'),
  wood: flat('#8a5e38'), woodDark: flat('#5e3e24'),
  fur: flat('#8a7a64'), furLight: flat('#a8977c'), furDark: flat('#5e5040'),
  stone: flat('#9a958c'), bone: flat('#efe6d0'), horn: flat('#d8cdb2'),
};
for (const m of Object.values(MAT)) m.envMapIntensity = 0.2;
const cache = new Map();
const mat = (color, o) => { const k = color + JSON.stringify(o || {}); if (!cache.has(k)) cache.set(k, flat(color, o)); return cache.get(k); };
const twoSided = m => { const k = 'ds:' + m.uuid; if (!cache.has(k)) { const c = m.clone(); c.side = THREE.DoubleSide; cache.set(k, c); } return cache.get(k); };

/* ---------- Внешний вид всех бойцов ----------
   paint — одежда на теле; hair — причёски (цвет); helm, torso, skirt, cape — снаряжение;
   weapon / shield — в руках; skin — оттенок кожи; ghost — полупрозрачная тень. */
const R = { top: '#b3302a', trim: '#e2b850', foot: '#5a3a22', footTop: 0.11 };
const LOOKS = {
  legionary: { paint: { ...R, sleeve: 0.33, topBottom: 0.79 }, hair: [['Buzzed', '#3b2a1e'], ['Eyebrows_Regular', '#3b2a1e']],
    helm: { type: 'galea', crest: '#b3302a' }, torso: 'lorica', skirt: '#b3302a', pteruges: true, straps: true, cape: '#8e2620', weapon: 'gladius', shield: { type: 'scutum', color: '#b3302a' } },
  spearman: { paint: { ...R, top: '#8e2620', sleeve: 0.33, topBottom: 0.79 }, hair: [['Buzzed', '#2e2018'], ['Eyebrows_Regular', '#2e2018']],
    helm: { type: 'galea', crest: '#efe8d8', tall: true }, torso: 'cuirass', skirt: '#8e2620', pteruges: true, greaves: true, weapon: 'spear', shield: { type: 'round', color: '#a8362a', rim: MAT.bronze, r: 0.36 } },
  archer: { paint: { top: '#6f7f4a', trim: '#c9a046', sleeve: 0.36, topBottom: 0.68, foot: '#5a3a22', footTop: 0.11, leg: '#6a5a40', legTop: 0.68, legBottom: 0.36 }, hair: [['SimpleParted', '#4a2f1e'], ['Eyebrows_Regular', '#4a2f1e']],
    helm: { type: 'cone' }, belt: '#5a3a22', quiver: true, weapon: 'bow' },
  bandit: { paint: { top: '#6b5a46', topBottom: 0.62, sleeve: 0.36, leg: '#4a3f33', legTop: 0.62, foot: '#3a2a1e', footTop: 0.16 }, hair: [['Long', '#2e2018'], ['Beard', '#2e2018'], ['Eyebrows_Regular', '#2e2018']],
    helm: { type: 'hood', color: '#5a4a38' }, belt: '#3a2a1e', weapon: 'dagger' },
  slinger: { paint: { top: '#e6dcc6', trim: '#8a3a2a', topBottom: 0.66, sleeve: 0.3, foot: '#4a3020', footTop: 0.13 }, hair: [['Buzzed', '#3b2a1e'], ['Beard', '#3b2a1e'], ['Eyebrows_Regular', '#3b2a1e']],
    helm: { type: 'band', color: '#a8362a' }, belt: '#4a3020', weapon: 'sling' },
  wolf: { beast: 'wolf' },
  boar: { brute: 'boar' },
  bear: { brute: 'bear' },
  gaul: { paint: { leg: '#3f6b4a', plaid: 1, foot: '#4a3020', footTop: 0.16 }, hair: [['Long', '#e3b062'], ['Beard', '#d29e52'], ['Eyebrows_Regular', '#c08c48']],
    mantle: true, belt: '#4e3320', cuffs: true, weapon: 'axe', shield: { type: 'round', color: '#4d7a3a', rim: MAT.wood, r: 0.34 } },
  gaulArcher: { paint: { leg: '#7a5a3a', plaid: 1, top: '#5f7a4a', topBottom: 0.95, sleeve: 0.3, foot: '#4a3020', footTop: 0.16 }, hair: [['Long', '#b8642e'], ['Beard', '#a8582a'], ['Eyebrows_Regular', '#a8582a']],
    belt: '#4e3320', quiver: true, weapon: 'bow' },
  berserker: { paint: { leg: '#4a3a2a', wrap: '#6a5a40', foot: '#3a2a1e', footTop: 0.16, stripes: '#3a5aa0' }, hair: [['Long', '#c2603a'], ['Beard', '#b8562e'], ['Eyebrows_Regular', '#b8562e']],
    mantle: true, belt: '#3a2a1e', cuffs: true, weapon: 'bigaxe' },
  bull: { beast: 'bull', tint: { Main: '#3e2c22', Main_Light: '#5e4636' } },
  pirate: { paint: { top: '#e8dcc0', topBottom: 0.95, sleeve: 0.38, leg: '#3a4a6a', foot: '#3a2a1e', footTop: 0.14, plaid: 0 }, hair: [['Long', '#1e1a18'], ['Beard', '#1e1a18'], ['Eyebrows_Regular', '#1e1a18']],
    helm: { type: 'band', color: '#a8362a', big: true }, belt: '#a8362a', weapon: 'sword' },
  mercenary: { paint: { top: '#5a2a6a', trim: '#e2b850', topBottom: 0.7, sleeve: 0.33, foot: '#4a3020', footTop: 0.11 }, hair: [['Buzzed', '#1e1a18'], ['Beard', '#1e1a18'], ['Eyebrows_Regular', '#1e1a18']],
    helm: { type: 'bronze', crest: '#1e1a18' }, torso: 'cuirass', skirt: '#5a2a6a', greaves: true, weapon: 'spear', shield: { type: 'round', color: '#c99a45', rim: MAT.bronze, r: 0.36, metal: true } },
  shade: { paint: { top: '#2a2a38', trim: '#4a4a66', sleeve: 0.33, topBottom: 0.79, foot: '#1e1e28', footTop: 0.11 }, skin: '#5a5a78', ghost: true, eyes: '#8ad0ff',
    helm: { type: 'galea', crest: '#2a2a38', metal: MAT.black }, torso: 'lorica', torsoMat: MAT.black, skirt: '#2a2a38', weapon: 'gladius', shield: { type: 'scutum', color: '#2a2a38' } },
  hellhound: { beast: 'wolf', tint: { Main: '#3a1a1a', Main_Light: '#5a2a1e' }, eyes: '#ff5a2a', scale: 1.1 },
  chief: { paint: { top: '#5a4a38', topBottom: 0.62, sleeve: 0.36, leg: '#3a3028', legTop: 0.62, foot: '#2a1e14', footTop: 0.16 }, hair: [['Long', '#1e1a18'], ['Beard', '#1e1a18'], ['Eyebrows_Regular', '#1e1a18']],
    belt: '#2a1e14', cape: '#8e2620', cuffs: true, mantle: true, weapon: 'bigaxe' },
  greatbear: { brute: 'bear', scale: 1.15, colors: { main: '#3e2a1c', light: '#5e4430', dark: '#22160e' }, eyes: '#ffb03a' },
  gaulKing: { paint: { leg: '#3a4a7a', plaid: 1, top: '#c9a046', topBottom: 0.95, sleeve: 0.25, foot: '#4a3020', footTop: 0.16 }, hair: [['Long', '#e3b062'], ['Beard', '#d29e52'], ['Eyebrows_Regular', '#c08c48']],
    helm: { type: 'winged' }, cape: '#2a4a8a', belt: '#4e3320', torc: true, weapon: 'sword', shield: { type: 'round', color: '#c99a45', rim: MAT.gold, r: 0.38, metal: true } },
  giant: { paint: { leg: '#5a4a32', legTop: 1.0, legBottom: 0.68, foot: '#3a2a1e', footTop: 0.14 }, hair: [['Long', '#4a3020'], ['Beard', '#4a3020'], ['Eyebrows_Regular', '#4a3020']],
    mantle: true, belt: '#3a2a1e', cuffs: true, weapon: 'club' },
  minotaur: { paint: { leg: '#8e2620', legTop: 1.0, legBottom: 0.7, foot: '#2a1e14', footTop: 0.14 }, skin: '#6a4a38', bullHead: true, belt: '#3a2a1e', weapon: 'doubleaxe' },
  cyclops: { paint: { leg: '#6a5a40', legTop: 1.0, legBottom: 0.7, foot: '#3a2a1e', footTop: 0.14 }, skin: '#c8b8b0', oneEye: true, belt: '#3a2a1e', weapon: 'none' },
  elephant: { prop: 'War Elephant', h: 2.0 },
  cerberus: { beast: 'wolf', tint: { Main: '#1e1414', Main_Light: '#3a1a14' }, eyes: '#ff3a1a', heads: 3 },
  ballista: { prop: 'Balista', h: 0.95, yaw: Math.PI / 2 },
  catapult: { prop: 'Catapult', h: 1.25, yaw: -Math.PI / 2 },
};

/* ---------- Сборка человека ---------- */
// Мелкие детали склеиваются по материалу — на поле десятки бойцов, отрисовка должна быть дешёвой
function compact(obj) {
  obj.updateMatrixWorld(true);
  const byMat = new Map();
  obj.traverse(o => {
    if (!o.isMesh) return;
    const g = o.geometry.index ? o.geometry.toNonIndexed() : o.geometry.clone();
    for (const k of Object.keys(g.attributes)) if (k !== 'position' && k !== 'normal') g.deleteAttribute(k);
    g.applyMatrix4(o.matrixWorld);
    if (!byMat.has(o.material)) byMat.set(o.material, []);
    byMat.get(o.material).push(g);
  });
  const out = new THREE.Group();
  for (const [m, list] of byMat) {
    const g = list.length > 1 ? mergeGeometries(list) : list[0];
    g.userData.own = true;          // своя у каждой фигуры — после боя освобождается
    out.add(new THREE.Mesh(g, m));
  }
  return out;
}

function attach(fig, boneName, obj, pos, axes) {
  obj = compact(obj);
  const m = new THREE.Matrix4().makeBasis(axes ? axes[0] : fig.left, axes ? axes[1] : UP, axes ? axes[2] : fig.fwd);
  obj.quaternion.setFromRotationMatrix(m);
  obj.position.copy(pos);
  obj.updateMatrixWorld(true);
  fig.bone(boneName).attach(obj);
  obj.traverse(o => { if (o.isMesh) { o.castShadow = true; o.receiveShadow = true; } });
  return obj;
}
const grp = m => new THREE.Group().add(m);

function addHair(fig, name, color) {
  const src = HAIR[name];
  if (!src) return;
  src.traverse(o => {
    if (!o.isMesh) return;
    const m = new THREE.Mesh(o.geometry, o.material.clone());
    m.material.color.set(color);
    fig.mats.push(m.material);
    o.updateWorldMatrix(true, false);
    m.matrix.copy(o.matrixWorld).decompose(m.position, m.quaternion, m.scale);
    m.updateMatrixWorld(true);
    fig.bone('Head').attach(m);
    m.castShadow = true;
  });
}

function makeHuman(key, look) {
  const root = SkeletonUtils.clone(BODY);
  root.updateMatrixWorld(true);
  const box0 = new THREE.Box3().setFromObject(root);
  const mats = [];
  root.traverse(o => {
    if (!o.isMesh) return;
    o.castShadow = true; o.receiveShadow = true;
    o.material = o.material.clone();
    mats.push(o.material);
    const n = o.material.name || '';
    if (/Hair/i.test(n)) o.visible = false;
    if (/Eye/i.test(n) && (look.oneEye || look.bullHead)) o.visible = false;
    if (/Eye/i.test(n) && look.eyes) { o.material.emissive = new THREE.Color(look.eyes); o.material.emissiveIntensity = 2; }
    if (o.isSkinnedMesh && /Superhero/i.test(n)) { prepareRest(o); paintBody(o, Object.assign({ skin: look.skin }, look.paint || {})); }
  });
  const bone = n => root.getObjectByName(n);
  const P = n => bone(n).getWorldPosition(V());
  const s = (box0.max.y - box0.min.y) / 1.8;
  const fwd = P('ball_r').sub(P('foot_r')).setY(0).normalize();
  const left = V().crossVectors(UP, fwd).normalize();
  const fig = { root, key, bone, P, s, fwd, left, mats, kind: 'human' };
  // под закрытым шлемом волосы на макушке не нужны — торчали бы сквозь него; борода и брови остаются
  const covered = look.helm && ['galea', 'bronze', 'cone', 'hood'].includes(look.helm.type);
  for (const [n, c] of look.hair || []) if (!covered || n === 'Beard' || n === 'Eyebrows_Regular') addHair(fig, n === 'Eyebrows_Regular' ? n : 'Hair_' + n, c);
  dress(fig, look);
  fig.mixer = new THREE.AnimationMixer(root);
  fig.shield = !!look.shield;
  fig.actions = {};
  for (const [name, clip] of Object.entries(CLIPS)) fig.actions[name] = fig.mixer.clipAction(fig.shield && name !== 'Death01' ? NO_LEFT[name] : clip);
  if (fig.shield) { fig.guard = fig.mixer.clipAction(GUARD); fig.guard.play(); }
  arm(fig, look);
  const own = new Map();
  root.traverse(o => {
    if (!o.isMesh || mats.includes(o.material)) return;
    if (!own.has(o.material)) { const c = o.material.clone(); own.set(o.material, c); mats.push(c); }
    o.material = own.get(o.material);
  });
  if (look.ghost) for (const m of mats) { m.transparent = true; m.opacity = 0.82; }
  return fig;
}

// Снаряжение на теле: шлем, доспех, юбка, пояс, плащ, мех, поножи, колчан
function dress(fig, look) {
  const { s, P } = fig;
  const shoulderW = P('upperarm_l').distanceTo(P('upperarm_r'));
  const a = shoulderW * 0.45, b = a * 0.72;
  const H = P('Head'), waist = P('spine_01'), chest = P('spine_03'), neck = P('neck_01'), pel = P('pelvis');
  const hm = look.helm;
  if (hm) {
    const r = 0.108 * s, helm = new THREE.Group();
    const metal = hm.metal || (hm.type === 'bronze' || hm.type === 'winged' ? MAT.bronze : MAT.steel);
    if (hm.type === 'galea' || hm.type === 'bronze') {
      const dome = new THREE.Mesh(new THREE.SphereGeometry(r, 16, 9, 0, Math.PI * 2, 0, Math.PI * 0.6), metal);
      dome.scale.set(1, 1, 1.12); helm.add(dome);
      const band = new THREE.Mesh(new THREE.TorusGeometry(r * 0.99, r * 0.075, 6, 20), MAT.bronze);
      band.rotation.x = Math.PI / 2; band.position.y = -r * 0.2; band.scale.set(1, 1.12, 1); helm.add(band);
      const nape = new THREE.Mesh(new THREE.BoxGeometry(r * 1.8, r * 0.1, r * 0.8), metal);
      nape.position.set(0, -r * 0.48, -r * 1.12); nape.rotation.x = -0.5; helm.add(nape);
      for (const sx of [-1, 1]) {
        const cheek = new THREE.Mesh(new THREE.BoxGeometry(r * 0.1, r * 0.72, r * 0.62), metal);
        cheek.position.set(sx * r * 0.97, -r * 0.62, r * 0.3); cheek.rotation.z = sx * 0.08; helm.add(cheek);
      }
      const crest = new THREE.Group();
      const cm = mat(hm.crest), cm2 = mat(new THREE.Color(hm.crest).multiplyScalar(0.8).getStyle());
      for (let i = 0; i <= 12; i++) {
        const ang = -Math.PI / 2 + i / 12 * Math.PI, rr = r * (hm.tall ? 1.32 : 1.18);
        const tuft = new THREE.Mesh(new THREE.BoxGeometry(r * 0.32, r * (hm.tall ? 0.8 : 0.5), r * 0.32), i % 2 ? cm : cm2);
        tuft.position.set(0, Math.cos(ang) * rr * 0.98, Math.sin(ang) * rr * 1.1); tuft.rotation.x = ang; crest.add(tuft);
      }
      crest.position.y = r * 0.05; helm.add(crest);
    } else if (hm.type === 'winged') {
      const dome = new THREE.Mesh(new THREE.SphereGeometry(r, 14, 8, 0, Math.PI * 2, 0, Math.PI * 0.55), MAT.gold);
      dome.scale.set(1.02, 0.95, 1.1); helm.add(dome);
      for (const sx of [-1, 1]) {
        const wing = new THREE.Mesh(new THREE.BoxGeometry(r * 0.12, r * 1.1, r * 0.55), MAT.gold);
        wing.position.set(sx * r * 1.05, r * 0.45, -r * 0.1); wing.rotation.z = -sx * 0.5; helm.add(wing);
      }
    } else if (hm.type === 'cone') {
      const c = new THREE.Mesh(new THREE.ConeGeometry(r * 1.12, r * 1.5, 10), MAT.bronze);
      c.position.y = r * 0.5; helm.add(c);
      const band = new THREE.Mesh(new THREE.TorusGeometry(r * 1.0, r * 0.07, 6, 18), MAT.leatherDark);
      band.rotation.x = Math.PI / 2; band.position.y = -r * 0.15; helm.add(band);
    } else if (hm.type === 'hood') {
      // капюшон открыт спереди, чтобы было видно лицо
      const hood = new THREE.Mesh(new THREE.SphereGeometry(r * 1.18, 12, 8, Math.PI / 2 + 0.85, Math.PI * 2 - 1.7, 0, Math.PI * 0.62), mat(hm.color, { side: THREE.DoubleSide }));
      hood.scale.set(1, 1.05, 1.15); hood.position.set(0, -r * 0.1, -r * 0.12); helm.add(hood);
      const tail = new THREE.Mesh(new THREE.ConeGeometry(r * 0.5, r * 1.2, 8), mat(hm.color));
      tail.position.set(0, -r * 0.2, -r * 1.2); tail.rotation.x = -1.9; helm.add(tail);
    } else if (hm.type === 'band') {
      const band = new THREE.Mesh(new THREE.TorusGeometry(r * 0.98, r * (hm.big ? 0.16 : 0.09), 6, 20), mat(hm.color));
      band.rotation.x = Math.PI / 2; band.scale.set(1, 1.15, 1); band.position.y = hm.big ? r * 0.15 : -r * 0.05; helm.add(band);
      if (hm.big) { const top = new THREE.Mesh(new THREE.SphereGeometry(r * 1.0, 12, 6, 0, Math.PI * 2, 0, Math.PI * 0.45), mat(hm.color)); top.scale.set(1, 0.8, 1.12); top.position.y = r * 0.1; helm.add(top); }
    }
    attach(fig, 'Head', helm, V().copy(H).addScaledVector(UP, 0.145 * s).addScaledVector(fig.fwd, 0.002 * s));
  }
  if (look.bullHead) {
    // голова быка поверх человеческой: морда, рога, уши
    const r = 0.11 * s, head = new THREE.Group();
    const fur = mat('#4a3022'), snoutM = mat('#6a4a3a'), hornM = MAT.horn;
    const skull = new THREE.Mesh(new THREE.SphereGeometry(r * 1.25, 12, 9), fur); skull.scale.set(1, 1.05, 1.15); head.add(skull);
    const snout = new THREE.Mesh(new THREE.BoxGeometry(r * 1.2, r * 0.9, r * 1.1), snoutM); snout.position.set(0, -r * 0.45, r * 1.15); head.add(snout);
    for (const sx of [-1, 1]) {
      const horn = new THREE.Mesh(new THREE.ConeGeometry(r * 0.28, r * 1.9, 7), hornM);
      horn.position.set(sx * r * 1.5, r * 0.75, 0); horn.rotation.z = -sx * 1.05; head.add(horn);
      const ear = new THREE.Mesh(new THREE.BoxGeometry(r * 0.6, r * 0.18, r * 0.4), fur); ear.position.set(sx * r * 1.3, r * 0.15, -r * 0.2); ear.rotation.z = sx * 0.4; head.add(ear);
      const eye = new THREE.Mesh(new THREE.SphereGeometry(r * 0.13, 8, 6), mat('#ff3a1a', { emissive: '#ff2a0a', emissiveIntensity: 1.5 })); eye.position.set(sx * r * 0.5, r * 0.2, r * 1.1); head.add(eye);
    }
    const ring = new THREE.Mesh(new THREE.TorusGeometry(r * 0.25, r * 0.06, 6, 12), MAT.gold); ring.position.set(0, -r * 0.75, r * 1.72); head.add(ring);
    attach(fig, 'Head', head, V().copy(H).addScaledVector(UP, 0.1 * s).addScaledVector(fig.fwd, 0.02 * s));
  }
  if (look.oneEye) {
    const r = 0.11 * s, e = new THREE.Group();
    const white = new THREE.Mesh(new THREE.SphereGeometry(r * 0.42, 14, 10), mat('#f6f2e6', { roughness: 0.3 })); e.add(white);
    const iris = new THREE.Mesh(new THREE.SphereGeometry(r * 0.2, 10, 8), mat('#2a5a3a')); iris.position.z = r * 0.3; e.add(iris);
    const pupil = new THREE.Mesh(new THREE.SphereGeometry(r * 0.1, 8, 6), mat('#0a0a0a')); pupil.position.z = r * 0.42; e.add(pupil);
    attach(fig, 'Head', e, V().copy(H).addScaledVector(UP, 0.105 * s).addScaledVector(fig.fwd, 0.088 * s));
  }
  if (look.torso === 'lorica') {
    const metalA = look.torsoMat || MAT.steel, metalB = look.torsoMat || MAT.steelDark;
    const y0 = waist.y - 0.03 * s, y1 = chest.y + 0.07 * s, n = 5;
    for (let i = 0; i < n; i++) {
      const t = i / (n - 1), h = (y1 - y0) / n, k = 0.96 + t * 0.16;
      const c = V().lerpVectors(waist, chest, t); c.y = y0 + h * (i + 0.5);
      const m = new THREE.Mesh(new THREE.CylinderGeometry(1, 0.97, h * 0.94, 18), i % 2 ? metalA : metalB);
      m.scale.set(a * k, 1, b * k);
      attach(fig, i < 2 ? 'spine_01' : i < 4 ? 'spine_02' : 'spine_03', grp(m), c.addScaledVector(fig.fwd, 0.012 * s));
    }
    const yokeH = neck.y - y1 + 0.03 * s;
    const yoke = new THREE.Mesh(new THREE.SphereGeometry(1, 20, 8, 0, Math.PI * 2, Math.PI * 0.17, Math.PI * 0.33), metalA);
    yoke.scale.set(a * 1.13, yokeH, b * 1.2);
    attach(fig, 'spine_03', grp(yoke), V().copy(chest).setY(y1 - yokeH * 0.12).addScaledVector(fig.fwd, 0.012 * s));
    pauldrons(fig, chest, metalA, metalB);
  } else if (look.torso === 'cuirass') {
    // бронзовый «мускульный» панцирь
    const y0 = waist.y - 0.04 * s, y1 = neck.y - 0.02 * s, h = y1 - y0;
    const shell = new THREE.Mesh(new THREE.CylinderGeometry(1.08, 0.95, h, 18, 3), MAT.bronze);
    shell.scale.set(a * 1.04, 1, b * 1.2);
    attach(fig, 'spine_02', grp(shell), V().copy(waist).setY(y0 + h / 2).addScaledVector(fig.fwd, 0.014 * s));
    for (const sx of [-1, 1]) {
      const pec = new THREE.Mesh(new THREE.SphereGeometry(0.06 * s, 10, 6), MAT.bronze); pec.scale.set(1.3, 0.8, 0.5);
      attach(fig, 'spine_03', pec, V().copy(chest).addScaledVector(fig.left, sx * a * 0.42).addScaledVector(fig.fwd, b * 1.12).addScaledVector(UP, 0.02 * s));
    }
    pauldrons(fig, chest, MAT.bronze, MAT.bronze);
  }
  if (look.belt) {
    const belt = new THREE.Mesh(new THREE.TorusGeometry(1, 0.075, 6, 22), mat(look.belt));
    belt.rotation.x = Math.PI / 2; belt.scale.set(a * 0.98, b * 1.02, 0.55);
    attach(fig, 'spine_01', grp(belt), V().copy(waist).setY(waist.y - 0.05 * s));
  }
  if (look.skirt) {
    const skirt = new THREE.Mesh(new THREE.CylinderGeometry(a * 0.94, a * 1.22, 0.24 * s, 20, 1, true), twoSided(mat(look.skirt)));
    skirt.scale.z = 0.8;
    attach(fig, 'pelvis', grp(skirt), V().copy(pel).addScaledVector(UP, -0.1 * s));
    if (look.pteruges) for (let i = 0; i < 4; i++) {
      const strip = new THREE.Mesh(new THREE.BoxGeometry(0.03 * s, 0.2 * s, 0.012 * s), MAT.leatherDark);
      attach(fig, 'pelvis', grp(strip), V().copy(pel).addScaledVector(fig.left, (i - 1.5) * 0.05 * s).addScaledVector(UP, -0.1 * s).addScaledVector(fig.fwd, b * 1.12));
    }
  }
  if (look.straps || look.greaves) for (const side of ['l', 'r']) {
    const f = P('foot_' + side), calf = P('calf_' + side);
    if (look.greaves) {
      const g = new THREE.Mesh(new THREE.CylinderGeometry(0.058 * s, 0.05 * s, calf.distanceTo(f) * 0.62, 10, 1, true), twoSided(MAT.bronze));
      const mid = V().lerpVectors(calf, f, 0.42);
      attach(fig, 'calf_' + side, grp(g), mid, [fig.left, V().subVectors(calf, f).normalize(), fig.fwd]);
    } else for (let k = 0; k < 3; k++) {
      const ring = new THREE.Mesh(new THREE.TorusGeometry(0.05 * s, 0.009 * s, 4, 12), MAT.leather);
      ring.rotation.x = Math.PI / 2;
      attach(fig, 'calf_' + side, grp(ring), V().lerpVectors(calf, f, 0.68 + k * 0.11));
    }
  }
  if (look.cape) {
    const capeLen = 0.66 * s, capeW = shoulderW * 0.9;
    const cg = new THREE.CylinderGeometry(capeW * 0.55, capeW * 0.75, capeLen, 10, 1, true, Math.PI * 0.62, Math.PI * 0.76).translate(0, -capeLen / 2, 0);
    const cape = new THREE.Mesh(cg, twoSided(mat(look.cape)));
    cape.scale.z = 0.5; cape.rotation.x = 0.1;
    attach(fig, 'spine_03', grp(cape), V().copy(chest).setY(neck.y - 0.01 * s).addScaledVector(fig.fwd, -0.01 * s));
  }
  if (look.mantle) {
    const mantle = new THREE.Group(), furs = [MAT.fur, MAT.furLight, MAT.furDark];
    for (let i = 0; i < 13; i++) {
      const ang = -Math.PI * 0.8 + i / 12 * Math.PI * 1.6;
      const m = new THREE.Mesh(new THREE.IcosahedronGeometry(0.075 * s, 0), furs[i % 3]);
      m.position.set(Math.sin(ang) * a * 0.95, Math.cos(ang * 0.5) * 0.02 * s, -Math.cos(ang) * b * 0.9);
      m.scale.set(1.25, 0.8, 1.1); m.rotation.set(i * 1.3, i * 2.1, i * 0.7);
      mantle.add(m);
    }
    attach(fig, 'spine_03', mantle, V().copy(chest).setY(neck.y - 0.03 * s));
  }
  if (look.cuffs) for (const side of ['l', 'r']) {
    const cuff = new THREE.Mesh(new THREE.CylinderGeometry(0.052 * s, 0.046 * s, 0.12 * s, 8), MAT.leather);
    cuff.rotation.z = Math.PI / 2;
    attach(fig, 'lowerarm_' + side, grp(cuff), V().lerpVectors(P('lowerarm_' + side), P('hand_' + side), 0.72));
  }
  if (look.torc) {
    const torc = new THREE.Mesh(new THREE.TorusGeometry(0.075 * s, 0.012 * s, 6, 16, Math.PI * 1.6), MAT.gold);
    torc.rotation.x = Math.PI / 2; torc.rotation.z = Math.PI * 0.7;
    attach(fig, 'neck_01', grp(torc), V().copy(neck).addScaledVector(UP, -0.01 * s).addScaledVector(fig.fwd, 0.01 * s));
  }
  if (look.quiver) {
    const q = new THREE.Group();
    const tube = new THREE.Mesh(new THREE.CylinderGeometry(0.05 * s, 0.045 * s, 0.4 * s, 8), MAT.leather); q.add(tube);
    for (let i = 0; i < 4; i++) { const arrow = new THREE.Mesh(new THREE.BoxGeometry(0.012 * s, 0.1 * s, 0.03 * s), mat('#efe6d0')); arrow.position.set((i - 1.5) * 0.018 * s, 0.24 * s, 0); q.add(arrow); }
    q.rotation.z = 0.5;
    attach(fig, 'spine_03', q, V().copy(chest).addScaledVector(fig.fwd, -b * 1.25).addScaledVector(UP, 0.02 * s));
  }
}

function pauldrons(fig, chest, A, B) {
  const { s, P } = fig;
  for (const side of ['l', 'r']) {
    const sh = P('upperarm_' + side), out = V().subVectors(sh, chest).setY(0).normalize();
    const cap = new THREE.Group();
    for (let i = 0; i < 3; i++) {
      const m = new THREE.Mesh(new THREE.SphereGeometry(0.1 * s, 12, 5, 0, Math.PI * 2, 0, Math.PI * 0.5), i % 2 ? B : A);
      m.scale.set(1.0, 0.6, 1.05); m.position.y = -i * 0.032 * s; cap.add(m);
    }
    attach(fig, 'upperarm_' + side, cap, V().copy(sh).addScaledVector(UP, 0.03 * s).addScaledVector(out, 0.03 * s));
  }
}

// Оружие и щит — в боевой стойке, чтобы правильно лечь в руку
function arm(fig, look) {
  const { s } = fig;
  const act = fig.actions.Sword_Idle;
  act.play(); fig.mixer.update(0.4); fig.root.updateMatrixWorld(true);
  const P = fig.P;
  const hand = P('hand_r'), mid = P('middle_01_r'), thumb = P('thumb_01_r'), fore = P('lowerarm_r');
  const f = V().subVectors(hand, fore).normalize();
  const t = V().subVectors(thumb, hand).normalize();
  const d = V().copy(t).addScaledVector(f, -t.dot(f)).normalize();
  const x = V().crossVectors(d, f).normalize();
  const z = V().crossVectors(x, d).normalize();
  const grip = V().lerpVectors(hand, mid, 0.7);
  const w = new THREE.Group();
  const blade = (L, W, m) => {
    const sh = new THREE.Shape();
    sh.moveTo(-W, 0); sh.lineTo(W, 0); sh.lineTo(W * 0.9, L * 0.82); sh.lineTo(0, L); sh.lineTo(-W * 0.9, L * 0.82); sh.closePath();
    return new THREE.Mesh(new THREE.ExtrudeGeometry(sh, { depth: 0.008 * s, bevelEnabled: true, bevelThickness: 0.004 * s, bevelSize: 0.004 * s, bevelSegments: 1 }).translate(0, 0, -0.004 * s), m || MAT.steel);
  };
  const hilt = (len) => {
    const handle = new THREE.Mesh(new THREE.CylinderGeometry(0.016 * s, 0.018 * s, 0.11 * s, 8), MAT.woodDark); w.add(handle);
    const guard = new THREE.Mesh(new THREE.BoxGeometry(0.1 * s, 0.025 * s, 0.045 * s), MAT.bronze); guard.position.y = 0.065 * s; w.add(guard);
    const pommel = new THREE.Mesh(new THREE.SphereGeometry(0.028 * s, 8, 6), MAT.bronze); pommel.position.y = -0.07 * s; w.add(pommel);
    const b = blade(len, 0.032 * s); b.position.y = 0.075 * s; w.add(b);
  };
  const axeHead = (size, double) => {
    const sh = new THREE.Shape();
    sh.moveTo(0, 0); sh.lineTo(0.17 * size, -0.06 * size); sh.quadraticCurveTo(0.22 * size, 0.07 * size, 0.17 * size, 0.2 * size); sh.lineTo(0, 0.14 * size); sh.closePath();
    const g = new THREE.ExtrudeGeometry(sh, { depth: 0.02 * size, bevelEnabled: false }).translate(0, 0, -0.01 * size);
    const h = new THREE.Mesh(g, MAT.steel); h.rotation.y = Math.PI / 2; const out = new THREE.Group().add(h);
    if (double) { const h2 = h.clone(); h2.rotation.y = -Math.PI / 2; out.add(h2); }
    return out;
  };
  switch (look.weapon) {
    case 'gladius': hilt(0.46 * s); break;
    case 'sword': hilt(0.72 * s); break;
    case 'dagger': hilt(0.24 * s); break;
    case 'axe': case 'bigaxe': case 'doubleaxe': {
      const big = look.weapon !== 'axe', L = (big ? 1.0 : 0.7) * s;
      const handle = new THREE.Mesh(new THREE.CylinderGeometry(0.02 * s, 0.024 * s, L, 7).translate(0, L * 0.32, 0), MAT.wood); w.add(handle);
      const head = axeHead((big ? 1.5 : 1) * s, look.weapon === 'doubleaxe'); head.position.y = L * 0.68; w.add(head);
      break;
    }
    case 'spear': {
      const L = 1.7 * s;
      const shaft = new THREE.Mesh(new THREE.CylinderGeometry(0.016 * s, 0.018 * s, L, 7).translate(0, L * 0.3, 0), MAT.wood); w.add(shaft);
      const tip = new THREE.Mesh(new THREE.ConeGeometry(0.035 * s, 0.2 * s, 6), MAT.steel); tip.position.y = L * 0.8 + 0.1 * s; w.add(tip);
      break;
    }
    case 'club': {
      const L = 0.85 * s;
      const c = new THREE.Mesh(new THREE.CylinderGeometry(0.075 * s, 0.03 * s, L, 7).translate(0, L * 0.4, 0), MAT.woodDark); w.add(c);
      for (let i = 0; i < 4; i++) { const k = new THREE.Mesh(new THREE.IcosahedronGeometry(0.035 * s, 0), MAT.wood); k.position.set(Math.cos(i * 1.6) * 0.07 * s, L * (0.55 + i * 0.08), Math.sin(i * 1.6) * 0.07 * s); w.add(k); }
      break;
    }
    case 'sling': {
      const cord = new THREE.Mesh(new THREE.CylinderGeometry(0.005 * s, 0.005 * s, 0.35 * s, 4).translate(0, -0.17 * s, 0), MAT.leather); w.add(cord);
      const stone = new THREE.Mesh(new THREE.IcosahedronGeometry(0.03 * s, 0), MAT.stone); stone.position.y = -0.35 * s; w.add(stone);
      break;
    }
  }
  if (w.children.length) attach(fig, 'hand_r', w, grip, [x, d, z]);

  // лук — в левой руке, тетива к груди
  if (look.weapon === 'bow') {
    const lh = P('hand_l'), lm = P('middle_01_l');
    const bow = new THREE.Group();
    const curve = new THREE.CatmullRomCurve3([V().set(0, -0.55, 0.05), V().set(0, -0.25, 0.12), V().set(0, 0, 0.14), V().set(0, 0.25, 0.12), V().set(0, 0.55, 0.05)].map(p => p.multiplyScalar(s)));
    bow.add(new THREE.Mesh(new THREE.TubeGeometry(curve, 16, 0.016 * s, 5), MAT.woodDark));
    const str = new THREE.Mesh(new THREE.CylinderGeometry(0.003 * s, 0.003 * s, 1.1 * s, 3), mat('#efe6d0')); str.position.z = 0.05 * s; bow.add(str);
    attach(fig, 'hand_l', bow, V().lerpVectors(lh, lm, 0.6), [fig.left, UP, fig.fwd]);
  }

  // щит на левом предплечье: рука держит его за рукоять за умбоном, лицом к врагу
  const sp = look.shield;
  if (sp) {
    const ha = P('hand_l'), grip2 = V().lerpVectors(ha, P('middle_01_l'), 0.6);
    const cen = V().copy(grip2).addScaledVector(fig.fwd, 0.085 * s);
    const sh = new THREE.Group();
    if (sp.type === 'scutum') {
      const Rr = 0.6 * s, T = 1.0, Hs = 1.0 * s;
      const face = new THREE.Mesh(new THREE.CylinderGeometry(Rr, Rr, Hs, 14, 1, true, -T / 2, T).translate(0, 0, -Rr), twoSided(mat(sp.color)));
      const back = new THREE.Mesh(new THREE.CylinderGeometry(Rr - 0.02 * s, Rr - 0.02 * s, Hs, 14, 1, true, -T / 2, T).translate(0, 0, -Rr), twoSided(MAT.leather));
      sh.add(face, back);
      for (const yy of [-0.5, 0.5]) {
        const rim = new THREE.Mesh(new THREE.CylinderGeometry(Rr + 0.006 * s, Rr + 0.006 * s, 0.035 * s, 14, 1, true, -T / 2, T).translate(0, 0, -Rr), twoSided(MAT.gold));
        rim.position.y = yy * Hs; sh.add(rim);
      }
      for (const sx of [-1, 1]) {
        const edge = new THREE.Mesh(new THREE.BoxGeometry(0.032 * s, Hs + 0.03 * s, 0.032 * s), MAT.gold);
        edge.position.set(sx * Math.sin(T / 2) * Rr, 0, Math.cos(T / 2) * Rr - Rr); edge.rotation.y = -sx * T / 2; sh.add(edge);
      }
      const boss = new THREE.Mesh(new THREE.SphereGeometry(0.075 * s, 12, 8, 0, Math.PI * 2, 0, Math.PI / 2), MAT.gold);
      boss.rotation.x = Math.PI / 2; sh.add(boss);
      const spine = new THREE.Mesh(new THREE.BoxGeometry(0.035 * s, Hs * 0.92, 0.016 * s), MAT.gold); spine.position.z = 0.006 * s; sh.add(spine);
      for (const sx of [-1, 1]) for (const sy of [-1, 1]) for (let k = 0; k < 3; k++) {
        const xx = sx * (0.1 + k * 0.055) * s, yy = sy * (0.135 + k * 0.03) * s;
        const seg = new THREE.Mesh(new THREE.BoxGeometry(0.075 * s, 0.024 * s, 0.012 * s), MAT.gold);
        seg.position.set(xx, yy, Math.sqrt(Rr * Rr - xx * xx) - Rr + 0.007 * s); seg.rotation.set(0, -Math.asin(xx / Rr), sy * sx * (0.25 + k * 0.12)); sh.add(seg);
      }
    } else {
      const rr = sp.r * s;
      const disc = new THREE.Mesh(new THREE.CylinderGeometry(rr, rr, 0.035 * s, 18), sp.rim || MAT.wood); disc.rotation.x = Math.PI / 2; sh.add(disc);
      const paint = new THREE.Mesh(new THREE.CylinderGeometry(rr * 0.8, rr * 0.8, 0.037 * s, 18), sp.metal ? MAT.bronze : mat(sp.color)); paint.rotation.x = Math.PI / 2; sh.add(paint);
      const boss = new THREE.Mesh(new THREE.SphereGeometry(0.07 * s, 10, 6, 0, Math.PI * 2, 0, Math.PI / 2), sp.metal ? MAT.gold : MAT.steelDark);
      boss.rotation.x = Math.PI / 2; boss.position.z = 0.018 * s; sh.add(boss);
    }
    attach(fig, 'lowerarm_l', sh, cen);
    fig.guardQ = fig.bone('upperarm_l').getWorldQuaternion(new THREE.Quaternion()).premultiply(fig.root.quaternion.clone().invert());
  }
  act.stop();
  fig.mixer.update(0);
}

/* ---------- Звери ---------- */
function addActions(rig, clips) {
  for (const c of clips) {
    const n = c.name.replace(/^.*\|/, '');
    if (!rig.actions[n]) rig.actions[n] = rig.mixer.clipAction(c);
  }
}

// Материал, который рисует только вершины, привязанные к костям головы (по весам скелета)
function headOnly(m, idx) {
  m.onBeforeCompile = sh => {
    sh.uniforms.uHead = { value: idx.concat(Array(16).fill(-9)).slice(0, 16) };
    sh.vertexShader = sh.vertexShader
      .replace('#include <common>', '#include <common>\nuniform float uHead[16];\nvarying float vHead;')
      .replace('#include <begin_vertex>', `#include <begin_vertex>
vHead = 0.0;
for (int i = 0; i < 16; i++) {
  float b = uHead[i];
  vHead += skinWeight.x * step(abs(skinIndex.x - b), 0.5) + skinWeight.y * step(abs(skinIndex.y - b), 0.5)
         + skinWeight.z * step(abs(skinIndex.z - b), 0.5) + skinWeight.w * step(abs(skinIndex.w - b), 0.5);
}`);
    sh.fragmentShader = sh.fragmentShader
      .replace('#include <common>', '#include <common>\nvarying float vHead;')
      .replace('void main() {', 'void main() {\n  if (vHead < 0.5) discard;');
  };
  m.customProgramCacheKey = () => 'civ-head-only';
  return m;
}

const BEAST_ANIM = { idle: ['Idle'], run: ['Gallop', 'Run'], walk: ['Walk'], attack: ['Attack', 'Attack_Headbutt', 'Headbutt'], attack2: ['Attack_Kick', 'Attack', 'Headbutt'],
  hit: ['Idle_HitReact_Left'], hit2: ['Idle_HitReact_Right', 'Idle_HitReact_Left'], death: ['Death'], win: ['Idle'] };
const BEAST_SRC = { wolf: wolfG, bull: bullG };
const BEAST_H = { wolf: 0.95, bull: 1.15 };
function makeBeast(key, look) {
  const g = BEAST_SRC[look.beast];
  const root = SkeletonUtils.clone(g.scene);
  root.updateMatrixWorld(true);
  g.scene.updateMatrixWorld(true);
  const box = new THREE.Box3().setFromObject(g.scene);
  const mats = [];
  const tint = look.tint;
  root.traverse(o => {
    if (!o.isMesh) return;
    o.castShadow = true; o.receiveShadow = true;
    o.material = [].concat(o.material).map(m => {
      const c = m.clone();
      if (tint && tint[m.name]) c.color.set(tint[m.name]);
      if (look.eyes && /Eye/i.test(m.name)) { c.color.set(look.eyes); c.emissive = new THREE.Color(look.eyes); c.emissiveIntensity = 2; }
      mats.push(c);
      return c;
    });
    if (o.material.length === 1) o.material = o.material[0];
  });
  const wrap = new THREE.Group();
  const k = (BEAST_H[look.beast] / (box.max.y - box.min.y)) * (look.scale || 1);
  root.scale.multiplyScalar(k);
  wrap.add(root);
  const fig = { root: wrap, inner: root, key, mats, kind: 'beast', mixer: new THREE.AnimationMixer(root), actions: {} };
  addActions(fig, g.animations);
  // Цербер: ещё две головы — копии волка, у которых видны только шея и голова
  if (look.heads > 1) {
    const h0 = box.max.y - box.min.y;
    fig.extra = [-1, 1].map(sx => {
      const r2 = SkeletonUtils.clone(g.scene);
      const idx = [];
      r2.traverse(o => { if (o.isSkinnedMesh) o.skeleton.bones.forEach((b, i) => { if (/^(Neck2|Neck3|Head|Ear)/.test(b.name)) idx.push(i); }); });
      r2.traverse(o => {
        if (!o.isMesh) return;
        o.castShadow = false;
        o.material = [].concat(o.material).map(m => { const c = headOnly(m.clone(), idx); if (tint && tint[m.name]) c.color.set(tint[m.name]); if (look.eyes && /Eye/i.test(m.name)) { c.color.set(look.eyes); c.emissive = new THREE.Color(look.eyes); c.emissiveIntensity = 2; } mats.push(c); return c; });
        if (o.material.length === 1) o.material = o.material[0];
      });
      r2.position.set(sx * h0 * 0.2, -h0 * 0.03, -h0 * 0.08);
      r2.rotation.y = sx * 0.4;
      r2.scale.setScalar(0.92);
      root.add(r2);
      const rig = { mixer: new THREE.AnimationMixer(r2), actions: {} };
      addActions(rig, g.animations);
      return rig;
    });
  }
  // у разных зверей движения названы по-разному: берём первое, что есть
  fig.anim = {};
  for (const [role, names] of Object.entries(BEAST_ANIM)) fig.anim[role] = names.find(n => fig.actions[n]) || null;
  return fig;
}

/* ---------- Медведь и кабан: гранёные звери из простых форм, лапы и голова двигаются кодом ----------
   Готовых зверей в нужном стиле нет: медведь из волчьего скелета выглядит волком, а кабан набора — кубиком. */
const BRUTES = {
  bear: { H: 1.25, main: '#5c3b24', light: '#7d5638', dark: '#33221a', nose: '#1e1612' },
  boar: { H: 0.85, main: '#4a3a30', light: '#8a6a5e', dark: '#2a201a', nose: '#b08a80' },
};
function makeBrute(key, look) {
  const P = Object.assign({}, BRUTES[look.brute], look.colors || {}), H = P.H;
  const M = { main: mat(P.main), light: mat(P.light), dark: mat(P.dark), nose: mat(P.nose), eye: look.eyes ? mat(look.eyes, { emissive: look.eyes, emissiveIntensity: 2 }) : mat('#141010'), tusk: MAT.bone };
  const blob = (r, sx, sy, sz, m, x, y, z, det) => { const o = new THREE.Mesh(new THREE.IcosahedronGeometry(r, det ?? 1), m); o.scale.set(sx, sy, sz); o.position.set(x, y, z); return o; };
  const inner = new THREE.Group(), body = new THREE.Group(), head = new THREE.Group();
  const legs = [];
  inner.add(body);
  const bear = look.brute === 'bear';
  if (bear) {
    body.add(blob(H, 0.37, 0.31, 0.56, M.main, 0, 0.55 * H, -0.04 * H));
    body.add(blob(H, 0.31, 0.27, 0.3, M.main, 0, 0.68 * H, 0.2 * H));           // загривок
    body.add(blob(H, 0.08, 0.08, 0.08, M.main, 0, 0.56 * H, -0.58 * H, 0));     // хвостик
    head.position.set(0, 0.66 * H, 0.5 * H);
    head.add(blob(H, 0.2, 0.18, 0.2, M.main, 0, 0, 0.05 * H));
    head.add(blob(H, 0.1, 0.085, 0.13, M.light, 0, -0.045 * H, 0.21 * H));
    head.add(blob(H, 0.04, 0.03, 0.03, M.nose, 0, -0.02 * H, 0.33 * H, 0));
    for (const sx of [-1, 1]) {
      head.add(blob(H, 0.06, 0.06, 0.035, M.main, sx * 0.13 * H, 0.15 * H, 0.0, 0));
      head.add(blob(H, 0.022, 0.022, 0.015, M.eye, sx * 0.08 * H, 0.05 * H, 0.2 * H, 0));
    }
  } else {
    body.add(blob(H, 0.27, 0.3, 0.52, M.main, 0, 0.55 * H, -0.02 * H));
    for (let i = 0; i < 6; i++) {                                               // щетина по хребту
      const c = new THREE.Mesh(new THREE.ConeGeometry(0.05 * H, 0.16 * H, 4), M.dark);
      c.position.set(0, (0.86 - i * 0.03) * H, (0.28 - i * 0.11) * H); c.rotation.x = -0.5;
      body.add(c);
    }
    const tail = new THREE.Mesh(new THREE.CylinderGeometry(0.012 * H, 0.012 * H, 0.2 * H, 4), M.dark);
    tail.position.set(0, 0.55 * H, -0.56 * H); tail.rotation.x = 0.5; body.add(tail);
    head.position.set(0, 0.62 * H, 0.42 * H);
    const snout = new THREE.Mesh(new THREE.CylinderGeometry(0.11 * H, 0.2 * H, 0.42 * H, 6), M.main);
    snout.rotation.x = Math.PI / 2 + 0.25; snout.position.set(0, -0.04 * H, 0.14 * H); head.add(snout);
    const disc = new THREE.Mesh(new THREE.CylinderGeometry(0.1 * H, 0.1 * H, 0.04 * H, 8), M.nose);
    disc.rotation.x = Math.PI / 2 + 0.25; disc.position.set(0, -0.09 * H, 0.35 * H); head.add(disc);
    for (const sx of [-1, 1]) {
      const tusk = new THREE.Mesh(new THREE.ConeGeometry(0.025 * H, 0.16 * H, 5), M.tusk);
      tusk.position.set(sx * 0.1 * H, -0.06 * H, 0.27 * H); tusk.rotation.set(-0.5, 0, -sx * 0.6); head.add(tusk);
      const ear = new THREE.Mesh(new THREE.ConeGeometry(0.06 * H, 0.14 * H, 4), M.dark);
      ear.position.set(sx * 0.12 * H, 0.14 * H, -0.06 * H); ear.rotation.set(-0.4, 0, -sx * 0.5); head.add(ear);
      head.add(blob(H, 0.022, 0.022, 0.015, M.eye, sx * 0.1 * H, 0.06 * H, 0.1 * H, 0));
    }
  }
  body.add(head);
  // лапы: шарнир у плеча, внизу — тёмная ступня
  const lw = bear ? 0.105 * H : 0.055 * H, ll = bear ? 0.4 * H : 0.4 * H;
  for (const [sx, sz] of [[-1, 1], [1, 1], [-1, -1], [1, -1]]) {
    const leg = new THREE.Group();
    leg.position.set(sx * (bear ? 0.2 : 0.14) * H, ll, sz * (bear ? 0.3 : 0.3) * H);
    const l = new THREE.Mesh(new THREE.CylinderGeometry(lw * 1.15, lw * 0.8, ll, 7).translate(0, -ll / 2, 0), M.main);
    const foot = blob(1, lw * 1.15, lw * 0.6, lw * 1.35, M.dark, 0, -ll + lw * 0.4, lw * 0.25, 0);
    leg.add(l, foot);
    inner.add(leg);
    legs.push(leg);
  }
  // склеиваем детали каждой части по материалу
  const bake = g => {
    const p = g.position.clone(), r = g.rotation.clone();
    g.parent.remove(g);
    g.position.set(0, 0, 0); g.rotation.set(0, 0, 0);
    const c = compact(g);
    c.position.copy(p); c.rotation.copy(r);
    return c;
  };
  const headC = bake(head);
  const bodyC = compact(body);
  body.clear(); body.add(bodyC, headC);
  const legsC = legs.map(leg => { const c = bake(leg); inner.add(c); return c; });
  const root = new THREE.Group().add(inner);
  root.traverse(o => { if (o.isMesh) { o.castShadow = true; o.receiveShadow = true; } });
  const mats = [];
  const own = new Map();
  root.traverse(o => {
    if (!o.isMesh) return;
    if (!own.has(o.material)) { const c = o.material.clone(); own.set(o.material, c); mats.push(c); }
    o.material = own.get(o.material);
  });
  if (look.scale) inner.scale.setScalar(look.scale);
  return { root, inner, body, head: headC, legs: legsC, key, mats, kind: 'brute', H, headY: headC.position.y, actions: {} };
}

// Движения гранёного зверя: шаг диагональными парами, рывок головой, падение на бок
function animateBrute(f, v, u, dt, t) {
  const H = f.H;
  if (!u.alive) {
    const k = Math.min(1, v.dead / 0.5);
    f.inner.rotation.z = k * 1.45;
    f.inner.position.y = k * 0.18 * H;
    for (const l of f.legs) l.rotation.x *= 0.9;
    return;
  }
  if (u.moving) v.ph = (v.ph || 0) + dt * (u.speed || 1.6) * (f.key === 'boar' ? 7 : 5);
  const sw = u.moving ? Math.sin(v.ph) * 0.55 : 0;
  f.legs[0].rotation.x = sw; f.legs[3].rotation.x = sw;
  f.legs[1].rotation.x = -sw; f.legs[2].rotation.x = -sw;
  const breathe = Math.sin(t * 2.2 + (v.seed ??= Math.random() * 6));
  f.body.position.y = u.moving ? Math.abs(Math.cos(v.ph)) * 0.05 * H : breathe * 0.006 * H;
  const atk = u.attackT > 0 ? 1 - u.attackT / 0.35 : -1;
  const lunge = atk >= 0 ? Math.sin(atk * Math.PI) : 0;
  f.body.position.z = lunge * 0.14 * H;
  f.body.rotation.x = -lunge * 0.12 + (u.hitT > 0.15 ? 0.06 : 0);
  f.head.rotation.x = atk >= 0 ? -lunge * 0.5 : breathe * 0.04;
  f.head.position.y = f.headY + (u.moving ? Math.sin(v.ph * 2) * 0.02 * H : 0);
}

/* ---------- Машины и слон: неподвижные модели набора, движение — покачиванием ---------- */
function makeProp(key, look) {
  const geo = Look2.propGeometry(look.prop);
  const m = Look2.props.meta.models[look.prop];
  geo.computeVertexNormals();
  const material = new THREE.MeshLambertMaterial({ vertexColors: true, flatShading: true });
  const mesh = new THREE.Mesh(geo.toNonIndexed(), material);
  mesh.geometry.userData.own = true;
  const h = m.max[1] - m.min[1];
  const k = look.h / h;
  mesh.scale.setScalar(k);
  mesh.position.set(-(m.min[0] + m.max[0]) / 2 * k, -m.min[1] * k, -(m.min[2] + m.max[2]) / 2 * k);
  mesh.castShadow = true; mesh.receiveShadow = true;
  // у моделей набора перед смотрит куда придётся — разворачиваем передом к врагу (+z)
  const turn = new THREE.Group().add(mesh);
  turn.rotation.y = look.yaw || 0;
  const inner = new THREE.Group().add(turn);
  const root = new THREE.Group().add(inner);
  return { root, inner, key, mats: [material], kind: key === 'elephant' ? 'heavy' : 'siege', actions: {} };
}

/* ---------- Фигура по ключу бойца ---------- */
export function makeUnit(key) {
  const look = LOOKS[key];
  if (!look) return null;
  let fig;
  if (look.prop) fig = makeProp(key, look);
  else if (look.brute) fig = makeBrute(key, look);
  else if (look.beast) fig = makeBeast(key, look);
  else {
    fig = makeHuman(key, look);
    // тело обёрнуто в группу: масштаб к росту поля боя
    const wrap = new THREE.Group();
    fig.root.scale.setScalar(HUMAN_H / 1.81);
    wrap.add(fig.root);
    fig.inner = fig.root;
    fig.root = wrap;
  }
  for (const m of fig.mats) { m.emissive = m.emissive || new THREE.Color(0); fig.baseEmissive = fig.baseEmissive || []; fig.baseEmissive.push(m.emissive.clone()); }
  fig.real = true;
  fig.h = look.prop ? look.h : look.brute ? BRUTES[look.brute].H * (look.scale || 1) : look.beast ? BEAST_H[look.beast] * (look.scale || 1) : HUMAN_H;
  fig.look = look;
  fig.cur = null;
  fig.ranged = ['bow', 'sling', 'none'].includes(look.weapon);
  return fig;
}

/* ---------- Движения по состоянию бойца ---------- */
const HUMAN_ANIM = { idle: 'Sword_Idle', idleRanged: 'Idle_Loop', run: 'Jog_Fwd_Loop', walk: 'Walk_Loop', attack: 'Sword_Attack', attack2: 'Punch_Cross', shoot: 'Spell_Simple_Shoot', hit: 'Hit_Chest', hit2: 'Hit_Head', death: 'Death01', win: 'Idle_Loop' };

function play(fig, name, opts) {
  const a = playRig(fig, name, opts);
  if (a && fig.extra) for (const e of fig.extra) playRig(e, name, opts);
  if (a && fig.guard && name === 'Death01') fig.guard.fadeOut(0.12);
  return a;
}

function tick(fig, dt) {
  if (!fig.mixer) return;
  fig.mixer.update(dt);
  if (fig.extra) for (const e of fig.extra) e.mixer.update(dt);
  if (fig.guardQ) lockGuard(fig);
}

function playRig(fig, name, { once = false, fade = 0.18, speed = 1 } = {}) {
  const a = name && fig.actions[name];
  if (!a) return null;
  if (fig.cur === a && !once) { a.timeScale = speed; return a; }
  a.reset();
  a.setLoop(once ? THREE.LoopOnce : THREE.LoopRepeat, Infinity);
  a.clampWhenFinished = once;
  a.timeScale = speed;
  a.enabled = true;
  if (fig.cur && fig.cur !== a) a.crossFadeFrom(fig.cur, fade, false);
  a.play();
  fig.cur = a;
  return a;
}

const _q1 = new THREE.Quaternion(), _q2 = new THREE.Quaternion();
function lockGuard(fig) {
  if (!fig.guardQ || fig.cur === fig.actions.Death01) return;
  const b = fig.bone('upperarm_l');
  b.parent.updateWorldMatrix(true, false);
  b.parent.getWorldQuaternion(_q1).invert();
  _q2.copy(fig.inner.getWorldQuaternion(new THREE.Quaternion())).multiply(fig.guardQ);
  b.quaternion.slerp(_q1.multiply(_q2), 0.85);
}

// Каждый кадр: выбрать движение по состоянию из BattleSim и проиграть его
export function animate(v, dt, sim) {
  const u = v.u, f = v.fig;
  const A = f.kind === 'beast' ? f.anim : HUMAN_ANIM;
  if (!u.alive) {
    if (!v.deadStarted) {
      v.deadStarted = true;
      if (v.flash) { v.flash = false; f.mats.forEach((m, i) => { if (m.emissive) m.emissive.copy(f.baseEmissive[i]); }); }
      if (f.kind === 'human' || f.kind === 'beast') play(f, A.death, { once: true, fade: 0.12 });
    }
    v.dead += dt;
    if (f.kind === 'brute') animateBrute(f, v, u, dt, sim.t);
    if (f.kind === 'siege' || f.kind === 'heavy') { f.inner.rotation.z = Math.min(1, v.dead / 0.6) * (f.kind === 'heavy' ? 1.3 : 0.25); }
    if (v.dead > 1.6) {
      for (const m of f.mats) { m.transparent = true; m.opacity = Math.max(0, 1 - (v.dead - 1.6) / 1.2) * (f.look.ghost ? 0.82 : 1); }
      f.root.position.y -= dt * 0.25;
      if (v.dead > 2.8) f.root.visible = false;
    }
    tick(f, dt);
    return;
  }
  const t = sim.t;
  // поворот: к цели, но всегда вполоборота к зрителю — чтобы видно было лица, а не спины
  let dir = u.side === 'ally' ? 1 : -1, tilt = 0;
  if (u.target && u.target.alive) {
    const dx = u.target.x - u.x, dz = u.target.z - u.z;
    if (Math.abs(dx) > 0.05) dir = Math.sign(dx);
    tilt = Math.max(-0.35, Math.min(0.6, Math.atan2(dz, Math.abs(dx) + 0.3)));
  }
  const th = tilt + 0.38;
  const want = Math.atan2(dir * Math.cos(th), Math.sin(th));
  let dy = want - (v.yaw ?? want); dy = Math.atan2(Math.sin(dy), Math.cos(dy));
  v.yaw = (v.yaw ?? want) + dy * Math.min(1, dt * 8);
  f.root.position.set(u.x, 0, u.z);
  f.root.rotation.y = v.yaw;
  // выбор движения
  const fast = u.horn > t ? 1.35 : 1;
  if (u.attackT > (v.lastAtk || 0)) {
    // удар начался: взмах один раз
    const name = f.kind === 'human' ? (f.ranged || u.shot ? A.shoot : (Math.random() < 0.3 ? A.attack2 : A.attack)) : (Math.random() < 0.5 ? A.attack : A.attack2);
    const a = play(f, name, { once: true, fade: 0.08, speed: 1.6 * fast });
    v.busy = a ? a.getClip().duration / (1.6 * fast) * 0.8 : 0.3;
    if (f.kind === 'siege') v.recoil = 1;
  }
  v.lastAtk = u.attackT;
  if (u.hitT > (v.lastHit || 0) && (v.busy || 0) <= 0) {
    play(f, Math.random() < 0.5 ? A.hit : A.hit2, { once: true, fade: 0.06, speed: 1.4 });
    v.busy = 0.35;
  }
  v.lastHit = u.hitT;
  v.busy = (v.busy || 0) - dt;
  if (v.busy <= 0 && f.actions && f.kind !== 'siege' && f.kind !== 'heavy' && f.kind !== 'brute') {
    if (u.moving) {
      const sp = (u.speed || 1.5) * fast;
      play(f, sp > 1.25 || f.kind === 'beast' ? A.run : A.walk, { speed: f.kind === 'beast' ? 0.6 + sp * 0.15 : 0.55 + sp * 0.18 });
    } else if (sim.result && sim.result.win && u.side === 'ally') play(f, A.win, { fade: 0.4 });
    else play(f, f.ranged || u.shot ? (A.idleRanged || A.idle) : A.idle, { fade: 0.25 });
  }
  if (f.kind === 'brute') animateBrute(f, v, u, dt, t);
  // слон и машины: покачивание на ходу, отдача при выстреле, рывок при ударе
  else if (f.kind === 'heavy') {
    v.ph = (v.ph || 0) + dt * (u.moving ? 5 : 1.2);
    f.inner.position.y = Math.abs(Math.sin(v.ph)) * (u.moving ? 0.08 : 0.02);
    f.inner.rotation.z = Math.sin(v.ph) * (u.moving ? 0.04 : 0.01);
    f.inner.rotation.x = u.attackT > 0 ? -Math.sin((1 - u.attackT / 0.35) * Math.PI) * 0.25 : 0;
  } else if (f.kind === 'siege') {
    v.recoil = Math.max(0, (v.recoil || 0) - dt * 2.5);
    f.inner.position.z = -v.recoil * 0.15;
    f.inner.rotation.x = -v.recoil * 0.08;
  }
  // вспышка при попадании
  const hit = Math.max(0, u.hitT - 0.15) * 10;
  if (hit > 0 || v.flash) {
    v.flash = hit > 0;
    f.mats.forEach((m, i) => { if (m.emissive) m.emissive.copy(f.baseEmissive[i]).add(_c.setRGB(hit * 0.16, hit * 0.04, hit * 0.02)); });
  }
  tick(f, dt);
}
const _c = new THREE.Color();

/* ---------- Портреты для меню ---------- */
const portraitCache = {};
let pr = null;
export function portrait(key) {
  if (portraitCache[key]) return portraitCache[key];
  const fig = makeUnit(key);
  if (!fig) return null;
  if (!pr) {
    const canvas = document.createElement('canvas');
    pr = { r: new THREE.WebGLRenderer({ canvas, antialias: true, alpha: true, preserveDrawingBuffer: true }), scene: new THREE.Scene(), cam: new THREE.PerspectiveCamera(26, 1, 0.05, 50) };
    pr.r.setSize(192, 192, false); pr.r.setPixelRatio(1);
    pr.r.outputColorSpace = THREE.SRGBColorSpace; pr.r.toneMapping = THREE.ACESFilmicToneMapping; pr.r.setClearColor(0x000000, 0);
    pr.scene.add(new THREE.HemisphereLight('#fff6e6', '#8d9a70', 1.6));
    const sun = new THREE.DirectionalLight('#fff0d6', 2.4); sun.position.set(3, 5, 6); pr.scene.add(sun);
  }
  const root = fig.root;
  root.rotation.y = 0.55;
  if (fig.kind === 'human') { play(fig, fig.ranged ? 'Idle_Loop' : 'Sword_Idle'); tick(fig, 0.5); }
  else if (fig.kind === 'beast') { play(fig, fig.anim.idle); tick(fig, 0.3); }
  pr.scene.add(root);
  root.updateMatrixWorld(true);
  // человека берём по колено — так видно лицо и снаряжение; зверей и машины — целиком
  let c, r;
  if (fig.kind === 'human') { c = V().set(0, HUMAN_H * 0.66, 0); r = HUMAN_H * 0.4; }
  else {
    const box = new THREE.Box3().setFromObject(root), size = box.getSize(V());
    c = box.getCenter(V());
    r = Math.max(size.y, size.x * 0.8, size.z * 0.8) * 0.56;
  }
  const dist = r / Math.tan(THREE.MathUtils.degToRad(13));
  pr.cam.position.set(c.x + dist * 0.2, c.y + dist * 0.14, c.z + dist * 0.97);
  pr.cam.lookAt(c.x, c.y, c.z);
  pr.r.render(pr.scene, pr.cam);
  portraitCache[key] = pr.r.domElement.toDataURL('image/png');
  pr.scene.remove(root);
  dispose(fig);
  return portraitCache[key];
}

// После боя: освободить то, что фигура создала сама (общие тела и текстуры остаются)
export function dispose(fig) {
  fig.root.traverse(o => { if (o.geometry && o.geometry.userData.own) o.geometry.dispose(); });
  for (const m of fig.mats) m.dispose();
  if (fig.mixer) fig.mixer.stopAllAction();
}

export const KEYS = Object.keys(LOOKS);
window.Battle3D = { ready: true, makeUnit, animate, portrait, dispose, KEYS };
