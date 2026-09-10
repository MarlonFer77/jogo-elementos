# Download de atualização dentro do app Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Trocar "abrir o navegador pra baixar o APK" por um download com barra de progresso dentro do próprio app, terminando em abrir o instalador nativo do Android sozinho.

**Architecture:** `UpdateGateScreen` ganha um sub-estado de download (`_DownloadState`: idle/downloading/installing/error) alimentado pelo `Stream<OtaEvent>` do pacote `ota_update` — injetável no construtor pro mesmo padrão de teste já usado (`updateChecker`/`currentVersion`/`isAndroid`). O Android precisa de duas permissões novas e um `FileProvider`/`receiver` documentados pelo próprio pacote.

**Tech Stack:** Flutter + Dart, pacote `ota_update` (v7.1.0, API confirmada lendo o código-fonte real em `~/.pub-cache` antes de escrever este plano — ver Global Constraints).

**Spec:** [docs/superpowers/specs/2026-09-10-in-app-update-download-design.md](../specs/2026-09-10-in-app-update-download-design.md)

## Global Constraints

- API real do `ota_update` (v7.1.0), confirmada lendo
  `lib/ota_update.dart` do pacote antes de escrever este plano — não é
  suposição:
  - `OtaUpdate().execute(url, {..., String? destinationFilename, ...})`
    devolve `Stream<OtaEvent>`.
  - `class OtaEvent { OtaEvent(this.status, this.value); OtaStatus status;
    String? value; }` — construtor público, posicional.
  - `enum OtaStatus { DOWNLOADING, INSTALLING, INSTALLATION_DONE,
    ALREADY_RUNNING_ERROR, INSTALLATION_ERROR,
    PERMISSION_NOT_GRANTED_ERROR, INTERNAL_ERROR, DOWNLOAD_ERROR,
    CHECKSUM_ERROR, CANCELED }` — exatamente estes 10 valores, nesta
    grafia.
  - Cada chamada a `OtaUpdate().execute(...)` numa instância nova de
    `OtaUpdate` começa uma stream nova (o cache interno do pacote é por
    instância) — por isso todo retry cria uma instância `OtaUpdate()`
    nova, nunca reaproveita uma guardada em campo de estado.
- Sem botão de cancelar, sem verificação de checksum — YAGNI, não pedido.
- Falha no download: mostra erro + botão "Tentar de novo", sem fallback
  pro navegador (mecanismo antigo é removido, não mantido como plano B).
- `url_launcher` sai das dependências — confirmado por busca no
  repositório que só era usado em `update_gate_screen.dart`, sem uso
  nenhum depois deste bloco.
- Paleta já estabelecida: `Color(0xFF2B2B2B)` (borda/texto escuro),
  `Color(0xFFF4F4E4)` (creme), `Color(0xFFF4C94A)` (dourado, preenchimento
  da barra de progresso). Erro em `Colors.red`, mesmo padrão já usado em
  `_error` de outras telas.
- Esta máquina não builda Android localmente (só via GitHub Actions) —
  nenhuma das mudanças de Manifest/XML tem como ser validada rodando de
  verdade aqui. A validação real fica pro usuário, testando o próximo APK
  gerado.
- Cada task com código Dart termina com `flutter analyze` limpo e
  `flutter test` verde antes do commit.

---

## Task 1: Dependências (`ota_update` entra, `url_launcher` sai)

**Files:**
- Modify: `app/pubspec.yaml`, `app/pubspec.lock`

**Interfaces:**
- Consumes: nada de outras tasks.
- Produces: `package:ota_update/ota_update.dart` disponível pras Tasks 2 e 3.

- [ ] **Step 1: Adicionar `ota_update`**

Run: `cd app && flutter pub add ota_update`
Expected: `pubspec.yaml` ganha `ota_update: ^7.1.0` em `dependencies:`,
comando termina sem erro (o aviso sobre "Building with plugins requires
symlink support" já apareceu antes nesta máquina pra outras dependências
— é sobre o target Windows desktop, que este projeto não usa pra nada
distribuído, pode ignorar).

- [ ] **Step 2: Remover `url_launcher`**

Run: `cd app && flutter pub remove url_launcher`
Expected: `url_launcher` (e os pacotes de plataforma dele —
`url_launcher_android`, `url_launcher_web` etc.) somem de `pubspec.yaml`/
`pubspec.lock`, comando termina sem erro.

- [ ] **Step 3: Confirmar que a suíte ainda roda (o código ainda usa `url_launcher` neste ponto — vai quebrar, é esperado)**

Run: `cd app && flutter analyze`
Expected: FALHA — `update_gate_screen.dart` ainda importa
`package:url_launcher/url_launcher.dart`, que não existe mais como
dependência. Essa falha é esperada e será corrigida na Task 3, que
reescreve o arquivo inteiro.

- [ ] **Step 4: Commit**

```bash
git add app/pubspec.yaml app/pubspec.lock
git commit -m "Adiciona ota_update, remove url_launcher"
```

---

## Task 2: Setup Android (Manifest + FileProvider)

**Files:**
- Modify: `app/android/app/src/main/AndroidManifest.xml`
- Create: `app/android/app/src/main/res/xml/filepaths.xml`

**Interfaces:**
- Consumes: nada de outras tasks.
- Produces: nada consumido por outras tasks (configuração nativa, sem
  interface Dart).

- [ ] **Step 1: Adicionar as duas permissões novas**

Em `app/android/app/src/main/AndroidManifest.xml`, substituir:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>
```

por:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
    <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>
```

- [ ] **Step 2: Adicionar o `<provider>` e o `<receiver>` do `ota_update`**

No mesmo arquivo, substituir:

```xml
        <!-- Don't delete the meta-data below.
             This is used by the Flutter tool to generate GeneratedPluginRegistrant.java -->
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
```

por:

```xml
        <!-- Don't delete the meta-data below.
             This is used by the Flutter tool to generate GeneratedPluginRegistrant.java -->
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
        <provider
            android:name="sk.fourq.otaupdate.OtaUpdateFileProvider"
            android:authorities="${applicationId}.ota_update_provider"
            android:exported="false"
            android:grantUriPermissions="true">
            <meta-data
                android:name="android.support.FILE_PROVIDER_PATHS"
                android:resource="@xml/filepaths" />
        </provider>
        <receiver android:name="sk.fourq.otaupdate.InstallResultReceiver" android:exported="false">
            <intent-filter>
                <action android:name="${applicationId}.ACTION_INSTALL_COMPLETE"/>
            </intent-filter>
        </receiver>
    </application>
```

- [ ] **Step 3: Criar `app/android/app/src/main/res/xml/filepaths.xml`**

```xml
<?xml version="1.0" encoding="utf-8"?>
<paths xmlns:android="http://schemas.android.com/apk/res/android">
    <files-path name="internal_apk_storage" path="ota_update/"/>
</paths>
```

- [ ] **Step 4: Verificação disponível nesta máquina**

Não há como compilar Android aqui pra validar o XML de verdade (ver
Global Constraints). Confirmar visualmente que o `AndroidManifest.xml`
ainda é um XML bem-formado (tags abertas/fechadas corretamente) e que o
arquivo novo foi criado no caminho certo:

Run: `cd app && cat android/app/src/main/res/xml/filepaths.xml`
Expected: mostra o conteúdo exato do Step 3.

- [ ] **Step 5: Commit**

```bash
git add app/android/app/src/main/AndroidManifest.xml app/android/app/src/main/res/xml/filepaths.xml
git commit -m "Configura Android pro download in-app (permissoes, FileProvider)"
```

---

## Task 3: `UpdateGateScreen` — download com progresso

**Files:**
- Modify: `app/lib/ui/update_gate_screen.dart` (arquivo inteiro)
- Modify: `app/test/update_gate_screen_test.dart` (o terceiro teste, mais dois novos)

**Interfaces:**
- Consumes: `OtaUpdate`/`OtaEvent`/`OtaStatus` (pacote `ota_update`, Task 1).
- Produces: `UpdateGateScreen` com o construtor trocando `Future<void>
  Function(Uri uri)? launchUrl` por `Stream<OtaEvent> Function(String
  url)? startDownload` — nada mais consome isso depois (é a última peça
  do fluxo de atualização).

- [ ] **Step 1: Confirmar a suíte atual passa antes de mexer (baseline)**

Run: `cd app && flutter test test/update_gate_screen_test.dart`
Expected: FALHA — já esperado desde a Task 1 (import de `url_launcher`
quebrado). Isso confirma que estamos no ponto certo do plano pra corrigir
com a reescrita desta task.

- [ ] **Step 2: Reescrever o terceiro teste e adicionar dois novos**

Substituir todo o conteúdo de `app/test/update_gate_screen_test.dart` por:

```dart
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
    await tester.pump();

    expect(find.text('Baixando... 45%'), findsOneWidget);

    controller.add(OtaEvent(OtaStatus.INSTALLATION_DONE, null));
    await tester.pump();

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
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd app && flutter test test/update_gate_screen_test.dart`
Expected: FALHA — `UpdateGateScreen` ainda não tem o parâmetro
`startDownload` nem o fluxo de download novo.

- [ ] **Step 4: Reescrever `UpdateGateScreen`**

Substituir todo o conteúdo de `app/lib/ui/update_gate_screen.dart` por:

```dart
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../game_domain/update_checker.dart';
import '../game_presentation/pixel_arena_background.dart';
import '../game_presentation/pixel_menu_button.dart';
import '../game_presentation/pixel_outlined_text.dart';
import 'home_screen.dart';

enum _GateState { checking, upToDate, updateRequired }

enum _DownloadState { idle, downloading, installing, error }

/// Tela raiz do app (`main.dart`'s `home:`) — checa se existe uma versão
/// nova antes de mostrar a Home, e bloqueia o jogo inteiro se estiver
/// desatualizado. Só roda a checagem de verdade em Android; Web/Windows
/// (só desenvolvimento, nunca distribuídos) pulam direto pra Home. O
/// download da atualização acontece dentro do próprio app (pacote
/// `ota_update`), com barra de progresso, terminando em abrir o
/// instalador nativo do Android. Ver
/// docs/superpowers/specs/2026-09-10-in-app-update-download-design.md.
class UpdateGateScreen extends StatefulWidget {
  const UpdateGateScreen({
    super.key,
    UpdateChecker? updateChecker,
    String? currentVersion,
    bool? isAndroid,
    Stream<OtaEvent> Function(String url)? startDownload,
  })  : _updateChecker = updateChecker,
        _currentVersion = currentVersion,
        _isAndroid = isAndroid,
        _startDownload = startDownload;

  final UpdateChecker? _updateChecker;
  final String? _currentVersion;
  final bool? _isAndroid;
  final Stream<OtaEvent> Function(String url)? _startDownload;

  @override
  State<UpdateGateScreen> createState() => _UpdateGateScreenState();
}

class _UpdateGateScreenState extends State<UpdateGateScreen> {
  _GateState _state = _GateState.checking;
  String? _latestVersion;
  String? _downloadUrl;

  _DownloadState _downloadState = _DownloadState.idle;
  double _downloadProgress = 0;
  String? _downloadErrorMessage;

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

  void _startDownload() {
    final url = _downloadUrl;
    if (url == null) return;
    setState(() {
      _downloadState = _DownloadState.downloading;
      _downloadProgress = 0;
      _downloadErrorMessage = null;
    });
    final stream = widget._startDownload?.call(url) ??
        OtaUpdate().execute(url, destinationFilename: 'app-release.apk');
    stream.listen(
      _handleOtaEvent,
      onError: (Object _) => _handleError('Falha ao baixar a atualização.'),
    );
  }

  void _handleOtaEvent(OtaEvent event) {
    switch (event.status) {
      case OtaStatus.DOWNLOADING:
        final progress = double.tryParse(event.value ?? '');
        if (!mounted) return;
        setState(() {
          _downloadState = _DownloadState.downloading;
          if (progress != null) _downloadProgress = progress;
        });
      case OtaStatus.INSTALLING:
      case OtaStatus.INSTALLATION_DONE:
        if (!mounted) return;
        setState(() => _downloadState = _DownloadState.installing);
      case OtaStatus.ALREADY_RUNNING_ERROR:
      case OtaStatus.INSTALLATION_ERROR:
      case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
      case OtaStatus.INTERNAL_ERROR:
      case OtaStatus.DOWNLOAD_ERROR:
      case OtaStatus.CHECKSUM_ERROR:
      case OtaStatus.CANCELED:
        _handleError('Falha ao baixar a atualização.');
    }
  }

  void _handleError(String message) {
    if (!mounted) return;
    setState(() {
      _downloadState = _DownloadState.error;
      _downloadErrorMessage = message;
    });
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
                          ..._buildDownloadSection(),
                        ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDownloadSection() {
    switch (_downloadState) {
      case _DownloadState.idle:
        return [
          PixelMenuButton(
            label: 'Baixar atualização',
            primary: true,
            onPressed: _startDownload,
          ),
        ];
      case _DownloadState.downloading:
        final progress = (_downloadProgress / 100).clamp(0.0, 1.0);
        return [
          Container(
            width: 240,
            height: 20,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF2B2B2B), width: 3),
              color: const Color(0xFFF4F4E4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: Container(color: const Color(0xFFF4C94A)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Baixando... ${_downloadProgress.round()}%',
            style: const TextStyle(fontFamily: 'monospace', color: Color(0xFF2B2B2B)),
          ),
        ];
      case _DownloadState.installing:
        return [
          const Text(
            'Abrindo instalador...',
            style: TextStyle(fontFamily: 'monospace', color: Color(0xFF2B2B2B)),
          ),
        ];
      case _DownloadState.error:
        return [
          Text(
            _downloadErrorMessage ?? 'Falha ao baixar a atualização.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'monospace', color: Colors.red),
          ),
          const SizedBox(height: 16),
          PixelMenuButton(
            label: 'Tentar de novo',
            primary: true,
            onPressed: _startDownload,
          ),
        ];
    }
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd app && flutter test test/update_gate_screen_test.dart`
Expected: PASS (4 testes).

- [ ] **Step 6: `flutter analyze`**

Run: `cd app && flutter analyze`
Expected: "No issues found!"

- [ ] **Step 7: Commit**

```bash
git add app/lib/ui/update_gate_screen.dart app/test/update_gate_screen_test.dart
git commit -m "UpdateGateScreen baixa a atualizacao dentro do app (ota_update)"
```

---

## Task 4: Suíte completa e registro da decisão

**Files:**
- Modify: `DECISIONS.md` (nova `## DECISION-040`)
- Modify: `TASKS.md` (linha `DONE` nova, ajuste na linha do BACKLOG sobre validação Android)

**Interfaces:**
- Consumes: tudo das Tasks 1-3.
- Produces: nada (última task do bloco).

- [ ] **Step 1: Rodar a suíte completa do app**

Run: `cd app && flutter test`
Expected: PASS — 134 testes no total (133 já existentes antes deste
bloco, menos 1 do teste antigo de `launchUrl` que foi substituído, mais 2
novos = 133 - 1 + 2 = 134).

- [ ] **Step 2: `flutter analyze` na árvore final**

Run: `cd app && flutter analyze`
Expected: "No issues found!"

- [ ] **Step 3: Registrar `DECISION-040` em `DECISIONS.md`**

Adicionar ao final do arquivo, seguindo o formato das decisões anteriores:

```markdown
## DECISION-040
Data: 2026-09-10
Decisão: download de atualização dentro do app — o botão "Baixar
atualização" (DECISION-037) deixa de abrir o navegador e passa a baixar o
APK dentro do próprio app, com barra de progresso, terminando em abrir o
instalador nativo do Android automaticamente. Substitui completamente o
mecanismo de `url_launcher` (removido das dependências).
Passos: pacote `ota_update` (v7.1.0) — `OtaUpdate().execute(url,
destinationFilename: 'app-release.apk')` devolve um `Stream<OtaEvent>`
(`status`/`value`), escutado por `UpdateGateScreen` pra dirigir um novo
sub-estado (`_DownloadState`: idle/downloading/installing/error). Android
ganhou duas permissões (`WRITE_EXTERNAL_STORAGE`,
`REQUEST_INSTALL_PACKAGES`) e um `FileProvider`/`receiver` — configuração
documentada pelo próprio pacote, sem inventar nada na mão. Falha em
qualquer ponto (download ou instalação) mostra uma mensagem + botão
"Tentar de novo", que reinicia o download do zero (sem fallback pro
navegador, decisão do usuário). API do pacote confirmada lendo o
código-fonte real (`~/.pub-cache`) antes de escrever o plano, não por
suposição.
Motivo: o usuário testou a checagem de atualização (DECISION-037) de
verdade e esperava um download com barra de progresso dentro do app, não
precisar sair pro navegador — pedido explícito depois de ver o
comportamento anterior ao vivo.
Consequência: nenhuma lacuna nova conhecida. Depende da DECISION-039
(assinatura estável do APK) já estar em vigor pra realmente funcionar
"atualizar por cima" — sem ela, o download novo funcionaria mas a
instalação ainda falharia com "app não instalado".
Testes: suíte completa do app (`flutter test`, 134 testes) e `flutter
analyze` passando. Sem validação real em Android nesta máquina (só
compila via GitHub Actions) — fica pra confirmação manual do usuário no
próximo APK: baixar dentro do app, ver a barra de progresso andar, o
instalador abrir sozinho, e a instalação por cima da versão anterior
funcionar sem erro.
```

- [ ] **Step 4: Atualizar `TASKS.md`**

Adicionar ao final da seção `# DONE`:

```markdown
- Download de atualização dentro do app: `UpdateGateScreen` baixa o APK
  com barra de progresso (pacote `ota_update`) e abre o instalador do
  Android sozinho, substituindo o "abrir navegador" — erro mostra
  "Tentar de novo", sem fallback pro navegador (DECISION-040)
```

Na seção `# BACKLOG`, sub-seção "App Flutter (app/)", substituir a linha:

```markdown
- Checagem de atualização (DECISION-037) nunca testada rodando de verdade
  num Android — esta máquina só compila via GitHub Actions. Validado só
  via teste de widget com `isAndroid` forçado
```

por:

```markdown
- Checagem de atualização (DECISION-037) e download in-app (DECISION-040)
  nunca testados rodando de verdade num Android — esta máquina só compila
  via GitHub Actions. Validado só via teste de widget com `isAndroid`/
  `startDownload` forçados
```

- [ ] **Step 5: Commit**

```bash
git add DECISIONS.md TASKS.md
git commit -m "Registra DECISION-040 e atualiza TASKS.md (download de atualizacao in-app)"
```

- [ ] **Step 6: Finalizar o bloco**

Announce: "I'm using the finishing-a-development-branch skill to complete this work."
**REQUIRED SUB-SKILL:** Use superpowers:finishing-a-development-branch — rodar a suíte final, apresentar as opções, executar a escolha do usuário.

---

## Self-Review

**1. Cobertura da spec:** "Pacote `ota_update`" → Task 1 (dependência) + Task 3 (uso real, API confirmada contra o código-fonte). "Setup Android" → Task 2, com o XML exato documentado pelo pacote. "Falha: erro + Tentar de novo, sem fallback" → Task 3, teste dedicado (`DOWNLOAD_ERROR` → mensagem + retry, `attempts` contando as duas tentativas). "`url_launcher` sai" → Task 1, Step 2. "Consequência em testes" → Task 3, os 2 testes que sobrevivem intactos (`isAndroid: false`/`upToDate`) e o teste antigo de `launchUrl` completamente substituído por 2 novos. Nenhuma decisão da spec ficou sem task.

**2. Placeholder scan:** Nenhum "TBD"/"implementar depois" — todo código é completo e colável direto, incluindo o arquivo de teste inteiro (Task 3) e o XML do Manifest (Task 2).

**3. Consistência de tipos:** `Stream<OtaEvent> Function(String url)? startDownload` (construtor de `UpdateGateScreen`, Task 3) usado identicamente nos 2 testes novos que o injetam. `OtaEvent(status, value)`/`OtaStatus` (confirmados na Task 1/Global Constraints, direto do código-fonte do pacote) usados identicamente em `_handleOtaEvent` e nos testes. `_DownloadState` (idle/downloading/installing/error) — todo os 4 estados têm um `case` correspondente em `_buildDownloadSection`, nenhum esquecido.
