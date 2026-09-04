import { test } from "node:test";
import assert from "node:assert/strict";

import {
  createBattleState,
  hasStatus,
  hpOf,
  opponentOf,
  statusesOf,
  withDamage,
  withMaxHpIncreased,
  withStatusApplied,
  withStatusRemoved,
  withStatusesTicked,
} from "../../src/battle-rules/battle-state.js";
import { TurnValidationError } from "../../src/battle-rules/errors.js";

test("throws if playerAId and playerBId are the same", () => {
  assert.throws(
    () =>
      createBattleState({
        playerAId: "a",
        playerBId: "a",
        currentTurnId: "a",
      }),
    TurnValidationError,
  );
});

test("throws if currentTurnId is neither playerAId nor playerBId", () => {
  assert.throws(
    () =>
      createBattleState({
        playerAId: "a",
        playerBId: "b",
        currentTurnId: "c",
      }),
    TurnValidationError,
  );
});

test("defaults activeFieldEffects to an empty list", () => {
  const state = createBattleState({
    playerAId: "a",
    playerBId: "b",
    currentTurnId: "a",
  });
  assert.deepEqual(state.activeFieldEffects, []);
});

test("opponentOf returns the other participant", () => {
  const state = createBattleState({
    playerAId: "a",
    playerBId: "b",
    currentTurnId: "a",
  });
  assert.equal(opponentOf(state, "a"), "b");
  assert.equal(opponentOf(state, "b"), "a");
});

test("opponentOf throws for a combatant outside the battle", () => {
  const state = createBattleState({
    playerAId: "a",
    playerBId: "b",
    currentTurnId: "a",
  });
  assert.throws(() => opponentOf(state, "c"), TurnValidationError);
});

test("defaults both combatants to 100/100 HP and no winner", () => {
  const state = createBattleState({
    playerAId: "a",
    playerBId: "b",
    currentTurnId: "a",
  });
  assert.deepEqual(hpOf(state, "a"), { max: 100, current: 100 });
  assert.deepEqual(hpOf(state, "b"), { max: 100, current: 100 });
  assert.equal(state.winner, null);
});

test("withDamage subtracts HP from the target only", () => {
  const state = createBattleState({
    playerAId: "a",
    playerBId: "b",
    currentTurnId: "a",
  });
  const updated = withDamage(state, "b", 30);
  assert.deepEqual(hpOf(updated, "b"), { max: 100, current: 70 });
  assert.deepEqual(hpOf(updated, "a"), { max: 100, current: 100 });
});

test("withDamage sets the opponent as winner once the target is defeated", () => {
  const state = createBattleState({
    playerAId: "a",
    playerBId: "b",
    currentTurnId: "a",
  });
  const updated = withDamage(state, "b", 100);
  assert.equal(updated.winner, "a");
});

test("withDamage never un-sets an existing winner", () => {
  const state = createBattleState({
    playerAId: "a",
    playerBId: "b",
    currentTurnId: "a",
  });
  const defeated = withDamage(state, "b", 100);
  const again = withDamage(defeated, "a", 50);
  assert.equal(again.winner, "a");
});

test("withMaxHpIncreased raises the target's max and current HP, leaving the opponent untouched", () => {
  const state = createBattleState({ playerAId: "a", playerBId: "b", currentTurnId: "a" });
  const updated = withMaxHpIncreased(state, "a", 20);
  assert.deepEqual(hpOf(updated, "a"), { max: 120, current: 120 });
  assert.deepEqual(hpOf(updated, "b"), { max: 100, current: 100 });
});

test("defaults both combatants to no active statuses", () => {
  const state = createBattleState({
    playerAId: "a",
    playerBId: "b",
    currentTurnId: "a",
  });
  assert.deepEqual(statusesOf(state, "a"), []);
  assert.deepEqual(statusesOf(state, "b"), []);
});

test("withStatusApplied adds a status to the target only", () => {
  const state = createBattleState({
    playerAId: "a",
    playerBId: "b",
    currentTurnId: "a",
  });
  const updated = withStatusApplied(state, "b", {
    effectId: "shield",
    turnsRemaining: null,
    damagePerTick: 0,
  });
  assert.equal(statusesOf(updated, "b").length, 1);
  assert.equal(statusesOf(updated, "a").length, 0);
});

test("hasStatus finds an applied status by effectId", () => {
  const state = withStatusApplied(
    createBattleState({ playerAId: "a", playerBId: "b", currentTurnId: "a" }),
    "b",
    { effectId: "shield", turnsRemaining: null, damagePerTick: 0 },
  );
  assert.equal(hasStatus(state, "b", "shield"), true);
  assert.equal(hasStatus(state, "b", "burn"), false);
  assert.equal(hasStatus(state, "a", "shield"), false);
});

test("withStatusRemoved removes every instance of that effectId from the target", () => {
  let state = createBattleState({ playerAId: "a", playerBId: "b", currentTurnId: "a" });
  state = withStatusApplied(state, "b", { effectId: "shield", turnsRemaining: null, damagePerTick: 0 });
  state = withStatusApplied(state, "b", { effectId: "burn", turnsRemaining: 2, damagePerTick: 8 });

  const updated = withStatusRemoved(state, "b", "shield");

  assert.equal(hasStatus(updated, "b", "shield"), false);
  assert.equal(hasStatus(updated, "b", "burn"), true);
});

test("withStatusesTicked ticks every status for both combatants, dropping expired ones", () => {
  let state = createBattleState({ playerAId: "a", playerBId: "b", currentTurnId: "a" });
  state = withStatusApplied(state, "a", { effectId: "shield", turnsRemaining: null, damagePerTick: 0 });
  state = withStatusApplied(state, "b", { effectId: "burn", turnsRemaining: 1, damagePerTick: 8 });

  const updated = withStatusesTicked(state);

  assert.equal(hasStatus(updated, "a", "shield"), true); // permanent, untouched
  assert.equal(hasStatus(updated, "b", "burn"), false); // 1 -> 0 -> expired, removed
});
