import 'element.dart';

/// Built-in elements. Data-driven: adding a new element means adding a new
/// entry here, not new branching logic elsewhere.
class Elements {
  Elements._();

  static const fire = Element(id: 'fire', name: 'Fogo', symbol: '🔥');
  static const water = Element(id: 'water', name: 'Água', symbol: '💧');
  static const wind = Element(id: 'wind', name: 'Vento', symbol: '🌪️');
  static const ice = Element(id: 'ice', name: 'Gelo', symbol: '❄️');
  static const nature = Element(id: 'nature', name: 'Natureza', symbol: '🌱');
  static const lightning =
      Element(id: 'lightning', name: 'Raio', symbol: '⚡');
  static const earth = Element(id: 'earth', name: 'Terra', symbol: '🪨');
  static const shadow = Element(id: 'shadow', name: 'Sombra', symbol: '🌑');
  static const light = Element(id: 'light', name: 'Luz', symbol: '✨');
  static const poison = Element(id: 'poison', name: 'Veneno', symbol: '☠️');

  static const List<Element> all = [
    fire,
    water,
    wind,
    ice,
    nature,
    lightning,
    earth,
    shadow,
    light,
    poison,
  ];
}
