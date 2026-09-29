import 'dart:io';
import 'dart:ui' as ui;
import 'package:app/game_domain/battle_scene_view.dart';
import 'package:app/game_domain/combatant_appearance.dart';
import 'package:app/game_domain/dungeon_catalog.dart';
import 'package:app/game_presentation/battle_character_component.dart';
import 'package:app/game_presentation/battle_scene_game.dart';
import 'package:app/game_presentation/battle_scene_widget.dart';
import 'package:app/game_presentation/pixel_arena_background.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Optional local review sheet only; CI keeps its default test font.
    if (Platform.environment['ELEMENTOS_ART_PREVIEW'] == '1' &&
        Platform.isWindows) {
      final font = File('${Platform.environment['WINDIR']}/Fonts/consola.ttf');
      if (font.existsSync()) {
        await (FontLoader('CreaturePreview')..addFont(
              font.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
            ))
            .load();
      }
    }
  });

  test(
    'all ten rooms have distinct creature identities and render every pose',
    () async {
      final rooms = DungeonRoom.all;
      expect(rooms.map((r) => r.appearance).toSet().length, 10);
      expect(
        rooms.any((r) => r.appearance == CombatantAppearance.adventurer),
        isFalse,
      );
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawColor(const Color(0xFFDBD3B6), BlendMode.src);
      for (var i = 0; i < rooms.length; i++) {
        canvas.save();
        canvas.translate((i % 2) * 480.0, (i ~/ 2) * 178.0);
        final text = TextPainter(
          text: TextSpan(
            text: '${i + 1}. ${rooms[i].name}',
            style: const TextStyle(
              color: Color(0xFF263D3D),
              fontSize: 17,
              fontFamily: 'CreaturePreview',
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 470);
        text.paint(canvas, const Offset(10, 8));
        for (var pose = 0; pose < 3; pose++) {
          final creature = BattleCharacterComponent(
            side: pose == 2 ? BattleSide.right : BattleSide.left,
            position: Vector2.zero(),
            appearance: rooms[i].appearance,
          );
          creature.update(.25);
          if (pose == 1) {
            creature.setActionPose(
              swordElement: rooms[i].elements.first,
              strike: .65,
              striding: true,
            );
          }
          if (pose == 2) creature.setActionPose(charge: .9);
          canvas.save();
          canvas.translate(30 + pose * 150.0, 42);
          canvas.scale(1.35);
          creature.render(canvas);
          canvas.restore();
          creature.setFrozen(true);
          creature.playHitEffect();
          final effects = ui.PictureRecorder();
          creature.render(Canvas(effects));
          effects.endRecording().dispose();
        }
        text.dispose();
        canvas.restore();
      }
      final picture = recorder.endRecording();
      final image = await picture.toImage(960, 890);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      expect(bytes!.lengthInBytes, greaterThan(10000));
      if (Platform.environment['ELEMENTOS_ART_PREVIEW'] == '1') {
        Directory('build/art-preview').createSync(recursive: true);
        File(
          'build/art-preview/dungeon-creatures.png',
        ).writeAsBytesSync(bytes.buffer.asUint8List());
      }
      image.dispose();
      picture.dispose();
      for (final size in [const Size(360, 230), const Size(568, 200)]) {
        final scene = ui.PictureRecorder();
        final arena = Canvas(scene);
        drawBattleArena(arena, size);
        for (final side in BattleSide.values) {
          final actor = BattleCharacterComponent(
            side: side,
            position: Vector2.zero(),
            appearance: side == BattleSide.left
                ? CombatantAppearance.adventurer
                : CombatantAppearance.ruinDrake,
          );
          arena.save();
          arena.translate(
            size.width * (side == BattleSide.left ? .25 : .75) - 32,
            size.height * .85 - 80,
          );
          actor.render(arena);
          arena.restore();
        }
        final drawing = scene.endRecording();
        final frame = await drawing.toImage(
          size.width.toInt(),
          size.height.toInt(),
        );
        if (Platform.environment['ELEMENTOS_ART_PREVIEW'] == '1') {
          final png = await frame.toByteData(format: ui.ImageByteFormat.png);
          File(
            'build/art-preview/dungeon-arena-${size.width.toInt()}.png',
          ).writeAsBytesSync(png!.buffer.asUint8List());
        }
        frame.dispose();
        drawing.dispose();
      }
    },
  );

  testWidgets(
    'scene applies creature before load, changes room and restores PvP avatar',
    (tester) async {
      Future<void> show(CombatantAppearance appearance) async {
        await tester.pumpWidget(
          MaterialApp(
            home: BattleSceneWidget(
              view: BattleSceneView(
                leftCurrentHp: 100,
                leftMaxHp: 100,
                rightCurrentHp: 100,
                rightMaxHp: 100,
                isLeftTurn: true,
                rightAppearance: appearance,
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }

      await show(CombatantAppearance.emberGoblin);
      final game = tester
          .widget<GameWidget<BattleSceneGame>>(
            find.byType(GameWidget<BattleSceneGame>),
          )
          .game!;
      await tester.runAsync(() => game.loaded);
      await tester.pump(const Duration(milliseconds: 100));
      final characters = game.children
          .whereType<BattleCharacterComponent>()
          .toList();
      expect(characters.first.appearance, CombatantAppearance.adventurer);
      expect(characters.last.appearance, CombatantAppearance.emberGoblin);
      await show(CombatantAppearance.ruinDrake);
      expect(characters.last.appearance, CombatantAppearance.ruinDrake);
      await show(CombatantAppearance.adventurer);
      expect(characters.last.appearance, CombatantAppearance.adventurer);
      expect(tester.takeException(), isNull);
    },
  );
}
