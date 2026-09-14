import { test } from "node:test";
import assert from "node:assert/strict";

import { canAfford, withRegenerated, withSpent } from "../../src/battle-rules/ap-pool.js";

test("canAfford is true when current is greater than or equal to amount", () => {
  assert.equal(canAfford({ max: 5, current: 3 }, 3), true);
  assert.equal(canAfford({ max: 5, current: 3 }, 2), true);
});

test("canAfford is false when current is less than amount", () => {
  assert.equal(canAfford({ max: 5, current: 2 }, 3), false);
});

test("withRegenerated increments current by 1", () => {
  const pool = withRegenerated({ max: 5, current: 2 });
  assert.deepEqual(pool, { max: 5, current: 3 });
});

test("withRegenerated clamps at max", () => {
  const pool = withRegenerated({ max: 5, current: 5 });
  assert.deepEqual(pool, { max: 5, current: 5 });
});

test("withSpent subtracts amount from current", () => {
  const pool = withSpent({ max: 5, current: 4 }, 3);
  assert.deepEqual(pool, { max: 5, current: 1 });
});

test("withSpent throws for a negative amount", () => {
  assert.throws(() => withSpent({ max: 5, current: 4 }, -1));
});

test("withSpent throws when amount exceeds current", () => {
  assert.throws(() => withSpent({ max: 5, current: 2 }, 3));
});
