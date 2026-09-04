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
 * BattleState. `hitCount`/`critChanceBonus` from the Dart source aren't
 * mirrored: nothing on either side consumes them yet (see the doc comment
 * on AbilityEffect in ability_effect.dart), so carrying them here would be
 * dead weight — see DECISION-025. */
export interface AbilityEffect {
  readonly statusesToApply: readonly TargetedStatus[];
  readonly fieldEffect: FieldEffect | null;
}

export const emptyAbilityEffect: AbilityEffect = {
  statusesToApply: [],
  fieldEffect: null,
};
