# CivCity

Уютный римский градостроитель на Godot 4. Строите город, а он растёт сам, если жителям хватает еды, воды, храмов, товаров и красоты. Поражений нет. Рядом с городом стоит форт Легиона: набор бойцов, снаряжение и бои с племенами.

Сайт и скачивание игры: [civcity.ru](https://civcity.ru) (Windows и Mac).

Код открыт: смотрите, как сделана игра, и берите что пригодится. Условия — в разделе [Лицензия](#лицензия).

## Что где лежит

| Папка | Что внутри |
|---|---|
| `godot/` | **Сама игра** (Godot 4.7.2, GDScript) |
| `server/` | Сервер на Node.js: аккаунты, облачные сохранения, бои с другими игроками, почта |
| `desktop/` | Лаунчер для Windows на Electron: ставит и обновляет игру, проверяет подпись файлов |
| `site/` | Сайт civcity.ru (обычный HTML) |
| `deploy/` | Сборка игры для Windows и Mac, проверки и выкладка на сервер |
| `docs/` | План развития и заметки по механикам |
| `js/`, `index.html` | Первая, браузерная версия игры на Three.js (больше не развивается) |
| `roblox/` | Отдельная мини-игра для Roblox |

### Главные файлы игры (`godot/scripts`)

| Файл | Что делает |
|---|---|
| `game.gd` | Главная сцена: собирает город, камеру, интерфейс и игровой цикл |
| `city.gd` | Симуляция города: жители, работа, товары, нужды, налоги |
| `hud.gd` | Интерфейс города: панели, карточки домов, стройка, исследования |
| `people.gd` | Жители и кошки на улицах |
| `land.gd`, `bp.gd` | Земля, дороги и размещение построек |
| `legion.gd`, `legion_sim.gd` | Легион: бойцы, снаряжение, расчёт боя |
| `legion_ui.gd` | Окна Легиона: поход, войска, бой |
| `fort_*.gd` | Форт в разрезе: комнаты и фигурки бойцов |
| `camera_rig.gd` | Камера, мышь, тач и клавиатура |
| `sound.gd` | Музыка и звуки |
| `test_*.gd` | Автоматические проверки (запускаются без окна) |

Тот же расчёт боя есть на сервере (`server/legion_sim.js`), чтобы результаты боёв с другими игроками проверял сервер.

## Как запустить из исходников

1. Скачайте [Godot 4.7.2](https://godotengine.org/download).
2. **Купите модели Synty POLYGON** — Ancient Empire и Meadow Forest — на [syntystudios.com](https://syntystudios.com). Их нет в репозитории: это платные наборы, выкладывать их нельзя. Положите их в `godot/assets/synty` и `godot/assets/synty_meadow`.
3. Откройте в Godot файл `godot/project.godot` и нажмите «Запустить».

Без моделей Synty игру целиком не собрать, но код можно читать и брать по частям.

Игра работает и без сервера, просто без входа и облака. Запуск своего сервера: `cd server && npm install && npm start`.

## Лицензия

- **Код** — [MIT](LICENSE): берите и используйте как угодно, даже в платных проектах, указав CivCity.
- **Наши картинки, модели и звуки** — [CC BY-NC 4.0](LICENSE-ASSETS.md): можно брать с указанием CivCity, но нельзя продавать.
- **Чужие модели и звуки** — по их лицензиям, список в [LICENSE-ASSETS.md](LICENSE-ASSETS.md).

---

## English

**CivCity** is a cozy Roman city builder made with Godot 4.7 (GDScript), with a Node.js server for accounts, cloud saves and PvP, and an Electron launcher. Download the game at [civcity.ru](https://civcity.ru).

- The game lives in `godot/`; key scripts are listed in the table above.
- To run it from source you need Godot 4.7.2 and the paid **Synty POLYGON Ancient Empire** and **Meadow Forest** packs (not included), placed in `godot/assets/synty` and `godot/assets/synty_meadow`.
- License: code is MIT; original art, models and sounds are CC BY-NC 4.0; third-party assets keep their own licenses (see [LICENSE-ASSETS.md](LICENSE-ASSETS.md)).
