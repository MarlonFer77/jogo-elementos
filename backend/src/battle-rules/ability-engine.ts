import { emptyAbilityEffect } from "./ability-effect.js";
import { opponentOf, withStatusApplied, withStatusRemoved, statusesOf, hasStatus, apOf } from "./battle-state.js";
import type { CombinationBook } from "./combination-book.js";
import type { CombinationModifier } from "./combination-modifiers.js";
import type { Mutation } from "./mutations.js";
import { basicRecoveryStatus, playTurn } from "./turn-engine.js";
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
  sealDamagePercent?: number,
): TurnResult {
  const combo = action.elementIds.length > 1 ? combinationBook.resolve(action.elementIds) : null;
  let effect = emptyAbilityEffect;
  if (combo) for (const mutation of mutations) effect = mutation.apply(effect);
  const pool = apOf(state, action.actorId);
  const available = hasStatus(state, action.actorId, 'slow') || hasStatus(state, action.actorId, 'freeze')
    ? pool.current : Math.min(pool.max, pool.current + 1);
  const focused = !!combo && combo.damage > 0 && effect.critChanceBonus > 0 && available >= pool.max;
  const recovery = basicRecoveryStatus(state, action);
  const feedback = [
    ...(recovery ? [`recover_${recovery}`] : []),
    ...(sealDamagePercent === undefined ? [] : [`seal_${sealDamagePercent}`]),
    ...(focused ? ['focused'] : []),
    ...(combo && combo.damage > 0 && effect.hitCount > 1 ? ['fragmented'] : []),
  ];
  const turnResult = playTurn(state, action, combinationBook, combinationModifiers,
    {hitCount: effect.hitCount, focusedBonus: focused ? effect.critChanceBonus : 0}, sealDamagePercent);
  if (!turnResult.triggeredCombinationId || turnResult.state.winner) return {...turnResult, feedback};

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
      if (targetId === opponentId && hasStatus(state, opponentId, 'shield')) continue;
      if (targeted.status.effectId === 'burn') {
        if (statusesOf(nextState, targetId).some(s => s.effectId === 'burn' && (s.damagePerTick > targeted.status.damagePerTick || (s.damagePerTick === targeted.status.damagePerTick && (s.turnsRemaining ?? 999) >= (targeted.status.turnsRemaining ?? 999))))) continue;
        nextState = withStatusRemoved(nextState, targetId, 'burn');
      }
      nextState = withStatusApplied(nextState, targetId, targeted.status);
    }
  }

  return { state: nextState, triggeredCombinationId: turnResult.triggeredCombinationId, feedback };
}
