import 'dart:math' as math;
import '../game_domain/beta_session.dart';

/// Presentation-only sampling, shared by the blade and its short motion ribbon.
/// Contact remains at the engine's existing swordContact, regardless of FPS.
class BetaSwordPose {
  const BetaSwordPose(
    this.swing,
    this.lift,
    this.lunge,
    this.brace,
    this.pitch,
  );
  final double swing, lift, lunge, brace, pitch;

  static const rest = BetaSwordPose(0, 0, 0, 0, .12);
  static const windupEnd = BetaSession.swordContact - .07;
  static const followEnd = BetaSession.swordContact + .07;

  static double _ease(double t) {
    t = t.clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  static BetaSwordPose at(double elapsed, int side) {
    if (elapsed <= 0 || elapsed >= BetaSession.swordDuration) return rest;
    final windup = _ease(elapsed / windupEnd);
    final strike = _ease((elapsed - windupEnd) / (followEnd - windupEnd));
    final settle =
        1 -
        _ease((elapsed - followEnd) / (BetaSession.swordDuration - followEnd));
    final brace = windup * settle;
    final swing = elapsed < windupEnd
        ? -1.25 * windup
        : (-1.25 + 2.5 * strike) * settle;
    final lunge = elapsed < windupEnd
        ? -.06 * windup
        : elapsed < BetaSession.swordContact
        ? -.06 + .26 * _ease((elapsed - windupEnd) / .07)
        : .2 *
              (1 -
                  _ease(
                    (elapsed - BetaSession.swordContact) /
                        (BetaSession.swordDuration - BetaSession.swordContact),
                  ));
    return BetaSwordPose(
      swing * (side < 0 ? -1 : 1),
      .26 * brace,
      lunge,
      brace,
      .12 + .36 * brace * (1 - 2 * strike),
    );
  }

  double get handX => .42 + math.sin(swing) * .3;
  double get handY => .77 + lift * .65;
  double get handZ => .25 + math.cos(swing) * .17;
}
