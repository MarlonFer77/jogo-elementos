import { test } from 'node:test';
import assert from 'node:assert/strict';
import { defaultCombinationBook } from '../../src/battle-rules/combination-book.js';
import { propagation, volatility } from '../../src/battle-rules/combination-modifiers.js';

test('DOT synergy preserves input and grants one burst bonus, not one per status', () => {
  const base = defaultCombinationBook.resolve(['fire','poison'])!;
  const spread = propagation.apply(base);
  assert.equal(spread.statusesToApply![0]!.status.damagePerTick, 4);
  assert.equal(base.statusesToApply![0]!.status.damagePerTick, 3);
  const burst = volatility.apply(spread);
  assert.equal(burst.damage, base.damage + 4);
  assert.deepEqual(burst.statusesToApply!.map(s => s.status.turnsRemaining), [1,2]);
  const shield = defaultCombinationBook.resolve(['earth','light'])!;
  assert.equal(volatility.apply(shield).damage, shield.damage);
  assert.equal(propagation.apply(shield).statusesToApply![0]!.status.damagePerTick, 0);
});
