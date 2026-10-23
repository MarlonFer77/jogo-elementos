import 'dart:convert';
import 'package:app/game_domain/beta_session.dart';
import 'package:flutter_test/flutter_test.dart';

void advance(BetaSession run, double seconds, [int fps = 60]) {
  for (var i = 0; i < (seconds * fps).round(); i++) {
    run.update(1 / fps);
  }
}

BetaSession arena() => BetaSession()
  ..start()
  ..enemies.clear();

void main() {
  test(
    'sword and dodge charge once; rejected actions and magic do not spend ST',
    () {
      final run = arena();
      expect(run.sword(), true);
      expect(run.stamina, 82);
      expect(run.sword(), false);
      expect(run.stamina, 82);
      expect(
        run.dodge(),
        true,
      ); // Cancels the swing but never refunds its cost.
      expect(run.stamina, 54);
      expect(run.dodge(), false);
      expect(run.stamina, 54);
      final empty = arena()..stamina = 0;
      expect(empty.sword(), false);
      expect(empty.dodge(), false);
      expect(empty.canRequest(BetaAction.sword), false);
      expect(empty.canRequest(BetaAction.dodge), false);
      expect(empty.swordTime, 0);
      expect(empty.dodgeTime, 0);
      expect(empty.cast(), true);
      expect(empty.mana, 75);
      expect(empty.stamina, 0);
    },
  );

  test('recovery waits, caps at 100 and is independent of frame rate', () {
    for (final fps in [30, 60, 120]) {
      final run = arena()..stamina = 18;
      expect(run.sword(), true);
      advance(run, .8, fps);
      expect(run.stamina, closeTo(0, .00001));
      advance(run, 1, fps);
      expect(run.stamina, closeTo(22, .00001));
      expect(run.canSword, true);
      expect(run.canDodge, false);
      advance(run, 5, fps);
      expect(run.stamina, 100);
    }
  });

  test('walking can recover stamina, pause and defeat cannot', () {
    final run = arena()..stamina = 18;
    run.sword();
    run.pause();
    advance(run, 2);
    expect(run.stamina, 0);
    run.resume();
    run.setMovement(1, 0);
    advance(run, 1.8);
    expect(run.stamina, closeTo(22, .00001));
    run.phase = BetaPhase.lost;
    advance(run, 1);
    expect(run.stamina, closeTo(22, .00001));
  });

  test(
    'buffer spends on execution, not enqueue, and revalidates resources',
    () {
      final run = arena()..swordCooldown = .1;
      expect(run.request(BetaAction.sword), true);
      expect(run.stamina, 100);
      advance(run, .2);
      expect(run.stamina, 82);
      expect(run.queuedAction, isNull);
      final rejected = arena()..swordCooldown = .1;
      expect(rejected.request(BetaAction.sword), true);
      rejected.stamina = 0;
      advance(rejected, .2);
      expect(rejected.swordTime, 0);
      expect(rejected.queuedAction, isNull);
      expect(rejected.stamina, closeTo(4.4, .00001));
    },
  );

  test(
    'checkpoint preserves stamina and recovery wait; legacy saves start full',
    () {
      final run = arena()..stamina = 18;
      run.sword();
      advance(run, .2);
      run.pause();
      final saved = run.latestCheckpoint!;
      final restored = BetaCheckpoint.decode(saved.encoded).restore();
      expect(restored.stamina, 0);
      advance(restored, 2);
      expect(restored.stamina, 0);
      restored.resume();
      advance(restored, .6);
      expect(restored.stamina, closeTo(0, .00001));
      advance(restored, .5);
      expect(restored.stamina, closeTo(11, .00001));
      final legacy = jsonDecode(saved.encoded) as Map<String, dynamic>;
      legacy.remove('stamina');
      legacy.remove('staminaWait');
      expect(BetaCheckpoint.decode(jsonEncode(legacy)).restore().stamina, 100);
      for (final bad in [null, -1, 101, '100']) {
        final corrupted = jsonDecode(saved.encoded) as Map<String, dynamic>;
        corrupted['stamina'] = bad;
        expect(
          () => BetaCheckpoint.decode(jsonEncode(corrupted)),
          throwsFormatException,
        );
      }
      final corrupted = jsonDecode(saved.encoded) as Map<String, dynamic>;
      corrupted['staminaWait'] = 1;
      expect(
        () => BetaCheckpoint.decode(jsonEncode(corrupted)),
        throwsFormatException,
      );
    },
  );
}
