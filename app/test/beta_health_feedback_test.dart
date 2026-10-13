import 'package:app/game_domain/beta_session.dart';
import 'package:app/game_presentation/beta_arena_painter.dart';
import 'package:app/game_presentation/beta_health_feedback.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('damage trails briefly; healing and max HP changes reset the trail', () {
    final feedback = BetaHealthFeedback(100, 100);
    feedback.advance(60, 100, .01);
    expect(feedback.trail, 1);
    feedback.advance(60, 100, .1);
    expect(feedback.trail, 1);
    for (var i = 0; i < 5; i++) {
      feedback.advance(60, 100, .1);
    }
    expect(feedback.trail, .6);
    feedback.advance(20, 100, .01);
    expect(feedback.trail, .6);
    feedback.advance(28, 100, .01);
    expect(feedback.trail, .28); // Partial healing clears the old loss.
    feedback.advance(48, 110, .01);
    expect(feedback.trail, closeTo(48 / 110, .000001));
    expect(BetaHealthFeedback(100, 100).trail, 1);
  });

  test(
    'continuous damage cannot freeze the trail or move it below real HP',
    () {
      final feedback = BetaHealthFeedback(100, 100);
      for (var i = 1; i <= 60; i++) {
        final hp = 100 - i * .3;
        feedback.advance(hp, 100, 1 / 60);
        expect(feedback.trail, inInclusiveRange(hp / 100, 1));
      }
      expect(feedback.trail, lessThan(.9));
      final trail = feedback.trail;
      feedback.advance(0, 100, 0);
      feedback.advance(0, 100, double.nan);
      expect(feedback.trail, trail);
      for (var i = 0; i < 10; i++) {
        feedback.advance(0, 100, .1);
      }
      expect(feedback.trail, 0);
    },
  );

  test(
    'arena pause freezes health feedback and a new painter starts clean',
    () {
      final run = BetaSession()..start();
      final painter = BetaArenaPainter(run);
      addTearDown(painter.dispose);
      run.hp = 50;
      painter.advance(.01);
      expect(painter.heroHealthTrail, 1);
      run.pause();
      painter.advance(1);
      expect(painter.heroHealthTrail, 1);
      run.resume();
      for (var i = 0; i < 6; i++) {
        painter.advance(.1);
      }
      expect(painter.heroHealthTrail, .5);
      final fresh = BetaArenaPainter(BetaSession());
      addTearDown(fresh.dispose);
      expect(fresh.heroHealthTrail, 1);
    },
  );
}
