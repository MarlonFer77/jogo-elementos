import 'dart:math';
import 'package:battle_engine/battle_engine.dart';

/// Pure, versioned recipe geometry. Mirrored by backend/battle-rules/seal.ts.
class ConjurationSeal {
  ConjurationSeal(List<String> elements) {
    final ids = [...elements]..sort();
    final seed = ids.join('+').codeUnits.fold(0, (a, b) => a + b);
    final recipe = defaultCombinationBook.resolve(
      ids.map((id) => Elements.all.firstWhere((e) => e.id == id)).toList(),
    );
    final strong = (recipe?.damage ?? 0) >= (ids.length == 3 ? 24 : 18);
    final count = (ids.length == 3 ? 6 : 4) + (strong ? 1 : 0);
    difficulty = ids.length == 3
        ? 'Avançado'
        : strong
        ? 'Intermediário'
        : 'Básico';
    durationMs = ids.length == 3 ? 8000 : 6000;
    nodes = List.generate(count, (i) {
      final angle = -pi / 2 + (i + seed % count) * 2 * pi / count;
      final radius = i.isOdd && seed.isOdd ? .25 : .34;
      return (x: .5 + radius * cos(angle), y: .5 + radius * sin(angle));
    });
  }
  late final int durationMs;
  late final String difficulty;
  late final List<({double x, double y})> nodes;
  static const tolerance = .13;

  bool hits(int index, double x, double y) {
    if (index < 0 || index >= nodes.length || !x.isFinite || !y.isFinite) {
      return false;
    }
    final n = nodes[index];
    return pow(x - n.x, 2) + pow(y - n.y, 2) <= tolerance * tolerance;
  }

  /// Best approach to each node; speed is only the deadline, not a bonus.
  /// Mirror thresholds/validation in backend/battle-rules/seal.ts.
  int damagePercent(List<Map<String, num>> trace, {required int elapsedMs}) {
    if (trace.length != nodes.length) return 0;
    var previous = -1;
    var error = 0.0;
    for (var i = 0; i < trace.length; i++) {
      final sample = trace[i];
      final x = sample['x'], y = sample['y'], ms = sample['ms'];
      if (x == null ||
          y == null ||
          ms == null ||
          !x.isFinite ||
          !y.isFinite ||
          !ms.isFinite ||
          ms != ms.truncate() ||
          x < 0 ||
          x > 1 ||
          y < 0 ||
          y > 1 ||
          ms < 0 ||
          ms <= previous ||
          ms > durationMs ||
          ms > elapsedMs ||
          !hits(i, x.toDouble(), y.toDouble())) {
        return 0;
      }
      previous = ms.toInt();
      error +=
          sqrt(pow(x - nodes[i].x, 2) + pow(y - nodes[i].y, 2)) / tolerance;
    }
    final average = error / nodes.length;
    return average <= .25 + 1e-9
        ? 100
        : average <= .5 + 1e-9
        ? 80
        : average <= .75 + 1e-9
        ? 60
        : 40;
  }
}
