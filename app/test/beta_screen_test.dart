import 'dart:io';
import 'dart:ui' as ui;
import 'package:app/game_domain/beta_session.dart';
import 'package:app/game_presentation/beta_game.dart';
import 'package:app/game_presentation/sfx_player.dart';
import 'package:app/ui/beta_access_screen.dart';
import 'package:app/ui/beta_controls.dart';
import 'package:app/ui/beta_screen.dart';
import 'package:app/ui/home_screen.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'training_sentinel': 12,
      'dungeon_sentinel': 24,
    });
    final previous = sfxPlayer;
    sfxPlayer = SfxPlayer(play: (_) {});
    addTearDown(() => sfxPlayer = previous);
  });
  setUpAll(() async {
    if (Platform.environment['ELEMENTOS_ART_PREVIEW'] == '1' &&
        Platform.isWindows) {
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      for (final font in [('Roboto', 'segoeui'), ('monospace', 'consola')]) {
        final file = File('C:/Windows/Fonts/${font.$2}.ttf');
        await (FontLoader(font.$1)..addFont(
              Future.value(ByteData.sublistView(await file.readAsBytes())),
            ))
            .load();
      }
    }
  });
  Future<void> frame(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets(
    'rotation cancels held input; diagnostics and idle loop are local',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final previewKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: previewKey,
          child: const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: BetaScreen(),
          ),
        ),
      );
      await frame(tester);
      final game = tester
          .widget<GameWidget<BetaGame>>(find.byType(GameWidget<BetaGame>))
          .game!;
      expect(game.paused, true);
      await tester.tap(find.text('Diagnóstico local'));
      await frame(tester);
      await tester.ensureVisible(find.byType(SwitchListTile));
      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();
      expect(game.performance.enabled, true);
      if (Platform.environment['ELEMENTOS_ART_PREVIEW'] == '1') {
        await tester.ensureVisible(find.text('Copiar diagnóstico'));
        await frame(tester);
        await tester.runAsync(() async {
          final image =
              await (previewKey.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('build/gameplay-preview/beta-diagnostics.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.ensureVisible(find.text('Entrar na ruína'));
      await tester.tap(find.text('Entrar na ruína'));
      await frame(tester);
      expect(game.paused, false);
      final stamp = tester.binding.currentSystemFrameTimeStamp.inMicroseconds;
      final timing = ui.FrameTiming(
        vsyncStart: stamp,
        buildStart: stamp,
        buildFinish: stamp + 2000,
        rasterStart: stamp + 2000,
        rasterFinish: stamp + 6000,
        rasterFinishWallTime: stamp + 6000,
      );
      tester.binding.platformDispatcher.onReportTimings!([timing]);
      expect(game.performance.frameSamples, 1);
      expect(game.performance.rasterP95, 4);
      final finger = await tester.startGesture(
        tester.getCenter(find.byType(BetaJoystick)) + const Offset(32, 0),
      );
      expect(game.session.moveX, greaterThan(0));
      await tester.pump(const Duration(milliseconds: 16));
      tester.view.physicalSize = const Size(640, 360);
      await frame(tester);
      expect(game.session.phase, BetaPhase.paused);
      expect(game.session.moveX, 0);
      expect(game.paused, true);
      tester.binding.platformDispatcher.onReportTimings?.call([timing]);
      expect(game.performance.frameSamples, 1);
      final time = game.session.time;
      final samples = game.performance.loopSamples;
      expect(samples, greaterThan(0));
      await tester.pump(const Duration(seconds: 2));
      expect(game.session.time, time);
      expect(game.performance.loopSamples, samples);
      await tester.ensureVisible(find.text('Retomar'));
      await tester.tap(find.text('Retomar'));
      await frame(tester);
      await finger.moveBy(const Offset(5, 0));
      await finger.up();
      // A delayed batch from before the pause must not contaminate this run.
      tester.binding.platformDispatcher.onReportTimings!([timing]);
      expect(game.performance.frameSamples, 1);
      expect(game.session.moveX, 0);
      expect(game.session.playing, true);
      game.session.phase = BetaPhase.won;
      game.session.resultTime = .01;
      await frame(tester);
      expect(game.paused, true);
      await tester.ensureVisible(find.text('Testar novamente'));
      await tester.tap(find.text('Testar novamente'));
      await frame(tester);
      expect(game.session.playing, true);
      await tester.pumpWidget(const SizedBox());
      expect(game.paused, true);
      expect(game.performance.loopSamples, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('home beta requires the exact password again after leaving', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.tap(find.text('BETA TEST'));
    await frame(tester);
    expect(find.byType(BetaAccessScreen), findsOneWidget);
    await tester.enterText(find.byType(TextField), '32431');
    await tester.tap(find.text('Acessar BETA TEST'));
    await frame(tester);
    expect(find.textContaining('Senha incorreta'), findsOneWidget);
    expect(find.byType(BetaScreen), findsNothing);
    await tester.enterText(find.byType(TextField), '032431');
    await tester.tap(find.text('Acessar BETA TEST'));
    await frame(tester);
    expect(find.byType(BetaScreen), findsOneWidget);
    await tester.tap(find.text('Voltar ao menu'));
    await frame(tester);
    await frame(tester);
    expect(find.byType(BetaScreen), findsNothing);
    await tester.tap(find.text('BETA TEST'));
    await frame(tester);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
    expect(find.byType(BetaScreen), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(640, 360),
  ]) {
    testWidgets('beta controls, simultaneous input and lifecycle at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: BetaScreen(),
          ),
        ),
      );
      await frame(tester);
      await tester.ensureVisible(find.text('Entrar na ruína'));
      await tester.tap(find.text('Entrar na ruína'));
      await frame(tester);
      final game = tester
          .widget<GameWidget<BetaGame>>(find.byType(GameWidget<BetaGame>))
          .game!;
      expect(game.session.playing, true);
      for (final label in ['Espada', 'Magia', 'Esquiva']) {
        expect(find.text(label).hitTestable(), findsOneWidget);
      }
      final startX = game.session.x;
      final finger = await tester.startGesture(
        tester.getCenter(find.byType(BetaJoystick)) + const Offset(32, 0),
        pointer: 4,
      );
      final attack = await tester.startGesture(
        tester.getCenter(find.text('Espada')),
        pointer: 5,
      );
      // Contact executes immediately, even while moving and before releasing.
      expect(game.session.swordTime, BetaSession.swordDuration);
      await attack.up();
      await tester.pump(const Duration(milliseconds: 80));
      await tester.pump(const Duration(milliseconds: 80));
      expect(game.session.x, greaterThan(startX));
      await finger.cancel();
      await tester.pump();
      expect(game.session.moveX, 0);
      expect(
        tester
            .getRect(find.byType(BetaJoystick))
            .overlaps(tester.getRect(find.byType(BetaActionPad))),
        false,
      );
      // Capture a populated arena, not just an empty backdrop.
      if (Platform.environment['ELEMENTOS_ART_PREVIEW'] == '1') {
        game.session.enemies[0]
          ..x = -1.8
          ..z = 1;
        game.session.enemies[1]
          ..x = 2.6
          ..z = -.5;
        game.session.enemies[2] = BetaEnemy(BetaEnemyKind.guardian, .4, -3);
        game.session
          ..swordTime = 0
          ..swordCooldown = 0
          ..angle = 3.141592653589793;
        game.refresh();
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            'build/gameplay-preview/beta-${size.width.toInt()}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      game.session
        ..swordTime = 0
        ..swordCooldown = 0
        ..spellCooldown = 0
        ..mana = 100;
      game.refresh();
      await tester.pump();
      await tester.tap(find.text('Magia'));
      await tester.pump();
      expect(find.text('Conjurando'), findsNWidgets(3));
      game.session
        ..castTime = .15
        ..swordCooldown = 0;
      game.refresh();
      await tester.pump();
      await tester.tap(find.text('Espada'));
      await tester.pump();
      expect(find.text('Na fila'), findsOneWidget);
      game.session.pause();
      game.session.resume(); // Discard test intent without changing the route.
      game.session
        ..castTime = 0
        ..spellCooldown = 0
        ..mana = 0;
      game.refresh();
      await tester.pump();
      expect(find.text('Sem mana'), findsOneWidget);
      game.session.enemies.clear();
      game.refresh();
      await tester.pump();
      expect(find.textContaining('ENCONTRO 1 CONCLUÍDO'), findsOneWidget);
      expect(
        tester.getTopLeft(find.textContaining('ENCONTRO 1 CONCLUÍDO')).dy,
        greaterThan(
          tester.getBottomLeft(find.textContaining('progresso temporário')).dy,
        ),
      );
      if (Platform.environment['ELEMENTOS_ART_PREVIEW'] == '1') {
        await tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            'build/gameplay-preview/beta-recovery-${size.width.toInt()}.png',
          ).writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(game.session.phase, BetaPhase.paused);
      final time = game.session.time;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 2));
      expect(game.session.time, time);
      await tester.ensureVisible(find.text('Retomar'));
      await tester.tap(find.text('Retomar'));
      await tester.pump();
      expect(game.session.playing, true);
      await tester.tap(find.byTooltip('Pausar beta'));
      await tester.pump();
      expect(game.session.phase, BetaPhase.paused);
      game.session.phase = BetaPhase.won;
      game.session.resultTime = .7;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(game.session.settling, false);
      expect(find.text('GUARDIÃO DERROTADO'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect((await SharedPreferences.getInstance()).getKeys(), {
        'training_sentinel',
        'dungeon_sentinel',
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
