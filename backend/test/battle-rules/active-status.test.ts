import { test } from "node:test";
import assert from "node:assert/strict";

import { isExpired, tick } from "../../src/battle-rules/active-status.js";

test("isExpired is false while turnsRemaining is above 0", () => {
  assert.equal(
    isExpired({ effectId: "burn", turnsRemaining: 1, damagePerTick: 8 }),
    false,
  );
});

test("isExpired is false when turnsRemaining is null (permanent until removed)", () => {
  assert.equal(
    isExpired({ effectId: "shield", turnsRemaining: null, damagePerTick: 0 }),
    false,
  );
});

test("isExpired is true once turnsRemaining reaches 0", () => {
  assert.equal(
    isExpired({ effectId: "burn", turnsRemaining: 0, damagePerTick: 8 }),
    true,
  );
});

test("tick decrements turnsRemaining by 1", () => {
  const ticked = tick({ effectId: "burn", turnsRemaining: 2, damagePerTick: 8 });
  assert.deepEqual(ticked, { effectId: "burn", turnsRemaining: 1, damagePerTick: 8 });
});

test("tick leaves a permanent status (null turnsRemaining) unchanged", () => {
  const status = { effectId: "shield", turnsRemaining: null, damagePerTick: 0 };
  assert.deepEqual(tick(status), status);
});
