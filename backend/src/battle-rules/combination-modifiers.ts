import type { FieldEffect } from "./types.js";

/** Mirrors CombinationModifier in battle_engine (Dart): an id plus a pure
 * transform over a triggered combination's FieldEffect. No name/
 * description — same reasoning as Mutation. */
export interface CombinationModifier {
  readonly id: string;
  apply(effect: FieldEffect): FieldEffect;
}

/** Mirrors CombinationModifiers.propagation. */
export const propagation: CombinationModifier = {
  id: "propagation",
  apply: (effect) => ({ ...effect, area: effect.area + 2 }),
};

/** Mirrors CombinationModifiers.volatility. */
export const volatility: CombinationModifier = {
  id: "volatility",
  apply: (effect) => {
    if (effect.duration === null) return effect;
    return { ...effect, duration: Math.max(0, effect.duration - 1) };
  },
};

export const combinationModifiersById: Readonly<Record<string, CombinationModifier>> = {
  [propagation.id]: propagation,
  [volatility.id]: volatility,
};
