/// A single game element (e.g. Fire, Water). Immutable and identified by [id].
class Element {
  final String id;
  final String name;
  final String symbol;

  const Element({required this.id, required this.name, required this.symbol});

  @override
  bool operator ==(Object other) => other is Element && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Element($id)';
}
