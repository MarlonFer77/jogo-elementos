import type { IncomingMessage, ServerResponse } from "node:http";

import { defaultCombinationBook } from "../battle-rules/combination-book.js";
import { TurnValidationError } from "../battle-rules/errors.js";
import { parseTurnAction } from "../battle-rules/parse.js";
import { readJsonBody } from "../http/json-body.js";
import { sendErrorResponse, sendJson } from "../http/respond.js";
import { isNonEmptyString } from "../http/validation.js";
import type { MatchStore } from "../matches/match-store.js";

function token(req: IncomingMessage): string {
  const value = req.headers.authorization?.replace(/^Bearer /, '');
  if (!value || !/^[a-f0-9]{64}$/.test(value)) throw new TurnValidationError('Atualize o aplicativo: credencial de sessão obrigatória.');
  return value;
}

function revision(body: unknown): number {
  const value = (body as Record<string, unknown>)?.revision;
  if (!Number.isSafeInteger(value) || (value as number) < 0) throw new TurnValidationError('Revisão da partida obrigatória. Atualize o aplicativo.');
  return value as number;
}

export async function handleConfigure(req: IncomingMessage, res: ServerResponse, store: MatchStore, id: string): Promise<void> {
  try {
    const body = await readJsonBody(req) as Record<string, unknown>;
    if (!body || !isNonEmptyString(body.playerId) || typeof body.kind !== 'string' || !Array.isArray(body.ids) || !body.ids.every(id => typeof id === 'string')) throw new TurnValidationError('Configuração inválida.');
    const playerId = body.playerId;
    const kind = body.kind;
    sendJson(res, 200, await store.run(id, current => {
      current.authorize(id, token(req), playerId);
      return current.configure(id, playerId, kind, body.ids as string[], revision(body));
    }, true));
  } catch (error) { sendErrorResponse(res, error); }
}

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
    sendJson(res, 201, await store.run(undefined, current => current.create(playerAId, token(req)), true, {playerId: playerAId, token: token(req)}));
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
    sendJson(res, 200, await store.run(matchId, current => current.join(matchId, playerBId, token(req)), true, {playerId: playerBId, token: token(req)}));
  } catch (error) {
    sendErrorResponse(res, error);
  }
}

/** GET /matches/:id — full match state, for reconnection: a client that
 * dropped just re-fetches this to resync. */
export async function handleGetMatch(
  req: IncomingMessage,
  res: ServerResponse,
  store: MatchStore,
  matchId: string,
): Promise<void> {
  try {
    let match = await store.run(matchId, current => {
      current.authorize(matchId, token(req));
      return current.get(matchId);
    });
    if (match.seal && Date.now() > match.seal.deadline) {
      match = await store.run(matchId, current => current.expireSeal(matchId), true);
    }
    sendJson(res, 200, match);
  } catch (error) {
    sendErrorResponse(res, error);
  }
}

export async function handleSeal(req: IncomingMessage, res: ServerResponse, store: MatchStore, id: string, finish: boolean): Promise<void> {
  try {
    const body = await readJsonBody(req) as Record<string, unknown>;
    if (!body || !isNonEmptyString(body.actorId)) throw new TurnValidationError('Jogador obrigatório.');
    const actorId = body.actorId;
    sendJson(res, 200, await store.run(id, current => {
      current.authorize(id, token(req), actorId);
      if (finish) {
        if (!isNonEmptyString(body.sealId)) throw new TurnValidationError('Selo obrigatório.');
        return current.finishSeal(id, actorId, body.sealId, body.trace);
      }
      return current.startSeal(id, parseTurnAction(body), revision(body));
    }, true));
  } catch (error) { sendErrorResponse(res, error); }
}

/** POST /matches/:id/turns — a player's action; validated and applied
 * server-side (see battle-rules/turn-engine.ts). */
export async function handleSubmitTurn(
  req: IncomingMessage,
  res: ServerResponse,
  store: MatchStore,
  matchId: string,
  preview = false,
): Promise<void> {
  try {
    const body = await readJsonBody(req);
    const action = parseTurnAction(body);
    sendJson(res, 200, await store.run(matchId, current => {
      current.authorize(matchId, token(req), action.actorId);
      const beforeState = preview ? current.get(matchId).state : undefined;
      const { match, result } = current.applyTurn(matchId, action, defaultCombinationBook, preview, revision(body));
      return { match, triggeredCombinationId: result.triggeredCombinationId, ...(preview ? {beforeState} : {}) };
    }, !preview));
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

    sendJson(res, 200, await store.run(matchId, current => {
      current.authorize(matchId, token(req), playerId);
      if (revision(body) !== current.get(matchId).revision) throw new TurnValidationError('Estado desatualizado. Sincronize antes de desbloquear.');
      return current.unlockSkill(matchId, playerId, nodeId);
    }, true));
  } catch (error) {
    sendErrorResponse(res, error);
  }
}
