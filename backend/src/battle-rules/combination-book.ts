import type { ElementCombination, FieldEffect } from "./types.js";
import type { TargetedStatus } from './ability-effect.js';

const status = (effectId: string, turnsRemaining = 1, damagePerTick = 0, self = false): TargetedStatus => ({
  target: self ? 'actor' : 'opponent', status: {effectId, turnsRemaining, damagePerTick},
});
const combo = (id: string, elementIds: string[], damage: number, statusesToApply: TargetedStatus[]): ElementCombination => ({
  elementIds: new Set(elementIds), result: {id, area: 1, duration: null, damage, statusesToApply},
});

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
  combo('silent_gale', ['wind','shadow'],12,[status('silence')]),
  combo('quagmire', ['earth','water'],12,[status('slow')]),
  combo('solar_flame', ['fire','light'],12,[status('buff',2,0,true)]),
  combo('eclipse', ['shadow','light'],12,[status('debuff')]),
  combo('rain_dance', ['wind','water'],14,[status('wet',2)]),
  combo('toxic_bloom', ['nature','poison'],12,[status('poison',3,2)]),
  combo('static_gale', ['lightning','wind'],12,[status('shock')]),
  combo('crystal_wall', ['earth','light'],6,[status('shield',2,0,true)]),
  combo('living_ward', ['nature','light'],14,[status('guard',1,0,true)]),
  combo('caustic_flame', ['fire','poison'],10,[status('burn',2,3),status('poison',3,1)]),
  combo('winter_gale', ['ice','wind'],10,[status('slow'),status('wet',2)]),
  combo('toxic_hex', ['shadow','poison'],10,[status('debuff'),status('poison',3,1)]),
  combo('solar_tempest', ['fire','wind','light'],26,[status('buff',2,0,true)]),
  combo('sacred_grove', ['earth','nature','light'],18,[status('shield',2,0,true)]),
  combo('thunderstorm', ['water','lightning','wind'],24,[status('shock')]),
  combo('plague_garden', ['nature','poison','shadow'],24,[status('poison',3,3)]),
  {
    elementIds: new Set(["fire", "wind"]),
    result: { id: "ignited_storm", area: 1, duration: null, damage: 14,
      statusesToApply: [{target: 'opponent', status: {effectId: 'burn', turnsRemaining: 2, damagePerTick: 3}}] },
  },
  {
    elementIds: new Set(["water", "lightning"]),
    result: { id: "electrified_field", area: 1, duration: null, damage: 12,
      statusesToApply: [{target: 'actor', status: {effectId: 'guard', turnsRemaining: 1, damagePerTick: 0}}] },
  },
  {
    elementIds: new Set(["water", "ice"]),
    result: { id: "glacial_prison", area: 1, duration: null, damage: 10,
      statusesToApply: [{target: 'opponent', status: {effectId: 'freeze', turnsRemaining: null, damagePerTick: 0}}] },
  },
  {
    elementIds: new Set(["earth", "fire", "water"]),
    result: { id: "lava", area: 1, duration: null, damage: 35 },
  },
]);
