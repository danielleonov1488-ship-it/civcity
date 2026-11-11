# 03. Дома плебеев (простых римлян)

Папка результатов: `out/03_houses_plebs/`. Образец стиля: `refs/style_higgsfield_house_1.png`.
Образец того, что сейчас в игре: `refs/now_house_plebs_1.png`.

В игре дом растёт: жители надстраивают этажи. Поэтому нужны **один и тот же дом на 1, 2 и 3 этажа**. Сделай
два разных облика: **A** и **B**. Всего 6 моделей.

**Размеры в игре:** узкий фасад с дверью 2,8 м, глубина 4 м. Высота по этажам: 1 этаж — около 3,3 м, 2 этажа — около
5,4 м, 3 этажа — около 7,3 м. Дверь — на узкой передней стороне.

`face_limit`: 25000.

## Порядок для облика A (потом так же для B)

1. **A1** — картинка дома в 1 этаж, промпт ниже. Сделай 2–3 варианта и выбери лучший.
2. **A2** — по лучшей картинке A1 как образцу: «the same house with one more storey added on top, same style,
   colors and details». Сделай 1–2 варианта.
3. **A3** — по картинке A2 так же: ещё один этаж.
4. Потом три модели 3D: `A1.glb`, `A2.glb`, `A3.glb`.

## Промпт A (после блока СТИЛЬ)

```
A small simple house of poor Roman commoners (plebeians), one storey, narrow front with a wooden door (front 2.8 m,
depth 4 m), plain warm ochre plaster with a few cracks and patches, one small window with wooden shutters, a simple
terracotta tile roof, a small cloth awning over the door, a wooden bench, a clay pot with herbs, a stack of firewood
and a basket by the wall.
```

## Промпт B (после блока СТИЛЬ)

```
A small simple house of poor Roman commoners (plebeians), one storey, narrow front with a wooden door (front 2.8 m,
depth 4 m), pale cream and faded pink plaster, a small window with a flower box, a terracotta tile roof with a small
chimney, laundry hanging on a rope, an amphora and a broom by the door, a little wooden ladder at the side.
```

Имена файлов: `A1.png` / `A1.glb`, `A2…`, `A3…`, `B1…`, `B2…`, `B3…`.
