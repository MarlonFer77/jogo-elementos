import 'package:battle_engine/battle_engine.dart';
import 'package:test/test.dart';

void main() {
  final ignitedStorm = defaultCombinationBook.resolve(
    [Elements.fire, Elements.wind],
  )!;
  final electrifiedField = defaultCombinationBook.resolve(
    [Elements.water, Elements.lightning],
  )!;

  group('DiscoveryBook', () {
    test('starts with nothing discovered', () {
      final book = DiscoveryBook();
      expect(book.isDiscovered(ignitedStorm), isFalse);
    });

    test('withDiscovered marks a combination as discovered without '
        'mutating the original book', () {
      final book = DiscoveryBook();
      final next = book.withDiscovered(ignitedStorm);

      expect(next.isDiscovered(ignitedStorm), isTrue);
      expect(book.isDiscovered(ignitedStorm), isFalse);
    });

    test('discovering one combination does not affect another', () {
      final book = DiscoveryBook().withDiscovered(ignitedStorm);
      expect(book.isDiscovered(electrifiedField), isFalse);
    });

    test('discovering an already-discovered combination returns the same '
        'instance', () {
      final book = DiscoveryBook().withDiscovered(ignitedStorm);
      final again = book.withDiscovered(ignitedStorm);
      expect(identical(book, again), isTrue);
    });
  });

  group('DiscoveryBook.entriesFor', () {
    test('returns one entry per combination in the book, all undiscovered '
        'at first', () {
      final book = DiscoveryBook();
      final entries = book.entriesFor(defaultCombinationBook);

      expect(entries, hasLength(defaultCombinationBook.combinations.length));
      expect(entries.every((e) => !e.discovered), isTrue);
    });

    test('reflects which combinations have been discovered', () {
      final book = DiscoveryBook().withDiscovered(ignitedStorm);
      final entries = book.entriesFor(defaultCombinationBook);

      final ignitedEntry = entries.firstWhere(
        (e) => e.combination.resultId == ignitedStorm.resultId,
      );
      final otherEntry = entries.firstWhere(
        (e) => e.combination.resultId == electrifiedField.resultId,
      );

      expect(ignitedEntry.discovered, isTrue);
      expect(otherEntry.discovered, isFalse);
    });
  });
}
