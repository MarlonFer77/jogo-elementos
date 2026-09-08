import 'package:app/game_domain/battle_scene_view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('holds the values it was constructed with', () {
    const view = BattleSceneView(
      leftCurrentHp: 80,
      leftMaxHp: 100,
      rightCurrentHp: 60,
      rightMaxHp: 100,
      isLeftTurn: true,
    );

    expect(view.leftCurrentHp, 80);
    expect(view.leftMaxHp, 100);
    expect(view.rightCurrentHp, 60);
    expect(view.rightMaxHp, 100);
    expect(view.isLeftTurn, isTrue);
  });
}
