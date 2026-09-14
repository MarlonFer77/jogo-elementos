import 'battle_state.dart';
import 'combatant.dart';
import 'combination_book.dart';
import 'combination_modifier.dart';
import 'status_effects.dart';
import 'turn_action.dart';
import 'turn_result.dart';

/// Resolves one turn at a time. Pure logic: given a state and an action,
/// produces the next state — including AP (regen, cost, rejection),
/// combination damage, basic (single-element) damage, Escudo blocking,
/// status damage-over-time ticks, and the win condition. Does not know
/// about Skill Tree/Build (mutations/combination modifiers are passed in
/// by the caller) or about persistence/the backend.
class TurnEngine {
  final CombinationBook combinationBook;

  static const _basicDamage = 5;
  static const _comboApCost = {2: 3, 3: 5};

  const TurnEngine(this.combinationBook);

  /// Resolves [action] against [state]:
  /// - rejects it if the battle already has a [BattleState.winner]
  /// - rejects it if it's not [TurnAction.actor]'s turn
  /// - regenerates 1 AP for [TurnAction.actor] (clamped at their max)
  /// - if 2 or 3 elements were played, rejects the whole action (no AP
  ///   spent, no damage, turn doesn't pass) if the actor can't afford it
  ///   (2 elements cost 3 AP, 3 elements cost 5), otherwise spends it
  /// - resolves a combination from the played elements, if 2 or 3 were
  ///   played
  /// - runs the triggered combination's [FieldEffect] through
  ///   [combinationModifiers], in order (bigger area, shorter duration...)
  /// - adds the (possibly modified) effect to the field
  /// - if it deals damage, applies it to the opponent — unless the
  ///   opponent has an active Escudo, which blocks the hit entirely and
  ///   is then consumed
  /// - a single played element never resolves a combination — instead it
  ///   always deals a flat basic damage to the opponent (same Escudo
  ///   blocking rule)
  /// - passes the turn to the opponent
  /// - ticks every active status for both combatants, applying each
  ///   status's `damagePerTick` to its owner (including the tick that
  ///   expires it)
  /// - sets [BattleState.winner] the moment either combatant's HP reaches
  ///   0; if both would be defeated in the same resolution, [action]'s
  ///   actor wins the tie
  TurnResult playTurn(
    BattleState state,
    TurnAction action, {
    List<CombinationModifier> combinationModifiers = const [],
  }) {
    if (state.winner != null) {
      throw StateError('The battle is already over');
    }
    if (action.actor != state.currentTurn) {
      throw StateError('It is not ${action.actor}\'s turn');
    }

    var nextState = state.withApRegenerated(action.actor);

    final elementCount = action.elements.length;
    if (elementCount >= 2) {
      final cost = _comboApCost[elementCount]!;
      if (!nextState.apOf(action.actor).canAfford(cost)) {
        throw StateError(
          'Not enough AP for a $elementCount-element combination',
        );
      }
      nextState = nextState.withApSpent(action.actor, cost);
    }

    final combination = elementCount >= 2
        ? combinationBook.resolve(action.elements)
        : null;

    final opponent = nextState.opponentOf(action.actor);
    nextState = nextState.copyWith(currentTurn: opponent);

    if (combination != null) {
      var fieldEffect = combination.result;
      for (final modifier in combinationModifiers) {
        fieldEffect = modifier.apply(fieldEffect);
      }
      nextState = nextState.withFieldEffect(fieldEffect);
      nextState = _applyDamage(nextState, opponent, fieldEffect.damage);
    } else if (elementCount == 1) {
      nextState = _applyDamage(nextState, opponent, _basicDamage);
    }

    nextState = _tickStatusDamage(nextState, action.actor);

    return TurnResult(state: nextState, triggeredCombination: combination);
  }

  BattleState _applyDamage(
    BattleState state,
    Combatant target,
    int damage,
  ) {
    if (damage <= 0) return state;

    if (state.hasStatus(target, StatusEffects.shield)) {
      return state.withStatusRemoved(target, StatusEffects.shield);
    }
    return state.withDamage(target, damage);
  }

  /// Ticks damage-over-time statuses for both combatants. [actor] is
  /// processed last so that, if both combatants would be defeated by this
  /// same tick, [BattleState.withDamage]'s "first defeat sets the winner"
  /// rule makes the actor the winner (see the class doc).
  BattleState _tickStatusDamage(BattleState state, Combatant actor) {
    var result = state;
    final opponent = state.opponentOf(actor);
    for (final combatant in [opponent, actor]) {
      for (final status in state.statusesOf(combatant)) {
        if (status.damagePerTick > 0) {
          result = result.withDamage(combatant, status.damagePerTick);
        }
      }
    }
    return result.withStatusesTicked();
  }
}
