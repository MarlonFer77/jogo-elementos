import 'package:battle_engine/battle_engine.dart';
import 'package:test/test.dart';

void main() {
  const playerA = Combatant(id: 'a', name: 'Ana');
  const playerB = Combatant(id: 'b', name: 'Beto');
  final abilityEngine = AbilityEngine(TurnEngine(defaultCombinationBook));

  Ability fireball({List<Mutation>? mutations}) {
    var ability = Ability(
      id: 'fireball',
      name: 'Bola de Fogo',
      baseElements: [Elements.fire],
    );
    for (final m in mutations ?? const []) {
      ability = ability.withMutation(m);
    }
    return ability;
  }

  group('AbilityEngine.useAbility', () {
    test('rejects use from a combatant whose turn it is not', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);
      expect(
        () => abilityEngine.useAbility(state, playerB, fireball()),
        throwsStateError,
      );
    });

    test('plain ability (no mutations) just plays its base elements', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);

      final result = abilityEngine.useAbility(state, playerA, fireball());

      expect(result.state.currentTurn, equals(playerB));
      expect(result.state.activeFieldEffects, isEmpty);
      expect(result.state.statusesOf(playerB), isEmpty);
    });

    test('base elements can still trigger a combination', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);
      final windCall = Ability(
        id: 'wind_call',
        name: 'Chamado do Vento',
        baseElements: [Elements.fire, Elements.wind],
      );

      final result = abilityEngine.useAbility(state, playerA, windCall);

      expect(result.triggeredCombination?.resultId, equals('ignited_storm'));
      expect(result.state.activeFieldEffects, hasLength(1));
      expect(
        result.state.activeFieldEffects.first.id,
        equals('ignited_storm'),
      );
    });

    test('Combustão mutation applies burn to the opponent, not the actor',
        () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);

      final result = abilityEngine.useAbility(
        state,
        playerA,
        fireball(mutations: [Mutations.combustion]),
      );

      expect(result.state.hasStatus(playerB, StatusEffects.burn), isTrue);
      expect(result.state.hasStatus(playerA, StatusEffects.burn), isFalse);
    });

    test('Guarda mutation applies Escudo to the actor, not the opponent', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);

      final result = abilityEngine.useAbility(
        state,
        playerA,
        fireball(mutations: [Mutations.guard]),
      );

      expect(result.state.hasStatus(playerA, StatusEffects.shield), isTrue);
      expect(result.state.hasStatus(playerB, StatusEffects.shield), isFalse);
    });

    test('a self-targeted Escudo actually blocks the next combo damage '
        'against the actor', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);
      final guarded = abilityEngine.useAbility(
        state,
        playerA,
        fireball(mutations: [Mutations.guard]),
      ).state; // playerA guarded, turn passed to playerB

      final windCall = Ability(
        id: 'wind_call',
        name: 'Chamado do Vento',
        baseElements: [Elements.fire, Elements.wind],
      );
      final afterOpponentCombo =
          abilityEngine.useAbility(guarded, playerB, windCall).state;

      expect(afterOpponentCombo.hpOf(playerA).current, equals(100));
      expect(
        afterOpponentCombo.hasStatus(playerA, StatusEffects.shield),
        isFalse,
      );
    });

    test('Incêndio mutation adds its field effect alongside a triggered '
        'combination', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);
      final windCall = Ability(
        id: 'wind_call',
        name: 'Chamado do Vento',
        baseElements: [Elements.fire, Elements.wind],
      ).withMutation(Mutations.wildfire);

      final result = abilityEngine.useAbility(state, playerA, windCall);

      expect(result.state.activeFieldEffects, hasLength(2));
      expect(
        result.state.activeFieldEffects.map((e) => e.id),
        containsAll(['ignited_storm', 'fire_zone']),
      );
    });

    test('Núcleo Instável mutation reports a crit bonus without applying '
        'any status or field effect', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);

      final result = abilityEngine.useAbility(
        state,
        playerA,
        fireball(mutations: [Mutations.unstableCore]),
      );

      expect(result.effect.critChanceBonus, closeTo(0.15, 1e-9));
      expect(result.state.activeFieldEffects, isEmpty);
      expect(result.state.statusesOf(playerB), isEmpty);
    });

    test('multiple mutations combine and the turn still passes once', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);

      final result = abilityEngine.useAbility(
        state,
        playerA,
        fireball(
          mutations: [Mutations.combustion, Mutations.fragmentation],
        ),
      );

      expect(result.effect.hitCount, equals(2));
      expect(result.state.hasStatus(playerB, StatusEffects.burn), isTrue);
      expect(result.state.currentTurn, equals(playerB));
    });

    test('forwards combinationModifiers to the triggered combination\'s '
        'field effect', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);
      final windCall = Ability(
        id: 'wind_call',
        name: 'Chamado do Vento',
        baseElements: [Elements.fire, Elements.wind],
      );

      final result = abilityEngine.useAbility(
        state,
        playerA,
        windCall,
        combinationModifiers: [CombinationModifiers.propagation],
      );

      final triggered = result.state.activeFieldEffects
          .firstWhere((e) => e.id == 'ignited_storm');
      expect(triggered.area, equals(3));
    });
  });
}
