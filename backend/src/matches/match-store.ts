import { randomUUID } from "node:crypto";

import { useAbility } from "../battle-rules/ability-engine.js";
import { createBattleState, withMaxHpIncreased } from "../battle-rules/battle-state.js";
import type { CombinationBook } from "../battle-rules/combination-book.js";
import { maxHpBonusesById } from "../battle-rules/max-hp-bonuses.js";
import {
  canUnlock,
  grantedCombinationModifiers,
  grantedMutations,
  nodeById,
} from "../battle-rules/skill-tree.js";
import type { TurnAction, TurnResult } from "../battle-rules/types.js";
import { MatchError } from "./errors.js";
import type { Match } from "./types.js";

/** Short, easy-to-share code — two friends read it to each other or type
 * it, not a UUID. */
function generateMatchId(): string {
  return randomUUID().replace(/-/g, "").slice(0, 6).toUpperCase();
}

/**
 * In-memory match storage. Lost on server restart — real persistence
 * (Firestore) is a follow-up once a real Firebase project exists (see
 * DECISION-015); this is enough to prove the multiplayer flow end to end.
 */
export class MatchStore {
  private readonly matches = new Map<string, Match>();

  create(playerAId: string): Match {
    let id = generateMatchId();
    while (this.matches.has(id)) {
      id = generateMatchId();
    }
    const match: Match = {
      id,
      playerAId,
      playerBId: null,
      status: "waiting_for_opponent",
      state: null,
      skillProgress: { [playerAId]: [] },
    };
    this.matches.set(id, match);
    return match;
  }

  get(id: string): Match {
    const match = this.matches.get(id);
    if (!match) {
      throw new MatchError(`match "${id}" not found`, 404);
    }
    return match;
  }

  join(id: string, playerBId: string): Match {
    const match = this.get(id);
    if (match.status !== "waiting_for_opponent") {
      throw new MatchError(`match "${id}" is not waiting for an opponent`, 409);
    }
    if (playerBId === match.playerAId) {
      throw new MatchError("playerBId must be different from playerAId", 400);
    }

    const updated: Match = {
      ...match,
      playerBId,
      status: "in_progress",
      state: createBattleState({
        playerAId: match.playerAId,
        playerBId,
        currentTurnId: match.playerAId,
      }),
      skillProgress: { ...match.skillProgress, [playerBId]: [] },
    };
    this.matches.set(id, updated);
    return updated;
  }

  applyTurn(
    id: string,
    action: TurnAction,
    combinationBook: CombinationBook,
  ): { match: Match; result: TurnResult } {
    const match = this.get(id);
    if (match.status !== "in_progress" || match.state === null) {
      throw new MatchError(`match "${id}" is not in progress`, 409);
    }
    if (action.actorId !== match.playerAId && action.actorId !== match.playerBId) {
      throw new MatchError(`"${action.actorId}" is not part of match "${id}"`, 403);
    }

    const unlockedNodeIds = match.skillProgress[action.actorId] ?? [];
    const result = useAbility(
      match.state,
      action,
      combinationBook,
      grantedMutations(unlockedNodeIds),
      grantedCombinationModifiers(unlockedNodeIds),
    );
    const updated: Match = {
      ...match,
      state: result.state,
      status: result.state.winner !== null ? "finished" : match.status,
    };
    this.matches.set(id, updated);
    return { match: updated, result };
  }

  /** Unlocks `nodeId` in `playerId`'s Skill Tree progress for this match —
   * mirrors TrainingMatch.unlockSkillForCurrentPlayer, moved server-side.
   * Only the player whose turn it currently is can unlock (same
   * restriction as Modo Treino's UI, now enforced as real authority —
   * see DECISION-025); doesn't itself pass the turn. If the node grants a
   * maxHpBonus, it's applied immediately, same as in battle_engine. */
  unlockSkill(
    id: string,
    playerId: string,
    nodeId: string,
  ): { match: Match } {
    const match = this.get(id);
    if (match.status !== "in_progress" || match.state === null) {
      throw new MatchError(`match "${id}" is not in progress`, 409);
    }
    if (playerId !== match.playerAId && playerId !== match.playerBId) {
      throw new MatchError(`"${playerId}" is not part of match "${id}"`, 403);
    }
    if (playerId !== match.state.currentTurnId) {
      throw new MatchError(`it is not "${playerId}"'s turn`, 400);
    }

    const unlockedNodeIds = match.skillProgress[playerId] ?? [];
    if (!canUnlock(unlockedNodeIds, nodeId)) {
      throw new MatchError(`cannot unlock "${nodeId}" yet`, 400);
    }

    let state = match.state;
    const node = nodeById(nodeId)!;
    if (node.grant.kind === "maxHpBonus") {
      state = withMaxHpIncreased(state, playerId, maxHpBonusesById[node.grant.id]!);
    }

    const updated: Match = {
      ...match,
      state,
      skillProgress: {
        ...match.skillProgress,
        [playerId]: [...unlockedNodeIds, nodeId],
      },
    };
    this.matches.set(id, updated);
    return { match: updated };
  }
}
