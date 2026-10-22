import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:app/game_domain/update_checker.dart';
import 'package:app/game_presentation/beta_arena_painter.dart';
import 'package:app/game_presentation/sfx_player.dart';
import 'package:app/settings/game_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/ui/loading_battle_scene.dart';
import 'package:app/ui/update_gate_screen.dart';
import 'package:app/ui/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _PendingCheck implements UpdateChecker {
  final result = Completer<UpdateCheckResult>();
  @override
  Future<UpdateCheckResult> checkForUpdate({required String currentVersion}) =>
      result.future;
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await gameSettings.setMuted(false);
  });
  setUpAll(() async {
    if (Platform.environment['ELEMENTOS_ART_PREVIEW'] != '1') return;
    for (final font in [('Roboto', 'segoeui'), ('monospace', 'consola')]) {
      await (FontLoader(font.$1)..addFont(
            Future.value(
              ByteData.sublistView(
                await File('C:/Windows/Fonts/${font.$2}.ttf').readAsBytes(),
              ),
            ),
          ))
          .load();
    }
  });
  for (final size in [const Size(320, 568), const Size(568, 320)]) {
    testWidgets('loading choreography fits $size through its entire loop', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundary = GlobalKey();
      var presented = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: boundary,
            child: LoadingBattleScene(
              audio: SfxPlayer(play: (_) {}),
              ready: false,
              onPresented: () => presented++,
              onEnter: () => fail('not ready'),
            ),
          ),
        ),
      );
      for (var frame = 1; frame <= 84; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
        if ([8, 17, 33, 52].contains(frame) &&
            Platform.environment['ELEMENTOS_ART_PREVIEW'] == '1') {
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File(
              'build/gameplay-preview/loading-${size.width.toInt()}-$frame.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        }
      }
      expect(presented, 1);
      expect(
        find.text('Verificando atualização…').hitTestable(),
        findsOneWidget,
      );
      expect(find.byType(Scrollable), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('slow update never enters Home; background freezes the scene', (
    tester,
  ) async {
    final checker = _PendingCheck();
    await tester.pumpWidget(
      MaterialApp(
        home: UpdateGateScreen(
          isAndroid: true,
          currentVersion: '0.40.0',
          updateChecker: checker,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));
    final art = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<LoadingBattlePainter>()
        .single;
    await tester.pump(const Duration(milliseconds: 500));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    final frozen = art.clock.value;
    await tester.pump(const Duration(seconds: 10));
    expect(art.clock.value, frozen);
    expect(find.byType(HomeScreen), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(art.clock.value, isNot(frozen));
    expect(find.byType(HomeScreen), findsNothing);
    checker.result.complete(const UpdateCheckResult.failed('Sem conexão.'));
    await tester.pump();
    expect(find.text('Verificar novamente'), findsOneWidget);
    expect(find.byType(LoadingBattleScene), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('audio respects mute and is released when leaving the opening', (
    tester,
  ) async {
    final played = <String>[];
    final audio = SfxPlayer(play: played.add);
    await tester.pumpWidget(
      MaterialApp(
        home: LoadingBattleScene(
          ready: false,
          audio: audio,
          onPresented: () {},
          onEnter: () {},
        ),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(played, [SfxId.defend.path]);
    await tester.runAsync(() => gameSettings.setMuted(true));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(played, hasLength(1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(audio.volume, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.runAsync(() => gameSettings.setMuted(false));
    expect(audio.volume, greaterThan(0));
    await tester.pumpWidget(const SizedBox());
    expect(audio.volume, 0);
  });

  testWidgets('reduced motion has static art and no mandatory intro delay', (
    tester,
  ) async {
    var presented = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: LoadingBattleScene(
            ready: false,
            onPresented: () => presented++,
            onEnter: () {},
          ),
        ),
      ),
    );
    final art = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<LoadingBattlePainter>()
        .single;
    await tester.pump(const Duration(seconds: 4));
    expect(art.clock.value, 0);
    expect(presented, 1);
    await tester.pumpWidget(const SizedBox());
  });
}
