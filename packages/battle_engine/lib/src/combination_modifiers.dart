import 'combination_modifier.dart';

/// Built-in combination modifiers, illustrating the design's example: the
/// same "Fogo + Vento → Tempestade Ígnea" combination coming out differently
/// depending on the build that triggered it.
class CombinationModifiers {
  CombinationModifiers._();

  static final propagation = CombinationModifier(
    id: 'propagation',
    name: 'Propagação',
    description: 'Aumenta a área do efeito de campo resultante.',
    apply: (effect) => effect.copyWith(area: effect.area + 2),
  );

  static final volatility = CombinationModifier(
    id: 'volatility',
    name: 'Instabilidade',
    description: 'Reduz a duração do efeito de campo resultante em 1 turno.',
    apply: (effect) {
      final duration = effect.duration;
      if (duration == null) return effect;
      return effect.copyWith(duration: duration > 0 ? duration - 1 : 0);
    },
  );

  static final List<CombinationModifier> all = [propagation, volatility];
}
