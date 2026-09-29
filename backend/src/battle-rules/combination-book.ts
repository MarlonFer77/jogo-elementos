import type { ElementCombination, FieldEffect } from "./types.js";
import type { TargetedStatus } from './ability-effect.js';

const status = (effectId: string, turnsRemaining = 1, damagePerTick = 0, self = false): TargetedStatus => ({
  target: self ? 'actor' : 'opponent', status: {effectId, turnsRemaining, damagePerTick},
});
const combo = (id: string, elementIds: string[], damage: number, statusesToApply: TargetedStatus[], support: Pick<FieldEffect, 'healing' | 'cleanses' | 'apDrain'> = {}): ElementCombination => ({
  elementIds: new Set(elementIds), result: {id, area: 1, duration: null, damage, statusesToApply, ...support},
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
  combo('eruption', ['fire', 'earth'], 18, []),
  combo('inferno', ['fire', 'shadow'], 10, [], {"healing":0,"cleanses":false,"apDrain":1}),
  combo('fulgor', ['fire', 'lightning'], 10, [status('shock', 1, 0, false)]),
  combo('vital_ember', ['fire', 'nature'], 8, [], {"healing":6,"cleanses":false,"apDrain":0}),
  combo('purifying_water', ['water', 'light'], 0, [], {"healing":14,"cleanses":true,"apDrain":0}),
  combo('swamp', ['water', 'nature'], 8, [status('slow', 1, 0, false), status('wet', 2, 0, false)]),
  combo('acid', ['water', 'poison'], 10, [status('debuff', 1, 0, false)]),
  combo('abyss', ['water', 'shadow'], 8, [status('wet', 2, 0, false)], {"healing":0,"cleanses":false,"apDrain":1}),
  combo('rock_gale', ['wind', 'earth'], 10, [status('debuff', 1, 0, false)]),
  combo('aurora', ['wind', 'light'], 8, [status('buff', 2, 0, true), status('guard', 1, 0, true)]),
  combo('pestilence', ['wind', 'poison'], 10, [status('poison', 2, 3, false)]),
  combo('shadow_frost', ['ice', 'shadow'], 6, [status('freeze', 1, 0, false), status('debuff', 3, 0, false)]),
  combo('living_crystal', ['ice', 'nature'], 0, [status('guard', 1, 0, true)], {"healing":10,"cleanses":false,"apDrain":0}),
  combo('sacred_ice', ['ice', 'light'], 6, [status('freeze', 1, 0, false)], {"healing":0,"cleanses":true,"apDrain":0}),
  combo('toxic_frost', ['ice', 'poison'], 6, [status('slow', 1, 0, false), status('poison', 3, 1, false)]),
  combo('deep_roots', ['nature', 'earth'], 8, [status('slow', 1, 0, false), status('guard', 1, 0, true)]),
  combo('shadow_forest', ['nature', 'shadow'], 8, [status('debuff', 1, 0, false)], {"healing":4,"cleanses":false,"apDrain":0}),
  combo('electric_sap', ['nature', 'lightning'], 8, [status('shock', 1, 0, false), status('buff', 2, 0, true)]),
  combo('magnetism', ['lightning', 'earth'], 8, [status('shock', 1, 0, false), status('guard', 1, 0, true)]),
  combo('holy_lightning', ['lightning', 'light'], 10, [], {"healing":0,"cleanses":true,"apDrain":0}),
  combo('dark_thunder', ['lightning', 'shadow'], 8, [status('shock', 1, 0, false)], {"healing":0,"cleanses":false,"apDrain":1}),
  combo('conductive_toxin', ['lightning', 'poison'], 8, [status('poison', 3, 1, false), status('wet', 2, 0, false)]),
  combo('shadow_stone', ['earth', 'shadow'], 6, [status('guard', 1, 0, true)], {"healing":0,"cleanses":false,"apDrain":1}),
  combo('toxic_rock', ['earth', 'poison'], 6, [status('poison', 3, 2, false), status('guard', 1, 0, true)]),
  combo('toxic_light', ['light', 'poison'], 6, [status('poison', 2, 2, false), status('buff', 2, 0, true)]),
  combo('cataclysm', ['fire', 'earth', 'lightning'], 28, [status('shock', 1, 0, false)]),
  combo('primordial_volcano', ['fire', 'earth', 'nature'], 22, [], {"healing":10,"cleanses":false,"apDrain":0}),
  combo('deluge', ['water', 'wind', 'ice'], 18, [status('freeze', 1, 0, false), status('wet', 3, 0, false)]),
  combo('solstice', ['fire', 'light', 'nature'], 18, [status('buff', 2, 0, true)], {"healing":12,"cleanses":false,"apDrain":0}),
  combo('total_eclipse', ['shadow', 'light', 'lightning'], 20, [status('silence', 1, 0, false), status('debuff', 2, 0, false)]),
  combo('green_plague', ['nature', 'poison', 'water'], 18, [status('slow', 1, 0, false), status('poison', 3, 2, false)]),
  combo('eternal_winter', ['ice', 'wind', 'shadow'], 14, [status('freeze', 1, 0, false), status('slow', 3, 0, false)]),
  combo('colossus', ['earth', 'nature', 'shadow'], 14, [status('shield', 2, 0, true), status('buff', 2, 0, true)]),
  combo('black_storm', ['lightning', 'wind', 'shadow'], 22, [status('shock', 1, 0, false)], {"healing":0,"cleanses":false,"apDrain":1}),
  combo('crystal_heart', ['earth', 'ice', 'light'], 0, [status('shield', 2, 0, true)], {"healing":12,"cleanses":true,"apDrain":0}),
  combo('burning_plague', ['fire', 'poison', 'shadow'], 16, [status('burn', 2, 3, false), status('poison', 3, 2, false)]),
  combo('primordial_sea', ['water', 'nature', 'light'], 0, [], {"healing":26,"cleanses":true,"apDrain":0}),
  combo('astral_vacuum', ['shadow', 'wind', 'light'], 18, [status('silence', 1, 0, false)], {"healing":0,"cleanses":false,"apDrain":2}),
  combo('celestial_storm', ['lightning', 'light', 'wind'], 22, [status('buff', 2, 0, true)], {"healing":0,"cleanses":true,"apDrain":0}),
  combo('ancient_forest', ['nature', 'earth', 'water'], 14, [status('slow', 1, 0, false), status('guard', 1, 0, true)], {"healing":12,"cleanses":false,"apDrain":0}),
  combo('glacial_aurora', ['ice', 'light', 'wind'], 16, [status('freeze', 1, 0, false), status('guard', 1, 0, true)]),
  combo('volcanic_dragon', ['fire', 'earth', 'shadow'], 26, [status('burn', 2, 3, false)]),
  combo('nova', ['fire', 'light', 'lightning'], 30, [], {"healing":0,"cleanses":true,"apDrain":0}),
  combo('silent_gale', ['wind','shadow'],12,[status('silence')]),
  combo('quagmire', ['earth','water'],12,[status('slow')]),
  combo('solar_flame', ['fire','light'],12,[status('buff',2,0,true)]),
  combo('eclipse', ['shadow','light'],12,[status('debuff')]),
  combo('rain_dance', ['wind','water'],14,[status('wet',2)]),
  combo('toxic_bloom', ['nature','poison'],12,[status('poison',3,2)]),
  combo('static_gale', ['lightning','wind'],12,[status('shock')]),
  combo('crystal_wall', ['earth','light'],6,[status('shield',2,0,true)]),
  combo('living_ward', ['nature','light'],12,[status('guard',1,0,true)]),
  combo('caustic_flame', ['fire','poison'],10,[status('burn',2,3),status('poison',3,1)]),
  combo('winter_gale', ['ice','wind'],10,[status('slow'),status('wet',2)]),
  combo('toxic_hex', ['shadow','poison'],10,[status('debuff'),status('poison',3,1)]),
  combo('solar_tempest', ['fire','wind','light'],26,[status('buff',2,0,true)]),
  combo('sacred_grove', ['earth','nature','light'],18,[status('shield',2,0,true)]),
  combo('thunderstorm', ['water','lightning','wind'],28,[status('shock')]),
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
