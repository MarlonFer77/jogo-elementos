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
  List<TargetedStatus> statuses, {
  int healing = 0,
  bool cleanses = false,
  int apDrain = 0,
}) => ElementCombination(
  elements: elements,
  resultId: id,
  resultName: name,
  damage: damage,
  description:
      '$damage de dano. '
      '${healing > 0 ? 'Recupera até $healing HP antes do dano contínuo. ' : ''}'
      '${cleanses ? 'Remove seus efeitos negativos antes do dano contínuo; não ignora bloqueios de ação. ' : ''}'
      '${apDrain > 0 ? 'Remove até $apDrain AP do alvo; Escudo bloqueia. ' : ''}'
      '${statuses.map((s) => '${s.target == StatusTarget.actor ? 'Você' : 'Alvo'}: ${s.status.effect.name} (${s.status.turnsRemaining} ações). ${s.status.effect.description}').join(' ')}',
  statusesToApply: statuses,
  healing: healing,
  cleanses: cleanses,
  apDrain: apDrain,
);

/// Built-in combinations, from the game's design examples. Data-driven —
/// new combinations are added as entries, not as new code paths.
///
/// Storm trades burst for burn, electric field trades damage for guard.
/// Lava keeps its 35 direct damage and higher 5 AP cost.
final defaultCombinationBook = CombinationBook([
  // Expansion: preserve existing IDs and one canonical recipe per set.
  _combo('eruption', 'Erupção', [Elements.fire, Elements.earth], 18, []),
  _combo(
    'inferno',
    'Inferno',
    [Elements.fire, Elements.shadow],
    10,
    [],
    apDrain: 1,
  ),
  _combo(
    'fulgor',
    'Fulgor',
    [Elements.fire, Elements.lightning],
    10,
    [_status(StatusEffects.shock, turns: 1, tick: 0, self: false)],
  ),
  _combo(
    'vital_ember',
    'Brasa Vital',
    [Elements.fire, Elements.nature],
    8,
    [],
    healing: 6,
  ),
  _combo(
    'purifying_water',
    'Água Purificadora',
    [Elements.water, Elements.light],
    0,
    [],
    healing: 12,
    cleanses: true,
  ),
  _combo(
    'swamp',
    'Pântano',
    [Elements.water, Elements.nature],
    8,
    [
      _status(StatusEffects.slow, turns: 1, tick: 0, self: false),
      _status(StatusEffects.wet, turns: 2, tick: 0, self: false),
    ],
  ),
  _combo(
    'acid',
    'Ácido',
    [Elements.water, Elements.poison],
    10,
    [_status(StatusEffects.debuff, turns: 1, tick: 0, self: false)],
  ),
  _combo(
    'abyss',
    'Abismo',
    [Elements.water, Elements.shadow],
    8,
    [_status(StatusEffects.wet, turns: 2, tick: 0, self: false)],
    apDrain: 1,
  ),
  _combo(
    'rock_gale',
    'Vendaval Rochoso',
    [Elements.wind, Elements.earth],
    10,
    [_status(StatusEffects.debuff, turns: 1, tick: 0, self: false)],
  ),
  _combo(
    'aurora',
    'Aurora',
    [Elements.wind, Elements.light],
    8,
    [
      _status(StatusEffects.buff, turns: 2, tick: 0, self: true),
      _status(StatusEffects.guard, turns: 1, tick: 0, self: true),
    ],
  ),
  _combo(
    'pestilence',
    'Pestilência',
    [Elements.wind, Elements.poison],
    10,
    [_status(StatusEffects.poison, turns: 2, tick: 3, self: false)],
  ),
  _combo(
    'shadow_frost',
    'Geada Sombria',
    [Elements.ice, Elements.shadow],
    6,
    [
      _status(StatusEffects.freeze, turns: 1, tick: 0, self: false),
      _status(StatusEffects.debuff, turns: 3, tick: 0, self: false),
    ],
  ),
  _combo(
    'living_crystal',
    'Cristal Vivo',
    [Elements.ice, Elements.nature],
    0,
    [_status(StatusEffects.guard, turns: 1, tick: 0, self: true)],
    healing: 8,
  ),
  _combo(
    'sacred_ice',
    'Gelo Sagrado',
    [Elements.ice, Elements.light],
    6,
    [_status(StatusEffects.freeze, turns: 1, tick: 0, self: false)],
    cleanses: true,
  ),
  _combo(
    'toxic_frost',
    'Geada Tóxica',
    [Elements.ice, Elements.poison],
    6,
    [
      _status(StatusEffects.slow, turns: 1, tick: 0, self: false),
      _status(StatusEffects.poison, turns: 3, tick: 1, self: false),
    ],
  ),
  _combo(
    'deep_roots',
    'Raízes Profundas',
    [Elements.nature, Elements.earth],
    8,
    [
      _status(StatusEffects.slow, turns: 1, tick: 0, self: false),
      _status(StatusEffects.guard, turns: 1, tick: 0, self: true),
    ],
  ),
  _combo(
    'shadow_forest',
    'Floresta Sombria',
    [Elements.nature, Elements.shadow],
    8,
    [_status(StatusEffects.debuff, turns: 1, tick: 0, self: false)],
    healing: 4,
  ),
  _combo(
    'electric_sap',
    'Seiva Elétrica',
    [Elements.nature, Elements.lightning],
    8,
    [
      _status(StatusEffects.shock, turns: 1, tick: 0, self: false),
      _status(StatusEffects.buff, turns: 2, tick: 0, self: true),
    ],
  ),
  _combo(
    'magnetism',
    'Magnetismo',
    [Elements.lightning, Elements.earth],
    8,
    [
      _status(StatusEffects.shock, turns: 1, tick: 0, self: false),
      _status(StatusEffects.guard, turns: 1, tick: 0, self: true),
    ],
  ),
  _combo(
    'holy_lightning',
    'Raio Sagrado',
    [Elements.lightning, Elements.light],
    10,
    [],
    cleanses: true,
  ),
  _combo(
    'dark_thunder',
    'Trovão Sombrio',
    [Elements.lightning, Elements.shadow],
    8,
    [_status(StatusEffects.shock, turns: 1, tick: 0, self: false)],
    apDrain: 1,
  ),
  _combo(
    'conductive_toxin',
    'Toxina Condutora',
    [Elements.lightning, Elements.poison],
    8,
    [
      _status(StatusEffects.poison, turns: 3, tick: 1, self: false),
      _status(StatusEffects.wet, turns: 2, tick: 0, self: false),
    ],
  ),
  _combo(
    'shadow_stone',
    'Pedra Sombria',
    [Elements.earth, Elements.shadow],
    6,
    [_status(StatusEffects.guard, turns: 1, tick: 0, self: true)],
    apDrain: 1,
  ),
  _combo(
    'toxic_rock',
    'Rocha Tóxica',
    [Elements.earth, Elements.poison],
    6,
    [
      _status(StatusEffects.poison, turns: 3, tick: 2, self: false),
      _status(StatusEffects.guard, turns: 1, tick: 0, self: true),
    ],
  ),
  _combo(
    'toxic_light',
    'Luz Venenosa',
    [Elements.light, Elements.poison],
    6,
    [
      _status(StatusEffects.poison, turns: 2, tick: 2, self: false),
      _status(StatusEffects.buff, turns: 2, tick: 0, self: true),
    ],
  ),
  _combo(
    'cataclysm',
    'Cataclismo',
    [Elements.fire, Elements.earth, Elements.lightning],
    28,
    [_status(StatusEffects.shock, turns: 1, tick: 0, self: false)],
  ),
  _combo(
    'primordial_volcano',
    'Vulcão Primordial',
    [Elements.fire, Elements.earth, Elements.nature],
    22,
    [],
    healing: 10,
  ),
  _combo(
    'deluge',
    'Dilúvio',
    [Elements.water, Elements.wind, Elements.ice],
    18,
    [
      _status(StatusEffects.freeze, turns: 1, tick: 0, self: false),
      _status(StatusEffects.wet, turns: 3, tick: 0, self: false),
    ],
  ),
  _combo(
    'solstice',
    'Solstício',
    [Elements.fire, Elements.light, Elements.nature],
    18,
    [_status(StatusEffects.buff, turns: 2, tick: 0, self: true)],
    healing: 12,
  ),
  _combo(
    'total_eclipse',
    'Eclipse Total',
    [Elements.shadow, Elements.light, Elements.lightning],
    20,
    [
      _status(StatusEffects.silence, turns: 1, tick: 0, self: false),
      _status(StatusEffects.debuff, turns: 2, tick: 0, self: false),
    ],
  ),
  _combo(
    'green_plague',
    'Praga Verde',
    [Elements.nature, Elements.poison, Elements.water],
    18,
    [
      _status(StatusEffects.slow, turns: 1, tick: 0, self: false),
      _status(StatusEffects.poison, turns: 3, tick: 2, self: false),
    ],
  ),
  _combo(
    'eternal_winter',
    'Inverno Eterno',
    [Elements.ice, Elements.wind, Elements.shadow],
    14,
    [
      _status(StatusEffects.freeze, turns: 1, tick: 0, self: false),
      _status(StatusEffects.slow, turns: 3, tick: 0, self: false),
    ],
  ),
  _combo(
    'colossus',
    'Colosso',
    [Elements.earth, Elements.nature, Elements.shadow],
    18,
    [
      _status(StatusEffects.shield, turns: 2, tick: 0, self: true),
      _status(StatusEffects.buff, turns: 2, tick: 0, self: true),
    ],
  ),
  _combo(
    'black_storm',
    'Tempestade Negra',
    [Elements.lightning, Elements.wind, Elements.shadow],
    22,
    [_status(StatusEffects.shock, turns: 1, tick: 0, self: false)],
    apDrain: 1,
  ),
  _combo(
    'crystal_heart',
    'Coração de Cristal',
    [Elements.earth, Elements.ice, Elements.light],
    0,
    [_status(StatusEffects.shield, turns: 2, tick: 0, self: true)],
    healing: 12,
    cleanses: true,
  ),
  _combo(
    'burning_plague',
    'Peste Ardente',
    [Elements.fire, Elements.poison, Elements.shadow],
    16,
    [
      _status(StatusEffects.burn, turns: 2, tick: 3, self: false),
      _status(StatusEffects.poison, turns: 3, tick: 2, self: false),
    ],
  ),
  _combo(
    'primordial_sea',
    'Mar Primordial',
    [Elements.water, Elements.nature, Elements.light],
    0,
    [],
    healing: 24,
    cleanses: true,
  ),
  _combo(
    'astral_vacuum',
    'Vácuo Astral',
    [Elements.shadow, Elements.wind, Elements.light],
    18,
    [_status(StatusEffects.silence, turns: 1, tick: 0, self: false)],
    apDrain: 2,
  ),
  _combo(
    'celestial_storm',
    'Tempestade Celestial',
    [Elements.lightning, Elements.light, Elements.wind],
    24,
    [_status(StatusEffects.buff, turns: 2, tick: 0, self: true)],
    cleanses: true,
  ),
  _combo(
    'ancient_forest',
    'Floresta Ancestral',
    [Elements.nature, Elements.earth, Elements.water],
    14,
    [
      _status(StatusEffects.slow, turns: 1, tick: 0, self: false),
      _status(StatusEffects.guard, turns: 1, tick: 0, self: true),
    ],
    healing: 12,
  ),
  _combo(
    'glacial_aurora',
    'Aurora Glacial',
    [Elements.ice, Elements.light, Elements.wind],
    16,
    [
      _status(StatusEffects.freeze, turns: 1, tick: 0, self: false),
      _status(StatusEffects.guard, turns: 1, tick: 0, self: true),
    ],
  ),
  _combo(
    'volcanic_dragon',
    'Dragão Vulcânico',
    [Elements.fire, Elements.earth, Elements.shadow],
    26,
    [_status(StatusEffects.burn, turns: 2, tick: 3, self: false)],
  ),
  _combo(
    'nova',
    'Nova',
    [Elements.fire, Elements.light, Elements.lightning],
    32,
    [],
    cleanses: true,
  ),
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
