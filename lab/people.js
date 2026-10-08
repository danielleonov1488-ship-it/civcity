// Люди CivCity: бесплатные тела и анимации Quaternius (CC0), одежда рисуется прямо на теле,
// снаряжение строится кодом и крепится к костям. Общий модуль для всех проверочных сцен.
import * as THREE from 'three';
import { GLTFLoader } from '../vendor/three-module/examples/jsm/loaders/GLTFLoader.js';
import * as SkeletonUtils from '../vendor/three-module/examples/jsm/utils/SkeletonUtils.js';

const BODY_DIR = '../assets/incoming/universal-base-characters/unpacked/Universal Base Characters[Standard]/Base Characters/Godot - UE/';
const BODY = encodeURI(BODY_DIR + 'Superhero_Male_FullBody.gltf'), BODY_F = encodeURI(BODY_DIR + 'Superhero_Female_FullBody.gltf');
const ANIMS = encodeURI('../assets/incoming/universal-animation-library/unpacked/Universal Animation Library[Standard]/Unreal-Godot/UAL1_Standard.glb');
const flat = (color, o) => new THREE.MeshStandardMaterial(Object.assign({ color, roughness: 0.9, metalness: 0, flatShading: true }, o || {}));
let scene = null;
export function setScene(s) { scene = s; }
/* ---------- Загрузка ---------- */
const loader = new GLTFLoader();
const load = url => new Promise((res, rej) => loader.load(url, res, undefined, rej));

const [body, bodyF, animGltf] = await Promise.all([load(BODY), load(BODY_F), load(ANIMS)]);

// Щитоносцы: левая рука всегда держит щит перед собой (поза из Sword_Idle), остальное тело играет любое движение
const LEFT_ARM = /^(clavicle_l|upperarm_l|lowerarm_l|hand_l|(index|middle|pinky|ring|thumb)_\d+(_leaf)?_l)\./;
// Анимации под каждое тело: оставляем повороты костей, сдвиг таза пересчитываем под его пропорции
function clipSet(bodyScene) {
  const bp = bodyScene.getObjectByName('pelvis'), ap = animGltf.scene.getObjectByName('pelvis');
  const k = bp && ap ? bp.position.length() / Math.max(1e-6, ap.position.length()) : 1;
  const all = {}, noLeft = {};
  for (const clip of animGltf.animations) {
    const c = clip.clone();
    c.tracks = c.tracks.filter(t => t.name.endsWith('.quaternion') || t.name === 'pelvis.position');
    for (const t of c.tracks) if (t.name === 'pelvis.position') { t.values = t.values.slice(); for (let i = 0; i < t.values.length; i++) t.values[i] *= k; }
    all[clip.name] = c;
    const n = c.clone(); n.tracks = n.tracks.filter(t => !LEFT_ARM.test(t.name)); noLeft[clip.name] = n;
  }
  const guard = all.Sword_Idle.clone();
  guard.name = 'Guard';
  guard.tracks = guard.tracks.filter(t => LEFT_ARM.test(t.name));
  return { all, noLeft, guard };
}
const SETS = { m: clipSet(body.scene), f: clipSet(bodyF.scene) };
const BODIES = { m: body, f: bodyF };
const CLIPS = SETS.m.all;

/* ---------- Сборка бойца ---------- */
const V = () => new THREE.Vector3();
const UP = new THREE.Vector3(0, 1, 0);

// Волосы и борода из того же набора (CC0): стоят на голове, когда тело в начале координат
const HAIR_DIR = '../assets/incoming/universal-base-characters/unpacked/Universal Base Characters[Standard]/Hairstyles/Origin at 0/glTF (Godot)/';
const HAIR = {};
await Promise.all(['Hair_Buzzed', 'Hair_Long', 'Hair_Beard', 'Hair_SimpleParted', 'Hair_Buns', 'Eyebrows_Regular', 'Eyebrows_Female'].map(n => load(encodeURI(HAIR_DIR + n + '.gltf')).then(g => { HAIR[n] = g.scene; })));

// Исходная поза каждой вершины тела: по ней «рисуем» одежду прямо на коже, и ткань гнётся вместе с телом
function prepareRest(mesh) {
  const g = mesh.geometry;
  if (g.attributes.rest) return;
  const n = g.attributes.position.count, arr = new Float32Array(n * 3), v = V();
  for (let i = 0; i < n; i++) { mesh.getVertexPosition(i, v); arr[i * 3] = v.x; arr[i * 3 + 1] = v.y; arr[i * 3 + 2] = v.z; }
  g.setAttribute('rest', new THREE.BufferAttribute(arr, 3));
}

// Покраска тела: туника (верх и рукава), штаны (с клеткой или обмотками), обувь, кайма
function paintBody(mesh, o) {
  const C = c => new THREE.Color(c || '#000');
  const U = {
    uTop: { value: C(o.top) }, uTopOn: { value: o.top ? 1 : 0 }, uTopBot: { value: o.topBottom ?? 0.8 }, uSleeve: { value: o.sleeve ?? 0.34 }, uNeck: { value: o.neck ?? 1.49 },
    uLeg: { value: C(o.leg) }, uLegOn: { value: o.leg ? 1 : 0 }, uLegTop: { value: o.legTop ?? 1.02 },
    uFoot: { value: C(o.foot) }, uFootOn: { value: o.foot ? 1 : 0 }, uFootTop: { value: o.footTop ?? 0.14 },
    uWrap: { value: C(o.wrap) }, uWrapOn: { value: o.wrap ? 1 : 0 }, uWrapTop: { value: o.wrapTop ?? 0.48 },
    uTrim: { value: C(o.trim) }, uTrimOn: { value: o.trim ? 1 : 0 }, uPlaid: { value: o.plaid ? 1 : 0 }, uK: { value: o.k || 1 },
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
uniform vec3 uTop, uLeg, uFoot, uWrap, uTrim;
uniform float uTopOn, uTopBot, uSleeve, uNeck, uLegOn, uLegTop, uFootOn, uFootTop, uWrapOn, uWrapTop, uTrimOn, uPlaid, uK;`)
      .replace('#include <map_fragment>', `#include <map_fragment>
{
  vec3 p = vRest; p.y /= uK; float ax = abs(p.x);
  float lum = dot(diffuseColor.rgb, vec3(0.2126, 0.7152, 0.0722));
  float sh = clamp(0.62 + lum * 1.1, 0.72, 1.12);
  float neck = uNeck + 0.06 * smoothstep(0.065, 0.1, ax) - 0.045 * step(0.02, p.z) * (1.0 - smoothstep(0.0, 0.07, ax));
  float top = uTopOn * step(ax, uSleeve) * step(uTopBot, p.y) * step(p.y, neck);
  float leg = uLegOn * step(ax, 0.3) * step(p.y, uLegTop) * step(uFootTop, p.y);
  float foot = uFootOn * step(ax, 0.3) * step(p.y, uFootTop);
  vec3 legC = uLeg;
  if (uPlaid > 0.5) { float a = step(0.5, fract((p.x + p.z) * 9.0)); float b = step(0.5, fract(p.y * 9.0)); legC *= 0.72 + 0.2 * (a + b); }
  if (uWrapOn > 0.5 && p.y < uWrapTop) legC = uWrap * (0.8 + 0.25 * step(0.5, fract(p.y * 26.0 + (p.x + p.z) * 3.0)));
  vec3 c = diffuseColor.rgb;
  c = mix(c, uTop * sh, top);
  c = mix(c, legC * sh, leg);
  c = mix(c, uFoot * sh, foot);
  float trim = uTrimOn * top * clamp(step(uSleeve - 0.02, ax) * step(0.24, ax) + step(p.y, uTopBot + 0.022), 0.0, 1.0);
  diffuseColor.rgb = mix(c, uTrim * sh, trim);
}`);
  };
  mat.customProgramCacheKey = () => 'civ-paint';
}

function addHair(fig, name, color) {
  const src = HAIR[name];
  if (!src) return;
  src.traverse(o => {
    if (!o.isMesh) return;
    const m = new THREE.Mesh(o.geometry, o.material.clone());
    m.material.color.set(color);
    o.updateWorldMatrix(true, false);
    m.matrix.copy(o.matrixWorld).decompose(m.position, m.quaternion, m.scale);
    scene.add(m);
    m.updateMatrixWorld(true);
    fig.bone('Head').attach(m);
    m.castShadow = true;
  });
}

const LOOKS = {
  legionary: { paint: { top: '#b3302a', sleeve: 0.33, topBottom: 0.79, trim: '#e2b850', foot: '#5a3a22', footTop: 0.11 }, hair: [['Hair_Buzzed', '#3b2a1e'], ['Eyebrows_Regular', '#3b2a1e']] },
  barbarian: { paint: { leg: '#6b5a3e', wrap: '#8a7652', foot: '#4a3020', footTop: 0.16 }, hair: [['Hair_Long', '#b8642e'], ['Hair_Beard', '#a8582a'], ['Eyebrows_Regular', '#a8582a']] },
  barbarian2: { paint: { leg: '#3f6b4a', plaid: 1, foot: '#4a3020', footTop: 0.16 }, hair: [['Hair_Long', '#e3b062'], ['Hair_Beard', '#d29e52'], ['Eyebrows_Regular', '#c08c48']] },
};

function makeFighter(kind) { return makePerson(Object.assign({ kind }, LOOKS[kind])); }

// Любой житель или боец по описанию: тело (m/f), раскраска одежды, причёска, юбка, роль
function makePerson(look) {
  const kind = look.kind || 'citizen', sex = look.body || 'm';
  const root = SkeletonUtils.clone(BODIES[sex].scene);
  scene.add(root);
  root.updateMatrixWorld(true);
  const h0 = new THREE.Box3().setFromObject(root).max.y;
  root.traverse(o => {
    if (!o.isMesh) return;
    o.castShadow = true; o.receiveShadow = true;
    o.material = o.material.clone();
    const n = o.material.name || '';
    if (/Hair/i.test(n)) o.visible = false;                 // брови ставим свои, цветные
    if (o.isSkinnedMesh && /Superhero/i.test(n)) { prepareRest(o); paintBody(o, Object.assign({ k: h0 / 1.81 }, look.paint)); }
  });
  const bone = n => root.getObjectByName(n);
  const P = n => bone(n).getWorldPosition(V());
  // рост и направление «вперёд» в исходной позе
  const box = new THREE.Box3().setFromObject(root);
  const s = (box.max.y - box.min.y) / 1.8;
  const fwd = P('ball_r').sub(P('foot_r')).setY(0).normalize();
  const left = V().crossVectors(UP, fwd).normalize();
  const fig = { root, kind, sex, bone, P, s, fwd, left, top: box.max.y };
  fig.yaw0 = Math.atan2(fwd.x, fwd.z);
  for (const [n, c] of look.hair || []) addHair(fig, n, c);
  fig.mixer = new THREE.AnimationMixer(root);
  fig.actions = {};
  fig.shield = look.shield ?? (kind === 'legionary' || kind === 'barbarian');
  const set = SETS[sex];
  for (const [name, clip] of Object.entries(set.all)) fig.actions[name] = fig.mixer.clipAction(fig.shield && name !== 'Death01' ? set.noLeft[name] : clip);
  if (fig.shield) { fig.guard = fig.mixer.clipAction(set.guard); fig.guard.play(); }
  if (kind === 'legionary') dressLegionary(fig);
  else if (kind === 'barbarian' || kind === 'barbarian2') dressBarbarian(fig);
  else dressCitizen(fig, look);
  return fig;
}

// Поставить деталь в мировые координаты (оси: x — влево, y — вверх, z — вперёд) и прикрепить к кости
function attach(fig, boneName, obj, pos, axes) {
  const m = new THREE.Matrix4().makeBasis(axes ? axes[0] : fig.left, axes ? axes[1] : UP, axes ? axes[2] : fig.fwd);
  obj.quaternion.setFromRotationMatrix(m);
  obj.position.copy(pos);
  scene.add(obj);
  obj.updateMatrixWorld(true);
  fig.bone(boneName).attach(obj);
  obj.traverse(o => { if (o.isMesh) { o.castShadow = true; o.receiveShadow = true; } });
  return obj;
}

const MAT = {
  steel: new THREE.MeshStandardMaterial({ color: '#c3c8cf', metalness: 0.75, roughness: 0.32, flatShading: true }),
  steelDark: new THREE.MeshStandardMaterial({ color: '#8f969f', metalness: 0.7, roughness: 0.4, flatShading: true }),
  bronze: new THREE.MeshStandardMaterial({ color: '#c99a45', metalness: 0.8, roughness: 0.3, flatShading: true }),
  gold: new THREE.MeshStandardMaterial({ color: '#e7bb4c', metalness: 0.85, roughness: 0.25, flatShading: true }),
  red: flat('#b3302a', { roughness: 0.75 }),
  redDark: flat('#8e2620', { roughness: 0.8 }),
  leather: flat('#7a4f2e'), leatherDark: flat('#4e3320'),
  wood: flat('#8a5e38'), woodDark: flat('#5e3e24'),
  fur: flat('#8a7a64'), furLight: flat('#a8977c'), furDark: flat('#5e5040'),
  shieldGreen: flat('#4d7a3a'), shieldBlue: flat('#3e5f8a'),
};
const twoSided = m => { const c = m.clone(); c.side = THREE.DoubleSide; return c; };

/* ---------- Легионер: шлем-галея, лорика, туника, калиги, плащ; щит и гладиус ---------- */
function dressLegionary(fig) {
  const { s, P } = fig;
  const shoulderW = P('upperarm_l').distanceTo(P('upperarm_r'));
  const a = shoulderW * 0.45, b = a * 0.72;

  // Шлем: купол, бронзовый обод и козырёк, назатыльник, нащёчники, красный гребень
  const H = P('Head'), r = 0.108 * s;
  const helm = new THREE.Group();
  const dome = new THREE.Mesh(new THREE.SphereGeometry(r, 16, 9, 0, Math.PI * 2, 0, Math.PI * 0.6), MAT.steel);
  dome.scale.set(1.0, 1.0, 1.12); helm.add(dome);
  const band = new THREE.Mesh(new THREE.TorusGeometry(r * 0.99, r * 0.075, 6, 20), MAT.bronze);
  band.rotation.x = Math.PI / 2; band.position.y = -r * 0.2; band.scale.set(1, 1.12, 1); helm.add(band);
  const visor = new THREE.Mesh(new THREE.BoxGeometry(r * 1.4, r * 0.1, r * 0.32), MAT.bronze);
  visor.position.set(0, -r * 0.24, r * 1.1); visor.rotation.x = 0.3; helm.add(visor);
  const nape = new THREE.Mesh(new THREE.BoxGeometry(r * 1.8, r * 0.1, r * 0.8), MAT.steel);
  nape.position.set(0, -r * 0.48, -r * 1.12); nape.rotation.x = -0.5; helm.add(nape);
  for (const sx of [-1, 1]) {
    const cheek = new THREE.Mesh(new THREE.BoxGeometry(r * 0.1, r * 0.72, r * 0.62), MAT.steel);
    cheek.position.set(sx * r * 0.97, -r * 0.62, r * 0.3); cheek.rotation.z = sx * 0.08; helm.add(cheek);
    const stud = new THREE.Mesh(new THREE.SphereGeometry(r * 0.09, 6, 4), MAT.bronze);
    stud.position.set(sx * r * 1.03, -r * 0.55, r * 0.32); helm.add(stud);
  }
  const crest = new THREE.Group();
  for (let i = 0; i <= 12; i++) {
    const ang = -Math.PI / 2 + i / 12 * Math.PI, rr = r * 1.18;
    const tuft = new THREE.Mesh(new THREE.BoxGeometry(r * 0.32, r * 0.5, r * 0.32), i % 2 ? MAT.red : MAT.redDark);
    tuft.position.set(0, Math.cos(ang) * rr * 0.98, Math.sin(ang) * rr * 1.1);
    tuft.rotation.x = ang; crest.add(tuft);
  }
  crest.position.y = r * 0.05; helm.add(crest);
  const holder = new THREE.Mesh(new THREE.CylinderGeometry(r * 0.12, r * 0.16, r * 0.25, 6), MAT.bronze);
  holder.position.y = r * 1.08; helm.add(holder);
  attach(fig, 'Head', helm, V().copy(H).addScaledVector(UP, 0.145 * s).addScaledVector(fig.fwd, 0.002 * s));

  // Лорика сегментата: полосы от пояса до груди, сверху наплечная часть, наплечники
  const waist = P('spine_01'), chest = P('spine_03'), neck = P('neck_01');
  const y0 = waist.y - 0.03 * s, y1 = chest.y + 0.07 * s, n = 5;
  for (let i = 0; i < n; i++) {
    const t = i / (n - 1), h = (y1 - y0) / n;
    const k = 0.96 + t * 0.16;
    const c = V().lerpVectors(waist, chest, t); c.y = y0 + h * (i + 0.5);
    const m = new THREE.Mesh(new THREE.CylinderGeometry(1, 0.97, h * 0.94, 18), i % 2 ? MAT.steel : MAT.steelDark);
    m.scale.set(a * k, 1, b * k);
    attach(fig, i < 2 ? 'spine_01' : i < 4 ? 'spine_02' : 'spine_03', new THREE.Group().add(m), c.addScaledVector(fig.fwd, 0.012 * s));
  }
  // наплечная часть: пояс сферы от шеи до груди
  const yokeH = neck.y - y1 + 0.03 * s;
  const yoke = new THREE.Mesh(new THREE.SphereGeometry(1, 20, 8, 0, Math.PI * 2, Math.PI * 0.17, Math.PI * 0.33), MAT.steel);
  yoke.scale.set(a * 1.13, yokeH * 1.0, b * 1.2);
  attach(fig, 'spine_03', new THREE.Group().add(yoke), V(0, 0, 0).copy(chest).setY(y1 - yokeH * 0.12).addScaledVector(fig.fwd, 0.012 * s));
  for (const side of ['l', 'r']) {
    const sh = P('upperarm_' + side), out = V().subVectors(sh, chest).setY(0).normalize();
    const cap = new THREE.Group();
    for (let i = 0; i < 3; i++) {
      const m = new THREE.Mesh(new THREE.SphereGeometry(0.1 * s, 12, 5, 0, Math.PI * 2, 0, Math.PI * 0.5), i % 2 ? MAT.steelDark : MAT.steel);
      m.scale.set(1.0, 0.6, 1.05); m.position.y = -i * 0.032 * s; m.position.x = (side === 'l' ? 1 : -1) * i * 0.01 * s; cap.add(m);
    }
    attach(fig, 'upperarm_' + side, cap, V().copy(sh).addScaledVector(UP, 0.03 * s).addScaledVector(out, 0.03 * s));
  }
  // Пояс с бронзовыми бляхами и юбка туники с кожаными полосками (птеруги)
  const pel = P('pelvis');
  const belt = new THREE.Mesh(new THREE.TorusGeometry(1, 0.075, 6, 22), MAT.leather);
  belt.rotation.x = Math.PI / 2; belt.scale.set(a * 0.98, b * 1.02, 0.55);
  attach(fig, 'spine_01', new THREE.Group().add(belt), V().copy(waist).setY(y0 - 0.005 * s));
  for (let i = -2; i <= 2; i++) {
    const plate = new THREE.Mesh(new THREE.BoxGeometry(0.035 * s, 0.035 * s, 0.01 * s), MAT.bronze);
    const ang = i * 0.32;
    attach(fig, 'spine_01', plate, V().copy(waist).setY(y0 - 0.005 * s).addScaledVector(fig.left, Math.sin(ang) * a * 1.0).addScaledVector(fig.fwd, Math.cos(ang) * b * 1.06), [V().copy(fig.left).multiplyScalar(Math.cos(ang)).addScaledVector(fig.fwd, -Math.sin(ang)), UP, V().copy(fig.fwd).multiplyScalar(Math.cos(ang)).addScaledVector(fig.left, Math.sin(ang))]);
  }
  const skirt = new THREE.Mesh(new THREE.CylinderGeometry(a * 0.94, a * 1.22, 0.24 * s, 20, 1, true), twoSided(MAT.red));
  skirt.scale.z = 0.8;
  attach(fig, 'pelvis', new THREE.Group().add(skirt), V().copy(pel).addScaledVector(UP, -0.1 * s));
  const hem = new THREE.Mesh(new THREE.TorusGeometry(1, 0.035, 4, 24), MAT.gold);
  hem.rotation.x = Math.PI / 2; hem.scale.set(a * 1.22, a * 1.22 * 0.8, 0.5);
  attach(fig, 'pelvis', new THREE.Group().add(hem), V().copy(pel).addScaledVector(UP, -0.22 * s));
  for (let i = 0; i < 4; i++) {
    const strip = new THREE.Mesh(new THREE.BoxGeometry(0.03 * s, 0.2 * s, 0.012 * s), MAT.leatherDark);
    const g = new THREE.Group(); g.add(strip);
    for (let k = 0; k < 3; k++) { const st = new THREE.Mesh(new THREE.SphereGeometry(0.009 * s, 5, 3), MAT.bronze); st.position.set(0, (0.06 - k * 0.06) * s, 0.008 * s); g.add(st); }
    const end = new THREE.Mesh(new THREE.BoxGeometry(0.034 * s, 0.025 * s, 0.014 * s), MAT.bronze); end.position.y = -0.105 * s; g.add(end);
    attach(fig, 'pelvis', g, V().copy(pel).addScaledVector(fig.left, (i - 1.5) * 0.05 * s).addScaledVector(UP, -0.1 * s).addScaledVector(fig.fwd, b * 1.12));
  }
  // Калиги: ремешки на лодыжках
  for (const side of ['l', 'r']) {
    const f = P('foot_' + side), calf = P('calf_' + side);
    for (let k = 0; k < 3; k++) {
      const ring = new THREE.Mesh(new THREE.TorusGeometry(0.05 * s, 0.009 * s, 4, 12), MAT.leather);
      ring.rotation.x = Math.PI / 2;
      attach(fig, 'calf_' + side, new THREE.Group().add(ring), V().lerpVectors(calf, f, 0.68 + k * 0.11));
    }
  }
  // Плащ-сагум за спиной: заколот на плечах, чуть расширяется книзу
  const capeLen = 0.66 * s, capeW = shoulderW * 0.9;
  const cg = new THREE.CylinderGeometry(capeW * 0.55, capeW * 0.75, capeLen, 10, 1, true, Math.PI * 0.62, Math.PI * 0.76).translate(0, -capeLen / 2, 0);
  const cape = new THREE.Mesh(cg, twoSided(MAT.redDark));
  cape.scale.z = 0.5; cape.rotation.x = 0.1;
  attach(fig, 'spine_03', new THREE.Group().add(cape), V().copy(chest).setY(neck.y - 0.01 * s).addScaledVector(fig.fwd, -0.01 * s));
  for (const sx of [-1, 1]) {
    const fib = new THREE.Mesh(new THREE.CylinderGeometry(0.022 * s, 0.022 * s, 0.012 * s, 10), MAT.gold);
    fib.rotation.x = Math.PI / 2;
    attach(fig, 'spine_03', new THREE.Group().add(fib), V().copy(chest).setY(neck.y - 0.035 * s).addScaledVector(fig.left, sx * a * 0.62).addScaledVector(fig.fwd, b * 0.82));
  }
}

/* ---------- Варвар: штаны (нарисованы на теле), меховая накидка, пояс; топор и круглый щит ---------- */
function dressBarbarian(fig) {
  const { s, P } = fig;
  const shoulderW = P('upperarm_l').distanceTo(P('upperarm_r'));
  const a = shoulderW * 0.45, b = a * 0.72;
  const waist = P('spine_01'), chest = P('spine_03'), neck = P('neck_01');
  const belt = new THREE.Mesh(new THREE.TorusGeometry(1, 0.08, 6, 22), MAT.leatherDark);
  belt.rotation.x = Math.PI / 2; belt.scale.set(a * 0.96, b * 1.0, 0.55);
  const beltY = waist.y - 0.05 * s;
  attach(fig, 'spine_01', new THREE.Group().add(belt), V().copy(waist).setY(beltY));
  const buckle = new THREE.Mesh(new THREE.BoxGeometry(0.065 * s, 0.055 * s, 0.02 * s), MAT.gold);
  attach(fig, 'spine_01', buckle, V().copy(waist).setY(beltY).addScaledVector(fig.fwd, b * 1.04));
  // меховая накидка: валик из «клочьев» по плечам и шкура на спине
  const mantle = new THREE.Group();
  const furs = [MAT.fur, MAT.furLight, MAT.furDark];
  for (let i = 0; i < 13; i++) {
    const ang = -Math.PI * 0.8 + i / 12 * Math.PI * 1.6;
    const m = new THREE.Mesh(new THREE.IcosahedronGeometry(0.075 * s, 0), furs[i % 3]);
    m.position.set(Math.sin(ang) * a * 0.95, Math.cos(ang * 0.5) * 0.02 * s, -Math.cos(ang) * b * 0.9);
    m.scale.set(1.25, 0.8, 1.1); m.rotation.set(i * 1.3, i * 2.1, i * 0.7);
    mantle.add(m);
  }
  const hide = new THREE.Mesh(new THREE.CylinderGeometry(shoulderW * 0.4, shoulderW * 0.46, 0.34 * s, 9, 1, true, Math.PI * 0.62, Math.PI * 0.76).translate(0, -0.17 * s, 0), twoSided(MAT.furDark));
  hide.scale.z = 0.62; hide.rotation.x = 0.08; mantle.add(hide);
  attach(fig, 'spine_03', mantle, V().copy(chest).setY(neck.y - 0.03 * s));
  // наручи на предплечьях
  for (const side of ['l', 'r']) {
    const fa = P('lowerarm_' + side), ha = P('hand_' + side);
    const g = new THREE.Group();
    const cuff = new THREE.Mesh(new THREE.CylinderGeometry(0.052 * s, 0.046 * s, 0.12 * s, 8), MAT.leather);
    cuff.rotation.z = Math.PI / 2; g.add(cuff);
    attach(fig, 'lowerarm_' + side, g, V().lerpVectors(fa, ha, 0.72));
  }
}

/* ---------- Жители: пояс, юбка платья или тоги, край тоги через плечо ---------- */
function dressCitizen(fig, look) {
  const { s, P } = fig;
  const shoulderW = P('upperarm_l').distanceTo(P('upperarm_r'));
  const a = shoulderW * (fig.sex === 'f' ? 0.5 : 0.45), b = a * 0.72;
  const waist = P('spine_01'), pel = P('pelvis');
  if (look.belt) {
    const belt = new THREE.Mesh(new THREE.TorusGeometry(1, 0.06, 5, 20), flat(look.belt));
    belt.rotation.x = Math.PI / 2; belt.scale.set(a * 0.95, b * 1.0, 0.5);
    attach(fig, 'spine_01', new THREE.Group().add(belt), V().copy(waist).setY(waist.y - 0.04 * s));
  }
  if (look.skirt) {
    // жёсткая расклёшенная юбка до колен: ноги при ходьбе остаются внутри, ниже ткань нарисована на ногах
    const top = waist.y - 0.04 * s, bot = look.skirt.bottom * fig.top / 1.81, hgt = top - bot, fl = look.skirt.flare || 1.35;
    const sk = new THREE.Mesh(new THREE.CylinderGeometry(a * 0.9, a * fl, hgt, 18, 1, true), flat(look.skirt.color, { side: THREE.DoubleSide }));
    sk.scale.z = 0.85;
    attach(fig, 'pelvis', new THREE.Group().add(sk), V().copy(pel).setY(top - hgt / 2));
    if (look.skirt.hem) {
      const hem = new THREE.Mesh(new THREE.TorusGeometry(1, 0.03, 4, 24), flat(look.skirt.hem));
      hem.rotation.x = Math.PI / 2; hem.scale.set(a * fl, a * fl * 0.85, 0.5);
      attach(fig, 'pelvis', new THREE.Group().add(hem), V().copy(pel).setY(bot + 0.01 * s));
    }
  }
  if (look.sash) {
    // край тоги, перекинутый через левое плечо
    const chest = P('spine_03'), len = 0.7 * s;
    const sash = new THREE.Mesh(new THREE.BoxGeometry(0.15 * s, len, 0.03 * s), flat(look.sash, { side: THREE.DoubleSide }));
    sash.rotation.z = -0.62;
    attach(fig, 'spine_03', new THREE.Group().add(sash), V().copy(chest).addScaledVector(fig.fwd, b * 1.12).addScaledVector(UP, -0.08 * s));
  }
}

// Оружие и щит — в боевой стойке, чтобы правильно лечь в руку
function arm(fig) {
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
  if (fig.kind === 'legionary') {
    // гладиус: рукоять, гарда, широкий клинок с остриём, навершие
    const handle = new THREE.Mesh(new THREE.CylinderGeometry(0.016 * s, 0.018 * s, 0.11 * s, 8), MAT.woodDark); w.add(handle);
    const guard = new THREE.Mesh(new THREE.BoxGeometry(0.1 * s, 0.025 * s, 0.045 * s), MAT.bronze); guard.position.y = 0.065 * s; w.add(guard);
    const pommel = new THREE.Mesh(new THREE.SphereGeometry(0.028 * s, 8, 6), MAT.bronze); pommel.position.y = -0.07 * s; w.add(pommel);
    const shape = new THREE.Shape();
    const L = 0.46 * s, W = 0.032 * s;
    shape.moveTo(-W, 0); shape.lineTo(W, 0); shape.lineTo(W * 0.9, L * 0.82); shape.lineTo(0, L); shape.lineTo(-W * 0.9, L * 0.82); shape.closePath();
    const blade = new THREE.Mesh(new THREE.ExtrudeGeometry(shape, { depth: 0.008 * s, bevelEnabled: true, bevelThickness: 0.004 * s, bevelSize: 0.004 * s, bevelSegments: 1 }).translate(0, 0, -0.004 * s), MAT.steel);
    blade.position.y = 0.075 * s; w.add(blade);
  } else {
    // топор варвара
    const handle = new THREE.Mesh(new THREE.CylinderGeometry(0.018 * s, 0.022 * s, 0.7 * s, 7).translate(0, 0.22 * s, 0), MAT.wood); w.add(handle);
    const shape = new THREE.Shape();
    shape.moveTo(0, 0); shape.lineTo(0.17 * s, -0.06 * s); shape.quadraticCurveTo(0.22 * s, 0.07 * s, 0.17 * s, 0.2 * s); shape.lineTo(0, 0.14 * s); shape.closePath();
    const head = new THREE.Mesh(new THREE.ExtrudeGeometry(shape, { depth: 0.02 * s, bevelEnabled: false }).translate(0.0, 0, -0.01 * s), MAT.steel);
    head.position.y = 0.45 * s; head.rotation.y = Math.PI / 2; w.add(head);
  }
  attach(fig, 'hand_r', w, grip, [x, d, z]);

  // щит: рука держит его за рукоять за умбоном, лицом к врагу
  const ha = P('hand_l'), grip2 = V().lerpVectors(ha, P('middle_01_l'), 0.6);
  const cen = V().copy(grip2).addScaledVector(fig.fwd, 0.085 * s);
  const sh = new THREE.Group();
  if (fig.kind === 'legionary') {
    const R = 0.6 * s, T = 1.0, Hs = 1.0 * s;
    const onCurve = (x, lift) => Math.sqrt(R * R - x * x) - R + lift;
    const face = new THREE.Mesh(new THREE.CylinderGeometry(R, R, Hs, 14, 1, true, -T / 2, T).translate(0, 0, -R), twoSided(MAT.red)); sh.add(face);
    const back = new THREE.Mesh(new THREE.CylinderGeometry(R - 0.02 * s, R - 0.02 * s, Hs, 14, 1, true, -T / 2, T).translate(0, 0, -R), twoSided(MAT.leather)); sh.add(back);
    for (const yy of [-0.5, 0.5]) {
      const rim = new THREE.Mesh(new THREE.CylinderGeometry(R + 0.006 * s, R + 0.006 * s, 0.035 * s, 14, 1, true, -T / 2, T).translate(0, 0, -R), twoSided(MAT.gold));
      rim.position.y = yy * Hs; sh.add(rim);
    }
    for (const sx of [-1, 1]) {
      const edge = new THREE.Mesh(new THREE.BoxGeometry(0.032 * s, Hs + 0.03 * s, 0.032 * s), MAT.gold);
      edge.position.set(sx * Math.sin(T / 2) * R, 0, Math.cos(T / 2) * R - R); edge.rotation.y = -sx * T / 2; sh.add(edge);
    }
    const boss = new THREE.Mesh(new THREE.SphereGeometry(0.075 * s, 12, 8, 0, Math.PI * 2, 0, Math.PI / 2), MAT.gold);
    boss.rotation.x = Math.PI / 2; sh.add(boss);
    const ring = new THREE.Mesh(new THREE.TorusGeometry(0.1 * s, 0.012 * s, 5, 18), MAT.gold); ring.position.z = 0.005 * s; sh.add(ring);
    const spine = new THREE.Mesh(new THREE.BoxGeometry(0.035 * s, Hs * 0.92, 0.016 * s), MAT.gold); spine.position.z = 0.006 * s; sh.add(spine);
    // крылья орла: по три пера в каждую сторону над и под умбоном
    for (const sx of [-1, 1]) for (const sy of [-1, 1]) for (let k = 0; k < 3; k++) {
      const x = sx * (0.1 + k * 0.055) * s, y = sy * (0.135 + k * 0.03) * s;
      const seg = new THREE.Mesh(new THREE.BoxGeometry(0.075 * s, 0.024 * s, 0.012 * s), MAT.gold);
      seg.position.set(x, y, onCurve(x, 0.007 * s)); seg.rotation.set(0, -Math.asin(x / R), sy * sx * (0.25 + k * 0.12)); sh.add(seg);
    }
  } else if (fig.kind === 'barbarian') {
    const disc = new THREE.Mesh(new THREE.CylinderGeometry(0.34 * s, 0.34 * s, 0.035 * s, 16), MAT.wood);
    disc.rotation.x = Math.PI / 2; sh.add(disc);
    const paint = new THREE.Mesh(new THREE.CylinderGeometry(0.26 * s, 0.26 * s, 0.037 * s, 16), MAT.shieldGreen);
    paint.rotation.x = Math.PI / 2; sh.add(paint);
    const boss = new THREE.Mesh(new THREE.SphereGeometry(0.07 * s, 10, 6, 0, Math.PI * 2, 0, Math.PI / 2), MAT.steelDark);
    boss.rotation.x = Math.PI / 2; boss.position.z = 0.018 * s; sh.add(boss);
  }
  if (sh.children.length) attach(fig, 'lowerarm_l', sh, cen);
  // запоминаем, как плечо со щитом смотрит относительно всего тела в стойке
  if (fig.shield) fig.guardQ = fig.bone('upperarm_l').getWorldQuaternion(new THREE.Quaternion()).premultiply(fig.root.quaternion.clone().invert());
  act.stop();
  fig.mixer.update(0);
}

// Корпус в ударе сильно скручивается, и щит улетал бы назад. Держим плечо со щитом
// повёрнутым к врагу относительно всего бойца, а не относительно корпуса.
const _q1 = new THREE.Quaternion(), _q2 = new THREE.Quaternion();
function lockGuard(f) {
  if (!f.guardQ || f.cur === f.actions.Death01) return;
  const b = f.bone('upperarm_l');
  b.parent.updateWorldMatrix(true, false);
  b.parent.getWorldQuaternion(_q1).invert();
  _q2.copy(f.root.quaternion).multiply(f.guardQ);
  b.quaternion.slerp(_q1.multiply(_q2), 0.85);
}

function play(f, name, once, fade) {
  const next = f.actions[name];
  if (!next || f.cur === next && !once) return next;
  next.reset();
  next.setLoop(once ? THREE.LoopOnce : THREE.LoopRepeat, Infinity);
  next.clampWhenFinished = !!once;
  next.enabled = true;
  if (f.cur) next.crossFadeFrom(f.cur, fade || 0.2, false);
  if (f.guard && name === 'Death01') f.guard.fadeOut(fade || 0.2);
  next.play();
  f.cur = next;
  return next;
}


export { THREE, load, CLIPS, LOOKS, MAT, makeFighter, makePerson, arm, lockGuard, play, attach, paintBody, addHair, V, UP };
