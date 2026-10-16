import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:app/game_domain/update_checker.dart';
import 'package:app/game_presentation/sfx_player.dart';
import 'package:app/ui/home_screen.dart';
import 'package:app/ui/update_gate_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_update/ota_update.dart';

class _FakeUpdateChecker implements UpdateChecker {
  _FakeUpdateChecker(this._result);
  final UpdateCheckResult _result;

  @override
  Future<UpdateCheckResult> checkForUpdate({
    required String currentVersion,
  }) async => _result;
}

class _ThrowingUpdateChecker implements UpdateChecker {
  @override
  Future<UpdateCheckResult> checkForUpdate({required String currentVersion}) {
    throw StateError('should not be called when not running on Android');
  }
}

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
        await (FontLoader(font.$1)..addFont(
              Future.value(
                ByteData.sublistView(
                  await File('C:/Windows/Fonts/${font.$2}.ttf').readAsBytes(),
                ),
              ),
            ))
            .load();
      }
    }
  });
  for (final size in [
    const Size(320, 568),
    const Size(568, 320),
    const Size(800, 360),
  ]) {
    testWidgets('update states fit $size and recheck resets installer', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final streams = <StreamController<OtaEvent>>[];
      addTearDown(() async {
        for (final stream in streams) {
          await stream.close();
        }
      });
      final key = GlobalKey();
      Future<void> capture(String state) async {
        if (Platform.environment['ELEMENTOS_ART_PREVIEW'] != '1') return;
        await tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            'build/gameplay-preview/update-${size.width.toInt()}-$state.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: key,
            child: UpdateGateScreen(
              isAndroid: true,
              currentVersion: '0.37.0',
              updateChecker: _FakeUpdateChecker(
                const UpdateCheckResult.updateAvailable(
                  latestVersion: '0.38.0',
                  downloadUrl: 'https://example.com/app-release.apk',
                  checksum: 'test',
                ),
              ),
              startDownload: (_) {
                final stream = StreamController<OtaEvent>();
                streams.add(stream);
                return stream.stream;
              },
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));
      expect(
        find.text('Versão instalada: 0.37.0').hitTestable(),
        findsOneWidget,
      );
      expect(find.text('Nova versão: v0.38.0').hitTestable(), findsOneWidget);
      expect(find.text('Baixar atualização').hitTestable(), findsOneWidget);
      await capture('available');
      await tester.tap(find.text('Baixar atualização'));
      await tester.pump();
      expect(find.text('Conectando ao download...'), findsOneWidget);
      streams.last.add(OtaEvent(OtaStatus.DOWNLOADING, '45'));
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('Baixando... 45%').hitTestable(), findsOneWidget);
      await capture('downloading');
      streams.last.add(OtaEvent(OtaStatus.INSTALLING, null));
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('Verificar instalação').hitTestable(), findsOneWidget);
      await capture('installing');
      await tester.tap(find.text('Verificar instalação'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('Baixar atualização').hitTestable(), findsOneWidget);
      expect(find.text('Abrindo instalador...'), findsNothing);
      await tester.tap(find.text('Baixar atualização'));
      await tester.pump();
      streams.last.add(OtaEvent(OtaStatus.CHECKSUM_ERROR, null));
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('Tentar de novo').hitTestable(), findsOneWidget);
      expect(find.textContaining('integridade'), findsOneWidget);
      await capture('error');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('failed check offers retry and explicit offline continuation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: UpdateGateScreen(
          isAndroid: true,
          currentVersion: '0.8.0',
          updateChecker: _FakeUpdateChecker(
            const UpdateCheckResult.failed('Sem conexão.'),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('Atualização não verificada'), findsOneWidget);
    expect(find.text('Verificar novamente'), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    await tester.tap(find.text('Continuar sem verificar'));
    await tester.pump();
    expect(find.byType(HomeScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('manual check reports installed version without opening home', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: UpdateGateScreen(
          manual: true,
          isAndroid: true,
          currentVersion: '0.8.0',
          updateChecker: _FakeUpdateChecker(const UpdateCheckResult.upToDate()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('Versão instalada: 0.8.0'), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('synchronous plugin failure is recoverable', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: UpdateGateScreen(
          isAndroid: true,
          currentVersion: '0.8.0',
          updateChecker: _FakeUpdateChecker(
            const UpdateCheckResult.updateAvailable(
              latestVersion: '0.9.0',
              downloadUrl: 'https://example.com/app-release.apk',
            ),
          ),
          startDownload: (_) => throw StateError('plugin unavailable'),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));
    await tester.tap(find.text('Baixar atualização'));
    await tester.pump();
    expect(find.text('Tentar de novo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the Home screen directly when not running on Android', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: UpdateGateScreen(
          isAndroid: false,
          updateChecker: _ThrowingUpdateChecker(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.byType(HomeScreen), findsOneWidget);

    await tester.pumpWidget(
      const SizedBox(),
    ); // dispose the idle AnimationControllers
  });

  testWidgets('shows the Home screen after checking, when up to date', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: UpdateGateScreen(
          isAndroid: true,
          currentVersion: '0.8.0',
          updateChecker: _FakeUpdateChecker(const UpdateCheckResult.upToDate()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.byType(HomeScreen), findsOneWidget);

    await tester.pumpWidget(
      const SizedBox(),
    ); // dispose the idle AnimationControllers
  });

  testWidgets('shows a progress bar while downloading, then switches to the '
      'installing message', (tester) async {
    final controller = StreamController<OtaEvent>();
    await tester.pumpWidget(
      MaterialApp(
        home: UpdateGateScreen(
          isAndroid: true,
          currentVersion: '0.8.0',
          updateChecker: _FakeUpdateChecker(
            const UpdateCheckResult.updateAvailable(
              latestVersion: '0.9.0',
              downloadUrl: 'https://example.com/app-release.apk',
            ),
          ),
          startDownload: (url) {
            expect(url, 'https://example.com/app-release.apk');
            return controller.stream;
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('Atualização necessária'), findsOneWidget);
    expect(find.textContaining('v0.9.0'), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);

    await tester.tap(find.text('Baixar atualização'));
    await tester.pump();

    controller.add(OtaEvent(OtaStatus.DOWNLOADING, '45'));
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('Baixando... 45%'), findsOneWidget);

    controller.add(OtaEvent(OtaStatus.INSTALLATION_DONE, null));
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('Abrindo instalador...'), findsOneWidget);

    await controller.close();
  });

  testWidgets('shows an error and a retry button when the download fails', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: UpdateGateScreen(
          isAndroid: true,
          currentVersion: '0.8.0',
          updateChecker: _FakeUpdateChecker(
            const UpdateCheckResult.updateAvailable(
              latestVersion: '0.9.0',
              downloadUrl: 'https://example.com/app-release.apk',
            ),
          ),
          startDownload: (url) {
            attempts++;
            return Stream<OtaEvent>.value(
              OtaEvent(OtaStatus.DOWNLOAD_ERROR, 'sem conexão'),
            );
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));

    await tester.tap(find.text('Baixar atualização'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Falha ao baixar a atualização.'), findsOneWidget);
    expect(find.text('Tentar de novo'), findsOneWidget);
    expect(attempts, 1);

    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
  });
}
