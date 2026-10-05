import {test} from 'node:test';
import assert from 'node:assert/strict';
import type {AddressInfo} from 'node:net';
import type {Firestore} from 'firebase-admin/firestore';
import {MatchStore} from '../../src/matches/match-store.js';
import {FirestoreMatchStore} from '../../src/matches/firestore-match-store.js';
import {PREPARATION_MS, TURN_MS} from '../../src/matches/lifecycle.js';
import {defaultCombinationBook} from '../../src/battle-rules/combination-book.js';
import {createServer} from '../../src/server.js';

function fixture(ready = true) {
  let now = Date.now();
  const store = new MatchStore({now: () => now});
  let match = store.create('a', 'a'.repeat(64));
  if (ready) {
    match = store.join(match.id, 'b', 'b'.repeat(64));
    for (const id of ['a', 'b']) match = store.configure(match.id, id, 'prepare', ['fire', 'wind'], match.revision);
  }
  return {store, id: match.id, now: () => now, advance: (ms: number) => {now += ms;}};
}

test('lobby/preparation expires without a winner; cannot join or act late', () => {
  for (const joined of [false, true]) {
    const f = fixture(false);
    if (joined) f.store.join(f.id, 'b');
    f.advance(PREPARATION_MS);
    assert.throws(() => f.store.join(f.id, 'c'), /Prazo encerrado/);
    assert.throws(() => f.store.configure(f.id, 'a', 'prepare', ['fire','wind'], f.store.get(f.id).revision), /Prazo encerrado/);
    const ended = f.store.expire(f.id);
    assert.equal(ended.status, 'finished');
    assert.equal(ended.state?.winner ?? null, null);
    assert.equal(ended.ending?.reason, 'preparation_timeout');
  }
});

test('reconnect keeps deadline; config cannot buy time; late action is rejected', () => {
  const f = fixture();
  const initial = f.store.get(f.id);
  assert.equal(initial.deadline, f.now() + TURN_MS);
  f.advance(30_000);
  assert.equal(f.store.expire(f.id).deadline, initial.deadline);
  const configured = f.store.configure(f.id, 'a', 'elements', ['fire'], initial.revision);
  assert.equal(configured.deadline, initial.deadline);
  const restored = new MatchStore({now: () => f.now()});
  restored.restore(f.store.snapshot(f.id));
  f.advance(60_000);
  assert.throws(() => restored.applyTurn(f.id, {actorId:'a',elementIds:['fire']}, defaultCombinationBook), /Prazo encerrado/);
  const ended = restored.expire(f.id);
  assert.equal(ended.state!.winner, 'b');
  assert.deepEqual(ended.state!.hp, initial.state!.hp);
  assert.deepEqual(ended.ending, {reason:'timeout',playerId:'a'});
  assert.equal(restored.expire(f.id).revision, ended.revision);
  assert.equal(restored.surrender(f.id, 'b').state!.winner, 'b');
});

test('turn grants next player a full deadline, preview does not mutate', () => {
  const f = fixture();
  const before = f.store.get(f.id);
  f.advance(20_000);
  const action = {actorId:'a',elementIds:[],kind:'defend' as const};
  f.store.applyTurn(f.id, action, defaultCombinationBook, true);
  assert.equal(f.store.get(f.id).deadline, before.deadline);
  const next = f.store.applyTurn(f.id, action, defaultCombinationBook).match;
  assert.equal(next.deadline, f.now() + TURN_MS);
  assert.equal(next.state!.currentTurnId, 'b');
});

test('surrender closes once, including during a seal; cancellation has no winner', () => {
  const lobby = fixture(false);
  assert.equal(lobby.store.surrender(lobby.id, 'a').ending?.reason, 'cancelled');
  const f = fixture();
  for (const actorId of ['a','b','a','b']) f.store.applyTurn(f.id, {actorId,elementIds:[],kind:'defend'}, defaultCombinationBook);
  const cast = f.store.startSeal(f.id, {actorId:'a',elementIds:['fire','wind']}, f.store.get(f.id).revision, f.now());
  assert.throws(() => f.store.surrender(f.id, 'outsider'));
  const ended = f.store.surrender(f.id, 'b');
  assert.equal(ended.state!.winner, 'a');
  assert.equal(ended.seal, null);
  assert.equal(f.store.surrender(f.id, 'a').revision, ended.revision);
  assert.throws(() => f.store.finishSeal(f.id, 'a', cast.seal!.id, [], f.now()));
});

test('seal started just before deadline gets its full duration, fizzles once on reconnect', () => {
  const f = fixture();
  for (const actorId of ['a','b','a','b']) f.store.applyTurn(f.id, {actorId,elementIds:[],kind:'defend'}, defaultCombinationBook);
  f.advance(TURN_MS - 1);
  const cast = f.store.startSeal(f.id, {actorId:'a',elementIds:['fire','wind']}, f.store.get(f.id).revision, f.now());
  assert.equal(cast.deadline, cast.seal!.deadline);
  f.advance(2);
  assert.equal(f.store.expire(f.id).seal!.id, cast.seal!.id);
  f.advance(20_000);
  const next = f.store.expire(f.id);
  assert.equal(next.lastAction!.kind, 'fizzle');
  assert.equal(next.state!.currentTurnId, 'b');
  assert.equal(next.deadline, f.now() + TURN_MS);
  assert.equal(f.store.expire(f.id).revision, next.revision);
});

test('legacy room receives grace instead of an immediate loss', () => {
  const f = fixture();
  const snapshot = f.store.snapshot(f.id);
  f.store.restore({...snapshot,match:{...snapshot.match,deadline:undefined}});
  f.advance(999_999);
  const migrated = f.store.expire(f.id);
  assert.equal(migrated.deadline, f.now() + TURN_MS);
  assert.equal(migrated.status, 'in_progress');
});

test('Firestore finalization writes profiles only once; cancellation never replaces them', async () => {
  for (const ready of [false, true]) {
    const f = fixture(ready);
    let snapshot = f.store.snapshot(f.id), profiles = 0, writes = 0;
    const db = {collection: (collection: string) => ({doc: () => ({collection})}),
      runTransaction: async (fn: Function) => fn({
        get: async () => ({exists:true,data:() => snapshot}),
        set: (ref: {collection:string}, data: typeof snapshot) => {
          if (ref.collection === 'elementosProfiles') profiles++;
          else { snapshot = data; writes++; }
        },
      })} as unknown as Firestore;
    const store = new FirestoreMatchStore(db);
    const end = () => store.run(f.id, s => s.surrender(f.id, 'a'), true);
    await end(); await end();
    assert.equal(writes, 1);
    assert.equal(profiles, ready ? 2 : 0);
  }
});

test('HTTP surrender authenticates actor and safely accepts repeated requests', async () => {
  const f = fixture();
  const server = createServer(f.store).listen(0);
  const url = `http://localhost:${(server.address() as AddressInfo).port}/matches/${f.id}/surrender`;
  const post = (token: string, playerId: string) => fetch(url, {method:'POST',
    headers:{'Content-Type':'application/json',Authorization:`Bearer ${token}`}, body:JSON.stringify({playerId})});
  try {
    assert.equal((await post('c'.repeat(64),'a')).status, 403);
    assert.equal((await post('a'.repeat(64),'b')).status, 403);
    const first = await (await post('a'.repeat(64),'a')).json() as {revision:number,state:{winner:string}};
    assert.equal(first.state.winner, 'b');
    assert.deepEqual(await (await post('a'.repeat(64),'a')).json(), first);
  } finally { server.closeAllConnections(); server.close(); }
});

test('authenticated GET finalizes expired room; unauthorized polling changes nothing', async () => {
  const f = fixture();
  const snapshot = f.store.snapshot(f.id);
  f.store.restore({...snapshot, match:{...snapshot.match,deadline:Date.now() - 1000}});
  const server = createServer(f.store).listen(0);
  const url = `http://localhost:${(server.address() as AddressInfo).port}/matches/${f.id}`;
  try {
    assert.equal((await fetch(url, {headers:{Authorization:`Bearer ${'c'.repeat(64)}`}})).status, 403);
    assert.equal(f.store.get(f.id).status, 'in_progress');
    const response = await fetch(url, {headers:{Authorization:`Bearer ${'b'.repeat(64)}`}});
    assert.equal(response.status, 200);
    const result = await response.json() as {status:string;serverNow:number;state:{winner:string}};
    assert.equal(result.status, 'finished');
    assert.equal(result.state.winner, 'b');
    assert.ok(Number.isSafeInteger(result.serverNow));
    assert.equal(f.store.get(f.id).status, 'finished');
  } finally { server.closeAllConnections(); server.close(); }
});
