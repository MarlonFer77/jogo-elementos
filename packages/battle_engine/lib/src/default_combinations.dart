import 'combination_book.dart';
import 'element_combination.dart';
import 'elements.dart';

/// Built-in combinations, from the game's design examples. Data-driven —
/// new combinations are added as entries, not as new code paths.
///
/// Damage: 2-element combinations deal 20, the 3-element one deals 35 —
/// harder to set up, pays more (see the damage/HP/victory design doc).
final defaultCombinationBook = CombinationBook([
  ElementCombination(
    elements: [Elements.fire, Elements.wind],
    resultId: 'ignited_storm',
    resultName: 'Tempestade Ígnea',
    description: 'Fogo espalhado pelo vento; dano em área.',
    damage: 20,
  ),
  ElementCombination(
    elements: [Elements.water, Elements.lightning],
    resultId: 'electrified_field',
    resultName: 'Campo Eletrocutado',
    description: 'Água carregada de eletricidade; choca quem entrar no campo.',
    damage: 20,
  ),
  ElementCombination(
    elements: [Elements.earth, Elements.fire, Elements.water],
    resultId: 'lava',
    resultName: 'Lava',
    description: 'Terra fundida pelo fogo; terreno perigoso e persistente.',
    damage: 35,
  ),
]);
