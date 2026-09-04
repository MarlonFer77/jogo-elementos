import 'package:app/game_domain/combination_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('byId finds a known combination by its result id', () {
    const catalog = CombinationCatalog();
    final option = catalog.byId('ignited_storm');
    expect(option?.name, 'Tempestade Ígnea');
  });

  test('byId returns null for an unknown id', () {
    const catalog = CombinationCatalog();
    expect(catalog.byId('nope'), isNull);
  });
}
