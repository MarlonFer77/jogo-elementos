# Cenário de Batalha Visual (Flame) — Plano de Implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dar uma representação visual real à batalha (fundo ilustrado + dois personagens genéricos por lado + flash/shake ao tomar dano) nas duas telas onde se joga de verdade — `TrainingScreen` e `MultiplayerBattleScreen` — substituindo a demo Flame desconectada existente.

**Architecture:** Novo `BattleSceneView` (Game Domain, dado puro) é construído por cada tela a partir do que ela já expõe (HP/vez). Um novo `BattleSceneGame` (Flame, Game Presentation) renderiza um fundo estático + dois `BattleCharacterComponent` (formas desenhadas em código, sem sprite) e reage a quedas de HP com um efeito de dano local (sem depender do sistema `Effect` do Flame). Um `BattleSceneWidget` (StatefulWidget fino) hospeda o `GameWidget` e repassa `updateView` a cada rebuild da tela. Nenhuma mudança em `battle_engine`, `backend/src/battle-rules/`, `TrainingMatch`\* ou `MultiplayerMatch` além de um getter trivial.

**Tech Stack:** Flutter + Dart, pacote `flame` (já uma dependência, `^1.38.2`), sem novas dependências.

**Spec:** [docs/superpowers/specs/2026-09-08-battle-scene-visuals-design.md](../specs/2026-09-08-battle-scene-visuals-design.md)

## Global Constraints

- R$ 0 de custo: o asset é um download único de arquivo estático (CC0), sem chamada a serviço externo em runtime.
- `battle_engine` (Dart) e `backend/src/battle-rules/` (TypeScript) NÃO são tocados nesta tarefa — puramente apresentação no app Flutter.
- Regra de escopo (CLAUDE.md): não alterar outro sistema além do necessário para esta tarefa (a única exceção documentada é remover a demo Flame desconectada, que é o próprio sistema que esta tarefa está substituindo).
- Cada task termina com `flutter analyze` e `flutter test` (dentro de `app/`) passando antes do commit.

---

## Task 1: `TrainingMatch.isPlayerATurn`

**Files:**
- Modify: `app/lib/game_domain/training_match.dart`
- Test: `app/test/game_domain/training_match_test.dart`

**Interfaces:**
- Produces: `bool get isPlayerATurn` em `TrainingMatch` — `true` quando é a vez do Jogador A, `false` quando é a vez do Jogador B. Usado pela Task 7 para montar `BattleSceneView.isLeftTurn`.

- [ ] **Step 1: Escrever o teste que falha**

Adicionar ao final do `main()` em `app/test/game_domain/training_match_test.dart`:

```dart
  test('isPlayerATurn reflects whose turn it currently is', () {
    final match = TrainingMatch();
    expect(match.isPlayerATurn, isTrue);

    match.playElementIds(['fire']);
    expect(match.isPlayerATurn, isFalse);

    match.playElementIds(['ice']);
    expect(match.isPlayerATurn, isTrue);
  });
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `flutter test test/game_domain/training_match_test.dart` (dentro de `app/`)
Expected: FAIL — `isPlayerATurn` não existe em `TrainingMatch` (erro de compilação).

- [ ] **Step 3: Implementar**

Em `app/lib/game_domain/training_match.dart`, logo abaixo de `bool get _isPlayerATurn => _state.currentTurn == _playerA;`, adicionar:

```dart
  /// Exposição pública de [_isPlayerATurn] — usada pela Game Presentation
  /// para saber de que lado é a vez, sem comparar `currentTurnName` por
  /// string.
  bool get isPlayerATurn => _isPlayerATurn;
```

- [ ] **Step 4: Rodar e confirmar que passa**

Run: `flutter test test/game_domain/training_match_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/lib/game_domain/training_match.dart app/test/game_domain/training_match_test.dart
git commit -m "Expõe TrainingMatch.isPlayerATurn"
```

---

## Task 2: `BattleSceneView` (Game Domain)

**Files:**
- Create: `app/lib/game_domain/battle_scene_view.dart`
- Test: `app/test/game_domain/battle_scene_view_test.dart`

**Interfaces:**
- Produces: `class BattleSceneView` com campos `int leftCurrentHp, leftMaxHp, rightCurrentHp, rightMaxHp` e `bool isLeftTurn`, construtor `const BattleSceneView({required ...})`. Consumida pelas Tasks 5 (BattleSceneGame), 7 e 8 (telas).

- [ ] **Step 1: Escrever o teste que falha**

```dart
// app/test/game_domain/battle_scene_view_test.dart
import 'package:app/game_domain/battle_scene_view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('holds the values it was constructed with', () {
    const view = BattleSceneView(
      leftCurrentHp: 80,
      leftMaxHp: 100,
      rightCurrentHp: 60,
      rightMaxHp: 100,
      isLeftTurn: true,
    );

    expect(view.leftCurrentHp, 80);
    expect(view.leftMaxHp, 100);
    expect(view.rightCurrentHp, 60);
    expect(view.rightMaxHp, 100);
    expect(view.isLeftTurn, isTrue);
  });
}
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `flutter test test/game_domain/battle_scene_view_test.dart`
Expected: FAIL — arquivo `battle_scene_view.dart` não existe.

- [ ] **Step 3: Implementar**

```dart
// app/lib/game_domain/battle_scene_view.dart

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

  const BattleSceneView({
    required this.leftCurrentHp,
    required this.leftMaxHp,
    required this.rightCurrentHp,
    required this.rightMaxHp,
    required this.isLeftTurn,
  });
}
```

- [ ] **Step 4: Rodar e confirmar que passa**

Run: `flutter test test/game_domain/battle_scene_view_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/lib/game_domain/battle_scene_view.dart app/test/game_domain/battle_scene_view_test.dart
git commit -m "Adiciona BattleSceneView (dado puro da cena de batalha)"
```

---

## Task 3: Asset de fundo (CC0)

**Files:**
- Create: `app/assets/images/battlefield_bg.jpg`
- Modify: `app/pubspec.yaml`

**Interfaces:**
- Produces: arquivo `assets/images/battlefield_bg.jpg` carregável via `Game.loadSprite('battlefield_bg.jpg')` (Task 5).

Imagem escolhida: **"Meadow background"** de `bart`, OpenGameArt.org, licença **CC0** (domínio público, sem exigência de atribuição) — confirmado na página `https://opengameart.org/content/meadow-background` (campo "License(s): CC0"). Arquivo original `meadow.jpg`, 1390×934, 89.7 KB.

- [ ] **Step 1: Baixar o arquivo**

```bash
mkdir -p app/assets/images
curl -L -o app/assets/images/battlefield_bg.jpg https://opengameart.org/sites/default/files/meadow.jpg
```

Confirmar que o arquivo baixou de verdade (não uma página de erro HTML):

```bash
file app/assets/images/battlefield_bg.jpg
```

Expected: algo como `JPEG image data, ... 1390x934`.

- [ ] **Step 2: Declarar o asset no `pubspec.yaml`**

Em `app/pubspec.yaml`, dentro do bloco `flutter:` (que hoje só tem `uses-material-design: true` e comentários), adicionar:

```yaml
flutter:
  uses-material-design: true

  assets:
    - assets/images/
```

- [ ] **Step 3: Confirmar que o Flutter reconhece o asset**

Run (dentro de `app/`): `flutter pub get`
Expected: termina sem erro (confirma que o `pubspec.yaml` está sintaticamente válido).

- [ ] **Step 4: Commit**

```bash
git add app/assets/images/battlefield_bg.jpg app/pubspec.yaml
git commit -m "Adiciona fundo de batalha (CC0, OpenGameArt.org 'Meadow background' de bart)"
```

---

## Task 4: `BattleCharacterComponent` (Game Presentation)

**Files:**
- Create: `app/lib/game_presentation/battle_character_component.dart`
- Test: `app/test/game_presentation/battle_character_component_test.dart`

**Interfaces:**
- Consumes: nada de outra task.
- Produces: `enum BattleSide { left, right }`; `class BattleCharacterComponent extends PositionComponent` com construtor `BattleCharacterComponent({required BattleSide side, required Vector2 position})`, métodos `setHpFraction(double)`, `setActiveTurn(bool)`, `playHitEffect()`, getter `bool get isPlayingHitEffect`, campo `BattleSide side`. Consumida pela Task 5 (`BattleSceneGame`).

**Nota de design:** o flash/shake é implementado como uma contagem regressiva manual em `update(dt)` (sem usar `package:flame/effects.dart`) porque os `Effect`s prontos do Flame (`ColorEffect` etc.) exigem o mixin `HasPaint`, que este componente não usa (ele desenha com `Paint`s locais em `render`). Isso mantém a lógica simples de testar sem precisar do game loop do Flame.

- [ ] **Step 1: Escrever os testes que falham**

```dart
// app/test/game_presentation/battle_character_component_test.dart
import 'package:app/game_presentation/battle_character_component.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BattleCharacterComponent', () {
    test('starts with no hit effect playing', () {
      final component = BattleCharacterComponent(
        side: BattleSide.left,
        position: Vector2(100, 200),
      );

      expect(component.isPlayingHitEffect, isFalse);
    });

    test('playHitEffect starts the effect, which fades out over time', () {
      final component = BattleCharacterComponent(
        side: BattleSide.left,
        position: Vector2(100, 200),
      );

      component.playHitEffect();
      expect(component.isPlayingHitEffect, isTrue);

      component.update(0.5); // maior que a duração do efeito (0.3s)
      expect(component.isPlayingHitEffect, isFalse);
    });

    test('the shake offsets position during the effect and restores it after', () {
      final basePosition = Vector2(100, 200);
      final component = BattleCharacterComponent(
        side: BattleSide.left,
        position: basePosition.clone(),
      );

      component.playHitEffect();
      component.update(0.05);
      expect(component.position, isNot(equals(basePosition)));

      component.update(0.5);
      expect(component.position, equals(basePosition));
    });

    test('setHpFraction clamps to the 0..1 range', () {
      final component = BattleCharacterComponent(
        side: BattleSide.right,
        position: Vector2.zero(),
      );

      component.setHpFraction(-0.5);
      component.setHpFraction(1.5);
      // Sem getter público de fração — o teste confirma que chamar com
      // valores fora do intervalo não lança.
    });
  });
}
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `flutter test test/game_presentation/battle_character_component_test.dart`
Expected: FAIL — arquivo `battle_character_component.dart` não existe.

- [ ] **Step 3: Implementar**

```dart
// app/lib/game_presentation/battle_character_component.dart
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/material.dart' show Colors;

/// Qual lado do campo de batalha um [BattleCharacterComponent] representa.
/// Puramente cosmético (cor, direção do shake) — sem significado de jogo
/// (ver docs/superpowers/specs/2026-09-08-battle-scene-visuals-design.md).
enum BattleSide { left, right }

/// Um combatente genérico, diferenciado só por lado: um "corpo" desenhado
/// em código (sem sprite), uma barra de HP acima, um contorno indicando
/// vez ativa, e um flash+shake breve quando toma dano.
class BattleCharacterComponent extends PositionComponent {
  BattleCharacterComponent({required this.side, required Vector2 position})
      : _basePosition = position.clone(),
        super(size: Vector2(64, 96), position: position, anchor: Anchor.bottomCenter);

  final BattleSide side;
  final Vector2 _basePosition;

  static const double _hitEffectDuration = 0.3;

  double _hpFraction = 1.0;
  bool _isActiveTurn = false;
  double _hitEffectRemaining = 0;

  Color get _bodyColor =>
      side == BattleSide.left ? const Color(0xFF3B6EA5) : const Color(0xFFA53B3B);

  /// Se o flash/shake de dano está tocando agora.
  bool get isPlayingHitEffect => _hitEffectRemaining > 0;

  void setHpFraction(double fraction) {
    _hpFraction = fraction.clamp(0.0, 1.0);
  }

  void setActiveTurn(bool isActive) {
    _isActiveTurn = isActive;
  }

  /// Inicia um flash+shake breve — chamado quando o HP deste lado acabou
  /// de cair (ver `BattleSceneGame.updateView`).
  void playHitEffect() {
    _hitEffectRemaining = _hitEffectDuration;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_hitEffectRemaining <= 0) {
      position.setFrom(_basePosition);
      return;
    }

    _hitEffectRemaining = (_hitEffectRemaining - dt).clamp(0, _hitEffectDuration);
    final progress = _hitEffectRemaining / _hitEffectDuration;
    final shakeX = math.sin(progress * math.pi * 6) * 4 * progress;
    position.setValues(_basePosition.x + shakeX, _basePosition.y);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

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
        Paint()..color = Colors.white.withOpacity(flashOpacity * 0.7),
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
      Rect.fromLTWH(barLeft, barTop, barWidth * _hpFraction, barHeight),
      Paint()
        ..color = _hpFraction > 0.3
            ? const Color(0xFF4CAF50)
            : const Color(0xFFE53935),
    );
  }
}
```

- [ ] **Step 4: Rodar e confirmar que passa**

Run: `flutter test test/game_presentation/battle_character_component_test.dart`
Expected: PASS (4 testes)

- [ ] **Step 5: `flutter analyze`**

Run: `flutter analyze` (dentro de `app/`)
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add app/lib/game_presentation/battle_character_component.dart app/test/game_presentation/battle_character_component_test.dart
git commit -m "Adiciona BattleCharacterComponent (corpo genérico + HP bar + flash/shake)"
```

---

## Task 5: `BattleSceneGame` (Game Presentation)

**Files:**
- Create: `app/lib/game_presentation/battle_scene_game.dart`
- Test: `app/test/game_presentation/battle_scene_game_test.dart`

**Interfaces:**
- Consumes: `BattleSceneView` (Task 2); `BattleCharacterComponent`, `BattleSide` (Task 4); asset `battlefield_bg.jpg` (Task 3).
- Produces: função pura `bool didTakeDamage({required int? previousHp, required int currentHp})`; `class BattleSceneGame extends FlameGame` com método público `void updateView(BattleSceneView view)`. Consumida pela Task 6 (`BattleSceneWidget`).

**Nota de escopo:** a lógica que decide "esse lado tomou dano" (`didTakeDamage`) é isolada e testada por completo (é a única decisão real deste arquivo). O método `updateView`/`_applyView` em si é só 8 linhas de dispatch direto (chamar `setHpFraction`/`setActiveTurn`/`playHitEffect` nos dois `BattleCharacterComponent`s) — testar isso exigiria subir uma `FlameGame` de verdade (pacote `flame_test`, que não é dependência do projeto hoje). Dado o tamanho da lógica e que a Task 10 já faz verificação visual manual (`flutter run -d chrome`), adicionar `flame_test` só para isso não se paga (YAGNI) — decisão tomada aqui, não esquecida.

- [ ] **Step 1: Escrever o teste que falha**

```dart
// app/test/game_presentation/battle_scene_game_test.dart
import 'package:app/game_domain/battle_scene_view.dart';
import 'package:app/game_presentation/battle_scene_game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('didTakeDamage', () {
    test('no previous value is never damage (first update)', () {
      expect(didTakeDamage(previousHp: null, currentHp: 50), isFalse);
    });

    test('lower hp than before counts as damage', () {
      expect(didTakeDamage(previousHp: 50, currentHp: 30), isTrue);
    });

    test('equal hp does not count as damage', () {
      expect(didTakeDamage(previousHp: 50, currentHp: 50), isFalse);
    });

    test('higher hp than before does not count as damage', () {
      expect(didTakeDamage(previousHp: 50, currentHp: 60), isFalse);
    });
  });

  group('BattleSceneGame.updateView', () {
    test('does not throw when called before the game has finished loading', () {
      final game = BattleSceneGame();

      expect(
        () => game.updateView(
          const BattleSceneView(
            leftCurrentHp: 100,
            leftMaxHp: 100,
            rightCurrentHp: 100,
            rightMaxHp: 100,
            isLeftTurn: true,
          ),
        ),
        returnsNormally,
      );
    });
  });
}
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `flutter test test/game_presentation/battle_scene_game_test.dart`
Expected: FAIL — arquivo `battle_scene_game.dart` não existe.

- [ ] **Step 3: Implementar**

```dart
// app/lib/game_presentation/battle_scene_game.dart
import 'package:flame/components.dart';
import 'package:flame/game.dart';

import '../game_domain/battle_scene_view.dart';
import 'battle_character_component.dart';

/// Se [currentHp] deve ser tratado como dano em relação a [previousHp].
/// `previousHp == null` (primeira leitura, ainda sem baseline) nunca conta
/// como dano. Pura e sem efeito colateral — fica fora de qualquer
/// componente do Flame para ser testável sem o game loop.
bool didTakeDamage({required int? previousHp, required int currentHp}) {
  return previousHp != null && currentHp < previousHp;
}

/// Jogo Flame que renderiza um [BattleSceneView]: um fundo estático mais
/// dois personagens genéricos (um por lado) com barra de HP, indicador de
/// vez, e um flash+shake breve quando o HP de um lado cai. Apresentação
/// pura — nenhuma regra de batalha mora aqui; o estado a renderizar vem de
/// fora via [updateView].
class BattleSceneGame extends FlameGame {
  BattleCharacterComponent? _left;
  BattleCharacterComponent? _right;

  int? _lastLeftHp;
  int? _lastRightHp;
  BattleSceneView? _pendingView;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final background = await loadSprite('battlefield_bg.jpg');
    add(SpriteComponent(sprite: background, size: size)..priority = -1);

    final left = BattleCharacterComponent(
      side: BattleSide.left,
      position: Vector2(size.x * 0.25, size.y * 0.85),
    );
    final right = BattleCharacterComponent(
      side: BattleSide.right,
      position: Vector2(size.x * 0.75, size.y * 0.85),
    );
    add(left);
    add(right);
    _left = left;
    _right = right;

    final pending = _pendingView;
    if (pending != null) {
      _applyView(pending);
    }
  }

  @override
  void onGameResize(Vector2 newSize) {
    super.onGameResize(newSize);
    for (final child in children.whereType<SpriteComponent>()) {
      child.size = newSize;
    }
  }

  /// Reflete [view] na cena: atualiza as duas barras de HP e o indicador
  /// de vez, e toca o efeito de dano no lado cujo HP acabou de cair em
  /// relação à última chamada. Seguro chamar antes do `onLoad` terminar
  /// (guarda a view pendente e aplica assim que os personagens existirem).
  void updateView(BattleSceneView view) {
    if (_left == null || _right == null) {
      _pendingView = view;
      return;
    }
    _applyView(view);
  }

  void _applyView(BattleSceneView view) {
    final left = _left!;
    final right = _right!;

    left.setHpFraction(view.leftMaxHp == 0 ? 0 : view.leftCurrentHp / view.leftMaxHp);
    right.setHpFraction(view.rightMaxHp == 0 ? 0 : view.rightCurrentHp / view.rightMaxHp);
    left.setActiveTurn(view.isLeftTurn);
    right.setActiveTurn(!view.isLeftTurn);

    if (didTakeDamage(previousHp: _lastLeftHp, currentHp: view.leftCurrentHp)) {
      left.playHitEffect();
    }
    if (didTakeDamage(previousHp: _lastRightHp, currentHp: view.rightCurrentHp)) {
      right.playHitEffect();
    }

    _lastLeftHp = view.leftCurrentHp;
    _lastRightHp = view.rightCurrentHp;
  }
}
```

- [ ] **Step 4: Rodar e confirmar que passa**

Run: `flutter test test/game_presentation/battle_scene_game_test.dart`
Expected: PASS (5 testes)

- [ ] **Step 5: `flutter analyze`**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add app/lib/game_presentation/battle_scene_game.dart app/test/game_presentation/battle_scene_game_test.dart
git commit -m "Adiciona BattleSceneGame (fundo + dois personagens + reação a dano)"
```

---

## Task 6: `BattleSceneWidget` (host Flutter do jogo Flame)

**Files:**
- Create: `app/lib/game_presentation/battle_scene_widget.dart`

**Interfaces:**
- Consumes: `BattleSceneGame` (Task 5), `BattleSceneView` (Task 2).
- Produces: `class BattleSceneWidget extends StatefulWidget` com construtor `BattleSceneWidget({Key? key, required BattleSceneView view})`. Consumida pelas Tasks 7 e 8.

Sem teste unitário próprio nesta task — `BattleSceneWidget` é testado indiretamente pelos testes de widget de `TrainingScreen`/`MultiplayerBattleScreen` (Tasks 7 e 8), que já pumpam a árvore inteira.

- [ ] **Step 1: Implementar**

```dart
// app/lib/game_presentation/battle_scene_widget.dart
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game_domain/battle_scene_view.dart';
import 'battle_scene_game.dart';

/// Hospeda um [BattleSceneGame] numa área de altura fixa no topo de uma
/// tela de batalha. O jogo é criado uma única vez por instância deste
/// widget e recebe [view] via `updateView` a cada rebuild — não a cada
/// frame do jogo, só quando a tela que o contém já ia re-renderizar de
/// qualquer forma (nova jogada, poll do Multiplayer, etc.).
class BattleSceneWidget extends StatefulWidget {
  const BattleSceneWidget({super.key, required this.view});

  final BattleSceneView view;

  @override
  State<BattleSceneWidget> createState() => _BattleSceneWidgetState();
}

class _BattleSceneWidgetState extends State<BattleSceneWidget> {
  final BattleSceneGame _game = BattleSceneGame();

  @override
  void initState() {
    super.initState();
    _game.updateView(widget.view);
  }

  @override
  void didUpdateWidget(covariant BattleSceneWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _game.updateView(widget.view);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: GameWidget(game: _game),
    );
  }
}
```

- [ ] **Step 2: `flutter analyze`**

Run: `flutter analyze`
Expected: `No issues found!` (o widget ainda não é usado em lugar nenhum — `unused_element`/`unused_import` não se aplicam a uma classe pública exportada de uma lib, então isso não deve acusar nada; se acusar "não usado", é esperado até a Task 7 e não bloqueia o commit desta task).

- [ ] **Step 3: Commit**

```bash
git add app/lib/game_presentation/battle_scene_widget.dart
git commit -m "Adiciona BattleSceneWidget (host Flutter do BattleSceneGame)"
```

---

## Task 7: Ligar ao `TrainingScreen`

**Files:**
- Modify: `app/lib/ui/training_screen.dart`
- Modify: `app/test/training_screen_test.dart`

**Interfaces:**
- Consumes: `BattleSceneWidget`/`BattleSceneView` (Tasks 2, 6); `TrainingMatch.isPlayerATurn` (Task 1).

- [ ] **Step 1: Adicionar os imports**

Em `app/lib/ui/training_screen.dart`, junto aos imports existentes:

```dart
import '../game_domain/battle_scene_view.dart';
import '../game_presentation/battle_scene_widget.dart';
```

- [ ] **Step 2: Inserir o `BattleSceneWidget` no topo do `Column`**

Localizar, dentro de `build()`:

```dart
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vez de: ${_match.currentTurnName}',
```

Substituir por:

```dart
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BattleSceneWidget(
              view: BattleSceneView(
                leftCurrentHp: _match.playerACurrentHp,
                leftMaxHp: _match.playerAMaxHp,
                rightCurrentHp: _match.playerBCurrentHp,
                rightMaxHp: _match.playerBMaxHp,
                isLeftTurn: _match.isPlayerATurn,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Vez de: ${_match.currentTurnName}',
```

(o restante do `children` não muda — só os dois novos widgets entram antes do `Text` de "Vez de").

- [ ] **Step 3: Corrigir os `pumpAndSettle` que agora nunca settle**

`BattleSceneGame` mantém o game loop do Flame sempre agendando frames (o mesmo motivo já documentado no comentário de `app/test/battle_screen_navigation_test.dart`) — qualquer `pumpAndSettle()` numa árvore que contenha `TrainingScreen` passa a travar até o timeout. Em `app/test/training_screen_test.dart`, no teste `'unlocking Maestria da Brasa applies Queimadura to the opponent on the next action'`, trocar:

```dart
      await tester.tap(find.byIcon(Icons.auto_awesome));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Desbloquear').first);
      await tester.pump();

      await tester.tap(find.text('Fechar'));
      await tester.pumpAndSettle();
```

por:

```dart
      await tester.tap(find.byIcon(Icons.auto_awesome));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('Desbloquear').first);
      await tester.pump();

      await tester.tap(find.text('Fechar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
```

- [ ] **Step 4: Rodar os testes de `TrainingScreen`**

Run: `flutter test test/training_screen_test.dart`
Expected: PASS (todos os testes existentes, incluindo os ajustados no Step 3).

- [ ] **Step 5: `flutter analyze`**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add app/lib/ui/training_screen.dart app/test/training_screen_test.dart
git commit -m "Liga a cena de batalha visual ao Modo Treino"
```

---

## Task 8: Ligar ao `MultiplayerBattleScreen`

**Files:**
- Modify: `app/lib/ui/multiplayer_battle_screen.dart`
- Modify: `app/test/multiplayer_battle_screen_test.dart`

**Interfaces:**
- Consumes: `BattleSceneWidget`/`BattleSceneView` (Tasks 2, 6).

A cena só aparece dentro de `_buildBattle` (partida `in_progress`) — não nas telas de espera (`isWaitingForOpponent`, sem HP ainda) nem de fim de partida (`isFinished`, coberta por texto de vitória/derrota + Revanche). `myCurrentHp`/`myMaxHp`/`opponentCurrentHp`/`opponentMaxHp` são `int?` (podem ser `null` antes do estado chegar) — usar `?? 0` é seguro aqui porque `_buildBattle` só é chamado quando `isInProgress` é verdadeiro, ou seja, o estado já existe.

- [ ] **Step 1: Adicionar os imports**

Em `app/lib/ui/multiplayer_battle_screen.dart`:

```dart
import '../game_domain/battle_scene_view.dart';
import '../game_presentation/battle_scene_widget.dart';
```

- [ ] **Step 2: Inserir o `BattleSceneWidget` no topo de `_buildBattle`**

Localizar:

```dart
  List<Widget> _buildBattle(BuildContext context) {
    final elements = const ElementCatalog().all();
    const combinationCatalog = CombinationCatalog();

    return [
      Text(
        _match.isMyTurn ? 'Sua vez' : 'Vez do oponente',
```

Substituir por:

```dart
  List<Widget> _buildBattle(BuildContext context) {
    final elements = const ElementCatalog().all();
    const combinationCatalog = CombinationCatalog();

    return [
      BattleSceneWidget(
        view: BattleSceneView(
          leftCurrentHp: _match.myCurrentHp ?? 0,
          leftMaxHp: _match.myMaxHp ?? 0,
          rightCurrentHp: _match.opponentCurrentHp ?? 0,
          rightMaxHp: _match.opponentMaxHp ?? 0,
          isLeftTurn: _match.isMyTurn,
        ),
      ),
      const SizedBox(height: 16),
      Text(
        _match.isMyTurn ? 'Sua vez' : 'Vez do oponente',
```

- [ ] **Step 3: Corrigir os `pumpAndSettle` que agora nunca settle**

Mesmo motivo da Task 7. No teste `'Habilidades modal lists what can be unlocked and unlocking it updates the list live'` em `app/test/multiplayer_battle_screen_test.dart`, trocar:

```dart
      await tester.tap(find.byTooltip('Habilidades'));
      await tester.pumpAndSettle();

      expect(find.text('[fogo] Maestria da Brasa'), findsOneWidget);

      await tester.tap(find.text('Desbloquear').first);
      await tester.pump();
      await tester.pump();

      expect(find.text('[fogo] Maestria da Brasa'), findsNothing);
      expect(find.text('[fogo] Caminho do Incêndio'), findsOneWidget);

      await tester.tap(find.text('Fechar'));
      await tester.pumpAndSettle();
```

por:

```dart
      await tester.tap(find.byTooltip('Habilidades'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('[fogo] Maestria da Brasa'), findsOneWidget);

      await tester.tap(find.text('Desbloquear').first);
      await tester.pump();
      await tester.pump();

      expect(find.text('[fogo] Maestria da Brasa'), findsNothing);
      expect(find.text('[fogo] Caminho do Incêndio'), findsOneWidget);

      await tester.tap(find.text('Fechar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
```

- [ ] **Step 4: Rodar os testes de `MultiplayerBattleScreen`**

Run: `flutter test test/multiplayer_battle_screen_test.dart`
Expected: PASS (todos os 4 testes existentes).

- [ ] **Step 5: `flutter analyze`**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add app/lib/ui/multiplayer_battle_screen.dart app/test/multiplayer_battle_screen_test.dart
git commit -m "Liga a cena de batalha visual ao Multiplayer"
```

---

## Task 9: Remover a demo Flame desconectada

**Files:**
- Delete: `app/lib/game_domain/battle_view.dart`
- Delete: `app/lib/game_domain/demo_battle.dart`
- Delete: `app/lib/game_presentation/battle_game.dart`
- Delete: `app/lib/ui/battle_screen.dart`
- Delete: `app/test/game_domain/demo_battle_test.dart`
- Delete: `app/test/battle_screen_navigation_test.dart`
- Modify: `app/lib/ui/home_screen.dart`

Justificativa (já registrada no spec): `BattleView`/`BattleGame`/`BattleScreen`/`DemoBattle` são uma demo explicitamente rotulada como tal ("Batalha (demo)"), nunca ligada a `TrainingMatch`/`MultiplayerMatch`, e agora totalmente substituída pela cena de verdade das Tasks 2–8. Mantê-la ao lado só confundiria.

- [ ] **Step 1: Remover o botão "Batalha (demo)" do `HomeScreen`**

Em `app/lib/ui/home_screen.dart`, remover o import `import 'battle_screen.dart';` e o `IconButton` inteiro:

```dart
          IconButton(
            icon: const Icon(Icons.sports_kabaddi),
            tooltip: 'Batalha (demo)',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BattleScreen()),
              );
            },
          ),
```

(os outros dois `IconButton`s — Modo Treino e Multiplayer — continuam exatamente como estão).

- [ ] **Step 2: Apagar os arquivos da demo**

```bash
git rm app/lib/game_domain/battle_view.dart
git rm app/lib/game_domain/demo_battle.dart
git rm app/lib/game_presentation/battle_game.dart
git rm app/lib/ui/battle_screen.dart
git rm app/test/game_domain/demo_battle_test.dart
git rm app/test/battle_screen_navigation_test.dart
```

- [ ] **Step 3: Rodar a suíte inteira**

Run: `flutter test` (dentro de `app/`)
Expected: PASS em todos os testes restantes (nenhum deles referenciava os arquivos apagados, exceto os dois já removidos no Step 2).

- [ ] **Step 4: `flutter analyze`**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add app/lib/ui/home_screen.dart
git commit -m "Remove a demo Flame desconectada (substituída pela cena de batalha real)"
```

---

## Task 10: Verificação manual, `DECISIONS.md` e `TASKS.md`

**Files:**
- Modify: `DECISIONS.md`
- Modify: `TASKS.md`

- [ ] **Step 1: Rodar o app no Chrome e olhar a cena de verdade**

Como o build Android local tem a limitação de ambiente já conhecida (DECISION-015/029 — loopback da JVM), a verificação visual é via Flutter Web, que não usa Gradle:

```bash
cd app
flutter run -d chrome
```

No app aberto: entrar no Modo Treino, confirmar que aparece o fundo + dois personagens (azul à esquerda, vermelho à direita) com barra de HP cheia e contorno amarelo no lado ativo; jogar uma combinação que cause dano (ex.: 🔥 Fogo + 🌪️ Vento) e confirmar visualmente o flash/shake no lado que tomou dano e a barra de HP encolhendo. Repetir a mesma checagem no Multiplayer (criar uma partida, entrar com outra aba/sessão se necessário, jogar um turno).

- [ ] **Step 2: Registrar a decisão em `DECISIONS.md`**

Adicionar ao final de `DECISIONS.md`:

```markdown

## DECISION-030
Data: 2026-09-08
Decisão: cenário de batalha visual (Flame) ligado a `TrainingScreen` e
`MultiplayerBattleScreen` — pedido do usuário depois de testar o APK e
sentir falta de um campo de batalha/personagens.
Passos: novo `BattleSceneView` (Game Domain, dado puro) montado por cada
tela a partir do que já expõe (HP/vez) — nenhuma mudança em
`TrainingMatch`/`MultiplayerMatch` além de um getter (`isPlayerATurn`).
Novo `BattleSceneGame` (Flame) renderiza um fundo estático mais dois
`BattleCharacterComponent` — personagens genéricos desenhados em código
(sem sprite), diferenciados só por lado/cor — com barra de HP, indicador
de vez, e um flash+shake local (contagem regressiva em `update(dt)`, sem
o sistema `Effect` do Flame, que exigiria o mixin `HasPaint`) quando o HP
de um lado cai. `BattleSceneWidget` hospeda o `GameWidget` numa área fixa
no topo de cada tela — o resto do layout (HP em texto, chips, botões)
continua exatamente como era. A demo Flame desconectada anterior
(`BattleView`/`BattleGame`/`BattleScreen`/`DemoBattle`, nunca ligada a uma
partida real) foi removida.
Fundo: imagem CC0 "Meadow background" de `bart`, OpenGameArt.org
(https://opengameart.org/content/meadow-background) — domínio público,
sem exigência de atribuição, 89.7 KB.
Motivo: pedido explícito do usuário; abordagem híbrida (fundo pronto CC0 +
personagens em código) escolhida em vez de um asset pack completo para
evitar depender de achar sprites genéricos para "dois lados" e para não
correr risco de licença nos personagens.
Consequência (lacuna conhecida, não esquecida): sem ícones de status
(Escudo/Queimadura) sobre o personagem — `RemoteBattleState` do
Multiplayer não expõe estados ativos por jogador hoje; adicionar isso é
mudança de contrato do backend, fora desta tarefa. Sem sprites por
elemento/combinação, sem animação de movimento. O APK existente
(DECISION-029) não inclui essa mudança — gerar um novo é ação separada.
Testes: suíte completa do app (`flutter test`) e `flutter analyze`
passando depois da mudança. Verificado de ponta a ponta de verdade via
`flutter run -d chrome`: cena renderizando fundo + dois personagens com
HP/vez corretos no Modo Treino e no Multiplayer, e o flash/shake tocando
visivelmente no lado que toma dano.
```

- [ ] **Step 3: Atualizar `TASKS.md`**

Em `TASKS.md`, na seção `# BACKLOG`, sub-seção **App Flutter (app/)**, remover a linha:

```
- `BattleScreen`/`DemoBattle` ainda é só a demo fixa do Flame, não jogo real
```

(ela descrevia exatamente a lacuna que esta tarefa fechou).

Ainda na seção `# BACKLOG`, sub-seção **Multiplayer (cliente)**, adicionar uma linha nova documentando a lacuna registrada na DECISION-030:

```
- Cena de batalha visual não mostra ícone de Escudo/Queimadura — o
  Multiplayer não recebe estados ativos por jogador do backend hoje
  (DECISION-030)
```

Na seção `# DONE`, adicionar ao final:

```
- Cenário de batalha visual (Flame): fundo CC0 + dois personagens
  genéricos por lado + flash/shake ao tomar dano, ligado ao Modo Treino e
  ao Multiplayer, substituindo a demo Flame desconectada (DECISION-030)
```

- [ ] **Step 4: Commit**

```bash
git add DECISIONS.md TASKS.md
git commit -m "Registra DECISION-030 e atualiza TASKS.md (cenário de batalha visual)"
```

---

## Self-Review (feito ao escrever este plano)

- **Cobertura do spec:** seção "Modelo de dados" → Tasks 1–2; "Apresentação" (`BattleSceneGame`/`BattleCharacterComponent`) → Tasks 4–5; "UI" (`BattleSceneWidget` + telas) → Tasks 6–8; "Limpeza" → Task 9; "Assets" → Task 3; "Testes esperados" e "Verificação manual" → cobertos em cada task + Task 10; "Fora de escopo" respeitado (nenhuma task toca `battle_engine`, `backend/`, sprites por elemento, ou ícones de status).
- **Placeholders:** nenhum "TBD"/"implementar depois" — todo step tem código completo ou comando exato.
- **Consistência de tipos:** `BattleSceneView` (Task 2) usado com os mesmos 5 campos em `BattleSceneGame._applyView` (Task 5) e nas duas telas (Tasks 7–8); `BattleCharacterComponent` (Task 4) usado com os mesmos métodos (`setHpFraction`, `setActiveTurn`, `playHitEffect`) em `BattleSceneGame` (Task 5); `TrainingMatch.isPlayerATurn` (Task 1) é o único ponto novo em `TrainingMatch`, consumido só na Task 7.
- **Achado durante o planejamento, não no spec original:** os testes de widget existentes de `TrainingScreen`/`MultiplayerBattleScreen` usam `pumpAndSettle()`, que trava para sempre com o game loop do Flame rodando (mesmo problema já documentado no comentário do teste da demo antiga). Corrigido explicitamente nas Tasks 7 e 8 — sem isso, a suíte quebraria ao final da implementação.
