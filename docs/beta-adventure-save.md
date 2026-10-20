# Registro e aventura por ID

Implementação preparada para a v0.40.0; publicação acompanhada em TASKS.md.

## Entrada

O BETA reutiliza Firebase Auth e a tela de conta existente: criar conta com
e-mail, senha e confirmação; confirmar o e-mail; continuar. O UID vem do Firebase,
nunca de um campo editável. Contas Multiplayer existentes usam o mesmo ID.
Esse fluxo não cria salas nem depende do Render. Recuperação de senha e reenvio
da confirmação continuam disponíveis. Nenhuma senha é salva no aparelho.

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
Treino, Dungeon, multiplayer e seus saves não são alterados.

## Verificação

Testes direcionados passaram para cadastro em 320×568 e 568×320, confirmação
de senha/e-mail, UID retornado pelo Firebase (respostas simuladas), identidade
offline, logout durante confirmação, contas isoladas, corrupção/versões futuras,
rollback sem XP duplicado, puzzles/restauração, combate e falha/retry ao salvar.
Entrada pelo menu e cancelamento de nova aventura também conferidos.
Análise estática limpa. Cadastro real, encerramento/reabertura do processo e
instalação por atualização ainda precisam de validação física no próximo APK.
