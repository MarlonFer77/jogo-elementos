# DECISIONS.md

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
