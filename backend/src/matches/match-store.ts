import { randomUUID, createHash } from "node:crypto";
import { readFileSync, writeFileSync, renameSync, mkdirSync } from 'node:fs';
import { dirname } from 'node:path';
import { elementIds } from '../battle-rules/skill-tree.js';
import { defaultCombinationBook } from '../battle-rules/combination-book.js';
import { sealFor, validSealTrace } from '../battle-rules/seal.js';

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
import type { Match, PlayerProgress } from "./types.js";

export interface MatchSnapshot { match: Match; credentials: Record<string, string>; }
export interface ProfileSeed { playerId: string; token: string; }

/** Short, easy-to-share code — two friends read it to each other or type
 * it, not a UUID. */
function generateMatchId(): string {
  return randomUUID().replace(/-/g, "").slice(0, 6).toUpperCase();
}

/**
 * Authoritative, single-process prototype store. Optional atomic snapshots
 * survive restarts only when filePath points to retained storage. Without
 * filePath, this is explicitly an in-memory development instance.
 */
export class MatchStore {
  private readonly matches = new Map<string, Match>();
  private readonly credentials = new Map<string, Map<string, string>>();

  async run<T>(_id: string | undefined, action: (store: MatchStore) => T, _write = false, _profile?: ProfileSeed): Promise<T> {
    return action(this);
  }

  snapshot(id: string): MatchSnapshot {
    return {match: this.get(id), credentials: Object.fromEntries(this.credentials.get(id) ?? [])};
  }

  restore(snapshot: MatchSnapshot): void {
    if (!snapshot.match?.id || !snapshot.credentials || !Number.isSafeInteger(snapshot.match.revision)) throw new Error('Dados persistidos inválidos.');
    this.matches.set(snapshot.match.id, snapshot.match);
    this.credentials.set(snapshot.match.id, new Map(Object.entries(snapshot.credentials)));
  }

  seedProgress(playerId: string, digest: string, progress: PlayerProgress, skills: readonly string[]): void {
    this.restore({match: {id: 'profile', revision: 0, playerAId: playerId, playerBId: null,
      status: 'finished', state: null, players: {[playerId]: progress}, skillProgress: {[playerId]: skills}},
      credentials: {[playerId]: digest}});
  }

  private previousProgress(playerId: string, token: string) {
    const digest = createHash('sha256').update(token).digest('hex');
    return [...this.matches.values()].reverse().find(match => match.status === 'finished' && this.credentials.get(match.id)?.get(playerId) === digest);
  }

  constructor(private readonly options: {filePath?: string} = {}) {
    if (!options.filePath) return;
    try {
      const saved = JSON.parse(readFileSync(options.filePath, 'utf8'));
      if (saved.version !== 2 || !Array.isArray(saved.matches) || !Array.isArray(saved.credentials)) throw new Error('Arquivo de partidas inválido; restaure um backup.');
      for (const match of saved.matches as Match[]) {
        if (!match.id || !match.players || !Number.isSafeInteger(match.revision)) throw new Error('Partida persistida inválida.');
        this.matches.set(match.id, match);
      }
      for (const [id, credentials] of saved.credentials) this.credentials.set(id, new Map(credentials));
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error;
    }
  }

  private commit(match: Match, playerId?: string, token?: string): void {
    const credentials = new Map(this.credentials.get(match.id));
    if (playerId && token) credentials.set(playerId, createHash('sha256').update(token).digest('hex'));
    if (this.options.filePath) {
      const matches = new Map(this.matches).set(match.id, match);
      const sessions = new Map(this.credentials).set(match.id, credentials);
      const file = this.options.filePath;
      mkdirSync(dirname(file), {recursive: true});
      writeFileSync(`${file}.tmp`, JSON.stringify({version: 2, matches: [...matches.values()],
        credentials: [...sessions].map(([id, entries]) => [id, [...entries]])}), {mode: 0o600});
      renameSync(`${file}.tmp`, file);
    }
    this.matches.set(match.id, match);
    this.credentials.set(match.id, credentials);
  }

  authorize(id: string, token: string | undefined, playerId?: string): void {
    this.get(id);
    const credentials = this.credentials.get(id);
    const digest = token ? createHash('sha256').update(token).digest('hex') : '';
    if (!token || !(playerId ? credentials?.get(playerId) === digest : [...(credentials?.values() ?? [])].includes(digest))) {
      throw new MatchError('Credencial inválida. Reconecte pelo aparelho que entrou na sala.', 403);
    }
  }

  private checkRevision(match: Match, revision: number): void {
    if (revision !== match.revision) throw new MatchError('Estado desatualizado. Sincronize antes de agir.', 409);
  }

  configure(id: string, playerId: string, kind: string, ids: string[], revision: number): Match {
    const match = this.get(id);
    if (match.seal) throw new MatchError('Conjuração em andamento.', 409);
    this.checkRevision(match, revision);
    const player = match.players[playerId];
    if (!player || match.status === 'finished') throw new MatchError('Jogador ou partida indisponível.', 409);
    if (new Set(ids).size !== ids.length) throw new MatchError('Escolhas duplicadas.', 400);
    let updatedPlayer = player;
    let skills = match.skillProgress[playerId] ?? [];
    if (kind === 'prepare') {
      if (player.ready || ids.length !== 2 || ids.some(id => !elementIds.includes(id as typeof elementIds[number]))) throw new MatchError('Escolha exatamente 2 elementos iniciais válidos.', 400);
      updatedPlayer = {...player, ready: true, elements: ids};
      skills = ids.map(id => `unlock_${id}`);
    } else {
      if (!player.ready || match.state?.currentTurnId !== playerId) throw new MatchError('Aguarde sua vez.', 409);
      if (kind === 'elements') {
        if (ids.length < 1 || ids.length > 4 || ids.some(id => !skills.includes(`unlock_${id}`))) throw new MatchError('Equipe até 4 elementos desbloqueados.', 400);
        updatedPlayer = {...player, elements: ids};
      } else if (kind === 'attacks') {
        if (ids.length > 3 || ids.some(id => !player.discoveries.includes(id))) throw new MatchError('Equipe até 3 habilidades descobertas.', 400);
        updatedPlayer = {...player, attacks: ids};
      } else throw new MatchError('Configuração desconhecida.', 400);
    }
    const updated = {...match, revision: match.revision + 1,
      players: {...match.players, [playerId]: updatedPlayer},
      skillProgress: {...match.skillProgress, [playerId]: skills}};
    this.commit(updated);
    return updated;
  }

  create(playerAId: string, token: string = randomUUID()): Match {
    const previous = this.previousProgress(playerAId, token);
    let id = generateMatchId();
    while (this.matches.has(id)) {
      id = generateMatchId();
    }
    const match: Match = {
      revision: 0,
      players: {[playerAId]: previous?.players[playerAId] ?? {ready: false, elements: [], attacks: [], discoveries: [], turns: 0}},
      id,
      playerAId,
      playerBId: null,
      status: "waiting_for_opponent",
      state: null,
      skillProgress: { [playerAId]: previous?.skillProgress[playerAId] ?? [] },
    };
    this.commit(match, playerAId, token);
    return match;
  }

  get(id: string): Match {
    const match = this.matches.get(id);
    if (!match) {
      throw new MatchError(`match "${id}" not found`, 404);
    }
    return match;
  }

  join(id: string, playerBId: string, token: string = randomUUID()): Match {
    const previous = this.previousProgress(playerBId, token);
    const match = this.get(id);
    if (match.status !== "waiting_for_opponent") {
      throw new MatchError(`match "${id}" is not waiting for an opponent`, 409);
    }
    if (playerBId === match.playerAId) {
      throw new MatchError("playerBId must be different from playerAId", 400);
    }

    const progress = {...match.skillProgress, [playerBId]: previous?.skillProgress[playerBId] ?? []};
    let initialState = createBattleState({playerAId: match.playerAId, playerBId, currentTurnId: match.playerAId});
    for (const [playerId, ids] of Object.entries(progress)) {
      for (const nodeId of ids) {
        const node = nodeById(nodeId);
        if (node?.grant.kind === 'maxHpBonus') initialState = withMaxHpIncreased(initialState, playerId, maxHpBonusesById[node.grant.id]!);
      }
    }
    const updated: Match = {
      ...match,
      revision: match.revision + 1,
      players: {...match.players, [playerBId]: previous?.players[playerBId] ?? {ready: false, elements: [], attacks: [], discoveries: [], turns: 0}},
      playerBId,
      status: "in_progress",
      state: initialState,
      skillProgress: progress,
    };
    this.commit(updated, playerBId, token);
    return updated;
  }

  applyTurn(
    id: string,
    action: TurnAction,
    combinationBook: CombinationBook,
    preview = false,
    revision?: number,
    sealResolution = false,
  ): { match: Match; result: TurnResult } {
    const match = this.get(id);
    if (!sealResolution && match.seal) throw new MatchError('Conclua o selo ou aguarde seu prazo.', 409);
    if (!preview && !sealResolution && action.elementIds.length > 1) throw new MatchError('Conjure o selo para combinar elementos. Atualize o aplicativo.', 409);
    if (revision !== undefined) this.checkRevision(match, revision);
    if (match.status !== "in_progress" || match.state === null) {
      throw new MatchError(`match "${id}" is not in progress`, 409);
    }
    if (action.actorId !== match.playerAId && action.actorId !== match.playerBId) {
      throw new MatchError(`"${action.actorId}" is not part of match "${id}"`, 403);
    }

    const unlockedNodeIds = match.skillProgress[action.actorId] ?? [];
    if (Object.values(match.players).some(player => !player.ready)) throw new MatchError('Aguarde os dois jogadores escolherem seus elementos.', 409);
    const player = match.players[action.actorId]!;
    if (action.elementIds.some(id => !unlockedNodeIds.includes(`unlock_${id}`))) throw new MatchError('Elemento bloqueado.', 400);
    const combo = combinationBook.resolve(action.elementIds);
    const known = combo && player.discoveries.includes(combo.id);
    if (known && !player.attacks.includes(combo.id)) throw new MatchError('Habilidade não equipada. Troque na janela de habilidades.', 400);
    if (!known && action.elementIds.some(id => !player.elements.includes(id))) throw new MatchError('Use os elementos equipados para experimentar.', 400);
    const result = useAbility(
      match.state,
      action,
      combinationBook,
      grantedMutations(unlockedNodeIds),
      grantedCombinationModifiers(unlockedNodeIds),
    );
    const updated: Match = {
      ...match,
      seal: null,
      revision: match.revision + 1,
      players: {...match.players, [action.actorId]: {...player, turns: player.turns + 1,
        discoveries: combo && !known ? [...player.discoveries, combo.id] : player.discoveries,
        attacks: combo && !known && player.attacks.length < 3 ? [...player.attacks, combo.id] : player.attacks}},
      lastAction: {revision: match.revision + 1, actorId: action.actorId, elementIds: action.elementIds, kind: action.kind ?? 'attack', comboId: result.triggeredCombinationId},
      state: result.state,
      status: result.state.winner !== null ? "finished" : match.status,
    };
    if (!preview) this.commit(updated);
    return { match: updated, result };
  }

  startSeal(id: string, action: TurnAction, revision: number, now = Date.now()): Match {
    if (action.elementIds.length < 2 || action.kind && action.kind !== 'attack') throw new MatchError('Selecione 2 ou 3 elementos.', 400);
    const match = this.get(id);
    this.checkRevision(match, revision);
    const preview = this.applyTurn(id, action, defaultCombinationBook, true, revision);
    const durationMs = sealFor(action.elementIds).durationMs;
    // Exclusive reservation: no other action/configuration can change AP or build.
    const beforeAp = match.state!.ap[action.actorId]!;
    const slowed = match.state!.combatantStatuses[action.actorId]?.some(s => s.effectId === 'slow');
    const reservedAp = Math.min(beforeAp.max, beforeAp.current + (slowed ? 0 : 1)) - preview.match.state!.ap[action.actorId]!.current;
    const updated: Match = {...match, revision: match.revision + 1, seal: {
      id: randomUUID(), actorId: action.actorId, elementIds: [...action.elementIds],
      startedAt: now, durationMs, deadline: now + durationMs + 1500, reservedAp}};
    this.commit(updated);
    return updated;
  }

  finishSeal(id: string, actorId: string, sealId: string, trace: unknown, now = Date.now()): Match {
    const match = this.get(id);
    const seal = match.seal;
    if (!seal || seal.id !== sealId || seal.actorId !== actorId) throw new MatchError('Selo expirado ou já resolvido. Sincronize.', 409);
    const success = now <= seal.deadline && validSealTrace(seal.elementIds, trace, now - seal.startedAt);
    return this.applyTurn(id, {actorId, elementIds: success ? seal.elementIds : [],
      kind: success ? 'attack' : 'fizzle'}, defaultCombinationBook, false, match.revision, true).match;
  }

  expireSeal(id: string, now = Date.now()): Match {
    const match = this.get(id);
    return match.seal && now > match.seal.deadline
      ? this.finishSeal(id, match.seal.actorId, match.seal.id, [], now) : match;
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
    if (match.seal) throw new MatchError('Conjuração em andamento.', 409);
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
    const player = match.players[playerId]!;
    if (!player.ready) throw new MatchError('Escolha seus elementos iniciais.', 409);
    if (!canUnlock(unlockedNodeIds, nodeId)) {
      throw new MatchError(`cannot unlock "${nodeId}" yet`, 400);
    }

    let state = match.state;
    const node = nodeById(nodeId)!;
    if (node.grant.kind === 'element') {
      const required = (unlockedNodeIds.filter(id => id.startsWith('unlock_')).length - 1) * 10;
      if (player.turns < required) throw new MatchError(`Faltam ${required - player.turns} turnos para desbloquear este elemento.`, 400);
    }
    if (node.grant.kind === "maxHpBonus") {
      state = withMaxHpIncreased(state, playerId, maxHpBonusesById[node.grant.id]!);
    }

    const updated: Match = {
      ...match,
      revision: match.revision + 1,
      players: {...match.players, [playerId]: {...player,
        elements: node.grant.kind === 'element' && player.elements.length < 4 ? [...player.elements, node.grant.id] : player.elements}},
      state,
      skillProgress: {
        ...match.skillProgress,
        [playerId]: [...unlockedNodeIds, nodeId],
      },
    };
    this.commit(updated);
    return { match: updated };
  }
}
