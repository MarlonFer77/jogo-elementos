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
  apply: (effect) => ({ ...effect, area: effect.area + 2,
    statusesToApply: effect.statusesToApply?.map(entry => entry.target !== 'opponent' || entry.status.damagePerTick === 0 ? entry :
      {...entry, status: {...entry.status, damagePerTick: entry.status.damagePerTick + 1}}),
  }),
};

/** Mirrors CombinationModifiers.volatility. */
export const volatility: CombinationModifier = {
  id: "volatility",
  apply: (effect) => {
    let converted = false;
    const statusesToApply = effect.statusesToApply?.map(entry => {
      const turns = entry.status.turnsRemaining;
      if (entry.target !== 'opponent' || entry.status.damagePerTick === 0 || turns === null || turns <= 1) return entry;
      converted = true;
      return {...entry, status: {...entry.status, turnsRemaining: turns - 1}};
    });
    return { ...effect, duration: effect.duration === null ? null : Math.max(0, effect.duration - 1),
      damage: effect.damage + (converted ? 4 : 0), statusesToApply };
  },
};

export const combinationModifiersById: Readonly<Record<string, CombinationModifier>> = {
  [propagation.id]: propagation,
  [volatility.id]: volatility,
};
