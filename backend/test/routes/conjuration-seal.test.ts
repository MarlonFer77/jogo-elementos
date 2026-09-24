import {test} from 'node:test';
import assert from 'node:assert/strict';
import {MatchStore} from '../../src/matches/match-store.js';
import {defaultCombinationBook} from '../../src/battle-rules/combination-book.js';
import {sealFor, validSealTrace} from '../../src/battle-rules/seal.js';

function ready() {
  const store = new MatchStore();
  let match = store.create('a');
  match = store.join(match.id,'b');
  for (const p of ['a','b']) match = store.configure(match.id,p,'prepare',['fire','wind'],match.revision);
  for (const actorId of ['a','b','a','b']) match = store.applyTurn(match.id,{actorId,elementIds:[],kind:'defend'},defaultCombinationBook).match;
  return {store, match};
}

test('seal reserves build, rejects bypass/replay and resolves success once',()=>{
  const {store,match}=ready();
  const action={actorId:'a',elementIds:['fire','wind']};
  const casting=store.startSeal(match.id,action,match.revision,1000);
  assert.equal(casting.seal!.reservedAp,3);
  assert.throws(()=>store.applyTurn(match.id,action,defaultCombinationBook));
  assert.throws(()=>store.startSeal(match.id,action,casting.revision,1001));
  assert.throws(()=>store.configure(match.id,'a','attacks',[],casting.revision));
  assert.throws(()=>store.unlockSkill(match.id,'a','vitality_training'));
  const trace=sealFor(action.elementIds).nodes.map((n,i)=>({...n,ms:i*100}));
  const resolved=store.finishSeal(match.id,'a',casting.seal!.id,trace,1500);
  assert.equal(resolved.lastAction!.comboId,'ignited_storm');
  assert.equal(resolved.state!.currentTurnId,'b');
  assert.equal(resolved.state!.ap.a!.current,0);
  assert.throws(()=>store.finishSeal(match.id,'a',casting.seal!.id,trace,1600));
});

test('persisted timeout loses one AP, no discovery or guard and advances once',()=>{
  const {store,match}=ready();
  const casting=store.startSeal(match.id,{actorId:'a',elementIds:['fire','wind']},match.revision,1000);
  const restored=new MatchStore(); restored.restore(store.snapshot(match.id));
  const failed=restored.expireSeal(match.id,casting.seal!.deadline+1);
  assert.equal(failed.state!.ap.a!.current,1);
  assert.equal(failed.state!.hp.b!.current,100);
  assert.deepEqual(failed.players.a!.discoveries,[]);
  assert.equal(failed.lastAction!.kind,'fizzle');
  assert.equal(failed.state!.currentTurnId,'b');
  assert.equal(restored.expireSeal(match.id,99999).revision,failed.revision);
});

test('trace requires correct ordered geometry and finite monotonic bounded times',()=>{
  const elements=['fire','wind'];
  const trace=sealFor(elements).nodes.map((n,i)=>({...n,ms:i*100}));
  assert.equal(validSealTrace(elements,trace,500),true);
  assert.deepEqual(sealFor(elements),sealFor([...elements].reverse()));
  for(const bad of [trace.slice(1),[...trace].reverse(),trace.map(n=>({...n,ms:0})),trace.map(n=>({...n,x:NaN})),trace.map(n=>({...n,ms:9000}))]) {
    assert.equal(validSealTrace(elements,bad,500),false);
  }
  const {store,match}=ready();
  const cast=store.startSeal(match.id,{actorId:'a',elementIds:elements},match.revision,0);
  assert.equal(store.finishSeal(match.id,'a',cast.seal!.id,[],100).lastAction!.kind,'fizzle');
});
