import 'package:battle_engine/battle_engine.dart';
import 'package:test/test.dart';

void main() {
  group('ElementCombination', () {
    test('accepts 2 distinct elements', () {
      final combo = ElementCombination(
        elements: [Elements.fire, Elements.wind],
        resultId: 'x',
        resultName: 'X',
        description: 'desc',
      );
      expect(combo.elements, hasLength(2));
    });

    test('accepts 3 distinct elements', () {
      final combo = ElementCombination(
        elements: [Elements.earth, Elements.fire, Elements.water],
        resultId: 'x',
        resultName: 'X',
        description: 'desc',
      );
      expect(combo.elements, hasLength(3));
    });

    test('rejects a single element', () {
      expect(
        () => ElementCombination(
          elements: [Elements.fire],
          resultId: 'x',
          resultName: 'X',
          description: 'desc',
        ),
        throwsArgumentError,
      );
    });

    test('rejects more than 3 elements', () {
      expect(
        () => ElementCombination(
          elements: [
            Elements.fire,
            Elements.water,
            Elements.wind,
            Elements.earth,
          ],
          resultId: 'x',
          resultName: 'X',
          description: 'desc',
        ),
        throwsArgumentError,
      );
    });

    test('duplicate elements collapse to a distinct set', () {
      final combo = ElementCombination(
        elements: [Elements.fire, Elements.fire, Elements.wind],
        resultId: 'x',
        resultName: 'X',
        description: 'desc',
      );
      expect(combo.elements, hasLength(2));
    });

    test('defaults damage to 0', () {
      final combo = ElementCombination(
        elements: [Elements.fire, Elements.wind],
        resultId: 'x',
        resultName: 'X',
        description: 'desc',
      );
      expect(combo.damage, equals(0));
    });
  });

  group('CombinationBook', () {
    test('resolves Fogo + Vento to Tempestade Ígnea', () {
      final result = defaultCombinationBook.resolve(
        [Elements.fire, Elements.wind],
      );
      expect(result, isNotNull);
      expect(result!.resultId, equals('ignited_storm'));
    });

    test('resolve is order-independent', () {
      final a = defaultCombinationBook.resolve([Elements.fire, Elements.wind]);
      final b = defaultCombinationBook.resolve([Elements.wind, Elements.fire]);
      expect(a, isNotNull);
      expect(a!.resultId, equals(b!.resultId));
    });

    test('resolves a 3-element combination (Terra + Fogo + Água = Lava)', () {
      final result = defaultCombinationBook.resolve(
        [Elements.earth, Elements.fire, Elements.water],
      );
      expect(result, isNotNull);
      expect(result!.resultId, equals('lava'));
    });

    test('returns null for an unknown combination', () {
      final result = defaultCombinationBook.resolve(
        [Elements.ice, Elements.shadow],
      );
      expect(result, isNull);
    });

    test('a 2-element subset of a known 3-element combo does not match', () {
      final result = defaultCombinationBook.resolve(
        [Elements.earth, Elements.fire],
      );
      expect(result, isNull);
    });

    test('the built-in combinations carry their damage value', () {
      final twoElement = defaultCombinationBook.resolve(
        [Elements.fire, Elements.wind],
      )!;
      final threeElement = defaultCombinationBook.resolve(
        [Elements.earth, Elements.fire, Elements.water],
      )!;

      expect(twoElement.damage, equals(20));
      expect(twoElement.result.damage, equals(20));
      expect(threeElement.damage, equals(35));
      expect(threeElement.result.damage, equals(35));
    });
  });
}
