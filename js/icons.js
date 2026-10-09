'use strict';
/* Маленькие рисованные значки товаров и ресурсов для интерфейса. */

// Контурные «чернильные» иконки интерфейса (как в Town to City): рисуются линией цвета текста
const UI_SVG = {
  research: '<path d="M7 4h10a2 2 0 0 1 0 4H7a2 2 0 0 1 0-4Zm0 4v10a2 2 0 0 0 2 2h8a2 2 0 0 0 2-2V8M10 12h6M10 15.5h4.5"/>',
  goods: '<path d="M10 3h4M10.5 3v3.2C8 7.3 6.5 9.6 6.5 13c0 4 2.4 7 5.5 7s5.5-3 5.5-7c0-3.4-1.5-5.7-4-6.8V3M6.5 9.5H4.5M17.5 9.5h2M8.5 14h7"/>',
  wonders: '<path d="M3 9.2 12 4l9 5.2Z"/><path d="M4 9.2h16M5.8 18.8V9.2M10 18.8V9.2M14 18.8V9.2M18.2 18.8V9.2M3.5 18.8h17M2.5 21h19"/>',
  swords: '<path d="M4 4l10 10M14 14l2.5-.8L20 20l-3 1-3.2-4.5Z"/><path d="M20 4 10 14M10 14l-2.5-.8L4 20l3 1 3.2-4.5Z"/>',
  legion: '<path d="M5 16a7 7 0 0 1 14 0v3h-4.5v-3a2.5 2.5 0 0 0-5 0v3H5Z"/><path d="M12 9V4.5M8.5 5.5c1.5-2 5.5-2 7 0"/>',
  guide: '<path d="M4 5.5c3-1.2 6-1 8 .8 2-1.8 5-2 8-.8v13c-3-1.2-6-1-8 .8-2-1.8-5-2-8-.8Z"/><path d="M12 6.3v13"/>',
  journal: '<path d="M6 3.5h9l3.5 3.5v13.5H6Z"/><path d="M15 3.5V7h3.5M9 10.5h6.5M9 13.5h6.5M9 16.5h4"/>',
  gear: '<circle cx="12" cy="12" r="3"/><path d="M12 2.8v2.4M12 18.8v2.4M2.8 12h2.4M18.8 12h2.4M5.5 5.5l1.7 1.7M16.8 16.8l1.7 1.7M5.5 18.5l1.7-1.7M16.8 7.2l1.7-1.7"/><circle cx="12" cy="12" r="6.3"/>',
  rotl: '<path d="M8 6H4V2M4.6 6A8 8 0 1 1 4 13"/>',
  eye: '<path d="M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12Z"/><circle cx="12" cy="12" r="3"/>',
  map: '<path d="M3.5 6.5 9 4l6 2.5 5.5-2.5v13.5L15 20l-6-2.5-5.5 2.5Z"/><path d="M9 4v13.5M15 6.5V20"/>',
  home: '<path d="M3.5 10.5 12 4l8.5 6.5"/><path d="M5.5 9v10h13V9"/><path d="M10 19v-5.5h4V19"/>',
  rotr: '<path d="M16 6h4V2M19.4 6A8 8 0 1 0 20 13"/>',
  pause: '<path d="M9 5v14M15 5v14"/>',
  play: '<path d="M7 5l11 7-11 7Z"/>',
  fast: '<path d="M3 6l8 6-8 6ZM12 6l8 6-8 6Z"/>',
  faster: '<path d="M2 7l6 5-6 5ZM9 7l6 5-6 5ZM16 7l6 5-6 5Z"/>',
  close: '<path d="M6 6l12 12M18 6 6 18"/>',
  menu: '<path d="M4.5 7h15M4.5 12h15M4.5 17h15"/>',
  smile: '<circle cx="12" cy="12" r="8.5"/><path d="M8.5 14c.9 1.5 2.1 2.2 3.5 2.2s2.6-.7 3.5-2.2"/><path d="M9.2 9.6v.6M14.8 9.6v.6"/>',
  road: '<path d="M8 3.5 4 20.5M16 3.5l4 17"/><path d="M12 4.5v2.5M12 10.5v3M12 17v3"/>',
  dropper: '<path d="M14.5 4.5a2.8 2.8 0 0 1 4 4L16 11l-3-3Z"/><path d="M13 8 5.5 15.5 5 19l3.5-.5L16 11"/>',
  move: '<path d="M12 3v18M3 12h18"/><path d="M9 6l3-3 3 3M9 18l3 3 3-3M6 9l-3 3 3 3M18 9l3 3-3 3"/>',
  shovel: '<path d="M14 10 5 19"/><path d="M13.5 5.5 18.5 10.5 21 8l-5-5Z"/><path d="M3.5 17.5 6.5 20.5"/>',
  up: '<path d="M6 14l6-6 6 6"/>',
  pick: '<path d="M5 20 15 10"/><path d="M9 5.5c4.5-2.5 10-1.3 12 3l-3.5 1C16 7.3 12.6 6.2 9 5.5Z"/>',
  coin: '<circle cx="12" cy="12" r="8.5"/><circle cx="12" cy="12" r="5.5"/>',
  people: '<circle cx="9" cy="8" r="3"/><path d="M3.5 19c.5-4 2.6-6 5.5-6s5 2 5.5 6"/><circle cx="16.5" cy="9" r="2.4"/><path d="M15.5 13.3c2.7-.3 4.6 1.6 5 5"/>',
  hammer: '<path d="M5 19.5l8.5-8.5"/><path d="M10.5 5.5l3.5-2.5 6.5 6.5-2.5 3.5Z"/>',
  wheat: '<path d="M12 21V8"/><path d="M12 8c-2.2-1-2.8-3.2-2.2-5.4 2.2.6 3.2 2.8 2.2 5.4Zm0 0c2.2-1 2.8-3.2 2.2-5.4-2.2.6-3.2 2.8-2.2 5.4ZM12 13.5c-2.2-.8-3.4-2.4-3.4-4.6 2.2.3 3.4 2 3.4 4.6Zm0 0c2.2-.8 3.4-2.4 3.4-4.6-2.2.3-3.4 2-3.4 4.6Z"/>',
  laurel: '<path d="M8 19C4.5 16 4 10.5 7 6.5M16 19c3.5-3 4-8.5 1-12.5"/><path d="M6.2 9.5l2.3.8M5.4 13l2.6.4M6.4 16.3l2.4-.3M17.8 9.5l-2.3.8M18.6 13l-2.6.4M17.6 16.3l-2.4-.3"/>',
};

const Icons = {
  cache: {},

  svg(name, cls) {
    return `<svg class="ui-ico ${cls || ''}" viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">${UI_SVG[name] || ''}</svg>`;
  },

  // Значок класса жителей: цветной кружок с белым рисунком
  cls(cls, size) {
    const glyph = { plebs: 'wheat', citizens: 'hammer', patricians: 'laurel' }[cls];
    return `<span class="cls-badge" style="--c:${CLASSES[cls].color};${size ? `--s:${size}px` : ''}" title="${CLASSES[cls].name}">${this.svg(glyph)}</span>`;
  },

  get(id) {
    if (this.cache[id]) return this.cache[id];
    const S = 64;
    const cv = document.createElement('canvas');
    cv.width = cv.height = S;
    const c = cv.getContext('2d');
    c.lineCap = 'round';
    c.lineJoin = 'round';
    const draw = this.draw[id];
    if (draw) draw(c, S);
    return (this.cache[id] = cv.toDataURL('image/png'));
  },

  img(id, cls) {
    return `<img class="ico ${cls || ''}" src="${this.get(id)}" alt="" aria-hidden="true">`;
  },

  draw: {
    money(c) {
      c.fillStyle = '#9c741c'; c.beginPath(); c.arc(32, 33, 25, 0, 7); c.fill();
      c.fillStyle = '#e8bd4e'; c.beginPath(); c.arc(32, 31, 24, 0, 7); c.fill();
      c.strokeStyle = '#b88c2a'; c.lineWidth = 3; c.beginPath(); c.arc(32, 31, 16, 0, 7); c.stroke();
      c.fillStyle = '#a77a1e'; c.font = 'bold 20px Georgia, serif'; c.textAlign = 'center'; c.fillText('D', 32, 38);
    },
    people(c) {
      c.fillStyle = '#8a6a50';
      c.beginPath(); c.arc(24, 20, 10, 0, 7); c.fill();
      c.beginPath(); c.moveTo(6, 58); c.quadraticCurveTo(8, 34, 24, 34); c.quadraticCurveTo(40, 34, 42, 58); c.fill();
      c.fillStyle = '#b8957a';
      c.beginPath(); c.arc(44, 24, 8, 0, 7); c.fill();
      c.beginPath(); c.moveTo(34, 58); c.quadraticCurveTo(36, 37, 44, 37); c.quadraticCurveTo(58, 37, 59, 58); c.fill();
    },
    workers(c) {
      c.strokeStyle = '#7a5a3a'; c.lineWidth = 7; c.beginPath(); c.moveTo(14, 52); c.lineTo(40, 26); c.stroke();
      c.fillStyle = '#7d7a76'; c.beginPath(); c.moveTo(30, 10); c.lineTo(56, 22); c.lineTo(48, 34); c.lineTo(26, 20); c.closePath(); c.fill();
    },
    scrolls(c) {
      c.fillStyle = '#efe1bb'; c.fillRect(14, 14, 36, 36);
      c.fillStyle = '#c9a86a'; c.beginPath(); c.ellipse(14, 32, 6, 20, 0, 0, 7); c.fill(); c.beginPath(); c.ellipse(50, 32, 6, 20, 0, 0, 7); c.fill();
      c.strokeStyle = '#8a6a44'; c.lineWidth = 2.5;
      for (let i = 0; i < 4; i++) { c.beginPath(); c.moveTo(22, 22 + i * 7); c.lineTo(42, 22 + i * 7); c.stroke(); }
      c.fillStyle = '#a3372a'; c.beginPath(); c.arc(40, 46, 5, 0, 7); c.fill();
    },
    glory(c) {
      c.strokeStyle = '#6f8f3a'; c.lineWidth = 3;
      c.beginPath(); c.arc(32, 34, 20, Math.PI * 0.7, Math.PI * 2.3); c.stroke();
      c.fillStyle = '#7fa64a';
      for (let i = 0; i < 9; i++) {
        const a = Math.PI * 0.75 + i * 0.19;
        for (const s of [-1, 1]) {
          const aa = s < 0 ? Math.PI * 3 - a : a;
          c.beginPath(); c.ellipse(32 + Math.cos(aa) * 20, 34 + Math.sin(aa) * 20, 7, 3.5, aa + 0.6 * s, 0, 7); c.fill();
        }
      }
      c.fillStyle = '#e0b040'; c.beginPath(); c.arc(32, 52, 5, 0, 7); c.fill();
    },
    wheat(c) {
      c.strokeStyle = '#a07a2a'; c.lineWidth = 3; c.beginPath(); c.moveTo(32, 60); c.lineTo(32, 18); c.stroke();
      c.fillStyle = '#e2b84a';
      c.beginPath(); c.ellipse(32, 12, 4, 7, 0, 0, 7); c.fill();
      for (let i = 0; i < 4; i++) for (const s of [-1, 1]) { c.beginPath(); c.ellipse(32 + s * 7, 22 + i * 8, 4, 7, s * 0.6, 0, 7); c.fill(); }
    },
    fish(c) {
      c.fillStyle = '#7f9fb0'; c.beginPath(); c.ellipse(28, 32, 20, 11, 0, 0, 7); c.fill();
      c.beginPath(); c.moveTo(44, 32); c.lineTo(60, 20); c.lineTo(60, 44); c.closePath(); c.fill();
      c.fillStyle = '#a9c4d0'; c.beginPath(); c.ellipse(26, 36, 14, 5, 0, 0, 7); c.fill();
      c.fillStyle = '#2a3a44'; c.beginPath(); c.arc(16, 29, 2.5, 0, 7); c.fill();
    },
    olives(c) {
      c.strokeStyle = '#6a5a3a'; c.lineWidth = 3; c.beginPath(); c.moveTo(8, 50); c.quadraticCurveTo(30, 30, 56, 14); c.stroke();
      c.fillStyle = '#93a467';
      for (const [x, y, a] of [[18, 34, -0.8], [40, 18, -0.6], [44, 30, 0.6]]) { c.beginPath(); c.ellipse(x, y, 10, 4, a, 0, 7); c.fill(); }
      c.fillStyle = '#5a6a2a';
      for (const [x, y] of [[26, 46], [36, 40], [30, 32]]) { c.beginPath(); c.ellipse(x, y, 6, 8, 0.3, 0, 7); c.fill(); }
    },
    grapes(c) {
      c.strokeStyle = '#6a5a3a'; c.lineWidth = 3; c.beginPath(); c.moveTo(32, 6); c.lineTo(32, 16); c.stroke();
      c.fillStyle = '#7fa64a'; c.beginPath(); c.ellipse(42, 12, 10, 5, -0.4, 0, 7); c.fill();
      c.fillStyle = '#7a3f86';
      const pts = [[24, 20], [32, 20], [40, 20], [28, 28], [36, 28], [20, 28], [44, 28], [24, 36], [32, 36], [40, 36], [28, 44], [36, 44], [32, 52]];
      for (const [x, y] of pts) { c.beginPath(); c.arc(x, y, 6, 0, 7); c.fill(); }
      c.fillStyle = 'rgba(255,255,255,0.3)';
      for (const [x, y] of pts) { c.beginPath(); c.arc(x - 2, y - 2, 2, 0, 7); c.fill(); }
    },
    bread(c) {
      c.fillStyle = '#b8743a'; c.beginPath(); c.ellipse(32, 36, 26, 17, 0, 0, 7); c.fill();
      c.fillStyle = '#d99a52'; c.beginPath(); c.ellipse(32, 32, 24, 14, 0, 0, 7); c.fill();
      c.strokeStyle = '#a5622a'; c.lineWidth = 3;
      for (let i = 0; i < 4; i++) { c.beginPath(); c.moveTo(18 + i * 9, 24); c.lineTo(22 + i * 9, 40); c.stroke(); }
    },
    oil(c) {
      c.fillStyle = '#c98a5a';
      c.beginPath(); c.moveTo(32, 60); c.quadraticCurveTo(10, 44, 20, 22); c.lineTo(44, 22); c.quadraticCurveTo(54, 44, 32, 60); c.fill();
      c.fillRect(26, 10, 12, 14);
      c.strokeStyle = '#a5683e'; c.lineWidth = 3; c.beginPath(); c.arc(20, 22, 7, Math.PI * 0.5, Math.PI * 1.5); c.stroke(); c.beginPath(); c.arc(44, 22, 7, Math.PI * 1.5, Math.PI * 0.5); c.stroke();
      c.fillStyle = '#c9b43a'; c.beginPath(); c.moveTo(48, 40); c.quadraticCurveTo(58, 52, 50, 56); c.quadraticCurveTo(42, 52, 48, 40); c.fill();
    },
    wine(c) {
      c.fillStyle = '#8a2a3a';
      c.beginPath(); c.moveTo(16, 14); c.lineTo(48, 14); c.quadraticCurveTo(48, 40, 32, 40); c.quadraticCurveTo(16, 40, 16, 14); c.fill();
      c.fillStyle = '#c9a050'; c.fillRect(30, 40, 4, 12); c.fillRect(20, 52, 24, 5);
      c.fillStyle = 'rgba(255,255,255,0.25)'; c.fillRect(20, 16, 5, 16);
    },
    wood(c) {
      c.fillStyle = '#8a5f3c';
      c.fillRect(8, 22, 44, 14); c.fillRect(14, 38, 44, 14);
      c.fillStyle = '#d8b68a';
      c.beginPath(); c.ellipse(52, 29, 6, 7, 0, 0, 7); c.fill(); c.beginPath(); c.ellipse(58, 45, 6, 7, 0, 0, 7); c.fill();
      c.strokeStyle = '#a07a52'; c.lineWidth = 1.5; c.beginPath(); c.arc(52, 29, 3, 0, 7); c.stroke(); c.beginPath(); c.arc(58, 45, 3, 0, 7); c.stroke();
    },
    stone(c) {
      c.fillStyle = '#9a9488'; c.beginPath(); c.moveTo(8, 46); c.lineTo(16, 20); c.lineTo(40, 12); c.lineTo(58, 28); c.lineTo(52, 52); c.lineTo(20, 56); c.closePath(); c.fill();
      c.fillStyle = '#bdb6a8'; c.beginPath(); c.moveTo(16, 20); c.lineTo(40, 12); c.lineTo(58, 28); c.lineTo(32, 32); c.closePath(); c.fill();
    },
    clay(c) {
      c.fillStyle = '#9c6a48'; c.beginPath(); c.ellipse(32, 40, 26, 16, 0, 0, 7); c.fill();
      c.fillStyle = '#b8845e'; c.beginPath(); c.ellipse(28, 34, 18, 10, -0.2, 0, 7); c.fill();
    },
    bricks(c) {
      const b = (x, y, col) => { c.fillStyle = col; c.fillRect(x, y, 22, 11); c.fillStyle = 'rgba(0,0,0,0.15)'; c.fillRect(x, y + 9, 22, 2); };
      b(8, 42, '#b5654a'); b(32, 42, '#a8583e'); b(20, 30, '#c97b5c'); b(44, 30, '#b5654a'); b(14, 18, '#a8583e'); b(36, 18, '#c97b5c');
    },
    marble(c) {
      c.fillStyle = '#d9d4c8'; c.beginPath(); c.moveTo(10, 24); c.lineTo(36, 12); c.lineTo(56, 22); c.lineTo(56, 46); c.lineTo(30, 56); c.lineTo(10, 46); c.closePath(); c.fill();
      c.fillStyle = '#f5f2ea'; c.beginPath(); c.moveTo(10, 24); c.lineTo(36, 12); c.lineTo(56, 22); c.lineTo(30, 34); c.closePath(); c.fill();
      c.strokeStyle = '#a9b0b8'; c.lineWidth = 1.5; c.beginPath(); c.moveTo(20, 40); c.quadraticCurveTo(28, 36, 26, 48); c.stroke(); c.beginPath(); c.moveTo(40, 38); c.quadraticCurveTo(46, 44, 50, 40); c.stroke();
    },
    iron(c) {
      c.fillStyle = '#4e4a48'; c.beginPath(); c.moveTo(8, 44); c.lineTo(16, 28); c.lineTo(56, 28); c.lineTo(58, 44); c.closePath(); c.fill();
      c.fillStyle = '#7a7470'; c.beginPath(); c.moveTo(16, 28); c.lineTo(22, 20); c.lineTo(52, 20); c.lineTo(56, 28); c.closePath(); c.fill();
    },
    weapons(c) {
      c.strokeStyle = '#d8dadc'; c.lineWidth = 7; c.beginPath(); c.moveTo(14, 50); c.lineTo(50, 14); c.stroke();
      c.strokeStyle = '#a9adb2'; c.lineWidth = 2; c.beginPath(); c.moveTo(16, 46); c.lineTo(48, 14); c.stroke();
      c.strokeStyle = '#c9a050'; c.lineWidth = 6; c.beginPath(); c.moveTo(10, 40); c.lineTo(24, 54); c.stroke();
      c.strokeStyle = '#6e4a2f'; c.lineWidth = 6; c.beginPath(); c.moveTo(14, 50); c.lineTo(6, 58); c.stroke();
    },
    legion(c) {
      c.fillStyle = '#b88c2a'; c.beginPath(); c.arc(32, 36, 18, Math.PI, 0); c.lineTo(50, 46); c.lineTo(14, 46); c.closePath(); c.fill();
      c.fillStyle = '#a3372a'; c.beginPath(); c.ellipse(32, 14, 18, 7, 0, Math.PI, 0); c.fill(); c.fillRect(30, 12, 4, 8);
      c.fillStyle = '#8a6a1a'; c.fillRect(14, 44, 10, 12); c.fillRect(40, 44, 10, 12);
    },
    research(c) { Icons.draw.scrolls(c); },
    store(c) {
      Icons.draw.oil(c);
    },
    water(c) {
      const g = c.createLinearGradient(20, 8, 44, 58);
      g.addColorStop(0, '#9fd4ec'); g.addColorStop(1, '#3f8fb8');
      c.fillStyle = g;
      c.beginPath(); c.moveTo(32, 6); c.bezierCurveTo(40, 22, 52, 32, 52, 42); c.arc(32, 42, 20, 0, Math.PI); c.bezierCurveTo(12, 32, 24, 22, 32, 6); c.fill();
      c.fillStyle = 'rgba(255,255,255,0.6)'; c.beginPath(); c.ellipse(25, 42, 4, 8, -0.3, 0, 7); c.fill();
    },
    temple(c) {
      c.fillStyle = '#c4553f'; c.beginPath(); c.moveTo(6, 22); c.lineTo(32, 8); c.lineTo(58, 22); c.closePath(); c.fill();
      c.fillStyle = '#efe7d6'; c.fillRect(8, 22, 48, 5); c.fillRect(6, 50, 52, 6);
      for (let i = 0; i < 5; i++) { c.fillStyle = '#f6f1e6'; c.fillRect(11 + i * 10, 27, 6, 23); c.fillStyle = '#d6cdbb'; c.fillRect(14 + i * 10, 27, 3, 23); }
    },
    baths(c) {
      c.fillStyle = '#c97b5c'; c.fillRect(8, 36, 48, 20);
      c.fillStyle = '#c5d0cc'; c.beginPath(); c.arc(32, 36, 16, Math.PI, 0); c.fill();
      c.fillStyle = '#3e5f6c'; for (let i = 0; i < 4; i++) { c.beginPath(); c.arc(14 + i * 12, 47, 3.5, Math.PI, 0); c.fill(); c.fillRect(10.5 + i * 12, 47, 7, 6); }
      c.strokeStyle = 'rgba(255,255,255,0.85)'; c.lineWidth = 3;
      for (let i = 0; i < 3; i++) { c.beginPath(); c.moveTo(22 + i * 10, 16); c.bezierCurveTo(18 + i * 10, 11, 26 + i * 10, 7, 22 + i * 10, 2); c.stroke(); }
    },
    theatre(c) {
      c.fillStyle = '#f1e6c8'; c.beginPath(); c.ellipse(28, 30, 18, 21, -0.15, 0, 7); c.fill();
      c.fillStyle = '#4a3a2a'; c.beginPath(); c.ellipse(21, 26, 4, 3, 0, 0, 7); c.fill(); c.beginPath(); c.ellipse(34, 24, 4, 3, 0, 0, 7); c.fill();
      c.strokeStyle = '#4a3a2a'; c.lineWidth = 3; c.beginPath(); c.arc(28, 36, 8, 0.2, Math.PI - 0.2); c.stroke();
      c.fillStyle = '#c9a050'; c.beginPath(); c.ellipse(44, 42, 13, 15, 0.3, 0, 7); c.fill();
      c.fillStyle = '#4a3a2a'; c.beginPath(); c.ellipse(40, 40, 3, 2.2, 0, 0, 7); c.fill(); c.beginPath(); c.ellipse(49, 43, 3, 2.2, 0, 0, 7); c.fill();
      c.strokeStyle = '#4a3a2a'; c.beginPath(); c.arc(44, 54, 6, Math.PI + 0.3, -0.3); c.stroke();
    },
    happy(c) {
      c.fillStyle = '#e8b54a'; c.beginPath(); c.arc(32, 32, 24, 0, 7); c.fill();
      c.fillStyle = '#f3cf6a'; c.beginPath(); c.arc(29, 28, 18, 0, 7); c.fill();
      c.strokeStyle = '#7a4a1a'; c.lineWidth = 4;
      c.beginPath(); c.arc(32, 34, 12, 0.2, Math.PI - 0.2); c.stroke();
      c.fillStyle = '#7a4a1a'; c.beginPath(); c.arc(24, 26, 3.2, 0, 7); c.fill(); c.beginPath(); c.arc(40, 26, 3.2, 0, 7); c.fill();
    },
    book(c) {
      c.fillStyle = '#7a4a2a'; c.fillRect(10, 12, 44, 42);
      c.fillStyle = '#f2e6c8'; c.fillRect(14, 10, 18, 40); c.fillRect(32, 10, 18, 40);
      c.strokeStyle = '#b89a6a'; c.lineWidth = 2;
      for (let i = 0; i < 5; i++) { c.beginPath(); c.moveTo(17, 17 + i * 6); c.lineTo(29, 17 + i * 6); c.stroke(); c.beginPath(); c.moveTo(35, 17 + i * 6); c.lineTo(47, 17 + i * 6); c.stroke(); }
      c.fillStyle = '#a3372a'; c.fillRect(30, 8, 4, 46);
    },
    tablet(c) {
      c.fillStyle = '#8a5f3a'; c.fillRect(8, 10, 48, 44);
      c.fillStyle = '#4a3a2a'; c.fillRect(13, 15, 38, 34);
      c.strokeStyle = '#c9a86a'; c.lineWidth = 2.5;
      for (let i = 0; i < 4; i++) { c.beginPath(); c.moveTo(18, 22 + i * 7); c.lineTo(46 - (i % 2) * 8, 22 + i * 7); c.stroke(); }
      c.strokeStyle = '#d9c39b'; c.lineWidth = 3; c.beginPath(); c.moveTo(46, 52); c.lineTo(58, 36); c.stroke();
    },
    emblem(c) {
      c.fillStyle = '#a3372a'; c.beginPath(); c.arc(32, 32, 29, 0, 7); c.fill();
      c.strokeStyle = '#e3b445'; c.lineWidth = 2.5; c.beginPath(); c.arc(32, 32, 25, 0, 7); c.stroke();
      c.fillStyle = '#c9d77a';
      for (let i = 0; i < 7; i++) for (const s of [-1, 1]) {
        const a = Math.PI / 2 + s * (0.5 + i * 0.27);
        c.beginPath(); c.ellipse(32 + Math.cos(a) * 19, 32 + Math.sin(a) * 19, 5, 2.4, a + s * 1.1, 0, 7); c.fill();
      }
      c.fillStyle = '#f6e8c4'; c.font = '900 13px Georgia, serif'; c.textAlign = 'center'; c.fillText('SPQR', 32, 37);
    },
    advisor(c) {
      const g = c.createRadialGradient(32, 26, 4, 32, 32, 34);
      g.addColorStop(0, '#c4553f'); g.addColorStop(1, '#8a2a20');
      c.fillStyle = g; c.beginPath(); c.arc(32, 32, 31, 0, 7); c.fill();
      c.save(); c.beginPath(); c.arc(32, 32, 30, 0, 7); c.clip();
      // тога
      c.fillStyle = '#f4efe2'; c.beginPath(); c.moveTo(6, 64); c.quadraticCurveTo(14, 44, 32, 44); c.quadraticCurveTo(50, 44, 58, 64); c.fill();
      c.strokeStyle = '#7a2a6a'; c.lineWidth = 3; c.beginPath(); c.moveTo(18, 64); c.quadraticCurveTo(24, 50, 40, 46); c.stroke();
      // шея и голова
      c.fillStyle = '#e2b48c'; c.fillRect(27, 36, 10, 10);
      c.beginPath(); c.ellipse(32, 27, 11, 13, 0, 0, 7); c.fill();
      c.beginPath(); c.moveTo(42, 26); c.lineTo(46, 31); c.lineTo(42, 32); c.fill();
      // волосы и лавры
      c.fillStyle = '#d8d2c4'; c.beginPath(); c.ellipse(30, 18, 11, 6, -0.1, Math.PI, 0); c.fill();
      c.fillStyle = '#7fa64a';
      for (let i = 0; i < 6; i++) { const a = Math.PI * 1.05 + i * 0.32; c.beginPath(); c.ellipse(32 + Math.cos(a) * 12, 22 + Math.sin(a) * 9, 4, 2, a + 1.2, 0, 7); c.fill(); }
      // глаз, бровь, улыбка
      c.fillStyle = '#3a2a20'; c.beginPath(); c.arc(37, 25, 1.6, 0, 7); c.fill();
      c.strokeStyle = '#8a6a5a'; c.lineWidth = 1.5; c.beginPath(); c.moveTo(34, 21.5); c.lineTo(40, 21); c.stroke();
      c.strokeStyle = '#a0624a'; c.beginPath(); c.arc(37, 33, 3.5, 0.2, 1.4); c.stroke();
      c.restore();
      c.strokeStyle = '#e3b445'; c.lineWidth = 3; c.beginPath(); c.arc(32, 32, 30, 0, 7); c.stroke();
    },
  },
};
