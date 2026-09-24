import 'combatant.dart';
import 'element.dart';

/// A turn action: [actor] plays a set of elements, attempting to trigger a
/// combination. 1 element is a valid play (no combination possible); 2 or 3
/// elements may resolve into an [ElementCombination] via [CombinationBook].
class TurnAction {
  final Combatant actor;
  final List<Element> elements;
  final bool isDefend;
  final bool isThaw;
  final bool isFizzle;

  TurnAction.fizzle({required this.actor})
    : elements = const [],
      isDefend = false,
      isThaw = false,
      isFizzle = true;

  TurnAction.defend({required this.actor})
    : elements = const [],
      isDefend = true,
      isThaw = false,
      isFizzle = false;

  TurnAction.thaw({required this.actor})
    : elements = const [],
      isDefend = false,
      isThaw = true,
      isFizzle = false;

  TurnAction({required this.actor, required Iterable<Element> elements})
    : elements = List.unmodifiable(elements),
      isDefend = false,
      isThaw = false,
      isFizzle = false {
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
