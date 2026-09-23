import { createHash } from 'node:crypto';
import type { Firestore } from 'firebase-admin/firestore';
import { MatchStore, type MatchSnapshot, type ProfileSeed } from './match-store.js';
import { MatchError } from './errors.js';
import type { Match, PlayerProgress } from './types.js';

const digest = (value: string) => createHash('sha256').update(value).digest('hex');
const profileKey = (player: string, credential: string) => digest(JSON.stringify([player, credential]));

/** Transactions wrap the existing rules, never duplicate them. Polls share a
 * short cache; mutations always read and validate the authoritative revision. */
export class FirestoreMatchStore extends MatchStore {
  private readonly cache = new Map<string, {until: number; store: MatchStore}>();
  constructor(private readonly db: Firestore) { super(); }

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
      const cached = this.cache.get(id);
      if (cached && cached.until > Date.now()) return action(cached.store);
      const document = await this.db.collection('elementosMatches').doc(id).get();
      if (!document.exists) throw new MatchError('Sala não encontrada.', 404);
      const store = new MatchStore();
      store.restore(document.data() as MatchSnapshot);
      if (this.cache.size >= 500) this.cache.clear();
      this.cache.set(id, {until: Date.now() + 1500, store});
      return action(store);
    }
    const output = await this.db.runTransaction(async transaction => {
      const store = new MatchStore();
      if (id) {
        const document = await transaction.get(this.db.collection('elementosMatches').doc(id));
        if (!document.exists) throw new MatchError('Sala não encontrada.', 404);
        store.restore(document.data() as MatchSnapshot);
      }
      if (profile) {
        const credential = digest(profile.token);
        const saved = await transaction.get(this.db.collection('elementosProfiles').doc(profileKey(profile.playerId, credential)));
        if (saved.exists) {
          const data = saved.data() as {progress: PlayerProgress; skills: string[]};
          store.seedProgress(profile.playerId, credential, data.progress, data.skills);
        }
      }
      const result = action(store);
      const match = ((result as {match?: Match}).match ?? result) as Match;
      const snapshot = store.snapshot(match.id);
      // Serialize once to remove optional undefined fields before Firestore.
      const data = JSON.parse(JSON.stringify(snapshot));
      const reference = this.db.collection('elementosMatches').doc(match.id);
      if (id) transaction.set(reference, data);
      else transaction.create(reference, data);
      if (match.status === 'finished') {
        for (const [player, progress] of Object.entries(match.players)) {
          const credential = snapshot.credentials[player]!;
          transaction.set(this.db.collection('elementosProfiles').doc(profileKey(player, credential)),
            {progress, skills: match.skillProgress[player] ?? []});
        }
      }
      return {result, id: match.id};
    });
    this.cache.delete(output.id);
    return output.result;
  }
}
