import 'package:app/game_domain/attack_event.dart';
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

  group('BattleSceneGame attack sequence gating', () {
    test('the same sequenceId is not replayed on a second updateView call',
        () {
      final game = BattleSceneGame();
      const attack = AttackEvent(
        sequenceId: 5,
        attackerIsLeft: true,
        elementIds: ['fire'],
        damage: 10,
        appliedStatusNames: [],
      );

      // Só verifica que chamar duas vezes com o mesmo sequenceId não lança
      // — o comportamento fino (não duplicar o componente na árvore) é
      // coberto pela verificação manual (flutter run -d web-server), já
      // que testar a árvore de componentes exigiria montar o FlameGame de
      // verdade (ver decisão de escopo da Task 5 do bloco anterior).
      expect(
        () {
          game.updateView(const BattleSceneView(
            leftCurrentHp: 90, leftMaxHp: 100,
            rightCurrentHp: 100, rightMaxHp: 100,
            isLeftTurn: false, lastAttack: attack,
          ));
          game.updateView(const BattleSceneView(
            leftCurrentHp: 90, leftMaxHp: 100,
            rightCurrentHp: 100, rightMaxHp: 100,
            isLeftTurn: false, lastAttack: attack,
          ));
        },
        returnsNormally,
      );
    });
  });
}
