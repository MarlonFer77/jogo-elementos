import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import type {Firestore} from 'firebase-admin/firestore';
import {MatchStore} from '../src/matches/match-store.js';
import {FirestoreMatchStore} from '../src/matches/firestore-match-store.js';
import {mergeProfile, validProfile, type SavedProfile} from '../src/matches/profile-progress.js';

const profile = (turns = 10): SavedProfile => ({progress: {ready:true, elements:['fire','wind'],
  attacks:[], discoveries:[], turns}, skills:['unlock_fire','unlock_wind']});
const hash = (s: string) => createHash('sha256').update(s).digest('hex');
const key = hash(JSON.stringify(['a',hash('secret')]));

function database() {
  const docs = new Map<string, unknown>();
  let writes = 0;
  const db = {collection: (name:string) => ({doc: (id:string) => `${name}/${id}`}),
    runTransaction: async (fn: Function) => {
      const staged = new Map<string, unknown>();
      let writing = false;
      const value = await fn({get: async (id:string) => {
        assert.equal(writing, false, 'Firestore forbids reads after writes');
        return {exists:docs.has(id), data:()=>structuredClone(docs.get(id))};
      }, set: (id:string,data:unknown) => {writing=true;staged.set(id,structuredClone(data));},
      create: (id:string,data:unknown) => {assert.ok(!docs.has(id));writing=true;staged.set(id,structuredClone(data));}});
      for (const [id,data] of staged) {docs.set(id,data);writes++;}
      return value;
    }} as unknown as Firestore;
  return {docs, store:new FirestoreMatchStore(db), writes:()=>writes};
}

function room(turns: number) {
  const store = new MatchStore();
  const p = profile();
  store.seedProgress('a',hash('secret'),p.progress,p.skills);
  const m = store.create('a','secret');
  store.join(m.id,'b','other');
  store.configure(m.id,'b','prepare',['water','earth'],1);
  const snapshot = store.snapshot(m.id);
  store.restore({...snapshot,match:{...snapshot.match,players:{...snapshot.match.players,
    a:{...snapshot.match.players.a!,turns}}}});
  return store.snapshot(m.id);
}

test('different rooms add only their earned turns; stale loadout cannot erase newer one', () => {
  const a = profile(12), b = profile(13);
  const first = mergeProfile(profile(),a,10);
  const next = mergeProfile({...first,progress:{...first.progress,elements:['wind','fire']}},b,10);
  assert.equal(next.progress.turns,15);
  assert.deepEqual(next.progress.elements,['wind','fire']);
  assert.equal(mergeProfile(profile(90),profile(102),100).progress.turns,102);
  assert.equal(mergeProfile(profile(20),profile(12)).progress.turns,20);
  const changedBuild = {...profile(),revision:2,progress:{...profile().progress,elements:['wind']}};
  assert.deepEqual(mergeProfile(changedBuild,profile(),10,1).progress.elements,['wind']);
  assert.equal(validProfile({...profile(),progress:{...profile().progress,turns:-1}}),false);
});

test('concurrent starter choices cannot bypass element progression gates', () => {
  const incoming: SavedProfile = {progress:{...profile(0).progress,elements:['water','earth']},skills:['unlock_water','unlock_earth']};
  const merged = mergeProfile(profile(0),incoming,0);
  assert.deepEqual(merged.skills,['unlock_fire','unlock_wind']);
  assert.equal(validProfile(merged),true);
});

test('transactions preserve both finished rooms, previous backup and retry idempotence', async () => {
  const f = database();
  f.docs.set(`elementosProfiles/${key}`,profile());
  for (const turns of [12,13]) {
    const snapshot = room(turns), id=snapshot.match.id;
    f.docs.set(`elementosMatches/${id}`,snapshot);
    await f.store.run(id,s=>s.surrender(id,'a'),true);
    const count=f.writes();
    await f.store.run(id,s=>s.surrender(id,'a'),true);
    assert.equal(f.writes(),count);
  }
  assert.equal((f.docs.get(`elementosProfiles/${key}`) as SavedProfile).progress.turns,15);
  assert.equal((f.docs.get(`elementosProfileBackups/${key}`) as SavedProfile).progress.turns,12);
});

test('missing/corrupted profile recovers from backup; no valid backup fails closed', async () => {
  const f=database();
  const load=()=>f.store.run(undefined,s=>s.create('a','secret'),true,{playerId:'a',token:'secret'});
  f.docs.set(`elementosProfiles/${key}`,{broken:true});
  await assert.rejects(load(),/sem cópia válida/);
  assert.deepEqual(f.docs.get(`elementosProfiles/${key}`),{broken:true});
  f.docs.set(`elementosProfileBackups/${key}`,profile(19));
  assert.equal((await load()).players.a!.turns,19);
  f.docs.delete(`elementosProfiles/${key}`);
  assert.equal((await load()).players.a!.turns,19);
  f.docs.set(`elementosProfiles/${key}`,{...profile(),version:2});
  await assert.rejects(load(),/versão mais recente/);
});
