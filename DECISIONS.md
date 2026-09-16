# DECISIONS.md

## DECISION-051
Data: 2026-09-16
Decisão: diferenciar visualmente a preparação inicial do Treino da batalha.
ElementStarterScreen reutiliza os comandos emoldurados da interface portátil,
com etapa/jogador atual, trilha Jogador A → Jogador B → Batalha, contador de
seleção e explicação dos dois elementos iniciais versus quatro equipáveis.
Confirmar A passa a se chamar Preparar Jogador B; a última escolha usa Entrar
na batalha. Mantidos os desbloqueios e a persistência existentes: jogadores
com progresso salvo não precisam escolher novamente. Sem reset de dados.

No Treino, a orientação horizontal usa campo à esquerda e comandos à direita;
a vertical mantém campo acima. Layout considera a área segura, inclusive
celulares baixos com recorte lateral. Turno, abas, AP e confirmação ficam
fora da rolagem de ações. A preparação também distribui introdução e seleção
lado a lado na horizontal. Janelas de seleção respeitam as áreas seguras.

A árvore de widgets da arena permanece estável ao girar para preservar a
instância do Flame e não repetir ataques. A sequência visual atualiza suas
posições quando a arena muda de tamanho, sem reiniciar seu tempo. Nenhuma
regra de combate, engine, backend ou esquema de persistência foi alterado.
Multiplayer mantém sua interface atual; o ajuste de posições de efeitos no
componente compartilhado também respeita o redimensionamento nesse modo.

Testes cobrem preparação A/B, limite e troca de seleção, persistência/reabertura,
320×568, 360×740, 568×320 e 740×360, barras/recortes, seleção e ataque durante
rotação (mesma instância Flame, um único turno/dano), e janelas auxiliares.
Preview web usado para inspeção visual; validação em aparelho Android físico
permanece necessária após gerar o próximo APK.

Validação final: 237 testes do app aprovados, incluindo regressões do
Multiplayer, atualização e persistência; flutter analyze sem problemas.

## DECISION-050
Data: 2026-09-15
Decisão: a pedido do usuário após testar a v0.16.0, refazer o painel de
batalha do Treino com inspiração nos RPGs portáteis/Game Boy. A arena e o
HUD ficam fora da rolagem; somente a área de comandos pode rolar em telas
pequenas. Elementos em grade 2×2, Habilidades em três slots mais comando
Trocar. Selecionar não consome turno: confirmação executa com a arena
visível. Durante animação, caixa de mensagem informa quem usou a ação;
ao terminar, aparecem os comandos do próximo jogador. Resumo de
descobertas/último combo fica no botão de informação; Skill Tree se chama
Árvore para não confundir com Habilidades (combos).

Cada jogador equipa até quatro elementos desbloqueados. TrainingMatch
valida limite, duplicatas, IDs inválidos e uso de elemento fora dos slots;
ataques básicos e experimentação usam esses quatro. Habilidades aprendidas
equipadas têm receitas independentes dos slots básicos, mas continuam
exigindo os elementos desbloqueados e AP suficiente. Isso permite trocar
básicos sem perder acesso a uma habilidade aprendida. Novo elemento ocupa
uma vaga livre automaticamente; acima de quatro fica disponível para troca.
Escolha inicial de dois elementos e progressão permanecem.

SharedPreferences ganha training_elements_equipped_a/b. Saves sem a chave
recebem até quatro elementos já desbloqueados; IDs desconhecidos/duplicados
são filtrados e uma lista sem elementos válidos recebe fallback. Progresso,
descobertas, habilidades e contagem de turnos não são apagados. Trocas são
salvas e preservadas ao iniciar outra partida. Cancelar a experimentação
não modifica a seleção anterior. AttacksScreen é reutilizada em janela
inferior; os três slots e o fluxo de substituição permanecem.

BattleSceneWidget aceita altura opcional (260 por padrão para manter o
Multiplayer); BattleSceneGame reposiciona sprites ao redimensionar a cena.
Correção descoberta na inspeção visual em 360×640. Nenhuma nova regra no
motor, protocolo de rede ou atualização Android. O Multiplayer mantém seu
fluxo existente até implementar equipamentos autoritativos no servidor.

Validação: suíte completa do app com 229 testes passou. Novos testes cobrem
quatro slots, validação, migração/armazenamento, independência entre elementos
e habilidades, desbloqueio com vagas, cancelamento e arena fixa em 360×640,
320×568 e 740×360. Preview web compilado e inspecionado em tamanho de celular,
com onboarding, persistência da escolha e ataque básico real. O servidor de
debug do SDK apresentou falha própria no DWDS; build web funcionou.


## DECISION-049
Data: 2026-09-15
Decisão: Bloco 2d — ataques equipados durante a batalha do Treino,
aprovado pelo usuário após apresentação do escopo. TrainingMatch expõe
ataques do jogador da vez, disponibilidade e playEquippedAttack(id).
A execução resolve os elementos do catálogo e usa playElementIds,
preservando AP, mutações, dano, status, descobertas e progressão existentes.
Rejeita partida encerrada, ID inexistente, ataque não equipado, elemento
bloqueado e AP insuficiente antes de alterar o estado.

EquippedAttackPanel mostra três slots, custo, elementos, descrição na
seleção e confirmação. Slots vazios convidam à descoberta; ataques
indisponíveis permitem consultar detalhes, mas não executar. TrainingScreen
mantém básicos gratuitos e o seletor de combinação livre. O AP informado
para agir inclui +1 da regeneração já feita por TurnEngine, limitado ao
máximo, evitando divergência entre o botão e a regra de execução.

AttackSequencePlayer notifica conclusão uma única vez; BattleSceneGame e
BattleSceneWidget repassam callback opcional. Treino bloqueia comandos até
essa conclusão e produz AttackEvent também para básicos. Novas partidas
limpam seleção e feedback antigo. O multiplayer continua usando os mesmos
componentes sem exigir callback nem introduzir loadout apenas no cliente.
Não houve mudança no Battle Engine, backend, esquema de persistência ou
atualização Android. Ajustes pequenos de quebra de texto no HUD e nos
botões compartilhados corrigem overflow detectado em tela de 360 px.

Verificação: suíte completa inicial do app com 217 testes passou;
posteriormente, os dois novos testes de tela e 30 testes de regressão de
Treino, HUD, botões e Multiplayer passaram após o ajuste de layout.
Battle Engine: 213 testes passaram. Backend: npm test passou.
Testes novos cobrem execução, AP com regeneração, toque duplicado,
animação real, troca dos slots, equipamento persistido e ações inválidas.
Validação da interface automatizada; não foi realizada sessão manual no
Android nem publicação de APK neste bloco.


Somente decisões arquiteturais ou de design relevantes. Não é histórico de commits.

## DECISION-001
Data: 2026-09-02
Decisão: Battle Engine vive em `packages/battle_engine` como pacote Dart puro,
separado do app Flutter, sem depender de Flutter ou Flame.
Motivo: a lógica de batalha precisa ser testável isoladamente (`dart test`) e
não pode depender de renderização, conforme exigência do projeto.
Consequência: o app Flutter consome `battle_engine` como path dependency. Qualquer
código que precise de `flutter:` no pubspec não pode entrar nesse pacote.

## DECISION-002
Data: 2026-09-02
Decisão: Elementos e combinações são tratados como dados (data-driven), não como
regras condicionais hardcoded no código.
Motivo: permitir adicionar novos elementos/combinações e permitir que builds
modifiquem o resultado de uma combinação sem reescrever lógica central.
Consequência: `Element` e `ElementCombination` carregam dados; a resolução de
efeito é uma função pura que consulta esses dados, com ponto de extensão futuro
para modificadores de build.

## DECISION-003
Data: 2026-09-02
Decisão: Backend é a autoridade sobre todo resultado crítico do multiplayer
(dano, vitória, derrota, recompensa, XP, recursos, resultado final).
Motivo: impedir que o cliente manipule resultados de partida.
Consequência: o Battle Engine roda no cliente para simulação/preview local e
offline, mas qualquer resultado multiplayer precisa ser validado/recalculado
pelo backend antes de ser aceito como definitivo.

## DECISION-004
Data: 2026-09-02
Decisão: no `TurnEngine` atual, uma ação de turno é diretamente "jogar 1 a 3
elementos" — não existe ainda um conceito de habilidade/skill separado dos
elementos. 2–3 elementos tentam resolver uma combinação; 1 elemento nunca
resolve combinação (sem efeito por enquanto).
Motivo: entregar o motor de turnos de forma testável sem antecipar o sistema
de Habilidades (BACKLOG), que ainda não foi desenhado.
Consequência: quando o sistema de Habilidades for implementado, ele provavelmente
vai envolver/substituir `TurnAction` (uma habilidade pode determinar quais
elementos são jogados, ou adicionar efeitos além da combinação). Isso é um
ponto de atenção para a tarefa de Habilidades, não uma limitação definitiva.

## DECISION-005
Data: 2026-09-02
Decisão: estados (`StatusEffect`/`ActiveStatus`) são aplicados por combatente
(`BattleState.combatantStatuses`). `AreaEffect` existe como um `StatusEffect`
nomeado, mas não está conectado a `activeFieldEffects` (que hoje guarda
`ElementCombination`s resolvidas no campo).
Motivo: os dois conceitos (estado por combatente vs. efeito de área/campo)
ainda não têm um consumidor real — implementar a integração agora seria
adivinhar o formato antes da hora.
Consequência: quando um efeito de área precisar existir de fato (ex: uma
combinação que aplica dano em área a cada turno), será necessário decidir se
`AreaEffect` vira um tipo próprio de efeito de campo ou se combinações passam
a poder aplicar `ActiveStatus` a ambos os combatentes.

## DECISION-006
Data: 2026-09-02
Decisão: extraído `FieldEffect` (id/nome/descrição) como o formato comum de
"efeito ativo no campo". `ElementCombination` ganhou o getter `.result` que
expõe seus dados como `FieldEffect`; `BattleState.activeFieldEffects` passou
de `List<ElementCombination>` para `List<FieldEffect>`.
Motivo: a mutação "Incêndio" (habilidade cria área de fogo) precisava colocar
algo no campo sem ser uma combinação de elementos de 2–3 — forçar isso dentro
de `ElementCombination` seria semanticamente errado (aquela classe é
especificamente "N elementos → efeito"). Duplicar um segundo tipo "efeito de
campo" ao lado de `ElementCombination.resultId/resultName/description`
também seria duplicação real, não apenas parecida.
Consequência: `ElementCombination` e seus testes ficaram intactos (campos
antigos preservados); só `BattleState`/`TurnEngine` e os testes que inspecionam
`activeFieldEffects` mudaram de `.resultId` para `.id`.

## DECISION-007
Data: 2026-09-02
Decisão: `Mutation.apply` é uma função (`AbilityEffect Function(AbilityEffect)`)
guardada na instância, não uma struct de dados interpretada por um switch
central no `AbilityEngine`.
Motivo: seguir o mesmo princípio de DECISION-002 (novas mutações sem alterar
o resolver) da forma mais direta em Dart — sem um interpretador de regras
declarativas, que seria overengineering para 4 mutações de exemplo.
Consequência: `Mutation` não é serializável como JSON puro por enquanto. Se
mutações precisarem ser definidas fora do código (ex: editor de conteúdo,
dados vindos do backend), será necessário revisitar essa decisão.

## DECISION-008
Data: 2026-09-02
Decisão: cada `SkillNode` concede exatamente uma `Mutation` já existente
(sistema implementado na tarefa anterior). Não implementei nós que alteram
diretamente `CombinationBook`, permitem combinações de 3 elementos, convertem
estados (`Wet` → `Shock`) ou alteram área/duração de um `FieldEffect`.
Motivo: `Mutation`/`AbilityEffect` já cobrem boa parte dos exemplos do design
("modificar habilidades", indiretamente "transformar dano" via hitCount/crit).
Os outros exemplos (alterar combinações, permitir 3 elementos, converter
estados, alterar área) não têm ainda um ponto de extensão real no motor —
inventar um agora seria adivinhar a forma antes de "Ponto de extensão: build
modificando resultado de uma combinação" (NEXT) existir.
Consequência: a Skill Tree está pronta para builds reais dentro do que já é
suportado (aplicar status, criar campo, hitCount, crit). Os outros tipos de
nó ficam bloqueados até o ponto de extensão de combinação (e, se necessário,
um mecanismo de conversão de estados) serem desenhados.

## DECISION-009
Data: 2026-09-02
Decisão: `SkillNode.grants` deixou de ser `Mutation` e passou a ser
`SkillGrant`, uma interface mínima (`String get id`) que `Mutation` e o novo
`CombinationModifier` implementam. `SkillProgress` filtra por tipo
(`grant is Mutation` / `grant is CombinationModifier`) para expor
`grantedMutations` e `grantedCombinationModifiers` separadamente.
Motivo: a tarefa "Ponto de extensão: build modificando combinação" exigia
que um nó da Skill Tree pudesse conceder algo diferente de uma `Mutation`
(agora um `CombinationModifier`). Um sealed type completo ou um sistema de
"grant kind" com enum pareceu overengineering para 2 variantes; a interface
`SkillGrant` é o mínimo que faz `SkillNode`/`SkillTree` não precisarem saber
qual tipo de grant estão carregando.
Consequência: `defaultSkillTree` ganhou uma 3ª branch ("elemental") só para
os `CombinationModifier`s de exemplo. Um terceiro tipo de grant no futuro
(ex: algo que converte estados — ver DECISION-005) só precisa implementar
`SkillGrant` e ganhar um `grantedX` correspondente em `SkillProgress`; não
exige alterar `SkillNode`/`SkillTree`.

## DECISION-010
Data: 2026-09-02
Decisão: `flutter create` do `app/` usou `--platforms=web,windows`, não o
padrão (android, ios, web, windows, macos, linux).
Motivo: esta máquina não tem Android SDK nem Visual Studio com o workload
C++ (`flutter doctor` confirmou) — gerar plataformas sem toolchain só cria
arquivos que não buildam e não são verificáveis agora. Web (Chrome/Edge) foi
o alvo usado para rodar e conferir o app de verdade nesta tarefa.
Consequência: quando o ambiente tiver Android Studio/Visual Studio
instalados, rodar `flutter create --platforms=android,ios .` (ou os que
faltarem) dentro de `app/` adiciona as plataformas sem afetar o código Dart
existente. Isso deve acontecer antes de qualquer tarefa que dependa de rodar
em device/emulador mobile de verdade.

## DECISION-011
Data: 2026-09-02
Decisão: código de UI (`app/lib/ui/`) nunca importa `package:battle_engine`
diretamente — mesmo quando o dado é trivial (ex: `Elements.all`), passa por
uma classe da camada Game Domain (`app/lib/game_domain/`), como
`ElementCatalog`.
Motivo: CLAUDE.md/ARCHITECTURE.md exigem a separação
UI → Game Presentation → Game Domain → Battle Engine desde o início do
projeto (seção 4 do prompt original). Não é uma abstração especulativa —
é a regra de camadas já declarada, aplicada à primeira tela.
Consequência: toda tela nova precisa de uma classe/função correspondente em
`game_domain` para os dados que ela usa, mesmo que essa classe comece como
um wrapper fino. O wrapper cresce (orquestra partida, valida com backend,
etc.) conforme as tarefas futuras (batalha, skill tree, builds) exigirem.

## DECISION-012
Data: 2026-09-03
Decisão: `DemoBattle.start()` (em `game_domain`) roda uma batalha fixa e
hardcoded (Ana joga Fogo+Vento contra Beto) só para o `BattleGame` (Flame)
ter um `BattleView` real para desenhar. Não é orquestração de partida de
verdade — não cria/entra em partida, não aceita ação do jogador.
Motivo: a tarefa era "integração com o Flame" (a tecnologia de renderização),
não "sistema de batalha jogável". Orquestração real de partida (criar/entrar,
turno do jogador humano, multiplayer) é escopo de tarefas futuras (Multiplayer,
Modo treino).
Consequência: `DemoBattle`/`BattleScreen` devem ser substituídos, não
estendidos, quando a orquestração real existir — não é a base para o menu de
batalha final. Nos testes de widget Flutter que envolvem uma tela com
`GameWidget`, usar `tester.pump()` com duração fixa em vez de
`tester.pumpAndSettle()` — o game loop do Flame agenda frames continuamente,
então `pumpAndSettle` nunca "assenta" e estoura timeout.

## DECISION-013
Data: 2026-09-03
Problema: as regras de batalha (elementos, combinações, turnos, habilidades,
skill tree, builds) existem só em `packages/battle_engine`, que é Dart. O
backend é Node.js/TypeScript (stack definida no CLAUDE.md) e precisa validar
essas mesmas regras para não confiar no cliente (seção 4 do briefing
original). Não existe hoje uma forma de o Node chamar código Dart
diretamente.
Impacto: a próxima tarefa ("Validação de ações críticas no backend") não é
só "escrever validação" — primeiro precisa decidir COMO o servidor conhece
as mesmas regras que o cliente usa. Sem decidir isso, o risco é reimplementar
tudo em TypeScript sem perceber que é uma duplicação deliberada, ou pior,
duplicar por acidente com um envelhecimento silencioso de umas das duas
implementações (RA: 3.4 — balanceamento mudado num lado só).
Solução recomendada: duplicação deliberada e explícita, mas mínima —
reimplementar em TypeScript só o subconjunto necessário para validar cada
ação crítica (ex: dado um `TurnAction`, o resultado teria que bater com o
que o cliente reportou), não o motor inteiro (sem Skill Tree/builds no
servidor por enquanto, já que isso não é "resultado final" nem "recurso").
Manter os dados de conteúdo (ids/nomes de elementos e combinações) como a
fonte da verdade sendo o Dart, copiados manualmente para o TS até haver
necessidade real de um formato compartilhado.
Alternativas consideradas:
1. Rodar Dart no servidor (`dart:io` tem HTTP server) — rejeitada: contradiz
   a stack definida explicitamente no CLAUDE.md (Node.js + TypeScript).
2. Compilar `battle_engine` para JS (`dart compile js`) e importar no Node —
   tecnicamente possível, mas incomum e frágil para este projeto (toolchain
   de build cruzado, sem precedente testado aqui); reavaliar só se a
   duplicação em TS virar dor real.
3. Servidor validar só invariantes estruturais (é a vez certa? elementos
   existem? ids conhecidos?) e confiar no resultado que os dois clientes
   calcularam e concordaram (lockstep determinístico) — mais barato, mas
   enfraquece a garantia "nunca confiar no cliente" da seção 4; só cogitar
   se a duplicação em TS se mostrar inviável de manter.
Consequência: ao iniciar "Validação de ações críticas no backend", a
primeira decisão de implementação é montar o subconjunto de regras em TS
(começando por `TurnEngine.playTurn`, que é o menor núcleo), não pular
direto para escrever endpoints.

## DECISION-014
Data: 2026-09-03
Decisão: implementada a solução recomendada da DECISION-013. O que foi
duplicado manualmente em `backend/src/battle-rules/`, e o que ficou de fora:
- Duplicado: `Element` (só o id, sem nome/símbolo), `ElementCombination` →
  `CombinationBook.resolve`, `defaultCombinationBook` (as mesmas 3
  combinações de `default_combinations.dart`), `BattleState` (só
  playerAId/playerBId/currentTurnId/activeFieldEffects — sem
  `combatantStatuses`), `opponentOf`, `TurnEngine.playTurn`.
  `FieldEffect` no TS não tem `name`/`description` — só `id`/`area`/
  `duration` — porque o cliente já tem o texto pelo próprio catálogo; o
  servidor só precisa saber "qual" e "quanto", não "como mostrar".
- Não duplicado (de propósito): `StatusEffect`/`ActiveStatus`, `Ability`/
  `Mutation`/`AbilityEngine`, `SkillTree`/`SkillProgress`/`Build`,
  `CombinationModifier`. O servidor hoje só valida a ação de turno mais
  básica (jogar elementos → combinação → passar o turno); habilidades e
  builds não são "resultado final" no sentido da seção 4 (dano, vitória,
  XP, recursos) — ainda não existe sistema de dano/HP nem no Dart.
Motivo: minimizar a superfície duplicada, conforme recomendado.
Consequência (risco aceito): não existe verificação automática de que as 3
combinações do TS continuam batendo com as do Dart — é sincronização
manual. Se `default_combinations.dart` mudar (novo id, nova combinação,
resultId renomeado), `backend/src/battle-rules/combination-book.ts`
precisa ser atualizado manualmente no mesmo PR/tarefa. Isso deve ser
lembrado toda vez que uma tarefa mexer em `packages/battle_engine/lib/src/
default_combinations.dart` ou em `ElementCombination`/`FieldEffect`.

## DECISION-015
Data: 2026-09-03
Decisão: `firebase/.firebaserc` usa um project id "demo" (`demo-jogo-elementos`)
em vez de um projeto real do Firebase. Nenhum projeto real foi criado.
Motivo: o usuário pediu explicitamente free tier sem cadastrar cartão. Criar
um projeto real do Firebase exige login numa conta Google — não é algo que
eu possa fazer (não tenho as credenciais do usuário, e mesmo se tivesse,
digitar credenciais é uma ação proibida). O Firebase Emulator Suite trata
qualquer project id prefixado com "demo-" como projeto falso: roda os
emuladores 100% local, sem internet, sem login, sem possibilidade de gerar
cobrança — exatamente o que a regra de custo do CLAUDE.md pede para
desenvolvimento.
Consequência: quando o usuário quiser um ambiente de nuvem de verdade (não
só emuladores locais), ele mesmo precisa: 1) criar o projeto em
console.firebase.google.com (plano Spark/gratuito não pede cartão), 2) rodar
`firebase login` no terminal dele (abre o navegador para autenticar), 3)
`firebase use --add` dentro de `firebase/` apontando pro project id real.
Nada disso foi feito.

Problema encontrado (não é decisão, é limitação do ambiente): o emulador do
Firestore precisa de Java 21+; instalado via choco (Temurin 21) a pedido do
usuário. Mesmo assim, o JVM falha ao iniciar com
`java.io.IOException: Unable to establish loopback connection` — um erro
conhecido do JDK 21+ no Windows relacionado a sockets Unix domain internos
(usados pelo novo `WEPollSelectorProvider`). Tentei: `-Djava.net.preferIPv4Stack`,
`-Djdk.net.useFastTcpLoopback`, forçar `WindowsSelectorProvider` explicitamente,
rodar via Bash e via PowerShell nativo, e com o sandbox de execução
desabilitado — todas as tentativas falharam de forma idêntica, o que indica
uma restrição de rede da própria máquina/VM, não do meu sandbox de execução
nem da configuração do Firebase. Os arquivos de config (`firebase.json`,
`.firebaserc`, `firestore.rules`, `firestore.indexes.json`) foram validados
como JSON/sintaxe corretos e seguem o formato padrão documentado do Firebase,
mas `npm run emulators` não pôde ser confirmado rodando de verdade nesta
máquina. Se o usuário rodar em outra máquina (sem essa restrição de rede),
`cd firebase && npm run emulators` deve simplesmente funcionar.

## DECISION-016
Data: 2026-09-03
Decisão: o multiplayer (`backend/src/matches/`) guarda partidas em memória
(`Map` dentro de `MatchStore`), não no Firestore. Reconexão é por polling
(`GET /matches/:id`), não push em tempo real. Identidade de jogador é só
uma string (`playerAId`/`playerBId`) que o cliente manda, sem autenticação.
Motivo:
1. Persistência real no Firestore está bloqueada por DECISION-015 — não
   existe projeto real do Firebase (exige login do usuário) nem o emulador
   pôde ser verificado rodando nesta máquina. Implementar contra o Firestore
   agora seria código não verificável.
2. Push em tempo real (WebSocket/SSE) não foi pedido em nenhuma tarefa
   ainda — a seção 11 do briefing descreve o fluxo (criar → entrar → ação →
   valida → ação → valida → resultado → próximo turno), que funciona por
   polling; tempo real é uma melhoria de UX, não um requisito funcional
   declarado.
3. Não existe sistema de contas/login em lugar nenhum do projeto (nem
   Flutter, nem backend). Autenticação de verdade é um projeto à parte
   (provavelmente Firebase Auth, quando um projeto real existir) — inventar
   uma solução ad-hoc agora seria decidir uma arquitetura de auth sem ter
   sido pedida.
Consequência: partidas somem se o servidor reiniciar (sem persistência) e
não há garantia de que "ana" é realmente a mesma pessoa em todas as
requisições (sem auth) — aceitável para o escopo atual ("dois amigos",
sem contas), mas **não é uma base segura para produção real**. Cada
uma dessas três limitações tem um caminho claro pra virar tarefa futura
quando for necessário: persistência → Firestore (depende de DECISION-015
ser resolvida), tempo real → WebSocket/SSE endpoint adicional, autenticação
→ Firebase Auth + regras de segurança reais no Firestore (hoje
`firestore.rules` nega tudo, de propósito).

## DECISION-017
Data: 2026-09-03
Decisão: `ElementCatalog.all()` (app/lib/game_domain) passou a devolver
`List<ElementOption>` — um tipo próprio da Game Domain (id/nome/símbolo) —
em vez de `List<Element>` do `battle_engine`. `TrainingMatch` (também Game
Domain) só expõe `String`/`int` pro `TrainingScreen` (nomes, contagens),
nunca um `Combatant`/`BattleState`/`ElementCombination`.
Motivo: DECISION-011 disse "UI nunca importa battle_engine diretamente",
mas a `HomeScreen` original conseguia contornar isso na prática sem violar
a letra da regra — ela recebia `List<Element>` só via inferência de tipo
(`final elements = ...`), nunca escrevendo `Element` explicitamente, então
nunca precisou de `import`. Isso ia quebrar em `TrainingScreen`: guardar a
seleção do jogador como estado (`Set<String>` de ids funciona, mas guardar
os `Element` escolhidos exigiria escrever o tipo em algum lugar — campo de
State, parâmetro de função). Em vez de deixar essa pressão forçar um import
direto de `battle_engine` na UI, criei `ElementOption` pra fechar a
fronteira de verdade, não só na prática.
Consequência: toda tela nova que trabalha com elementos usa `ElementOption`
(já existe, reaproveitar). Se aparecer necessidade parecida pra
`FieldEffect`/`StatusEffect`/etc. na UI, o mesmo padrão se aplica — criar um
tipo de Game Domain equivalente em vez de expor o tipo do `battle_engine`.

## DECISION-018
Data: 2026-09-03
Decisão: no Modo Treino, cada jogador tem só **um** slot de ação — não um
conjunto de `Ability`s nomeadas e configuráveis individualmente. A cada
turno, `TrainingMatch.playElementIds` monta uma `Ability` nova a partir dos
elementos escolhidos naquele momento + **todas** as `Mutation`s que o
jogador já desbloqueou (não um subconjunto escolhido). Da mesma forma,
**todos** os `CombinationModifier`s desbloqueados sempre se aplicam.
Motivo: um editor de build de verdade (múltiplas habilidades nomeadas,
escolher quais mutações vão em qual habilidade) é uma tela própria — maior
escopo do que "integrar o que já existe no modo treino". A abordagem "um
slot, tudo que foi desbloqueado se aplica sempre" reaproveita 100% do motor
já testado (`Ability`/`Mutation`/`Build`/`AbilityEngine`) sem inventar
nenhuma regra nova, e ainda demonstra o que o design pede: dois jogadores
com os mesmos elementos e builds diferentes têm resultados diferentes.
Consequência: se/quando existir uma tela de "criar build" de verdade (fora
de escopo aqui), ela vai gerenciar múltiplas `Ability`s com mutações
escolhidas manualmente — `TrainingMatch` deve ser revisto nesse momento, não
estendido aos poucos. Também consequência: como toda mutação desbloqueada
se aplica sempre, um jogador que desbloqueia várias fica cada vez mais
forte a cada turno dentro da mesma partida — é o comportamento esperado
(mostra a progressão), não um bug.

## DECISION-019
Data: 2026-09-03
Decisão: sistema de dano/HP/vitória implementado seguindo o spec
conversado com o usuário (`docs/superpowers/specs/2026-09-03-damage-hp-
victory-design.md`) e o plano de implementação
(`docs/superpowers/plans/2026-09-03-damage-hp-victory.md`). Números finais:
HP base 100; combinação de 2 elementos causa 20 de dano, a de 3 (mais
difícil de formar) causa 35; Combustão causa 8 de dano por tick, 2 ticks
(16 no total, incluindo o tick que expira o estado); Escudo bloqueia o
próximo dano de combo inteiro e é consumido (não bloqueia dano de status);
nó "Treino de Vitalidade" concede +20 HP máximo. Empate simultâneo (os
dois chegam a 0 HP na mesma resolução) é decidido a favor de quem jogou o
turno — a ordem de tick de estados processa o oponente antes do ator
especificamente por causa disso.
Refinamento feito durante o planejamento (fora dos 3 blocos originalmente
conversados): `BattleState.start` ganhou `playerAMaxHp`/`playerBMaxHp`
**opcionais** com default 100 visível na assinatura, em vez de
obrigatórios sem default como decidido inicialmente — isso evitou editar
~32 testes existentes que não têm nada a ver com HP. Código de produção
(`TrainingMatch`) sempre passa o valor calculado explicitamente; nada
depende do default.
Motivo: dar às partidas um fim de verdade — até aqui, batalha nenhuma no
projeto (Dart, TypeScript ou Flutter) jamais terminava.
Consequência (lacuna conhecida, não esquecida): `backend/src/battle-rules/`
(o mirror em TypeScript, DECISION-013/014) **não** foi estendido — continua
validando só a resolução básica de turno (elementos → combinação → passa o
turno), sem dano, HP ou vitória. Isso é um pré-requisito real antes de
`POST /matches/:id/turns` do Multiplayer poder ser confiado pra validar o
resultado de uma partida de verdade (hoje ele só valida que a jogada é
estruturalmente válida). `hitCount`/`critChanceBonus` de `AbilityEffect`
continuam inertes — dar significado a eles interage com Escudo de um jeito
que ainda precisa ser desenhado (múltiplos hits furando o escudo, por
exemplo). Congelar/Silenciar/Lentidão/Buff/Debuff continuam sem
comportamento. "Artefatos" (mencionado pelo usuário como fonte futura de
bônus, junto com a Skill Tree) não foi implementado — `MaxHpBonus` serve de
modelo pra esse sistema entrar depois.

## DECISION-020
Data: 2026-09-04
Decisão: `backend/src/battle-rules/` (mirror TypeScript, DECISION-013/014)
foi estendido com o subconjunto de dano/HP/vitória da DECISION-019:
`FieldEffect.damage`, `defaultCombinationBook` com os mesmos números (20 nos
combos de 2 elementos, 35 no de 3), `HpPool`/`hp`/`winner` em `BattleState`
(default 100/100 por jogador, sem vencedor), `playTurn` aplicando o dano da
combinação ao oponente, definindo o vencedor na primeira derrota (nunca
desfazendo um já definido) e rejeitando jogar depois que `winner` já está
definido. `MatchStatus` ganhou `"finished"`; `MatchStore.applyTurn` marca o
match assim que `result.state.winner` é definido, e passa a rejeitar novas
jogadas (409) do mesmo jeito que uma partida ainda não iniciada. O endpoint
stateless `POST /battles/validate-turn` também aceita e devolve `hp`/`winner`
no corpo, pra não "resetar" o HP a cada chamada se o cliente os reenviar.
Escopo deliberadamente **não** estendido: nenhum status (Escudo, Queimadura/
DOT) foi portado — `TurnEngine.playTurn` no Dart usa Escudo pra bloquear
dano de combo e tickar dano de status por turno, mas ambos só existem no
jogo hoje através de Mutações/Skill Tree, que o backend nunca mirrorizou
(DECISION-013 já excluía isso explicitamente) e que o Multiplayer não expõe
na UI ainda (DECISION-019: "Multiplayer não está conectado ao app"). Portar
status/abilities/skill tree pro backend agora seria antecipar um sistema que
nenhuma tela ainda usa — overengineering pela regra de escopo do CLAUDE.md.
Motivo: fechar a lacuna registrada na DECISION-019 — o backend é quem deveria
ser a autoridade pra dano/vitória no Multiplayer (regra do CLAUDE.md), e até
aqui ele simplesmente não sabia que essas coisas existiam.
Consequência (lacuna conhecida, não esquecida): se/quando abilities ou Skill
Tree passarem a ser jogáveis via Multiplayer, o mirror do backend vai
precisar de Escudo e do tick de dano por status pra continuar sendo
confiável como autoridade — até lá, um jogador "escudado" no cliente ainda
tomaria o dano completo se essa jogada fosse validada pelo backend (não
acontece hoje porque nada no Multiplayer aplica status). Testes: 57
(`npm test` em `backend/`), `npm run typecheck` limpo.

## DECISION-021
Data: 2026-09-04
Decisão: Multiplayer conectado ao app Flutter — `MultiplayerLobbyScreen`
(criar partida / entrar com código) e `MultiplayerBattleScreen` (joga,
mostra HP dos dois lados, campo ativo, fim de partida), sobre
`MultiplayerClient` (`package:http`, injetável — testes usam
`http/testing.dart`, sem servidor real) + `MultiplayerMatch` (domínio: só
lê o que o backend decidiu, nunca calcula dano/turno). Identidade do
jogador é o nome digitado na tela (mesmo modelo sem-login da
DECISION-016). Reconexão/atualização é polling a cada 2s
(`Timer.periodic` no `State`, cancelado em `dispose`) — mesma limitação
"sem tempo real" já aceita pro backend (DECISION-016), agora também no
cliente.
Decisão adjacente, necessária pra conectar o app de verdade (não dava pra
testar em navegador sem ela): o backend passou a mandar CORS permissivo
(`Access-Control-Allow-Origin: *`, `OPTIONS` respondido 204 antes de
qualquer rota) — o app Flutter Web roda numa origem própria
(`localhost:5000`), diferente da do backend (`localhost:3000`), e o
navegador bloquearia toda chamada sem isso. `*` em vez de restringir a uma
origem porque não há conceito de "origem confiável" ainda (sem auth, sem
deploy real — ver DECISION-016) e a app não roda em nenhum domínio de
produção; reavaliar quando existir um.
Motivo: o objetivo original (seção 1 do briefing) é uma partida jogável
entre dois amigos — até aqui só existia como API HTTP, sem nenhuma tela.
Consequência (lacuna conhecida, não esquecida): sem persistência real
(`MatchStore` in-memory — DECISION-016), então a partida se perde se o
backend reiniciar; o app não avisa disso, só passaria a falhar as próximas
chamadas. Sem indicação visual de "jogada enviando"/erro de rede além do
texto de erro do backend. `CombinationCatalog` só resolve os 3 combos
hoje existentes — cresce junto de `default_combinations.dart`/
`defaultCombinationBook` (mesmo aviso de sincronia manual da
DECISION-013/014, mas para nomes de exibição, não regra de jogo). Testado
de ponta a ponta de verdade: backend (`npm run dev`) + app
(`flutter run -d web-server`) rodando ao mesmo tempo, duas abas do
navegador como jogadoras diferentes ("ana"/"beto") — criar, entrar,
Fogo+Vento (20 de dano, "Tempestade Ígnea" exibido), a outra aba
atualizando sozinha via polling. `flutter analyze` limpo, `flutter test`
verde (39 testes no app, incluindo os novos de `multiplayer_client`/
`multiplayer_match`/`multiplayer_lobby_screen`/`multiplayer_battle_screen`).

## DECISION-022
Data: 2026-09-04
Decisão: `MultiplayerLobbyScreen` ganhou um terceiro fluxo, "Reconectar"
(botão ao lado de "Entrar com código", mesmos campos de nome + código),
sobre um novo `MultiplayerMatch.reconnect(matchId)` que faz um `GET
/matches/:id` puro (não chama `join` — não muda quem é playerA/playerB no
servidor) e valida **localmente** se `localPlayerId` é `playerAId` ou
`playerBId` da partida buscada, lançando `MultiplayerException` se não for
— o backend não faz essa checagem sozinho num `GET` (rota é pública por
design, pra reconexão funcionar sem sessão).
Motivo: joguei uma partida de multiplayer de ponta a ponta (ver DECISION-
021) e descobri na prática que fechar/recarregar uma aba depois de criar
ou entrar numa partida deixava sem jeito nenhum de voltar pra ela — a tela
só sabia criar ou entrar (que falha com 409 pra quem já está na partida).
Precisei recriar a partida do zero pra terminar a demonstração. Isso é
esperado ficar ruim justamente pelo modelo "identidade = nome digitado,
sem conta" (DECISION-016) — não tem sessão nenhuma pra retomar sozinha, só
o nome + o código servem de "credencial".
Consequência (lacuna conhecida, não esquecida): a validação de
pertencimento é só no cliente — qualquer um que souber o código E o nome
de um dos dois jogadores consegue "reconectar" como esse jogador (mesma
falta de autenticação já aceita desde a DECISION-016, agora alcançável por
mais um caminho). Sem indicação na UI de "isso é uma reconexão, não uma
partida nova" além de já cair direto no estado real da partida.
Testado de ponta a ponta de verdade: joguei um turno real como "ana"
(dano aplicado, HP real da partida), fechei a aba do "beto" por completo,
abri uma aba nova do zero, digitei "beto" + o código, cliquei
"Reconectar" — voltou exatamente no HP/turno/campo reais da partida (não
resetou nada). `flutter analyze` limpo, `flutter test` verde (43 testes no
app, incluindo os 4 novos de reconexão em `multiplayer_match_test.dart`/
`multiplayer_lobby_screen_test.dart`).

## DECISION-023
Data: 2026-09-04
Decisão: botão "Revanche" na tela de fim de partida do Multiplayer
(`MultiplayerBattleScreen`), sobre `MultiplayerMatch.startRematch()`.
Como não existe (nem faz sentido existir) um "reset" no backend — uma
`Match` `finished` fica `finished` pra sempre, é o registro de um
resultado — Revanche é simplesmente `create()` de novo: uma partida nova,
`waiting_for_opponent`, com o mesmo jogador como playerA, código novo.
`startRematch` devolve uma instância separada de `MultiplayerMatch` (não
muta a atual, que continua apontando pra partida finalizada) e a tela
navega até ela via `pushReplacement`. O código novo precisa ser
compartilhado com o amigo de novo — mesmo modelo sem matchmaking do
resto do Multiplayer (ver seção Multiplayer em ARCHITECTURE.md).
Motivo: pedido explícito do usuário depois de jogar partidas de
multiplayer de ponta a ponta nesta sessão — sem isso, "jogar de novo"
significava sair até a `MultiplayerLobbyScreen` e preencher tudo de novo.
Consequência (lacuna conhecida, não esquecida): se os dois jogadores
clicarem "Revanche" ao mesmo tempo, cada um cria sua própria partida nova
(não ficam ligadas) — só um dos dois deveria clicar, e o outro entra com
o código novo, exatamente como na primeira partida. A tela não avisa isso
explicitamente, só mostra "Cria uma partida nova — compartilhe o código
com seu oponente de novo." como dica.
Testado de ponta a ponta de verdade: joguei uma partida real até o fim
(Ana venceu), cliquei "Revanche", confirmei por `GET` direto no backend
que a partida antiga continuou `finished` intacta e a nova nasceu
`waiting_for_opponent` com um código diferente. `flutter analyze` limpo,
`flutter test` verde (45 testes no app).

## DECISION-024
Data: 2026-09-04
Decisão: `backend/src/battle-rules/` ganhou Escudo e Queimadura/DOT,
fechando a lacuna registrada nas DECISION-020/021. Novo `ActiveStatus`
(`effectId`/`turnsRemaining`/`damagePerTick` — sem nome/descrição, mesmo
padrão de `FieldEffect`) e `combatantStatuses` em `BattleState` (default
vazio pros dois jogadores). `turn-engine.ts` ganhou duas peças de
`TurnEngine.playTurn`: dano de combo é bloqueado e o Escudo consumido se o
alvo tiver o status `"shield"` (`SHIELD_STATUS_ID`, o único id que o
motor precisa conhecer por nome); ao final de cada `playTurn`, todo status
ativo dos dois combatentes tica — dano de `damagePerTick` aplicado
(genérico, não específico de Queimadura — qualquer status com
`damagePerTick > 0` tica dano, incluindo Veneno se algum dia existir uma
fonte pra ele), estados expirados removidos, tudo na mesma ordem
`[oponente, ator]` que decide empate simultâneo a favor de quem jogou o
turno (mirror exato do mecanismo da DECISION-019). `/battles/validate-turn`
também aceita e devolve `combatantStatuses`, mesmo motivo do `hp` (não
"resetar" a cada chamada).
Motivo: pedido explícito do usuário, direto do item do BACKLOG (mapa
criado nesta sessão) — fecha o pré-requisito que a própria DECISION-020/
021 apontava antes de abilities/Skill Tree poderem entrar no Multiplayer
com o backend continuando confiável como autoridade de dano/vitória.
Consequência (lacuna conhecida, não esquecida): nada no Multiplayer
aplica um status ainda — `TurnAction` continua sendo só
`{actorId, elementIds}`, sem conceito de habilidade/mutação. Isso
significa que `combatantStatuses` só é alcançável hoje construindo um
`BattleState` diretamente (testes) ou via `/battles/validate-turn`
mandando o status já pronto no corpo — nenhuma jogada real de Multiplayer
aplica Escudo ou Queimadura em ninguém. Portar Ability/Mutation/Skill Tree
pro backend (e pro cliente de Multiplayer) pra isso virar alcançável de
verdade continua fora de escopo — ver DECISION-013 e a regra de escopo do
CLAUDE.md.
Testes: 76 no backend (`npm test`), `npm run typecheck` limpo — incluindo
os 5 casos espelhados 1:1 de `turn_engine_test.dart` (Escudo bloqueia e é
consumido; não bloqueia um segundo hit; DOT tica a cada `playTurn`
incluindo o tick que expira; DOT sozinho decide vencedor; empate
simultâneo por DOT decidido a favor do ator).

## DECISION-025
Data: 2026-09-04
Decisão: Habilidades, Mutações e Skill Tree portados pro backend
(`backend/src/battle-rules/` + `MatchStore`), fechando o gap final que a
DECISION-013 tinha deixado de fora de propósito. Novos módulos:
`ability-effect.ts` (`AbilityEffect`), `mutations.ts` (Combustão/
Fragmentação/Incêndio/Núcleo Instável), `combination-modifiers.ts`
(Propagação/Instabilidade), `max-hp-bonuses.ts` (Vitalidade: +20),
`skill-tree.ts` (dados de `defaultSkillTree` + `canUnlock`/
`availableNodeIds`/`grantedMutations`/`grantedCombinationModifiers`) e
`ability-engine.ts` (`useAbility`, a camada que fica por cima de
`playTurn`, mesma separação TurnEngine/AbilityEngine do Dart).
`turn-engine.ts`'s `playTurn` ganhou o parâmetro `combinationModifiers`
que já devia ter desde a DECISION-020 mas não tinha uso ainda. `Match`
ganhou `skillProgress: Record<playerId, unlockedNodeIds[]>` (vazio pros
dois até `join`); `MatchStore.applyTurn` passa a chamar `useAbility` (não
`playTurn` puro) com as Mutações/CombinationModifiers já desbloqueadas do
ator; nova `MatchStore.unlockSkill` (mirror de
`TrainingMatch.unlockSkillForCurrentPlayer`) só deixa quem tem a vez
desbloquear, e aplica um `maxHpBonus` na hora, igual ao Modo Treino. Nova
rota `POST /matches/:id/skills/unlock`.
Decisão de tradução (não port estrutural 1:1, ao contrário dos módulos
anteriores): o `SkillNode`/`SkillTree`/`SkillGrant`/`SkillProgress`
genéricos do Dart (grafo + classe mutável + interface de tipo `is T`)
viraram dado estático (`defaultSkillTreeNodes`, sem detecção de ciclo —
essa árvore é confiável, já validada pelos testes do `battle_engine`) mais
funções puras sobre um `unlockedNodeIds: string[]` que o `MatchStore`
guarda — TypeScript não precisa do truque `is T` do Dart pra filtrar tipo
de `SkillGrant`, um union discriminado (`{kind: 'mutation'|...}`) faz o
mesmo com menos código. `Build` (a classe Dart de validação de builds
offline) não foi portada — não existe edição de build offline no
Multiplayer, `useAbility` monta a "habilidade" direto de
`elementIds + grantedMutations`, sempre válida por construção (mesmo
padrão que `TrainingMatch.playElementIds` já usava, sem nunca precisar de
`Build`/`Ability` como classes de verdade). `AbilityEffect` também não
carrega `hitCount`/`critChanceBonus` — nenhum lado (nem o Dart) os
consome ainda, então seriam peso morto na serialização; ficam de fora até
existir um sistema de dano múltiplo/crítico de verdade.
Motivo: pedido explícito do usuário, item mais claro do BACKLOG — sem
isso, Escudo/Queimadura (DECISION-024) nunca eram alcançáveis por
nenhuma jogada real, e o Multiplayer não conseguia entregar a mesma
experiência de build/progressão que o Modo Treino já tem.
Consequência (lacuna conhecida, não esquecida): o app Flutter ainda não
tem UI nenhuma pra isso — `MultiplayerLobbyScreen`/`MultiplayerBattleScreen`
não mostram nós desbloqueáveis nem chamam `POST .../skills/unlock`. O
motor está pronto e testado, mas um jogador de Multiplayer de verdade
ainda não consegue desbloquear nada pela tela — só via chamada HTTP
direta (como fiz pra verificar). Portar a UI (botão "Habilidades" na
`MultiplayerBattleScreen`, igual ao que já existe na `TrainingScreen`) é
o próximo passo natural. `hitCount`/`critChanceBonus` continuam sem
nenhum efeito, em ambos os lados — não é uma lacuna nova desta tarefa, é
herdada do próprio `battle_engine`.
Testes: 118 no backend (`npm test`), `npm run typecheck` limpo. Verificado
de ponta a ponta de verdade via HTTP puro contra o servidor rodando:
criar partida, entrar, desbloquear Maestria da Brasa pra "ana", jogar só
Fogo — Queimadura apareceu em `combatantStatuses.beto` na resposta.

## DECISION-026
Data: 2026-09-04
Decisão: UI de Habilidades/Skill Tree no Multiplayer, fechando a lacuna
que a DECISION-025 tinha deixado explícita (motor pronto no backend, sem
tela nenhuma pra usar). Botão "Habilidades" na AppBar da
`MultiplayerBattleScreen` (só visível com a partida em progresso) abre um
`showModalBottomSheet` no mesmo molde da `TrainingScreen`. Novo
`MultiplayerMatch.unlockedNodeIdsForMe` (ids crus, sem tipo do
`battle_engine` — a regra da classe inteira) e `unlockSkill(nodeId)`
(`POST /matches/:id/skills/unlock`). `RemoteMatch` ganhou `skillProgress`.
Pra exibir nome/descrição/branch dos nós, `skill_tree_catalog.dart` ganhou
`availableSkillNodeOptions(unlockedNodeIds)` — monta um `SkillProgress`
local só de leitura sobre `defaultSkillTree` do próprio `battle_engine`
(o app já tem essa árvore, é a mesma que o backend espelha) e devolve
`SkillNodeOption`s, mesmo raciocínio do `CombinationCatalog` pra
combinações.
Decisão de UX: a lista de nós só aparece se for a vez do jogador local
(`_match.isMyTurn`) — o backend rejeitaria um desbloqueio fora de vez de
qualquer jeito (DECISION-025), então checar antes evita uma chamada
fadada ao erro e deixa a mensagem clara ("Só dá pra desbloquear na sua
vez") em vez de um erro genérico depois de tentar.
Motivo: pedido explícito do usuário, sequência direta da DECISION-025 —
sem isso, o motor de Habilidades ficava pronto mas inacessível pra
qualquer jogador real do Multiplayer.
Consequência (lacuna conhecida, não esquecida): a modal não escuta o
polling da tela por trás — se a vez mudar enquanto ela está aberta, a
lista não atualiza sozinha (mesma limitação que a `TrainingScreen` já
tinha, não é regressão). Erro do backend durante um desbloqueio (ex: a
vez mudou nesse meio-tempo) aparece como `SnackBar`, não fecha a modal.
Nenhuma Mutação concede Escudo ainda (nem no Dart) — Queimadura é a única
coisa alcançável de verdade por uma partida real hoje.
Testes: 52 no app (`flutter test`), `flutter analyze` limpo — incluindo
um teste de widget que desbloqueia Maestria da Brasa na modal e confirma
a lista atualizando ao vivo (Caminho do Incêndio aparecendo no lugar).
Verificado de ponta a ponta de verdade jogando pela tela: criei partida
como "ana", "beto" entrou via API, abri "Habilidades" na tela da Ana,
desbloqueei Maestria da Brasa (lista atualizou na hora), joguei só Fogo,
e `GET /matches/:id` confirmou Queimadura (`damagePerTick: 8,
turnsRemaining: 2`) aplicada em "beto".

## DECISION-027
Data: 2026-09-04
Problema: pedido do usuário foi "Escudo via Skill Tree" — uma Mutação que
concede Escudo a quem a usa. Mas `AbilityEngine.useAbility` (Dart,
`ability_engine.dart`) sempre aplicava todo `ActiveStatus` de
`statusesToApply` no **oponente** do ator, hardcoded
(`state.opponentOf(actor)`). Fazia sentido pra Combustão (debuff no
oponente), mas pra um autobuff como Escudo isso aplicaria o efeito errado
— o Escudo protegeria quem está *apanhando*, não quem o desbloqueou.
Impacto: implementar Escudo como Mutação sem mexer nisso ou produziria um
efeito sem sentido (Escudo indo pro oponente) ou exigiria um workaround
fora do padrão já estabelecido pelas outras Mutações.
Solução recomendada (aplicada): estender o modelo pra saber *quem* cada
status mira. Novo `TargetedStatus` (`status: ActiveStatus`, `target:
StatusTarget` — `actor` ou `opponent`, default `opponent` pra manter
Combustão/etc. exatamente como estavam) substitui `List<ActiveStatus>`
por `List<TargetedStatus>` em `AbilityEffect.statusesToApply`.
`AbilityEngine.useAbility` passou a escolher o alvo por status
individualmente. Nova `Mutations.guard` ("Guarda"): aplica
`ActiveStatus(shield)` com `target: actor`. Novo `SkillNode`
`guard_training` (branch "defesa", raiz, sem pré-requisito) na
`defaultSkillTree`, concedendo Guarda.
Alternativas consideradas: (a) não generalizar e tratar Escudo como
caso especial só no `AbilityEngine` — rejeitada, reintroduziria
branching por tipo de efeito, exatamente o que `AbilityEngine`/`Mutation`
foram desenhados pra evitar; (b) modelar Escudo como algo fora do sistema
de Mutação (ex: um novo tipo de `SkillGrant`) — rejeitada, Escudo já É um
`ActiveStatus` existente (`StatusEffects.shield`), só precisava de alvo
diferente, não de um conceito novo.
Espelhado no backend (`backend/src/battle-rules/`): `ability-effect.ts`
ganhou `StatusTarget`/`TargetedStatus`; `mutations.ts`'s `combustion`
passou a declarar `target: "opponent"` explicitamente e ganhou `guard`
(`target: "actor"`); `ability-engine.ts`'s `useAbility` escolhe o alvo
por status; `skill-tree.ts` ganhou o nó `guard_training`.
Ripple pego rodando os testes (não antecipado ao planejar): `app/lib/
game_domain/training_match.dart` acessava `status.effect.name` — quebrou
porque `status` virou `TargetedStatus`, precisa ser `status.status.effect
.name`. `packages/battle_engine/test/ability_test.dart` tinha três
asserções acessando `ActiveStatus` direto de `statusesToApply` — mesma
correção.
Motivo: pedido explícito do usuário, saindo direto da UI de Habilidades
implementada na DECISION-026.
Consequência (lacuna conhecida, não esquecida): nenhuma outra lacuna nova
— o design generalizado já cobre qualquer Mutação futura que precise
mirar o ator (não só Escudo).
Testes: 176 no battle_engine (`dart test`, `dart analyze` limpo), 52 no
app (`flutter test`, `flutter analyze` limpo), 123 no backend (`npm
test`, `npm run typecheck` limpo). Verificado de ponta a ponta de
verdade jogando o Modo Treino no navegador: desbloqueei "Treino de
Guarda" (aparece automaticamente na lista, sem nenhuma mudança de UI —
prova de que o sistema é mesmo data-driven), joguei um elemento — "Efeitos
aplicados: Escudo" e "Jogador A: Escudo" apareceram (no jogador certo,
não no oponente) — joguei Fogo+Vento no outro jogador contra ele: "Última
combinação: Tempestade Ígnea" disparou mas o HP do jogador guardado ficou
em 100/100 e o Escudo sumiu (bloqueado e consumido).

## DECISION-028
Data: 2026-09-04
Decisão: backend implantado de verdade no Render (free tier), fechando o
maior item do BACKLOG de "Produção/deploy" — até aqui só rodava com
`npm run dev` na máquina de quem estivesse desenvolvendo, então dois
amigos em dispositivos diferentes nunca conseguiam jogar entre si de
verdade, mesmo com todo o resto (dano/HP/Escudo/Skill Tree/Multiplayer)
já funcionando.
Passos: `tsx` (rodava o TypeScript direto, sem etapa de build) estava em
`devDependencies` no `backend/package.json` — corrigido pra
`dependencies`, já que é preciso em runtime, não só em dev (`npm install`
em produção não instala devDependencies). Projeto inteiro virou um
repositório git pela primeira vez (`git init`, `.gitignore` cobrindo
`node_modules`/`build`/`.dart_tool`/etc.) e foi publicado no GitHub via
`gh repo create` (conta já autenticada na máquina, escopo `repo`) —
revisei a lista de arquivos staged antes de commitar, nada sensível.
Serviço `jogo-elementos-backend` criado no Render (plano `free`
explicitamente, runtime Node, `buildCommand: cd backend && npm install`,
`startCommand: cd backend && npm start`, região Virginia — mais perto do
Brasil que as outras opções disponíveis: Oregon/Frankfurt/Singapore/Ohio)
via MCP, apontando pro repositório GitHub. `defaultMultiplayerBaseUrl` no
app Flutter passou a apontar pra URL do Render em vez de `localhost:3000`
— telas que precisam do backend local pra desenvolver já aceitam um
`MultiplayerClient` com `baseUrl` customizado.
Decisão adjacente, não planejada: a integração nativa Render↔GitHub App
deu erro do lado do Render ao tentar conceder acesso a um repositório
novo (reproduzido pelo usuário, não algo que eu pudesse contornar sozinho
— pedir a instalação/permissão do GitHub App é uma ação que só o usuário
pode autorizar). Com a integração quebrada, o Render oferece repositório
público como alternativa direta (sem precisar do App instalado) — perguntei
explicitamente ao usuário antes de tornar o repositório público (`gh repo
edit --visibility public`), ele confirmou. `jogo-elementos` no GitHub é
público desde então — é só código do jogo, sem segredos (chave nenhuma,
`.env` nenhum; conferido antes do commit inicial).
Motivo: pedido explícito do usuário — "utilize o Render, ele está
conectado com o Claude" — depois de eu ter respondido honestamente que o
jogo não estava "pronto" justamente por nada estar implantado.
Consequência (lacuna conhecida, não esquecida): o **app Flutter em si**
continua sem estar implantado em lugar nenhum — só o backend. Pra dois
amigos jogarem de verdade hoje, alguém ainda precisa rodar
`flutter run -d web-server` localmente (apontando pro backend do Render,
que já é o default). Publicar o app em algum lugar (Firebase Hosting,
Render Static Site, GitHub Pages) é o próximo passo pra isso não depender
de rodar nada localmente. `MatchStore` continua em memória — reiniciar o
serviço no Render (redeploy, ou o free tier hibernando e sendo reativado)
não derruba partidas em andamento (hibernação não reinicia o processo,
só pausa), mas um redeploy de verdade (novo commit) sim. CORS continua
`Access-Control-Allow-Origin: *` (DECISION-021) — agora com uma origem de
produção de verdade, vale reavaliar restringir isso no futuro. Repositório
GitHub é público — qualquer pessoa pode ver o código-fonte (aceito
explicitamente pelo usuário).
Testes: nenhum teste novo (mudança de infraestrutura, não de lógica) —
`npm test`/`npm run typecheck` do backend continuam verdes depois da
mudança em `package.json` (123 testes). Verificado de ponta a ponta de
verdade contra o serviço real no Render: `curl` direto (`/health`, criar/
entrar/jogar uma partida com dano correto) e, principal prova, o app
Flutter rodando localmente **sem nenhum backend local no ar** — criei
uma partida pela tela, confirmei via `curl` que ela existia no Render,
"beto" entrou via `curl`, e a tela da "ana" pegou a mudança sozinha via
polling, sem eu recarregar nada.

## DECISION-029
Data: 2026-09-04
Decisão: primeiro APK Android de verdade, publicado como GitHub Release
(`v0.1.0`) — pedido explícito do usuário: "quero que continue até
termos um apk pra baixar e poder jogar eu e meu amigo de forma
tranquila".
Passos: `flutter create --platforms=android .` gerou `app/android/`
(nunca tinha sido criado — só web/windows existiam, DECISION-010).
`AndroidManifest.xml` ganhou `<uses-permission
android:name="android.permission.INTERNET"/>`, que o template não inclui
por padrão — sem isso o Multiplayer falharia silenciosamente em
dispositivo Android (rede bloqueada pelo próprio Android). Toolchain do
Android instalada nesta máquina: command-line tools do Android SDK
(baixadas direto do Google, sem depender do pacote `android-sdk` do
Chocolatey, marcado como "possibly broken"), plataformas/build-tools
`35`/`36`/`28.0.3` (as versões que o Flutter atual pediu), licenças
aceitas.
Problema real encontrado: `flutter build apk --release` local falha com
`java.io.IOException: Unable to establish loopback connection` — a
*mesma* limitação de rede da JVM que já tinha impedido o emulador do
Firestore de rodar (DECISION-015), agora atingindo a conexão entre o
processo Flutter e o daemon/Tooling API do Gradle. As mesmas mitigações
tentadas na DECISION-015 (`-Djava.net.preferIPv4Stack=true`, desabilitar
o daemon do Gradle, rodar sem sandbox) não resolveram — falha em ~3ms,
antes de qualquer trabalho de rede de verdade começar, confirmando que
não é algo contornável por configuração.
Solução: compilar via GitHub Actions em vez de localmente. Novo
`.github/workflows/build-apk.yml` (`workflow_dispatch`, runner
`ubuntu-latest`, sem essa limitação) — `flutter pub get` +
`flutter build apk --release` + upload do artefato. Precisei que o
usuário autorizasse o escopo `workflow` pro `gh` CLI via
`gh auth refresh -s workflow` (fluxo de autorização por dispositivo no
navegador — só ele podia completar isso). Depois de rodar o workflow
(`gh workflow run` + `gh run watch`) e confirmar sucesso, baixei o
artefato (`gh run download`) e publiquei como asset de uma GitHub
Release (`gh release create v0.1.0 ...`) — não bastava mandar o arquivo
só pro usuário: o link também precisa alcançar o amigo dele, que não
está nesta conversa, então um link de download direto (funciona de
qualquer navegador, inclusive no Android) é a forma certa de entregar
isso, não o chat.
Motivo: pedido explícito do usuário, sequência direta do deploy do
backend (DECISION-028) — sem um APK, "jogar de forma tranquila" ainda
significava alguém rodar `flutter run` numa máquina de desenvolvedor.
Consequência (lacuna conhecida, não esquecida): o build usa a chave de
assinatura de **debug** (`signingConfig = signingConfigs.getByName
("debug")` já vinha assim no template gerado) — funciona pra instalar
direto num aparelho ("sideload", com "fontes desconhecidas" habilitado),
mas não é uma chave de release de verdade nem serve pra publicar numa
loja. Sem atualização automática — uma nova versão do jogo exige gerar
e publicar um APK novo manualmente (não há checagem de versão no app
nem CI disparando sozinho em cada push ainda, só `workflow_dispatch`
manual). iOS continua fora de alcance (precisa de um Mac). O
`gradle.properties` local ganhou `org.gradle.daemon=false` e
`-Djava.net.preferIPv4Stack=true` das tentativas de mitigação — inofensivo
mantê-los (não atrapalham o build no CI), mas não resolveram o problema
local.
Testes: nenhum teste novo (mudança de infraestrutura/build, não de
lógica) — os 52 testes do app continuam verdes. Verificado de ponta a
ponta de verdade: o workflow rodou no GitHub Actions e terminou com
todos os passos verdes (`✓ flutter build apk --release`), o artefato
baixado tinha o tamanho esperado (~48MB), e o link de download da
Release respondeu com `Content-Type:
application/vnd.android.package-archive` e o `Content-Length` correto.

## DECISION-030
Data: 2026-09-08
Decisão: cenário de batalha visual (Flame) ligado a `TrainingScreen` e
`MultiplayerBattleScreen` — pedido do usuário depois de testar o APK e
sentir falta de um campo de batalha/personagens.
Passos: novo `BattleSceneView` (Game Domain, dado puro) montado por cada
tela a partir do que já expõe (HP/vez) — nenhuma mudança em
`TrainingMatch`/`MultiplayerMatch` além de um getter (`isPlayerATurn`).
Novo `BattleSceneGame` (Flame) renderiza um fundo estático mais dois
`BattleCharacterComponent` — personagens genéricos desenhados em código
(sem sprite), diferenciados só por lado/cor — com barra de HP, indicador
de vez, e um flash+shake local (contagem regressiva em `update(dt)`, sem
o sistema `Effect` do Flame, que exigiria o mixin `HasPaint`) quando o HP
de um lado cai. `BattleSceneWidget` hospeda o `GameWidget` numa área fixa
no topo de cada tela — o resto do layout (HP em texto, chips, botões)
continua exatamente como era. A demo Flame desconectada anterior
(`BattleView`/`BattleGame`/`BattleScreen`/`DemoBattle`, nunca ligada a uma
partida real) foi removida.
Fundo: imagem CC0 "Meadow background" de `bart`, OpenGameArt.org
(https://opengameart.org/content/meadow-background) — domínio público,
sem exigência de atribuição, 89.7 KB.
Detalhe encontrado durante a implementação: a cena de 220px estourava a
altura do `Column` das duas telas em telas menores (overflow de layout,
e os botões perto do fim do formulário ficavam fora da área tocável nos
testes de widget). Corrigido trocando o `Padding` do `body` por um
`SingleChildScrollView` nas duas telas — nenhuma outra mudança de layout.
Motivo: pedido explícito do usuário; abordagem híbrida (fundo pronto CC0 +
personagens em código) escolhida em vez de um asset pack completo para
evitar depender de achar sprites genéricos para "dois lados" e para não
correr risco de licença nos personagens.
Consequência (lacuna conhecida, não esquecida): sem ícones de status
(Escudo/Queimadura) sobre o personagem — `RemoteBattleState` do
Multiplayer não expõe estados ativos por jogador hoje; adicionar isso é
mudança de contrato do backend, fora desta tarefa. Sem sprites por
elemento/combinação, sem animação de movimento. O APK existente
(DECISION-029) não inclui essa mudança — gerar um novo é ação separada.
Testes: suíte completa do app (`flutter test`, 61 testes) e `flutter
analyze` passando depois da mudança. Verificado de ponta a ponta de
verdade via `flutter run -d web-server`: cena renderizando fundo + dois
personagens com HP/vez corretos no Modo Treino (jogada de Fogo+Vento
reduziu o HP do oponente e a barra encolheu visivelmente) e no
Multiplayer (duas abas de navegador, `ana` criando a partida e `beto`
entrando com o código — lado esquerdo/direito e indicador de vez
corretos nos dois lados).

## DECISION-031
Data: 2026-09-08
Decisão: sequência de feedback visual de ataque (Bloco 1 da nova direção de
produto — ver CLAUDE.md, seção "Direção de produto (game feel)") — dano
instantâneo vira preparação→efeito elemental→impacto→dano→estado, pra
qualquer combinação, no Modo Treino e no Multiplayer.
Passos: novo `AttackEvent` (Game Domain, dado puro) descreve o que
aconteceu num turno; cada tela monta esse evento a partir do que já sabia
(elementos jogados, combinação, dano, estados). Novo
`AttackSequencePlayer` (Flame `Component`) toca a sequência com timer
manual (mesmo padrão do `BattleCharacterComponent`), sem o sistema
`Effect` do Flame. Identidade visual mínima: símbolo já existente de cada
elemento (`ElementCatalog`) mais uma cor nova por elemento — sem asset
novo. `BattleCharacterComponent` ganhou barra de HP interpolada (persegue
o valor novo em vez de saltar) e um pulso de escala pro passo de
preparação.
No Multiplayer, o backend não manda quais elementos o oponente jogou — a
jogada dele é deduzida (`detectOpponentAttack`) comparando os efeitos de
campo ativos antes/depois de cada poll: um efeito novo identifica a
combinação, e por tabela os elementos que a formam
(`CombinationCatalog.elementIds`, novo), sem mudar o contrato do backend.
Motivo: primeiro bloco da nova direção de produto (game feel) — o usuário
pediu blocos pequenos e completos, priorizando a batalha (o "coração do
jogo") antes de identidade visual ampla, áudio, etc.
Consequência (lacuna conhecida, não esquecida): no Multiplayer, o passo de
"Estado" da sequência nunca toca — o cliente não recebe estados ativos por
jogador do backend (mesma lacuna da DECISION-030). Sem crítico (não existe
no jogo), sem projétil com física de verdade, sem ícone de status
persistente entre turnos — tudo já fora de escopo desde a spec.
Testes: suíte completa do app (`flutter test`, 81 testes) e `flutter
analyze` passando depois da mudança. Verificado de ponta a ponta de
verdade via `flutter run -d web-server`: jogada de Fogo+Vento no Modo
Treino disparou a sequência completa — pulso no atacante, flash de
impacto tingindo o alvo no momento certo, HP caindo de 100 pra 80,
indicador de turno migrando pro lado certo — sem nenhum erro no console.

## DECISION-032
Data: 2026-09-08
Decisão: arena de batalha em pixel art (Bloco 2 da direção de produto) —
HUD de HP fixo no topo (estilo jogo de luta), personagens desenhados como
sprite pixel art estilo Pokémon GBA/GBC (grade de cores em código, sem
asset), fundo procedural em blocos de cor. Vale pro Modo Treino e pro
Multiplayer (componentes compartilhados).
Passos: `BattleSceneView` ganhou `leftLabel`/`rightLabel`. Novo
`BattleHudWidget` (Flutter puro, não Canvas) desenha o painel de HP no
topo — `BattleSceneWidget` virou um `Stack` com ele sobreposto ao
`GameWidget`. Novo `pixel_sprite.dart`: uma grade 20×16 de índices de cor
(dado) + uma função de desenho genérica (`drawPixelGrid`) + duas paletas
(esquerda/direita, mesmos índices, só a cor principal/sombra muda).
`BattleCharacterComponent` passou a desenhar essa grade em vez de formas
soltas, e perdeu a barra de HP/contorno de turno (migraram pro HUD) — o
mesmo `canvas.scale` já usado no pulso de preparação agora também espelha
o lado direito. Novo `PixelArenaBackground` substitui a imagem CC0 por
céu/chão em blocos de cor; `battlefield_bg.jpg` e a declaração `assets:`
correspondente foram removidos.
Como pedido explícito do usuário: as linhas "Jogador X: HP" em texto
simples abaixo da cena foram removidas (redundantes com o HUD novo) — o
resto do texto (estados, descobertas, combinação, campo, chips, botão)
continua igual.
Motivo: Bloco 2 da nova direção de produto (game feel) — pedido explícito
do usuário por um visual "estilo jogos de luta, bonecos de gameboy tipo
pokemon", feito em código.
Consequência (lacuna conhecida, não esquecida): a sequência de ataque
(`AttackSequencePlayer`: burst elemental, número de dano, texto de
estado) continua com o visual anterior (texto/formas simples), não em
pixel art — fora de escopo deste bloco. Sem escolha de avatar, sem
animação de idle, sem sprites por elemento — tudo já era esperado desde a
spec.
Testes: suíte completa do app (`flutter test`, 87 testes) e `flutter
analyze` passando depois da mudança. Verificado de ponta a ponta de
verdade via `flutter run -d web-server`: HUD, arena e personagens
pixelados renderizando corretamente no Modo Treino (jogada de Fogo+Vento
disparou a sequência de ataque normalmente sobre o novo visual, HP e
indicador de turno corretos) e no Multiplayer (duas abas, "Você"/
"Oponente" no HUD, indicador de turno correto) — sem nenhum erro no
console nos dois casos.

## DECISION-033
Data: 2026-09-09
Decisão: tela inicial de verdade (Bloco 3 da direção de produto) —
substitui a `HomeScreen` placeholder (lista crua dos 10 elementos, o
próprio código já dizia "Placeholder screen... Real screens... come in
later tasks") por uma tela de título estilo jogo de luta: fundo/
personagens pixel art reaproveitados da batalha, título com contorno,
dois botões blocudos pro Treino/Multiplayer.
Passos: `PixelArenaBackground` teve o desenho extraído pra uma função
pura `drawArenaBackdrop` (Flame e a tela inicial compartilham a mesma
fonte de verdade pro céu/chão). Novo `TrainerSpriteImage` reaproveita
`drawPixelGrid` fora do Flame, via `CustomPainter` puro (sem game loop,
decoração estática). Novo `PixelMenuButton`, mesmo espírito visual do
`BattleHudWidget`. O título usa `TextStyle.shadows` (vários `Shadow`
deslocados sem blur) pra simular contorno grosso, sem fonte nova. A
lista dos 10 elementos saiu de cena — elementos continuam sendo a
identidade do jogo dentro da batalha, não precisam de vitrine própria na
Home.
Motivo: Bloco 3 da nova direção de produto (game feel) — a Home era
literalmente o único lugar do app ainda sem nenhuma identidade visual,
sendo a primeira tela que o jogador vê.
Problema real encontrado na verificação manual: `PixelMenuButton`
renderizava preto sólido (texto invisível) com a estrutura inicial
`Material > InkWell > Container(decorado)` — a cor do `Material` não
aparecia. Corrigido trocando por um único `Container` decorado (cor,
borda, sombra no mesmo `BoxDecoration`) com `GestureDetector` — sem
ambiguidade de qual camada pinta o quê. Separadamente, a primeira
tentativa de verificar visualmente deu falso negativo: o
`flutter run -d web-server` já estava no ar de uma verificação anterior
e um simples reload de página não recompila Dart alterado (só reflete
mudanças com o servidor reiniciado ou hot reload de verdade) — reiniciar
o servidor foi necessário pra ver a correção de fato.
Consequência: nenhuma lacuna nova — Treino/Multiplayer/Lobby/Skill Tree
continuam com o visual Material padrão (fora de escopo deste bloco,
prioridade "UI/UX" mais ampla fica pra um bloco futuro).
Testes: suíte completa do app (`flutter test`, 92 testes) e `flutter
analyze` passando depois da mudança. Verificado de ponta a ponta de
verdade via `flutter run -d web-server` (servidor reiniciado pra
garantir código atual): tela inicial renderizando título/personagens/
botões corretamente (batendo com o mockup aprovado), navegação pros dois
modos funcionando, cena de batalha do Bloco 2 continuando intacta —
sem erro no console.

## DECISION-034
Data: 2026-09-09
Decisão: consistência visual pixel art (Bloco 4 da direção de produto) —
`TrainingScreen`, `MultiplayerLobbyScreen` e `MultiplayerBattleScreen`
ganham o mesmo fundo/título/botões da Home (DECISION-033), fechando o
choque visual entre a Home e as telas de jogo. Nenhuma lógica, regra ou
texto visível mudou — só o widget por trás de cada elemento.
Passos: `ArenaBackdropPainter` (antes privada da Home) virou pública,
reaproveitada nas três telas via `Stack` + `Scaffold` transparente (mesmo
padrão da Home). Novo `PixelOutlinedText` (título com contorno,
parametrizado) e `PixelContentPanel` (painel "cartão" que mantém o
conteúdo existente — texto, chips, campos — legível por cima do fundo
colorido). `PixelMenuButton` ganhou suporte a `onPressed` nulo (estado
desabilitado, opacidade reduzida) pra poder substituir todo `ElevatedButton`/
`OutlinedButton` de ação principal: "Jogar" (Treino e Multiplayer), "Nova
partida", "Criar partida", "Entrar com código", "Reconectar", "Revanche".
Motivo: Bloco 4 da nova direção de produto (game feel) — a Home (Bloco 3)
deixou evidente que sair dela pras telas de jogo era um tombo visual pro
Material puro; "sem mexer na lógica" foi pedido explícito do usuário.
Consequência (lacuna conhecida, não esquecida): `FilterChip`, `TextField`
e o conteúdo do modal de Skill Tree continuam Material padrão — fora de
escopo deste bloco, ficam pra um bloco futuro de "feedback visual" mais
focado nesses elementos especificamente.
Testes: suíte completa do app (`flutter test`, 96 testes) e `flutter
analyze` passando depois da mudança. Verificado de ponta a ponta de
verdade via `flutter run -d web-server` (servidor reiniciado, não só
recarregado): Modo Treino (jogada de Fogo+Vento de verdade, botão
desabilitando/habilitando corretamente), Lobby e criação de partida real
no Multiplayer, todos com fundo/título/botões consistentes com a Home —
sem erro no console.

## DECISION-035
Data: 2026-09-10
Decisão: feedback visual em pixel art pros chips de elemento, campos de
texto e modal de Skill Tree (Bloco 5 da direção de produto) — fecha o gap
documentado desde o Bloco 4 (DECISION-034). Nenhuma lógica, regra ou texto
visível mudou — só o widget por trás de cada elemento.
Passos: três componentes novos em `game_presentation/` —
`PixelElementChip` (substitui `FilterChip`, preenchimento dourado quando
selecionado/creme quando não, opacidade reduzida quando `onTap` é nulo),
`PixelTextField` (substitui `TextField` cru na Lobby, mesma borda/fundo dos
outros componentes, `TextField` real por dentro pra não quebrar os testes
existentes) e `PixelSheetPanel` (envolve o conteúdo do modal de Skill Tree
num painel com cantos superiores arredondados, pra parecer um painel de
jogo subindo em vez de um bottom sheet branco genérico). Dentro do modal, o
título virou `PixelOutlinedText`, cada nó desbloqueável ganhou um cartão
com borda pixel art (era `ListTile`), e "Desbloquear"/"Fechar" viraram
`PixelMenuButton` (eram `TextButton`).
Motivo: Bloco 5 da nova direção de produto (game feel) — esses três
elementos eram justamente os mais interagidos durante uma partida (seleção
de elemento, desbloqueio de habilidade) e o gap ficou documentado
explicitamente no BACKLOG desde a DECISION-034.
Consequência: nenhuma lacuna nova conhecida — o gap de "feedback visual"
Material padrão apontado na DECISION-034 está fechado.
Testes: suíte completa do app (`flutter test`, 100 testes) e `flutter
analyze` passando. Verificado de ponta a ponta de verdade via `flutter run
-d web-server` (servidor reiniciado, não só recarregado): Modo Treino com
seleção de elemento (chip dourado/creme) e desbloqueio real de habilidade
pelo painel novo, Lobby com campos restilizados e criação de partida real
contra o backend no Render, zero erros no console.

## DECISION-036
Data: 2026-09-10
Decisão: animações (Bloco 6 da direção de produto) — sprites com idle
(balanço vertical sutil na Home e na cena de batalha), botões/chips
afundando ao toque, transição de tela em slide de baixo pra cima — mais a
lista de elementos saindo do corpo da tela e virando um painel que sobe de
baixo (`PixelSheetPanel`, mesmo do Bloco 5), resolvendo a rolagem que a
lista sempre visível causava em Treino e Multiplayer.
Passos: `TrainerSpriteImage` e `BattleCharacterComponent` ganharam um
deslocamento senoidal em Y (2px de amplitude, ciclo de 1.6s) — o primeiro
via `AnimationController`/`AnimatedBuilder`, o segundo somado direto no
`update()` do componente Flame, sem conflitar com o shake de dano (só X) ou
o pulso de preparação (só escala) que já existiam. `PixelMenuButton` e
`PixelElementChip` viraram `StatefulWidget`, com `AnimatedContainer`
reagindo a `onTapDown`/`onTapUp`/`onTapCancel` (sombra some, conteúdo
desloca 3px). Novo `pixelSlideRoute` (`PageRouteBuilder` com
`SlideTransition`, 300ms) substitui `MaterialPageRoute` nas 4 navegações
principais. `TrainingScreen`/`MultiplayerBattleScreen` ganharam
`_openElementPicker`/`_selectedElementsSummary` — a lista de chips agora só
aparece dentro do painel, aberto por um botão "Escolher elementos"
(desabilitado fora da vez no Multiplayer, mesma condição que os chips já
tinham); a tela principal mostra só o resumo do que foi escolhido.
Motivo: Bloco 6 da nova direção de produto (game feel) — "animações" era o
próximo item sem bloco dedicado na ordem de prioridade; o painel de
elementos entrou no mesmo bloco por resolver, com a mesma peça visual
(painel subindo), um problema de UX real apontado pelo usuário (rolagem
causada pela lista de elementos sempre visível).
Consequência: nenhuma lacuna nova conhecida. Testes que montam
`TrainerSpriteImage`/`HomeScreen` agora precisam descartar o
`AnimationController` explicitamente no final (`pumpWidget(SizedBox())`) —
documentado como constraint pra blocos futuros que tocam essas telas.
Achado à parte (não é regressão deste bloco): `flutter run -d web-server`
sempre gerou uma quantidade grande de erros 404 no console, presentes já
no carregamento inicial da página antes de qualquer interação — ruído do
servidor de desenvolvimento (DWDS buscando arquivos-fonte pra
debug/source-map), não afeta a aplicação. Confirmado comparando console
logo após reload, sem nenhuma interação, com o mesmo padrão.
Testes: suíte completa do app (`flutter test`, 104 testes) e `flutter
analyze` passando. Verificado de ponta a ponta de verdade via `flutter run
-d web-server` (servidor reiniciado, não só recarregado): idle nos
personagens da Home e da batalha, "afundar" ao segurar um botão, painel de
elementos abrindo/fechando com seleção e confirmação reais, jogada completa
com a sequência de ataque do Bloco 1 ainda funcionando (dano real
100→80 HP), transição em slide entre Home/Treino/Multiplayer/Lobby, criação
de partida real no Multiplayer contra o backend no Render — sem nenhuma
exceção não tratada no console (só o ruído pré-existente do dev server).

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
Dois achados reais durante a implementação, não previstos no plano:
(1) `PixelMenuButton` com `width: 280` fixo (mesmo padrão da Home) estoura
("RenderFlex overflow") com o label "Baixar atualização", mais longo que
os outros — corrigido deixando o botão sem largura fixa, do jeito que
"Jogar"/"Escolher elementos" já são usados em outras telas. (2) em teste
de widget, `tester.pump()` **sem duração** não avança o relógio falso o
suficiente pra disparar um `Future.delayed(Duration.zero)` — precisa de
`tester.pump(const Duration(milliseconds: 1))` (ou qualquer duração > 0)
pra isso resolver de verdade; documentado como lição nova, mesma categoria
da proibição de `pumpAndSettle()` com animação infinita (Bloco 6) — aliás
essa proibição se confirmou aqui na prática: `pumpAndSettle()` nos testes
de `UpdateGateScreen` travou (timeout) porque o estado "atualizado"
mostra a `HomeScreen`, que desde o Bloco 6 tem idle infinito.
Consequência/processo novo: a partir de agora, toda vez que eu gerar e
publicar um APK novo preciso **também** atualizar o campo `version:` do
`app/pubspec.yaml` pra bater com a tag da release (ex: tag `v0.9.0` →
`version: 0.9.0+9`) — é esse campo que vira o `versionName` real
instalado, que o `package_info_plus` lê em runtime. Sem esse passo, o app
nunca vai se reconhecer como desatualizado. `pubspec.yaml` está em
`1.0.0+1` ainda — a próxima geração de APK precisa vir com esse bump.
Lacuna conhecida: esta máquina não roda Android de verdade (só compila via
GitHub Actions), então a validação ficou limitada aos testes de widget com
`isAndroid: true` forçado — nunca visto rodando de verdade num aparelho
Android aqui. Confirmação manual pendente do usuário depois do próximo APK.
Testes: suíte completa do app (`flutter test`, 117 testes) e `flutter
analyze` passando. Verificado no navegador (Web, servidor reiniciado do
zero): Home abre direto sem travar em "Verificando atualizações..."
(checagem pulada fora do Android), sem exceções no console.

## DECISION-038
Data: 2026-09-10
Decisão: Skill Tree visual (Bloco 7 da direção de produto) — o botão
"Habilidades" (Treino e Multiplayer) passa a abrir uma tela cheia com a
árvore inteira (travados/disponíveis/desbloqueados juntos, ícone por nó,
5 branches lado a lado roláveis horizontalmente) em vez do modal com só
os "disponíveis agora". Uma única `SkillTreeScreen` substitui as duas
implementações quase idênticas que existiam antes.
Passos: `SkillTreeNodeOption`/`allSkillTreeNodes`/`skillTreeBranchDisplayName`
novos em `game_domain/skill_tree_catalog.dart` (ícone por nó — emoji,
mesmo espírito do symbol de `ElementOption` — e nome de exibição por
branch), sem tocar `battle_engine`/backend. `TrainingMatch` ganhou
`unlockedNodeIdsForCurrentPlayer` (só tinha os "disponíveis agora" antes).
Layout puro (`orderBranchNodes`/`skillTreeNodeState`, testáveis sem
Flutter) assume que cada branch é uma cadeia linear — cobre 100% do
conteúdo real hoje; se um nó ganhar 2+ pré-requisitos/filhos no futuro,
ainda produz uma ordem topológica válida, só não desenha ramificação
visual (limitação conhecida). Cada branch vira uma coluna própria —
nenhuma raiz falsa inventada pra unificar visualmente. Tocar qualquer nó
(`SkillTreeNodeWidget`, círculo com ícone) abre um painel de detalhe
(`PixelSheetPanel`) com nome/descrição e, dependendo do estado, os
pré-requisitos que faltam, o botão "Desbloquear", ou o aviso de que só dá
pra desbloquear na própria vez. Mudança de UX deliberada: a árvore
inteira agora fica visível a qualquer momento no Multiplayer, mesmo fora
da vez — só a ação de desbloquear continua condicionada a isso (antes,
fora da vez, nem a lista aparecia).
Motivo: Bloco 7 da nova direção de produto (game feel) — o usuário trouxe
uma imagem de referência de árvore de habilidades visual; decidido em
brainstorming não inventar uma raiz falsa (os dados reais não têm uma
raiz compartilhada entre as 5 branches) e usar tela cheia em vez de
continuar no painel que sobe de baixo.
Consequência: nenhuma lacuna nova conhecida além da já documentada
(layout assume cadeia linear, registrada no BACKLOG).
`SkillNodeOption`/`skillNodeOptionFrom`/`availableSkillNodeOptions`
(código antigo) continuam existindo, sem uso depois deste bloco — não
removidos, fora de escopo.
Testes: suíte completa do app (`flutter test`, 133 testes) e `flutter
analyze` passando. Verificado de ponta a ponta de verdade via `flutter
run -d web-server` (servidor reiniciado, não só recarregado): árvore
completa visível no Modo Treino (5 branches, nós travados com opacidade
reduzida), nó "Maestria da Brasa" desbloqueado de verdade pelo painel de
detalhe (virou dourado, "Caminho do Incêndio" saiu do travado), voltar
pra tela de batalha funcionando, zero exceções no console. Verificação
completa no Multiplayer (contra o backend real) e do bônus de HP
imediato (Treino de Vitalidade) ficou pro usuário confirmar depois, já
coberta pelos testes automatizados de widget (`skill_tree_screen_test.dart`,
`multiplayer_battle_screen_test.dart`).

## DECISION-039
Data: 2026-09-10
Decisão: assinatura estável do APK — `.github/workflows/build-apk.yml`
passa a cachear `~/.android/debug.keystore` (`actions/cache`, chave fixa
`android-debug-keystore-v1`) entre execuções, em vez de deixar o Gradle
gerar um keystore de debug novo (chave aleatória) a cada build.
Problema encontrado: o usuário testou a checagem obrigatória de
atualização (DECISION-037) de verdade num Android — apareceu a tela de
"Atualização necessária", abriu o navegador, baixou o APK novo, mas o
Android recusou instalar com "app não instalado". Diagnóstico: o runner
do GitHub Actions é efêmero, sem nenhum keystore de debug persistido —
toda build gerava uma chave nova, então nenhum dos APKs publicados até
agora (v0.1.0 a v0.10.0) tem a mesma assinatura que o anterior, e o
Android recusa instalar por cima de uma assinatura diferente (proteção de
segurança padrão do sistema).
Impacto: qualquer tentativa de atualizar um APK já instalado por cima de
outro, até agora, falhava sempre — não é específico da checagem de
atualização em si, é um problema do processo de build que só ficou
visível quando alguém tentou de verdade uma atualização in-place pela
primeira vez.
Alternativa considerada e descartada: commitar um keystore de debug fixo
direto no repositório — funcionaria igual, mas cache é mais simples de
reverter/trocar se algo der errado, sem deixar um arquivo binário extra
versionado.
Consequência: a partir do primeiro APK gerado depois deste ajuste, a
assinatura fica estável — atualizações in-place devem funcionar dali em
diante. Quem já tem uma versão anterior instalada (qualquer uma até
v0.10.0) precisa desinstalar e instalar do zero mais uma vez; depois
disso, atualizar por cima deve funcionar.
Testes: não há teste automatizado pra assinatura de build (é
configuração de CI, fora do escopo de `flutter test`) — validação é
gerar um APK novo e confirmar manualmente que instala por cima do
anterior sem erro.

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

## DECISION-041
Data: 2026-09-11
Decisão: habilitar "core library desugaring" no Gradle do módulo `app`
(`app/android/app/build.gradle.kts`) — `compileOptions.isCoreLibraryDesugaringEnabled
= true` + dependência `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")`.
Problema encontrado: a primeira build de APK depois da DECISION-040
(pacote `ota_update`) falhou no GitHub Actions com "Dependency
':ota_update' requires core library desugaring to be enabled for :app" —
o próprio `flutter analyze`/`flutter test` local não pega esse tipo de
erro (é validado só na hora de compilar de verdade pro Android, que só
acontece via GitHub Actions nesta máquina).
Motivo: a documentação do `ota_update` já mencionava "requer
compatibilidade Java 8" mas o passo concreto de habilitar desugaring no
Gradle não tinha sido replicado no projeto — só apareceu como erro na
build real.
Consequência: nenhuma outra dependência do projeto precisa disso hoje —
mudança isolada ao `ota_update`.
Testes: nenhum automatizado (configuração de build). Validação: a
próxima build do GitHub Actions precisa terminar com sucesso.

## DECISION-042
Data: 2026-09-11
Decisão: primeiro som do jogo — Bloco 8 (áudio) da "Direção de produto".
Pacote `flame_audio` (v2.12.2) + `SfxPlayer`
(`game_presentation/sfx_player.dart`), uma instância global mutável
(`sfxPlayer`) que envolve `FlameAudio.play` com `runZonedGuarded` — som
nunca derruba o app nem quebra teste, mesmo sem binding de plataforma
inicializado (ex: `flutter test` fora de `testWidgets`, onde o erro de
platform channel escapa de um try/catch comum). É a única variável
global mutável do código-base, de propósito: só assim `PixelMenuButton`
e `PixelElementChip` conseguem trocar por uma instância com `play`
injetado nos próprios testes, sem mudar a API pública de nenhum widget.
6 sons CC0 (Kenney, via `raw.githubusercontent.com/Calinou/kenney-ui-audio`
e `gamesounds.xyz`) cobrem: toque de botão/chip, ataque disparado,
impacto, habilidade desbloqueada, vitória (Treino) e vitória/derrota
(Multiplayer, com flag `_playedGameOverSound` pra tocar só uma vez).
Escopo explícito: só efeitos sonoros. Sem música de fundo (loop/fade/
mixagem — complexidade própria, fica pra bloco futuro) e sem botão de
mutar/desmutar (não existe tela de configurações ainda — registrado no
BACKLOG).
Motivo: "áudio" era o próximo item sem bloco dedicado na ordem de
prioridade do CLAUDE.md, e o jogo não tinha nenhum som até aqui — gap
grande de game feel pra um jogo de batalha.
Consequência: os 6 sons foram escolhidos por nome/categoria/tamanho dos
pacotes CC0, não por audição (Claude não consegue ouvir áudio) — o
usuário pode precisar trocar algum arquivo depois de ouvir no app de
verdade; troca é só substituir o arquivo em `assets/audio/`, sem mudar
código.
Testes: suíte completa do app (`flutter test`, 142 testes) e `flutter
analyze` passando. Verificado manualmente via `flutter run -d
web-server`: toque de botão, cast e impacto de ataque confirmados
carregando (`tap.wav`/`cast.ogg`/`impact.ogg`, 200/206 no navegador) sem
erro no console. Som de unlock/vitória/derrota não foram clicados
manualmente nesta sessão (ícone de habilidades não localizado a tempo no
preview web), mas a lógica que decide quando tocar (`_match.isOver`,
`_match.isFinished`/`_match.amIWinner`) já é coberta pelas suítes de
`TrainingScreen`/`MultiplayerBattleScreen`/`SkillTreeScreen`, que
continuam passando sem mudança de contagem.

## DECISION-043
Data: 2026-09-11
Decisão: corrigir o caminho cacheado do keystore de debug em
`.github/workflows/build-apk.yml` — de `~/.android/debug.keystore` pra
`~/.config/.android/debug.keystore` (chave do cache também trocada pra
`android-debug-keystore-v2`, já que a v1 nunca guardou nada de útil).
Problema encontrado: o usuário testou a atualização in-app de v0.11.0
pra v0.12.0 de verdade num Android — baixou, o instalador abriu, mas deu
"app não instalado" de novo, mesmo depois da DECISION-039 (cache do
keystore) supostamente já estar em vigor. Comparando os certificados de
assinatura dos dois APKs publicados
(`apksigner verify --print-certs`) confirmou que v0.11.0 e v0.12.0 têm
SHA-256 diferentes — o cache nunca funcionou. Investigando o log do
workflow: o passo "Post Cache Android debug keystore" reportava
"Path Validation Error: Path(s) specified in the action for caching
do(es) not exist" no fim de toda build — ou seja, `flutter build apk`
nunca escreveu nada em `~/.android/debug.keystore`. Um passo de debug
temporário (`find / -xdev -iname debug.keystore`) confirmou o caminho
real usado por esta versão do toolchain Gradle/AGP:
`/home/runner/.config/.android/debug.keystore` (dentro de `.config/`,
não direto em `~/.android/`).
Motivo: a DECISION-039 assumiu o caminho "clássico" documentado do
keystore de debug do Android sem verificar de verdade onde o Gradle
escrevia no runner — o mesmo tipo de suposição que já tinha causado a
DECISION-041 (desugaring), só que dessa vez o build passava e só falhava
de verdade na instalação no celular, não na CI.
Consequência: toda versão publicada entre v0.9.0 e v0.12.0 tem uma
assinatura diferente uma da outra — nenhuma delas instala "por cima" de
nenhuma outra. O celular do usuário precisa de mais um
desinstalar+instalar manual, dessa vez da v0.13.0 (primeira com o cache
de verdade funcionando) — depois dela, updates in-app devem funcionar
de verdade pela primeira vez.
Testes: nenhum automatizado (configuração de build/CI). Validação: dois
builds seguidos do workflow corrigido — o primeiro deu cache miss ("Cache
not found for input keys: android-debug-keystore-v2") e salvou o
keystore novo; o segundo deu cache hit ("Cache restored from key:
android-debug-keystore-v2"). `apksigner verify --print-certs` nos dois
APKs baixados confirmou o mesmo certificado SHA-256
(`ec257adaebff1cc...`) nos dois — só depois disso a v0.13.0 foi
publicada. Confirmação final (instalar por cima de verdade no Android)
ainda depende do usuário testar no próprio celular.

## DECISION-044
Data: 2026-09-11
Decisão: badges de status ativo por jogador (Queimadura, Escudo...) e
efeito de campo (Tempestade Ígnea, Lava...) na cena de batalha — Bloco 9
da "Direção de produto" ("efeitos"), substituindo o texto cru
("Jogador A: Escudo") por um círculo colorido com ícone (emoji) e,
quando o efeito tem duração contada em turnos, um número pequeno com os
turnos restantes. `EffectBadgeView` (novo, `game_domain`) é o dado
puro; `status_visuals.dart` (novo, `game_presentation`) mapeia
id→ícone/cor pros 11 status de `StatusEffects` (mesmo os 9 ainda
inertes hoje) + fallback genérico pra efeito de campo sem entrada
dedicada. `BattleSceneView`/`BattleHudWidget` ganharam os campos/badges;
`TrainingMatch`/`MultiplayerMatch` ganharam os getters que os produzem.
Estilo do badge (círculo colorido simples, não a família pixel art dos
outros componentes) escolhido pelo usuário no companheiro visual de
brainstorming.
Descoberta importante: o backend do Multiplayer já mandava
`combatantStatuses` (status ativos por jogador) na resposta de
`GET /matches/:id` desde a DECISION-024 — o cliente Flutter nunca tinha
parseado esse campo. Este bloco não precisou de nenhuma mudança de
backend, só adicionar `RemoteActiveStatus`/`RemoteBattleState.combatantStatuses`
no parse do cliente.
Motivo: "efeitos" era o próximo item sem bloco dedicado na ordem de
prioridade do CLAUDE.md, e a apresentação de status/campo ativo era só
texto cru — gap de game feel já registrado no BACKLOG (a parte
"Multiplayer não recebe estados ativos do backend" estava desatualizada,
corrigida por esta descoberta).
Consequência: nenhuma lacuna nova conhecida. Fora de escopo (registrado
no BACKLOG): animação nos badges, tooltip/descrição ao tocar, ícone
dedicado por combinação futura (cai no fallback ✨ até alguém adicionar).
Testes: suíte completa do app (`flutter test`, 158 testes) e `flutter
analyze` passando. Verificado manualmente via `flutter run -d
web-server`: jogar Fogo+Vento no Treino mostrou o badge de campo
(Tempestade Ígnea) no lugar certo, entre os dois painéis do HUD, sem
erro no console — a resolução exata do emoji não foi possível conferir
a olho nesse preview (escala pequena do navegador embutido), mas está
coberta pelo teste de widget de `battle_hud_widget_test.dart`
(`find.text('🌪️')`). Badge de status (Queimadura) e a árvore de
habilidades não foram clicados manualmente nesta sessão (mesma
limitação do Bloco 8 pra localizar o ícone de Habilidades no preview
web) — coberto pelas suítes de `TrainingMatch`/`MultiplayerMatch`/
`BattleHudWidget`.

## DECISION-045
Data: 2026-09-12
Decisão: progressão persistente no Modo Treino (Bloco 10, "progressão")
— Skill Tree (por Jogador A/Jogador B) e Livro de Descobertas
(compartilhado, mesmo comportamento de sempre dentro de uma partida)
passam a sobreviver a "Nova partida" e a fechar/reabrir o app, via
`shared_preferences` (novo pacote), local ao aparelho, sem rede, sem
custo. `TrainingMatch` ganhou `fromPersistedProgress` (monta a partida
a partir de ids crus persistidos) e `startNewBattleKeepingProgress`
(reseta HP/turno/campo mas mantém progresso) em vez da UI montar
`SkillProgress`/`DiscoveryBook` diretamente — mantém a regra de que
`training_screen.dart` nunca nomeia um tipo do `battle_engine`
(DECISION-011/017), ajuste descoberto revisando o código real antes de
escrever o plano. Detalhe corrigido de passagem: o HP inicial de uma
partida seedada com progresso já soma `grantedMaxHpBonus` do progresso
inicial (ex: Treino de Vitalidade já desbloqueado dá 120 HP desde a
primeira batalha, não só quando desbloqueado ao vivo).
Este é o primeiro de dois blocos de progressão decididos com o usuário
— o segundo (Bloco 11, Multiplayer: Skill Tree persistente + Livro de
Descobertas novo no backend via Firestore) foi separado por depender
de credenciais reais do Firebase e ter escopo bem maior. Nessa mesma
conversa, o usuário criou o projeto Firebase real (`elements-1173d`,
ver `.firebaserc`) e já criou o Firestore no console — confirmado
rodando `firebase deploy --only firestore:rules` de verdade contra o
projeto (substituindo o `demo-jogo-elementos` fake da DECISION-015).
Motivo: "progressão" era o próximo item sem bloco dedicado na ordem de
prioridade do CLAUDE.md — hoje nada sobrevivia a fechar o app (Skill
Tree/Descobertas recriados do zero a cada `TrainingMatch`).
Consequência: nenhuma lacuna nova conhecida pro Treino. Bloco 11
(Multiplayer) ainda depende de gerar a credencial de serviço do
Firebase (Admin SDK) antes de poder implementar — próximo passo.
Testes: suíte completa do app (`flutter test`, 169 testes) e `flutter
analyze` passando. Verificado manualmente via `flutter run -d
web-server` (persistência real via `localStorage` do navegador):
descobrir Tempestade Ígnea, recarregar a página do zero (nova sessão
Flutter), "Descobertas: 1/3" continuou depois do reload. Desbloqueio de
Skill Tree não foi clicado manualmente (mesma limitação recorrente
desta sessão pra localizar o ícone de Habilidades no preview web) —
coberto pelo teste de widget novo (`training_screen_test.dart`,
progresso pré-populado via `SharedPreferences.setMockInitialValues`).

## DECISION-046
Data: 2026-09-14
Decisão: custo de AP (pontos de ação) pra combinar 2-3 elementos numa
mesma jogada (Bloco 2a) — fora da ordem de prioridade do CLAUDE.md,
implementado a pedido direto do usuário depois de jogar de verdade e
achar os combos fáceis demais de spammar. `ApPool{max: 5, current}`
(novo, espelhado em `battle_engine`/Dart e `backend/src/battle-rules/`/
TypeScript, regra do CLAUDE.md) por jogador em `BattleState.ap`; regenera
+1 no início do próprio turno (acumula entre turnos, não recarrega
tudo de uma vez — opção B escolhida pelo usuário entre três propostas
de tuning, "carga pesada", contra minha recomendação da opção A);
combinar 2 elementos custa 3 AP, 3 elementos custam 5 AP; sem AP
suficiente, a jogada inteira é rejeitada (nenhum AP gasto, sem dano,
turno não passa) — `StateError`/`TurnValidationError`. Jogar um único
elemento passou a ser sempre de graça (0 AP) e causar 5 de dano básico
direto no oponente (sujeito a bloqueio por Escudo, igual dano de combo)
em vez de não fazer nada — antes disso, um elemento sozinho existia só
como isca pra Mutations/AbilityEngine, sem efeito ofensivo próprio.
Cliente (Treino e Multiplayer) ganhou pips de AP (círculos preenchidos
até o AP atual) no HUD de batalha, entre a barra de HP e os badges de
status (Bloco 9), estilo escolhido pelo usuário no companheiro visual
de brainstorming. Primeiro de quatro blocos decididos com o usuário
nessa mesma conversa (2a AP; 2b elementos começam bloqueados, a
desbloquear; 2c combos virarem "ataques" permanentes equipáveis num
loadout de 3 slots; 2d UI de batalha estilo Pokémon, dependente do 2c)
— só o 2a foi implementado aqui, 2b/2c/2d ficam no BACKLOG.
Descoberta durante o plano: a mudança quebrou a maior parte dos testes
pré-existentes de `TurnEngine`/`turn-engine.ts` e vários testes de
integração do backend/cliente que combinavam como primeira ação ou
repetidamente sem intervalo de carga — corrigidos semeando AP inicial
via parâmetro de teste (`ap:`/`initialApA`/`initialApB`, nunca usado
por código de produção) onde só um combo bastava, ou trocando por
ataques de elemento sozinho (agora com dano próprio) onde o teste
media bookkeeping (vencedor, partida encerrada) e não matemática de
combo especificamente — inclusive em arquivos fora da lista original
do plano (`ability_engine_test.dart` no Dart; `training_screen_test.dart`
tinha dois testes widget-level com o mesmo padrão de grind repetido).
`TrainingScreen._playTurn` ganhou tratamento pro novo `StateError` (que
antes não era capturado e derrubava a árvore de widgets) com mensagem
em português ("AP insuficiente para essa combinação."), sem vazar a
mensagem crua do `battle_engine`.
Motivo: jogar a versão publicada revelou que combinar 2-3 elementos
não tinha nenhum custo ou risco — o jogador ótimo sempre combina,
tornando elementos sozinhos inúteis e a decisão tática (quando arriscar
um combo vs. jogar seguro) inexistente.
Consequência: nenhuma lacuna nova conhecida pro 2a. Blocos 2b/2c/2d
ainda não iniciados, dependem de decisões de design próprias (quais
elementos começam bloqueados e como desbloquear; mecânica de conversão
combo→ataque equipável; nova tela de batalha estilo Pokémon).
Testes: suíte completa de `battle_engine` (`dart analyze` limpo,
`dart test`, 196 testes), backend (`npx tsc --noEmit` limpo, `npm
test`, 140 testes) e app (`flutter analyze` limpo, `flutter test`, 174
testes) passando. Verificado manualmente via `flutter run -d
web-server` (reinício completo do preview) no Modo Treino: jogar um
elemento sozinho causou dano (barra de HP do oponente moveu) e acendeu
1 pip de AP; tentar Fogo+Vento com menos de 3 AP mostrou "AP
insuficiente para essa combinação." e o turno não passou (mesmo
jogador, mesma HP); carregar AP com jogadas de elemento sozinho e
tentar o combo de novo funcionou — Tempestade Ígnea disparou, 20 de
dano, pips de AP desceram refletindo o gasto (4 acumulados, 3 gastos, 1
restante). Nenhum erro no console do navegador.

## DECISION-047
Data: 2026-09-14
Decisão: elementos bloqueados no Modo Treino (Bloco 2b) — segundo dos
quatro blocos combinados com o usuário junto do Bloco 2a
(DECISION-046). Cada jogador (Jogador A e Jogador B, independentemente)
escolhe **2 elementos iniciais**, uma vez só, na primeira vez que abre
o Modo Treino, via `ElementStarterScreen` (nova, tela cheia bloqueante,
mesmo padrão do `UpdateGateScreen`). Os outros 8 elementos começam
bloqueados e se desbloqueiam via um novo tipo de `SkillGrant`
(`ElementUnlock`/`ElementUnlocks`, `packages/battle_engine`), com uma
nova branch "elementos" em `defaultSkillTree` (10 nós, sem
pré-requisito entre si — o jogador escolhe livremente qual desbloquear
a seguir). Diferente dos nós existentes (instantâneos assim que o
pré-requisito é satisfeito), desbloquear um nó de elemento exige
também um número crescente de turnos cumulativos jogados por aquele
jogador: `(E-1) × 10`, `E` = quantos elementos esse jogador já tem
(contando os 2 iniciais) — 10 turnos pro 3º elemento, 20 pro 4º, 30
pro 5º. Esse contador é persistido (`TrainingProgressStore`, chave
nova `training_turns_played_<slot>`) e não reseta em "Nova partida",
mesma regra da Skill Tree/Livro de Descobertas.
Só Modo Treino — Multiplayer aguarda o Bloco 11 (persistência real) pra
não reintroduzir o problema que o Bloco 10 já resolveu só pro Treino.
Nada neste bloco toca `BattleState`/`TurnEngine` (Dart) nem
`backend/src/battle-rules/` (TypeScript) — o gate de turnos vive
inteiramente em `TrainingMatch` (Game Domain), a única camada que
conhece contagem cumulativa persistida entre partidas.
`SkillTreeScreen` (compartilhada com o Multiplayer) ganhou um hook
opcional `extraLockedHint` pra mostrar "Faltam N turnos." no lugar do
botão "Desbloquear" — o Multiplayer nunca passa esse parâmetro, então
seu comportamento fica inalterado.
Descoberta durante o plano: a mesma classe de ripple do Bloco 2a se
repetiu — quase todo teste existente de `TrainingMatch`/`TrainingScreen`
jogava elementos partindo do pressuposto de que estavam sempre livres;
corrigido semeando `initialProgressA`/`B` (ou `SharedPreferences` já
com elementos escolhidos) em cada teste afetado, com um helper
compartilhado (`_allElementsUnlocked()`) pros testes que não são
especificamente sobre o novo bloqueio. Um bug real foi pego pelo
próprio teste de onboarding, não pelo plano: `ElementStarterScreen` sem
`Key` fazia o Flutter reaproveitar o mesmo `State` (e a seleção
`_selectedIds`) entre a tela do Jogador A e a do Jogador B — corrigido
com `key: ValueKey(_pendingOnboardingSlot)`.
Motivo: sequência já combinada com o usuário desde o Bloco 2a — dar
progressão real ao "quais elementos eu posso jogar", não só ao "quanto
custa combinar".
Consequência: nenhuma lacuna nova conhecida pro 2b. Blocos 2c (ataques
equipáveis) e 2d (UI estilo Pokémon) continuam no BACKLOG, dependem de
decisões de design próprias ainda não feitas.
Testes: suíte completa de `battle_engine` (`dart analyze` limpo, `dart
test`, 205 testes) e app (`flutter analyze` limpo, `flutter test`, 191
testes) passando. Verificado manualmente via `flutter run -d
web-server` (reinício completo do preview, sessão de navegador sem
progresso salvo): a tela de escolha inicial apareceu pro Jogador A
(Fogo+Vento escolhidos), depois pro Jogador B (Água+Raio, confirmando
que os dois jogadores escolhem de forma independente — o bug do `Key`
foi justamente pego aqui), só então o jogo normal apareceu; no picker
de elementos, Fogo/Vento apareceram normais e Água (entre outros)
apareceu com cadeado e não reagiu ao toque; jogar Fogo sozinho causou
5 de dano e acendeu 1 pip de AP. Não foi possível clicar no ícone de
Habilidades no preview web (mesma limitação recorrente desta sessão,
já registrada nas DECISION-044/045) — a mensagem "Faltam N turnos."
não foi conferida a olho, mas está coberta pelo teste de widget novo
de `skill_tree_screen_test.dart`. Nenhum erro no console do navegador.

## DECISION-048
Data: 2026-09-15
Decisão: ataques combinados equipáveis no Modo Treino (Bloco 2c) —
terceiro dos quatro blocos combinados com o usuário desde o Bloco 2a
(DECISION-046/047). A primeira vez que um jogador dispara uma
combinação (2-3 elementos) vira um "ataque" pessoal permanentemente
desbloqueado pra esse jogador — até 3 podem estar "equipados" ao mesmo
tempo; só um ataque equipado pode ser jogado de novo. Nova classe
`AttackLoadout` (`packages/battle_engine`), imutável, por jogador,
deliberadamente separada do `DiscoveryBook` compartilhado existente
(que não muda — continua só meta-progressão, alimentando "Descobertas:
X/Y"): `unlockedCombinationIds` (Set) + `equippedCombinationIds` (List,
máx 3). `withUnlocked(id)` marca desbloqueado e equipa automático se
houver vaga livre (<3); `withEquipped(ids)` substitui a lista de
equipados, lançando `ArgumentError` pra mais de 3 ids ou pra um id
ainda não desbloqueado. `TrainingMatch.playElementIds` ganha uma nova
checagem — via `defaultCombinationBook.resolve(elements)`, antes de
montar a `Ability` — que lança `StateError` (mensagem em português, ex:
"Tempestade Ígnea não está equipado. Troque na janela de Ataques
Combinados.") se a combinação já foi desbloqueada mas não está
equipada; a jogada fica um no-op completo (sem gastar AP, sem passar o
turno), mesmo padrão de "AP insuficiente"/"elemento bloqueado". Quando
as 3 vagas já estão cheias no momento do desbloqueio, a nova combinação
fica desbloqueada mas não equipada, e a `TrainingScreen` abre a tela
"Ataques Combinados" (`AttacksScreen`, nova) automaticamente, com o
combo recém-desbloqueado em destaque, pedindo a troca; com vaga livre,
o equipar é automático e some um texto inline ("Novo ataque
desbloqueado: X! (equipado automaticamente)"), sem abrir tela nova. A
mesma `AttacksScreen` é reaproveitada pros dois fluxos — abertura
automática (com `highlightComboId`) e gerenciamento manual via um novo
ícone (`Icons.flash_on`, tooltip "Ataques Combinados") na AppBar.
Getters/setter novos em `TrainingMatch` são todos diretos por jogador
(`unlockedAttackIdsForPlayerA`/`B`, `equippedAttackIdsForPlayerA`/`B`,
`setEquippedAttacks({required forPlayerA, required combinationIds})`) —
não "do jogador da vez atual", porque no momento em que a
`TrainingScreen` decide abrir a troca automática (dentro de
`_playTurn`, depois que `playElementIds` já passou o turno), "o
jogador da vez" já é o oponente de quem acabou de desbloquear; um
`_currentLoadout` privado, só pra uso interno em `playElementIds` (que
roda antes do turno passar), é a única exceção "current player".
Persistência nova em `TrainingProgressStore`:
`training_attacks_unlocked_<slot>`/`training_attacks_equipped_<slot>`,
mesmo padrão de `SharedPreferences.getStringList`/`setStringList` já
usado pros outros progressos do Treino.
Só Modo Treino — Multiplayer aguarda o Bloco 11 (persistência real),
mesma razão dos Blocos 2b/10. Nada neste bloco toca
`BattleState`/`TurnEngine` (Dart) nem `backend/src/battle-rules/`
(TypeScript) — o gate vive inteiramente em `TrainingMatch`.
Dois ajustes descobertos rodando os testes de `AttacksScreen`, fora do
sketch original do plano: o indicador visual de "equipado" virou um
ícone (não mais texto concatenado ao nome, que quebrava finders de
texto exato), e a lista de ataques desbloqueados some enquanto um modal
(desequipar/trocar) está aberto — sem isso, o nome de um ataque já
equipado aparecia duas vezes na árvore de widgets (tile de fundo +
botão do modal), ambíguo pra `find.text`.
Diferente dos Blocos 2a/2b, o ripple em testes pré-existentes foi
mínimo — nenhum teste de `training_match_test.dart` jogava a mesma
combinação duas vezes pro mesmo jogador antes deste bloco, então o
auto-equipar nunca colidiu com nada já escrito; só duas chamadas
pré-existentes de `fromPersistedProgress` (em testes de
`fromPersistedProgress`/Bloco 2b) precisaram dos 4 novos parâmetros
required.
Motivo: sequência já combinada com o usuário desde o Bloco 2a — dar
peso de progressão real às combinações descobertas, não só registrar
que existem.
Consequência: fecha a sequência. Bloco 2d (UI de batalha estilo
Pokémon) é o próximo e último, consumindo
`equippedAttackIdsForPlayerA`/`B` pra montar os botões de ação do
turno. Multiplayer com ataques equipáveis aguarda o Bloco 11.
Testes: suíte completa de `battle_engine` (`dart analyze` limpo, `dart
test`, 213 testes) e app (`flutter analyze` limpo, `flutter test`, 214
testes) passando. Verificado manualmente via `flutter run -d
web-server` (reinício completo do preview): disparar Fogo+Vento pela
primeira vez (depois de acumular AP com jogadas de elemento sozinho)
mostrou "Última combinação: Tempestade Ígnea" e "Novo ataque
desbloqueado: Tempestade Ígnea! (equipado automaticamente)" inline, sem
abrir tela nova; o ícone novo na AppBar abriu "Ataques Combinados"
mostrando Tempestade Ígnea marcado como equipado (ícone de check);
desequipar manualmente funcionou (fundo da lista some enquanto o modal
de desequipar está aberto, confirma visualmente); tentar montar
Fogo+Vento de novo mostrou "Tempestade Ígnea não está equipado. Troque
na janela de Ataques Combinados." e o turno não passou. O cenário de
"3 vagas cheias abre a troca sozinha" não foi reproduzido manualmente
— o jogo só tem 3 combinações reais definidas hoje, insuficiente pra
encher 3 vagas e ainda sobrar uma 4ª real pra descobrir em uma sessão
de verificação manual — mas está coberto pelos testes automatizados de
`training_match_test.dart` e `training_screen_test.dart` (que usam ids
sintéticos como preenchimento, já que `AttackLoadout` não valida que um
id equipado corresponda a uma combinação real). Nenhum erro no console
do navegador.
