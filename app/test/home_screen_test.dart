import 'package:app/ui/home_screen.dart';
import 'package:app/ui/multiplayer_lobby_screen.dart';
import 'package:app/ui/training_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in [
    const Size(360, 800),
    const Size(800, 360),
    const Size(568, 320),
  ]) {
    testWidgets('home adapts to $size without hiding mode buttons', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      expect(
        find.byKey(
          ValueKey(
            size.width > size.height ? 'home-landscape' : 'home-portrait',
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('MODO TREINO').hitTestable(), findsOneWidget);
      expect(find.text('MULTIPLAYER').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('shows the title and both menu buttons', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    expect(find.text('ELEMENTOS'), findsOneWidget);
    expect(find.text('MODO TREINO'), findsOneWidget);
    expect(find.text('MULTIPLAYER'), findsOneWidget);

    await tester.pumpWidget(
      const SizedBox(),
    ); // dispose the idle AnimationControllers
  });

  testWidgets('MODO TREINO navigates to TrainingScreen', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    await tester.tap(find.text('MODO TREINO'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(TrainingScreen), findsOneWidget);

    // Returning from a mode must release the navigation lock.
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('MODO TREINO'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(TrainingScreen), findsOneWidget);

    await tester.pumpWidget(
      const SizedBox(),
    ); // dispose the idle AnimationControllers
  });

  testWidgets('MULTIPLAYER navigates to MultiplayerLobbyScreen', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    await tester.tap(find.text('MULTIPLAYER'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(MultiplayerLobbyScreen), findsOneWidget);

    await tester.pumpWidget(
      const SizedBox(),
    ); // dispose the idle AnimationControllers
  });
}
