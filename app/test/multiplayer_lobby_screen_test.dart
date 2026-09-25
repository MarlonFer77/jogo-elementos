import 'dart:async';
import 'dart:convert';
import 'package:app/game_domain/multiplayer_client.dart';
import 'package:app/game_presentation/pixel_menu_button.dart';
import 'package:app/ui/element_starter_screen.dart';
import 'package:app/ui/multiplayer_lobby_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> waitingRoom() => {
  'id': 'ABC123',
  'revision': 0,
  'status': 'waiting_for_opponent',
  'playerAId': 'ana',
  'playerBId': null,
  'state': null,
  'players': {
    'ana': {
      'ready': false,
      'elements': [],
      'attacks': [],
      'discoveries': [],
      'turns': 0,
    },
  },
  'skillProgress': {'ana': []},
};

MultiplayerClient client(
  Future<http.Response> Function(http.Request) handler,
) => MultiplayerClient(baseUrl: 'http://test', httpClient: MockClient(handler));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'create shows real progress, blocks duplicates and opens room before preparation',
    (tester) async {
      final response = Completer<http.Response>();
      var requests = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MultiplayerLobbyScreen(
            client: client((request) {
              requests++;
              expectSync(request.method, 'POST');
              if (request.url.path.endsWith('/configure')) {
                final prepared = waitingRoom();
                prepared['players']['ana']['ready'] = true;
                return Future.value(http.Response(jsonEncode(prepared), 200));
              }
              return response.future;
            }),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField).first, 'ana');
      await tester.ensureVisible(find.text('Criar partida'));
      final button = tester.widget<PixelMenuButton>(
        find.widgetWithText(PixelMenuButton, 'Criar partida'),
      );
      button.onPressed!();
      button.onPressed!();
      await tester.pump();
      await tester.pump();
      expect(requests, 1);
      expect(find.text('CRIANDO SALA'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(
        tester.widget<PopScope>(find.byType(PopScope).first).canPop,
        isFalse,
      );
      response.complete(http.Response(jsonEncode(waitingRoom()), 201));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('ABC123'), findsOneWidget);
      expect(find.text('Copiar código'), findsOneWidget);
      expect(find.text('Oponente · aguardando entrada'), findsOneWidget);
      await tester.ensureVisible(find.text('Preparar elementos'));
      await tester.tap(find.text('Preparar elementos'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ElementStarterScreen), findsOneWidget);
      expect(requests, 1);
      tester
          .widget<ElementStarterScreen>(find.byType(ElementStarterScreen))
          .onConfirm(['fire', 'wind']);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ElementStarterScreen), findsNothing);
      expect(find.textContaining('Tudo pronto do seu lado.'), findsOneWidget);
      expect(requests, 2);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('name and code validation never send requests', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MultiplayerLobbyScreen(
          client: client((_) async => throw StateError('Unexpected request')),
        ),
      ),
    );
    await tester.ensureVisible(find.text('Criar partida'));
    await tester.tap(find.text('Criar partida'));
    await tester.pump();
    expect(find.text('Informe seu nome.'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'ana');
    await tester.tap(find.text('Entrar'));
    await tester.pump();
    await tester.ensureVisible(find.text('Entrar com código'));
    await tester.tap(find.text('Entrar com código'));
    await tester.pump();
    expect(
      find.text('Informe o código de 6 caracteres da sala.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('unknown room is friendly and retains typed values', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MultiplayerLobbyScreen(
          client: client((request) async {
            expect(request.url.path, '/matches/GHOST1/join');
            return http.Response(jsonEncode({'error': 'not found'}), 404);
          }),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField).first, 'ana');
    await tester.tap(find.text('Entrar'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, 'ghost1');
    await tester.ensureVisible(find.text('Entrar com código'));
    await tester.tap(find.text('Entrar com código'));
    await tester.pump();
    await tester.pump();
    expect(
      find.text('Sala não encontrada. Confira o código com seu amigo.'),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).last).controller!.text,
      'ghost1',
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('resume uses the saved identity instead of the edited name', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'multiplayer.lastPlayer.http://test': 'ana',
      'multiplayer.lastCode.http://test': 'ABC123',
    });
    var requests = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MultiplayerLobbyScreen(
          client: client((request) async {
            requests++;
            expect(request.method, 'GET');
            expect(request.url.path, '/matches/ABC123');
            return http.Response(jsonEncode(waitingRoom()), 200);
          }),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'outro nome');
    await tester.ensureVisible(find.text('Retomar última sala'));
    await tester.tap(find.text('Retomar última sala'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('ana (você) · Preparando elementos'), findsOneWidget);
    expect(requests, 1);
    await tester.pumpWidget(const SizedBox());
  });

  for (final size in [const Size(360, 640), const Size(740, 360)]) {
    testWidgets('lobby scrolls safely with keyboard at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 180);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        const MaterialApp(home: MultiplayerLobbyScreen()),
      );
      await tester.ensureVisible(find.text('Entrar'));
      await tester.tap(find.text('Entrar'));
      await tester.pump();
      await tester.ensureVisible(find.text('Entrar com código'));
      expect(find.text('Entrar com código').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
