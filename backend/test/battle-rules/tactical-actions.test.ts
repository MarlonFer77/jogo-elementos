import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createBattleState, withStatusApplied, hpOf, hasStatus} from '../../src/battle-rules/battle-state.js';
import {defaultCombinationBook} from '../../src/battle-rules/combination-book.js';
import {playTurn} from '../../src/battle-rules/turn-engine.js';
import {useAbility} from '../../src/battle-rules/ability-engine.js';
import {combustion, guard} from '../../src/battle-rules/mutations.js';
import type {BattleState} from '../../src/battle-rules/types.js';
const start = () => createBattleState({playerAId:'a', playerBId:'b', currentTurnId:'a',
  ap:{a:{max:5,current:4},b:{max:5,current:4}}});
const defend = (s: BattleState) => playTurn(s,{actorId:s.currentTurnId,elementIds:[],kind:'defend'},defaultCombinationBook).state;
const attack = (s: BattleState, elementIds: string[]) => playTurn(s,{actorId:s.currentTurnId,elementIds},defaultCombinationBook).state;

for (const actor of ['a','b']) test(`defend halves one hit and caps AP: ${actor}`, () => {
  const state = {...start(),currentTurnId:actor};
  const defended = defend(state);
  assert.equal(state.ap[actor]!.current,4);
  assert.equal(defended.ap[actor]!.current,5);
  const hit = attack(defended,['fire']);
  assert.equal(hpOf(hit,actor).current,97);
  assert.equal(hasStatus(hit,actor,'guard'),false);
});
test('defense expires against defense and does not apply skill mutations', () => {
  const first = useAbility(start(), {actorId:'a',elementIds:[],kind:'defend'},defaultCombinationBook,[combustion,guard]).state;
  assert.deepEqual(first.combatantStatuses.b,[]);
  assert.equal(hasStatus(first,'a','shield'),false);
  const second = defend(first);
  assert.equal(hasStatus(second,'a','guard'),false);
  assert.equal(second.combatantStatuses.b!.length,1);
});
test('storm applies two later DOT ticks that defense cannot block', () => {
  let s = attack(start(),['fire','wind']);
  assert.equal(hpOf(s,'b').current,86);
  assert.equal(s.combatantStatuses.b![0]!.turnsRemaining,2);
  s=defend(s); assert.equal(hpOf(s,'b').current,83);
  s=defend(s); assert.equal(hpOf(s,'b').current,80);
  assert.equal(hasStatus(s,'b','burn'),false);
});
test('shield blocks storm burn; electric field grants guard', () => {
  const shield = attack(withStatusApplied(start(),'b',{effectId:'shield',turnsRemaining:null,damagePerTick:0}),['fire','wind']);
  assert.equal(hpOf(shield,'b').current,100);
  assert.equal(hasStatus(shield,'b','burn'),false);
  let s = attack(start(),['water','lightning']);
  assert.equal(hpOf(s,'b').current,88);
  assert.equal(s.ap.a!.current,2);
  s=attack(s,['fire','wind']); assert.equal(hpOf(s,'a').current,93);
});
test('invalid defend payload, duplicates and out-of-turn defense fail', () => {
  for (const action of [{actorId:'a',elementIds:['fire'],kind:'defend' as const},
    {actorId:'a',elementIds:['fire','fire']}, {actorId:'b',elementIds:[],kind:'defend' as const}]) {
    assert.throws(()=>playTurn(start(),action,defaultCombinationBook));
  }
});
test('combo and skill burn do not stack; stronger burn wins', () => {
  const s=useAbility(start(),{actorId:'a',elementIds:['fire','wind']},defaultCombinationBook,[combustion]).state;
  assert.equal(s.combatantStatuses.b!.length,1);
  assert.equal(s.combatantStatuses.b![0]!.damagePerTick,8);
});
