import 'package:battle_engine/battle_engine.dart';
import 'package:test/test.dart';

void main() {
  group('ElementUnlock', () {
    test('two unlocks with the same id are equal', () {
      const a = ElementUnlock(id: 'x', elementId: 'fire');
      const b = ElementUnlock(id: 'x', elementId: 'water');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('holds the elementId it was constructed with', () {
      const unlock = ElementUnlock(id: 'unlock_fire', elementId: 'fire');
      expect(unlock.elementId, equals('fire'));
    });
  });
}
