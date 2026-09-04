import 'dart:convert';

import 'package:app/game_domain/multiplayer_client.dart';
import 'package:app/ui/multiplayer_lobby_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets(
    'creating a match navigates to the battle screen showing the code and '
    '"aguardando oponente"',
    (WidgetTester tester) async {
      final client = MultiplayerClient(
        baseUrl: 'http://x',
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'id': 'ABC123',
              'playerAId': 'ana',
              'playerBId': null,
              'status': 'waiting_for_opponent',
              'state': null,
            }),
            201,
          );
        }),
      );

      await tester.pumpWidget(
        MaterialApp(home: MultiplayerLobbyScreen(client: client)),
      );

      await tester.enterText(find.byType(TextField).first, 'ana');
      await tester.tap(find.text('Criar partida'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Aguardando oponente...'), findsOneWidget);
      expect(find.text('Compartilhe o código: ABC123'), findsOneWidget);

      // Dispose the battle screen (and its poll Timer) before the test ends.
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('shows an error and does not navigate when the name is empty',
      (WidgetTester tester) async {
    final client = MultiplayerClient(
      baseUrl: 'http://x',
      httpClient: MockClient((request) async {
        throw StateError('should not be called');
      }),
    );

    await tester.pumpWidget(
      MaterialApp(home: MultiplayerLobbyScreen(client: client)),
    );

    await tester.tap(find.text('Criar partida'));
    await tester.pump();

    expect(find.text('Informe seu nome.'), findsOneWidget);
    expect(find.text('Multiplayer'), findsOneWidget); // still on the lobby
  });

  testWidgets('shows the backend error when joining an unknown code',
      (WidgetTester tester) async {
    final client = MultiplayerClient(
      baseUrl: 'http://x',
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'match "GHOST1" not found'}),
          404,
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(home: MultiplayerLobbyScreen(client: client)),
    );

    await tester.enterText(find.byType(TextField).first, 'ana');
    await tester.enterText(find.byType(TextField).last, 'GHOST1');
    await tester.tap(find.text('Entrar com código'));
    await tester.pump();
    await tester.pump();

    expect(find.text('match "GHOST1" not found'), findsOneWidget);
  });

  testWidgets(
    'reconnecting fetches the match by code and lands back on the battle '
    'screen',
    (WidgetTester tester) async {
      final client = MultiplayerClient(
        baseUrl: 'http://x',
        httpClient: MockClient((request) async {
          expect(request.method, 'GET');
          return http.Response(
            jsonEncode({
              'id': 'ABC123',
              'playerAId': 'ana',
              'playerBId': 'beto',
              'status': 'in_progress',
              'state': {
                'playerAId': 'ana',
                'playerBId': 'beto',
                'currentTurnId': 'beto',
                'activeFieldEffects': [],
                'hp': {
                  'ana': {'max': 100, 'current': 100},
                  'beto': {'max': 100, 'current': 100},
                },
                'winner': null,
              },
            }),
            200,
          );
        }),
      );

      await tester.pumpWidget(
        MaterialApp(home: MultiplayerLobbyScreen(client: client)),
      );

      await tester.enterText(find.byType(TextField).first, 'ana');
      await tester.enterText(find.byType(TextField).last, 'ABC123');
      await tester.tap(find.text('Reconectar'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Vez do oponente'), findsOneWidget);

      await tester.pumpWidget(const SizedBox()); // dispose the poll Timer
    },
  );

  testWidgets(
    'shows an error when reconnecting as someone not part of the match',
    (WidgetTester tester) async {
      final client = MultiplayerClient(
        baseUrl: 'http://x',
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'id': 'ABC123',
              'playerAId': 'ana',
              'playerBId': 'beto',
              'status': 'in_progress',
              'state': {
                'playerAId': 'ana',
                'playerBId': 'beto',
                'currentTurnId': 'ana',
                'activeFieldEffects': [],
                'hp': {
                  'ana': {'max': 100, 'current': 100},
                  'beto': {'max': 100, 'current': 100},
                },
                'winner': null,
              },
            }),
            200,
          );
        }),
      );

      await tester.pumpWidget(
        MaterialApp(home: MultiplayerLobbyScreen(client: client)),
      );

      await tester.enterText(find.byType(TextField).first, 'carla');
      await tester.enterText(find.byType(TextField).last, 'ABC123');
      await tester.tap(find.text('Reconectar'));
      await tester.pump();
      await tester.pump();

      expect(find.text('você não faz parte da partida "ABC123"'), findsOneWidget);
    },
  );
}
