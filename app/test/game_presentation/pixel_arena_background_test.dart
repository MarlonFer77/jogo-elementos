import 'dart:ui';

import 'package:app/game_presentation/pixel_arena_background.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('drawArenaBackdrop does not throw for a valid size', () {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    expect(
      () => drawArenaBackdrop(canvas, const Size(320, 200)),
      returnsNormally,
    );
  });

  test('ArenaBackdropPainter never requests a repaint', () {
    final painter = ArenaBackdropPainter();
    expect(painter.shouldRepaint(painter), isFalse);
  });
}
