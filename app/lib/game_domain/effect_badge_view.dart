/// Dado puro pra um badge de status ativo (por jogador) ou efeito de
/// campo (compartilhado): [id] mapeia pra ícone/cor em
/// `game_presentation/status_visuals.dart`; [remainingTurns] é `null`
/// quando o efeito não tem contagem visível — Escudo dura até ser
/// consumido, e nenhuma combinação atual define duração de campo.
class EffectBadgeView {
  final String id;
  final int? remainingTurns;

  const EffectBadgeView({required this.id, this.remainingTurns});

  @override
  bool operator ==(Object other) =>
      other is EffectBadgeView &&
      other.id == id &&
      other.remainingTurns == remainingTurns;

  @override
  int get hashCode => Object.hash(id, remainingTurns);
}
