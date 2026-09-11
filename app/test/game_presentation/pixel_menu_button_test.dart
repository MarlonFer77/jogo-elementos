import 'package:app/game_presentation/pixel_menu_button.dart';
import 'package:app/game_presentation/sfx_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the label and calls onPressed when tapped',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PixelMenuButton(
          label: 'MODO TREINO',
          onPressed: () => tapped = true,
        ),
      ),
    ));

    expect(find.text('MODO TREINO'), findsOneWidget);

    await tester.tap(find.text('MODO TREINO'));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('does not throw and stays inert when onPressed is null',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: PixelMenuButton(label: 'Jogar', onPressed: null)),
    ));

    expect(find.text('Jogar'), findsOneWidget);

    await tester.tap(find.text('Jogar'));
    await tester.pump();
  });

  testWidgets(
      'shows a pressed-in offset while held down, and releases it back',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PixelMenuButton(label: 'Jogar', onPressed: () {}),
      ),
    ));

    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Jogar')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    final pressed =
        tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
    expect(pressed.transform, Matrix4.translationValues(3, 3, 0));

    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    final released =
        tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
    expect(released.transform, Matrix4.translationValues(0, 0, 0));
  });

  testWidgets('plays a tap sound when pressed while enabled',
      (tester) async {
    final playedPaths = <String>[];
    sfxPlayer = SfxPlayer(play: playedPaths.add);
    addTearDown(() => sfxPlayer = SfxPlayer());

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PixelMenuButton(label: 'Jogar', onPressed: () {}),
      ),
    ));

    await tester.tap(find.text('Jogar'));
    await tester.pump();

    expect(playedPaths, ['tap.wav']);
  });

  testWidgets('does not play a sound when disabled', (tester) async {
    final playedPaths = <String>[];
    sfxPlayer = SfxPlayer(play: playedPaths.add);
    addTearDown(() => sfxPlayer = SfxPlayer());

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: PixelMenuButton(label: 'Jogar', onPressed: null)),
    ));

    await tester.tap(find.text('Jogar'));
    await tester.pump();

    expect(playedPaths, isEmpty);
  });
}
