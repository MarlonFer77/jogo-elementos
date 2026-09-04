import 'combination_book.dart';
import 'discovery_entry.dart';
import 'element_combination.dart';

/// Tracks which [ElementCombination]s a player has discovered (triggered
/// at least once), by `resultId`. Meta-progression, not battle state — it
/// outlives a single battle and needs no network (offline, section 12).
///
/// Purely data: nothing here calls this automatically. Whoever processes a
/// [TurnResult]/[AbilityResult] and sees a `triggeredCombination` decides
/// to call [withDiscovered] — the Battle Engine's turn/ability resolvers
/// stay unaware of meta-progression, same as they are of builds/skills.
class DiscoveryBook {
  final Set<String> discoveredCombinationIds;

  DiscoveryBook({Set<String> discoveredCombinationIds = const {}})
      : discoveredCombinationIds = Set.unmodifiable(discoveredCombinationIds);

  bool isDiscovered(ElementCombination combination) =>
      discoveredCombinationIds.contains(combination.resultId);

  /// Returns a new book with [combination] marked as discovered, or this
  /// same instance if it already was.
  DiscoveryBook withDiscovered(ElementCombination combination) {
    if (isDiscovered(combination)) return this;
    return DiscoveryBook(
      discoveredCombinationIds: {
        ...discoveredCombinationIds,
        combination.resultId,
      },
    );
  }

  /// One [DiscoveryEntry] per combination in [book], in the same order,
  /// each flagged with whether it's been discovered.
  List<DiscoveryEntry> entriesFor(CombinationBook book) {
    return book.combinations
        .map(
          (combination) => DiscoveryEntry(
            combination: combination,
            discovered: isDiscovered(combination),
          ),
        )
        .toList();
  }
}
