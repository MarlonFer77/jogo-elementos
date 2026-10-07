import 'package:battle_engine/battle_engine.dart';
import 'package:test/test.dart';

void main() {
  const a = Combatant(id: 'a', name: 'A'), b = Combatant(id: 'b', name: 'B');
  final engine = TurnEngine(defaultCombinationBook);
  BattleState start() => BattleState.start(playerA: a, playerB: b);
  BattleState afflict(BattleState s, Combatant who, StatusEffect effect) =>
      s.withStatusApplied(
        who,
        ActiveStatus(
          effect: effect,
          turnsRemaining: 3,
          damagePerTick:
              effect == StatusEffects.burn || effect == StatusEffects.poison
              ? 2
              : 0,
        ),
      );
  for (final (element, status) in [
    (Elements.water, StatusEffects.burn),
    (Elements.nature, StatusEffects.poison),
  ]) {
    TurnAction action() => TurnAction(actor: a, elements: [element]);
    test(
      '${element.id} cleanses before lethal tick; trades damage, keeps AP/turn',
      () {
        final state = afflict(start().withDamage(a, 99), a, status);
        final next = engine.playTurn(state, action()).state;
        expect(next.hpOf(a).current, 1);
        expect(next.hpOf(b).current, 97);
        expect(next.hasStatus(a, status), false);
        expect(next.apOf(a).current, 1);
        expect(next.currentTurn, b);
        expect(next.winner, isNull);
        expect(state.hasStatus(a, status), true);
        expect(engine.playTurn(start(), action()).state.hpOf(b).current, 95);
        final ability = AbilityEngine(engine).useAbility(
          state,
          a,
          Ability(id: 'basic', name: 'Básico', baseElements: [element]),
        );
        expect(ability.feedback, contains('recover_${status.id}'));
      },
    );
    test('${element.id} respects defenses, slow, silence and freeze', () {
      final state = afflict(
        afflict(afflict(start(), a, status), a, StatusEffects.slow),
        a,
        StatusEffects.silence,
      );
      final shielded = engine
          .playTurn(afflict(state, b, StatusEffects.shield), action())
          .state;
      expect(shielded.hpOf(b).current, 100);
      expect(shielded.hasStatus(a, status), false);
      expect(shielded.apOf(a).current, 0);
      final guarded = engine
          .playTurn(afflict(state, b, StatusEffects.guard), action())
          .state;
      expect(guarded.hpOf(b).current, 98);
      final frozen = afflict(state, a, StatusEffects.freeze);
      expect(() => engine.playTurn(frozen, action()), throwsStateError);
      expect(frozen.hasStatus(a, status), true);
    });
  }
  test('recovery removes only its own status, never triggers from a combo', () {
    final state = afflict(
      afflict(start(), a, StatusEffects.burn),
      a,
      StatusEffects.poison,
    );
    final next = engine
        .playTurn(state, TurnAction(actor: a, elements: [Elements.water]))
        .state;
    expect(next.hasStatus(a, StatusEffects.poison), true);
    expect(next.hpOf(a).current, 98);
    expect(
      TurnEngine.basicRecoveryStatus(
        state,
        TurnAction(actor: a, elements: [Elements.water, Elements.wind]),
      ),
      isNull,
    );
    expect(
      () => engine.playTurn(
        state,
        TurnAction(actor: b, elements: [Elements.water]),
      ),
      throwsStateError,
    );
  });
}
