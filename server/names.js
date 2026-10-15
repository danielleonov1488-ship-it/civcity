'use strict';
// Название города: проверки, общие с игрой (godot/scripts/city_name.gd — те же строки-списки и те же шаги;
// test_pvp.js сверяет, что списки в двух файлах не разошлись).
//
// Грубые слова: корни русского мата и английской брани. Перед сверкой название приводится к нескольким видам:
// строчные буквы, ё→е; латиница-«двойники» → кириллица (XYЙ), транслит → кириллица (huy, pizda),
// кириллица-«двойники» и цифры → латиница (для английских корней); цифры внутри слов выкидываются,
// повторы букв схлопываются, а слова из одной-двух букв склеиваются с соседями («х у й», «ху-йня»).
// Длинные слова между собой не склеиваются: «Дух уединения» — не «духуединения».

// корни: *_WORD — только в начале слова (сабля, барсука, Скипидар — не грубость), остальные — в любом месте
const RUDE_RU = 'хуй хуе хуя хуи пизд пезд бляд блят ебан ебат ебал ебло ебуч ебну уебищ мудак мудил мудач пидор пидр пидарас залуп гандон гондон шлюх дроч жоп говн мраз шалав';
const RUDE_RU_WORD = 'еб бля сука сукин заеб наеб выеб въеб отъеб съеб поеб доеб долбоеб пидар';
const RUDE_EN = 'fuck shit cunt bitch whore pusy ashole porn twat';
const RUDE_EN_WORD = 'dick cock slut wank';
// латинские буквы и цифры, похожие на русские
const LOOK = 'a=а b=в c=с e=е h=н k=к m=м n=п o=о p=р r=г t=т u=и x=х y=у 0=о 3=з 4=ч 6=б @=а';
// транслит (сначала длинные сочетания)
const TRANS = 'shch=щ sch=щ zh=ж kh=х ch=ч sh=ш ts=ц ya=я yu=ю yo=е ye=е a=а b=б c=с d=д e=е f=ф g=г h=х i=и j=й k=к l=л m=м n=н o=о p=п q=к r=р s=с t=т u=у v=в w=в x=х y=й z=з';
// русские буквы и цифры, похожие на латинские
const LAT = 'а=a в=b с=c е=e н=h к=k м=m о=o р=p т=t у=y х=x и=u п=n г=r ь=b 0=o 1=i 3=e 4=a 5=s 7=t 8=b @=a $=s';

const pairs = s => s.split(' ').map(t => t.split('='));
const LOOK_P = pairs(LOOK), TRANS_P = pairs(TRANS), LAT_P = pairs(LAT);
const RU = { any: RUDE_RU.split(' '), word: RUDE_RU_WORD.split(' ') };
const EN = { any: RUDE_EN.split(' '), word: RUDE_EN_WORD.split(' ') };

// посимвольная замена (ключи — по одному знаку)
function swap(t, ps) {
  const m = new Map(ps);
  let o = '';
  for (const ch of t) o += m.has(ch) ? m.get(ch) : ch;
  return o;
}

// транслит: на каждом месте — первое подходящее сочетание из списка
function translit(t) {
  let o = '';
  let i = 0;
  while (i < t.length) {
    let hit = false;
    for (const [k, v] of TRANS_P) {
      if (t.startsWith(k, i)) { o += v; i += k.length; hit = true; break; }
    }
    if (!hit) { o += t[i]; i++; }
  }
  return o;
}

// повторы букв подряд — одной буквой
function squash(w) {
  let o = '';
  for (const ch of w) if (o === '' || o[o.length - 1] !== ch) o += ch;
  return o;
}

// слова (буквы a–z, а–я; цифры выкидываются, остальное разделяет) и склейки коротких слов с соседями
function chunks(t) {
  const words = [];
  let cur = '';
  for (const ch of t) {
    if ((ch >= 'a' && ch <= 'z') || (ch >= 'а' && ch <= 'я')) cur += ch;
    else if (ch >= '0' && ch <= '9') continue;
    else { if (cur !== '') words.push(squash(cur)); cur = ''; }
  }
  if (cur !== '') words.push(squash(cur));
  const glued = [];
  for (let i = 0; i < words.length; i++) {
    if (glued.length && (words[i].length <= 2 || words[i - 1].length <= 2)) glued[glued.length - 1] += words[i];
    else glued.push(words[i]);
  }
  return words.concat(glued.map(squash));
}

function hits(t, roots) {
  for (const c of chunks(t)) {
    if (roots.any.some(r => c.includes(r)) || roots.word.some(r => c.startsWith(r))) return true;
  }
  return false;
}

// грубое ли название
function rude(s) {
  const t = String(s || '').toLowerCase().replace(/ё/g, 'е');
  return hits(swap(t, LOOK_P), RU) || hits(translit(t), RU) || hits(swap(t, LAT_P), EN);
}

module.exports = { rude, RUDE_RU, RUDE_RU_WORD, RUDE_EN, RUDE_EN_WORD, LOOK, TRANS, LAT };
