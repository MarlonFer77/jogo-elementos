# Custo de AP pra combinar elementos (Bloco 2a) — design

Data: 2026-09-12
Status: aprovado pelo usuário, pronto para virar plano de implementação.

## Contexto

Jogando o jogo, o usuário percebeu dois problemas na batalha (tratados
como blocos separados): (1) texto crescendo na tela até forçar rolagem
— já corrigido, removendo linhas redundantes com os badges do Bloco 9;
(2) combinar 2-3 elementos é hoje trivial e de graça — qualquer jogador
pode fazer isso todo turno, sem custo nem risco. O usuário quer uma
mudança maior de mecânica, estilo batalha de Pokémon, decomposta em 4
blocos sequenciais (decidido em brainstorming):

- **Bloco 2a (este)**: um recurso (AP) que dá fricção real pra combinar
  2-3 elementos, mantendo elemento sozinho sempre livre.
- Bloco 2b: alguns elementos começam bloqueados (fora de escopo aqui).
- Bloco 2c: combos viram "ataques" desbloqueáveis, equipáveis/
  trocáveis, limite de 3 (fora de escopo aqui).
- Bloco 2d: tela de batalha estilo Pokémon pra escolher a ação do turno
  (fora de escopo aqui — depende do 2c definir o que é "equipado").

## Escopo

Um `ApPool` por jogador (`max: 5`, começa em `0`), que **acumula entre
turnos** (não recarrega tudo de uma vez) — estilo "carregar especial"
de jogo de luta:

- Regenera **+1** no início de cada turno próprio do jogador (mesmo
  turno em que ele vai agir), até o teto de 5.
- Jogar **1 elemento sozinho**: sempre grátis (0 AP), e agora causa
  **5 de dano direto** no oponente (novo — hoje não causa dano nenhum).
  Bloqueável/consome Escudo, igual dano de combinação.
- Jogar **2 elementos**: custa **3 AP**.
- Jogar **3 elementos**: custa **5 AP** (o teto inteiro).
- Sem AP suficiente pro que o jogador tentou: a ação inteira é
  **rejeitada** (erro, igual "não é sua vez") — não gasta AP, não
  causa dano, não passa o turno. O jogador tenta de novo com uma
  jogada mais barata (ou espera acumular mais AP).

Fora de escopo: elementos bloqueados (Bloco 2b), ataques
desbloqueáveis/equipáveis (Bloco 2c), UI de batalha nova (Bloco 2d,
só o medidor de AP no HUD atual entra aqui). Sem bônus de AP máximo via
Skill Tree por enquanto (YAGNI — não pedido).

## `battle_engine` (Dart)

### `ApPool` (`packages/battle_engine/lib/src/ap_pool.dart`, novo)

Espelha `HpPool` na forma:

```dart
/// An immutable AP (action point) pool: how much a combatant can hold
/// (`max`) and how much they currently have (`current`). Used to gate
/// combining 2-3 elements in one turn — see [TurnEngine.playTurn].
/// `current` never goes below 0 or above `max`.
class ApPool {
  final int max;
  final int current;

  const ApPool({required this.max, required this.current});

  bool canAfford(int amount) => current >= amount;

  /// Returns a new pool with `current` incremented by 1, clamped at `max`.
  ApPool withRegenerated() {
    final next = current + 1;
    return ApPool(max: max, current: next > max ? max : next);
  }

  /// Returns a new pool with `amount` subtracted from `current`. Callers
  /// must check [canAfford] first — throws if `amount` is negative or
  /// exceeds `current`.
  ApPool withSpent(int amount) {
    if (amount < 0) {
      throw ArgumentError.value(amount, 'amount', 'must not be negative');
    }
    if (amount > current) {
      throw ArgumentError.value(amount, 'amount', 'exceeds current AP');
    }
    return ApPool(max: max, current: current - amount);
  }
}
```

### `BattleState` ganha `ap`

Mesmo padrão de `hp`: campo novo `Map<Combatant, ApPool> ap`, default
`ApPool(max: 5, current: 0)` pra cada jogador quando não informado
(construtor, `copyWith`), mais três métodos novos: `apOf(Combatant)`,
`withApRegenerated(Combatant)`, `withApSpent(Combatant, int amount)` —
espelhando exatamente `hpOf`/o padrão de `withDamage` já existentes.

### `TurnEngine.playTurn` — a mudança central

```dart
static const _basicDamage = 5;
static const _comboApCost = {2: 3, 3: 5};

TurnResult playTurn(
  BattleState state,
  TurnAction action, {
  List<CombinationModifier> combinationModifiers = const [],
}) {
  if (state.winner != null) {
    throw StateError('The battle is already over');
  }
  if (action.actor != state.currentTurn) {
    throw StateError('It is not ${action.actor}\'s turn');
  }

  var nextState = state.withApRegenerated(action.actor);

  final elementCount = action.elements.length;
  if (elementCount >= 2) {
    final cost = _comboApCost[elementCount]!;
    if (!nextState.apOf(action.actor).canAfford(cost)) {
      throw StateError(
        'Not enough AP for a $elementCount-element combination',
      );
    }
    nextState = nextState.withApSpent(action.actor, cost);
  }

  final combination = elementCount >= 2
      ? combinationBook.resolve(action.elements)
      : null;

  final opponent = nextState.opponentOf(action.actor);
  nextState = nextState.copyWith(currentTurn: opponent);

  if (combination != null) {
    var fieldEffect = combination.result;
    for (final modifier in combinationModifiers) {
      fieldEffect = modifier.apply(fieldEffect);
    }
    nextState = nextState.withFieldEffect(fieldEffect);
    nextState = _applyDamage(nextState, opponent, fieldEffect.damage);
  } else if (elementCount == 1) {
    nextState = _applyDamage(nextState, opponent, _basicDamage);
  }

  nextState = _tickStatusDamage(nextState, action.actor);

  return TurnResult(state: nextState, triggeredCombination: combination);
}
```

`_applyComboDamage` (existente) vira `_applyDamage` — mesmo corpo
(bloqueia/consome Escudo, senão aplica dano; `if (damage <= 0) return
state;` no topo), só reaproveitado agora pros dois casos (combo e dano
básico) em vez de duplicar a lógica.

**Por que a ordem importa**: como `playTurn` não retorna nada quando
lança uma exceção, uma jogada rejeitada por falta de AP não deixa
nenhum resíduo — nem o regen de +1 é aplicado de verdade (o
`_state`/`state` do chamador só é atualizado quando `playTurn` termina
com sucesso). Rejeitar é sempre um no-op completo, do jeito que o
usuário pediu.

## Sincronizar com `backend/src/battle-rules/` (obrigatório, mesmo bloco)

Sem isso o Multiplayer fica com combo de graça enquanto o Treino fica
travado — regra do próprio CLAUDE.md.

- `types.ts`: `ApPool` novo (`{max, current}`), `BattleState.ap:
  Readonly<Record<string, ApPool>>`.
- `ap-pool.ts` (novo, espelha `hp-pool.ts`): `canAfford`,
  `withRegenerated`, `withSpent`.
- `battle-state.ts`: `createBattleState` ganha `ap` opcional (default
  `{max:5,current:0}` por jogador, mesmo padrão de `hp`); `apOf`,
  `withApRegenerated`, `withApSpent` novos (espelham `hpOf`/
  `withDamage`).
- `turn-engine.ts`: mesma mudança do `playTurn` do Dart — regenerar,
  checar custo, rejeitar (`TurnValidationError`) se insuficiente,
  gastar, dano básico de 5 pra 1 elemento. `applyComboDamage` vira
  `applyDamage`, reaproveitado pros dois casos.
- `parse.ts`/`validate-turn.ts`: `parseApPool`/`parseAp` (espelham
  `parseHpPool`/`parseHp`), passados pro `createBattleState` do
  endpoint stateless — mesmo padrão de `combatantStatuses`.
- `match-store.ts` **não precisa mudar** — já chama `createBattleState`
  sem passar `hp`/`ap` explícito, então o default novo (`{max:5,
  current:0}`) já se aplica sozinho a toda partida real criada.

## Cliente (Flutter)

- `RemoteApPool` (novo, espelha `RemoteHpPool`) e
  `RemoteBattleState.ap: Map<String, RemoteApPool>` (default `{}` se
  o campo não vier — mesma cautela defensiva do `combatantStatuses`
  do Bloco 9).
- `MultiplayerMatch` ganha `myAp`/`myApMax`/`opponentAp`/
  `opponentApMax` (fallback 0/5 se o dado ainda não chegou).
- `TrainingMatch` ganha `playerAAp`/`playerAApMax`/`playerBAp`/
  `playerBApMax`.
- `BattleSceneView` ganha `leftAp`/`leftApMax`/`rightAp`/`rightApMax`
  (`int`, default `0`/`5` — não quebra nenhuma construção existente,
  mesmo padrão aditivo do Bloco 9).
- `BattleHudWidget`/`_HudPanel`: nova fileira de **pontinhos roxos**
  (estilo escolhido no companheiro visual) logo abaixo da barra de HP
  — um pip por ponto de `apMax`, preenchido (roxo) até `ap`, vazio
  (cinza) depois. Fica **acima** da fileira de badges de status (Bloco
  9), quando os dois aparecem juntos.

**Correção necessária, descoberta revisando o código real**:
`TrainingScreen._playTurn` hoje só captura `on ArgumentError` (id de
elemento desconhecido) — a nova rejeição por AP insuficiente lança
`StateError` (mesmo tipo de "não é sua vez"/"partida já acabou" no
`battle_engine`), que **não seria capturada** e derrubaria a tela com
uma exceção não tratada. `_playTurn` precisa de um `on StateError`
novo, mostrando uma mensagem própria em português (ex: "AP insuficiente
para essa combinação.") — nunca `e.message` cru (essas mensagens do
`battle_engine` são texto de debug em inglês, não pensadas pra
aparecer pro jogador). O Multiplayer **não precisa dessa mudança**: a
rejeição acontece no backend (TypeScript), vira erro HTTP, e já é
capturada pelo `catch` genérico existente de
`MultiplayerBattleScreen._playTurn` via `_match.lastError` — mesmo
caminho que "não é sua vez" já usa hoje.

## Testes esperados

- `ap_pool_test.dart` (novo): `canAfford`, `withRegenerated` (clampado
  em `max`, inclusive já no teto), `withSpent` (throws se negativo ou
  maior que o atual).
- `turn_engine_test.dart`: regenera +1 no início do turno do ator;
  combo de 2 rejeitado com menos de 3 AP (sem mudar estado, sem passar
  o turno); combo de 2 funciona normalmente com AP suficiente,
  descontando 3; combo de 3 exige os 5 inteiros; elemento sozinho
  aplica 5 de dano direto e não mexe em AP; dano básico bloqueado/
  consome Escudo igual dano de combo.
- `turn-engine.test.ts`: os mesmos casos, espelhados.
- `battle_state_test.dart`/equivalente TS: `apOf` default 0/5,
  `withApRegenerated`/`withApSpent` isolados.
- `training_match_test.dart`/`multiplayer_match_test.dart`:
  `playerAAp`/`playerBAp`/`myAp`/`opponentAp` refletem o estado real.
- `battle_hud_widget_test.dart`: pips aparecem no número certo,
  preenchidos até `ap`, o resto vazio.
- Verificação manual: jogar vários elementos sozinhos até acumular AP
  suficiente, depois um combo de 2 (e depois de 3), confirmando que o
  botão/ação falha se tentado cedo demais.

## Fora de escopo, mas não esquecido

- Bloco 2b (elementos bloqueados), 2c (ataques equipáveis), 2d (UI
  estilo Pokémon) — sequência já combinada com o usuário.
- Bônus de AP máximo via Skill Tree — não pedido, YAGNI.
- Indicar visualmente na UI que uma ação é "cara demais" antes de
  tentar (ex: desabilitar o botão de Confirmar quando não há AP) —
  pode ser um retoque de UX do Bloco 2d; por enquanto o erro aparece
  do mesmo jeito que "Jogada inválida" já aparece hoje.
