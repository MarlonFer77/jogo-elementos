import 'package:battle_engine/battle_engine.dart';

class DiscoveryEntry {
  const DiscoveryEntry({
    required this.id,
    required this.name,
    required this.description,
    required this.elements,
    required this.damage,
    required this.apCost,
    required this.learned,
    required this.equipped,
    required this.unavailableReason,
  });
  final String id, name, description;
  final List<String> elements;
  final int damage, apCost;
  final bool learned, equipped;
  final String? unavailableReason;

  bool matches({
    String query = '',
    String? element,
    int? cost,
    bool equippedOnly = false,
  }) {
    final search = _normalize(query.trim());
    final recipeNames = Elements.all
        .where((e) => elements.contains(e.id))
        .map((e) => e.name)
        .join(' ');
    return (!equippedOnly || equipped) &&
        (element == null || elements.contains(element)) &&
        (cost == null || apCost == cost) &&
        _normalize('$name $description $recipeNames').contains(search);
  }
}

String _normalize(String text) {
  var value = text.toLowerCase();
  const groups = {
    'a': 'áàâãä',
    'e': 'éèêë',
    'i': 'íìîï',
    'o': 'óòôõö',
    'u': 'úùûü',
    'c': 'ç',
  };
  for (final entry in groups.entries) {
    for (final letter in entry.value.split('')) {
      value = value.replaceAll(letter, entry.key);
    }
  }
  return value;
}

class DiscoveryCatalog {
  const DiscoveryCatalog();
  int get total => defaultCombinationBook.combinations.length;

  /// Hidden recipes never leave this projection. Legacy/stale IDs are ignored.
  List<DiscoveryEntry> entries({
    required Iterable<String> discoveredIds,
    required Iterable<String> learnedIds,
    required Iterable<String> equippedIds,
    required String? Function(String id) unavailableReason,
  }) {
    final found = discoveredIds.toSet(),
        learned = learnedIds.toSet(),
        equipped = equippedIds.toSet();
    return [
      for (final combo in defaultCombinationBook.combinations)
        if (found.contains(combo.resultId))
          DiscoveryEntry(
            id: combo.resultId,
            name: combo.resultName,
            description: combo.description,
            elements: List.unmodifiable(combo.elements.map((e) => e.id)),
            damage: combo.damage,
            apCost: combo.elements.length == 2 ? 3 : 5,
            learned: learned.contains(combo.resultId),
            equipped:
                learned.contains(combo.resultId) &&
                equipped.contains(combo.resultId),
            unavailableReason:
                learned.contains(combo.resultId) &&
                    equipped.contains(combo.resultId)
                ? unavailableReason(combo.resultId)
                : null,
          ),
    ];
  }
}
