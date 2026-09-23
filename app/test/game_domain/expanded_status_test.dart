import 'package:app/game_domain/training_match.dart';
import 'package:battle_engine/battle_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TrainingMatch setup(List<String> recipe) {
    final progress = SkillProgress(
      defaultSkillTree,
      unlockedNodeIds: ElementUnlocks.all.map((e) => e.id).toList(),
    );
    final match = TrainingMatch(
      initialProgressA: progress,
      initialProgressB: progress,
      initialApA: const ApPool(max: 5, current: 3),
      initialApB: const ApPool(max: 5, current: 3),
    );
    match.setEquippedElements(recipe);
    match.playElementIds(recipe);
    match.setEquippedElements(['fire', 'wind']);
    return match;
  }

  test('silence explains unavailable combos and preserves state', () {
    final match = setup(['wind', 'shadow']);
    expect(match.currentPlayerIsSilenced, true);
    expect(match.currentActionWarning, contains('Silêncio'));
    expect(() => match.previewAction(['fire', 'wind']), throwsStateError);
    expect(match.turnsPlayed, 1);
    match.playElementIds(['fire']);
    expect(match.turnsPlayed, 2);
  });
  test('slow preview and execution agree without AP regeneration', () {
    final match = setup(['earth', 'water']);
    expect(match.availableApForAction, 3);
    final preview = match.previewAction(['fire', 'wind']);
    expect(preview.regeneratesAp, false);
    expect(preview.apAfter, 0);
    match.playElementIds(['fire', 'wind']);
    expect(match.playerBAp, preview.apAfter);
  });
  test('shock preview and displayed cost agree with execution', () {
    final match = setup(['lightning', 'wind']);
    final preview = match.previewAction(['fire', 'wind']);
    expect(match.attackApCost(2), 4);
    expect(preview.apCost, 4);
    match.playElementIds(['fire', 'wind']);
    expect(match.playerBAp, preview.apAfter);
    expect(match.unlockedAttackIdsForPlayerA, contains('static_gale'));
  });
}
