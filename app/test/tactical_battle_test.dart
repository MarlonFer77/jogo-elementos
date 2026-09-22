import 'dart:io';
import 'dart:ui' as ui;
import 'package:app/game_domain/training_match.dart';
import 'package:app/game_presentation/battle_scene_widget.dart';
import 'package:app/ui/training_screen.dart';
import 'package:battle_engine/battle_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final size in [const Size(360, 640), const Size(568, 320)]) {
    testWidgets('defense preview, confirmation and return to attack at $size', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final progress = SkillProgress(
        defaultSkillTree,
        unlockedNodeIds: ['unlock_fire', 'unlock_wind'],
      );
      final match = TrainingMatch(
        initialProgressA: progress,
        initialProgressB: progress,
      );
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(home: TrainingScreen(initialMatch: match)),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.ensureVisible(find.text('Defender'));
      await tester.tap(find.text('Defender'));
      await tester.pump();
      expect(match.turnsPlayed, 0);
      expect(find.text('Confirmar defesa').hitTestable(), findsOneWidget);
      expect(
        find.byKey(const ValueKey('action-preview-compact')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      if (Platform.environment['ELEMENTOS_ART_PREVIEW'] == '1') {
        await tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          Directory('build/art-preview').createSync(recursive: true);
          File(
            'build/art-preview/defend-${size.width.toInt()}.png',
          ).writeAsBytesSync(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.tap(find.text('Confirmar defesa'));
      await tester.pump();
      expect(match.turnsPlayed, 1);
      expect(match.playerBCurrentHp, 100);
      expect(
        tester
            .widget<BattleSceneWidget>(find.byType(BattleSceneWidget))
            .view
            .lastAttack!
            .isDefend,
        isTrue,
      );
      for (var i = 0; i < 16; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.ensureVisible(find.text('Fogo'));
      await tester.tap(find.text('Fogo'));
      await tester.pump();
      await tester.tap(find.text('Jogar'));
      await tester.pump();
      expect(match.playerACurrentHp, 97);
      expect(match.turnsPlayed, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('frozen player only gets the break-free action', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final progress = SkillProgress(
      defaultSkillTree,
      unlockedNodeIds: ElementUnlocks.all.map((unlock) => unlock.id).toList(),
    );
    final match = TrainingMatch(
      initialApA: const ApPool(max: 5, current: 3),
      initialApB: const ApPool(max: 5, current: 2),
      initialProgressA: progress,
      initialProgressB: progress,
    );
    match.playElementIds(['water', 'ice']);
    final key = GlobalKey();

    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(home: TrainingScreen(initialMatch: match)),
      ),
    );
    await tester.pump();
    expect(find.text('CONGELADO'), findsOneWidget);
    expect(find.text('Quebrar gelo'), findsOneWidget);
    expect(find.text('Defender'), findsNothing);
    if (Platform.environment['ELEMENTOS_ART_PREVIEW'] == '1') {
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory('build/art-preview').createSync(recursive: true);
        File(
          'build/art-preview/freeze.png',
        ).writeAsBytesSync(data!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.ensureVisible(find.text('Quebrar gelo'));
    await tester.tap(find.text('Quebrar gelo'));
    await tester.pump();
    expect(match.currentTurnName, 'Jogador A');
    expect(match.playerBAp, 2);
    expect(match.currentPlayerIsFrozen, isFalse);
  });
}
