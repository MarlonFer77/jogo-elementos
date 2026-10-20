import 'package:app/game_domain/account_auth.dart';
import 'package:app/game_domain/beta_adventure_store.dart';
import 'package:app/game_domain/beta_session.dart';
import 'package:app/game_domain/multiplayer_exception.dart';
import 'package:app/game_presentation/beta_game.dart';
import 'package:app/game_presentation/sfx_player.dart';
import 'package:app/ui/beta_access_screen.dart';
import 'package:app/ui/beta_screen.dart';
import 'package:app/ui/multiplayer_login_screen.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TestAuth extends AccountAuth {
  bool signed = false, confirmed = false;
  int registrations = 0, emails = 0;
  @override
  bool get configured => true;
  @override
  bool get hasSession => signed;
  @override
  Future<void> restore() async {}
  @override
  Future<void> signIn(
    String address,
    String password, {
    bool register = false,
  }) async {
    signed = true;
    uid = 'firebase-test-id';
    email = address;
    if (register) registrations++;
  }

  @override
  Future<void> sendVerification() async {
    emails++;
  }

  @override
  Future<void> verifyIdentity() async {
    if (!confirmed) {
      throw MultiplayerException('Confirme seu e-mail antes de continuar.');
    }
    emailVerified = true;
  }

  @override
  Future<void> signOut() async {
    signed = false;
    uid = null;
    emailVerified = false;
  }
}

Future<void> frame(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

class FailingAdventureStore extends BetaAdventureStore {
  FailingAdventureStore() : super('disk-test');
  bool fail = true;
  @override
  Future<void> save(BetaCheckpoint checkpoint) async {
    if (fail) throw StateError('Disk unavailable');
    await super.save(checkpoint);
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final previous = sfxPlayer;
    sfxPlayer = SfxPlayer(play: (_) {});
    addTearDown(() => sfxPlayer = previous);
  });
  testWidgets('save error is visible and exit waits until retry succeeds', (
    tester,
  ) async {
    final store = FailingAdventureStore();
    await tester.pumpWidget(
      MaterialApp(home: BetaScreen(adventureStore: store)),
    );
    await frame(tester);
    expect(find.textContaining('Falha ao salvar.'), findsOneWidget);
    await tester.ensureVisible(find.text('Voltar ao menu'));
    await tester.tap(find.text('Voltar ao menu'));
    await frame(tester);
    expect(find.byType(BetaScreen), findsOneWidget);
    expect(await store.load(), isNull);
    store.fail = false;
    await tester.ensureVisible(find.text('Tentar salvar novamente'));
    await tester.tap(find.text('Tentar salvar novamente'));
    await frame(tester);
    expect(await store.load(), isNotNull);
    expect(
      find.textContaining('Checkpoint salvo neste aparelho'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });
  for (final size in [const Size(320, 568), const Size(568, 320)]) {
    testWidgets(
      'registration confirms password and email, returns Firebase UID at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final auth = TestAuth();
        String? returned;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    returned = await Navigator.push<String>(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            MultiplayerLoginScreen(auth: auth, adventure: true),
                      ),
                    );
                  },
                  child: const Text('Abrir cadastro'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Abrir cadastro'));
        await frame(tester);
        await tester.enterText(
          find.byType(TextField).at(0),
          'tester@example.invalid',
        );
        await tester.enterText(find.byType(TextField).at(1), 'safe-password');
        await tester.enterText(find.byType(TextField).at(2), 'different');
        await tester.ensureVisible(find.text('Criar conta'));
        await tester.tap(find.text('Criar conta'));
        await frame(tester);
        expect(auth.registrations, 0);
        expect(
          find.text('A confirmação da senha não confere.'),
          findsOneWidget,
        );
        await tester.enterText(find.byType(TextField).at(2), 'safe-password');
        await tester.ensureVisible(find.text('Criar conta'));
        await tester.tap(find.text('Criar conta'));
        await frame(tester);
        expect(auth.registrations, 1);
        expect(auth.emails, 1);
        expect(find.text('ID: firebase-test-id'), findsOneWidget);
        final continueButton = find.text('Continuar / já confirmei o e-mail');
        await tester.ensureVisible(continueButton);
        await tester.tap(continueButton);
        await frame(tester);
        expect(returned, isNull);
        auth.confirmed = true;
        await tester.ensureVisible(continueButton);
        await tester.tap(continueButton);
        await frame(tester);
        expect(returned, 'firebase-test-id');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'saved adventure resumes paused and account switch cannot reuse another UID',
    (tester) async {
      final auth = TestAuth()
        ..signed = true
        ..confirmed = true
        ..emailVerified = true
        ..uid = 'firebase-test-id'
        ..email = 'tester@example.invalid';
      final store = BetaAdventureStore(auth.uid!);
      final run = BetaSession()..start();
      run.enemies.clear();
      run.pause();
      await store.save(run.latestCheckpoint!);
      await tester.pumpWidget(MaterialApp(home: BetaAccessScreen(auth: auth)));
      await frame(tester);
      await tester.enterText(find.byType(TextField), '032431');
      await tester.ensureVisible(find.text('Continuar aventura'));
      await tester.tap(find.text('Continuar aventura'));
      await frame(tester);
      final game = tester
          .widget<GameWidget<BetaGame>>(find.byType(GameWidget<BetaGame>))
          .game!;
      expect(game.session.phase, BetaPhase.paused);
      expect(game.session.remaining, 0);
      await tester.ensureVisible(find.text('Voltar ao menu'));
      await tester.tap(find.text('Voltar ao menu'));
      await frame(tester);
      await tester.tap(find.text('Salvar e sair'));
      for (
        var i = 0;
        i < 5 && find.byType(BetaScreen).evaluate().isNotEmpty;
        i++
      ) {
        await frame(tester);
      }
      expect(find.byType(BetaScreen), findsNothing);
      await tester.ensureVisible(find.text('Nova aventura'));
      await tester.tap(find.text('Nova aventura'));
      await frame(tester);
      await tester.tap(find.text('Cancelar'));
      await frame(tester);
      expect((await store.load())!.cleared, true);
      await tester.ensureVisible(find.text('Trocar conta (mantém os saves)'));
      await tester.tap(find.text('Trocar conta (mantém os saves)'));
      await frame(tester);
      expect(find.text('Criar conta / entrar'), findsOneWidget);
      expect(find.text('Continuar aventura'), findsNothing);
      expect((await store.load())!.cleared, true);
    },
  );
}
