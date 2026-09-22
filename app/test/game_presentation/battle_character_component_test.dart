import 'package:app/game_presentation/battle_character_component.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('frozen presentation state can be toggled independently', () {
    final component = BattleCharacterComponent(
      side: BattleSide.left,
      position: Vector2.zero(),
    );
    expect(component.isFrozen, isFalse);
    component.setFrozen(true);
    expect(component.isFrozen, isTrue);
    component.setFrozen(false);
    expect(component.isFrozen, isFalse);
  });
  test('reposition updates the resting anchor during idle and hit effects', () {
    final character = BattleCharacterComponent(
      side: BattleSide.left,
      position: Vector2(90, 200),
    );
    character.playHitEffect();
    character.reposition(Vector2(180, 300));
    character.update(.1);
    expect(character.position.x, closeTo(180, 14));
    character.update(1);
    expect(character.position.x, 180);
    expect(character.position.y, closeTo(300, 2));
  });

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

    test(
      'the shake offsets position.x during the effect and restores it after',
      () {
        final basePosition = Vector2(100, 200);
        final component = BattleCharacterComponent(
          side: BattleSide.left,
          position: basePosition.clone(),
        );

        component.playHitEffect();
        component.update(0.07);
        expect(component.position.x, isNot(equals(basePosition.x)));

        component.update(0.5);
        expect(component.position.x, equals(basePosition.x));
      },
    );

    test('the idle bob moves position.y sinusoidally around the base '
        'position, independent of the shake', () {
      final basePosition = Vector2(100, 200);
      final component = BattleCharacterComponent(
        side: BattleSide.left,
        position: basePosition.clone(),
      );

      component.update(0.4); // 1/4 do ciclo de 1.6s: seno no pico (+1)
      expect(component.position.y, closeTo(202.0, 0.0001));

      component.update(0.4); // 1/2 do ciclo: seno de volta a 0
      expect(component.position.y, closeTo(200.0, 0.0001));

      component.update(0.4); // 3/4 do ciclo: seno no fundo (-1)
      expect(component.position.y, closeTo(198.0, 0.0001));
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
  });
}
