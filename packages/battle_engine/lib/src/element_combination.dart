import 'element.dart';
import 'field_effect.dart';
import 'targeted_status.dart';

/// Data-driven rule mapping a set of 2 or 3 distinct [Element]s to a
/// resulting effect. Order of the input elements does not matter.
///
/// This is plain data — how a build modifies the resolved effect (area,
/// duration, damage, etc.) is a concern for a later layer, not for this
/// class.
class ElementCombination {
  final Set<Element> elements;
  final String resultId;
  final String resultName;
  final String description;
  final int damage;
  final int healing;
  final bool cleanses;
  final int apDrain;
  final List<TargetedStatus> statusesToApply;

  ElementCombination({
    required Iterable<Element> elements,
    required this.resultId,
    required this.resultName,
    required this.description,
    this.damage = 0,
    this.healing = 0,
    this.cleanses = false,
    this.apDrain = 0,
    this.statusesToApply = const [],
  }) : elements = Set.unmodifiable(Set.of(elements)) {
    if (damage < 0 || healing < 0 || apDrain < 0) {
      throw ArgumentError('Combination values must not be negative');
    }
    if (this.elements.length < 2 || this.elements.length > 3) {
      throw ArgumentError.value(
        elements,
        'elements',
        'ElementCombination requires 2 or 3 distinct elements',
      );
    }
  }

  /// The effect this combination places on the field when triggered.
  FieldEffect get result => FieldEffect(
    id: resultId,
    name: resultName,
    description: description,
    damage: damage,
    healing: healing,
    cleanses: cleanses,
    apDrain: apDrain,
    statusesToApply: statusesToApply,
  );
}
