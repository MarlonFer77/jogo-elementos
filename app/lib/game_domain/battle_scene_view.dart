/// Read-only view of what the battle scene should show: a fraction of HP
/// per side and whose turn it is. Game Presentation (Flame) nunca toca em
/// tipos de `battle_engine` ou do backend diretamente — renderiza um
/// [BattleSceneView], que cada tela monta a partir do que já expõe
/// (`TrainingMatch`/`MultiplayerMatch`). Sem lógica: é um dado puro.
class BattleSceneView {
  final int leftCurrentHp;
  final int leftMaxHp;
  final int rightCurrentHp;
  final int rightMaxHp;
  final bool isLeftTurn;

  const BattleSceneView({
    required this.leftCurrentHp,
    required this.leftMaxHp,
    required this.rightCurrentHp,
    required this.rightMaxHp,
    required this.isLeftTurn,
  });
}
