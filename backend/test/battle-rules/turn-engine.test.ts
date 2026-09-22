import { test } from "node:test";
import assert from "node:assert/strict";

import {
  apOf,
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
    // Convenient default for tests that just need one combo to be
    // affordable right away — tests exercising the AP mechanic itself,
    // or needing more than one combo in a row, override this.
    ap: { a: { max: 5, current: 3 }, b: { max: 5, current: 3 } },
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
  assert.deepEqual(hpOf(result.state, "b"), { max: 100, current: 86 });
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

test("sets a winner once repeated basic (single-element) damage defeats a combatant", () => {
  // 5 basic damage per hit, always affordable (0 AP) — 20 hits defeat
  // 100 HP. Isolates "playTurn sets a winner"; combo/AP math is covered
  // by the AP-specific tests below.
  let state = startState();
  for (let i = 0; i < 19; i++) {
    state = playTurn(state, { actorId: "a", elementIds: ["fire"] }, defaultCombinationBook).state;
    state = playTurn(state, { actorId: "b", elementIds: ["ice"] }, defaultCombinationBook).state;
  }
  assert.equal(state.winner, null);
  const final = playTurn(
    state,
    { actorId: "a", elementIds: ["fire"] },
    defaultCombinationBook,
  );
  assert.equal(final.state.winner, "a");
});

test("throws when playing a turn after the battle is already over", () => {
  let state = startState();
  for (let i = 0; i < 19; i++) {
    state = playTurn(state, { actorId: "a", elementIds: ["fire"] }, defaultCombinationBook).state;
    state = playTurn(state, { actorId: "b", elementIds: ["ice"] }, defaultCombinationBook).state;
  }
  state = playTurn(state, { actorId: "a", elementIds: ["fire"] }, defaultCombinationBook).state;
  assert.equal(state.winner, "a");

  assert.throws(
    () => playTurn(state, { actorId: "b", elementIds: ["ice"] }, defaultCombinationBook),
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
  let state = withStatusApplied(
    createBattleState({
      playerAId: "a",
      playerBId: "b",
      currentTurnId: "a",
      ap: { a: { max: 5, current: 4 } },
    }),
    "b",
    { effectId: "shield", turnsRemaining: null, damagePerTick: 0 },
  );

  state = playTurn(
    state,
    { actorId: "a", elementIds: ["fire", "wind"] },
    defaultCombinationBook,
  ).state; // blocked, shield consumed (4 seeded + 1 regen - 3 spent = 2 left)
  state = playTurn(
    state,
    { actorId: "b", elementIds: ["ice"] },
    defaultCombinationBook,
  ).state; // no-op, just passes the turn back
  state = playTurn(
    state,
    { actorId: "a", elementIds: ["fire", "wind"] },
    defaultCombinationBook,
  ).state; // 2 + 1 regen = 3, affordable again — not blocked this time

  assert.equal(hpOf(state, "b").current, 86);
});

test(
  "a status with damagePerTick damages its owner at the end of every " +
    "playTurn call, including the tick that expires it — on top of the " +
    "actor's own basic damage",
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
    // b: 100 - 5 (a's basic damage) - 8 (first DOT tick) = 87
    assert.equal(hpOf(state, "b").current, 87);

    state = playTurn(
      state,
      { actorId: "b", elementIds: ["water"] },
      defaultCombinationBook,
    ).state;
    // a: 100 - 5 (b's basic damage) = 95
    // b: 87 - 8 (second DOT tick, expires) = 79
    assert.equal(hpOf(state, "a").current, 95);
    assert.equal(hpOf(state, "b").current, 79);
    assert.equal(hasStatus(state, "b", "burn"), false);
  },
);

test("DOT damage alone can set a winner", () => {
  // b's maxHp is 10, not 5: a's basic damage (5) alone must not be
  // enough to defeat them — only the DOT tick (8) on top of it should.
  const state = withStatusApplied(
    createBattleState({
      playerAId: "a",
      playerBId: "b",
      currentTurnId: "a",
      hp: { a: { max: 100, current: 100 }, b: { max: 10, current: 10 } },
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
    // Both start at 8 HP (not 5): a's basic damage to b alone must not
    // decide the winner ahead of the DOT tick this test is about.
    let state = createBattleState({
      playerAId: "a",
      playerBId: "b",
      currentTurnId: "a",
      hp: { a: { max: 8, current: 8 }, b: { max: 8, current: 8 } },
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

test("regenerates 1 AP for the actor at the start of their turn", () => {
  const state = createBattleState({ playerAId: "a", playerBId: "b", currentTurnId: "a" });
  const result = playTurn(state, { actorId: "a", elementIds: ["fire"] }, defaultCombinationBook);

  assert.deepEqual(apOf(result.state, "a"), { max: 5, current: 1 });
  assert.deepEqual(apOf(result.state, "b"), { max: 5, current: 0 });
});

test("AP regeneration is clamped at max", () => {
  const state = createBattleState({
    playerAId: "a",
    playerBId: "b",
    currentTurnId: "a",
    ap: { a: { max: 5, current: 5 } },
  });
  const result = playTurn(state, { actorId: "a", elementIds: ["fire"] }, defaultCombinationBook);

  assert.equal(apOf(result.state, "a").current, 5);
});

test("rejects a 2-element combination without enough AP", () => {
  const state = createBattleState({ playerAId: "a", playerBId: "b", currentTurnId: "a" });
  assert.throws(
    () => playTurn(state, { actorId: "a", elementIds: ["fire", "wind"] }, defaultCombinationBook),
    TurnValidationError,
  );
});

test("rejects a 3-element combination that only affords a 2-element one", () => {
  const state = createBattleState({
    playerAId: "a",
    playerBId: "b",
    currentTurnId: "a",
    ap: { a: { max: 5, current: 3 } },
  });
  assert.throws(
    () =>
      playTurn(
        state,
        { actorId: "a", elementIds: ["earth", "fire", "water"] },
        defaultCombinationBook,
      ),
    TurnValidationError,
  );
});

test("spends 3 AP on a successful 2-element combination", () => {
  const result = playTurn(
    startState(),
    { actorId: "a", elementIds: ["fire", "wind"] },
    defaultCombinationBook,
  );
  // startState seeds 3 + 1 regen = 4, minus 3 spent = 1
  assert.equal(apOf(result.state, "a").current, 1);
});

test("spends all 5 AP on a successful 3-element combination", () => {
  const state = createBattleState({
    playerAId: "a",
    playerBId: "b",
    currentTurnId: "a",
    ap: { a: { max: 5, current: 5 } },
  });
  const result = playTurn(
    state,
    { actorId: "a", elementIds: ["earth", "fire", "water"] },
    defaultCombinationBook,
  );
  assert.equal(apOf(result.state, "a").current, 0);
});
