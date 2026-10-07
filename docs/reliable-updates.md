# Operação e atualização confiáveis

Implementação local, 07/10/2026. Sem APK, publicação ou deploy neste bloco.

## Aplicativo

- Consulta a release estável `latest` do repositório oficial com timeout de 10 s.
- Erro de rede, limite de consultas e release inválida não significam app atualizado:
  a tela oferece nova tentativa ou continuação explícita sem verificar.
- O ícone de atualização no menu permite repetir a consulta manualmente.
- Versão nova exige exatamente um `app-release.apk`, upload concluído, tamanho
  positivo, URL HTTPS do repositório/tag esperado e digest SHA-256 válido.
- O hash é entregue ao instalador OTA para conferir o arquivo baixado. Erros de
  integridade, permissão, instalação e download têm mensagens e nova tentativa.
- O Android continua responsável pela confirmação da instalação e compatibilidade
  da assinatura. Abrir o instalador não comprova que a atualização foi instalada.
- A comparação usa a versão semântica; aumentar apenas `+build` não dispara aviso.

O campo `digest` é documentado na [API oficial de assets do GitHub](https://docs.github.com/en/rest/releases/assets).
Ele verifica integridade, não substitui a assinatura Android nem protege contra
uma conta de publicação comprometida. Assets antigos sem digest são recusados
quando representam uma atualização; publique um novo asset válido.

## Servidor e build

- Em Render ou `NODE_ENV=production`, a inicialização exige `MATCH_STORE=firestore`
  e `FIREBASE_PROJECT_ID`, evitando iniciar silenciosamente com dados em memória.
- `/health` mantém protocolo/contas/persistência e adiciona `revision` (12 caracteres
  de `RENDER_GIT_COMMIT`, ou `APP_COMMIT`; `local` quando ausente/inválido).
  É identificação/configuração, não prova de leitura/gravação no banco.
- Actions permanece manual: imagem Ubuntu 24.04, limite de 30 min, permissão de
  leitura, sem builds concorrentes da mesma ref e erro se o APK não existir.
- A assinatura anterior continua obrigatória. Não foi gerada uma nova chave.

## Próxima publicação coordenada

1. Validar login, recuperação, partida em dois celulares e backups. Não desinstalar
   para atualizar: os saves locais e sua cópia seriam removidos juntos.
2. Aumentar versão **e** build em `app/pubspec.yaml`; salvar em um commit identificado.
3. Publicar o backend desse commit no Render e conferir `/health`, inclusive
   `revision`, `protocol:2`, `accounts:true` e `persistence:firestore`. Fazer uma
   verificação autenticada real antes de disponibilizar o APK.
4. Executar o workflow manual na branch/commit correto; baixar o artefato e extrair
   `app-release.apk`. Conferir versão/build e certificado contra o APK instalado.
5. Testar instalação por cima e preservação de progresso em aparelho real.
6. Criar release estável com tag `v<versão>`, anexar **o APK**, não o ZIP do Actions.
   Conferir se ela é `latest`, asset `uploaded` e digest presente antes de anunciar.
7. Testar a consulta a partir da versão anterior e a checagem manual na nova versão.

## Limitações / pendências

- As melhorias só alcançam celulares após instalar o próximo APK.
- Falha de consulta não bloqueia o Treino offline; não é mecanismo de revogação.
- Download/instalação dependem do plugin e do Android; falta teste real de rede
  interrompida, permissão negada, cancelamento e instalação por cima.
- Assinatura definitiva é o próximo bloco; cache de chave debug não é custódia.
- Versões de actions/Flutter ainda não estão fixadas por SHA/versão; alertas
  anteriores de dependências também permanecem pendentes.
- Não reverter banco nem versão de APK automaticamente. Rollback de servidor exige
  checar compatibilidade de protocolo e schema; APK corretivo deve ter build maior.
