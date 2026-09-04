import 'package:battle_engine/battle_engine.dart';
import 'package:test/test.dart';

void main() {
  const playerA = Combatant(id: 'a', name: 'Ana');
  const playerB = Combatant(id: 'b', name: 'Beto');

  group('BattleState.start', () {
    test('sets playerA as the current turn', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);
      expect(state.currentTurn, equals(playerA));
    });

    test('starts with no active field effects', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);
      expect(state.activeFieldEffects, isEmpty);
    });
  });

  group('BattleState validation', () {
    test('throws if playerA and playerB are the same combatant', () {
      expect(
        () => BattleState(
          playerA: playerA,
          playerB: const Combatant(id: 'a', name: 'Outro nome'),
          currentTurn: playerA,
        ),
        throwsArgumentError,
      );
    });

    test('throws if currentTurn is neither playerA nor playerB', () {
      const stranger = Combatant(id: 'c', name: 'Carla');
      expect(
        () => BattleState(
          playerA: playerA,
          playerB: playerB,
          currentTurn: stranger,
        ),
        throwsArgumentError,
      );
    });
  });

  group('BattleState.copyWith', () {
    test('changes currentTurn without affecting other fields', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);
      final next = state.copyWith(currentTurn: playerB);

      expect(next.currentTurn, equals(playerB));
      expect(next.playerA, equals(playerA));
      expect(next.playerB, equals(playerB));
      expect(state.currentTurn, equals(playerA)); // original unchanged
    });
  });

  group('BattleState.withFieldEffect', () {
    test('appends an effect without mutating the original state', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);
      final effect = defaultCombinationBook
          .resolve([Elements.fire, Elements.wind])!
          .result;

      final next = state.withFieldEffect(effect);

      expect(next.activeFieldEffects, equals([effect]));
      expect(state.activeFieldEffects, isEmpty);
    });

    test('active field effects list is unmodifiable', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);
      expect(
        () => state.activeFieldEffects.add(
          defaultCombinationBook
              .resolve([Elements.fire, Elements.wind])!
              .result,
        ),
        throwsUnsupportedError,
      );
    });
  });

  group('BattleState.opponentOf', () {
    test('returns playerB when given playerA', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);
      expect(state.opponentOf(playerA), equals(playerB));
    });

    test('returns playerA when given playerB', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);
      expect(state.opponentOf(playerB), equals(playerA));
    });

    test('throws for a combatant outside the battle', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);
      const stranger = Combatant(id: 'c', name: 'Carla');
      expect(() => state.opponentOf(stranger), throwsArgumentError);
    });
  });

  group('BattleState statuses', () {
    test('both combatants start with no active statuses', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);
      expect(state.statusesOf(playerA), isEmpty);
      expect(state.statusesOf(playerB), isEmpty);
    });

    test('withStatusApplied only affects the target combatant', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);
      final burn = ActiveStatus(effect: StatusEffects.burn, turnsRemaining: 3);

      final next = state.withStatusApplied(playerA, burn);

      expect(next.statusesOf(playerA), equals([burn]));
      expect(next.statusesOf(playerB), isEmpty);
      expect(state.statusesOf(playerA), isEmpty); // original unchanged
    });

    test('hasStatus reflects applied statuses', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB)
          .withStatusApplied(
            playerA,
            ActiveStatus(effect: StatusEffects.shield),
          );

      expect(state.hasStatus(playerA, StatusEffects.shield), isTrue);
      expect(state.hasStatus(playerA, StatusEffects.burn), isFalse);
      expect(state.hasStatus(playerB, StatusEffects.shield), isFalse);
    });

    test('withStatusRemoved removes only the matching effect', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB)
          .withStatusApplied(
            playerA,
            ActiveStatus(effect: StatusEffects.burn, turnsRemaining: 2),
          )
          .withStatusApplied(
            playerA,
            ActiveStatus(effect: StatusEffects.shield),
          );

      final next = state.withStatusRemoved(playerA, StatusEffects.burn);

      expect(next.hasStatus(playerA, StatusEffects.burn), isFalse);
      expect(next.hasStatus(playerA, StatusEffects.shield), isTrue);
    });

    test('withStatusesTicked decrements duration and drops expired '
        'statuses, but leaves permanent ones untouched', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB)
          .withStatusApplied(
            playerA,
            ActiveStatus(effect: StatusEffects.burn, turnsRemaining: 1),
          )
          .withStatusApplied(
            playerA,
            ActiveStatus(effect: StatusEffects.shield),
          )
          .withStatusApplied(
            playerB,
            ActiveStatus(effect: StatusEffects.poison, turnsRemaining: 2),
          );

      final next = state.withStatusesTicked();

      expect(next.hasStatus(playerA, StatusEffects.burn), isFalse);
      expect(next.hasStatus(playerA, StatusEffects.shield), isTrue);
      expect(
        next.statusesOf(playerB).single.turnsRemaining,
        equals(1),
      );
    });

    test('withStatusApplied throws for a combatant outside the battle', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);
      const stranger = Combatant(id: 'c', name: 'Carla');
      expect(
        () => state.withStatusApplied(
          stranger,
          ActiveStatus(effect: StatusEffects.burn, turnsRemaining: 1),
        ),
        throwsArgumentError,
      );
    });
  });

  group('BattleState HP', () {
    test('start defaults both players to 100/100 HP', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);
      expect(state.hpOf(playerA).max, equals(100));
      expect(state.hpOf(playerA).current, equals(100));
      expect(state.hpOf(playerB).max, equals(100));
      expect(state.hpOf(playerB).current, equals(100));
    });

    test('start accepts different max HP per player', () {
      final state = BattleState.start(
        playerA: playerA,
        playerB: playerB,
        playerAMaxHp: 120,
        playerBMaxHp: 80,
      );
      expect(state.hpOf(playerA).max, equals(120));
      expect(state.hpOf(playerB).max, equals(80));
    });

    test('start sets winner to null', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);
      expect(state.winner, isNull);
    });

    test('hpOf throws for a combatant outside the battle', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);
      const stranger = Combatant(id: 'c', name: 'Carla');
      expect(() => state.hpOf(stranger), throwsArgumentError);
    });

    test('withDamage reduces only the target\'s current HP', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);
      final next = state.withDamage(playerB, 30);

      expect(next.hpOf(playerB).current, equals(70));
      expect(next.hpOf(playerA).current, equals(100));
      expect(state.hpOf(playerB).current, equals(100)); // original unchanged
    });

    test('withDamage sets the opponent as winner when it defeats the '
        'target', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);
      final next = state.withDamage(playerB, 100);

      expect(next.hpOf(playerB).isDefeated, isTrue);
      expect(next.winner, equals(playerA));
    });

    test('withDamage does not overwrite an existing winner', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB)
          .withDamage(playerB, 100); // playerA already won
      final next = state.withDamage(playerA, 100); // playerA also drops to 0

      expect(next.hpOf(playerA).isDefeated, isTrue);
      expect(next.winner, equals(playerA)); // unchanged, first winner sticks
    });

    test('withMaxHpIncreased raises both max and current for the target '
        'only', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);
      final next = state.withMaxHpIncreased(playerA, 20);

      expect(next.hpOf(playerA).max, equals(120));
      expect(next.hpOf(playerA).current, equals(120));
      expect(next.hpOf(playerB).max, equals(100));
    });

    test('copyWith preserves hp and winner when not specified', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB)
          .withDamage(playerB, 30);
      final next = state.copyWith(currentTurn: playerB);

      expect(next.hpOf(playerB).current, equals(70));
      expect(next.winner, equals(state.winner));
    });
  });
}
