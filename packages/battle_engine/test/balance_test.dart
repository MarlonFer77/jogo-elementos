import 'package:battle_engine/battle_engine.dart';
import 'package:test/test.dart';

void main() {
  const a = Combatant(id: 'a', name: 'A'), b = Combatant(id: 'b', name: 'B');
  final engine = AbilityEngine(TurnEngine(defaultCombinationBook));
  BattleState start() => BattleState.start(
    playerA: a,
    playerB: b,
    ap: {a: const ApPool(max: 5, current: 5)},
  );
  Ability ability(List<Element> elements) => Ability(
    id: 'test',
    name: 'Test',
    baseElements: elements,
    mutations: [Mutations.combustion, Mutations.guard],
  );

  test(
    'basics cannot farm shield or free burn; combos pay AP and grant passives',
    () {
      final basic = engine
          .useAbility(start(), a, ability([Elements.fire]))
          .state;
      expect(basic.statusesOf(a), isEmpty);
      expect(basic.statusesOf(b), isEmpty);
      final combo = engine
          .useAbility(start(), a, ability([Elements.fire, Elements.earth]))
          .state;
      expect(combo.apOf(a).current, 2);
      expect(combo.statusesOf(b).single.damagePerTick, 3);
      expect(combo.statusesOf(a).single.turnsRemaining, 2);
      final after = engine
          .useAbility(
            combo,
            b,
            Ability(id: 'basic', name: 'basic', baseElements: [Elements.water]),
          )
          .state;
      expect(after.hpOf(a).current, 100);
      expect(after.hasStatus(a, StatusEffects.shield), false);
      final next = engine.useAbility(after, a, ability([Elements.fire])).state;
      expect(next.hasStatus(a, StatusEffects.shield), false);
    },
  );

  test('shield blocks passive burn; stronger combo DOT is not overwritten', () {
    final shielded = start().withStatusApplied(
      b,
      ActiveStatus(effect: StatusEffects.shield, turnsRemaining: 2),
    );
    final blocked = engine
        .useAbility(shielded, a, ability([Elements.fire, Elements.earth]))
        .state;
    expect(blocked.hasStatus(b, StatusEffects.burn), false);
    final spread = engine
        .useAbility(
          start(),
          a,
          ability([Elements.fire, Elements.wind]),
          combinationModifiers: [CombinationModifiers.propagation],
        )
        .state;
    expect(spread.statusesOf(b).single.damagePerTick, 4);
  });

  test(
    'defensive utility trades burst, while equivalent electric trios match',
    () {
      final book = defaultCombinationBook;
      expect(book.resolve([Elements.nature, Elements.light])!.damage, 12);
      expect(
        book.resolve([
          Elements.water,
          Elements.lightning,
          Elements.wind,
        ])!.damage,
        28,
      );
      expect(
        book.resolve([
          Elements.earth,
          Elements.nature,
          Elements.shadow,
        ])!.damage,
        lessThan(
          book.resolve([
            Elements.earth,
            Elements.nature,
            Elements.light,
          ])!.damage,
        ),
      );
    },
  );
}
