/// Read-only prediction of a complete action, including existing status ticks.
class ActionPreview {
  final int apCost;
  final int apAfter;
  final int opponentHpLoss;
  final int selfHpLoss;
  final int opponentApLoss;
  final bool cleanses;
  final List<String> effects;
  final bool regeneratesAp;

  const ActionPreview({
    required this.apCost,
    required this.apAfter,
    required this.opponentHpLoss,
    required this.selfHpLoss,
    this.opponentApLoss = 0,
    this.cleanses = false,
    this.effects = const [],
    this.regeneratesAp = true,
  });

  String get summary =>
      'Custo $apCost AP · restam $apAfter AP '
      '${regeneratesAp ? '(inclui +1 ao agir)' : '(sem regeneração nesta ação)'}\n'
      'HP previsto${apCost > 0 ? ' (selo perfeito)' : ''}: adversário −$opponentHpLoss'
      '${selfHpLoss > 0 ? ' · você −$selfHpLoss' : ''}'
      '${selfHpLoss < 0 ? ' · você +${-selfHpLoss} HP' : ''}'
      '${opponentApLoss > 0 ? ' · alvo −$opponentApLoss AP' : ''}'
      '${cleanses ? ' · Purificação' : ''}'
      '${effects.isEmpty ? '' : '\n${effects.join(' · ')}'}';
}
