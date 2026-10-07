import {defaultCombinationBook} from '../battle-rules/combination-book.js';
import {elementIds, nodeById} from '../battle-rules/skill-tree.js';
import type {PlayerProgress} from './types.js';

export interface SavedProfile {
  version?: 1;
  revision?: number;
  progress: PlayerProgress;
  skills: readonly string[];
}

const unique = (values: readonly string[]) => [...new Set(values)];
const ids = (value: unknown): value is string[] => Array.isArray(value) &&
  value.every(id => typeof id === 'string') && new Set(value).size === value.length;

/** Validate stored data, including legacy documents, before using or backing it up. */
export function validProfile(value: unknown): value is SavedProfile {
  if (!value || typeof value !== 'object') return false;
  const {version, revision, progress: p, skills} = value as SavedProfile;
  return (version === undefined || version === 1) &&
    (revision === undefined || Number.isSafeInteger(revision) && revision >= 0) &&
    !!p && typeof p.ready === 'boolean' && Number.isSafeInteger(p.turns) && p.turns >= 0 &&
    ids(skills) && skills.every(id => !!nodeById(id) && nodeById(id)!.prerequisites.every(pre => skills.includes(pre))) &&
    ids(p.discoveries) && p.discoveries.every(id => defaultCombinationBook.containsResult(id)) &&
    ids(p.attacks) && p.attacks.length <= 3 && p.attacks.every(id => p.discoveries.includes(id)) &&
    ids(p.elements) && p.elements.length <= 4 &&
    p.elements.every(id => elementIds.includes(id as typeof elementIds[number]) && skills.includes(`unlock_${id}`)) &&
    (!p.ready || p.elements.length > 0);
}

/** Only server-produced progress enters this merge. Never sum cumulative totals. */
export function mergeProfile(current: SavedProfile | undefined, incoming: SavedProfile,
    baseTurns?: number, baseRevision?: number): SavedProfile {
  if (!validProfile(incoming) || current && !validProfile(current) ||
      baseTurns !== undefined && (!Number.isSafeInteger(baseTurns) || baseTurns < 0 || baseTurns > incoming.progress.turns)) {
    throw new Error('Progresso inválido; dados preservados.');
  }
  const previous = current?.progress;
  const turns = !previous ? incoming.progress.turns : baseTurns === undefined
    ? Math.max(previous.turns, incoming.progress.turns) // Legacy rooms: conservative, no double rewards.
    : Math.max(incoming.progress.turns, previous.turns + incoming.progress.turns - baseTurns);
  const skills = [...(current?.skills ?? [])];
  // Concurrent first-time rooms must not grant unlimited free starter elements.
  const elementLimit = 2 + Math.floor(turns / 10);
  for (const id of incoming.skills) {
    if (skills.includes(id)) continue;
    if (id.startsWith('unlock_') && skills.filter(s => s.startsWith('unlock_')).length >= elementLimit) continue;
    skills.push(id);
  }
  const discoveries = unique([...(previous?.discoveries ?? []), ...incoming.progress.discoveries]);
  // A stale room adds earnings, but does not replace a newer chosen loadout.
  const stale = baseRevision === undefined ? baseTurns !== previous?.turns : baseRevision !== (current?.revision ?? 0);
  const loadout = previous && stale ? previous : incoming.progress;
  const elements = loadout.elements.filter(id => skills.includes(`unlock_${id}`));
  const result: SavedProfile = {version: 1, revision: (current?.revision ?? 0) + 1,
    skills, progress: {...loadout, ready: !!previous?.ready || incoming.progress.ready,
      turns, discoveries, elements: elements.length ? elements : skills.filter(id => id.startsWith('unlock_')).slice(0, 2).map(id => id.slice(7))}};
  if (!validProfile(result)) throw new Error('Progresso inválido; dados preservados.');
  return result;
}
