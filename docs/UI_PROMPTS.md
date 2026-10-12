# Промты для ChatGPT: рисованный интерфейс CivCity

## Как работать

1. **Откройте новый чат в ChatGPT.** Первым сообщением отправьте блок «СТИЛЬ» целиком. Он задаёт единый стиль для всех картинок.
2. **Отправляйте задания по одному**, в том же чате. Порядок: 1, 2, 3 и так далее.
3. **Сохраняйте картинки в PNG** под номером задания: `01.png`, `02.png`… Если вариантов несколько — `05a.png`, `05b.png`.
4. **Фон должен быть прозрачным.** Если ChatGPT нарисовал фон, напишите ему: *«Сделай фон прозрачным (transparent background PNG), без изменений самого рисунка»*.
5. **Если картинка не понравилась**, напишите *«ещё вариант»*. Можно попросить: *«в том же стиле, но …»*.
6. **Кладите готовые файлы в папку `D:\CivCity\assets\incoming\ui_ai\`** (создайте её, если нет). Или присылайте сюда в чат — я разложу сам.

Надписей на картинках не нужно. Все надписи делает игра, кроме логотипа в задании 20.

---

## СТИЛЬ (отправить первым сообщением)

```
I am making a cozy city-building game set in Ancient Rome (like "Town to City", but Roman).
For every image I ask next, keep ONE consistent art style:
- hand-painted, cozy, warm storybook game UI (high quality mobile/PC game UI art, similar quality to "Town to City", "Ever Oasis", "Kingdom Rush")
- materials: warm cream parchment / papyrus, polished bronze and soft gold trims, deep Roman red cloth, olive-green laurel leaves, white marble
- Roman ornaments: greek-key (meander) borders, laurel garlands, small rosettes, ionic volutes — elegant and not cluttered
- soft painted shading, gentle highlights, thin dark-brown outlines (#4a2c17), no harsh black
- palette: cream #f4e6c4, parchment #ecd9ae, bronze #b07a3a, gold #e2b45a, roman red #a8322a, olive #6f8a3a, ink brown #4a2c17
- NO text, NO letters, NO numbers on any element (unless I ask)
- clean PNG with TRANSPARENT background, centered, nothing cropped at the edges
Reply "OK" and wait for my tasks.
```

---

## Панели и рамки

**01 — Большая панель (окна, свитки)**
```
Task 01: a square UI panel for windows. Cream parchment fill with subtle paper texture, framed by an elegant bronze-and-gold Roman border with a thin greek-key (meander) band; small decorative rosettes in the 4 corners.
IMPORTANT for 9-slice scaling: all four straight edges must be identical and uniform along their whole length (decoration only in the corners), the inner parchment area must be plain and evenly lit. 1024x1024, transparent background outside the frame.
```

**02 — Маленькая панель (подсказки, плашки)**
```
Task 02: a small simple UI panel / tooltip: cream parchment with a thin bronze rim and rounded corners, no corner ornaments, very clean. Uniform straight edges for 9-slice scaling. 512x512, transparent background.
```

**03 — Свиток-папирус (раздел стройки разворачивается)**
```
Task 03: a horizontal papyrus scroll for a building menu: wide unrolled papyrus sheet with visible papyrus fibres, two carved dark-wood rollers on the LEFT and RIGHT ends with small gold caps. The papyrus area between the rollers must be plain and uniform (it will be stretched horizontally). 1536x512, transparent background.
```

**04 — Вертикальный свиток (список заданий)**
```
Task 04: a vertical papyrus scroll for a quest list: rollers at the TOP and BOTTOM (carved dark wood with gold caps), plain uniform papyrus in between (will be stretched vertically). 512x1024, transparent background.
```

**05 — Табличка города (верх слева)**
```
Task 05: a compact ornate name plate for the top-left corner of the screen: a horizontal Roman red cloth banner with gold trim and swallow-tail ends, mounted on a small bronze plaque; on the left side a round medallion with a golden Roman eagle (aquila) inside a green laurel wreath. Leave the red banner area EMPTY (the city name will be written there by the game). Small and elegant, not bulky. 1024x384, transparent background.
```

**06 — Разделитель**
```
Task 06: a thin horizontal decorative divider line: bronze line with a small laurel sprig and a rosette in the middle. 1024x96, transparent background.
```

---

## Кнопки

**07 — Круглая кнопка-медальон, 4 состояния**
```
Task 07: a round medallion button: polished bronze ring with tiny gold studs, cream parchment disk inside, EMPTY center (an icon will be placed on top). Draw 4 versions side by side in one image, equal size, evenly spaced: 1) normal, 2) hover (warmer, brighter gold rim), 3) pressed/active (glowing gold rim, slightly lighter center), 4) disabled (grey stone). 2048x512, transparent background.
```

**08 — Длинная кнопка, 3 состояния**
```
Task 08: a rectangular UI button with rounded ends: cream parchment fill, bronze border, subtle highlight on top. Uniform straight top and bottom edges for horizontal stretching. Draw 3 versions stacked vertically: normal, hover (brighter gold border), pressed (slightly darker, inset). 1024x768, transparent background.
```

**09 — Карточка постройки, 3 состояния**
```
Task 09: a portrait card frame for a building shop menu: parchment card with bronze frame and a small laurel ornament at the bottom center; the inner area plain (a building picture will be placed inside). Draw 3 versions side by side: available, hovered (gold glow frame), locked (desaturated grey parchment with a small bronze padlock in the bottom corner). 1536x768, transparent background.
```

**10 — Флажок и ползунок для настроек**
```
Task 10: small settings controls on one sheet, evenly spaced: a checkbox unchecked (bronze square frame, parchment inside), the same checkbox checked (with a hand-painted green checkmark), a slider track (thin bronze bar with parchment inlay), a slider knob (small bronze coin with a laurel). 1024x512, transparent background.
```

---

## Иконки

Все иконки рисуются листами 4 × 4 — 16 штук на картинке, ровными клетками без подписей.

**11 — Иконки, лист 1: главные**
```
Task 11: an icon sheet, 4x4 grid, 16 game icons, each centered in its own equal square cell, generous padding, NO labels, transparent background, 2048x2048.
Style: colorful hand-painted icons with thick ink-brown outline, soft shading, readable at small size.
Icons in order (row by row):
1 a stack of gold Roman denarius coins, 2 a rolled papyrus scroll with a red seal (research), 3 a Roman family (man, woman, child) silhouettes, 4 a green laurel wreath (happiness),
5 a hammer and chisel (workers), 6 a Roman townhouse with terracotta roof (housing), 7 a market stall with striped awning (shops), 8 a wheat sheaf with a small barn (farming),
9 a flower pot with blooming flowers (decorations), 10 a small Roman temple with columns (monuments), 11 a stone-paved road segment (paving), 12 a dirt footpath with grass,
13 square mosaic floor tiles (plaza), 14 an eraser, 15 two overlapping building silhouettes (copy), 16 a four-way move arrow cross.
```

**12 — Иконки, лист 2: инструменты и меню**
```
Task 12: icon sheet 4x4, same rules and style as Task 11, transparent background, 2048x2048, no labels.
1 a pickaxe and broken bricks (demolish), 2 a bronze bell (events/notifications), 3 an open book with a quill (research menu), 4 a coin purse with a small bar chart (finance),
5 a scroll with figures of people (population statistics), 6 an eye inside a circle (show range), 7 an old-style camera / painter's frame (photo mode), 8 three horizontal bronze bars (menu),
9 a bronze gear (settings), 10 musical notes over a lyre (music), 11 a speaker with sound waves (sounds), 12 a play triangle,
13 two vertical bars (pause), 14 double triangle fast-forward, 15 triple triangle very-fast-forward, 16 a red X close.
```

**13 — Иконки, лист 3: знаки и подсказки**
```
Task 13: icon sheet 4x4, same rules and style, transparent background, 2048x2048, no labels.
1 a green check mark, 2 a bronze padlock, 3 a golden pointing arrow (down), 4 an "i" information medallion,
5 a question mark medallion, 6 a bronze key over a land plot map (buy land), 7 a floppy-free "save" icon: wax tablet with a stylus, 8 a wooden door slightly open (exit),
9 a Roman eagle standard (aquila), 10 a Roman legionary helmet with red crest, 11 a red rectangular legion shield (scutum), 12 crossed gladius swords,
13 a sun, 14 a crescent moon with stars, 15 a sleeping "Zz" cloud, 16 an hourglass.
```

**14 — Иконки, лист 4: потребности и товары**
```
Task 14: icon sheet 4x4, same rules and style, transparent background, 2048x2048, no labels.
1 a red apple and pear (food), 2 a folded Roman tunic (clothes), 3 comedy and tragedy theatre masks (fun), 4 a barber razor and comb (services),
5 an amphora (goods), 6 a marble fountain with water (water), 7 a loaf of bread, 8 a leg of ham (meat),
9 a fish, 10 a basket of vegetables (cabbage, onion, carrot), 11 a bunch of purple grapes, 12 a branch with green olives,
13 a cup of red wine, 14 a clay pot / pottery, 15 a ball of wool with spindle, 16 a pair of Roman sandals.
```

**15 — Иконки, лист 5: ремёсла и науки**
```
Task 15: icon sheet 4x4, same rules and style, transparent background, 2048x2048, no labels.
1 an oil lamp with a flame (lamps), 2 a glass perfume flask, 3 a gold ring with a gem, 4 a mortar with herbs (medic),
5 a bathtub with steam (baths), 6 a lyre, 7 dice (game of dice), 8 a puppet/mime mask on a stick,
9 a quill and inkpot (scriptorium), 10 a wax tablet with an abacus (school), 11 shelves with scrolls (library), 12 a philosopher's bust (academy),
13 a wooden warehouse with crates, 14 a log pile (wood), 15 a cut marble block (stone), 16 a blacksmith anvil.
```

**16 — Иконки, лист 6: украшения и мир**
```
Task 16: icon sheet 4x4, same rules and style, transparent background, 2048x2048, no labels.
1 a Roman street lamp post with a lantern, 2 a bronze brazier with fire, 3 a marble bench, 4 a cypress tree,
5 an olive tree, 6 a flower bed, 7 a marble statue on a pedestal, 8 a wooden fence section,
9 a stone arch, 10 a small water well, 11 a pergola with vines, 12 a cat (cute, sitting),
13 a white swan, 14 a duck, 15 a cart with goods, 16 a rock/boulder.
```

**17 — Иконки классов жителей (крупнее)**
```
Task 17: three large character portrait icons in round bronze medallions, side by side, same style: 1) a Roman plebeian (simple brown tunic, friendly), 2) a Roman artisan (leather apron, holding a hammer), 3) a Roman patrician (white toga with purple stripe, laurel crown). Bust portraits, cozy and charming, no text. 1536x512, transparent background.
```

**18 — Советник**
```
Task 18: a portrait of the friendly city advisor "Marcus": an elderly kind Roman senator with a white toga, short grey beard, warm smile, holding a scroll. Bust portrait inside an ornate round bronze frame with laurel garland. Cozy storybook style, no text. 1024x1024, transparent background.
```

---

## Крупные картинки

**19 — Значки над постройками (что не так)**
```
Task 19: five small speech-bubble style badges that float above buildings, side by side, same style: parchment bubble with bronze rim and a small icon inside: 1) a hammer (needs workers), 2) a wooden crate (needs warehouse), 3) a wheat sheaf (needs raw goods), 4) a stone road piece with a red X (no road), 5) a family silhouette with a house (waiting for housing). 2560x512, transparent background, no text.
```

**20 — Логотип игры**
```
Task 20: the game logo "CivCity" — elegant Roman capital lettering in gold and cream with a dark-brown outline, a laurel wreath curving behind/around the word, a small golden eagle above the letters. Exactly the text "CivCity", spelled correctly, nothing else. 1536x768, transparent background.
```

**21 — Картинка экрана загрузки (необязательно)**
```
Task 21: a wide cozy painted illustration for a loading screen: a small Roman town on green hills at golden hour — terracotta roofs, colorful stucco houses, a little temple with columns, cypress trees, a road with a horse cart coming out of a tunnel in a small hill, people in tunics, birds in the sky. Storybook game art, warm light, no text. 1920x1080.
```

---

## Дополнительно (сейчас эти значки нарисованы временно, «золотом» по старым контурам)

**22 — Иконки, лист 7: кисть дороги и цвет дома**
```
Task 22: icon sheet 4x2, same rules and style as Task 11 (colorful hand-painted icons, thick ink-brown outline, soft shading, readable at small size), each centered in its own equal square cell, generous padding, NO labels, transparent background, 2048x1024.
Icons in order (row by row):
1 a winding freehand stroke of stone paving drawn by a brush (free drawing), 2 a straight stone road segment with a small ruler beside it (straight line), 3 a round brush tip dipped in grey stone paint (round brush), 4 a square brush tip dipped in grey stone paint (square brush),
5 a golden curved arrow turning back to the left (undo), 6 the same golden curved arrow turning to the right (redo), 7 a painter's brush with a drop of terracotta paint and a small color palette (recolor house), 8 an empty cell.
```

---

После каждого листа можно спросить ChatGPT: *«сделай ещё один вариант в том же стиле»*. Пришлите мне всё, что получилось, вместе с вариантами — я выберу лучшее и порежу на части для игры.
