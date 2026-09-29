import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createBattleState, withStatusApplied} from '../../src/battle-rules/battle-state.js';
import {useAbility} from '../../src/battle-rules/ability-engine.js';
import {defaultCombinationBook as book} from '../../src/battle-rules/combination-book.js';
import {fragmentation, unstableCore} from '../../src/battle-rules/mutations.js';

test('seal grade scales direct damage before shields/fragments, not AP/healing/statuses', () => {
  const state = createBattleState({playerAId:'a',playerBId:'b',currentTurnId:'a',ap:{a:{max:5,current:4}}});
  const action = {actorId:'a',elementIds:['fire','earth']};
  for (const [percent, damage] of [[100,18],[80,15],[60,11],[40,8]]) {
    const result = useAbility(state,action,book,[],[],percent);
    assert.equal(result.state.hp.b!.current,100-damage!);
    assert.equal(result.state.ap.a!.current,2);
    assert.equal(result.state.currentTurnId,'b');
    assert.deepEqual(result.feedback,[`seal_${percent}`]);
  }
  const shield = withStatusApplied(state,'b',{effectId:'shield',turnsRemaining:null,damagePerTick:0});
  assert.equal(useAbility(shield,action,book,[],[],40).state.hp.b!.current,100);
  assert.equal(useAbility(state,action,book,[fragmentation,unstableCore],[],80).state.hp.b!.current,85);
  const wounded = {...state,hp:{...state.hp,a:{max:100,current:60}}};
  assert.equal(useAbility(wounded,{actorId:'a',elementIds:['water','light']},book,[],[],40).state.hp.a!.current,74);
  const burn = {actorId:'a',elementIds:['fire','wind']};
  assert.deepEqual(useAbility(state,burn,book,[],[],40).state.combatantStatuses.b,
    useAbility(state,burn,book,[],[],100).state.combatantStatuses.b);
  assert.throws(() => useAbility(state,action,book,[],[],101));
});
