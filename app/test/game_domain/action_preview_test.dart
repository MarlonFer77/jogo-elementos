import 'package:app/game_domain/training_match.dart';
import 'package:battle_engine/battle_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TrainingMatch match() => TrainingMatch(
    initialApA: const ApPool(max: 5, current: 3),
    initialProgressA: SkillProgress(
      defaultSkillTree,
      unlockedNodeIds: [
        'unlock_fire',
        'unlock_wind',
        'ember_mastery',
        'guard_training',
      ],
    ),
  );
  test('preview does not discover, advance, spend AP or award progress', () {
    final m = match();
    final beforeAp = m.availableApForAction;
    final preview = m.previewAction(['fire', 'wind']);
    expect(m.turnsPlayed, 0);
    expect(m.discoveredCount, 0);
    expect(m.unlockedAttackIdsForPlayerA, isEmpty);
    expect(m.availableApForAction, beforeAp);
    expect(m.playerBCurrentHp, 100);
    m.playElementIds(['fire', 'wind']);
    expect(100 - m.playerBCurrentHp, preview.opponentHpLoss);
  });
  test(
    'defense is previewed exactly and does not trigger offensive mutations',
    () {
      final m = match();
      final preview = m.previewAction([], defending: true);
      expect(preview.apCost, 0);
      expect(preview.apAfter, 4);
      expect(preview.opponentHpLoss, 0);
      m.defend();
      expect(m.turnsPlayed, 1);
      expect(m.cumulativeTurnsPlayedA, 1);
      expect(m.playerBCurrentHp, 100);
      expect(m.lastAppliedStatusNames, ['Defesa']);
      expect(m.discoveredCount, 0);
      expect(m.activeFieldEffectNames, isEmpty);
    },
  );
  test('preview rejects unavailable attacks and elements', () {
    final m = match();
    expect(() => m.previewAction(['ghost']), throwsStateError);
    expect(() => m.previewAction([], attackId: 'ghost'), throwsStateError);
    expect(m.turnsPlayed, 0);
  });
}
