# ARCHITECTURE.md

Arquitetura atual do projeto. Atualizar somente quando a arquitetura mudar de fato.

## Estrutura de pastas (monorepo)

```
game/
  packages/
    battle_engine/   # Dart puro — domínio de batalha (elementos, combinações,
                     # estados, dano, turnos). Sem dependência de Flutter/Flame.
                     # Testável com `dart test`, sem SDK do Flutter instalado.
  app/               # App Flutter (mobile). Consome battle_engine via path dependency.
                     # Plataformas: web, windows (as únicas com toolchain
                     # instalado nesta máquina; android/ios habilitam-se depois
                     # com `flutter create --platforms=android,ios .`)
  backend/           # Node.js + TypeScript. Autoridade sobre partidas multiplayer.
                     # (ainda não criado — será criado quando uma tarefa exigir backend)
  CLAUDE.md
  ARCHITECTURE.md
  TASKS.md
  DECISIONS.md
```

## Camadas (mobile)

```
Flutter (UI / Navegação)      → app/lib/ui/
  ↓
Game Presentation   → widgets, telas, Flame components (renderização da batalha)
                       → app/lib/game_presentation/
  ↓
Game Domain         → orquestra partida, Skill Tree, builds, integra com backend
                       → app/lib/game_domain/
  ↓
Battle Engine        → regras puras: elementos, combinações, efeitos, estados,
                       dano, turnos. Sem Flutter, sem Flame, sem I/O.
                       → packages/battle_engine
```

O Battle Engine é o núcleo testável isoladamente. Game Domain decide *quando*
chamar o Battle Engine; Game Presentation decide *como* mostrar o resultado.
UI (`app/lib/ui/`) nunca importa `package:battle_engine` diretamente — sempre
passa pelo Game Domain (`app/lib/game_domain/`), mesmo quando o wrapper é fino.

## App Flutter (app/)

- `lib/main.dart`: `GameApp` (MaterialApp) → `HomeScreen`.
- `lib/game_domain/element_catalog.dart`: `ElementCatalog.all()` →
  `List<ElementOption>` (id/nome/símbolo) — tipo próprio da Game Domain, não
  `Element` do `battle_engine`, pra UI nunca precisar nomear/importar esse
  tipo nem implicitamente (ver DECISION-011/017).
- `lib/game_domain/battle_view.dart`: `BattleView` — projeção somente-leitura
  de um `BattleState` (nomes dos jogadores, turno atual, nomes dos efeitos de
  campo ativos) para a camada de apresentação.
- `lib/game_domain/demo_battle.dart`: `DemoBattle.start()` — roda uma
  batalha fixa via `TurnEngine` (Ana joga Fogo+Vento) e devolve o
  `BattleView` resultante. Prova de conceito da integração com o Flame, não
  o modo de jogo real.
- `lib/game_domain/skill_tree_catalog.dart`: `SkillNodeOption` (id/nome/
  descrição/branch) — mesmo padrão de `ElementOption`, pra UI nunca nomear
  `SkillNode` do `battle_engine`. `availableSkillNodeOptions(unlockedNodeIds)`
  — dado uma lista de ids desbloqueados (do jeito que o Multiplayer os
  manda, crus), devolve os nós desbloqueáveis com nome/descrição/branch,
  montando um `SkillProgress` local só pra consultar a mesma
  `defaultSkillTree` que o backend espelha (ver DECISION-025/026) — mesmo
  raciocínio do `CombinationCatalog` pra combinações.
- `lib/game_domain/training_match.dart`: `TrainingMatch` — o modo treino de
  verdade: batalha local, offline, hotseat (os dois lados jogados no mesmo
  aparelho), sem IA. Cada jogador tem seu próprio `SkillProgress` sobre
  `defaultSkillTree` (independente do outro) e pode desbloquear nós na
  própria vez (`unlockSkillForCurrentPlayer`). Toda `Mutation`/
  `CombinationModifier` já desbloqueada se aplica automaticamente em toda
  ação seguinte: `playElementIds` monta um `Ability` novo a cada turno
  (elementos escolhidos na hora + `grantedMutations` do jogador), embrulha
  num `Build` (validado — sempre válido aqui, já que vem direto do que foi
  concedido) e chama `AbilityEngine.useAbility`. Envolve `BattleState` +
  `AbilityEngine` + `SkillProgress` + `Build` + `DiscoveryBook`, mas só
  expõe tipos simples (`String`/`int`/`SkillNodeOption`) — nunca um tipo do
  `battle_engine` — `currentTurnName`, `playerAStatusNames`/
  `playerBStatusNames`, `activeFieldEffectNames`,
  `lastTriggeredCombinationName`, `lastAppliedStatusNames`,
  `discoveredCount`, `totalCombinationsCount`,
  `availableSkillNodesForCurrentPlayer`,
  `unlockedGrantNamesForCurrentPlayer`, `unlockSkillForCurrentPlayer`,
  `playElementIds`. HP: começa em 100 + `grantedMaxHpBonus` de cada
  jogador (`playerAMaxHp`/`playerACurrentHp`/`playerBMaxHp`/
  `playerBCurrentHp`); `winnerName`/`isOver` refletem `BattleState.winner`.
  Se o nó desbloqueado concede `MaxHpBonus`, `unlockSkillForCurrentPlayer`
  chama `BattleState.withMaxHpIncreased` na hora — o bônus vale
  imediatamente, não só na próxima ação.
- `lib/game_presentation/battle_game.dart`: `BattleGame extends FlameGame` —
  renderiza um `BattleView` (nomes dos jogadores, turno, efeitos de campo)
  como `TextComponent`s. Sem regra de jogo nenhuma — só desenha o que recebe.
- `lib/ui/home_screen.dart`: lista os elementos, com botões pra
  `BattleScreen` (demo do Flame) e `TrainingScreen` (jogo de verdade).
- `lib/ui/battle_screen.dart`: hospeda o `BattleGame` num `GameWidget`.
- `lib/ui/training_screen.dart`: **primeira tela realmente jogável do
  projeto** — `StatefulWidget` com `setState` (sem lib de state management;
  não se justifica ainda pra uma tela isolada). `TrainingScreen({initialMatch})`
  aceita um `TrainingMatch` opcional (testabilidade — injeta uma partida já
  num estado específico sem precisar simular toques). Chips de elemento
  (`FilterChip`, até 3 selecionados), botão "Jogar" desabilitado até
  selecionar pelo menos 1, mostra de quem é a vez, HP e estados ativos de
  cada jogador, campo ativo, última combinação, efeitos aplicados no
  oponente e progresso do Livro de Descobertas. Quando `_match.isOver`, o
  formulário de jogada é trocado por "Fim de partida! Vencedor: X" + botão
  "Nova partida" (recria o `TrainingMatch`). Botão "Habilidades" na AppBar
  abre um `showModalBottomSheet` (altura fixa, 60% da tela, com a lista de
  nós num `ListView` rolável e "Fechar" sempre visível — evita overflow
  conforme a árvore cresce) listando os nós desbloqueáveis do jogador da
  vez (`availableSkillNodesForCurrentPlayer`) — desbloquear atualiza a
  lista na hora (via `StatefulBuilder` dentro do sheet + `setState` do
  widget pai).
- `lib/game_domain/multiplayer_models.dart`: `RemoteFieldEffect`/
  `RemoteHpPool`/`RemoteBattleState`/`RemoteMatch`/`SubmitTurnResult` —
  mirrors diretos do JSON servido por `backend/src/battle-rules`/
  `backend/src/matches` (não tipos do `battle_engine`: essa engine não roda
  no cliente do Multiplayer — o backend é a única autoridade, ver seção
  Multiplayer abaixo).
- `lib/game_domain/multiplayer_exception.dart`: `MultiplayerException`
  (mensagem + status HTTP opcional).
- `lib/game_domain/multiplayer_client.dart`: `MultiplayerClient` — um
  método por rota (`createMatch`/`joinMatch`/`getMatch`/`submitTurn`),
  `package:http` injetável (testes usam `http/testing.dart`'s `MockClient`,
  sem servidor real). Resposta HTTP fora de 2xx vira `MultiplayerException`
  com a mensagem `error` do corpo.
- `lib/game_domain/multiplayer_config.dart`: `defaultMultiplayerBaseUrl` —
  aponta pro backend implantado de verdade no Render
  (`https://jogo-elementos-backend.onrender.com`, free tier — ver
  DECISION-028), não pro `localhost:3000` do `npm run dev`. Pra
  desenvolver contra o backend local, passar um `MultiplayerClient` com
  `baseUrl` explícito (toda tela que aceita um já suporta isso — mesmo
  padrão do `initialMatch`/`client` opcional nas telas de Multiplayer).
- `lib/game_domain/multiplayer_match.dart`: `MultiplayerMatch` — visão de
  uma partida a partir de um jogador (`localPlayerId`): `create`/`join`/
  `reconnect`/`refresh`/`playElementIds` chamam o `MultiplayerClient` e
  guardam o último `RemoteMatch`; getters traduzem `playerAId`/`playerBId`
  pra "eu"/"oponente" (`myCurrentHp`/`opponentCurrentHp`/`isMyTurn`/
  `amIWinner`...). Nunca calcula dano/turno/vitória — só lê o que o
  servidor já decidiu. `refresh` engole `MultiplayerException` (chamada
  usada em polling — uma falha de rede não deve derrubar a tela, só tenta
  de novo no próximo tick); `playElementIds` propaga o erro (`lastError`)
  pra UI reagir. `reconnect` é um `GET` puro (não muda quem é playerA/
  playerB no servidor) que valida localmente se `localPlayerId` é mesmo
  `playerAId`/`playerBId` da partida buscada, já que o backend não checa
  isso num `GET` (ver DECISION-022). `startRematch` devolve um
  `MultiplayerMatch` **novo** (mesmo `localPlayerId`, `create()` chamado
  por baixo) — não muta a instância atual, que continua representando a
  partida finalizada (ver DECISION-023). `unlockedNodeIdsForMe` (ids crus
  — sem tipo do `battle_engine`, mesma regra da classe inteira) +
  `unlockSkill(nodeId)` (`POST .../skills/unlock`, só funciona na vez do
  jogador local — validado pelo servidor, ver DECISION-025/026).
- `lib/game_domain/combination_catalog.dart`: `CombinationCatalog.byId` —
  mapeia o `id` de um `FieldEffect`/combinação (única coisa que o backend
  manda) pro nome/descrição de exibição, lendo `defaultCombinationBook` do
  `battle_engine` só como dado estático (catálogo, não lógica de jogo) —
  igual ao comentário em `backend/src/battle-rules/types.ts` já previa
  ("o cliente já tem isso pelo próprio catálogo").
- `lib/ui/home_screen.dart`: lista os elementos, com botões pra
  `BattleScreen` (demo do Flame), `TrainingScreen` (modo treino local) e
  `MultiplayerLobbyScreen` (multiplayer de verdade).
- `lib/ui/battle_screen.dart`: hospeda o `BattleGame` num `GameWidget`.
- `lib/ui/training_screen.dart`: **primeira tela realmente jogável do
  projeto** — `StatefulWidget` com `setState` (sem lib de state management;
  não se justifica ainda pra uma tela isolada). `TrainingScreen({initialMatch})`
  aceita um `TrainingMatch` opcional (testabilidade — injeta uma partida já
  num estado específico sem precisar simular toques). Chips de elemento
  (`FilterChip`, até 3 selecionados), botão "Jogar" desabilitado até
  selecionar pelo menos 1, mostra de quem é a vez, HP e estados ativos de
  cada jogador, campo ativo, última combinação, efeitos aplicados no
  oponente e progresso do Livro de Descobertas. Quando `_match.isOver`, o
  formulário de jogada é trocado por "Fim de partida! Vencedor: X" + botão
  "Nova partida" (recria o `TrainingMatch`). Botão "Habilidades" na AppBar
  abre um `showModalBottomSheet` (altura fixa, 60% da tela, com a lista de
  nós num `ListView` rolável e "Fechar" sempre visível — evita overflow
  conforme a árvore cresce) listando os nós desbloqueáveis do jogador da
  vez (`availableSkillNodesForCurrentPlayer`) — desbloquear atualiza a
  lista na hora (via `StatefulBuilder` dentro do sheet + `setState` do
  widget pai).
- `lib/ui/multiplayer_lobby_screen.dart`: `MultiplayerLobbyScreen` —
  campo de nome (é a identidade do jogador, sem login — ver DECISION-016) +
  "Criar partida" (mostra o código pra compartilhar); campo de código com
  dois botões, "Entrar com código" (novo playerB, via `POST .../join`) e
  "Reconectar" (via `GET /matches/:id` — mesmo nome + código de uma partida
  da qual o jogador já faz parte; único jeito de voltar a uma partida em
  andamento depois de fechar/recarregar a aba, já que não existe sessão pra
  retomar sozinho — ver DECISION-022). `MultiplayerMatch.reconnect` rejeita
  localmente (`MultiplayerException`) se o nome digitado não for
  `playerAId`/`playerBId` daquela partida — o backend não valida isso
  sozinho num `GET`. Erro do backend (ex: código não encontrado) aparece
  inline. Aceita um `MultiplayerClient` opcional (testabilidade, mesmo
  padrão do `initialMatch` do Modo Treino).
- `lib/ui/multiplayer_battle_screen.dart`: `MultiplayerBattleScreen` — só é
  alcançável depois de criar/entrar numa partida. Um `Timer.periodic`
  (padrão 2s, parâmetro `pollInterval` pros testes) chama
  `MultiplayerMatch.refresh` e para sozinho quando a partida termina;
  cancelado em `dispose`. Três estados de tela: aguardando oponente (mostra
  o código), em progresso (chips + HP de cada lado + campo ativo, chips e
  "Jogar" desabilitados quando não é a vez do jogador local) e fim de
  partida ("Você venceu!"/"Você perdeu." + botão "Revanche"). "Revanche"
  chama `MultiplayerMatch.startRematch` (cria uma partida nova pro mesmo
  jogador, `waiting_for_opponent` — não existe "reset" no backend, uma
  `Match` `finished` fica `finished` pra sempre) e navega via
  `pushReplacement` pra um novo `MultiplayerBattleScreen` com o novo
  código; a partida antiga não é alterada. Botão "Habilidades" na AppBar
  (só visível com a partida em progresso) abre o mesmo tipo de
  `showModalBottomSheet` da `TrainingScreen`, mas cada nó listado vem de
  `availableSkillNodeOptions(_match.unlockedNodeIdsForMe)` e só aparece
  se for a vez do jogador local (senão a mensagem é "Só dá pra
  desbloquear na sua vez" — o servidor rejeitaria de qualquer jeito, isso
  só evita uma chamada fadada ao erro); "Desbloquear" chama
  `MultiplayerMatch.unlockSkill` de verdade contra o backend, e a lista
  atualiza na hora (`setSheetState` + `setState` do widget pai, mesmo
  padrão da `TrainingScreen`) — um erro do backend (ex: a vez mudou
  enquanto o modal estava aberto) aparece como `SnackBar`, não derruba o
  modal. Ver DECISION-025/026. O código novo precisa ser
  compartilhado com o amigo de novo, mesmo jeito que o primeiro (sem
  matchmaking — ver DECISION-023).
- `.claude/launch.json` (raiz do projeto, fora de `app/`): configs
  `app-web` (`flutter run -d web-server --web-port 5000` a partir de
  `game/app`) e `backend-dev` (`npm run dev` a partir de `game/backend`,
  porta 3000) — pra pré-visualizar o app e o backend juntos no navegador.
  O Multiplayer só funciona de verdade com os dois rodando ao mesmo tempo.
- Dependências: `flame` (open source), `http` (open source, cliente HTTP
  usado só pelo Multiplayer) — ambas via `flutter pub add`.

## Battle Engine (packages/battle_engine)

- **Element**: representa um elemento (id, nome, ícone/símbolo). Data-driven —
  novos elementos são dados, não código novo.
- **ElementCombination**: regra que mapeia um conjunto de elementos (2 ou 3) para
  um `FieldEffect` resultante (`.result`), incluindo `damage` (int, default 0
  — repassado pro `FieldEffect`). Resolução de combinação é modificável por
  build via `CombinationModifier` (ver abaixo). `defaultCombinationBook`:
  Tempestade Ígnea/Campo Eletrocutado (2 elementos) causam 20 de dano;
  Lava (3 elementos) causa 35 — combinação mais difícil de formar paga mais.
- **CombinationBook**: resolve um conjunto de elementos para a `ElementCombination`
  correspondente (ou null), independente da ordem informada.
- **FieldEffect**: efeito nomeado ativo no campo, não ligado a um combatente
  específico. É o formato comum usado tanto por combinações elementais
  (`ElementCombination.result`) quanto por mutações de habilidade. Campos:
  `area`/`duration` (magnitudes abstratas) e `damage` (int, default 0) — o
  dano é aplicado **uma vez**, no momento em que a combinação dispara, não
  enquanto o efeito continua no campo (Lava não continua queimando a cada
  turno só por estar em `activeFieldEffects`).
- **Combatant**: participante da batalha (id, nome). Identidade por id.
- **HpPool**: `max`/`current` imutáveis. `withDamage` (clampa em 0, rejeita
  valor negativo — sem cura neste motor), `withMaxIncreased` (soma em `max`
  **e** `current` — fica mais forte na hora, não só com teto mais alto).
- **BattleState**: snapshot imutável da partida — playerA, playerB, turno atual
  (`currentTurn`), efeitos de campo ativos (`activeFieldEffects`, lista de
  `FieldEffect`), HP de cada combatente (`hp: Map<Combatant, HpPool>`, via
  `hpOf`) e `winner` (`Combatant?`, `null` enquanto a partida não acabou).
  `copyWith`/`withFieldEffect`/`withDamage`/`withMaxHpIncreased` derivam
  novos estados sem mutar o anterior; `opponentOf` retorna o outro
  participante. `BattleState.start` aceita `playerAMaxHp`/`playerBMaxHp`
  opcionais (default 100, visível na assinatura — conveniência pra testes
  que não testam HP; código de produção sempre passa o valor calculado).
  `withDamage` seta `winner` (o oponente do alvo) quando o HP chega a 0 —
  nunca sobrescreve um `winner` já definido.
- **TurnAction**: um turno = um `Combatant` joga 1 a 3 `Element`s.
- **TurnEngine**: recebe `BattleState` + `TurnAction` e devolve um `TurnResult`
  (novo estado + combinação disparada, se houver). Rejeita a ação se a
  partida já tem `winner` ou se não é a vez do ator (`StateError`), resolve
  combinação via `CombinationBook` quando 2–3 elementos são jogados, aplica
  `combinationModifiers` ao `FieldEffect`, adiciona o efeito ao campo e
  aplica o dano (`FieldEffect.damage`) no oponente — bloqueado inteiramente
  por um Escudo ativo (`StatusEffects.shield`, consumido no processo).
  Depois passa o turno e tickeia automaticamente os estados dos dois
  combatentes, aplicando `damagePerTick` de cada um ainda ativo (inclusive
  no tick que expira o estado). Se os dois chegassem a 0 HP na mesma
  resolução, quem jogou o turno vence o desempate (a ordem de tick processa
  o oponente antes do ator — ver DECISION-019). Não conhece Skill Tree/Build
  (mutações/modificadores são passados de fora) nem o backend.
- **StatusEffect** / **StatusEffects**: definição data-driven de estado
  (Burn, Freeze, Wet, Poison, Shock, Slow, Shield, Silence, Buff, Debuff,
  AreaEffect), igual ao padrão de `Element`/`Elements`.
- **ActiveStatus**: instância de um `StatusEffect` aplicada a um alvo, com
  duração em turnos (`turnsRemaining`; `null` = permanente até ser removido
  explicitamente) e `damagePerTick` (int, default 0 — quem aplica decide o
  valor, não é fixo por tipo de `StatusEffect`). `tick()` decrementa
  (preservando `damagePerTick`); `isExpired` indica remoção.
- `BattleState` guarda `combatantStatuses` (estado por combatente) com
  `statusesOf`, `hasStatus`, `withStatusApplied`, `withStatusRemoved` e
  `withStatusesTicked` — chamado automaticamente pelo `TurnEngine` a cada
  `playTurn` (fechou a lacuna "sem integração automática" da tarefa de
  Estados). Congelar/Silenciar/Lentidão/Buff/Debuff ainda não têm
  comportamento (não bloqueiam ação nem alteram nada) — só dano por tick
  (Burn/Poison, via `damagePerTick`) e Escudo (bloqueio de dano) têm efeito
  real hoje.
- **Mutation**: modificador anexável a uma `Ability` — id/nome/descrição +
  `apply(AbilityEffect) → AbilityEffect`. Nova mutação = nova instância de
  `Mutation`, sem alterar o resolver (`AbilityEngine`). `Mutations` traz as
  5 mutações de exemplo do design (Combustão, Fragmentação, Incêndio, Núcleo
  Instável — pra Bola de Fogo — e Guarda). Combustão aplica
  `ActiveStatus(burn, turnsRemaining: 2, damagePerTick: 8)` — 16 de dano
  total, os dois ticks causam dano. **Guarda** aplica `ActiveStatus(shield)`
  visando o **próprio ator**, não o oponente — a única mutação assim (ver
  `TargetedStatus` abaixo e DECISION-027).
- **TargetedStatus**/**StatusTarget**: um `ActiveStatus` emparelhado com
  quem ele mira quando `AbilityEngine` resolve — `StatusTarget.actor` ou
  `.opponent` (default). Existe porque toda mutação até a Guarda debuffava
  o oponente (Combustão), então `AbilityEngine` mirava o oponente
  incondicionalmente; um autobuff como Escudo precisa mirar quem jogou —
  ver DECISION-027 pro porquê disso ser uma mudança real de design, não só
  dado novo.
- **AbilityEffect**: acumulador imutável que as mutações vão transformando —
  `statusesToApply` (`List<TargetedStatus>`), `fieldEffect` opcional,
  `hitCount` e `critChanceBonus`. Os dois últimos ainda não são consumidos
  por nada (dar significado a eles — múltiplos hits, crítico — interage
  com Escudo de um jeito que ainda não foi desenhado) — ficam como dado
  pronto.
- **Ability**: uma habilidade = `baseElements` (1 a 3 `Element`s, jogados como
  em `TurnAction`) + lista ordenada de `Mutation`s (`withMutation` anexa sem
  mutar o original). Dois jogadores podem ter a mesma habilidade base com
  mutações diferentes.
- **AbilityEngine**: `useAbility(state, actor, ability)` — joga `baseElements`
  via `TurnEngine` (então combinações ainda disparam e o turno ainda passa),
  aplica as mutações em ordem sobre um `AbilityEffect`, adiciona o
  `fieldEffect` resultante (se houver) ao campo e aplica cada
  `TargetedStatus` de `statusesToApply` em quem ele mira — o ator
  (`StatusTarget.actor`, ex: Guarda) ou o oponente (`.opponent`, default,
  ex: Combustão). Devolve `AbilityResult` (estado, efeito acumulado,
  combinação disparada).
- **SkillNode**: nó de uma `SkillTree` — id/nome/descrição, `branch` (agrupa
  os diferentes caminhos, ex: "fogo", "precisao"), `prerequisites` (ids de
  outros nós) e `grants` (a `Mutation` desbloqueada).
- **SkillTree**: grafo data-driven de `SkillNode`s. Valida na construção:
  sem ids duplicados, sem pré-requisito para um id inexistente, sem ciclos
  (DFS). `availableFrom(unlockedIds)` lista os nós já liberados por
  pré-requisito e ainda não desbloqueados — permite múltiplos caminhos
  disponíveis ao mesmo tempo (branches independentes) e convergência (um nó
  exigindo nós de branches diferentes).
- **SkillProgress**: progresso imutável de um jogador numa `SkillTree`
  (`unlockedNodeIds`, em ordem). `canUnlock`/`unlock` (lança `StateError` se
  inválido), `availableNodes`, `grantedMutations`/`grantedCombinationModifiers`
  (deduplicados, em ordem — prontos pra anexar a uma `Ability`/`Build`) e
  `grantedMaxHpBonus` (soma de todo `MaxHpBonus` concedido, deduplicado por
  id). Dois jogadores na mesma árvore podem desbloquear nós diferentes e
  acabar com builds completamente diferentes.
- **MaxHpBonus**/**MaxHpBonuses**: modificador de HP máximo que um nó da
  Skill Tree concede — id/nome/descrição/`bonus` (int). Dado puro (sem
  função `apply`, ao contrário de `Mutation`/`CombinationModifier`) —
  `BattleState.withMaxHpIncreased` faz o trabalho, chamado por quem estiver
  orquestrando a partida (ex: `TrainingMatch`, quando o bônus é
  desbloqueado no meio da partida). `MaxHpBonuses.vitality` concede +20.
- `defaultSkillTree`: árvore de exemplo com 5 branches ("fogo", "precisao",
  "elemental", "vitalidade", "defesa" — nó "Treino de Guarda", raiz,
  concede `Mutations.guard`) reaproveitando `Mutations`/
  `CombinationModifiers`/`MaxHpBonuses` já existentes. Conteúdo real da
  árvore é responsabilidade de uma tarefa futura (conteúdo do jogo).
- **SkillGrant**: interface mínima (`String get id`) que `Mutation`,
  `CombinationModifier` e `MaxHpBonus` implementam, para que `SkillNode.grants`
  possa ser qualquer um deles sem `SkillNode`/`SkillTree` precisarem saber
  qual. `SkillProgress` filtra por tipo em `grantedMutations`/
  `grantedCombinationModifiers`/`grantedMaxHpBonus`.
- **Ability** ganhou igualdade por id (`==`/`hashCode`), consistente com o
  resto do domínio (`Element`, `Mutation`, `SkillNode`, etc.) — faltava.
- **CombinationModifier**: o ponto de extensão do design ("uma build pode
  alterar o resultado de uma combinação") — id/nome/descrição +
  `apply(FieldEffect) → FieldEffect`, mesmo princípio do `Mutation` (nova
  instância, sem branch no resolver). `CombinationModifiers` traz 2 exemplos:
  Propagação (+área) e Instabilidade (−duração).
- `TurnEngine.playTurn` ganhou o parâmetro opcional `combinationModifiers`
  (default `[]`, comportamento antigo preservado): aplica cada modificador,
  em ordem, ao `FieldEffect` de uma combinação disparada, antes de adicioná-lo
  ao campo. `AbilityEngine.useAbility` repassa o mesmo parâmetro.
- `Build` ganhou `combinationModifiers` (lista, default vazia), validada do
  mesmo jeito que `abilities`/mutações: cada modificador precisa estar em
  `skillProgress.grantedCombinationModifiers`. `withCombinationModifier`
  adiciona/substitui por id (revalida), simétrico a `withAbility`.
- Ainda fora de escopo: nós que permitem combinações de 3 elementos ou
  convertem estados diretamente — a "conversão de estado" não tem um ponto
  de extensão desenhado ainda (ver DECISION-009).
- **Build**: build de um jogador — `skillProgress` + `abilities` (lista de
  `Ability`, ids únicos). Não depende de nenhuma batalha (offline). Validado
  na construção e em toda alteração: toda `Mutation` usada por toda `Ability`
  precisa estar em `skillProgress.grantedMutations`. `abilityById`,
  `withAbility` (adiciona ou substitui por id, revalida), `withSkillProgress`
  (troca o progresso, revalida — útil após desbloquear novos nós).
- **DiscoveryEntry**/**DiscoveryBook** ("Livro de Descobertas", seção 12 —
  offline): `DiscoveryBook` guarda quais `ElementCombination`s (por
  `resultId`) o jogador já descobriu — meta-progressão, não estado de
  batalha, não depende de rede. `withDiscovered` marca uma combinação (não
  muta o original); `entriesFor(CombinationBook)` devolve um
  `DiscoveryEntry` (combinação + `discovered`) por combinação do livro, na
  ordem do livro. Ninguém chama `withDiscovered` automaticamente — é a
  camada que processa o resultado de um turno/habilidade (futura Game
  Domain) que decide atualizar o livro ao ver um `triggeredCombination`;
  `TurnEngine`/`AbilityEngine` continuam sem saber nada sobre progressão.

## Backend (backend/)

Node.js + TypeScript, sem framework HTTP (só `node:http` + um matcher de
rota bem pequeno em `src/http/route.ts` — 6 rotas com no máximo 1 segmento
dinâmico não justificam Express/Fastify ainda).

- `src/server.ts`: `createServer()` monta o `http.Server` sem dar `listen`
  (permite testar em porta efêmera). Cria um `MatchStore` novo por chamada
  (isola os testes uns dos outros). Toda resposta ganha CORS permissivo
  (`Access-Control-Allow-Origin: *`) e todo `OPTIONS` é respondido 204 sem
  bater em rota nenhuma — necessário pro app Flutter Web (origem diferente)
  poder chamar o backend; ver DECISION-021. Rotas: `GET /health`,
  `POST /battles/validate-turn`, `POST /matches`, `POST /matches/:id/join`,
  `POST /matches/:id/turns`, `GET /matches/:id`.
- `src/http/route.ts`: `matchPath(pattern, pathname)` — casamento de rota
  bem simples (sem regex, sem wildcard), só o suficiente pra `:id`.
- `src/http/respond.ts`: `sendJson`/`sendErrorResponse` — toda rota usa os
  mesmos helpers pra responder; erros com `.status` (ex: `MatchError`) usam
  esse status, o resto vira 400.
- `src/http/validation.ts`: `isNonEmptyString`, usado em toda validação de
  corpo de requisição.
- `src/index.ts`: entry point — `createServer().listen(PORT)` (`PORT` via
  env, default 3000).
- `src/battle-rules/`: mirror deliberado de parte do `battle_engine`
  (Dart) em TypeScript — validação de um `TurnAction` **e** Habilidades/
  Mutações/Skill Tree, mas não Build/edição offline (ver
  DECISION-013/014/020/024/025):
  - `types.ts`: `FieldEffect` (sem nome/descrição — o cliente já tem isso
    pelo próprio catálogo — com `damage`), `ElementCombination`, `HpPool`,
    `ActiveStatus` (sem nome/descrição — só `effectId`), `BattleState`
    (com `hp`/`combatantStatuses`/`winner`), `TurnAction`, `TurnResult`.
  - `hp-pool.ts`: `isDefeated`/`withDamage`/`withMaxIncreased` — mirror de
    `hp_pool.dart` (funções puras sobre `HpPool`, não uma classe —
    consistente com o resto do módulo).
  - `active-status.ts`: `isExpired`/`tick` — mirror de `ActiveStatus` em
    `active_status.dart` (funções puras, mesmo padrão de `hp-pool.ts`).
  - `status-effects.ts`: `SHIELD_STATUS_ID` — o único id de status que
    `turn-engine.ts` precisa conhecer por nome (Escudo bloqueia e é
    consumido); todo o resto (Queimadura incluída) é genérico via
    `damagePerTick`/`turnsRemaining`, sem checar `effectId` — mirror
    mínimo de `StatusEffects.shield` em `status_effects.dart`.
  - `ability-effect.ts`: `StatusTarget` (`"actor" | "opponent"`) +
    `TargetedStatus` (`status`/`target`) + `AbilityEffect`
    (`statusesToApply: TargetedStatus[]`/`fieldEffect`) — mirror de
    `StatusTarget`/`TargetedStatus`/`AbilityEffect` em `targeted_status.dart`/
    `ability_effect.dart`, **sem** `hitCount`/`critChanceBonus`: nenhum dos
    dois lados os consome, então carregá-los seria peso morto (ver
    DECISION-025).
  - `mutations.ts`: `Mutation` (`id` + `apply(AbilityEffect)`) +
    `combustion`/`fragmentation`/`wildfire`/`unstableCore`/`guard` +
    `mutationsById` — mirror de `Mutations` em `mutations.dart`.
    `fragmentation`/`unstableCore` são no-ops (mesmo motivo do
    `hitCount`/`critChanceBonus` acima). `guard` é a única com
    `target: "actor"` — protege quem a usa, não o oponente (ver
    DECISION-027).
  - `combination-modifiers.ts`: `CombinationModifier` (`id` +
    `apply(FieldEffect)`) + `propagation`/`volatility` +
    `combinationModifiersById` — mirror de `CombinationModifiers`.
  - `max-hp-bonuses.ts`: `maxHpBonusesById` (`{vitality: 20}`) — mirror de
    `MaxHpBonuses`.
  - `skill-tree.ts`: `defaultSkillTreeNodes` (ids/prerequisites/grant —
    mirror de `defaultSkillTree` em `default_skill_tree.dart`, sem nome/
    descrição/branch — o cliente já tem isso do próprio `battle_engine`,
    que já renderiza a árvore de verdade no Modo Treino) + `canUnlock`/
    `availableNodeIds`/`grantedMutations`/`grantedCombinationModifiers`,
    funções puras sobre um `unlockedNodeIds: string[]` fornecido pelo
    chamador (`MatchStore` é quem guarda essa lista por jogador — não
    existe uma classe `SkillProgress` mutável aqui, nem `SkillNode`/
    `SkillTree` genéricos com detecção de ciclo: essa árvore é dado
    estático confiável, já validado pelos testes do `battle_engine`, não
    algo que uma implantação normal deste backend jamais construiria em
    runtime). Ver DECISION-025 pra por que isso é uma tradução, não um
    port estrutural 1:1.
  - `combination-book.ts`: `CombinationBook.resolve` + `defaultCombinationBook`
    (mirror manual de `default_combinations.dart`, incluindo `damage`: 20
    nas combinações de 2 elementos, 35 na de 3).
  - `battle-state.ts`: `createBattleState` (valida jogadores distintos e
    `currentTurnId`; `hp` default 100/100 por jogador, `combatantStatuses`
    default vazio, `winner` default `null`) + `opponentOf` + `hpOf` +
    `withDamage` (aplica dano e define `winner` na primeira derrota, nunca
    desfaz um vencedor já definido) + `withMaxHpIncreased` +
    `statusesOf`/`hasStatus`/`withStatusApplied`/`withStatusRemoved`/
    `withStatusesTicked` — mirror dos métodos de status de `BattleState`
    em battle_engine.
  - `turn-engine.ts`: `playTurn(state, action, combinationBook,
    combinationModifiers?)` — mirror de `TurnEngine.playTurn`: roda um
    combo resolvido pelos `combinationModifiers` do ator antes de colocá-lo
    no campo, rejeita jogar se `state.winner` já estiver definido, aplica
    o dano da combinação ao oponente **a menos que Escudo bloqueie**
    (consumindo o Escudo em vez de aplicar dano), e tica todo status ativo
    dos dois combatentes ao final (`damagePerTick`, incluindo o tick que
    expira o status) — mesma ordem de resolução (`[oponente, ator]`) que
    decide empate simultâneo a favor de quem jogou o turno. Não conhece
    Mutação/`AbilityEffect` — isso é uma camada acima.
  - `ability-engine.ts`: `useAbility(state, action, combinationBook,
    mutations, combinationModifiers?)` — mirror de
    `AbilityEngine.useAbility`: chama `playTurn`, aplica cada `Mutation`
    concedida sobre um `AbilityEffect` acumulado, então aplica o
    `fieldEffect` resultante e cada `statusesToApply` no alvo que ele
    especifica (`"actor"` ou `"opponent"` — ver DECISION-027; antes dessa
    decisão isso era hardcoded pro oponente). É a peça que
    `MatchStore.applyTurn` chama de verdade — `playTurn` sozinho só é
    usado diretamente por `/battles/validate-turn` (que não tem Skill Tree
    de jogador nenhuma pra consultar, ver abaixo).
  - `errors.ts`: `TurnValidationError` (mapeia para HTTP 400).
  - `parse.ts`: `parseTurnAction`/`parseFieldEffect`/`parseHp`/`parseHpPool`/
    `parseCombatantStatuses`/`parseActiveStatus` — parsing de fronteira
    externa reaproveitado por `validate-turn` e `matches`.
- `src/http/json-body.ts`: lê o corpo da requisição como JSON, com limite de
  tamanho (guarda simples, não é rate limiting de verdade).
- `src/matches/`: estado de partida multiplayer (ver seção Multiplayer
  abaixo) — `types.ts` (`Match`, `MatchStatus` — agora com `"finished"`;
  `Match.skillProgress: Record<playerId, unlockedNodeIds[]>`, vazio pros
  dois até `join`), `errors.ts` (`MatchError`, carrega o próprio status
  HTTP), `match-store.ts` (`MatchStore`, in-memory):
  - `applyTurn` chama `ability-engine.ts`'s `useAbility` (não `playTurn`
    puro) passando `grantedMutations`/`grantedCombinationModifiers` do
    `skillProgress` do ator — toda `Mutation`/`CombinationModifier`
    desbloqueada se aplica automaticamente em toda jogada, igual ao Modo
    Treino, só que a autoridade é o servidor. Marca o match `"finished"`
    assim que `result.state.winner` é definido — daí em diante `applyTurn`
    (e `unlockSkill`) rejeitam novas ações com 409.
  - `unlockSkill(id, playerId, nodeId)`: mirror de
    `TrainingMatch.unlockSkillForCurrentPlayer`, movido pro servidor.
    Exige que seja a vez de `playerId` (mesma restrição que a UI do Modo
    Treino já tinha, agora aplicada como autoridade de verdade — não dá
    pra desbloquear pelo oponente nem fora de vez); valida `canUnlock`;
    aplica `withMaxHpIncreased` na hora se o nó conceder um `maxHpBonus`
    (mesmo comportamento "vale imediatamente" do `TrainingMatch`). Não
    passa o turno.
- `src/routes/validate-turn.ts`: `handleValidateTurn` — monta o
  `BattleState`/`TurnAction` a partir do corpo da requisição e chama
  `playTurn` **puro** (sem Mutação/Skill Tree — esse endpoint é stateless,
  não existe identidade de jogador nenhuma pra guardar `skillProgress`
  contra). Sem persistência: o cliente manda o estado inteiro a cada
  chamada, incluindo `hp`/`combatantStatuses`/`winner` se quiser
  continuidade entre chamadas (se omitidos, `createBattleState` aplica os
  defaults — então HP/status "resetam" se o chamador não mandar de volta);
  é uma ferramenta de validação pura, não o fluxo de partida real (esse é
  `src/routes/matches.ts`, que já persiste tudo no `MatchStore` entre
  chamadas, sem precisar que o cliente reenvie nada).
- `src/routes/matches.ts`: `handleCreateMatch`/`handleJoinMatch`/
  `handleGetMatch`/`handleSubmitTurn`/`handleUnlockSkill` — a API de
  multiplayer de verdade, usando `MatchStore` + `battle-rules`.
- Testes: `test/battle-rules/*` e `test/matches/*` (unitário) +
  `test/routes/*.test.ts` (integração HTTP real, porta efêmera).
- Scripts: `npm run dev` (tsx watch), `npm start`, `npm test`,
  `npm run typecheck` (`tsc --noEmit`).
- Persistência real (backend lendo/escrevendo no Firestore via Admin SDK)
  ainda não existe — só a configuração abaixo.

## Firebase (firebase/)

Estrutura mínima, free tier (Spark), **sem projeto real do Firebase criado
ainda** — usa um project id "demo" (`demo-jogo-elementos`), que o Firebase
Local Emulator Suite reconhece como projeto falso: roda 100% local, sem
login, sem cobrança, sem precisar de conta/cartão. Ver DECISION-015.

- `firebase.json`: só o emulador do Firestore + UI configurados (portas
  8080/4000). Nenhum outro produto Firebase (Auth, Functions, Hosting)
  configurado ainda — nada no projeto usa isso hoje.
- `.firebaserc`: aponta pro project id demo. Trocar para um project id real
  (via `firebase use --add`) é passo manual do usuário quando for hora de
  ter um ambiente de nuvem de verdade — criar o projeto exige login numa
  conta Google, que não é algo que possa ser feito por aqui.
- `firestore.rules`: nega tudo por padrão (`allow read, write: if false`) —
  não existe schema nem estratégia de autenticação decididos ainda; regras
  reais chegam com o schema de partida (Multiplayer).
- `firestore.indexes.json`: vazio.
- `package.json`: só `firebase-tools` como dev dependency. Scripts:
  `npm run emulators` (interativo) / `npm run emulators:ci` (roda e sai,
  para verificação automatizada).
- Emulador do Firestore exige Java 21+. Não verificado rodando de verdade
  nesta máquina — ver DECISION-015 (limitação do ambiente, não da config).

## Multiplayer

Fluxo implementado (backend/src/matches/ + backend/src/routes/matches.ts):
```
POST /matches {playerAId}              → cria partida (waiting_for_opponent)
POST /matches/:id/join {playerBId}     → entra na partida, começa a batalha
                                          (playerA joga primeiro)
POST /matches/:id/turns {actorId, elementIds} → ação de um jogador; validada
                                          e aplicada com `useAbility`
                                          (playTurn + as Mutações/
                                          CombinationModifiers já
                                          desbloqueadas pelo ator)
POST /matches/:id/skills/unlock {playerId, nodeId} → desbloqueia um nó da
                                          Skill Tree pra quem tem a vez
GET  /matches/:id                      → estado completo da partida
                                          (inclui skillProgress dos dois)
```

- `MatchStore` (in-memory, `Map` — perdido ao reiniciar o servidor;
  persistência real via Firestore é follow-up quando existir um projeto
  Firebase de verdade, ver DECISION-015/016): `create`, `get`, `join`,
  `applyTurn`, `unlockSkill`. Erros de partida (`MatchError`) carregam o
  próprio status HTTP (404 não encontrada, 409 conflito de estado, 403 não
  é participante, 400 fora de vez/nó ainda não desbloqueável).
- `Match.id`: código curto de 6 caracteres (mais fácil pra dois amigos
  compartilharem do que um UUID inteiro).
- **Reconexão**: por polling — um cliente que caiu simplesmente refaz
  `GET /matches/:id` pra resincronizar tudo (id, jogadores, status, estado).
  Não existe push em tempo real (WebSocket/SSE) ainda; se um jogador ficar
  esperando a ação do outro, precisa re-consultar. Isso é uma limitação
  aceita, não esquecida — ver DECISION-016.
- **Identidade dos jogadores**: `playerAId`/`playerBId` são só strings que o
  cliente manda — não há autenticação verificando quem é quem. Aceitável
  para "dois amigos" (seção 1 do briefing), mas não é uma garantia de
  segurança. Nenhum sistema de contas/login existe no projeto ainda.
- Sem matchmaking: quem cria a partida compartilha o `id` (o código) com o
  amigo por fora do app (mensagem, etc.) — não existe lista pública de
  partidas nem pareamento automático.
- Condição de vitória: `MatchStatus` tem `"finished"` — `applyTurn` marca o
  match assim que `useAbility`/`playTurn` define `state.winner` (dano de
  combinação, ou de status, levou algum jogador a 0 HP), e passa a
  rejeitar novas ações com 409.
- **Escudo/Queimadura**: o motor sabe processar os dois (DECISION-024), e
  Skill Tree agora é jogável de ponta a ponta (backend + app — ver
  abaixo), então os dois são alcançáveis de verdade numa partida real:
  Queimadura via Combustão, Escudo via Guarda (DECISION-027) — a única
  Mutação que mira o próprio ator, não o oponente.
- **Habilidades e Skill Tree**: `Match.skillProgress` rastreia, por
  jogador, quais nós da `defaultSkillTree` foram desbloqueados (mirror
  server-side de `SkillProgress`, ver `skill-tree.ts` acima). Só quem tem
  a vez pode desbloquear (`unlockSkill`); toda `Mutation`/
  `CombinationModifier` desbloqueada se aplica automaticamente em toda
  ação seguinte via `useAbility` — igual ao Modo Treino, mas com o
  servidor como autoridade, não o cliente. `hitCount`/`critChanceBonus`
  continuam sem efeito nenhum (nem no Dart, nem aqui — ver DECISION-025).
  **Com UI no app** (ver `MultiplayerBattleScreen` acima — botão
  "Habilidades" na AppBar, DECISION-026): verificado de ponta a ponta de
  verdade jogando pela tela — criei partida como "ana", entrei como
  "beto" via API, abri "Habilidades" na tela da Ana, desbloqueei Maestria
  da Brasa (a lista atualizou na hora, trocando por "Caminho do
  Incêndio"), joguei só Fogo, e `GET /matches/:id` confirmou Queimadura
  aplicada em "beto" (`damagePerTick: 8`).
- **Conectado ao app Flutter** (ver App Flutter acima, `lib/ui/multiplayer_*`
  + `lib/game_domain/multiplayer_*`): `MultiplayerLobbyScreen` cria/entra
  numa partida, `MultiplayerBattleScreen` joga, desbloqueia habilidades e
  faz polling a cada 2s. CORS liberado no backend
  (`Access-Control-Allow-Origin: *`, todo `OPTIONS` respondido 204)
  especificamente pra isso — o app web roda numa origem diferente da do
  backend; ver DECISION-021. Verificado de ponta a ponta com o backend
  (`npm run dev`) e o app (`flutter run -d web-server`) rodando de
  verdade, duas abas do navegador como "ana" e "beto": criar, entrar,
  Fogo+Vento causou 20 de dano ("Campo: Tempestade Ígnea" exibido via
  `CombinationCatalog`) e a outra aba pegou a atualização sozinha, via
  polling, sem recarregar.
- **Implantado de verdade**: backend rodando no Render
  (`jogo-elementos-backend`, free tier, região Virginia) —
  `https://jogo-elementos-backend.onrender.com`. O app já aponta pra lá
  por padrão (`defaultMultiplayerBaseUrl`), então Multiplayer funciona sem
  ninguém rodar `npm run dev`. Ver DECISION-028 pro código-fonte
  (repositório GitHub público, só pra viabilizar o deploy — ver a
  decisão), free tier e suas limitações (hiberna após ~15min ocioso).
  O app Flutter em si **não** está implantado em lugar nenhum ainda — só
  o backend; jogar de verdade com um amigo remoto ainda exige rodar o app
  localmente (`flutter run`) apontando pro Render.

## Offline

Tudo que não depende de multiplayer deve funcionar offline: Skill Tree, criação
de build, configurações, livro de descobertas, treinamento, lógica local de batalha.
