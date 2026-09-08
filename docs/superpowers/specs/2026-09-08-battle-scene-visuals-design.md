# Cenário de batalha visual (Flame) — design

Data: 2026-09-08
Status: aprovado pelo usuário, pronto para virar plano de implementação.

## Contexto

Hoje `TrainingScreen` e `MultiplayerBattleScreen` — as duas únicas telas onde
se joga de verdade — são puro Material (chips de elemento, texto de HP/vez,
botões). Não existe nenhuma representação visual da batalha. O único código
Flame do projeto (`BattleView`, `BattleGame`, `BattleScreen`, `DemoBattle`)
é uma demo isolada, nunca conectada a `TrainingMatch`/`MultiplayerMatch` —
confirmado lendo os quatro arquivos: `BattleGame` só desenha `TextComponent`s
com nome/vez/campo, `DemoBattle` roda um turno fixo entre "Ana"/"Beto"
hardcoded, e `BattleScreen` é acessível só pelo botão "Batalha (demo)" no
`HomeScreen`.

O usuário testou o APK e sentiu falta de um cenário de batalha e personagens.
Autorizou explicitamente usar sites externos GRATUITOS com arte pronta, ou
fazer só em código — escolha do desenvolvedor.

## Decisões confirmadas (conversa com o usuário)

1. **Escopo**: Treino e Multiplayer, os dois, desde já — não é só uma tela.
2. **Personagens**: genéricos, diferenciados só por lado (esquerda/direita),
   não por elemento nem por jogador específico.
3. **Nível de animação**: cenário e personagens parados (sem sprite
   animation), com efeitos simples (flash + leve shake ao tomar dano).
4. **Fonte da arte**: abordagem híbrida — fundo é uma imagem pronta
   CC0/domínio público (OpenGameArt.org ou Kenney.nl); personagens são
   formas simples desenhadas em código (sem depender de achar um asset pack
   que sirva genericamente para "dois lados").
5. **Layout de informação**: a cena Flame fica no topo da tela; HP/vez/chips
   de elemento/botões continuam exatamente como são hoje (widgets Material
   abaixo da cena). Não migrar HP para dentro da cena.

## O que NÃO está nesta tarefa

- Sprites diferentes por elemento ou por combinação.
- Animação de movimento/ataque (só flash + shake no dano).
- Mudança de regras, dano, HP ou qualquer coisa em `battle_engine` ou
  `backend/src/battle-rules/` — puramente apresentação.
- Status visual (ícone de Escudo/Queimadura sobre o personagem): o
  `RemoteBattleState` do Multiplayer não expõe estados ativos por jogador
  hoje (só HP, vez, campo, vencedor) — adicionar isso seria mudar o
  contrato do backend, fora do escopo desta tarefa. Os efeitos visuais
  desta tarefa reagem só a variação de HP (dano), que já está disponível
  nas duas telas sem nenhuma mudança de backend.
- Barra de vida "real" com números sobrepostos na cena — a barra visual é
  só indicativa (fração de HP); os números continuam no texto Material
  abaixo, como já é.

## Modelo de dados (`app/lib/game_domain`)

### `BattleSceneView` (novo, substitui `BattleView`)

```dart
class BattleSceneView {
  final int leftCurrentHp;
  final int leftMaxHp;
  final int rightCurrentHp;
  final int rightMaxHp;
  final bool isLeftTurn;

  const BattleSceneView({
    required this.leftCurrentHp,
    required this.leftMaxHp,
    required this.rightCurrentHp,
    required this.rightMaxHp,
    required this.isLeftTurn,
  });
}
```

Classe de dados pura, sem lógica (mesmo espírito de `BattleView` hoje) — não
depende de `battle_engine` nem de Flutter/Flame. Convenção de "esquerda"/
"direita":

- `TrainingScreen`: esquerda = Jogador A, direita = Jogador B (usa
  `_match.playerACurrentHp/playerAMaxHp/playerBCurrentHp/playerBMaxHp`;
  `isLeftTurn = _match.currentTurnName == 'Jogador A'` via comparação de id,
  não de nome — ver nota de implementação abaixo).
- `MultiplayerBattleScreen`: esquerda = eu, direita = oponente (usa
  `_match.myCurrentHp/myMaxHp/opponentCurrentHp/opponentMaxHp/isMyTurn`).

Nenhuma mudança em `TrainingMatch`/`MultiplayerMatch`/`RemoteBattleState` —
tudo que a view precisa já é exposto hoje.

**Nota de implementação**: `TrainingMatch` hoje só expõe `currentTurnName`
(uma `String`), não um booleano "é a vez do jogador A". Para montar
`isLeftTurn` sem comparar strings (frágil), `TrainingMatch` ganha um getter
`bool get isPlayerATurn` (== ao já existente `_isPlayerATurn` privado, só
exposto publicamente) — mudança trivial, não mexe em nenhuma regra.

## Apresentação (`app/lib/game_presentation`)

### `BattleSceneGame` (novo, substitui `BattleGame`)

`FlameGame` que:

1. No `onLoad`, carrega o sprite de fundo (`assets/images/battlefield_bg.<ext>`,
   ver seção de assets) como um `SpriteComponent` cobrindo o `size` do jogo
   (`size: this.size`, redimensiona via `onGameResize`).
2. Cria dois `BattleCharacterComponent` (novo componente, formas simples —
   ex.: `RRect`/círculo representando um "corpo" genérico, desenhado via
   `PositionComponent.render`, sem depender de imagem externa), posicionados
   nos cantos inferiores esquerdo/direito. Diferenciados só por cor (ex.:
   tom azulado para "esquerda", avermelhado para "direita").
3. Cada `BattleCharacterComponent` tem uma barra de HP simples acima de si
   (retângulo de fundo + retângulo colorido escalado pela fração
   `current/max`) e um indicador de turno (contorno/brilho quando é o lado
   ativo).
4. Método público `updateView(BattleSceneView view)`: compara
   `view.leftCurrentHp`/`rightCurrentHp` com os últimos valores vistos
   (guardados em campos privados, inicializados no primeiro `updateView`
   sem disparar efeito). Se o HP de um lado caiu, chama
   `BattleCharacterComponent.playHitEffect()` nesse lado (flash de cor via
   `ColorEffect` + pequeno deslocamento via `MoveEffect`/`SequenceEffect`,
   ambos nativos do pacote `flame`). Sempre atualiza a barra de HP e o
   indicador de turno, independentemente de ter havido dano.

A comparação "HP caiu → disparar efeito" fica em um método isolado e puro
(recebe HP antigo/novo, devolve `bool`), testável sem precisar do game loop
do Flame.

### `BattleCharacterComponent` (novo)

`PositionComponent` com corpo desenhado em código + sub-componentes de barra
de HP e indicador de turno. `playHitEffect()` adiciona os `Effect`s de
flash/shake ao componente.

## UI (`app/lib/ui` + novo widget em `game_presentation`)

### `BattleSceneWidget` (novo)

Widget Flutter fino: `SizedBox` de altura fixa (ex.: 220px) contendo um
`GameWidget(game: ...)`. O `BattleSceneGame` é criado uma vez (`late final`
no `State`) e atualizado chamando `game.updateView(...)` sempre que a tela
já chamaria `setState` (mesmo ponto onde hoje ela só re-renderiza texto).

### `TrainingScreen` / `MultiplayerBattleScreen` (alterados)

Cada uma ganha, no topo do `Column` do `build()` (antes do texto "Vez de.../
Sua vez"), um `BattleSceneWidget` construído a partir do `BattleSceneView`
montado como descrito acima. Todo o resto do layout (chips, botões, texto de
HP/estado/campo) permanece idêntico ao de hoje.

### Limpeza (código morto substituído)

Removidos: `app/lib/game_domain/battle_view.dart`,
`app/lib/game_domain/demo_battle.dart`,
`app/lib/game_presentation/battle_game.dart`,
`app/lib/ui/battle_screen.dart`, o botão "Batalha (demo)" em
`home_screen.dart`, e os testes correspondentes
(`app/test/game_domain/demo_battle_test.dart` e qualquer teste de
`battle_screen`/`battle_game`/`battle_view` existente). Justificativa: é uma
demo explicitamente rotulada como tal, nunca usada por um fluxo real, e
mantê-la ao lado da cena de verdade só geraria confusão (regra de escopo do
CLAUDE.md não impede remover código morto do próprio sistema que a tarefa
está tocando).

## Assets

Uma única imagem de fundo, CC0/domínio público, de um cenário genérico de
batalha (arena, campo, ou similar — sem elementos/personagens específicos
demais, já que os "personagens" reais são as formas em código por cima).
Fonte: OpenGameArt.org ou Kenney.nl (ambos com packs CC0 sem exigência de
atribuição). Arquivo salvo em `app/assets/images/battlefield_bg.<ext>`,
declarado em `pubspec.yaml` (`flutter.assets`). A URL/licença da imagem
escolhida é registrada em `DECISIONS.md` ao final da tarefa (rastreabilidade
— não é um serviço pago, custo zero, mas fica documentado de onde veio).

Sem custo: é um download único de um arquivo estático, sem chamada a
serviço externo em tempo de execução, sem violar a regra de custo do
CLAUDE.md.

## Testes esperados

### `app/test/game_domain`
- `BattleSceneView`: construção simples guarda os valores (mesmo padrão
  trivial de `BattleView` hoje, se houver teste equivalente).
- `TrainingMatch.isPlayerATurn`: reflete `currentTurnName` corretamente nos
  dois lados.

### `app/test/game_presentation`
- Função/método de detecção de dano (HP antigo vs. novo → disparou efeito
  ou não): casos de HP igual (sem efeito), HP menor (dispara), HP maior —
  não deveria acontecer na prática, mas não deve quebrar (sem efeito).
- `BattleSceneGame.updateView`: chamado duas vezes com o mesmo lado tomando
  dano dispara o hit effect só nesse lado, não no outro.

### `app/test` (widget)
- `TrainingScreen`/`MultiplayerBattleScreen`: os testes de widget existentes
  continuam passando com o `BattleSceneWidget` adicionado no topo (ajustar
  apenas se algum finder colidir com algo novo). Não é necessário testar o
  conteúdo visual do Flame em teste de widget — isso é responsabilidade dos
  testes de `game_presentation`.

### Verificação manual
Como build Android local tem limitação de ambiente conhecida (ver
DECISION-015/029), a verificação visual será feita via `flutter run -d
chrome` (Flutter Web), visível no Browser pane, antes de considerar a
tarefa concluída — sem precisar gerar um novo APK só para isso (o cenário
entra num próximo APK quando fizer sentido, não é obrigatório rodar essa
verificação especificamente via Android).

## Fora de escopo, mas não esquecido

- Ícones de status (Escudo/Queimadura) sobre o personagem — depende de
  `RemoteBattleState` expor estados ativos por jogador no Multiplayer, que
  é uma mudança de contrato do backend fora desta tarefa.
- Sprites por elemento/combinação, animações de ataque, cenário
  reagindo a efeitos de campo (ex.: fundo mudando com Lava ativa).
- Novo APK — o cenário passa a existir no código; gerar e distribuir um
  novo APK com ele é uma ação separada, não implícita nesta tarefa.
