import { test } from "node:test";
import assert from "node:assert/strict";

import {
  combinationModifiersById,
  propagation,
  volatility,
} from "../../src/battle-rules/combination-modifiers.js";

test("propagation increases area by 2", () => {
  const effect = propagation.apply({ id: "x", area: 1, duration: null, damage: 20 });
  assert.equal(effect.area, 3);
});

test("volatility reduces duration by 1, clamped at 0", () => {
  const effect = volatility.apply({ id: "x", area: 1, duration: 1, damage: 0 });
  assert.equal(effect.duration, 0);
  const effectAtZero = volatility.apply({ id: "x", area: 1, duration: 0, damage: 0 });
  assert.equal(effectAtZero.duration, 0);
});

test("volatility leaves a permanent (null duration) effect unchanged", () => {
  const effect = volatility.apply({ id: "x", area: 1, duration: null, damage: 0 });
  assert.equal(effect.duration, null);
});

test("combinationModifiersById indexes every built-in modifier by id", () => {
  assert.equal(combinationModifiersById["propagation"], propagation);
  assert.equal(combinationModifiersById["volatility"], volatility);
});
