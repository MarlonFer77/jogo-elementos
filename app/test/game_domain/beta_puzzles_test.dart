import 'package:app/game_domain/beta_session.dart';
import 'package:flutter_test/flutter_test.dart';

void advance(BetaSession run, double seconds) {
  for (var t = 0.0; t < seconds; t += .02) {
    run.update(.02);
  }
}

void main() {
  test(
    'hints persist through errors and pause, but never reveal future steps',
    () {
      final run = BetaSession()..start();
      run.revealPuzzleHint();
      expect(run.puzzle.revealedHint, isNull);
      run.enemies.clear();
      run.revealPuzzleHint();
      expect(run.puzzle.revealedHint?.hint, 'A: Água');
      advance(run, 10);
      expect(run.messageTime, 0);
      expect(run.puzzle.revealedHint?.hint, 'A: Água');
      run.pause();
      advance(run, 1);
      run.resume();
      run.x = -2;
      run.z = 3;
      expect(run.attune(), false);
      expect(run.puzzle.revealedHint, isNotNull);
      advance(run, .5);
      run.select(BetaElement.water);
      expect(run.attune(), true);
      expect(run.puzzle.revealedHint, isNull);
      expect(run.puzzle.history.map((step) => step.hint), ['A: Água']);
      run.revealPuzzleHint();
      expect(run.puzzle.revealedHint?.hint, 'B: Terra');
      expect(BetaSession().puzzle.revealedHint, isNull);
    },
  );

  test('six increasingly complex puzzles and reachable seals', () {
    expect(BetaPuzzle.catalog.length, BetaRegion.values.length);
    for (final region in BetaRegion.values) {
      final run = BetaSession()..wave = region.index + 1;
      expect(run.puzzle.puzzle.steps.length, region.index + 2);
      // Grid flood fill verifies routes, not just valid destination points.
      final visited = <(int, int)>{(0, 10)};
      final pending = <(int, int)>[(0, 10)];
      for (var i = 0; i < pending.length; i++) {
        final p = pending[i];
        for (final delta in [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
          final q = (p.$1 + delta.$1, p.$2 + delta.$2);
          if (!visited.contains(q) && run.walkable(q.$1 * .5, q.$2 * .5, .35)) {
            visited.add(q);
            pending.add(q);
          }
        }
      }
      for (final altar in BetaAltar.all) {
        expect(
          visited.contains(((altar.x * 2).round(), (altar.z * 2).round())),
          true,
          reason: region.title,
        );
      }
    }
  });

  test(
    'combat, distance, busy, pause, arrival, duplicates and failures are safe',
    () {
      final run = BetaSession()..start();
      run.x = -2;
      run.z = 3;
      run.select(BetaElement.water);
      expect(run.attune(), false);
      run.enemies.clear();
      run.mana = 0;
      advance(run, 3);
      expect(run.passageOpen, false);
      run.x = 7;
      expect(run.attune(), false);
      run.x = -2;
      run.arrivalTime = .2;
      expect(run.attune(), false);
      advance(run, .3);
      run.pause();
      expect(run.attune(), false);
      run.resume();
      run.dodgeTime = .2;
      expect(run.attune(), false);
      run.dodgeTime = 0;
      run.select(BetaElement.fire);
      expect(run.attune(), false);
      expect(run.puzzle.completed, 0);
      advance(run, .5);
      run.select(BetaElement.water);
      final mana = run.mana, xp = run.xp;
      expect(run.attune(), true);
      expect(run.attune(), false);
      expect(run.puzzle.completed, 1);
      expect(run.mana, mana);
      expect(run.xp, xp);
      advance(run, .5);
      expect(run.attune(), false);
      expect(run.puzzle.completed, 1);
      run.revealPuzzleHint();
      expect(run.message, contains('B: Terra'));
      expect(run.discoveredCombos, isEmpty);
      expect(BetaSession().restoredAreas, 0);
    },
  );

  test(
    'complete all six areas with real interactions, final victory needs ritual',
    () {
      final run = BetaSession()..start();
      for (var stage = 1; stage <= BetaRegion.values.length; stage++) {
        expect(run.wave, stage);
        expect(run.restoredAreas, stage - 1);
        expect(run.sceneryRestored, stage > 1);
        expect(run.puzzle.solved, false);
        expect(run.passageOpen, false);
        run.enemies.clear();
        advance(run, .5);
        run.x = BetaRegion.gateX;
        run.z = BetaRegion.gateZ;
        advance(run, 3);
        expect(run.wave, stage);
        expect(run.phase, BetaPhase.playing);
        final steps = run.puzzle.puzzle.steps;
        for (final step in steps) {
          final altar = BetaAltar.all[step.altar];
          run.x = altar.x;
          run.z = altar.z;
          // Mixed recipes accept the reverse order and don't require combat slots.
          run.select(step.second ?? step.first);
          if (step.second != null) run.mix(step.first);
          run.mana = 0;
          expect(run.attune(), true, reason: 'Stage $stage: ${step.hint}');
          expect(run.mana, 0);
          expect(run.attune(), false);
          advance(run, .5);
        }
        expect(run.restoredAreas, stage);
        expect(run.sceneryRestored, true);
        expect(run.discoveredCombos, isEmpty);
        expect(run.xp, 0);
        advance(run, 2.1);
        expect(run.passageOpen, true);
        if (run.finalArea) {
          // Finishing the ritual allows free exploration, never auto-victory.
          advance(run, 8);
          expect(run.phase, BetaPhase.playing);
          run.x = BetaRegion.gateX;
          run.z = BetaRegion.gateZ;
          advance(run, .25);
          run.pause();
          advance(run, 1);
          expect(run.passageProgress, 0);
          run.resume();
          run.x = 3;
          advance(run, .6);
          expect(run.phase, BetaPhase.playing);
        }
        run.x = BetaRegion.gateX;
        run.z = BetaRegion.gateZ;
        advance(run, .6);
      }
      expect(run.phase, BetaPhase.won);
      expect(run.wave, BetaRegion.values.length);
      expect(run.xp, 0);
      expect(run.sounds.where((s) => s == BetaSound.victory), hasLength(1));
      expect(run.attune(), false);
      expect(run.sceneryRestored, true);
      expect(BetaSession().sceneryRestored, false);
    },
  );
}
