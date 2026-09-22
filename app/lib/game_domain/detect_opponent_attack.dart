import 'attack_event.dart';
import 'combination_catalog.dart';

/// Deduz um [AttackEvent] pra jogada do oponente no Multiplayer, descoberta
/// via poll (o backend não manda quais elementos foram jogados — ver
/// docs/superpowers/specs/2026-09-08-attack-feedback-sequence-design.md).
/// Retorna `null` quando não há nada de novo pra encenar (nenhum efeito de
/// campo novo, ou o novo efeito não corresponde a uma queda de HP local —
/// defensivo, nunca deveria acontecer dado que só combinação causa dano).
AttackEvent? detectOpponentAttack({
  required Set<String> previousFieldEffectIds,
  required Set<String> newFieldEffectIds,
  required int myHpBefore,
  required int myHpAfter,
  required int sequenceId,
  List<String> appliedStatusNames = const [],
}) {
  final newlyAppeared = newFieldEffectIds.difference(previousFieldEffectIds);
  if (newlyAppeared.isEmpty) return null;

  final damage = myHpBefore - myHpAfter;
  if (damage <= 0) return null;

  final combo = const CombinationCatalog().byId(newlyAppeared.first);
  if (combo == null) return null;

  return AttackEvent(
    sequenceId: sequenceId,
    attackerIsLeft: false,
    elementIds: combo.elementIds,
    comboName: combo.name,
    damage: damage,
    appliedStatusNames: appliedStatusNames,
  );
}
