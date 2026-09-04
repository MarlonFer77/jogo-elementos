import { isNonEmptyString } from "../http/validation.js";
import { TurnValidationError } from "./errors.js";
import type { ActiveStatus, FieldEffect, HpPool, TurnAction } from "./types.js";

export function parseFieldEffect(value: unknown): FieldEffect {
  if (typeof value !== "object" || value === null) {
    throw new TurnValidationError("each field effect must be an object");
  }
  const { id, area, duration, damage } = value as Record<string, unknown>;

  if (!isNonEmptyString(id)) {
    throw new TurnValidationError("field effect id must be a non-empty string");
  }
  if (typeof area !== "number") {
    throw new TurnValidationError("field effect area must be a number");
  }
  if (duration !== null && duration !== undefined && typeof duration !== "number") {
    throw new TurnValidationError("field effect duration must be a number or null");
  }
  if (damage !== undefined && typeof damage !== "number") {
    throw new TurnValidationError("field effect damage must be a number");
  }

  return { id, area, duration: duration ?? null, damage: damage ?? 0 };
}

export function parseHpPool(value: unknown): HpPool {
  if (typeof value !== "object" || value === null) {
    throw new TurnValidationError("each HP pool must be an object");
  }
  const { max, current } = value as Record<string, unknown>;

  if (typeof max !== "number") {
    throw new TurnValidationError("HP pool max must be a number");
  }
  if (typeof current !== "number") {
    throw new TurnValidationError("HP pool current must be a number");
  }

  return { max, current };
}

/** Parses the optional `state.hp` map sent by a stateless caller (see
 * /battles/validate-turn) — keyed by combatant id, same shape createBattleState
 * accepts. Returns undefined (letting createBattleState apply its own
 * 100/100 default) when absent. */
export function parseHp(
  value: unknown,
): Record<string, HpPool> | undefined {
  if (value === undefined) return undefined;
  if (typeof value !== "object" || value === null) {
    throw new TurnValidationError("state.hp must be an object");
  }
  const entries = Object.entries(value as Record<string, unknown>);
  return Object.fromEntries(
    entries.map(([id, pool]) => [id, parseHpPool(pool)]),
  );
}

export function parseActiveStatus(value: unknown): ActiveStatus {
  if (typeof value !== "object" || value === null) {
    throw new TurnValidationError("each active status must be an object");
  }
  const { effectId, turnsRemaining, damagePerTick } = value as Record<string, unknown>;

  if (!isNonEmptyString(effectId)) {
    throw new TurnValidationError("active status effectId must be a non-empty string");
  }
  if (
    turnsRemaining !== null &&
    turnsRemaining !== undefined &&
    typeof turnsRemaining !== "number"
  ) {
    throw new TurnValidationError("active status turnsRemaining must be a number or null");
  }
  if (damagePerTick !== undefined && typeof damagePerTick !== "number") {
    throw new TurnValidationError("active status damagePerTick must be a number");
  }

  return {
    effectId,
    turnsRemaining: turnsRemaining ?? null,
    damagePerTick: damagePerTick ?? 0,
  };
}

/** Parses the optional `state.combatantStatuses` map sent by a stateless
 * caller (see /battles/validate-turn) — keyed by combatant id, same shape
 * createBattleState accepts. Returns undefined (letting createBattleState
 * default to no statuses) when absent. */
export function parseCombatantStatuses(
  value: unknown,
): Record<string, ActiveStatus[]> | undefined {
  if (value === undefined) return undefined;
  if (typeof value !== "object" || value === null) {
    throw new TurnValidationError("state.combatantStatuses must be an object");
  }
  const entries = Object.entries(value as Record<string, unknown>);
  return Object.fromEntries(
    entries.map(([id, statuses]) => {
      if (!Array.isArray(statuses)) {
        throw new TurnValidationError(
          `state.combatantStatuses["${id}"] must be a list`,
        );
      }
      return [id, statuses.map(parseActiveStatus)];
    }),
  );
}

export function parseTurnAction(value: unknown): TurnAction {
  if (typeof value !== "object" || value === null) {
    throw new TurnValidationError("action is required");
  }
  const input = value as Record<string, unknown>;

  if (!isNonEmptyString(input.actorId)) {
    throw new TurnValidationError("actorId is required");
  }
  if (!Array.isArray(input.elementIds) || !input.elementIds.every(isNonEmptyString)) {
    throw new TurnValidationError("elementIds must be a list of strings");
  }

  return { actorId: input.actorId, elementIds: input.elementIds as string[] };
}
