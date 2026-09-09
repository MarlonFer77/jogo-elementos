import 'package:app/ui/home_screen.dart';
import 'package:app/ui/multiplayer_lobby_screen.dart';
import 'package:app/ui/training_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the title and both menu buttons', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    expect(find.text('ELEMENTOS'), findsOneWidget);
    expect(find.text('MODO TREINO'), findsOneWidget);
    expect(find.text('MULTIPLAYER'), findsOneWidget);
  });

  testWidgets('MODO TREINO navigates to TrainingScreen', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    await tester.tap(find.text('MODO TREINO'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(TrainingScreen), findsOneWidget);
  });

  testWidgets('MULTIPLAYER navigates to MultiplayerLobbyScreen',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    await tester.tap(find.text('MULTIPLAYER'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(MultiplayerLobbyScreen), findsOneWidget);
  });
}
