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
      final state = BattleState.start(
        playerA: playerA,
        playerB: playerB,
        ap: {playerA: const ApPool(max: 5, current: 3)},
      );
      final action = TurnAction(
        actor: playerA,
        elements: [Elements.fire, Elements.wind],
      );

      final result = engine.playTurn(state, action);

      expect(result.triggeredCombination?.resultId, equals('ignited_storm'));
      expect(result.state.activeFieldEffects, hasLength(1));
      expect(result.state.activeFieldEffects.first.id, equals('ignited_storm'));
    });

    test('playing an unknown combination advances the turn without adding '
        'a field effect', () {
      final state = BattleState.start(
        playerA: playerA,
        playerB: playerB,
        ap: {playerA: const ApPool(max: 5, current: 3)},
      );
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
          .playTurn(
            state,
            TurnAction(actor: playerA, elements: [Elements.fire]),
          )
          .state;
      expect(state.currentTurn, equals(playerB));

      state = engine
          .playTurn(
            state,
            TurnAction(actor: playerB, elements: [Elements.water]),
          )
          .state;
      expect(state.currentTurn, equals(playerA));
    });

    test('field effects accumulate across turns', () {
      var state = BattleState.start(
        playerA: playerA,
        playerB: playerB,
        ap: {
          playerA: const ApPool(max: 5, current: 3),
          playerB: const ApPool(max: 5, current: 3),
        },
      );

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
      final state = BattleState.start(
        playerA: playerA,
        playerB: playerB,
        ap: {playerA: const ApPool(max: 5, current: 3)},
      );
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
      final state = BattleState.start(
        playerA: playerA,
        playerB: playerB,
        ap: {playerA: const ApPool(max: 5, current: 5)},
      );
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

    test('combinationModifiers are ignored when no combination triggers', () {
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
      final state = BattleState.start(
        playerA: playerA,
        playerB: playerB,
        ap: {playerA: const ApPool(max: 5, current: 3)},
      );
      final action = TurnAction(
        actor: playerA,
        elements: [Elements.fire, Elements.wind],
      );

      final result = engine.playTurn(state, action);

      expect(result.state.activeFieldEffects.single.area, equals(1));
    });

    test('Tempestade deals 14 direct damage to the opponent', () {
      final state = BattleState.start(
        playerA: playerA,
        playerB: playerB,
        ap: {playerA: const ApPool(max: 5, current: 3)},
      );
      final action = TurnAction(
        actor: playerA,
        elements: [Elements.fire, Elements.wind],
      );

      final result = engine.playTurn(state, action);

      expect(result.state.hpOf(playerB).current, equals(86));
      expect(result.state.hpOf(playerA).current, equals(100));
    });

    test('the 3-element combination deals 35 damage', () {
      final state = BattleState.start(
        playerA: playerA,
        playerB: playerB,
        ap: {playerA: const ApPool(max: 5, current: 5)},
      );
      final action = TurnAction(
        actor: playerA,
        elements: [Elements.earth, Elements.fire, Elements.water],
      );

      final result = engine.playTurn(state, action);

      expect(result.state.hpOf(playerB).current, equals(65));
    });

    test('a single element deals 5 basic damage; an unknown combination '
        'deals none', () {
      final state = BattleState.start(
        playerA: playerA,
        playerB: playerB,
        ap: {playerB: const ApPool(max: 5, current: 3)},
      );

      final afterSingle = engine
          .playTurn(
            state,
            TurnAction(actor: playerA, elements: [Elements.fire]),
          )
          .state;
      expect(afterSingle.hpOf(playerB).current, equals(95));

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
      final state = BattleState.start(
        playerA: playerA,
        playerB: playerB,
        ap: {playerA: const ApPool(max: 5, current: 3)},
      ).withStatusApplied(playerB, ActiveStatus(effect: StatusEffects.shield));
      final action = TurnAction(
        actor: playerA,
        elements: [Elements.fire, Elements.wind],
      );

      final result = engine.playTurn(state, action);

      expect(result.state.hpOf(playerB).current, equals(100));
      expect(result.state.hasStatus(playerB, StatusEffects.shield), isFalse);
    });

    test('Shield does not block a second hit after being consumed', () {
      var state = BattleState.start(
        playerA: playerA,
        playerB: playerB,
        ap: {playerA: const ApPool(max: 5, current: 4)},
      ).withStatusApplied(playerB, ActiveStatus(effect: StatusEffects.shield));

      state = engine
          .playTurn(
            state,
            TurnAction(
              actor: playerA,
              elements: [Elements.fire, Elements.wind],
            ),
          )
          .state; // blocked, shield consumed (4 seeded + 1 regen - 3 spent = 2 left)
      state = engine
          .playTurn(state, TurnAction(actor: playerB, elements: [Elements.ice]))
          .state; // no-op action, just passes the turn back
      state = engine
          .playTurn(
            state,
            TurnAction(
              actor: playerA,
              elements: [Elements.fire, Elements.wind],
            ),
          )
          .state; // 2 + 1 regen = 3, affordable again — not blocked this time

      expect(state.hpOf(playerB).current, equals(86));
    });

    test('a status with damagePerTick damages its owner at the end of '
        'every playTurn call, including the tick that expires it — on top '
        'of the actor\'s own basic damage', () {
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
          .playTurn(
            state,
            TurnAction(actor: playerA, elements: [Elements.fire]),
          )
          .state;
      // playerB: 100 - 5 (a's basic damage) - 8 (first DOT tick) = 87
      expect(state.hpOf(playerB).current, equals(87));

      state = engine
          .playTurn(
            state,
            TurnAction(actor: playerB, elements: [Elements.water]),
          )
          .state;
      // playerA: 100 - 5 (b's basic damage) = 95
      // playerB: 87 - 8 (second DOT tick, expires) = 79
      expect(state.hpOf(playerA).current, equals(95));
      expect(state.hpOf(playerB).current, equals(79));
      expect(state.hasStatus(playerB, StatusEffects.burn), isFalse);
    });

    test('combo damage can set a winner', () {
      final state = BattleState.start(
        playerA: playerA,
        playerB: playerB,
        playerBMaxHp: 14,
        ap: {playerA: const ApPool(max: 5, current: 3)},
      );
      final result = engine.playTurn(
        state,
        TurnAction(actor: playerA, elements: [Elements.fire, Elements.wind]),
      );

      expect(result.state.hpOf(playerB).isDefeated, isTrue);
      expect(result.state.winner, equals(playerA));
    });

    test('DOT damage alone can set a winner', () {
      // playerBMaxHp is 10, not 5: a's basic damage (5) alone must not be
      // enough to defeat them — only the DOT tick (8) on top of it should.
      var state =
          BattleState.start(
            playerA: playerA,
            playerB: playerB,
            playerBMaxHp: 10,
          ).withStatusApplied(
            playerB,
            ActiveStatus(
              effect: StatusEffects.burn,
              turnsRemaining: 1,
              damagePerTick: 8,
            ),
          );

      final result = engine.playTurn(
        state,
        TurnAction(actor: playerA, elements: [Elements.ice]),
      );

      expect(result.state.winner, equals(playerA));
    });

    test('when DOT ticks would defeat both combatants in the same '
        'resolution, the actor wins the tie', () {
      // Both start at 8 HP (not 5): a's basic damage (5) to b alone must
      // not decide the winner ahead of the DOT tick this test is about —
      // it isolates the tie strictly to DOT tick ordering.
      final state =
          BattleState.start(
                playerA: playerA,
                playerB: playerB,
                playerAMaxHp: 8,
                playerBMaxHp: 8,
              )
              .withStatusApplied(
                playerA,
                ActiveStatus(
                  effect: StatusEffects.burn,
                  turnsRemaining: 1,
                  damagePerTick: 8,
                ),
              )
              .withStatusApplied(
                playerB,
                ActiveStatus(
                  effect: StatusEffects.burn,
                  turnsRemaining: 1,
                  damagePerTick: 8,
                ),
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
        ap: {playerA: const ApPool(max: 5, current: 3)},
      );
      final finished = engine
          .playTurn(
            state,
            TurnAction(
              actor: playerA,
              elements: [Elements.fire, Elements.wind],
            ),
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

    test('ends the match after enough basic (single-element) hits, with '
        'no AP involved', () {
      // 5 basic damage per hit — 20 hits defeat 100 HP. Actor A acts
      // first each round, so their 20th hit lands before B's 20th.
      var state = BattleState.start(playerA: playerA, playerB: playerB);
      for (var i = 0; i < 19; i++) {
        state = engine
            .playTurn(
              state,
              TurnAction(actor: playerA, elements: [Elements.fire]),
            )
            .state;
        state = engine
            .playTurn(
              state,
              TurnAction(actor: playerB, elements: [Elements.ice]),
            )
            .state;
      }
      final result = engine.playTurn(
        state,
        TurnAction(actor: playerA, elements: [Elements.fire]),
      );

      expect(result.state.hpOf(playerB).isDefeated, isTrue);
      expect(result.state.winner, equals(playerA));
    });
  });

  group('AP cost for combining elements', () {
    test('regenerates 1 AP for the actor at the start of their turn', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);
      final action = TurnAction(actor: playerA, elements: [Elements.fire]);

      final result = engine.playTurn(state, action);

      expect(result.state.apOf(playerA).current, equals(1));
      expect(result.state.apOf(playerB).current, equals(0));
    });

    test('AP regeneration is clamped at max', () {
      final state = BattleState.start(
        playerA: playerA,
        playerB: playerB,
        ap: {playerA: const ApPool(max: 5, current: 5)},
      );
      final action = TurnAction(actor: playerA, elements: [Elements.fire]);

      final result = engine.playTurn(state, action);

      expect(result.state.apOf(playerA).current, equals(5));
    });

    test('rejects a 2-element combination without enough AP', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);
      final action = TurnAction(
        actor: playerA,
        elements: [Elements.fire, Elements.wind],
      );

      expect(() => engine.playTurn(state, action), throwsStateError);
    });

    test('rejects a 3-element combination that only affords a 2-element '
        'one', () {
      final state = BattleState.start(
        playerA: playerA,
        playerB: playerB,
        ap: {playerA: const ApPool(max: 5, current: 3)},
      );
      final action = TurnAction(
        actor: playerA,
        elements: [Elements.earth, Elements.fire, Elements.water],
      );

      expect(() => engine.playTurn(state, action), throwsStateError);
    });

    test('spends 3 AP on a successful 2-element combination', () {
      final state = BattleState.start(
        playerA: playerA,
        playerB: playerB,
        ap: {playerA: const ApPool(max: 5, current: 3)},
      );
      final action = TurnAction(
        actor: playerA,
        elements: [Elements.fire, Elements.wind],
      );

      final result = engine.playTurn(state, action);

      // seeded 3 + 1 regen = 4, minus 3 spent = 1
      expect(result.state.apOf(playerA).current, equals(1));
    });

    test('spends all 5 AP on a successful 3-element combination', () {
      final state = BattleState.start(
        playerA: playerA,
        playerB: playerB,
        ap: {playerA: const ApPool(max: 5, current: 5)},
      );
      final action = TurnAction(
        actor: playerA,
        elements: [Elements.earth, Elements.fire, Elements.water],
      );

      final result = engine.playTurn(state, action);

      expect(result.state.apOf(playerA).current, equals(0));
    });
  });
}
