# Tela de Skill Tree visual (Bloco 7) — design

Data: 2026-09-10
Status: aprovado pelo usuário, pronto para virar plano de implementação.

## Contexto

O usuário trouxe uma imagem de referência ("GAME DESIGN SKILL TREE"): uma
árvore de habilidades visual — nós em círculos coloridos com ícones,
conectados por linhas, organizados hierarquicamente. Hoje a "Skill Tree"
do jogo é só um modal (bottom sheet, desde o Bloco 5) com uma lista simples
dos nós **disponíveis agora** — sem visualização de árvore, sem ícones,
sem mostrar nós travados ou já desbloqueados junto dos disponíveis. É
aberto pelo botão "Habilidades" na AppBar, tanto no Modo Treino quanto no
Multiplayer, com duas implementações praticamente idênticas.

A estrutura de dados por trás já suporta uma árvore de verdade
(`packages/battle_engine`, Dart puro): `SkillNode` (id, nome, descrição,
`branch`, `prerequisites`, o que concede), `SkillTree` (grafo validado,
sem ciclos), `SkillProgress` (nós desbloqueados de um jogador,
`availableNodes`, `canUnlock`). `defaultSkillTree` hoje tem 8 nós em 5
branches (`fogo`, `precisao`, `elemental`, `vitalidade`, `defesa`) — cada
branch, na prática, é uma cadeia linear (0 ou 1 pré-requisito por nó,
nunca convergência nem ramificação real ainda), embora o modelo de dados
já permita as duas coisas (documentado no próprio `SkillTree`).

## Decisões confirmadas (conversa com o usuário)

1. **Sem raiz falsa**: cada uma das 5 branches vira sua própria
   mini-árvore visual — nada de inventar um nó raiz compartilhado que não
   existe nos dados, só pra imitar a imagem de referência.
2. **Tela cheia**, não um painel: o botão "Habilidades" passa a abrir uma
   tela nova (`pixelSlideRoute`, Bloco 6) em vez do bottom sheet atual.

## O que NÃO está neste bloco

- Nenhuma mudança em `battle_engine`/backend — a árvore de dados
  (`defaultSkillTree`, `SkillNode`, `SkillTree`, `SkillProgress`) continua
  exatamente a mesma. Tudo que é novo (ícone por nó, nome de exibição por
  branch) vive só em `game_domain`.
- **Layout simplificado, assumindo cadeia linear**: cada branch é
  desenhada como uma coluna vertical simples (um nó embaixo do outro, uma
  linha reta conectando cada par). Isso cobre 100% do conteúdo real hoje.
  Se uma branch um dia ganhar um nó com 2+ pré-requisitos ou 2+ nós
  dependendo dele (ramificação/convergência de verdade), o layout ainda
  produz uma ordem válida (todo pré-requisito aparece antes de quem
  depende dele) mas não desenha a ramificação visualmente — vira uma
  lista reta mesmo assim. Registrado como limitação conhecida, não
  resolvida agora (YAGNI — não existe esse conteúdo hoje).
- Nenhum pré-requisito cruzando branches é considerado pra desenhar linha
  (também não existe isso nos dados hoje).
- Sem zoom/pan na árvore — cada branch cabe numa coluna de largura fixa,
  a tela toda rola horizontalmente entre as 5 branches (`SingleChildScrollView`
  horizontal), e cada branch rola verticalmente se a cadeia for comprida
  (`SingleChildScrollView` vertical dentro da coluna).

## Mudança de UX deliberada (fora do pedido original, mas decorre naturalmente do design)

Hoje, no Multiplayer, se não é sua vez, o modal mostra só o texto "Só dá
pra desbloquear na sua vez." — nem a lista de nós aparece. Com a árvore
sempre visível, isso deixa de fazer sentido: **a árvore inteira (travados/
disponíveis/desbloqueados) fica visível a qualquer momento**, em ambas as
telas; só a *ação* de desbloquear continua condicionada à vez (no
Multiplayer). Ver com o usuário faz parte da consequência natural de
"mostrar a árvore toda" — incluído aqui porque decorre diretamente do
design pedido, não é uma funcionalidade nova à parte.

## Dados novos (`game_domain/skill_tree_catalog.dart`, arquivo já existente)

```dart
class SkillTreeNodeOption {
  final String id;
  final String name;
  final String description;
  final String branch;
  final List<String> prerequisites;
  final String icon; // emoji, mesmo espírito do symbol de ElementOption

  const SkillTreeNodeOption({...});
}

List<SkillTreeNodeOption> allSkillTreeNodes(); // mapeia defaultSkillTree.nodes inteiro

String skillTreeBranchDisplayName(String branch); // 'fogo' -> 'Fogo', 'precisao' -> 'Precisão', etc.
```

Ícones por nó (emoji, escolhidos pelo tema de cada mutação/modificador):

| id | ícone | branch |
|---|---|---|
| `ember_mastery` | 🔥 | fogo |
| `wildfire_path` | 🌋 | fogo |
| `unstable_core_training` | 🎯 | precisao |
| `fragment_strikes` | 💥 | precisao |
| `elemental_insight` | 🌊 | elemental |
| `elemental_mastery` | ⚡ | elemental |
| `vitality_training` | ❤️ | vitalidade |
| `guard_training` | 🛡️ | defesa |

`TrainingMatch` ganha um getter novo — hoje só expõe `availableSkillNodesForCurrentPlayer`
(só os disponíveis), a árvore inteira precisa também dos já desbloqueados:

```dart
List<String> get unlockedNodeIdsForCurrentPlayer => _currentProgress.unlockedNodeIds;
```

`MultiplayerMatch` já expõe `unlockedNodeIdsForMe` — nada novo lá.

## Layout puro (`game_presentation/skill_tree_layout.dart`, novo arquivo)

```dart
/// Ordena os nós de uma branch em ordem topológica (pré-requisitos antes
/// de quem depende deles), pra empilhar verticalmente numa coluna.
/// Assume que a branch é uma cadeia linear — ver limitação na seção de
/// escopo do design.
List<SkillTreeNodeOption> orderBranchNodes(List<SkillTreeNodeOption> branchNodes);
```

Pura, sem Flutter, testável isolada (mesma categoria de `isNewerVersion`,
`didTakeDamage`).

## Estado visual de um nó

```dart
enum SkillTreeNodeState { locked, available, unlocked }

SkillTreeNodeState skillTreeNodeState(SkillTreeNodeOption node, List<String> unlockedNodeIds) {
  if (unlockedNodeIds.contains(node.id)) return SkillTreeNodeState.unlocked;
  return node.prerequisites.every(unlockedNodeIds.contains)
      ? SkillTreeNodeState.available
      : SkillTreeNodeState.locked;
}
```

`available` aqui **não** considera de quem é a vez — só se os
pré-requisitos foram cumpridos. "De quem é a vez" só entra na hora de
habilitar o botão "Desbloquear" dentro do painel de detalhe (ver abaixo).

## Componente novo: `SkillTreeNodeWidget` (`game_presentation/`)

Círculo (borda escura 3px, mesmo espírito de `PixelElementChip`) com o
`icon` (emoji) centralizado e o `name` do nó como rótulo pequeno embaixo.
Cor de fundo por estado: `unlocked` → dourado (`0xFFF4C94A`), `available`
→ creme normal (`0xFFF4F4E4`), `locked` → creme com opacidade 0.4 (mesmo
padrão de botão desabilitado). Sempre tocável (`onTap` nunca nulo) —
tocar em qualquer estado abre o painel de detalhe; é o painel que decide
o que mostrar.

```dart
class SkillTreeNodeWidget extends StatelessWidget {
  const SkillTreeNodeWidget({
    required this.name,
    required this.icon,
    required this.state,
    required this.onTap,
  });

  final String name;
  final String icon;
  final SkillTreeNodeState state;
  final VoidCallback onTap;
}
```

## Tela nova: `SkillTreeScreen` (`ui/`)

Substitui as duas implementações de `_openSkillTree` (Treino e
Multiplayer) — única tela compartilhada pelos dois.

```dart
class SkillTreeScreen extends StatefulWidget {
  const SkillTreeScreen({
    required this.title,
    required this.unlockedNodeIds,
    required this.canUnlockNow,
    required this.onUnlock,
  });

  final String title; // 'Habilidades de Jogador A' (Treino) ou 'Habilidades' (Multiplayer)
  final List<String> unlockedNodeIds; // snapshot no momento de abrir
  final bool canUnlockNow; // Treino: sempre true. Multiplayer: isInProgress && isMyTurn
  final Future<String?> Function(String nodeId) onUnlock; // null = sucesso, String = mensagem de erro
}
```

Estado interno: mantém sua própria cópia mutável de `unlockedNodeIds`
(`late List<String> _unlockedNodeIds = List.of(widget.unlockedNodeIds)`),
atualizada localmente a cada desbloqueio bem-sucedido — não depende de a
tela de trás (Treino/Multiplayer) recompor sozinha, já que agora é uma
tela empilhada de verdade (`Navigator.push`), não um modal sobre a mesma
árvore de widgets.

**Corpo**: `Scaffold` com `AppBar` (`title` como `PixelOutlinedText`,
fundo/estilo pixel art já padrão) + fundo `ArenaBackdropPainter` + um
`SingleChildScrollView` horizontal com uma coluna por branch
(`for (final branch in branches) SkillTreeBranchColumn(...)`) dentro de
um `PixelContentPanel`.

**Cada coluna de branch**: título (`skillTreeBranchDisplayName(branch)`),
depois `orderBranchNodes(...)` renderizado como `Column` de
`SkillTreeNodeWidget`s, com uma linha vertical curta (`Container` 3px de
largura, cor escura) entre cada par consecutivo — sem `CustomPainter`,
sem cálculo de posição: é só inserir a linha entre os widgets já
empilhados no `Column`.

**Painel de detalhe** (ao tocar um nó — `showModalBottomSheet` com
`PixelSheetPanel`, mesmo padrão do Bloco 5/6): nome (`PixelOutlinedText`),
descrição, e:
- `locked`: lista os nomes dos pré-requisitos que faltam (`'Requer: ...'`).
- `available` + `canUnlockNow`: `PixelMenuButton('Desbloquear')` — ao
  tocar, chama `widget.onUnlock(nodeId)`; se devolver `null`, atualiza
  `_unlockedNodeIds` local (`setState`) e fecha o painel; se devolver uma
  mensagem, mostra um `SnackBar` com ela (mesmo padrão de erro já usado
  no modal de Multiplayer hoje) e mantém o painel aberto.
- `available` + `!canUnlockNow`: texto `'Só dá pra desbloquear na sua vez.'`
  (mesma frase já usada hoje), sem botão.
- `unlocked`: só a descrição, sem ação.

## Telas que chamam (`TrainingScreen`/`MultiplayerBattleScreen`)

`_openSkillTree` (as duas versões atuais, inteiras) é removido de ambas as
telas. O `IconButton` da AppBar ("Habilidades") passa a empurrar
`SkillTreeScreen` via `pixelSlideRoute`, e faz `setState(() {})` quando a
navegação retorna (`await Navigator.push(...); setState(() {});`) — pro
HUD/resumo da tela de batalha (HP, build) refletir qualquer bônus
imediato (ex: `MaxHpBonus`) que o desbloqueio possa ter concedido.

`TrainingScreen`:
```dart
onPressed: () async {
  await Navigator.of(context).push(pixelSlideRoute((_) => SkillTreeScreen(
    title: 'Habilidades de ${_match.currentTurnName}',
    unlockedNodeIds: _match.unlockedNodeIdsForCurrentPlayer,
    canUnlockNow: true,
    onUnlock: (nodeId) async {
      try {
        _match.unlockSkillForCurrentPlayer(nodeId);
        return null;
      } on StateError catch (e) {
        return e.message;
      }
    },
  )));
  setState(() {});
},
```

`MultiplayerBattleScreen`:
```dart
onPressed: () async {
  await Navigator.of(context).push(pixelSlideRoute((_) => SkillTreeScreen(
    title: 'Habilidades',
    unlockedNodeIds: _match.unlockedNodeIdsForMe,
    canUnlockNow: _match.isInProgress && _match.isMyTurn,
    onUnlock: (nodeId) async {
      try {
        await _match.unlockSkill(nodeId);
        return null;
      } on MultiplayerException catch (e) {
        return e.message;
      }
    },
  )));
  setState(() {});
},
```

`SkillTreeNodeOption`/`allSkillTreeNodes` substitui totalmente
`skillNodeOptionFrom`/`availableSkillNodeOptions` como base pra essa tela
— essas duas funções antigas continuam existindo (nada mais as usa depois
deste bloco, mas removê-las está fora de escopo: não fazem mal ficando,
e removê-las não foi pedido).

## Consequência em testes existentes

Os dois testes que exercitam o fluxo de Habilidades de ponta a ponta
precisam ser **reescritos** (não é só adicionar/trocar 1-2 linhas — a
interação em si mudou de "lista com botão ao lado" pra "tocar no nó, ver
painel, confirmar"):

- `training_screen_test.dart`, teste "unlocking Maestria da Brasa applies
  Queimadura...": em vez de `find.text('Desbloquear').first` direto na
  lista, o fluxo vira: tocar o ícone da AppBar → aguardar a transição de
  tela (`pixelSlideRoute`, 400ms) → tocar `find.text('Maestria da Brasa')`
  (nome do nó, visível direto na árvore) → aguardar o painel de detalhe
  subir (`PixelSheetPanel`, 400ms) → tocar `find.text('Desbloquear')` →
  aguardar o painel fechar (400ms) → tocar o botão de voltar
  (`find.byType(BackButton)`, inserido automaticamente pela `AppBar` da
  `SkillTreeScreen` por ter uma rota pra voltar) → aguardar a transição de
  volta (400ms) → seguir pro resto do teste (escolher elementos, jogar).
  Pode confirmar o estado antes/depois checando
  `tester.widget<SkillTreeNodeWidget>(find.widgetWithText(SkillTreeNodeWidget,
  'Maestria da Brasa')).state` (`available` antes, `unlocked` depois).
- `multiplayer_battle_screen_test.dart`, teste "Habilidades modal lists
  what can be unlocked and unlocking it updates the list live": mesma
  reestruturação. A asserção `find.text('[fogo] Maestria da Brasa')`
  deixa de existir — o texto visível na árvore é só `'Maestria da Brasa'`
  (o prefixo `[branch]` não faz mais sentido: a branch já é visual, é a
  coluna onde o nó está). Substituir pela checagem de `SkillTreeNodeWidget.state`
  (`available` → `unlocked` depois de desbloquear) e, opcionalmente,
  checar que `'Caminho do Incêndio'` (próximo nó da mesma branch) também
  aparece com `state: SkillTreeNodeState.available` depois — mesma
  intenção do teste original ("a lista atualiza"), adaptada pro novo
  formato.
- Nenhum outro teste toca o fluxo de Habilidades/Skill Tree.

## Testes esperados (novos)

- `orderBranchNodes`: cadeia de 1 nó (devolve ele mesmo), cadeia de 2
  (pré-requisito primeiro), cadeia de 3.
- `skillTreeNodeState`: os 3 casos (sem pré-requisito e não desbloqueado
  → `available`; com pré-requisito não cumprido → `locked`; id presente
  em `unlockedNodeIds` → `unlocked`, mesmo que tecnicamente também
  cumprisse pré-requisitos de novo).
- `allSkillTreeNodes`/`skillTreeBranchDisplayName`: cobertura básica (8
  nós, ids/branches batendo com `defaultSkillTree`; nomes de exibição
  conhecidos pras 5 branches atuais).
- `SkillTreeNodeWidget`: mostra `name`/`icon`, cor de fundo muda por
  `state`, chama `onTap` ao tocar.
- `SkillTreeScreen`: widget test cobrindo os 3 ramos do painel de detalhe
  (locked mostra pré-requisitos, available+canUnlockNow desbloqueia com
  sucesso e atualiza o estado do nó, available+!canUnlockNow mostra o
  aviso sem botão) — com um `onUnlock` fake (sem precisar de
  `TrainingMatch`/`MultiplayerMatch` reais).
- Testes de tela reescritos conforme a seção acima.
- Verificação manual via `flutter run -d web-server` (servidor
  reiniciado): abrir Habilidades no Treino, ver as 5 branches lado a
  lado/roláveis, tocar num nó disponível, desbloquear de verdade, ver a
  cor mudar pra dourado e o próximo nó da cadeia virar disponível; voltar
  pra tela de batalha e confirmar que o HUD reflete qualquer bônus
  (ex: desbloquear Treino de Vitalidade e ver o HP máximo subir); repetir
  no Multiplayer contra o backend real, incluindo tentar abrir fora da
  vez pra confirmar que a árvore aparece mas "Desbloquear" não.

## Fora de escopo, mas não esquecido

- Layout genérico pra branches com ramificação/convergência real (ver
  seção de escopo) — fica pro dia em que existir conteúdo assim.
- `skillNodeOptionFrom`/`availableSkillNodeOptions` (código antigo, sem
  uso depois deste bloco) — não removidas, não é objetivo deste bloco.
- Nenhuma mudança em áudio/efeitos/conteúdo novo de skill tree em si (nós
  novos, branches novas) — só a apresentação dos que já existem.
