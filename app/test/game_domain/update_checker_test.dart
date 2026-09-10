import 'package:app/game_domain/update_checker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isNewerVersion', () {
    test('returns false when versions are equal', () {
      expect(isNewerVersion('0.8.0', '0.8.0'), isFalse);
    });

    test('returns true when the remote patch is newer', () {
      expect(isNewerVersion('0.8.1', '0.8.0'), isTrue);
    });

    test('returns true when the remote minor is newer', () {
      expect(isNewerVersion('0.9.0', '0.8.5'), isTrue);
    });

    test('returns true when the remote major is newer', () {
      expect(isNewerVersion('1.0.0', '0.9.9'), isTrue);
    });

    test('returns false when the remote is older', () {
      expect(isNewerVersion('0.7.0', '0.8.0'), isFalse);
    });

    test('treats missing segments as zero', () {
      expect(isNewerVersion('0.9', '0.9.0'), isFalse);
      expect(isNewerVersion('0.9.1', '0.9'), isTrue);
    });
  });
}
