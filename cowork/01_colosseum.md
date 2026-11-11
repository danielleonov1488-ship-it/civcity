# 01. Амфитеатр (колизей)

Папка результатов: `out/01_colosseum/`. Образец формы: `refs/now_colosseum_1.png` и `refs/now_colosseum_2.png`.
Это то, что сейчас стоит в игре. Стиль бери из `refs/style_higgsfield_house_1.png`.

**Зачем важна форма.** В игре на ступенях амфитеатра сидят зрители, а на арене бьются гладиаторы. Поэтому:

- ряды сидений — ясные широкие ступени, их хорошо видно сверху;
- арена в центре — ровная, открытая, песчаная, на ней ничего не стоит.

**Размеры в игре:** след около 19 × 19,6 м, высота около 7,4 м. Форма низкая и широкая: ширина примерно в 2,6 раза
больше высоты.

Сколько делать: 3 картинки и 1–2 модели. `face_limit`: 60000.

## Промпт (после блока СТИЛЬ)

```
A round Roman amphitheater (colosseum), low and wide (width about 2.6 times the height). Outer wall of two to three
storeys of arches with chunky stone piers, small statues standing in some upper arches, red and yellow banners on
poles along the top rim, a colorful striped cloth awning (velarium) covering part of the top. Inside: clearly visible
wide tiered stone seating steps going down all around, an open flat empty sandy arena floor in the middle with a
small gate on two sides. One grand main entrance on the front with a columned portico, bronze braziers and potted
plants beside it. View from above at 3/4 so the inner seating and the arena are visible.
```

## Если не вышло

- Картинка без вида внутрь: добавь в промпт «high camera angle looking down into the arena».
- Арена не видна или занята: добавь «the arena floor is completely empty flat sand».
