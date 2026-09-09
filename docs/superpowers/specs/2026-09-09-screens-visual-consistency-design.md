# Vestir Treino/Multiplayer/Lobby no estilo pixel art (Bloco 4) — design

Data: 2026-09-09
Status: aprovado pelo usuário, pronto para virar plano de implementação.

## Contexto

Continuação da nova direção de produto (CLAUDE.md, "Direção de produto (game
feel)"). Blocos anteriores deram identidade pixel art à batalha em si
(DECISION-031/032) e à tela inicial (DECISION-033). Hoje existe um choque
visual real: sair da Home (título pixel, fundo céu/chão, botões blocudos) e
entrar no Modo Treino, no Lobby do Multiplayer ou na tela de batalha do
Multiplayer despenca de volta pro Material puro — `AppBar` branca padrão,
`ElevatedButton`/`OutlinedButton`/`TextField` genéricos, fundo branco do
`Scaffold`. A cena de batalha em si (dentro dessas telas) já está no novo
estilo — é só a moldura ao redor que ainda não foi vestida.

## Decisões confirmadas (conversa com o usuário)

1. **Escopo**: `TrainingScreen`, `MultiplayerLobbyScreen`,
   `MultiplayerBattleScreen` ganham o mesmo fundo/paleta/estilo de botão da
   Home — sem mexer em nenhuma lógica/regra dessas telas.
2. **Fora de escopo** (fica pra um bloco futuro, mais focado): os chips de
   seleção de elemento (`FilterChip`), os campos de texto do Lobby
   (`TextField`), e o conteúdo do modal de Skill Tree (lista de nós,
   botões "Desbloquear"/"Fechar") continuam exatamente como estão —
   Material padrão.

## O que NÃO está neste bloco

- Nenhuma mudança em `battle_engine`, `backend`, `TrainingMatch`,
  `MultiplayerMatch` — puramente apresentação.
- Nenhuma mudança na cena de batalha em si (`BattleSceneWidget` e tudo
  dentro dela) — já está no estilo novo desde os Blocos 1/2.
- `FilterChip`, `TextField`, conteúdo do modal de Skill Tree — continuam
  Material padrão (ver "Decisões confirmadas" acima).
- Textos/rótulos não mudam — só o widget visual por trás de cada um.

## Peças reaproveitáveis novas

Duas pequenas extrações, pra não duplicar código entre a Home e as três
telas:

- **`ArenaBackdropPainter`** (`pixel_arena_background.dart`): a classe
  `CustomPainter` que hoje é privada dentro de `home_screen.dart`
  (`_BackdropPainter`) vira pública e reaproveitável — chama
  `drawArenaBackdrop` (já existente). A Home passa a usar essa classe
  pública em vez de duplicar a sua própria.
- **`PixelOutlinedText`** (novo, `game_presentation`): o texto com
  contorno (hoje só o método privado `_title()` da Home) vira um widget
  reaproveitável, parametrizado por texto/tamanho/cor — usado pelo título
  da Home E pelos títulos das três telas (menor).

## `PixelMenuButton` ganha estado desabilitado

`onPressed` passa de `VoidCallback` (obrigatório, sempre chamável) pra
`VoidCallback?` — quando nulo, o botão fica com opacidade reduzida e não
responde a toque (mesmo espírito do `ElevatedButton.onPressed: null`, que
é exatamente o que ele substitui). Os dois testes que hoje verificam botão
desabilitado via `tester.widget<ElevatedButton>(...)` passam a verificar
`tester.widget<PixelMenuButton>(...)` — mesma ideia, tipo novo.

## Fundo + painel de conteúdo (as três telas)

Cada tela passa a ser um `Stack`: `ArenaBackdropPainter` (`CustomPaint`)
ocupando a tela toda, com o `Scaffold` (fundo transparente, `AppBar`
transparente sem sombra, título via `PixelOutlinedText` menor) por cima.
Isso sozinho deixaria o conteúdo existente (texto preto, chips, divisores)
meio "flutuando" sobre um fundo colorido, então o corpo de cada tela
(o que já existe: `SingleChildScrollView`/`Padding`/`Column`) passa a ficar
dentro de um painel — um `Container` com fundo quase opaco (mesma cor
creme do HUD/painéis já usados) e borda escura, no mesmo espírito visual
do `BattleHudWidget`/`PixelMenuButton`. Nada do que está DENTRO do painel
muda (mesmos widgets, mesma lógica) — só ganha esse "cartão" por trás pra
continuar legível.

## Botões trocados por `PixelMenuButton`

- `TrainingScreen`: "Jogar" (desabilitado sem seleção), "Nova partida".
- `MultiplayerLobbyScreen`: "Criar partida", "Entrar com código",
  "Reconectar" (os dois últimos continuam lado a lado, como hoje).
- `MultiplayerBattleScreen`: "Jogar" (desabilitado fora da vez/sem
  seleção), "Revanche" (desabilitado enquanto inicia).

`OutlinedButton` ("Reconectar") também vira `PixelMenuButton` — sem
`primary` (mesmo visual "secundário" creme que os outros não-destacados —
não há uma variante visual "outline" nova nesta tarefa, YAGNI).

## Consequência nos testes existentes

- `app/test/training_screen_test.dart`: o teste "the play button is
  disabled..." troca `tester.widget<ElevatedButton>(...)` por
  `tester.widget<PixelMenuButton>(...)`.
- `app/test/multiplayer_battle_screen_test.dart`: mesma troca no teste
  equivalente.
- Nenhum outro teste depende do tipo concreto `ElevatedButton`/
  `OutlinedButton`/`TextField` nessas telas (confirmado por busca no
  repositório) — os demais testes procuram por texto (`find.text(...)`),
  que não muda.

## Testes esperados (novos/ajustados)

- `PixelMenuButton`: novo teste — com `onPressed: null`, não lança ao
  tocar e não chama nada (não há efeito observável de "desabilitado" além
  de não disparar o callback, já que não há callback nenhum passado).
- `ArenaBackdropPainter`/`PixelOutlinedText`: sem teste de pixel
  renderizado (mesma limitação já aceita em todo o projeto) — só
  confirmam que constroem sem lançar.
- Testes de tela ajustados conforme "Consequência nos testes existentes"
  acima.
- Verificação manual via `flutter run -d web-server`: navegar
  Home → Treino → voltar → Multiplayer → Lobby → criar partida, e
  confirmar visualmente que as três telas têm a mesma "cara" da Home, com
  o conteúdo existente ainda legível e funcionando (jogar uma combinação,
  criar uma partida).

## Fora de escopo, mas não esquecido

Chips de elemento, campos de texto, conteúdo do modal de Skill Tree —
ficam pro próximo bloco de "feedback visual"/UI mais focado.
