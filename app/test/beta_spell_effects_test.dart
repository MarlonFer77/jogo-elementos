import 'dart:io';
import 'dart:ui' as ui;
import 'package:app/game_domain/beta_session.dart';
import 'package:app/game_presentation/beta_arena_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'ten spell silhouettes render, pause and expire without changing rules',
    (tester) async {
      final preview = Platform.environment['ELEMENTOS_ART_PREVIEW'] == '1';
      if (preview && Platform.isWindows) {
        await tester.runAsync(() async {
          final bytes = await File(
            'C:/Windows/Fonts/segoeui.ttf',
          ).readAsBytes();
          await (FontLoader(
            'Roboto',
          )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
        });
      }
      final spells = [
        for (final element in BetaElement.values)
          (element, null, element.label),
        for (final combo in BetaCombo.values) (combo.first, combo, combo.label),
      ];
      const size = Size(320, 300);
      for (final impact in [false, true]) {
        final sheet = ui.PictureRecorder();
        final canvas = Canvas(sheet);
        final signatures = <int>{};
        for (var index = 0; index < spells.length; index++) {
          final (element, combo, label) = spells[index];
          final run = BetaSession()..start();
          run.x = -1.6;
          run.enemies
            ..clear()
            ..add(BetaEnemy(BetaEnemyKind.darkElf, .6, 2.4)..cooldown = 100);
          if (impact) {
            run.effects.add(
              BetaEffect(
                0,
                3.4,
                element,
                combo: combo,
                kind: BetaEffectKind.spell,
              )..life = .41,
            );
          } else {
            run.projectiles.add(
              BetaProjectile(0, 3.4, 0, -1, element, combo: combo)..life = 1.1,
            );
          }
          final painter = BetaArenaPainter(run)..advance(.1);
          addTearDown(painter.dispose);
          ui.Picture frame(Size frameSize) {
            final recorder = ui.PictureRecorder();
            painter.paint(Canvas(recorder), frameSize);
            expect(painter.lastSpellFaceCount, inInclusiveRange(1, 200));
            return recorder.endRecording();
          }

          final picture = frame(size);
          // Exercise horizontal, portrait and reduced motion without advancing rules.
          frame(const Size(640, 360)).dispose();
          frame(const Size(360, 640)).dispose();
          painter.reduceMotion = true;
          frame(size).dispose();
          painter.reduceMotion = false;
          run.pause();
          final pauseStart = frame(size);
          painter.advance(.1);
          final paused = frame(size);
          await tester.runAsync(() async {
            Future<int> signature(ui.Picture p) async {
              final image = await p.toImage(320, 300);
              final data = await image.toByteData();
              final hash = Object.hashAll(data!.buffer.asUint8List());
              image.dispose();
              return hash;
            }

            final hash = await signature(picture);
            signatures.add(hash);
            expect(await signature(paused), await signature(pauseStart));
          });
          paused.dispose();
          pauseStart.dispose();
          canvas.save();
          canvas.translate(
            (index % 5) * size.width,
            (index ~/ 5) * size.height,
          );
          canvas.clipRect(Offset.zero & size);
          canvas.save();
          canvas.translate(-size.width / 2, -size.height / 2);
          canvas.scale(2);
          canvas.drawPicture(picture);
          canvas.restore();
          final text = TextPainter(
            text: TextSpan(
              text: label,
              style: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 15,
                color: Colors.white,
                backgroundColor: Color(0xFF253F3A),
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          text.paint(canvas, const Offset(8, 8));
          text.dispose();
          canvas.restore();
          picture.dispose();
          expect(run.hp, 100);
          expect(run.mana, 100);
          expect(run.enemies.single.hp, run.enemies.single.maxHp);
          if (impact) {
            final effect = run.effects.single;
            expect(effect.life, .41);
            for (final life in [.64, .52, .3, .06]) {
              effect.life = life;
              frame(size).dispose();
              expect(effect.life, life); // Drawing must not advance gameplay.
            }
            // Fizzles must not reuse a full damaging-area silhouette.
            run.effects
              ..clear()
              ..add(
                BetaEffect(
                  0,
                  3.4,
                  element,
                  combo: combo,
                  kind: BetaEffectKind.blocked,
                )..life = .41,
              );
            frame(size).dispose();
            run.effects.single.life = 0;
            final recorder = ui.PictureRecorder();
            painter.paint(Canvas(recorder), size);
            recorder.endRecording().dispose();
            expect(painter.lastSpellFaceCount, 0);
          } else {
            expect(run.projectiles.single.life, 1.1);
            run.projectiles.single.life = 0;
            final recorder = ui.PictureRecorder();
            painter.paint(Canvas(recorder), size);
            recorder.endRecording().dispose();
            expect(painter.lastSpellFaceCount, 0);
          }
        }
        expect(signatures, hasLength(10));
        final picture = sheet.endRecording();
        if (preview) {
          await tester.runAsync(() async {
            final image = await picture.toImage(1600, 600);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File(
              'build/gameplay-preview/beta-spells-${impact ? 'impact' : 'flight'}.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        picture.dispose();
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'six mixtures gather both elements before forming; bounded at every stage',
    (tester) async {
      for (final combo in BetaCombo.values) {
        final run = BetaSession()..start();
        run.enemies.clear();
        run.select(combo.first);
        run.mix(combo.second);
        expect(run.cast(), true);
        final mana = run.mana, time = run.time;
        final painter = BetaArenaPainter(run);
        addTearDown(painter.dispose);
        for (final charge in [.01, .2, .44, .45, .7, .98]) {
          run.castTime = run.activeCastDuration * (1 - charge);
          final castTime = run.castTime;
          for (final reduced in [false, true]) {
            painter.reduceMotion = reduced;
            for (final size in [const Size(360, 640), const Size(640, 360)]) {
              final recorder = ui.PictureRecorder();
              painter.paint(Canvas(recorder), size);
              recorder.endRecording().dispose();
              expect(painter.lastSpellFaceCount, inInclusiveRange(1, 200));
            }
          }
          expect(run.castTime, castTime);
          expect(run.mana, mana);
          expect(run.time, time);
          expect(run.projectiles, isEmpty);
        }
      }
      expect(tester.takeException(), isNull);
    },
  );
}
