import 'package:battle_engine/battle_engine.dart';

/// Game Domain's own value type for an element — so UI code never needs to
/// name (or import) `battle_engine`'s `Element` type, not even implicitly.
class ElementOption {
  final String id;
  final String name;
  final String symbol;

  const ElementOption({
    required this.id,
    required this.name,
    required this.symbol,
  });
}

/// Game Domain's view of the element catalog — the seam between Battle
/// Engine data and the presentation layer, so UI code never imports
/// `battle_engine` directly.
class ElementCatalog {
  const ElementCatalog();

  List<ElementOption> all() => Elements.all
      .map((e) => ElementOption(id: e.id, name: e.name, symbol: e.symbol))
      .toList();
}
