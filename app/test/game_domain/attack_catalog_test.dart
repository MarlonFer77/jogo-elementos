import 'package:app/game_domain/attack_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('allAttackOptions lists every known combination with display info', () {
    final options = allAttackOptions(unlockedIds: const [], equippedIds: const []);

    expect(options, isNotEmpty);
    final stormOption = options.firstWhere((o) => o.id == 'ignited_storm');
    expect(stormOption.name, 'Tempestade Ígnea');
    expect(stormOption.unlocked, isFalse);
    expect(stormOption.equipped, isFalse);
  });

  test('allAttackOptions marks unlocked/equipped ids correctly', () {
    final options = allAttackOptions(
      unlockedIds: const ['ignited_storm'],
      equippedIds: const ['ignited_storm'],
    );

    final stormOption = options.firstWhere((o) => o.id == 'ignited_storm');
    expect(stormOption.unlocked, isTrue);
    expect(stormOption.equipped, isTrue);

    final otherOption = options.firstWhere((o) => o.id != 'ignited_storm');
    expect(otherOption.unlocked, isFalse);
    expect(otherOption.equipped, isFalse);
  });
}
