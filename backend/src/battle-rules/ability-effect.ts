import type { ActiveStatus, FieldEffect } from "./types.js";

/** Mirrors StatusTarget in targeted_status.dart — who a mutation-applied
 * status lands on. Most mutations (e.g. Combustão) debuff the opponent —
 * the default in Dart; a defensive one (e.g. Guarda) needs to protect
 * whoever's using it instead. */
export type StatusTarget = "actor" | "opponent";

/** Mirrors TargetedStatus in battle_engine (Dart). */
export interface TargetedStatus {
  readonly status: ActiveStatus;
  readonly target: StatusTarget;
}

/** Mirrors AbilityEffect in battle_engine (Dart) — the accumulated effect
 * of resolving an ability's mutations, before it's applied to a
 * BattleState. Precision parameters are computed from server-owned skills,
 * never from the submitted action. Full AP gives deterministic focus, not RNG. */
export interface AbilityEffect {
  readonly hitCount: number;
  readonly critChanceBonus: number;
  readonly statusesToApply: readonly TargetedStatus[];
  readonly fieldEffect: FieldEffect | null;
}

export const emptyAbilityEffect: AbilityEffect = {
  hitCount: 1,
  critChanceBonus: 0,
  statusesToApply: [],
  fieldEffect: null,
};
