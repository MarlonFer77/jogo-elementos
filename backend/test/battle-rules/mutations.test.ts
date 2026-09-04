import { test } from "node:test";
import assert from "node:assert/strict";

import { emptyAbilityEffect } from "../../src/battle-rules/ability-effect.js";
import {
  combustion,
  fragmentation,
  guard,
  mutationsById,
  unstableCore,
  wildfire,
} from "../../src/battle-rules/mutations.js";

test("combustion adds a burn status targeting the opponent", () => {
  const effect = combustion.apply(emptyAbilityEffect);
  assert.deepEqual(effect.statusesToApply, [
    {
      status: { effectId: "burn", turnsRemaining: 2, damagePerTick: 8 },
      target: "opponent",
    },
  ]);
});

test("guard adds a shield status targeting the actor", () => {
  const effect = guard.apply(emptyAbilityEffect);
  assert.deepEqual(effect.statusesToApply, [
    {
      status: { effectId: "shield", turnsRemaining: null, damagePerTick: 0 },
      target: "actor",
    },
  ]);
});

test("wildfire sets a fire_zone field effect", () => {
  const effect = wildfire.apply(emptyAbilityEffect);
  assert.equal(effect.fieldEffect?.id, "fire_zone");
});

test("fragmentation and unstableCore are no-ops (hitCount/critChanceBonus not modeled server-side)", () => {
  assert.deepEqual(fragmentation.apply(emptyAbilityEffect), emptyAbilityEffect);
  assert.deepEqual(unstableCore.apply(emptyAbilityEffect), emptyAbilityEffect);
});

test("mutationsById indexes every built-in mutation by id", () => {
  assert.equal(mutationsById["combustion"], combustion);
  assert.equal(mutationsById["wildfire"], wildfire);
  assert.equal(mutationsById["fragmentation"], fragmentation);
  assert.equal(mutationsById["unstable_core"], unstableCore);
  assert.equal(mutationsById["guard"], guard);
});
