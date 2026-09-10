# Download de atualização dentro do app (Bloco extra) — design

Data: 2026-09-10
Status: aprovado pelo usuário, pronto para virar plano de implementação.

## Contexto

A checagem obrigatória de atualização (DECISION-037) funciona, mas o
mecanismo de "atualizar" hoje é: abrir o navegador na URL do APK no
GitHub Release, o usuário baixa e instala manualmente. O usuário testou
de verdade no celular e esperava algo diferente — download com barra de
progresso dentro do próprio app, terminando em abrir o instalador do
Android sozinho, sem sair pro navegador.

No mesmo teste, apareceu um bug separado, já corrigido (DECISION-039): o
workflow de build gerava uma assinatura de debug diferente a cada APK,
então nenhuma atualização "por cima" funcionava, não importa o mecanismo
de download. Isso está resolvido — o próximo APK gerado já fixa a
assinatura pra sempre a partir dali.

## Decisões confirmadas (conversa com o usuário)

1. **Pacote**: `ota_update` (pub.dev, v7.1.0, publicado há ~9 meses,
   mantenedor verificado `4q.eu`) — feito especificamente pra esse fluxo
   (baixar + acionar o instalador do Android), evitando montar na mão a
   configuração de `FileProvider`/intent de instalação numa máquina que
   não builda Android localmente pra testar.
2. **Falha no download**: mostra erro com botão "Tentar de novo" — sem
   fallback pro navegador (mecanismo antigo é removido, não mantido como
   plano B).

## O que NÃO está neste bloco

- Nenhuma mudança em `UpdateChecker`/`isNewerVersion` (DECISION-037) —
  continuam exatamente iguais, só fornecem a `downloadUrl`.
- Nenhuma mudança no workflow de build/assinatura (DECISION-039, já
  resolvido separadamente).
- Sem botão de cancelar o download em andamento — YAGNI, não foi pedido.
- Sem verificação de checksum (`sha256checksum` do `ota_update` é
  opcional) — o GitHub Release já serve o arquivo por HTTPS, verificação
  extra não foi pedida.

## Dependências

- **Adiciona** `ota_update` (`flutter pub add ota_update`).
- **Remove** `url_launcher` — usado hoje só em `update_gate_screen.dart`
  (confirmado por busca no repositório), fica sem nenhum uso depois deste
  bloco. `flutter pub remove url_launcher` evita deixar uma dependência
  fantasma (CLAUDE.md: "sem dependências desnecessárias").

## Setup Android (`app/android/app/src/main/AndroidManifest.xml`)

Duas permissões novas, dentro de `<manifest>` (junto da já existente
`INTERNET`):

```xml
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>
```

Um `<provider>` e um `<receiver>` novos, dentro de `<application>` (o
pacote documenta essas classes exatas):

```xml
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
```

Novo arquivo de recurso `app/android/app/src/main/res/xml/filepaths.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<paths xmlns:android="http://schemas.android.com/apk/res/android">
    <files-path name="internal_apk_storage" path="ota_update/"/>
</paths>
```

**Importante pro plano**: os nomes exatos de enum/API do `ota_update`
citados abaixo (`OtaStatus`, campos de `OtaEvent`) vêm da documentação do
pacote, não do código-fonte lido diretamente — a task que adiciona a
dependência precisa abrir o pacote baixado (`~/.pub-cache` ou
`.dart_tool/package_config.json` aponta o caminho) e confirmar os nomes
exatos antes de escrever o código que os usa, já que esta máquina não
consegue compilar Android pra pegar esse tipo de erro cedo.

## `UpdateGateScreen` — novo fluxo de download

Substitui `_openDownload`/`_launchUrl` por um sub-estado de download
dentro do estado `updateRequired`:

```dart
enum _DownloadState { idle, downloading, installing, error }
```

- **`idle`** (estado inicial): mostra o `PixelMenuButton('Baixar
  atualização')` de hoje — `onPressed` chama `_startDownload`.
- **`downloading`**: barra de progresso simples (`Container` com borda
  escura 3px preenchido proporcionalmente em dourado, mesma paleta de
  sempre) + texto `'Baixando... X%'`.
- **`installing`**: texto `'Abrindo instalador...'` — a partir daqui o
  Android assume, mostrando a tela nativa de confirmação de instalação
  (o app pode ficar em segundo plano nesse momento; isso é esperado, não
  um bug).
- **`error`**: mensagem de erro + `PixelMenuButton('Tentar de novo')` que
  chama `_startDownload` de novo do zero.

`_startDownload()` chama `widget._startDownload?.call(url) ??
OtaUpdate().execute(url, destinationFilename: 'app-release.apk')` —
mesmo padrão de injeção pra teste já usado com `launchUrl`/`currentVersion`/
`isAndroid` hoje. Escuta o `Stream<OtaEvent>`:
- `OtaStatus.DOWNLOADING` → `_DownloadState.downloading`, atualiza o
  percentual a partir de `event.value`.
- `OtaStatus.INSTALLING` / `OtaStatus.INSTALLATION_DONE` →
  `_DownloadState.installing`.
- Qualquer status de erro (`DOWNLOAD_ERROR`, `INSTALLATION_ERROR`,
  `PERMISSION_NOT_GRANTED_ERROR`, `CHECKSUM_ERROR`, `INTERNAL_ERROR`,
  `ALREADY_RUNNING_ERROR`, `CANCELED`) → `_DownloadState.error`, com uma
  mensagem fixa em português (não expõe o enum cru na tela).
- Erro na própria `Stream` (`onError`) → mesma coisa, mensagem genérica.

`UpdateGateScreen`'s construtor: `launchUrl` sai, entra
`Stream<OtaEvent> Function(String url)? startDownload`. `updateChecker`/
`currentVersion`/`isAndroid` continuam iguais.

## Consequência em testes existentes

`update_gate_screen_test.dart` tem 3 testes hoje; o terceiro ("shows the
update-required screen and opens the download link when an update is
available") precisa ser **reescrito por completo** — não é mais sobre
abrir um link, é sobre acompanhar um download. Ele passa a:
1. Montar a tela com um `startDownload` fake que devolve uma `Stream`
   controlada (ex: via `StreamController<OtaEvent>` manual, pra emitir
   eventos um de cada vez e verificar a UI depois de cada um).
2. Tocar "Baixar atualização", confirmar que aparece a barra de
   progresso.
3. Emitir um evento `DOWNLOADING` com `value` intermediário, confirmar
   que o texto do percentual bate.
4. Emitir `INSTALLATION_DONE`, confirmar que aparece "Abrindo
   instalador...".
5. Um teste novo separado cobre o caminho de erro: emitir um status de
   erro (ou fechar a stream com `addError`), confirmar que aparece a
   mensagem + "Tentar de novo", tocar nele, confirmar que volta pra
   `downloading` (uma nova chamada de `startDownload` acontece).

Os outros 2 testes (`isAndroid: false` → Home; `isAndroid: true` +
`upToDate` → Home) não tocam nesse fluxo — sem mudança.

## Testes esperados (novos/ajustados)

- Os 4 pontos acima em `update_gate_screen_test.dart` (3 reescritos/
  novos, cobrindo download com progresso, transição pra instalação, e
  erro com retry).
- Sem teste automatizado pra configuração do Android Manifest/provider
  (não é algo que `flutter test` alcança) — fica só a validação manual.
- Verificação manual: como esta máquina não builda Android, a validação
  real fica pro usuário — gerar um APK novo (com a assinatura já
  estabilizada pela DECISION-039) e confirmar no celular que "Baixar
  atualização" mostra a barra de progresso, termina abrindo o instalador
  nativo, e a instalação por cima da versão anterior funciona sem erro.

## Fora de escopo, mas não esquecido

Nenhum gap novo — este bloco fecha a expectativa original do usuário
sobre a checagem de atualização (DECISION-037).
