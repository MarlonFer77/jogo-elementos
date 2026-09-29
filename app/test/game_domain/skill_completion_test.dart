import 'package:app/game_domain/training_match.dart';
import 'package:app/game_domain/skill_feedback.dart';
import 'package:battle_engine/battle_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'saved precision build previews and plays the same damage and feedback',
    () {
      final match = TrainingMatch(
        initialApA: const ApPool(max: 5, current: 4),
        initialProgressA: SkillProgress(
          defaultSkillTree,
          unlockedNodeIds: [
            'unlock_fire',
            'unlock_earth',
            'unstable_core_training',
            'fragment_strikes',
          ],
        ),
      );
      final preview = match.previewAction(['fire', 'earth']);
      expect(preview.opponentHpLoss, 18);
      expect(
        preview.effects,
        containsAll(['Concentração +25%', 'Fragmentação · 2 golpes']),
      );
      expect(match.turnsPlayed, 0);
      match.playElementIds(['fire', 'earth']);
      expect(match.playerBCurrentHp, 82);
      expect(match.lastAppliedStatusNames, containsAll(preview.effects));
    },
  );
  test('remote feedback tolerates older servers and ignores unknown codes', () {
    expect(skillFeedbackLabels(null), isEmpty);
    expect(skillFeedbackLabels(['focused', 'fragmented', 'unknown']), [
      'Concentração +25%',
      'Fragmentação · 2 golpes',
    ]);
  });
}
