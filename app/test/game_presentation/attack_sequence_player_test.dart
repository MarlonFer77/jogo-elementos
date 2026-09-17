import 'package:app/game_domain/attack_event.dart';
import 'package:app/game_presentation/attack_sequence_player.dart';
import 'package:app/game_presentation/battle_character_component.dart';
import 'package:app/game_presentation/sfx_player.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

AttackSequencePlayer _buildPlayer({
  List<String> statusNames = const [],
  int damage = 20,
  bool melee = false,
  bool left = true,
  String element = 'fire',
  void Function()? onImpact,
  void Function()? onComplete,
}) {
  final attacker = BattleCharacterComponent(
    side: left ? BattleSide.left : BattleSide.right,
    position: Vector2(left ? 0 : 200, 0),
  );
  final target = BattleCharacterComponent(
    side: left ? BattleSide.right : BattleSide.left,
    position: Vector2(left ? 200 : 0, 0),
  );
  return AttackSequencePlayer(
    event: AttackEvent(
      sequenceId: 1,
      attackerIsLeft: left,
      elementIds: melee ? [element] : const ['fire', 'wind'],
      comboName: melee ? null : 'Tempestade Ígnea',
      damage: damage,
      appliedStatusNames: statusNames,
    ),
    attacker: attacker,
    target: target,
    attackerPosition: attacker.restPosition - Vector2(0, 40),
    targetPosition: target.restPosition - Vector2(0, 40),
    onImpact: onImpact,
    onComplete: onComplete,
  );
}

void main() {
  for (final element in [
    'fire',
    'water',
    'wind',
    'ice',
    'nature',
    'lightning',
    'earth',
    'shadow',
    'light',
    'poison',
  ]) {
    for (final left in [true, false]) {
      test('sword follows $element, left=$left, and clears after action', () {
        final player = _buildPlayer(melee: true, left: left, element: element);
        player.update(.1);
        expect(player.attacker.swordElement, element);
        player.update(.3);
        expect(player.attacker.swordElement, element);
        player.update(1);
        expect(player.attacker.swordElement, isNull);
      });
    }
  }
  test('cancel clears sword and channeling never equips one', () {
    final melee = _buildPlayer(melee: true);
    melee.update(.3);
    melee.cancelVisuals();
    expect(melee.attacker.swordElement, isNull);
    melee.update(.1);
    expect(melee.attacker.swordElement, isNull);
    final channel = _buildPlayer();
    channel.update(.3);
    expect(channel.attacker.swordElement, isNull);
  });
  for (final left in [true, false]) {
    test('melee approaches, hits and returns to rest (left=$left)', () {
      final player = _buildPlayer(melee: true, left: left);
      final origin = player.attacker.restPosition.x;
      player.update(.25);
      expect((player.attacker.position.x - origin).abs(), greaterThan(20));
      player.update(.11);
      expect(
        (player.target.restPosition.x - player.attacker.position.x).abs(),
        closeTo(52, .01),
      );
      expect(player.target.isPlayingHitEffect, isFalse);
      player.update(.2);
      expect(player.target.isPlayingHitEffect, isTrue);
      player.update(1);
      expect(player.attacker.position.x, origin);
      expect(player.isFinished, isTrue);
    });
  }

  test(
    'channeling stays ranged and cancellation does not reset a newer pose',
    () {
      final player = _buildPlayer();
      player.update(.3);
      expect(player.attacker.position.x.abs(), lessThan(5));
      player.cancelVisuals();
      expect(player.attacker.position.x, 0);
      player.attacker.setActionPose(offsetX: 20);
      player.update(5);
      expect(player.target.isPlayingHitEffect, isFalse);
      player.onRemove();
      expect(player.attacker.position.x, 20);
    },
  );

  test(
    'melee resize retargets from new resting positions and still returns home',
    () {
      final player = _buildPlayer(melee: true);
      player.update(.36);
      player.attacker.reposition(Vector2(100, 0));
      player.target.reposition(Vector2(400, 0));
      player.updatePositions(
        attackerPosition: Vector2(100, -40),
        targetPosition: Vector2(400, -40),
      );
      expect(player.attacker.position.x, 348);
      player.update(1);
      expect(player.attacker.position.x, 100);
    },
  );

  test(
    'impact and completion fire once, in order, even across a long frame',
    () {
      final events = <String>[];
      final player = _buildPlayer(
        onImpact: () => events.add('impact'),
        onComplete: () => events.add('complete'),
      );
      player.update(.3);
      expect(events, isEmpty);
      player.update(5);
      player.update(5);
      expect(events, ['impact', 'complete']);
    },
  );

  test('zero damage reports impact but does not play a damage reaction', () {
    var impacts = 0;
    final player = _buildPlayer(damage: 0, onImpact: () => impacts++);
    player.update(.56);
    expect(impacts, 1);
    expect(player.target.isPlayingHitEffect, isFalse);
    player.update(1);
    expect(player.isFinished, isTrue);
  });

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

  test('a single large update() call advances through every step at once', () {
    final player = _buildPlayer();
    player.update(2.0); // bem mais que o total — não deve travar num passo
    expect(player.isFinished, isTrue);
  });

  test('plays the cast sound at the start of the preparation step', () {
    final playedPaths = <String>[];
    sfxPlayer = SfxPlayer(play: playedPaths.add);
    addTearDown(() => sfxPlayer = SfxPlayer());

    final player = _buildPlayer();
    player.update(0.01);

    expect(playedPaths, contains('cast.ogg'));
  });

  test('plays the impact sound when the impact step resolves', () {
    final playedPaths = <String>[];
    sfxPlayer = SfxPlayer(play: playedPaths.add);
    addTearDown(() => sfxPlayer = SfxPlayer());

    final player = _buildPlayer();
    player.update(0.56);

    expect(playedPaths, contains('impact.ogg'));
  });
}
