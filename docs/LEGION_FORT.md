# Легион: римский форт (план 16.11)

Owner, 16.11: «Форт огонь! Только он должен быть больше: зданий может быть почти до бесконечности, как в Hustle Castle; строятся и улучшаются разные здания.»

Concept art (approved): `.work/stage2/fort/fort_concepts.jpg`. The upper image is the early game (tents and empty plots); the lower one is the late game (stone buildings).

## 1. The fort grows
- **Fort level = HQ (Штаб) level.** The HQ is unique and stands in the centre at the back. Its level caps every other building's level and opens expansions.
- **Plots** form a grid on both sides of the main road (gate → HQ). Each **expansion** moves the palisade and towers outward and adds plots:

  | Expansion | Needs HQ | Plots | Fort size |
  |---|---|---|---|
  | 0 (start) | 1 | 6 | small fort, 4 towers |
  | 1 | 3 | 10 | wider |
  | 2 | 5 | 14 | deeper (a new row toward the gate) |
  | 3 | 7 | 20 | |
  | 4 | 9 | 26 | |
  | 5 | 12 | 32 | |
  | 6+ | +3 HQ levels each | +6 plots each | endless |

- **The expansion is the player's action**: the «Расширить форт» button at the gate. It costs coins + materials and has a growing timer. While it runs, there are workers on the palisade.
- An empty plot shows a dashed foundation and «+». Clicking it opens the build menu.

## 2. Buildings (most can be built several times; the count limit grows with HQ)

| Building | Gives | Max count |
|---|---|---|
| Штаб | caps levels, opens expansions, HQ skills | 1 |
| Казарма | soldier places (roster) | 1 → 4 |
| Полевая кухня | produces **rations**, collected by hand | 1 → 4 |
| Плавильня / Лесопилка / Кожевня | produce **iron / wood / leather** (in addition to the city workshops) | 1 → 3 each |
| Склад | storage limits for rations and materials | 1 → 4 |
| Кузница | forging and gear upgrades | 1 |
| Плац | trains soldiers' levels (one soldier per drill ground at a time) | 1 → 3 |
| Лазарет | heals wounded faster | 1 → 2 |
| Храм Марса | talents and blessings | 1 |
| Конюшня | cavalry; faster campaigns | 1 |
| Сторожевая вышка (on the corners) | defence against barbarian raids | 4 → 8 |
| Сокровищница | slowly accrues **gold ingots** | 1 |
| Арсенал | gear storage places | 1 → 2 |

- **Levels:** 1 … HQ cap. Cost and time grow (the `CAMP_TIME_H` table plus a step for each level beyond it, as now).
- **Looks by level:**
  - level 1–2: a canvas tent;
  - 3–5: a timber building;
  - 6+: a stone Roman building;
  - every level adds a detail (banner, props, a second wing).
- **Production:** production buildings fill up to a cap. A bubble with a fill ring sits above the building; clicking it collects and the amount flies to the bar. When full, production stops.
- **Migration** from the current V3 camp (slots hq, barracks, forge, drill, store, mars): those become buildings on the first plots with the same levels. Nothing is lost.

## 3. Living fort
- Sentries on the towers.
- Soldiers drill on the drill ground; the smith hammers; the cook stirs the cauldron.
- After a campaign, the squad marches in through the gate.
- A new recruit walks from the gate to the barracks.
- Workers and scaffolding on any building that is upgrading.

## 4. Interface (clear like Hustle Castle)
- **Top:** 4 big bars with icons: Денарии · Пайки · Слава · Слитки (amount / limit, «+» shows where to get). Materials appear in the warehouse and smithy cards and in costs.
- **Left:** round buttons with red counters:
  - Поход (map);
  - Задания дня;
  - Сундуки;
  - Арена (locked for now).
- **Bottom right:** a big round **«Строить»** button (hammer). It opens a menu of building cards: picture, name, what it gives, cost, «2 / 3».
- **Click a building:** a card from the bottom with:
  - a big picture;
  - the name and level;
  - one line saying what it gives;
  - ONE main action (Собрать / Призвать / Ковать / Тренировать);
  - «Улучшить» with cost icons and the time;
  - «Ускорить».
- **Over buildings:** a collect bubble, «!» when a building is idle, and a timer ring while upgrading.

## 5. Order of work
1. FORT1: model and data (plots, buildings, expansions, migration, production) plus logic tests.
2. FORT-ART: fort pieces in Blender in our low-poly style:
   - a sharpened-log palisade segment;
   - a watchtower;
   - a gate with a bridge;
   - tents (small, long, command).

   The rampart and ditch are procedural in Godot.
3. FORT-SCENE: the 3D fort from these pieces. It grows with expansions, and buildings change looks by level.
4. FORT-UI: the interface from §4.
