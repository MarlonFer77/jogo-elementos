/// Descreve um ataque que já aconteceu no domínio (dano e efeitos já
/// aplicados) para a apresentação reencenar visualmente. Dado puro, sem
/// dependência de Flutter/Flame nem de `battle_engine` — mesmo espírito de
/// [BattleSceneView].
class AttackEvent {
  /// Identifica esta ocorrência de forma única — usado por
  /// `BattleSceneGame` para não tocar a mesma sequência duas vezes.
  final int sequenceId;

  final bool attackerIsLeft;

  /// Ids dos elementos jogados (ex: `['fire', 'wind']`) — a apresentação
  /// resolve símbolo/cor a partir disso, nunca embutidos aqui.
  final List<String> elementIds;

  final String? comboName;
  final int damage;
  final List<String> appliedStatusNames;
  final bool isDefend;
  final bool isFrozenRecovery;

  const AttackEvent({
    required this.sequenceId,
    required this.attackerIsLeft,
    required this.elementIds,
    this.comboName,
    required this.damage,
    required this.appliedStatusNames,
    this.isDefend = false,
    this.isFrozenRecovery = false,
  });
}
