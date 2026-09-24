import type { BattleState } from "../battle-rules/types.js";

export type MatchStatus = "waiting_for_opponent" | "in_progress" | "finished";

export interface Match {
  readonly seal?: {id: string; actorId: string; elementIds: readonly string[];
    startedAt: number; deadline: number; durationMs: number; reservedAp: number} | null;
  readonly revision: number;
  readonly players: Readonly<Record<string, PlayerProgress>>;
  readonly lastAction?: { revision: number; actorId: string; elementIds: readonly string[]; kind: string; comboId: string | null };
  readonly id: string;
  readonly playerAId: string;
  readonly playerBId: string | null;
  readonly status: MatchStatus;
  readonly state: BattleState | null;
  /** Unlocked Skill Tree node ids per player id — mirrors SkillProgress in
   * battle_engine, tracked here instead of client-side since the backend
   * is the authority (see ARCHITECTURE.md's Multiplayer section and
   * DECISION-025). Empty for both until `join`. */
  readonly skillProgress: Readonly<Record<string, readonly string[]>>;
}

export interface PlayerProgress {
  readonly ready: boolean;
  readonly elements: readonly string[];
  readonly attacks: readonly string[];
  readonly discoveries: readonly string[];
  readonly turns: number;
}
