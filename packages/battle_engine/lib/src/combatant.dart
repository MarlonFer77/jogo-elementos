/// A battle participant. Identity is by [id]; [name] is display-only.
class Combatant {
  final String id;
  final String name;

  const Combatant({required this.id, required this.name});

  @override
  bool operator ==(Object other) => other is Combatant && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Combatant($id)';
}
