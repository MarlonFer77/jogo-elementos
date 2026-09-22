import 'combatant.dart';
import 'element.dart';

/// A turn action: [actor] plays a set of elements, attempting to trigger a
/// combination. 1 element is a valid play (no combination possible); 2 or 3
/// elements may resolve into an [ElementCombination] via [CombinationBook].
class TurnAction {
  final Combatant actor;
  final List<Element> elements;
  final bool isDefend;

  TurnAction.defend({required this.actor})
    : elements = const [],
      isDefend = true;

  TurnAction({required this.actor, required Iterable<Element> elements})
    : elements = List.unmodifiable(elements),
      isDefend = false {
    if (this.elements.isEmpty ||
        this.elements.length > 3 ||
        this.elements.toSet().length != this.elements.length) {
      throw ArgumentError.value(
        elements,
        'elements',
        'must play at least one element',
      );
    }
  }
}
