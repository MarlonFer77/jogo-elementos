import { tick as tickStatus, isExpired } from "./active-status.js";
import {
  withDamage as poolWithDamage,
  withMaxIncreased as poolWithMaxIncreased,
  isDefeated,
} from "./hp-pool.js";
import { TurnValidationError } from "./errors.js";
import type { ActiveStatus, BattleState, FieldEffect, HpPool } from "./types.js";

/** Builds a validated BattleState — mirrors the invariants of
 * BattleState's constructor in battle_engine. `hp` defaults each player to
 * 100/100 (mirrors BattleState's plain constructor default in Dart — there
 * is no Skill Tree here to raise it); `combatantStatuses` defaults to no
 * active statuses for either player. */
export function createBattleState(input: {
  playerAId: string;
  playerBId: string;
  currentTurnId: string;
  activeFieldEffects?: readonly FieldEffect[];
  hp?: Readonly<Record<string, HpPool>>;
  combatantStatuses?: Readonly<Record<string, readonly ActiveStatus[]>>;
  winner?: string | null;
}): BattleState {
  if (input.playerAId === input.playerBId) {
    throw new TurnValidationError(
      "playerAId and playerBId must be distinct",
    );
  }
  if (
    input.currentTurnId !== input.playerAId &&
    input.currentTurnId !== input.playerBId
  ) {
    throw new TurnValidationError(
      "currentTurnId must be playerAId or playerBId",
    );
  }

  return {
    playerAId: input.playerAId,
    playerBId: input.playerBId,
    currentTurnId: input.currentTurnId,
    activeFieldEffects: input.activeFieldEffects ?? [],
    hp: {
      [input.playerAId]: input.hp?.[input.playerAId] ?? { max: 100, current: 100 },
      [input.playerBId]: input.hp?.[input.playerBId] ?? { max: 100, current: 100 },
    },
    combatantStatuses: {
      [input.playerAId]: input.combatantStatuses?.[input.playerAId] ?? [],
      [input.playerBId]: input.combatantStatuses?.[input.playerBId] ?? [],
    },
    winner: input.winner ?? null,
  };
}

/** Mirrors BattleState.opponentOf. */
export function opponentOf(state: BattleState, combatantId: string): string {
  if (combatantId === state.playerAId) return state.playerBId;
  if (combatantId === state.playerBId) return state.playerAId;
  throw new TurnValidationError(
    `"${combatantId}" is not part of this battle`,
  );
}

/** HP pool of a combatant. */
export function hpOf(state: BattleState, combatantId: string): HpPool {
  const pool = state.hp[combatantId];
  if (!pool) {
    throw new TurnValidationError(
      `"${combatantId}" is not part of this battle`,
    );
  }
  return pool;
}

/** Mirrors BattleState.withDamage: applies `amount` of damage to `targetId`
 * and, if that brings them to 0 HP and nobody has won yet, sets their
 * opponent as the winner. Never un-sets an existing winner. */
export function withDamage(
  state: BattleState,
  targetId: string,
  amount: number,
): BattleState {
  const updatedPool = poolWithDamage(hpOf(state, targetId), amount);
  const newWinner =
    state.winner === null && isDefeated(updatedPool)
      ? opponentOf(state, targetId)
      : state.winner;

  return {
    ...state,
    hp: { ...state.hp, [targetId]: updatedPool },
    winner: newWinner,
  };
}

/** Returns a new state with `targetId`'s max (and current) HP increased by
 * `amount` — used when a mid-battle bonus (e.g. a Skill Tree node) raises
 * the ceiling. */
export function withMaxHpIncreased(
  state: BattleState,
  targetId: string,
  amount: number,
): BattleState {
  return {
    ...state,
    hp: { ...state.hp, [targetId]: poolWithMaxIncreased(hpOf(state, targetId), amount) },
  };
}

/** Active statuses currently applied to a combatant. */
export function statusesOf(
  state: BattleState,
  combatantId: string,
): readonly ActiveStatus[] {
  return state.combatantStatuses[combatantId] ?? [];
}

/** Whether a combatant currently has a status with this `effectId`. */
export function hasStatus(
  state: BattleState,
  combatantId: string,
  effectId: string,
): boolean {
  return statusesOf(state, combatantId).some((s) => s.effectId === effectId);
}

/** Returns a new state with `status` applied to `targetId`. */
export function withStatusApplied(
  state: BattleState,
  targetId: string,
  status: ActiveStatus,
): BattleState {
  return {
    ...state,
    combatantStatuses: {
      ...state.combatantStatuses,
      [targetId]: [...statusesOf(state, targetId), status],
    },
  };
}

/** Returns a new state with every active instance of `effectId` removed
 * from `targetId`. */
export function withStatusRemoved(
  state: BattleState,
  targetId: string,
  effectId: string,
): BattleState {
  return {
    ...state,
    combatantStatuses: {
      ...state.combatantStatuses,
      [targetId]: statusesOf(state, targetId).filter((s) => s.effectId !== effectId),
    },
  };
}

/** Ticks every active status for both combatants by one turn, removing
 * any that expire. */
export function withStatusesTicked(state: BattleState): BattleState {
  const updated: Record<string, readonly ActiveStatus[]> = {};
  for (const combatantId of [state.playerAId, state.playerBId]) {
    updated[combatantId] = statusesOf(state, combatantId)
      .map(tickStatus)
      .filter((s) => !isExpired(s));
  }
  return { ...state, combatantStatuses: updated };
}
