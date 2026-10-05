# Conta recuperável — checkpoint local

## Implementação

- Login/cadastro por e-mail e senha, confirmação do endereço, recuperação e logout.
- Firebase Authentication via REST oficial; senhas não passam pelo Render.
- Refresh token no armazenamento protegido da plataforma, ID token só em memória.
  Renovação é compartilhada entre requisições concorrentes; logout não permite
  que uma renovação pendente restaure a sessão.
- Backend verifica assinatura, validade e projeto com Firebase Admin, exige
  provedor password/e-mail confirmado e nunca aceita um UID informado pelo app.
- `elementosAccounts/{uid}` associa nome e hash da identidade. Vínculo com sessão
  antiga é transacional, prova posse pelo perfil/sala e tem exclusividade em
  `elementosIdentityClaims`. Nenhuma cópia/substituição de progresso na migração.
- Após vínculo, a credencial de instalação deixa de autenticar. Conta existente
  não é mesclada/sobrescrita por outro perfil. Não há vinculação automática no login.
- Última sala local separada por conta. Em outro aparelho, entre com o mesmo e-mail;
  para uma sala ainda ativa, informe seu código dentro do prazo de abandono.
- Treino/Dungeon não são sincronizados por este bloco. Os saves não foram alterados.

## Ativação e validação

1. No projeto Firebase `elements-1173d`, ativar Authentication → E-mail/senha.
   Manter login por link/SMS/serviços pagos desativados. Confirmar plano gratuito.
   E-mail/senha confirmado ativo em 05/10/2026.
2. Obter a Web API Key desse mesmo projeto. É configuração pública de cliente,
   **não** a chave privada/JSON da conta de serviço do Render.
3. Configurar a variável de repositório `FIREBASE_API_KEY` no GitHub. Workflow
   existente passa `--dart-define=FIREBASE_API_KEY=...` e recusa build sem a chave.
   Localmente, fornecer o mesmo dart-define ao executar/buildar o app.
   Variável configurada em 05/10/2026, reutilizando a chave de cliente existente.
4. Publicar backend e app coordenadamente quando autorizado. `/health` deve mostrar
   `accounts: true` e `persistence: firestore`. App não confunde backend antigo
   sem `/account` com um perfil novo. Backend 7c509f3 publicado em 05/10/2026:
   health confirmou ambos os campos; `/account` sem credencial respondeu 401.
5. Em aparelho de teste: cadastro → e-mail confirmado → vincular o nome antigo →
   terminar partida → sair → entrar em outro aparelho → conferir progresso;
   recuperar senha, entrar novamente e reconectar sala com código.

## Limites e cuidados

- Uma conta recebe o nome escolhido; não há fusão de diferentes nomes/perfis.
  Se usou vários nomes online na mesma instalação, revisar a migração antes de
  vinculá-la: o token antigo é aposentado para a instalação inteira. Documentos
  antigos não são apagados. Não desinstalar/apagar dados antes de vincular.
- Partida em andamento continua em `elementosMatches`; progresso de perfil só é
  salvo no encerramento, como antes. Não foi implementado backup nem autosave novo.
- Verificação de ID token usa a validação padrão do Admin SDK, **sem** consulta
  de revogação a cada poll. Token já emitido pode durar até sua expiração (~1 h)
  após revogação/reset. Logout é local, não encerra todos os aparelhos.
- Contas em cache por 30 s; legacy não vinculado ainda aceito na transição, com
  consulta de claim no Firestore. Não há plano pago ou serviço adicional ativado.
- Regras Firestore continuam negando acesso direto de apps; somente backend Admin.
- Exclusões de backup Android atingem apenas dados/chaves da sessão criptografada,
  não os saves offline. Isso evita restaurar token cifrado sem a chave do aparelho.
- Dependência nova: flutter_secure_storage 10.3.4. `pub get` baixou e resolveu as
  dependências, mas avisou sobre symlinks/Developer Mode no Windows. Testes Dart/
  Flutter locais funcionaram; build Android concluído no Actions 37323904719 em
  05/10/2026. Nenhuma configuração de segurança do Windows foi alterada.

## Verificação local

Testes com Firebase/HTTP/secure storage simulados: vínculo, prova de posse,
isolamento, e-mail não confirmado, replay, senha não persistida, refresh/logout,
recuperação, layout com teclado nas duas orientações; regressão de abandono.
Não equivalem a teste real Firebase/Android nem auditoria de segurança.

Referências: [Firebase Auth REST](https://firebase.google.com/docs/reference/rest/auth),
[validação de tokens](https://firebase.google.com/docs/auth/admin/verify-id-tokens),
[sessões e revogação](https://firebase.google.com/docs/auth/admin/manage-sessions),
[backup Android](https://developer.android.com/identity/data/autobackup).
