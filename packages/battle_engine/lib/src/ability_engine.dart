import 'ability.dart';
import 'ability_effect.dart';
import 'ability_result.dart';
import 'battle_state.dart';
import 'combatant.dart';
import 'combination_modifier.dart';
import 'targeted_status.dart';
import 'turn_action.dart';
import 'turn_engine.dart';
import 'status_effects.dart';

/// Resolves the use of an [Ability]: plays its base elements as a normal
/// turn (via [TurnEngine], so combinations still trigger, combo damage and
/// the win condition are already resolved, and the turn still passes),
/// then applies whatever its mutations add — a field effect, and any
/// [TargetedStatus]es on whichever side each one targets (most, like
/// Combustão, land on the opponent; a defensive one like Guarda targets
/// the actor instead — see [StatusTarget]). Precision modifies direct combo
/// damage before defense; preview and execution are deterministic.
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
    int? sealDamagePercent,
  }) {
    final combo = ability.baseElements.length > 1
        ? turnEngine.combinationBook.resolve(ability.baseElements)
        : null;
    var effect = const AbilityEffect();
    if (combo != null) {
      for (final mutation in ability.mutations) {
        effect = mutation.apply(effect);
      }
    }
    final focused =
        combo != null &&
        combo.damage > 0 &&
        effect.critChanceBonus > 0 &&
        TurnEngine.availableAp(state, actor) >= state.apOf(actor).max;
    final action = TurnAction(actor: actor, elements: ability.baseElements);
    final recovery = TurnEngine.basicRecoveryStatus(state, action);
    final feedback = <String>[
      if (recovery != null) 'recover_${recovery.id}',
      if (sealDamagePercent != null) 'seal_$sealDamagePercent',
      if (focused) 'focused',
      if (combo != null && combo.damage > 0 && effect.hitCount > 1)
        'fragmented',
    ];
    final turnResult = turnEngine.playTurn(
      state,
      action,
      combinationModifiers: combinationModifiers,
      hitCount: effect.hitCount,
      focusedBonus: focused ? effect.critChanceBonus : 0,
      sealDamagePercent: sealDamagePercent ?? 100,
    );

    // Passives require a real combo (and its AP cost), never a free basic hit.
    if (turnResult.triggeredCombination == null ||
        turnResult.state.winner != null) {
      return AbilityResult(
        state: turnResult.state,
        effect: const AbilityEffect(),
        feedback: feedback,
        triggeredCombination: turnResult.triggeredCombination,
      );
    }

    var nextState = turnResult.state;
    if (effect.fieldEffect != null) {
      nextState = nextState.withFieldEffect(effect.fieldEffect!);
    }
    if (effect.statusesToApply.isNotEmpty) {
      final opponent = state.opponentOf(actor);
      for (final targeted in effect.statusesToApply) {
        final target = targeted.target == StatusTarget.actor ? actor : opponent;
        if (target == opponent &&
            state.hasStatus(opponent, StatusEffects.shield)) {
          continue;
        }
        if (targeted.status.effect == StatusEffects.burn) {
          final existing = nextState
              .statusesOf(target)
              .where((s) => s.effect == StatusEffects.burn);
          if (existing.any(
            (s) =>
                s.damagePerTick > targeted.status.damagePerTick ||
                (s.damagePerTick == targeted.status.damagePerTick &&
                    (s.turnsRemaining ?? 999) >=
                        (targeted.status.turnsRemaining ?? 999)),
          )) {
            continue;
          }
          nextState = nextState.withStatusRemoved(target, StatusEffects.burn);
        }
        nextState = nextState.withStatusApplied(target, targeted.status);
      }
    }

    return AbilityResult(
      state: nextState,
      effect: effect,
      feedback: feedback,
      triggeredCombination: turnResult.triggeredCombination,
    );
  }
}
