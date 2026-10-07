import 'package:battle_engine/battle_engine.dart';

/// Game Domain's own value type for a combination's display info — so UI
/// code never needs to name `battle_engine`'s `ElementCombination`.
class CombinationOption {
  final String id;
  final String name;
  final String description;
  final List<String> elementIds;
  final bool cleanses;
  final int directDamage;

  const CombinationOption({
    required this.id,
    required this.name,
    required this.description,
    required this.elementIds,
    this.cleanses = false,
    this.directDamage = 0,
  });
}

/// Maps a combination's result id (e.g. "ignited_storm") to its display
/// name/description. The Multiplayer backend only ever sends ids — by
/// design, the client is expected to already know the names from its own
/// catalog (see the doc comment on FieldEffect in backend/src/battle-rules)
/// — this is that catalog.
class CombinationCatalog {
  const CombinationCatalog();

  CombinationOption? byId(String id) {
    for (final combination in defaultCombinationBook.combinations) {
      if (combination.resultId == id) {
        return CombinationOption(
          id: combination.resultId,
          name: combination.resultName,
          description: combination.description,
          elementIds: combination.elements.map((e) => e.id).toList(),
          cleanses: combination.cleanses,
          directDamage: combination.damage,
        );
      }
    }
    return null;
  }

  CombinationOption? byElements(List<String> ids) {
    final set = ids.toSet();
    for (final combo in defaultCombinationBook.combinations) {
      if (combo.elements.length == set.length &&
          combo.elements.every((e) => set.contains(e.id))) {
        return byId(combo.resultId);
      }
    }
    return null;
  }
}
