import 'package:app/game_presentation/beta_performance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('diagnostics are opt-in, bounded and discard invalid samples', () {
    final metrics = BetaPerformance();
    metrics.recordLoop(1 / 60);
    metrics.recordFrame(2, 4);
    expect(metrics.loopSamples, 0);
    expect(metrics.frameSamples, 0);
    metrics.enabled = true;
    for (var i = 0; i < 300; i++) {
      metrics.recordLoop(1 / 60);
      metrics.recordFrame(2, 4);
    }
    metrics.recordLoop(double.nan);
    metrics.recordLoop(0);
    metrics.recordFrame(-1, 4);
    metrics.recordFrame(2, double.infinity);
    expect(metrics.loopSamples, BetaPerformance.capacity);
    expect(metrics.frameSamples, BetaPerformance.capacity);
    expect(metrics.loopFps, closeTo(60, .001));
    expect(metrics.buildP95, 2);
    expect(metrics.rasterP95, 4);
    expect(metrics.worstLoopMs, closeTo(16.667, .001));
    expect(metrics.report, contains('não é FPS apresentado'));
    metrics.reset();
    expect(metrics.frameSamples, 0);
    expect(metrics.loopFps, isNull);
    expect(metrics.buildP95, isNull);
  });
}
