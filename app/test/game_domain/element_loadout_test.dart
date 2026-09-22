import 'package:app/game_domain/training_match.dart';
import 'package:app/game_domain/training_progress_store.dart';
import 'package:battle_engine/battle_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

SkillProgress unlocked() => SkillProgress(
  defaultSkillTree,
  unlockedNodeIds: ElementUnlocks.all.map((e) => e.id).toList(),
);

void main() {
  test(
    'old saves receive at most four elements; invalid saved IDs are filtered',
    () {
      final match = TrainingMatch(initialProgressA: unlocked());
      expect(match.equippedElementIdsForCurrentPlayer, [
        'fire',
        'water',
        'wind',
        'ice',
      ]);
      final restored = TrainingMatch(
        initialProgressA: unlocked(),
        initialEquippedElementsA: [
          'poison',
          'poison',
          'missing',
          'earth',
          'fire',
          'ice',
          'water',
        ],
      );
      expect(restored.equippedElementIdsForCurrentPlayer, [
        'poison',
        'earth',
        'fire',
        'ice',
      ]);
      expect(
        () => restored.equippedElementIdsForCurrentPlayer.add('water'),
        throwsUnsupportedError,
      );
    },
  );

  test(
    'rejects fifth slot, duplicates, empty and locked elements atomically',
    () {
      final match = TrainingMatch(initialProgressA: unlocked());
      final before = match.equippedElementIdsForCurrentPlayer;
      for (final ids in <List<String>>[
        ['fire', 'water', 'wind', 'ice', 'earth'],
        ['fire', 'fire'],
        [],
        ['missing'],
      ]) {
        expect(() => match.setEquippedElements(ids), throwsArgumentError);
        expect(match.equippedElementIdsForCurrentPlayer, before);
      }
      expect(
        () => TrainingMatch().setEquippedElements(['fire']),
        throwsArgumentError,
      );
    },
  );

  test('unequipped basic and combination cannot consume a turn', () {
    final match = TrainingMatch(
      initialProgressA: unlocked(),
      initialApA: const ApPool(max: 5, current: 5),
    );
    expect(() => match.playElementIds(['earth']), throwsStateError);
    expect(
      () => match.playElementIds(['earth', 'fire', 'water']),
      throwsStateError,
    );
    expect(match.turnsPlayed, 0);
    expect(match.playerAAp, 5);
    match.setEquippedElements(['earth', 'fire', 'water']);
    match.playElementIds(['earth', 'fire', 'water']);
    expect(match.playerBCurrentHp, 65);
  });

  test('learned abilities are independent of the four basic slots', () {
    final match = TrainingMatch(
      initialProgressA: unlocked(),
      initialEquippedElementsA: ['ice', 'earth'],
      initialApA: const ApPool(max: 5, current: 2),
      initialLoadoutA: AttackLoadout(
        unlockedCombinationIds: {'ignited_storm'},
        equippedCombinationIds: ['ignited_storm'],
      ),
    );
    match.playEquippedAttack('ignited_storm');
    expect(match.playerBCurrentHp, 86);
    expect(match.equippedElementIdsForPlayerA, ['ice', 'earth']);
    expect(match.startNewBattleKeepingProgress().equippedElementIdsForPlayerA, [
      'ice',
      'earth',
    ]);
  });

  test('new element fills a free slot without exceeding four', () {
    final match = TrainingMatch(
      initialProgressA: SkillProgress(
        defaultSkillTree,
        unlockedNodeIds: ['unlock_fire', 'unlock_wind'],
      ),
      initialTurnsPlayedA: 100,
    );
    match.unlockSkillForCurrentPlayer('unlock_water');
    match.unlockSkillForCurrentPlayer('unlock_ice');
    match.unlockSkillForCurrentPlayer('unlock_earth');
    expect(match.equippedElementIdsForCurrentPlayer, [
      'fire',
      'wind',
      'water',
      'ice',
    ]);
    expect(match.availableElementIdsForCurrentPlayer, contains('earth'));
  });

  test(
    'equipment storage distinguishes old saves and keeps players separate',
    () async {
      SharedPreferences.setMockInitialValues({
        'training_elements_equipped_b': 42,
      });
      final store = TrainingProgressStore();
      expect(await store.loadEquippedElementIds('a'), isNull);
      expect(await store.loadEquippedElementIds('b'), isNull);
      await store.saveEquippedElementIds('a', ['fire', 'ice']);
      await store.saveEquippedElementIds('b', ['earth']);
      expect(await store.loadEquippedElementIds('a'), ['fire', 'ice']);
      expect(await store.loadEquippedElementIds('b'), ['earth']);
    },
  );
}
