import 'package:battle_engine/battle_engine.dart';
import 'package:test/test.dart';

void main() {
  const a = Combatant(id: 'a', name: 'A'), b = Combatant(id: 'b', name: 'B');
  final engine = AbilityEngine(TurnEngine(defaultCombinationBook));
  BattleState start(int ap) => BattleState.start(
    playerA: a,
    playerB: b,
    ap: {a: ApPool(max: 5, current: ap)},
  );
  AbilityResult play(
    BattleState state,
    List<Mutation> mutations, {
    List<Element> elements = const [],
  }) => engine.useAbility(
    state,
    a,
    Ability(
      id: 'test',
      name: 'test',
      baseElements: elements.isEmpty
          ? [Elements.fire, Elements.earth]
          : elements,
      mutations: mutations,
    ),
  );

  test(
    'focus requires full AP including regen; previews do not consume it',
    () {
      final state = start(4);
      final focused = play(state, [Mutations.unstableCore]);
      expect(focused.state.hpOf(b).current, 77); // ceil(18 * 1.25)
      expect(focused.feedback, ['focused']);
      expect(play(state, [Mutations.unstableCore]).state.hpOf(b).current, 77);
      expect(state.apOf(a).current, 4);
      expect(
        play(start(3), [Mutations.unstableCore]).state.hpOf(b).current,
        82,
      );
      final slow = state.withStatusApplied(
        a,
        ActiveStatus(effect: StatusEffects.slow, turnsRemaining: 1),
      );
      expect(play(slow, [Mutations.unstableCore]).feedback, isEmpty);
      expect(
        play(
          state,
          [Mutations.unstableCore],
          elements: [Elements.fire],
        ).feedback,
        isEmpty,
      );
      expect(() => play(start(0), [Mutations.unstableCore]), throwsStateError);
    },
  );

  test(
    'fragmentation preserves reduced total; shield/guard affect first hit only',
    () {
      final fragments = [Mutations.fragmentation];
      expect(play(start(4), fragments).state.hpOf(b).current, 85); // 15 = 8 + 7
      final shield = start(
        4,
      ).withStatusApplied(b, ActiveStatus(effect: StatusEffects.shield));
      final split = play(shield, [...fragments, Mutations.combustion]);
      expect(split.state.hpOf(b).current, 93);
      expect(split.state.hasStatus(b, StatusEffects.burn), false);
      expect(split.state.apOf(a).current, 2);
      expect(split.feedback, ['fragmented']);
      final guard = start(4).withStatusApplied(
        b,
        ActiveStatus(effect: StatusEffects.guard, turnsRemaining: 1),
      );
      expect(play(guard, fragments).state.hpOf(b).current, 89); // 4 + 7
      expect(
        play(start(4), [
          Mutations.unstableCore,
          ...fragments,
        ]).state.hpOf(b).current,
        82,
      );
    },
  );

  test('support and DOT are never duplicated; wildfire extends one burn', () {
    final support = start(4).withDamage(a, 40);
    final healed = play(
      support,
      [Mutations.fragmentation, Mutations.unstableCore],
      elements: [Elements.water, Elements.light],
    );
    expect(healed.state.hpOf(a).current, 74);
    expect(healed.state.hpOf(b).current, 100);
    expect(healed.feedback, isEmpty);
    final burned = play(
      start(4),
      [Mutations.combustion, Mutations.wildfire, Mutations.fragmentation],
      elements: [Elements.fire, Elements.wind],
    );
    expect(burned.state.statusesOf(b), hasLength(1));
    expect(burned.state.statusesOf(b).single.turnsRemaining, 3);
    expect(burned.state.statusesOf(b).single.damagePerTick, 3);
    var state = burned.state;
    final turns = TurnEngine(defaultCombinationBook);
    for (var i = 0; i < 3; i++) {
      state = turns
          .playTurn(state, TurnAction.defend(actor: state.currentTurn))
          .state;
    }
    expect(state.hasStatus(b, StatusEffects.burn), false);
    expect(state.hpOf(b).current, burned.state.hpOf(b).current - 9);
  });
}
