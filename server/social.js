'use strict';
/* Друзья и гости («Уютный Рим», этап 6 — онлайн-уют, docs/ONLINE_V2.md). Мягкий онлайн без драк:

   - Карточка города (PUT /api/social/card): население, ранг, почётный титул, известность, лучшие достопримечательности,
     имя своего героя. Её шлёт игра сама (раз в несколько минут, если поменялась). Название города — общее с боями
     (pvp_players.name: табличка, таблица лучших); здесь его не меняют.
   - Друзья (POST /api/social/friend {name} / unfriend {id}): по названию города, в одну сторону, до FRIENDS_MAX.
     Кого вы добавили — оттуда к вам приезжают гости; кто добавил вас — видно числом («вас добавили в друзья: N»).
   - Гости (GET /api/social/state → guests): до GUESTS городов — сначала друзья, потом случайные живые города с карточкой.
     Игра одевает по ним туристов («гость из Колонии Юлия») и платит за них больше; о том, что гости из её города
     у кого-то побывали, город узнаёт (POST /api/social/visited {ids} → у города-источника visits) — это известность.
     Засчитываются только города из последнего выданного списка гостей и не чаще раза в сутки на пару городов.
   - Подарки (POST /api/social/gift {id, kind}): кошка или украшение (GIFTS) — другу или любому городу, GIFT_DAY в сутки,
     одному городу — раз в сутки. Получатель видит их в state.inbox и забирает (POST /api/social/claim {ids}): игра
     ставит украшение даром или приводит кошку. Подарок забирают один раз.
   - В гости (GET /api/social/city?id= или ?name=): карточка и последний город из облака (rome2) — игра открывает его
     только посмотреть (ничего не строится и не сохраняется). «Нравится» (POST /api/social/like {id}) — раз в сутки.
   Почты и прочих личных данных здесь нет: города знают друг друга только по названию и имени героя. */

const FRIENDS_MAX = 30;
const GUESTS = 8;
const GIFT_DAY = 3;
const VISIT_DAY = 12;                 // скольким городам за сутки можно засчитать своих гостей
const ACTIVE = 30 * 864e5;            // карточка свежее месяца — город живой
const OFFER_TTL = 6 * 3600e3;         // список гостей живёт полдня (дольше — засчитывать по нему не будем)
const CARD_MAX = 4000;
const DAY = 864e5;
// подарки: kind → что это для получателя (игра знает, что с ним делать: cat — кошка приходит в дом с любовью к кошкам,
// остальное — украшение этого вида даром)
const GIFTS = {
  cat: 'кошка',
  flowers: 'цветочные вазоны',
  bench: 'скамья',
  amphorae: 'амфоры',
  statue: 'статуя',
  fountain: 'фонтанчик',
};

const int = v => (Number.isFinite(+v) ? Math.trunc(+v) : 0);
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const today = () => Math.floor(Date.now() / DAY);
const nameKey = s => String(s).toLowerCase().replace(/ё/g, 'е').replace(/\s+/g, ' ').trim();
const str = (v, n) => String(v == null ? '' : v).replace(/[\u0000-\u001f\u007f]/g, '').slice(0, n);

// карточка от игры → только известные поля, короткие строки и разумные числа
function cleanCard(c) {
  if (!c || typeof c !== 'object' || Array.isArray(c)) return null;
  const out = {
    pop: clamp(int(c.pop), 0, 1e6),
    level: clamp(int(c.level), 0, 7),
    rank: str(c.rank, 40),
    title: str(c.title, 40),
    fame: clamp(int(c.fame), 0, 1e9),
    beauty: clamp(int(c.beauty), 0, 1e6),
    day: clamp(int(c.day), 0, 1e7),
    hero: str(c.hero, 40),
    cats: clamp(int(c.cats), 0, 9999),
    inns: clamp(int(c.inns), 0, 999),
    sights: Array.isArray(c.sights) ? c.sights.slice(0, 6).map(s => str(s, 40)).filter(Boolean) : [],
  };
  return JSON.stringify(out).length > CARD_MAX ? null : out;
}

function install({ db, routes, auth, json, limited, Fail, latestSave, pvpPlayer }) {
  db.exec(`
    CREATE TABLE IF NOT EXISTS social_cards (
      user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
      card TEXT NOT NULL,
      updated INTEGER NOT NULL,
      likes INTEGER NOT NULL DEFAULT 0,
      visits INTEGER NOT NULL DEFAULT 0,
      seen_likes INTEGER NOT NULL DEFAULT 0,
      seen_visits INTEGER NOT NULL DEFAULT 0
    );
    CREATE INDEX IF NOT EXISTS social_cards_upd ON social_cards(updated);
    CREATE TABLE IF NOT EXISTS social_friends (
      user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      friend_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      created INTEGER NOT NULL,
      PRIMARY KEY (user_id, friend_id)
    );
    CREATE INDEX IF NOT EXISTS social_friends_back ON social_friends(friend_id);
    CREATE TABLE IF NOT EXISTS social_gifts (
      n INTEGER PRIMARY KEY,
      from_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
      to_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      from_name TEXT NOT NULL,
      kind TEXT NOT NULL,
      day INTEGER NOT NULL,
      created INTEGER NOT NULL,
      claimed INTEGER NOT NULL DEFAULT 0
    );
    CREATE INDEX IF NOT EXISTS social_gifts_to ON social_gifts(to_id, claimed);
    CREATE INDEX IF NOT EXISTS social_gifts_from ON social_gifts(from_id, day);
    CREATE TABLE IF NOT EXISTS social_marks (
      day INTEGER NOT NULL,
      kind TEXT NOT NULL,
      from_id INTEGER NOT NULL,
      to_id INTEGER NOT NULL,
      PRIMARY KEY (day, kind, from_id, to_id)
    );
  `);

  const q = {
    card: db.prepare('SELECT * FROM social_cards WHERE user_id = ?'),
    setCard: db.prepare(`INSERT INTO social_cards (user_id, card, updated) VALUES (?, ?, ?)
      ON CONFLICT(user_id) DO UPDATE SET card = excluded.card, updated = excluded.updated`),
    seen: db.prepare('UPDATE social_cards SET seen_likes = likes, seen_visits = visits WHERE user_id = ?'),
    like: db.prepare('UPDATE social_cards SET likes = likes + 1 WHERE user_id = ?'),
    visit: db.prepare('UPDATE social_cards SET visits = visits + 1 WHERE user_id = ?'),
    byKey: db.prepare('SELECT user_id, name FROM pvp_players WHERE name_key = ?'),
    nameOf: db.prepare('SELECT name FROM pvp_players WHERE user_id = ?'),
    find: db.prepare(`SELECT p.user_id, p.name, c.card, c.updated, c.likes FROM pvp_players p JOIN social_cards c ON c.user_id = p.user_id
      WHERE p.name_key LIKE ? ESCAPE '\\' AND p.user_id != ? ORDER BY c.updated DESC LIMIT 10`),
    friends: db.prepare(`SELECT f.friend_id AS id, p.name, c.card, c.updated, c.likes FROM social_friends f
      LEFT JOIN pvp_players p ON p.user_id = f.friend_id LEFT JOIN social_cards c ON c.user_id = f.friend_id
      WHERE f.user_id = ? ORDER BY f.created ASC`),
    friendN: db.prepare('SELECT COUNT(*) AS n FROM social_friends WHERE user_id = ?'),
    followers: db.prepare('SELECT COUNT(*) AS n FROM social_friends WHERE friend_id = ?'),
    isFriend: db.prepare('SELECT 1 AS y FROM social_friends WHERE user_id = ? AND friend_id = ?'),
    addFriend: db.prepare('INSERT OR IGNORE INTO social_friends (user_id, friend_id, created) VALUES (?, ?, ?)'),
    dropFriend: db.prepare('DELETE FROM social_friends WHERE user_id = ? AND friend_id = ?'),
    randomLive: db.prepare(`SELECT c.user_id AS id, p.name, c.card FROM social_cards c JOIN pvp_players p ON p.user_id = c.user_id
      WHERE c.user_id != ? AND c.updated > ? ORDER BY RANDOM() LIMIT ?`),
    inbox: db.prepare('SELECT n, from_id, from_name, kind, created FROM social_gifts WHERE to_id = ? AND claimed = 0 ORDER BY n ASC LIMIT 30'),
    giftsToday: db.prepare('SELECT COUNT(*) AS n FROM social_gifts WHERE from_id = ? AND day = ?'),
    giftedPair: db.prepare('SELECT 1 AS y FROM social_gifts WHERE from_id = ? AND to_id = ? AND day = ?'),
    addGift: db.prepare('INSERT INTO social_gifts (from_id, to_id, from_name, kind, day, created) VALUES (?, ?, ?, ?, ?, ?)'),
    claim: db.prepare('UPDATE social_gifts SET claimed = ? WHERE n = ? AND to_id = ? AND claimed = 0'),
    mark: db.prepare('INSERT OR IGNORE INTO social_marks (day, kind, from_id, to_id) VALUES (?, ?, ?, ?)'),
    marksDay: db.prepare('SELECT COUNT(*) AS n FROM social_marks WHERE day = ? AND kind = ? AND from_id = ?'),
    oldMarks: db.prepare('DELETE FROM social_marks WHERE day < ?'),
  };

  function tx(fn) {
    db.exec('BEGIN IMMEDIATE');
    try { const r = fn(); db.exec('COMMIT'); return r; } catch (e) { try { db.exec('ROLLBACK'); } catch (e2) { /* */ } throw e; }
  }

  const parse = s => { try { return JSON.parse(s); } catch (e) { return null; } };
  const nameOf = uid => { pvpPlayer(uid); const r = q.nameOf.get(uid); return r ? r.name : '?'; };
  const live = t => !!t && Date.now() - t < ACTIVE;
  function cityOut(r) {
    return { id: r.id !== undefined ? r.id : r.user_id, name: r.name || '?', card: r.card ? parse(r.card) : null,
      live: live(r.updated), likes: r.likes || 0 };
  }

  // выданные списки гостей: uid → {t, ids} — засчитываем только их (не любые номера от клиента)
  const offers = new Map();
  setInterval(() => {
    const now = Date.now();
    for (const [k, o] of offers) if (now - o.t > OFFER_TTL) offers.delete(k);
    try { q.oldMarks.run(today() - 3); } catch (e) { /* */ }
  }, 3600e3).unref();

  function guests(uid) {
    const now = Date.now();
    const out = [], seen = new Set([uid]);
    for (const f of q.friends.all(uid)) {
      if (out.length >= GUESTS) break;
      if (!f.card || !live(f.updated)) continue;
      out.push({ id: f.id, name: f.name || '?', hero: (parse(f.card) || {}).hero || '', friend: true });
      seen.add(f.id);
    }
    if (out.length < GUESTS) {
      for (const r of q.randomLive.all(uid, now - ACTIVE, GUESTS * 2)) {
        if (out.length >= GUESTS) break;
        if (seen.has(r.id)) continue;
        out.push({ id: r.id, name: r.name || '?', hero: (parse(r.card) || {}).hero || '', friend: false });
        seen.add(r.id);
      }
    }
    offers.set(uid, { t: now, ids: new Set(out.map(g => g.id)) });
    return out;
  }

  function findCity(uid, url) {
    const id = int(url.searchParams.get('id'));
    if (id > 0) {
      const nm = q.nameOf.get(id);
      return nm ? { id, name: nm.name } : null;
    }
    const nm = String(url.searchParams.get('name') || '');
    const r = q.byKey.get(nameKey(nm));
    return r && r.user_id !== uid ? { id: r.user_id, name: r.name } : null;
  }

  function state(uid, url) {
    const ack = url && url.searchParams.get('ack') === '1';
    let c = q.card.get(uid);
    const me = { name: nameOf(uid), card: c ? parse(c.card) : null, likes: c ? c.likes : 0, visits: c ? c.visits : 0,
      new_likes: c ? c.likes - c.seen_likes : 0, new_visits: c ? c.visits - c.seen_visits : 0,
      friends: q.friendN.get(uid).n, followers: q.followers.get(uid).n, friends_max: FRIENDS_MAX,
      gifts_left: Math.max(0, GIFT_DAY - q.giftsToday.get(uid, today()).n), gift_day: GIFT_DAY };
    if (ack && c) q.seen.run(uid);
    return {
      me,
      friends: q.friends.all(uid).map(cityOut),
      inbox: q.inbox.all(uid).map(g => ({ id: g.n, from: g.from_name, from_id: g.from_id || 0, kind: g.kind, name: GIFTS[g.kind] || g.kind,
        t: Math.floor(g.created / 1000) })),
      guests: guests(uid),
      gifts: GIFTS,
    };
  }

  /* ---------- адреса ---------- */

  routes['GET /api/social/state'] = (req, url) => {
    const a = auth(req);
    if (limited(`soc:state:${a.userId}`, 60, 600e3)) throw new Fail(429, 'Слишком часто');
    return state(a.userId, url);
  };

  routes['PUT /api/social/card'] = async (req) => {
    const a = auth(req);
    if (limited(`soc:card:${a.userId}`, 20, 600e3)) throw new Fail(429, 'Слишком часто');
    const b = await json(req);
    const card = cleanCard(b.card);
    if (!card) throw new Fail(400, 'Неверная карточка города');
    pvpPlayer(a.userId);
    q.setCard.run(a.userId, JSON.stringify(card), Date.now());
    return { ok: true };
  };

  routes['GET /api/social/find'] = (req, url) => {
    const a = auth(req);
    if (limited(`soc:find:${a.userId}`, 60, 600e3)) throw new Fail(429, 'Слишком часто — подождите минуту');
    const k = nameKey(url.searchParams.get('name') || '');
    if (k.length < 2) return { list: [] };
    const like = k.replace(/[\\%_]/g, m => '\\' + m) + '%';
    return { list: q.find.all(like, a.userId).map(r => cityOut(r)) };
  };

  routes['POST /api/social/friend'] = async (req) => {
    const a = auth(req);
    if (limited(`soc:friend:${a.userId}`, 30, 600e3)) throw new Fail(429, 'Слишком часто');
    const b = await json(req);
    const id = int(b.id);
    const r = id > 0 ? (q.nameOf.get(id) ? { user_id: id } : null) : q.byKey.get(nameKey(b.name || ''));
    if (!r) throw new Fail(404, 'Такого города нет — проверьте название');
    if (r.user_id === a.userId) throw new Fail(400, 'Это ваш город');
    if (!q.isFriend.get(a.userId, r.user_id) && q.friendN.get(a.userId).n >= FRIENDS_MAX) throw new Fail(409, `Друзей — не больше ${FRIENDS_MAX}`);
    q.addFriend.run(a.userId, r.user_id, Date.now());
    return state(a.userId);
  };

  routes['POST /api/social/unfriend'] = async (req) => {
    const a = auth(req);
    if (limited(`soc:friend:${a.userId}`, 30, 600e3)) throw new Fail(429, 'Слишком часто');
    const b = await json(req);
    q.dropFriend.run(a.userId, int(b.id));
    return state(a.userId);
  };

  // город другого игрока — посмотреть (карточка и последнее сохранение из облака)
  routes['GET /api/social/city'] = (req, url) => {
    const a = auth(req);
    if (limited(`soc:city:${a.userId}`, 20, 3600e3)) throw new Fail(429, 'Слишком часто — загляните чуть позже');
    const c = findCity(a.userId, url);
    if (!c) throw new Fail(404, 'Такого города нет');
    const card = q.card.get(c.id);
    const s = latestSave(c.id);
    const data = s ? s.load() : '';
    if (!data) throw new Fail(404, 'Этот город ещё не сохранён в облаке — в гости пока нельзя');
    return { id: c.id, name: c.name, card: card ? parse(card.card) : null, likes: card ? card.likes : 0,
      friend: !!q.isFriend.get(a.userId, c.id), liked: !!db.prepare('SELECT 1 FROM social_marks WHERE day = ? AND kind = ? AND from_id = ? AND to_id = ?').get(today(), 'like', a.userId, c.id),
      data };
  };

  routes['POST /api/social/like'] = async (req) => {
    const a = auth(req);
    if (limited(`soc:like:${a.userId}`, 30, 600e3)) throw new Fail(429, 'Слишком часто');
    const b = await json(req);
    const id = int(b.id);
    if (id === a.userId) throw new Fail(400, 'Это ваш город');
    if (!q.card.get(id)) throw new Fail(404, 'Такого города нет');
    const done = tx(() => {
      const r = q.mark.run(today(), 'like', a.userId, id);
      if (r.changes) q.like.run(id);
      return !!r.changes;
    });
    return { ok: true, liked: true, first: done, likes: q.card.get(id).likes };
  };

  routes['POST /api/social/gift'] = async (req) => {
    const a = auth(req);
    if (limited(`soc:gift:${a.userId}`, 20, 600e3)) throw new Fail(429, 'Слишком часто');
    const b = await json(req);
    const id = int(b.id), kind = String(b.kind || '');
    if (!Object.prototype.hasOwnProperty.call(GIFTS, kind)) throw new Fail(400, 'Такого подарка нет');
    if (id === a.userId) throw new Fail(400, 'Себе подарок не отправить');
    if (!q.nameOf.get(id)) throw new Fail(404, 'Такого города нет');
    const d = today();
    const from = nameOf(a.userId);
    tx(() => {
      if (q.giftsToday.get(a.userId, d).n >= GIFT_DAY) throw new Fail(429, `Подарков — ${GIFT_DAY} в день. Завтра можно снова`);
      if (q.giftedPair.get(a.userId, id, d)) throw new Fail(409, 'Этому городу сегодня уже есть подарок от вас');
      q.addGift.run(a.userId, id, from, kind, d, Date.now());
    });
    return { ok: true, gifts_left: Math.max(0, GIFT_DAY - q.giftsToday.get(a.userId, d).n) };
  };

  // забрать подарки: ответ — те, что забраны сейчас (игра ставит украшения и приводит кошек); повтор — пустой список
  routes['POST /api/social/claim'] = async (req) => {
    const a = auth(req);
    if (limited(`soc:claim:${a.userId}`, 30, 600e3)) throw new Fail(429, 'Слишком часто');
    const b = await json(req);
    const ids = Array.isArray(b.ids) ? b.ids.slice(0, 30).map(int) : [];
    const want = new Set(ids);
    const got = tx(() => {
      const list = [];
      for (const g of q.inbox.all(a.userId)) {
        if (!want.has(g.n)) continue;
        if (q.claim.run(Date.now(), g.n, a.userId).changes) list.push({ id: g.n, from: g.from_name, kind: g.kind, name: GIFTS[g.kind] || g.kind });
      }
      return list;
    });
    return { claimed: got };
  };

  // гости из этих городов побывали у нас (только из последнего выданного списка; пара — раз в сутки)
  routes['POST /api/social/visited'] = async (req) => {
    const a = auth(req);
    if (limited(`soc:visit:${a.userId}`, 20, 600e3)) throw new Fail(429, 'Слишком часто');
    const b = await json(req);
    const o = offers.get(a.userId);
    const ids = Array.isArray(b.ids) ? b.ids.slice(0, GUESTS).map(int) : [];
    const d = today();
    let n = 0;
    tx(() => {
      let left = VISIT_DAY - q.marksDay.get(d, 'visit', a.userId).n;
      for (const id of ids) {
        if (left <= 0) break;
        if (!o || !o.ids.has(id) || id === a.userId) continue;
        if (q.mark.run(d, 'visit', a.userId, id).changes) { q.visit.run(id); n++; left--; }
      }
    });
    return { ok: true, counted: n };
  };

  return { GIFTS };
}

module.exports = { install, cleanCard, GIFTS, FRIENDS_MAX, GUESTS, GIFT_DAY };
