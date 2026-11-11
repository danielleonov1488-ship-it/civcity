# 02. Цирк для гонок колесниц (как Цирк Максимус)

Папка результатов: `out/02_circus/`. Образец формы: `refs/now_circus_1.png` и `refs/now_circus_2.png`.
Это то, что сейчас стоит в игре. Стиль бери из `refs/style_higgsfield_house_1.png`.

**Зачем важна форма.** В игре по дорожке мчатся колесницы, а на трибунах сидят зрители. Поэтому:

- беговая дорожка — ровный открытый песок вокруг центральной стенки;
- трибуны вдоль длинных сторон — ясные ступени.

**Размеры в игре:** след около 38 × 11,9 м, высота около 5 м. Очень длинный и узкий: длина примерно в 3,2 раза больше
ширины.

Сколько делать: 3 картинки и 1–2 модели. `face_limit`: 60000.

## Промпт (после блока СТИЛЬ)

```
A Roman chariot racing stadium like the Circus Maximus, very long and narrow (length about 3.2 times the width), low.
Long tiered stone seating stands along both long sides with colorful striped cloth awnings and banners. In the middle,
an open flat sandy race track that loops around a long low central wall (spina) decorated with a tall obelisk,
small statues, little shrines and lap-counter eggs and dolphins on a frame. At one short end: the starting gates
(carceres), a row of arched stalls with two square towers. At the other short end: a rounded curved end of the stands
with an arched triumphal gate. View from above at 3/4, the whole stadium visible end to end.
```

## Если не вышло

- Получилось коротким: добавь «extremely elongated, very long and thin».
- Дорожки не видно: добавь «the race track is wide empty flat sand all around the central wall».
