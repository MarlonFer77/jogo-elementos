import 'max_hp_bonus.dart';

/// Built-in max HP bonuses. Data-driven — new bonuses are added as
/// entries here, not as new logic.
class MaxHpBonuses {
  MaxHpBonuses._();

  static const vitality = MaxHpBonus(
    id: 'vitality',
    name: 'Vitalidade',
    description: 'Aumenta o HP máximo em 20.',
    bonus: 20,
  );

  static const List<MaxHpBonus> all = [vitality];
}
