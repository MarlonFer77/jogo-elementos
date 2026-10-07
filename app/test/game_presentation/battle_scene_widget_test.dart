import 'package:app/game_domain/attack_event.dart';
import 'package:app/game_domain/battle_scene_view.dart';
import 'package:app/game_domain/effect_badge_view.dart';
import 'package:app/game_presentation/pixel_arena_background.dart';
import 'package:app/game_presentation/battle_scene_game.dart';
import 'package:app/game_presentation/battle_hud_widget.dart';
import 'package:app/game_presentation/battle_scene_widget.dart';
import 'package:app/game_presentation/battle_character_component.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

BattleSceneView view({
  int leftHp = 100,
  int rightHp = 100,
  bool leftTurn = true,
  AttackEvent? attack,
}) => BattleSceneView(
  leftCurrentHp: leftHp,
  leftMaxHp: 100,
  rightCurrentHp: rightHp,
  rightMaxHp: 100,
  isLeftTurn: leftTurn,
  lastAttack: attack,
  leftLabel: 'Jogador A',
  rightLabel: 'Jogador B',
);

AttackEvent attack({int id = 1, int damage = 20, bool left = true}) =>
    AttackEvent(
      sequenceId: id,
      attackerIsLeft: left,
      elementIds: const ['fire', 'wind'],
      comboName: 'Tempestade Ígnea',
      damage: damage,
      appliedStatusNames: const [],
    );

Future<void> tick(WidgetTester tester, int count) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets(
    'arena loads once, defense waits for impact and reduced motion is respected',
    (tester) async {
      Future<void> show({bool shield = true, AttackEvent? event}) =>
          tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: const MediaQueryData(disableAnimations: true),
                child: Scaffold(
                  body: BattleSceneWidget(
                    view: BattleSceneView(
                      leftCurrentHp: 100,
                      leftMaxHp: 100,
                      rightCurrentHp: 100,
                      rightMaxHp: 100,
                      isLeftTurn: true,
                      arena: ArenaTheme.glacier,
                      lastAttack: event,
                      rightStatuses: shield
                          ? const [
                              EffectBadgeView(id: 'shield', remainingTurns: 2),
                            ]
                          : const [],
                    ),
                  ),
                ),
              ),
            ),
          );
      await show();
      await tick(tester, 4);
      final game =
          tester
                  .widget<GameWidget>(
                    find.byWidgetPredicate((w) => w is GameWidget),
                  )
                  .game
              as BattleSceneGame;
      expect(
        game.children.whereType<PixelArenaBackground>().single.theme,
        ArenaTheme.glacier,
      );
      expect(game.ambientMotionEnabled, false);
      final target = game.children.whereType<BattleCharacterComponent>().last;
      expect(target.hasShield, true);
      await show(shield: false, event: attack(damage: 0));
      await tick(tester, 2);
      expect(target.hasShield, true);
      await tick(tester, 5);
      expect(target.hasShield, false);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'new battle cancels old feedback and allows a reused sequence id',
    (tester) async {
      var completions = 0;
      Future<void> show(BattleSceneView state) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BattleSceneWidget(
              view: state,
              onAttackComplete: () => completions++,
            ),
          ),
        ),
      );
      await show(view());
      await tick(tester, 4);
      await show(view(rightHp: 80, attack: attack()));
      await tick(tester, 2);
      await show(view());
      await tick(tester, 15);
      expect(completions, 0);
      expect(find.byKey(const ValueKey('attack-caption')), findsNothing);
      expect(
        tester
            .widget<BattleHudWidget>(find.byType(BattleHudWidget))
            .view
            .rightCurrentHp,
        100,
      );
      await show(view(rightHp: 80, attack: attack()));
      await tick(tester, 15);
      expect(completions, 1);
      expect(
        tester
            .widget<BattleHudWidget>(find.byType(BattleHudWidget))
            .view
            .rightCurrentHp,
        80,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('initial snapshot never invents HP before a reconnect event', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BattleSceneWidget(view: view(rightHp: 20, attack: attack())),
        ),
      ),
    );
    expect(
      tester
          .widget<BattleHudWidget>(find.byType(BattleHudWidget))
          .view
          .rightCurrentHp,
      20,
    );
    await tick(tester, 15);
    expect(
      tester
          .widget<BattleHudWidget>(find.byType(BattleHudWidget))
          .view
          .rightCurrentHp,
      20,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'HP waits for impact; actor remains highlighted until completion; polling does not replay',
    (tester) async {
      var completions = 0;
      Future<void> show(BattleSceneView state) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BattleSceneWidget(
                view: state,
                onAttackComplete: () => completions++,
              ),
            ),
          ),
        );
        await tester.pump();
      }

      await show(view());
      await tick(tester, 4);
      final state = view(rightHp: 80, leftTurn: false, attack: attack());
      await show(state);
      var hud = tester.widget<BattleHudWidget>(find.byType(BattleHudWidget));
      expect(hud.view.rightCurrentHp, 100);
      expect(hud.actingIsLeft, isTrue);
      expect(find.byKey(const ValueKey('attack-caption')), findsOneWidget);
      await tick(tester, 3);
      expect(
        tester
            .widget<BattleHudWidget>(find.byType(BattleHudWidget))
            .view
            .rightCurrentHp,
        100,
      );
      await tick(tester, 4);
      hud = tester.widget<BattleHudWidget>(find.byType(BattleHudWidget));
      expect(hud.view.rightCurrentHp, 80);
      expect(hud.actingIsLeft, isTrue);
      expect(find.text('Tempestade Ígnea · 20 de dano'), findsOneWidget);
      await tick(tester, 8);
      expect(completions, 1);
      expect(
        tester
            .widget<BattleHudWidget>(find.byType(BattleHudWidget))
            .actingIsLeft,
        isNull,
      );
      expect(find.byKey(const ValueKey('attack-caption')), findsNothing);
      await show(view(rightHp: 80, leftTurn: false, attack: attack()));
      await tick(tester, 15);
      expect(completions, 1);
      expect(find.byKey(const ValueKey('attack-caption')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('opponent zero damage, replacement event and disposal are safe', (
    tester,
  ) async {
    var completions = 0;
    Future<void> show(BattleSceneView state) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BattleSceneWidget(
              view: state,
              onAttackComplete: () => completions++,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    await show(view());
    await tick(tester, 4);
    await show(view(attack: attack(left: false, damage: 0)));
    await tick(tester, 7);
    expect(find.text('Tempestade Ígnea · Sem dano'), findsOneWidget);
    expect(
      tester.widget<BattleHudWidget>(find.byType(BattleHudWidget)).actingIsLeft,
      isFalse,
    );
    await show(view(rightHp: 80, attack: attack(id: 2)));
    await tick(tester, 15);
    expect(
      completions,
      1,
    ); // interrupted zero-damage action never completes late
    expect(
      tester
          .widget<BattleHudWidget>(find.byType(BattleHudWidget))
          .view
          .rightCurrentHp,
      80,
    );
    await show(view(rightHp: 60, attack: attack(id: 3)));
    await tester.pumpWidget(const SizedBox());
    await tick(tester, 15);
    expect(completions, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'snapshot without event updates immediately and rotation keeps sprite anchors',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 740);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      Future<void> show(BattleSceneView state) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BattleSceneWidget(view: state)),
        ),
      );
      await show(view());
      await tick(tester, 4);
      await show(view(rightHp: 60));
      expect(
        tester
            .widget<BattleHudWidget>(find.byType(BattleHudWidget))
            .view
            .rightCurrentHp,
        60,
      );
      tester.view.physicalSize = const Size(740, 360);
      await tick(tester, 15);
      final game =
          tester
                  .widget<GameWidget>(
                    find.byWidgetPredicate((w) => w is GameWidget),
                  )
                  .game
              as FlameGame;
      final characters = game.children
          .whereType<BattleCharacterComponent>()
          .toList();
      expect(characters.length, 2);
      expect(characters.first.position.x, closeTo(game.size.x * .25, .01));
      expect(characters.last.position.x, closeTo(game.size.x * .75, .01));
      expect(tester.takeException(), isNull);
    },
  );
}
