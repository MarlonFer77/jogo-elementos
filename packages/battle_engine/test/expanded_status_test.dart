import 'package:battle_engine/battle_engine.dart';
import 'package:test/test.dart';

void main() {
  const a = Combatant(id: 'a', name: 'A');
  const b = Combatant(id: 'b', name: 'B');
  final engine = TurnEngine(defaultCombinationBook);
  BattleState start() => BattleState.start(
    playerA: a,
    playerB: b,
    ap: {a: const ApPool(max: 5, current: 3)},
  );
  BattleState status(
    BattleState state,
    Combatant target,
    StatusEffect effect, {
    int turns = 1,
    int tick = 0,
  }) => state.withStatusApplied(
    target,
    ActiveStatus(effect: effect, turnsRemaining: turns, damagePerTick: tick),
  );
  BattleState hit(BattleState state, List<Element> elements) => engine
      .playTurn(state, TurnAction(actor: state.currentTurn, elements: elements))
      .state;

  test('silence rejects combos atomically but permits basic attacks', () {
    final state = status(start(), a, StatusEffects.silence);
    expect(() => hit(state, [Elements.fire, Elements.wind]), throwsStateError);
    expect(state.apOf(a).current, 3);
    expect(
      hit(state, [Elements.fire]).hasStatus(a, StatusEffects.silence),
      false,
    );
    expect(
      engine.playTurn(state, TurnAction.defend(actor: a)).state.currentTurn,
      b,
    );
  });
  test('slow prevents regeneration; shock adds cost only to combos', () {
    expect(
      hit(status(start(), a, StatusEffects.slow), [
        Elements.fire,
      ]).apOf(a).current,
      3,
    );
    final shocked = status(start(), a, StatusEffects.shock);
    expect(hit(shocked, [Elements.fire, Elements.wind]).apOf(a).current, 0);
    expect(hit(shocked, [Elements.fire]).apOf(a).current, 4);
    expect(
      () => hit(shocked, [Elements.fire, Elements.earth, Elements.wind]),
      throwsStateError,
    );
  });
  for (final entry in [(StatusEffects.buff, 7), (StatusEffects.debuff, 4)]) {
    test('${entry.$1.id} modifies direct damage and expires', () {
      final state = status(start(), a, entry.$1);
      final result = hit(state, [Elements.fire]);
      expect(state.hpOf(b).current - result.hpOf(b).current, entry.$2);
      expect(result.hasStatus(a, entry.$1), false);
    });
  }
  test('buff and debuff cancel; wet is consumed only by an electric hit', () {
    final state = status(
      status(start(), a, StatusEffects.buff),
      a,
      StatusEffects.debuff,
    );
    expect(
      state.hpOf(b).current - hit(state, [Elements.fire]).hpOf(b).current,
      5,
    );
    final wet = status(start(), b, StatusEffects.wet, turns: 2);
    final result = hit(wet, [Elements.lightning]);
    expect(wet.hpOf(b).current - result.hpOf(b).current, 7);
    expect(result.hasStatus(b, StatusEffects.wet), false);
    expect(
      hit(wet, [
        Elements.lightning,
        Elements.shadow,
      ]).hasStatus(b, StatusEffects.wet),
      true,
    );
    final shielded = status(wet, b, StatusEffects.shield, turns: 2);
    expect(
      hit(shielded, [Elements.lightning]).hpOf(b).current,
      wet.hpOf(b).current,
    );
    expect(
      hit(shielded, [Elements.lightning]).hasStatus(b, StatusEffects.wet),
      true,
    );
  });
  test('poison ticks 2, 3, 4 on actions then expires', () {
    var state = status(start(), b, StatusEffects.poison, turns: 3, tick: 2);
    for (final damage in [2, 3, 4]) {
      final before = state.hpOf(b).current;
      state = engine
          .playTurn(state, TurnAction.defend(actor: state.currentTurn))
          .state;
      expect(before - state.hpOf(b).current, damage);
    }
    expect(state.hasStatus(b, StatusEffects.poison), false);
  });
  test('20 distinct recipes resolve regardless of order and execute', () {
    final combos = defaultCombinationBook.combinations;
    expect(combos, hasLength(20));
    expect(combos.map((c) => c.resultId).toSet(), hasLength(20));
    final recipes = <String>{};
    for (final combo in combos) {
      final ids = combo.elements.map((e) => e.id).toList()..sort();
      expect(recipes.add(ids.join('+')), true);
      expect(
        defaultCombinationBook
            .resolve(combo.elements.toList().reversed)
            ?.resultId,
        combo.resultId,
      );
      final state = start().copyWith(
        ap: {
          a: const ApPool(max: 5, current: 5),
          b: const ApPool(max: 5, current: 5),
        },
      );
      expect(
        engine
            .playTurn(state, TurnAction(actor: a, elements: combo.elements))
            .triggeredCombination
            ?.resultId,
        combo.resultId,
      );
    }
  });
}
