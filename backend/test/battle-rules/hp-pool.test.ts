import { test } from "node:test";
import assert from "node:assert/strict";

import { isDefeated, withDamage, withMaxIncreased } from "../../src/battle-rules/hp-pool.js";

test("isDefeated is false while current is above 0", () => {
  assert.equal(isDefeated({ max: 100, current: 1 }), false);
});

test("isDefeated is true once current reaches 0", () => {
  assert.equal(isDefeated({ max: 100, current: 0 }), true);
});

test("withDamage subtracts from current", () => {
  const pool = withDamage({ max: 100, current: 100 }, 30);
  assert.deepEqual(pool, { max: 100, current: 70 });
});

test("withDamage clamps at 0 instead of going negative", () => {
  const pool = withDamage({ max: 100, current: 20 }, 35);
  assert.deepEqual(pool, { max: 100, current: 0 });
});

test("withDamage throws for a negative amount", () => {
  assert.throws(() => withDamage({ max: 100, current: 100 }, -1));
});

test("withMaxIncreased raises both max and current by the same amount", () => {
  const pool = withMaxIncreased({ max: 100, current: 60 }, 20);
  assert.deepEqual(pool, { max: 120, current: 80 });
});

test("withMaxIncreased throws for a negative amount", () => {
  assert.throws(() => withMaxIncreased({ max: 100, current: 100 }, -1));
});
