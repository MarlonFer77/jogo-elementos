import 'dart:async';

import 'package:app/game_domain/update_checker.dart';
import 'package:app/ui/home_screen.dart';
import 'package:app/ui/update_gate_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_update/ota_update.dart';

class _FakeUpdateChecker implements UpdateChecker {
  _FakeUpdateChecker(this._result);
  final UpdateCheckResult _result;

  @override
  Future<UpdateCheckResult> checkForUpdate({required String currentVersion}) async =>
      _result;
}

class _ThrowingUpdateChecker implements UpdateChecker {
  @override
  Future<UpdateCheckResult> checkForUpdate({required String currentVersion}) {
    throw StateError('should not be called when not running on Android');
  }
}

void main() {
  testWidgets('shows the Home screen directly when not running on Android',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: UpdateGateScreen(
        isAndroid: false,
        updateChecker: _ThrowingUpdateChecker(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.byType(HomeScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox()); // dispose the idle AnimationControllers
  });

  testWidgets('shows the Home screen after checking, when up to date',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: UpdateGateScreen(
        isAndroid: true,
        currentVersion: '0.8.0',
        updateChecker: _FakeUpdateChecker(const UpdateCheckResult.upToDate()),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.byType(HomeScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox()); // dispose the idle AnimationControllers
  });

  testWidgets(
      'shows a progress bar while downloading, then switches to the '
      'installing message', (tester) async {
    final controller = StreamController<OtaEvent>();
    await tester.pumpWidget(MaterialApp(
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
    ));
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

  testWidgets('shows an error and a retry button when the download fails',
      (tester) async {
    var attempts = 0;
    await tester.pumpWidget(MaterialApp(
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
    ));
    await tester.pump(const Duration(milliseconds: 1));

    await tester.tap(find.text('Baixar atualização'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Falha ao baixar a atualização.'), findsOneWidget);
    expect(find.text('Tentar de novo'), findsOneWidget);
    expect(attempts, 1);

    await tester.tap(find.text('Tentar de novo'));
    await tester.pump();
    await tester.pump();

    expect(attempts, 2);
  });
}
