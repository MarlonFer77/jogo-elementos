import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createBattleState, withStatusApplied, withDamage, hpOf, apOf, hasStatus } from '../../src/battle-rules/battle-state.js';
import { defaultCombinationBook } from '../../src/battle-rules/combination-book.js';
import { basicRecoveryStatus, playTurn } from '../../src/battle-rules/turn-engine.js';
import { useAbility } from '../../src/battle-rules/ability-engine.js';
import type { BattleState } from '../../src/battle-rules/types.js';

const start = () => createBattleState({playerAId:'a', playerBId:'b', currentTurnId:'a'});
const afflict = (s: BattleState, who: string, effectId: string) => withStatusApplied(s, who,
  {effectId, turnsRemaining:3, damagePerTick:['burn','poison'].includes(effectId) ? 2 : 0});
for (const [element, status] of [['water','burn'], ['nature','poison']] as const) {
  const action = {actorId:'a', elementIds:[element]};
  test(`${element} cleanses before lethal tick, trades damage, keeps AP/turn`, () => {
    const state = afflict(withDamage(start(), 'a', 99), 'a', status);
    const next = playTurn(state, action, defaultCombinationBook).state;
    assert.equal(hpOf(next, 'a').current, 1);
    assert.equal(hpOf(next, 'b').current, 97);
    assert.equal(hasStatus(next, 'a', status), false);
    assert.equal(apOf(next, 'a').current, 1);
    assert.equal(next.currentTurnId, 'b');
    assert.equal(next.winner, null);
    assert.equal(hasStatus(state, 'a', status), true);
    assert.equal(hpOf(playTurn(start(), action, defaultCombinationBook).state, 'b').current, 95);
    assert.ok(useAbility(state, action, defaultCombinationBook, []).feedback?.includes(`recover_${status}`));
  });
  test(`${element} respects defenses, slow, silence and freeze`, () => {
    const state = afflict(afflict(afflict(start(), 'a', status), 'a', 'slow'), 'a', 'silence');
    const shielded = playTurn(afflict(state, 'b', 'shield'), action, defaultCombinationBook).state;
    assert.equal(hpOf(shielded, 'b').current, 100);
    assert.equal(hasStatus(shielded, 'a', status), false);
    assert.equal(apOf(shielded, 'a').current, 0);
    const guarded = playTurn(afflict(state, 'b', 'guard'), action, defaultCombinationBook).state;
    assert.equal(hpOf(guarded, 'b').current, 98);
    assert.throws(() => playTurn(afflict(state, 'a', 'freeze'), action, defaultCombinationBook));
  });
}
test('recovery is specific, never free support from combos or invalid turns', () => {
  const state = afflict(afflict(start(), 'a', 'burn'), 'a', 'poison');
  const next = playTurn(state, {actorId:'a', elementIds:['water']}, defaultCombinationBook).state;
  assert.equal(hasStatus(next, 'a', 'poison'), true);
  assert.equal(hpOf(next, 'a').current, 98);
  assert.equal(basicRecoveryStatus(state, {actorId:'a', elementIds:['water','wind']}), null);
  assert.throws(() => playTurn(state, {actorId:'b', elementIds:['water']}, defaultCombinationBook));
});
