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
      status: { effectId: "burn", turnsRemaining: 2, damagePerTick: 3 },
      target: "opponent",
    },
  ]);
});

test("guard adds a shield status targeting the actor", () => {
  const effect = guard.apply(emptyAbilityEffect);
  assert.deepEqual(effect.statusesToApply, [
    {
      status: { effectId: "shield", turnsRemaining: 2, damagePerTick: 0 },
      target: "actor",
    },
  ]);
});

test("wildfire extends combustion without stacking", () => {
  const effect = wildfire.apply(combustion.apply(emptyAbilityEffect));
  assert.equal(effect.statusesToApply[0]!.status.turnsRemaining, 3);
});

test("precision provides deterministic combo parameters", () => {
  assert.equal(fragmentation.apply(emptyAbilityEffect).hitCount, 2);
  assert.equal(unstableCore.apply(emptyAbilityEffect).critChanceBonus, .25);
});

test("mutationsById indexes every built-in mutation by id", () => {
  assert.equal(mutationsById["combustion"], combustion);
  assert.equal(mutationsById["wildfire"], wildfire);
  assert.equal(mutationsById["fragmentation"], fragmentation);
  assert.equal(mutationsById["unstable_core"], unstableCore);
  assert.equal(mutationsById["guard"], guard);
});
