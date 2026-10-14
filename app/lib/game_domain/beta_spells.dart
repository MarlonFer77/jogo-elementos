enum BetaElement {
  fire('Fogo', 'Projétil + queimadura'),
  water('Água', 'Lentidão + cura ao acertar'),
  wind('Vento', 'Explosão que afasta inimigos'),
  earth('Terra', 'Impacto + proteção por 2s');

  const BetaElement(this.label, this.description);
  final String label, description;
}

/// Canonical, unordered recipes. Costs trade single-target efficiency for utility.
enum BetaCombo {
  steam(
    'Vapor',
    BetaElement.fire,
    BetaElement.water,
    '28 de dano e até 12 HP de cura ao acertar.',
    35,
    28,
    .45,
    1.8,
    heal: 12,
  ),
  firestorm(
    'Tornado Ígneo',
    BetaElement.fire,
    BetaElement.wind,
    '26 de dano, explosão de 2m, queimadura e afastamento.',
    42,
    26,
    .55,
    2.2,
    radius: 2,
    burn: 2.5,
    push: 3,
  ),
  eruption(
    'Erupção',
    BetaElement.fire,
    BetaElement.earth,
    '40 de dano e explosão de 1,6m. Canalização mais lenta.',
    45,
    40,
    .65,
    2.4,
    radius: 1.6,
  ),
  mist(
    'Névoa',
    BetaElement.water,
    BetaElement.wind,
    '20 de dano em 2,4m. Acertar concede proteção de 50% por 2s.',
    38,
    20,
    .5,
    2,
    radius: 2.4,
    ward: 2,
  ),
  mud(
    'Lama',
    BetaElement.water,
    BetaElement.earth,
    '24 de dano em 2m e lentidão de 4s.',
    38,
    24,
    .55,
    2.1,
    radius: 2,
    slow: 4,
  ),
  shards(
    'Estilhaços',
    BetaElement.wind,
    BetaElement.earth,
    '34 de dano. Interrompe o alvo; guardião se recupera mais rápido.',
    40,
    34,
    .5,
    2,
    stagger: .8,
  );

  const BetaCombo(
    this.label,
    this.first,
    this.second,
    this.description,
    this.mana,
    this.damage,
    this.castTime,
    this.cooldown, {
    this.radius = 0,
    this.burn = 0,
    this.slow = 0,
    this.heal = 0,
    this.ward = 0,
    this.push = 0,
    this.stagger = 0,
  });
  final String label, description;
  final BetaElement first, second;
  final int mana;
  final double damage,
      castTime,
      cooldown,
      radius,
      burn,
      slow,
      heal,
      ward,
      push,
      stagger;
  String get recipe => '${first.label} + ${second.label}';

  static BetaCombo? resolve(BetaElement first, BetaElement? second) {
    if (second == null || first == second) return null;
    for (final combo in values) {
      if ((combo.first == first && combo.second == second) ||
          (combo.first == second && combo.second == first)) {
        return combo;
      }
    }
    return null;
  }
}
