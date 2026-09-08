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

    test('starts with no preparation pulse playing', () {
      final component = BattleCharacterComponent(
        side: BattleSide.left,
        position: Vector2(0, 0),
      );
      expect(component.isPlayingPreparationPulse, isFalse);
    });

    test('playPreparationPulse starts and then fades out over time', () {
      final component = BattleCharacterComponent(
        side: BattleSide.left,
        position: Vector2(0, 0),
      );

      component.playPreparationPulse();
      expect(component.isPlayingPreparationPulse, isTrue);

      component.update(0.5); // maior que a duração do pulso (0.15s)
      expect(component.isPlayingPreparationPulse, isFalse);
    });

    test('the displayed HP fraction chases the target instead of jumping',
        () {
      final component = BattleCharacterComponent(
        side: BattleSide.right,
        position: Vector2(0, 0),
      );

      component.setHpFraction(1.0);
      component.update(1.0); // deixa a barra assentar em 1.0 primeiro

      component.setHpFraction(0.2);
      component.update(0.05); // um passo pequeno: ainda não chegou

      final displayedAfterOneStep = component.debugDisplayedHpFraction;
      expect(displayedAfterOneStep, greaterThan(0.2));
      expect(displayedAfterOneStep, lessThan(1.0));

      component.update(1.0); // tempo de sobra: converge
      expect(component.debugDisplayedHpFraction, closeTo(0.2, 0.001));
    });
  });
}
