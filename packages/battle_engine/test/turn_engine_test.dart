import 'package:battle_engine/battle_engine.dart';
import 'package:test/test.dart';

void main() {
  const playerA = Combatant(id: 'a', name: 'Ana');
  const playerB = Combatant(id: 'b', name: 'Beto');
  final engine = TurnEngine(defaultCombinationBook);

  group('TurnAction', () {
    test('throws if no elements are played', () {
      expect(
        () => TurnAction(actor: playerA, elements: const []),
        throwsArgumentError,
      );
    });
  });

  group('TurnEngine.playTurn', () {
    test('rejects an action from a combatant whose turn it is not', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);
      final action = TurnAction(actor: playerB, elements: [Elements.fire]);

      expect(() => engine.playTurn(state, action), throwsStateError);
    });

    test('passes the turn to the opponent after a valid action', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);
      final action = TurnAction(actor: playerA, elements: [Elements.fire]);

      final result = engine.playTurn(state, action);

      expect(result.state.currentTurn, equals(playerB));
    });

    test('a single played element never triggers a combination', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);
      final action = TurnAction(actor: playerA, elements: [Elements.fire]);

      final result = engine.playTurn(state, action);

      expect(result.triggeredCombination, isNull);
      expect(result.state.activeFieldEffects, isEmpty);
    });

    test('playing a known 2-element combination adds it to the field', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);
      final action = TurnAction(
        actor: playerA,
        elements: [Elements.fire, Elements.wind],
      );

      final result = engine.playTurn(state, action);

      expect(result.triggeredCombination?.resultId, equals('ignited_storm'));
      expect(result.state.activeFieldEffects, hasLength(1));
      expect(
        result.state.activeFieldEffects.first.id,
        equals('ignited_storm'),
      );
    });

    test('playing an unknown combination advances the turn without adding '
        'a field effect', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);
      final action = TurnAction(
        actor: playerA,
        elements: [Elements.ice, Elements.shadow],
      );

      final result = engine.playTurn(state, action);

      expect(result.triggeredCombination, isNull);
      expect(result.state.activeFieldEffects, isEmpty);
      expect(result.state.currentTurn, equals(playerB));
    });

    test('turns alternate across multiple plays', () {
      var state = BattleState.start(playerA: playerA, playerB: playerB);

      state = engine
          .playTurn(state, TurnAction(actor: playerA, elements: [Elements.fire]))
          .state;
      expect(state.currentTurn, equals(playerB));

      state = engine
          .playTurn(state, TurnAction(actor: playerB, elements: [Elements.water]))
          .state;
      expect(state.currentTurn, equals(playerA));
    });

    test('field effects accumulate across turns', () {
      var state = BattleState.start(playerA: playerA, playerB: playerB);

      state = engine
          .playTurn(
            state,
            TurnAction(
              actor: playerA,
              elements: [Elements.fire, Elements.wind],
            ),
          )
          .state;

      state = engine
          .playTurn(
            state,
            TurnAction(
              actor: playerB,
              elements: [Elements.water, Elements.lightning],
            ),
          )
          .state;

      expect(state.activeFieldEffects, hasLength(2));
    });

    test('applies combinationModifiers to a triggered combination\'s '
        'field effect before adding it to the field', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);
      final action = TurnAction(
        actor: playerA,
        elements: [Elements.fire, Elements.wind],
      );

      final result = engine.playTurn(
        state,
        action,
        combinationModifiers: [CombinationModifiers.propagation],
      );

      expect(result.state.activeFieldEffects.single.area, equals(3));
    });

    test('combinationModifiers apply in order', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);
      final action = TurnAction(
        actor: playerA,
        elements: [Elements.earth, Elements.fire, Elements.water],
      );

      final result = engine.playTurn(
        state,
        action,
        combinationModifiers: [
          CombinationModifiers.propagation,
          CombinationModifiers.propagation,
        ],
      );

      expect(result.state.activeFieldEffects.single.area, equals(5));
    });

    test('combinationModifiers are ignored when no combination triggers',
        () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);
      final action = TurnAction(actor: playerA, elements: [Elements.fire]);

      final result = engine.playTurn(
        state,
        action,
        combinationModifiers: [CombinationModifiers.propagation],
      );

      expect(result.state.activeFieldEffects, isEmpty);
    });

    test('with no combinationModifiers the combination result is '
        'unmodified', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);
      final action = TurnAction(
        actor: playerA,
        elements: [Elements.fire, Elements.wind],
      );

      final result = engine.playTurn(state, action);

      expect(result.state.activeFieldEffects.single.area, equals(1));
    });

    test('a known 2-element combination deals 20 damage to the opponent',
        () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);
      final action = TurnAction(
        actor: playerA,
        elements: [Elements.fire, Elements.wind],
      );

      final result = engine.playTurn(state, action);

      expect(result.state.hpOf(playerB).current, equals(80));
      expect(result.state.hpOf(playerA).current, equals(100));
    });

    test('the 3-element combination deals 35 damage', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);
      final action = TurnAction(
        actor: playerA,
        elements: [Elements.earth, Elements.fire, Elements.water],
      );

      final result = engine.playTurn(state, action);

      expect(result.state.hpOf(playerB).current, equals(65));
    });

    test('a single element or an unknown combination deals no damage', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);

      final afterSingle = engine
          .playTurn(
            state,
            TurnAction(actor: playerA, elements: [Elements.fire]),
          )
          .state;
      expect(afterSingle.hpOf(playerB).current, equals(100));

      final afterUnknown = engine
          .playTurn(
            afterSingle,
            TurnAction(
              actor: playerB,
              elements: [Elements.ice, Elements.shadow],
            ),
          )
          .state;
      expect(afterUnknown.hpOf(playerA).current, equals(100));
    });

    test('Shield blocks the next combo damage and is consumed', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB)
          .withStatusApplied(playerB, ActiveStatus(effect: StatusEffects.shield));
      final action = TurnAction(
        actor: playerA,
        elements: [Elements.fire, Elements.wind],
      );

      final result = engine.playTurn(state, action);

      expect(result.state.hpOf(playerB).current, equals(100));
      expect(result.state.hasStatus(playerB, StatusEffects.shield), isFalse);
    });

    test('Shield does not block a second hit after being consumed', () {
      var state = BattleState.start(playerA: playerA, playerB: playerB)
          .withStatusApplied(playerB, ActiveStatus(effect: StatusEffects.shield));

      state = engine
          .playTurn(
            state,
            TurnAction(actor: playerA, elements: [Elements.fire, Elements.wind]),
          )
          .state; // blocked, shield consumed
      state = engine
          .playTurn(
            state,
            TurnAction(actor: playerB, elements: [Elements.ice]),
          )
          .state; // no-op action, just passes the turn back
      state = engine
          .playTurn(
            state,
            TurnAction(actor: playerA, elements: [Elements.fire, Elements.wind]),
          )
          .state; // not blocked this time

      expect(state.hpOf(playerB).current, equals(80));
    });

    test('a status with damagePerTick damages its owner at the end of '
        'every playTurn call, including the tick that expires it', () {
      var state = BattleState.start(playerA: playerA, playerB: playerB)
          .withStatusApplied(
            playerB,
            ActiveStatus(
              effect: StatusEffects.burn,
              turnsRemaining: 2,
              damagePerTick: 8,
            ),
          );

      state = engine
          .playTurn(state, TurnAction(actor: playerA, elements: [Elements.fire]))
          .state;
      expect(state.hpOf(playerB).current, equals(92)); // first tick

      state = engine
          .playTurn(state, TurnAction(actor: playerB, elements: [Elements.water]))
          .state;
      expect(state.hpOf(playerB).current, equals(84)); // second tick, expires
      expect(state.hasStatus(playerB, StatusEffects.burn), isFalse);
    });

    test('combo damage can set a winner', () {
      final state = BattleState.start(
        playerA: playerA,
        playerB: playerB,
        playerBMaxHp: 15,
      );
      final result = engine.playTurn(
        state,
        TurnAction(actor: playerA, elements: [Elements.fire, Elements.wind]),
      );

      expect(result.state.hpOf(playerB).isDefeated, isTrue);
      expect(result.state.winner, equals(playerA));
    });

    test('DOT damage alone can set a winner', () {
      var state = BattleState.start(
        playerA: playerA,
        playerB: playerB,
        playerBMaxHp: 5,
      ).withStatusApplied(
        playerB,
        ActiveStatus(effect: StatusEffects.burn, turnsRemaining: 1, damagePerTick: 8),
      );

      final result = engine.playTurn(
        state,
        TurnAction(actor: playerA, elements: [Elements.ice]),
      );

      expect(result.state.winner, equals(playerA));
    });

    test('when DOT ticks would defeat both combatants in the same '
        'resolution, the actor wins the tie', () {
      // Both start lethal-low on HP, both carry a lethal DOT — the action
      // itself deals no combo damage (single element), so this isolates
      // the tie strictly to the DOT tick ordering.
      final state = BattleState.start(
        playerA: playerA,
        playerB: playerB,
        playerAMaxHp: 5,
        playerBMaxHp: 5,
      ).withStatusApplied(
        playerA,
        ActiveStatus(effect: StatusEffects.burn, turnsRemaining: 1, damagePerTick: 8),
      ).withStatusApplied(
        playerB,
        ActiveStatus(effect: StatusEffects.burn, turnsRemaining: 1, damagePerTick: 8),
      );

      final result = engine.playTurn(
        state,
        TurnAction(actor: playerA, elements: [Elements.ice]),
      );

      expect(result.state.hpOf(playerA).isDefeated, isTrue);
      expect(result.state.hpOf(playerB).isDefeated, isTrue);
      expect(result.state.winner, equals(playerA));
    });

    test('playTurn throws once the battle already has a winner', () {
      final state = BattleState.start(
        playerA: playerA,
        playerB: playerB,
        playerBMaxHp: 1,
      );
      final finished = engine
          .playTurn(
            state,
            TurnAction(actor: playerA, elements: [Elements.fire, Elements.wind]),
          )
          .state;
      expect(finished.winner, equals(playerA));

      expect(
        () => engine.playTurn(
          finished,
          TurnAction(actor: playerB, elements: [Elements.water]),
        ),
        throwsStateError,
      );
    });
  });
}
