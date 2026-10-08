'use strict';
/* Тестовый город: адрес с #test (например …/civcity/#test) открывает отдельный город со своим сохранением.
   Всё изучено, много ресурсов, готовый квартал, казармы и легионеры. Настоящий город игрока не трогается. */

const Test = {
  setup() {
    state.testReady = true;
    state.cityName = 'Тестовый город';
    state.techs = TECHS.map(t => t.id);
    state.research = null;

    const free = (t, x, y) => {
      const d = BUILDINGS[t];
      for (let j = 0; j < d.h; j++) for (let i = 0; i < d.w; i++) {
        const tx = x + i, ty = y + j;
        if (!isOwnedTile(tx, ty) || isWater(groundAt(tx, ty)) || World.occ.has(tkey(tx, ty))) return false;
      }
      return true;
    };
    const put = (t, x, y, tier) => {
      if (!free(t, x, y)) return null;
      const b = placeBuilding(t, x, y, true);
      if (tier) {
        b.tier = tier;
        b.pop = BUILDINGS[t].tiers[tier].cap;
        Engine.buildingsChanged(b);
      }
      return b;
    };

    // вторая улица параллельно стартовой (стартовая — y = 11)
    for (let x = 0; x < PLOT; x++) put('road', x, 17);
    let n = 0;
    for (let x = 1; x < PLOT - 1; x += 2) {
      for (const y of [9, 12, 18]) put('house', x, y, 1 + (n++ % 4));
    }
    // службы между улицами: дома растут, легион тренируется
    put('temple', 1, 14); put('market', 4, 14); put('baths', 7, 14); put('barracks', 10, 14);
    put('smithy', 13, 15); put('warehouse', 15, 15); put('warehouse', 17, 15);
    put('fountain', 19, 15); put('school', 21, 15); put('well', 23, 16);
    this.give();
    UI.buildToolbar();
    UI.log('Тестовый город: всё изучено, ресурсы и легионеры уже есть. Легион — кнопка слева.', 'good', true);
  },

  give() {
    state.money += 30000;
    state.scrolls += 300;
    state.glory += 60;
    for (const g of GOOD_IDS) state.goods[g] = Math.max(state.goods[g] || 0, 450);
    state.legion.soldiers += 40;
    afterCityChanged();
    UI.updateHud(true);
  },
};
