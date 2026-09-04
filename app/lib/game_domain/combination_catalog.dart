import 'package:battle_engine/battle_engine.dart';

/// Game Domain's own value type for a combination's display info — so UI
/// code never needs to name `battle_engine`'s `ElementCombination`.
class CombinationOption {
  final String id;
  final String name;
  final String description;

  const CombinationOption({
    required this.id,
    required this.name,
    required this.description,
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
        );
      }
    }
    return null;
  }
}
