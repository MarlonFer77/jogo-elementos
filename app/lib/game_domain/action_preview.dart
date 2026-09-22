/// Read-only prediction of a complete action, including existing status ticks.
class ActionPreview {
  final int apCost;
  final int apAfter;
  final int opponentHpLoss;
  final int selfHpLoss;
  final List<String> effects;
  final bool regeneratesAp;

  const ActionPreview({
    required this.apCost,
    required this.apAfter,
    required this.opponentHpLoss,
    required this.selfHpLoss,
    this.effects = const [],
    this.regeneratesAp = true,
  });

  String get summary =>
      'Custo $apCost AP · restam $apAfter AP '
      '${regeneratesAp ? '(inclui +1 ao agir)' : '(sem regenerar ao descongelar)'}\n'
      'HP previsto: adversário −$opponentHpLoss'
      '${selfHpLoss > 0 ? ' · você −$selfHpLoss' : ''}'
      '${effects.isEmpty ? '' : '\n${effects.join(' · ')}'}';
}
