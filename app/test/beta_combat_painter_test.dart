import 'dart:io';
import 'dart:ui' as ui;
import 'package:app/game_domain/beta_session.dart';
import 'package:app/game_presentation/beta_arena_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  BetaArenaPainter painterFor(BetaSession run) {
    final painter = BetaArenaPainter(run);
    addTearDown(painter.dispose);
    return painter;
  }

  testWidgets('label cache is bounded, reused and released', (tester) async {
    final run = BetaSession()..start();
    final painter = painterFor(run);
    void paint() {
      final recorder = ui.PictureRecorder();
      painter.paint(Canvas(recorder), const Size(360, 640));
      recorder.endRecording().dispose();
    }

    for (var i = 0; i < 80; i++) {
      run.effects
        ..clear()
        ..add(BetaEffect(run.x, run.z, run.element, text: '-$i'));
      paint();
    }
    expect(painter.cachedLabelCount, BetaArenaPainter.labelCacheLimit);
    paint();
    expect(painter.cachedLabelCount, BetaArenaPainter.labelCacheLimit);
    painter.dispose();
    expect(painter.cachedLabelCount, 0);
  });

  testWidgets('combat renders windup, contact, recovery, cast and death', (
    tester,
  ) async {
    final preview = Platform.environment['ELEMENTOS_ART_PREVIEW'] == '1';
    if (preview && Platform.isWindows) {
      await tester.runAsync(() async {
        final bytes = await File('C:/Windows/Fonts/segoeui.ttf').readAsBytes();
        await (FontLoader(
          'BetaPreview',
        )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
        await (FontLoader(
          'Roboto',
        )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      });
    }
    var recorder = ui.PictureRecorder();
    var canvas = Canvas(recorder);
    const size = Size(400, 280);
    var index = 0;
    BetaSession duel() {
      final run = BetaSession()..start();
      run.enemies
        ..clear()
        ..add(BetaEnemy(BetaEnemyKind.goblin, .2, 3.3)..cooldown = 10);
      return run;
    }

    void advance(BetaSession run, BetaArenaPainter painter, double seconds) {
      for (var t = 0.0; t < seconds - .00001; t += .01) {
        run.update(.01);
        painter.advance(.01);
      }
    }

    void frame(BetaArenaPainter painter, String label) {
      canvas.save();
      canvas.translate((index % 2) * size.width, (index ~/ 2) * size.height);
      canvas.save();
      canvas.clipRect(Offset.zero & size);
      canvas.translate(-size.width / 2, -size.height / 2);
      canvas.scale(2);
      painter.paint(canvas, size);
      canvas.restore();
      final text = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            fontFamily: 'BetaPreview',
            color: Colors.white,
            fontSize: 14,
            backgroundColor: Color(0xFF203B35),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, const Offset(8, 8));
      text.dispose();
      canvas.restore();
      index++;
    }

    final sword = duel()..sword();
    final swordPainter = painterFor(sword);
    advance(sword, swordPainter, .08);
    frame(swordPainter, 'Espada: preparação (80ms)');
    advance(sword, swordPainter, .09);
    frame(swordPainter, 'Espada: contato + dano (170ms)');
    expect(sword.enemies.single.hp, 25);
    advance(sword, swordPainter, .13);
    frame(swordPainter, 'Espada: recuperação (300ms)');
    final magic = duel()
      ..select(BetaElement.water)
      ..cast();
    final magicPainter = painterFor(magic);
    advance(magic, magicPainter, .22);
    frame(magicPainter, 'Magia: canalização');
    final enemy = duel();
    enemy.enemies.single
      ..windup = .14
      ..aimX = enemy.x
      ..aimZ = enemy.z;
    final enemyPainter = painterFor(enemy);
    advance(enemy, enemyPainter, .02);
    frame(enemyPainter, 'Inimigo: golpe anunciado');
    advance(enemy, enemyPainter, .14);
    frame(enemyPainter, 'Inimigo: impacto + reação');
    expect(enemy.hurtTime, greaterThan(0));
    final death = duel()..wave = 3;
    death.enemies.single.hp = 1;
    death.sword();
    final deathPainter = painterFor(death);
    advance(death, deathPainter, .38);
    frame(deathPainter, 'Criatura: queda');
    advance(death, deathPainter, .36);
    frame(deathPainter, 'Fim: antes do resultado');
    for (final element in BetaElement.values) {
      final run = duel()
        ..select(element)
        ..hp = 80;
      run.enemies.single
        ..x = 1.8
        ..z = 2.5
        ..cooldown = 10;
      run.cast();
      final painter = painterFor(run);
      advance(run, painter, .47);
      frame(painter, '${element.label}: projétil e alvo');
      advance(run, painter, .2);
      frame(painter, '${element.label}: impacto');
    }
    Future<void> save(String name) async {
      final picture = recorder.endRecording();
      await tester.runAsync(() async {
        final image = await picture.toImage(
          800,
          (index ~/ 2) * size.height.toInt(),
        );
        if (preview) {
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('build/gameplay-preview/$name.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
        }
        image.dispose();
      });
      picture.dispose();
    }

    await save('beta-combat-polish');
    recorder = ui.PictureRecorder();
    canvas = Canvas(recorder);
    index = 0;
    for (final kind in BetaEnemyKind.values) {
      final run = duel();
      final enemy = BetaEnemy(kind, 1, 3.4)..beginAttack(run.x, run.z);
      run.enemies
        ..clear()
        ..add(enemy);
      final painter = painterFor(run);
      advance(run, painter, enemy.preparation - enemy.strikeDuration - .03);
      frame(painter, '${enemy.label}: ${enemy.attackLabel}');
      advance(run, painter, enemy.strikeDuration + .11);
      frame(painter, '${enemy.label}: recuperação');
      expect(enemy.recovery, greaterThan(0));
    }
    await save('beta-enemy-polish');
    expect(tester.takeException(), isNull);
  });
}
