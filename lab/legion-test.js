// Проверка моделей: бесплатные персонажи и анимации Quaternius (CC0), римское снаряжение
// строится кодом и крепится к костям. Двое легионеров против двоих варваров.
import * as THREE from 'three';
import { RoomEnvironment } from '../vendor/three-module/examples/jsm/environments/RoomEnvironment.js';
import { setScene, CLIPS, makeFighter, arm, lockGuard, play } from './people.js';


const status = document.getElementById('status');
const canvas = document.getElementById('c');
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true });
renderer.setPixelRatio(Math.min(2, devicePixelRatio));
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 0.95;
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;

const scene = new THREE.Scene();
const pmrem = new THREE.PMREMGenerator(renderer);
scene.environment = pmrem.fromScene(new RoomEnvironment(renderer), 0.04).texture;

// небо: мягкий градиент, как в Synty
{
  const c = document.createElement('canvas'); c.width = 2; c.height = 256;
  const g = c.getContext('2d'), gr = g.createLinearGradient(0, 0, 0, 256);
  gr.addColorStop(0, '#7fb8e6'); gr.addColorStop(0.6, '#cfe6f0'); gr.addColorStop(1, '#eef3e2');
  g.fillStyle = gr; g.fillRect(0, 0, 2, 256);
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace;
  scene.background = t;
}
scene.fog = new THREE.Fog('#d6e6ea', 26, 75);

scene.add(new THREE.HemisphereLight('#dff1ff', '#6f8c48', 0.95));
const sun = new THREE.DirectionalLight('#fff1d6', 2.6);
sun.position.set(-6, 10, 7);
sun.castShadow = true;
sun.shadow.mapSize.set(2048, 2048);
Object.assign(sun.shadow.camera, { left: -9, right: 9, top: 9, bottom: -9, near: 1, far: 40 });
sun.shadow.bias = -0.0004;
sun.shadow.normalBias = 0.02;
scene.add(sun);

const camera = new THREE.PerspectiveCamera(32, 1, 0.1, 200);

/* ---------- Поле: трава, камни, деревья в духе Synty (плоские грани, чистые цвета) ---------- */
const flat = (color, o) => new THREE.MeshStandardMaterial(Object.assign({ color, roughness: 0.9, metalness: 0, flatShading: true }, o || {}));
{
  const geo = new THREE.PlaneGeometry(60, 40, 60, 40).rotateX(-Math.PI / 2);
  const col = [], c = new THREE.Color(), a = new THREE.Color('#6ea33e'), b = new THREE.Color('#4c8a2e'), p = new THREE.Color('#bb9c62');
  const pos = geo.attributes.position;
  for (let i = 0; i < pos.count; i++) {
    const x = pos.getX(i), z = pos.getZ(i);
    const n = Math.sin(x * 0.9 + z * 0.5) * 0.5 + Math.sin(x * 0.31 - z * 1.3) * 0.5;
    c.copy(a).lerp(b, 0.5 + n * 0.5);
    const band = Math.max(0, 1 - Math.abs(z) / 2.2 + n * 0.15);
    c.lerp(p, Math.min(1, band) * 0.55);
    col.push(c.r, c.g, c.b);
    pos.setY(i, z < -8 ? Math.pow((-8 - z) / 10, 1.5) * 2.5 : 0);
  }
  geo.setAttribute('color', new THREE.Float32BufferAttribute(col, 3));
  geo.computeVertexNormals();
  const ground = new THREE.Mesh(geo, new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.95, flatShading: true }));
  ground.receiveShadow = true;
  scene.add(ground);
  const rnd = (() => { let s = 7; return () => (s = (s * 16807) % 2147483647) / 2147483647; })();
  const tree = (x, z, k) => {
    const g = new THREE.Group();
    const trunk = new THREE.Mesh(new THREE.CylinderGeometry(0.12 * k, 0.18 * k, 1.4 * k, 6), flat('#7a5636'));
    trunk.position.y = 0.7 * k; g.add(trunk);
    for (const [dx, dy, dz, r, col] of [[0, 1.9, 0, 0.95, '#5f9a3e'], [0.45, 1.6, 0.2, 0.7, '#4f8a35'], [-0.4, 1.7, -0.2, 0.75, '#6aa845'], [0, 2.5, 0, 0.6, '#7cb84e']]) {
      const m = new THREE.Mesh(new THREE.IcosahedronGeometry(r * k, 0), flat(col));
      m.position.set(dx * k, dy * k, dz * k); m.rotation.set(rnd(), rnd(), rnd()); g.add(m);
    }
    g.position.set(x, 0, z);
    g.traverse(o => { if (o.isMesh) { o.castShadow = true; o.receiveShadow = true; } });
    scene.add(g);
  };
  const rock = (x, z, k) => {
    const m = new THREE.Mesh(new THREE.DodecahedronGeometry(0.5 * k, 0), flat('#a7a197'));
    m.position.set(x, 0.2 * k, z); m.scale.set(1.3, 0.7, 1); m.rotation.y = rnd() * 3;
    m.castShadow = true; m.receiveShadow = true; scene.add(m);
  };
  for (let i = 0; i < 14; i++) tree(-18 + i * 2.8 + rnd() * 1.2, -7 - rnd() * 7, 0.9 + rnd() * 0.6);
  for (let i = 0; i < 7; i++) rock(-11 + i * 3.6 + rnd(), -3.4 - rnd() * 2.5, 0.5 + rnd() * 0.7);
}

setScene(scene);


/* ---------- Бой: подход, удары, попадания, смерть ---------- */
const fighters = [];
function spawn() {
  for (const f of fighters) { scene.remove(f.root); f.mixer.stopAllAction(); }
  fighters.length = 0;
  const kinds = [['legionary', -1, -0.7], ['legionary', -1, 0.8], ['barbarian', 1, -0.6], ['barbarian2', 1, 0.75]];
  for (const [kind, side, z] of kinds) {
    const f = makeFighter(kind);
    arm(f);
    f.side = side; f.hp = kind === 'legionary' ? 5 : 3;
    f.x = side * 4.2; f.z = z;
    f.state = 'wait'; f.t = Math.random() * 0.4;
    f.root.position.set(f.x, 0, f.z);
    f.root.rotation.y = (side < 0 ? Math.PI / 2 : -Math.PI / 2) - f.yaw0;
    fighters.push(f);
    play(f, 'Sword_Idle');
  }
}

function foesOf(f) { return fighters.filter(o => o.side !== f.side && o.state !== 'dead'); }

let mode = 'fight', resetT = 0;
function stepFight(dt) {
  for (const f of fighters) {
    if (f.state === 'dead') continue;
    f.t -= dt;
    const foes = foesOf(f);
    if (!foes.length) { if (f.state !== 'win') { f.state = 'win'; play(f, 'Idle_Loop', false, 0.4); } continue; }
    let tgt = f.target;
    if (!tgt || tgt.state === 'dead') tgt = f.target = foes.reduce((a, o) => Math.abs(o.x - f.x) + Math.abs(o.z - f.z) * 0.5 < Math.abs(a.x - f.x) + Math.abs(a.z - f.z) * 0.5 ? o : a);
    const dx = tgt.x - f.x, dz = tgt.z - f.z, dist = Math.hypot(dx, dz);
    // поворот к цели
    // к врагу, но вполоборота к зрителю: так видно лица и щиты
    const want = Math.atan2(dx, dz + Math.abs(dx) * 0.45) - f.yaw0;
    let dy = want - f.root.rotation.y; dy = Math.atan2(Math.sin(dy), Math.cos(dy));
    f.root.rotation.y += dy * Math.min(1, dt * 6);
    if (f.state === 'wait') { if (f.t <= 0) f.state = 'move'; continue; }
    if (f.state === 'hit' || f.state === 'attack') { if (f.t <= 0) { f.state = 'fight'; play(f, 'Sword_Idle', false, 0.25); f.t = 0.7 + Math.random() * 1.1; } else if (f.state === 'attack' && !f.dealt && f.t < f.hitAt) { f.dealt = true; strike(f, tgt); } continue; }
    if (dist > 1.75) {
      if (f.state !== 'move') { f.state = 'move'; }
      play(f, 'Jog_Fwd_Loop', false, 0.25);
      const sp = 2.4 * dt;
      f.x += dx / dist * sp; f.z += dz / dist * sp * 0.6;
    } else {
      if (f.state === 'move') { f.state = 'fight'; play(f, 'Sword_Idle', false, 0.25); f.t = Math.random() * 0.5; }
      if (f.t <= 0) {
        f.state = 'attack'; f.dealt = false;
        const a = play(f, 'Sword_Attack', true, 0.12);
        const dur = a.getClip().duration;
        f.t = dur * 0.95; f.hitAt = dur * 0.5;
      }
    }
    f.root.position.set(f.x, 0, f.z);
  }
  if (fighters.every(f => f.state === 'dead' || f.state === 'win') && fighters.some(f => f.state === 'win')) {
    resetT += dt;
    if (resetT > 4) { resetT = 0; spawn(); tuneEnv(); }
  }
}

function strike(f, tgt) {
  if (!tgt || tgt.state === 'dead') return;
  tgt.hp -= 1 + (Math.random() < 0.25 ? 1 : 0);
  if (tgt.hp <= 0) { tgt.state = 'dead'; play(tgt, 'Death01', true, 0.15); return; }
  if (tgt.state !== 'attack') {
    tgt.state = 'hit';
    const a = play(tgt, Math.random() < 0.5 ? 'Hit_Chest' : 'Hit_Head', true, 0.1);
    tgt.t = a.getClip().duration * 0.9;
  }
}

/* ---------- Режим «Движения»: одно движение на выбор ---------- */
const SHOW = ['Sword_Idle', 'Sword_Attack', 'Walk_Loop', 'Jog_Fwd_Loop', 'Sprint_Loop', 'Hit_Chest', 'Hit_Head', 'Death01', 'Roll', 'Idle_Loop', 'Punch_Cross', 'Spell_Simple_Shoot', 'Jump_Start', 'Dance_Loop'];
const animsEl = document.getElementById('anims');
animsEl.innerHTML = SHOW.filter(n => CLIPS[n]).map(n => `<button data-a="${n}">${n.replace(/_Loop$/, '').replace(/_/g, ' ')}</button>`).join('');
animsEl.querySelectorAll('[data-a]').forEach(b => b.onclick = () => {
  animsEl.querySelectorAll('button').forEach(x => x.classList.toggle('on', x === b));
  for (const f of fighters) { const a = play(f, b.dataset.a, /Death|Hit|Attack|Roll|Jump|Shoot|Punch/.test(b.dataset.a), 0.2); if (a.loop === THREE.LoopOnce) { a.reset().play(); } }
});
function setMode(m) {
  mode = m;
  document.getElementById('m-fight').classList.toggle('on', m === 'fight');
  document.getElementById('m-show').classList.toggle('on', m === 'show');
  animsEl.hidden = m !== 'show';
  spawn(); tuneEnv();
  if (m === 'show') fighters.forEach((f, i) => { f.x = -2.4 + i * 1.6; f.z = 0; f.root.position.set(f.x, 0, 0); f.root.rotation.y = -f.yaw0; play(f, 'Sword_Idle'); });
}
document.getElementById('m-fight').onclick = () => setMode('fight');
document.getElementById('m-show').onclick = () => setMode('show');
document.getElementById('restart').onclick = () => setMode(mode);
let camMode = 0;
const camBtn = document.getElementById('cam');
camBtn.onclick = () => { camMode = (camMode + 1) % 3; camBtn.textContent = ['Камера: как в игре', 'Камера: крупно', 'Камера: облёт'][camMode]; };

function resize() {
  const w = innerWidth, h = innerHeight;
  renderer.setSize(w, h, false);
  camera.aspect = w / h;
  camera.updateProjectionMatrix();
}
addEventListener('resize', resize);
resize();
spawn();
// отражения неба только металлу (в этой версии three нет scene.environmentIntensity)
function tuneEnv() { scene.traverse(o => { if (o.isMesh) for (const m of [].concat(o.material)) m.envMapIntensity = m.metalness > 0.4 ? 0.9 : 0.15; }); }
tuneEnv();
status.textContent = `Готово: ${Object.keys(CLIPS).length} движений`;
window.LAB = { fighters, scene, camera, renderer, CLIPS, setMode, play };

const clock = new THREE.Clock();
let T = 0, focusX = 0;
function tick(dt) {
  T += dt;
  if (mode === 'fight') stepFight(dt);
  for (const f of fighters) { f.mixer.update(dt); lockGuard(f); }
  // расстояние, при котором нужная ширина поля помещается в кадр
  const fit = halfW => Math.max(halfW * 1.3, halfW / (Math.tan(THREE.MathUtils.degToRad(camera.fov / 2)) * camera.aspect));
  const alive = fighters.filter(f => f.state !== 'dead');
  const cx = alive.length ? alive.reduce((s, f) => s + f.x, 0) / alive.length : 0;
  focusX += (cx - focusX) * Math.min(1, dt * 2);
  if (LAB.freeCam) { /* камера задана вручную */ }
  else if (camMode === 0) { const d = fit(3.6); camera.position.set(focusX, d * 0.26, d); camera.lookAt(focusX, 0.9, 0); }
  else if (camMode === 1) { const d = fit(1.9); camera.position.set(focusX + d * 0.25, 1.55, d); camera.lookAt(focusX, 1.05, 0); }
  else { camera.position.set(focusX + Math.sin(T * 0.3) * 6, 2.2, Math.cos(T * 0.3) * 6); camera.lookAt(focusX, 1, 0); }
  renderer.render(scene, camera);
}
renderer.setAnimationLoop(() => tick(Math.min(clock.getDelta(), 0.05)));
// для проверки без видимого окна: прокрутить бой на sec секунд
LAB.advance = sec => { for (let t = 0; t < sec; t += 1 / 30) tick(1 / 30); return fighters.map(f => f.kind + ':' + f.state + ':' + f.hp); };
