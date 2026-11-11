# 04. Дома ремесленников (внизу — лавка или мастерская)

Папка результатов: `out/04_houses_artisans/`. Образец стиля: `refs/style_higgsfield_house_1.png`.
Образец того, что сейчас в игре: `refs/now_house_artisans_1.png`.

Как и у плебеев, нужен **один и тот же дом на 1, 2 и 3 этажа**, два облика — **A** и **B**. Всего 6 моделей.
Порядок шагов — как в `03_houses_plebs.md`: сначала 1 этаж, потом по этой картинке +1 этаж, потом ещё +1.

**Размеры в игре:** фасад 2,8 м, глубина 5 м. Высота: 1 этаж — около 3,3 м, 2 этажа — около 5,5 м, 3 этажа — около
7,35 м. Лавка — на узкой передней стороне.

`face_limit`: 30000.

## Промпт A — гончар (после блока СТИЛЬ)

```
A Roman artisan's house with a pottery shop on the ground floor, one storey, narrow front (front 2.8 m, depth 5 m):
a wide open shop counter under a striped cloth awning, shelves with amphorae, bowls and vases, a potter's wheel
visible inside, warm ochre plaster, wooden shutters, a terracotta tile roof, a hanging shop sign, potted plants.
```

## Промпт B — ткач (после блока СТИЛЬ)

```
A Roman artisan's house with a cloth and dye workshop on the ground floor, one storey, narrow front (front 2.8 m,
depth 5 m): an open front with colorful rolls of cloth and hanging dyed fabrics, a wooden loom inside, baskets of wool,
light cream plaster with a painted band, wooden beams, a terracotta tile roof, a hanging shop sign.
```

Для 2 и 3 этажей: «the same house with one more storey added on top (living rooms with small windows and a little
wooden balcony with flower pots), same style, colors and details; the shop stays on the ground floor».

Имена файлов: `A1…A3`, `B1…B3` (`.png` и `.glb`).
