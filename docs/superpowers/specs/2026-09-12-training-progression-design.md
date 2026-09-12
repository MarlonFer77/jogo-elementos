# Progressão persistente do Modo Treino (Bloco 10) — design

Data: 2026-09-12
Status: aprovado pelo usuário, pronto para virar plano de implementação.

## Contexto

Skill Tree e Livro de Descobertas já funcionam de verdade no Modo
Treino, mas são recriados do zero a cada partida — `TrainingMatch`
monta um `SkillProgress`/`DiscoveryBook` novo em memória sempre que é
construído ("Nova partida" recria tudo), e fechar/reabrir o app perde
tudo. Próximo item sem bloco dedicado na ordem de prioridade do
CLAUDE.md: progressão.

Este é o primeiro dos dois blocos de progressão decididos com o
usuário — o segundo (Bloco 11, Multiplayer: Skill Tree persistente +
Livro de Descobertas novo no backend via Firestore) foi separado por
depender de credenciais reais do projeto Firebase (`elements-1173d`,
já criado) e ter escopo bem maior. Este bloco (10) cobre só o Modo
Treino, inteiramente local ao aparelho, sem depender de rede nem do
Firebase.

## Escopo

- Skill Tree: cada slot (Jogador A / Jogador B, hotseat no mesmo
  aparelho) tem seu próprio progresso persistido — sobrevive a "Nova
  partida" e a fechar/reabrir o app.
- Livro de Descobertas: **compartilhado**, não por slot — já é assim
  hoje dentro de uma partida (`DiscoveryBook` é uma instância só,
  independente de quem descobriu a combinação); persistir mantém esse
  mesmo comportamento, só passa a sobreviver entre partidas.
- "Nova partida" deixa de resetar Skill Tree/Descobertas: volta a
  carregar o que está salvo, só reinicia a batalha (HP/turno/campo).
- Fora de escopo: Multiplayer (Bloco 11, separado); Livro de
  Descobertas por slot (não é como o sistema já funciona hoje, YAGNI);
  qualquer sincronização entre aparelhos (é local, por design — sem
  conta/login).

## Persistência: `shared_preferences` (novo pacote)

Pacote oficial do time Flutter (`shared_preferences: ^2.x`), key-value
simples, sem custo, tudo local. `getStringList`/`setStringList` bastam
— nenhum dos dados a persistir precisa de JSON (são listas de string
puras: ids de nós desbloqueados, ids de combinações descobertas).

## `TrainingProgressStore` (`game_domain/training_progress_store.dart`, novo)

```dart
import 'package:shared_preferences/shared_preferences.dart';

/// Persiste o progresso do Modo Treino (Skill Tree por slot, Livro de
/// Descobertas compartilhado) entre partidas e entre execuções do app
/// — `shared_preferences`, local ao aparelho, sem rede.
class TrainingProgressStore {
  static const _unlockedKeyPrefix = 'training_unlocked_';
  static const _discoveredKey = 'training_discovered';

  Future<List<String>> loadUnlockedNodeIds(String slot) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('$_unlockedKeyPrefix$slot') ?? const [];
  }

  Future<void> saveUnlockedNodeIds(String slot, List<String> unlockedNodeIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('$_unlockedKeyPrefix$slot', unlockedNodeIds);
  }

  Future<List<String>> loadDiscoveredCombinationIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_discoveredKey) ?? const [];
  }

  Future<void> saveDiscoveredCombinationIds(List<String> discoveredCombinationIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_discoveredKey, discoveredCombinationIds);
  }
}
```

`slot` é `'a'`/`'b'`, literal (só dois valores possíveis, não precisa
de enum). Testável com o utilitário oficial do próprio pacote —
`SharedPreferences.setMockInitialValues({})` no `setUp` do teste, sem
precisar inventar abstração/interface nova (diferente do padrão do
`SfxPlayer` — ali a injeção era necessária porque `flame_audio` não
tem um utilitário de teste equivalente; `shared_preferences` já tem).

## `TrainingMatch` ganha memória

`battle_engine`'s `SkillProgress`/`DiscoveryBook` já suportam ser
construídos com progresso existente (`SkillProgress(tree,
unlockedNodeIds: [...])`, `DiscoveryBook(discoveredCombinationIds:
{...})`) — nenhuma mudança no `battle_engine` é necessária.

`TrainingMatch` (`game_domain/training_match.dart`) passa a ter um
construtor de verdade (os campos `_state`/`_discoveryBook`/
`_progressA`/`_progressB` viram `late`, setados no corpo do
construtor) com três parâmetros opcionais:

```dart
TrainingMatch({
  SkillProgress? initialProgressA,
  SkillProgress? initialProgressB,
  DiscoveryBook? initialDiscoveryBook,
}) {
  _progressA = initialProgressA ?? SkillProgress(defaultSkillTree);
  _progressB = initialProgressB ?? SkillProgress(defaultSkillTree);
  _discoveryBook = initialDiscoveryBook ?? DiscoveryBook();
  _state = BattleState.start(
    playerA: _playerA,
    playerB: _playerB,
    playerAMaxHp: _baseMaxHp + _progressA.grantedMaxHpBonus,
    playerBMaxHp: _baseMaxHp + _progressB.grantedMaxHpBonus,
  );
}
```

`TrainingMatch()` sem argumentos continua se comportando exatamente
como hoje (progresso vazio, 100 HP pra ambos) — nenhum teste existente
quebra. **Detalhe importante descoberto revisando o código**: o HP
inicial hoje é sempre 100 fixo; com progresso persistido, o bônus de
"Treino de Vitalidade" já desbloqueado precisa entrar na conta já na
primeira batalha (`_baseMaxHp + progress.grantedMaxHpBonus`), não só
quando desbloqueado ao vivo durante a partida (isso já funciona via
`unlockSkillForCurrentPlayer`/`withMaxHpIncreased`, não muda).

Três getters novos, pra `TrainingScreen` saber o que salvar depois de
cada mudança:

```dart
List<String> get unlockedNodeIdsForPlayerA => _progressA.unlockedNodeIds;
List<String> get unlockedNodeIdsForPlayerB => _progressB.unlockedNodeIds;
List<String> get discoveredCombinationIds => _discoveryBook.discoveredCombinationIds.toList();
```

## `TrainingScreen`: carregar e salvar

Fluxo novo, só quando a tela é aberta sem `initialMatch` (uso real do
app — os testes que já passam `initialMatch` continuam síncronos e
inalterados):

1. `initState`: se `widget._initialMatch` foi passado, comportamento
   atual, sem loading. Senão, `_loading = true` e dispara o
   carregamento assíncrono.
2. Carregamento: lê os dois slots + descobertas via
   `TrainingProgressStore`, monta `SkillProgress(defaultSkillTree,
   unlockedNodeIds: ...)` pra cada slot e `DiscoveryBook
   (discoveredCombinationIds: ...)`, constrói o `TrainingMatch` com
   esses três parâmetros, `setState(() => _loading = false)`.
3. Enquanto `_loading`, a tela mostra só um indicador de carregamento
   centralizado (`CircularProgressIndicator`) dentro do mesmo
   `Scaffold` — rápido, `shared_preferences` é local.
4. Depois de `unlockSkillForCurrentPlayer` ter sucesso: salva
   `unlockedNodeIdsForPlayerA`/`B` (o slot que acabou de desbloquear).
5. Depois de `playElementIds`: se `discoveredCombinationIds.length`
   mudou, salva a lista nova (Livro de Descobertas).
6. "Nova partida" (`_startNewMatch`) passa a ser assíncrona: reexecuta
   o mesmo carregamento do passo 2 (recarrega o que está salvo — Skill
   Tree/Descobertas preservados) e só zera `_selectedIds`/`_error`; a
   batalha em si (HP/turno/campo) nasce nova porque é um `TrainingMatch`
   novo.

## Testes esperados

- `training_progress_store_test.dart` (novo): salva e recarrega um
  slot, slot vazio devolve lista vazia, dois slots independentes não
  se misturam, descobertas salvam e recarregam — usando
  `SharedPreferences.setMockInitialValues({})`.
- `training_match_test.dart`: `TrainingMatch` construído com
  `initialProgressA` já tendo "Treino de Vitalidade" começa com 120 HP
  (não 100); construído com `initialProgressA` tendo "Maestria da
  Brasa" já consegue aplicar Queimadura na primeira jogada, sem
  precisar desbloquear de novo; `unlockedNodeIdsForPlayerA`/`B`/
  `discoveredCombinationIds` refletem o estado real.
- `training_screen_test.dart`: um teste novo cobrindo o carregamento
  assíncrono real (sem `initialMatch`, com `setMockInitialValues`
  pré-populado) — a tela mostra o progresso já desbloqueado depois de
  carregar. Os testes existentes (todos com `initialMatch`) continuam
  passando sem mudança.
- Nenhum teste existente deveria quebrar — `TrainingMatch()` sem
  argumentos e `TrainingScreen(initialMatch: ...)` continuam com o
  mesmo comportamento de hoje.
- Verificação manual: `flutter run -d web-server` (o pacote
  `shared_preferences` funciona em Web via `localStorage`) —
  desbloquear um nó, fechar a aba, abrir de novo, confirmar que
  continua desbloqueado.

## Fora de escopo, mas não esquecido

- Multiplayer (Skill Tree persistente + Livro de Descobertas novo no
  backend) — Bloco 11, depende da credencial de serviço do Firebase.
- Livro de Descobertas por slot (A separado de B) — YAGNI, não é como
  o sistema já funciona hoje.
- Sincronizar progresso entre aparelhos — sem conta/login, é local por
  design.
