import type { Match } from './types.js';

export const PREPARATION_MS = 5 * 60_000;
export const TURN_MS = 90_000;

export const battleReady = (match: Match): boolean =>
  match.status === 'in_progress' && !!match.state &&
  Object.values(match.players).length === 2 && Object.values(match.players).every(p => p.ready);

export function needsExpiry(match: Match, now: number): boolean {
  return match.status !== 'finished' &&
    (match.deadline === undefined || now >= match.deadline ||
      !!match.seal && now > match.seal.deadline);
}
