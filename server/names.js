'use strict';
// Название города: проверки, общие с игрой (godot/scripts/city_name.gd — те же строки-списки и те же шаги;
// test_pvp.js сверяет, что списки в двух файлах не разошлись, а примеры из names_cases.json проходят обе стороны).
//
// Грубые слова: корни русского мата и английской брани. Перед сверкой название приводится к нескольким видам:
// строчные буквы, ё→е, украинские и латинские буквы с надстрочными знаками → обычные (і→и, ý→y);
// целые безобидные латинские слова (Pueblo, Lebanon) выкидываются; латиница-«двойники» и цифры → кириллица
// (XYЙ, П1зда), транслит → кириллица (huy, pizda), кириллица-«двойники» и цифры → латиница (для английских корней).
// Слова: дефис, апостроф, точка и цифры слово не рвут («Пиз-дец», «ПИЗ.ДЕЦ»), повторы букв схлопываются, слова из
// одной-двух букв склеиваются с соседями («х у й», «ху-йня»). Длинные слова между собой не склеиваются («Дух уединения» —
// не «духуединения»); через пробел целиком сверяются лишь корни *_JOIN, которые случайно на стыке слов не встают
// («Пиз Дец», «Пидо Рас», но «Хлеб Алтая», «Степи Дорог», «Рубля дом» — можно).

// корни: *_WORD — только в начале слова (сабля, барсука, Скипидар, Опорный — не грубость), остальные — в любом месте
const RUDE_RU = 'хуй хуе хуя хуи пизд пезд бляд блят ебан ебат ебал ебло ебуч ебну уебищ мудак мудил мудач пидор пидр пидарас залуп гандон гондон шлюх дроч жоп говн мраз шалав';
const RUDE_RU_WORD = 'еб бля сука сукин заеб наеб выеб въеб отъеб съеб поеб доеб долбоеб пидар уеб порн';
const RUDE_EN = 'fuck shit cunt bitch whore pusy ashole porn twat';
const RUDE_EN_WORD = 'dick cock slut wank';
// корни, которые ищутся и во всём названии без пробелов
const RUDE_RU_JOIN = 'пизд пезд залуп шлюх уебищ долбоеб мудак пидорас пидарас';
const RUDE_EN_JOIN = 'fuck cunt bitch whore';
// украинские буквы и буквы с надстрочными знаками → обычные
const EXTRA = 'і=и ї=и є=е ў=у ґ=г á=a à=a â=a ä=a ã=a å=a é=e è=e ê=e ë=e í=i ì=i î=i ï=i ó=o ò=o ô=o ö=o õ=o ø=o ú=u ù=u û=u ü=u ý=y ÿ=y ç=c ñ=n';
// безобидные латинские слова, в которых транслит или английский корень находят брань (только целым словом)
const SAFE_LAT = 'pueblo lebanon ebony eboracum ebusus eboli huesca huelva scunthorpe dickinson cockermouth';
// латинские буквы и цифры, похожие на русские
const LOOK = 'a=а b=в c=с e=е h=н k=к m=м n=п o=о p=р r=г t=т u=и x=х y=у 0=о 1=и 3=з 4=ч 6=б 9=я @=а';
// транслит (сначала длинные сочетания)
const TRANS = 'shch=щ sch=щ zh=ж kh=х ch=ч sh=ш ts=ц ya=я yu=ю yo=е ye=е a=а b=б c=с d=д e=е f=ф g=г h=х i=и j=й k=к l=л m=м n=н o=о p=п q=к r=р s=с t=т u=у v=в w=в x=х y=й z=з';
// русские буквы и цифры, похожие на латинские
const LAT = 'а=a в=b с=c е=e н=h к=k м=m о=o р=p т=t у=y х=x и=u п=n г=r ь=b 0=o 1=i 3=e 4=a 5=s 7=t 8=b @=a $=s';

const pairs = s => s.split(' ').map(t => t.split('='));
const EXTRA_P = pairs(EXTRA), LOOK_P = pairs(LOOK), TRANS_P = pairs(TRANS), LAT_P = pairs(LAT);
const RU = { any: RUDE_RU.split(' '), word: RUDE_RU_WORD.split(' '), join: RUDE_RU_JOIN.split(' ') };
const EN = { any: RUDE_EN.split(' '), word: RUDE_EN_WORD.split(' '), join: RUDE_EN_JOIN.split(' ') };
const SAFE_RE = new RegExp('(^|[^a-z])(' + SAFE_LAT.split(' ').join('|') + ')(?=$|[^a-z])', 'g');
const LETTER = /\p{L}/u;
const KEEP = "-'’.";                 // внутри слова: слово не рвут (как цифры)

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

const len = w => [...w].length;

// слова и куски для сверки: части (их делит любой не-буквенный знак, цифры выкидываются), склейки коротких частей
// с соседями и слова целиком (дефис, апостроф, точка их не делят: «Пиз-дец» → «пиздец»)
function chunks(t) {
  const words = [], whole = [];
  let cur = '', wcur = '';
  for (const ch of t) {
    if (LETTER.test(ch)) { cur += ch; wcur += ch; continue; }
    if (ch >= '0' && ch <= '9') continue;
    if (cur !== '') words.push(squash(cur));
    cur = '';
    if (KEEP.includes(ch)) continue;
    if (wcur !== '') whole.push(squash(wcur));
    wcur = '';
  }
  if (cur !== '') words.push(squash(cur));
  if (wcur !== '') whole.push(squash(wcur));
  const glued = [];
  for (let i = 0; i < words.length; i++) {
    if (glued.length && (len(words[i]) <= 2 || len(words[i - 1]) <= 2)) glued[glued.length - 1] += words[i];
    else glued.push(words[i]);
  }
  return words.concat(glued.map(squash), whole);
}

// всё название одной строкой: только буквы a–z, а–я
function joined(t) {
  let o = '';
  for (const ch of t) if ((ch >= 'a' && ch <= 'z') || (ch >= 'а' && ch <= 'я')) o += ch;
  return squash(o);
}

function hits(t, roots) {
  for (const c of chunks(t)) {
    if (roots.any.some(r => c.includes(r)) || roots.word.some(r => c.startsWith(r))) return true;
  }
  const j = joined(t);
  return roots.join.some(r => j.includes(r));
}

// грубое ли название
function rude(s) {
  let t = swap(String(s || '').toLowerCase().replace(/ё/g, 'е'), EXTRA_P);
  t = t.replace(SAFE_RE, '$1 ');
  return hits(swap(t, LOOK_P), RU) || hits(translit(t), RU) || hits(swap(t, LAT_P), EN);
}

module.exports = { rude, RUDE_RU, RUDE_RU_WORD, RUDE_EN, RUDE_EN_WORD, RUDE_RU_JOIN, RUDE_EN_JOIN, EXTRA, SAFE_LAT, LOOK, TRANS, LAT };
