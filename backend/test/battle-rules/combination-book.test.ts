import { test } from "node:test";
import assert from "node:assert/strict";

import { defaultCombinationBook } from "../../src/battle-rules/combination-book.js";

test("resolves fire+wind to ignited_storm", () => {
  const result = defaultCombinationBook.resolve(["fire", "wind"]);
  assert.equal(result?.id, "ignited_storm");
});

test("combinations have distinct direct damage and effects", () => {
  assert.equal(defaultCombinationBook.resolve(["fire", "wind"])?.damage, 14);
  assert.equal(
    defaultCombinationBook.resolve(["water", "lightning"])?.damage,
    12,
  );
  assert.equal(
    defaultCombinationBook.resolve(["earth", "fire", "water"])?.damage,
    35,
  );
});

test("resolve is order-independent", () => {
  const a = defaultCombinationBook.resolve(["fire", "wind"]);
  const b = defaultCombinationBook.resolve(["wind", "fire"]);
  assert.equal(a?.id, b?.id);
});

test("resolves the 3-element combination earth+fire+water to lava", () => {
  const result = defaultCombinationBook.resolve(["earth", "fire", "water"]);
  assert.equal(result?.id, "lava");
});

test("returns null for an unknown combination", () => {
  const result = defaultCombinationBook.resolve(["ice", "shadow"]);
  assert.equal(result, null);
});

test("a 2-element subset of a known 3-element combo does not match", () => {
  const result = defaultCombinationBook.resolve(["earth", "fire"]);
  assert.equal(result, null);
});
