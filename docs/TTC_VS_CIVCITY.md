# Town to City против CivCity: подробный разбор и отличия

Дата: 6 ноября 2026. Кому: владельцу и Claude (Codex).
Зачем: зафиксировать, как устроена Town to City и чего у нас нет, чтобы не спорить «на вкус», а брать из их конструкции конкретные решения.

---

## 1. Откуда данные и насколько им верить

- Игра установлена: `D:\SteamLibrary\steamapps\common\Town To City` (UE5, ~2,3 ГБ).
- Внутри — `Manifest_UFSFiles_Win64.txt` (42 081 строка) со списком всех ассетов и папка `TownToCity\Content\GameData`
  со всеми игровыми данными (здания, нужды, кривые, трейты, квесты, диалоги).
- **Что это значит:** имена ассетов и названия кривых говорят, *какие системы есть и как они называются*.
  Сами числа внутри `.uasset` не читались (это бинарные ассеты UE). Поэтому ниже — «как устроено по конструкции»,
  а не «точные формулы».
- Числа в тексте — строки манифеста (ассет + его экспорт `.uexp`), поэтому реальных ассетов примерно **вдвое меньше**.
- Проверить самому можно одной командой (PowerShell):

```
$m='D:\SteamLibrary\steamapps\common\Town To City\Manifest_UFSFiles_Win64.txt'
Get-Content $m | Select-String 'GameData/BalanceCurves/' | ForEach-Object { $_.Line.Split("`t")[0] }
```

---

## 2. Их системы — по полкам

### 2.1. Данные и «настройки без кода»

| Папка `GameData` | Строк в манифесте | Что это |
|---|---|---|
| `DialogueSystem` | 2148 | диалоги: узлы, варианты ответов, ветки по зданиям |
| `Buildings` | 772 | все постройки и их параметры |
| `Inhabitants` | 745 | типы жителей и животных + варианты окрасов |
| `Encyclopedia` | 722 | встроенная энциклопедия (статьи + видео) |
| `Quests` | 384 | квесты |
| `TechTree` | 380 | дерево исследований |
| `Brushes` | 160 | кисти (дороги, земля, поля) |
| `BuildingCategories` | 144 | категории построек |
| `Terrain` | 126 | рельеф |
| `BalanceCurves` | 84 (25 уникальных кривых) | **весь баланс в кривых** |
| `FamilyTraits` | 84 (32 трейта + 9 кривых) | характеры жителей |
| `Departments` | 80 | ведомства и политики |
| `BuildMenuCategories` | 74 | меню постройки |
| `Routes` | 48 (6 маршрутов) | туристические маршруты |
| `Upgrades` | 38 (19 видов) | апгрейды лавок |
| `CashFlow` | 30 | потоки денег и бонусы к ним |
| `Families` / `Households` | 26 / 14 | семьи и домохозяйства |
| `Notifications` | 18 | правила уведомлений |
| `InformationOverlays` | 12 | инфо-слои |
| `Needs` | 12 (6 нужд) | нужды жителей |
| `RouteVisuals` | 8 | как рисуется маршрут |

### 2.2. Три принципа, на которых держится их «уютность»

1. **Рост сам себя тормозит.**
   - `Curve_FamilySpawnRatePerDayOnHapinessLevel` (+ `_Boosted`) — сколько семей приезжает в день в зависимости от счастья;
   - `Curve_FamilySpawnRateMultiplierPerOpenFamilySpot` — множитель от числа свободных мест;
   - `Curve_HappinessDebuffFromPopulationDensity` и `Curve_HappinessDebuffFromTotalNumInhabitants` — **штрафы за плотность
     и за общее число жителей**: чем больше город, тем он капризнее;
   - `Curve_PopulationDesnityIntensityOnRangeFallOff` — плотность «давит» с затуханием по расстоянию.
   У нас вместо этого: `defs.gd:98 ARRIVE_EVERY` — повозка раз в 1,8–2,6 игровых часа по рангу, фиксированный таймер.

2. **Красота — механика, а не косметика.**
   - `Curve_DesirabillityProvidedByBeautification` + `Curve_BeatificationIntensityOnRangeFallOff` — украшения дают
     «желательность» с затуханием по расстоянию;
   - `Curve_JobHappinessByBeautification` — на работе тоже важно, красиво ли вокруг;
   - `Curve_DesirabilityBonusFromMissingLuxuryPoints` — дефицит роскоши отдельно влияет на желательность;
   - `Curve_HappinessBonusGroundTypeDistance` — даже тип земли под домом влияет.

3. **Нормы считаются на жителя.**
   - шесть нужд, у каждой пара кривых «минимум / цель на душу населения» (еда, одежда, **развлечения**, утварь,
     госуслуги, **туризм**);
   - `Curve_HomeDecoPerPop_Min` / `_Target`, `Curve_WorkDecoPerPop_Min` / `_Target` — сколько украшений должно быть
     у дома и у работы **на человека**; с ростом города планка растёт, и цель не кончается;
   - `Curve_HappinessPerAmountConnectedOfNeed` — сколько счастья за каждую подключённую нужду.

### 2.3. Характеры жителей (32 трейта)

Трейты (**полный список из файлов**):
`AllergicToCamels`, `AllergicToPets`, `Artisan`, `ArtisinalShopper`, `BeeLover`, `BellsAndWhistles`, `Bourgeoisie`,
`CityLife`, `CottageCore`, `Cowboy`, `CozyLiving`, `CrowdFavorite`, `Farners`, `Fishers`, `FlowerLover`, `GreenThumbs`,
`Hikers`, `LavenderFields`, `NeedsClothing`, `NeedsEntertainment`, `NeedsFood`, `NeedsHousewares`, `NeedsPublicService`,
`ScaredOfTheDark`, `Shepherd`, `SizeUp`, `Solitude`, `TreeHugger`, `WantsCat`, `WantsDog`, `WantsGoose`, `WantsPet`.

Кривые под трейты:
`HappinessBonusPerHouseForCrowdFavorite`, `HappinessBonusPerHouseForSolitude` (любит толпу / любит уединение — счастье
зависит от плотности рядом с домом), `HappinessDecreaseCozyLiving` («уютная жизнь» — штраф за тесноту),
`HappinessBonusPerPropForTrait` (бонус за конкретные украшения рядом), `HappinessIncreasePerNeedBuildingInRange`,
`HappinessDecreasePerBuildingForTrait`, `DesirabilityFromPet` / `DesirabilityFromPetNegative` (питомец поднимает
привлекательность — если у жителя нет аллергии), `HappinessBonusHouseSizeup` (радость от расширения дома).

**Вывод:** наш «характер» — это сословие и семья. У них — 32 мелких предпочтения, которые превращают одинаковые дома
в разных людей. Это самый дешёвый источник уюта: новых моделей не нужно.

### 2.4. Нужды

Шесть (`DAHumanNeed_*`): `Food`, `Clothing`, `Entertainment`, `Housewares`, `PublicService`, **`Tourism`**.
У нас (`defs.gd`, `CLASSES`) нужды уже есть по сословиям: плебеи — `food`; ремесленники — `food`, `clothes`, `fun`;
патриции — `food`, `clothes`, `fun`, `services`, `goods`. То есть **набор почти тот же**, не хватает «туризма»
и нормативов «на жителя» — у нас покрытие лавками, а не планка на человека.

### 2.5. Туризм — целая система

- **15 достопримечательностей** (`Buildings/TouristAttractions`): `WaterBallet`, `Automaton`, `ClockCityGate`,
  `GiantFountain`, `Lighthouse`, `RomanAqueduct`, `RomanTemple`, `Obelisk`, `BigGreenMonument`, `MetalTower`,
  `AnimalStatue`, `MayorStatue`, `PetStatues`, `Statue`, `TESTHOTELS`.
- **Отели** (`Buildings/Special`): `Inn`, `Hotel`, `BoutiqueHotel`; там же `CityHall`, `MayorsHome`, `ResearchCenter`,
  `ArtAtelier`, `AnimalShelter`.
- **Маршруты** (`Routes`, 6): `Spring`, `Summer`, `Autumn`, `Winter`, `SpookyStroll`, `TEST` — приезжие ходят
  по сезонным маршрутам, маршрут виден на карте (`RouteVisuals`).
- **Очки маршрута** (`BalanceCurves`): за достопримечательность, за красоту, за еду, за напитки, за скамьи,
  за туристические места; плюс `Curve_RouteHappinessByBeautification` и `Curve_FarmResearchPointsGainPerSuperBuildingConnection`.
- У нас туризма нет совсем.

### 2.6. Ведомства и политики (12 ведомств)

`Agriculture`, `Animals`, `Apparel`, `Finance`, `Food`, `Housewares`, `Immigration`, `Leisure`, `Logistics`,
`PublicService`, `Tourism`, `SillyWalks`.

Политики — по три на ведомство, классическая тройка: **Luxury / Output / Profit** (роскошь / выпуск / прибыль),
например `FoodLuxury`, `FoodOutput`, `FoodProfit`; отдельные: `ImmigrationAmount`, `ImmigrationTraits` (какие трейты
приезжают!), `LogisticEfficiency`, `LogisticWorkers`, `FinanceTreasury`, `AnimalsExotic`, `Farmland`.

У нас: налоги по классам (`TAX_SET`) и содержание; политик нет.

### 2.7. Деньги

Категории потоков (`CashFlow/CashFlowCategories`): `BuildingUpkeep`, `CommerceConnections`, `Employment`, `Household`.
Бонусы к потокам (`CashFlowBonusCategories`): `Beautification`, `BuildlingUpgrade`, `Nature`, `Pollution`
(красота и природа приносят, грязь отнимает).
У нас: `HIST_KEYS` (tax, wage, upkeep, build, fest, land, legion, reward, other, lost) — близко, но без «красота
приносит деньги» и без связей между лавками.

### 2.8. Исследования

`TechTree`: 380 строк, структура `TechTree/<Сословие>/<Здание>/Tier<N>/TechTreeItem_<Что открывается>`.
Пример: `TechTree/Peasants/ArtAtelier/Tier1/TechTreeItem_BenchStoneRound`, `..._GateGolden`, `..._WillowTree`.
То есть исследования открывают **не только здания, но и отдельные украшения, ворота, деревья** — и привязаны к сословию.
У нас: 90 исследований «полками по уровням» (`defs.gd`), дерево плоское.

### 2.9. Квесты и диалоги

- `Quests` — 384 строки; менеджер `DAQuestManager`.
- `DialogueSystem` — 2148 строк, реальный диалоговый граф: `Dialogues/<Дом>/<Квест>/<Квест>_DialogueNode_0`,
  `_ChoiceNode_3`, `_Completion`. Ветки привязаны к домам (`MayorsHome` и др.).
- У нас: истории — сцены с выбором (`stories.gd`, `story_defs.gd`), 17 историй; диалогов «поговорить с жителем» нет,
  объяснения даёт советник.

### 2.10. Энциклопедия

722 строки, статьи по темам: `Animals`, `Farming`, `Building`, `Other`, `Progression`, `Residents`, `Tools` —
и к ним **видеоролики** (`Content/Movies/Encyclopedia/...`: например `Residents/NewArrivals`, `Animals/Assign`,
`Farming/CropsBrushing`, `Tools/Terraforming`). У нас встроенной энциклопедии нет (есть подсказки советника и
страница «Обновления» на сайте).

### 2.11. Мелочи, которые создают «жизнь»

- `Notifications` (18 правил): «житель ушёл, потому что негде жить», «новая запись в энциклопедии», «новая просьба»,
  напоминания («постройте дом мэра», «напоминание о Фонтебраке»).
- `InformationOverlays` (12): инфо-слои по постройкам и жителям + отдельная панель **трейтов семьи**.
- `Inhabitants/Animal`: `Cat`, `Dog`, `Dromedary`, `Goose` + варианты окрасов (`Cat_Variation1…10`).
  Трейты «хочет кошку/собаку/гуся» и «аллергия на питомцев/верблюдов» — то есть питомец реально влияет на счастье
  конкретного человека.

### 2.12. Постройки

| Категория | Строк | Примеры |
|---|---|---|
| `Beautification` | 504 | мосты, заборы, живая изгородь, площадки, стройка, сезонные наборы |
| `ModularHouses` | 94 | модульный дом: формы, двери, перекраска |
| `Commerce` | 88 | 44 вида лавок (см. ниже) |
| `TouristAttractions` | 30 | 15 достопримечательностей |
| `Houses` | 20 | дом по району (город/ферма/туризм) × сословие |
| `Special` | 16 | ратуша, дом мэра, исследовательский центр, арт-ателье, приют, отели |
| `Warehouses` | 6 | склады, зернохранилище |
| `Stations` | 2 | вокзал |

**44 лавки:** `Apothecary`, `ArtGallery`, `Bakery`, `BallThrow`, `Barber`, `Bistro`, `Butcher`, `CandleMaker`,
`Carpenter`, `Cathedral`, `Chapel`, `ClockMaker`, `ClothingStore`, `FerrisWheel`, `Hatter`, `Jeweler`,
`KioskTheatre`, `Launderer`, `Library`, `Luthier`, `Market_Cheese`, `Market_Eggs`, `Market_Fish`, `Market_Fruit`,
`Market_Vegetables`, `MerryGoRound`, `NewspaperBuilding`, `Optician`, `Parfumer`, `Patisserie`, `PostOffice`,
`Pottery`, `Pub`, `PuppetTheatre`, `Restaurant`, `School`, `ShoeStore`, `Smithy`, `SocialClub`, `StreetOrgan`,
`Tailor`, `Theatre`, `University`, `Winery`.

Заметьте: среди них **театр, кукольный театр, киоск-театр, карусель, колесо обозрения, духовой орган** —
это и есть «зрелища», о которых мы говорили. У нас лавки есть (35), но зрелищ в них нет — туда просто «заходят».

---

## 3. Что уже есть у нас (для честного сравнения)

По коду (`godot/scripts`):

- **постройки**: 260 определений в `Defs.B` — 192 украшения, 35 лавок, 13 монументов, 8 военных, 4 «дворца/станция»,
  3 фермы, 3 типа домов, 1 склад, 1 станция;
- **сословия**: 3 (плебеи, ремесленники, патриции) с разными нуждами и налогами (`Defs.CLASSES`);
- **исследования**: 90 (`defs.gd`), открывают постройки и наборы украшений;
- **украшения**: 12 наборов (`DECOR_SETS`) + бонус за набор (`SET_BONUS`), в каталогах ~1000 вариантов;
- **истории**: 17 (сцены, выборы, проверки на карте), `stories.gd` / `story_defs.gd`;
- **просьбы и заказы**: 34 просьбы (`Defs.REQUESTS`) + заказы старосты;
- **«Летопись»**: 29 значков (`chronicle.gd`);
- **Легион**: армия, постройки на карте, бои; PvP с другими городами (сервер `server/`);
- **жители**: свои дела (лавки, скамьи, кошки, лудус), семьи, «Следовать», «Внешность»;
- **животные**: кошки (модель Kitten), утки, лебедь, овцы, ослик;
- **зрелища**: нет (арена и трибуны — только геометрия, кроме `WATCH`-зрелищ у лавок: музыканты, кости, мимы, куклы, лудус).

---

## 4. Сравнение по системам

| Система | Town to City | CivCity сейчас | Вердикт |
|---|---|---|---|
| Рост города | кривые от счастья и свободных мест, штрафы за плотность и население | фиксированный таймер повозки (`ARRIVE_EVERY`) | **брать** (это и есть «не фармить») |
| Красота | «желательность» с затуханием, влияет на дом и работу, деньги | бонус за набор украшений и «Главные» | **брать** как механику |
| Нужды | 6 нужд, нормы «на жителя», дефицит роскоши | 5 нужд по сословиям, покрытие лавками | **адаптировать** |
| Характеры | 32 трейта + 9 кривых | нет | **брать первым** |
| Туризм | достопримечательности, отели, сезонные маршруты, очки | нет | **брать** (бесконечная цель) |
| Ведомства/политики | 12 ведомств × 3 политики | налоги по классам | **позже** |
| Техдерево | по сословиям и зданиям, открывает украшения | 90 плоских исследований | **адаптировать** |
| Квесты | 384, привязаны к диалогам и домам | 17 историй + 34 просьбы | у нас уже хорошо |
| Диалоги | граф с вариантами, ветки по домам | сцены с выбором, без диалогов | **добрать** короткими репликами |
| Энциклопедия | 722 статьи с видео | подсказки советника | **позже** |
| Питомцы | влияют на счастье конкретного жителя | есть модели, влияния нет | **дешёво, брать** |
| Деньги | 4 потока + бонусы за красоту/природу/грязь | 11 ключей истории | **адаптировать** |
| Армия/PvP | нет | есть Легион и бои с городами | наше преимущество |
| Сезоны | 4 сезонных набора декора и маршрутов | нет | **позже** |

---

## 5. Пять вещей, которые дадут больше всего

1. **Характеры жителей.** 10–15 трейтов на старте (`любит толпу`, `любит уединение`, `цветы`, `тень`,
   `хочет кошку`, `аллергия на питомцев`, `домосед`, `гуляка`, `садовник`, `боится темноты`), у каждого —
   1–2 правила «+счастье за X рядом» / «−счастье за Y рядом». Новых моделей не нужно, а город сразу становится
   из людей. Опирается на `residents.gd` и `happy_parts` в `city.gd`.
2. **Туризм с маршрутами.** 3–4 достопримечательности, 2 отеля, маршрут-петля по городу, очки за красоту,
   еду и скамьи на пути. Даёт и «город живёт», и бесконечную цель, и деньги. Опирается на существующие
   `city.gd` (гости) и `Decor`-бонусы.
3. **Нужда «развлечения» через зрелища.** Расписание сеансов в амфитеатре/цирке/театре, жители идут с целью,
   садятся, смотрят — и это закрывает нужду `fun` (она у нас уже есть у ремесленников и патрициев).
4. **Короткие диалоги.** По 2–3 реплики с выбором в карточке жителя и при просьбах; шаблон уже есть в историях.
5. **Баланс в данные.** Вынести правила роста, красоты и норм в отдельный файл-таблицу (по образцу их
   `BalanceCurves`), чтобы крутить числа без пересборки логики.

---

## 6. Чего копировать не надо

- **Картинку.** У них воксельный UE5 с Lumen; у нас Synty и Godot. Стиль не переносим — переносим правила.
- **Их тон.** 19 век, Франция, «милота». У нас Рим — тон другой, и это нормально.
- **Модульные дома.** У них 94 ассета под сборку домов из частей; нам это дорого и ломает текущий вид домов.
- **Энциклопедию с видео.** 722 статьи — это контент-проект на месяцы; нам пока хватает советника.

---

## 7. Конкретные задания для Claude

Каждое — самостоятельное, проверяемое, без «переделать всё»:

1. **Трейты жителей.** В `residents.gd` добавить поле `traits` (массив строк), в `defs.gd` — таблицу
   `TRAITS = {id: {name, desc, effect}}`, в `city.gd` — учёт в `happy_parts` (например `"trait_flowers": +3`).
   Показать трейт в карточке жителя (`person_card.gd`). Тест: житель с трейтом «цветы» рядом с клумбой счастливее
   такого же без клумбы.
2. **Кривые вместо констант.** Новый файл `godot/scripts/curves.gd` с чистыми функциями
   (`spawn_rate(happiness, free_spots, population)`, `desirability_from_decor(distance)`); заменить
   `ARRIVE_EVERY` и бонусы декора. Тест: при росте населения темп приезда падает.
3. **Туризм, минимум.** 2 отеля + 3 достопримечательности (у нас уже есть арка, акведук, маяк, обелиск),
   «гость» как отдельный тип жителя с маршрутом по 4 точкам, деньги за ночь. Тест: гость проходит маршрут и уезжает.
4. **Зрелища.** Расписание сеансов, посадка на трибуны по геометрии постройки (сетка высот по треугольникам
   деталей `SM_Bld_Amphitheatre_01` / `SM_Bld_Amphitheatre_End_01`), нужда `fun` закрывается на сеансе.
   Тест: 30 жителей пришли, сели лицом к арене, счастье выросло.
5. **Проверка «на жителя».** Для каждой нужды посчитать норму на душу (по образцу `Curve_*PerPop_Min/_Target`)
   и показывать в интерфейсе «еда: 0,8 из 1,0 на жителя».

---

## 8. Что из их файлов можно цитировать как доказательство

- `GameData/BalanceCurves/Curve_HappinessDebuffFromPopulationDensity`
- `GameData/BalanceCurves/Curve_FamilySpawnRatePerDayOnHapinessLevel`
- `GameData/BalanceCurves/Curve_DesirabillityProvidedByBeautification`
- `GameData/BalanceCurves/Curve_BeatificationIntensityOnRangeFallOff`
- `GameData/FamilyTraits/DAFamilyTrait_CrowdFavorite`, `..._Solitude`, `..._AllergicToPets`
- `GameData/Needs/DAHumanNeed_Entertainment`, `..._Tourism`
- `GameData/Departments/Food/Policies/DAPolicy_FoodLuxury`
- `GameData/Routes/DARoute_Winter`
- `GameData/Buildings/TouristAttractions/*` (15 штук)
- `GameData/TechTree/Peasants/ArtAtelier/Tier1/TechTreeItem_BenchStoneRound`
- `GameData/Buildings/Commerce/*` (44 лавки, включая `Theatre`, `PuppetTheatre`, `KioskTheatre`)

Оговорка ещё раз: это устройство по названиям и структуре данных, а не по игре руками; точные формулы внутри
`.uasset` не читались, и там могут быть свои исключения.
