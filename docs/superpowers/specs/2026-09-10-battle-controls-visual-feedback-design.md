# Chips, campos de texto e modal de Skill Tree em pixel art (Bloco 5) — design

Data: 2026-09-10
Status: aprovado pelo usuário, pronto para virar plano de implementação.

## Contexto

Continuação da nova direção de produto (CLAUDE.md, "Direção de produto (game
feel)"). O Bloco 4 (DECISION-034) vestiu o fundo/título/botões de Treino,
Lobby e batalha Multiplayer no mesmo estilo pixel art da Home, mas deixou
explicitamente de fora três peças que continuam Material padrão, sem nenhum
tratamento visual customizado: os chips de seleção de elemento
(`FilterChip`), os campos de texto da Lobby (`TextField`) e o conteúdo do
modal de Skill Tree (`ListTile`/`TextButton` dentro de um bottom sheet
branco comum). São justamente os elementos com que o jogador mais interage
durante uma partida — escolher elementos e desbloquear habilidades — então
o choque visual ali é o mais sentido.

## Decisões confirmadas (conversa com o usuário)

1. **Escopo**: as três frentes (chips, campos de texto, modal de Skill
   Tree) no mesmo bloco — fecha o gap de "feedback visual" documentado no
   BACKLOG por completo, em vez de fatiar em blocos menores ainda.
2. **Estado selecionado do chip**: preenchimento dourado (mesma cor
   `0xFFF4C94A` que o `PixelMenuButton` primário usa) quando selecionado;
   creme (`0xFFF4F4E4`, cor "não selecionado" já usada nos outros
   componentes) quando não.
3. **Modal de Skill Tree**: tratamento completo — o próprio bottom sheet
   (não só o conteúdo dentro dele) ganha um painel pixel art, para parecer
   um painel de jogo subindo da parte de baixo da tela, não um bottom sheet
   genérico do Material.

## O que NÃO está neste bloco

- Nenhuma mudança em `battle_engine`, `backend`, `TrainingMatch`,
  `MultiplayerMatch` — puramente apresentação.
- Nenhuma mudança na cena de batalha (`BattleSceneWidget`), no fundo/título/
  painel de conteúdo geral das telas, ou nos botões já trocados no Bloco 4
  — tudo isso já está no estilo novo.
- Textos/rótulos não mudam — só o widget visual por trás de cada um
  (`'🔥 Fogo'`, `'Desbloquear'`, `'Fechar'`, `'Seu nome'`,
  `'Código da partida'` continuam literalmente os mesmos).
- A modal de Habilidades do Multiplayer continuar sem escutar o polling
  (gap já documentado, DECISION-026) — fora de escopo, não é regressão
  nova.
- Nenhuma variante "outline"/"ghost" nova de botão — já resolvido no
  Bloco 4 (YAGNI).

## Peças reaproveitáveis novas (`game_presentation/`)

### `PixelElementChip`

Substitui `FilterChip` nas duas telas de batalha (`TrainingScreen`,
`MultiplayerBattleScreen`). Mesma família visual do `PixelMenuButton`:
`Container` com borda escura de 3px, sombra deslocada (`Offset(3, 3)`),
cantos levemente arredondados. Parâmetros: `label` (String, o texto
completo `'${symbol} ${name}'` já montado pela tela, igual hoje),
`selected` (bool), `onTap` (`VoidCallback?` — nulo quando não é a vez do
jogador, mesmo espírito de `PixelMenuButton.onPressed`).

- `selected: true` → fundo dourado (`0xFFF4C94A`).
- `selected: false` → fundo creme (`0xFFF4F4E4`).
- `onTap: null` → `Opacity(0.4)` + toque não faz nada (mesmo padrão já
  usado em `PixelMenuButton`).

Chama `onTap` diretamente (não recebe o `bool` que `FilterChip.onSelected`
recebe) — quem chama decide o novo estado, igual ao `_toggleElement(id)`
que as duas telas já têm hoje.

### `PixelTextField`

Substitui os dois `TextField` crus da `MultiplayerLobbyScreen`. Continua
sendo um `TextField` real por dentro — decisivo para não quebrar
`multiplayer_lobby_screen_test.dart`, que hoje interage via
`find.byType(TextField).first`/`.last` e `tester.enterText(...)`.
Parâmetros: `controller` (`TextEditingController`), `label` (String, vira
`InputDecoration.labelText`, mesmo texto de hoje: `'Seu nome'`/`'Código da
partida'`). Decoração customizada: borda box 3px cor escura (`InputBorder`
substituído por `OutlineInputBorder` sem raio ou com raio pequeno igual ao
`PixelMenuButton`), fundo preenchido creme (`filled: true, fillColor:
0xFFF4F4E4`), sem underline padrão do Material.

### `PixelSheetPanel`

Novo wrapper para o conteúdo do `showModalBottomSheet` de Skill Tree
(usado por `TrainingScreen._openSkillTree` e
`MultiplayerBattleScreen._openSkillTree`, hoje praticamente idênticos).
`Container` com fundo creme, borda escura de 3px só nos lados
esquerdo/direito/topo (sem borda inferior, que encosta na borda da tela) e
cantos superiores arredondados (`BorderRadius.only(topLeft, topRight)`).
`showModalBottomSheet` passa a receber `backgroundColor:
Colors.transparent` para essa decoração aparecer no lugar do fundo branco
padrão do Material.

## Mudanças por tela

### `training_screen.dart` / `multiplayer_battle_screen.dart` (mesma mudança nas duas)

- `_buildPlayForm`/`_buildBattle`: o `for (final element in elements)
  FilterChip(...)` dentro do `Wrap` vira `PixelElementChip(label: '${e.symbol}
  ${e.name}', selected: _selectedIds.contains(e.id), onTap: <condição de vez>
  ? () => _toggleElement(e.id) : null)`.
- `_openSkillTree`: o `builder` do `showModalBottomSheet` passa a envolver
  o conteúdo existente (`SizedBox` com o `Column`) num `PixelSheetPanel`;
  `showModalBottomSheet(backgroundColor: Colors.transparent, ...)`. Dentro:
  o `Text('Habilidades...')`/`Text('Habilidades de ...')` vira
  `PixelOutlinedText` (tamanho pequeno, ~18-20, consistente com os títulos
  de `AppBar` já usados no Bloco 4); cada nó desbloqueável ganha um
  `Container` com borda 3px (em vez do `ListTile` cru) envolvendo
  título/descrição; `TextButton('Desbloquear')` e `TextButton('Fechar')`
  viram `PixelMenuButton`.

### `multiplayer_lobby_screen.dart`

- Os dois `TextField(controller: ..., decoration: InputDecoration(labelText:
  ...))` viram `PixelTextField(controller: ..., label: ...)`.

## Consequência nos testes existentes

- `multiplayer_lobby_screen_test.dart`: **nenhuma mudança esperada** —
  continua usando `find.byType(TextField).first`/`.last` e
  `tester.enterText`, que funcionam contra o `TextField` interno do
  `PixelTextField` sem precisar saber que ele existe. Confirma-se rodando a
  suíte depois da troca.
- `training_screen_test.dart` e `multiplayer_battle_screen_test.dart`: os
  testes que tocam chips usam `find.text('🔥 Fogo')`/`find.text('🌪️
  Vento')` (por texto, não por tipo) — sem mudança esperada. O teste de
  Habilidades em `multiplayer_battle_screen_test.dart` usa
  `find.text('[fogo] Maestria da Brasa')`, `find.text('Desbloquear').first`,
  `find.text('Fechar')` — sem mudança esperada, mesmos textos.
- Nenhum teste depende do tipo concreto `FilterChip`/`TextButton`/`ListTile`
  nessas telas (confirmado por busca no repositório).

## Testes esperados (novos/ajustados)

- `PixelElementChip`: mostra o label, chama `onTap` ao tocar quando
  selecionado/não selecionado; com `onTap: null`, não lança e não chama
  nada.
- `PixelTextField`: mostra o label, aceita texto digitado e reflete no
  `controller` passado (equivalente ao que já se espera de um `TextField`).
- `PixelSheetPanel`: constrói sem lançar, envolve o `child` passado (sem
  teste de pixel renderizado, mesma limitação já aceita no projeto).
- Testes de tela: suíte completa roda sem nenhuma alteração esperada (ver
  seção acima) — serve como confirmação de que a troca foi só visual.
- Verificação manual via `flutter run -d web-server` (servidor reiniciado,
  não só recarregado — lição do Bloco 3): no Modo Treino, selecionar
  elementos e ver o chip dourado ao selecionar/creme ao desselecionar,
  abrir Habilidades e ver o painel pixel art subindo, desbloquear um nó de
  verdade; no Lobby, digitar nome num campo já restilizado e criar uma
  partida real.

## Fora de escopo, mas não esquecido

Nenhum gap novo identificado neste bloco além dos já registrados no
BACKLOG (modal de Habilidades do Multiplayer não escuta polling —
DECISION-026).
