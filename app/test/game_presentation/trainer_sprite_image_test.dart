import 'package:app/game_presentation/trainer_sprite_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('builds without throwing, mirrored or not', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: TrainerSpriteImage())),
    );
    expect(find.byType(TrainerSpriteImage), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: TrainerSpriteImage(mirror: true)),
      ),
    );
    expect(find.byType(TrainerSpriteImage), findsOneWidget);
  });
}
