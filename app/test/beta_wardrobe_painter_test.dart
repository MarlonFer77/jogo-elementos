import 'dart:io';
import 'dart:ui' as ui;
import 'package:app/game_domain/beta_session.dart';
import 'package:app/game_domain/cosmetics.dart';
import 'package:app/game_presentation/beta_arena_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'new silhouettes and equipped techniques render in real actor poses',
    (tester) async {
      const size = Size(320, 320);
      final recorder = ui.PictureRecorder(), signatures = <int>{};
      final canvas = Canvas(recorder);
      final cases = [
        (HeroOutfit.angel, const BetaLoadout(), null),
        (HeroOutfit.demon, const BetaLoadout(), null),
        (HeroOutfit.arthur, const BetaLoadout(), null),
        (
          HeroOutfit.arthur,
          const BetaLoadout(
            weapon: ShopUpgrade.excalibur,
            armor: ShopUpgrade.perseus,
            cloak: ShopUpgrade.mercerus,
          ),
          BetaAction.cast,
        ),
        (
          HeroOutfit.angel,
          const BetaLoadout(sword: ShopUpgrade.leap),
          BetaAction.sword,
        ),
        (
          HeroOutfit.demon,
          const BetaLoadout(dodge: ShopUpgrade.somersault),
          BetaAction.dodge,
        ),
        (
          HeroOutfit.arthur,
          const BetaLoadout(sword: ShopUpgrade.spin),
          BetaAction.sword,
        ),
        (
          HeroOutfit.demon,
          const BetaLoadout(weapon: ShopUpgrade.excalibur),
          null,
        ),
      ];
      for (var i = 0; i < cases.length; i++) {
        final (outfit, loadout, action) = cases[i];
        final run = BetaSession(loadout: loadout)..start();
        run.enemies.clear();
        run.angle = .5;
        final painter = BetaArenaPainter(
          run,
          outfit: outfit,
          wardrobePreview: true,
        );
        if (action != null) {
          run.request(action);
          final frames = action == BetaAction.cast
              ? 30
              : action == BetaAction.dodge
              ? 12
              : 7;
          for (var frame = 0; frame < frames; frame++) {
            run.update(1 / 60);
            painter.advance(1 / 60);
          }
        }
        final local = ui.PictureRecorder();
        painter.paint(Canvas(local), size);
        final picture = local.endRecording();
        canvas.save();
        canvas.translate((i % 4) * 320, (i ~/ 4) * 320);
        canvas.drawPicture(picture);
        canvas.restore();
        await tester.runAsync(() async {
          final image = await picture.toImage(320, 320);
          final bytes = await image.toByteData();
          signatures.add(Object.hashAll(bytes!.buffer.asUint8List()));
          image.dispose();
        });
        picture.dispose();
        painter.dispose();
      }
      final montage = recorder.endRecording();
      if (Platform.environment['ELEMENTOS_ART_PREVIEW'] == '1') {
        await tester.runAsync(() async {
          final image = await montage.toImage(1280, 640);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('build/gameplay-preview/wardrobe-collection.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      montage.dispose();
      expect(signatures, hasLength(cases.length));
    },
  );
}
