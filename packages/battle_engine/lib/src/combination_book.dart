import 'element.dart';
import 'element_combination.dart';

/// Looks up the [ElementCombination] (if any) matching a set of elements.
/// Pure function over data — no I/O, no rendering, no Flutter/Flame.
class CombinationBook {
  final List<ElementCombination> combinations;

  CombinationBook(this.combinations);

  /// Returns the combination matching exactly [elements] (order-independent),
  /// or null if that set has no known combination.
  ElementCombination? resolve(Iterable<Element> elements) {
    final query = Set<Element>.from(elements);
    for (final combo in combinations) {
      if (combo.elements.length == query.length &&
          combo.elements.containsAll(query)) {
        return combo;
      }
    }
    return null;
  }
}
