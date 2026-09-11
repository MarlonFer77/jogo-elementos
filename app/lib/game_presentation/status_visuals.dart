import 'package:flutter/material.dart' show Color;

const Map<String, String> _statusIcons = {
  'burn': '🔥',
  'freeze': '❄️',
  'wet': '💧',
  'poison': '☠️',
  'shock': '⚡',
  'slow': '🐌',
  'shield': '🛡️',
  'silence': '🤐',
  'buff': '⬆️',
  'debuff': '⬇️',
  'area_effect': '🌀',
};

const Map<String, Color> _statusColors = {
  'burn': Color(0xFFFF7043),
  'freeze': Color(0xFF64B5F6),
  'wet': Color(0xFF4FC3F7),
  'poison': Color(0xFFAB47BC),
  'shock': Color(0xFFFFD54F),
  'slow': Color(0xFF8D6E63),
  'shield': Color(0xFF90CAF9),
  'silence': Color(0xFFBCAAA4),
  'buff': Color(0xFF81C784),
  'debuff': Color(0xFFE57373),
  'area_effect': Color(0xFFCE93D8),
};

const Map<String, String> _fieldEffectIcons = {
  'ignited_storm': '🌪️',
  'electrified_field': '🌩️',
  'lava': '🌋',
};

/// Ícone (emoji) de um badge de status ativo por jogador. `?` como
/// fallback — nunca deveria ser atingido com um id real de
/// `StatusEffects.all` (`packages/battle_engine`), mas evita quebrar
/// caso a lista de status mude.
String statusIcon(String statusId) => _statusIcons[statusId] ?? '?';

/// Cor do badge de status ativo por jogador. Cinza como fallback, mesmo
/// padrão de `element_visuals.dart`.
Color statusColor(String statusId) =>
    _statusColors[statusId] ?? const Color(0xFF9E9E9E);

/// Ícone (emoji) de um badge de efeito de campo. Fallback genérico (✨)
/// pra qualquer `FieldEffect`/combinação sem entrada dedicada — mantém
/// data-driven: uma combinação nova não quebra nada, só usa o fallback
/// até alguém adicionar o ícone específico.
String fieldEffectIcon(String fieldEffectId) =>
    _fieldEffectIcons[fieldEffectId] ?? '✨';
