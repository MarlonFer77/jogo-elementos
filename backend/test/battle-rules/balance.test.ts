import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createBattleState, hasStatus, statusesOf, withStatusApplied } from '../../src/battle-rules/battle-state.js';
import { defaultCombinationBook as book } from '../../src/battle-rules/combination-book.js';
import { useAbility } from '../../src/battle-rules/ability-engine.js';
import { combustion, guard } from '../../src/battle-rules/mutations.js';
import { propagation } from '../../src/battle-rules/combination-modifiers.js';

const start = () => createBattleState({playerAId:'a', playerBId:'b', currentTurnId:'a',
  ap:{a:{max:5,current:5}}});
test('basics cannot farm shield/burn; combos pay AP and grant bounded passives', () => {
  const basic = useAbility(start(), {actorId:'a',elementIds:['fire']},book,[combustion,guard]).state;
  assert.deepEqual(statusesOf(basic,'a'), []); assert.deepEqual(statusesOf(basic,'b'), []);
  const combo = useAbility(start(), {actorId:'a',elementIds:['fire','earth']},book,[combustion,guard]).state;
  assert.equal(combo.ap.a!.current,2);
  assert.equal(statusesOf(combo,'b')[0]!.damagePerTick,3);
  assert.equal(statusesOf(combo,'a')[0]!.turnsRemaining,2);
  const after = useAbility(combo,{actorId:'b',elementIds:['water']},book,[]).state;
  assert.equal(after.hp.a!.current,100);
  const next = useAbility(after,{actorId:'a',elementIds:['fire']},book,[guard]).state;
  assert.equal(hasStatus(next,'a','shield'),false);
});
test('shield blocks passive burn and stronger combo DOT survives', () => {
  const shielded = withStatusApplied(start(),'b',{effectId:'shield',turnsRemaining:2,damagePerTick:0});
  const blocked = useAbility(shielded,{actorId:'a',elementIds:['fire','earth']},book,[combustion]).state;
  assert.equal(hasStatus(blocked,'b','burn'),false);
  const spread = useAbility(start(),{actorId:'a',elementIds:['fire','wind']},book,[combustion],[propagation]).state;
  assert.equal(statusesOf(spread,'b')[0]!.damagePerTick,4);
});
test('defense trades burst; equivalent electric trios match', () => {
  assert.equal(book.resolve(['nature','light'])!.damage,12);
  assert.equal(book.resolve(['water','lightning','wind'])!.damage,28);
  assert.ok(book.resolve(['earth','nature','shadow'])!.damage < book.resolve(['earth','nature','light'])!.damage);
});
