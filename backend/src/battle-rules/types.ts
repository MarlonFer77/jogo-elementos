/**
 * Minimal, deliberate mirror of parts of packages/battle_engine (Dart) —
 * only what's needed to validate a submitted TurnAction server-side. Not a
 * port of the whole engine: statuses (Shield, damage-over-time) are
 * mirrored since they affect dano/HP/vitória directly, but abilities,
 * skill tree and builds are not — nothing in Multiplayer applies a status
 * yet, so `combatantStatuses` stays reachable only through direct state
 * construction (tests, or a future ability-aware endpoint), not through
 * `TurnAction` itself. See DECISION-013/DECISION-014/DECISION-024 in
 * DECISIONS.md.
 */

/** A field effect placed by a resolved combination. No display text (name,
 * description) — the client already has that from its own combination
 * catalog, keyed by `id`. `damage` is the one-time damage dealt to the
 * opponent when this effect is produced — mirrors FieldEffect.damage in
 * battle_engine (Dart). */
export interface FieldEffect {
  readonly id: string;
  readonly area: number;
  readonly duration: number | null;
  readonly damage: number;
}

export interface ElementCombination {
  readonly elementIds: ReadonlySet<string>;
  readonly result: FieldEffect;
}

/** Mirrors HpPool in battle_engine (Dart). */
export interface HpPool {
  readonly max: number;
  readonly current: number;
}

/** Mirrors ActiveStatus in battle_engine (Dart) — an instance of a status
 * effect applied to a target. `effectId` identifies which one (e.g.
 * "shield", "burn"); no display text, same reasoning as FieldEffect.
 * `turnsRemaining: null` means permanent until removed explicitly.
 * `damagePerTick` is how much damage this instance deals every time it
 * ticks (0 for statuses that don't damage, e.g. Shield). */
export interface ActiveStatus {
  readonly effectId: string;
  readonly turnsRemaining: number | null;
  readonly damagePerTick: number;
}

export interface BattleState {
  readonly playerAId: string;
  readonly playerBId: string;
  readonly currentTurnId: string;
  readonly activeFieldEffects: readonly FieldEffect[];
  readonly hp: Readonly<Record<string, HpPool>>;
  readonly combatantStatuses: Readonly<Record<string, readonly ActiveStatus[]>>;
  readonly winner: string | null;
}

export interface TurnAction {
  readonly actorId: string;
  readonly elementIds: readonly string[];
}

export interface TurnResult {
  readonly state: BattleState;
  readonly triggeredCombinationId: string | null;
}
