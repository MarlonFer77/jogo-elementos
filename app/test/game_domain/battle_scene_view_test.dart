import 'package:app/game_domain/attack_event.dart';
import 'package:app/game_domain/battle_scene_view.dart';
import 'package:app/game_domain/effect_badge_view.dart';
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

  test('leftStatuses/rightStatuses/fieldEffects default to empty and can '
      'be set', () {
    const withoutBadges = BattleSceneView(
      leftCurrentHp: 100, leftMaxHp: 100,
      rightCurrentHp: 100, rightMaxHp: 100,
      isLeftTurn: true,
    );
    expect(withoutBadges.leftStatuses, isEmpty);
    expect(withoutBadges.rightStatuses, isEmpty);
    expect(withoutBadges.fieldEffects, isEmpty);

    const withBadges = BattleSceneView(
      leftCurrentHp: 100, leftMaxHp: 100,
      rightCurrentHp: 100, rightMaxHp: 100,
      isLeftTurn: true,
      leftStatuses: [EffectBadgeView(id: 'burn', remainingTurns: 2)],
      rightStatuses: [EffectBadgeView(id: 'shield')],
      fieldEffects: [EffectBadgeView(id: 'ignited_storm')],
    );
    expect(withBadges.leftStatuses, [const EffectBadgeView(id: 'burn', remainingTurns: 2)]);
    expect(withBadges.rightStatuses, [const EffectBadgeView(id: 'shield')]);
    expect(withBadges.fieldEffects, [const EffectBadgeView(id: 'ignited_storm')]);
  });

  test('leftAp/leftApMax/rightAp/rightApMax default to 0/5 and can be set',
      () {
    const withoutAp = BattleSceneView(
      leftCurrentHp: 100, leftMaxHp: 100,
      rightCurrentHp: 100, rightMaxHp: 100,
      isLeftTurn: true,
    );
    expect(withoutAp.leftAp, 0);
    expect(withoutAp.leftApMax, 5);
    expect(withoutAp.rightAp, 0);
    expect(withoutAp.rightApMax, 5);

    const withAp = BattleSceneView(
      leftCurrentHp: 100, leftMaxHp: 100,
      rightCurrentHp: 100, rightMaxHp: 100,
      isLeftTurn: true,
      leftAp: 3,
      rightAp: 5,
    );
    expect(withAp.leftAp, 3);
    expect(withAp.rightAp, 5);
  });
}
