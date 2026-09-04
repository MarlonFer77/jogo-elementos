import 'package:battle_engine/battle_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Ability', () {
    test('throws if no base elements are given', () {
      expect(
        () => Ability(id: 'fireball', name: 'Bola de Fogo', baseElements: []),
        throwsArgumentError,
      );
    });

    test('starts with no mutations', () {
      final ability = Ability(
        id: 'fireball',
        name: 'Bola de Fogo',
        baseElements: [Elements.fire],
      );
      expect(ability.mutations, isEmpty);
    });

    test('withMutation appends without mutating the original ability', () {
      final ability = Ability(
        id: 'fireball',
        name: 'Bola de Fogo',
        baseElements: [Elements.fire],
      );

      final mutated = ability.withMutation(Mutations.combustion);

      expect(mutated.mutations, equals([Mutations.combustion]));
      expect(ability.mutations, isEmpty);
    });

    test('mutations attach in order', () {
      final ability = Ability(
        id: 'fireball',
        name: 'Bola de Fogo',
        baseElements: [Elements.fire],
      )
          .withMutation(Mutations.combustion)
          .withMutation(Mutations.fragmentation);

      expect(
        ability.mutations,
        equals([Mutations.combustion, Mutations.fragmentation]),
      );
    });
  });

  group('Mutations', () {
    test('all built-in mutations have unique ids', () {
      final ids = Mutations.all.map((m) => m.id).toSet();
      expect(ids.length, equals(Mutations.all.length));
    });

    test('combustion adds a burn status targeting the opponent, without '
        'touching other fields', () {
      const effect = AbilityEffect();
      final result = Mutations.combustion.apply(effect);

      expect(result.statusesToApply, hasLength(1));
      expect(
        result.statusesToApply.single.status.effect,
        equals(StatusEffects.burn),
      );
      expect(
        result.statusesToApply.single.target,
        equals(StatusTarget.opponent),
      );
      expect(result.hitCount, equals(1));
      expect(result.fieldEffect, isNull);
    });

    test('guard adds a shield status targeting the actor', () {
      const effect = AbilityEffect();
      final result = Mutations.guard.apply(effect);

      expect(result.statusesToApply, hasLength(1));
      expect(
        result.statusesToApply.single.status.effect,
        equals(StatusEffects.shield),
      );
      expect(result.statusesToApply.single.target, equals(StatusTarget.actor));
    });

    test('fragmentation increases hitCount', () {
      const effect = AbilityEffect();
      final result = Mutations.fragmentation.apply(effect);
      expect(result.hitCount, equals(2));
    });

    test('wildfire sets a fire field effect', () {
      const effect = AbilityEffect();
      final result = Mutations.wildfire.apply(effect);
      expect(result.fieldEffect?.id, equals('fire_zone'));
    });

    test('unstableCore increases critChanceBonus', () {
      const effect = AbilityEffect();
      final result = Mutations.unstableCore.apply(effect);
      expect(result.critChanceBonus, closeTo(0.15, 1e-9));
    });

    test('combustion\'s burn status deals 8 damage per tick for 2 ticks',
        () {
      const effect = AbilityEffect();
      final result = Mutations.combustion.apply(effect);

      final burn = result.statusesToApply.single.status;
      expect(burn.damagePerTick, equals(8));
      expect(burn.turnsRemaining, equals(2));
    });

    test('mutations compose when applied in sequence', () {
      var effect = const AbilityEffect();
      effect = Mutations.combustion.apply(effect);
      effect = Mutations.fragmentation.apply(effect);

      expect(effect.statusesToApply, hasLength(1));
      expect(effect.hitCount, equals(2));
    });
  });
}
