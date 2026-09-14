# Elementos bloqueados no Modo Treino (Bloco 2b) — design

Data: 2026-09-14
Status: aprovado pelo usuário, pronto para virar plano de implementação.

## Contexto

Segundo de quatro blocos decididos com o usuário numa mesma conversa de
brainstorming (ver `docs/superpowers/specs/2026-09-12-combo-ap-cost-design.md`):

- Bloco 2a (feito, `DECISION-046`): custo de AP pra combinar 2-3
  elementos.
- **Bloco 2b (este)**: alguns elementos começam bloqueados.
- Bloco 2c: combos viram "ataques" desbloqueáveis, equipáveis/
  trocáveis, limite de 3 (fora de escopo aqui).
- Bloco 2d: tela de batalha estilo Pokémon (fora de escopo aqui).

Hoje os 10 elementos (`Elements.all`) ficam sempre livres pros dois
jogadores desde o início de qualquer partida do Modo Treino — nenhum
progresso guarda relação com "quais elementos posso usar".

## Escopo

**Só Modo Treino.** O Multiplayer não tem progressão persistente entre
partidas ainda (Bloco 11, bloqueado em credencial Firebase) — aplicar
elementos bloqueados lá reintroduziria o mesmo problema que o Bloco 10
resolveu só pro Treino ("progresso que reseta toda partida"). Nada
neste bloco toca `BattleState`/`TurnEngine` (Dart) nem
`backend/src/battle-rules/` (TypeScript) — fica inteiramente na
Skill Tree do `battle_engine` (reaproveitada, engine-level) e na
camada Game Domain/UI do app.

### A mecânica

Cada jogador (Jogador A e Jogador B independentemente, mesma separação
que a Skill Tree já tem hoje) escolhe **2 elementos iniciais**, uma vez
só, na primeira vez que abre o Modo Treino — ficam livres pra sempre,
sem custo. Os outros 8 elementos começam bloqueados e se desbloqueiam
via Skill Tree (reaproveitando `SkillGrant`/`SkillProgress`, mesmo
mecanismo de Mutações/CombinationModifiers/MaxHpBonus), mas com uma
condição extra: **custo crescente em turnos jogados**, não só
pré-requisito.

- O 3º elemento desbloqueado custa **10 turnos jogados** (daquele
  jogador, cumulativo, contando desde sempre — não reseta em "Nova
  partida", igual Skill Tree/Livro de Descobertas).
- O 4º custa **20**, o 5º **30**, e assim por diante — regra geral:
  `custo = (E - 1) × 10`, onde `E` é quantos elementos esse jogador
  **já tem desbloqueados no momento da tentativa** (contando os 2
  iniciais, sem contar o elemento que está tentando desbloquear
  agora). Com os 2 iniciais (`E=2`), o 3º custa `(2-1)×10=10`; depois
  de desbloqueá-lo (`E=3`), o 4º custa `(3-1)×10=20`; e assim por
  diante.
- O jogador escolhe livremente QUAL dos elementos ainda bloqueados
  gastar seu "próximo desbloqueio" em — sem ordem fixa entre eles (os
  10 nós da nova branch não têm pré-requisito uns dos outros).
- Sem o pré-requisito hoje existente (nenhum), mas SEM turnos
  suficientes: tentativa de desbloquear rejeitada (mesmo padrão de erro
  que "não dá pra desbloquear ainda" já usa).

**Consequência aceita, não é bug**: com só 2 elementos iniciais, é
plenamente possível que a escolha do jogador não bata com nenhuma das
3 combinações existentes (Fogo+Vento, Água+Raio, Terra+Fogo+Água) — ele
só descobre combos depois de desbloquear o elemento que falta. Isso é
o próprio ponto do bloco.

**Saves existentes**: um jogador que já tinha progresso salvo antes
deste bloco existir simplesmente não tem nenhum nó da branch
"elementos" desbloqueado ainda — cai automaticamente no fluxo de
escolha inicial na primeira vez que abrir o Treino depois da
atualização, sem precisar de migração especial. O contador de turnos
cumulativos começa do zero nesse momento (turnos jogados antes da
atualização não contam) — aceito, sem tentativa de estimar/recuperar.

## `battle_engine` (Dart)

### `ElementUnlock` (`packages/battle_engine/lib/src/element_unlock.dart`, novo)

Novo `SkillGrant`, mesmo padrão de `MaxHpBonus`:

```dart
import 'skill_grant.dart';

/// A [SkillGrant] that unlocks a specific element for use — the
/// build-level counterpart to [Mutation]/[CombinationModifier]/
/// [MaxHpBonus]. Plain data; [SkillProgress.grantedElementIds] collects
/// which elements a player can currently play with.
class ElementUnlock implements SkillGrant {
  @override
  final String id;
  final String elementId;

  const ElementUnlock({required this.id, required this.elementId});

  @override
  bool operator ==(Object other) => other is ElementUnlock && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ElementUnlock($id)';
}
```

(Sem `name`/`description` própria — diferente de `MaxHpBonus`, esses
dois campos nunca são lidos em nenhum lugar do código hoje fora da
própria definição; o `SkillNode` que usa este grant já carrega
`name`/`description` pra exibição. Evita campo morto.)

### `ElementUnlocks` (`packages/battle_engine/lib/src/element_unlocks.dart`, novo)

Mesmo padrão de `MaxHpBonuses`, um `const` por elemento — os 10, não só
os 8 "trancáveis por padrão" (qual par começa livre é escolha do
jogador, não da árvore):

```dart
import 'element_unlock.dart';

class ElementUnlocks {
  ElementUnlocks._();

  static const fire = ElementUnlock(id: 'unlock_fire', elementId: 'fire');
  static const water = ElementUnlock(id: 'unlock_water', elementId: 'water');
  static const wind = ElementUnlock(id: 'unlock_wind', elementId: 'wind');
  static const ice = ElementUnlock(id: 'unlock_ice', elementId: 'ice');
  static const nature = ElementUnlock(id: 'unlock_nature', elementId: 'nature');
  static const lightning = ElementUnlock(id: 'unlock_lightning', elementId: 'lightning');
  static const earth = ElementUnlock(id: 'unlock_earth', elementId: 'earth');
  static const shadow = ElementUnlock(id: 'unlock_shadow', elementId: 'shadow');
  static const light = ElementUnlock(id: 'unlock_light', elementId: 'light');
  static const poison = ElementUnlock(id: 'unlock_poison', elementId: 'poison');

  static const List<ElementUnlock> all = [
    fire, water, wind, ice, nature, lightning, earth, shadow, light, poison,
  ];
}
```

### `defaultSkillTree` ganha a branch `"elementos"`

10 nós novos, adicionados dentro do literal de lista que já existe em
`defaultSkillTree = SkillTree([...])`, usando um `for` de coleção (Dart
permite isso dentro de um literal de lista) — sem `prerequisites` entre
si nem com as outras branches:

```dart
final defaultSkillTree = SkillTree([
  // ... os 8 SkillNodes já existentes, sem mudança ...
  for (final unlock in ElementUnlocks.all)
    SkillNode(
      id: unlock.id,
      name: Elements.all.firstWhere((e) => e.id == unlock.elementId).name,
      description: 'Desbloqueia o elemento '
          '${Elements.all.firstWhere((e) => e.id == unlock.elementId).name} '
          'pra jogar.',
      branch: 'elementos',
      grants: unlock,
    ),
]);
```

Gera os 10 nós data-driven a partir de `ElementUnlocks.all`/
`Elements.all`, sem repetir os 10 nomes na mão.

### `SkillProgress` ganha `grantedElementIds`

Mesmo padrão de `grantedMutations`/`grantedCombinationModifiers`:

```dart
/// Element ids granted by unlocked nodes (nodes that grant something
/// else are skipped), in unlock order, deduplicated by id.
List<String> get grantedElementIds {
  return _grantedOfType<ElementUnlock>((grant) => grant.id)
      .map((grant) => grant.elementId)
      .toList();
}
```

## Cliente (Flutter) — `TrainingProgressStore`

Uma chave nova (turnos cumulativos por slot), mesmo padrão das
existentes:

```dart
static const _turnsPlayedKeyPrefix = 'training_turns_played_';

Future<int> loadTurnsPlayed(String slot) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt('$_turnsPlayedKeyPrefix$slot') ?? 0;
}

Future<void> saveTurnsPlayed(String slot, int turnsPlayed) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('$_turnsPlayedKeyPrefix$slot', turnsPlayed);
}
```

Não precisa de chave nova pra "o jogador já escolheu os 2 iniciais?" —
isso é derivado: `unlockedNodeIds` daquele slot conter ao menos um nó
da branch "elementos" já responde a pergunta (ver seção da tela de
onboarding abaixo).

## Cliente (Flutter) — `TrainingMatch`

- Construtor ganha `int initialTurnsPlayedA = 0, initialTurnsPlayedB = 0`
  (cumulativos, persistidos — não confundir com o `_turnsPlayed` já
  existente, que é efêmero por partida e só serve pra sequenciar
  animação de ataque).
- Dois campos internos `_cumulativeTurnsA`/`_cumulativeTurnsB`,
  seedados dos parâmetros acima, incrementados em `playElementIds` pra
  quem quer que tenha acabado de jogar (além do `_turnsPlayed++` já
  existente, que continua intocado).
- `unlockSkillForCurrentPlayer(nodeId)`: antes de chamar
  `progress.unlock(nodeId)`, se `defaultSkillTree.nodeById(nodeId)!.grants
  is ElementUnlock`, calcular `requiredTurns =
  (progress.grantedElementIds.length - 1) * 10` e comparar com o
  contador cumulativo do jogador da vez; se insuficiente, lançar
  `StateError('Faltam ${requiredTurns - cumulativo} turnos para '
  'desbloquear ${node.name}.')` — mesmo tipo de exceção que
  `SkillProgress.unlock` já lança pra "não dá pra desbloquear ainda",
  capturado do mesmo jeito pela UI (`onUnlock` devolve `e.message`).
- `playElementIds(elementIds)`: checagem defensiva nova, antes de
  montar a `Ability` — se algum id em `elementIds` não estiver em
  `_currentProgress.grantedElementIds`, lançar `ArgumentError` (mesmo
  tipo já usado pra "id de elemento desconhecido" — a UI nunca deveria
  permitir isso, mas fecha a garantia mesmo se algo escapar). Depois
  de aplicar dano/aplicar mutação/etc, salvar o contador cumulativo
  atualizado é responsabilidade de quem chama (`TrainingScreen`, igual
  já faz hoje pro Livro de Descobertas).
- Getters novos: `List<String> get availableElementIdsForCurrentPlayer`
  (= `_currentProgress.grantedElementIds`, usado pelo picker de
  elementos pra saber o que está liberado); `int
  cumulativeTurnsPlayedA`/`cumulativeTurnsPlayedB` (diretos por
  jogador, **não** "do jogador da vez" — depois de `playElementIds`
  passar o turno, "o jogador da vez" já é o oponente de quem acabou de
  jogar, então `TrainingScreen` precisa poder ler o valor de quem
  jogou por último, não de quem vai jogar a seguir; segue o mesmo
  padrão de `unlockedNodeIdsForPlayerA`/`PlayerB`, que já são diretos
  por jogador pelo mesmo motivo); `int?
  turnsRemainingToUnlock(String nodeId)` (opera sobre o jogador da vez
  **atual** — usado só a partir da tela de Skill Tree, que sempre abre
  pro jogador da vez, igual `unlockSkillForCurrentPlayer` já faz hoje;
  null se o nó não é um `ElementUnlock`, já está desbloqueado, ou a
  exigência já foi atingida — senão a diferença positiva).

## Cliente (Flutter) — tela de escolha inicial

Novo arquivo `app/lib/ui/element_starter_screen.dart` — tela cheia
(mesmo padrão bloqueante que `UpdateGateScreen` já usa pro app
inteiro, só que aqui é local ao Modo Treino): grade de
`PixelElementChip` pros 10 elementos, seleciona até 2, botão
"Confirmar" só habilita com exatamente 2 escolhidos. Devolve os 2 ids
escolhidos (via callback ou `Navigator.pop`); não decide sozinha onde
persistir.

`TrainingScreen`: depois de carregar `unlockedNodeIdsA`/`B` (já
carregado hoje pro Bloco 10) e `turnsPlayedA`/`B` (novo, via
`TrainingProgressStore.loadTurnsPlayed`), checar se `unlockedNodeIdsA`
contém algum id que comece com `'unlock_'` (ou:
`ElementUnlocks.all.any((u) => unlockedNodeIdsA.contains(u.id))`) — se
não, mostrar `ElementStarterScreen(playerLabel: 'Jogador A', ...)` no
lugar do conteúdo normal. Ao confirmar, salvar via
`TrainingProgressStore.saveUnlockedNodeIds('a', [...unlockedNodeIdsA,
...os 2 ids escolhidos])` e repetir a checagem pro slot `'b'`. Só
depois de ambos resolvidos (ou já tinham progresso antes), construir o
`TrainingMatch.fromPersistedProgress(...)`.

Diferente do que a lista de parâmetros de `fromPersistedProgress`
sugeriria por analogia direta: esse factory **precisa** de dois
parâmetros novos, `required int turnsPlayedA, required int
turnsPlayedB`, repassados pro construtor como `initialTurnsPlayedA`/
`initialTurnsPlayedB` — sem isso, o contador cumulativo não teria como
ser carregado do disco. Pelo mesmo motivo,
`startNewBattleKeepingProgress()` (que hoje só repassa
`initialProgressA/B`/`initialDiscoveryBook` pra um `TrainingMatch`
novo, resetando HP/turno/campo) precisa passar também
`initialTurnsPlayedA: _cumulativeTurnsA, initialTurnsPlayedB:
_cumulativeTurnsB` — o contador cumulativo **não** é HP/turno/campo,
segue a mesma regra de "sobrevive à Nova partida" que Skill Tree/Livro
de Descobertas já seguem.

## Cliente (Flutter) — picker de elementos (`_openElementPicker`)

Elemento fora de `_match.availableElementIdsForCurrentPlayer`: chip
renderizado com `onTap: null` (já fica com opacidade reduzida
automaticamente, `PixelElementChip` já suporta isso) e rótulo trocado
pra `'🔒 ${element.name}'` em vez de `'${element.symbol} ${element.name}'`
— deixa claro que está bloqueado, não só "desabilitado por algum
motivo".

## Cliente (Flutter) — `SkillTreeScreen`

Widget compartilhado com o Multiplayer — não pode saber sobre "turnos
jogados" diretamente (conceito que não existe lá). Ganha um parâmetro
opcional novo:

```dart
final String? Function(String nodeId)? extraLockedHint;
```

Quando não-nulo e devolve uma string pra um nó com estado
`available` (pré-requisitos ok, mas ainda bloqueado por outro motivo),
o painel de detalhe mostra esse texto no lugar do botão "Desbloquear"
— mesma posição onde já mostra "Só dá pra desbloquear na sua vez."
hoje. `training_screen.dart` passa `extraLockedHint: (id) =>
_match.turnsRemainingToUnlock(id) != null ? 'Faltam
${_match.turnsRemainingToUnlock(id)} turnos.' : null`;
`multiplayer_battle_screen.dart` não passa nada (mantém `null`,
comportamento inalterado).

**Limitação visual já conhecida e aceita** (registrada no BACKLOG):
`orderBranchNodes`/`_BranchColumn` desenham uma linha conectando nós
consecutivos de uma branch, dando a impressão de uma cadeia linear —
os 10 nós de "elementos" não têm pré-requisito nenhum entre si (o
jogador escolhe livremente qual desbloquear a seguir), então a linha
vai aparecer mesmo sem relação de dependência real. Puramente
cosmético, mesma limitação que já existia pras outras branches se um
dia ganharem ramificação — não é regressão nova deste bloco.

## Testes esperados

- `element_unlock_test.dart`/equivalente: `ElementUnlock` guarda
  `id`/`elementId`, igualdade por `id`.
- `skill_progress_test.dart`: `grantedElementIds` reflete só nós de
  `ElementUnlock` desbloqueados, deduplicado, ignora outros tipos de
  grant.
- `training_match_test.dart`: `availableElementIdsForCurrentPlayer`
  reflete os ids reais; `playElementIds` lança `ArgumentError` pra um
  elemento fora da lista; `unlockSkillForCurrentPlayer` lança
  `StateError` com a mensagem certa quando os turnos cumulativos não
  bastam pro nó de elemento tentado, e desbloqueia normalmente quando
  bastam; `turnsRemainingToUnlock` calcula certo em cada estágio
  (2 iniciais → precisa de 10 pro 3º; depois de desbloquear o 3º,
  precisa de 20 pro 4º); contador cumulativo sobrevive a
  `startNewBattleKeepingProgress` (não reseta) mas HP/turno/campo
  resetam normalmente.
- `training_progress_store_test.dart`: `loadTurnsPlayed`/
  `saveTurnsPlayed` isolados, default 0 quando nunca salvo.
- Teste de widget novo pra `ElementStarterScreen`: seleciona até 2,
  "Confirmar" desabilitado com 0 ou 1 selecionado, habilitado com 2,
  devolve os ids certos.
- `training_screen_test.dart`: abrir o Treino sem nenhum progresso
  salvo mostra a escolha inicial pro Jogador A, depois pro Jogador B,
  só então o jogo normal; elemento bloqueado aparece com cadeado no
  picker e não é selecionável; Skill Tree mostra "Faltam N turnos."
  pra um nó de elemento ainda não alcançável.
- Verificação manual: abrir o Treino pela primeira vez (sem
  `shared_preferences` prévio), escolher 2 elementos pra cada jogador,
  jogar turnos até acumular 10, desbloquear um 3º elemento na Skill
  Tree, confirmar que ele aparece liberado no picker.

## Fora de escopo, mas não esquecido

- Multiplayer (aguardando o Bloco 11 dar persistência de verdade lá
  primeiro).
- Bloco 2c (ataques equipáveis) e 2d (UI estilo Pokémon) — sequência já
  combinada.
- Recuperar/estimar turnos jogados antes deste bloco existir — aceito
  como perda, sem migração.
- Indicador visual mais rico que o texto "Faltam N turnos." (ex: barra
  de progresso) — pode ser retoque de UX futuro, não pedido agora.
