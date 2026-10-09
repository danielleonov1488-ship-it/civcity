// Запуск игры. Three.js подключается как модуль — один и тот же для города, боёв и загрузчиков
// моделей (бойцы со скелетом, звери). Потом по порядку грузятся обычные скрипты игры.
import * as THREE from 'three';

window.THREE = THREE;
const v = new URL(import.meta.url).searchParams.get('v') || '';
const FILES = ['config', 'util', 'world', 'roads', 'paving', 'models', 'look2', 'post', 'atmos', 'engine', 'sim', 'army', 'battle',
  'walkers', 'settlers', 'icons', 'input', 'advisor', 'armyui', 'ui', 'minimap', 'save', 'account', 'audio', 'test', 'diag', 'main'];
// город для съёмок рекламы — только по адресу с #promo
if (location.hash.includes('promo')) FILES.splice(FILES.indexOf('main'), 0, 'promo');
let last;
for (const f of FILES) {
  const s = last = document.createElement('script');
  s.src = `js/${f}.js?v=${v}`;
  s.async = false;          // выполняются строго по порядку, а качаются все сразу
  document.body.appendChild(s);
}
// Бойцы для сражений (тела со скелетом, звери) — тяжёлые, их догружаем в фоне, когда город уже работает
last.addEventListener('load', () => setTimeout(() => {
  import(`./battle3d.js?v=${v}`).catch(e => console.warn('Бойцы для боёв не загрузились, будут прежние фигурки', e));
}, 1500));
