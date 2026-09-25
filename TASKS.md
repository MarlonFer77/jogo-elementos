# TASKS.md

Fonte única da verdade sobre o trabalho atual.

# NOW

v0.26.0 publicada em 2026-09-25: lobby/conexão Multiplayer e pós-batalha.
CI 36137752619 aprovado, commit cd3c59d, versionCode 26. Assinatura igual à
v0.25.0 e SHA-256 local igual ao asset público. Marcada como latest no GitHub.
Servidor respondeu com protocolo 2/Firestore; smoke online aprovou criar/entrar,
preparar, conjurar, rejeitar duplicata e recuperar estado. Sem novo deploy/plano.
No plano gratuito, primeira conexão após inatividade pode demorar.
Próximo: validar em dois celulares com v0.26.0, sem desinstalar o jogo.

Checkpoint anterior:

Lobby/conexão Multiplayer concluídos localmente: criar/entrar/retomar separados,
feedback de requisição real sem reenvio automático, retomada com identidade salva,
erros compreensíveis e validação de código. Sala mostra código copiável e preparo
de ambos antes da batalha; seleção de elementos é aberta pela sala.
Layout rolável nas duas orientações/com teclado. Identidade, polling e backend
reutilizados; reconexão autorizada também atualiza a última sala local.
13 testes focados passaram (6 lobby + 2 multiplayer + 5 pós-batalha), análise limpa
e prévias conferidas. Teste em dois celulares pendente. Sem commit/release;
bloco de pós-batalha anterior preservado.

Checkpoint anterior:

Pós-batalha concluído localmente: painel pixel art compartilhado, arena mantida,
resultado após animação final e ações Revanche/Menu acima dos detalhes.
Ganhos comparados ao progresso inicial (sem conceder recompensas): livro
compartilhado e habilidades/árvore separados por jogador no Treino; estado do
servidor no Multiplayer. Reconexão sem histórico inicial é indicada explicitamente.
Treino permite ajustar os 3 slots; Multiplayer encerrado oferece consulta,
com troca na próxima sala. Revanche mantém fluxo existente e bloqueia duplicatas.
7 testes focados aprovados, análise limpa e prévias vertical/horizontal conferidas.
Sem novo backend, persistência, commit ou release. Falta teste em aparelhos.

Checkpoint anterior:

v0.25.0 publicada em 2026-09-24: Home RPG, Livro de Descobertas e polimento
dos Selos. CI 36052579909 aprovado, commit 6812389, versionCode 25.
APK com a mesma assinatura da v0.24.0; hash local igual ao asset publicado.
Release pública confirmada em 2026-09-25. Sem alteração de backend, protocolo
ou persistência. Falta experimentar no celular, em ambas as orientações.

Checkpoint anterior:

Tela inicial concluída localmente: cena pixel art reaproveita arena/sprites,
emblema de conjuração e menu RPG com identificação de Treino/Multiplayer.
Vertical empilhada; horizontal lado a lado, compacta em telas baixas, com rolagem
de segurança. Navegação protegida contra toque duplo; animação suspensa ao sair
e com movimento reduzido. Combate, atualização, backend e persistência intactos.
6 testes da Home aprovados (incluindo retorno e 360x800/800x360/568x320), análise
focada limpa e prévias renderizadas/inspecionadas. Falta validar no aparelho.
Sem nova release; melhorias anteriores do livro/selos continuam preservadas.

Checkpoint anterior:

Livro de Descobertas concluído localmente: tela compartilhada Treino/Multiplayer,
busca por nome/efeito/elemento, filtros por AP/elemento/equipamento, receitas e dano
base das descobertas. Receitas desconhecidas ocultas. Gestão dos 3 slots reutilizada;
registro compartilhado do Treino separado das habilidades pessoais. Sem release.
9 testes focados aprovados (4 do livro + 5 do gerenciador existente). Entrada pelo
ícone de livro na batalha. Disponibilidade é uma consulta, não promessa em tempo
real; botão de atualizar e prévia da batalha mantidos. Persistência não alterada.

Checkpoint anterior:

Polimento dos Selos concluído localmente (sem nova release): rastro do dedo,
orientação de próximo nó/retomada e aviso nos últimos 2s, mantendo dano/AP/prazo.
Janela com espaços fixos para não deslocar o desenho ao iniciar. Alteração apenas
na UI compartilhada entre Treino e Multiplayer; sem novo protocolo/infraestrutura.
6 testes focados aprovados: início, correção/retomada, tempo curto, estabilidade
do desenho em vertical/horizontal e ataque equipado. Falta experimentar no celular.

Checkpoint anterior:

v0.24.0 publicada em 2026-09-24: APK do CI 35998111703 (versionCode 24),
assinatura igual à v0.23.0. Backend 942b336 ativo no Render com Firestore.
Smoke online aprovado: início, reserva, resolução, rejeição de duplicata e recuperação.
Diagrama fixo por receita (4/6 nós, 6/8 segundos), arraste com retomada pelo último
nó, janela compartilhada adaptativa e canalização do avatar. Básicos continuam diretos.
Falha perde 1 AP sem regenerar, passa turno e processa status, sem combo/descoberta.
Servidor reserva ação/build, valida geometria/ordem/prazo e rejeita duplicatas.
Prazo e selo persistidos no snapshot; primeira leitura após expirar resolve a falha
atomicamente (sem jobs nem escritas a cada polling). Tolerância de transporte: 1,5s.
Validação pontual: backend (5 testes), domínio/widget/ataque equipado/multiplayer
(7 testes), análise do app e typecheck backend aprovados;
sem suíte completa. Pendente teste físico de gesto/latência nos dois celulares
atualizados para v0.24.0. Ver docs/conjuration-seals.md. Checkpoint anterior:

v0.23.0 publicada em 2026-09-23 com APK do CI (run 35857481276).
Backend 00a0117 no Render, protocolo 2 e Firestore ativos. Conta exclusiva com
roles/datastore.user; segredo salvo no Render e cópias temporárias locais apagadas.
Cobrança Firebase desativada; nenhum plano pago ativado.
Smoke online aprovado: criar, entrar, preparar ambos, atacar e recuperar estado.
Recuperação por nova instância do adaptador Firestore também aprovada.
Próximo: usuário validar dois celulares com v0.23.0, reconexão e orientações.
Protótipo fechado: identidade por instalação; faltam rate limiting/retenção e
recuperação de conta antes de abertura pública. Checkpoints abaixo são históricos.

Checkpoint anterior:

Multiplayer: protótipo integrado localmente, sem publicação.
Servidor controla preparação, 4 elementos, 3 ataques, descobertas, progressão
e habilidades/status. Credencial por instalação + revisão obrigatória.
Frontend reutiliza preparação, Skill Tree, ataques, arena e feedback; controles
nas duas orientações, reconexão com última sala lembrada e avisos de conexão.
Snapshot atômico opcional via MATCH_STORE_FILE; progresso de partidas concluídas
reutilizado com a mesma credencial e nome. Sem importar progresso local do Treino.
Validação pontual: 2 testes HTTP/persistência + 2 widgets de orientação aprovados;
typecheck aprovado. Não foi rodada suíte completa nem teste em aparelhos físicos.
Contrato novo exige atualizar fixtures antigas de multiplayer (credencial,
revisão e preparação) antes de voltar a usar a suíte legada como gate de release.
Publicação bloqueada até escolher armazenamento durável e validar dois aparelhos;
ver docs/multiplayer-prototype.md. Nenhuma infraestrutura alterada.

Checkpoint anterior:

Árvore de habilidades: incremento concluído, sem publicar. Tela compartilhada
mostra identidade/progresso dos ramos, estados e limitações dos nós ainda inertes.
Detalhes roláveis e desbloqueio protegido contra envio duplicado.
Propagação fortalece DOT de combos; Instabilidade troca duração por dano imediato.
IDs/pré-requisitos/persistência preservados. Validação pontual: 7 testes Dart,
5 backend, 4 da tela compartilhada; typecheck aprovado. Sem suíte completa.

Checkpoint anterior:

INLINE: completar status e ampliar combos. Sem publicar.
Checkpoint 1: regras definidas (Silêncio, Lentidão, Buff/Debuff, Molhado,
Choque e Veneno); 16 novas receitas, total 20.
Checkpoint 2 concluído: engine/backend/UI, prévias, custos e avisos integrados.
Checkpoint 3 concluído: engine 233, backend 160 e app 289 testes aprovados;
análise do app e typecheck do backend sem problemas. Capturas de layout de
defesa em 360x640 e 568x320 inspecionadas (fontes de teste, não arte final).
Validação manual em aparelhos e balanceamento pendentes. Sem commit/release/deploy.

# NEXT

Validar o protótipo multiplayer em dois aparelhos e decidir persistência durável
dentro do orçamento R$ 0. Migrar fixtures legadas do protocolo e revisar limites
de acesso/armazenamento antes de publicação pública. Publicação não autorizada.

# BACKLOG

Mapa do que falta, por área — não é ordem de prioridade. Consultar antes de
perguntar "o que falta"; atualizar aqui (não como pergunta solta) sempre que
uma tarefa nova terminar revelando um gap novo.

**Battle Engine (packages/battle_engine)**
- `hitCount`/`critChanceBonus` (Fragmentação/Núcleo Instável) inertes —
  precisa desenhar como múltiplos hits/crítico interagem com Escudo
- Conversões adicionais de status: Molhado já amplifica Raio e é consumido;
  outras conversões ainda precisam de desenho de gameplay.
- Dano de campo é hit único — Lava não continua queimando enquanto ativa
- Artefatos não implementado (`MaxHpBonus` é o modelo pronto pra isso)

**Backend (backend/)**
- Persistência durável de produção não configurada; snapshot local opcional
  não resolve disco efêmero nem múltiplas instâncias.
- Credencial por instalação implementada; contas e recuperação ainda ausentes.
- Sem push em tempo real — só polling (cliente já poll a cada 2s)
- CORS liberado pra `*` — ok sem deploy real, reavaliar quando existir um (DECISION-021)

**Firebase (firebase/)**
- Nenhum projeto real criado — exige login numa conta Google do usuário
- Emulador do Firestore nunca verificado rodando de verdade nesta máquina
  (limitação de ambiente já diagnosticada, não da config — DECISION-015)

**App Flutter (app/)**
- Livro de Descobertas sem tela própria (só o contador no Modo Treino)
- Sistema de build do Modo Treino simplificado (um slot só, tudo
  desbloqueado se aplica sempre — DECISION-018)
- Sem iOS — precisa de um Mac, indisponível (DECISION-010). Android agora
  tem APK de verdade (ver DECISION-029), mas só compila via GitHub
  Actions — o Gradle não roda localmente nesta máquina (mesma limitação
  de rede da JVM da DECISION-015)
- Layout da Skill Tree visual (DECISION-038) assume que cada branch é
  uma cadeia linear (`orderBranchNodes`) — se um nó ganhar 2+
  pré-requisitos ou 2+ nós dependendo dele no futuro, o layout continua
  correto logicamente mas não desenha a ramificação visualmente
- Botão de mutar/desmutar os efeitos sonoros (Bloco 8, DECISION-042) —
  precisa de uma tela de configurações, que ainda não existe
- Música de fundo (Bloco 8, DECISION-042) — loop/fade/mixagem é
  complexidade própria, fora do escopo do bloco de áudio já feito
- Sons de habilidade desbloqueada/vitória/derrota (Bloco 8, DECISION-042)
  não foram ouvidos manualmente nesta sessão (ícone de Habilidades não
  localizado a tempo no preview web) — só a lógica que decide quando
  tocar foi verificada (suítes de tela passando)
- Animação nos badges de status/campo (Bloco 9, DECISION-044) — fica
  pra um bloco futuro de polimento, se quiser
- Tooltip/descrição ao tocar num badge de status/campo (Bloco 9,
  DECISION-044) — não pedido, YAGNI
- Ícone dedicado por combinação futura sem entrada em
  `status_visuals.dart` (Bloco 9, DECISION-044) — cai no fallback (✨)
  até alguém adicionar

**Multiplayer (cliente)**
- A modal de Habilidades não escuta o polling por trás — se a vez mudar
  com ela aberta, a lista não atualiza sozinha (mesma limitação que a
  `TrainingScreen` já tinha — DECISION-026)
- Revanche simultânea dos dois jogadores cria duas partidas separadas, não
  ligadas — só um dos dois deveria clicar (DECISION-023)
- Sem indicação visual de "enviando"/erro de rede além do texto cru do
  backend
- `CombinationCatalog` precisa sincronizar manualmente toda vez que
  `default_combinations.dart` ganhar uma combinação nova
- Progressão persistente no Multiplayer (Bloco 11 da direção de
  produto, decidido mas não iniciado): Skill Tree persistente + Livro
  de Descobertas novo no backend (não existe nenhum hoje), via
  Firestore. Projeto Firebase real já criado (`elements-1173d`,
  DECISION-045) — falta gerar a credencial de serviço (Admin SDK) no
  console e configurar no backend/Render antes de poder implementar

**Produção / deploy**
- Backend implantado no Render (free tier) — ver DECISION-028. APK
  Android distribuído via GitHub Release (ver DECISION-029) — compilado
  via GitHub Actions, não localmente (Gradle não roda nesta máquina).
  Ainda faltam: versão web do app não está implantada em lugar nenhum
  (só roda localmente, `flutter run -d web-server`); Firebase continua só
  local (emulador); free tier do Render hiberna após ~15min sem uso
  (primeira requisição depois disso demora mais, "cold start"); APK sem
  assinatura de release de verdade (usa a chave de debug — suficiente
  pra instalar direto, não pra publicar numa loja); sem atualização
  automática — uma nova versão do jogo exige gerar e reenviar um APK novo

# DONE

- Congelamento funcional: Água + Gelo cria Prisão Glacial (10 de dano),
  aplicando Congelamento se Escudo não bloquear. O alvo perde a próxima ação
  para quebrar o gelo, sem regenerar AP; ataques/Defesa são rejeitados até
  isso acontecer. Treino e Multiplayer mostram badge, camada azul/cristais no
  personagem, aviso, prévia e comando exclusivo “Quebrar gelo”. Mirror Dart/
  TypeScript e rotas autoritativas sincronizados. 226 testes no engine, 153 no
  backend e 286 no app; análises estáticas limpas. Ver DECISION-055.
  Preparado para distribuição na v0.22.0+22.

- v0.21.0+21 publicada: backend validado no Render com prévia de Defesa sem
  mutar a partida; APK Android de 52.879.521 bytes publicado no GitHub Release
  `v0.21.0` após build verde no Actions. Defender, prévia autoritativa e combos
  diferenciados disponíveis em produção. Ver DECISION-054.

- Combate fluido: básicos com aproximação, golpe e recuo; combos com
  canalização e projétil pixelado; pernas, poses, respiração e reação a dano.
  HUD sincronizado com impacto; legenda e dano legíveis; rotação/cancelamento
  sem poses presas. Básicos locais do Multiplayer também geram animação.
  250 testes aprovados, análise estática limpa e preview visual verificado
  com básicos/combo nas orientações vertical/horizontal. DECISION-052.
  Preparado para distribuição na v0.19.0+19.

- Preparação personalizada do Treino: etapas A/B, seleção de dois elementos,
  contador e entrada explícita na batalha. Campo e comandos lado a lado na
  horizontal, empilhados na vertical; abas/AP/confirmação fixos, áreas seguras
  respeitadas e rotação sem reiniciar a animação ou perder seleção/progresso.
  Suíte do app: 237 testes aprovados; análise estática sem problemas.
  Ver DECISION-051. Preparado para distribuição na v0.18.0+18.

- Interface portátil do Treino: arena/HUD fixos, grade 2×2 com até quatro
  elementos ativos por jogador, aba com três habilidades, troca em janela
  inferior e combinação com confirmação. Equipamento elemental persistente,
  migração de saves antigos e validação no domínio. Habilidades aprendidas
  independem dos quatro elementos básicos. Mensagem durante animação;
  troca de habilidade nova só abre após o feedback. Ver DECISION-050.

- Bloco 2d: painel com três slots de ataques equipados no Treino, seleção,
  descrição, custo e motivo de indisponibilidade; execução por ID validada
  em TrainingMatch e encaminhada ao motor existente. Básicos e combinação
  livre preservados; AP disponível inclui a regeneração existente. Bloqueio
  contra toque duplo acompanha a conclusão real da animação. Corrigidos
  estouros de texto no HUD/botões em 360 px. Ver DECISION-049.

- Definição da arquitetura mínima e criação dos 4 arquivos de contexto (CLAUDE.md,
  ARCHITECTURE.md, TASKS.md, DECISIONS.md)
- Pacote `packages/battle_engine` criado (Dart puro, sem dependência de Flutter)
- `Element` implementado (data-driven: id, nome, símbolo) com os 10 elementos do design
- `ElementCombination` + `CombinationBook` implementados (2 e 3 elementos → efeito),
  com combinações de exemplo (Tempestade Ígnea, Campo Eletrocutado, Lava)
- Testes das combinações (13 testes, `dart analyze` e `dart test` passando)
- `Combatant` e `BattleState` implementados (participantes, turno atual, efeitos
  de campo ativos), imutáveis com `copyWith`/`withFieldEffect`, com testes
  (20 testes no total no pacote, `dart analyze` e `dart test` passando)
- `TurnAction` e `TurnEngine` implementados: joga 1–3 elementos, resolve
  combinação via `CombinationBook`, rejeita ação fora da vez, alterna o turno
  e acumula efeitos de campo. Sem dano/HP/vitória ainda (fora de escopo)
  (31 testes no total no pacote, `dart analyze` e `dart test` passando)
- `StatusEffect`/`StatusEffects` (data-driven: Burn, Freeze, Wet, Poison, Shock,
  Slow, Shield, Silence, Buff, Debuff, AreaEffect) e `ActiveStatus` (duração em
  turnos) implementados. `BattleState` ganhou `statusesOf`/`hasStatus`/
  `withStatusApplied`/`withStatusRemoved`/`withStatusesTicked`. Sem integração
  automática com o `TurnEngine` ainda (fora de escopo)
  (43 testes no total no pacote, `dart analyze` e `dart test` passando)
- `FieldEffect` extraído (efeito de campo genérico); `ElementCombination.result`
  e `BattleState.activeFieldEffects` passaram a usá-lo. `Ability`, `Mutation`/
  `Mutations` (Combustão, Fragmentação, Incêndio, Núcleo Instável) e
  `AbilityEngine` implementados: uma habilidade joga elementos via `TurnEngine`
  e suas mutações acumulam um `AbilityEffect` (status a aplicar no oponente,
  efeito de campo, hitCount e critChanceBonus — os dois últimos ainda inertes,
  sem sistema de dano)
  (62 testes no total no pacote, `dart analyze` e `dart test` passando)
- `SkillNode`/`SkillTree` (grafo data-driven, valida ids duplicados,
  pré-requisito inexistente e ciclos) e `SkillProgress` (desbloqueio
  imutável, `availableNodes`, `grantedMutations`) implementados. Cada nó
  concede uma `Mutation` já existente — pronta para anexar a uma `Ability`.
  `defaultSkillTree` de exemplo com 2 branches (fogo, precisão). Nós que
  alteram combinações/estados diretamente ficaram fora de escopo
  (ver DECISION-008)
  (90 testes no total no pacote, `dart analyze` e `dart test` passando)
- `Build` implementado: `skillProgress` + lista de `Ability`s (ids únicos),
  validado na construção e a cada mudança (toda `Mutation` usada precisa
  estar desbloqueada em `skillProgress`). `abilityById`, `withAbility`,
  `withSkillProgress`. `Ability` ganhou igualdade por id (faltava, corrigido
  por consistência). Não depende de nenhuma batalha — build é editável offline
  (102 testes no total no pacote, `dart analyze` e `dart test` passando)
- Ponto de extensão implementado: `CombinationModifier` (id/nome/descrição +
  `apply(FieldEffect)→FieldEffect`), aplicado por `TurnEngine.playTurn`
  (parâmetro opcional `combinationModifiers`) antes do efeito ir pro campo;
  `AbilityEngine` repassa. `FieldEffect` ganhou `area`/`duration` para ter o
  que modificar. `SkillNode.grants` virou `SkillGrant` (`Mutation` ou
  `CombinationModifier`, via interface comum) — `SkillProgress` ganhou
  `grantedCombinationModifiers`. `Build` ganhou `combinationModifiers`
  (validado contra o skillProgress) e `withCombinationModifier`.
  `defaultSkillTree` ganhou a branch "elemental" (Propagação, Instabilidade)
  (125 testes no total no pacote, `dart analyze` e `dart test` passando)
- App Flutter criado em `app/` (plataformas web + windows, únicas com
  toolchain nesta máquina), com `battle_engine` como path dependency.
  Estrutura inicial: `lib/game_domain/element_catalog.dart` (primeira classe
  da camada Game Domain) + `lib/ui/home_screen.dart` (tela provisória que
  lista os elementos — prova a fiação, não é UI de jogo real). `flutter
  analyze` limpo, teste de widget passando, verificado rodando de verdade no
  navegador (`flutter run -d web-server`, via `.claude/launch.json`)
- Integração Flame: dependência `flame` adicionada. `BattleView` (projeção
  somente-leitura de `BattleState`) e `DemoBattle.start()` (roda um turno via
  `TurnEngine`) em `game_domain`. `BattleGame extends FlameGame` em
  `game_presentation` renderiza o `BattleView` como texto — sem regra de jogo
  nenhuma. `BattleScreen` hospeda o `BattleGame` num `GameWidget`, acessível
  pelo botão na `HomeScreen`. `flutter analyze` limpo, 3 testes passando
  (unitário do `DemoBattle` + navegação), verificado rodando de verdade no
  navegador — Flame renderizou "Ana"/"Beto"/"Turno: Beto"/"Tempestade Ígnea"
- Backend Node/TS criado em `backend/`: TypeScript + `tsx` (dev/execução) +
  `node:test` nativo (sem dependência de test runner). `src/server.ts`
  (`createServer()`, testável em porta efêmera) + `src/index.ts` (entry
  point). Só `GET /health` por enquanto — nenhuma regra de jogo ainda.
  `tsc --noEmit` limpo, 2 testes passando, servidor rodado de verdade
  (`curl /health` → `{"status":"ok"}`). Problema arquitetural identificado
  e registrado: ver DECISION-013 antes de começar "Validação de ações
  críticas no backend"
- Validação de ações críticas no backend: `src/battle-rules/` — mirror
  deliberado e mínimo do `battle_engine` em TypeScript (`FieldEffect`,
  `CombinationBook`/`defaultCombinationBook`, `createBattleState`/
  `opponentOf`, `TurnEngine.playTurn`). Endpoint `POST /battles/validate-turn`
  (stateless: cliente manda o estado, servidor recalcula e devolve o
  resultado autoritativo). Sem estados/habilidades/skill tree/builds no
  servidor ainda (ver DECISION-013/014). `tsc --noEmit` limpo, 24 testes
  passando (unitário das regras + integração HTTP em porta efêmera),
  servidor testado de verdade com `curl` (turno válido calcula
  `ignited_storm` e passa o turno; turno fora de vez → 400)
- Firebase (setup mínimo, free tier, sem cartão): `firebase/` criado com
  `firebase-tools` (dev dependency), `firebase.json` (emulador do Firestore +
  UI), `firestore.rules` (nega tudo por padrão — sem schema/auth decididos),
  `firestore.indexes.json` (vazio), `.firebaserc` apontando pro project id
  demo `demo-jogo-elementos` (Firebase Emulator Suite reconhece "demo-*" como
  projeto falso — roda 100% local, sem login, sem cartão, sem projeto real
  criado). JSON de todos os arquivos validado. Emulador do Firestore não
  pôde ser verificado rodando de verdade nesta máquina — precisa de Java 21+
  (instalado via choco), mas o próprio JVM falha com "Unable to establish
  loopback connection" (bug/limitação de sockets Unix domain do ambiente,
  reproduzido em Bash, PowerShell nativo e com sandbox desabilitado — não é
  problema da configuração). Ver DECISION-015. Nenhum projeto real do
  Firebase foi criado — isso exige login numa conta Google do usuário
- Multiplayer: `POST /matches`, `POST /matches/:id/join`,
  `POST /matches/:id/turns`, `GET /matches/:id` implementados. `MatchStore`
  in-memory (perde estado ao reiniciar o servidor — persistência real via
  Firestore é follow-up, bloqueado em ter um projeto Firebase de verdade).
  Reconexão por polling (`GET /matches/:id`), sem push em tempo real ainda.
  Identidade de jogador é só uma string mandada pelo cliente, sem
  autenticação (aceitável para "dois amigos", registrado como limitação).
  `tsc --noEmit` limpo, 38 testes passando no total do backend, fluxo
  completo (criar → entrar → ação A → ação B → reconectar) testado de
  verdade com `curl` contra o servidor rodando (ver DECISION-016)
- Livro de Descobertas: `DiscoveryEntry`/`DiscoveryBook` implementados em
  `battle_engine` — rastreia `ElementCombination`s descobertas por
  `resultId` (`withDiscovered`, `isDiscovered`, `entriesFor(CombinationBook)`).
  Meta-progressão pura, offline, imutável, sem integração automática com
  `TurnEngine`/`AbilityEngine` (a camada que processa o resultado decide
  atualizar o livro). Sem UI no Flutter ainda (fora de escopo, mesmo padrão
  de Skill Tree/Build)
  (132 testes no total no pacote, `dart analyze` e `dart test` passando)
- Modo treino / offline: `TrainingMatch` (game_domain) — batalha local
  hotseat (`BattleState`+`TurnEngine`+`DiscoveryBook`, offline, sem IA),
  expõe só tipos simples pra UI. `TrainingScreen` — primeira tela realmente
  jogável do app: seleciona 1–3 elementos (chips), joga o turno, vê o
  campo/última combinação/progresso do Livro de Descobertas atualizarem.
  `ElementCatalog` refatorado pra devolver `ElementOption` (tipo próprio da
  Game Domain) em vez do `Element` do `battle_engine`, fechando de vez a
  regra "UI nunca precisa nomear um tipo do battle_engine" (ver
  DECISION-017). `flutter analyze` limpo, 10 testes passando no app
  (unitário do `TrainingMatch` + 2 de widget), verificado jogando de
  verdade no navegador — Fogo+Vento disparou "Tempestade Ígnea", passou o
  turno pra Jogador B e "Descobertas: 1/3" atualizou
- Integrar Habilidades/Mutações/Skill Tree/Build no Modo Treino:
  `TrainingMatch` ganhou um `SkillProgress` independente por jogador sobre
  `defaultSkillTree`. `playElementIds` agora monta um `Ability` novo a cada
  turno (elementos escolhidos + `grantedMutations` do jogador da vez),
  embrulha num `Build` (validado) e chama `AbilityEngine.useAbility` em vez
  do `TurnEngine.playTurn` cru. `TrainingScreen` ganhou o botão
  "Habilidades" (abre modal listando nós desbloqueáveis do jogador da vez,
  com desbloqueio ao vivo) e mostra estados ativos de cada jogador + efeitos
  aplicados no oponente. `SkillNodeOption` criado (Game Domain) pro mesmo
  motivo do `ElementOption`. `flutter analyze` limpo, 16 testes passando no
  app, verificado jogando de verdade no navegador: Jogador A desbloqueou
  Maestria da Brasa, jogou só Fogo, e "Queimadura" foi aplicada em Jogador B
  — a cadeia Skill Tree → SkillProgress → Build → Ability → AbilityEngine →
  BattleState funcionando de ponta a ponta pela UI
- Sistema de dano/HP/condição de vitória: `HpPool` (novo); `damage` em
  `FieldEffect`/`ElementCombination` (Tempestade Ígnea/Campo Eletrocutado
  20, Lava 35); `damagePerTick` em `ActiveStatus` (Combustão: 8×2 = 16);
  `TurnEngine.playTurn` passou a aplicar dano de combo (bloqueado por
  Escudo, que é consumido), tickar estados automaticamente (dano incluso,
  inclusive no tick que expira) e setar `BattleState.winner` — rejeita
  ação se a partida já acabou; empate simultâneo é decidido a favor de quem
  jogou o turno. `MaxHpBonus`/`MaxHpBonuses` (novo `SkillGrant`,
  `SkillProgress.grantedMaxHpBonus`) + nó "Treino de Vitalidade" (+20 HP)
  na `defaultSkillTree`. `TrainingMatch` calcula HP inicial (100 + bônus) e
  aplica bônus desbloqueado no meio da partida ao vivo; `TrainingScreen`
  mostra HP, tela de fim de partida e botão "Nova partida" (corrigiu de
  passagem um overflow no modal de Habilidades, exposto pelo 4º nó da
  árvore). 173 testes no total no battle_engine, 24 no app — `dart
  analyze`/`flutter analyze` limpos, `dart test`/`flutter test` passando.
  Verificado jogando uma partida completa até o fim de verdade no
  navegador (5 combos de Fogo+Vento derrubaram Jogador B de 100 a 0,
  "Vencedor: Jogador A" apareceu, "Nova partida" resetou corretamente).
  O mirror do backend (`backend/src/battle-rules/`) **não** foi
  atualizado — continua validando só a resolução básica de turno, sem
  dano/HP/vitória (ver DECISION-019)
- Sincronizar dano/HP/vitória no backend: `backend/src/battle-rules/`
  ganhou `HpPool`/`hp-pool.ts`, `damage` em `FieldEffect`/
  `defaultCombinationBook` (mesmos números do Dart), `hp`/`winner` em
  `BattleState` (`hpOf`/`withDamage`), e `playTurn` passou a aplicar dano
  de combo ao oponente, definir o vencedor e rejeitar jogar depois que a
  partida acabou. `MatchStatus` ganhou `"finished"`; `MatchStore.applyTurn`
  marca o match e passa a rejeitar novas jogadas (409). O endpoint
  stateless `/battles/validate-turn` também aceita/devolve `hp`/`winner`.
  Deliberadamente sem Escudo/Queimadura (DOT) — dependem de
  status/abilities/skill tree, que o backend nunca mirrorizou e que o
  Multiplayer não expõe ainda (ver DECISION-020). `tsc --noEmit` limpo, 57
  testes passando no backend
- Conectar o Multiplayer ao app: `MultiplayerLobbyScreen` (criar/entrar com
  código) + `MultiplayerBattleScreen` (joga, HP dos dois lados, campo
  ativo, fim de partida, polling a cada 2s) no Flutter, sobre
  `MultiplayerClient`/`MultiplayerMatch`/`CombinationCatalog` (novos, em
  `game_domain`). Backend ganhou CORS permissivo (necessário pro app web
  chamar o backend numa origem diferente) — ver DECISION-021. `flutter
  analyze` limpo, 39 testes passando no app (incluindo os novos de
  multiplayer), 59 no backend. Verificado de ponta a ponta de verdade:
  backend + app rodando juntos, duas abas do navegador como "ana"/"beto" —
  criar, entrar, jogar Fogo+Vento (dano e nome da combinação corretos), a
  outra aba atualizando sozinha via polling
- Tela de reconexão do Multiplayer: `MultiplayerMatch.reconnect` (GET
  puro, valida localmente que o jogador faz parte da partida) + botão
  "Reconectar" na `MultiplayerLobbyScreen` (mesmos campos de nome/código).
  Motivado por um gap descoberto jogando a partida anterior de ponta a
  ponta: fechar a aba não deixava voltar pra partida em andamento (ver
  DECISION-022). `flutter analyze` limpo, 43 testes passando no app.
  Verificado de verdade: joguei um turno real, fechei a aba do "beto" por
  completo, abri uma aba nova, reconectei só com nome + código — voltou
  no HP/turno/campo reais, sem resetar nada
- Botão de revanche no Multiplayer: `MultiplayerMatch.startRematch()` cria
  uma partida nova pro mesmo jogador (não existe "reset" no backend — uma
  `Match` `finished` fica `finished`); botão "Revanche" na tela de fim de
  partida navega pra ela via `pushReplacement`, código novo pra
  compartilhar de novo com o amigo (ver DECISION-023). `flutter analyze`
  limpo, 45 testes passando no app. Verificado de verdade: joguei uma
  partida até o fim, cliquei Revanche, confirmei por `GET` no backend que
  a partida antiga ficou intacta (`finished`) e a nova nasceu
  `waiting_for_opponent` com código diferente
- Escudo e Queimadura/DOT no backend: `ActiveStatus`/`active-status.ts` +
  `combatantStatuses` em `BattleState`; `playTurn` bloqueia dano de combo e
  consome Escudo (`SHIELD_STATUS_ID`), tica `damagePerTick` de todo status
  ativo dos dois jogadores ao final de cada turno (dano genérico, não
  específico de Queimadura), remove estados expirados — mesma ordem
  `[oponente, ator]` que decide empate simultâneo a favor de quem jogou
  (mirror 1:1 de `TurnEngine.playTurn`). `/battles/validate-turn` também
  aceita/devolve `combatantStatuses`. Fecha a lacuna da DECISION-020/021
  (ver DECISION-024). Deliberadamente sem ligação com abilities/Skill
  Tree — `TurnAction` do Multiplayer continua só `{actorId, elementIds}`,
  então nenhuma jogada real ainda produz um status (registrado no
  BACKLOG). `tsc --noEmit` limpo, 76 testes passando no backend,
  incluindo os 5 casos espelhados 1:1 de `turn_engine_test.dart` (Dart)
- Habilidades, Mutações e Skill Tree no backend do Multiplayer: novos
  `ability-effect.ts`/`mutations.ts`/`combination-modifiers.ts`/
  `max-hp-bonuses.ts`/`skill-tree.ts`/`ability-engine.ts` em
  `battle-rules/`; `Match.skillProgress` (nós desbloqueados por jogador);
  `MatchStore.applyTurn` passou a usar `useAbility` (aplica as Mutações/
  CombinationModifiers já desbloqueadas do ator automaticamente); nova
  `MatchStore.unlockSkill` (só quem tem a vez desbloqueia, aplica
  `maxHpBonus` na hora) + rota `POST /matches/:id/skills/unlock`. Fecha o
  gap da DECISION-024 (ver DECISION-025). `SkillNode`/`SkillTree`/
  `SkillProgress` genéricos do Dart viraram dado estático + funções puras
  (tradução, não port 1:1); `Build` não foi portado (não precisa — mesmo
  padrão que `TrainingMatch.playElementIds` já usava sem `Build`/`Ability`
  como classes). `tsc --noEmit` limpo, 118 testes passando no backend.
  Deliberadamente sem UI no app ainda — verificado de ponta a ponta via
  HTTP puro contra o servidor rodando: criar, entrar, desbloquear Maestria
  da Brasa pra "ana", jogar só Fogo, Queimadura apareceu em
  `combatantStatuses.beto` na resposta
- UI de Habilidades/Skill Tree no Multiplayer: botão "Habilidades" na
  AppBar da `MultiplayerBattleScreen` (só com a partida em progresso) abre
  modal igual à `TrainingScreen`, listando nós desbloqueáveis só quando é
  a vez do jogador local (`MultiplayerMatch.unlockedNodeIdsForMe` +
  `unlockSkill` novos, `RemoteMatch.skillProgress`,
  `skill_tree_catalog.dart`'s `availableSkillNodeOptions`). Fecha a
  lacuna da DECISION-025 (ver DECISION-026). `flutter analyze` limpo, 52
  testes passando no app. Verificado de ponta a ponta de verdade jogando
  pela tela: criei partida como "ana", "beto" entrou via API, abri
  Habilidades, desbloqueei Maestria da Brasa (lista atualizou na hora
  pra "Caminho do Incêndio"), joguei só Fogo, `GET /matches/:id`
  confirmou Queimadura aplicada em "beto"
- Escudo via Skill Tree: nova Mutação "Guarda" que protege quem a usa, não
  o oponente. Isso expôs um problema real — `AbilityEngine.useAbility`
  sempre mirava o oponente do ator, hardcoded. Solução: novo
  `TargetedStatus`/`StatusTarget` (Dart) e mirror em TypeScript
  (`ability-effect.ts`), `AbilityEngine`/`ability-engine.ts` escolhem o
  alvo por status. Nó `guard_training` (branch "defesa", raiz) na
  `defaultSkillTree`/`skill-tree.ts`. Como a árvore é data-driven, a UI
  (Treino e Multiplayer) já lista e permite desbloquear o nó novo sem
  nenhuma mudança de tela (ver DECISION-027). Ripple pego rodando os
  testes: `TrainingMatch`/`ability_test.dart` acessavam `ActiveStatus`
  direto de `statusesToApply`, corrigido pra `.status.effect`. 176 testes
  no battle_engine, 52 no app, 123 no backend — todos verdes, analyze/
  typecheck limpos. Verificado de ponta a ponta de verdade jogando o
  Modo Treino no navegador: desbloqueei Treino de Guarda, joguei um
  elemento ("Jogador A: Escudo" apareceu no jogador certo), o outro
  jogador disparou Tempestade Ígnea contra ele — HP ficou intacto em
  100/100 e o Escudo foi consumido
- Backend implantado no Render (free tier): `tsx` movido de
  `devDependencies` pra `dependencies` (precisa em runtime, não só em
  dev). Projeto virou repositório git pela primeira vez, publicado no
  GitHub (`github.com/MarlonFer77/jogo-elementos`, público — a integração
  Render↔GitHub App deu erro tentando conceder acesso a um repo privado
  novo, então usei repositório público como alternativa, confirmado com o
  usuário antes). Serviço `jogo-elementos-backend` criado no Render
  (plano free, região Virginia) via MCP. App Flutter passou a apontar
  `defaultMultiplayerBaseUrl` pro Render em vez de `localhost:3000`. Ver
  DECISION-028. Verificado de ponta a ponta contra o serviço real: `curl`
  direto (criar/entrar/jogar com dano correto) e o app rodando localmente
  **sem nenhum backend local no ar** — criei partida pela tela, "beto"
  entrou via `curl`, a tela da "ana" pegou a mudança sozinha via polling
- APK Android de verdade: gerado `app/android/` (`flutter create
  --platforms=android .`), `AndroidManifest.xml` ganhou a permissão de
  INTERNET (faltava, o Multiplayer não funcionaria sem ela). Build local
  (`flutter build apk`) esbarra na mesma limitação de rede da JVM da
  DECISION-015 ("Unable to establish loopback connection", agora no
  Gradle) — contornado compilando via GitHub Actions
  (`.github/workflows/build-apk.yml`, `workflow_dispatch`, runner
  `ubuntu-latest`). APK publicado como asset de uma GitHub Release
  (`v0.1.0`) pra dar um link de download direto, já que o arquivo
  (48MB) passa do limite de anexo do chat e o amigo também precisa
  baixá-lo (não só o usuário). Ver DECISION-029. Verificado: build real
  no Actions terminou verde, `curl` no link de download confirmou
  `Content-Type: application/vnd.android.package-archive` e tamanho
  correto
- Cenário de batalha visual (Flame): fundo CC0 + dois personagens
  genéricos por lado + flash/shake ao tomar dano, ligado ao Modo Treino e
  ao Multiplayer, substituindo a demo Flame desconectada (DECISION-030)
- Sequência de feedback visual de ataque (Bloco 1 da direção de produto):
  preparação→efeito→impacto→dano→estado pra qualquer combinação, Modo
  Treino e Multiplayer, sem mudar battle_engine/backend (DECISION-031)
- Arena de batalha em pixel art (Bloco 2 da direção de produto): HUD estilo
  jogo de luta no topo, personagens em sprite pixel art (grade de cores em
  código), fundo procedural — Modo Treino e Multiplayer (DECISION-032)
- Tela inicial de verdade (Bloco 3 da direção de produto): título com
  contorno, personagens pixel art de frente, botões blocudos pro Treino/
  Multiplayer — substitui o placeholder antigo (DECISION-033)
- Consistência visual pixel art (Bloco 4 da direção de produto): Treino,
  Lobby e batalha Multiplayer ganham o mesmo fundo/título/botões da Home,
  sem mudar lógica nem texto (DECISION-034)
- Feedback visual pixel art em chips/campos/modal (Bloco 5 da direção de
  produto): `PixelElementChip`, `PixelTextField` e `PixelSheetPanel` novos,
  substituindo `FilterChip`/`TextField`/conteúdo cru do modal de Skill Tree
  em Treino e Multiplayer, sem mudar lógica nem texto (DECISION-035)
- Animações + painel de seleção de elementos (Bloco 6 da direção de
  produto): idle nos sprites (Home e batalha), botões/chips afundando ao
  toque, transição de tela em slide de baixo pra cima, e a lista de
  elementos virando um painel (`PixelSheetPanel`) em vez de ficar sempre
  visível — resolve a rolagem em Treino e Multiplayer (DECISION-036)
- Checagem obrigatória de atualização: `UpdateChecker` consulta a API do
  GitHub Releases, `UpdateGateScreen` vira a raiz do app e bloqueia o jogo
  inteiro se existir versão mais nova (fail-open em erro de rede,
  checagem só em Android) — acaba com o aviso manual de "tem APK novo"
  pro amigo (DECISION-037)
- Skill Tree visual (Bloco 7 da direção de produto): `SkillTreeScreen`
  única (Treino e Multiplayer) substitui o modal de "disponíveis agora"
  por uma árvore completa — travados/disponíveis/desbloqueados juntos,
  ícone por nó, 5 branches lado a lado roláveis, painel de detalhe ao
  tocar um nó (DECISION-038)
- Assinatura estável do APK: workflow de build passa a cachear o keystore
  de debug entre execuções, em vez de gerar um novo a cada build —
  corrige atualização in-place falhando com "app não instalado"
  (DECISION-039)
- Download de atualização dentro do app: `UpdateGateScreen` baixa o APK
  com barra de progresso (pacote `ota_update`) e abre o instalador do
  Android sozinho, substituindo o "abrir navegador" — erro mostra
  "Tentar de novo", sem fallback pro navegador (DECISION-040)
- Core library desugaring habilitado no Gradle do app — exigido pelo
  `ota_update`, descoberto só numa build real via GitHub Actions
  (DECISION-041)
- Efeitos sonoros (Bloco 8 da direção de produto): primeiro som do jogo —
  `SfxPlayer`/`flame_audio`, 6 sons CC0 cobrindo toque de botão/chip,
  ataque disparado, impacto, habilidade desbloqueada, vitória (Treino) e
  vitória/derrota (Multiplayer). Só efeitos sonoros — sem música de fundo
  nem botão de mutar (DECISION-042)
- Badges de status ativo/efeito de campo (Bloco 9 da direção de
  produto): círculo colorido com ícone e turnos restantes na cena de
  batalha, substituindo o texto cru — Treino e Multiplayer, sem mudar
  battle_engine/backend (o Multiplayer já recebia `combatantStatuses`
  do backend, só o cliente nunca parseava) (DECISION-044)
- Progressão persistente do Modo Treino (Bloco 10 da direção de
  produto): Skill Tree (por Jogador A/Jogador B) e Livro de Descobertas
  (compartilhado) sobrevivem a "Nova partida" e a fechar/reabrir o app,
  via `shared_preferences` local ao aparelho (DECISION-045)
- Custo de AP pra combinar elementos (Bloco 2a, fora da ordem de
  prioridade do CLAUDE.md, a pedido do usuário após jogar): elemento
  sozinho grátis + 5 de dano básico; combinar 2-3 elementos custa AP
  (3/5), que regenera +1 por turno próprio e acumula (não recarrega
  tudo de uma vez); sem AP suficiente, a jogada inteira é rejeitada.
  Pips de AP no HUD de batalha (Treino e Multiplayer). Sincronizado em
  `battle_engine` (Dart) e `backend/src/battle-rules/` (TypeScript)
  (DECISION-046)
- Elementos bloqueados no Modo Treino (Bloco 2b, sequência combinada
  com o usuário desde o Bloco 2a): cada jogador escolhe 2 elementos
  iniciais uma vez, os outros 8 desbloqueiam via nova branch
  "elementos" na Skill Tree (`ElementUnlock`/`ElementUnlocks`), com
  custo crescente em turnos cumulativos jogados ((E-1)×10) além do
  pré-requisito de sempre. Só Modo Treino — Multiplayer aguarda o
  Bloco 11 pra ter persistência real primeiro (DECISION-047)
- Ataques combinados equipáveis no Modo Treino (Bloco 2c, sequência
  combinada com o usuário desde o Bloco 2a, fecha a sequência): a
  primeira vez que um jogador dispara uma combinação, ela vira um
  ataque pessoal desbloqueado; até 3 podem ficar equipados por vez
  (`AttackLoadout`, novo, separado do Livro de Descobertas
  compartilhado); replay de combo desbloqueado-mas-não-equipado é
  rejeitado; vaga livre equipa automático, vagas cheias abre a tela
  "Ataques Combinados" pedindo a troca. Só Modo Treino — Multiplayer
  aguarda o Bloco 11 (DECISION-048)

# BLOCKED

Nenhum
