import 'combatant_appearance.dart';

/// Ordered difficulty curve; shared by checkpoints, battle setup and UI.
class DungeonRoom {
  const DungeonRoom(
    this.name,
    this.hint,
    this.elements,
    this.attacks,
    this.hp,
    this.xp, {
    required this.appearance,
    required this.pattern,
    this.enragedPattern = const [],
    this.initialAp = 0,
  });
  final String name, hint;
  final List<String> elements, attacks;
  final int hp, xp, initialAp;
  final CombatantAppearance appearance;

  /// Element/attack IDs or 'guard'. A blocked spell becomes a basic attack.
  final List<String> pattern, enragedPattern;

  static int get totalXp => all.fold(0, (sum, room) => sum + room.xp);
  static const all = [
    DungeonRoom(
      'Goblin das Brasas',
      'Fogo e vento · pressão ofensiva',
      ['fire', 'wind'],
      ['ignited_storm'],
      35,
      40,
      appearance: CombatantAppearance.emberGoblin,
      pattern: ['fire', 'wind', 'ignited_storm'],
    ),
    DungeonRoom(
      'Elfa Negra Glacial',
      'Água e gelo · controle de turnos',
      ['water', 'ice'],
      ['glacial_prison'],
      55,
      60,
      appearance: CombatantAppearance.frostElf,
      pattern: ['guard', 'water', 'glacial_prison', 'ice'],
    ),
    DungeonRoom(
      'Golem do Pântano',
      'Terra e água · lentidão',
      ['earth', 'water'],
      ['quagmire'],
      65,
      70,
      appearance: CombatantAppearance.swampGolem,
      pattern: ['earth', 'guard', 'quagmire', 'earth'],
    ),
    DungeonRoom(
      'Escaravelho Solar',
      'Chama Solar e Tempestade Ígnea',
      ['fire', 'light', 'wind'],
      ['solar_flame', 'ignited_storm'],
      75,
      80,
      appearance: CombatantAppearance.sunScarab,
      pattern: ['guard', 'solar_flame', 'wind', 'fire', 'ignited_storm'],
      initialAp: 1,
    ),
    DungeonRoom(
      'Harpia da Tempestade',
      'Defesa elétrica e choque',
      ['water', 'lightning', 'wind'],
      ['electrified_field', 'static_gale'],
      85,
      90,
      appearance: CombatantAppearance.stormHarpy,
      pattern: [
        'wind',
        'static_gale',
        'lightning',
        'water',
        'electrified_field',
      ],
      initialAp: 1,
    ),
    DungeonRoom(
      'Oráculo dos Elfos Negros',
      'Silêncio, veneno e enfraquecimento',
      ['shadow', 'poison', 'wind'],
      ['toxic_hex', 'silent_gale'],
      95,
      100,
      appearance: CombatantAppearance.darkElf,
      pattern: ['shadow', 'silent_gale', 'poison', 'guard', 'toxic_hex'],
      initialAp: 1,
    ),
    DungeonRoom(
      'Ent do Bosque',
      'Escudo e defesa · prepare o impacto',
      ['earth', 'nature', 'light'],
      ['sacred_grove', 'crystal_wall', 'living_ward'],
      105,
      110,
      appearance: CombatantAppearance.ancientEnt,
      pattern: [
        'guard',
        'nature',
        'sacred_grove',
        'earth',
        'guard',
        'living_ward',
      ],
      initialAp: 2,
    ),
    DungeonRoom(
      'Troll dos Trovões',
      'Temporal Elétrico · pressão de AP',
      ['water', 'lightning', 'wind'],
      ['thunderstorm', 'electrified_field', 'static_gale'],
      115,
      120,
      appearance: CombatantAppearance.thunderTroll,
      pattern: ['lightning', 'water', 'thunderstorm', 'lightning', 'water'],
      initialAp: 2,
    ),
    DungeonRoom(
      'Aranha da Peste',
      'Jardim da Peste · desgaste contínuo',
      ['nature', 'poison', 'shadow'],
      ['plague_garden', 'toxic_hex', 'toxic_bloom'],
      130,
      150,
      appearance: CombatantAppearance.plagueSpider,
      pattern: [
        'toxic_bloom',
        'shadow',
        'guard',
        'nature',
        'shadow',
        'plague_garden',
      ],
      initialAp: 2,
    ),
    DungeonRoom(
      'Dragão da Ruína',
      'Lava, lentidão e Queimadura · chefe final',
      ['fire', 'earth', 'water', 'wind'],
      ['lava', 'quagmire', 'ignited_storm'],
      150,
      180,
      appearance: CombatantAppearance.ruinDrake,
      pattern: ['guard', 'lava', 'earth', 'water', 'quagmire', 'fire', 'wind'],
      enragedPattern: ['fire', 'wind', 'ignited_storm', 'fire', 'wind', 'lava'],
      initialAp: 3,
    ),
  ];
}
