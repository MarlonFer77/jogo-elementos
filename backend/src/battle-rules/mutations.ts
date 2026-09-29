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
        status: { effectId: "burn", turnsRemaining: 2, damagePerTick: 3 },
        target: "opponent",
      },
    ],
  }),
};

/** Two direct hits, with the 80% damage tradeoff resolved by TurnEngine. */
export const fragmentation: Mutation = {
  id: "fragmentation",
  apply: (effect) => ({...effect, hitCount: effect.hitCount + 1}),
};

/** Mirrors Mutations.wildfire. */
export const wildfire: Mutation = {
  id: "wildfire",
  apply: (effect) => ({
    ...effect,
    statusesToApply: [
      ...(!effect.statusesToApply.some(t => t.status.effectId === 'burn')
        ? [{target: 'opponent' as const, status: {effectId: 'burn', turnsRemaining: 3, damagePerTick: 3}}] : []),
      ...effect.statusesToApply.map(targeted => targeted.status.effectId === 'burn'
        ? {...targeted, status: {...targeted.status, turnsRemaining: 3}} : targeted),
    ],
  }),
};

/** Legacy property name; deterministic +25% damage at full AP, not RNG. */
export const unstableCore: Mutation = {
  id: "unstable_core",
  apply: (effect) => ({...effect, critChanceBonus: effect.critChanceBonus + .25}),
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
        status: { effectId: SHIELD_STATUS_ID, turnsRemaining: 2, damagePerTick: 0 },
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
