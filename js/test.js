'use strict';
/* Тестовый город: адрес с #test (например …/civcity/#test) открывает отдельный город со своим сохранением.
   Всё изучено, пройдены шесть провинций походов (открыты все войска и умения), войска прокачаны под этот этап,
   много ресурсов, готовый квартал.
   Улучшения идут в 100 раз быстрее и завершаются кнопкой. Настоящий город игрока не трогается. */

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
    // военные здания за второй улицей, на соседнем участке
    state.plots.add('0,1');
    Engine.plotChanged(0, 1);
    for (let x = 0; x < PLOT; x++) put('road', x, 21);
    for (const t of ['range', 'spearcamp', 'ballistae', 'catapults']) for (let x = 0; x < PLOT - 2 && !put(t, x, 22); x++);
    const A = Army.ensure();
    A.progress = 6 * STAGES_PER_REGION;   // шесть боссов побеждено: открыты все рода войск и умения
    A.rating = 150;                        // открыты Арка и Колизей, Пантеон ещё впереди
    A.squad = ['legionary', 'legionary', 'spearman', 'archer', 'ballista', 'catapult'];
    this.army();
    this.give();
    UI.buildToolbar();
    UI.log('Тестовый город: всё изучено, военные здания стоят. Легион и Чудеса — кнопки слева.', 'good', true);
  },

  // Войска и умения — как у игрока, дошедшего до Карфагена: первые бои провинции берутся, к боссу надо расти.
  // Раньше тут были войска 1-го уровня против седьмой провинции — первый же бой проигрывался.
  army() {
    const A = state.army;
    for (const t of UNIT_IDS) {
      A.levels[t] = Math.max(A.levels[t] || 1, 6);
      if (A.upg[t] && A.upg[t].to <= A.levels[t]) delete A.upg[t];
    }
    for (const p of PERK_IDS) A.perks[p] = Math.max(2, A.perks[p] || 0);
    state.testV = 2;
  },

  // Уже созданный тестовый город подтягиваем к новым правилам
  update() {
    if ((state.testV || 0) < 2) this.army();
  },

  give() {
    state.money += 30000;
    state.scrolls += 300;
    state.glory += 120;
    for (const g of GOOD_IDS) state.goods[g] = Math.max(state.goods[g] || 0, 450);
    afterCityChanged();
    UI.updateHud(true);
  },
};
