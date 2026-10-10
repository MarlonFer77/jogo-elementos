import 'dart:collection';
import 'dart:math' as math;

/// Local, opt-in, bounded samples. No storage or network; no device identifiers.
class BetaPerformance {
  static const capacity = 240;
  bool enabled = false;
  final _loop = ListQueue<double>();
  final _build = ListQueue<double>();
  final _raster = ListQueue<double>();
  int get frameSamples => _build.length;
  int get loopSamples => _loop.length;

  void reset() {
    _loop.clear();
    _build.clear();
    _raster.clear();
  }

  void _add(ListQueue<double> samples, double value) {
    if (samples.length == capacity) samples.removeFirst();
    samples.add(value);
  }

  void recordLoop(double seconds) {
    if (enabled && seconds.isFinite && seconds > 0) _add(_loop, seconds);
  }

  void recordFrame(double buildMs, double rasterMs) {
    if (!enabled ||
        !buildMs.isFinite ||
        !rasterMs.isFinite ||
        buildMs < 0 ||
        rasterMs < 0) {
      return;
    }
    _add(_build, buildMs);
    _add(_raster, rasterMs);
  }

  double? get loopFps => _loop.length < 30
      ? null
      : _loop.length / _loop.fold<double>(0, (sum, dt) => sum + dt);

  double? _p95(ListQueue<double> values) {
    if (values.isEmpty) return null;
    final sorted = values.toList()..sort();
    return sorted[(sorted.length * .95).ceil() - 1];
  }

  double? get buildP95 => _p95(_build);
  double? get rasterP95 => _p95(_raster);
  double? get worstLoopMs =>
      _loop.isEmpty ? null : _loop.reduce(math.max) * 1000;
  String _ms(double? value) =>
      value == null ? 'sem amostras' : '${value.toStringAsFixed(1)} ms';
  String get report =>
      'FPS do loop: ${loopFps?.toStringAsFixed(1) ?? 'amostras insuficientes'} ($loopSamples amostras)\n'
      'Maior intervalo: ${_ms(worstLoopMs)}\n'
      'UI p95: ${_ms(buildP95)} · Raster p95: ${_ms(rasterP95)}\n'
      'Quadros Flutter: $frameSamples (janela máxima: $capacity)\n'
      'FPS do loop não é FPS apresentado. Não mede bateria/temperatura.';
}
