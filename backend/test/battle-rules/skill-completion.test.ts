import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createBattleState, withStatusApplied, hasStatus } from '../../src/battle-rules/battle-state.js';
import { useAbility } from '../../src/battle-rules/ability-engine.js';
import { defaultCombinationBook as book } from '../../src/battle-rules/combination-book.js';
import { combustion, wildfire, fragmentation, unstableCore, type Mutation } from '../../src/battle-rules/mutations.js';
import type { BattleState } from '../../src/battle-rules/types.js';
const start = (ap: number) => createBattleState({playerAId:'a',playerBId:'b',currentTurnId:'a',ap:{a:{max:5,current:ap}}});
const play = (s: BattleState, mutations: Mutation[], elementIds = ['fire','earth']) =>
  useAbility(s,{actorId:'a',elementIds},book,mutations);
test('full AP focus is deterministic, includes regen and respects slow', () => {
  const state = start(4);
  assert.equal(play(state,[unstableCore]).state.hp.b!.current,77);
  assert.equal(play(state,[unstableCore]).state.hp.b!.current,77);
  assert.equal(state.ap.a!.current,4);
  assert.deepEqual(play(state,[unstableCore]).feedback,['focused']);
  assert.equal(play(start(3),[unstableCore]).state.hp.b!.current,82);
  const slow = withStatusApplied(state,'a',{effectId:'slow',turnsRemaining:1,damagePerTick:0});
  assert.deepEqual(play(slow,[unstableCore]).feedback,[]);
  assert.deepEqual(play(state,[unstableCore],['fire']).feedback,[]);
  assert.throws(() => play(start(0),[unstableCore]));
});
test('fragments trade damage for breaking defense; statuses/AP happen once', () => {
  assert.equal(play(start(4),[fragmentation]).state.hp.b!.current,85);
  const shield = withStatusApplied(start(4),'b',{effectId:'shield',turnsRemaining:null,damagePerTick:0});
  const split = play(shield,[fragmentation,combustion]);
  assert.equal(split.state.hp.b!.current,93);
  assert.equal(hasStatus(split.state,'b','burn'),false);
  assert.equal(split.state.ap.a!.current,2);
  const guarded = withStatusApplied(start(4),'b',{effectId:'guard',turnsRemaining:1,damagePerTick:0});
  assert.equal(play(guarded,[fragmentation]).state.hp.b!.current,89);
  assert.equal(play(start(4),[unstableCore,fragmentation]).state.hp.b!.current,82);
});
test('support is not multiplied and wildfire creates one longer burn', () => {
  const state = {...start(4), hp:{a:{max:100,current:60},b:{max:100,current:100}}};
  const healed = play(state,[fragmentation,unstableCore],['water','light']);
  assert.equal(healed.state.hp.a!.current,74); assert.equal(healed.state.hp.b!.current,100);
  assert.deepEqual(healed.feedback,[]);
  const burned = play(start(4),[combustion,wildfire,fragmentation],['fire','wind']);
  assert.deepEqual(burned.state.combatantStatuses.b,[{effectId:'burn',turnsRemaining:3,damagePerTick:3}]);
});
