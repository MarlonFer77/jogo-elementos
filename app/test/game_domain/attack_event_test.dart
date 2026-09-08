import 'package:app/game_domain/attack_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('holds the values it was constructed with', () {
    const event = AttackEvent(
      sequenceId: 1,
      attackerIsLeft: true,
      elementIds: ['fire', 'wind'],
      comboName: 'Tempestade Ígnea',
      damage: 20,
      appliedStatusNames: ['Queimadura'],
    );

    expect(event.sequenceId, 1);
    expect(event.attackerIsLeft, isTrue);
    expect(event.elementIds, ['fire', 'wind']);
    expect(event.comboName, 'Tempestade Ígnea');
    expect(event.damage, 20);
    expect(event.appliedStatusNames, ['Queimadura']);
  });
}
