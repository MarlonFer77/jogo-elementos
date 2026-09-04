import { test } from "node:test";
import assert from "node:assert/strict";
import type { AddressInfo } from "node:net";

import { createServer } from "../../src/server.js";

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

interface MatchBody {
  id: string;
  playerAId: string;
  playerBId: string | null;
  status: string;
  state: {
    currentTurnId: string;
    activeFieldEffects: unknown[];
    hp?: Record<string, { max: number; current: number }>;
    combatantStatuses?: Record<string, { effectId: string }[]>;
  } | null;
  skillProgress: Record<string, string[]>;
}

async function postJson(url: string, body: unknown): Promise<Response> {
  return fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
}

test(
  "the full section-11 flow: create → join → action A → action B → " +
    "reconnect via GET",
  async () => {
    await withServer(async (baseUrl) => {
      const created = (await (
        await postJson(`${baseUrl}/matches`, { playerAId: "ana" })
      ).json()) as MatchBody;
      assert.equal(created.status, "waiting_for_opponent");

      const joinResponse = await postJson(
        `${baseUrl}/matches/${created.id}/join`,
        { playerBId: "beto" },
      );
      const joined = (await joinResponse.json()) as MatchBody;
      assert.equal(joinResponse.status, 200);
      assert.equal(joined.status, "in_progress");
      assert.equal(joined.state?.currentTurnId, "ana");

      const turnAResponse = await postJson(
        `${baseUrl}/matches/${created.id}/turns`,
        { actorId: "ana", elementIds: ["fire", "wind"] },
      );
      const turnABody = (await turnAResponse.json()) as {
        match: MatchBody;
        triggeredCombinationId: string | null;
      };
      assert.equal(turnAResponse.status, 200);
      assert.equal(turnABody.triggeredCombinationId, "ignited_storm");
      assert.equal(turnABody.match.state?.currentTurnId, "beto");

      const turnBResponse = await postJson(
        `${baseUrl}/matches/${created.id}/turns`,
        { actorId: "beto", elementIds: ["water", "lightning"] },
      );
      const turnBBody = (await turnBResponse.json()) as {
        match: MatchBody;
      };
      assert.equal(turnBResponse.status, 200);
      assert.equal(turnBBody.match.state?.activeFieldEffects.length, 2);
      assert.equal(turnBBody.match.state?.currentTurnId, "ana");

      // Reconnection: a dropped client just re-fetches the match.
      const reconnectResponse = await fetch(`${baseUrl}/matches/${created.id}`);
      const reconnected = (await reconnectResponse.json()) as MatchBody;
      assert.equal(reconnectResponse.status, 200);
      assert.equal(reconnected.state?.activeFieldEffects.length, 2);
    });
  },
);

test("joining an unknown match returns 404", async () => {
  await withServer(async (baseUrl) => {
    const response = await postJson(`${baseUrl}/matches/GHOST1/join`, {
      playerBId: "beto",
    });
    assert.equal(response.status, 404);
  });
});

test("submitting a turn before an opponent joins returns 409", async () => {
  await withServer(async (baseUrl) => {
    const created = (await (
      await postJson(`${baseUrl}/matches`, { playerAId: "ana" })
    ).json()) as MatchBody;

    const response = await postJson(`${baseUrl}/matches/${created.id}/turns`, {
      actorId: "ana",
      elementIds: ["fire"],
    });
    assert.equal(response.status, 409);
  });
});

test("submitting a turn as a non-participant returns 403", async () => {
  await withServer(async (baseUrl) => {
    const created = (await (
      await postJson(`${baseUrl}/matches`, { playerAId: "ana" })
    ).json()) as MatchBody;
    await postJson(`${baseUrl}/matches/${created.id}/join`, {
      playerBId: "beto",
    });

    const response = await postJson(`${baseUrl}/matches/${created.id}/turns`, {
      actorId: "carla",
      elementIds: ["fire"],
    });
    assert.equal(response.status, 403);
  });
});

test("submitting an out-of-turn action returns 400", async () => {
  await withServer(async (baseUrl) => {
    const created = (await (
      await postJson(`${baseUrl}/matches`, { playerAId: "ana" })
    ).json()) as MatchBody;
    await postJson(`${baseUrl}/matches/${created.id}/join`, {
      playerBId: "beto",
    });

    const response = await postJson(`${baseUrl}/matches/${created.id}/turns`, {
      actorId: "beto",
      elementIds: ["fire"],
    });
    assert.equal(response.status, 400);
  });
});

test("GET on an unknown match returns 404", async () => {
  await withServer(async (baseUrl) => {
    const response = await fetch(`${baseUrl}/matches/GHOST1`);
    assert.equal(response.status, 404);
  });
});

test(
  "unlocking a Skill Tree node applies its mutation on the next turn: " +
    "unlock Combustão, play Fogo, opponent gets Queimadura",
  async () => {
    await withServer(async (baseUrl) => {
      const created = (await (
        await postJson(`${baseUrl}/matches`, { playerAId: "ana" })
      ).json()) as MatchBody;
      await postJson(`${baseUrl}/matches/${created.id}/join`, { playerBId: "beto" });

      const unlockResponse = await postJson(
        `${baseUrl}/matches/${created.id}/skills/unlock`,
        { playerId: "ana", nodeId: "ember_mastery" },
      );
      const unlockBody = (await unlockResponse.json()) as { match: MatchBody };
      assert.equal(unlockResponse.status, 200);
      assert.deepEqual(unlockBody.match.skillProgress.ana, ["ember_mastery"]);

      const turnResponse = await postJson(`${baseUrl}/matches/${created.id}/turns`, {
        actorId: "ana",
        elementIds: ["fire"],
      });
      const turnBody = (await turnResponse.json()) as { match: MatchBody };
      assert.equal(
        turnBody.match.state?.combatantStatuses?.beto?.some((s) => s.effectId === "burn"),
        true,
      );
    });
  },
);

test("unlocking a node out of turn returns 400", async () => {
  await withServer(async (baseUrl) => {
    const created = (await (
      await postJson(`${baseUrl}/matches`, { playerAId: "ana" })
    ).json()) as MatchBody;
    await postJson(`${baseUrl}/matches/${created.id}/join`, { playerBId: "beto" });

    const response = await postJson(`${baseUrl}/matches/${created.id}/skills/unlock`, {
      playerId: "beto",
      nodeId: "ember_mastery",
    });
    assert.equal(response.status, 400);
  });
});

test("unlocking an unreachable node (unmet prerequisite) returns 400", async () => {
  await withServer(async (baseUrl) => {
    const created = (await (
      await postJson(`${baseUrl}/matches`, { playerAId: "ana" })
    ).json()) as MatchBody;
    await postJson(`${baseUrl}/matches/${created.id}/join`, { playerBId: "beto" });

    const response = await postJson(`${baseUrl}/matches/${created.id}/skills/unlock`, {
      playerId: "ana",
      nodeId: "wildfire_path",
    });
    assert.equal(response.status, 400);
  });
});
