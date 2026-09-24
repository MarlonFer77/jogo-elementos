import 'dart:math';

/// Pure, versioned recipe geometry. Mirrored by backend/battle-rules/seal.ts.
class ConjurationSeal {
  ConjurationSeal(List<String> elements) {
    final ids = [...elements]..sort();
    final seed = ids.join('+').codeUnits.fold(0, (a, b) => a + b);
    final count = ids.length == 3 ? 6 : 4;
    durationMs = ids.length == 3 ? 8000 : 6000;
    nodes = List.generate(count, (i) {
      final angle = -pi / 2 + (i + seed % count) * 2 * pi / count;
      final radius = i.isOdd && seed.isOdd ? .25 : .34;
      return (x: .5 + radius * cos(angle), y: .5 + radius * sin(angle));
    });
  }
  late final int durationMs;
  late final List<({double x, double y})> nodes;
  static const tolerance = .13;

  bool hits(int index, double x, double y) {
    if (index >= nodes.length) return false;
    final n = nodes[index];
    return pow(x - n.x, 2) + pow(y - n.y, 2) <= tolerance * tolerance;
  }
}
