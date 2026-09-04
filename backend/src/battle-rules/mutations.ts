import type { AbilityEffect } from "./ability-effect.js";
import { SHIELD_STATUS_ID } from "./status-effects.js";

/** Mirrors Mutation in battle_engine (Dart): an id plus a pure transform
 * over an AbilityEffect. No name/description — the client already has
 * that from its own `battle_engine` (same reasoning as FieldEffect). */
export interface Mutation {
  readonly id: string;
  apply(effect: AbilityEffect): AbilityEffect;
}

/** Mirrors Mutations.combustion in mutations.dart. */
export const combustion: Mutation = {
  id: "combustion",
  apply: (effect) => ({
    ...effect,
    statusesToApply: [
      ...effect.statusesToApply,
      {
        status: { effectId: "burn", turnsRemaining: 2, damagePerTick: 8 },
        target: "opponent",
      },
    ],
  }),
};

/** Mirrors Mutations.fragmentation. No-op here: `hitCount` isn't modeled
 * server-side (see ability-effect.ts/DECISION-025) — nothing to change. */
export const fragmentation: Mutation = {
  id: "fragmentation",
  apply: (effect) => effect,
};

/** Mirrors Mutations.wildfire. */
export const wildfire: Mutation = {
  id: "wildfire",
  apply: (effect) => ({
    ...effect,
    fieldEffect: { id: "fire_zone", area: 1, duration: null, damage: 0 },
  }),
};

/** Mirrors Mutations.unstableCore. No-op here: `critChanceBonus` isn't
 * modeled server-side (see ability-effect.ts/DECISION-025). */
export const unstableCore: Mutation = {
  id: "unstable_core",
  apply: (effect) => effect,
};

/** Mirrors Mutations.guard. Unlike every other built-in mutation, this one
 * protects the actor, not the opponent (`target: "actor"`). */
export const guard: Mutation = {
  id: "guard",
  apply: (effect) => ({
    ...effect,
    statusesToApply: [
      ...effect.statusesToApply,
      {
        status: { effectId: SHIELD_STATUS_ID, turnsRemaining: null, damagePerTick: 0 },
        target: "actor",
      },
    ],
  }),
};

export const mutationsById: Readonly<Record<string, Mutation>> = {
  [combustion.id]: combustion,
  [fragmentation.id]: fragmentation,
  [wildfire.id]: wildfire,
  [unstableCore.id]: unstableCore,
  [guard.id]: guard,
};
