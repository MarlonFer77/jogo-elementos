import type { ApPool } from "./types.js";

/** Mirrors ApPool in battle_engine (Dart) — `current` never goes below 0
 * or above `max`. Used to gate combining 2-3 elements in one turn. */
export function canAfford(pool: ApPool, amount: number): boolean {
  return pool.current >= amount;
}

/** Increments `current` by 1, clamped at `max`. */
export function withRegenerated(pool: ApPool): ApPool {
  return { max: pool.max, current: Math.min(pool.max, pool.current + 1) };
}

/** Subtracts `amount` from `current`. Callers must check `canAfford`
 * first — throws if `amount` is negative or exceeds `current`. */
export function withSpent(pool: ApPool, amount: number): ApPool {
  if (amount < 0) {
    throw new Error("amount must not be negative");
  }
  if (amount > pool.current) {
    throw new Error("amount exceeds current AP");
  }
  return { max: pool.max, current: pool.current - amount };
}
