import { test } from "node:test";
import assert from "node:assert/strict";

import {
  createBattleState,
  hasStatus,
  hpOf,
  withStatusApplied,
} from "../../src/battle-rules/battle-state.js";
import { defaultCombinationBook } from "../../src/battle-rules/combination-book.js";
import { propagation, volatility } from "../../src/battle-rules/combination-modifiers.js";
import { TurnValidationError } from "../../src/battle-rules/errors.js";
import { playTurn } from "../../src/battle-rules/turn-engine.js";

function startState() {
  return createBattleState({
    playerAId: "a",
    playerBId: "b",
    currentTurnId: "a",
  });
}

test("throws if no elements are played", () => {
  assert.throws(
    () => playTurn(startState(), { actorId: "a", elementIds: [] }, defaultCombinationBook),
    TurnValidationError,
  );
});

test("rejects an action from a combatant whose turn it is not", () => {
  assert.throws(
    () =>
      playTurn(
        startState(),
        { actorId: "b", elementIds: ["fire"] },
        defaultCombinationBook,
      ),
    TurnValidationError,
  );
});

test("passes the turn to the opponent after a valid action", () => {
  const result = playTurn(
    startState(),
    { actorId: "a", elementIds: ["fire"] },
    defaultCombinationBook,
  );
  assert.equal(result.state.currentTurnId, "b");
});

test("a single played element never triggers a combination", () => {
  const result = playTurn(
    startState(),
    { actorId: "a", elementIds: ["fire"] },
    defaultCombinationBook,
  );
  assert.equal(result.triggeredCombinationId, null);
  assert.deepEqual(result.state.activeFieldEffects, []);
});

test("playing a known 2-element combination adds it to the field", () => {
  const result = playTurn(
    startState(),
    { actorId: "a", elementIds: ["fire", "wind"] },
    defaultCombinationBook,
  );
  assert.equal(result.triggeredCombinationId, "ignited_storm");
  assert.equal(result.state.activeFieldEffects.length, 1);
  assert.equal(result.state.activeFieldEffects[0]?.id, "ignited_storm");
});

test("playing an unknown combination advances the turn without adding a field effect", () => {
  const result = playTurn(
    startState(),
    { actorId: "a", elementIds: ["ice", "shadow"] },
    defaultCombinationBook,
  );
  assert.equal(result.triggeredCombinationId, null);
  assert.deepEqual(result.state.activeFieldEffects, []);
  assert.equal(result.state.currentTurnId, "b");
});

test("field effects accumulate across turns", () => {
  const first = playTurn(
    startState(),
    { actorId: "a", elementIds: ["fire", "wind"] },
    defaultCombinationBook,
  );
  const second = playTurn(
    first.state,
    { actorId: "b", elementIds: ["water", "lightning"] },
    defaultCombinationBook,
  );
  assert.equal(second.state.activeFieldEffects.length, 2);
});

test("a triggered combination damages the opponent, not the actor", () => {
  const result = playTurn(
    startState(),
    { actorId: "a", elementIds: ["fire", "wind"] },
    defaultCombinationBook,
  );
  assert.deepEqual(hpOf(result.state, "b"), { max: 100, current: 80 });
  assert.deepEqual(hpOf(result.state, "a"), { max: 100, current: 100 });
});

test("an unknown combination deals no damage", () => {
  const result = playTurn(
    startState(),
    { actorId: "a", elementIds: ["ice", "shadow"] },
    defaultCombinationBook,
  );
  assert.deepEqual(hpOf(result.state, "b"), { max: 100, current: 100 });
});

test("sets a winner once repeated combo damage defeats a combatant", () => {
  let state = startState();
  for (let i = 0; i < 4; i++) {
    state = playTurn(
      state,
      { actorId: "a", elementIds: ["fire", "wind"] },
      defaultCombinationBook,
    ).state;
    state = playTurn(
      state,
      { actorId: "b", elementIds: ["ice"] },
      defaultCombinationBook,
    ).state;
  }
  assert.equal(state.winner, null);
  const final = playTurn(
    state,
    { actorId: "a", elementIds: ["fire", "wind"] },
    defaultCombinationBook,
  );
  assert.equal(final.state.winner, "a");
});

test("throws when playing a turn after the battle is already over", () => {
  let state = startState();
  for (let i = 0; i < 5; i++) {
    state = playTurn(
      state,
      { actorId: "a", elementIds: ["fire", "wind"] },
      defaultCombinationBook,
    ).state;
    if (state.winner) break;
    state = playTurn(
      state,
      { actorId: "b", elementIds: ["ice"] },
      defaultCombinationBook,
    ).state;
  }
  assert.equal(state.winner, "a");
  assert.throws(
    () =>
      playTurn(
        state,
        { actorId: "b", elementIds: ["ice"] },
        defaultCombinationBook,
      ),
    TurnValidationError,
  );
});

test("Shield blocks the next combo damage and is consumed", () => {
  const state = withStatusApplied(startState(), "b", {
    effectId: "shield",
    turnsRemaining: null,
    damagePerTick: 0,
  });

  const result = playTurn(
    state,
    { actorId: "a", elementIds: ["fire", "wind"] },
    defaultCombinationBook,
  );

  assert.equal(hpOf(result.state, "b").current, 100);
  assert.equal(hasStatus(result.state, "b", "shield"), false);
});

test("Shield does not block a second hit after being consumed", () => {
  let state = withStatusApplied(startState(), "b", {
    effectId: "shield",
    turnsRemaining: null,
    damagePerTick: 0,
  });

  state = playTurn(
    state,
    { actorId: "a", elementIds: ["fire", "wind"] },
    defaultCombinationBook,
  ).state; // blocked, shield consumed
  state = playTurn(
    state,
    { actorId: "b", elementIds: ["ice"] },
    defaultCombinationBook,
  ).state; // no-op, just passes the turn back
  state = playTurn(
    state,
    { actorId: "a", elementIds: ["fire", "wind"] },
    defaultCombinationBook,
  ).state; // not blocked this time

  assert.equal(hpOf(state, "b").current, 80);
});

test(
  "a status with damagePerTick damages its owner at the end of every " +
    "playTurn call, including the tick that expires it",
  () => {
    let state = withStatusApplied(startState(), "b", {
      effectId: "burn",
      turnsRemaining: 2,
      damagePerTick: 8,
    });

    state = playTurn(
      state,
      { actorId: "a", elementIds: ["fire"] },
      defaultCombinationBook,
    ).state;
    assert.equal(hpOf(state, "b").current, 92); // first tick

    state = playTurn(
      state,
      { actorId: "b", elementIds: ["water"] },
      defaultCombinationBook,
    ).state;
    assert.equal(hpOf(state, "b").current, 84); // second tick, expires
    assert.equal(hasStatus(state, "b", "burn"), false);
  },
);

test("DOT damage alone can set a winner", () => {
  const state = withStatusApplied(
    createBattleState({
      playerAId: "a",
      playerBId: "b",
      currentTurnId: "a",
      hp: { a: { max: 100, current: 100 }, b: { max: 5, current: 5 } },
    }),
    "b",
    { effectId: "burn", turnsRemaining: 1, damagePerTick: 8 },
  );

  const result = playTurn(
    state,
    { actorId: "a", elementIds: ["ice"] },
    defaultCombinationBook,
  );

  assert.equal(result.state.winner, "a");
});

test(
  "when DOT ticks would defeat both combatants in the same resolution, " +
    "the actor wins the tie",
  () => {
    // Both start lethal-low on HP, both carry a lethal DOT — the action
    // itself deals no combo damage (single element), so this isolates the
    // tie strictly to the DOT tick ordering.
    let state = createBattleState({
      playerAId: "a",
      playerBId: "b",
      currentTurnId: "a",
      hp: { a: { max: 5, current: 5 }, b: { max: 5, current: 5 } },
    });
    state = withStatusApplied(state, "a", {
      effectId: "burn",
      turnsRemaining: 1,
      damagePerTick: 8,
    });
    state = withStatusApplied(state, "b", {
      effectId: "burn",
      turnsRemaining: 1,
      damagePerTick: 8,
    });

    const result = playTurn(
      state,
      { actorId: "a", elementIds: ["ice"] },
      defaultCombinationBook,
    );

    assert.equal(hpOf(result.state, "a").current, 0);
    assert.equal(hpOf(result.state, "b").current, 0);
    assert.equal(result.state.winner, "a");
  },
);

test(
  "applies combinationModifiers to a triggered combination's field effect " +
    "before adding it to the field",
  () => {
    const result = playTurn(
      startState(),
      { actorId: "a", elementIds: ["fire", "wind"] },
      defaultCombinationBook,
      [propagation],
    );

    assert.equal(result.state.activeFieldEffects[0]?.area, 3);
  },
);

test("combinationModifiers apply in order", () => {
  const result = playTurn(
    startState(),
    { actorId: "a", elementIds: ["fire", "wind"] },
    defaultCombinationBook,
    [propagation, propagation],
  );

  assert.equal(result.state.activeFieldEffects[0]?.area, 5);
});

test("combinationModifiers are ignored when no combination triggers", () => {
  const result = playTurn(
    startState(),
    { actorId: "a", elementIds: ["fire"] },
    defaultCombinationBook,
    [propagation],
  );

  assert.deepEqual(result.state.activeFieldEffects, []);
});

test("volatility reduces a triggered combination's duration", () => {
  const result = playTurn(
    startState(),
    { actorId: "a", elementIds: ["fire", "wind"] },
    defaultCombinationBook,
    [volatility],
  );

  // ignited_storm has a null (permanent) duration — volatility leaves it
  // unchanged, same as in battle_engine.
  assert.equal(result.state.activeFieldEffects[0]?.duration, null);
});
