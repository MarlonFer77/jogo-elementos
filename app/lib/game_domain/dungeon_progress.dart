import 'package:battle_engine/battle_engine.dart';
import 'dungeon_catalog.dart';
import 'dungeon_blessings.dart';
import 'dungeon_variations.dart';

/// Offline campaign only. Never imported into the multiplayer profile.
class DungeonProgress {
  DungeonProgress({
    this.xp = 0,
    List<String> nodes = const [],
    List<String> attacks = const [],
    List<String> equippedAttacks = const [],
    List<String> elements = const [],
    this.run = 0,
    this.room = 0,
    this.active = false,
    this.hp = 100,
    this.clears = 0,
    List<String> blessings = const [],
    List<String> encounters = const [],
  }) : nodes = List.unmodifiable(nodes),
       attacks = List.unmodifiable(attacks),
       equippedAttacks = List.unmodifiable(equippedAttacks),
       elements = List.unmodifiable(elements),
       blessings = List.unmodifiable(blessings),
       encounters = List.unmodifiable(encounters);

  final int xp, run, room, hp, clears;
  final bool active;
  final List<String> nodes, attacks, equippedAttacks, elements;
  final List<String> blessings;
  final List<String> encounters;
  static const saveVersion = 3;

  DungeonRoom roomAt(int index) => DungeonVariations.room(
    index,
    active && encounters.isNotEmpty ? encounters[index] : null,
  );

  List<DungeonBlessing> get activeBlessings => active
      ? blessings.map((id) => DungeonBlessings.byId(id)!).toList()
      : const [];
  int? get pendingAltar => active && blessings.length < room ~/ 3
      ? DungeonBlessings.milestones[blessings.length]
      : null;
  List<DungeonBlessing> get blessingOffers =>
      pendingAltar == null ? const [] : DungeonBlessings.offers(pendingAltar!);

  DungeonProgress chooseBlessing(String id) {
    if (!blessingOffers.any((b) => b.id == id)) {
      throw StateError('Bênção indisponível ou altar já concluído.');
    }
    return copyWith(blessings: [...blessings, id]);
  }

  bool get prepared => nodes.length >= 2;
  SkillProgress get skills =>
      SkillProgress(defaultSkillTree, unlockedNodeIds: nodes);
  int get maxHp => 100 + skills.grantedMaxHpBonus;
  int get level {
    var level = 1, remaining = xp;
    while (remaining >= xpForLevel(level)) {
      remaining -= xpForLevel(level++);
    }
    return level;
  }

  // First room grants the first build choice; later level costs stay unchanged.
  static int xpForLevel(int level) => level == 1 ? 40 : 100 + (level - 1) * 50;
  int get levelXp =>
      xp - (25 * (level - 1) * (level + 2) - (level > 1 ? 60 : 0));
  int get nextLevelXp => xpForLevel(level);
  int get points => level - 1 - (prepared ? nodes.length - 2 : 0);

  DungeonProgress copyWith({
    int? xp,
    List<String>? nodes,
    List<String>? attacks,
    List<String>? equippedAttacks,
    List<String>? elements,
    int? run,
    int? room,
    bool? active,
    int? hp,
    int? clears,
    List<String>? blessings,
    List<String>? encounters,
  }) => DungeonProgress(
    xp: xp ?? this.xp,
    nodes: nodes ?? this.nodes,
    attacks: attacks ?? this.attacks,
    equippedAttacks: equippedAttacks ?? this.equippedAttacks,
    elements: elements ?? this.elements,
    run: run ?? this.run,
    room: room ?? this.room,
    active: active ?? this.active,
    hp: hp ?? this.hp,
    clears: clears ?? this.clears,
    blessings: blessings ?? this.blessings,
    encounters: encounters ?? this.encounters,
  );

  DungeonProgress prepare(List<String> ids) {
    if (prepared ||
        ids.length != 2 ||
        ids.toSet().length != 2 ||
        ids.any((id) => !Elements.all.any((e) => e.id == id))) {
      throw StateError('Escolha dois elementos diferentes.');
    }
    return copyWith(
      nodes: ids.map((id) => 'unlock_$id').toList(),
      elements: ids,
    );
  }

  String? unlockReason(String id) {
    if (!prepared || points < 1) return 'Ganhe um nível para obter 1 ponto.';
    if (!skills.canUnlock(id)) {
      return 'Habilidade indisponível ou já desbloqueada.';
    }
    return null;
  }

  DungeonProgress unlock(String id) {
    final reason = unlockReason(id);
    if (reason != null) throw StateError(reason);
    final updated = skills.unlock(id);
    final bonus = updated.grantedMaxHpBonus - skills.grantedMaxHpBonus;
    return copyWith(
      nodes: updated.unlockedNodeIds,
      hp: hp + bonus,
      elements: [
        ...elements,
        ...updated.grantedElementIds.where((e) => !elements.contains(e)),
      ].take(4).toList(),
    );
  }

  Map<String, Object> toJson() => {
    'version': saveVersion,
    'blessings': blessings,
    'encounters': encounters,
    'xp': xp,
    'nodes': nodes,
    'attacks': attacks,
    'equippedAttacks': equippedAttacks,
    'elements': elements,
    'run': run,
    'room': room,
    'active': active,
    'hp': hp,
    'clears': clears,
  };

  factory DungeonProgress.fromJson(Map<String, dynamic> json) {
    if (![1, 2, saveVersion].contains(json['version'])) {
      throw const FormatException('Versão de save desconhecida.');
    }
    List<String> ids(String key) => (json[key] as List).cast<String>();
    final p = DungeonProgress(
      xp: json['xp'] as int,
      nodes: ids('nodes'),
      attacks: ids('attacks'),
      equippedAttacks: ids('equippedAttacks'),
      elements: ids('elements'),
      run: json['run'] as int,
      room: json['room'] as int,
      active: json['active'] as bool,
      hp: json['hp'] as int,
      clears: json['clears'] as int,
      blessings: json['version'] == 1 ? const [] : ids('blessings'),
      encounters: json['version'] == saveVersion ? ids('encounters') : const [],
    );
    final knownAttacks = defaultCombinationBook.combinations
        .map((c) => c.resultId)
        .toSet();
    if (!DungeonVariations.validRoute(p.encounters) ||
        (!p.active && p.encounters.isNotEmpty) ||
        p.blessings.length > 3 ||
        (!p.active && p.blessings.isNotEmpty) ||
        p.blessings.length > p.room ~/ 3 ||
        p.blessings.indexed.any(
          (entry) =>
              DungeonBlessings.byId(entry.$2)?.altar !=
              DungeonBlessings.milestones[entry.$1],
        ) ||
        p.xp < 0 ||
        p.xp > 100000000 ||
        p.run < 0 ||
        p.clears < 0 ||
        p.room < 0 ||
        p.room >= DungeonRoom.all.length ||
        p.nodes.toSet().length != p.nodes.length ||
        p.nodes.any((id) => defaultSkillTree.nodeById(id) == null) ||
        (p.nodes.isNotEmpty &&
            (p.nodes.length < 2 ||
                !p.nodes.take(2).every((id) => id.startsWith('unlock_'))))) {
      throw const FormatException('Progresso inválido.');
    }
    final skills = p.skills;
    if (p.points < 0 ||
        p.hp < 1 ||
        p.hp > p.maxHp ||
        (p.active && (!p.prepared || p.run < 1)) ||
        p.nodes.any(
          (id) => !defaultSkillTree
              .nodeById(id)!
              .prerequisites
              .every(p.nodes.contains),
        ) ||
        p.elements.length > 4 ||
        (p.prepared && p.elements.isEmpty) ||
        p.elements.toSet().length != p.elements.length ||
        p.elements.any((id) => !skills.grantedElementIds.contains(id)) ||
        p.attacks.toSet().length != p.attacks.length ||
        p.attacks.any((id) => !knownAttacks.contains(id)) ||
        p.equippedAttacks.length > 3 ||
        p.equippedAttacks.toSet().length != p.equippedAttacks.length ||
        p.equippedAttacks.any((id) => !p.attacks.contains(id))) {
      throw const FormatException('Equipamento ou pontos inválidos.');
    }
    return p;
  }
}
