import 'combination_book.dart';
import 'element_combination.dart';
import 'elements.dart';
import 'active_status.dart';
import 'status_effects.dart';
import 'targeted_status.dart';
import 'element.dart';
import 'status_effect.dart';

TargetedStatus _status(
  StatusEffect effect, {
  bool self = false,
  int turns = 1,
  int tick = 0,
}) => TargetedStatus(
  target: self ? StatusTarget.actor : StatusTarget.opponent,
  status: ActiveStatus(
    effect: effect,
    turnsRemaining: turns,
    damagePerTick: tick,
  ),
);

ElementCombination _combo(
  String id,
  String name,
  List<Element> elements,
  int damage,
  List<TargetedStatus> statuses,
) => ElementCombination(
  elements: elements,
  resultId: id,
  resultName: name,
  damage: damage,
  description:
      '$damage de dano. ${statuses.map((s) => '${s.target == StatusTarget.actor ? 'Você' : 'Alvo'}: ${s.status.effect.name} (${s.status.turnsRemaining} ações). ${s.status.effect.description}').join(' ')}',
  statusesToApply: statuses,
);

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
  _combo(
    'silent_gale',
    'Vendaval Mudo',
    [Elements.wind, Elements.shadow],
    12,
    [_status(StatusEffects.silence)],
  ),
  _combo(
    'quagmire',
    'Lama Profunda',
    [Elements.earth, Elements.water],
    12,
    [_status(StatusEffects.slow)],
  ),
  _combo(
    'solar_flame',
    'Chama Solar',
    [Elements.fire, Elements.light],
    12,
    [_status(StatusEffects.buff, self: true, turns: 2)],
  ),
  _combo(
    'eclipse',
    'Eclipse',
    [Elements.shadow, Elements.light],
    12,
    [_status(StatusEffects.debuff)],
  ),
  _combo(
    'rain_dance',
    'Dança da Chuva',
    [Elements.wind, Elements.water],
    14,
    [_status(StatusEffects.wet, turns: 2)],
  ),
  _combo(
    'toxic_bloom',
    'Floração Tóxica',
    [Elements.nature, Elements.poison],
    12,
    [_status(StatusEffects.poison, turns: 3, tick: 2)],
  ),
  _combo(
    'static_gale',
    'Rajada Estática',
    [Elements.lightning, Elements.wind],
    12,
    [_status(StatusEffects.shock)],
  ),
  _combo(
    'crystal_wall',
    'Muralha de Cristal',
    [Elements.earth, Elements.light],
    6,
    [_status(StatusEffects.shield, self: true, turns: 2)],
  ),
  _combo(
    'living_ward',
    'Guarda Viva',
    [Elements.nature, Elements.light],
    14,
    [_status(StatusEffects.guard, self: true)],
  ),
  _combo(
    'caustic_flame',
    'Chama Cáustica',
    [Elements.fire, Elements.poison],
    10,
    [
      _status(StatusEffects.burn, turns: 2, tick: 3),
      _status(StatusEffects.poison, turns: 3, tick: 1),
    ],
  ),
  _combo(
    'winter_gale',
    'Vento Invernal',
    [Elements.ice, Elements.wind],
    10,
    [_status(StatusEffects.slow), _status(StatusEffects.wet, turns: 2)],
  ),
  _combo(
    'toxic_hex',
    'Maldição Tóxica',
    [Elements.shadow, Elements.poison],
    10,
    [
      _status(StatusEffects.debuff),
      _status(StatusEffects.poison, turns: 3, tick: 1),
    ],
  ),
  _combo(
    'solar_tempest',
    'Tempestade Solar',
    [Elements.fire, Elements.wind, Elements.light],
    26,
    [_status(StatusEffects.buff, self: true, turns: 2)],
  ),
  _combo(
    'sacred_grove',
    'Bosque Sagrado',
    [Elements.earth, Elements.nature, Elements.light],
    18,
    [_status(StatusEffects.shield, self: true, turns: 2)],
  ),
  _combo(
    'thunderstorm',
    'Temporal Elétrico',
    [Elements.water, Elements.lightning, Elements.wind],
    24,
    [_status(StatusEffects.shock)],
  ),
  _combo(
    'plague_garden',
    'Jardim da Peste',
    [Elements.nature, Elements.poison, Elements.shadow],
    24,
    [_status(StatusEffects.poison, turns: 3, tick: 3)],
  ),
]);
