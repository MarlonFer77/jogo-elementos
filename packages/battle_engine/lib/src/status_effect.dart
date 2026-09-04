/// A status effect definition (e.g. Burn, Shield). Data-driven, like
/// [Element] — adding a new status is a new entry, not new branching logic.
class StatusEffect {
  final String id;
  final String name;
  final String description;

  const StatusEffect({
    required this.id,
    required this.name,
    required this.description,
  });

  @override
  bool operator ==(Object other) => other is StatusEffect && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'StatusEffect($id)';
}
