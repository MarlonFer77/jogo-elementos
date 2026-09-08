# Arena de batalha pixel art (Bloco 2) — design

Data: 2026-09-08
Status: aprovado pelo usuário, pronto para virar plano de implementação.

## Contexto

Continuação da nova direção de produto (CLAUDE.md, "Direção de produto (game
feel)"). O Bloco 1 (DECISION-031) deu à batalha uma sequência real de feedback
de ataque, mas o visual em si (fundo aquarela CC0, personagens como blobs
coloridos sem forma, barra de HP flutuando sobre cada um) ainda não tem
identidade — é o que este bloco resolve, endereçando a prioridade #1 da
direção de produto ("identidade visual") aplicada especificamente à cena de
batalha (prioridade #2, "a batalha é o coração do jogo").

Pedido do usuário: "adapte a central de treino, quero um campo de batalha e
avatares estilo jogos de luta porém como se fosse bonecos de gameboy (tipo de
pokemon), faça tudo com código mesmo". Como `BattleSceneGame`/
`BattleCharacterComponent`/`BattleSceneWidget` já são compartilhados entre
Modo Treino e Multiplayer (decisão da DECISION-030/031), esta mudança vale
para os dois automaticamente.

Direção visual validada com o usuário via mockup no companion de brainstorming
(HUD fixo no topo + arena pixelada + bonecos em pixel art, contorno preto
grosso, cores só variando por lado) — aprovada sem ajustes.

## Decisões confirmadas (conversa com o usuário)

1. **Referência visual**: sprite de batalha estilo Pokémon GBA/GBC — pixel
   art colorido, não o Game Boy monocromático (DMG) original.
2. **Identidade dos personagens**: continuam genéricos por lado (sem escolha
   de avatar por jogador) — só a técnica de desenho muda, de forma simples
   pra pixel art de verdade.
3. **Layout**: vira estilo jogo de luta — nome + barra de HP fixos no topo
   da cena (um painel por lado), não mais flutuando sobre o personagem.
4. **Fundo**: também vira pixel art (céu + chão em blocos de cor), a imagem
   CC0 atual (`battlefield_bg.jpg`) sai de uso.
5. **Texto duplicado**: as linhas "Jogador A: X/Y HP" (Treino) / "Você:
   X/Y HP" (Multiplayer) que hoje ficam em texto simples abaixo da cena são
   removidas — a informação já fica bem visível no HUD novo. O resto do
   texto abaixo da cena (estados, descobertas, última combinação, campo
   ativo, chips, botão) continua exatamente como está.

## O que NÃO está neste bloco

- A sequência de ataque (`AttackSequencePlayer`: burst elemental, número de
  dano, texto de estado) continua exatamente como está hoje — não fica em
  pixel art nesta tarefa.
- Escolha/customização de avatar por jogador.
- Animação de "idle" contínua (respiração, balanço) — personagens parados,
  como já é hoje, só que desenhados diferente.
- Qualquer mudança em `battle_engine`, `backend/src/battle-rules/`,
  `TrainingMatch` ou `MultiplayerMatch` além do necessário para expor os
  rótulos ("Jogador A"/"Jogador B", "Você"/"Oponente") ao `BattleSceneView` —
  puramente apresentação.

## HUD (mudança de arquitetura)

O painel de HP no topo é **Flutter puro**, não desenhado no Canvas do Flame —
texto nítido, cantos arredondados, sombra, via `Container`/`BoxDecoration`,
em vez de reimplementar isso à mão. `BattleSceneWidget` deixa de ser só um
`SizedBox` em torno do `GameWidget` e passa a ser um `Stack`: o `GameWidget`
(arena, personagens, sequência de ataque — tudo Flame) embaixo, e um novo
`BattleHudWidget` (Flutter) por cima, ocupando a faixa superior, mostrando
nome + barra de HP dos dois lados.

O indicador de "vez" (hoje um contorno amarelo desenhado no personagem)
migra pro painel ativo do HUD (borda/destaque diferente) — sai do
`BattleCharacterComponent` inteiramente.

`BattleSceneView` ganha dois campos novos, `String leftLabel` e
`String rightLabel` (ex.: "Jogador A"/"Jogador B" no Treino, "Você"/
"Oponente" no Multiplayer) — cada tela já sabe esse texto hoje (usa em
outros lugares da própria tela), só passa a repassar pro HUD também.

A animação suave da barra de HP (hoje um "chase" manual dentro de
`BattleCharacterComponent.update(dt)`) deixa de existir ali — vira uma
animação implícita do Flutter (`TweenAnimationBuilder` no `BattleHudWidget`),
mais simples que o código manual que tinha antes.

## Personagens em pixel art

Uma grade pequena e fixa (16 colunas × 20 linhas) de índices de cor,
definida como dado (`List<List<int>>`), representando um "bonequinho"
genérico de corpo inteiro visto de frente/três-quartos — cabeça arredondada
com contorno escuro, tronco retangular na cor principal (com uma faixa mais
escura de sombra de um lado e um "cinto" de detalhe), duas pernas. Mesmo
espírito do mockup já aprovado.

Paleta curta e compartilhada entre os dois lados:

| Índice | Uso | Cor |
|---|---|---|
| 0 | transparente | — |
| 1 | contorno | `#20242B` |
| 2 | pele | `#F4C99B` |
| 3 | cabelo/detalhe escuro | `#2B2F38` |
| 4 | cor principal (varia por lado) | `#3D6FE0` (esquerda) / `#E0503D` (direita) |
| 5 | sombra da cor principal | `#2B52B0` (esquerda) / `#B02B2B` (direita) |
| 6 | cinto/detalhe | `#F4C94A` |

A MESMA grade serve pros dois lados — só os índices 4/5 (cor principal/
sombra) trocam de valor real conforme o lado, o resto da paleta é idêntico.
O lado direito é desenhado espelhado (`canvas.scale(-1, 1)` antes de
desenhar, mesma técnica já usada no pulso de preparação).

Uma função utilitária (`game_presentation`, não acoplada a
`BattleCharacterComponent`) desenha qualquer grade desse formato no
`Canvas`: percorre linhas/colunas, ignora índice 0, desenha um `Rect`
colorido por pixel do tamanho escolhido (`pixelSize`, ex. 8px lógicos por
"pixel" da grade — dá um sprite de ~128×160px na tela). Reutilizável para
qualquer sprite futuro no mesmo estilo, não só este bonequinho.

`BattleCharacterComponent` passa a chamar essa função no lugar do desenho
atual (corpo arredondado + círculo da cabeça). Mantém: posição, lado, flash
de dano (agora como um overlay branco semi-transparente sobre toda a área
do sprite, mesma ideia de antes só que cobrindo a grade em vez do RRect) e
pulso de preparação (mesmo `canvas.scale` de escala, só que envolvendo o
desenho da grade). Perde: fração de HP, barra de HP, contorno de turno —
esse estado e esse desenho não existem mais aqui (foram pro HUD).

## Fundo (arena)

Uma função/component simples substitui o `SpriteComponent` com a imagem
CC0: poucos blocos de cor sólida — uma faixa de céu, uma linha de horizonte,
uma faixa de chão — desenhados diretamente no `Canvas`, sem imagem nenhuma.
Nada elaborado: o objetivo é combinar com os personagens pixelados, não
competir com eles visualmente. `battlefield_bg.jpg` e a declaração
`assets:` correspondente no `pubspec.yaml` são removidos (asset não usado
em lugar nenhum depois desta tarefa).

## Testes esperados

- Função de desenho da grade de pixels: teste de estrutura/dado (dimensões
  da grade, paleta com o número certo de cores, nenhum índice fora do
  range) — não há como testar pixel renderizado automaticamente, mesma
  limitação já aceita para todo o resto do desenho manual neste projeto
  (verificação visual cobre a parte de "ficou bonito").
- `BattleCharacterComponent`: testes existentes de flash/pulso continuam
  válidos; os testes de fração de HP interpolada são removidos (a lógica
  não existe mais ali).
- `BattleHudWidget`: teste de widget isolado (fora da árvore do
  `GameWidget`, então sem o problema de `pumpAndSettle` travando) —
  mostra nome/HP dos dois lados, painel ativo destacado conforme
  `isLeftTurn`.
- Testes de widget de `TrainingScreen`/`MultiplayerBattleScreen`: ajustar
  as asserções que hoje procuram o texto "Jogador A: X/Y HP" /
  "Você: X/Y HP" (removido) — o resto continua igual.
- Verificação manual via `flutter run -d web-server`: cena com HUD no
  topo, personagens pixelados reconhecíveis, sequência de ataque
  continuando a funcionar sobre o novo visual, nos dois modos.

## Fora de escopo, mas não esquecido

Sequência de ataque em pixel art, escolha de avatar, animação de idle,
sprites por elemento/combinação — tudo já listado em "O que NÃO está neste
bloco".
