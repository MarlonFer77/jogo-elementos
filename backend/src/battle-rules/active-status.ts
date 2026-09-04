import type { ActiveStatus } from "./types.js";

/** Mirrors ActiveStatus in battle_engine (Dart). `turnsRemaining: null`
 * means permanent until removed explicitly (e.g. Shield, consumed on hit,
 * not by turn count). */
export function isExpired(status: ActiveStatus): boolean {
  return status.turnsRemaining !== null && status.turnsRemaining <= 0;
}

/** Returns a copy with `turnsRemaining` decremented by 1, or the same
 * instance if it has no duration. */
export function tick(status: ActiveStatus): ActiveStatus {
  if (status.turnsRemaining === null) return status;
  return { ...status, turnsRemaining: status.turnsRemaining - 1 };
}
