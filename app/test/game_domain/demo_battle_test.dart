import 'package:app/game_domain/demo_battle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DemoBattle.start resolves the Fogo + Vento combination onto the '
      'field', () {
    final view = DemoBattle.start();

    expect(view.playerAName, equals('Ana'));
    expect(view.playerBName, equals('Beto'));
    expect(view.currentTurnName, equals('Beto'));
    expect(view.activeFieldEffectNames, equals(['Tempestade Ígnea']));
  });
}
