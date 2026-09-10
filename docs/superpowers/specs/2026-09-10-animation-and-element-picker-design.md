# Animações + painel de seleção de elementos (Bloco 6) — design

Data: 2026-09-10
Status: aprovado pelo usuário, pronto para virar plano de implementação.

## Contexto

Continuação da nova direção de produto (CLAUDE.md, "Direção de produto (game
feel)"). Identidade visual (Blocos 2/3) e feedback visual (Blocos 4/5) já
receberam vários blocos de investimento — o próximo item sem bloco dedicado
na ordem de prioridade é "animações". Hoje só existe uma animação implícita
no jogo: a barra de HP do `BattleHudWidget` (`TweenAnimationBuilder`, de
antes desta direção de produto). Tudo o resto é estático: sprites parados,
botões sem resposta de toque além de opacidade quando desabilitados,
navegação no `MaterialPageRoute` padrão.

Durante o brainstorming, o usuário também apontou um problema de UX ligado
a isso: a tela de batalha (Treino e Multiplayer) rola porque a lista dos 10
elementos ocupa várias linhas sempre visíveis. A solução escolhida — mover
essa lista pra um painel que sobe de baixo (reaproveitando o
`PixelSheetPanel` do Bloco 5) — entrou neste bloco porque depende
diretamente da mesma peça visual (painel subindo) que as animações de
transição de tela também usam, e porque resolve um problema real de
usabilidade, não só estética.

## Decisões confirmadas (conversa com o usuário)

1. **Escopo**: as três animações (idle nos sprites, "afundar" nos botões,
   transição de tela) MAIS o painel de seleção de elementos, no mesmo
   bloco.
2. **Idle nos sprites**: Home E cena de batalha (Treino/Multiplayer) — não
   só a Home.
3. **Transição de tela**: slide de baixo pra cima (não fade) — reforça a
   identidade "painel de jogo" que o `PixelSheetPanel` já estabeleceu.
4. **Seletor de elementos**: painel subindo de baixo (reaproveita
   `PixelSheetPanel`), não um menu radial — mais simples, menos trabalho,
   resolve o mesmo problema.

## O que NÃO está neste bloco

- Nenhuma mudança em `battle_engine`, `backend`, `TrainingMatch`,
  `MultiplayerMatch` — puramente apresentação.
- Nenhuma mudança na sequência de feedback de ataque (`AttackSequencePlayer`,
  Bloco 1/DECISION-031) — já cobre a parte mais crítica de "batalha"; este
  bloco só adiciona o idle *por cima* dela (ver seção própria sobre como as
  duas coexistem sem conflito).
- `FilterChip`/`TextField`/modal de Skill Tree já resolvidos no Bloco 5 —
  não revisitados aqui, exceto que o modal de Skill Tree e o novo painel de
  elementos passam a compartilhar exatamente o mesmo `PixelSheetPanel`
  (nenhum widget novo de painel).
- Nenhum "auto-fechar ao escolher 3 elementos" no painel novo — fecha só
  quando o jogador toca "Confirmar" (mesmo padrão manual do "Fechar" do
  modal de Skill Tree).

## 1. Sprites "vivos" (idle)

**Home (`TrainerSpriteImage`)**: passa de `StatelessWidget` para
`StatefulWidget` com `SingleTickerProviderStateMixin`. Um
`AnimationController` (`duration: 1600ms`) repetindo com reversão
(`repeat(reverse: true)`) dirige um `Tween<double>(begin: -2, end: 2)` com
`CurvedAnimation(curve: Curves.easeInOut)`; o valor vira um
`Transform.translate(offset: Offset(0, valor))` em volta do `CustomPaint`
existente. Nada na API pública do widget muda (`mirror`/`size` continuam
os mesmos parâmetros).

**Cena de batalha (`BattleCharacterComponent`, Flame)**: `update(double dt)`
ganha um acumulador `_idleTime += dt` e soma um deslocamento senoidal em Y
(mesma amplitude/período do idle da Home: 2px, ~1.6s de ciclo) à posição
base, por cima do que já existe:
- o shake de dano (`_hitEffectRemaining`) continua deslocando só X;
- o pulso de preparação (`_prepPulseRemaining`) continua sendo só escala no
  `render`, não mexe em posição;
- o idle bob desloca só Y, sempre, independente dos outros dois efeitos
  estarem tocando ou não.

Os três continuam ortogonais — nenhum precisa saber da existência dos
outros. Confirmado lendo `AttackSequencePlayer`: ele nunca escreve em
`attacker.position`/`target.position` diretamente (usa sua própria cópia
`_attackerPosition`/`_targetPosition`, capturada na criação, só pra
desenhar os efeitos visuais) — não há conflito entre a sequência de ataque
e o idle bob rodando ao mesmo tempo.

### Consequência em testes

- `battle_character_component_test.dart`, teste "the shake offsets
  position during the effect and restores it after": hoje checa
  `component.position == basePosition` (igualdade exata) depois do efeito
  de dano acabar. Com o idle bob, `position.y` nunca fica parado
  exatamente em `basePosition.y` — muda pra checar só
  `component.position.x == basePosition.x` (o shake é sempre só em X).
  Novo teste: chamar `update` em alguns instantes e confirmar que `y` varia
  (ex: `update(0.4)` e `update(0.8)` dão valores de Y diferentes um do
  outro, dentro da amplitude de 2px em torno de `basePosition.y`).
- `trainer_sprite_image_test.dart` e as 3 telas de `home_screen_test.dart`
  (que montam `HomeScreen`, com dois `TrainerSpriteImage`): cada teste
  precisa de uma linha final `await tester.pumpWidget(const SizedBox());`
  pra desmontar a árvore e descartar o `AnimationController` repetindo —
  mesmo motivo/mesmo padrão já usado nos testes de Multiplayer para os
  `Timer` de polling (comentário `// dispose the poll Timer` já existente
  no código). Sem esse pump final, o teste falha com timer/ticker pendente.
  **Nunca usar `pumpAndSettle()` em nenhum desses testes** — uma animação
  que repete infinitamente (`repeat(reverse: true)`) nunca deixa de agendar
  frames, e `pumpAndSettle()` trava esperando isso acontecer.

## 2. Botões "afundando" ao toque

`PixelMenuButton` e `PixelElementChip` passam de `StatelessWidget` para
`StatefulWidget` com um `bool _pressed` local. `GestureDetector` ganha
`onTapDown`/`onTapUp`/`onTapCancel` (além do `onTap` que já existia) —
`onTapDown` seta `_pressed = true`, os outros dois voltam pra `false`
(nenhum dos dois faz nada se `onPressed`/`onTap` for nulo, pra não animar
um botão desabilitado). O `Container` vira `AnimatedContainer`
(`duration: 80ms`): quando `_pressed`, `transform:
Matrix4.translationValues(3, 3, 0)` (desloca o conteúdo na direção da
sombra) e `boxShadow: const []` (a sombra some); quando não, volta pro
`transform`/`boxShadow` de hoje. Isso simula fisicamente o botão afundando
até "encostar" onde a sombra estava — sem mudar o tamanho/posição visual
total do widget (evita relayout dos vizinhos em `Wrap`/`Column`).
`AnimatedContainer` é implícito (padrão já simples do projeto, sem precisar
de outro `AnimationController` manual pra isso).

Nenhuma mudança na lógica de habilitado/desabilitado (`onPressed`/`onTap`
nulo continua desenhando com opacidade reduzida e ignorando toques, exatamente
como hoje).

### Consequência em testes

Nenhuma mudança nos testes existentes (`tester.tap` já simula um gesto
completo de down+up, então o `onTap`/`onPressed` original ainda dispara
normalmente). Testes novos: simular um toque sustentado com
`tester.startGesture` e checar que o `AnimatedContainer` interno tem
`transform` deslocado enquanto pressionado e volta a `Matrix4.identity()`
(offset zero) depois de soltar — ver seção "Testes esperados" abaixo pro
código exato.

## 3. Transições de tela

Novo helper `pixelSlideRoute<T>(WidgetBuilder builder)` em
`game_presentation/pixel_page_route.dart`: um `PageRouteBuilder<T>`
(`transitionDuration`/`reverseTransitionDuration: 300ms`) cujo
`transitionsBuilder` desliza a tela nova de baixo pra cima
(`Tween<Offset>(begin: Offset(0, 1), end: Offset.zero)` com
`Curves.easeOutCubic`, embrulhado num `SlideTransition`) — mesmo espírito
visual do `PixelSheetPanel`, agora pra navegação de tela inteira.

Substitui `MaterialPageRoute` nos 4 pontos onde é usado hoje:
- `home_screen.dart`: Home → `TrainingScreen`, Home → `MultiplayerLobbyScreen`.
- `multiplayer_lobby_screen.dart`: Lobby → `MultiplayerBattleScreen` (criar/
  entrar/reconectar, `_run`).
- `multiplayer_battle_screen.dart`: Revanche → `MultiplayerBattleScreen`
  nova (`pushReplacement`, `_startRematch`).

### Consequência em testes

Nenhuma mudança esperada. `find.text`/`find.byType` não dependem do estado
da animação de transição — encontram o widget na árvore independente de
onde ele está sendo desenhado. Os testes que tocam algo logo depois de uma
navegação (`home_screen_test.dart`, `training_screen_test.dart`) já usam
`await tester.pump(); await tester.pump(const Duration(milliseconds:
400));` depois de cada navegação (herdado da necessidade de esperar o
modal de Skill Tree assentar) — 400ms já é folga suficiente pra uma
transição de 300ms.

## 4. Seletor de elementos vira painel

A lista de 10 `PixelElementChip` sempre visível (`Wrap` dentro do corpo de
`TrainingScreen._buildPlayForm`/`MultiplayerBattleScreen._buildBattle`) sai
do corpo da tela. No lugar:

```
Text(_selectedElementsSummary(elements))   // "Elementos: 🔥 Fogo, 🌪️ Vento"
                                            // ou "Nenhum elemento escolhido"
SizedBox(height: 8)
PixelMenuButton(label: 'Escolher elementos', onPressed: <condição>)
SizedBox(height: 16)
PixelMenuButton(label: 'Jogar', onPressed: <condição já existente, sem mudar>)
```

`_selectedElementsSummary` é um método privado (um em cada tela, mesma
implementação — as duas telas já não compartilham uma classe base, então
não vale introduzir uma só pra isso):

```dart
String _selectedElementsSummary(List<ElementOption> elements) {
  final selected = elements.where((e) => _selectedIds.contains(e.id));
  if (selected.isEmpty) return 'Nenhum elemento escolhido';
  return 'Elementos: ${selected.map((e) => '${e.symbol} ${e.name}').join(', ')}';
}
```

`onPressed` de "Escolher elementos": no Treino, sempre não-nulo (hotseat,
sem restrição de vez — igual ao `onTap` que os chips já tinham antes deste
bloco). No Multiplayer, `_match.isMyTurn ? _openElementPicker : null` —
exatamente a mesma condição que já limitava cada chip individualmente.

`_openElementPicker()` abre um `showModalBottomSheet` com
`backgroundColor: Colors.transparent`, embrulhando o conteúdo num
`PixelSheetPanel` (mesmo componente do modal de Skill Tree, Bloco 5) — sem
`SizedBox` de altura fixa dessa vez, porque o conteúdo (título + `Wrap` de
chips + botão) é naturalmente curto, sem precisar rolar:

```
PixelSheetPanel(
  child: Padding(
    padding: EdgeInsets.all(16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PixelOutlinedText('Escolha de 1 a 3 elementos', fontSize: 18),
        SizedBox(height: 12),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: [
            for (elemento) PixelElementChip(
              label: ...,
              selected: _selectedIds.contains(elemento.id),
              onTap: <mesma condição de antes>(() {
                _toggleElement(elemento.id); // já faz setState
                setSheetState(() {});        // mesmo padrão do modal de Skill Tree
              }),
            ),
          ],
        ),
        SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: PixelMenuButton(label: 'Confirmar', onPressed: () => Navigator.of(context).pop()),
        ),
      ],
    ),
  ),
)
```

`showModalBottomSheet` builder usa `StatefulBuilder` (mesmo padrão do modal
de Skill Tree) pra que tocar um chip atualize a seleção dentro do painel
sem fechar/reabrir. Tocar fora do painel (barreira padrão) fecha sem
confirmar explicitamente — comportamento padrão do `showModalBottomSheet`,
igual ao modal de Skill Tree já tem hoje (nunca configurado como
não-dispensável).

### Consequência em testes

- `training_screen_test.dart`: dois lugares tocam `find.text('🔥
  Fogo')`/`'🌪️ Vento'` direto na tela — passam a abrir o painel primeiro
  (`tester.tap(find.text('Escolher elementos')); pump(); pump(400ms);`),
  tocar o(s) chip(s) dentro dele, fechar com `tester.tap(find.text('Confirmar'));
  pump(); pump(400ms);`, e só then seguir pro `ensureVisible`/tap em
  "Jogar" como já faziam.
- `multiplayer_battle_screen_test.dart`, teste "shows HP/turn for an
  in-progress match and plays a combo turn": o comentário existente já
  documenta que beto tenta jogar fora da vez (o teste simula um estado onde
  ainda é a vez de "ana") — hoje isso funciona porque o `onTap` do chip já
  era nulo nesse caso (toque inerte, sem crash). Com o painel, "Escolher
  elementos" fica desabilitado antes mesmo de o painel abrir, então
  `find.text('🔥 Fogo')` não existe mais na árvore pra tocar. Troca as duas
  linhas de tap por uma checagem direta (mesmo padrão já usado pro "Jogar"
  logo abaixo):
  ```dart
  final pickerButton = tester.widget<PixelMenuButton>(
    find.widgetWithText(PixelMenuButton, 'Escolher elementos'),
  );
  expect(pickerButton.onPressed, isNull);
  ```
- Nenhuma outra ocorrência de `find.text('🔥 Fogo')`/chips de elemento em
  testes de tela (confirmado por busca no repositório) além dessas duas.

## Testes esperados (novos/ajustados)

- `pixel_menu_button_test.dart`/`pixel_element_chip_test.dart`: novo teste
  de "afundar" — `tester.startGesture` no centro do widget, `pump()` +
  `pump(80ms)`, checar `tester.widget<AnimatedContainer>(...).transform ==
  Matrix4.translationValues(3, 3, 0)`; depois `gesture.up()`, `pump()` +
  `pump(80ms)`, checar `transform == Matrix4.translationValues(0, 0, 0)`.
- `trainer_sprite_image_test.dart`: teste existente ganha
  `await tester.pumpWidget(const SizedBox());` no final.
- `home_screen_test.dart`: os 3 testes existentes ganham a mesma linha
  final.
- `battle_character_component_test.dart`: teste de shake ajustado (ver
  seção 1) + novo teste do idle bob.
- `training_screen_test.dart`/`multiplayer_battle_screen_test.dart`:
  ajustados conforme a seção 4 acima — suíte roda sem nenhum outro teste
  quebrando.
- Verificação manual via `flutter run -d web-server` (servidor reiniciado,
  não só recarregado — lição do Bloco 3): Home com os dois personagens
  balançando sutilmente; Modo Treino com balanço nos personagens da
  batalha, botão "Escolher elementos" abrindo o painel de baixo, seleção
  funcionando, "Confirmar" fechando, jogada real disparando um combo (a
  sequência de ataque do Bloco 1 continua tocando normalmente por cima do
  idle bob); botões com efeito de "afundar" visível ao segurar o clique;
  navegação Home → Treino/Multiplayer com slide de baixo pra cima.

## Fora de escopo, mas não esquecido

Nenhum gap novo identificado além dos já registrados no BACKLOG.
