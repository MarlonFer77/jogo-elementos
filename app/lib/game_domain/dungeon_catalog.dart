/// Ordered difficulty curve; shared by checkpoints, battle setup and UI.
class DungeonRoom {
  const DungeonRoom(
    this.name,
    this.hint,
    this.elements,
    this.attacks,
    this.hp,
    this.xp, {
    this.initialAp = 0,
  });
  final String name, hint;
  final List<String> elements, attacks;
  final int hp, xp, initialAp;

  static int get totalXp => all.fold(0, (sum, room) => sum + room.xp);
  static const all = [
    DungeonRoom(
      'Vigia das Brasas',
      'Fogo e vento · pressão ofensiva',
      ['fire', 'wind'],
      ['ignited_storm'],
      35,
      40,
    ),
    DungeonRoom(
      'Sentinela Glacial',
      'Água e gelo · controle de turnos',
      ['water', 'ice'],
      ['glacial_prison'],
      55,
      60,
    ),
    DungeonRoom(
      'Golem do Pântano',
      'Terra e água · lentidão',
      ['earth', 'water'],
      ['quagmire'],
      65,
      70,
    ),
    DungeonRoom(
      'Arauto Solar',
      'Chama Solar e Tempestade Ígnea',
      ['fire', 'light', 'wind'],
      ['solar_flame', 'ignited_storm'],
      75,
      80,
      initialAp: 1,
    ),
    DungeonRoom(
      'Vigia da Tempestade',
      'Defesa elétrica e choque',
      ['water', 'lightning', 'wind'],
      ['electrified_field', 'static_gale'],
      85,
      90,
      initialAp: 1,
    ),
    DungeonRoom(
      'Oráculo Sombrio',
      'Silêncio, veneno e enfraquecimento',
      ['shadow', 'poison', 'wind'],
      ['toxic_hex', 'silent_gale'],
      95,
      100,
      initialAp: 1,
    ),
    DungeonRoom(
      'Guardião do Bosque',
      'Escudo e defesa · prepare o impacto',
      ['earth', 'nature', 'light'],
      ['sacred_grove', 'crystal_wall', 'living_ward'],
      105,
      110,
      initialAp: 2,
    ),
    DungeonRoom(
      'Senhor dos Trovões',
      'Temporal Elétrico · pressão de AP',
      ['water', 'lightning', 'wind'],
      ['thunderstorm', 'electrified_field', 'static_gale'],
      115,
      120,
      initialAp: 2,
    ),
    DungeonRoom(
      'Soberano da Peste',
      'Jardim da Peste · desgaste contínuo',
      ['nature', 'poison', 'shadow'],
      ['plague_garden', 'toxic_hex', 'toxic_bloom'],
      130,
      150,
      initialAp: 2,
    ),
    DungeonRoom(
      'Guardião da Ruína',
      'Lava, lentidão e Queimadura · chefe final',
      ['fire', 'earth', 'water', 'wind'],
      ['lava', 'quagmire', 'ignited_storm'],
      150,
      180,
      initialAp: 3,
    ),
  ];
}
