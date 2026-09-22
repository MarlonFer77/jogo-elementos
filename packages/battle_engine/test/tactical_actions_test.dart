import 'package:battle_engine/battle_engine.dart';
import 'package:test/test.dart';

void main() {
  const a = Combatant(id: 'a', name: 'A');
  const b = Combatant(id: 'b', name: 'B');
  final engine = TurnEngine(defaultCombinationBook);
  BattleState start() => BattleState.start(
    playerA: a,
    playerB: b,
    ap: {
      a: const ApPool(max: 5, current: 4),
      b: const ApPool(max: 5, current: 4),
    },
  );
  BattleState attack(BattleState s, List<Element> elements) => engine
      .playTurn(s, TurnAction(actor: s.currentTurn, elements: elements))
      .state;
  BattleState defend(BattleState s) =>
      engine.playTurn(s, TurnAction.defend(actor: s.currentTurn)).state;

  for (final actor in [a, b]) {
    test(
      'defend costs an action, caps AP and halves one basic hit: ${actor.id}',
      () {
        final s = start().copyWith(currentTurn: actor);
        final guarded = defend(s);
        expect(s.apOf(actor).current, 4);
        expect(guarded.apOf(actor).current, 5);
        expect(guarded.currentTurn, s.opponentOf(actor));
        expect(guarded.hpOf(s.opponentOf(actor)).current, 100);
        expect(guarded.hasStatus(actor, StatusEffects.guard), isTrue);
        final hit = attack(guarded, [Elements.fire]);
        expect(
          hit.hpOf(actor).current,
          97,
        ); // round damage up; no immunity to basics.
        expect(hit.hasStatus(actor, StatusEffects.guard), isFalse);
      },
    );
  }
  test('defense expires even if opponent defends; it does not stack', () {
    final s = defend(defend(start()));
    expect(s.hasStatus(a, StatusEffects.guard), isFalse);
    expect(s.statusesOf(b).length, 1);
    final next = defend(s);
    expect(next.statusesOf(a).length, 1);
    expect(next.hasStatus(b, StatusEffects.guard), isFalse);
  });
  test('defense does not block DOT or prevent defeat', () {
    final s = start()
        .withDamage(a, 98)
        .withStatusApplied(
          a,
          ActiveStatus(
            effect: StatusEffects.burn,
            damagePerTick: 3,
            turnsRemaining: 2,
          ),
        );
    final next = defend(s);
    expect(next.winner, b);
    expect(next.hasStatus(a, StatusEffects.guard), isFalse);
    expect(() => defend(next), throwsStateError);
  });
  test(
    'storm deals 14 now, then two ticks of 3, including while defending',
    () {
      var s = attack(start(), [Elements.fire, Elements.wind]);
      expect(s.hpOf(b).current, 86);
      expect(s.statusesOf(b).single.turnsRemaining, 2);
      s = defend(s);
      expect(s.hpOf(b).current, 83);
      s = defend(s);
      expect(s.hpOf(b).current, 80);
      expect(s.hasStatus(b, StatusEffects.burn), isFalse);
    },
  );
  test('shield blocks storm burn; guard only reduces direct damage', () {
    final shield = attack(
      start().withStatusApplied(b, ActiveStatus(effect: StatusEffects.shield)),
      [Elements.fire, Elements.wind],
    );
    expect(shield.hpOf(b).current, 100);
    expect(shield.statusesOf(b), isEmpty);
    final guarded = attack(
      start().withStatusApplied(
        b,
        ActiveStatus(effect: StatusEffects.guard, turnsRemaining: 1),
      ),
      [Elements.fire, Elements.wind],
    );
    expect(guarded.hpOf(b).current, 93);
    expect(guarded.hasStatus(b, StatusEffects.burn), isTrue);
  });
  test(
    'electric field trades damage for protection without changing AP cost',
    () {
      var s = attack(start(), [Elements.water, Elements.lightning]);
      expect(s.hpOf(b).current, 88);
      expect(s.apOf(a).current, 2);
      expect(s.hasStatus(a, StatusEffects.guard), isTrue);
      s = attack(s, [Elements.fire, Elements.wind]);
      expect(s.hpOf(a).current, 93);
      expect(s.hasStatus(a, StatusEffects.guard), isFalse);
    },
  );
  test('duplicate and oversized attack selections are rejected', () {
    expect(
      () => TurnAction(actor: a, elements: [Elements.fire, Elements.fire]),
      throwsArgumentError,
    );
    expect(
      () => TurnAction(actor: a, elements: Elements.all.take(4)),
      throwsArgumentError,
    );
    expect(
      () => engine.playTurn(start(), TurnAction.defend(actor: b)),
      throwsStateError,
    );
  });
  test('combo and skill burn do not stack; the stronger burn wins', () {
    final s = AbilityEngine(engine)
        .useAbility(
          start(),
          a,
          Ability(
            id: 'storm',
            name: 'Storm',
            baseElements: [Elements.fire, Elements.wind],
            mutations: [Mutations.combustion],
          ),
        )
        .state;
    expect(
      s.statusesOf(b).where((s) => s.effect == StatusEffects.burn).length,
      1,
    );
    expect(s.statusesOf(b).single.damagePerTick, 8);
  });

  test(
    'glacial prison freezes the opponent until they spend an action thawing',
    () {
      final frozen = attack(start(), [Elements.water, Elements.ice]);
      expect(frozen.hpOf(b).current, 90);
      expect(frozen.currentTurn, b);
      expect(frozen.hasStatus(b, StatusEffects.freeze), isTrue);
      expect(
        () => attack(frozen, [Elements.fire]),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('frozen'),
          ),
        ),
      );

      final thawed = engine.playTurn(frozen, TurnAction.thaw(actor: b)).state;
      expect(thawed.currentTurn, a);
      expect(thawed.hasStatus(b, StatusEffects.freeze), isFalse);
      expect(thawed.apOf(b).current, 4, reason: 'thaw never regenerates AP');
    },
  );

  test('thaw is rejected unless the current actor is frozen', () {
    expect(
      () => engine.playTurn(start(), TurnAction.thaw(actor: a)),
      throwsStateError,
    );
  });

  test('shield blocks both glacial prison damage and freeze', () {
    final shielded = start().withStatusApplied(
      b,
      ActiveStatus(effect: StatusEffects.shield),
    );
    final next = attack(shielded, [Elements.water, Elements.ice]);
    expect(next.hpOf(b).current, 100);
    expect(next.hasStatus(b, StatusEffects.freeze), isFalse);
  });
}
