import 'package:app/game_domain/conjuration_seal.dart';
import 'package:app/game_domain/training_match.dart';
import 'package:app/ui/conjuration_seal_dialog.dart';
import 'package:battle_engine/battle_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TrainingMatch ready() => TrainingMatch(
    initialApA: const ApPool(max: 5, current: 2),
    initialProgressA: SkillProgress(
      defaultSkillTree,
      unlockedNodeIds: ['unlock_fire', 'unlock_wind'],
    ),
  );
  test(
    'training failure is one AP, no discovery, and success preserves combo',
    () {
      final match = ready();
      match.beginSeal(['fire', 'wind']);
      expect(match.defend, throwsStateError);
      expect(() => match.beginSeal(['fire', 'wind']), throwsStateError);
      expect(match.resolveSeal([]), false);
      expect(match.playerAAp, 1);
      expect(match.playerBCurrentHp, 100);
      expect(match.discoveredCount, 0);
      expect(match.isPlayerATurn, false);
      expect(() => match.resolveSeal([]), throwsStateError);
      final success = ready();
      success.beginSeal(['fire', 'wind']);
      expect(
        success.resolveSeal(
          ConjurationSeal(['fire', 'wind']).nodes.indexed
              .map((e) => <String, num>{'x': e.$2.x, 'y': e.$2.y, 'ms': e.$1})
              .toList(),
        ),
        true,
      );
      expect(success.playerAAp, 0);
      expect(success.playerBCurrentHp, 86);
      expect(success.discoveredCount, 1);
    },
  );
  for (final size in [const Size(360, 800), const Size(800, 360)]) {
    testWidgets('seal trace and layout $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      List<Map<String, num>>? result;
      var starts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showConjurationSeal(
                    context,
                    elements: ['fire', 'wind'],
                    onStart: () async {
                      starts++;
                      return 6000;
                    },
                  );
                },
                child: const Text('Conjurar'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Conjurar'));
      await tester.pumpAndSettle();
      expect(starts, 0);
      final canvas = find.byKey(const ValueKey('seal-canvas'));
      final rect = tester.getRect(canvas);
      final nodes = ConjurationSeal(['fire', 'wind']).nodes;
      final gesture = await tester.startGesture(
        Offset(
          rect.left + nodes.first.x * rect.width,
          rect.top + nodes.first.y * rect.height,
        ),
      );
      await tester.pump();
      for (final n in nodes.skip(1)) {
        await gesture.moveTo(
          Offset(rect.left + n.x * rect.width, rect.top + n.y * rect.height),
        );
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(starts, 1);
      expect(result, hasLength(4));
      expect(tester.takeException(), isNull);
    });
  }
}
