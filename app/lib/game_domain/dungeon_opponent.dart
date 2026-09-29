import 'combination_catalog.dart';
import 'dungeon_catalog.dart';
import 'element_catalog.dart';
import 'training_match.dart';

/// A committed telegraph, not a promise of exact damage after the player's move.
class DungeonIntent {
  const DungeonIntent({
    required this.name,
    required this.hint,
    this.elements = const [],
    this.attackId,
    this.defending = false,
    this.thawing = false,
    this.apCost = 0,
    this.enraged = false,
    this.interruption,
  });
  final String name, hint;
  final List<String> elements;
  final String? attackId, interruption;
  final bool defending, thawing, enraged;
  final int apCost;
}

class DungeonOpponent {
  static bool _has(TrainingMatch match, String status) =>
      match.playerBActiveStatuses.any((s) => s.id == status);

  static DungeonIntent _basic(
    String id, {
    bool enraged = false,
    String? interruption,
    String? hint,
  }) {
    final element = const ElementCatalog().all().firstWhere((e) => e.id == id);
    return DungeonIntent(
      name: element.name,
      elements: List.unmodifiable([id]),
      hint: hint ?? 'Ataque básico · defender reduz o impacto.',
      enraged: enraged,
      interruption: interruption,
    );
  }

  static DungeonIntent _thaw({bool enraged = false, String? interruption}) =>
      DungeonIntent(
        name: 'Quebrar gelo',
        hint: 'Perde a ação · oportunidade para preparar seu combo.',
        thawing: true,
        enraged: enraged,
        interruption: interruption,
      );

  static DungeonIntent plan(TrainingMatch match, DungeonRoom room) {
    if (match.isOver) throw StateError('A batalha terminou.');
    final enraged =
        room.enragedPattern.isNotEmpty &&
        match.playerBCurrentHp * 2 <= match.playerBMaxHp;
    if (_has(match, 'freeze')) return _thaw(enraged: enraged);
    final pattern = enraged ? room.enragedPattern : room.pattern;
    final move = pattern[match.cumulativeTurnsPlayedB % pattern.length];
    if (move == 'guard') {
      return DungeonIntent(
        name: 'Defender',
        hint: 'Vai se proteger · prepare AP ou aplique pressão.',
        defending: true,
        enraged: enraged,
      );
    }
    if (match.equippedElementIdsForPlayerB.contains(move)) {
      return _basic(move, enraged: enraged);
    }
    final combo = const CombinationCatalog().byId(move);
    if (combo != null &&
        match.equippedAttackIdsForPlayerB.contains(move) &&
        combo.elementIds.every(match.equippedElementIdsForPlayerB.contains) &&
        !_has(match, 'silence') &&
        match.opponentAvailableAp >=
            match.opponentAttackCost(combo.elementIds.length)) {
      return DungeonIntent(
        name: combo.name,
        hint: 'Combo · defenda ou interrompa a conjuração.',
        elements: List.unmodifiable(combo.elementIds),
        attackId: combo.id,
        apCost: match.opponentAttackCost(combo.elementIds.length),
        enraged: enraged,
      );
    }
    return _basic(
      match.equippedElementIdsForPlayerB.first,
      enraged: enraged,
      hint: _has(match, 'silence')
          ? 'Silenciado · só pode atacar com um elemento.'
          : 'Ataque básico · acumula AP para conjurar.',
    );
  }

  /// Revalidate without choosing a stronger move after seeing the player's action.
  static DungeonIntent resolve(TrainingMatch match, DungeonIntent intent) {
    if (match.isOver || match.isPlayerATurn) {
      throw StateError('Não é a vez do inimigo.');
    }
    if (match.currentPlayerIsFrozen) {
      return _thaw(
        enraged: intent.enraged,
        interruption: intent.thawing ? null : 'Plano interrompido: congelado.',
      );
    }
    final reason = intent.attackId == null
        ? null
        : match.attackUnavailableReason(intent.attackId!);
    if (reason != null ||
        intent.thawing ||
        intent.elements.any(
          (id) => !match.equippedElementIdsForPlayerB.contains(id),
        )) {
      return _basic(
        match.equippedElementIdsForPlayerB.first,
        enraged: intent.enraged,
        interruption: 'Plano interrompido: ${reason ?? 'ação indisponível.'}',
      );
    }
    return intent;
  }
}
