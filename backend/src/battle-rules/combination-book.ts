import type { ElementCombination, FieldEffect } from "./types.js";

/** Resolves a set of element ids to the matching combination's result, or
 * null. Mirrors CombinationBook.resolve in battle_engine — order-
 * independent, exact set match (a 2-element subset of a 3-element combo
 * does not match). */
export class CombinationBook {
  constructor(private readonly combinations: readonly ElementCombination[]) {}

  resolve(elementIds: readonly string[]): FieldEffect | null {
    const query = new Set(elementIds);
    for (const combination of this.combinations) {
      if (
        combination.elementIds.size === query.size &&
        [...combination.elementIds].every((id) => query.has(id))
      ) {
        return combination.result;
      }
    }
    return null;
  }
}

/**
 * Mirrors packages/battle_engine/lib/src/default_combinations.dart.
 * Kept manually in sync — see DECISION-014 in DECISIONS.md.
 */
export const defaultCombinationBook = new CombinationBook([
  {
    elementIds: new Set(["fire", "wind"]),
    result: { id: "ignited_storm", area: 1, duration: null, damage: 20 },
  },
  {
    elementIds: new Set(["water", "lightning"]),
    result: { id: "electrified_field", area: 1, duration: null, damage: 20 },
  },
  {
    elementIds: new Set(["earth", "fire", "water"]),
    result: { id: "lava", area: 1, duration: null, damage: 35 },
  },
]);
