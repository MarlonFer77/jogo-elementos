import 'package:app/game_domain/account_auth.dart';
import 'package:app/ui/multiplayer_login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final size in [const Size(360, 640), const Size(740, 360)]) {
    testWidgets(
      'login is usable in $size with keyboard and does not expose password',
      (tester) async {
        FlutterSecureStorage.setMockInitialValues({});
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: MultiplayerLoginScreen(auth: AccountAuth(apiKey: 'test-key')),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('E-mail'), findsOneWidget);
        expect(find.text('Senha'), findsOneWidget);
        expect(
          tester.widgetList<TextField>(find.byType(TextField)).last.obscureText,
          isTrue,
        );
        tester.view.viewInsets = const FakeViewPadding(bottom: 160);
        addTearDown(tester.view.resetViewInsets);
        await tester.pump();
        await tester.ensureVisible(find.text('Esqueci minha senha'));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
