import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:app/game_domain/beta_session.dart';
import 'package:app/game_presentation/beta_game.dart';
import 'package:app/game_presentation/sfx_player.dart';
import 'package:app/ui/beta_access_screen.dart';
import 'package:app/ui/beta_controls.dart';
import 'package:app/ui/beta_screen.dart';
import 'package:app/ui/beta_status_readout.dart';
import 'package:app/ui/home_screen.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

  for (final size in [const Size(320, 568), const Size(568, 320)]) {
    testWidgets(
      'simultaneous status feedback preserves critical warning at $size',
      (tester) async {
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
        final game = tester
            .widget<GameWidget<BetaGame>>(find.byType(GameWidget<BetaGame>))
            .game!;
        game.session.start();
        game.pauseEngine(); // Freeze a worst-case HUD snapshot, not the simulation phase.
        game.session
          ..hp = 20
          ..stamina = 0
          ..burnTime = 3
          ..curseTime = 4
          ..blessingTime = 5
          ..runicBladeTime = 4
          ..protection = 2
          ..wardTime = .7;
        game.refresh();
        await tester.pump();
        expect(find.text('VIDA BAIXA · Água cura ao acertar'), findsOneWidget);
        expect(find.text('ST 0/100'), findsOneWidget);
        expect(find.text('Sem stamina'), findsNWidgets(2));
        for (final id in [
          'burn',
          'curse',
          'blessing',
          'rune',
          'shield',
          'ward',
        ]) {
          expect(
            find.byKey(ValueKey('beta-effect-$id')).hitTestable(),
            findsOneWidget,
          );
        }
        final status = tester.getRect(find.byType(BetaStatusReadout));
        expect(
          status.overlaps(tester.getRect(find.byType(BetaJoystick))),
          false,
        );
        expect(
          status.overlaps(tester.getRect(find.byType(BetaActionPad))),
          false,
        );
        expect(tester.takeException(), isNull);
        if (Platform.environment['ELEMENTOS_ART_PREVIEW'] == '1') {
          await tester.runAsync(() async {
            final image =
                await (key.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File(
              'build/gameplay-preview/beta-status-${size.width.toInt()}.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.longPress(find.byKey(const ValueKey('beta-effect-ward')));
        await tester.pump(const Duration(milliseconds: 200));
        expect(
          find.text(
            'Perseu impediu um efeito negativo. O dano de impacto não foi bloqueado.',
          ),
          findsOneWidget,
        );
        game.session
          ..burnTime = 0
          ..stamina = 100
          ..curseTime = 0
          ..blessingTime = 0
          ..runicBladeTime = 0
          ..protection = 0
          ..wardTime = 0;
        game.refresh();
        await tester.pump();
        expect(find.byKey(const ValueKey('beta-effect-burn')), findsNothing);
        expect(find.text('ST 100/100'), findsOneWidget);
        expect(find.text('28 ST'), findsOneWidget);
        expect(find.text('Sem stamina'), findsNothing);
        expect(find.byKey(const ValueKey('beta-effect-ward')), findsNothing);
        expect(find.text('VIDA BAIXA · Água cura ao acertar'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('back protects a session; guide is available while paused', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final previewKey = GlobalKey();
    Future<void> capture(String name) async {
      if (Platform.environment['ELEMENTOS_ART_PREVIEW'] != '1') return;
      await tester.runAsync(() async {
        final image =
            await (previewKey.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/gameplay-preview/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }

    await tester.pumpWidget(
      RepaintBoundary(
        key: previewKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const BetaScreen()),
                ),
                child: const Text('Abrir beta'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir beta'));
    await frame(tester);
    await tester.tap(find.text('Entrar na ruína'));
    await frame(tester);
    final game = tester
        .widget<GameWidget<BetaGame>>(find.byType(GameWidget<BetaGame>))
        .game!;
    expect(game.reduceMotion, true);
    game.session
      ..hp = 77
      ..mana = 43;
    final attack = await tester.startGesture(
      tester.getCenter(find.text('Espada')),
    );
    await tester.pump();
    expect(
      tester
          .widgetList<AnimatedScale>(find.byType(AnimatedScale))
          .every((widget) => widget.scale == 1),
      true,
    );
    await attack.up();
    final finger = await tester.startGesture(
      tester.getCenter(find.byType(BetaJoystick)) + const Offset(30, 0),
      pointer: 4,
    );
    await tester.binding.handlePopRoute();
    await frame(tester);
    expect(game.session.phase, BetaPhase.paused);
    expect(game.session.moveX, 0);
    expect(find.text('SAIR DA RUÍNA?'), findsNothing);
    await finger.up();
    final hp = game.session.hp,
        mana = game.session.mana,
        time = game.session.time;
    await tester.binding.handlePopRoute();
    await frame(tester);
    expect(find.text('SAIR DA RUÍNA?'), findsOneWidget);
    await capture('beta-exit-polish');
    await tester.pump(const Duration(seconds: 2));
    expect(game.session.time, time);
    await tester.tap(find.text('Continuar na pausa'));
    await frame(tester);
    expect(game.session.phase, BetaPhase.paused);
    expect(game.session.hp, hp);
    expect(game.session.mana, mana);
    await tester.ensureVisible(find.text('Guia de combate'));
    await tester.tap(find.text('Guia de combate'));
    await frame(tester);
    for (final element in BetaElement.values) {
      expect(
        find.text('${element.label} · ${element.description}'),
        findsOneWidget,
      );
    }
    await tester.ensureVisible(find.text('Guia de combate'));
    await frame(tester);
    await capture('beta-guide-polish');
    await tester.ensureVisible(find.text('Retomar'));
    await tester.tap(find.text('Retomar'));
    await frame(tester);
    expect(game.session.playing, true);
    expect(game.session.moveX, 0);
    game.session
      ..phase = BetaPhase.won
      ..resultTime = .01;
    await frame(tester);
    await tester.ensureVisible(find.text('Testar novamente'));
    await tester.tap(find.text('Testar novamente'));
    await frame(tester);
    expect(game.reduceMotion, true);
    expect(game.session.playing, true);
    await tester.tap(find.byTooltip('Pausar beta'));
    await frame(tester);
    await tester.ensureVisible(find.text('Voltar ao menu'));
    await tester.tap(find.text('Voltar ao menu'));
    await frame(tester);
    await tester.tap(find.text('Sair e descartar sessão'));
    // The dialog and page each have a reverse transition; the arena is paused.
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
    expect(find.byType(BetaScreen), findsNothing);
    expect(game.paused, true);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'action feedback keeps one request per contact and rearms on cancel',
    (tester) async {
      final run = BetaSession()..start();
      final refresh = ValueNotifier(0);
      addTearDown(refresh.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ValueListenableBuilder<int>(
                valueListenable: refresh,
                builder: (context, _, _) =>
                    BetaActionPad(run: run, refresh: () => refresh.value++),
              ),
            ),
          ),
        ),
      );
      final button = find.byKey(const ValueKey('beta-Magia'));
      double scale() => tester
          .widget<AnimatedScale>(
            find.descendant(of: button, matching: find.byType(AnimatedScale)),
          )
          .scale;
      final finger = await tester.startGesture(
        tester.getCenter(button),
        pointer: 1,
      );
      await tester.pump();
      expect(run.mana, 75);
      expect(scale(), .96);
      for (var i = 0; i < 14; i++) {
        run.update(.1);
      }
      refresh.value++;
      await tester.pump();
      expect(run.canCast, true);
      expect(run.castTime, 0); // Holding is not autofire.
      final mana = run.mana;
      final extra = await tester.startGesture(
        tester.getCenter(button),
        pointer: 2,
      );
      await extra.up();
      await tester.pump();
      expect(run.mana, mana);
      expect(scale(), .96); // Another finger cannot release the first.
      await finger.cancel();
      await tester.pump();
      expect(scale(), 1);
      await tester.tap(button);
      await tester.pump();
      expect(run.mana, closeTo(mana - 25, .001));
      expect(scale(), 1);
      await tester.tap(button); // Unavailable: no request or stuck press state.
      await tester.pump();
      expect(run.mana, closeTo(mana - 25, .001));
      expect(scale(), 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

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
      expect(game.reduceMotion, false);
      await tester.pumpWidget(const SizedBox());
      expect(game.paused, true);
      expect(game.performance.loopSamples, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('home beta requires the exact password again after leaving', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({
      'elementos.firebase.session.': jsonEncode({
        'refresh': 'test-refresh',
        'uid': 'adventurer',
        'email': 'tester@example.invalid',
        'verified': true,
      }),
    });
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.tap(find.text('BETA TEST'));
    await frame(tester);
    expect(find.byType(BetaAccessScreen), findsOneWidget);
    await tester.enterText(find.byType(TextField), '32431');
    await tester.tap(find.text('Iniciar aventura'));
    await frame(tester);
    expect(find.textContaining('Senha do beta incorreta'), findsOneWidget);
    expect(find.byType(BetaScreen), findsNothing);
    await tester.enterText(find.byType(TextField), '032431');
    await tester.tap(find.text('Iniciar aventura'));
    await frame(tester);
    expect(find.byType(BetaScreen), findsOneWidget);
    await tester.ensureVisible(find.text('Voltar ao menu'));
    await tester.tap(find.text('Voltar ao menu'));
    await frame(tester);
    await frame(tester);
    expect(find.byType(BetaScreen), findsNothing);
    expect(find.text('Continuar aventura'), findsOneWidget);
    await tester.pageBack();
    await frame(tester);
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
      expect(find.text('Entrar na ruína').hitTestable(), findsOneWidget);
      if (Platform.environment['ELEMENTOS_ART_PREVIEW'] == '1') {
        await tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            'build/gameplay-preview/beta-menu-${size.width.toInt()}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.ensureVisible(find.text('Entrar na ruína'));
      await tester.tap(find.text('Entrar na ruína'));
      await frame(tester);
      final game = tester
          .widget<GameWidget<BetaGame>>(find.byType(GameWidget<BetaGame>))
          .game!;
      expect(game.session.playing, true);
      for (final label in ['Espada', 'Magia', 'Rolar']) {
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
      if (Platform.environment['ELEMENTOS_ART_PREVIEW'] == '1') {
        final attacker = game.session.enemies.first
          ..x = game.session.x
          ..z = game.session.z - 1.5;
        attacker.beginAttack(game.session.x, game.session.z);
        game.refresh();
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            'build/gameplay-preview/beta-danger-${size.width.toInt()}.png',
          ).writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
        attacker.cancelAttack();
      }
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
      final hudHeight = tester
          .getBottomLeft(find.byKey(const ValueKey('beta-status')))
          .dy;
      game.session
        ..hp = 20
        ..invulnerable = 1;
      game.update(.01);
      game.refresh();
      await tester.pump();
      expect(find.text('HP 20/100'), findsOneWidget);
      expect(find.text('VIDA BAIXA · Água cura ao acertar'), findsOneWidget);
      expect(game.healthTrail, greaterThan(.2));
      expect(
        tester.getBottomLeft(find.textContaining('VIDA BAIXA')).dy,
        closeTo(hudHeight, 1),
      );
      if (Platform.environment['ELEMENTOS_ART_PREVIEW'] == '1') {
        await tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            'build/gameplay-preview/beta-vitals-${size.width.toInt()}.png',
          ).writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      game.session.hp = 28;
      game.update(.01);
      game.refresh();
      await tester.pump();
      expect(find.textContaining('VIDA BAIXA'), findsNothing);
      expect(game.healthTrail, .28);
      game.session.enemies.clear();
      game.session.x = -2;
      game.session.z = 3;
      game.session.select(BetaElement.water);
      game.refresh();
      await tester.pump();
      expect(find.text('Sintonizar').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Inscrição'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Em A, a chuva'), findsOneWidget);
      await tester.tap(find.text('Revelar próximo passo'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Sintonizar'));
      await tester.pump();
      expect(game.session.puzzle.completed, 1);
      expect(game.session.puzzle.revealedHint, isNull);
      await tester.tap(find.text('Inscrição'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('✓ A: Água'), findsOneWidget);
      await tester.tap(find.text('Revelar próximo passo'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(game.session.puzzle.revealedHint?.hint, 'B: Terra');
      if (Platform.environment['ELEMENTOS_ART_PREVIEW'] == '1') {
        await tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            'build/gameplay-preview/beta-puzzles-${size.width.toInt()}.png',
          ).writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      for (var i = 0; i < 5; i++) {
        game.update(.1);
      }
      game.session.x = 2;
      game.session.select(BetaElement.earth);
      game.refresh();
      await tester.pump();
      await tester.tap(find.text('Sintonizar'));
      expect(game.session.puzzle.solved, true);
      game.refresh();
      await tester.pump();
      expect(find.textContaining('ÁREA LIVRE'), findsOneWidget);
      expect(
        tester.getTopLeft(find.textContaining('ÁREA LIVRE')).dy,
        greaterThan(
          tester.getBottomLeft(find.byKey(const ValueKey('beta-status'))).dy,
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
      for (var i = 0; i < 22; i++) {
        game.update(.1);
      }
      game.refresh();
      await tester.pump();
      expect(find.textContaining('PASSAGEM ABERTA'), findsOneWidget);
      game.session.x = BetaRegion.gateX;
      game.session.z = BetaRegion.gateZ;
      for (var i = 0; i < 6; i++) {
        game.update(.1);
      }
      await tester.pump();
      expect(find.textContaining('Aqueduto Velado · 2/6'), findsOneWidget);
      expect(find.byKey(const ValueKey('beta-movement-2')), findsOneWidget);
      expect(find.byKey(const ValueKey('beta-actions-1')), findsNothing);
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
      expect(find.text('AURORA RESTAURADA'), findsOneWidget);
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
