import 'dart:io';
import 'dart:ui' as ui;
import 'package:app/game_domain/beta_session.dart';
import 'package:app/game_presentation/beta_game.dart';
import 'package:app/game_presentation/sfx_player.dart';
import 'package:app/ui/beta_build_panel.dart';
import 'package:app/ui/beta_controls.dart';
import 'package:app/ui/beta_screen.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final preview = Platform.environment['ELEMENTOS_ART_PREVIEW'] == '1';
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final previous = sfxPlayer;
    sfxPlayer = SfxPlayer(play: (_) {});
    addTearDown(() => sfxPlayer = previous);
  });
  setUpAll(() async {
    if (!preview || !Platform.isWindows) return;
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    for (final font in [('Roboto', 'segoeui'), ('monospace', 'consola')]) {
      final bytes = await File('C:/Windows/Fonts/${font.$2}.ttf').readAsBytes();
      await (FontLoader(
        font.$1,
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
  });

  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(640, 360),
  ]) {
    testWidgets('grimoire, skills, mixing and replacement at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      Future<void> frame() async {
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }

      Future<void> capture(String name) async {
        if (!preview) return;
        await tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            'build/gameplay-preview/$name-${size.width.toInt()}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: BetaScreen(),
          ),
        ),
      );
      await frame();
      final game = tester
          .widget<GameWidget<BetaGame>>(find.byType(GameWidget<BetaGame>))
          .game!;
      final run = game.session;
      final open = find.byKey(const ValueKey('beta-open-build'));
      await tester.ensureVisible(open);
      await tester.tap(open);
      await frame();
      expect(find.byType(BetaBuildPanel), findsOneWidget);
      expect(run.phase, BetaPhase.ready);
      await tester.tap(find.text('Habilidades'));
      await frame();
      await capture('beta-skills');
      final learn = find.byKey(const ValueKey('beta-learn-runicBlade'));
      await tester.ensureVisible(learn);
      await tester.pump();
      await tester.tap(learn);
      await frame();
      expect(run.hasSkill(BetaSkill.runicBlade), true);
      expect(run.skillPoints, 0);
      expect(tester.widget<TextButton>(learn).onPressed, isNull);
      await tester.tap(find.byTooltip('Fechar grimório'));
      await frame();
      await tester.ensureVisible(find.text('Entrar na ruína'));
      await tester.tap(find.text('Entrar na ruína'));
      await frame();
      await tester.tap(find.byKey(const ValueKey('beta-mode-mix')));
      await tester.tap(find.byKey(const ValueKey('beta-element-water')));
      await tester.pump();
      expect(run.selectedCombo, BetaCombo.steam);
      expect(find.text('35 MP · Vapor'), findsOneWidget);
      final mana = run.mana;
      await tester.tap(find.text('Magia'));
      await tester.pump();
      expect(run.mana, closeTo(mana - 35, .01));
      expect(run.castingCombo, BetaCombo.steam);
      expect(run.castTime, greaterThan(0));

      // Feed actual impacts to discover four recipes without an extended fight.
      run.castTime = run.spellCooldown = 0;
      run.projectiles.clear();
      for (final combo in BetaCombo.values.take(4)) {
        run.enemies
          ..clear()
          ..add(BetaEnemy(BetaEnemyKind.guardian, 0, 3.4)..cooldown = 100);
        run.projectiles.add(
          BetaProjectile(0, 3.4, 0, -1, combo.first, combo: combo),
        );
        run.update(.01);
      }
      run.select(BetaElement.water);
      run.mix(BetaElement.wind);
      game.refresh();
      await tester.pump();
      expect(find.text('Não equipado'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('beta-mode-equipped')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('beta-combo-slot-1')));
      await tester.pump();
      expect(run.selectedCombo, BetaCombo.firestorm);
      expect(
        tester
            .getRect(find.byType(BetaActionPad))
            .overlaps(tester.getRect(find.byType(BetaJoystick))),
        false,
      );
      await capture('beta-combos-hud');
      run.enemies.clear();
      await tester.tap(find.byTooltip('Pausar beta'));
      await frame();
      await tester.ensureVisible(open);
      await tester.tap(open);
      await frame();
      await capture('beta-grimoire');
      final replace = find.byTooltip('Escolher slot para Névoa');
      await tester.scrollUntilVisible(
        replace,
        150,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('beta-combo-book')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pump();
      await tester.tap(replace);
      await frame();
      await tester.tap(find.text('Slot 1: Vapor'));
      await frame();
      expect(run.equippedCombos.first, BetaCombo.mist);
      expect(run.equippedCombos, hasLength(3));
      expect(run.phase, BetaPhase.paused);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
