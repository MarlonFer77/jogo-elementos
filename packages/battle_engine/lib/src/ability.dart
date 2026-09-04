import 'element.dart';
import 'mutation.dart';

/// A skill a combatant can use, e.g. "Bola de Fogo": the elements it plays
/// and the mutations currently attached to it. Two combatants can use the
/// same base elements with different mutations and get different abilities.
class Ability {
  final String id;
  final String name;
  final List<Element> baseElements;
  final List<Mutation> mutations;

  Ability({
    required this.id,
    required this.name,
    required Iterable<Element> baseElements,
    List<Mutation> mutations = const [],
  })  : baseElements = List.unmodifiable(baseElements),
        mutations = List.unmodifiable(mutations) {
    if (this.baseElements.isEmpty) {
      throw ArgumentError.value(
        baseElements,
        'baseElements',
        'must play at least one element',
      );
    }
  }

  /// Returns a copy of this ability with [mutation] attached. Mutations are
  /// applied in attachment order when the ability resolves.
  Ability withMutation(Mutation mutation) {
    return Ability(
      id: id,
      name: name,
      baseElements: baseElements,
      mutations: [...mutations, mutation],
    );
  }

  @override
  bool operator ==(Object other) => other is Ability && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Ability($id)';
}
