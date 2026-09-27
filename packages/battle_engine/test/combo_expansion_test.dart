import 'dart:convert';
import 'dart:io';
import 'package:battle_engine/battle_engine.dart';
import 'package:test/test.dart';

void main() {
  const a = Combatant(id: 'a', name: 'A'), b = Combatant(id: 'b', name: 'B');
  final engine = TurnEngine(defaultCombinationBook);
  BattleState start() => BattleState(
    playerA: a,
    playerB: b,
    currentTurn: a,
    hp: {a: const HpPool(max: 100, current: 50)},
    ap: {
      a: const ApPool(max: 5, current: 5),
      b: const ApPool(max: 5, current: 2),
    },
  );
  BattleState play(BattleState s, List<Element> ids) =>
      engine.playTurn(s, TurnAction(actor: a, elements: ids)).state;

  test(
    '43 new recipes match the shared server fixture and resolve support',
    () {
      final rows =
          jsonDecode(
                File(
                  '../../test_fixtures/expanded_combos.json',
                ).readAsStringSync(),
              )
              as List;
      expect(rows.length, 43);
      expect(
        defaultCombinationBook.combinations
            .where((c) => c.elements.length == 2)
            .length,
        40,
      );
      for (final row in rows) {
        final ids = (row['elements'] as List).cast<String>();
        final elements = ids.reversed
            .map((id) => Elements.all.firstWhere((e) => e.id == id))
            .toList();
        final c = defaultCombinationBook.resolve(elements)!;
        expect(c.resultId, row['id']);
        expect(c.resultName, row['name']);
        expect(c.damage, row['damage']);
        expect(c.healing, row['healing']);
        expect(c.cleanses, row['cleanses']);
        expect(c.apDrain, row['apDrain']);
        expect(
          c.statusesToApply
              .map(
                (s) => {
                  'id': s.status.effect.id,
                  'turns': s.status.turnsRemaining,
                  'tick': s.status.damagePerTick,
                  'self': s.target == StatusTarget.actor,
                },
              )
              .toList(),
          row['statuses'],
        );
        final next = play(start(), elements);
        expect(next.hpOf(a).current, 50 + (row['healing'] as int));
        expect(next.hpOf(b).current, 100 - (row['damage'] as int));
        expect(next.apOf(b).current, 2 - (row['apDrain'] as int));
        expect(next.apOf(a).current, ids.length == 2 ? 2 : 0);
        expect(next.currentTurn, b);
        final modified = CombinationModifiers.volatility.apply(
          CombinationModifiers.propagation.apply(c.result),
        );
        expect(modified.healing, c.healing);
        expect(modified.cleanses, c.cleanses);
        expect(modified.apDrain, c.apDrain);
      }
    },
  );

  test(
    'purification precedes ticks, keeps benefits and does not refund AP',
    () {
      var state = start();
      for (final status in [
        StatusEffects.burn,
        StatusEffects.poison,
        StatusEffects.debuff,
        StatusEffects.wet,
        StatusEffects.slow,
        StatusEffects.shock,
        StatusEffects.buff,
        StatusEffects.guard,
        StatusEffects.shield,
      ]) {
        state = state.withStatusApplied(
          a,
          ActiveStatus(
            effect: status,
            turnsRemaining: 3,
            damagePerTick:
                [StatusEffects.burn, StatusEffects.poison].contains(status)
                ? 5
                : 0,
          ),
        );
      }
      final next = play(state, [Elements.water, Elements.light]);
      expect(next.hpOf(a).current, 62);
      expect(
        next.apOf(a).current,
        1,
      ); // no regen under slow, +1 cost under shock
      expect(next.statusesOf(a).map((s) => s.effect.id).toSet(), {
        'buff',
        'guard',
        'shield',
      });
      expect(state.hpOf(a).current, 50);
    },
  );

  test('healing caps, cannot revive; shield blocks drain, not healing', () {
    expect(const HpPool(max: 100, current: 97).withHealing(24).current, 100);
    expect(const HpPool(max: 100, current: 0).withHealing(24).current, 0);
    final shielded = start().withStatusApplied(
      b,
      ActiveStatus(effect: StatusEffects.shield, turnsRemaining: 2),
    );
    final drained = play(shielded, [Elements.fire, Elements.shadow]);
    expect(drained.apOf(b).current, 2);
    expect(drained.hpOf(b).current, 100);
    final healed = play(shielded, [Elements.fire, Elements.nature]);
    expect(healed.hpOf(a).current, 56);
    expect(healed.hpOf(b).current, 100);
    final emptyAp = start().copyWith(
      ap: {
        a: const ApPool(max: 5, current: 5),
        b: const ApPool(max: 5, current: 0),
      },
    );
    expect(play(emptyAp, [Elements.fire, Elements.shadow]).apOf(b).current, 0);
  });

  test(
    'support cannot bypass action locks, insufficient AP or finished battle',
    () {
      for (final effect in [StatusEffects.silence, StatusEffects.freeze]) {
        final s = start().withStatusApplied(
          a,
          ActiveStatus(effect: effect, turnsRemaining: 2),
        );
        expect(
          () => play(s, [Elements.water, Elements.light]),
          throwsStateError,
        );
        expect(s.hasStatus(a, effect), true);
      }
      expect(
        () => play(
          start().copyWith(ap: {a: const ApPool(max: 5, current: 0)}),
          [Elements.water, Elements.light],
        ),
        throwsStateError,
      );
      expect(
        () =>
            play(start().copyWith(winner: b), [Elements.water, Elements.light]),
        throwsStateError,
      );
    },
  );
}
