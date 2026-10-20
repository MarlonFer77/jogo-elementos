import 'dart:async';
import 'dart:convert';
import 'package:app/game_domain/account_auth.dart';
import 'package:app/game_domain/multiplayer_client.dart';
import 'package:app/game_domain/multiplayer_exception.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });
  test(
    'login persists no password, restore refreshes once for concurrent calls, logout clears',
    () async {
      var refreshes = 0;
      final client = MockClient((req) async {
        if (req.url.host == 'securetoken.googleapis.com') {
          refreshes++;
          return http.Response(
            jsonEncode({
              'id_token': 'renewed',
              'refresh_token': 'refresh2',
              'user_id': 'user',
              'expires_in': '3600',
            }),
            200,
          );
        }
        expect(req.url.host, 'identitytoolkit.googleapis.com');
        return http.Response(
          jsonEncode({
            'idToken': 'first',
            'refreshToken': 'refresh1',
            'localId': 'user',
            'expiresIn': '3600',
          }),
          200,
        );
      });
      final auth = AccountAuth(apiKey: 'test-key', httpClient: client);
      await auth.signIn('a@example.invalid', 'not-saved');
      final storage = await const FlutterSecureStorage().readAll();
      expect(storage.values.single, isNot(contains('not-saved')));
      expect(storage.values.single, isNot(contains('first')));
      final restored = AccountAuth(apiKey: 'test-key', httpClient: client);
      await restored.restore();
      expect(await Future.wait([restored.idToken(), restored.idToken()]), [
        'renewed',
        'renewed',
      ]);
      expect(refreshes, 1);
      await restored.signOut();
      expect(await const FlutterSecureStorage().readAll(), isEmpty);
      await expectLater(
        restored.idToken(),
        throwsA(isA<MultiplayerException>()),
      );
    },
  );
  test('in-flight refresh cannot resurrect signed-out account', () async {
    FlutterSecureStorage.setMockInitialValues({
      'elementos.firebase.session.test-key': jsonEncode({
        'refresh': 'r',
        'uid': 'u',
        'email': 'a@example.invalid',
      }),
    });
    final gate = Completer<http.Response>();
    final auth = AccountAuth(
      apiKey: 'test-key',
      httpClient: MockClient((_) => gate.future),
    );
    await auth.restore();
    final refreshing = auth.idToken();
    final rejected = expectLater(
      refreshing,
      throwsA(isA<MultiplayerException>()),
    );
    final logout = auth.signOut();
    gate.complete(
      http.Response(
        jsonEncode({
          'id_token': 't',
          'refresh_token': 'r2',
          'user_id': 'u',
          'expires_in': '3600',
        }),
        200,
      ),
    );
    await rejected;
    await logout;
    expect(auth.hasSession, isFalse);
    expect(await const FlutterSecureStorage().readAll(), isEmpty);
  });
  test('sign-out invalidates an in-flight identity verification', () async {
    final lookup = Completer<http.Response>(), started = Completer<void>();
    final auth = AccountAuth(
      apiKey: 'test-key',
      httpClient: MockClient((req) async {
        if (req.url.path.endsWith(':lookup')) {
          started.complete();
          return lookup.future;
        }
        return http.Response(
          jsonEncode(
            req.url.host == 'securetoken.googleapis.com'
                ? {
                    'id_token': 't',
                    'refresh_token': 'r',
                    'user_id': 'u',
                    'expires_in': '3600',
                  }
                : {
                    'idToken': 't',
                    'refreshToken': 'r',
                    'localId': 'u',
                    'expiresIn': '3600',
                  },
          ),
          200,
        );
      }),
    );
    await auth.signIn('a@example.invalid', 'not-saved');
    final verifying = auth.verifyIdentity();
    final rejected = expectLater(
      verifying,
      throwsA(isA<MultiplayerException>()),
    );
    await started.future;
    final logout = auth.signOut();
    lookup.complete(
      http.Response(
        jsonEncode({
          'users': [
            {'localId': 'u', 'emailVerified': true},
          ],
        }),
        200,
      ),
    );
    await rejected;
    await logout;
    expect(auth.hasSession, false);
    expect(auth.emailVerified, false);
    expect(await const FlutterSecureStorage().readAll(), isEmpty);
  });
  test(
    'adventure verifies Firebase UID and email before caching offline identity',
    () async {
      var verified = false;
      final auth = AccountAuth(
        apiKey: 'test-key',
        httpClient: MockClient((req) async {
          if (req.url.host == 'securetoken.googleapis.com') {
            return http.Response(
              jsonEncode({
                'id_token': 't',
                'refresh_token': 'r',
                'user_id': 'u',
                'expires_in': '3600',
              }),
              200,
            );
          }
          if (req.url.path.endsWith(':lookup')) {
            expect(jsonDecode(req.body)['idToken'], 't');
            return http.Response(
              jsonEncode({
                'users': [
                  {'localId': 'u', 'emailVerified': verified},
                ],
              }),
              200,
            );
          }
          expect(req.url.path, endsWith(':signUp'));
          return http.Response(
            jsonEncode({
              'idToken': 't',
              'refreshToken': 'r',
              'localId': 'u',
              'expiresIn': '3600',
            }),
            200,
          );
        }),
      );
      await auth.signIn('a@example.invalid', 'not-stored', register: true);
      expect(auth.uid, 'u');
      await expectLater(
        auth.verifyIdentity(),
        throwsA(isA<MultiplayerException>()),
      );
      expect(auth.emailVerified, false);
      verified = true;
      await auth.verifyIdentity();
      final offline = AccountAuth(apiKey: 'test-key');
      await offline.restore();
      expect(offline.uid, 'u');
      expect(offline.emailVerified, true);
      expect(offline.hasSession, true);
      await offline.signOut();
      expect(offline.emailVerified, false);
    },
  );
  test(
    'recovery hides unknown email but does not hide disabled provider',
    () async {
      var code = 'EMAIL_NOT_FOUND';
      final auth = AccountAuth(
        apiKey: 'test-key',
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'error': {'message': code},
            }),
            400,
          ),
        ),
      );
      await auth.resetPassword('a@example.invalid');
      code = 'OPERATION_NOT_ALLOWED';
      await expectLater(
        auth.resetPassword('a@example.invalid'),
        throwsA(isA<MultiplayerException>()),
      );
    },
  );
  test(
    'account client uses refreshed JWT and namespaces last room; never falls back to legacy',
    () async {
      SharedPreferences.setMockInitialValues({
        'multiplayer.session.http://x': 'legacy-secret',
        'multiplayer.lastPlayer.http://x': 'old',
      });
      var value = 'jwt1';
      final client = MultiplayerClient(
        baseUrl: 'http://x',
        accountId: 'user',
        idToken: () async => value,
        httpClient: MockClient((req) async {
          expect(req.headers['Authorization'], 'Bearer $value');
          return http.Response('{"playerId":"ana"}', 200);
        }),
      );
      await client.account();
      value = 'jwt2';
      await client.account();
      await client.rememberSession('ABC123', 'ana');
      expect(await client.lastSession(), ('ana', 'ABC123'));
      expect(
        (await SharedPreferences.getInstance()).getString(
          'multiplayer.lastPlayer.http://x',
        ),
        'old',
      );
    },
  );
}
