# Checagem obrigatória de atualização (Bloco extra — antes do Skill Tree) — design

Data: 2026-09-10
Status: aprovado pelo usuário, pronto para virar plano de implementação.

## Contexto

Hoje, toda vez que sai uma versão nova do jogo, o fluxo é totalmente manual:
gero o APK, publico como asset de uma GitHub Release, e cada amigo precisa
saber que existe uma versão nova e baixar o link de novo por conta própria.
Não existe nenhum mecanismo no app que avise "sua versão está desatualizada".
O usuário pediu uma forma de o próprio app avisar e **obrigar** a
atualização ao abrir, antes de investir no próximo bloco de game feel
(Skill Tree).

Distribuição atual (ver DECISION-029): APK compilado via GitHub Actions
(`.github/workflows/build-apk.yml`), publicado como asset `app-release.apk`
de uma GitHub Release (`gh release create vX.Y.Z app-release.apk ...`). Sem
Play Store — instalação é sideload manual. `pubspec.yaml` tem
`version: 1.0.0+1` hoje, nunca incrementado — as tags de release (v0.1.0 a
v0.8.0) não têm relação nenhuma com esse campo ainda.

## Decisões confirmadas (conversa com o usuário)

1. **Fonte da versão mais recente**: a API pública do GitHub Releases
   (`GET /repos/MarlonFer77/jogo-elementos/releases/latest`), consultada
   direto do app. Zero infraestrutura nova, zero custo, e reaproveita
   exatamente o processo que já existe — toda `gh release create` já vira
   automaticamente a "versão mais recente", sem nenhum passo manual extra
   pra lembrar (rejeitada a alternativa de expor um endpoint próprio no
   backend, que exigiria manter uma segunda fonte de verdade sincronizada
   manualmente a cada release).
2. **Falha na checagem** (sem internet, GitHub fora do ar, timeout):
   **fail-open** — trata como "está atualizado", deixa jogar normalmente.
   Uma falha de rede transitória não pode impedir o Modo Treino (que nem
   depende de rede).
3. **Escopo do bloqueio**: bloqueia o jogo inteiro, logo ao abrir — não só
   o Multiplayer. Ninguém joga com versão desatualizada, nem offline.

## O que NÃO está neste bloco

- Nenhum mecanismo de auto-instalação/auto-update de verdade — Android
  sideload não permite isso sem complexidade/permissões extras
  desproporcionais pro tamanho do projetinho. A "atualização" é: abrir o
  navegador na URL de download do APK novo e deixar o usuário instalar por
  cima manualmente (o APK já é assinado com a mesma chave debug em todo
  build — ver DECISION-029 — então instalar por cima do já instalado
  funciona sem precisar desinstalar antes).
- Nenhuma mudança no processo de build/release em si
  (`build-apk.yml`, `gh release create`) — só um passo manual novo no meu
  processo, descrito abaixo.
- Nenhuma verificação de versão em Web/Windows (plataformas só de
  desenvolvimento, nunca distribuídas — ver BACKLOG "Produção / deploy").
  Nessas plataformas a checagem é pulada e o app abre direto na Home.

## Novo passo no processo de release (ação minha, não é código)

A partir de agora, toda vez que eu gerar e publicar um APK novo, preciso
**também** atualizar o campo `version:` do `app/pubspec.yaml` pra bater com
a tag da release (ex: tag `v0.9.0` → `version: 0.9.0+9`, incrementando o
build number). É esse campo que vira o `versionName` real instalado no
Android, que o app lê em runtime (via `package_info_plus`) pra se comparar
com o que a API do GitHub diz que é o mais recente. Sem esse passo, o app
nunca vai se reconhecer como desatualizado.

## Componentes novos (`game_domain/`)

### `UpdateChecker`

Mesmo padrão de `MultiplayerClient` (`http.Client` injetável, sem estado,
sem retry — quem chama decide quando chamar de novo):

```dart
class UpdateChecker {
  UpdateChecker({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;

  static const _releasesUrl =
      'https://api.github.com/repos/MarlonFer77/jogo-elementos/releases/latest';
  static const _apkAssetName = 'app-release.apk';

  Future<UpdateCheckResult> checkForUpdate({required String currentVersion}) async {
    try {
      final response = await _http.get(
        Uri.parse(_releasesUrl),
        headers: {'User-Agent': 'jogo-elementos-app'}, // GitHub API exige User-Agent — sem isso, 403
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return const UpdateCheckResult.upToDate();

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final tagName = body['tag_name'] as String?;
      if (tagName == null) return const UpdateCheckResult.upToDate();

      final latestVersion = tagName.startsWith('v') ? tagName.substring(1) : tagName;
      if (!isNewerVersion(latestVersion, currentVersion)) {
        return const UpdateCheckResult.upToDate();
      }

      final assets = (body['assets'] as List<dynamic>?) ?? const [];
      final apkAsset = assets
          .cast<Map<String, dynamic>>()
          .where((a) => a['name'] == _apkAssetName)
          .firstOrNull;
      final downloadUrl = apkAsset?['browser_download_url'] as String?;
      if (downloadUrl == null) return const UpdateCheckResult.upToDate();

      return UpdateCheckResult.updateAvailable(
        latestVersion: latestVersion,
        downloadUrl: downloadUrl,
      );
    } catch (_) {
      return const UpdateCheckResult.upToDate(); // fail-open, decisão confirmada
    }
  }
}
```

(`firstOrNull` vem de `package:collection` — se não estiver já como
dependência transitiva disponível, usar um `for`/`try` manual equivalente;
decisão de implementação, não muda o comportamento.)

### `UpdateCheckResult`

```dart
class UpdateCheckResult {
  const UpdateCheckResult({required this.updateAvailable, this.latestVersion, this.downloadUrl});
  const UpdateCheckResult.upToDate() : this(updateAvailable: false);
  const UpdateCheckResult.updateAvailable({required String latestVersion, required String downloadUrl})
      : this(updateAvailable: true, latestVersion: latestVersion, downloadUrl: downloadUrl);

  final bool updateAvailable;
  final String? latestVersion;
  final String? downloadUrl;
}
```

### `isNewerVersion(String remote, String local)`

Função pura, sem Flutter, comparando `major.minor.patch` (ou qualquer
número de segmentos — segmentos faltando contam como `0`, então `"0.9"` vs
`"0.9.0"` são iguais):

```dart
bool isNewerVersion(String remote, String local) {
  final remoteParts = _versionParts(remote);
  final localParts = _versionParts(local);
  final length = remoteParts.length > localParts.length ? remoteParts.length : localParts.length;
  for (var i = 0; i < length; i++) {
    final r = i < remoteParts.length ? remoteParts[i] : 0;
    final l = i < localParts.length ? localParts[i] : 0;
    if (r != l) return r > l;
  }
  return false;
}

List<int> _versionParts(String version) =>
    version.split('.').map((p) => int.tryParse(p) ?? 0).toList();
```

## Nova tela (`ui/update_gate_screen.dart`)

Substitui `HomeScreen` como `home:` do `MaterialApp` em `main.dart`. Três
parâmetros opcionais pra testabilidade — mesmo espírito de
`MultiplayerLobbyScreen({MultiplayerClient? client})`, sem precisar mockar
platform channels (`PackageInfo`, `dart:io Platform`) em teste:

```dart
class UpdateGateScreen extends StatefulWidget {
  const UpdateGateScreen({
    super.key,
    UpdateChecker? updateChecker,
    String? currentVersion,
    bool? isAndroid,
    Future<void> Function(Uri)? launchUrl,
  });
  // campos privados correspondentes
}
```

- `isAndroid` (default: `!kIsWeb && Platform.isAndroid`) — em teste,
  força o caminho Android sem depender da plataforma real que roda `flutter
  test` (que nunca é Android).
- `currentVersion` (default: resolvido via `(await
  PackageInfo.fromPlatform()).version`) — em teste, passa a string direto.
- `updateChecker` (default: `UpdateChecker()` real) — em teste, passa um
  com `http.Client` mockado (`MockClient`, mesmo padrão dos testes de
  Multiplayer) ou um fake que já devolve o `UpdateCheckResult` esperado.
- `launchUrl` (default: `url_launcher`'s `launchUrl(uri, mode:
  LaunchMode.externalApplication)`) — em teste, um fake que só registra a
  chamada.

Três estados (`_GateState`: `checking`, `upToDate`, `updateRequired`):

- **Se não for Android** (`!_runningOnAndroid`): pula a checagem
  inteiramente, vai direto pra `upToDate`.
- **`checking`**: tela no estilo pixel art (mesmo fundo/título da Home —
  `ArenaBackdropPainter` + `PixelOutlinedText('ELEMENTOS')`) com o texto
  "Verificando atualizações...".
- **`updateRequired`**: mesmo fundo, título `PixelOutlinedText('Atualização
  necessária')`, mensagem citando a versão nova, e um único
  `PixelMenuButton('Baixar atualização')` que chama `launchUrl` com a URL
  do APK. Sem forma de pular — não é um diálogo dispensável, é a tela
  inteira; não há navegação de volta (é a raiz do app).
- **`upToDate`**: retorna `const HomeScreen()` direto (não navega — troca
  o que é construído).

**Detalhe importante de implementação**: `_check()` precisa de pelo menos
um `await` genuíno *antes* de qualquer `setState`, mesmo no caminho
"não é Android" (que senão chamaria `setState` de forma síncrona dentro de
`initState`, o que o Flutter não permite). Resolver com
`await Future<void>.delayed(Duration.zero);` como a primeira linha de
`_check()`, cobrindo todos os caminhos igualmente.

## `main.dart`

```dart
home: const UpdateGateScreen(),
```
no lugar de `home: const HomeScreen()`.

## Dependências novas

`package_info_plus` (lê a versão instalada de verdade) e `url_launcher`
(abre o link de download no navegador) — ambos pacotes oficiais/"Flutter
Favorite", gratuitos, mantidos ativamente. Adicionados via `flutter pub add
package_info_plus url_launcher` na hora da implementação (sem fixar número
de versão aqui no spec — deixa o `pub` resolver a versão compatível atual).

## Consequência em testes existentes

`training_screen_test.dart` é o único arquivo de teste que usa
`GameApp()` diretamente (`home_screen_test.dart` monta `HomeScreen()` sem
passar pelo `GameApp`/`UpdateGateScreen`, então não é afetado). Os 3 testes
que fazem:

```dart
await tester.pumpWidget(const GameApp());
await tester.tap(find.text('MODO TREINO'));
```

passam a precisar de um `await tester.pump();` entre as duas linhas —
sem isso, a tela ainda está em `checking` ("Verificando atualizações...")
e `find.text('MODO TREINO')` não encontra nada (`GameApp()`, sem
plataforma Android real em teste, cai no caminho "pula a checagem", mas
ainda precisa de um ciclo de `pump()` pra sair do estado inicial por causa
do `await Future.delayed(Duration.zero)`). Os testes que montam
`TrainingScreen`/`MaterialApp(home: TrainingScreen(...))` diretamente (os
outros 2 testes do arquivo) não usam `GameApp` — sem mudança.

## Testes esperados (novos)

- `isNewerVersion`: casos — igual (`false`), remoto maior em patch/minor/
  major (`true`), remoto menor (`false`), segmentos faltando (`"0.9"` vs
  `"0.9.0"` → igual, `false`).
- `UpdateChecker.checkForUpdate`: com `MockClient` (mesmo padrão dos testes
  de `MultiplayerClient`) — resposta 200 com `tag_name` maior que
  `currentVersion` → `updateAvailable` com a URL certa do asset
  `app-release.apk`; resposta 200 com `tag_name` igual/menor →
  `upToDate`; resposta não-200, corpo inválido, ou o `MockClient` lançando
  uma exceção (simula timeout/sem rede) → `upToDate` nos três casos
  (fail-open).
- `UpdateGateScreen`: widget test — `isAndroid: false` → mostra a Home
  direto, sem chamar o `updateChecker` passado (usar um fake que lança se
  for chamado, provando que nem é invocado); `isAndroid: true` +
  `updateChecker` fake devolvendo `upToDate` → mostra a Home depois de um
  `pump()`; `isAndroid: true` + `updateChecker` fake devolvendo
  `updateAvailable` → mostra "Atualização necessária" e a versão, e tocar
  "Baixar atualização" chama o `launchUrl` fake com a URI esperada.
- Verificação manual: como o ambiente de desenvolvimento nesta máquina só
  roda `flutter run -d web-server` (Android só compila via GitHub Actions,
  ver DECISION-015/029), a checagem real não pode ser testada rodando de
  verdade num Android aqui — verificado via `isAndroid: true` forçado nos
  testes de widget acima, que é a validação disponível. Depois de gerar o
  próximo APK (com a versão do `pubspec.yaml` já bumped), pedir pro
  usuário confirmar manualmente no celular dele que abrir uma versão mais
  antiga instalada mostra a tela de atualização obrigatória.

## Fora de escopo, mas não esquecido

Nenhum gap novo — este bloco é auto-contido (checagem de versão +
bloqueio). O próximo bloco de game feel (Skill Tree) continua na fila.
