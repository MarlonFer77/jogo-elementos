import 'battle_state.dart';
import 'combatant.dart';
import 'combination_book.dart';
import 'combination_modifier.dart';
import 'status_effects.dart';
import 'turn_action.dart';
import 'turn_result.dart';

/// Resolves one turn at a time. Pure logic: given a state and an action,
/// produces the next state — including combination damage, Escudo
/// blocking, status damage-over-time ticks, and the win condition. Does
/// not know about Skill Tree/Build (mutations/combination modifiers are
/// passed in by the caller) or about persistence/the backend.
class TurnEngine {
  final CombinationBook combinationBook;

  const TurnEngine(this.combinationBook);

  /// Resolves [action] against [state]:
  /// - rejects it if the battle already has a [BattleState.winner]
  /// - rejects it if it's not [TurnAction.actor]'s turn
  /// - resolves a combination from the played elements, if 2 or 3 were played
  /// - runs the triggered combination's [FieldEffect] through
  ///   [combinationModifiers], in order (bigger area, shorter duration...)
  /// - adds the (possibly modified) effect to the field
  /// - if it deals damage, applies it to the opponent — unless the
  ///   opponent has an active Escudo, which blocks the hit entirely and
  ///   is then consumed
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

    final combination = action.elements.length >= 2
        ? combinationBook.resolve(action.elements)
        : null;

    final opponent = state.opponentOf(action.actor);
    var nextState = state.copyWith(currentTurn: opponent);

    if (combination != null) {
      var fieldEffect = combination.result;
      for (final modifier in combinationModifiers) {
        fieldEffect = modifier.apply(fieldEffect);
      }
      nextState = nextState.withFieldEffect(fieldEffect);
      nextState = _applyComboDamage(nextState, opponent, fieldEffect.damage);
    }

    nextState = _tickStatusDamage(nextState, action.actor);

    return TurnResult(state: nextState, triggeredCombination: combination);
  }

  BattleState _applyComboDamage(
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
