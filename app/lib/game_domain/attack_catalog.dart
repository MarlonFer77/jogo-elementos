import 'package:battle_engine/battle_engine.dart';

/// Game Domain's own value type for a combination shown as an
/// equippable "attack" (Bloco 2c) — UI never names `ElementCombination`
/// directly (DECISION-011/017).
class AttackOption {
  final String id;
  final String name;
  final String description;
  final bool unlocked;
  final bool equipped;
  final List<String> elementIds;
  final int apCost;

  const AttackOption({
    required this.id,
    required this.name,
    required this.description,
    required this.unlocked,
    required this.equipped,
    this.elementIds = const [],
    this.apCost = 0,
  });
}

/// Todas as combinações de `defaultCombinationBook`, marcadas com o
/// que um jogador específico já desbloqueou/equipou — quem chama
/// decide se esconde as entradas ainda não desbloqueadas (ver
/// `attacks_screen.dart`).
List<AttackOption> allAttackOptions({
  required List<String> unlockedIds,
  required List<String> equippedIds,
}) {
  return defaultCombinationBook.combinations
      .map(
        (combo) => AttackOption(
          id: combo.resultId,
          name: combo.resultName,
          description: combo.description,
          unlocked: unlockedIds.contains(combo.resultId),
          equipped: equippedIds.contains(combo.resultId),
          elementIds: List.unmodifiable(combo.elements.map((e) => e.id)),
          apCost: combo.elements.length == 2 ? 3 : 5,
        ),
      )
      .toList();
}
