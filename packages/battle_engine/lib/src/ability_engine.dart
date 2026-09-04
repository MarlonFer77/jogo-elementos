import 'ability.dart';
import 'ability_effect.dart';
import 'ability_result.dart';
import 'battle_state.dart';
import 'combatant.dart';
import 'combination_modifier.dart';
import 'targeted_status.dart';
import 'turn_action.dart';
import 'turn_engine.dart';

/// Resolves the use of an [Ability]: plays its base elements as a normal
/// turn (via [TurnEngine], so combinations still trigger, combo damage and
/// the win condition are already resolved, and the turn still passes),
/// then applies whatever its mutations add — a field effect, and any
/// [TargetedStatus]es on whichever side each one targets (most, like
/// Combustão, land on the opponent; a defensive one like Guarda targets
/// the actor instead — see [StatusTarget]). [AbilityEffect.hitCount] and
/// [AbilityEffect.critChanceBonus] are still not consumed by anything;
/// they're carried through for a future combat system to read.
class AbilityEngine {
  final TurnEngine turnEngine;

  const AbilityEngine(this.turnEngine);

  /// [combinationModifiers] is the actor's build-level extension point over
  /// a triggered combination's result (see [TurnEngine.playTurn]) —
  /// typically `build.combinationModifiers`.
  AbilityResult useAbility(
    BattleState state,
    Combatant actor,
    Ability ability, {
    List<CombinationModifier> combinationModifiers = const [],
  }) {
    final turnResult = turnEngine.playTurn(
      state,
      TurnAction(actor: actor, elements: ability.baseElements),
      combinationModifiers: combinationModifiers,
    );

    var effect = const AbilityEffect();
    for (final mutation in ability.mutations) {
      effect = mutation.apply(effect);
    }

    var nextState = turnResult.state;
    if (effect.fieldEffect != null) {
      nextState = nextState.withFieldEffect(effect.fieldEffect!);
    }
    if (effect.statusesToApply.isNotEmpty) {
      final opponent = state.opponentOf(actor);
      for (final targeted in effect.statusesToApply) {
        final target =
            targeted.target == StatusTarget.actor ? actor : opponent;
        nextState = nextState.withStatusApplied(target, targeted.status);
      }
    }

    return AbilityResult(
      state: nextState,
      effect: effect,
      triggeredCombination: turnResult.triggeredCombination,
    );
  }
}
