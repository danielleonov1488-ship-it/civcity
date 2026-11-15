# Legion 3.0: simple, like Hustle Castle (owner's decisions, 15.11.2026)

The current code map is in `.work/stage1/legion/LEGION_MAP.md` (Codex, 15.11). This file is the target design. It applies ONLY to new games (`City.legion_v >= 3`, set for a new game). Old saves keep Legion 2.0 unchanged, and so do their tests.

## Player's view (the loop)
1. When the city reaches **50 residents**, the advisor says «Лагерь открыт». A **«Лагерь»** button appears in the top bar.
2. **Лагерь** is a separate screen: a painted Roman camp with **6 fixed building slots**. Nothing is placed on the city map, so the city never runs out of room for it.
3. **Казарма → «Призвать»** is one button. One city resident becomes a recruit:
   - unemployed residents are taken first;
   - otherwise someone from the least important job;
   - farms and bakeries are never emptied while food is short;
   - never when the city has fewer than 30 residents.

   A card shows «Луций, был пекарем → новобранец». The city loses one resident, and newcomers refill the house as usual.
4. **The weapon decides the class**: give a bow and the soldier becomes an archer.
5. **Отряд** has 5 places in 2 rows (front 3, back 2). The player drags soldiers into places.
6. **Поход**:
   - the existing campaign, 10 provinces × 15 battles with bosses;
   - every battle costs a **ration** (паёк);
   - rations come from the city's bakeries.
7. Rewards:
   - money and glory;
   - chests with gear;
   - materials (iron, wood, leather from the city workshops and from battles).

   Camp buildings are upgraded on timers. One builder.
8. Later stages:
   - **arena** against other players' squads (async; the server and its leagues already exist);
   - **barbarian raids** on the city (losing damages one building; repaired for coins; there is a peaceful mode);
   - **daily tasks** and the **Senate**.

## Classes (decided by the equipped weapon)

| Weapon | Class | Role | Counter |
|---|---|---|---|
| sword | Легионер | front tank, melee | ×1.3 damage vs cavalry/swift/beast |
| bow | Лучник | back row, ranged | ×1.3 damage vs armored melee (legionaries, spearmen) |
| staff | Жрец | back row, heals the weakest ally periodically, weak attack | — |
| spear (rides a horse) | Всадник | fast, ignores the front row and hits the enemy back row first | ×1.3 damage vs ranged |

Counters form a triangle: Всадник > Лучник > Легионер > Всадник. The Priest supports.

A recruit without a weapon gets a free common sword, so he starts as a Легионер.

## Gear
- **4 slots:** weapon, offhand (shield, class-neutral), helmet, armor. `badge` is hidden in V3.
- 5 rarities stay as they are, with the same colours.
- Sources: battle drops, chests, the forge.

## Camp slots (6), levels and timers

| Slot | Building (reuse) | Effect |
|---|---|---|
| Штаб | principia | camp level: no building can go higher than HQ; HQ needs the city level |
| Казарма | barracks | squad places 3 → 4 → 5 (levels 1/3/5); roster size 4 + level; the «Призвать» button |
| Кузница | forge | crafting and smelting (existing); sets from level 5 |
| Плац | NEW (drill ground) | training soldiers' rank (existing training logic moves here); training slots by level |
| Храм Марса | mars | battle perks (existing), opens at HQ 3; perk cap = level |
| Склад трофеев | armory | item storage, opens chests, ration cap +5 per level |

Notes:
- Upgrade timers to levels 2, 3, 4, 5, 6: **5 min, 30 min, 2 h, 8 h, 24 h**, then 24 h + 12 h per level.
- **One builder**. Costs reuse the existing formula.
- No donation. Speed-ups only as game rewards (daily chest token «−30 мин»).
- Camp buildings are not city-map buildings in V3. Range, spear camp, ballistae and catapults are not built in V3.
- The infirmary's job (wound healing) becomes a passive camp effect.
- The workshops (smelter, sawmill, tannery) STAY in the city: the city's workers produce the camp's materials.

## Rations
- Rations come from the city's bakeries: **+3 per working bakery per game day**, +2 base.
- Cap 20, plus the trophy store bonus.
- A campaign battle costs 2 (a boss costs 4).
- This replaces V2 provision energy in V3.

## Hidden until later (complexity opens gradually)
- Talents: HQ level 6.
- Sets: forge level 5 (as now).
- Perks: once the Temple of Mars is built.
- PvP, events and wonders tabs are hidden in V3 until the later stages.

## Code plan (phases)
- **L3.1 rules** (`legion.gd`, `soldiers.gd`, `gear.gd`, `city.gd`, new `test_legion3.gd`):
  - the V3 gate;
  - camp slot state and upgrades;
  - recruiting from residents (City API: take/return a resident);
  - weapon → class;
  - 4 slots;
  - 5 places in 2 rows;
  - rations;
  - hide gates;
  - save/load;
  - 50-resident unlock.
- **L3.2 battle:**
  - sim support for priest healing, cavalry back-row targeting, counters and explicit rows;
  - fighter visuals (staff and robe, a rider on a horse);
  - campaign parity untouched for legacy.
- **L3.3 camp screen:**
  - a painted camp background (Codex) with 6 hotspots;
  - building cards with timers;
  - the recruit card;
  - squad rows with drag;
  - reuse the forge, store, campaign map and soldier card.
- **L3.4 city side:**
  - remove military buildings from the V3 build menu;
  - the «bandits» story and the barracks step become «open the camp» at 50 residents;
  - advisor texts.
- **L3.5 later:** arena on the new snapshot (server sim and parity), raids, daily and Senate.
