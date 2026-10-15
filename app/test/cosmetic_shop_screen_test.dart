import 'dart:io';
import 'dart:ui' as ui;
import 'package:app/game_domain/cosmetic_store.dart';
import 'package:app/game_domain/cosmetics.dart';
import 'package:app/game_presentation/beta_game.dart';
import 'package:app/ui/cosmetic_shop_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    if (Platform.environment['ELEMENTOS_ART_PREVIEW'] == '1' &&
        Platform.isWindows) {
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      await (FontLoader('Roboto')..addFont(
            Future.value(
              ByteData.sublistView(
                await File('C:/Windows/Fonts/segoeui.ttf').readAsBytes(),
              ),
            ),
          ))
          .load();
    }
  });
  setUpAll(() async {
    if (Platform.environment['ELEMENTOS_ART_PREVIEW'] == '1' &&
        Platform.isWindows) {
      await (FontLoader('monospace')..addFont(
            Future.value(
              ByteData.sublistView(
                await File('C:/Windows/Fonts/consola.ttf').readAsBytes(),
              ),
            ),
          ))
          .load();
    }
  });
  for (final size in [
    const Size(360, 640),
    const Size(640, 360),
    const Size(568, 320),
  ]) {
    testWidgets('shop purchase, preview and equip fit $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(key: key, child: const CosmeticShopScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Brasa Errante').first);
      await tester.tap(find.text('Brasa Errante').first);
      await tester.pumpAndSettle();
      expect((await CosmeticStore().load()).equipped, HeroOutfit.traveler);
      await tester.tap(find.byTooltip('Girar para a direita'));
      await tester.pumpAndSettle();
      if (Platform.environment['ELEMENTOS_ART_PREVIEW'] == '1') {
        await tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            'build/gameplay-preview/shop-${size.width.toInt()}-${size.height.toInt()}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      expect(find.text('Comprar · 75 Ecos').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Comprar · 75 Ecos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect((await CosmeticStore().load()).coins, 100);
      await tester.tap(find.text('Comprar · 75 Ecos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar compra'));
      await tester.pumpAndSettle();
      expect(find.text('25 ECOS'), findsOneWidget);
      await tester.tap(find.text('Equipar'));
      await tester.pumpAndSettle();
      final saved = await CosmeticStore().load();
      expect(saved.equipped, HeroOutfit.ember);
      final game = BetaGame(outfit: saved.equipped)..restart();
      expect(game.outfit, HeroOutfit.ember);
      expect(game.session.maxHp, 100);
      game.close();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('unreadable inventory offers retry instead of a fresh wallet', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({CosmeticStore.key: 'broken'});
    await tester.pumpWidget(const MaterialApp(home: CosmeticShopScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(find.text('100 ECOS'), findsNothing);
  });
}
