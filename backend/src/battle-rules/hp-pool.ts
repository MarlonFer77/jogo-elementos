import type { HpPool } from "./types.js";

/** Mirrors HpPool in battle_engine (Dart) — `current` never goes below 0 or
 * above `max`. No healing yet, so this only ever subtracts. */
export function isDefeated(pool: HpPool): boolean {
  return pool.current <= 0;
}

export function withDamage(pool: HpPool, amount: number): HpPool {
  if (amount < 0) {
    throw new Error("amount must not be negative");
  }
  return { max: pool.max, current: Math.max(0, pool.current - amount) };
}

/** Raises both `max` and `current` by `amount` — used when a mid-battle
 * bonus (e.g. a Skill Tree node) raises the ceiling; the combatant gets
 * tougher right now, not just later. */
export function withMaxIncreased(pool: HpPool, amount: number): HpPool {
  if (amount < 0) {
    throw new Error("amount must not be negative");
  }
  return { max: pool.max + amount, current: pool.current + amount };
}
