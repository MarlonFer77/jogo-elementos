import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:app/game_domain/dungeon_progress.dart';
import 'package:app/game_domain/dungeon_progress_store.dart';
import 'package:app/game_presentation/pixel_element_chip.dart';
import 'package:app/game_presentation/sfx_player.dart';
import 'package:app/ui/dungeon_screen.dart';
import 'package:app/ui/training_screen.dart';
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
    if (Platform.environment['ELEMENTOS_ART_PREVIEW'] == '1' &&
        Platform.isWindows) {
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
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
    testWidgets('scouting and preparation remain usable at $size', (
      tester,
    ) async {
      final p = DungeonProgress()
          .prepare(['fire', 'wind'])
          .copyWith(
            active: true,
            run: 1,
            encounters: List.filled(10, 'control'),
          );
      SharedPreferences.setMockInitialValues({
        DungeonProgressStore.key: jsonEncode(p.toJson()),
      });
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: DungeonScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('PRÓXIMO · SALA 1/10').hitTestable(), findsOneWidget);
      expect(find.text('Controle').hitTestable(), findsOneWidget);
      expect(find.text('Elementos').hitTestable(), findsOneWidget);
      expect(find.text('Habilidades').hitTestable(), findsOneWidget);
      expect(find.text('Sala 1/10 · Entrar').hitTestable(), findsOneWidget);
      expect(find.text('Árvore · 0').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (Platform.environment['ELEMENTOS_ART_PREVIEW'] == '1') {
        await tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            'build/gameplay-preview/scouting-${size.width.toInt()}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.tap(find.byTooltip('Repertório do inimigo'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Fulgor\n'), findsOneWidget);
      await tester.tap(find.text('Entendi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elementos'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PixelElementChip).last);
      await tester.pump();
      // Rotation preserves the pending choice without saving it early.
      tester.view.physicalSize = Size(size.height, size.width);
      await tester.pumpAndSettle();
      expect(find.text('Elementos · 1/4'), findsOneWidget);
      expect((await DungeonProgressStore().load()).elements.length, 2);
      await tester.tap(find.text('Equipar'));
      await tester.pumpAndSettle();
      expect((await DungeonProgressStore().load()).elements, ['fire']);
      expect((await DungeonProgressStore().load()).encounters, p.encounters);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('start reveals a saved route before the first battle', (
    tester,
  ) async {
    final p = DungeonProgress().prepare(['fire', 'wind']);
    SharedPreferences.setMockInitialValues({
      DungeonProgressStore.key: jsonEncode(p.toJson()),
    });
    await tester.pumpWidget(const MaterialApp(home: DungeonScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Iniciar expedição'));
    await tester.pumpAndSettle();
    final saved = await DungeonProgressStore().load();
    expect(saved.encounters.length, 10);
    expect(find.byType(TrainingScreen), findsNothing);
    expect(find.text('PRÓXIMO · SALA 1/10'), findsOneWidget);
    await tester.tap(find.byTooltip('Encerrar tentativa · manter ganhos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect((await DungeonProgressStore().load()).encounters, saved.encounters);
    await tester.tap(find.text('Sala 1/10 · Entrar'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final battle = tester.widget<TrainingScreen>(find.byType(TrainingScreen));
    expect(battle.encounter!.room.tactic, saved.roomAt(0).tactic);
    expect(battle.encounter!.room.pattern, saved.roomAt(0).pattern);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('boss briefing and primary actions tolerate larger text', (
    tester,
  ) async {
    final p = DungeonProgress()
        .prepare(['fire', 'wind'])
        .copyWith(
          active: true,
          run: 1,
          room: 9,
          blessings: ['first_spark', 'deep_reserve', 'last_breath'],
          encounters: List.filled(10, 'control'),
        );
    SharedPreferences.setMockInitialValues({
      DungeonProgressStore.key: jsonEncode(p.toJson()),
    });
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: const DungeonScreen(),
      ),
    );
    for (final size in [const Size(360, 640), const Size(568, 320)]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(find.text('Sala 10/10 · Entrar').hitTestable(), findsOneWidget);
      await tester.ensureVisible(find.text('Habilidades'));
      await tester.pumpAndSettle();
      expect(find.text('Habilidades').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
  });
}
