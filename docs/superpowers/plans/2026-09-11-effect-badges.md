# Badges de status/efeito de campo (Bloco 9) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mostrar status ativos por jogador (Queimadura, Escudo...) e efeitos de campo (Tempestade Ígnea, Lava...) como badges pequenos e coloridos na cena de batalha, no Modo Treino e no Multiplayer, em vez de só texto cru.

**Architecture:** Um tipo de dado puro (`EffectBadgeView`) carrega id+turnos-restantes; `TrainingMatch`/`MultiplayerMatch` ganham getters novos que o produzem a partir do que já têm (o backend do Multiplayer já manda `combatantStatuses`, só o cliente nunca parseou); um mapa id→ícone/cor (`status_visuals.dart`) resolve a aparência; `BattleSceneView`/`BattleHudWidget` ganham os campos/badges visuais. Nenhuma mudança em `battle_engine`/backend.

**Tech Stack:** Flutter/Dart, `flutter_test`.

**Spec:** [docs/superpowers/specs/2026-09-11-effect-badges-design.md](../specs/2026-09-11-effect-badges-design.md)

## Global Constraints

- Nenhuma mudança em `battle_engine`/`backend/src/battle-rules/` — puramente cliente (o backend já manda `combatantStatuses`, confirmado lendo `backend/src/routes/matches.ts`/`backend/src/battle-rules/types.ts`).
- Badge é círculo colorido com emoji (estilo escolhido pelo usuário no companheiro visual) — não a família pixel art (`PixelMenuButton`/`PixelElementChip`).
- 11 ids de status cobertos desde já (`burn`, `freeze`, `wet`, `poison`, `shock`, `slow`, `shield`, `silence`, `buff`, `debuff`, `area_effect`), mesmo os inertes hoje — data-driven, sem custo extra.
- Fallback genérico (`?`/cinza pra status, `✨` pra campo) pra qualquer id sem entrada dedicada — nunca deveria ser atingido, mas não quebra se acontecer.
- `remainingTurns` (ou `duration`) é `null` quando o efeito não tem contagem visível (Escudo dura até ser consumido; nenhuma combinação atual define duração de campo) — badge mostra só o ícone, sem número, nesse caso.
- Fora de escopo: sem animação nova nos badges, sem tooltip, sem ícone dedicado por combinação futura (cai no fallback).
- **Lição de teste (padrão desta sessão):** nunca chamar `pumpAndSettle()` numa árvore de widget com `AnimationController` repetindo (`TrainerSpriteImage`) — não se aplica a `BattleHudWidget` (sem esse componente), então `pumpAndSettle()` continua seguro nos testes desse widget, como já é usado hoje.
- `flutter run -d web-server` nunca recompila sozinho ao recarregar — sempre reiniciar com `preview_stop` + `preview_start` completo antes de verificar manualmente.

---

## Arquivos afetados

**Novos:**
- `app/lib/game_domain/effect_badge_view.dart` — `EffectBadgeView`.
- `app/test/game_domain/effect_badge_view_test.dart`.
- `app/lib/game_presentation/status_visuals.dart` — `statusIcon`/`statusColor`/`fieldEffectIcon`.
- `app/test/game_presentation/status_visuals_test.dart`.

**Modificados:**
- `app/lib/game_domain/training_match.dart` / `app/test/game_domain/training_match_test.dart` — 3 getters novos.
- `app/lib/game_domain/multiplayer_models.dart` — `RemoteActiveStatus` novo, `RemoteBattleState.combatantStatuses` novo.
- `app/lib/game_domain/multiplayer_match.dart` / `app/test/game_domain/multiplayer_match_test.dart` — 3 getters novos + fixture de `combatantStatuses` no fake backend.
- `app/lib/game_domain/battle_scene_view.dart` / `app/test/game_domain/battle_scene_view_test.dart` — 3 campos novos.
- `app/lib/game_presentation/battle_hud_widget.dart` / `app/test/game_presentation/battle_hud_widget_test.dart` — badges visuais.
- `app/lib/ui/training_screen.dart` — fiação.
- `app/lib/ui/multiplayer_battle_screen.dart` — fiação.
- `DECISIONS.md` — nova entrada DECISION-044.
- `TASKS.md` — marca o bloco como DONE.

---

### Task 1: `EffectBadgeView`

**Files:**
- Create: `app/lib/game_domain/effect_badge_view.dart`
- Test: `app/test/game_domain/effect_badge_view_test.dart`

**Interfaces:**
- Produces: `class EffectBadgeView { final String id; final int? remainingTurns; const EffectBadgeView({required id, remainingTurns}); }` com `==`/`hashCode` por valor (`id` + `remainingTurns`) — usado por todas as tasks seguintes, e necessário pra comparar listas em teste (`expect(list, [EffectBadgeView(...)])`).

- [ ] **Step 1: Escrever o teste falho**

Criar `app/test/game_domain/effect_badge_view_test.dart`:

```dart
import 'package:app/game_domain/effect_badge_view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('holds id and remainingTurns', () {
    const badge = EffectBadgeView(id: 'burn', remainingTurns: 2);
    expect(badge.id, 'burn');
    expect(badge.remainingTurns, 2);
  });

  test('remainingTurns defaults to null', () {
    const badge = EffectBadgeView(id: 'shield');
    expect(badge.remainingTurns, isNull);
  });

  test('two badges with the same id and remainingTurns are equal', () {
    expect(
      const EffectBadgeView(id: 'burn', remainingTurns: 2),
      const EffectBadgeView(id: 'burn', remainingTurns: 2),
    );
  });

  test('badges with different remainingTurns are not equal', () {
    expect(
      const EffectBadgeView(id: 'burn', remainingTurns: 2),
      isNot(const EffectBadgeView(id: 'burn', remainingTurns: 1)),
    );
  });
}
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `cd app && flutter test test/game_domain/effect_badge_view_test.dart`
Expected: FAIL — `effect_badge_view.dart` ainda não existe.

- [ ] **Step 3: Implementar `EffectBadgeView`**

Criar `app/lib/game_domain/effect_badge_view.dart`:

```dart
/// Dado puro pra um badge de status ativo (por jogador) ou efeito de
/// campo (compartilhado): [id] mapeia pra ícone/cor em
/// `game_presentation/status_visuals.dart`; [remainingTurns] é `null`
/// quando o efeito não tem contagem visível — Escudo dura até ser
/// consumido, e nenhuma combinação atual define duração de campo.
class EffectBadgeView {
  final String id;
  final int? remainingTurns;

  const EffectBadgeView({required this.id, this.remainingTurns});

  @override
  bool operator ==(Object other) =>
      other is EffectBadgeView &&
      other.id == id &&
      other.remainingTurns == remainingTurns;

  @override
  int get hashCode => Object.hash(id, remainingTurns);
}
```

- [ ] **Step 4: Rodar o teste e confirmar que passa**

Run: `cd app && flutter test test/game_domain/effect_badge_view_test.dart`
Expected: PASS (4 testes).

- [ ] **Step 5: Commit**

```bash
git add app/lib/game_domain/effect_badge_view.dart app/test/game_domain/effect_badge_view_test.dart
git commit -m "$(cat <<'EOF'
Adiciona EffectBadgeView (Bloco 9, badges de status/campo)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Ícones e cores (`status_visuals.dart`)

**Files:**
- Create: `app/lib/game_presentation/status_visuals.dart`
- Test: `app/test/game_presentation/status_visuals_test.dart`

**Interfaces:**
- Produces: `String statusIcon(String statusId)`, `Color statusColor(String statusId)`, `String fieldEffectIcon(String fieldEffectId)`.

- [ ] **Step 1: Escrever o teste falho**

Criar `app/test/game_presentation/status_visuals_test.dart`:

```dart
import 'package:app/game_presentation/status_visuals.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('statusIcon', () {
    test('resolves every known status id to a distinct icon', () {
      const ids = [
        'burn', 'freeze', 'wet', 'poison', 'shock', 'slow', 'shield',
        'silence', 'buff', 'debuff', 'area_effect',
      ];
      final icons = ids.map(statusIcon).toSet();
      expect(icons.length, ids.length);
    });

    test('falls back to "?" for an unknown id', () {
      expect(statusIcon('not_a_real_status'), '?');
    });
  });

  group('statusColor', () {
    test('resolves a known id to a real color', () {
      expect(statusColor('burn'), isNot(const Color(0xFF9E9E9E)));
    });

    test('falls back to grey for an unknown id', () {
      expect(statusColor('not_a_real_status'), const Color(0xFF9E9E9E));
    });
  });

  group('fieldEffectIcon', () {
    test('resolves the 3 known field effects', () {
      expect(fieldEffectIcon('ignited_storm'), '🌪️');
      expect(fieldEffectIcon('electrified_field'), '🌩️');
      expect(fieldEffectIcon('lava'), '🌋');
    });

    test('falls back to a generic icon for an unknown id', () {
      expect(fieldEffectIcon('not_a_real_combo'), '✨');
    });
  });
}
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `cd app && flutter test test/game_presentation/status_visuals_test.dart`
Expected: FAIL — `status_visuals.dart` ainda não existe.

- [ ] **Step 3: Implementar `status_visuals.dart`**

Criar `app/lib/game_presentation/status_visuals.dart`:

```dart
import 'package:flutter/material.dart' show Color;

const Map<String, String> _statusIcons = {
  'burn': '🔥',
  'freeze': '❄️',
  'wet': '💧',
  'poison': '☠️',
  'shock': '⚡',
  'slow': '🐌',
  'shield': '🛡️',
  'silence': '🤐',
  'buff': '⬆️',
  'debuff': '⬇️',
  'area_effect': '🌀',
};

const Map<String, Color> _statusColors = {
  'burn': Color(0xFFFF7043),
  'freeze': Color(0xFF64B5F6),
  'wet': Color(0xFF4FC3F7),
  'poison': Color(0xFFAB47BC),
  'shock': Color(0xFFFFD54F),
  'slow': Color(0xFF8D6E63),
  'shield': Color(0xFF90CAF9),
  'silence': Color(0xFFBCAAA4),
  'buff': Color(0xFF81C784),
  'debuff': Color(0xFFE57373),
  'area_effect': Color(0xFFCE93D8),
};

const Map<String, String> _fieldEffectIcons = {
  'ignited_storm': '🌪️',
  'electrified_field': '🌩️',
  'lava': '🌋',
};

/// Ícone (emoji) de um badge de status ativo por jogador. `?` como
/// fallback — nunca deveria ser atingido com um id real de
/// `StatusEffects.all` (`packages/battle_engine`), mas evita quebrar
/// caso a lista de status mude.
String statusIcon(String statusId) => _statusIcons[statusId] ?? '?';

/// Cor do badge de status ativo por jogador. Cinza como fallback, mesmo
/// padrão de `element_visuals.dart`.
Color statusColor(String statusId) =>
    _statusColors[statusId] ?? const Color(0xFF9E9E9E);

/// Ícone (emoji) de um badge de efeito de campo. Fallback genérico (✨)
/// pra qualquer `FieldEffect`/combinação sem entrada dedicada — mantém
/// data-driven: uma combinação nova não quebra nada, só usa o fallback
/// até alguém adicionar o ícone específico.
String fieldEffectIcon(String fieldEffectId) =>
    _fieldEffectIcons[fieldEffectId] ?? '✨';
```

- [ ] **Step 4: Rodar o teste e confirmar que passa**

Run: `cd app && flutter test test/game_presentation/status_visuals_test.dart`
Expected: PASS (6 testes).

- [ ] **Step 5: Commit**

```bash
git add app/lib/game_presentation/status_visuals.dart app/test/game_presentation/status_visuals_test.dart
git commit -m "$(cat <<'EOF'
Adiciona mapa de ícones/cores de status e efeito de campo (Bloco 9)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Dados do Modo Treino (`TrainingMatch`)

**Files:**
- Modify: `app/lib/game_domain/training_match.dart`
- Test: `app/test/game_domain/training_match_test.dart`

**Interfaces:**
- Consumes: `EffectBadgeView` (Task 1).
- Produces: `TrainingMatch.playerAActiveStatuses`/`playerBActiveStatuses`/`activeFieldEffectBadges` — todos `List<EffectBadgeView>`.

- [ ] **Step 1: Escrever os testes falhos**

Em `app/test/game_domain/training_match_test.dart`, adicionar o import:

```dart
import 'package:app/game_domain/effect_badge_view.dart';
import 'package:app/game_domain/training_match.dart';
import 'package:flutter_test/flutter_test.dart';
```

E os testes novos ao final do `main()` (antes do `}` de fechamento), depois do teste `'turnsPlayed counts successful plays regardless of damage'`:

```dart
  test('activeFieldEffectBadges resolves id and remainingTurns from a '
      'triggered combination', () {
    final match = TrainingMatch();
    match.playElementIds(['fire', 'wind']); // Tempestade Ígnea

    expect(
      match.activeFieldEffectBadges,
      [const EffectBadgeView(id: 'ignited_storm', remainingTurns: null)],
    );
  });

  test('playerAActiveStatuses/playerBActiveStatuses resolve id and '
      'remainingTurns from an applied mutation status', () {
    final match = TrainingMatch();
    match.unlockSkillForCurrentPlayer('ember_mastery'); // Jogador A

    match.playElementIds(['fire']); // aplica Queimadura em Jogador B

    expect(match.playerAActiveStatuses, isEmpty);
    expect(
      match.playerBActiveStatuses,
      [const EffectBadgeView(id: 'burn', remainingTurns: 2)],
    );
  });
```

- [ ] **Step 2: Rodar os testes e confirmar que os dois novos falham**

Run: `cd app && flutter test test/game_domain/training_match_test.dart`
Expected: os testes antigos PASS, os 2 novos FAIL — `activeFieldEffectBadges`/`playerAActiveStatuses`/`playerBActiveStatuses` não existem ainda.

- [ ] **Step 3: Implementar os getters**

Em `app/lib/game_domain/training_match.dart`, adicionar o import:

```dart
import 'package:battle_engine/battle_engine.dart';

import 'effect_badge_view.dart';
import 'skill_tree_catalog.dart';
```

E os 3 getters novos, logo depois de `playerBStatusNames` (linha 67 do arquivo atual):

```dart
  List<EffectBadgeView> get playerAActiveStatuses => _state
      .statusesOf(_playerA)
      .map((s) => EffectBadgeView(id: s.effect.id, remainingTurns: s.turnsRemaining))
      .toList();

  List<EffectBadgeView> get playerBActiveStatuses => _state
      .statusesOf(_playerB)
      .map((s) => EffectBadgeView(id: s.effect.id, remainingTurns: s.turnsRemaining))
      .toList();

  List<EffectBadgeView> get activeFieldEffectBadges => _state.activeFieldEffects
      .map((effect) => EffectBadgeView(id: effect.id, remainingTurns: effect.duration))
      .toList();
```

- [ ] **Step 4: Rodar os testes e confirmar que passam**

Run: `cd app && flutter test test/game_domain/training_match_test.dart`
Expected: PASS (todos os testes do arquivo, incluindo os 2 novos).

- [ ] **Step 5: Commit**

```bash
git add app/lib/game_domain/training_match.dart app/test/game_domain/training_match_test.dart
git commit -m "$(cat <<'EOF'
TrainingMatch expõe badges de status/campo (Bloco 9)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Dados do Multiplayer (`RemoteBattleState`/`MultiplayerMatch`)

**Files:**
- Modify: `app/lib/game_domain/multiplayer_models.dart`
- Modify: `app/lib/game_domain/multiplayer_match.dart`
- Test: `app/test/game_domain/multiplayer_match_test.dart`

**Interfaces:**
- Consumes: `EffectBadgeView` (Task 1).
- Produces: `RemoteActiveStatus{effectId, turnsRemaining}`; `RemoteBattleState.combatantStatuses: Map<String, List<RemoteActiveStatus>>`; `MultiplayerMatch.myActiveStatuses`/`opponentActiveStatuses`/`activeFieldEffectBadges` — todos `List<EffectBadgeView>`.

- [ ] **Step 1: Adicionar `combatantStatuses` na fixture do fake backend**

Em `app/test/game_domain/multiplayer_match_test.dart`, no handler de `join` (dentro de `_FakeBackend._handle`), adicionar o campo `combatantStatuses` ao `match['state']`, logo depois de `'hp'`:

```dart
      match['state'] = {
        'playerAId': match['playerAId'],
        'playerBId': match['playerBId'],
        'currentTurnId': match['playerAId'],
        'activeFieldEffects': <dynamic>[],
        'hp': <String, dynamic>{
          match['playerAId'] as String: {'max': 100, 'current': 100},
          match['playerBId'] as String: {'max': 100, 'current': 100},
        },
        'combatantStatuses': <String, dynamic>{
          match['playerAId'] as String: <dynamic>[
            {'effectId': 'burn', 'turnsRemaining': 2, 'damagePerTick': 8},
          ],
          match['playerBId'] as String: <dynamic>[
            {'effectId': 'shield', 'turnsRemaining': null, 'damagePerTick': 0},
          ],
        },
        'winner': null,
      };
```

- [ ] **Step 2: Escrever o teste falho**

No mesmo arquivo, adicionar o import:

```dart
import 'package:app/game_domain/effect_badge_view.dart';
import 'package:app/game_domain/multiplayer_client.dart';
```

E um teste novo, dentro de `void main()`, depois do teste `'join starts the battle and exposes whose turn it is'`:

```dart
  test('myActiveStatuses/opponentActiveStatuses resolve id and '
      'remainingTurns from combatantStatuses', () async {
    final backend = _FakeBackend();
    final ana = MultiplayerMatch(
      client: MultiplayerClient(baseUrl: 'http://x', httpClient: backend.asClient()),
      localPlayerId: 'ana',
    );
    await ana.create();
    final beto = MultiplayerMatch(
      client: MultiplayerClient(baseUrl: 'http://x', httpClient: backend.asClient()),
      localPlayerId: 'beto',
    );
    await beto.join(ana.matchId!);
    await ana.refresh();

    expect(
      ana.myActiveStatuses,
      [const EffectBadgeView(id: 'burn', remainingTurns: 2)],
    );
    expect(
      ana.opponentActiveStatuses,
      [const EffectBadgeView(id: 'shield', remainingTurns: null)],
    );
    expect(
      beto.myActiveStatuses,
      [const EffectBadgeView(id: 'shield', remainingTurns: null)],
    );
    expect(
      beto.opponentActiveStatuses,
      [const EffectBadgeView(id: 'burn', remainingTurns: 2)],
    );
  });
```

- [ ] **Step 3: Rodar o teste e confirmar que falha**

Run: `cd app && flutter test test/game_domain/multiplayer_match_test.dart`
Expected: os testes antigos PASS, o novo FAIL — `myActiveStatuses`/`opponentActiveStatuses` não existem ainda.

- [ ] **Step 4: Implementar `RemoteActiveStatus`/`RemoteBattleState.combatantStatuses`**

Em `app/lib/game_domain/multiplayer_models.dart`, adicionar a classe `RemoteActiveStatus` logo depois de `RemoteHpPool`:

```dart
class RemoteActiveStatus {
  final String effectId;
  final int? turnsRemaining;

  const RemoteActiveStatus({required this.effectId, this.turnsRemaining});

  factory RemoteActiveStatus.fromJson(Map<String, dynamic> json) {
    return RemoteActiveStatus(
      effectId: json['effectId'] as String,
      turnsRemaining: json['turnsRemaining'] as int?,
    );
  }
}
```

Em `RemoteBattleState`, adicionar o campo `combatantStatuses` (depois de `hp`) e parseá-lo em `fromJson`:

```dart
class RemoteBattleState {
  final String playerAId;
  final String playerBId;
  final String currentTurnId;
  final List<RemoteFieldEffect> activeFieldEffects;
  final Map<String, RemoteHpPool> hp;
  final Map<String, List<RemoteActiveStatus>> combatantStatuses;
  final String? winner;

  const RemoteBattleState({
    required this.playerAId,
    required this.playerBId,
    required this.currentTurnId,
    required this.activeFieldEffects,
    required this.hp,
    this.combatantStatuses = const {},
    this.winner,
  });

  factory RemoteBattleState.fromJson(Map<String, dynamic> json) {
    final combatantStatusesJson = json['combatantStatuses'] as Map<String, dynamic>?;
    return RemoteBattleState(
      playerAId: json['playerAId'] as String,
      playerBId: json['playerBId'] as String,
      currentTurnId: json['currentTurnId'] as String,
      activeFieldEffects: (json['activeFieldEffects'] as List)
          .map((e) => RemoteFieldEffect.fromJson(e as Map<String, dynamic>))
          .toList(),
      hp: (json['hp'] as Map<String, dynamic>).map(
        (id, pool) => MapEntry(id, RemoteHpPool.fromJson(pool as Map<String, dynamic>)),
      ),
      combatantStatuses: combatantStatusesJson == null
          ? const {}
          : combatantStatusesJson.map(
              (id, statuses) => MapEntry(
                id,
                (statuses as List)
                    .map((s) => RemoteActiveStatus.fromJson(s as Map<String, dynamic>))
                    .toList(),
              ),
            ),
      winner: json['winner'] as String?,
    );
  }
}
```

(`combatantStatuses` fica `const {}` por padrão — o backend já manda o campo hoje, mas o parse não deve quebrar em nenhuma resposta antiga/inesperada que não tenha.)

- [ ] **Step 5: Implementar os getters em `MultiplayerMatch`**

Em `app/lib/game_domain/multiplayer_match.dart`, adicionar 3 getters novos, logo depois de `activeFieldEffectIds` (linha 57 do arquivo atual):

```dart
  List<EffectBadgeView> _statusesOf(String? playerId) {
    if (playerId == null) return const [];
    final statuses = _match?.state?.combatantStatuses[playerId] ?? const [];
    return statuses
        .map((s) => EffectBadgeView(id: s.effectId, remainingTurns: s.turnsRemaining))
        .toList();
  }

  List<EffectBadgeView> get myActiveStatuses => _statusesOf(localPlayerId);

  List<EffectBadgeView> get opponentActiveStatuses => _statusesOf(_opponentId);

  List<EffectBadgeView> get activeFieldEffectBadges =>
      _match?.state?.activeFieldEffects
          .map((e) => EffectBadgeView(id: e.id, remainingTurns: e.duration))
          .toList() ??
      const [];
```

E o import no topo do arquivo:

```dart
import 'effect_badge_view.dart';
import 'multiplayer_client.dart';
import 'multiplayer_exception.dart';
import 'multiplayer_models.dart';
```

- [ ] **Step 6: Rodar o teste e confirmar que passa**

Run: `cd app && flutter test test/game_domain/multiplayer_match_test.dart`
Expected: PASS (todos os testes do arquivo, incluindo o novo).

- [ ] **Step 7: Commit**

```bash
git add app/lib/game_domain/multiplayer_models.dart app/lib/game_domain/multiplayer_match.dart app/test/game_domain/multiplayer_match_test.dart
git commit -m "$(cat <<'EOF'
MultiplayerMatch expõe badges de status/campo (Bloco 9)

O backend já mandava combatantStatuses em GET /matches/:id desde a
DECISION-024 — só o cliente nunca parseava esse campo.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: `BattleSceneView` ganha os campos de badge

**Files:**
- Modify: `app/lib/game_domain/battle_scene_view.dart`
- Test: `app/test/game_domain/battle_scene_view_test.dart`

**Interfaces:**
- Consumes: `EffectBadgeView` (Task 1).
- Produces: `BattleSceneView.leftStatuses`/`rightStatuses`/`fieldEffects` — todos `List<EffectBadgeView>`, default `const []`.

- [ ] **Step 1: Escrever o teste falho**

Em `app/test/game_domain/battle_scene_view_test.dart`, adicionar o import:

```dart
import 'package:app/game_domain/attack_event.dart';
import 'package:app/game_domain/battle_scene_view.dart';
import 'package:app/game_domain/effect_badge_view.dart';
import 'package:flutter_test/flutter_test.dart';
```

E um teste novo ao final do `main()`:

```dart
  test('leftStatuses/rightStatuses/fieldEffects default to empty and can '
      'be set', () {
    const withoutBadges = BattleSceneView(
      leftCurrentHp: 100, leftMaxHp: 100,
      rightCurrentHp: 100, rightMaxHp: 100,
      isLeftTurn: true,
    );
    expect(withoutBadges.leftStatuses, isEmpty);
    expect(withoutBadges.rightStatuses, isEmpty);
    expect(withoutBadges.fieldEffects, isEmpty);

    const withBadges = BattleSceneView(
      leftCurrentHp: 100, leftMaxHp: 100,
      rightCurrentHp: 100, rightMaxHp: 100,
      isLeftTurn: true,
      leftStatuses: [EffectBadgeView(id: 'burn', remainingTurns: 2)],
      rightStatuses: [EffectBadgeView(id: 'shield')],
      fieldEffects: [EffectBadgeView(id: 'ignited_storm')],
    );
    expect(withBadges.leftStatuses, [const EffectBadgeView(id: 'burn', remainingTurns: 2)]);
    expect(withBadges.rightStatuses, [const EffectBadgeView(id: 'shield')]);
    expect(withBadges.fieldEffects, [const EffectBadgeView(id: 'ignited_storm')]);
  });
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `cd app && flutter test test/game_domain/battle_scene_view_test.dart`
Expected: FAIL — `leftStatuses`/`rightStatuses`/`fieldEffects` não existem ainda.

- [ ] **Step 3: Implementar os campos novos**

Em `app/lib/game_domain/battle_scene_view.dart`, reescrever o arquivo inteiro:

```dart
import 'attack_event.dart';
import 'effect_badge_view.dart';

/// Read-only view of what the battle scene should show: a fraction of HP
/// per side and whose turn it is. Game Presentation (Flame) nunca toca em
/// tipos de `battle_engine` ou do backend diretamente — renderiza um
/// [BattleSceneView], que cada tela monta a partir do que já expõe
/// (`TrainingMatch`/`MultiplayerMatch`). Sem lógica: é um dado puro.
class BattleSceneView {
  final int leftCurrentHp;
  final int leftMaxHp;
  final int rightCurrentHp;
  final int rightMaxHp;
  final bool isLeftTurn;
  final AttackEvent? lastAttack;
  final String leftLabel;
  final String rightLabel;
  final List<EffectBadgeView> leftStatuses;
  final List<EffectBadgeView> rightStatuses;
  final List<EffectBadgeView> fieldEffects;

  const BattleSceneView({
    required this.leftCurrentHp,
    required this.leftMaxHp,
    required this.rightCurrentHp,
    required this.rightMaxHp,
    required this.isLeftTurn,
    this.lastAttack,
    this.leftLabel = 'Esquerda',
    this.rightLabel = 'Direita',
    this.leftStatuses = const [],
    this.rightStatuses = const [],
    this.fieldEffects = const [],
  });
}
```

- [ ] **Step 4: Rodar o teste e confirmar que passa**

Run: `cd app && flutter test test/game_domain/battle_scene_view_test.dart`
Expected: PASS (todos os testes do arquivo, incluindo o novo).

- [ ] **Step 5: Commit**

```bash
git add app/lib/game_domain/battle_scene_view.dart app/test/game_domain/battle_scene_view_test.dart
git commit -m "$(cat <<'EOF'
BattleSceneView ganha campos de badge de status/campo (Bloco 9)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: Badges visuais em `BattleHudWidget`

**Files:**
- Modify: `app/lib/game_presentation/battle_hud_widget.dart`
- Test: `app/test/game_presentation/battle_hud_widget_test.dart`

**Interfaces:**
- Consumes: `BattleSceneView.leftStatuses`/`rightStatuses`/`fieldEffects` (Task 5); `statusIcon`/`statusColor`/`fieldEffectIcon` (Task 2).

- [ ] **Step 1: Escrever os testes falhos**

Em `app/test/game_presentation/battle_hud_widget_test.dart`, adicionar o import:

```dart
import 'package:app/game_domain/battle_scene_view.dart';
import 'package:app/game_domain/effect_badge_view.dart';
import 'package:app/game_presentation/battle_hud_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
```

E dois testes novos ao final do `main()`:

```dart
  testWidgets('shows a status badge with its icon and remaining turns',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: BattleHudWidget(
          view: BattleSceneView(
            leftCurrentHp: 100, leftMaxHp: 100,
            rightCurrentHp: 100, rightMaxHp: 100,
            isLeftTurn: true,
            leftLabel: 'Jogador A',
            rightLabel: 'Jogador B',
            leftStatuses: [EffectBadgeView(id: 'burn', remainingTurns: 2)],
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('🔥'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('shows a field effect badge without a turn count when '
      'remainingTurns is null', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: BattleHudWidget(
          view: BattleSceneView(
            leftCurrentHp: 100, leftMaxHp: 100,
            rightCurrentHp: 100, rightMaxHp: 100,
            isLeftTurn: true,
            leftLabel: 'Jogador A',
            rightLabel: 'Jogador B',
            fieldEffects: [EffectBadgeView(id: 'ignited_storm')],
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('🌪️'), findsOneWidget);
  });
```

- [ ] **Step 2: Rodar os testes e confirmar que falham**

Run: `cd app && flutter test test/game_presentation/battle_hud_widget_test.dart`
Expected: os 3 testes antigos PASS, os 2 novos FAIL — `leftStatuses`/`fieldEffects` ainda não renderizam nada.

- [ ] **Step 3: Implementar os badges**

Em `app/lib/game_presentation/battle_hud_widget.dart`, reescrever o arquivo inteiro:

```dart
import 'package:flutter/material.dart';

import '../game_domain/battle_scene_view.dart';
import '../game_domain/effect_badge_view.dart';
import 'status_visuals.dart';

/// Painel de HP fixo no topo da cena, estilo jogo de luta: nome + barra de
/// HP de cada lado, com o lado ativo destacado (borda + seta), e badges
/// de status ativo por jogador / efeito de campo (Bloco 9 — ver
/// docs/superpowers/specs/2026-09-11-effect-badges-design.md). Flutter
/// puro (não Canvas do Flame) — ver
/// docs/superpowers/specs/2026-09-08-pixel-battle-arena-design.md.
class BattleHudWidget extends StatelessWidget {
  const BattleHudWidget({super.key, required this.view});

  final BattleSceneView view;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _HudPanel(
                  label: view.leftLabel,
                  currentHp: view.leftCurrentHp,
                  maxHp: view.leftMaxHp,
                  isActive: view.isLeftTurn,
                  alignEnd: false,
                  statuses: view.leftStatuses,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HudPanel(
                  label: view.rightLabel,
                  currentHp: view.rightCurrentHp,
                  maxHp: view.rightMaxHp,
                  isActive: !view.isLeftTurn,
                  alignEnd: true,
                  statuses: view.rightStatuses,
                ),
              ),
            ],
          ),
          if (view.fieldEffects.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              children: [
                for (final badge in view.fieldEffects)
                  _EffectBadge(
                    icon: fieldEffectIcon(badge.id),
                    color: const Color(0xFFCFD8DC),
                    remainingTurns: badge.remainingTurns,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _HudPanel extends StatelessWidget {
  const _HudPanel({
    required this.label,
    required this.currentHp,
    required this.maxHp,
    required this.isActive,
    required this.alignEnd,
    required this.statuses,
  });

  final String label;
  final int currentHp;
  final int maxHp;
  final bool isActive;
  final bool alignEnd;
  final List<EffectBadgeView> statuses;

  Widget _buildNameRow() {
    final arrow = Text(
      alignEnd ? '◀' : '▶',
      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFB8860B)),
    );
    final nameText = Text(
      label,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF20242B)),
    );
    final children = alignEnd
        ? [nameText, if (isActive) ...[const SizedBox(width: 4), arrow]]
        : [if (isActive) ...[arrow, const SizedBox(width: 4)], nameText];
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }

  @override
  Widget build(BuildContext context) {
    final fraction = maxHp == 0 ? 0.0 : (currentHp / maxHp).clamp(0.0, 1.0);
    final crossAlign = alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final barAlignment = alignEnd ? Alignment.centerRight : Alignment.centerLeft;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4E4),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isActive ? const Color(0xFFF4C94A) : const Color(0xFF20242B),
          width: isActive ? 3 : 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: crossAlign,
        children: [
          _buildNameRow(),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 10,
              child: Stack(
                alignment: barAlignment,
                children: [
                  Container(color: const Color(0xFF20242B)),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(end: fraction),
                    duration: const Duration(milliseconds: 400),
                    builder: (context, value, _) {
                      return FractionallySizedBox(
                        alignment: barAlignment,
                        widthFactor: value,
                        child: Container(
                          color: value > 0.3
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFE53935),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$currentHp/$maxHp HP',
            style: const TextStyle(fontSize: 10, color: Color(0xFF555555)),
          ),
          if (statuses.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              alignment: alignEnd ? WrapAlignment.end : WrapAlignment.start,
              children: [
                for (final badge in statuses)
                  _EffectBadge(
                    icon: statusIcon(badge.id),
                    color: statusColor(badge.id),
                    remainingTurns: badge.remainingTurns,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EffectBadge extends StatelessWidget {
  const _EffectBadge({required this.icon, required this.color, this.remainingTurns});

  final String icon;
  final Color color;
  final int? remainingTurns;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(icon, style: const TextStyle(fontSize: 10)),
          ),
          if (remainingTurns != null)
            Positioned(
              bottom: -2,
              right: -2,
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(color: Color(0xFF20242B), shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(
                  '$remainingTurns',
                  style: const TextStyle(
                    fontSize: 7,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Rodar os testes e confirmar que passam**

Run: `cd app && flutter test test/game_presentation/battle_hud_widget_test.dart`
Expected: PASS (5 testes).

- [ ] **Step 5: Commit**

```bash
git add app/lib/game_presentation/battle_hud_widget.dart app/test/game_presentation/battle_hud_widget_test.dart
git commit -m "$(cat <<'EOF'
Renderiza badges de status/campo no HUD de batalha (Bloco 9)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: Fiação no Modo Treino

**Files:**
- Modify: `app/lib/ui/training_screen.dart`

**Interfaces:**
- Consumes: `TrainingMatch.playerAActiveStatuses`/`playerBActiveStatuses`/`activeFieldEffectBadges` (Task 3); `BattleSceneView.leftStatuses`/`rightStatuses`/`fieldEffects` (Task 5).

Sem teste dedicado — os getters de `TrainingMatch` (Task 3) e a renderização de `BattleHudWidget` (Task 6) já são testados isoladamente; esta task só liga um no outro. A suíte existente de `TrainingScreen` continua cobrindo que nada quebrou.

- [ ] **Step 1: Passar os badges pro `BattleSceneView`**

Em `app/lib/ui/training_screen.dart`, dentro do `build`, no `BattleSceneWidget`, adicionar os 3 campos novos ao `BattleSceneView`:

```dart
                  BattleSceneWidget(
                    view: BattleSceneView(
                      leftCurrentHp: _match.playerACurrentHp,
                      leftMaxHp: _match.playerAMaxHp,
                      rightCurrentHp: _match.playerBCurrentHp,
                      rightMaxHp: _match.playerBMaxHp,
                      isLeftTurn: _match.isPlayerATurn,
                      lastAttack: _pendingAttack,
                      leftLabel: 'Jogador A',
                      rightLabel: 'Jogador B',
                      leftStatuses: _match.playerAActiveStatuses,
                      rightStatuses: _match.playerBActiveStatuses,
                      fieldEffects: _match.activeFieldEffectBadges,
                    ),
                  ),
```

- [ ] **Step 2: Rodar a suíte de testes de `TrainingScreen` e confirmar que nada quebrou**

Run: `cd app && flutter test test/training_screen_test.dart`
Expected: PASS, sem nenhuma mudança na contagem de testes existente.

- [ ] **Step 3: Rodar `flutter analyze` no app**

Run: `cd app && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add app/lib/ui/training_screen.dart
git commit -m "$(cat <<'EOF'
Mostra badges de status/campo na cena de batalha do Treino (Bloco 9)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: Fiação no Multiplayer

**Files:**
- Modify: `app/lib/ui/multiplayer_battle_screen.dart`

**Interfaces:**
- Consumes: `MultiplayerMatch.myActiveStatuses`/`opponentActiveStatuses`/`activeFieldEffectBadges` (Task 4); `BattleSceneView.leftStatuses`/`rightStatuses`/`fieldEffects` (Task 5).

Sem teste dedicado, mesmo racional da Task 7.

- [ ] **Step 1: Passar os badges pro `BattleSceneView`**

Em `app/lib/ui/multiplayer_battle_screen.dart`, dentro de `_buildBattle`, no `BattleSceneWidget`, adicionar os 3 campos novos ao `BattleSceneView`:

```dart
      BattleSceneWidget(
        view: BattleSceneView(
          leftCurrentHp: _match.myCurrentHp ?? 0,
          leftMaxHp: _match.myMaxHp ?? 0,
          rightCurrentHp: _match.opponentCurrentHp ?? 0,
          rightMaxHp: _match.opponentMaxHp ?? 0,
          isLeftTurn: _match.isMyTurn,
          lastAttack: _pendingAttack,
          leftLabel: 'Você',
          rightLabel: 'Oponente',
          leftStatuses: _match.myActiveStatuses,
          rightStatuses: _match.opponentActiveStatuses,
          fieldEffects: _match.activeFieldEffectBadges,
        ),
      ),
```

- [ ] **Step 2: Rodar a suíte de testes de `MultiplayerBattleScreen` e confirmar que nada quebrou**

Run: `cd app && flutter test test/multiplayer_battle_screen_test.dart`
Expected: PASS, sem nenhuma mudança na contagem de testes existente.

- [ ] **Step 3: Rodar `flutter analyze` no app**

Run: `cd app && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add app/lib/ui/multiplayer_battle_screen.dart
git commit -m "$(cat <<'EOF'
Mostra badges de status/campo na cena de batalha do Multiplayer (Bloco 9)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 9: Suíte completa, verificação manual e documentação

**Files:**
- Modify: `DECISIONS.md`
- Modify: `TASKS.md`

**Interfaces:**
- Nenhuma — task de fechamento, sem código novo.

- [ ] **Step 1: Rodar a suíte completa do app**

Run: `cd app && flutter test`
Expected: todos os testes PASS (os existentes + os novos das Tasks 1-6).

- [ ] **Step 2: Rodar `flutter analyze` uma última vez no app**

Run: `cd app && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Verificar manualmente via `flutter run -d web-server`**

Reiniciar o preview com `preview_stop` + `preview_start` (nunca só recarregar), e confirmar:
- No Modo Treino, desbloquear Combustão ("Maestria da Brasa") e jogar Fogo sozinho — badge de Queimadura (🔥, com "2") aparece embaixo do HP do jogador atingido.
- Jogar Fogo+Vento — badge de campo (🌪️) aparece centralizado entre os dois painéis.
- Nenhum erro no console do navegador (`read_console_messages`).
- (Multiplayer real depende de duas sessões simultâneas — segue a mesma limitação já registrada nas DECISION-037/040 pra esta máquina; a suíte automatizada da Task 4 já cobre a resolução "eu"/"oponente".)

- [ ] **Step 4: Registrar DECISION-044 em `DECISIONS.md`**

Ler `DECISIONS.md`, localizar a última entrada (`DECISION-043`), e adicionar uma nova entrada `DECISION-044` logo depois, cobrindo:
- Bloco 9 (efeitos) — badges de status ativo por jogador e efeito de campo, substituindo o texto cru.
- Descoberta de que o backend já mandava `combatantStatuses` desde a DECISION-024 — nenhuma mudança de backend precisou entrar neste bloco, só o parse no cliente.
- Estilo de badge escolhido pelo usuário no companheiro visual (círculo colorido simples, não a família pixel art dos outros componentes).
- 11 ids de status cobertos desde já (data-driven), mesmo os 9 ainda inertes.

- [ ] **Step 5: Atualizar `TASKS.md`**

Ler `TASKS.md` e mover a entrada do Bloco 9 (efeitos) pra DONE, referenciando DECISION-044.

- [ ] **Step 6: Commit**

```bash
git add DECISIONS.md TASKS.md
git commit -m "$(cat <<'EOF'
Registra DECISION-044 e atualiza TASKS.md (badges de status/campo)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review

**Cobertura do spec:**
- `EffectBadgeView` → Task 1.
- Ícones/cores (`status_visuals.dart`, 11 status + 3 campo + fallbacks) → Task 2.
- Dados do Modo Treino → Task 3.
- Descoberta de que o backend já manda `combatantStatuses` (sem mudança de backend) + dados do Multiplayer → Task 4.
- `BattleSceneView` ganha os 3 campos → Task 5.
- Badges visuais (círculo colorido, número de turnos) no HUD → Task 6.
- Fiação em Treino/Multiplayer → Tasks 7 e 8.
- "Nenhum teste existente deveria quebrar" → confirmado a cada task (roda a suíte da tela/arquivo tocado) e na suíte completa (Task 9).
- Verificação manual via web-server → Task 9.
- Fora de escopo (animação, tooltip, ícone por combinação futura) → não implementado em nenhuma task, mencionado nos Global Constraints.

**Placeholder scan:** nenhum "TBD"/"depois"/passo sem código real — todo Step de código tem o trecho exato a escrever ou o arquivo reescrito por inteiro quando mais claro que um diff.

**Consistência de tipos:** `EffectBadgeView{id, remainingTurns}` usado identicamente em todas as tasks (2-8); `RemoteActiveStatus{effectId, turnsRemaining}` só na Task 4 (nome de campo diferente de propósito — espelha o JSON real do backend, `effectId` não `id`); `statusIcon`/`statusColor`/`fieldEffectIcon` com as mesmas assinaturas entre a Task 2 (onde nascem) e a Task 6 (onde são consumidos).
