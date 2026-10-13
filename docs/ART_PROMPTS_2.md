# Промты для ChatGPT, часть 2: значок игры, загрузочные экраны, легионы

Работайте так же, как с первой частью (`docs/UI_PROMPTS.md`):

- **Новый чат, сначала — блок «СТИЛЬ».** Откройте новый чат в ChatGPT и первым сообщением отправьте блок «СТИЛЬ» из первой части. Если чат старый и стиль уже задан, можно продолжить в нём.
- **Задания — по одному.** Сохраняйте картинки в PNG под номером задания: `30.png`, `36a.png` и так далее.
- **Куда класть.** Готовые файлы кладите в `D:\CivCity\assets\incoming\ui_ai\` или присылайте в чат — я разложу сам.
- **Фон.** У значков и иконок он должен быть прозрачным. У больших картинок (загрузка, карты) фон рисуется, прозрачность не нужна.
- **Надписи.** Нигде не нужны: все надписи делает игра.

---

## Значок игры и лаунчер

**30 — Значок игры (иконка на рабочем столе)**
```
Task 30: the application icon for the game. A bold, simple, instantly readable emblem that still reads at 32x32 pixels:
a golden Roman eagle (aquila) with spread wings standing on a small terracotta-roofed Roman house, framed by a green laurel wreath,
on a round deep-red enamel medallion with a thick polished bronze rim. Strong silhouette, big shapes, few details, soft painted shading.
No text. Square 1024x1024, transparent background around the round medallion.
```

**31 — Фон лаунчера (окно перед игрой)**
```
Task 31: a wide painted background for the game launcher window: a cozy Roman hill town at golden hour seen from slightly above —
terracotta roofs, colorful stucco houses (cream, ochre, pink, light blue), a small marble temple, cypress trees, a road with an arch,
gentle hills and a warm sky. Leave the LEFT third calmer and slightly darker (the login panel will sit there).
Storybook game art, warm light, no people close-up, no text. 1920x1080, no transparency.
```

---

## Загрузочные экраны (при запуске и загрузке города)

**32 — Загрузка: утренний рынок**
```
Task 32: a painted loading-screen illustration: a lively Roman market square in the soft morning — striped awnings,
baskets of fruit and vegetables, amphorae, a fountain, townspeople in tunics, a cat on a bench, pigeons,
houses with flower boxes and shutters. Cozy storybook style, warm light, no text. 1920x1080.
```

**33 — Загрузка: вечер, фонари**
```
Task 33: a painted loading-screen illustration: the same cozy Roman town at dusk — warm glowing lanterns and braziers,
a small temple with columns lit from below, people walking home, lavender sky with first stars, warm windows.
Calm, magical, cozy. No text. 1920x1080.
```

**34 — Загрузка: легион выходит в поход**
```
Task 34: a painted loading-screen illustration: a small Roman legion marching out of the town gate (a stone arch) along a road
into green hills — legionaries with red shields and crested helmets, a standard-bearer with the golden eagle, archers,
a ballista pulled by an ox, townspeople waving. Heroic but friendly storybook style (not grim, no blood). No text. 1920x1080.
```

---

## Легион: портреты бойцов

**35 — Пять портретов наших бойцов (в круглых бронзовых медальонах, как портреты классов)**
```
Task 35: five round portrait medallions side by side, same size and style as character portraits in a cozy game:
1) a Roman legionary (red tunic, segmented armor, red-crested helmet, big red scutum shield),
2) a spearman (long spear, round shield, lighter armor),
3) an archer (bow, quiver, leather cap),
4) a ballista (a wooden siege crossbow with a bronze tip, shown as an object),
5) a catapult (a wooden onager with a stone in the bucket, shown as an object).
Each inside a polished bronze ring with a parchment background and a small laurel sprig. Friendly, charming, not grim. No text.
Transparent background, 2560x512.
```

**36 — Портреты врагов, лист 1 (обычные враги)**
```
Task 36: an icon sheet 4x4 of enemy portraits in round dark-bronze medallions (slightly darker frame than our soldiers),
charming storybook style, not scary, no blood, no text, transparent background, 2048x2048. In order:
1 a forest bandit with a hood and club, 2 a slinger with a sling, 3 a grey wolf, 4 a wild boar,
5 a brown bear, 6 a Gaulish warrior with a braided moustache, 7 a Gaulish archer, 8 a Germanic berserker with a fur cloak,
9 a raging bull, 10 a pirate with a bandana, 11 a Carthaginian mercenary in heavy armor, 12 a shade of Hades (ghostly blue warrior),
13 a hellhound (dark dog with ember eyes), 14 empty, 15 empty, 16 empty.
```

**37 — Портреты боссов (крупнее)**
```
Task 37: eight large boss portraits in ornate gold-and-dark-red round medallions with a small crown of laurel on top,
storybook style, impressive but not gory, no text, transparent background, 2048x1024 (4 per row, 2 rows):
1 the bandit chieftain, 2 a huge rogue bear, 3 the king of the Gauls, 4 a Germanic giant,
5 the Minotaur, 6 a Cyclops with a boulder, 7 Hannibal's war elephant with armor, 8 Cerberus the three-headed dog.
```

---

## Легион: умения и значки

**38 — Умения отряда (кнопки в бою)**
```
Task 38: an icon sheet 4x4 for battle abilities, same icon style as the game icons (colorful, thick ink-brown outline), transparent background, 2048x2048, no text:
1 a bronze cauldron pouring boiling oil (with steam), 2 a "testudo" — a wall of red Roman shields overlapping,
3 a bandage roll with a green herb (healing), 4 a volley of arrows in the sky, 5 a curved bronze war horn (cornu),
6 a golden eagle standard glowing (rally), 7 a flaming arrow, 8 a caltrop / spikes on the ground,
9 a shield with a cracked enemy sword (block), 10 a sword with a speed swoosh, 11 a red cross-shaped medical kit replaced by a laurel-and-cup symbol (potion), 12 a lightning bolt of Jupiter,
13 an hourglass (cooldown), 14 a skull-free "defeat" symbol: a broken spear, 15 a victory laurel wreath with a gold star, 16 a treasure chest with coins.
```

**39 — Значки легиона и рейтинга**
```
Task 39: an icon sheet 4x4, same icon style, transparent background, 2048x2048, no text:
1 Glory: a golden laurel wreath with a star, 2 rating: a bronze podium with a laurel, 3 a battle: crossed sword and spear over a shield,
4 a campaign map with a red route and a flag, 5 a military camp tent, 6 barracks building (small Roman barracks with red banner),
7 an archery range target, 8 a siege workshop with a catapult arm, 9 upgrade: a golden arrow up over a helmet,
10 a timer: a sundial, 11 attack another city: a red banner with an arrow, 12 defend: a stone wall with a shield,
13 a boss skull-free mark: a horned helmet with a crown, 14 a locked region: a gate with a padlock, 15 a trophy amphora, 16 a scroll with a red wax seal (battle report).
```

---

## Легион: карта походов (фон окна походов)

**40 — Карты областей (8 штук, по одной на область)**
```
Task 40: a painted map background for a campaign screen, top-down slightly tilted view, like a cozy board-game map on parchment:
[REGION]. A winding dirt path with 10 small stone stops along it (empty round spots for level buttons, no numbers),
small trees, rocks, rivers, little details matching the region, a bigger special spot at the end for the boss.
Warm storybook painting, no text, no characters. 1920x1080.
```
Вместо `[REGION]` вставляйте по очереди (сохраняйте как `40a.png` … `40h.png`):
- a) `a sunny forest of bandits with green hills and a wooden bandit camp`
- b) `wild rocky hills with boars and bear caves`
- c) `a dark misty Gaulish forest with a wooden village and standing stones`
- d) `Germanic swamps with reeds, wooden walkways and fog`
- e) `the island of Crete with the stone Labyrinth of the Minotaur`
- f) `the rocky Sicilian coast with caves of the Cyclopes and the sea`
- g) `the golden desert of Carthage with palm oases and a city on the horizon`
- h) `the gates of Hades: dark volcanic land with blue spirit fires and a river`

**41 — Чудеса (картинки для вкладки «Чудеса»)**
```
Task 41: eight small square paintings of famous Roman wonders, same cozy storybook style, framed in thin bronze, no text,
transparent background around each frame, 2048x1024 (4 per row, 2 rows):
1 a triumphal arch, 2 the Colosseum, 3 the Pantheon, 4 the Circus Maximus with chariots, 5 an aqueduct across a valley,
6 Trajan's Column, 7 the Baths of Caracalla, 8 the Temple of Jupiter on the Capitol.
```
