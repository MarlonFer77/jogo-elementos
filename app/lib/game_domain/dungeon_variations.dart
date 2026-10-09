import 'dart:math';
import 'dungeon_catalog.dart';

/// IDs, not an RNG seed, are saved so reopening never changes an expedition.
/// An empty route denotes the original encounters used by legacy saves.
class DungeonVariations {
  static List<String> roll(Random random) {
    final route = <String>[];
    for (var block = 0; block < 3; block++) {
      route.addAll(
        DungeonTactic.values.map((t) => t.name).toList()..shuffle(random),
      );
    }
    route.add(DungeonTactic.values[random.nextInt(3)].name);
    return List.unmodifiable(route);
  }

  static bool validRoute(List<String> route) =>
      route.isEmpty ||
      (route.length == DungeonRoom.all.length &&
          route.every((id) => DungeonTactic.values.any((t) => t.name == id)));

  static DungeonRoom room(int index, [String? id]) {
    final base = DungeonRoom.all[index];
    if (id == null) return base;
    final tactic = DungeonTactic.values.firstWhere(
      (t) => t.name == id,
      orElse: () => throw StateError('Variação de sala desconhecida.'),
    );
    final variant = _rooms[index][tactic.index];
    final attacks = [...variant.pattern, ...variant.enragedPattern]
        .where((move) => move != 'guard' && !variant.elements.contains(move))
        .toSet()
        .toList();
    return DungeonRoom(
      base.name,
      variant.hint,
      variant.elements,
      List.unmodifiable(attacks),
      base.hp,
      base.xp,
      appearance: base.appearance,
      arena: base.arena,
      initialAp: base.initialAp,
      tactic: tactic,
      pattern: variant.pattern,
      enragedPattern: variant.enragedPattern,
    );
  }

  // Each row is one room; columns are assault / bulwark / control.
  // Keep costs, stats and XP unchanged; allow basic-action gaps between spells.
  static const _rooms = [
    [
      _Variation(
        ['fire', 'wind'],
        ['fire', 'wind', 'ignited_storm'],
        'Pressão de fogo. Água básica apaga sua Queimadura.',
      ),
      _Variation(
        ['fire', 'wind'],
        ['fire', 'guard', 'wind', 'ignited_storm', 'guard'],
        'Ataca entre defesas. Acumule AP enquanto ele se protege.',
      ),
      _Variation(
        ['fire', 'lightning'],
        ['fire', 'lightning', 'fulgor', 'fire'],
        'Fulgor encarece combos com Choque. Reserve AP ou use um básico.',
      ),
    ],
    [
      _Variation(
        ['ice', 'wind'],
        ['ice', 'wind', 'winter_gale', 'ice'],
        'Pressão glacial com Lentidão. Guarde AP antes do Vento Invernal.',
      ),
      _Variation(
        ['ice', 'nature'],
        ['ice', 'guard', 'living_crystal', 'nature', 'ice', 'ice'],
        'Cristal Vivo cura e protege. Prepare dano concentrado após a proteção.',
      ),
      _Variation(
        ['water', 'ice'],
        ['water', 'ice', 'glacial_prison', 'water', 'ice'],
        'Prisão Glacial congela. Escudo ou interrupção evitam perder a ação.',
      ),
    ],
    [
      _Variation(
        ['earth', 'fire'],
        ['earth', 'fire', 'eruption', 'earth'],
        'Erupção concentra dano. Defender antes do impacto reduz a explosão.',
      ),
      _Variation(
        ['earth', 'nature'],
        ['guard', 'earth', 'deep_roots', 'nature', 'earth'],
        'Raízes protegem e atrasam AP. Ataque nas aberturas entre proteções.',
      ),
      _Variation(
        ['earth', 'water'],
        ['water', 'earth', 'quagmire', 'earth', 'water'],
        'Lama Profunda impede regeneração de AP. Planeje sua reserva.',
      ),
    ],
    [
      _Variation(
        ['fire', 'light', 'wind'],
        ['fire', 'solar_flame', 'wind', 'fire', 'ignited_storm'],
        'Fortalece a ofensiva solar. Observe o próximo golpe antes de gastar AP.',
      ),
      _Variation(
        ['fire', 'light', 'wind'],
        ['guard', 'wind', 'aurora', 'light', 'fire', 'solar_flame'],
        'Aurora protege e fortalece. Defesa ajuda a atravessar o contra-ataque.',
      ),
      _Variation(
        ['fire', 'light', 'lightning'],
        ['lightning', 'fulgor', 'light', 'fire', 'solar_flame'],
        'Alterna Choque e fortalecimento. Um básico preserva AP sob Choque.',
      ),
    ],
    [
      _Variation(
        ['water', 'lightning', 'wind'],
        ['lightning', 'static_gale', 'wind', 'water', 'static_gale'],
        'Rajadas frequentes encarecem seus combos. Antecipe o gasto de AP.',
      ),
      _Variation(
        ['water', 'lightning', 'wind'],
        ['guard', 'water', 'electrified_field', 'wind', 'lightning'],
        'Campo Eletrocutado reduz o próximo golpe. Evite gastar seu combo na proteção.',
      ),
      _Variation(
        ['water', 'nature', 'lightning'],
        ['water', 'swamp', 'lightning', 'nature', 'electric_sap'],
        'Pântano aplica Molhado e Lentidão; Raio explora Molhado. Defenda o golpe anunciado.',
      ),
    ],
    [
      _Variation(
        ['shadow', 'poison', 'wind'],
        ['poison', 'wind', 'pestilence', 'shadow', 'poison', 'toxic_hex'],
        'Desgaste por Veneno. Natureza básica neutraliza o próprio Veneno.',
      ),
      _Variation(
        ['shadow', 'earth', 'wind'],
        ['guard', 'earth', 'shadow_stone', 'wind', 'shadow', 'rock_gale'],
        'Pedra Sombria protege e drena AP. Não conte com uma reserva exata.',
      ),
      _Variation(
        ['shadow', 'poison', 'wind'],
        ['shadow', 'wind', 'silent_gale', 'poison', 'shadow', 'toxic_hex'],
        'Silêncio bloqueia combos. Prepare básicos, Escudo ou interrupção.',
      ),
    ],
    [
      _Variation(
        ['earth', 'nature', 'fire'],
        ['fire', 'earth', 'eruption', 'nature', 'fire', 'vital_ember'],
        'Madeira em brasa troca proteção por explosão. Defenda a Erupção anunciada.',
      ),
      _Variation(
        ['earth', 'nature', 'light'],
        ['guard', 'earth', 'crystal_wall', 'nature', 'light', 'living_ward'],
        'Escudo absorve um golpe. Rompa com um básico antes de investir no combo.',
      ),
      _Variation(
        ['earth', 'nature', 'water'],
        ['water', 'nature', 'swamp', 'earth', 'water', 'deep_roots'],
        'Raízes e Pântano atrasam AP. Acumule energia nas ações básicas do Ent.',
      ),
    ],
    [
      _Variation(
        ['water', 'lightning', 'wind'],
        [
          'lightning',
          'water',
          'thunderstorm',
          'lightning',
          'water',
          'wind',
          'guard',
        ],
        'Temporal Elétrico custa 5 AP. Use a intenção para preparar sua defesa.',
      ),
      _Variation(
        ['water', 'lightning', 'earth'],
        [
          'guard',
          'water',
          'electrified_field',
          'earth',
          'lightning',
          'magnetism',
        ],
        'Proteções elétricas alternadas. Preserve combos fortes para as aberturas.',
      ),
      _Variation(
        ['wind', 'lightning', 'shadow'],
        ['wind', 'shadow', 'silent_gale', 'lightning', 'wind', 'dark_thunder'],
        'Silêncio e drenagem de AP. Interrompa a conjuração ou jogue com básicos.',
      ),
    ],
    [
      _Variation(
        ['nature', 'poison', 'shadow'],
        [
          'poison',
          'shadow',
          'plague_garden',
          'nature',
          'poison',
          'shadow',
          'guard',
        ],
        'Jardim da Peste causa Veneno forte. Leve Natureza ou uma purificação.',
      ),
      _Variation(
        ['earth', 'poison', 'nature'],
        ['guard', 'earth', 'toxic_rock', 'nature', 'poison', 'deep_roots'],
        'Veneno por trás da proteção. Remova o desgaste enquanto prepara sua abertura.',
      ),
      _Variation(
        ['poison', 'shadow', 'wind'],
        ['shadow', 'wind', 'silent_gale', 'poison', 'shadow', 'toxic_hex'],
        'Silêncio protege a teia venenosa. Natureza básica continua disponível silenciado.',
      ),
    ],
    [
      _Variation(
        ['fire', 'earth', 'water', 'wind'],
        [
          'fire',
          'wind',
          'lava',
          'earth',
          'fire',
          'ignited_storm',
          'water',
          'guard',
        ],
        'Lava concentra 35 de dano-base. Abaixo de 50% HP, alterna fogo e explosões; a intenção não muda após sua ação.',
        enragedPattern: [
          'fire',
          'wind',
          'ignited_storm',
          'fire',
          'earth',
          'wind',
          'water',
          'lava',
        ],
      ),
      _Variation(
        ['fire', 'earth', 'light', 'wind'],
        [
          'guard',
          'earth',
          'crystal_wall',
          'fire',
          'light',
          'solar_flame',
          'wind',
        ],
        'Rompa o Escudo antes do combo. Abaixo de 50% HP, Aurora prepara os contra-ataques; observe a intenção.',
        enragedPattern: [
          'wind',
          'earth',
          'aurora',
          'fire',
          'light',
          'solar_flame',
          'guard',
        ],
      ),
      _Variation(
        ['fire', 'earth', 'water', 'shadow'],
        ['water', 'earth', 'abyss', 'fire', 'water', 'guard', 'lava'],
        'Abismo drena AP. Abaixo de 50% HP, Lama Profunda atrasa sua reserva entre conjurações de Lava.',
        enragedPattern: [
          'water',
          'shadow',
          'abyss',
          'fire',
          'earth',
          'quagmire',
          'water',
          'earth',
          'guard',
          'lava',
        ],
      ),
    ],
  ];
}

class _Variation {
  const _Variation(
    this.elements,
    this.pattern,
    this.hint, {
    this.enragedPattern = const [],
  });
  final List<String> elements, pattern, enragedPattern;
  final String hint;
}
