import 'package:app/game_domain/update_checker.dart';
import 'package:app/ui/home_screen.dart';
import 'package:app/ui/update_gate_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
      'shows the update-required screen and opens the download link when '
      'an update is available', (tester) async {
    Uri? openedUri;
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
        launchUrl: (uri) async => openedUri = uri,
      ),
    ));
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('Atualização necessária'), findsOneWidget);
    expect(find.textContaining('v0.9.0'), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);

    await tester.tap(find.text('Baixar atualização'));
    await tester.pump();

    expect(openedUri, Uri.parse('https://example.com/app-release.apk'));
  });
}
