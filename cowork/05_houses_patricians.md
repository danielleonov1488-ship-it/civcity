# 05. Домусы патрициев (богатые дома)

Папка результатов: `out/05_houses_patricians/`. Образец стиля: `refs/style_higgsfield_house_1.png`.
Образец того, что сейчас в игре: `refs/now_house_patricians_1.png`.

Нужен **один и тот же домус на 1 и 2 этажа**, два облика — **A** и **B**. Всего 4 модели. Порядок шагов — как
в `03_houses_plebs.md`: сначала 1 этаж, потом по этой картинке +1 этаж.

**Размеры в игре:** фасад 2,8 м, глубина 7,35 м — длинный дом. Спереди вход, сзади маленький сад за низкой стеной.
Высота: 1 этаж — около 3,3 м, 2 этажа — около 5,5 м.

`face_limit`: 35000.

## Промпт A (после блока СТИЛЬ)

```
A rich Roman patrician domus, one storey, long and narrow (front 2.8 m, depth 7.35 m): an elegant entrance portico
with two white marble columns and a carved pediment at the narrow front, smooth terracotta-red plaster with white
marble trims, green wooden shutters, a terracotta tile roof, bronze lanterns by the door, potted laurel trees.
At the back: a small walled garden with a little fountain, flower beds and a marble statue.
```

## Промпт B (после блока СТИЛЬ)

```
A rich Roman patrician domus, one storey, long and narrow (front 2.8 m, depth 7.35 m): a grand doorway framed by
marble pilasters and steps at the narrow front, cream and gold plaster with a painted meander band, a terracotta
tile roof with decorative antefixes, vines climbing the wall, large painted amphorae by the entrance. At the back:
a small walled garden with cypress trees, a marble bench and a small pool.
```

Для 2 этажей: «the same domus with an upper storey added (a loggia with small columns and flower boxes), same style,
colors and details».

Имена файлов: `A1`, `A2`, `B1`, `B2` (`.png` и `.glb`).
