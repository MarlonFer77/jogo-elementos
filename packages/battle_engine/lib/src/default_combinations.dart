import 'combination_book.dart';
import 'element_combination.dart';
import 'elements.dart';
import 'active_status.dart';
import 'status_effects.dart';
import 'targeted_status.dart';

/// Built-in combinations, from the game's design examples. Data-driven —
/// new combinations are added as entries, not as new code paths.
///
/// Storm trades burst for burn, electric field trades damage for guard.
/// Lava keeps its 35 direct damage and higher 5 AP cost.
final defaultCombinationBook = CombinationBook([
  ElementCombination(
    elements: [Elements.fire, Elements.wind],
    resultId: 'ignited_storm',
    resultName: 'Tempestade Ígnea',
    description:
        '14 de dano + Queimadura: 3 ao fim das próximas 2 ações. Escudo bloqueia a aplicação; não acumula Queimadura.',
    damage: 14,
    statusesToApply: [
      TargetedStatus(
        status: ActiveStatus(
          effect: StatusEffects.burn,
          turnsRemaining: 2,
          damagePerTick: 3,
        ),
      ),
    ],
  ),
  ElementCombination(
    elements: [Elements.water, Elements.lightning],
    resultId: 'electrified_field',
    resultName: 'Campo Eletrocutado',
    description:
        '12 de dano + Defesa: reduz o próximo golpe direto em 50%, até o fim da ação adversária. Não reduz Queimadura.',
    damage: 12,
    statusesToApply: [
      TargetedStatus(
        status: ActiveStatus(effect: StatusEffects.guard, turnsRemaining: 1),
        target: StatusTarget.actor,
      ),
    ],
  ),
  ElementCombination(
    elements: [Elements.water, Elements.ice],
    resultId: 'glacial_prison',
    resultName: 'Prisão Glacial',
    description:
        '10 de dano + Congelamento: o alvo perde a próxima ação para quebrar o gelo, sem regenerar AP. Escudo bloqueia ambos.',
    damage: 10,
    statusesToApply: [
      TargetedStatus(status: ActiveStatus(effect: StatusEffects.freeze)),
    ],
  ),
  ElementCombination(
    elements: [Elements.earth, Elements.fire, Elements.water],
    resultId: 'lava',
    resultName: 'Lava',
    description: 'Terra fundida pelo fogo; terreno perigoso e persistente.',
    damage: 35,
  ),
]);
