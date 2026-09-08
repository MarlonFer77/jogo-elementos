import 'dart:ui';

import 'package:app/game_presentation/pixel_sprite.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('trainerSpriteGrid is 20 rows of 16 columns each', () {
    expect(trainerSpriteGrid, hasLength(20));
    for (final row in trainerSpriteGrid) {
      expect(row, hasLength(16));
    }
  });

  test('every pixel index in the grid has a matching palette entry', () {
    final maxIndex =
        trainerSpriteGrid.expand((row) => row).reduce((a, b) => a > b ? a : b);
    expect(pixelPaletteLeft.length, greaterThan(maxIndex));
    expect(pixelPaletteRight.length, greaterThan(maxIndex));
  });

  test('left and right palettes differ only in the accent colors (indices '
      '4 and 5)', () {
    expect(pixelPaletteLeft[4], isNot(equals(pixelPaletteRight[4])));
    expect(pixelPaletteLeft[5], isNot(equals(pixelPaletteRight[5])));
    expect(pixelPaletteLeft[1], equals(pixelPaletteRight[1])); // contorno
    expect(pixelPaletteLeft[2], equals(pixelPaletteRight[2])); // pele
    expect(pixelPaletteLeft[3], equals(pixelPaletteRight[3])); // detalhe
    expect(pixelPaletteLeft[6], equals(pixelPaletteRight[6])); // cinto
  });

  test('drawPixelGrid does not throw for a valid grid and palette', () {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    expect(
      () => drawPixelGrid(
        canvas,
        const [
          [0, 1],
          [1, 0],
        ],
        const [Color(0x00000000), Color(0xFF000000)],
        pixelSize: 4,
      ),
      returnsNormally,
    );
  });
}
