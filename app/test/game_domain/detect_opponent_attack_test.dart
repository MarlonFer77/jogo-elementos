import 'package:app/game_domain/detect_opponent_attack.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('returns null when no new field effect appeared', () {
    final result = detectOpponentAttack(
      previousFieldEffectIds: {'ignited_storm'},
      newFieldEffectIds: {'ignited_storm'},
      myHpBefore: 100,
      myHpAfter: 100,
      sequenceId: 1,
    );
    expect(result, isNull);
  });

  test('returns null when a new effect appeared but my HP did not drop '
      '(defensive — should not happen per game rules, but never guess)', () {
    final result = detectOpponentAttack(
      previousFieldEffectIds: {},
      newFieldEffectIds: {'ignited_storm'},
      myHpBefore: 100,
      myHpAfter: 100,
      sequenceId: 1,
    );
    expect(result, isNull);
  });

  test('builds an AttackEvent from a newly-appeared known combination', () {
    final result = detectOpponentAttack(
      previousFieldEffectIds: {},
      newFieldEffectIds: {'ignited_storm'},
      myHpBefore: 100,
      myHpAfter: 80,
      sequenceId: 7,
    );

    expect(result, isNotNull);
    expect(result!.sequenceId, 7);
    expect(result.attackerIsLeft, isFalse); // o oponente é sempre "direita"
    expect(result.comboName, 'Tempestade Ígnea');
    expect(result.elementIds, containsAll(['fire', 'wind']));
    expect(result.damage, 20);
    expect(result.appliedStatusNames, isEmpty);
  });

  test('returns null for a newly-appeared id the catalog does not '
      'recognize (defensive)', () {
    final result = detectOpponentAttack(
      previousFieldEffectIds: {},
      newFieldEffectIds: {'unknown_effect'},
      myHpBefore: 100,
      myHpAfter: 80,
      sequenceId: 1,
    );
    expect(result, isNull);
  });
}
