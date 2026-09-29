import 'package:app/game_domain/conjuration_seal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'quality bands, boundary geometry, recipe difficulty and invalid traces',
    () {
      final seal = ConjurationSeal(['fire', 'wind']);
      List<Map<String, num>> trace(double offset) => [
        for (final (i, node) in seal.nodes.indexed)
          {'x': node.x + offset, 'y': node.y, 'ms': i * 100},
      ];
      for (final (offset, percent) in [
        (0.0, 100),
        (.0325, 100),
        (.033, 80),
        (.065, 80),
        (.066, 60),
        (.0975, 60),
        (.098, 40),
        (.117, 40),
        (.14, 0),
      ]) {
        expect(seal.damagePercent(trace(offset), elapsedMs: 500), percent);
      }
      expect(seal.nodes.length, 4);
      expect(ConjurationSeal(['earth', 'fire']).nodes.length, 5);
      expect(ConjurationSeal(['fire', 'light', 'lightning']).nodes.length, 7);
      expect(ConjurationSeal(['wind', 'fire']).nodes, seal.nodes);
      for (final invalid in [
        trace(0).sublist(1),
        trace(0).reversed.toList(),
        trace(0).map((p) => {...p, 'ms': 0}).toList(),
        trace(0).map((p) => {...p, 'ms': 1.5}).toList(),
        trace(0).map((p) => {...p, 'x': double.nan}).toList(),
        trace(0).map((p) => {...p, 'ms': 9000}).toList(),
      ]) {
        expect(seal.damagePercent(invalid, elapsedMs: 10000), 0);
      }
      expect(seal.damagePercent(trace(0), elapsedMs: 0), 0);
    },
  );
}
