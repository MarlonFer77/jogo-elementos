/// Read-only prediction of a complete action, including existing status ticks.
class ActionPreview {
  final int apCost;
  final int apAfter;
  final int opponentHpLoss;
  final int selfHpLoss;
  final List<String> effects;

  const ActionPreview({
    required this.apCost,
    required this.apAfter,
    required this.opponentHpLoss,
    required this.selfHpLoss,
    this.effects = const [],
  });

  String get summary =>
      'Custo $apCost AP · restam $apAfter AP (inclui +1 ao agir)\n'
      'HP previsto: adversário −$opponentHpLoss'
      '${selfHpLoss > 0 ? ' · você −$selfHpLoss' : ''}'
      '${effects.isEmpty ? '' : '\n${effects.join(' · ')}'}';
}
