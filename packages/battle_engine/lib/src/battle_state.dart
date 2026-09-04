import 'active_status.dart';
import 'combatant.dart';
import 'field_effect.dart';
import 'hp_pool.dart';
import 'status_effect.dart';

/// Snapshot of an in-progress 1v1 battle: the two participants, any active
/// field effects (produced by element combinations or ability mutations),
/// the status effects and HP of each combatant, whose turn it is, and who
/// won (if the battle is over).
///
/// Pure data, immutable. Turn order, damage resolution and win/loss belong
/// to [TurnEngine] — this class only represents a valid state and how to
/// derive the next one.
class BattleState {
  final Combatant playerA;
  final Combatant playerB;
  final Combatant currentTurn;
  final List<FieldEffect> activeFieldEffects;
  final Map<Combatant, List<ActiveStatus>> combatantStatuses;
  final Map<Combatant, HpPool> hp;
  final Combatant? winner;

  BattleState({
    required this.playerA,
    required this.playerB,
    required this.currentTurn,
    List<FieldEffect> activeFieldEffects = const [],
    Map<Combatant, List<ActiveStatus>>? combatantStatuses,
    Map<Combatant, HpPool>? hp,
    this.winner,
  })  : activeFieldEffects = List.unmodifiable(activeFieldEffects),
        combatantStatuses = Map<Combatant, List<ActiveStatus>>.unmodifiable({
          playerA: List<ActiveStatus>.unmodifiable(
            combatantStatuses?[playerA] ?? const <ActiveStatus>[],
          ),
          playerB: List<ActiveStatus>.unmodifiable(
            combatantStatuses?[playerB] ?? const <ActiveStatus>[],
          ),
        }),
        hp = Map<Combatant, HpPool>.unmodifiable({
          playerA: hp?[playerA] ?? const HpPool(max: 100, current: 100),
          playerB: hp?[playerB] ?? const HpPool(max: 100, current: 100),
        }) {
    if (playerA == playerB) {
      throw ArgumentError('playerA and playerB must be distinct combatants');
    }
    if (currentTurn != playerA && currentTurn != playerB) {
      throw ArgumentError('currentTurn must be playerA or playerB');
    }
  }

  /// Starts a new battle with an empty field, no statuses, [playerA]
  /// acting first. [playerAMaxHp]/[playerBMaxHp] default to 100 — a
  /// convenience for callers that don't care about HP (most tests). Real
  /// gameplay always computes and passes the real value (base + Skill
  /// Tree bonus) explicitly; nothing in production code relies on this
  /// default.
  factory BattleState.start({
    required Combatant playerA,
    required Combatant playerB,
    int playerAMaxHp = 100,
    int playerBMaxHp = 100,
  }) {
    return BattleState(
      playerA: playerA,
      playerB: playerB,
      currentTurn: playerA,
      hp: {
        playerA: HpPool(max: playerAMaxHp, current: playerAMaxHp),
        playerB: HpPool(max: playerBMaxHp, current: playerBMaxHp),
      },
    );
  }

  BattleState copyWith({
    Combatant? currentTurn,
    List<FieldEffect>? activeFieldEffects,
    Map<Combatant, List<ActiveStatus>>? combatantStatuses,
    Map<Combatant, HpPool>? hp,
    Combatant? winner,
  }) {
    return BattleState(
      playerA: playerA,
      playerB: playerB,
      currentTurn: currentTurn ?? this.currentTurn,
      activeFieldEffects: activeFieldEffects ?? this.activeFieldEffects,
      combatantStatuses: combatantStatuses ?? this.combatantStatuses,
      hp: hp ?? this.hp,
      winner: winner ?? this.winner,
    );
  }

  /// Returns a new state with [effect] added to the field.
  BattleState withFieldEffect(FieldEffect effect) {
    return copyWith(activeFieldEffects: [...activeFieldEffects, effect]);
  }

  /// Returns the other participant relative to [combatant].
  Combatant opponentOf(Combatant combatant) {
    if (combatant == playerA) return playerB;
    if (combatant == playerB) return playerA;
    throw ArgumentError.value(
      combatant,
      'combatant',
      'is not part of this battle',
    );
  }

  /// Active statuses currently applied to [combatant].
  List<ActiveStatus> statusesOf(Combatant combatant) {
    _requireParticipant(combatant);
    return combatantStatuses[combatant] ?? const [];
  }

  /// Whether [combatant] currently has [effect] applied.
  bool hasStatus(Combatant combatant, StatusEffect effect) {
    return statusesOf(combatant).any((status) => status.effect == effect);
  }

  /// Returns a new state with [status] applied to [target].
  BattleState withStatusApplied(Combatant target, ActiveStatus status) {
    _requireParticipant(target);
    final updated = Map<Combatant, List<ActiveStatus>>.from(
      combatantStatuses,
    );
    updated[target] = [...statusesOf(target), status];
    return copyWith(combatantStatuses: updated);
  }

  /// Returns a new state with every active instance of [effect] removed
  /// from [target].
  BattleState withStatusRemoved(Combatant target, StatusEffect effect) {
    _requireParticipant(target);
    final updated = Map<Combatant, List<ActiveStatus>>.from(
      combatantStatuses,
    );
    updated[target] =
        statusesOf(target).where((status) => status.effect != effect).toList();
    return copyWith(combatantStatuses: updated);
  }

  /// Ticks every active status for both combatants by one turn, removing
  /// any that expire. Callers decide when this should run.
  BattleState withStatusesTicked() {
    final updated = <Combatant, List<ActiveStatus>>{
      for (final combatant in [playerA, playerB])
        combatant: statusesOf(combatant)
            .map((status) => status.tick())
            .where((status) => !status.isExpired)
            .toList(),
    };
    return copyWith(combatantStatuses: updated);
  }

  /// HP pool of [combatant].
  HpPool hpOf(Combatant combatant) {
    _requireParticipant(combatant);
    return hp[combatant]!;
  }

  /// Returns a new state with [amount] of damage applied to [target]. If
  /// this brings [target] to 0 HP and nobody has won yet, [target]'s
  /// opponent becomes the winner. Never un-sets an existing winner.
  BattleState withDamage(Combatant target, int amount) {
    _requireParticipant(target);
    final updatedPool = hpOf(target).withDamage(amount);
    final updatedHp = Map<Combatant, HpPool>.from(hp)..[target] = updatedPool;
    final newWinner = (winner == null && updatedPool.isDefeated)
        ? opponentOf(target)
        : winner;
    return copyWith(hp: updatedHp, winner: newWinner);
  }

  /// Returns a new state with [target]'s max (and current) HP increased by
  /// [amount] — used when a mid-battle bonus (e.g. a Skill Tree node)
  /// raises the ceiling.
  BattleState withMaxHpIncreased(Combatant target, int amount) {
    _requireParticipant(target);
    final updatedHp = Map<Combatant, HpPool>.from(hp)
      ..[target] = hpOf(target).withMaxIncreased(amount);
    return copyWith(hp: updatedHp);
  }

  void _requireParticipant(Combatant combatant) {
    if (combatant != playerA && combatant != playerB) {
      throw ArgumentError.value(
        combatant,
        'combatant',
        'is not part of this battle',
      );
    }
  }
}
