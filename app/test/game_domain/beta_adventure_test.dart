import 'dart:convert';
import 'package:app/game_domain/beta_adventure_store.dart';
import 'package:app/game_domain/beta_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/beta_puzzle_fixture.dart';

void advance(BetaSession run, double seconds) {
  for (var t = 0.0; t < seconds; t += .02) {
    run.update(.02);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('lethal lingering burn cannot replace the safe checkpoint', () {
    final run = BetaSession()..start();
    final safe = run.latestCheckpoint!;
    run.enemies.clear();
    run.hp = 1;
    run.burnTime = 3;
    run.pause();
    expect(run.latestCheckpoint!.encoded, safe.encoded);
    expect(run.latestCheckpoint!.restore().hp, 100);
  });

  test(
    'combat rollback keeps XP and enemies atomic; clear checkpoint retains rewards',
    () {
      final run = BetaSession();
      run.learnSkill(BetaSkill.runicBlade);
      run.start();
      final entry = run.latestCheckpoint!;
      run.enemies.removeLast();
      run.xp = 20;
      run.kills = 1;
      run.pause();
      expect(run.latestCheckpoint!.encoded, entry.encoded);
      final restored = entry.restore();
      expect(restored.phase, BetaPhase.paused);
      expect(restored.remaining, 3);
      expect(restored.xp, 0);
      expect(restored.kills, 0);
      expect(restored.hasSkill(BetaSkill.runicBlade), true);
      expect(restored.skillPoints, 0);
      restored.resume();
      restored.enemies
        ..clear()
        ..add(BetaEnemy(BetaEnemyKind.goblin, 0, 3.5)..hp = 1);
      restored.sword();
      advance(restored, .5);
      final cleared = BetaCheckpoint.decode(
        restored.latestCheckpoint!.encoded,
      ).restore();
      expect(cleared.remaining, 0);
      expect(cleared.kills, 1);
      expect(cleared.xp, 20);
      cleared.resume();
      advance(cleared, 1);
      expect(cleared.xp, 20);
    },
  );

  test(
    'puzzles, hints, restoration and next region survive resume without bypass',
    () {
      var run = BetaSession()..start();
      run.enemies.clear();
      run.x = -2;
      run.z = 3;
      run.select(BetaElement.water);
      expect(run.attune(), true);
      run.revealPuzzleHint();
      run = BetaCheckpoint.decode(run.latestCheckpoint!.encoded).restore();
      expect(run.puzzle.completed, 1);
      expect(run.puzzle.revealedHint, isNotNull);
      expect(run.passageOpen, false);
      run.resume();
      restorePuzzle(run);
      run.checkpointOutsideCombat();
      advance(run, 2.1);
      run.x = BetaRegion.gateX;
      run.z = BetaRegion.gateZ;
      advance(run, .6);
      final next = run.latestCheckpoint!.restore();
      expect(next.wave, 2);
      expect(next.sceneryRestored, true);
      expect(next.puzzle.solved, false);
      expect(next.passageOpen, false);
      expect(next.remaining, 3);
      next.resume();
      next.hp = 1;
      next.burnTime = 3;
      advance(next, 1);
      expect(next.phase, BetaPhase.lost);
      expect(next.latestCheckpoint!.restore().hp, greaterThan(1));
    },
  );

  test(
    'UID isolation, serialized writes and corrupt primary recovery',
    () async {
      final a = BetaAdventureStore('account-A'),
          b = BetaAdventureStore('account-B');
      final run = BetaSession()..start();
      final first = run.latestCheckpoint!;
      run.enemies.clear();
      restorePuzzle(run);
      run.pause();
      final second = run.latestCheckpoint!;
      await Future.wait([a.save(first), a.save(second)]);
      expect((await a.load())!.cleared, true);
      expect(await b.load(), isNull);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(a.key, 'broken');
      expect((await a.load())!.encoded, first.encoded);
      await prefs.setString(
        b.key,
        jsonEncode({
          'version': 1,
          'uid': 'account-A',
          'checkpoint': first.encoded,
        }),
      );
      await expectLater(b.load(), throwsStateError);
      expect(prefs.getString(b.key), contains('account-A'));
    },
  );

  test(
    'invalid progress and future versions never overwrite the stored save',
    () async {
      final run = BetaSession()..start();
      final raw =
          jsonDecode(run.latestCheckpoint!.encoded) as Map<String, dynamic>;
      for (final change in [
        {'hp': -1},
        {'wave': 0},
        {'level': 8},
        {'points': 9},
        {
          'skills': ['flow'],
        },
        {
          'equipped': ['unknown'],
        },
        {'won': true},
        {'puzzles': []},
        {'x': 999},
      ]) {
        expect(
          () => BetaCheckpoint.decode(jsonEncode({...raw, ...change})),
          throwsFormatException,
        );
      }
      final store = BetaAdventureStore('account');
      await store.save(run.latestCheckpoint!);
      final prefs = await SharedPreferences.getInstance();
      final future = jsonEncode({'version': 2, 'uid': 'account'});
      await prefs.setString(store.key, future);
      await expectLater(store.load(), throwsStateError);
      await expectLater(store.save(run.latestCheckpoint!), throwsStateError);
      expect(prefs.getString(store.key), future);
    },
  );
}
