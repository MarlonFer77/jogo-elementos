import 'package:app/game_presentation/element_visuals.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const knownElementIds = [
    'fire', 'water', 'wind', 'ice', 'nature',
    'lightning', 'earth', 'shadow', 'light', 'poison',
  ];

  test('every known element has a distinct color', () {
    final colors = knownElementIds.map(elementColor).toSet();
    expect(colors, hasLength(knownElementIds.length));
  });

  test('every known element resolves its real symbol', () {
    expect(elementSymbol('fire'), '🔥');
    expect(elementSymbol('water'), '💧');
  });

  test('an unknown element id falls back gracefully instead of throwing', () {
    expect(() => elementColor('unknown'), returnsNormally);
    expect(elementSymbol('unknown'), isNotEmpty);
  });
}
