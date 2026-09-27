import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { defaultCombinationBook } from '../../src/battle-rules/combination-book.js';
import { playTurn } from '../../src/battle-rules/turn-engine.js';
import { createBattleState, withStatusApplied, withHealing } from '../../src/battle-rules/battle-state.js';
import { propagation, volatility } from '../../src/battle-rules/combination-modifiers.js';
import type { BattleState } from '../../src/battle-rules/types.js';

const start = () => createBattleState({playerAId:'a', playerBId:'b', currentTurnId:'a',
  hp:{a:{max:100,current:50}}, ap:{a:{max:5,current:5},b:{max:5,current:2}}});
const play = (s: BattleState, ids: string[]) => playTurn(s, {actorId:'a',elementIds:ids},defaultCombinationBook).state;

test('43 new recipes match shared Dart fixture and support resolution', () => {
  const rows = JSON.parse(readFileSync(new URL('../../../test_fixtures/expanded_combos.json', import.meta.url), 'utf8'));
  assert.equal(rows.length, 43);
  for (const row of rows) {
    const ids: string[] = [...row.elements].reverse();
    const c = defaultCombinationBook.resolve(ids)!;
    assert.equal(c.id, row.id); assert.equal(c.damage, row.damage);
    assert.equal(c.healing ?? 0, row.healing); assert.equal(c.cleanses ?? false, row.cleanses);
    assert.equal(c.apDrain ?? 0, row.apDrain);
    assert.deepEqual(c.statusesToApply?.map(s => ({id:s.status.effectId, turns:s.status.turnsRemaining,
      tick:s.status.damagePerTick, self:s.target === 'actor'})), row.statuses);
    const next = play(start(), ids);
    assert.equal(next.hp.a!.current, 50 + row.healing); assert.equal(next.hp.b!.current, 100 - row.damage);
    assert.equal(next.ap.b!.current, 2 - row.apDrain); assert.equal(next.ap.a!.current, ids.length === 2 ? 2 : 0);
    assert.equal(next.currentTurnId, 'b');
    const modified = volatility.apply(propagation.apply(c));
    assert.equal(modified.healing, c.healing); assert.equal(modified.cleanses, c.cleanses); assert.equal(modified.apDrain, c.apDrain);
  }
});

test('purification before ticks retains benefits and pays original AP cost', () => {
  let s = start();
  for (const id of ['burn','poison','debuff','wet','slow','shock','buff','guard','shield']) {
    s = withStatusApplied(s,'a',{effectId:id,turnsRemaining:3,damagePerTick:['burn','poison'].includes(id)?5:0});
  }
  const next = play(s,['water','light']);
  assert.equal(next.hp.a!.current,62); assert.equal(next.ap.a!.current,1);
  assert.deepEqual(next.combatantStatuses.a!.map(s=>s.effectId).sort(),['buff','guard','shield']);
  assert.equal(s.hp.a!.current,50);
});

test('healing caps, cannot revive; shield blocks drain but not healing', () => {
  assert.equal(withHealing({...start(),hp:{a:{max:100,current:97}}},'a',24).hp.a!.current,100);
  assert.equal(withHealing({...start(),hp:{a:{max:100,current:0}}},'a',24).hp.a!.current,0);
  const shielded = withStatusApplied(start(),'b',{effectId:'shield',turnsRemaining:2,damagePerTick:0});
  const drained = play(shielded,['fire','shadow']);
  assert.equal(drained.ap.b!.current,2); assert.equal(drained.hp.b!.current,100);
  const healed = play(shielded,['fire','nature']);
  assert.equal(healed.hp.a!.current,56); assert.equal(healed.hp.b!.current,100);
  assert.equal(play({...start(),ap:{a:{max:5,current:5},b:{max:5,current:0}}},['fire','shadow']).ap.b!.current,0);
});

test('support respects silence, freeze, AP and finished battles', () => {
  for (const id of ['silence','freeze']) {
    const s = withStatusApplied(start(),'a',{effectId:id,turnsRemaining:2,damagePerTick:0});
    assert.throws(()=>play(s,['water','light'])); assert.equal(s.combatantStatuses.a!.length,1);
  }
  assert.throws(()=>play({...start(),ap:{a:{max:5,current:0}}},['water','light']));
  assert.throws(()=>play({...start(),winner:'b'},['water','light']));
});
