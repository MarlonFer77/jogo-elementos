import { test } from "node:test";
import assert from "node:assert/strict";
import type { AddressInfo } from "node:net";

import { createServer } from "../../src/server.js";

interface ResponseBody {
  error?: string;
  triggeredCombinationId?: string | null;
  state?: {
    currentTurnId: string;
    activeFieldEffects: unknown[];
    hp?: Record<string, { max: number; current: number }>;
    combatantStatuses?: Record<
      string,
      { effectId: string; turnsRemaining: number | null; damagePerTick: number }[]
    >;
    winner?: string | null;
  };
}

async function readBody(response: Response): Promise<ResponseBody> {
  return (await response.json()) as ResponseBody;
}

async function withServer(
  run: (baseUrl: string) => Promise<void>,
): Promise<void> {
  const server = createServer().listen(0);
  const { port } = server.address() as AddressInfo;
  try {
    await run(`http://localhost:${port}`);
  } finally {
    server.close();
  }
}

function baseState() {
  return {
    playerAId: "a",
    playerBId: "b",
    currentTurnId: "a",
    activeFieldEffects: [] as unknown[],
  };
}

test("valid turn returns the authoritative next state", async () => {
  await withServer(async (baseUrl) => {
    const response = await fetch(`${baseUrl}/battles/validate-turn`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        state: baseState(),
        action: { actorId: "a", elementIds: ["fire", "wind"] },
      }),
    });
    const body = await readBody(response);

    assert.equal(response.status, 200);
    assert.equal(body.triggeredCombinationId, "ignited_storm");
    assert.equal(body.state?.currentTurnId, "b");
    assert.equal(body.state?.activeFieldEffects.length, 1);
  });
});

test("rejects an action from a combatant whose turn it is not", async () => {
  await withServer(async (baseUrl) => {
    const response = await fetch(`${baseUrl}/battles/validate-turn`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        state: baseState(),
        action: { actorId: "b", elementIds: ["fire"] },
      }),
    });
    const body = await readBody(response);

    assert.equal(response.status, 400);
    assert.match(body.error ?? "", /turn/);
  });
});

test("rejects a malformed body", async () => {
  await withServer(async (baseUrl) => {
    const response = await fetch(`${baseUrl}/battles/validate-turn`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ state: baseState() }), // missing action
    });

    assert.equal(response.status, 400);
  });
});

test("rejects invalid JSON", async () => {
  await withServer(async (baseUrl) => {
    const response = await fetch(`${baseUrl}/battles/validate-turn`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: "{not json",
    });

    assert.equal(response.status, 400);
  });
});

test("carries over previously active field effects sent by the client",
  async () => {
    await withServer(async (baseUrl) => {
      const response = await fetch(`${baseUrl}/battles/validate-turn`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          state: {
            ...baseState(),
            activeFieldEffects: [
              { id: "ignited_storm", area: 1, duration: null },
            ],
          },
          action: { actorId: "a", elementIds: ["ice"] },
        }),
      });
      const body = await readBody(response);

      assert.equal(response.status, 200);
      assert.equal(body.state?.activeFieldEffects.length, 1);
    });
  });

test("a triggered combination damages the opponent and defaults to 100 HP", async () => {
  await withServer(async (baseUrl) => {
    const response = await fetch(`${baseUrl}/battles/validate-turn`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        state: baseState(),
        action: { actorId: "a", elementIds: ["fire", "wind"] },
      }),
    });
    const body = await readBody(response);

    assert.equal(response.status, 200);
    assert.deepEqual(body.state?.hp, {
      a: { max: 100, current: 100 },
      b: { max: 100, current: 80 },
    });
  });
});

test("carries over HP sent by the client instead of resetting it", async () => {
  await withServer(async (baseUrl) => {
    const response = await fetch(`${baseUrl}/battles/validate-turn`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        state: {
          ...baseState(),
          hp: { a: { max: 100, current: 100 }, b: { max: 100, current: 20 } },
        },
        action: { actorId: "a", elementIds: ["fire", "wind"] },
      }),
    });
    const body = await readBody(response);

    assert.equal(response.status, 200);
    assert.deepEqual(body.state?.hp?.b, { max: 100, current: 0 });
    assert.equal(body.state?.winner, "a");
  });
});

test("Shield blocks combo damage and is consumed, round-tripped over HTTP",
  async () => {
    await withServer(async (baseUrl) => {
      const response = await fetch(`${baseUrl}/battles/validate-turn`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          state: {
            ...baseState(),
            combatantStatuses: {
              b: [{ effectId: "shield", turnsRemaining: null, damagePerTick: 0 }],
            },
          },
          action: { actorId: "a", elementIds: ["fire", "wind"] },
        }),
      });
      const body = await readBody(response);

      assert.equal(response.status, 200);
      assert.equal(body.state?.hp?.b?.current, 100); // blocked
      assert.deepEqual(body.state?.combatantStatuses?.b, []); // consumed
    });
  });

test("carries over a damage-over-time status and ticks it", async () => {
  await withServer(async (baseUrl) => {
    const response = await fetch(`${baseUrl}/battles/validate-turn`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        state: {
          ...baseState(),
          combatantStatuses: {
            b: [{ effectId: "burn", turnsRemaining: 2, damagePerTick: 8 }],
          },
        },
        action: { actorId: "a", elementIds: ["ice"] },
      }),
    });
    const body = await readBody(response);

    assert.equal(response.status, 200);
    assert.equal(body.state?.hp?.b?.current, 92);
    assert.deepEqual(body.state?.combatantStatuses?.b, [
      { effectId: "burn", turnsRemaining: 1, damagePerTick: 8 },
    ]);
  });
});

test("rejects a further turn once state.winner is already set", async () => {
  await withServer(async (baseUrl) => {
    const response = await fetch(`${baseUrl}/battles/validate-turn`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        state: { ...baseState(), winner: "a" },
        action: { actorId: "b", elementIds: ["ice"] },
      }),
    });

    assert.equal(response.status, 400);
  });
});
