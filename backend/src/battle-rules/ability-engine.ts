import { emptyAbilityEffect } from "./ability-effect.js";
import { opponentOf, withStatusApplied } from "./battle-state.js";
import type { CombinationBook } from "./combination-book.js";
import type { CombinationModifier } from "./combination-modifiers.js";
import type { Mutation } from "./mutations.js";
import { playTurn } from "./turn-engine.js";
import type { BattleState, TurnAction, TurnResult } from "./types.js";

/**
 * Mirrors AbilityEngine.useAbility in battle_engine: plays `action`'s
 * elements as a normal turn (via playTurn — combinations, combo damage,
 * status ticks and the win condition already resolved there), then applies
 * whatever the actor's currently granted `mutations` add on top: a field
 * effect, and each status on whichever side it targets (most, like
 * Combustão, land on the opponent; a defensive one like Guarda targets the
 * actor instead — see StatusTarget in ability-effect.ts).
 * `combinationModifiers` passes straight through to playTurn.
 */
export function useAbility(
  state: BattleState,
  action: TurnAction,
  combinationBook: CombinationBook,
  mutations: readonly Mutation[],
  combinationModifiers: readonly CombinationModifier[] = [],
): TurnResult {
  const turnResult = playTurn(state, action, combinationBook, combinationModifiers);

  let effect = emptyAbilityEffect;
  for (const mutation of mutations) {
    effect = mutation.apply(effect);
  }

  let nextState = turnResult.state;
  if (effect.fieldEffect) {
    nextState = {
      ...nextState,
      activeFieldEffects: [...nextState.activeFieldEffects, effect.fieldEffect],
    };
  }
  if (effect.statusesToApply.length > 0) {
    const opponentId = opponentOf(state, action.actorId);
    for (const targeted of effect.statusesToApply) {
      const targetId = targeted.target === "actor" ? action.actorId : opponentId;
      nextState = withStatusApplied(nextState, targetId, targeted.status);
    }
  }

  return { state: nextState, triggeredCombinationId: turnResult.triggeredCombinationId };
}
