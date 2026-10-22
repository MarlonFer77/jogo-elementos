import 'dart:convert';
import 'package:app/game_domain/account_auth.dart';
import 'package:app/game_domain/beta_adventure_store.dart';
import 'package:app/game_domain/beta_session.dart';
import 'package:app/game_presentation/sfx_player.dart';
import 'package:app/main.dart';
import 'package:app/ui/account_login_screen.dart';
import 'package:app/ui/app_account_gate.dart';
import 'package:app/ui/beta_access_screen.dart';
import 'package:app/ui/home_screen.dart';
import 'package:app/ui/loading_battle_scene.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'adventure_registration_test.dart' show TestAuth, frame;

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({
      'training_unlocked_a': ['unlock_fire'],
    });
    final previous = sfxPlayer;
    sfxPlayer = SfxPlayer(play: (_) {});
    addTearDown(() => sfxPlayer = previous);
  });

  testWidgets('global opening leads to app registration, not a module', (
    tester,
  ) async {
    await tester.pumpWidget(GameApp(auth: TestAuth()));
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byType(LoadingBattleScene), findsOneWidget);
    await tester.tap(find.text('Toque para entrar'));
    await frame(tester);
    expect(find.text('CONTA ELEMENTOS'), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.byType(BetaAccessScreen), findsNothing);
    expect(find.text('Criar conta'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'email confirmation opens all modes and logout preserves local saves',
    (tester) async {
      final auth = TestAuth();
      final store = BetaAdventureStore('firebase-test-id');
      await store.save((BetaSession()..start()).latestCheckpoint!);
      await tester.pumpWidget(MaterialApp(home: AppAccountGate(auth: auth)));
      await frame(tester);
      await tester.enterText(
        find.byType(TextField).at(0),
        'tester@example.invalid',
      );
      await tester.enterText(find.byType(TextField).at(1), 'safe-password');
      await tester.enterText(find.byType(TextField).at(2), 'safe-password');
      await tester.ensureVisible(find.text('Criar conta'));
      await tester.tap(find.text('Criar conta'));
      await frame(tester);
      expect(find.byType(HomeScreen), findsNothing);
      auth.confirmed = true;
      await tester.ensureVisible(
        find.text('Continuar / já confirmei o e-mail'),
      );
      await tester.tap(find.text('Continuar / já confirmei o e-mail'));
      await frame(tester);
      expect(
        tester.widget<HomeScreen>(find.byType(HomeScreen)).auth,
        same(auth),
      );
      for (final mode in [
        'MODO TREINO',
        'MULTIPLAYER',
        'DUNGEON · SOLO',
        'BETA TEST',
      ]) {
        expect(find.text(mode), findsOneWidget);
      }
      await tester.tap(find.text('BETA TEST'));
      await frame(tester);
      expect(
        tester.widget<BetaAccessScreen>(find.byType(BetaAccessScreen)).auth,
        same(auth),
      );
      expect(find.text('Criar conta'), findsNothing);
      expect(find.text('Continuar aventura'), findsOneWidget);
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await frame(tester);
      await tester.tap(find.byTooltip('Minha conta'));
      await frame(tester);
      await tester.tap(find.text('Sair da conta'));
      await frame(tester);
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.byType(AccountLoginScreen), findsOneWidget);
      expect(
        tester.state<NavigatorState>(find.byType(Navigator).first).canPop(),
        isFalse,
      );
      expect(await store.load(), isNotNull);
      expect(await BetaAdventureStore('another-uid').load(), isNull);
      expect(
        (await SharedPreferences.getInstance()).getStringList(
          'training_unlocked_a',
        ),
        ['unlock_fire'],
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('global logout closes nested module routes', (tester) async {
    final auth = TestAuth()
      ..signed = true
      ..emailVerified = true
      ..uid = 'firebase-test-id';
    await tester.pumpWidget(MaterialApp(home: AppAccountGate(auth: auth)));
    await frame(tester);
    final home = tester.widget<HomeScreen>(find.byType(HomeScreen));
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Module route')),
      ),
    );
    await frame(tester);
    await home.onSignOut!();
    await frame(tester);
    expect(find.text('Module route'), findsNothing);
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.byType(AccountLoginScreen), findsOneWidget);
    expect(navigator.canPop(), isFalse);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 568), const Size(568, 320)]) {
    testWidgets(
      'cached verified account opens all local modes offline at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        FlutterSecureStorage.setMockInitialValues({
          'elementos.firebase.session.': jsonEncode({
            'refresh': 'offline-token',
            'uid': 'existing-uid',
            'email': 'tester@example.invalid',
            'verified': true,
          }),
        });
        await tester.pumpWidget(const MaterialApp(home: AppAccountGate()));
        await frame(tester);
        expect(find.byType(HomeScreen), findsOneWidget);
        for (final mode in [
          'MODO TREINO',
          'MULTIPLAYER',
          'DUNGEON · SOLO',
          'BETA TEST',
        ]) {
          expect(find.text(mode).hitTestable(), findsOneWidget);
        }
        expect(find.byTooltip('Minha conta').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('corrupt session cannot bypass account gate or delete progress', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({
      'elementos.firebase.session.': 'invalid',
    });
    await tester.pumpWidget(
      MaterialApp(home: AppAccountGate(auth: AccountAuth())),
    );
    await frame(tester);
    expect(find.textContaining('Seus dados foram preservados'), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    await tester.tap(find.text('Sair e entrar novamente'));
    await frame(tester);
    expect(find.byType(AccountLoginScreen), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance()).getStringList(
        'training_unlocked_a',
      ),
      ['unlock_fire'],
    );
    expect(tester.takeException(), isNull);
  });
}
