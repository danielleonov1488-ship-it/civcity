// Запуск игры. Three.js подключается как модуль — один и тот же для города, боёв и загрузчиков
// моделей (бойцы со скелетом, звери). Потом по порядку грузятся обычные скрипты игры.
import * as THREE from 'three';

window.THREE = THREE;
const v = new URL(import.meta.url).searchParams.get('v') || '';
const FILES = ['config', 'util', 'world', 'models', 'look2', 'post', 'atmos', 'engine', 'sim', 'army', 'battle',
  'walkers', 'icons', 'input', 'advisor', 'armyui', 'ui', 'save', 'test', 'main'];
for (const f of FILES) {
  const s = document.createElement('script');
  s.src = `js/${f}.js?v=${v}`;
  s.async = false;          // выполняются строго по порядку, а качаются все сразу
  document.body.appendChild(s);
}
