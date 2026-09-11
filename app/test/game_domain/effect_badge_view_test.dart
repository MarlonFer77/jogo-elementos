import 'package:app/game_domain/effect_badge_view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('holds id and remainingTurns', () {
    const badge = EffectBadgeView(id: 'burn', remainingTurns: 2);
    expect(badge.id, 'burn');
    expect(badge.remainingTurns, 2);
  });

  test('remainingTurns defaults to null', () {
    const badge = EffectBadgeView(id: 'shield');
    expect(badge.remainingTurns, isNull);
  });

  test('two badges with the same id and remainingTurns are equal', () {
    expect(
      const EffectBadgeView(id: 'burn', remainingTurns: 2),
      const EffectBadgeView(id: 'burn', remainingTurns: 2),
    );
  });

  test('badges with different remainingTurns are not equal', () {
    expect(
      const EffectBadgeView(id: 'burn', remainingTurns: 2),
      isNot(const EffectBadgeView(id: 'burn', remainingTurns: 1)),
    );
  });
}
