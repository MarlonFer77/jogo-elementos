import 'dart:io';
import 'dart:ui';

import 'package:app/game_presentation/battle_character_component.dart';
import 'package:app/game_presentation/pixel_arena_background.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final size in [const Size(360, 300), const Size(480, 240)]) {
    test(
      'rasterizes arena, mirrored swords and channel hands at $size',
      () async {
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);
        drawBattleArena(canvas, size);
        for (final side in BattleSide.values) {
          final character = BattleCharacterComponent(
            side: side,
            position: Vector2.zero(),
          );
          character.setActionPose(
            swordElement: side == BattleSide.left ? 'fire' : 'ice',
            strike: .55,
          );
          canvas.save();
          canvas.translate(
            size.width * (side == BattleSide.left ? .25 : .75) - 32,
            size.height * .85 - 80,
          );
          character.render(canvas);
          canvas.restore();
        }
        final picture = recorder.endRecording();
        final image = await picture.toImage(
          size.width.toInt(),
          size.height.toInt(),
        );
        final bytes = await image.toByteData(format: ImageByteFormat.png);
        expect(bytes, isNotNull);
        expect(bytes!.lengthInBytes, greaterThan(1000));
        if (Platform.environment['ELEMENTOS_ART_PREVIEW'] == '1') {
          final directory = Directory('build/art-preview')
            ..createSync(recursive: true);
          File(
            '${directory.path}/arena-${size.width.toInt()}.png',
          ).writeAsBytesSync(bytes.buffer.asUint8List());
        }
        image.dispose();
        picture.dispose();
        // Explicitly render the other poses too: hands must work without a weapon.
        final poses = PictureRecorder();
        final poseCanvas = Canvas(poses);
        final caster = BattleCharacterComponent(
          side: BattleSide.right,
          position: Vector2.zero(),
        );
        for (final charge in [0.0, .5, 1.0]) {
          caster.setActionPose(charge: charge);
          caster.render(poseCanvas);
          expect(caster.swordElement, isNull);
        }
        poses.endRecording().dispose();
      },
    );
  }
  test('arena safely ignores empty sizes', () {
    final recorder = PictureRecorder();
    drawBattleArena(Canvas(recorder), Size.zero);
    recorder.endRecording().dispose();
  });
}
