import type { IncomingMessage, ServerResponse } from "node:http";

import { createBattleState } from "../battle-rules/battle-state.js";
import { defaultCombinationBook } from "../battle-rules/combination-book.js";
import { TurnValidationError } from "../battle-rules/errors.js";
import {
  parseCombatantStatuses,
  parseFieldEffect,
  parseHp,
  parseTurnAction,
} from "../battle-rules/parse.js";
import { playTurn } from "../battle-rules/turn-engine.js";
import { readJsonBody } from "../http/json-body.js";
import { sendErrorResponse, sendJson } from "../http/respond.js";
import { isNonEmptyString } from "../http/validation.js";

function parseRequestBody(body: unknown) {
  if (typeof body !== "object" || body === null) {
    throw new TurnValidationError("request body must be a JSON object");
  }
  const { state, action } = body as Record<string, unknown>;

  if (typeof state !== "object" || state === null) {
    throw new TurnValidationError("state is required");
  }
  const stateInput = state as Record<string, unknown>;
  if (
    !isNonEmptyString(stateInput.playerAId) ||
    !isNonEmptyString(stateInput.playerBId) ||
    !isNonEmptyString(stateInput.currentTurnId)
  ) {
    throw new TurnValidationError(
      "state.playerAId, state.playerBId and state.currentTurnId are required strings",
    );
  }
  const activeFieldEffects = Array.isArray(stateInput.activeFieldEffects)
    ? stateInput.activeFieldEffects.map(parseFieldEffect)
    : [];
  if (
    stateInput.winner !== undefined &&
    stateInput.winner !== null &&
    !isNonEmptyString(stateInput.winner)
  ) {
    throw new TurnValidationError("state.winner must be a string or null");
  }

  return {
    state: createBattleState({
      playerAId: stateInput.playerAId,
      playerBId: stateInput.playerBId,
      currentTurnId: stateInput.currentTurnId,
      activeFieldEffects,
      hp: parseHp(stateInput.hp),
      combatantStatuses: parseCombatantStatuses(stateInput.combatantStatuses),
      winner: (stateInput.winner as string | null | undefined) ?? null,
    }),
    action: parseTurnAction(action),
  };
}

/**
 * POST /battles/validate-turn — given a state and an action, recomputes the
 * authoritative result server-side (see battle-rules/turn-engine.ts).
 *
 * Stateless: the client sends the full state, the server doesn't persist
 * anything. For an actual multiplayer match with server-held state, see
 * POST /matches/:id/turns instead.
 */
export async function handleValidateTurn(
  req: IncomingMessage,
  res: ServerResponse,
): Promise<void> {
  try {
    const body = await readJsonBody(req);
    const { state, action } = parseRequestBody(body);
    const result = playTurn(state, action, defaultCombinationBook);
    sendJson(res, 200, result);
  } catch (error) {
    sendErrorResponse(res, error);
  }
}
