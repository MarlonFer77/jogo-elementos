import 'package:flutter/material.dart' show Color;

import '../game_domain/element_catalog.dart';

const Map<String, Color> _elementColors = {
  'fire': Color(0xFFE85D3D),
  'water': Color(0xFF3D8FE8),
  'wind': Color(0xFF7FD1C4),
  'ice': Color(0xFF9EE8F5),
  'nature': Color(0xFF6FBF4F),
  'lightning': Color(0xFFF5D33D),
  'earth': Color(0xFF8A6A4B),
  'shadow': Color(0xFF4B4B5C),
  'light': Color(0xFFF5EFC8),
  'poison': Color(0xFF8B4FBF),
};

/// Cor de identidade de [elementId] — usada só no passo "Efeito elemental"
/// da sequência de ataque (ver
/// docs/superpowers/specs/2026-09-08-attack-feedback-sequence-design.md).
/// Cinza como fallback — nunca deveria ser atingido com um id real do
/// `ElementCatalog`, mas evita quebrar caso a lista de elementos mude.
Color elementColor(String elementId) =>
    _elementColors[elementId] ?? const Color(0xFF9E9E9E);

/// Símbolo (emoji) de [elementId], resolvido a partir do `ElementCatalog`
/// já existente — nenhuma duplicação de dado.
String elementSymbol(String elementId) {
  for (final element in const ElementCatalog().all()) {
    if (element.id == elementId) return element.symbol;
  }
  return '?';
}
