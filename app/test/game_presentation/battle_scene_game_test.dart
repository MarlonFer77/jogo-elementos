import 'package:app/game_domain/battle_scene_view.dart';
import 'package:app/game_presentation/battle_scene_game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('didTakeDamage', () {
    test('no previous value is never damage (first update)', () {
      expect(didTakeDamage(previousHp: null, currentHp: 50), isFalse);
    });

    test('lower hp than before counts as damage', () {
      expect(didTakeDamage(previousHp: 50, currentHp: 30), isTrue);
    });

    test('equal hp does not count as damage', () {
      expect(didTakeDamage(previousHp: 50, currentHp: 50), isFalse);
    });

    test('higher hp than before does not count as damage', () {
      expect(didTakeDamage(previousHp: 50, currentHp: 60), isFalse);
    });
  });

  group('BattleSceneGame.updateView', () {
    test('does not throw when called before the game has finished loading',
        () {
      final game = BattleSceneGame();

      expect(
        () => game.updateView(
          const BattleSceneView(
            leftCurrentHp: 100,
            leftMaxHp: 100,
            rightCurrentHp: 100,
            rightMaxHp: 100,
            isLeftTurn: true,
          ),
        ),
        returnsNormally,
      );
    });
  });
}
