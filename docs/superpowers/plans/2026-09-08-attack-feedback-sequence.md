# Sequência de Feedback de Ataque (Bloco 1) — Plano de Implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Substituir o dano instantâneo (barra de HP pulando + flash) por uma sequência visual real — preparação → efeito elemental → impacto → dano → estado — válida para qualquer combinação, no Modo Treino e no Multiplayer.

**Architecture:** Um novo `AttackEvent` (Game Domain, dado puro) descreve "o que aconteceu" num turno; cada tela monta esse evento a partir do que já sabe (elementos jogados, combinação disparada, dano, estados aplicados) e passa pro `BattleSceneWidget`/`BattleSceneGame` via `BattleSceneView.lastAttack`. Um novo `AttackSequencePlayer` (Flame `Component`, Game Presentation) toca a sequência com timers manuais (mesmo padrão do `BattleCharacterComponent` já existente), sem tocar em `battle_engine`/`backend` — o dano/HP/vitória continuam calculados exatamente como hoje, só a apresentação muda.

**Tech Stack:** Flutter + Dart, pacote `flame` (já dependência). Sem dependências novas.

**Spec:** [docs/superpowers/specs/2026-09-08-attack-feedback-sequence-design.md](../specs/2026-09-08-attack-feedback-sequence-design.md)

## Global Constraints

- R$ 0 de custo: nenhum asset novo, nenhuma chamada externa nova.
- `battle_engine` e `backend/src/battle-rules/` NÃO são tocados — puramente apresentação no app Flutter.
- Multiplayer: sem mudança de contrato do backend (`RemoteBattleState` continua igual) — a solução usa só dados já disponíveis no cliente (ver spec, seção "A limitação do Multiplayer").
- Consequência aceita: no Multiplayer, `appliedStatusNames` do `AttackEvent` fica sempre vazio (o cliente não recebe estados ativos por jogador do backend — mesma lacuna da DECISION-030) — o passo "Estado" da sequência só toca no Modo Treino.
- Cada task termina com `flutter analyze` e `flutter test` (dentro de `app/`) passando antes do commit.

---

## Task 1: `AttackEvent` (Game Domain)

**Files:**
- Create: `app/lib/game_domain/attack_event.dart`
- Test: `app/test/game_domain/attack_event_test.dart`

**Interfaces:**
- Produces: `class AttackEvent` com campos `sequenceId (int)`, `attackerIsLeft (bool)`, `elementIds (List<String>)`, `comboName (String?)`, `damage (int)`, `appliedStatusNames (List<String>)`. Consumida pelas Tasks 4, 7, 8, 9, 10, 11.

- [ ] **Step 1: Escrever o teste que falha**

```dart
// app/test/game_domain/attack_event_test.dart
import 'package:app/game_domain/attack_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('holds the values it was constructed with', () {
    const event = AttackEvent(
      sequenceId: 1,
      attackerIsLeft: true,
      elementIds: ['fire', 'wind'],
      comboName: 'Tempestade Ígnea',
      damage: 20,
      appliedStatusNames: ['Queimadura'],
    );

    expect(event.sequenceId, 1);
    expect(event.attackerIsLeft, isTrue);
    expect(event.elementIds, ['fire', 'wind']);
    expect(event.comboName, 'Tempestade Ígnea');
    expect(event.damage, 20);
    expect(event.appliedStatusNames, ['Queimadura']);
  });
}
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `flutter test test/game_domain/attack_event_test.dart` (dentro de `app/`)
Expected: FAIL — arquivo `attack_event.dart` não existe.

- [ ] **Step 3: Implementar**

```dart
// app/lib/game_domain/attack_event.dart

/// Descreve um ataque que já aconteceu no domínio (dano e efeitos já
/// aplicados) para a apresentação reencenar visualmente. Dado puro, sem
/// dependência de Flutter/Flame nem de `battle_engine` — mesmo espírito de
/// [BattleSceneView].
class AttackEvent {
  /// Identifica esta ocorrência de forma única — usado por
  /// `BattleSceneGame` para não tocar a mesma sequência duas vezes.
  final int sequenceId;

  final bool attackerIsLeft;

  /// Ids dos elementos jogados (ex: `['fire', 'wind']`) — a apresentação
  /// resolve símbolo/cor a partir disso, nunca embutidos aqui.
  final List<String> elementIds;

  final String? comboName;
  final int damage;
  final List<String> appliedStatusNames;

  const AttackEvent({
    required this.sequenceId,
    required this.attackerIsLeft,
    required this.elementIds,
    this.comboName,
    required this.damage,
    required this.appliedStatusNames,
  });
}
```

- [ ] **Step 4: Rodar e confirmar que passa**

Run: `flutter test test/game_domain/attack_event_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/lib/game_domain/attack_event.dart app/test/game_domain/attack_event_test.dart
git commit -m "Adiciona AttackEvent (dado puro do que aconteceu num ataque)"
```

---

## Task 2: `TrainingMatch.turnsPlayed`

**Files:**
- Modify: `app/lib/game_domain/training_match.dart`
- Test: `app/test/game_domain/training_match_test.dart`

**Interfaces:**
- Produces: `int get turnsPlayed` em `TrainingMatch` — conta jogadas bem-sucedidas (independente de terem causado dano). Consumida pela Task 10 como `sequenceId`.

- [ ] **Step 1: Escrever o teste que falha**

Adicionar ao final do `main()`:

```dart
  test('turnsPlayed counts successful plays regardless of damage', () {
    final match = TrainingMatch();
    expect(match.turnsPlayed, 0);

    match.playElementIds(['fire']); // sem dano, ainda conta
    expect(match.turnsPlayed, 1);

    match.playElementIds(['wind']);
    expect(match.turnsPlayed, 2);
  });
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `flutter test test/game_domain/training_match_test.dart`
Expected: FAIL — `turnsPlayed` não existe.

- [ ] **Step 3: Implementar**

Em `app/lib/game_domain/training_match.dart`, adicionar um campo e incrementá-lo em `playElementIds`:

```dart
  int _turnsPlayed = 0;

  int get turnsPlayed => _turnsPlayed;
```

(logo abaixo de `String? get lastTriggeredCombinationName => ...` ou em qualquer ponto entre os outros getters). Em `playElementIds`, incrementar só no
final do método (depois que tudo já teve sucesso — `elementIds` inválido
lança `ArgumentError` mais cedo, antes desse ponto, e não deve contar como
jogada):

```dart
    if (result.triggeredCombination != null) {
      _discoveryBook = _discoveryBook.withDiscovered(
        result.triggeredCombination!,
      );
    }
    _turnsPlayed++;
```

- [ ] **Step 4: Rodar e confirmar que passa**

Run: `flutter test test/game_domain/training_match_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/lib/game_domain/training_match.dart app/test/game_domain/training_match_test.dart
git commit -m "Adiciona TrainingMatch.turnsPlayed"
```

---

## Task 3: `CombinationOption.elementIds`

**Files:**
- Modify: `app/lib/game_domain/combination_catalog.dart`
- Test: `app/test/game_domain/combination_catalog_test.dart`

**Interfaces:**
- Produces: `CombinationOption` ganha `elementIds (List<String>)`. Consumida pela Task 7 (helper `detectOpponentAttack`) e pela Task 11 (`MultiplayerBattleScreen`).

- [ ] **Step 1: Ler o teste existente pra saber o padrão do arquivo**

Ler `app/test/game_domain/combination_catalog_test.dart` antes de editar (já existe — esta task só adiciona um teste, não recria o arquivo).

- [ ] **Step 2: Escrever o teste que falha**

Adicionar ao `main()` existente:

```dart
  test('byId exposes the element ids that make up the combination', () {
    const catalog = CombinationCatalog();
    final option = catalog.byId('ignited_storm');

    expect(option, isNotNull);
    expect(option!.elementIds, containsAll(['fire', 'wind']));
    expect(option.elementIds, hasLength(2));
  });
```

(`'ignited_storm'` é o `resultId` de Tempestade Ígnea — confirmar contra `defaultCombinationBook` em `packages/battle_engine/lib/src/default_combinations.dart` se o id mudou).

- [ ] **Step 3: Rodar e confirmar que falha**

Run: `flutter test test/game_domain/combination_catalog_test.dart`
Expected: FAIL — `elementIds` não existe em `CombinationOption`.

- [ ] **Step 4: Implementar**

Em `app/lib/game_domain/combination_catalog.dart`:

```dart
class CombinationOption {
  final String id;
  final String name;
  final String description;
  final List<String> elementIds;

  const CombinationOption({
    required this.id,
    required this.name,
    required this.description,
    required this.elementIds,
  });
}

class CombinationCatalog {
  const CombinationCatalog();

  CombinationOption? byId(String id) {
    for (final combination in defaultCombinationBook.combinations) {
      if (combination.resultId == id) {
        return CombinationOption(
          id: combination.resultId,
          name: combination.resultName,
          description: combination.description,
          elementIds: combination.elements.map((e) => e.id).toList(),
        );
      }
    }
    return null;
  }
}
```

- [ ] **Step 5: Rodar e confirmar que passa**

Run: `flutter test test/game_domain/combination_catalog_test.dart`
Expected: PASS

- [ ] **Step 6: `flutter analyze`**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add app/lib/game_domain/combination_catalog.dart app/test/game_domain/combination_catalog_test.dart
git commit -m "CombinationOption passa a expor os elementIds da combinação"
```

---

## Task 4: `BattleSceneView.lastAttack`

**Files:**
- Modify: `app/lib/game_domain/battle_scene_view.dart`
- Test: `app/test/game_domain/battle_scene_view_test.dart`

**Interfaces:**
- Consumes: `AttackEvent` (Task 1).
- Produces: `BattleSceneView` ganha `AttackEvent? lastAttack` (default `null` — telas antigas continuam compilando até serem atualizadas nas Tasks 10/11).

- [ ] **Step 1: Escrever o teste que falha**

Adicionar ao `main()` existente:

```dart
  test('lastAttack defaults to null and can be set', () {
    const withoutAttack = BattleSceneView(
      leftCurrentHp: 100, leftMaxHp: 100,
      rightCurrentHp: 100, rightMaxHp: 100,
      isLeftTurn: true,
    );
    expect(withoutAttack.lastAttack, isNull);

    const event = AttackEvent(
      sequenceId: 1, attackerIsLeft: true, elementIds: ['fire'],
      damage: 10, appliedStatusNames: [],
    );
    const withAttack = BattleSceneView(
      leftCurrentHp: 90, leftMaxHp: 100,
      rightCurrentHp: 100, rightMaxHp: 100,
      isLeftTurn: false,
      lastAttack: event,
    );
    expect(withAttack.lastAttack, same(event));
  });
```

Adicionar o import de `attack_event.dart` no topo do arquivo de teste.

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `flutter test test/game_domain/battle_scene_view_test.dart`
Expected: FAIL — `lastAttack` não existe.

- [ ] **Step 3: Implementar**

```dart
// app/lib/game_domain/battle_scene_view.dart
import 'attack_event.dart';

class BattleSceneView {
  final int leftCurrentHp;
  final int leftMaxHp;
  final int rightCurrentHp;
  final int rightMaxHp;
  final bool isLeftTurn;
  final AttackEvent? lastAttack;

  const BattleSceneView({
    required this.leftCurrentHp,
    required this.leftMaxHp,
    required this.rightCurrentHp,
    required this.rightMaxHp,
    required this.isLeftTurn,
    this.lastAttack,
  });
}
```

- [ ] **Step 4: Rodar e confirmar que passa**

Run: `flutter test test/game_domain/battle_scene_view_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/lib/game_domain/battle_scene_view.dart app/test/game_domain/battle_scene_view_test.dart
git commit -m "BattleSceneView ganha lastAttack"
```

---

## Task 5: `element_visuals.dart` (cor + símbolo por elemento)

**Files:**
- Create: `app/lib/game_presentation/element_visuals.dart`
- Test: `app/test/game_presentation/element_visuals_test.dart`

**Interfaces:**
- Produces: `Color elementColor(String elementId)`, `String elementSymbol(String elementId)`. Consumida pela Task 8 (`AttackSequencePlayer`).

- [ ] **Step 1: Escrever o teste que falha**

```dart
// app/test/game_presentation/element_visuals_test.dart
import 'package:app/game_presentation/element_visuals.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const knownElementIds = [
    'fire', 'water', 'wind', 'ice', 'nature',
    'lightning', 'earth', 'shadow', 'light', 'poison',
  ];

  test('every known element has a distinct color', () {
    final colors = knownElementIds.map(elementColor).toSet();
    expect(colors, hasLength(knownElementIds.length));
  });

  test('every known element resolves its real symbol', () {
    expect(elementSymbol('fire'), '🔥');
    expect(elementSymbol('water'), '💧');
  });

  test('an unknown element id falls back gracefully instead of throwing', () {
    expect(() => elementColor('unknown'), returnsNormally);
    expect(elementSymbol('unknown'), isNotEmpty);
  });
}
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `flutter test test/game_presentation/element_visuals_test.dart`
Expected: FAIL — arquivo não existe.

- [ ] **Step 3: Implementar**

```dart
// app/lib/game_presentation/element_visuals.dart
import 'package:flutter/material.dart' show Color;

import '../game_domain/element_catalog.dart';

const Map<String, Color> _elementColors = {
  'fire': Color(0xFFE85D3D),
  'water': Color(0xFF3D8FE8),
  'wind': Color(0xFF7FD1C4),
  'ice': Color(0xFF9EE8F5),
  'nature': Color(0xFF6FBF4F),
  'lightning': Color(0xFFF5D33D),
  'earth': Color(0xFF8A6A4B),
  'shadow': Color(0xFF4B4B5C),
  'light': Color(0xFFF5EFC8),
  'poison': Color(0xFF8B4FBF),
};

/// Cor de identidade de [elementId] — usada só no passo "Efeito elemental"
/// da sequência de ataque (ver
/// docs/superpowers/specs/2026-09-08-attack-feedback-sequence-design.md).
/// Cinza como fallback — nunca deveria ser atingido com um id real do
/// `ElementCatalog`, mas evita quebrar caso a lista de elementos mude.
Color elementColor(String elementId) =>
    _elementColors[elementId] ?? const Color(0xFF9E9E9E);

/// Símbolo (emoji) de [elementId], resolvido a partir do `ElementCatalog`
/// já existente — nenhuma duplicação de dado.
String elementSymbol(String elementId) {
  for (final element in const ElementCatalog().all()) {
    if (element.id == elementId) return element.symbol;
  }
  return '?';
}
```

- [ ] **Step 4: Rodar e confirmar que passa**

Run: `flutter test test/game_presentation/element_visuals_test.dart`
Expected: PASS

- [ ] **Step 5: `flutter analyze`**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add app/lib/game_presentation/element_visuals.dart app/test/game_presentation/element_visuals_test.dart
git commit -m "Adiciona element_visuals (cor + símbolo por elemento)"
```

---

## Task 6: `BattleCharacterComponent` — barra de HP interpolada + pulso de preparação

**Files:**
- Modify: `app/lib/game_presentation/battle_character_component.dart`
- Modify: `app/test/game_presentation/battle_character_component_test.dart`

**Interfaces:**
- Produces: `BattleCharacterComponent` ganha `bool get isPlayingPreparationPulse` e `void playPreparationPulse()`. `setHpFraction` passa a animar (não muda a assinatura). Consumida pela Task 8 (`AttackSequencePlayer` chama `playPreparationPulse()` no atacante).

- [ ] **Step 1: Escrever os testes que falham**

Adicionar ao `main()` existente de `battle_character_component_test.dart`:

```dart
    test('starts with no preparation pulse playing', () {
      final component = BattleCharacterComponent(
        side: BattleSide.left,
        position: Vector2(0, 0),
      );
      expect(component.isPlayingPreparationPulse, isFalse);
    });

    test('playPreparationPulse starts and then fades out over time', () {
      final component = BattleCharacterComponent(
        side: BattleSide.left,
        position: Vector2(0, 0),
      );

      component.playPreparationPulse();
      expect(component.isPlayingPreparationPulse, isTrue);

      component.update(0.5); // maior que a duração do pulso (0.15s)
      expect(component.isPlayingPreparationPulse, isFalse);
    });

    test('the displayed HP fraction chases the target instead of jumping',
        () {
      final component = BattleCharacterComponent(
        side: BattleSide.right,
        position: Vector2(0, 0),
      );

      component.setHpFraction(1.0);
      component.update(1.0); // deixa a barra assentar em 1.0 primeiro

      component.setHpFraction(0.2);
      component.update(0.05); // um passo pequeno: ainda não chegou

      final displayedAfterOneStep = component.debugDisplayedHpFraction;
      expect(displayedAfterOneStep, greaterThan(0.2));
      expect(displayedAfterOneStep, lessThan(1.0));

      component.update(1.0); // tempo de sobra: converge
      expect(component.debugDisplayedHpFraction, closeTo(0.2, 0.001));
    });
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `flutter test test/game_presentation/battle_character_component_test.dart`
Expected: FAIL — `isPlayingPreparationPulse`/`playPreparationPulse`/`debugDisplayedHpFraction` não existem.

- [ ] **Step 3: Implementar**

Em `app/lib/game_presentation/battle_character_component.dart`, substituir o campo único de HP por alvo+exibido, e adicionar o pulso de preparação:

```dart
  double _targetHpFraction = 1.0;
  double _displayedHpFraction = 1.0;
  bool _isActiveTurn = false;
  double _hitEffectRemaining = 0;
  double _prepPulseRemaining = 0;

  static const double _prepPulseDuration = 0.15;
  static const double _hpChaseSpeed = 2.5; // fração por segundo

  /// Exposto só para teste — a fração de HP realmente desenhada (persegue
  /// [_targetHpFraction] em vez de saltar direto pro valor novo).
  @visibleForTesting
  double get debugDisplayedHpFraction => _displayedHpFraction;

  bool get isPlayingPreparationPulse => _prepPulseRemaining > 0;

  void setHpFraction(double fraction) {
    _targetHpFraction = fraction.clamp(0.0, 1.0);
  }

  void playPreparationPulse() {
    _prepPulseRemaining = _prepPulseDuration;
  }
```

(mantém `setActiveTurn`/`playHitEffect`/`isPlayingHitEffect` como já estão). Adicionar o import de `package:flutter/foundation.dart show visibleForTesting` no topo (junto aos imports existentes).

Em `update(double dt)`, depois da lógica de shake já existente, avançar a barra e o pulso:

```dart
  @override
  void update(double dt) {
    super.update(dt);
    if (_hitEffectRemaining <= 0) {
      position.setFrom(_basePosition);
    } else {
      _hitEffectRemaining = (_hitEffectRemaining - dt).clamp(0, _hitEffectDuration);
      final progress = _hitEffectRemaining / _hitEffectDuration;
      final shakeX = math.sin(progress * math.pi * 6) * 4 * progress;
      position.setValues(_basePosition.x + shakeX, _basePosition.y);
    }

    if (_prepPulseRemaining > 0) {
      _prepPulseRemaining = (_prepPulseRemaining - dt).clamp(0, _prepPulseDuration);
    }

    if (_displayedHpFraction != _targetHpFraction) {
      final delta = _targetHpFraction - _displayedHpFraction;
      final step = _hpChaseSpeed * dt;
      _displayedHpFraction = delta.abs() <= step
          ? _targetHpFraction
          : _displayedHpFraction + step * delta.sign;
    }
  }
```

(isso substitui o corpo do `update` existente — a parte do shake muda de um `if...return` pra um `if/else` pra poder continuar executando o resto do método na mesma chamada).

Em `render`, trocar toda referência a `_hpFraction` por `_displayedHpFraction`, e envolver o desenho existente (corpo, cabeça, flash, contorno, barra) num pulso de escala:

```dart
  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final pulseScale = isPlayingPreparationPulse
        ? 1.0 + 0.12 * (_prepPulseRemaining / _prepPulseDuration)
        : 1.0;

    canvas.save();
    if (pulseScale != 1.0) {
      canvas.translate(size.x / 2, size.y);
      canvas.scale(pulseScale);
      canvas.translate(-size.x / 2, -size.y);
    }

    final bodyRect = Rect.fromLTWH(0, size.y * 0.25, size.x, size.y * 0.75);
    final bodyRRect = RRect.fromRectAndRadius(bodyRect, const Radius.circular(12));
    canvas.drawRRect(bodyRRect, Paint()..color = _bodyColor);
    canvas.drawCircle(
      Offset(size.x / 2, size.y * 0.15),
      size.x * 0.22,
      Paint()..color = _bodyColor,
    );

    if (isPlayingHitEffect) {
      final flashOpacity = (_hitEffectRemaining / _hitEffectDuration).clamp(0.0, 1.0);
      canvas.drawRRect(
        bodyRRect,
        Paint()..color = Colors.white.withValues(alpha: flashOpacity * 0.7),
      );
    }

    if (_isActiveTurn) {
      canvas.drawRRect(
        bodyRRect,
        Paint()
          ..color = const Color(0xFFFFD54F)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }

    const barWidth = 56.0;
    const barHeight = 8.0;
    final barLeft = (size.x - barWidth) / 2;
    const barTop = -18.0;
    canvas.drawRect(
      Rect.fromLTWH(barLeft, barTop, barWidth, barHeight),
      Paint()..color = const Color(0xFF2B2B2B),
    );
    canvas.drawRect(
      Rect.fromLTWH(barLeft, barTop, barWidth * _displayedHpFraction, barHeight),
      Paint()
        ..color = _displayedHpFraction > 0.3
            ? const Color(0xFF4CAF50)
            : const Color(0xFFE53935),
    );

    canvas.restore();
  }
```

- [ ] **Step 4: Rodar e confirmar que passa**

Run: `flutter test test/game_presentation/battle_character_component_test.dart`
Expected: PASS (7 testes no total)

- [ ] **Step 5: `flutter analyze`**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add app/lib/game_presentation/battle_character_component.dart app/test/game_presentation/battle_character_component_test.dart
git commit -m "BattleCharacterComponent: barra de HP interpolada + pulso de preparação"
```

---

## Task 7: `detectOpponentAttack` (helper puro, Game Domain)

**Files:**
- Create: `app/lib/game_domain/detect_opponent_attack.dart`
- Test: `app/test/game_domain/detect_opponent_attack_test.dart`

**Interfaces:**
- Consumes: `AttackEvent` (Task 1), `CombinationCatalog`/`CombinationOption.elementIds` (Task 3).
- Produces: `AttackEvent? detectOpponentAttack({required Set<String> previousFieldEffectIds, required Set<String> newFieldEffectIds, required int myHpBefore, required int myHpAfter, required int sequenceId})`. Consumida pela Task 11 (`MultiplayerBattleScreen`, jogada do oponente descoberta via poll).

Essa função isola a lógica descrita na spec ("A limitação do Multiplayer e como
ela é resolvida"): um novo item em `activeFieldEffectIds` identifica a
combinação disparada (e, por tabela, os elementos que a formam, via
`CombinationCatalog`); o dano é a queda de HP do jogador local. Pura — sem
Flutter/Flame, testável sem widget nenhum.

- [ ] **Step 1: Escrever o teste que falha**

```dart
// app/test/game_domain/detect_opponent_attack_test.dart
import 'package:app/game_domain/detect_opponent_attack.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('returns null when no new field effect appeared', () {
    final result = detectOpponentAttack(
      previousFieldEffectIds: {'ignited_storm'},
      newFieldEffectIds: {'ignited_storm'},
      myHpBefore: 100,
      myHpAfter: 100,
      sequenceId: 1,
    );
    expect(result, isNull);
  });

  test('returns null when a new effect appeared but my HP did not drop '
      '(defensive — should not happen per game rules, but never guess)', () {
    final result = detectOpponentAttack(
      previousFieldEffectIds: {},
      newFieldEffectIds: {'ignited_storm'},
      myHpBefore: 100,
      myHpAfter: 100,
      sequenceId: 1,
    );
    expect(result, isNull);
  });

  test('builds an AttackEvent from a newly-appeared known combination', () {
    final result = detectOpponentAttack(
      previousFieldEffectIds: {},
      newFieldEffectIds: {'ignited_storm'},
      myHpBefore: 100,
      myHpAfter: 80,
      sequenceId: 7,
    );

    expect(result, isNotNull);
    expect(result!.sequenceId, 7);
    expect(result.attackerIsLeft, isFalse); // o oponente é sempre "direita"
    expect(result.comboName, 'Tempestade Ígnea');
    expect(result.elementIds, containsAll(['fire', 'wind']));
    expect(result.damage, 20);
    expect(result.appliedStatusNames, isEmpty);
  });

  test('returns null for a newly-appeared id the catalog does not '
      'recognize (defensive)', () {
    final result = detectOpponentAttack(
      previousFieldEffectIds: {},
      newFieldEffectIds: {'unknown_effect'},
      myHpBefore: 100,
      myHpAfter: 80,
      sequenceId: 1,
    );
    expect(result, isNull);
  });
}
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `flutter test test/game_domain/detect_opponent_attack_test.dart`
Expected: FAIL — arquivo não existe.

- [ ] **Step 3: Implementar**

```dart
// app/lib/game_domain/detect_opponent_attack.dart
import 'attack_event.dart';
import 'combination_catalog.dart';

/// Deduz um [AttackEvent] pra jogada do oponente no Multiplayer, descoberta
/// via poll (o backend não manda quais elementos foram jogados — ver
/// docs/superpowers/specs/2026-09-08-attack-feedback-sequence-design.md).
/// Retorna `null` quando não há nada de novo pra encenar (nenhum efeito de
/// campo novo, ou o novo efeito não corresponde a uma queda de HP local —
/// defensivo, nunca deveria acontecer dado que só combinação causa dano).
AttackEvent? detectOpponentAttack({
  required Set<String> previousFieldEffectIds,
  required Set<String> newFieldEffectIds,
  required int myHpBefore,
  required int myHpAfter,
  required int sequenceId,
}) {
  final newlyAppeared = newFieldEffectIds.difference(previousFieldEffectIds);
  if (newlyAppeared.isEmpty) return null;

  final damage = myHpBefore - myHpAfter;
  if (damage <= 0) return null;

  final combo = const CombinationCatalog().byId(newlyAppeared.first);
  if (combo == null) return null;

  return AttackEvent(
    sequenceId: sequenceId,
    attackerIsLeft: false,
    elementIds: combo.elementIds,
    comboName: combo.name,
    damage: damage,
    appliedStatusNames: const [],
  );
}
```

- [ ] **Step 4: Rodar e confirmar que passa**

Run: `flutter test test/game_domain/detect_opponent_attack_test.dart`
Expected: PASS (4 testes)

- [ ] **Step 5: `flutter analyze`**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add app/lib/game_domain/detect_opponent_attack.dart app/test/game_domain/detect_opponent_attack_test.dart
git commit -m "Adiciona detectOpponentAttack (deduz ataque do oponente no Multiplayer)"
```

---

## Task 8: `AttackSequencePlayer` (Game Presentation)

**Files:**
- Create: `app/lib/game_presentation/attack_sequence_player.dart`
- Test: `app/test/game_presentation/attack_sequence_player_test.dart`

**Interfaces:**
- Consumes: `AttackEvent` (Task 1); `BattleCharacterComponent.playPreparationPulse()`/`playHitEffect()` (Tasks 6, e a já existente de antes); `elementColor`/`elementSymbol` (Task 5).
- Produces: `class AttackSequencePlayer extends Component` com construtor `AttackSequencePlayer({required AttackEvent event, required BattleCharacterComponent attacker, required BattleCharacterComponent target, required Vector2 attackerPosition, required Vector2 targetPosition})`, getter `bool get isFinished`. Consumida pela Task 9 (`BattleSceneGame`).

- [ ] **Step 1: Escrever os testes que falham**

```dart
// app/test/game_presentation/attack_sequence_player_test.dart
import 'package:app/game_domain/attack_event.dart';
import 'package:app/game_presentation/attack_sequence_player.dart';
import 'package:app/game_presentation/battle_character_component.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

AttackSequencePlayer _buildPlayer({List<String> statusNames = const []}) {
  final attacker = BattleCharacterComponent(
    side: BattleSide.left,
    position: Vector2(0, 0),
  );
  final target = BattleCharacterComponent(
    side: BattleSide.right,
    position: Vector2(200, 0),
  );
  return AttackSequencePlayer(
    event: AttackEvent(
      sequenceId: 1,
      attackerIsLeft: true,
      elementIds: const ['fire', 'wind'],
      comboName: 'Tempestade Ígnea',
      damage: 20,
      appliedStatusNames: statusNames,
    ),
    attacker: attacker,
    target: target,
    attackerPosition: Vector2(0, -40),
    targetPosition: Vector2(200, -40),
  );
}

void main() {
  test('starts unfinished and triggers the attacker preparation pulse right '
      'away', () {
    final player = _buildPlayer();
    expect(player.isFinished, isFalse);

    player.update(0.01);
    expect(player.attacker.isPlayingPreparationPulse, isTrue);
  });

  test('triggers the target hit effect once impact resolves', () {
    final player = _buildPlayer();
    // preparação (0.15) + efeito (0.2) + impacto (0.2) = 0.55, um pouco a
    // mais pra garantir que já cruzou pro passo de dano.
    player.update(0.56);
    expect(player.target.isPlayingHitEffect, isTrue);
  });

  test('finishes after the full duration when no status was applied', () {
    final player = _buildPlayer(statusNames: []);
    // preparação+efeito+impacto+dano = 0.15+0.2+0.2+0.4 = 0.95
    player.update(0.96);
    expect(player.isFinished, isTrue);
  });

  test('plays the extra state step when a status was applied, so it takes '
      'longer to finish', () {
    final player = _buildPlayer(statusNames: ['Queimadura']);
    player.update(0.96); // teria terminado sem o passo de estado
    expect(player.isFinished, isFalse);

    player.update(0.4); // 0.3s do passo de estado + folga
    expect(player.isFinished, isTrue);
  });

  test('a single large update() call advances through every step at once',
      () {
    final player = _buildPlayer();
    player.update(2.0); // bem mais que o total — não deve travar num passo
    expect(player.isFinished, isTrue);
  });
}
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `flutter test test/game_presentation/attack_sequence_player_test.dart`
Expected: FAIL — arquivo não existe.

- [ ] **Step 3: Implementar**

```dart
// app/lib/game_presentation/attack_sequence_player.dart
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../game_domain/attack_event.dart';
import 'battle_character_component.dart';
import 'element_visuals.dart';

enum _AttackStep { preparation, elementalEffect, impact, damage, stateApplied, done }

const _preparationDuration = 0.15;
const _elementalEffectDuration = 0.2;
const _impactDuration = 0.2;
const _damageDuration = 0.4;
const _stateDuration = 0.3;

/// Toca a sequência visual de um ataque (preparação → efeito elemental →
/// impacto → dano → estado) sobre um par de [BattleCharacterComponent] já
/// existentes na cena. Não decide regra de batalha nenhuma — só reencena
/// visualmente o que [event] diz que já aconteceu. Timer manual (mesmo
/// padrão de [BattleCharacterComponent]), sem o sistema `Effect` do Flame —
/// ver docs/superpowers/specs/2026-09-08-attack-feedback-sequence-design.md.
class AttackSequencePlayer extends Component {
  AttackSequencePlayer({
    required this.event,
    required this.attacker,
    required this.target,
    required Vector2 attackerPosition,
    required Vector2 targetPosition,
  })  : _attackerPosition = attackerPosition,
        _targetPosition = targetPosition;

  final AttackEvent event;
  final BattleCharacterComponent attacker;
  final BattleCharacterComponent target;
  final Vector2 _attackerPosition;
  final Vector2 _targetPosition;

  _AttackStep _step = _AttackStep.preparation;
  double _stepElapsed = 0;
  bool _preparationStarted = false;

  bool get isFinished => _step == _AttackStep.done;

  double get _stepDuration {
    switch (_step) {
      case _AttackStep.preparation:
        return _preparationDuration;
      case _AttackStep.elementalEffect:
        return _elementalEffectDuration;
      case _AttackStep.impact:
        return _impactDuration;
      case _AttackStep.damage:
        return _damageDuration;
      case _AttackStep.stateApplied:
        return _stateDuration;
      case _AttackStep.done:
        return 0;
    }
  }

  _AttackStep _nextStep(_AttackStep step) {
    switch (step) {
      case _AttackStep.preparation:
        return _AttackStep.elementalEffect;
      case _AttackStep.elementalEffect:
        return _AttackStep.impact;
      case _AttackStep.impact:
        return _AttackStep.damage;
      case _AttackStep.damage:
        return event.appliedStatusNames.isEmpty
            ? _AttackStep.done
            : _AttackStep.stateApplied;
      case _AttackStep.stateApplied:
        return _AttackStep.done;
      case _AttackStep.done:
        return _AttackStep.done;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    var remaining = dt;
    while (remaining > 0 && _step != _AttackStep.done) {
      if (_step == _AttackStep.preparation && !_preparationStarted) {
        _preparationStarted = true;
        attacker.playPreparationPulse();
      }

      final timeLeftInStep = _stepDuration - _stepElapsed;
      if (remaining < timeLeftInStep) {
        _stepElapsed += remaining;
        remaining = 0;
      } else {
        remaining -= timeLeftInStep;
        _stepElapsed = 0;
        final wasStep = _step;
        _step = _nextStep(_step);
        if (wasStep == _AttackStep.impact) {
          target.playHitEffect();
        }
      }
    }

    if (_step == _AttackStep.done && parent != null) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    switch (_step) {
      case _AttackStep.elementalEffect:
      case _AttackStep.impact:
        _renderElementalBurst(canvas);
        break;
      case _AttackStep.damage:
        _renderDamageNumber(canvas);
        break;
      case _AttackStep.stateApplied:
        _renderStateText(canvas);
        break;
      case _AttackStep.preparation:
      case _AttackStep.done:
        break;
    }
  }

  void _renderElementalBurst(Canvas canvas) {
    final progress = (_stepElapsed / _stepDuration).clamp(0.0, 1.0);
    final travel = _step == _AttackStep.impact ? progress : 0.0;
    final centerX =
        _attackerPosition.x + (_targetPosition.x - _attackerPosition.x) * travel;
    final centerY =
        _attackerPosition.y + (_targetPosition.y - _attackerPosition.y) * travel;
    final scale =
        _step == _AttackStep.elementalEffect ? progress.clamp(0.2, 1.0) : 1.0;

    final count = event.elementIds.length;
    const spacing = 30.0;
    final startX = centerX - spacing * (count - 1) / 2;

    for (var i = 0; i < count; i++) {
      final x = startX + spacing * i;
      final elementId = event.elementIds[i];
      final radius = 14.0 * scale;

      canvas.drawCircle(
        Offset(x, centerY),
        radius,
        Paint()..color = elementColor(elementId),
      );
      _drawText(canvas, elementSymbol(elementId), Offset(x, centerY),
          fontSize: 18 * scale);
    }
  }

  void _renderDamageNumber(Canvas canvas) {
    final progress = (_stepElapsed / _stepDuration).clamp(0.0, 1.0);
    final riseY = _targetPosition.y - 20 - (progress * 20);
    final opacity = (1.0 - progress).clamp(0.0, 1.0);

    _drawText(
      canvas,
      '-${event.damage}',
      Offset(_targetPosition.x, riseY),
      fontSize: 20,
      color: Color.fromRGBO(255, 82, 82, opacity),
      bold: true,
    );
  }

  void _renderStateText(Canvas canvas) {
    final progress = (_stepElapsed / _stepDuration).clamp(0.0, 1.0);
    final opacity = (1.0 - progress).clamp(0.0, 1.0);

    _drawText(
      canvas,
      event.appliedStatusNames.join(', '),
      Offset(_targetPosition.x, _targetPosition.y - 20),
      fontSize: 14,
      color: Color.fromRGBO(255, 255, 255, opacity),
    );
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset center, {
    double fontSize = 16,
    Color color = Colors.white,
    bool bold = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          color: color,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }
}
```

- [ ] **Step 4: Rodar e confirmar que passa**

Run: `flutter test test/game_presentation/attack_sequence_player_test.dart`
Expected: PASS (5 testes)

- [ ] **Step 5: `flutter analyze`**

Run: `flutter analyze`
Expected: `No issues found!` (se `Component` do Flame acusar algum método obrigatório faltando — não deveria, `Component` puro não exige `onLoad` — ajustar conforme o erro real do compilador, não adivinhar).

- [ ] **Step 6: Commit**

```bash
git add app/lib/game_presentation/attack_sequence_player.dart app/test/game_presentation/attack_sequence_player_test.dart
git commit -m "Adiciona AttackSequencePlayer (preparação/efeito/impacto/dano/estado)"
```

---

## Task 9: Ligar `AttackSequencePlayer` ao `BattleSceneGame`

**Files:**
- Modify: `app/lib/game_presentation/battle_scene_game.dart`
- Modify: `app/test/game_presentation/battle_scene_game_test.dart`

**Interfaces:**
- Consumes: `AttackSequencePlayer` (Task 8), `AttackEvent`/`BattleSceneView.lastAttack` (Tasks 1, 4).

- [ ] **Step 1: Escrever o teste que falha**

Adicionar ao `main()` existente de `battle_scene_game_test.dart` (dentro do grupo `BattleSceneGame.updateView` ou um novo grupo):

```dart
  group('BattleSceneGame attack sequence gating', () {
    test('the same sequenceId is not replayed on a second updateView call',
        () {
      final game = BattleSceneGame();
      const attack = AttackEvent(
        sequenceId: 5,
        attackerIsLeft: true,
        elementIds: ['fire'],
        damage: 10,
        appliedStatusNames: [],
      );

      // Só verifica que chamar duas vezes com o mesmo sequenceId não lança
      // — o comportamento fino (não duplicar o componente na árvore) é
      // coberto pela verificação manual (flutter run -d web-server), já
      // que testar a árvore de componentes exigiria montar o FlameGame de
      // verdade (ver decisão de escopo da Task 5 do bloco anterior).
      expect(
        () {
          game.updateView(const BattleSceneView(
            leftCurrentHp: 90, leftMaxHp: 100,
            rightCurrentHp: 100, rightMaxHp: 100,
            isLeftTurn: false, lastAttack: attack,
          ));
          game.updateView(const BattleSceneView(
            leftCurrentHp: 90, leftMaxHp: 100,
            rightCurrentHp: 100, rightMaxHp: 100,
            isLeftTurn: false, lastAttack: attack,
          ));
        },
        returnsNormally,
      );
    });
  });
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `flutter test test/game_presentation/battle_scene_game_test.dart`
Expected: FAIL — `BattleSceneView` não tem `lastAttack` neste ponto? Não, já tem (Task 4). Deve compilar e passar até aqui sem mudança nenhuma em `battle_scene_game.dart` — **este teste sozinho não falha** porque `updateView` já tolera `lastAttack` sendo ignorado. É esperado: o valor desta task está na Step 3 (comportamento real) e na verificação manual, não neste teste automatizado — ele serve de guarda de regressão (não lançar exceção), não de prova da sequência tocando. Prosseguir para a implementação mesmo assim.

- [ ] **Step 3: Implementar**

Em `app/lib/game_presentation/battle_scene_game.dart`, adicionar os imports e o estado novo:

```dart
import 'attack_sequence_player.dart';
```

```dart
class BattleSceneGame extends FlameGame {
  BattleCharacterComponent? _left;
  BattleCharacterComponent? _right;

  int? _lastLeftHp;
  int? _lastRightHp;
  int? _lastPlayedSequenceId;
  AttackSequencePlayer? _activeSequence;
  BattleSceneView? _pendingView;
```

Substituir o corpo de `_applyView`:

```dart
  void _applyView(BattleSceneView view) {
    final left = _left!;
    final right = _right!;

    left.setHpFraction(view.leftMaxHp == 0 ? 0 : view.leftCurrentHp / view.leftMaxHp);
    right.setHpFraction(view.rightMaxHp == 0 ? 0 : view.rightCurrentHp / view.rightMaxHp);
    left.setActiveTurn(view.isLeftTurn);
    right.setActiveTurn(!view.isLeftTurn);

    final attack = view.lastAttack;
    if (attack != null && attack.sequenceId != _lastPlayedSequenceId) {
      _lastPlayedSequenceId = attack.sequenceId;
      _playAttackSequence(attack);
    } else if (didTakeDamage(previousHp: _lastLeftHp, currentHp: view.leftCurrentHp) ||
        didTakeDamage(previousHp: _lastRightHp, currentHp: view.rightCurrentHp)) {
      // Fallback defensivo: HP caiu mas nenhum AttackEvent chegou (não
      // deveria acontecer — só combinação causa dano, e toda combinação
      // vira AttackEvent nas telas). Mantém pelo menos o flash simples de
      // antes em vez de dano silencioso.
      if (didTakeDamage(previousHp: _lastLeftHp, currentHp: view.leftCurrentHp)) {
        left.playHitEffect();
      }
      if (didTakeDamage(previousHp: _lastRightHp, currentHp: view.rightCurrentHp)) {
        right.playHitEffect();
      }
    }

    _lastLeftHp = view.leftCurrentHp;
    _lastRightHp = view.rightCurrentHp;
  }

  void _playAttackSequence(AttackEvent event) {
    final left = _left!;
    final right = _right!;
    final attacker = event.attackerIsLeft ? left : right;
    final target = event.attackerIsLeft ? right : left;

    _activeSequence?.removeFromParent();
    final sequence = AttackSequencePlayer(
      event: event,
      attacker: attacker,
      target: target,
      attackerPosition: attacker.position - Vector2(0, 40),
      targetPosition: target.position - Vector2(0, 40),
    );
    _activeSequence = sequence;
    add(sequence);
  }
```

Adicionar o import de `AttackEvent` (`../game_domain/attack_event.dart`) — necessário pra assinatura de `_playAttackSequence`.

- [ ] **Step 4: Rodar e confirmar que passa**

Run: `flutter test test/game_presentation/battle_scene_game_test.dart`
Expected: PASS (todos os testes, incluindo os já existentes do bloco anterior)

- [ ] **Step 5: `flutter analyze`**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add app/lib/game_presentation/battle_scene_game.dart app/test/game_presentation/battle_scene_game_test.dart
git commit -m "BattleSceneGame dispara AttackSequencePlayer a partir de lastAttack"
```

---

## Task 10: Ligar ao `TrainingScreen`

**Files:**
- Modify: `app/lib/ui/training_screen.dart`
- Test: `app/test/training_screen_test.dart`

**Interfaces:**
- Consumes: `AttackEvent` (Task 1), `TrainingMatch.turnsPlayed` (Task 2).

- [ ] **Step 1: Adicionar o import**

```dart
import '../game_domain/attack_event.dart';
```

- [ ] **Step 2: Capturar o evento de ataque em `_playTurn`**

Adicionar um campo de estado e recalcular `_playTurn`:

```dart
class _TrainingScreenState extends State<TrainingScreen> {
  late TrainingMatch _match = widget._initialMatch ?? TrainingMatch();
  final Set<String> _selectedIds = {};
  String? _error;
  AttackEvent? _pendingAttack;
```

```dart
  void _playTurn() {
    setState(() {
      _error = null;
      final playedElementIds = _selectedIds.toList();
      final wasPlayerATurn = _match.isPlayerATurn;
      final hpABefore = _match.playerACurrentHp;
      final hpBBefore = _match.playerBCurrentHp;
      try {
        _match.playElementIds(playedElementIds);
        _selectedIds.clear();

        final triggered = _match.lastTriggeredCombinationName != null;
        final appliedStatus = _match.lastAppliedStatusNames;
        if (triggered || appliedStatus.isNotEmpty) {
          final damage = wasPlayerATurn
              ? hpBBefore - _match.playerBCurrentHp
              : hpABefore - _match.playerACurrentHp;
          _pendingAttack = AttackEvent(
            sequenceId: _match.turnsPlayed,
            attackerIsLeft: wasPlayerATurn,
            elementIds: playedElementIds,
            comboName: _match.lastTriggeredCombinationName,
            damage: damage,
            appliedStatusNames: appliedStatus,
          );
        }
      } on ArgumentError {
        _error = 'Jogada inválida.';
      }
    });
  }
```

- [ ] **Step 3: Passar `_pendingAttack` pro `BattleSceneView`**

Localizar o `BattleSceneWidget` já adicionado (Task 7 do bloco anterior) e acrescentar `lastAttack`:

```dart
            BattleSceneWidget(
              view: BattleSceneView(
                leftCurrentHp: _match.playerACurrentHp,
                leftMaxHp: _match.playerAMaxHp,
                rightCurrentHp: _match.playerBCurrentHp,
                rightMaxHp: _match.playerBMaxHp,
                isLeftTurn: _match.isPlayerATurn,
                lastAttack: _pendingAttack,
              ),
            ),
```

- [ ] **Step 4: Rodar os testes de `TrainingScreen`**

Run: `flutter test test/training_screen_test.dart`
Expected: PASS — os testes existentes não verificam a sequência visual (só texto de HP/combinação, que continua vindo do domínio, inalterado). Se algum `tester.pump()` não for suficiente pra estabilizar o widget (por causa do novo componente no Flame), ajustar somando `tester.pump(const Duration(milliseconds: 400))` no mesmo padrão já usado nesse arquivo — rodar e observar a falha real antes de decidir o ajuste, não adivinhar.

- [ ] **Step 5: `flutter analyze`**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add app/lib/ui/training_screen.dart app/test/training_screen_test.dart
git commit -m "Liga a sequência de feedback de ataque ao Modo Treino"
```

---

## Task 11: Ligar ao `MultiplayerBattleScreen`

**Files:**
- Modify: `app/lib/ui/multiplayer_battle_screen.dart`
- Test: `app/test/multiplayer_battle_screen_test.dart`

**Interfaces:**
- Consumes: `AttackEvent` (Task 1), `detectOpponentAttack` (Task 7), `CombinationCatalog.elementIds` (Task 3).

`appliedStatusNames` fica sempre `const []` nos dois casos (própria jogada e
jogada do oponente) — o Multiplayer não recebe estados ativos por jogador do
backend (lacuna já conhecida, DECISION-030); o passo "Estado" da sequência
simplesmente não toca aqui.

- [ ] **Step 1: Adicionar os imports**

```dart
import '../game_domain/attack_event.dart';
import '../game_domain/detect_opponent_attack.dart';
```

- [ ] **Step 2: Estado novo pra rastrear sequência e efeitos de campo já vistos**

```dart
class _MultiplayerBattleScreenState extends State<MultiplayerBattleScreen> {
  final Set<String> _selectedIds = {};
  Timer? _pollTimer;
  String? _error;
  bool _startingRematch = false;
  AttackEvent? _pendingAttack;
  int _attackSequenceCounter = 0;
  Set<String> _previousFieldEffectIds = {};
```

Em `initState`, depois de iniciar o `_pollTimer` (a ordem não importa, mas
manter perto pra ficar claro que é parte da inicialização):

```dart
  @override
  void initState() {
    super.initState();
    _previousFieldEffectIds = _match.activeFieldEffectIds.toSet();
    _pollTimer = Timer.periodic(widget._pollInterval, (_) => _poll());
  }
```

- [ ] **Step 3: Detectar a jogada do oponente em `_poll`**

```dart
  Future<void> _poll() async {
    if (_match.isFinished) {
      _pollTimer?.cancel();
      return;
    }
    final myHpBefore = _match.myCurrentHp;
    final previousFieldEffectIds = _previousFieldEffectIds;
    await _match.refresh();
    if (mounted) {
      setState(() {
        final newFieldEffectIds = _match.activeFieldEffectIds.toSet();
        _previousFieldEffectIds = newFieldEffectIds;

        if (myHpBefore != null) {
          _attackSequenceCounter++;
          final detected = detectOpponentAttack(
            previousFieldEffectIds: previousFieldEffectIds,
            newFieldEffectIds: newFieldEffectIds,
            myHpBefore: myHpBefore,
            myHpAfter: _match.myCurrentHp ?? myHpBefore,
            sequenceId: _attackSequenceCounter,
          );
          if (detected != null) {
            _pendingAttack = detected;
          }
        }
      });
    }
  }
```

- [ ] **Step 4: Capturar a própria jogada em `_playTurn`**

```dart
  Future<void> _playTurn() async {
    setState(() => _error = null);
    final playedElementIds = _selectedIds.toList();
    final opponentHpBefore = _match.opponentCurrentHp;
    try {
      await _match.playElementIds(playedElementIds);
      setState(() {
        _selectedIds.clear();
        final triggeredId = _match.lastTriggeredCombinationId;
        if (triggeredId != null && opponentHpBefore != null) {
          _attackSequenceCounter++;
          final damage = opponentHpBefore - (_match.opponentCurrentHp ?? opponentHpBefore);
          final combo = const CombinationCatalog().byId(triggeredId);
          _pendingAttack = AttackEvent(
            sequenceId: _attackSequenceCounter,
            attackerIsLeft: true,
            elementIds: playedElementIds,
            comboName: combo?.name,
            damage: damage,
            appliedStatusNames: const [],
          );
        }
        _previousFieldEffectIds = _match.activeFieldEffectIds.toSet();
      });
    } catch (_) {
      setState(() => _error = _match.lastError ?? 'Jogada inválida.');
    }
  }
```

- [ ] **Step 5: Passar `_pendingAttack` pro `BattleSceneView`**

Em `_buildBattle`, no `BattleSceneWidget` já existente (Task 8 do bloco
anterior):

```dart
      BattleSceneWidget(
        view: BattleSceneView(
          leftCurrentHp: _match.myCurrentHp ?? 0,
          leftMaxHp: _match.myMaxHp ?? 0,
          rightCurrentHp: _match.opponentCurrentHp ?? 0,
          rightMaxHp: _match.opponentMaxHp ?? 0,
          isLeftTurn: _match.isMyTurn,
          lastAttack: _pendingAttack,
        ),
      ),
```

- [ ] **Step 6: Rodar os testes de `MultiplayerBattleScreen`**

Run: `flutter test test/multiplayer_battle_screen_test.dart`
Expected: PASS — nenhum teste existente verifica a sequência visual
diretamente; o teste que joga um turno (`shows HP/turn for an in-progress
match and plays a combo turn`) continua validando texto/HP, que não muda de
comportamento.

- [ ] **Step 7: `flutter analyze`**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add app/lib/ui/multiplayer_battle_screen.dart app/test/multiplayer_battle_screen_test.dart
git commit -m "Liga a sequência de feedback de ataque ao Multiplayer"
```

---

## Task 12: Verificação manual, `DECISIONS.md` e `TASKS.md`

**Files:**
- Modify: `DECISIONS.md`
- Modify: `TASKS.md`

- [ ] **Step 1: Suíte completa**

Run: `flutter test` (dentro de `app/`)
Expected: PASS em todos os testes (contagem deve ser a soma dos testes
anteriores + os novos desta tarefa).

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 2: Rodar o app no Chrome e observar a sequência de verdade**

```bash
cd app
flutter run -d web-server --web-port 5000
```

No Modo Treino: jogar Fogo+Vento (Tempestade Ígnea) e confirmar visualmente
os 5 passos (pulso no atacante, símbolos coloridos aparecendo, viajando até
o alvo, número de dano subindo, barra de HP animando em vez de saltar).
Jogar uma combinação que aplique estado (ex.: depois de desbloquear
Maestria da Brasa, Fogo sozinho) e confirmar que o texto do estado aparece
antes da barra assentar. No Multiplayer: repetir com duas abas/sessões
(`ana` cria, `beto` entra), jogando dos dois lados — confirmar que a
sequência toca tanto pra jogada própria (elementos certos) quanto pra
jogada do oponente descoberta via poll (nome da combinação certo, sem
esperar mais que o intervalo de poll configurado).

- [ ] **Step 3: Registrar a decisão em `DECISIONS.md`**

Adicionar ao final de `DECISIONS.md` (número de decisão seguinte ao último
existente no arquivo no momento desta task — confirmar o número real antes
de escrever, não assumir):

```markdown

## DECISION-0XX
Data: 2026-09-08
Decisão: sequência de feedback visual de ataque (Bloco 1 da nova direção de
produto — ver CLAUDE.md, seção "Direção de produto (game feel)") — dano
instantâneo vira preparação→efeito elemental→impacto→dano→estado, pra
qualquer combinação, no Modo Treino e no Multiplayer.
Passos: novo `AttackEvent` (Game Domain, dado puro) descreve o que
aconteceu num turno; cada tela monta esse evento a partir do que já sabia
(elementos jogados, combinação, dano, estados). Novo
`AttackSequencePlayer` (Flame `Component`) toca a sequência com timer
manual (mesmo padrão do `BattleCharacterComponent`), sem o sistema
`Effect` do Flame. Identidade visual mínima: símbolo já existente de cada
elemento (`ElementCatalog`) mais uma cor nova por elemento — sem asset
novo. `BattleCharacterComponent` ganhou barra de HP interpolada (persegue
o valor novo em vez de saltar) e um pulso de escala pro passo de
preparação.
No Multiplayer, o backend não manda quais elementos o oponente jogou — a
jogada dele é deduzida (`detectOpponentAttack`) comparando os efeitos de
campo ativos antes/depois de cada poll: um efeito novo identifica a
combinação, e por tabela os elementos que a formam
(`CombinationCatalog.elementIds`, novo), sem mudar o contrato do backend.
Motivo: primeiro bloco da nova direção de produto (game feel) — o usuário
pediu blocos pequenos e completos, priorizando a batalha (o "coração do
jogo") antes de identidade visual ampla, áudio, etc.
Consequência (lacuna conhecida, não esquecida): no Multiplayer, o passo de
"Estado" da sequência nunca toca — o cliente não recebe estados ativos por
jogador do backend (mesma lacuna da DECISION-030). Sem crítico (não existe
no jogo), sem projétil com física de verdade, sem ícone de status
persistente entre turnos — tudo já fora de escopo desde a spec.
Testes: suíte completa do app (`flutter test`) e `flutter analyze`
passando depois da mudança. Verificado de ponta a ponta de verdade via
`flutter run -d web-server`: sequência completa jogando no Modo Treino
(incluindo o passo de estado) e no Multiplayer, dos dois lados (jogada
própria e jogada do oponente descoberta via poll).
```

- [ ] **Step 4: Atualizar `TASKS.md`**

Na seção `# DONE`, adicionar ao final:

```
- Sequência de feedback visual de ataque (Bloco 1 da direção de produto):
  preparação→efeito→impacto→dano→estado pra qualquer combinação, Modo
  Treino e Multiplayer, sem mudar battle_engine/backend (DECISION-0XX)
```

(usar o número real da decisão registrada no Step 3).

- [ ] **Step 5: Commit**

```bash
git add DECISIONS.md TASKS.md
git commit -m "Registra decisão e atualiza TASKS.md (sequência de feedback de ataque)"
```

---

## Self-Review (feito ao escrever este plano)

- **Cobertura do spec:** "Modelo de dados" → Tasks 1, 3, 4; "sequenceId — de
  onde vem" → Tasks 2, 10, 11; "A limitação do Multiplayer" →
  Tasks 3, 7, 11; "Identidade visual mínima" → Task 5; "AttackSequencePlayer"
  → Task 8; "BattleCharacterComponent (alterado)" → Task 6; "Integração nas
  telas" → Tasks 10, 11; "Testes esperados" e "Verificação manual" →
  cobertos em cada task + Task 12. "O que NÃO está neste bloco" respeitado —
  nenhuma task toca `battle_engine`, `backend/`, adiciona crítico, ícone de
  status persistente ou áudio.
- **Placeholders:** nenhum "TBD"/"implementar depois" — todo step tem
  código completo ou comando exato. A única ressalva textual (Task 9, Step
  2) explica por que aquele teste específico não falha sozinho antes da
  implementação — não é um placeholder, é uma nota honesta sobre os limites
  do que dá pra automatizar sem `flame_test` (mesma decisão de escopo já
  tomada no bloco anterior).
- **Consistência de tipos:** `AttackEvent` (Task 1) usado com os mesmos 6
  campos em `BattleSceneView` (Task 4), `AttackSequencePlayer` (Task 8),
  `detectOpponentAttack` (Task 7) e nas duas telas (Tasks 10, 11).
  `CombinationOption.elementIds` (Task 3) é exatamente o que
  `detectOpponentAttack` (Task 7) e `MultiplayerBattleScreen` (Task 11)
  esperam. `BattleCharacterComponent.playPreparationPulse()`/
  `isPlayingPreparationPulse` (Task 6) usados com esses nomes exatos em
  `AttackSequencePlayer` (Task 8).
- **Achado durante o planejamento:** o `update(dt)` de
  `AttackSequencePlayer` precisa consumir múltiplas transições de passo
  numa única chamada (loop `while`, não um `if` só) — necessário tanto pro
  game loop de verdade (não travar num frame lento) quanto pros testes
  (que chamam `update()` com valores grandes de uma vez, mesmo padrão já
  usado em `BattleCharacterComponent`). Já implementado assim na Task 8,
  não é um risco pendente.
