import 'dart:convert';

import 'package:app/game_domain/update_checker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

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

  group('UpdateChecker.checkForUpdate', () {
    test('rejects incomplete or untrusted release assets', () async {
      final asset = <String, Object?>{
        'name': 'app-release.apk',
        'state': 'uploaded',
        'size': 100,
        'digest': 'sha256:${'a' * 64}',
        'browser_download_url':
            'https://github.com/MarlonFer77/jogo-elementos/releases/download/v0.9.0/app-release.apk',
      };
      for (final change in <Map<String, Object?>>[
        {'name': 'source.zip'},
        {'state': 'new'},
        {'size': 0},
        {'digest': null},
        {'digest': 'sha256:bad'},
        {'browser_download_url': 'https://example.com/app-release.apk'},
      ]) {
        final checker = UpdateChecker(
          httpClient: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'tag_name': 'v0.9.0',
                'assets': [
                  {...asset, ...change},
                ],
              }),
              200,
            ),
          ),
        );
        final result = await checker.checkForUpdate(currentVersion: '0.8.0');
        expect(result.updateAvailable, isFalse, reason: '$change');
        expect(result.error, isNotNull, reason: '$change');
      }
    });

    test('times out without claiming the app is current', () async {
      final checker = UpdateChecker(
        timeout: const Duration(milliseconds: 1),
        httpClient: MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return http.Response('{}', 200);
        }),
      );
      expect(
        (await checker.checkForUpdate(currentVersion: '0.8.0')).error,
        isNotNull,
      );
    });

    test('returns updateAvailable when the release tag is newer', () async {
      final client = MockClient((request) async {
        expect(request.headers['User-Agent'], 'jogo-elementos-app');
        return http.Response(
          jsonEncode({
            'tag_name': 'v0.9.0',
            'assets': [
              {
                'name': 'app-release.apk',
                'state': 'uploaded',
                'size': 100,
                'digest': 'sha256:${'a' * 64}',
                'browser_download_url':
                    'https://github.com/MarlonFer77/jogo-elementos/releases/download/v0.9.0/app-release.apk',
              },
            ],
          }),
          200,
        );
      });
      final checker = UpdateChecker(httpClient: client);

      final result = await checker.checkForUpdate(currentVersion: '0.8.0');

      expect(result.updateAvailable, isTrue);
      expect(result.latestVersion, '0.9.0');
      expect(result.checksum, 'a' * 64);
      expect(
        result.downloadUrl,
        'https://github.com/MarlonFer77/jogo-elementos/releases/download/v0.9.0/app-release.apk',
      );
    });

    test('returns upToDate when the release tag is the same version', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'tag_name': 'v0.8.0',
            'assets': <Map<String, dynamic>>[],
          }),
          200,
        );
      });
      final checker = UpdateChecker(httpClient: client);

      final result = await checker.checkForUpdate(currentVersion: '0.8.0');

      expect(result.updateAvailable, isFalse);
    });

    test('reports failed check when the response is not 200', () async {
      final client = MockClient((request) async => http.Response('', 404));
      final checker = UpdateChecker(httpClient: client);

      final result = await checker.checkForUpdate(currentVersion: '0.8.0');

      expect(result.updateAvailable, isFalse);
      expect(result.error, isNotNull);
    });

    test('reports failed check when offline', () async {
      final client = MockClient((request) async {
        throw Exception('no network');
      });
      final checker = UpdateChecker(httpClient: client);

      final result = await checker.checkForUpdate(currentVersion: '0.8.0');

      expect(result.updateAvailable, isFalse);
      expect(result.error, isNotNull);
    });
  });
}
