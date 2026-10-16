import 'package:app/game_domain/beta_session.dart';

/// Isolate existing travel/combat tests from the puzzle interaction tested
/// separately in beta_puzzles_test.dart.
void restorePuzzle(BetaSession run) {
  while (!run.puzzle.solved) {
    final step = run.puzzle.next!;
    run.puzzle.offer(step.altar, step.first, step.second);
  }
}
