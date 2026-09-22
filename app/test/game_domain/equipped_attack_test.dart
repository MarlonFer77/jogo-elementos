import 'package:app/game_domain/training_match.dart';
import 'package:battle_engine/battle_engine.dart';
import 'package:flutter_test/flutter_test.dart';

TrainingMatch matchWithAttack({
  int ap = 2,
  bool equipped = true,
  bool wind = true,
}) => TrainingMatch(
  initialApA: ApPool(max: 5, current: ap),
  initialProgressA: SkillProgress(
    defaultSkillTree,
    unlockedNodeIds: ['unlock_fire', if (wind) 'unlock_wind'],
  ),
  initialProgressB: SkillProgress(
    defaultSkillTree,
    unlockedNodeIds: ['unlock_fire'],
  ),
  initialLoadoutA: AttackLoadout(
    unlockedCombinationIds: {'ignited_storm'},
    equippedCombinationIds: equipped ? ['ignited_storm'] : [],
  ),
);

void main() {
  test(
    'equipped attack uses regeneration, existing damage and turn resolution',
    () {
      final match = matchWithAttack();
      expect(match.availableApForAction, 3);
      expect(match.attackUnavailableReason('ignited_storm'), isNull);
      match.playEquippedAttack('ignited_storm');
      expect(match.playerAAp, 0);
      expect(match.playerBCurrentHp, 86);
      expect(match.isPlayerATurn, false);
      expect(match.equippedAttacksForCurrentPlayer, isEmpty);
      expect(match.cumulativeTurnsPlayedA, 1);
      expect(
        match
            .startNewBattleKeepingProgress()
            .equippedAttacksForCurrentPlayer
            .single
            .id,
        'ignited_storm',
      );
    },
  );

  test('invalid requests do not consume AP, damage, progress or turn', () {
    for (final entry in [
      (matchWithAttack(ap: 1), 'ignited_storm', 'Falta 1 AP.'),
      (
        matchWithAttack(equipped: false),
        'ignited_storm',
        'Ataque não equipado.',
      ),
      (
        matchWithAttack(wind: false),
        'ignited_storm',
        'Elemento necessário bloqueado.',
      ),
      (matchWithAttack(), 'unknown', 'Ataque inexistente.'),
    ]) {
      final (match, id, reason) = entry;
      final ap = match.playerAAp;
      expect(match.attackUnavailableReason(id), reason);
      expect(() => match.playEquippedAttack(id), throwsStateError);
      expect(match.playerAAp, ap);
      expect(match.playerBCurrentHp, 100);
      expect(match.turnsPlayed, 0);
      expect(match.discoveredCount, 0);
    }
  });

  test('a defeated player cannot act', () {
    final match = matchWithAttack();
    for (var i = 0; i < 19; i++) {
      match.playElementIds(['fire']);
      match.playElementIds(['fire']);
    }
    match.playElementIds(['fire']);
    expect(
      match.attackUnavailableReason('ignited_storm'),
      'A partida terminou.',
    );
    expect(() => match.playEquippedAttack('ignited_storm'), throwsStateError);
  });
}
