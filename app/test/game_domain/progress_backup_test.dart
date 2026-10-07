import 'dart:convert';
import 'package:app/game_domain/dungeon_progress.dart';
import 'package:app/game_domain/dungeon_progress_store.dart';
import 'package:app/game_domain/training_progress_store.dart';
import 'package:app/ui/training_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'unrecoverable training save shows a retry instead of an endless loader',
    (tester) async {
      SharedPreferences.setMockInitialValues({'training_unlocked_a': 42});
      await tester.pumpWidget(const MaterialApp(home: TrainingScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Progresso preservado'), findsOneWidget);
      expect(find.text('Tentar novamente'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'dungeon recovers last good save, preserves damaged source and refuses future versions',
    () async {
      final store = DungeonProgressStore();
      final progress = DungeonProgress().prepare(['fire', 'wind']);
      await store.save(progress);
      await store.save(progress.copyWith(xp: 40));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(DungeonProgressStore.key, '{broken');
      final recovered = await store.load();
      expect(recovered.xp, 0);
      expect(store.recovered, isTrue);
      expect(prefs.getString(DungeonProgressStore.key), '{broken');
      await store.save(recovered);
      expect(
        jsonDecode(prefs.getString('${DungeonProgressStore.key}.corrupt.v1')!),
        '{broken',
      );
      await prefs.setString(
        DungeonProgressStore.key,
        jsonEncode({
          ...progress.toJson(),
          'version': DungeonProgress.saveVersion + 1,
        }),
      );
      await expectLater(store.load(), throwsStateError);
      await expectLater(store.save(progress), throwsStateError);
    },
  );

  test(
    'training migrates legacy keys and serializes concurrent instances',
    () async {
      SharedPreferences.setMockInitialValues({'training_turns_played_a': 7});
      final a = TrainingProgressStore(), b = TrainingProgressStore();
      await Future.wait([a.saveTurnsPlayed('a', 8), b.saveTurnsPlayed('a', 9)]);
      expect(await a.loadTurnsPlayed('a'), 9);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('training_turns_played_a', 'broken');
      expect(await a.loadTurnsPlayed('a'), 8);
      expect(a.recovered, isTrue);
      expect(await b.loadTurnsPlayed('b'), 0);
    },
  );

  test('invalid training value is not replaced with empty progress', () async {
    SharedPreferences.setMockInitialValues({'training_unlocked_a': 42});
    final store = TrainingProgressStore();
    await expectLater(store.loadUnlockedNodeIds('a'), throwsStateError);
    await expectLater(store.saveUnlockedNodeIds('a', []), throwsStateError);
    expect(
      (await SharedPreferences.getInstance()).get('training_unlocked_a'),
      42,
    );
  });

  test(
    'missing primary key recovers backup instead of onboarding again',
    () async {
      final store = TrainingProgressStore();
      await store.saveUnlockedNodeIds('a', ['unlock_fire', 'unlock_wind']);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('training_unlocked_a');
      expect(await store.loadUnlockedNodeIds('a'), [
        'unlock_fire',
        'unlock_wind',
      ]);
      expect(store.recovered, isTrue);
    },
  );
}
