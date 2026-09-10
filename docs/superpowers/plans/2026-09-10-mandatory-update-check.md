# Checagem obrigatória de atualização Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** O app passa a checar sozinho, ao abrir, se existe uma versão mais nova publicada no GitHub Releases — se existir, bloqueia o jogo inteiro (Treino incluso) até o jogador baixar e instalar a atualização, acabando com o processo manual de avisar cada amigo.

**Architecture:** Um `UpdateChecker` (game_domain) consulta a API pública do GitHub Releases via `http.Client` injetável (mesmo padrão do `MultiplayerClient`) e devolve um `UpdateCheckResult` puro. Uma nova tela `UpdateGateScreen` vira a raiz do app (`main.dart`), checando a versão instalada (via `package_info_plus`) contra a mais recente e mostrando Home, uma tela de "checando" ou uma tela bloqueante de "atualização necessária" (reaproveitando os componentes pixel art já existentes — nenhum widget visual novo).

**Tech Stack:** Flutter + Dart, `http` (já dependência), `package_info_plus` e `url_launcher` (novas), API pública do GitHub Releases.

**Spec:** [docs/superpowers/specs/2026-09-10-mandatory-update-check-design.md](../specs/2026-09-10-mandatory-update-check-design.md)

## Global Constraints

- Fonte da versão mais recente: `GET https://api.github.com/repos/MarlonFer77/jogo-elementos/releases/latest` — a API do GitHub **exige** um header `User-Agent`, senão devolve 403. Sempre mandar `'User-Agent': 'jogo-elementos-app'`.
- Qualquer falha na checagem (timeout, sem rede, resposta inesperada, JSON inválido) devolve "está atualizado" — fail-open, nunca bloqueia por causa de erro de rede.
- O bloqueio, quando existe versão nova, cobre o jogo inteiro (Treino incluso) — não só o Multiplayer.
- Checagem só roda de verdade em Android (`!kIsWeb && Platform.isAndroid`) — Web/Windows pulam direto pra Home (plataformas só de desenvolvimento, nunca distribuídas).
- Paleta/fontes pixel art já estabelecidas (`Color(0xFF2B2B2B)` texto, `fontFamily: 'monospace'`) — a tela nova reaproveita `ArenaBackdropPainter`/`PixelOutlinedText`/`PixelMenuButton` já existentes, nenhum componente visual novo.
- `_check()` precisa de um `await Future<void>.delayed(Duration.zero);` como primeira linha, em todo caminho — sem isso, o caminho "não é Android" chamaria `setState` de forma síncrona dentro de `initState`, o que o Flutter não permite.
- Lição do Bloco 3, ainda válida: `flutter run -d web-server` **não** recompila em reload de página — só um `preview_stop`+`preview_start` novo pega mudanças de código Dart.
- Cada task termina com `flutter analyze` limpo e `flutter test` verde antes do commit.
- Este ambiente de desenvolvimento não roda Android de verdade (só compila via GitHub Actions — ver DECISION-015/029) — a verificação manual deste bloco é limitada aos testes de widget com `isAndroid: true` forçado; não há como testar rodando de verdade num Android nesta máquina.

---

## Task 1: `isNewerVersion` (comparação pura de versão)

**Files:**
- Create: `app/lib/game_domain/update_checker.dart`
- Test: `app/test/game_domain/update_checker_test.dart`

**Interfaces:**
- Consumes: nada de outras tasks.
- Produces: `bool isNewerVersion(String remote, String local)` — usado pela Task 2 dentro de `UpdateChecker.checkForUpdate`.

- [ ] **Step 1: Write the failing test**

```dart
// app/test/game_domain/update_checker_test.dart
import 'package:app/game_domain/update_checker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isNewerVersion', () {
    test('returns false when versions are equal', () {
      expect(isNewerVersion('0.8.0', '0.8.0'), isFalse);
    });

    test('returns true when the remote patch is newer', () {
      expect(isNewerVersion('0.8.1', '0.8.0'), isTrue);
    });

    test('returns true when the remote minor is newer', () {
      expect(isNewerVersion('0.9.0', '0.8.5'), isTrue);
    });

    test('returns true when the remote major is newer', () {
      expect(isNewerVersion('1.0.0', '0.9.9'), isTrue);
    });

    test('returns false when the remote is older', () {
      expect(isNewerVersion('0.7.0', '0.8.0'), isFalse);
    });

    test('treats missing segments as zero', () {
      expect(isNewerVersion('0.9', '0.9.0'), isFalse);
      expect(isNewerVersion('0.9.1', '0.9'), isTrue);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/game_domain/update_checker_test.dart`
Expected: FAIL — `update_checker.dart` não existe ainda.

- [ ] **Step 3: Write minimal implementation**

```dart
// app/lib/game_domain/update_checker.dart
List<int> _versionParts(String version) =>
    version.split('.').map((p) => int.tryParse(p) ?? 0).toList();

/// Compara duas strings de versão `major.minor.patch` (ou qualquer número
/// de segmentos — os que faltam contam como zero). `true` se [remote] for
/// mais nova que [local].
bool isNewerVersion(String remote, String local) {
  final remoteParts = _versionParts(remote);
  final localParts = _versionParts(local);
  final length =
      remoteParts.length > localParts.length ? remoteParts.length : localParts.length;
  for (var i = 0; i < length; i++) {
    final r = i < remoteParts.length ? remoteParts[i] : 0;
    final l = i < localParts.length ? localParts[i] : 0;
    if (r != l) return r > l;
  }
  return false;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/game_domain/update_checker_test.dart`
Expected: PASS (6 testes).

- [ ] **Step 5: Commit**

```bash
git add app/lib/game_domain/update_checker.dart app/test/game_domain/update_checker_test.dart
git commit -m "Adiciona isNewerVersion (comparacao pura de versao)"
```

---

## Task 2: `UpdateCheckResult` + `UpdateChecker`

**Files:**
- Modify: `app/lib/game_domain/update_checker.dart` (adiciona ao arquivo da Task 1)
- Modify: `app/test/game_domain/update_checker_test.dart` (adiciona ao arquivo da Task 1)

**Interfaces:**
- Consumes: `isNewerVersion` (Task 1).
- Produces: `class UpdateCheckResult { bool updateAvailable; String? latestVersion; String? downloadUrl; }` (+ construtores `.upToDate()` e `.updateAvailable({required latestVersion, required downloadUrl})`) e `class UpdateChecker { UpdateChecker({http.Client? httpClient}); Future<UpdateCheckResult> checkForUpdate({required String currentVersion}); }` — usados pela Task 3 (`UpdateGateScreen`).

- [ ] **Step 1: Write the failing test**

Adicionar ao final de `app/test/game_domain/update_checker_test.dart` (dentro do `main()`, depois do `group('isNewerVersion', ...)`), e adicionar os imports novos no topo:

```dart
import 'dart:convert';

import 'package:app/game_domain/update_checker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
```

```dart
  group('UpdateChecker.checkForUpdate', () {
    test('returns updateAvailable when the release tag is newer', () async {
      final client = MockClient((request) async {
        expect(request.headers['User-Agent'], 'jogo-elementos-app');
        return http.Response(
          jsonEncode({
            'tag_name': 'v0.9.0',
            'assets': [
              {
                'name': 'app-release.apk',
                'browser_download_url':
                    'https://github.com/MarlonFer77/jogo-elementos/releases/download/v0.9.0/app-release.apk',
              },
            ],
          }),
          200,
        );
      });
      final checker = UpdateChecker(httpClient: client);

      final result = await checker.checkForUpdate(currentVersion: '0.8.0');

      expect(result.updateAvailable, isTrue);
      expect(result.latestVersion, '0.9.0');
      expect(
        result.downloadUrl,
        'https://github.com/MarlonFer77/jogo-elementos/releases/download/v0.9.0/app-release.apk',
      );
    });

    test('returns upToDate when the release tag is the same version',
        () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'tag_name': 'v0.8.0', 'assets': <Map<String, dynamic>>[]}),
          200,
        );
      });
      final checker = UpdateChecker(httpClient: client);

      final result = await checker.checkForUpdate(currentVersion: '0.8.0');

      expect(result.updateAvailable, isFalse);
    });

    test('returns upToDate when the response is not 200', () async {
      final client = MockClient((request) async => http.Response('', 404));
      final checker = UpdateChecker(httpClient: client);

      final result = await checker.checkForUpdate(currentVersion: '0.8.0');

      expect(result.updateAvailable, isFalse);
    });

    test('returns upToDate when the request throws (no network)', () async {
      final client = MockClient((request) async {
        throw Exception('no network');
      });
      final checker = UpdateChecker(httpClient: client);

      final result = await checker.checkForUpdate(currentVersion: '0.8.0');

      expect(result.updateAvailable, isFalse);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/game_domain/update_checker_test.dart`
Expected: FAIL — `UpdateChecker`/`UpdateCheckResult` ainda não existem.

- [ ] **Step 3: Write minimal implementation**

Adicionar ao final de `app/lib/game_domain/update_checker.dart` (mantendo `_versionParts`/`isNewerVersion` da Task 1 intactos), e adicionar os imports novos no topo do arquivo:

```dart
import 'dart:convert';

import 'package:http/http.dart' as http;
```

```dart
/// Resultado de [UpdateChecker.checkForUpdate].
class UpdateCheckResult {
  const UpdateCheckResult({
    required this.updateAvailable,
    this.latestVersion,
    this.downloadUrl,
  });
  const UpdateCheckResult.upToDate() : this(updateAvailable: false);
  const UpdateCheckResult.updateAvailable({
    required String latestVersion,
    required String downloadUrl,
  }) : this(updateAvailable: true, latestVersion: latestVersion, downloadUrl: downloadUrl);

  final bool updateAvailable;
  final String? latestVersion;
  final String? downloadUrl;
}

/// Consulta a API pública do GitHub Releases pra saber se existe uma
/// versão mais nova do que [currentVersion] instalada. Sem retry, sem
/// cache — quem chama decide quando chamar de novo (mesmo espírito do
/// `MultiplayerClient`). Qualquer falha (rede, timeout, resposta
/// inesperada) devolve `upToDate` — nunca bloqueia o jogo por causa de um
/// problema de rede transitório.
class UpdateChecker {
  UpdateChecker({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;

  static const _releasesUrl =
      'https://api.github.com/repos/MarlonFer77/jogo-elementos/releases/latest';
  static const _apkAssetName = 'app-release.apk';

  Future<UpdateCheckResult> checkForUpdate({required String currentVersion}) async {
    try {
      final response = await _http
          .get(
            Uri.parse(_releasesUrl),
            headers: const {'User-Agent': 'jogo-elementos-app'},
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return const UpdateCheckResult.upToDate();

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final tagName = body['tag_name'] as String?;
      if (tagName == null) return const UpdateCheckResult.upToDate();

      final latestVersion = tagName.startsWith('v') ? tagName.substring(1) : tagName;
      if (!isNewerVersion(latestVersion, currentVersion)) {
        return const UpdateCheckResult.upToDate();
      }

      final assets = (body['assets'] as List<dynamic>?) ?? const [];
      String? downloadUrl;
      for (final asset in assets) {
        final map = asset as Map<String, dynamic>;
        if (map['name'] == _apkAssetName) {
          downloadUrl = map['browser_download_url'] as String?;
          break;
        }
      }
      if (downloadUrl == null) return const UpdateCheckResult.upToDate();

      return UpdateCheckResult.updateAvailable(
        latestVersion: latestVersion,
        downloadUrl: downloadUrl,
      );
    } catch (_) {
      return const UpdateCheckResult.upToDate();
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/game_domain/update_checker_test.dart`
Expected: PASS (10 testes: 6 de `isNewerVersion` + 4 de `UpdateChecker.checkForUpdate`).

- [ ] **Step 5: `flutter analyze`**

Run: `cd app && flutter analyze`
Expected: "No issues found!"

- [ ] **Step 6: Commit**

```bash
git add app/lib/game_domain/update_checker.dart app/test/game_domain/update_checker_test.dart
git commit -m "Adiciona UpdateChecker (consulta a API do GitHub Releases)"
```

---

## Task 3: `UpdateGateScreen`

**Files:**
- Modify: `app/pubspec.yaml` (novas dependências)
- Create: `app/lib/ui/update_gate_screen.dart`
- Test: `app/test/update_gate_screen_test.dart`

**Interfaces:**
- Consumes: `UpdateChecker`/`UpdateCheckResult` (Task 2), `ArenaBackdropPainter`/`PixelOutlinedText`/`PixelMenuButton` (já existentes), `HomeScreen` (já existente).
- Produces: `UpdateGateScreen({UpdateChecker? updateChecker, String? currentVersion, bool? isAndroid, Future<void> Function(Uri uri)? launchUrl})` — usado pela Task 4 em `main.dart`.

- [ ] **Step 1: Adicionar as dependências novas**

Run: `cd app && flutter pub add package_info_plus url_launcher`
Expected: `pubspec.yaml` ganha as duas entradas em `dependencies:` (versão resolvida pelo `pub`, sem fixar número aqui), `pubspec.lock` atualizado, comando termina sem erro.

- [ ] **Step 2: Write the failing test**

```dart
// app/test/update_gate_screen_test.dart
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
    await tester.pump();

    expect(find.byType(HomeScreen), findsOneWidget);
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
    await tester.pump();

    expect(find.byType(HomeScreen), findsOneWidget);
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
    await tester.pump();

    expect(find.text('Atualização necessária'), findsOneWidget);
    expect(find.textContaining('v0.9.0'), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);

    await tester.tap(find.text('Baixar atualização'));
    await tester.pump();

    expect(openedUri, Uri.parse('https://example.com/app-release.apk'));
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd app && flutter test test/update_gate_screen_test.dart`
Expected: FAIL — `update_gate_screen.dart` não existe ainda.

- [ ] **Step 4: Write minimal implementation**

```dart
// app/lib/ui/update_gate_screen.dart
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

import '../game_domain/update_checker.dart';
import '../game_presentation/pixel_arena_background.dart';
import '../game_presentation/pixel_menu_button.dart';
import '../game_presentation/pixel_outlined_text.dart';
import 'home_screen.dart';

enum _GateState { checking, upToDate, updateRequired }

/// Tela raiz do app (`main.dart`'s `home:`) — checa se existe uma versão
/// nova antes de mostrar a Home, e bloqueia o jogo inteiro se estiver
/// desatualizado. Só roda a checagem de verdade em Android; Web/Windows
/// (só desenvolvimento, nunca distribuídos) pulam direto pra Home. Ver
/// docs/superpowers/specs/2026-09-10-mandatory-update-check-design.md.
class UpdateGateScreen extends StatefulWidget {
  const UpdateGateScreen({
    super.key,
    UpdateChecker? updateChecker,
    String? currentVersion,
    bool? isAndroid,
    Future<void> Function(Uri uri)? launchUrl,
  })  : _updateChecker = updateChecker,
        _currentVersion = currentVersion,
        _isAndroid = isAndroid,
        _launchUrl = launchUrl;

  final UpdateChecker? _updateChecker;
  final String? _currentVersion;
  final bool? _isAndroid;
  final Future<void> Function(Uri uri)? _launchUrl;

  @override
  State<UpdateGateScreen> createState() => _UpdateGateScreenState();
}

class _UpdateGateScreenState extends State<UpdateGateScreen> {
  _GateState _state = _GateState.checking;
  String? _latestVersion;
  String? _downloadUrl;

  bool get _runningOnAndroid => widget._isAndroid ?? (!kIsWeb && Platform.isAndroid);

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    await Future<void>.delayed(Duration.zero);

    if (!_runningOnAndroid) {
      if (mounted) setState(() => _state = _GateState.upToDate);
      return;
    }

    final currentVersion =
        widget._currentVersion ?? (await PackageInfo.fromPlatform()).version;
    final checker = widget._updateChecker ?? UpdateChecker();
    final result = await checker.checkForUpdate(currentVersion: currentVersion);

    if (!mounted) return;
    setState(() {
      if (result.updateAvailable) {
        _state = _GateState.updateRequired;
        _latestVersion = result.latestVersion;
        _downloadUrl = result.downloadUrl;
      } else {
        _state = _GateState.upToDate;
      }
    });
  }

  Future<void> _openDownload() async {
    final url = _downloadUrl;
    if (url == null) return;
    final launch = widget._launchUrl ??
        (uri) => url_launcher.launchUrl(uri, mode: url_launcher.LaunchMode.externalApplication);
    await launch(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    if (_state == _GateState.upToDate) {
      return const HomeScreen();
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: ArenaBackdropPainter()),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _state == _GateState.checking
                      ? const [
                          PixelOutlinedText('ELEMENTOS'),
                          SizedBox(height: 24),
                          Text(
                            'Verificando atualizações...',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: Color(0xFF2B2B2B),
                            ),
                          ),
                        ]
                      : [
                          const PixelOutlinedText('Atualização necessária', fontSize: 24),
                          const SizedBox(height: 16),
                          Text(
                            'Uma versão nova (v$_latestVersion) está disponível. '
                            'Atualize pra continuar jogando.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              color: Color(0xFF2B2B2B),
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: 280,
                            child: PixelMenuButton(
                              label: 'Baixar atualização',
                              primary: true,
                              onPressed: _openDownload,
                            ),
                          ),
                        ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd app && flutter test test/update_gate_screen_test.dart`
Expected: PASS (3 testes). Se o primeiro `pump()` não for suficiente pra resolver o `Future.delayed(Duration.zero)` em algum caso, adicionar um segundo `await tester.pump();` nos testes afetados — ajuste esperado de TDD, não muda nenhum comportamento do widget.

- [ ] **Step 6: `flutter analyze`**

Run: `cd app && flutter analyze`
Expected: "No issues found!"

- [ ] **Step 7: Commit**

```bash
git add app/pubspec.yaml app/pubspec.lock app/lib/ui/update_gate_screen.dart app/test/update_gate_screen_test.dart
git commit -m "Adiciona UpdateGateScreen (tela bloqueante de atualizacao)"
```

---

## Task 4: `main.dart` usa `UpdateGateScreen`

**Files:**
- Modify: `app/lib/main.dart`
- Modify: `app/test/training_screen_test.dart` (3 pontos que usam `GameApp()`)

**Interfaces:**
- Consumes: `UpdateGateScreen` (Task 3).
- Produces: nada consumido por outras tasks.

- [ ] **Step 1: Confirmar a suíte atual passa antes de mexer (baseline)**

Run: `cd app && flutter test test/training_screen_test.dart`
Expected: PASS (5 testes).

- [ ] **Step 2: Trocar `home: const HomeScreen()` por `home: const UpdateGateScreen()`**

Substituir todo o conteúdo de `app/lib/main.dart` por:

```dart
import 'package:flutter/material.dart';

import 'ui/update_gate_screen.dart';

void main() {
  runApp(const GameApp());
}

class GameApp extends StatelessWidget {
  const GameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Elementos',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: const UpdateGateScreen(),
    );
  }
}
```

- [ ] **Step 3: Rodar a suíte e confirmar a falha esperada (documentada na spec)**

Run: `cd app && flutter test test/training_screen_test.dart`
Expected: FAIL nos 3 testes que usam `GameApp()` — `find.text('MODO TREINO')` não encontra nada, porque a tela ainda está em "Verificando atualizações..." logo após `pumpWidget` (falta um `pump()` pra resolver o `Future.delayed(Duration.zero)` da Task 3).

- [ ] **Step 4: Adicionar o `pump()` que falta nos 3 pontos que usam `GameApp()`**

Em `app/test/training_screen_test.dart`, no primeiro teste (linhas 13-15 do arquivo original), substituir:

```dart
      await tester.pumpWidget(const GameApp());

      await tester.tap(find.text('MODO TREINO'));
```

por:

```dart
      await tester.pumpWidget(const GameApp());
      await tester.pump(); // resolve o Future.delayed da checagem de atualização

      await tester.tap(find.text('MODO TREINO'));
```

No segundo teste ("the play button is disabled...", linhas 50-52 do arquivo original — indentação de 4 espaços, não 6), substituir:

```dart
    await tester.pumpWidget(const GameApp());

    await tester.tap(find.text('MODO TREINO'));
```

por:

```dart
    await tester.pumpWidget(const GameApp());
    await tester.pump(); // resolve o Future.delayed da checagem de atualização

    await tester.tap(find.text('MODO TREINO'));
```

No terceiro teste ("unlocking Maestria da Brasa...", linhas 66-68 do arquivo original), substituir:

```dart
      await tester.pumpWidget(const GameApp());

      await tester.tap(find.text('MODO TREINO'));
```

por:

```dart
      await tester.pumpWidget(const GameApp());
      await tester.pump(); // resolve o Future.delayed da checagem de atualização

      await tester.tap(find.text('MODO TREINO'));
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd app && flutter test test/training_screen_test.dart`
Expected: PASS (5 testes) — inclusive os 2 testes que montam `TrainingScreen` direto (`MaterialApp(home: TrainingScreen(...))`, sem `GameApp`), que nunca foram afetados.

- [ ] **Step 6: `flutter analyze`**

Run: `cd app && flutter analyze`
Expected: "No issues found!"

- [ ] **Step 7: Commit**

```bash
git add app/lib/main.dart app/test/training_screen_test.dart
git commit -m "main.dart usa UpdateGateScreen como raiz do app"
```

---

## Task 5: Suíte completa, verificação e registro da decisão

**Files:**
- Modify: `DECISIONS.md` (nova `## DECISION-037`)
- Modify: `TASKS.md` (linha `DONE` nova)

**Interfaces:**
- Consumes: tudo das Tasks 1-4.
- Produces: nada (última task do bloco).

- [ ] **Step 1: Rodar a suíte completa do app**

Run: `cd app && flutter test`
Expected: PASS — 117 testes no total (104 já existentes + 10 de `update_checker_test.dart` + 3 de `update_gate_screen_test.dart`).

- [ ] **Step 2: `flutter analyze` na árvore final**

Run: `cd app && flutter analyze`
Expected: "No issues found!"

- [ ] **Step 3: Verificação disponível nesta máquina**

Esta máquina não roda Android de verdade (só compila via GitHub Actions —
ver DECISION-015/029), então não dá pra abrir o app instalado e ver a tela
de bloqueio acontecendo ao vivo aqui. A validação real já aconteceu nos
testes de widget da Task 3 (`isAndroid: true` forçado, cobrindo os três
estados). Rodar `flutter run -d web-server` uma vez (servidor reiniciado,
não só recarregado — lição do Bloco 3) só pra confirmar que a Home
continua abrindo normalmente em Web (checagem pulada, sem regressão):

1. Abrir a Home — deve aparecer direto, sem nenhuma tela de "Verificando
   atualizações..." travando (Web pula a checagem).
2. Checar o console: sem exceções novas.

- [ ] **Step 4: Registrar `DECISION-037` em `DECISIONS.md`**

Adicionar ao final do arquivo, seguindo o formato das decisões anteriores:

```markdown
## DECISION-037
Data: 2026-09-10
Decisão: checagem obrigatória de atualização — o app consulta a API
pública do GitHub Releases ao abrir (só em Android) e bloqueia o jogo
inteiro, Treino incluso, se existir uma versão mais nova publicada. Acaba
com o processo manual de avisar cada amigo que existe um APK novo pra
baixar.
Passos: `UpdateChecker` (`game_domain`) chama
`GET /repos/MarlonFer77/jogo-elementos/releases/latest` (header
`User-Agent` obrigatório, senão a API do GitHub devolve 403), compara a
tag da release com a versão instalada (`isNewerVersion`, comparação pura
de `major.minor.patch`) e devolve um `UpdateCheckResult`. Qualquer falha
(sem rede, timeout, resposta inesperada) devolve "está atualizado" —
fail-open, nunca bloqueia por problema de rede transitório. Nova
`UpdateGateScreen` vira a raiz do app (`main.dart`), no lugar da
`HomeScreen` direta: mostra "Verificando atualizações..." enquanto checa,
a Home se estiver tudo certo, ou uma tela bloqueante "Atualização
necessária" com um botão que abre o link de download no navegador
(`url_launcher`) — sem forma de pular. Web/Windows (só desenvolvimento,
nunca distribuídos) pulam a checagem inteira. Duas dependências novas:
`package_info_plus` (lê a versão instalada de verdade) e `url_launcher`
(abre o navegador).
Motivo: pedido direto do usuário — cansativo reenviar o link do APK pro
amigo toda vez que sai uma versão nova; o app agora se anuncia sozinho.
Consequência/processo novo: a partir de agora, toda vez que eu gerar e
publicar um APK novo preciso **também** atualizar o campo `version:` do
`app/pubspec.yaml` pra bater com a tag da release (ex: tag `v0.9.0` →
`version: 0.9.0+9`) — é esse campo que vira o `versionName` real
instalado, que o `package_info_plus` lê em runtime. Sem esse passo, o app
nunca vai se reconhecer como desatualizado. `pubspec.yaml` está em
`1.0.0+1` ainda — a primeira geração de APK depois deste bloco já precisa
vir com esse bump.
Lacuna conhecida: esta máquina não roda Android de verdade (só compila via
GitHub Actions), então a validação ficou limitada aos testes de widget com
`isAndroid: true` forçado — nunca visto rodando de verdade num aparelho
Android aqui. Pedir confirmação manual do usuário depois do próximo APK.
Testes: suíte completa do app (`flutter test`, 117 testes) e `flutter
analyze` passando.
```

- [ ] **Step 5: Atualizar `TASKS.md`**

Adicionar ao final da seção `# DONE`:

```markdown
- Checagem obrigatória de atualização: `UpdateChecker` consulta a API do
  GitHub Releases, `UpdateGateScreen` vira a raiz do app e bloqueia o jogo
  inteiro se existir versão mais nova (fail-open em erro de rede,
  checagem só em Android) — acaba com o aviso manual de "tem APK novo"
  pro amigo (DECISION-037)
```

Na seção `# BACKLOG`, sub-seção "App Flutter (app/)", adicionar:

```markdown
- Checagem de atualização (DECISION-037) nunca testada rodando de verdade
  num Android — esta máquina só compila via GitHub Actions. Validado só
  via teste de widget com `isAndroid` forçado
```

- [ ] **Step 6: Commit**

```bash
git add DECISIONS.md TASKS.md
git commit -m "Registra DECISION-037 e atualiza TASKS.md (checagem obrigatoria de atualizacao)"
```

- [ ] **Step 7: Finalizar o bloco**

Announce: "I'm using the finishing-a-development-branch skill to complete this work."
**REQUIRED SUB-SKILL:** Use superpowers:finishing-a-development-branch — rodar a suíte final, apresentar as opções, executar a escolha do usuário.

---

## Self-Review

**1. Cobertura da spec:** "Fonte: API do GitHub Releases" → Task 2 (`UpdateChecker`). "Fail-open" → Task 2, os 3 testes de falha (`404`, JSON sem `tag_name`/assets, exceção de rede) todos devolvendo `upToDate`. "Bloqueia tudo, logo ao abrir" → Task 3/4 (`UpdateGateScreen` vira a raiz do `main.dart`, sem opção de pular). "Header User-Agent obrigatório" → Task 2, testado explicitamente (`expect(request.headers['User-Agent'], ...)`). "Pula em Web/Windows" → Task 3, teste `isAndroid: false` com um `UpdateChecker` que lança se for chamado (prova que nem é invocado). "`await Future.delayed(Duration.zero)` antes de qualquer `setState`" → Task 3, primeira linha de `_check()`. "Novo passo no processo de release (bump do pubspec)" → registrado na DECISION-037 (Task 5), não é código, é processo — não cabe um "task de código" pra isso, é uma ação futura minha documentada. "Consequência em `training_screen_test.dart`" → Task 4, os 3 pontos exatos com before/depois. Nenhum requisito da spec ficou sem task.

**2. Placeholder scan:** Nenhum "TBD"/"implementar depois" — todo código é completo e colável direto, inclusive o arquivo de teste inteiro da Task 3.

**3. Consistência de tipos:** `UpdateChecker({http.Client? httpClient})`/`checkForUpdate({required String currentVersion})` (Task 2) usado identicamente pelos fakes da Task 3 (`implements UpdateChecker`, mesma assinatura de método). `UpdateCheckResult.upToDate()`/`UpdateCheckResult.updateAvailable({required latestVersion, required downloadUrl})` (Task 2) usados identicamente nos testes da Task 3. `UpdateGateScreen({UpdateChecker? updateChecker, String? currentVersion, bool? isAndroid, Future<void> Function(Uri uri)? launchUrl})` (Task 3) usado identicamente na Task 4 (`const UpdateGateScreen()` em `main.dart`, todos os parâmetros opcionais — nenhum quebra ao omitir).
