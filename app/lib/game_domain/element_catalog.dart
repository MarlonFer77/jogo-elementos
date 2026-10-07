import 'package:battle_engine/battle_engine.dart';

/// Compact affordance only: the engine/server remains authoritative.
String basicActionDetail(String elementId, Iterable<String> statusIds) {
  if (elementId == 'water' && statusIds.contains('burn')) {
    return '0 AP · apaga fogo · base 3';
  }
  if (elementId == 'nature' && statusIds.contains('poison')) {
    return '0 AP · antídoto · base 3';
  }
  return '0 AP';
}

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
