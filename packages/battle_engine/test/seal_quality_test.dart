import 'package:battle_engine/battle_engine.dart';
import 'package:test/test.dart';

void main() {
  const a = Combatant(id: 'a', name: 'A'), b = Combatant(id: 'b', name: 'B');
  final engine = AbilityEngine(TurnEngine(defaultCombinationBook));
  BattleState start() => BattleState.start(
    playerA: a,
    playerB: b,
    ap: {a: const ApPool(max: 5, current: 4)},
  );
  AbilityResult play(
    int percent, {
    BattleState? state,
    List<Mutation> mutations = const [],
    List<Element>? elements,
  }) => engine.useAbility(
    state ?? start(),
    a,
    Ability(
      id: 'seal',
      name: 'Seal',
      baseElements: elements ?? [Elements.fire, Elements.earth],
      mutations: mutations,
    ),
    sealDamagePercent: percent,
  );

  test(
    'grade scales direct damage only, before defense, and preserves AP/turn',
    () {
      for (final (grade, damage) in [(100, 18), (80, 15), (60, 11), (40, 8)]) {
        final result = play(grade);
        expect(result.state.hpOf(b).current, 100 - damage);
        expect(result.state.apOf(a).current, 2);
        expect(result.state.currentTurn, b);
        expect(result.feedback, ['seal_$grade']);
      }
      final shield = start().withStatusApplied(
        b,
        ActiveStatus(effect: StatusEffects.shield),
      );
      expect(play(40, state: shield).state.hpOf(b).current, 100);
      final split = play(
        80,
        mutations: [Mutations.fragmentation, Mutations.unstableCore],
      );
      expect(
        split.state.hpOf(b).current,
        85,
      ); // ceil(ceil(18 * 1.25 * .8) * .8)
      expect(() => play(101), throwsArgumentError);
    },
  );

  test('healing and periodic burn stay intact at low quality', () {
    final healed = play(
      40,
      state: start().withDamage(a, 40),
      elements: [Elements.water, Elements.light],
    );
    expect(healed.state.hpOf(a).current, 74);
    final full = play(100, elements: [Elements.fire, Elements.wind]);
    final weak = play(40, elements: [Elements.fire, Elements.wind]);
    expect(weak.state.statusesOf(b), full.state.statusesOf(b));
  });
}
