import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createBattleState, withStatusApplied, hasStatus, hpOf, apOf } from '../../src/battle-rules/battle-state.js';
import { defaultCombinationBook } from '../../src/battle-rules/combination-book.js';
import { playTurn } from '../../src/battle-rules/turn-engine.js';
import type { BattleState } from '../../src/battle-rules/types.js';

const start = () => createBattleState({playerAId: 'a', playerBId: 'b', currentTurnId: 'a', ap: {a: {max: 5, current: 3}}});
const status = (state: BattleState, target: string, effectId: string, turnsRemaining = 1, damagePerTick = 0) =>
  withStatusApplied(state, target, {effectId, turnsRemaining, damagePerTick});
const hit = (state: BattleState, elementIds: string[]) =>
  playTurn(state, {actorId: state.currentTurnId, elementIds}, defaultCombinationBook).state;

test('silence rejects combos atomically, allows basics and defense', () => {
  const state = status(start(), 'a', 'silence');
  assert.throws(() => hit(state, ['fire', 'wind']), /Silêncio/);
  assert.equal(apOf(state, 'a').current, 3);
  assert.equal(hasStatus(hit(state, ['fire']), 'a', 'silence'), false);
  assert.equal(playTurn(state, {actorId:'a', elementIds:[], kind:'defend'}, defaultCombinationBook).state.currentTurnId, 'b');
});
test('slow removes regeneration; shock increases combo cost only', () => {
  assert.equal(apOf(hit(status(start(), 'a', 'slow'), ['fire']), 'a').current, 3);
  const state = status(start(), 'a', 'shock');
  assert.equal(apOf(hit(state, ['fire', 'wind']), 'a').current, 0);
  assert.equal(apOf(hit(state, ['fire']), 'a').current, 4);
  assert.throws(() => hit(state, ['fire','earth','wind']));
});
for (const [effect, damage] of [['buff', 7], ['debuff', 4]] as const) {
  test(`${effect} modifies direct damage and expires`, () => {
    const state = status(start(), 'a', effect);
    const result = hit(state, ['fire']);
    assert.equal(hpOf(state, 'b').current - hpOf(result, 'b').current, damage);
    assert.equal(hasStatus(result, 'a', effect), false);
  });
}
test('modifiers cancel; wet requires electric hit and respects shield', () => {
  const state = status(status(start(), 'a', 'buff'), 'a', 'debuff');
  assert.equal(hpOf(state, 'b').current - hpOf(hit(state, ['fire']), 'b').current, 5);
  const wet = status(start(), 'b', 'wet', 2);
  const result = hit(wet, ['lightning']);
  assert.equal(hpOf(wet, 'b').current - hpOf(result, 'b').current, 7);
  assert.equal(hasStatus(result, 'b', 'wet'), false);
  assert.equal(hasStatus(hit(wet, ['lightning','shadow']), 'b', 'wet'), true);
  const blocked = hit(status(wet, 'b', 'shield', 2), ['lightning']);
  assert.equal(hpOf(blocked, 'b').current, hpOf(wet, 'b').current);
  assert.equal(hasStatus(blocked, 'b', 'wet'), true);
});
test('poison ticks 2,3,4 then expires', () => {
  let state = status(start(), 'b', 'poison', 3, 2);
  for (const damage of [2,3,4]) {
    const before = hpOf(state, 'b').current;
    state = playTurn(state, {actorId:state.currentTurnId, elementIds:[], kind:'defend'}, defaultCombinationBook).state;
    assert.equal(before - hpOf(state, 'b').current, damage);
  }
  assert.equal(hasStatus(state, 'b', 'poison'), false);
});
test('catalog contains 20 unique recipes executable in reverse order', () => {
  const elements = ['fire','water','wind','ice','nature','lightning','earth','shadow','light','poison'];
  const found = new Set<string>();
  for (let i = 0; i < elements.length; i++) {
    for (let j = i + 1; j < elements.length; j++) {
      for (let k = j; k < elements.length; k++) {
        const ids = k === j ? [elements[i]!, elements[j]!] : [elements[i]!, elements[j]!, elements[k]!];
        const combo = defaultCombinationBook.resolve(ids);
        if (!combo) continue;
        assert.equal(found.has(combo.id), false);
        found.add(combo.id);
        const state = {...start(), ap: {a:{max:5,current:5}, b:{max:5,current:5}}};
        assert.equal(playTurn(state, {actorId:'a', elementIds:ids.reverse()}, defaultCombinationBook).triggeredCombinationId, combo.id);
      }
    }
  }
  assert.equal(found.size, 20);
});
