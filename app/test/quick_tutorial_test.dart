import 'package:app/game_presentation/sfx_player.dart';
import 'package:app/settings/game_settings.dart';
import 'package:app/ui/quick_tutorial_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final size in [const Size(320, 568), const Size(568, 320)]) {
    testWidgets('guide completes, persists and can replay at $size', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final settings = GameSettings();
      final originalAudio = sfxPlayer;
      sfxPlayer = SfxPlayer(play: (_) {});
      addTearDown(() => sfxPlayer = originalAudio);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('Abrir guia'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => QuickTutorialScreen(settings: settings),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir guia'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        expect(find.text('Próximo').hitTestable(), findsOneWidget);
        await tester.tap(find.text('Próximo'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Vamos jogar').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Vamos jogar'));
      await tester.pumpAndSettle();
      expect(find.text('Abrir guia'), findsOneWidget);
      final restored = GameSettings();
      await restored.load();
      expect(restored.tutorialSeen, isTrue);
      await tester.tap(find.text('Abrir guia'));
      await tester.pumpAndSettle();
      expect(find.text('1/4 · Escolha sua jornada'), findsOneWidget);
      await tester.tap(find.text('Pular'));
      await tester.pumpAndSettle();
      expect(find.text('Abrir guia'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
