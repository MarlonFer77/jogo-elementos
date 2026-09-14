import 'attack_event.dart';
import 'effect_badge_view.dart';

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
  final AttackEvent? lastAttack;
  final String leftLabel;
  final String rightLabel;
  final List<EffectBadgeView> leftStatuses;
  final List<EffectBadgeView> rightStatuses;
  final List<EffectBadgeView> fieldEffects;
  final int leftAp;
  final int leftApMax;
  final int rightAp;
  final int rightApMax;

  const BattleSceneView({
    required this.leftCurrentHp,
    required this.leftMaxHp,
    required this.rightCurrentHp,
    required this.rightMaxHp,
    required this.isLeftTurn,
    this.lastAttack,
    this.leftLabel = 'Esquerda',
    this.rightLabel = 'Direita',
    this.leftStatuses = const [],
    this.rightStatuses = const [],
    this.fieldEffects = const [],
    this.leftAp = 0,
    this.leftApMax = 5,
    this.rightAp = 0,
    this.rightApMax = 5,
  });
}
