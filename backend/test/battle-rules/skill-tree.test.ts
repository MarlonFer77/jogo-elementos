import { test } from "node:test";
import assert from "node:assert/strict";

import {
  availableNodeIds,
  canUnlock,
  grantedCombinationModifiers,
  grantedMutations,
  nodeById,
} from "../../src/battle-rules/skill-tree.js";

test("a root node (no prerequisites) can be unlocked from scratch", () => {
  assert.equal(canUnlock([], "ember_mastery"), true);
});

test("a node with an unmet prerequisite cannot be unlocked yet", () => {
  assert.equal(canUnlock([], "wildfire_path"), false);
});

test("a node becomes unlockable once its prerequisite is unlocked", () => {
  assert.equal(canUnlock(["ember_mastery"], "wildfire_path"), true);
});

test("an already-unlocked node cannot be unlocked again", () => {
  assert.equal(canUnlock(["ember_mastery"], "ember_mastery"), false);
});

test("an unknown node id cannot be unlocked", () => {
  assert.equal(canUnlock([], "nope"), false);
});

test("availableNodeIds lists every root node when nothing is unlocked", () => {
  const ids = availableNodeIds([]);
  assert.ok(ids.includes("ember_mastery"));
  assert.ok(ids.includes("unstable_core_training"));
  assert.ok(ids.includes("elemental_insight"));
  assert.ok(ids.includes("vitality_training"));
  assert.ok(!ids.includes("wildfire_path")); // prerequisite not met
});

test("availableNodeIds excludes already-unlocked nodes and includes newly-reachable ones", () => {
  const ids = availableNodeIds(["ember_mastery"]);
  assert.ok(!ids.includes("ember_mastery"));
  assert.ok(ids.includes("wildfire_path"));
});

test("grantedMutations returns the mutations of unlocked mutation-granting nodes, deduplicated", () => {
  const mutations = grantedMutations(["ember_mastery", "ember_mastery"]);
  assert.equal(mutations.length, 1);
  assert.equal(mutations[0]?.id, "combustion");
});

test("grantedMutations skips nodes that grant something else", () => {
  const mutations = grantedMutations(["elemental_insight", "vitality_training"]);
  assert.deepEqual(mutations, []);
});

test("grantedCombinationModifiers returns the modifiers of unlocked modifier-granting nodes", () => {
  const modifiers = grantedCombinationModifiers(["elemental_insight"]);
  assert.equal(modifiers.length, 1);
  assert.equal(modifiers[0]?.id, "propagation");
});

test("nodeById finds a node's definition, including its grant", () => {
  const node = nodeById("vitality_training");
  assert.deepEqual(node?.grant, { kind: "maxHpBonus", id: "vitality" });
});

test("nodeById returns undefined for an unknown id", () => {
  assert.equal(nodeById("nope"), undefined);
});

test("guard_training is a root node granting guard", () => {
  assert.ok(availableNodeIds([]).includes("guard_training"));
  const mutations = grantedMutations(["guard_training"]);
  assert.equal(mutations.length, 1);
  assert.equal(mutations[0]?.id, "guard");
});
