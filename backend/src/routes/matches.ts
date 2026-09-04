import type { IncomingMessage, ServerResponse } from "node:http";

import { defaultCombinationBook } from "../battle-rules/combination-book.js";
import { TurnValidationError } from "../battle-rules/errors.js";
import { parseTurnAction } from "../battle-rules/parse.js";
import { readJsonBody } from "../http/json-body.js";
import { sendErrorResponse, sendJson } from "../http/respond.js";
import { isNonEmptyString } from "../http/validation.js";
import type { MatchStore } from "../matches/match-store.js";

async function readRequiredStringField(
  req: IncomingMessage,
  field: string,
): Promise<string> {
  const body = await readJsonBody(req);
  if (typeof body !== "object" || body === null) {
    throw new TurnValidationError("request body must be a JSON object");
  }
  const value = (body as Record<string, unknown>)[field];
  if (!isNonEmptyString(value)) {
    throw new TurnValidationError(`${field} is required`);
  }
  return value;
}

/** POST /matches — creates a match, waiting for a second player. */
export async function handleCreateMatch(
  req: IncomingMessage,
  res: ServerResponse,
  store: MatchStore,
): Promise<void> {
  try {
    const playerAId = await readRequiredStringField(req, "playerAId");
    sendJson(res, 201, store.create(playerAId));
  } catch (error) {
    sendErrorResponse(res, error);
  }
}

/** POST /matches/:id/join — second player joins; starts the battle. */
export async function handleJoinMatch(
  req: IncomingMessage,
  res: ServerResponse,
  store: MatchStore,
  matchId: string,
): Promise<void> {
  try {
    const playerBId = await readRequiredStringField(req, "playerBId");
    sendJson(res, 200, store.join(matchId, playerBId));
  } catch (error) {
    sendErrorResponse(res, error);
  }
}

/** GET /matches/:id — full match state, for reconnection: a client that
 * dropped just re-fetches this to resync. */
export function handleGetMatch(
  res: ServerResponse,
  store: MatchStore,
  matchId: string,
): void {
  try {
    sendJson(res, 200, store.get(matchId));
  } catch (error) {
    sendErrorResponse(res, error);
  }
}

/** POST /matches/:id/turns — a player's action; validated and applied
 * server-side (see battle-rules/turn-engine.ts). */
export async function handleSubmitTurn(
  req: IncomingMessage,
  res: ServerResponse,
  store: MatchStore,
  matchId: string,
): Promise<void> {
  try {
    const body = await readJsonBody(req);
    const action = parseTurnAction(body);
    const { match, result } = store.applyTurn(matchId, action, defaultCombinationBook);
    sendJson(res, 200, { match, triggeredCombinationId: result.triggeredCombinationId });
  } catch (error) {
    sendErrorResponse(res, error);
  }
}

/** POST /matches/:id/skills/unlock — unlocks a Skill Tree node for the
 * current-turn player (see matches/match-store.ts's unlockSkill). */
export async function handleUnlockSkill(
  req: IncomingMessage,
  res: ServerResponse,
  store: MatchStore,
  matchId: string,
): Promise<void> {
  try {
    const body = await readJsonBody(req);
    if (typeof body !== "object" || body === null) {
      throw new TurnValidationError("request body must be a JSON object");
    }
    const { playerId, nodeId } = body as Record<string, unknown>;
    if (!isNonEmptyString(playerId)) {
      throw new TurnValidationError("playerId is required");
    }
    if (!isNonEmptyString(nodeId)) {
      throw new TurnValidationError("nodeId is required");
    }

    const { match } = store.unlockSkill(matchId, playerId, nodeId);
    sendJson(res, 200, { match });
  } catch (error) {
    sendErrorResponse(res, error);
  }
}
