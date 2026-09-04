/// A named effect currently active on the battlefield (not tied to a
/// specific combatant). Produced either by resolving an [ElementCombination]
/// or by an ability [Mutation].
///
/// [area] and [duration] are abstract magnitudes — this engine has no
/// spatial/tile model, so [area] is just "how big" for a future
/// presentation layer to interpret. [duration] is turns remaining on the
/// field; `null` means permanent. [damage] is the one-time damage dealt to
/// the opponent when this effect is produced by a triggered combination —
/// it is not recurring damage for as long as the effect stays on the
/// field. All three exist so a [CombinationModifier] has something
/// concrete to change (bigger area, shorter duration, more damage).
class FieldEffect {
  final String id;
  final String name;
  final String description;
  final int area;
  final int? duration;
  final int damage;

  const FieldEffect({
    required this.id,
    required this.name,
    required this.description,
    this.area = 1,
    this.duration,
    this.damage = 0,
  });

  FieldEffect copyWith({int? area, int? duration, int? damage}) {
    return FieldEffect(
      id: id,
      name: name,
      description: description,
      area: area ?? this.area,
      duration: duration ?? this.duration,
      damage: damage ?? this.damage,
    );
  }

  @override
  bool operator ==(Object other) => other is FieldEffect && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'FieldEffect($id)';
}
