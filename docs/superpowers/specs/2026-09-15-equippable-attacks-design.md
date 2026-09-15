# Ataques combinados equipáveis no Modo Treino (Bloco 2c) — design

Data: 2026-09-15
Status: aprovado pelo usuário, pronto para virar plano de implementação.

## Contexto

Terceiro de quatro blocos decididos com o usuário numa mesma conversa
de brainstorming (ver Bloco 2a/DECISION-046, Bloco 2b/DECISION-047):

- Bloco 2a (feito): custo de AP pra combinar 2-3 elementos.
- Bloco 2b (feito): alguns elementos começam bloqueados, desbloqueio
  via Skill Tree com custo em turnos.
- **Bloco 2c (este)**: combinações disparadas viram "ataques"
  desbloqueáveis, equipáveis/trocáveis, limite de 3.
- Bloco 2d: tela de batalha estilo Pokémon (fora de escopo aqui —
  depende deste bloco definir o que é "equipado").

Ideia original do usuário: "assim que usasse ele iria mostrar a opção
falando q a combinação desbloqueou um novo ataque e se desejar pegar
tem de substituir na janela de skills combinadas, limitar a 3 também."

## Escopo

**Só Modo Treino**, mesma razão do Bloco 2b (Multiplayer ainda não tem
persistência real — Bloco 11). Nada neste bloco toca
`BattleState`/`TurnEngine` (Dart) nem `backend/src/battle-rules/`
(TypeScript).

### A mecânica

- Quando um jogador dispara uma combinação (2 ou 3 elementos) pela
  **primeira vez** (pra ele — não é mais compartilhado entre os dois
  jogadores, ver seção de dados abaixo), ela é marcada como
  **desbloqueada** permanentemente pra esse jogador.
- Se ele tem menos de 3 ataques equipados no momento do desbloqueio, o
  novo ataque **é equipado automaticamente**, sem perguntar nada.
- Se as 3 vagas já estão cheias, a tela de "Ataques Combinados" (ver
  abaixo) **abre na hora**, mostrando os 3 equipados e o recém-
  descoberto, pra escolher qual substituir (ou manter os atuais e
  deixar o novo só desbloqueado, sem equipar).
- **A partir do momento que uma combinação está desbloqueada pra um
  jogador, ele só consegue disparar essa combinação de novo se ela
  estiver equipada.** Tentar montá-la escolhendo os elementos
  manualmente (do jeito que já funciona hoje) enquanto ela está
  desbloqueada-mas-não-equipada é **rejeitado** — mesmo padrão de erro
  que "AP insuficiente"/"elemento bloqueado" já usam hoje (tenta,
  recebe uma mensagem clara, o turno não passa).
- Uma combinação **ainda não descoberta** continua livre pra tentar
  normalmente — a restrição só vale depois que ela já foi vista pela
  primeira vez.
- Elemento sozinho nunca é afetado — continua sempre livre (Bloco 2a).
- Um ataque equipado continua exigindo os elementos individuais
  desbloqueados (Bloco 2b) e continua custando AP pela tabela já
  existente (Bloco 2a: 3 AP pra 2 elementos, 5 pra 3) — nada muda
  nessas regras, só a checagem nova de "está equipado?" se soma às
  já existentes.

## `battle_engine` (Dart)

### `AttackLoadout` (novo, `packages/battle_engine/lib/src/attack_loadout.dart`)

Estrutura **separada** do `DiscoveryBook` já existente — não reutiliza
nem modifica ele. O `DiscoveryBook` continua exatamente como está hoje
(compartilhado entre os dois jogadores, só pro contador "Descobertas:
X/Y" na tela) — zero risco pro que já está em produção. `AttackLoadout`
é uma estrutura nova, **uma por jogador**, com um propósito diferente:
não é "alguém já viu isso", é "esse jogador específico pode usar isso
de novo".

```dart
/// Tracks which [ElementCombination]s a single player has unlocked as a
/// personal "attack" (triggered at least once), and which ≤3 of those
/// are currently equipped — the only ones that player can trigger again
/// (Bloco 2c, DECISION-048). Immutable — [withUnlocked]/[withEquipped]
/// return a new instance. Independent from [DiscoveryBook] (shared,
/// meta-progression-only, unaffected by this class) — see the design
/// doc for why they're kept separate.
class AttackLoadout {
  final Set<String> unlockedCombinationIds;
  final List<String> equippedCombinationIds;

  AttackLoadout({
    Set<String> unlockedCombinationIds = const {},
    List<String> equippedCombinationIds = const [],
  })  : unlockedCombinationIds = Set.unmodifiable(unlockedCombinationIds),
        equippedCombinationIds = List.unmodifiable(equippedCombinationIds);

  bool isUnlocked(String combinationId) =>
      unlockedCombinationIds.contains(combinationId);

  bool isEquipped(String combinationId) =>
      equippedCombinationIds.contains(combinationId);

  /// Returns a new loadout with [combinationId] marked as unlocked. If
  /// already unlocked, returns this same instance (no-op). If there's
  /// room (fewer than 3 equipped), also equips it automatically.
  AttackLoadout withUnlocked(String combinationId) {
    if (isUnlocked(combinationId)) return this;
    final nextEquipped = equippedCombinationIds.length < 3
        ? [...equippedCombinationIds, combinationId]
        : equippedCombinationIds;
    return AttackLoadout(
      unlockedCombinationIds: {...unlockedCombinationIds, combinationId},
      equippedCombinationIds: nextEquipped,
    );
  }

  /// Returns a new loadout with the equipped set replaced by
  /// [combinationIds]. Throws `ArgumentError` if it has more than 3
  /// ids, or if any id isn't already unlocked.
  AttackLoadout withEquipped(List<String> combinationIds) {
    if (combinationIds.length > 3) {
      throw ArgumentError.value(
        combinationIds,
        'combinationIds',
        'cannot equip more than 3 attacks',
      );
    }
    for (final id in combinationIds) {
      if (!isUnlocked(id)) {
        throw ArgumentError.value(
          id,
          'combinationIds',
          'not unlocked yet, cannot be equipped',
        );
      }
    }
    return AttackLoadout(
      unlockedCombinationIds: unlockedCombinationIds,
      equippedCombinationIds: combinationIds,
    );
  }
}
```

Exportar em `packages/battle_engine/lib/battle_engine.dart`, logo
depois de `export 'src/discovery_book.dart';`.

## Cliente (Flutter) — `TrainingProgressStore`

Duas chaves novas por slot (mesmo padrão de `training_unlocked_<slot>`
e `training_turns_played_<slot>`):

```dart
static const _attacksUnlockedKeyPrefix = 'training_attacks_unlocked_';
static const _attacksEquippedKeyPrefix = 'training_attacks_equipped_';

Future<List<String>> loadUnlockedAttackIds(String slot) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getStringList('$_attacksUnlockedKeyPrefix$slot') ?? const [];
}

Future<void> saveUnlockedAttackIds(String slot, List<String> ids) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList('$_attacksUnlockedKeyPrefix$slot', ids);
}

Future<List<String>> loadEquippedAttackIds(String slot) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getStringList('$_attacksEquippedKeyPrefix$slot') ?? const [];
}

Future<void> saveEquippedAttackIds(String slot, List<String> ids) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList('$_attacksEquippedKeyPrefix$slot', ids);
}
```

## Cliente (Flutter) — `TrainingMatch`

- Construtor ganha `AttackLoadout? initialLoadoutA, initialLoadoutB`
  (default `AttackLoadout()` vazio quando não passados — mesmo padrão
  de `initialProgressA`/`B`).
- `fromPersistedProgress` ganha `required List<String>
  unlockedAttackIdsA, required List<String> equippedAttackIdsA,
  required List<String> unlockedAttackIdsB, required List<String>
  equippedAttackIdsB` — monta `AttackLoadout(unlockedCombinationIds:
  unlockedAttackIdsA.toSet(), equippedCombinationIds:
  equippedAttackIdsA)` pra cada jogador e repassa como
  `initialLoadoutA`/`B`.
- `startNewBattleKeepingProgress` repassa `_loadoutA`/`_loadoutB`
  atuais como `initialLoadoutA`/`B` — não reseta, mesma regra do
  contador de turnos cumulativos (Bloco 2b) e da Skill Tree.
- `playElementIds`: **antes** de construir a `Ability`/`Build` (junto
  da checagem de elemento bloqueado já existente), se `elementIds.length
  >= 2`, resolver `defaultCombinationBook.resolve(elements)`; se achar
  uma combinação e `_currentLoadout.isUnlocked(combo.resultId) &&
  !_currentLoadout.isEquipped(combo.resultId)`, lançar
  `StateError('${combo.resultName} não está equipado. Troque na '
  'janela de Ataques Combinados.')` — mesmo tipo de exceção que "AP
  insuficiente" já lança, capturado do mesmo jeito pela UI.
- Depois que `_abilityEngine.useAbility` retorna, se
  `result.triggeredCombination != null`: computar `wasNewlyUnlocked =
  !loadoutBeforeThisPlay.isUnlocked(comboId)` (usar o loadout de
  **antes** de aplicar `withUnlocked`, capturado no início do método,
  já que `wasPlayerATurn` também precisa ser capturado ali por causa
  do gate de AP/Bloco 2a existente); atualizar o loadout do jogador que
  jogou (`_loadoutA`/`_loadoutB`, conforme `wasPlayerATurn`) via
  `.withUnlocked(comboId)`; guardar `_lastUnlockedAttackId`/
  `_lastUnlockedAttackName` (id e nome de exibição do combo, só quando
  `wasNewlyUnlocked`, senão ambos `null`) e
  `_lastUnlockedAttackNeededEquipChoice` (`true` só quando
  `wasNewlyUnlocked` e o loadout **antes** da atualização já tinha 3
  equipados — ou seja, o novo ataque ficou desbloqueado mas não
  equipado).
- Getters novos: `String? get lastUnlockedAttackId`; `String? get
  lastUnlockedAttackName`; `bool get
  lastUnlockedAttackNeededEquipChoice`; `List<String> get
  unlockedAttackIdsForCurrentPlayer` (=
  `_currentLoadout.unlockedCombinationIds.toList()`); `List<String> get
  equippedAttackIdsForCurrentPlayer` (=
  `_currentLoadout.equippedCombinationIds`); `void
  setEquippedAttacksForCurrentPlayer(List<String> combinationIds)`
  (atualiza `_loadoutA`/`_loadoutB` via `.withEquipped(...)` — deixa o
  `ArgumentError` de `AttackLoadout.withEquipped` propagar, mesmo
  padrão de erro que outros setters já seguem).
- `_currentLoadout` (privado, espelha `_currentProgress`): `_isPlayerATurn
  ? _loadoutA : _loadoutB`.

## Cliente (Flutter) — catálogo pra exibição

Novo `app/lib/game_domain/attack_catalog.dart`, mesmo espírito de
`skill_tree_catalog.dart` — a UI nunca nomeia `ElementCombination`
(DECISION-011/017):

```dart
class AttackOption {
  final String id;
  final String name;
  final String description;
  final bool unlocked;
  final bool equipped;

  const AttackOption({
    required this.id,
    required this.name,
    required this.description,
    required this.unlocked,
    required this.equipped,
  });
}

/// Todas as combinações de `defaultCombinationBook`, marcadas com o
/// que o jogador atual já desbloqueou/equipou — só entradas
/// desbloqueadas mostram nome/descrição reais (ver
/// `attacks_screen.dart`, que decide se esconde as ainda não vistas).
List<AttackOption> allAttackOptions({
  required List<String> unlockedIds,
  required List<String> equippedIds,
}) {
  return defaultCombinationBook.combinations
      .map((combo) => AttackOption(
            id: combo.resultId,
            name: combo.resultName,
            description: combo.description,
            unlocked: unlockedIds.contains(combo.resultId),
            equipped: equippedIds.contains(combo.resultId),
          ))
      .toList();
}
```

## Cliente (Flutter) — tela "Ataques Combinados"

Novo `app/lib/ui/attacks_screen.dart`, mesmo padrão visual/estrutural
**e de interação** de `SkillTreeScreen`: a tela não muda estado de
`TrainingMatch` sozinha — ela chama um callback que o chamador
(`TrainingScreen`) fornece, exatamente como `SkillTreeScreen.onUnlock`
já funciona hoje (`Future<String?> Function(...)`, devolve uma
mensagem de erro pra mostrar num `SnackBar`, ou `null` no sucesso).

```dart
class AttacksScreen extends StatefulWidget {
  const AttacksScreen({
    super.key,
    required this.attacks, // List<AttackOption>
    required this.onSetEquipped, // Future<String?> Function(List<String> combinationIds)
    this.highlightComboId,
  });
  // ...
  final String? highlightComboId;
}
```

- Lista só os ataques **desbloqueados** (`unlocked: true`) — os ainda
  não vistos não aparecem aqui (isso já é papel do Livro de Descobertas
  existente, não deste bloco).
- Cada item mostra se está equipado (destaque visual, ex: borda
  diferente, mesmo espírito de `SkillTreeNodeState.unlocked`).
- Tocar num ataque **não-equipado** com menos de 3 equipados: chama
  `onSetEquipped` já com esse id incluído na lista atual de equipados
  (equipa direto, sem confirmação extra).
- Tocar num ataque **não-equipado** com os 3 já cheios: abre um
  seletor pedindo qual dos 3 atuais sair — ao confirmar, chama
  `onSetEquipped` com a lista final (removeu o escolhido, incluiu o
  novo).
- Tocar num ataque **já equipado**: opção de desequipar — chama
  `onSetEquipped` com a lista atual sem esse id (não precisa preencher
  a vaga com outro).
- Em qualquer um dos casos, se `onSetEquipped` devolver uma mensagem
  de erro (não-nula), mostra num `SnackBar`, mesmo padrão de erro que
  `SkillTreeScreen` já usa pro `onUnlock`; em caso de sucesso, a tela
  atualiza seu próprio estado local pra refletir a troca (mesmo padrão
  de `_SkillTreeScreenState._unlockedNodeIds` sendo atualizado depois
  de um `onUnlock` bem-sucedido).
- `TrainingScreen` fornece:

```dart
onSetEquipped: (ids) async {
  try {
    _match.setEquippedAttacksForCurrentPlayer(ids);
    final slot = _match.isPlayerATurn ? 'a' : 'b';
    unawaited(_progressStore.saveEquippedAttackIds(slot, ids));
    return null;
  } on ArgumentError catch (e) {
    return e.message;
  }
}
```

  — mesmo formato do `onUnlock` já existente (o jogador da vez não
  muda ao equipar/desequipar, diferente de `playElementIds`, então
  `_match.isPlayerATurn` aqui já reflete o jogador certo no momento da
  chamada).
- Parâmetro opcional `highlightComboId` (`String?`) — quando a tela é
  aberta automaticamente pelo fluxo de "vagas cheias" (ver abaixo), ele
  é o id do ataque recém-descoberto, usado só pra dar destaque visual
  inicial (ex: já abrir o painel de detalhe dele) — não muda nenhuma
  regra de negócio.

## Cliente (Flutter) — `TrainingScreen`

- Novo método privado, reaproveitado pelos dois pontos de entrada
  abaixo (botão manual e abertura automática):

```dart
Future<void> _openAttacksScreen({String? highlightComboId}) async {
  await Navigator.of(context).push(pixelSlideRoute((_) => AttacksScreen(
    attacks: allAttackOptions(
      unlockedIds: _match.unlockedAttackIdsForCurrentPlayer,
      equippedIds: _match.equippedAttackIdsForCurrentPlayer,
    ),
    highlightComboId: highlightComboId,
    onSetEquipped: (ids) async {
      try {
        _match.setEquippedAttacksForCurrentPlayer(ids);
        final slot = _match.isPlayerATurn ? 'a' : 'b';
        unawaited(_progressStore.saveEquippedAttackIds(slot, ids));
        return null;
      } on ArgumentError catch (e) {
        return e.message;
      }
    },
  )));
  setState(() {});
}
```

- AppBar ganha um segundo `IconButton` (ao lado de "Habilidades"),
  chamando `_openAttacksScreen()` sem `highlightComboId` — sempre
  disponível, não só no momento do desbloqueio.
- `_playTurn`: depois de `_match.playElementIds(...)` suceder, checar
  `_match.lastUnlockedAttackName`. Se não-nulo (desbloqueou algo
  nesta jogada — com ou sem vaga livre), salvar
  `unlockedAttackIdsForCurrentPlayer`/`equippedAttackIdsForCurrentPlayer`
  do jogador que acabou de jogar via
  `TrainingProgressStore.saveUnlockedAttackIds`/`saveEquippedAttackIds`
  (mesmo padrão já usado pra Skill Tree/turnos cumulativos — nota: o
  jogador da vez já mudou depois de `playElementIds`, então usar
  `wasPlayerATurn`, capturado antes da chamada, pra saber o slot
  certo, igual já é feito pro contador de turnos do Bloco 2b). Depois:
  - Se `!_match.lastUnlockedAttackNeededEquipChoice`: guardar numa
    variável de estado (ex: `_lastUnlockedAttackText`) pra mostrar
    inline, mesmo padrão de "Última combinação: X" — algo como "Novo
    ataque desbloqueado: X! (equipado automaticamente)".
  - Se `_match.lastUnlockedAttackNeededEquipChoice`: depois do
    `setState` do turno, chamar
    `_openAttacksScreen(highlightComboId: _match.lastUnlockedAttackId)`.
    Trocas feitas dentro dessa tela já se salvam sozinhas, através do
    callback `onSetEquipped` (ver seção da tela acima) — nenhum salvar
    adicional necessário depois que ela fecha.
- `_loadPersistedMatch`: carregar as 4 listas novas
  (`unlockedAttackIdsA/B`, `equippedAttackIdsA/B`) junto do resto, e
  repassar pro `TrainingMatch.fromPersistedProgress`.

## Testes esperados

- `attack_loadout_test.dart` (novo, `battle_engine`): `isUnlocked`/
  `isEquipped` refletem o estado; `withUnlocked` equipa
  automaticamente com vaga livre; `withUnlocked` não equipa quando já
  tem 3 (fica só desbloqueado); `withUnlocked` é no-op se já
  desbloqueado; `withEquipped` lança `ArgumentError` com mais de 3 ids
  ou com um id não desbloqueado; `withEquipped` substitui a lista
  normalmente dentro das regras.
- `training_match_test.dart`: jogar uma combinação nova a primeira vez
  sempre funciona e desbloqueia; jogar a mesma combinação de novo sem
  equipar lança `StateError` com a mensagem certa; jogar uma
  combinação equipada funciona normalmente; desbloquear com vaga livre
  equipa automático (`lastUnlockedAttackNeededEquipChoice` falso);
  desbloquear com 3 vagas cheias não equipa
  (`lastUnlockedAttackNeededEquipChoice` verdadeiro);
  `setEquippedAttacksForCurrentPlayer` funciona e propaga erro de
  `AttackLoadout.withEquipped`; loadout sobrevive a
  `startNewBattleKeepingProgress`; `fromPersistedProgress` semeia os 4
  campos novos corretamente.
- `training_progress_store_test.dart`: `loadUnlockedAttackIds`/
  `saveUnlockedAttackIds`/`loadEquippedAttackIds`/
  `saveEquippedAttackIds` isolados, default vazio quando nunca salvo,
  slots independentes.
- `attacks_screen_test.dart` (novo): lista só ataques desbloqueados;
  tocar um não-equipado com vaga livre equipa direto; tocar um
  não-equipado com 3 cheios abre o seletor de troca; tocar um
  equipado desequipa; `highlightComboId` dá destaque inicial correto.
- `training_screen_test.dart`: texto inline aparece quando desbloqueia
  com vaga livre; `AttacksScreen` abre automaticamente quando
  desbloqueia com vagas cheias; tentar rejogar uma combinação
  desbloqueada-mas-não-equipada mostra a mensagem de erro certa e o
  turno não passa.
- Verificação manual: descobrir um combo (vaga livre, equipa
  automático, mensagem inline aparece); tentar montar esse mesmo combo
  de novo depois de desequipá-lo manualmente na tela de Ataques
  Combinados (deveria ser rejeitado); descobrir um terceiro/quarto
  combo depois das 3 vagas cheias (tela de troca abre sozinha).

## Fora de escopo, mas não esquecido

- Multiplayer (aguardando o Bloco 11).
- Bloco 2d (UI de batalha estilo Pokémon) — usa o que este bloco
  define (`equippedAttackIdsForCurrentPlayer`) pra montar os botões de
  ação do turno; não implementado aqui.
- Ordem/prioridade visual dos 3 slots equipados (ex: arrastar pra
  reordenar) — não pedido, YAGNI; a lista de equipados não tem ordem
  significativa por enquanto.
- Desbloquear um ataque também aumentar `DiscoveryBook` de alguma
  forma especial — não muda, `DiscoveryBook` continua fazendo
  exatamente o que já fazia, sem relação com `AttackLoadout`.
