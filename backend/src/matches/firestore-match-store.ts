import { createHash } from 'node:crypto';
import {credentialDigest} from '../auth/identity.js';
import type { Firestore, Transaction } from 'firebase-admin/firestore';
import { MatchStore, type MatchSnapshot, type ProfileSeed } from './match-store.js';
import { MatchError } from './errors.js';
import type { Match } from './types.js';
import {mergeProfile, validProfile, type SavedProfile} from './profile-progress.js';

const digest = (value: string) => createHash('sha256').update(value).digest('hex');
const profileKey = (player: string, credential: string) => digest(JSON.stringify([player, credential]));

/** Transactions wrap the existing rules, never duplicate them. Polls share a
 * short cache; mutations always read and validate the authoritative revision. */
export class FirestoreMatchStore extends MatchStore {
  private readonly cache = new Map<string, {until: number; store: MatchStore}>();
  private readonly pendingReads = new Map<string, Promise<MatchStore>>();
  constructor(private readonly db: Firestore) { super(); }

  private async loadProfile(transaction: Transaction, key: string): Promise<SavedProfile | undefined> {
    const saved = await transaction.get(this.db.collection('elementosProfiles').doc(key));
    const data: unknown = saved.data();
    // Do not downgrade a document written by a newer server.
    if (data && typeof data === 'object' && 'version' in data && data.version !== 1) {
      throw new MatchError('Perfil de uma versão mais recente. Atualize o servidor.', 503);
    }
    if (validProfile(data)) return data;
    const backup = await transaction.get(this.db.collection('elementosProfileBackups').doc(key));
    if (validProfile(backup.data())) return backup.data() as SavedProfile;
    if (saved.exists || backup.exists) throw new MatchError('Perfil inválido e sem cópia válida. Dados preservados; contate o suporte.', 503);
    return undefined;
  }

  private cacheStore(id: string, store: MatchStore): MatchStore {
    const current = this.cache.get(id);
    // A slow GET must never overwrite a newer committed transaction.
    if (current && current.store.get(id).revision > store.get(id).revision) return current.store;
    if (this.cache.size >= 500 && !this.cache.has(id)) {
      this.cache.delete(this.cache.keys().next().value!);
    }
    this.cache.set(id, {until: Date.now() + 1500, store});
    return store;
  }

  private async read(id: string): Promise<MatchStore> {
    const cached = this.cache.get(id);
    if (cached && cached.until > Date.now()) return cached.store;
    const pending = this.pendingReads.get(id);
    if (pending) return pending;
    const load = (async () => {
      const document = await this.db.collection('elementosMatches').doc(id).get();
      if (!document.exists) throw new MatchError('Sala não encontrada.', 404);
      const store = new MatchStore();
      store.restore(document.data() as MatchSnapshot);
      return this.cacheStore(id, store);
    })();
    this.pendingReads.set(id, load);
    try { return await load; }
    finally { this.pendingReads.delete(id); }
  }

  override async run<T>(id: string | undefined, action: (store: MatchStore) => T,
      write = false, profile?: ProfileSeed): Promise<T> {
    try { return await this.execute(id, action, write, profile); }
    catch (error) {
      if (error instanceof MatchError || error instanceof Error && error.name === 'TurnValidationError') throw error;
      throw new MatchError('Persistência indisponível. Aguarde e reconecte antes de repetir a ação.', 503);
    }
  }

  private async execute<T>(id: string | undefined, action: (store: MatchStore) => T,
      write: boolean, profile?: ProfileSeed): Promise<T> {
    if (id && !/^[A-F0-9]{6}$/.test(id)) throw new MatchError('Código de sala inválido.', 400);
    if (!write && id) {
      return action(await this.read(id));
    }
    const output = await this.db.runTransaction(async transaction => {
      const store = new MatchStore();
      let previousRevision: number | undefined;
      if (id) {
        const document = await transaction.get(this.db.collection('elementosMatches').doc(id));
        if (!document.exists) throw new MatchError('Sala não encontrada.', 404);
        store.restore(document.data() as MatchSnapshot);
        previousRevision = store.get(id).revision;
      }
      if (profile) {
        const credential = credentialDigest(profile.token);
        const data = await this.loadProfile(transaction, profileKey(profile.playerId, credential));
        if (data) {
          store.seedProgress(profile.playerId, credential, data.progress, data.skills, data.revision);
        }
      }
      const result = action(store);
      const match = ((result as {match?: Match}).match ?? result) as Match;
      if (match.revision === previousRevision) return {result, id: match.id, store};
      const snapshot = store.snapshot(match.id);
      // Serialize once to remove optional undefined fields before Firestore.
      const data = JSON.parse(JSON.stringify(snapshot));
      data.updatedAt = Date.now(); // Ordinary polls do not write; expiry writes once.
      const reference = this.db.collection('elementosMatches').doc(match.id);
      const profiles: {key: string; previous?: SavedProfile; next: SavedProfile}[] = [];
      if (match.status === 'finished' && match.state?.winner) {
        for (const [player, progress] of Object.entries(match.players)) {
          const key = profileKey(player, snapshot.credentials[player]!);
          const previous = await this.loadProfile(transaction, key);
          const next = mergeProfile(previous, {progress, skills: match.skillProgress[player] ?? []},
            match.progressBaseTurns?.[player], match.progressBaseRevisions?.[player]);
          profiles.push({key, previous, next});
        }
      }
      // All reads precede all writes; retries recompute against the latest profile.
      if (id) transaction.set(reference, data);
      else transaction.create(reference, data);
      for (const {key, previous, next} of profiles) {
        transaction.set(this.db.collection('elementosProfileBackups').doc(key), previous ?? next);
        transaction.set(this.db.collection('elementosProfiles').doc(key), next);
      }
      return {result, id: match.id, store};
    });
    this.cacheStore(output.id, output.store);
    return output.result;
  }
}
