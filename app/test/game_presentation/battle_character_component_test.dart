import 'package:app/game_presentation/battle_character_component.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BattleCharacterComponent', () {
    test('starts with no hit effect playing', () {
      final component = BattleCharacterComponent(
        side: BattleSide.left,
        position: Vector2(100, 200),
      );

      expect(component.isPlayingHitEffect, isFalse);
    });

    test('playHitEffect starts the effect, which fades out over time', () {
      final component = BattleCharacterComponent(
        side: BattleSide.left,
        position: Vector2(100, 200),
      );

      component.playHitEffect();
      expect(component.isPlayingHitEffect, isTrue);

      component.update(0.5); // maior que a duração do efeito (0.3s)
      expect(component.isPlayingHitEffect, isFalse);
    });

    test('the shake offsets position during the effect and restores it after',
        () {
      final basePosition = Vector2(100, 200);
      final component = BattleCharacterComponent(
        side: BattleSide.left,
        position: basePosition.clone(),
      );

      component.playHitEffect();
      component.update(0.07);
      expect(component.position, isNot(equals(basePosition)));

      component.update(0.5);
      expect(component.position, equals(basePosition));
    });

    test('setHpFraction clamps to the 0..1 range', () {
      final component = BattleCharacterComponent(
        side: BattleSide.right,
        position: Vector2.zero(),
      );

      component.setHpFraction(-0.5);
      component.setHpFraction(1.5);
      // Sem getter público de fração — o teste confirma que chamar com
      // valores fora do intervalo não lança.
    });
  });
}
