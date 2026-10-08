// Жители в стиле Synty: гранёные тела, одежда и причёски из набора Artisau (CC0, куплен).
// Модели в наборе неподвижные, поэтому «сажаем» их на скелет Quaternius (тот же, что у бойцов)
// и получаем все 43 движения бесплатной библиотеки анимаций.
import * as THREE from 'three';
import { FBXLoader } from '../vendor/three-module/examples/jsm/loaders/FBXLoader.js';
import { GLTFLoader } from '../vendor/three-module/examples/jsm/loaders/GLTFLoader.js';
import * as SkeletonUtils from '../vendor/three-module/examples/jsm/utils/SkeletonUtils.js';

const ART = '../assets/incoming/artisau/unpacked/AncientGrecce/';
const QBODY = encodeURI('../assets/incoming/universal-base-characters/unpacked/Universal Base Characters[Standard]/Base Characters/Godot - UE/Superhero_Male_FullBody.gltf');
const ANIMS = encodeURI('../assets/incoming/universal-animation-library/unpacked/Universal Animation Library[Standard]/Unreal-Godot/UAL1_Standard.glb');
export const ART_K = 0.0052;   // 350 единиц Artisau = 1,82 м

const fbx = new FBXLoader(), gltf = new GLTFLoader();
const cache = {};
export function loadArt(name) {
  return cache[name] ??= new Promise((res, rej) => fbx.load(encodeURI(ART + name + '.fbx'), res, undefined, rej));
}
const loadG = url => new Promise((res, rej) => gltf.load(url, res, undefined, rej));

/* ---------- Палитра: один квадрат 16×16 на весь набор; для разнообразия одежды делаем варианты ---------- */
const paletteImg = await new Promise((res, rej) => { const i = new Image(); i.onload = () => res(i); i.onerror = rej; i.src = encodeURI(ART + 'TexturaLowPoly.png'); });
const matCache = {};
// swap: { 'rrggbb': '#rrggbb' } — какие клетки палитры перекрасить
export function paletteMaterial(swap = {}, key = JSON.stringify(swap)) {
  if (matCache[key]) return matCache[key];
  const cv = document.createElement('canvas'); cv.width = paletteImg.width; cv.height = paletteImg.height;
  const g = cv.getContext('2d'); g.drawImage(paletteImg, 0, 0);
  const d = g.getImageData(0, 0, cv.width, cv.height);
  for (let i = 0; i < d.data.length; i += 4) {
    const hex = [0, 1, 2].map(k => d.data[i + k].toString(16).padStart(2, '0')).join('');
    const to = swap[hex];
    if (to) { const c = parseInt(to.slice(1), 16); d.data[i] = c >> 16; d.data[i + 1] = (c >> 8) & 255; d.data[i + 2] = c & 255; }
  }
  g.putImageData(d, 0, 0);
  const map = new THREE.CanvasTexture(cv);
  map.colorSpace = THREE.SRGBColorSpace; map.magFilter = map.minFilter = THREE.NearestFilter; map.generateMipmaps = false;
  return (matCache[key] = new THREE.MeshStandardMaterial({ map, roughness: 0.85, metalness: 0, envMapIntensity: 0.12 }));
}

/* ---------- Скелет-образец и движения ---------- */
const [qbody, animG] = await Promise.all([loadG(QBODY), loadG(ANIMS)]);
const TEMPLATE = qbody.scene;
TEMPLATE.updateMatrixWorld(true);
animG.scene.updateMatrixWorld(true);
const TPL_H = 1.81;

// Кости, к которым крепим вершины, и их «отрезки» (от кости к её главному ребёнку)
const SEG = [
  ['pelvis', 'spine_01'], ['spine_01', 'spine_02'], ['spine_02', 'spine_03'], ['spine_03', 'neck_01'], ['neck_01', 'Head'], ['Head', null, 0.2],
  ['clavicle_l', 'upperarm_l'], ['upperarm_l', 'lowerarm_l'], ['lowerarm_l', 'hand_l'], ['hand_l', 'middle_01_l', 1.6],
  ['clavicle_r', 'upperarm_r'], ['upperarm_r', 'lowerarm_r'], ['lowerarm_r', 'hand_r'], ['hand_r', 'middle_01_r', 1.6],
  ['thigh_l', 'calf_l'], ['calf_l', 'foot_l'], ['foot_l', 'ball_l'], ['ball_l', null, 0.08],
  ['thigh_r', 'calf_r'], ['calf_r', 'foot_r'], ['foot_r', 'ball_r'], ['ball_r', null, 0.08],
];

const _v = new THREE.Vector3(), _a = new THREE.Vector3(), _b = new THREE.Vector3(), _q = new THREE.Quaternion(), _q2 = new THREE.Quaternion();
const wp = b => b.getWorldPosition(new THREE.Vector3());

// Повернуть кость так, чтобы направление «кость → ребёнок» в мире стало dir
function aimBone(bone, child, dir) {
  bone.updateWorldMatrix(true, true);
  const cur = wp(child).sub(wp(bone)).normalize();
  const rot = _q.setFromUnitVectors(cur, dir.clone().normalize());
  const worldQ = bone.getWorldQuaternion(_q2);
  const parentQ = bone.parent.getWorldQuaternion(new THREE.Quaternion());
  bone.quaternion.copy(parentQ.invert().multiply(rot.multiply(worldQ)));
  bone.updateWorldMatrix(false, true);
}

// Подогнать скелет-образец под тело Artisau: рост, наклон рук (A-поза), постановка ног
function fitSkeleton(root, body) {
  const box = new THREE.Box3().setFromObject(body);
  const H = box.max.y;
  const k = H / TPL_H;
  root.traverse(o => { if (o.isBone) o.position.multiplyScalar(k); });
  root.updateMatrixWorld(true);
  const bone = n => root.getObjectByName(n);
  const pos = body.geometry.attributes.position, m = body.matrixWorld;
  const verts = [];
  for (let i = 0; i < pos.count; i++) verts.push(new THREE.Vector3().fromBufferAttribute(pos, i).applyMatrix4(m));
  // руки: вершины дальше плеча по ширине — это рука; кончик — самая дальняя точка
  for (const side of ['l', 'r']) {
    const sx = side === 'l' ? 1 : -1;
    const sh = wp(bone('upperarm_' + side));
    const arm = verts.filter(v => v.x * sx > Math.abs(sh.x) + 0.04 && v.y > 0.55 * H);
    if (!arm.length) continue;
    let tip = arm[0];
    for (const v of arm) if (v.distanceTo(sh) > tip.distanceTo(sh)) tip = v;
    // ось руки: от плеча к центру кисти (кисть — 8 % длины руки от кончика)
    const dir = tip.clone().sub(sh);
    const len = dir.length();
    aimBone(bone('upperarm_' + side), bone('lowerarm_' + side), dir);
    // длина руки: локоть и запястье по пропорциям образца
    const ua = bone('lowerarm_' + side), la = bone('hand_' + side);
    const tplLen = ua.position.length() + la.position.length();
    const want = len * 0.86;
    const r = want / tplLen;
    ua.position.multiplyScalar(r); la.position.multiplyScalar(r);
    root.updateMatrixWorld(true);
  }
  // ноги: ставим стопы туда, где у модели ступни
  for (const side of ['l', 'r']) {
    const sx = side === 'l' ? 1 : -1;
    const feet = verts.filter(v => v.y < 0.06 * H && v.x * sx > 0);
    if (!feet.length) continue;
    const c = feet.reduce((s, v) => s.add(v), new THREE.Vector3()).multiplyScalar(1 / feet.length);
    const hip = wp(bone('thigh_' + side));
    const ankle = new THREE.Vector3(c.x, wp(bone('foot_' + side)).y, wp(bone('foot_' + side)).z);
    aimBone(bone('thigh_' + side), bone('calf_' + side), ankle.clone().sub(hip));
    // длина ноги
    const legNow = wp(bone('foot_' + side)).distanceTo(hip), legWant = ankle.distanceTo(hip);
    const r = legWant / legNow;
    bone('calf_' + side).position.multiplyScalar(r); bone('foot_' + side).position.multiplyScalar(r);
    root.updateMatrixWorld(true);
  }
  return k;
}

// Веса: каждая вершина тянется к 2–3 ближайшим отрезкам костей (почти жёстко, мягко на сгибах)
function skinWeights(geo, matrixWorld, segs) {
  const pos = geo.attributes.position, n = pos.count;
  const idx = new Uint16Array(n * 4), wts = new Float32Array(n * 4);
  const v = new THREE.Vector3(), ab = new THREE.Vector3(), av = new THREE.Vector3();
  const best = [];
  for (let i = 0; i < n; i++) {
    v.fromBufferAttribute(pos, i).applyMatrix4(matrixWorld);
    best.length = 0;
    for (const s of segs) {
      ab.subVectors(s.b, s.a); av.subVectors(v, s.a);
      const t = THREE.MathUtils.clamp(av.dot(ab) / Math.max(1e-9, ab.lengthSq()), 0, 1);
      const d = av.addScaledVector(ab, -t).length() + s.bias;
      best.push([d, s.index]);
    }
    best.sort((x, y) => x[0] - y[0]);
    const d0 = best[0][0];
    let sum = 0;
    const ws = [];
    for (let j = 0; j < 4; j++) {
      const [d, bi] = best[j];
      // близкие к лучшей кости получают долю, дальние — ноль
      const w = Math.exp(-Math.pow((d - d0) / 0.035, 2));
      ws.push([w, bi]); sum += w;
    }
    for (let j = 0; j < 4; j++) { idx[i * 4 + j] = ws[j][1]; wts[i * 4 + j] = ws[j][0] / sum; }
  }
  geo.setAttribute('skinIndex', new THREE.Uint16BufferAttribute(idx, 4));
  geo.setAttribute('skinWeight', new THREE.Float32BufferAttribute(wts, 4));
}

function clipsFor(root) {
  const bp = root.getObjectByName('pelvis'), ap = animG.scene.getObjectByName('pelvis');
  const k = wp(bp).y / wp(ap).y;
  const out = {};
  for (const clip of animG.animations) {
    const c = clip.clone();
    c.tracks = c.tracks.filter(t => t.name.endsWith('.quaternion') || t.name === 'pelvis.position');
    for (const t of c.tracks) if (t.name === 'pelvis.position') { t.values = t.values.slice(); for (let i = 0; i < t.values.length; i++) t.values[i] *= k; }
    out[clip.name] = c;
  }
  return out;
}

/* ---------- Сборка жителя ---------- */
// Образцы (тело + скелет + веса) делаются один раз на каждый набор частей, дальше — дешёвые копии
const RIGS = {};
export async function rig(parts, swap) {
  const key = parts.join('|') + JSON.stringify(swap || {});
  if (RIGS[key]) return RIGS[key];
  const meshes = [];
  for (const p of parts) {
    const o = await loadArt(p);
    o.updateMatrixWorld(true);
    o.traverse(m => { if (m.isMesh) meshes.push({ name: p, mesh: m }); });
  }
  const root = SkeletonUtils.clone(TEMPLATE);
  const drop = []; root.traverse(o => { if (o.isMesh) drop.push(o); });   // тело Quaternius не нужно, только кости
  drop.forEach(o => o.parent.remove(o));
  const group = new THREE.Group();
  group.add(root);
  group.updateMatrixWorld(true);
  // тело Artisau в метрах — по нему подгоняем скелет
  const toM = new THREE.Matrix4().makeScale(ART_K, ART_K, ART_K);
  const probe = new THREE.Mesh(meshes[0].mesh.geometry);
  probe.matrixAutoUpdate = false;
  probe.matrix.multiplyMatrices(toM, meshes[0].mesh.matrixWorld);
  probe.matrixWorld.copy(probe.matrix);
  const bb = new THREE.Box3().setFromObject(probe);
  fitSkeleton(root, probe);
  group.updateMatrixWorld(true);
  const bones = []; root.traverse(o => { if (o.isBone) bones.push(o); });
  const bi = n => bones.findIndex(b => b.name === n);
  const segs = SEG.map(([a, b, ext]) => {
    const A = wp(root.getObjectByName(a));
    let B;
    if (b) { B = wp(root.getObjectByName(b)); if (ext) B = A.clone().lerp(B, ext); }
    else if (a === 'Head') B = A.clone().add(new THREE.Vector3(0, ext, 0));
    else { const foot = wp(root.getObjectByName(a.replace('ball', 'foot'))); B = A.clone().add(A.clone().sub(foot).setY(0).normalize().multiplyScalar(ext)); }
    return { a: A, b: B, index: bi(a), bias: a.startsWith('clavicle') ? 0.03 : 0 };
  });
  const skeleton = new THREE.Skeleton(bones);
  const mat = paletteMaterial(swap || {});
  const skinned = [];
  for (const { mesh } of meshes) {
    const geo = mesh.geometry.clone();
    geo.applyMatrix4(new THREE.Matrix4().multiplyMatrices(toM, mesh.matrixWorld));
    skinWeights(geo, new THREE.Matrix4(), segs);
    const sm = new THREE.SkinnedMesh(geo, mat);
    sm.castShadow = true; sm.receiveShadow = true;
    sm.frustumCulled = false;
    group.add(sm);
    sm.bind(skeleton, new THREE.Matrix4());
    skinned.push(sm);
  }
  const clips = clipsFor(root);
  return (RIGS[key] = { group, clips, height: bb.max.y });
}

// Готовый житель: копия образца со своим скелетом и проигрывателем движений
export async function citizen(parts, swap) {
  const r = await rig(parts, swap);
  const g = SkeletonUtils.clone(r.group);
  const mixer = new THREE.AnimationMixer(g);
  const actions = {};
  for (const [n, c] of Object.entries(r.clips)) actions[n] = mixer.clipAction(c);
  const c = { root: g, mixer, actions, cur: null };
  c.play = (name, fade = 0.25, once = false) => {
    const a = actions[name];
    if (!a || c.cur === a) return a;
    a.reset(); a.setLoop(once ? THREE.LoopOnce : THREE.LoopRepeat, Infinity); a.clampWhenFinished = once;
    if (c.cur) a.crossFadeFrom(c.cur, fade, false);
    a.play(); c.cur = a;
    return a;
  };
  return c;
}

export { THREE };
