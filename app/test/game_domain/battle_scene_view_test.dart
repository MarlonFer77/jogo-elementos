import 'package:app/game_domain/attack_event.dart';
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

  test('lastAttack defaults to null and can be set', () {
    const withoutAttack = BattleSceneView(
      leftCurrentHp: 100, leftMaxHp: 100,
      rightCurrentHp: 100, rightMaxHp: 100,
      isLeftTurn: true,
    );
    expect(withoutAttack.lastAttack, isNull);

    const event = AttackEvent(
      sequenceId: 1, attackerIsLeft: true, elementIds: ['fire'],
      damage: 10, appliedStatusNames: [],
    );
    const withAttack = BattleSceneView(
      leftCurrentHp: 90, leftMaxHp: 100,
      rightCurrentHp: 100, rightMaxHp: 100,
      isLeftTurn: false,
      lastAttack: event,
    );
    expect(withAttack.lastAttack, same(event));
  });

  test('leftLabel/rightLabel default to generic text and can be set', () {
    const withoutLabels = BattleSceneView(
      leftCurrentHp: 100, leftMaxHp: 100,
      rightCurrentHp: 100, rightMaxHp: 100,
      isLeftTurn: true,
    );
    expect(withoutLabels.leftLabel, 'Esquerda');
    expect(withoutLabels.rightLabel, 'Direita');

    const withLabels = BattleSceneView(
      leftCurrentHp: 100, leftMaxHp: 100,
      rightCurrentHp: 100, rightMaxHp: 100,
      isLeftTurn: true,
      leftLabel: 'Jogador A',
      rightLabel: 'Jogador B',
    );
    expect(withLabels.leftLabel, 'Jogador A');
    expect(withLabels.rightLabel, 'Jogador B');
  });
}
