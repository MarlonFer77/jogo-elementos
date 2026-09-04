import 'package:battle_engine/battle_engine.dart';
import 'package:test/test.dart';

void main() {
  group('StatusEffect', () {
    test('two effects with the same id are equal', () {
      const a = StatusEffect(id: 'burn', name: 'Queimadura', description: 'x');
      const b = StatusEffect(id: 'burn', name: 'Outro nome', description: 'y');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('StatusEffects.all contains every built-in status without '
        'duplicates', () {
      final ids = StatusEffects.all.map((e) => e.id).toSet();
      expect(ids.length, equals(StatusEffects.all.length));
      expect(ids, contains('burn'));
      expect(ids, contains('area_effect'));
    });
  });
}
