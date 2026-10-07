import 'dart:io';
import 'dart:ui' as ui;

import 'package:app/game_domain/arena_theme.dart';
import 'package:app/game_domain/dungeon_catalog.dart';
import 'package:app/game_domain/element_catalog.dart';
import 'package:app/game_presentation/pixel_arena_background.dart';
import 'package:app/game_presentation/battle_character_component.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'every room has a unique arena, and basic recovery hints are conditional',
    () {
      expect(DungeonRoom.all.map((r) => r.arena).toSet().length, 10);
      expect(basicActionDetail('water', ['burn']), contains('base 3'));
      expect(basicActionDetail('nature', ['poison']), contains('base 3'));
      expect(basicActionDetail('water', ['poison']), '0 AP');
    },
  );
  test(
    'all arenas render in portrait/landscape with deterministic bounded weather',
    () async {
      final hashes = <int>{};
      final gallery = ui.PictureRecorder();
      final grid = ui.Canvas(gallery);
      for (final theme in ArenaTheme.values) {
        for (final size in [const ui.Size(360, 240), const ui.Size(568, 300)]) {
          final recorder = ui.PictureRecorder();
          final canvas = ui.Canvas(recorder);
          drawBattleArena(canvas, size, theme: theme, time: 2);
          final picture = recorder.endRecording();
          final image = await picture.toImage(
            size.width.toInt(),
            size.height.toInt(),
          );
          final data = (await image.toByteData())!;
          hashes.add(Object.hashAll(data.buffer.asUint8List()));
          image.dispose();
          picture.dispose();
        }
        grid.save();
        grid.translate((theme.index % 3) * 360.0, (theme.index ~/ 3) * 240.0);
        drawBattleArena(grid, const ui.Size(360, 240), theme: theme, time: 2);
        final enemy = DungeonRoom.all
            .where((r) => r.arena == theme)
            .firstOrNull;
        for (final left in [true, false]) {
          final actor = BattleCharacterComponent(
            side: left ? BattleSide.left : BattleSide.right,
            position: Vector2.zero(),
          );
          if (!left && enemy != null) actor.appearance = enemy.appearance;
          actor.hasGuard = left;
          grid.save();
          grid.translate((left ? 90 : 270) - 32, 240 * .85 - 80);
          actor.render(grid);
          grid.restore();
        }
        grid.restore();
      }
      expect(hashes.length, ArenaTheme.values.length * 2);
      final picture = gallery.endRecording();
      if (const bool.fromEnvironment('ARENA_PREVIEW')) {
        final image = await picture.toImage(1080, 960);
        final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        final file = File('build/gameplay-preview/arenas.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(png.buffer.asUint8List());
        image.dispose();
      }
      picture.dispose();
    },
  );
}
