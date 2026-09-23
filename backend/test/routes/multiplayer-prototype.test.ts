import { test } from 'node:test';
import assert from 'node:assert/strict';
import type { AddressInfo } from 'node:net';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createServer } from '../../src/server.js';
import { MatchStore } from '../../src/matches/match-store.js';
import { defaultCombinationBook } from '../../src/battle-rules/combination-book.js';

test('two HTTP clients prepare, discover, equip and reject stale/forged actions', async () => {
  const server = createServer(new MatchStore()).listen(0);
  const base = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
  const request = async (path: string, player: string, body?: object) => {
    const response = await fetch(base + path, {method: body ? 'POST' : 'GET',
      headers: {'Content-Type':'application/json', Authorization: `Bearer ${player.repeat(64)}`},
      ...(body ? {body: JSON.stringify(body)} : {})});
    return {status: response.status, body: await response.json() as any};
  };
  try {
    const created = await request('/matches','a',{playerAId:'a'});
    assert.equal(created.status,201);
    const path = `/matches/${created.body.id}`;
    let match = (await request(`${path}/join`,'b',{playerBId:'b'})).body;
    for (const playerId of ['a','b']) {
      match = (await request(`${path}/configure`,playerId,{playerId,kind:'prepare',ids:['fire','wind'],revision:match.revision})).body;
    }
    assert.equal((await request(path,'c')).status,403);
    assert.equal((await request(`${path}/turns`,'b',{actorId:'a',elementIds:['fire'],revision:match.revision})).status,403);
    assert.equal((await request(`${path}/turns`,'a',{actorId:'a',elementIds:['ice'],revision:match.revision})).status,400);
    for (const actorId of ['a','b','a','b']) {
      const turn = await request(`${path}/turns`,actorId,{actorId,elementIds:[],kind:'defend',revision:match.revision});
      assert.equal(turn.status,200,JSON.stringify(turn.body)); match=turn.body.match;
    }
    const action = {actorId:'a',elementIds:['fire','wind'],revision:match.revision};
    const preview = await request(`${path}/preview`,'a',action);
    assert.equal(preview.status,200);
    assert.equal((await request(path,'a')).body.revision,match.revision);
    match=(await request(`${path}/turns`,'a',action)).body.match;
    assert.deepEqual(match.state,preview.body.match.state);
    assert.deepEqual(match.players.a.discoveries,['ignited_storm']);
    assert.deepEqual(match.players.a.attacks,['ignited_storm']);
    assert.equal((await request(`${path}/turns`,'a',action)).status,409);
    match=(await request(`${path}/turns`,'b',{actorId:'b',elementIds:['fire'],revision:match.revision})).body.match;
    match=(await request(`${path}/configure`,'a',{playerId:'a',kind:'attacks',ids:[],revision:match.revision})).body;
    assert.equal((await request(`${path}/turns`,'a',{...action,revision:match.revision})).status,400);
    assert.equal((await request(`${path}/configure`,'a',{playerId:'a',kind:'attacks',ids:['unknown'],revision:match.revision})).status,400);
  } finally { server.closeAllConnections(); await new Promise<void>(resolve => server.close(() => resolve())); }
});

test('configured persistence restores session, battle and completed-match progression', () => {
  const directory=mkdtempSync(join(tmpdir(),'elementos-prototype-'));
  try {
    const filePath=join(directory,'matches.json');
    let store=new MatchStore({filePath});
    let match=store.create('a','a'.repeat(64));
    match=store.join(match.id,'b','b'.repeat(64));
    for (const player of ['a','b']) match=store.configure(match.id,player,'prepare',['fire','wind'],match.revision);
    store=new MatchStore({filePath});
    store.authorize(match.id,'a'.repeat(64),'a');
    assert.throws(() => store.authorize(match.id,'b'.repeat(64),'a'));
    assert.deepEqual(store.get(match.id),match);
    match=store.unlockSkill(match.id,'a','vitality_training').match;
    while (match.status!=='finished') match=store.applyTurn(match.id,{actorId:match.state!.currentTurnId,elementIds:['fire']},defaultCombinationBook,false,match.revision).match;
    store=new MatchStore({filePath});
    const next=store.create('a','a'.repeat(64));
    assert.ok(next.skillProgress.a!.includes('vitality_training'));
    assert.equal(next.players.a!.turns,match.players.a!.turns);
    assert.equal(store.join(next.id,'b','b'.repeat(64)).state!.hp.a!.max,120);
  } finally { rmSync(directory,{recursive:true,force:true}); }
});
