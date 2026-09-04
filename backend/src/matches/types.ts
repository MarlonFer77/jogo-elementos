import type { BattleState } from "../battle-rules/types.js";

export type MatchStatus = "waiting_for_opponent" | "in_progress" | "finished";

export interface Match {
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
