/** The one status id `turn-engine.ts` needs to know by name — Escudo
 * blocks the next combo hit and is consumed (see TurnEngine.playTurn in
 * battle_engine). Every other status effect (Queimadura/burn included) is
 * handled generically by `damagePerTick`/`turnsRemaining`, with no
 * special-casing by id — mirrors `StatusEffects.shield` in
 * status_effects.dart, minimally: only the id, no display text (same
 * reasoning as FieldEffect/ElementCombination in this module). */
export const SHIELD_STATUS_ID = "shield";
