# Tela inicial estilo jogo de luta (Bloco 3) — design

Data: 2026-09-09
Status: aprovado pelo usuário, pronto para virar plano de implementação.

## Contexto

Continuação da nova direção de produto (CLAUDE.md, "Direção de produto (game
feel)"). Blocos anteriores deram identidade pixel art à batalha em si
(DECISION-031, sequência de ataque; DECISION-032, arena/personagens/HUD). A
`HomeScreen` (`app/lib/ui/home_screen.dart`) continua exatamente como
sempre foi — o próprio doc comment do código já dizia: "Placeholder screen:
lists the built-in elements to prove the app is wired to the Battle Engine
... Real screens (menu, skill tree...) come in later tasks". Hoje ela é uma
`ListView` crua dos 10 elementos com dois ícones no `AppBar` — a primeira
tela que o jogador vê, e a que menos parece parte de um jogo.

Direção visual validada com o usuário via mockup no companion de
brainstorming (título em "fonte pixel", os dois personagens da batalha de
frente com um "VS", botões grandes blocudos pro Treino/Multiplayer) —
aprovada sem ajustes.

## Decisões confirmadas (conversa com o usuário)

1. **Bloco 3 = tela inicial de verdade** (não "mais feedback visual nos
   controles de batalha", a outra opção considerada) — é o "primeiro
   contato" do jogador, e hoje é literalmente um placeholder.
2. **A lista dos 10 elementos sai de cena** — a tela inicial fica focada em
   título + botões. Elementos continuam sendo a identidade do jogo dentro
   da batalha (não precisam de vitrine própria aqui).
3. **Os dois personagens da batalha aparecem decorativamente** (frente a
   frente, com um "VS") — reaproveitando o mesmo desenho em pixel art já
   existente, dando continuidade visual e "gostinho do jogo" antes de
   entrar numa partida.

## O que NÃO está neste bloco

- Nenhuma mudança em `battle_engine`, `backend`, `TrainingMatch`,
  `MultiplayerMatch` — puramente apresentação.
- Nenhuma mudança nas telas de Treino/Multiplayer/Lobby/Skill Tree além do
  necessário pra continuar navegando a partir da Home (elas continuam
  visualmente como estão — é um bloco futuro de "UI/UX" mais amplo, não
  este).
- Sem animação na tela inicial (título/personagens/botões parados) — só a
  resposta padrão de toque dos botões.
- Sem tela de "Livro de Descobertas" nem qualquer outra tela nova — só a
  Home.

## Fundo compartilhado (refatoração pequena)

`PixelArenaBackground` (Flame, usado na cena de batalha) tem sua lógica de
desenho (céu, linha de horizonte, chão) extraída para uma função pura
`drawArenaBackdrop(Canvas canvas, Size size)`, em `pixel_arena_background.dart`
mesmo. `PixelArenaBackground.render` passa a chamar essa função; a tela
inicial usa a MESMA função direto num `CustomPainter` Flutter puro (sem
Flame, sem game loop — é uma decoração estática). Uma fonte só de verdade
pras cores/proporções do céu/chão, sem duplicar em dois lugares.

## Personagens decorativos (`TrainerSpriteImage`)

Novo widget em `game_presentation`: `TrainerSpriteImage({bool mirror})`,
um `CustomPaint` fino que chama `drawPixelGrid` (já existente, já usado
pela batalha) diretamente — mesma grade `trainerSpriteGrid`, mesmas
paletas `pixelPaletteLeft`/`pixelPaletteRight`. Sem depender de Flame:
`drawPixelGrid` já opera sobre um `dart:ui.Canvas` puro, que é exatamente
o que `CustomPainter.paint` fornece — reaproveitamento direto, sem
adaptação. O espelhamento do lado direito usa `Transform.flip(flipX:
true, ...)` na árvore de widgets, não lógica nova de desenho.

## Botão de menu (`PixelMenuButton`)

Novo widget em `game_presentation`: `PixelMenuButton({required String
label, required VoidCallback onPressed, bool primary = false})` — um
botão blocudo (fundo claro, contorno escuro grosso, sombra sólida
deslocada, texto em caixa alta com espaçamento), mesmo espírito visual do
painel do HUD de batalha (`BattleHudWidget`). `primary` dá um fundo mais
destacado (usado no botão "Modo Treino", a ação mais comum). Reage ao
toque com o feedback padrão do Flutter (`InkWell`/`GestureDetector`) —
nada de animação customizada nesta tarefa.

## Título em "fonte pixel"

Sem fonte nova (sem asset, sem custo): o título usa `TextStyle.shadows`
— uma lista de `Shadow`s deslocados em várias direções, sem blur — pra
simular um contorno grosso ao redor do texto, mesma técnica já usada no
mockup aprovado (lá era `text-shadow` do CSS; aqui é `Shadow` do Flutter,
mesmo princípio). Fonte `monospace` do sistema, sem dependência nova.

## `HomeScreen` (reescrita)

Perde o `AppBar` inteiramente — vira uma tela de título de verdade, sem
barra superior. Composição: fundo (`CustomPaint` com `drawArenaBackdrop`)
ocupando a tela toda; por cima, centralizado, título + subtítulo + os dois
`TrainerSpriteImage` lado a lado com um "VS" no meio + os dois
`PixelMenuButton` ("Modo Treino", destacado; "Multiplayer") que navegam
exatamente pra onde os ícones do `AppBar` navegavam hoje
(`TrainingScreen`/`MultiplayerLobbyScreen`, mesmo `Navigator.push`).

## Consequência nos testes existentes

- `app/test/widget_test.dart`: o teste atual ("home screen lists every
  built-in element") perde a premissa — os elementos não aparecem mais na
  Home. Reescrito para testar a Home de verdade: título visível, os dois
  botões visíveis.
- `app/test/training_screen_test.dart`: três ocorrências de
  `find.byIcon(Icons.school)` (usadas pra navegar da Home pro Treino no
  início de cada teste) passam a usar `find.text('MODO TREINO')` — label
  exato do botão (caixa alta, mesmo estilo do mockup aprovado).
- Nenhum outro teste navega pela Home via ícone (confirmado por busca no
  repositório) — `multiplayer_lobby_screen_test.dart` e os demais
  constroem as telas diretamente, sem passar pela Home.

## Testes esperados (novos/ajustados)

- `TrainerSpriteImage`: sem teste de pixel renderizado (mesma limitação
  já aceita para todo desenho manual no projeto) — mas testável que
  constrói sem lançar exceção (`pumpWidget` simples).
- `PixelMenuButton`: teste de widget — mostra o `label`, aciona
  `onPressed` ao tocar.
- `HomeScreen`: teste de widget — mostra o título, os dois botões, e que
  tocar em cada um navega pra tela certa (mesmo padrão dos testes de
  navegação já existentes no projeto).
- Verificação manual via `flutter run -d web-server`: olhar a tela
  inicial de verdade e confirmar que navegar pros dois modos continua
  funcionando.

## Fora de escopo, mas não esquecido

UI/UX mais ampla das outras telas (Treino, Multiplayer, Lobby, Skill Tree)
continua pendente — prioridade #5 na direção de produto, blocos futuros.
