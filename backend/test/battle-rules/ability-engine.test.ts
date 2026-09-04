import { test } from "node:test";
import assert from "node:assert/strict";

import { createBattleState, hasStatus, hpOf } from "../../src/battle-rules/battle-state.js";
import { defaultCombinationBook } from "../../src/battle-rules/combination-book.js";
import { propagation } from "../../src/battle-rules/combination-modifiers.js";
import { combustion, guard, wildfire } from "../../src/battle-rules/mutations.js";
import { useAbility } from "../../src/battle-rules/ability-engine.js";

function startState() {
  return createBattleState({ playerAId: "a", playerBId: "b", currentTurnId: "a" });
}

test("a mutation's status applies to the opponent, not the actor", () => {
  const result = useAbility(
    startState(),
    { actorId: "a", elementIds: ["fire"] },
    defaultCombinationBook,
    [combustion],
    [],
  );

  assert.equal(hasStatus(result.state, "b", "burn"), true);
  assert.equal(hasStatus(result.state, "a", "burn"), false);
});

test("a self-targeted status (guard) applies to the actor, not the opponent", () => {
  const result = useAbility(
    startState(),
    { actorId: "a", elementIds: ["fire"] },
    defaultCombinationBook,
    [guard],
    [],
  );

  assert.equal(hasStatus(result.state, "a", "shield"), true);
  assert.equal(hasStatus(result.state, "b", "shield"), false);
});

test("guard's Escudo actually blocks the next combo damage against the actor", () => {
  const guarded = useAbility(
    startState(),
    { actorId: "a", elementIds: ["fire"] },
    defaultCombinationBook,
    [guard],
    [],
  ).state; // a guarded, turn passed to b

  const result = useAbility(
    guarded,
    { actorId: "b", elementIds: ["fire", "wind"] },
    defaultCombinationBook,
    [],
    [],
  );

  assert.equal(hpOf(result.state, "a").current, 100);
  assert.equal(hasStatus(result.state, "a", "shield"), false); // consumed
});

test("a mutation's field effect is added even without a triggered combination", () => {
  const result = useAbility(
    startState(),
    { actorId: "a", elementIds: ["fire"] },
    defaultCombinationBook,
    [wildfire],
    [],
  );

  assert.equal(result.triggeredCombinationId, null);
  assert.equal(result.state.activeFieldEffects.some((e) => e.id === "fire_zone"), true);
});

test("combinationModifiers change a triggered combination's field effect before it's added", () => {
  const result = useAbility(
    startState(),
    { actorId: "a", elementIds: ["fire", "wind"] },
    defaultCombinationBook,
    [],
    [propagation],
  );

  assert.equal(result.triggeredCombinationId, "ignited_storm");
  assert.equal(result.state.activeFieldEffects.length, 1);
  assert.equal(result.state.activeFieldEffects[0]?.area, 3);
});

test("no mutations/modifiers behaves exactly like a plain playTurn", () => {
  const result = useAbility(
    startState(),
    { actorId: "a", elementIds: ["fire", "wind"] },
    defaultCombinationBook,
    [],
    [],
  );

  assert.equal(result.triggeredCombinationId, "ignited_storm");
  assert.equal(result.state.currentTurnId, "b");
});
