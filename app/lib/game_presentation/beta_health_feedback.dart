import 'dart:math' as math;

/// Presentation only: the solid bar always shows real HP; this trails a loss.
/// Driven by the arena clock, with no timer or persistence of its own.
class BetaHealthFeedback {
  BetaHealthFeedback(double health, double maximum)
    : _maximum = maximum,
      _current = _fraction(health, maximum),
      _trail = _fraction(health, maximum);

  double _maximum, _current, _trail;
  double _hold = 0;
  double get trail => _trail;

  static double _fraction(double health, double maximum) =>
      health.isFinite && maximum.isFinite && maximum > 0
      ? (health / maximum).clamp(0.0, 1.0)
      : 0;

  void advance(double health, double maximum, double elapsed) {
    if (!health.isFinite ||
        !maximum.isFinite ||
        maximum <= 0 ||
        !elapsed.isFinite ||
        elapsed <= 0) {
      return;
    }
    final current = _fraction(health, maximum);
    if (maximum != _maximum || current > _current) {
      // Healing/level-up must not look like additional damage or excess HP.
      _trail = current;
      _hold = 0;
    } else if (current < _current && _trail <= _current + .000001) {
      // Continuous burn damage cannot keep restarting the delay indefinitely.
      _hold = .18;
    }
    _current = current;
    _maximum = maximum;
    final dt = elapsed.clamp(0.0, .1);
    final decayTime = math.max(0.0, dt - _hold);
    _hold = math.max(0.0, _hold - dt);
    _trail = math.max(current, _trail - decayTime * 1.8);
  }
}
