import { canAfford } from "./ap-pool.js";
import {
  hasStatus,
  opponentOf,
  statusesOf,
  withApRegenerated,
  withApSpent,
  withDamage,
  withStatusesTicked,
  withStatusRemoved,
  apOf,
  withStatusApplied,
} from "./battle-state.js";
import type { CombinationBook } from "./combination-book.js";
import type { CombinationModifier } from "./combination-modifiers.js";
import { TurnValidationError } from "./errors.js";
import { FREEZE_STATUS_ID, SHIELD_STATUS_ID } from "./status-effects.js";
import type { BattleState, TurnAction, TurnResult } from "./types.js";

const BASIC_DAMAGE = 5;
const COMBO_AP_COST: Record<number, number> = { 2: 3, 3: 5 };

/**
 * Server-authoritative mirror of TurnEngine.playTurn in battle_engine.
 * Rejects an action if the battle is already over or outside the actor's
 * turn, regenerates 1 AP for the actor (clamped at their max), rejects
 * the whole action (no AP spent, no damage, turn doesn't pass) if 2-3
 * elements were played and the actor can't afford it, resolves a
 * combination from 2-3 played elements, runs it through
 * `combinationModifiers` (the actor's granted CombinationModifiers — see
 * skill-tree.ts), adds the (possibly modified) result to the field,
 * damages the opponent unless Escudo blocks it (consuming it instead), a
 * single played element always deals a flat basic damage instead (same
 * Escudo rule), passes the turn, ticks every active status for both
 * combatants (applying `damagePerTick`, including the tick that expires
 * it), and sets the winner once a combatant reaches 0 HP. Does not itself
 * know about Mutations/AbilityEffect (a mutation's own status/field
 * effect) — that's ability-engine.ts, one layer up, same split as
 * TurnEngine/AbilityEngine in battle_engine (see DECISION-025).
 */
export function playTurn(
  state: BattleState,
  action: TurnAction,
  combinationBook: CombinationBook,
  combinationModifiers: readonly CombinationModifier[] = [],
): TurnResult {
  if (state.winner !== null) {
    throw new TurnValidationError("the battle is already over");
  }
  const isPassiveAction = action.kind === 'defend' || action.kind === 'thaw' || action.kind === 'fizzle';
  if ((isPassiveAction && action.elementIds.length !== 0) ||
      (!isPassiveAction && (action.elementIds.length === 0 || action.elementIds.length > 3 || new Set(action.elementIds).size !== action.elementIds.length))) {
    throw new TurnValidationError("must play at least one element");
  }
  if (action.actorId !== state.currentTurnId) {
    throw new TurnValidationError(`it is not "${action.actorId}"'s turn`);
  }

  const actorIsFrozen = hasStatus(state, action.actorId, FREEZE_STATUS_ID);
  if (actorIsFrozen && action.kind !== 'thaw') {
    throw new TurnValidationError('the actor is frozen and must thaw');
  }
  if (!actorIsFrozen && action.kind === 'thaw') {
    throw new TurnValidationError('the actor is not frozen');
  }

  if (action.elementIds.length > 1 && hasStatus(state, action.actorId, 'silence')) {
    throw new TurnValidationError('Silêncio: use um elemento básico ou Defender.');
  }
  let nextState = action.kind === 'thaw'
    ? withStatusRemoved(state, action.actorId, FREEZE_STATUS_ID)
    : action.kind === 'fizzle' || hasStatus(state, action.actorId, 'slow') ? state : withApRegenerated(state, action.actorId);

  if (action.kind === 'fizzle') nextState = withApSpent(nextState, action.actorId, Math.min(1, apOf(nextState, action.actorId).current));

  const elementCount = action.elementIds.length;
  if (elementCount >= 2) {
    const cost = COMBO_AP_COST[elementCount]! + (hasStatus(state, action.actorId, 'shock') ? 1 : 0);
    if (!canAfford(apOf(nextState, action.actorId), cost)) {
      throw new TurnValidationError(
        `not enough AP for a ${elementCount}-element combination`,
      );
    }
    nextState = withApSpent(nextState, action.actorId, cost);
  }

  let combination =
    elementCount >= 2
      ? combinationBook.resolve(action.elementIds)
      : null;
  if (combination) {
    for (const modifier of combinationModifiers) {
      combination = modifier.apply(combination);
    }
  }

  const opponentId = opponentOf(nextState, action.actorId);
  const shieldBlocked = hasStatus(nextState, opponentId, SHIELD_STATUS_ID);
  nextState = {
    ...nextState,
    currentTurnId: opponentId,
    activeFieldEffects: combination
      ? [...nextState.activeFieldEffects, combination]
      : nextState.activeFieldEffects,
  };

  if (action.kind === 'thaw') {
    // Breaking free consumes the action without AP regeneration or damage.
  } else if (combination && combination.damage > 0) {
    nextState = applyDamage(nextState, opponentId, modifiedDamage(state, action, combination.damage));
  } else if (elementCount === 1) {
    nextState = applyDamage(nextState, opponentId, modifiedDamage(state, action, BASIC_DAMAGE));
  }
  if (!shieldBlocked && (elementCount === 1 || (combination?.damage ?? 0) > 0) && action.elementIds.includes('lightning')) {
    nextState = withStatusRemoved(nextState, opponentId, 'wet');
  }

  nextState = tickStatusDamage(nextState, action.actorId);
  if (nextState.winner === null) {
    if (action.kind === 'defend') {
      nextState = withStatusApplied(withStatusRemoved(nextState, action.actorId, 'guard'), action.actorId,
        {effectId: 'guard', turnsRemaining: 1, damagePerTick: 0});
    }
    for (const targeted of combination?.statusesToApply ?? []) {
      const target = targeted.target === 'actor' ? action.actorId : opponentId;
      if (target === opponentId && shieldBlocked) continue;
      if (hasStatus(nextState, target, targeted.status.effectId)) continue;
      nextState = withStatusApplied(nextState, target, targeted.status);
    }
  }

  return {
    state: nextState,
    triggeredCombinationId: combination?.id ?? null,
  };
}

function modifiedDamage(state: BattleState, action: TurnAction, damage: number): number {
  let percent = 100;
  if (hasStatus(state, action.actorId, 'buff')) percent += 25;
  if (hasStatus(state, action.actorId, 'debuff')) percent -= 25;
  if (action.elementIds.includes('lightning') && hasStatus(state, opponentOf(state, action.actorId), 'wet')) percent += 25;
  return Math.ceil(damage * percent / 100);
}

function applyDamage(
  state: BattleState,
  targetId: string,
  damage: number,
): BattleState {
  if (hasStatus(state, targetId, SHIELD_STATUS_ID)) {
    return withStatusRemoved(state, targetId, SHIELD_STATUS_ID);
  }
  if (hasStatus(state, targetId, 'guard')) {
    return withDamage(withStatusRemoved(state, targetId, 'guard'), targetId, Math.ceil(damage / 2));
  }
  return withDamage(state, targetId, damage);
}

/** Ticks damage-over-time statuses for both combatants. `actorId` is
 * processed last so that, if both combatants would be defeated by this
 * same tick, `withDamage`'s "first defeat sets the winner" rule makes the
 * actor the winner (mirrors TurnEngine's tie-break in battle_engine). */
function tickStatusDamage(state: BattleState, actorId: string): BattleState {
  let result = state;
  const opponentId = opponentOf(state, actorId);
  for (const combatantId of [opponentId, actorId]) {
    for (const status of statusesOf(state, combatantId)) {
      if (status.damagePerTick > 0) {
        result = withDamage(result, combatantId, status.damagePerTick);
      }
    }
  }
  return withStatusesTicked(result);
}
