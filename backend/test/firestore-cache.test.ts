import {test} from 'node:test';
import assert from 'node:assert/strict';
import type {Firestore} from 'firebase-admin/firestore';
import {FirestoreMatchStore} from '../src/matches/firestore-match-store.js';
import {MatchStore} from '../src/matches/match-store.js';

test('concurrent polling shares one read and still authorizes each caller', async () => {
  const memory = new MatchStore(); const m = memory.create('a','secret');
  const snapshot = memory.snapshot(m.id);
  let reads = 0;
  let release!: () => void;
  const gate = new Promise<void>(resolve => {release=resolve;});
  const db = {collection: () => ({doc: () => ({get: async () => {
    reads++; await gate; return {exists:true,data:()=>snapshot};
  }})})} as unknown as Firestore;
  const store = new FirestoreMatchStore(db);
  const good = store.run(m.id,s => {s.authorize(m.id,'secret');return s.get(m.id);});
  const bad = store.run(m.id,s => {s.authorize(m.id,'wrong');return s.get(m.id);});
  const rejected = assert.rejects(bad, /Credencial inválida/);
  release();
  assert.equal((await good).id,m.id);
  await rejected;
  await store.run(m.id,s => s.get(m.id));
  assert.equal(reads,1);
});

test('slow read never overwrites a newer committed revision', async () => {
  const memory = new MatchStore(); const m = memory.create('a','secret');
  let snapshot = memory.snapshot(m.id);
  const original = structuredClone(snapshot);
  let release!: () => void;
  const gate = new Promise<void>(resolve => {release=resolve;});
  const reference = {get: async () => {await gate;return {exists:true,data:()=>original};}};
  const db = {collection:()=>({doc:()=>reference}),runTransaction: async (fn: Function) => fn({
    get: async () => ({exists:true,data:()=>snapshot}),
    set: (_ref: unknown,data: typeof snapshot) => {snapshot=data;},
  })} as unknown as Firestore;
  const store = new FirestoreMatchStore(db);
  const pending = store.run(m.id,s=>s.get(m.id));
  const updated = await store.run(m.id,s=>s.configure(m.id,'a','prepare',['fire','wind'],0),true);
  release();
  assert.equal((await pending).revision,updated.revision);
  assert.equal((await store.run(m.id,s=>s.get(m.id))).revision,updated.revision);
});
