import 'package:app/game_domain/training_progress_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('unlocked node ids', () {
    test('an empty slot returns an empty list', () async {
      final store = TrainingProgressStore();
      expect(await store.loadUnlockedNodeIds('a'), isEmpty);
    });

    test('saves and reloads a slot', () async {
      final store = TrainingProgressStore();
      await store.saveUnlockedNodeIds('a', ['ember_mastery', 'wildfire_path']);

      expect(
        await store.loadUnlockedNodeIds('a'),
        ['ember_mastery', 'wildfire_path'],
      );
    });

    test('two slots are independent', () async {
      final store = TrainingProgressStore();
      await store.saveUnlockedNodeIds('a', ['ember_mastery']);
      await store.saveUnlockedNodeIds('b', ['vitality_training']);

      expect(await store.loadUnlockedNodeIds('a'), ['ember_mastery']);
      expect(await store.loadUnlockedNodeIds('b'), ['vitality_training']);
    });
  });

  group('discovered combination ids', () {
    test('starts empty', () async {
      final store = TrainingProgressStore();
      expect(await store.loadDiscoveredCombinationIds(), isEmpty);
    });

    test('saves and reloads', () async {
      final store = TrainingProgressStore();
      await store.saveDiscoveredCombinationIds(['ignited_storm', 'lava']);

      expect(
        await store.loadDiscoveredCombinationIds(),
        ['ignited_storm', 'lava'],
      );
    });
  });

  group('turns played', () {
    test('an empty slot returns 0', () async {
      final store = TrainingProgressStore();
      expect(await store.loadTurnsPlayed('a'), 0);
    });

    test('saves and reloads a slot', () async {
      final store = TrainingProgressStore();
      await store.saveTurnsPlayed('a', 7);

      expect(await store.loadTurnsPlayed('a'), 7);
    });

    test('two slots are independent', () async {
      final store = TrainingProgressStore();
      await store.saveTurnsPlayed('a', 10);
      await store.saveTurnsPlayed('b', 3);

      expect(await store.loadTurnsPlayed('a'), 10);
      expect(await store.loadTurnsPlayed('b'), 3);
    });
  });

  group('unlocked attack ids', () {
    test('an empty slot returns an empty list', () async {
      final store = TrainingProgressStore();
      expect(await store.loadUnlockedAttackIds('a'), isEmpty);
    });

    test('saves and reloads a slot', () async {
      final store = TrainingProgressStore();
      await store.saveUnlockedAttackIds('a', ['ignited_storm', 'lava']);

      expect(
        await store.loadUnlockedAttackIds('a'),
        ['ignited_storm', 'lava'],
      );
    });

    test('two slots are independent', () async {
      final store = TrainingProgressStore();
      await store.saveUnlockedAttackIds('a', ['ignited_storm']);
      await store.saveUnlockedAttackIds('b', ['lava']);

      expect(await store.loadUnlockedAttackIds('a'), ['ignited_storm']);
      expect(await store.loadUnlockedAttackIds('b'), ['lava']);
    });
  });

  group('equipped attack ids', () {
    test('an empty slot returns an empty list', () async {
      final store = TrainingProgressStore();
      expect(await store.loadEquippedAttackIds('a'), isEmpty);
    });

    test('saves and reloads a slot', () async {
      final store = TrainingProgressStore();
      await store.saveEquippedAttackIds('a', ['ignited_storm']);

      expect(await store.loadEquippedAttackIds('a'), ['ignited_storm']);
    });

    test('two slots are independent', () async {
      final store = TrainingProgressStore();
      await store.saveEquippedAttackIds('a', ['ignited_storm']);
      await store.saveEquippedAttackIds('b', ['lava']);

      expect(await store.loadEquippedAttackIds('a'), ['ignited_storm']);
      expect(await store.loadEquippedAttackIds('b'), ['lava']);
    });
  });
}
