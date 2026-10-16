import 'dart:io';
import 'dart:ui' as ui;
import 'package:app/game_domain/beta_session.dart';
import 'package:app/game_presentation/beta_arena_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/beta_puzzle_fixture.dart';

void main() {
  BetaArenaPainter painterFor(BetaSession run) {
    final painter = BetaArenaPainter(run);
    addTearDown(painter.dispose);
    return painter;
  }

  testWidgets('six regions render distinct scenery in both orientations', (
    tester,
  ) async {
    final preview = Platform.environment['ELEMENTOS_ART_PREVIEW'] == '1';
    if (preview && Platform.isWindows) {
      await tester.runAsync(() async {
        final bytes = await File('C:/Windows/Fonts/segoeui.ttf').readAsBytes();
        await (FontLoader(
          'Roboto',
        )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      });
    }
    for (final size in [const Size(360, 640), const Size(640, 360)]) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final signatures = <int>{};
      for (final region in BetaRegion.values) {
        final run = BetaSession()..wave = region.index + 1;
        run.z = 1.5;
        run.start();
        final painter = painterFor(run);
        final localRecorder = ui.PictureRecorder();
        painter.paint(Canvas(localRecorder), size);
        // Static detailing stays bounded; rotating the screen reuses the scene.
        expect(painter.cachedSceneryFaceCount, inInclusiveRange(1, 2600));
        final scene = localRecorder.endRecording();
        canvas.save();
        canvas.translate(region.index * size.width, 0);
        canvas.drawPicture(scene);
        final label = TextPainter(
          text: TextSpan(
            text: region.title,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFFFFE2A3),
              fontFamily: 'Roboto',
              backgroundColor: Color(0xEE243F3D),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        label.paint(canvas, const Offset(10, 12));
        label.dispose();
        canvas.restore();
        await tester.runAsync(() async {
          final image = await scene.toImage(
            size.width.toInt(),
            size.height.toInt(),
          );
          final bytes = await image.toByteData();
          signatures.add(Object.hashAll(bytes!.buffer.asUint8List()));
          image.dispose();
        });
        scene.dispose();
      }
      final picture = recorder.endRecording();
      if (preview) {
        await tester.runAsync(() async {
          final image = await picture.toImage(
            size.width.toInt() * BetaRegion.values.length,
            size.height.toInt(),
          );
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            'build/gameplay-preview/beta-world-${size.width.toInt()}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      picture.dispose();
      expect(signatures, hasLength(BetaRegion.values.length));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('restoration changes every region with bounded scenery', (
    tester,
  ) async {
    for (final region in BetaRegion.values) {
      final run = BetaSession()..wave = region.index + 1;
      run.start();
      run.enemies.clear();
      run.z = 1.5;
      final painter = painterFor(run)..reduceMotion = true;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final signatures = <int>{};
      for (var state = 0; state < 2; state++) {
        if (state == 1) restorePuzzle(run);
        final local = ui.PictureRecorder();
        painter.paint(Canvas(local), const Size(640, 360));
        expect(painter.cachedSceneryFaceCount, inInclusiveRange(1, 2600));
        final scene = local.endRecording();
        canvas.save();
        canvas.translate(state * 640.0, 0);
        canvas.drawPicture(scene);
        canvas.restore();
        await tester.runAsync(() async {
          final image = await scene.toImage(640, 360);
          final bytes = await image.toByteData();
          signatures.add(Object.hashAll(bytes!.buffer.asUint8List()));
          image.dispose();
        });
        scene.dispose();
      }
      expect(signatures, hasLength(2));
      final picture = recorder.endRecording();
      if (Platform.environment['ELEMENTOS_ART_PREVIEW'] == '1') {
        await tester.runAsync(() async {
          final image = await picture.toImage(1280, 360);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            'build/gameplay-preview/beta-restoration-${region.name}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      picture.dispose();
    }
  });

  testWidgets('reduced motion removes camera shake, not the arena', (
    tester,
  ) async {
    final run = BetaSession()..start();
    final painter = painterFor(run)..reduceMotion = true;
    painter.advance(.06);
    Future<List<int>> pixels() async {
      final recorder = ui.PictureRecorder();
      painter.paint(Canvas(recorder), const Size(360, 640));
      final picture = recorder.endRecording();
      final image = await picture.toImage(360, 640);
      final data = await image.toByteData();
      final result = data!.buffer.asUint8List().toList();
      image.dispose();
      picture.dispose();
      return result;
    }

    await tester.runAsync(() async {
      final resting = await pixels();
      run.impactTime = .18;
      expect(await pixels(), orderedEquals(resting));
      painter.reduceMotion = false;
      expect(await pixels(), isNot(orderedEquals(resting)));
    });
    expect(run.impactTime, .18); // Accessibility must not mutate the rules.
  });

  testWidgets('six combo channels and impacts render with bounded effects', (
    tester,
  ) async {
    if (Platform.environment['ELEMENTOS_ART_PREVIEW'] == '1' &&
        Platform.isWindows) {
      await tester.runAsync(() async {
        final bytes = await File('C:/Windows/Fonts/segoeui.ttf').readAsBytes();
        await (FontLoader(
          'Roboto',
        )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      });
    }
    const size = Size(360, 300);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    for (final combo in BetaCombo.values) {
      final run = BetaSession()..start();
      run.enemies
        ..clear()
        ..add(BetaEnemy(BetaEnemyKind.guardian, 0, 3.4)..cooldown = 100);
      run.select(combo.first);
      run.mix(combo.second);
      run.cast();
      run.update(.1);
      final painter = painterFor(run);
      final channel = ui.PictureRecorder();
      painter.paint(Canvas(channel), size);
      channel.endRecording().dispose();
      for (var i = 0; i < 70 && run.discoveredCombos.isEmpty; i++) {
        run.update(.01);
        painter.advance(.01);
      }
      expect(run.discoveredCombos, contains(combo));
      expect(run.effects.any((e) => e.combo == combo), true);
      for (var i = 0; i < 24; i++) {
        run.update(.01);
        painter.advance(.01);
      }
      canvas.save();
      canvas.translate(
        (combo.index % 3) * size.width,
        (combo.index ~/ 3) * size.height,
      );
      canvas.clipRect(Offset.zero & size);
      canvas.save();
      canvas.translate(-size.width / 2, -size.height / 2);
      canvas.scale(2);
      painter.paint(canvas, size);
      canvas.restore();
      final label = TextPainter(
        text: TextSpan(
          text: '${combo.label} · ${combo.recipe}',
          style: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 13,
            color: Colors.white,
            backgroundColor: Color(0xFF243F38),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width - 16);
      label.paint(canvas, const Offset(8, 8));
      label.dispose();
      canvas.restore();
      expect(
        painter.cachedLabelCount,
        lessThanOrEqualTo(BetaArenaPainter.labelCacheLimit),
      );
    }
    final picture = recorder.endRecording();
    if (Platform.environment['ELEMENTOS_ART_PREVIEW'] == '1') {
      await tester.runAsync(() async {
        final image = await picture.toImage(1080, 600);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/gameplay-preview/beta-combo-effects.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }
    picture.dispose();
    expect(tester.takeException(), isNull);
  });

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
    for (final life in [.5, .15, .08, .01]) {
      run.effects.single.life = life;
      paint();
    }
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
    final death = duel()..wave = BetaRegion.values.length;
    restorePuzzle(death);
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
      advance(run, painter, enemy.preparation - .04);
      frame(painter, '${enemy.label}: golpe em movimento');
      advance(run, painter, .07);
      frame(painter, '${enemy.label}: contato');
    }
    await save('beta-mob-strikes');
    recorder = ui.PictureRecorder();
    canvas = Canvas(recorder);
    index = 0;
    for (final kind in BetaEnemyKind.values) {
      final run = duel()..x = -1.2;
      final enemy = BetaEnemy(kind, 1, 3.4)..moving = true;
      run.enemies
        ..clear()
        ..add(enemy);
      final painter = painterFor(run)..advance(.1);
      frame(painter, '${enemy.label}: silhueta em movimento');
      enemy
        ..hp = 0
        ..moving = false
        ..deathTime = BetaSession.deathDuration * .3;
      frame(painter, '${enemy.label}: queda');
    }
    await save('beta-creature-designs');
    recorder = ui.PictureRecorder();
    canvas = Canvas(recorder);
    index = 0;
    for (final combined in [false, true]) {
      final run = duel()..select(BetaElement.fire);
      run.enemies.single
        ..z = 2
        ..cooldown = 100;
      if (combined) run.mix(BetaElement.wind);
      run.cast();
      final painter = painterFor(run);
      final duration = run.activeCastDuration;
      var time = 0.0;
      for (final targetTime in [
        duration * .25,
        duration * .75,
        duration + .02,
        duration + .09,
        duration + .18,
        duration + .29,
      ]) {
        advance(run, painter, targetTime - time);
        time = targetTime;
        frame(
          painter,
          '${combined ? 'Combo' : 'Fogo'}: ${(time * 1000).round()}ms',
        );
      }
    }
    await save('beta-magic-casting');
    for (final direction in [
      ('frente', 0.0, -1.0),
      ('tras', 0.0, 1.0),
      ('direita', 1.0, 0.0),
      ('esquerda', -1.0, 0.0),
    ]) {
      recorder = ui.PictureRecorder();
      canvas = Canvas(recorder);
      index = 0;
      final run = duel();
      run.enemies.clear();
      run.setMovement(direction.$2, direction.$3);
      run.dodge();
      run.setMovement(0, 0);
      final painter = painterFor(run);
      var time = 0.0;
      for (final targetTime in [0.0, .06, .11, .18, .25, .32, .39, .46]) {
        advance(run, painter, targetTime - time);
        time = targetTime;
        frame(painter, 'Rolar ${direction.$1}: ${(time * 1000).round()}ms');
      }
      expect(run.dodgeTime, 0);
      await save('beta-roll-${direction.$1}');
    }
    if (preview) {
      recorder = ui.PictureRecorder();
      canvas = Canvas(recorder);
      index = 0;
      for (final kind in BetaEnemyKind.values) {
        final run = duel();
        final enemy = BetaEnemy(kind, 0, 3.4)..beginAttack(run.x, run.z);
        run.enemies
          ..clear()
          ..add(enemy);
        final painter = painterFor(run);
        advance(run, painter, .3);
        frame(painter, '${enemy.label}: dentro da área');
        run.x = kind == BetaEnemyKind.goblin ? .8 : 2.4;
        frame(painter, '${enemy.label}: fora da área');
      }
      final blocked = duel()
        ..x = 2.9
        ..z = 2;
      final attacker = blocked.enemies.single
        ..x = 5.1
        ..z = 2;
      attacker.beginAttack(blocked.x, blocked.z);
      final painter = painterFor(blocked);
      frame(painter, 'Coluna bloqueia o golpe');
      attacker.cancelAttack();
      frame(painter, 'Ameaça cancelada');
      await save('beta-danger-polish');
      recorder = ui.PictureRecorder();
      canvas = Canvas(recorder);
      index = 0;
      for (final direction in [
        ('Frente', 0.0, -1.0),
        ('Lateral', 1.0, 0.0),
        ('Recuo', 0.0, 1.0),
      ]) {
        final run = duel()
          ..setMovement(direction.$2, direction.$3)
          ..dodge();
        final painter = painterFor(run);
        advance(run, painter, .12);
        frame(painter, '${direction.$1}: esquiva');
        advance(run, painter, .1);
        frame(painter, '${direction.$1}: assentando');
      }
      final released = duel()
        ..select(BetaElement.water)
        ..cast();
      final releasePainter = painterFor(released);
      advance(released, releasePainter, .38);
      frame(releasePainter, 'Magia: retorno do braço');
      advance(released, releasePainter, .15);
      frame(releasePainter, 'Magia: repouso');
      await save('beta-motion-polish');
      recorder = ui.PictureRecorder();
      canvas = Canvas(recorder);
      index = 0;
      for (final hurt in [false, true]) {
        final run = duel();
        final target = run.enemies.single;
        final effect = BetaEffect(
          hurt ? run.x : target.x,
          hurt ? run.z : target.z,
          BetaElement.water,
          text: hurt ? '-12' : '13',
          hurt: hurt,
        );
        run.effects.add(effect);
        final painter = painterFor(run);
        for (final life in [.62, .52, .14, .03]) {
          effect.life = life;
          frame(
            painter,
            '${hurt ? 'Dano recebido' : 'Acerto'}: ${((.65 - life) * 1000).round()}ms',
          );
        }
      }
      await save('beta-contact-polish');
      recorder = ui.PictureRecorder();
      canvas = Canvas(recorder);
      index = 0;
      for (final kind in [BetaEnemyKind.goblin, BetaEnemyKind.guardian]) {
        final run = duel();
        final enemy = BetaEnemy(kind, .2, 3.3)..cooldown = 10;
        run.enemies
          ..clear()
          ..add(enemy);
        final painter = painterFor(run);
        enemy.hp = enemy.maxHp * .45;
        painter.advance(.01);
        frame(painter, '${enemy.label}: perda recente');
        for (var i = 0; i < 7; i++) {
          painter.advance(.1);
        }
        frame(painter, '${enemy.label}: HP consolidado');
      }
      await save('beta-health-polish');
    }
    expect(tester.takeException(), isNull);
  });
}
