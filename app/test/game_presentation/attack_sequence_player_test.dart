import 'package:app/game_domain/attack_event.dart';
import 'package:app/game_presentation/attack_sequence_player.dart';
import 'package:app/game_presentation/battle_character_component.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

AttackSequencePlayer _buildPlayer({List<String> statusNames = const []}) {
  final attacker = BattleCharacterComponent(
    side: BattleSide.left,
    position: Vector2(0, 0),
  );
  final target = BattleCharacterComponent(
    side: BattleSide.right,
    position: Vector2(200, 0),
  );
  return AttackSequencePlayer(
    event: AttackEvent(
      sequenceId: 1,
      attackerIsLeft: true,
      elementIds: const ['fire', 'wind'],
      comboName: 'Tempestade Ígnea',
      damage: 20,
      appliedStatusNames: statusNames,
    ),
    attacker: attacker,
    target: target,
    attackerPosition: Vector2(0, -40),
    targetPosition: Vector2(200, -40),
  );
}

void main() {
  test('starts unfinished and triggers the attacker preparation pulse right '
      'away', () {
    final player = _buildPlayer();
    expect(player.isFinished, isFalse);

    player.update(0.01);
    expect(player.attacker.isPlayingPreparationPulse, isTrue);
  });

  test('triggers the target hit effect once impact resolves', () {
    final player = _buildPlayer();
    // preparação (0.15) + efeito (0.2) + impacto (0.2) = 0.55, um pouco a
    // mais pra garantir que já cruzou pro passo de dano.
    player.update(0.56);
    expect(player.target.isPlayingHitEffect, isTrue);
  });

  test('finishes after the full duration when no status was applied', () {
    final player = _buildPlayer(statusNames: []);
    // preparação+efeito+impacto+dano = 0.15+0.2+0.2+0.4 = 0.95
    player.update(0.96);
    expect(player.isFinished, isTrue);
  });

  test('plays the extra state step when a status was applied, so it takes '
      'longer to finish', () {
    final player = _buildPlayer(statusNames: ['Queimadura']);
    player.update(0.96); // teria terminado sem o passo de estado
    expect(player.isFinished, isFalse);

    player.update(0.4); // 0.3s do passo de estado + folga
    expect(player.isFinished, isTrue);
  });

  test('a single large update() call advances through every step at once',
      () {
    final player = _buildPlayer();
    player.update(2.0); // bem mais que o total — não deve travar num passo
    expect(player.isFinished, isTrue);
  });
}
