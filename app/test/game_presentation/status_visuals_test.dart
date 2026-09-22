import 'package:app/game_presentation/status_visuals.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('statusIcon', () {
    test('resolves every known status id to a distinct icon', () {
      const ids = [
        'burn',
        'freeze',
        'wet',
        'poison',
        'shock',
        'slow',
        'shield',
        'silence',
        'buff',
        'debuff',
        'area_effect',
      ];
      final icons = ids.map(statusIcon).toSet();
      expect(icons.length, ids.length);
    });

    test('falls back to "?" for an unknown id', () {
      expect(statusIcon('not_a_real_status'), '?');
    });
  });

  group('statusColor', () {
    test('resolves a known id to a real color', () {
      expect(statusColor('burn'), isNot(const Color(0xFF9E9E9E)));
    });

    test('falls back to grey for an unknown id', () {
      expect(statusColor('not_a_real_status'), const Color(0xFF9E9E9E));
    });
  });

  group('fieldEffectIcon', () {
    test('resolves the known field effects', () {
      expect(fieldEffectIcon('ignited_storm'), '🌪️');
      expect(fieldEffectIcon('electrified_field'), '🌩️');
      expect(fieldEffectIcon('glacial_prison'), '🧊');
      expect(fieldEffectIcon('lava'), '🌋');
    });

    test('falls back to a generic icon for an unknown id', () {
      expect(fieldEffectIcon('not_a_real_combo'), '✨');
    });
  });
}
