import { test } from "node:test";
import assert from "node:assert/strict";

import { defaultCombinationBook } from "../../src/battle-rules/combination-book.js";
import { MatchStore } from "../../src/matches/match-store.js";

test("create returns a match waiting for an opponent", () => {
  const store = new MatchStore();
  const match = store.create("ana");

  assert.equal(match.playerAId, "ana");
  assert.equal(match.playerBId, null);
  assert.equal(match.status, "waiting_for_opponent");
  assert.equal(match.state, null);
  assert.equal(match.id.length, 6);
});

test("get throws for an unknown match id", () => {
  const store = new MatchStore();
  assert.throws(
    () => store.get("GHOST1"),
    (error: unknown) => error instanceof Error && (error as { status?: number }).status === 404,
  );
});

test("join starts the battle with playerA acting first", () => {
  const store = new MatchStore();
  const created = store.create("ana");

  const joined = store.join(created.id, "beto");

  assert.equal(joined.playerBId, "beto");
  assert.equal(joined.status, "in_progress");
  assert.equal(joined.state?.currentTurnId, "ana");
  assert.equal(joined.state?.playerAId, "ana");
  assert.equal(joined.state?.playerBId, "beto");
});

test("join throws if the match already has an opponent", () => {
  const store = new MatchStore();
  const created = store.create("ana");
  store.join(created.id, "beto");

  assert.throws(
    () => store.join(created.id, "carla"),
    (error: unknown) => error instanceof Error && (error as { status?: number }).status === 409,
  );
});

test("join throws if playerBId equals playerAId", () => {
  const store = new MatchStore();
  const created = store.create("ana");

  assert.throws(
    () => store.join(created.id, "ana"),
    (error: unknown) => error instanceof Error && (error as { status?: number }).status === 400,
  );
});

test("applyTurn throws before an opponent has joined", () => {
  const store = new MatchStore();
  const created = store.create("ana");

  assert.throws(
    () =>
      store.applyTurn(
        created.id,
        { actorId: "ana", elementIds: ["fire"] },
        defaultCombinationBook,
      ),
    (error: unknown) => error instanceof Error && (error as { status?: number }).status === 409,
  );
});

test("applyTurn throws if the actor is not part of the match", () => {
  const store = new MatchStore();
  const created = store.create("ana");
  store.join(created.id, "beto");

  assert.throws(
    () =>
      store.applyTurn(
        created.id,
        { actorId: "carla", elementIds: ["fire"] },
        defaultCombinationBook,
      ),
    (error: unknown) => error instanceof Error && (error as { status?: number }).status === 403,
  );
});

test("applyTurn resolves a combination and advances the turn", () => {
  const store = new MatchStore();
  const created = store.create("ana");
  store.join(created.id, "beto");

  const { match, result } = store.applyTurn(
    created.id,
    { actorId: "ana", elementIds: ["fire", "wind"] },
    defaultCombinationBook,
  );

  assert.equal(result.triggeredCombinationId, "ignited_storm");
  assert.equal(match.state?.currentTurnId, "beto");
  assert.equal(match.state?.activeFieldEffects.length, 1);
  assert.equal(match.status, "in_progress");
});

test("applyTurn marks the match finished once a winner is decided", () => {
  const store = new MatchStore();
  const created = store.create("ana");
  store.join(created.id, "beto");

  let match = store.get(created.id);
  for (let i = 0; i < 4; i++) {
    match = store.applyTurn(
      created.id,
      { actorId: "ana", elementIds: ["fire", "wind"] },
      defaultCombinationBook,
    ).match;
    match = store.applyTurn(
      created.id,
      { actorId: "beto", elementIds: ["ice"] },
      defaultCombinationBook,
    ).match;
  }
  const { match: finished, result } = store.applyTurn(
    created.id,
    { actorId: "ana", elementIds: ["fire", "wind"] },
    defaultCombinationBook,
  );

  assert.equal(result.state.winner, "ana");
  assert.equal(finished.status, "finished");
});

test("applyTurn throws once the match is finished", () => {
  const store = new MatchStore();
  const created = store.create("ana");
  store.join(created.id, "beto");

  for (let i = 0; i < 4; i++) {
    store.applyTurn(
      created.id,
      { actorId: "ana", elementIds: ["fire", "wind"] },
      defaultCombinationBook,
    );
    store.applyTurn(
      created.id,
      { actorId: "beto", elementIds: ["ice"] },
      defaultCombinationBook,
    );
  }
  store.applyTurn(
    created.id,
    { actorId: "ana", elementIds: ["fire", "wind"] },
    defaultCombinationBook,
  );

  assert.throws(
    () =>
      store.applyTurn(
        created.id,
        { actorId: "beto", elementIds: ["ice"] },
        defaultCombinationBook,
      ),
    (error: unknown) => error instanceof Error && (error as { status?: number }).status === 409,
  );
});

test("join gives both players empty skill progress", () => {
  const store = new MatchStore();
  const created = store.create("ana");
  const joined = store.join(created.id, "beto");

  assert.deepEqual(joined.skillProgress, { ana: [], beto: [] });
});

test("unlockSkill unlocks a root node for the current-turn player", () => {
  const store = new MatchStore();
  const created = store.create("ana");
  store.join(created.id, "beto");

  const { match } = store.unlockSkill(created.id, "ana", "ember_mastery");

  assert.deepEqual(match.skillProgress.ana, ["ember_mastery"]);
});

test("unlockSkill applies a maxHpBonus node's bonus immediately", () => {
  const store = new MatchStore();
  const created = store.create("ana");
  store.join(created.id, "beto");

  const { match } = store.unlockSkill(created.id, "ana", "vitality_training");

  assert.deepEqual(match.state?.hp.ana, { max: 120, current: 120 });
});

test("unlockSkill throws when it is not that player's turn", () => {
  const store = new MatchStore();
  const created = store.create("ana");
  store.join(created.id, "beto");

  assert.throws(
    () => store.unlockSkill(created.id, "beto", "ember_mastery"),
    (error: unknown) => error instanceof Error && (error as { status?: number }).status === 400,
  );
});

test("unlockSkill throws when the node cannot be unlocked yet (missing prerequisite)", () => {
  const store = new MatchStore();
  const created = store.create("ana");
  store.join(created.id, "beto");

  assert.throws(
    () => store.unlockSkill(created.id, "ana", "wildfire_path"),
    (error: unknown) => error instanceof Error && (error as { status?: number }).status === 400,
  );
});

test("unlockSkill throws if the player is not part of the match", () => {
  const store = new MatchStore();
  const created = store.create("ana");
  store.join(created.id, "beto");

  assert.throws(
    () => store.unlockSkill(created.id, "carla", "ember_mastery"),
    (error: unknown) => error instanceof Error && (error as { status?: number }).status === 403,
  );
});

test("applyTurn applies a granted mutation's status to the opponent", () => {
  const store = new MatchStore();
  const created = store.create("ana");
  store.join(created.id, "beto");
  store.unlockSkill(created.id, "ana", "ember_mastery"); // grants Combustão

  const { match } = store.applyTurn(
    created.id,
    { actorId: "ana", elementIds: ["fire"] },
    defaultCombinationBook,
  );

  assert.equal(
    match.state?.combatantStatuses.beto?.some((s) => s.effectId === "burn"),
    true,
  );
});

test("applyTurn applies a self-targeted mutation's status (Guarda) to the actor, not the opponent", () => {
  const store = new MatchStore();
  const created = store.create("ana");
  store.join(created.id, "beto");
  store.unlockSkill(created.id, "ana", "guard_training"); // grants Guarda

  const { match } = store.applyTurn(
    created.id,
    { actorId: "ana", elementIds: ["fire"] },
    defaultCombinationBook,
  );

  assert.equal(
    match.state?.combatantStatuses.ana?.some((s) => s.effectId === "shield"),
    true,
  );
  assert.equal(
    match.state?.combatantStatuses.beto?.some((s) => s.effectId === "shield"),
    false,
  );
});

test("applyTurn applies a granted combinationModifier to a triggered combo", () => {
  const store = new MatchStore();
  const created = store.create("ana");
  store.join(created.id, "beto");
  store.unlockSkill(created.id, "ana", "elemental_insight"); // grants Propagação

  const { match } = store.applyTurn(
    created.id,
    { actorId: "ana", elementIds: ["fire", "wind"] },
    defaultCombinationBook,
  );

  assert.equal(match.state?.activeFieldEffects[0]?.area, 3);
});
