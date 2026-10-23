import 'package:app/game_domain/beta_session.dart';
import 'package:app/game_presentation/beta_sword_pose.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<double> values(BetaSwordPose p) => [
    p.swing,
    p.lift,
    p.lunge,
    p.brace,
    p.pitch,
    p.handX,
    p.handY,
    p.handZ,
  ];

  test('blade faces its target at the existing damage contact', () {
    for (final side in [-1, 1]) {
      final pose = BetaSwordPose.at(BetaSession.swordContact, side);
      expect(pose.swing, closeTo(0, 1e-10));
      expect(pose.lunge, closeTo(.2, 1e-10));
      expect(pose.brace, 1);
    }
  });

  test('windup, contact, recovery and rest have continuous poses', () {
    for (final side in [-1, 1]) {
      for (final t in [
        0.0,
        BetaSwordPose.windupEnd,
        BetaSession.swordContact,
        BetaSwordPose.followEnd,
        BetaSession.swordDuration,
      ]) {
        final before = values(BetaSwordPose.at(t - .000001, side));
        final after = values(BetaSwordPose.at(t + .000001, side));
        for (var i = 0; i < before.length; i++) {
          expect(
            before[i],
            closeTo(after[i], .0001),
            reason: '$side at $t, channel $i',
          );
        }
      }
    }
    expect(values(BetaSwordPose.at(1, 1)), values(BetaSwordPose.rest));
  });

  test(
    'alternating strikes mirror direction with bounded posture at any sample rate',
    () {
      for (final fps in [30, 60, 120]) {
        for (var i = 0; i <= fps; i++) {
          final t = i / fps * BetaSession.swordDuration;
          final left = BetaSwordPose.at(t, -1), right = BetaSwordPose.at(t, 1);
          expect(left.swing, -right.swing);
          expect(left.lunge, right.lunge);
          expect(left.brace, inInclusiveRange(0, 1));
          expect(left.lunge, inInclusiveRange(-.06, .2));
          expect(left.lift, inInclusiveRange(0, .26));
          expect(values(left).every((value) => value.isFinite), true);
        }
      }
    },
  );
}
