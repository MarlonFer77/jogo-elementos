import 'dart:convert';
import 'package:app/game_domain/dungeon_campaign.dart';
import 'package:app/game_domain/dungeon_progress.dart';
import 'package:app/game_domain/dungeon_progress_store.dart';
import 'package:app/game_presentation/battle_scene_widget.dart';
import 'package:app/game_presentation/dungeon_intent_banner.dart';
import 'package:app/game_presentation/sfx_player.dart';
import 'package:app/ui/dungeon_screen.dart';
import 'package:app/ui/training_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final previous = sfxPlayer;
    sfxPlayer = SfxPlayer(play: (_) {});
    addTearDown(() => sfxPlayer = previous);
  });
  for (final size in [const Size(360, 640), const Size(568, 320)]) {
    testWidgets('intent and play button visible at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = DungeonCampaign(
        DungeonProgress().prepare(['fire', 'wind']),
        DungeonProgressStore(),
      );
      await c.start();
      await tester.pumpWidget(
        MaterialApp(
          home: TrainingScreen(dungeon: c, encounter: c.enter()),
        ),
      );
      await tester.pump();
      expect(find.text('Próxima: Fogo').hitTestable(), findsOneWidget);
      expect(find.byType(DungeonIntentBanner), findsOneWidget);
      await tester.tap(find.text('Fogo'));
      await tester.pump();
      expect(find.text('Jogar').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
    testWidgets('camp actions visible at $size', (tester) async {
      final p = DungeonProgress().prepare(['fire', 'wind']);
      SharedPreferences.setMockInitialValues({
        DungeonProgressStore.key: jsonEncode(p.toJson()),
      });
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: DungeonScreen()));
      await tester.pump();
      await tester.pump();
      expect(find.text('Iniciar expedição').hitTestable(), findsOneWidget);
      expect(find.text('Árvore · 0').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('enemy responds after animation; player cannot control it', (
    tester,
  ) async {
    final c = DungeonCampaign(
      DungeonProgress().prepare(['fire', 'wind']),
      DungeonProgressStore(),
    );
    await c.start();
    final encounter = c.enter();
    await tester.pumpWidget(
      MaterialApp(
        home: TrainingScreen(dungeon: c, encounter: encounter),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Fogo'));
    await tester.pump();
    await tester.tap(find.text('Jogar'));
    await tester.pump();
    expect(encounter.match.isPlayerATurn, false);
    expect(find.text('Jogar').hitTestable(), findsNothing);
    tester
        .widget<BattleSceneWidget>(find.byType(BattleSceneWidget))
        .onAttackComplete!();
    await tester.pump(const Duration(milliseconds: 700));
    expect(encounter.match.isPlayerATurn, true);
    expect(encounter.match.playerACurrentHp, lessThan(100));
    tester
        .widget<BattleSceneWidget>(find.byType(BattleSceneWidget))
        .onAttackComplete!();
    await tester.pump();
    expect(find.text('Fogo').hitTestable(), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance()).getKeys().where(
        (k) => k.startsWith('training_'),
      ),
      isEmpty,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
