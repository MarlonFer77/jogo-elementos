import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:app/game_domain/dungeon_progress.dart';
import 'package:app/game_domain/dungeon_progress_store.dart';
import 'package:app/game_presentation/pixel_menu_button.dart';
import 'package:app/game_presentation/sfx_player.dart';
import 'package:app/ui/dungeon_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    final previous = sfxPlayer;
    sfxPlayer = SfxPlayer(play: (_) {});
    addTearDown(() => sfxPlayer = previous);
  });
  setUpAll(() async {
    // Optional local preview fonts; normal tests remain platform-independent.
    if (Platform.environment['ELEMENTOS_ART_PREVIEW'] == '1' &&
        Platform.isWindows) {
      for (final font in [('Roboto', 'segoeui'), ('monospace', 'consola')]) {
        final file = File('C:/Windows/Fonts/${font.$2}.ttf');
        if (await file.exists()) {
          await (FontLoader(font.$1)..addFont(
                Future.value(ByteData.sublistView(await file.readAsBytes())),
              ))
              .load();
        }
      }
    }
  });
  for (final size in [const Size(360, 640), const Size(568, 320)]) {
    testWidgets('altar choice and confirmation remain usable at $size', (
      tester,
    ) async {
      final progress = DungeonProgress()
          .prepare(['fire', 'wind'])
          .copyWith(active: true, run: 1, room: 3);
      SharedPreferences.setMockInitialValues({
        DungeonProgressStore.key: jsonEncode(progress.toJson()),
      });
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      Future<void> show() => tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: const MaterialApp(home: DungeonScreen()),
        ),
      );
      await show();
      await tester.pump();
      await tester.pump();
      expect(find.text('ALTAR · SALA 3'), findsOneWidget);
      expect(find.text('Sala 4/10 · Entrar'), findsNothing);
      expect(
        tester
            .widget<PixelMenuButton>(
              find.widgetWithText(PixelMenuButton, 'Receber bênção'),
            )
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('blessing-first_spark')),
      );
      await tester.tap(find.byKey(const ValueKey('blessing-first_spark')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('Receber bênção').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (Platform.environment['ELEMENTOS_ART_PREVIEW'] == '1') {
        await tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            'build/gameplay-preview/altar-${size.width.toInt()}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      // Rotation keeps the pending selection; it never saves before confirmation.
      tester.view.physicalSize = Size(size.height, size.width);
      await tester.pump();
      expect(
        tester
            .widget<PixelMenuButton>(
              find.widgetWithText(PixelMenuButton, 'Receber bênção'),
            )
            .onPressed,
        isNotNull,
      );
      expect((await DungeonProgressStore().load()).blessings, isEmpty);
      await tester.tap(find.text('Receber bênção'));
      await tester.pump();
      await tester.pump();
      expect((await DungeonProgressStore().load()).blessings, ['first_spark']);
      expect(find.text('Sala 4/10 · Entrar').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await show();
      await tester.pump();
      await tester.pump();
      expect(find.text('ALTAR · SALA 3'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
