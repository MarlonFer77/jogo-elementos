# Registro e aventura por ID

Incluído na v0.40.0, publicada em 20/10/2026. Validação física ainda pendente.

## Entrada

Correção posterior à v0.41.0 (ainda não publicada): login/cadastro pertencem ao
aplicativo inteiro, antes do menu, e não ao BETA. `AppAccountGate` restaura uma
única sessão e `AccountLoginScreen` permite criar/recuperar conta e confirmar o
e-mail. O UID vem do Firebase, nunca de um campo editável. Contas existentes
continuam válidas. Esse fluxo não cria salas nem depende do Render.

Treino, Dungeon, batalha 2D, Multiplayer, loja e BETA ficam no mesmo menu.
“Minha conta” centraliza ID e saída; o Multiplayer e o BETA recebem a mesma
instância de sessão. Sair remove as rotas abertas, sem apagar progresso.
O BETA mantém apenas a senha de testador, continuar/nova aventura e checkpoints.
Recuperação de senha e reenvio de confirmação continuam disponíveis na entrada
global. Nenhuma senha da conta é salva no aparelho.

Após a primeira confirmação online, a sessão guardada em armazenamento seguro
permite jogar offline. Trocar conta mantém saves separados por UID e não migra
progresso automaticamente. A senha de testador continua sendo apenas uma trava
local, não autenticação nem autorização de operações no servidor.

## Checkpoints

- Início de cada região: reinicia o encontro inteiro ao continuar, com XP,
  vida, mana e build daquele ponto. Não preserva mortes/XP parciais da luta.
- Ao vencer o combate: mantém os inimigos eliminados e as recompensas.
  Se a queimadura restante for fatal, mantém o checkpoint seguro anterior para
  não prender o jogador em um ciclo de mortes ao retomar.
- Cada passo/pista do puzzle e alteração de build fora do combate são guardados.
- Pausa fora do combate atualiza o checkpoint; status e durações são preservados.
- Retomada sempre pausada; sem comandos presos, projéteis ou ataques em execução.
- Morte permite tentar novamente do checkpoint. Vitória conserva a conclusão.
- Nova aventura pede confirmação e substitui o save da conta; loja não é apagada.

Preserva região, nível/XP, PH/habilidades, combos descobertos/equipados, puzzles,
pistas, restauração visual, posição fora do combate, vida/mana e estados duráveis.
Não é um save frame a frame: sair durante a luta volta ao início dela.

## Armazenamento e limites

`beta.adventure.v1.<UID em base64url>` é local, com envelope versionado/UID e
RecoverablePreferences. Validação rejeita números fora dos limites, builds
inconsistentes e puzzles incompatíveis com a região. Cópia anterior permite
recuperação de corrupção; sem cópia válida, preserva dados e bloqueia sobrescrita.
Versão futura também bloqueia escrita. Falhas são exibidas; sair exige confirmação
da gravação. Checkpoints são serializados, sem gravar a cada frame.

Não sincroniza com Firestore nem protege contra adulteração do aparelho. Não
usar esses dados como autoridade para economia online. Desinstalar/limpar dados
pode perder a aventura; entrar em outro aparelho ainda não a recupera.
A coleção da loja permanece compartilhada/local, como antes deste bloco.
Treino, Dungeon, multiplayer e seus formatos de save não são alterados.
Conta global não significa sincronização automática: progresso local legado
permanece no aparelho, sem migração ou transferência entre contas neste bloco.

## Verificação

Testes direcionados passaram para cadastro em 320×568 e 568×320, confirmação
de senha/e-mail, UID retornado pelo Firebase (respostas simuladas), identidade
offline, logout durante confirmação, contas isoladas, corrupção/versões futuras,
rollback sem XP duplicado, puzzles/restauração, combate e falha/retry ao salvar.
Entrada pelo menu e cancelamento de nova aventura também conferidos.
Análise estática limpa. Cadastro real, encerramento/reabertura do processo e
instalação por atualização ainda precisam de validação física no próximo APK.
