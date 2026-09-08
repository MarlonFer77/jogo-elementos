# Arena de Batalha Pixel Art (Bloco 2) — Plano de Implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Trocar o visual da batalha (Modo Treino e Multiplayer, componentes compartilhados) por uma arena estilo jogo de luta — HUD de HP fixo no topo (Flutter), personagens em pixel art estilo Pokémon GBA/GBC (desenhados em código, sem asset), fundo procedural em blocos de cor.

**Architecture:** `BattleSceneView` ganha rótulos por lado; `BattleHudWidget` (Flutter puro) desenha o painel de HP no topo, num `Stack` por cima do `GameWidget` dentro de `BattleSceneWidget`. `BattleCharacterComponent` passa a desenhar uma grade de pixels (dado + função utilitária em `pixel_sprite.dart`) em vez de formas soltas, e perde a barra de HP/contorno de turno (mudaram de lugar). O fundo vira um component simples (`PixelArenaBackground`) desenhando céu/chão em blocos de cor, substituindo a imagem CC0. Nenhuma mudança em `battle_engine`, `backend`, `TrainingMatch` ou `MultiplayerMatch`.

**Tech Stack:** Flutter + Dart, pacote `flame` (já dependência). Sem dependências novas, sem asset novo (o asset atual é removido).

**Spec:** [docs/superpowers/specs/2026-09-08-pixel-battle-arena-design.md](../specs/2026-09-08-pixel-battle-arena-design.md)

## Global Constraints

- R$ 0 de custo: nada de asset novo, nada de chamada externa em runtime.
- `battle_engine`, `backend/src/battle-rules/`, `TrainingMatch`, `MultiplayerMatch` NÃO são tocados.
- `AttackSequencePlayer` (sequência de ataque) continua exatamente como está — não fica em pixel art nesta tarefa.
- Cada task termina com `flutter analyze` e `flutter test` (dentro de `app/`) passando antes do commit.

---

## Task 1: `pixel_sprite.dart` — grade de pixels + paleta + desenho

**Files:**
- Create: `app/lib/game_presentation/pixel_sprite.dart`
- Test: `app/test/game_presentation/pixel_sprite_test.dart`

**Interfaces:**
- Produces: `const List<List<int>> trainerSpriteGrid` (20×16), `const List<Color> pixelPaletteLeft`, `const List<Color> pixelPaletteRight` (7 cores cada, mesmos índices 0-6), `void drawPixelGrid(Canvas canvas, List<List<int>> grid, List<Color> palette, {required double pixelSize})`. Consumida pela Task 5 (`BattleCharacterComponent`).

A grade representa um "bonequinho" genérico: cabeça arredondada com contorno,
tronco na cor principal (com uma faixa de sombra e um cinto de detalhe),
duas pernas — mesmo desenho já validado no mockup do companion de
brainstorming. Índice `0` = transparente (nunca desenhado). A MESMA grade
serve pros dois lados; só a paleta muda (índices 4/5 = cor principal/sombra,
diferentes por lado; os demais índices são idênticos nas duas paletas).

- [ ] **Step 1: Escrever os testes que falham**

```dart
// app/test/game_presentation/pixel_sprite_test.dart
import 'dart:ui';

import 'package:app/game_presentation/pixel_sprite.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('trainerSpriteGrid is 20 rows of 16 columns each', () {
    expect(trainerSpriteGrid, hasLength(20));
    for (final row in trainerSpriteGrid) {
      expect(row, hasLength(16));
    }
  });

  test('every pixel index in the grid has a matching palette entry', () {
    final maxIndex =
        trainerSpriteGrid.expand((row) => row).reduce((a, b) => a > b ? a : b);
    expect(pixelPaletteLeft.length, greaterThan(maxIndex));
    expect(pixelPaletteRight.length, greaterThan(maxIndex));
  });

  test('left and right palettes differ only in the accent colors (indices '
      '4 and 5)', () {
    expect(pixelPaletteLeft[4], isNot(equals(pixelPaletteRight[4])));
    expect(pixelPaletteLeft[5], isNot(equals(pixelPaletteRight[5])));
    expect(pixelPaletteLeft[1], equals(pixelPaletteRight[1])); // contorno
    expect(pixelPaletteLeft[2], equals(pixelPaletteRight[2])); // pele
    expect(pixelPaletteLeft[3], equals(pixelPaletteRight[3])); // detalhe
    expect(pixelPaletteLeft[6], equals(pixelPaletteRight[6])); // cinto
  });

  test('drawPixelGrid does not throw for a valid grid and palette', () {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    expect(
      () => drawPixelGrid(
        canvas,
        const [
          [0, 1],
          [1, 0],
        ],
        const [Color(0x00000000), Color(0xFF000000)],
        pixelSize: 4,
      ),
      returnsNormally,
    );
  });
}
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `flutter test test/game_presentation/pixel_sprite_test.dart` (dentro de `app/`)
Expected: FAIL — arquivo `pixel_sprite.dart` não existe.

- [ ] **Step 3: Implementar**

```dart
// app/lib/game_presentation/pixel_sprite.dart
import 'dart:ui';

/// Grade de pixels (20 linhas × 16 colunas) de um combatente genérico —
/// cabeça, tronco, cinto, pernas — desenhado por índice de cor, `0` sempre
/// transparente. A MESMA grade serve pros dois lados (ver [pixelPaletteLeft]/
/// [pixelPaletteRight]) — ver
/// docs/superpowers/specs/2026-09-08-pixel-battle-arena-design.md.
const List<List<int>> trainerSpriteGrid = [
  [0, 0, 0, 0, 0, 3, 3, 3, 3, 3, 3, 0, 0, 0, 0, 0],
  [0, 0, 0, 0, 1, 2, 2, 2, 2, 2, 2, 1, 0, 0, 0, 0],
  [0, 0, 0, 0, 1, 2, 2, 2, 2, 2, 2, 1, 0, 0, 0, 0],
  [0, 0, 0, 0, 1, 2, 1, 2, 2, 1, 2, 1, 0, 0, 0, 0],
  [0, 0, 0, 0, 1, 2, 2, 2, 2, 2, 2, 1, 0, 0, 0, 0],
  [0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0],
  [0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0],
  [0, 0, 0, 1, 4, 4, 4, 4, 4, 4, 4, 4, 1, 0, 0, 0],
  [0, 0, 0, 1, 4, 4, 4, 4, 4, 5, 5, 4, 1, 0, 0, 0],
  [0, 0, 0, 1, 4, 4, 4, 4, 4, 5, 5, 4, 1, 0, 0, 0],
  [0, 0, 0, 1, 4, 4, 4, 4, 4, 5, 5, 4, 1, 0, 0, 0],
  [0, 0, 0, 1, 4, 4, 4, 4, 4, 5, 5, 4, 1, 0, 0, 0],
  [0, 0, 0, 1, 6, 6, 6, 6, 6, 6, 6, 6, 1, 0, 0, 0],
  [0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0],
  [0, 0, 0, 0, 1, 1, 1, 0, 0, 1, 1, 1, 0, 0, 0, 0],
  [0, 0, 0, 0, 1, 3, 3, 0, 0, 3, 3, 1, 0, 0, 0, 0],
  [0, 0, 0, 0, 1, 3, 3, 0, 0, 3, 3, 1, 0, 0, 0, 0],
  [0, 0, 0, 0, 1, 3, 3, 0, 0, 3, 3, 1, 0, 0, 0, 0],
  [0, 0, 0, 0, 1, 6, 6, 0, 0, 6, 6, 1, 0, 0, 0, 0],
  [0, 0, 0, 0, 1, 1, 1, 0, 0, 1, 1, 1, 0, 0, 0, 0],
];

/// Paleta pro lado esquerdo. Índices: 0 transparente, 1 contorno, 2 pele,
/// 3 cabelo/detalhe escuro, 4 cor principal, 5 sombra da cor principal,
/// 6 cinto/detalhe.
const List<Color> pixelPaletteLeft = [
  Color(0x00000000),
  Color(0xFF20242B),
  Color(0xFFF4C99B),
  Color(0xFF2B2F38),
  Color(0xFF3D6FE0),
  Color(0xFF2B52B0),
  Color(0xFFF4C94A),
];

/// Paleta pro lado direito — mesmos índices, só a cor principal/sombra
/// (4/5) mudam.
const List<Color> pixelPaletteRight = [
  Color(0x00000000),
  Color(0xFF20242B),
  Color(0xFFF4C99B),
  Color(0xFF2B2F38),
  Color(0xFFE0503D),
  Color(0xFFB02B2B),
  Color(0xFFF4C94A),
];

/// Desenha [grid] em [canvas]: cada célula vira um `Rect` de [pixelSize]
/// lógico, na cor `palette[índice]`. Índice `0` nunca é desenhado
/// (transparente). Pura função de desenho — não sabe nada de personagem,
/// lado ou jogo.
void drawPixelGrid(
  Canvas canvas,
  List<List<int>> grid,
  List<Color> palette, {
  required double pixelSize,
}) {
  for (var row = 0; row < grid.length; row++) {
    final cols = grid[row];
    for (var col = 0; col < cols.length; col++) {
      final index = cols[col];
      if (index == 0) continue;
      canvas.drawRect(
        Rect.fromLTWH(col * pixelSize, row * pixelSize, pixelSize, pixelSize),
        Paint()..color = palette[index],
      );
    }
  }
}
```

- [ ] **Step 4: Rodar e confirmar que passa**

Run: `flutter test test/game_presentation/pixel_sprite_test.dart`
Expected: PASS (4 testes)

- [ ] **Step 5: `flutter analyze`**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add app/lib/game_presentation/pixel_sprite.dart app/test/game_presentation/pixel_sprite_test.dart
git commit -m "Adiciona pixel_sprite (grade de pixels + paleta + desenho)"
```

---

## Task 2: `BattleSceneView` ganha rótulos por lado

**Files:**
- Modify: `app/lib/game_domain/battle_scene_view.dart`
- Modify: `app/test/game_domain/battle_scene_view_test.dart`

**Interfaces:**
- Produces: `BattleSceneView` ganha `String leftLabel` (default `'Esquerda'`) e `String rightLabel` (default `'Direita'`) — opcionais, mesmo padrão de `lastAttack` (não quebra os call sites existentes). Consumida pela Task 3 (`BattleHudWidget`) e pelas Tasks 8/9 (telas).

- [ ] **Step 1: Escrever o teste que falha**

Adicionar ao `main()` existente:

```dart
  test('leftLabel/rightLabel default to generic text and can be set', () {
    const withoutLabels = BattleSceneView(
      leftCurrentHp: 100, leftMaxHp: 100,
      rightCurrentHp: 100, rightMaxHp: 100,
      isLeftTurn: true,
    );
    expect(withoutLabels.leftLabel, 'Esquerda');
    expect(withoutLabels.rightLabel, 'Direita');

    const withLabels = BattleSceneView(
      leftCurrentHp: 100, leftMaxHp: 100,
      rightCurrentHp: 100, rightMaxHp: 100,
      isLeftTurn: true,
      leftLabel: 'Jogador A',
      rightLabel: 'Jogador B',
    );
    expect(withLabels.leftLabel, 'Jogador A');
    expect(withLabels.rightLabel, 'Jogador B');
  });
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `flutter test test/game_domain/battle_scene_view_test.dart`
Expected: FAIL — `leftLabel`/`rightLabel` não existem.

- [ ] **Step 3: Implementar**

```dart
// app/lib/game_domain/battle_scene_view.dart
class BattleSceneView {
  final int leftCurrentHp;
  final int leftMaxHp;
  final int rightCurrentHp;
  final int rightMaxHp;
  final bool isLeftTurn;
  final AttackEvent? lastAttack;
  final String leftLabel;
  final String rightLabel;

  const BattleSceneView({
    required this.leftCurrentHp,
    required this.leftMaxHp,
    required this.rightCurrentHp,
    required this.rightMaxHp,
    required this.isLeftTurn,
    this.lastAttack,
    this.leftLabel = 'Esquerda',
    this.rightLabel = 'Direita',
  });
}
```

- [ ] **Step 4: Rodar e confirmar que passa**

Run: `flutter test test/game_domain/battle_scene_view_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/lib/game_domain/battle_scene_view.dart app/test/game_domain/battle_scene_view_test.dart
git commit -m "BattleSceneView ganha leftLabel/rightLabel"
```

---

## Task 3: `BattleHudWidget` (HUD de HP no topo, Flutter puro)

**Files:**
- Create: `app/lib/game_presentation/battle_hud_widget.dart`
- Test: `app/test/game_presentation/battle_hud_widget_test.dart`

**Interfaces:**
- Consumes: `BattleSceneView` (Task 2).
- Produces: `class BattleHudWidget extends StatelessWidget` com construtor `BattleHudWidget({Key? key, required BattleSceneView view})`. Consumida pela Task 7 (`BattleSceneWidget`).

Testável isoladamente (fora da árvore do `GameWidget`) — sem o problema de
`pumpAndSettle` travando por causa do game loop do Flame, então pode usar
`pumpAndSettle()` normalmente aqui.

- [ ] **Step 1: Escrever os testes que falham**

```dart
// app/test/game_presentation/battle_hud_widget_test.dart
import 'package:app/game_domain/battle_scene_view.dart';
import 'package:app/game_presentation/battle_hud_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows both labels and HP for each side', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: BattleHudWidget(
          view: BattleSceneView(
            leftCurrentHp: 80, leftMaxHp: 100,
            rightCurrentHp: 40, rightMaxHp: 100,
            isLeftTurn: true,
            leftLabel: 'Jogador A',
            rightLabel: 'Jogador B',
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Jogador A'), findsOneWidget);
    expect(find.text('Jogador B'), findsOneWidget);
    expect(find.textContaining('80/100 HP'), findsOneWidget);
    expect(find.textContaining('40/100 HP'), findsOneWidget);
  });

  testWidgets('marks the left panel as active when isLeftTurn is true',
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
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('▶'), findsOneWidget);
    expect(find.text('◀'), findsNothing);
  });

  testWidgets('marks the right panel as active when isLeftTurn is false',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: BattleHudWidget(
          view: BattleSceneView(
            leftCurrentHp: 100, leftMaxHp: 100,
            rightCurrentHp: 100, rightMaxHp: 100,
            isLeftTurn: false,
            leftLabel: 'Jogador A',
            rightLabel: 'Jogador B',
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('◀'), findsOneWidget);
    expect(find.text('▶'), findsNothing);
  });
}
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `flutter test test/game_presentation/battle_hud_widget_test.dart`
Expected: FAIL — arquivo `battle_hud_widget.dart` não existe.

- [ ] **Step 3: Implementar**

```dart
// app/lib/game_presentation/battle_hud_widget.dart
import 'package:flutter/material.dart';

import '../game_domain/battle_scene_view.dart';

/// Painel de HP fixo no topo da cena, estilo jogo de luta: nome + barra de
/// HP de cada lado, com o lado ativo destacado (borda + seta). Flutter
/// puro (não Canvas do Flame) — ver
/// docs/superpowers/specs/2026-09-08-pixel-battle-arena-design.md.
class BattleHudWidget extends StatelessWidget {
  const BattleHudWidget({super.key, required this.view});

  final BattleSceneView view;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _HudPanel(
              label: view.leftLabel,
              currentHp: view.leftCurrentHp,
              maxHp: view.leftMaxHp,
              isActive: view.isLeftTurn,
              alignEnd: false,
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
            ),
          ),
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
  });

  final String label;
  final int currentHp;
  final int maxHp;
  final bool isActive;
  final bool alignEnd;

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
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Rodar e confirmar que passa**

Run: `flutter test test/game_presentation/battle_hud_widget_test.dart`
Expected: PASS (3 testes)

- [ ] **Step 5: `flutter analyze`**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add app/lib/game_presentation/battle_hud_widget.dart app/test/game_presentation/battle_hud_widget_test.dart
git commit -m "Adiciona BattleHudWidget (HP fixo no topo, estilo jogo de luta)"
```

---

## Task 4: `PixelArenaBackground` (fundo procedural)

**Files:**
- Create: `app/lib/game_presentation/pixel_arena_background.dart`

**Interfaces:**
- Produces: `class PixelArenaBackground extends PositionComponent`. Consumida pela Task 6 (`BattleSceneGame`).

Sem teste dedicado — componente trivial (três `drawRect`, sem estado, sem
lógica) — mesmo padrão de não testar unitariamente o `SpriteComponent` de
fundo que existia antes; a verificação é visual (Task 11).

- [ ] **Step 1: Implementar**

```dart
// app/lib/game_presentation/pixel_arena_background.dart
import 'dart:ui';

import 'package:flame/components.dart';

/// Fundo da arena: poucos blocos de cor sólida (céu, linha de horizonte,
/// chão) desenhados em código — sem imagem nenhuma, pra combinar com os
/// personagens em pixel art. Ver
/// docs/superpowers/specs/2026-09-08-pixel-battle-arena-design.md.
class PixelArenaBackground extends PositionComponent {
  static const _sky = Color(0xFF8FD3E8);
  static const _ground = Color(0xFF7CC576);
  static const _horizonLine = Color(0xFF5FA857);

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final horizon = size.y * 0.62;

    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, horizon), Paint()..color = _sky);
    canvas.drawRect(
      Rect.fromLTWH(0, horizon, size.x, size.y - horizon),
      Paint()..color = _ground,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, horizon, size.x, 4),
      Paint()..color = _horizonLine,
    );
  }
}
```

- [ ] **Step 2: `flutter analyze`**

Run: `flutter analyze`
Expected: `No issues found!` (o componente ainda não é usado em lugar nenhum — normal até a Task 6).

- [ ] **Step 3: Commit**

```bash
git add app/lib/game_presentation/pixel_arena_background.dart
git commit -m "Adiciona PixelArenaBackground (fundo procedural em blocos de cor)"
```

---

## Task 5: `BattleCharacterComponent` vira sprite em pixel art

**Files:**
- Modify: `app/lib/game_presentation/battle_character_component.dart`
- Modify: `app/test/game_presentation/battle_character_component_test.dart`

**Interfaces:**
- Consumes: `pixel_sprite.dart` (Task 1).
- Produces: mesma API pública de flash/pulso (`isPlayingHitEffect`,
  `playHitEffect`, `isPlayingPreparationPulse`, `playPreparationPulse`).
  Remove: `setHpFraction`, `setActiveTurn`, `debugDisplayedHpFraction` (a
  barra de HP e o indicador de vez migraram pro `BattleHudWidget`, Task 3).

Tamanho do componente muda de `Vector2(64, 96)` pra `Vector2(64, 80)` —
64/16 = 80/20 = 4 (pixel lógico quadrado, batendo com a grade 16×20).

- [ ] **Step 1: Remover os testes que não se aplicam mais**

Em `app/test/game_presentation/battle_character_component_test.dart`,
remover os dois testes de fração de HP (o método some, não faz mais
sentido testar):

```dart
    test('setHpFraction clamps to the 0..1 range', () {
      ...
    });
```

e

```dart
    test('the displayed HP fraction chases the target instead of jumping',
        () {
      ...
    });
```

(os outros 5 testes — hit effect ×2, shake, pulso de preparação ×2 —
continuam exatamente como estão, a API deles não muda.)

- [ ] **Step 2: Rodar e confirmar que os 5 restantes ainda passam**

Run: `flutter test test/game_presentation/battle_character_component_test.dart`
Expected: PASS (5 testes) — nada mudou no componente ainda, só os testes
obsoletos saíram.

- [ ] **Step 3: Reescrever o componente**

```dart
// app/lib/game_presentation/battle_character_component.dart
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/material.dart' show Colors;

import 'pixel_sprite.dart';

/// Qual lado do campo de batalha um [BattleCharacterComponent] representa.
/// Puramente cosmético (paleta, direção do espelhamento/shake) — sem
/// significado de jogo.
enum BattleSide { left, right }

/// Um combatente genérico, diferenciado só por lado: um sprite em pixel
/// art desenhado em código (ver `pixel_sprite.dart`), um flash+shake breve
/// quando toma dano, e um pulso de escala na preparação de ataque. Barra
/// de HP e indicador de vez moraram no `BattleHudWidget` — não são
/// responsabilidade deste componente.
class BattleCharacterComponent extends PositionComponent {
  BattleCharacterComponent({required this.side, required Vector2 position})
      : _basePosition = position.clone(),
        super(size: Vector2(64, 80), position: position, anchor: Anchor.bottomCenter);

  final BattleSide side;
  final Vector2 _basePosition;

  static const double _hitEffectDuration = 0.3;
  static const double _prepPulseDuration = 0.15;

  double _hitEffectRemaining = 0;
  double _prepPulseRemaining = 0;

  /// Se o flash/shake de dano está tocando agora.
  bool get isPlayingHitEffect => _hitEffectRemaining > 0;

  /// Se o pulso de preparação está tocando agora.
  bool get isPlayingPreparationPulse => _prepPulseRemaining > 0;

  /// Inicia um flash+shake breve — chamado quando o HP deste lado acabou
  /// de cair (ver `AttackSequencePlayer`).
  void playHitEffect() {
    _hitEffectRemaining = _hitEffectDuration;
  }

  /// Inicia um pulso de escala breve — chamado no passo de preparação da
  /// sequência de ataque (`AttackSequencePlayer`).
  void playPreparationPulse() {
    _prepPulseRemaining = _prepPulseDuration;
  }

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
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final pulseScale = isPlayingPreparationPulse
        ? 1.0 + 0.12 * (_prepPulseRemaining / _prepPulseDuration)
        : 1.0;
    final mirror = side == BattleSide.right;

    canvas.save();
    canvas.translate(size.x / 2, size.y);
    canvas.scale(mirror ? -pulseScale : pulseScale, pulseScale);
    canvas.translate(-size.x / 2, -size.y);

    final palette = side == BattleSide.left ? pixelPaletteLeft : pixelPaletteRight;
    final pixelSize = size.x / trainerSpriteGrid.first.length;
    drawPixelGrid(canvas, trainerSpriteGrid, palette, pixelSize: pixelSize);

    if (isPlayingHitEffect) {
      final flashOpacity = (_hitEffectRemaining / _hitEffectDuration).clamp(0.0, 1.0);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()..color = Colors.white.withValues(alpha: flashOpacity * 0.6),
      );
    }

    canvas.restore();
  }
}
```

- [ ] **Step 4: Rodar e confirmar que os testes continuam passando**

Run: `flutter test test/game_presentation/battle_character_component_test.dart`
Expected: PASS (5 testes) — a API pública testada não mudou, só a
implementação interna do `render`.

- [ ] **Step 5: `flutter analyze`**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add app/lib/game_presentation/battle_character_component.dart app/test/game_presentation/battle_character_component_test.dart
git commit -m "BattleCharacterComponent desenha sprite em pixel art (era formas soltas)"
```

---

## Task 6: `BattleSceneGame` — fundo procedural + remove HP/turno do personagem

**Files:**
- Modify: `app/lib/game_presentation/battle_scene_game.dart`

**Interfaces:**
- Consumes: `PixelArenaBackground` (Task 4).

Nenhuma mudança na API pública (`updateView`) nem nos testes existentes —
`battle_scene_game_test.dart` continua passando sem alteração (os testes
já não verificam `setHpFraction`/`setActiveTurn` diretamente, só
`updateView`/`didTakeDamage`/gating de sequência).

- [ ] **Step 1: Trocar o fundo**

Em `app/lib/game_presentation/battle_scene_game.dart`, trocar o import:

```dart
import 'pixel_arena_background.dart';
```

no lugar de nada extra (remove-se a dependência do `loadSprite`, que era
built-in do `Game`, sem import próprio). Em `onLoad`:

```dart
  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final background = PixelArenaBackground()
      ..size = size
      ..priority = -1;
    add(background);

    final left = BattleCharacterComponent(
```

(remove a linha `final background = await loadSprite('battlefield_bg.jpg');`
e a linha `add(SpriteComponent(sprite: background, size: size)..priority = -1);`,
o resto do método continua igual).

Em `onGameResize`, trocar `SpriteComponent` por `PixelArenaBackground`:

```dart
  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    for (final child in children.whereType<PixelArenaBackground>()) {
      child.size = size;
    }
  }
```

- [ ] **Step 2: Remover as chamadas de HP/turno no personagem**

Em `_applyView`, remover estas quatro linhas (o método não existe mais em
`BattleCharacterComponent`):

```dart
    left.setHpFraction(view.leftMaxHp == 0 ? 0 : view.leftCurrentHp / view.leftMaxHp);
    right.setHpFraction(view.rightMaxHp == 0 ? 0 : view.rightCurrentHp / view.rightMaxHp);
    left.setActiveTurn(view.isLeftTurn);
    right.setActiveTurn(!view.isLeftTurn);
```

(o resto do método — detecção de `AttackEvent`, fallback de dano — continua
igual).

- [ ] **Step 3: Rodar e confirmar que os testes continuam passando**

Run: `flutter test test/game_presentation/battle_scene_game_test.dart`
Expected: PASS (todos os testes existentes, sem alteração).

- [ ] **Step 4: `flutter analyze`**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add app/lib/game_presentation/battle_scene_game.dart
git commit -m "BattleSceneGame usa o fundo procedural e não controla mais HP/turno do personagem"
```

---

## Task 7: `BattleSceneWidget` — HUD sobreposto ao `GameWidget`

**Files:**
- Modify: `app/lib/game_presentation/battle_scene_widget.dart`

**Interfaces:**
- Consumes: `BattleHudWidget` (Task 3).

Sem teste dedicado (mudança de composição de widgets, coberta pelos
testes de tela nas Tasks 8/9).

- [ ] **Step 1: Implementar**

```dart
// app/lib/game_presentation/battle_scene_widget.dart
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game_domain/battle_scene_view.dart';
import 'battle_hud_widget.dart';
import 'battle_scene_game.dart';

/// Hospeda um [BattleSceneGame] (arena + personagens, Flame) com um
/// [BattleHudWidget] (HP no topo, Flutter puro) sobreposto — numa área de
/// altura fixa no topo de uma tela de batalha. O jogo é criado uma única
/// vez por instância deste widget e recebe [view] via `updateView` a cada
/// rebuild.
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
      height: 260,
      child: Stack(
        children: [
          Positioned.fill(child: GameWidget(game: _game)),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: BattleHudWidget(view: widget.view),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: `flutter analyze`**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add app/lib/game_presentation/battle_scene_widget.dart
git commit -m "BattleSceneWidget sobrepõe o BattleHudWidget ao GameWidget"
```

---

## Task 8: Ligar ao `TrainingScreen`

**Files:**
- Modify: `app/lib/ui/training_screen.dart`
- Test: `app/test/training_screen_test.dart`

- [ ] **Step 1: Passar os rótulos e remover o texto de HP duplicado**

No `BattleSceneWidget` já existente:

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
              ),
            ),
```

Remover as duas linhas de HP em texto simples (as de estado continuam):

```dart
            Text(
              'Jogador A: ${_match.playerACurrentHp}/${_match.playerAMaxHp} HP',
            ),
            Text('Jogador A: ${_statusSummary(_match.playerAStatusNames)}'),
            Text(
              'Jogador B: ${_match.playerBCurrentHp}/${_match.playerBMaxHp} HP',
            ),
            Text('Jogador B: ${_statusSummary(_match.playerBStatusNames)}'),
```

vira:

```dart
            Text('Jogador A: ${_statusSummary(_match.playerAStatusNames)}'),
            Text('Jogador B: ${_statusSummary(_match.playerBStatusNames)}'),
```

- [ ] **Step 2: Rodar os testes de `TrainingScreen`**

Run: `flutter test test/training_screen_test.dart`
Expected: PASS sem nenhuma alteração no arquivo de teste — a asserção
`find.textContaining('80/100 HP')` passa a bater com o texto do
`BattleHudWidget` (que virou a única ocorrência dessa string na tela).
Se algum outro teste falhar de verdade, ler a falha real e corrigir —
não são esperadas mudanças aqui, mas confirmar rodando.

- [ ] **Step 3: `flutter analyze`**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add app/lib/ui/training_screen.dart
git commit -m "TrainingScreen usa o HUD novo, remove HP em texto duplicado"
```

---

## Task 9: Ligar ao `MultiplayerBattleScreen`

**Files:**
- Modify: `app/lib/ui/multiplayer_battle_screen.dart`
- Test: `app/test/multiplayer_battle_screen_test.dart`

- [ ] **Step 1: Passar os rótulos e remover o texto de HP duplicado**

No `BattleSceneWidget` já existente (dentro de `_buildBattle`):

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
        ),
      ),
```

Remover as duas linhas de HP em texto simples:

```dart
      Text('Você: ${_match.myCurrentHp}/${_match.myMaxHp} HP'),
      Text('Oponente: ${_match.opponentCurrentHp}/${_match.opponentMaxHp} HP'),
```

(nenhuma substituição — não havia linha de estado equivalente aqui).

- [ ] **Step 2: Corrigir a asserção de HP no teste**

Em `app/test/multiplayer_battle_screen_test.dart`, no teste
`'shows HP/turn for an in-progress match and plays a combo turn'`, trocar:

```dart
      expect(find.text('Vez do oponente'), findsOneWidget);
      expect(find.textContaining('Você: 100/100 HP'), findsOneWidget);
```

por (os dois lados começam em 100/100 nesse teste — `'100/100 HP'` sozinho
bateria duas vezes, então checa o rótulo e a contagem):

```dart
      expect(find.text('Vez do oponente'), findsOneWidget);
      expect(find.text('Você'), findsOneWidget);
      expect(find.text('Oponente'), findsOneWidget);
      expect(find.textContaining('100/100 HP'), findsNWidgets(2));
```

- [ ] **Step 3: Rodar os testes de `MultiplayerBattleScreen`**

Run: `flutter test test/multiplayer_battle_screen_test.dart`
Expected: PASS (todos os testes).

- [ ] **Step 4: `flutter analyze`**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add app/lib/ui/multiplayer_battle_screen.dart app/test/multiplayer_battle_screen_test.dart
git commit -m "MultiplayerBattleScreen usa o HUD novo, remove HP em texto duplicado"
```

---

## Task 10: Remover o asset de fundo não usado

**Files:**
- Delete: `app/assets/images/battlefield_bg.jpg`
- Modify: `app/pubspec.yaml`

- [ ] **Step 1: Apagar o arquivo e a pasta**

```bash
git rm app/assets/images/battlefield_bg.jpg
rmdir app/assets/images 2>/dev/null || true
```

- [ ] **Step 2: Remover a declaração em `pubspec.yaml`**

Em `app/pubspec.yaml`, remover:

```yaml
  assets:
    - assets/images/

```

(as duas linhas mais a linha em branco — o comentário de exemplo logo
abaixo, já comentado, continua como estava).

- [ ] **Step 3: Confirmar que o app ainda resolve**

Run: `flutter pub get` (dentro de `app/`)
Expected: termina sem erro.

Run: `flutter test`
Expected: PASS em toda a suíte (nenhum teste carrega esse asset
diretamente).

- [ ] **Step 4: Commit**

```bash
git add app/pubspec.yaml
git commit -m "Remove o asset de fundo não usado (substituído por PixelArenaBackground)"
```

---

## Task 11: Verificação manual, `DECISIONS.md` e `TASKS.md`

**Files:**
- Modify: `DECISIONS.md`
- Modify: `TASKS.md`

- [ ] **Step 1: Suíte completa**

Run: `flutter test` (dentro de `app/`)
Expected: PASS em todos os testes.

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 2: Rodar o app no Chrome e olhar a arena de verdade**

```bash
cd app
flutter run -d web-server --web-port 5000
```

No Modo Treino: confirmar HUD no topo (nome + barra de HP dos dois lados,
painel ativo destacado com seta), arena com céu/chão em blocos de cor,
personagens em pixel art reconhecíveis (silhueta de bonequinho, contorno
preto, cor por lado). Jogar uma combinação com dano e confirmar que a
sequência de ataque (preparação, burst, impacto, dano, estado) continua
funcionando por cima do novo visual, e que a barra de HP no HUD anima até
o valor novo. Repetir a checagem no Multiplayer (duas abas/sessões).
Ajustar posições/proporções (tamanho dos personagens, altura do HUD) se
alguma coisa ficar sobreposta ou cortada — são detalhes de acabamento
visual, não de arquitetura.

- [ ] **Step 3: Registrar a decisão em `DECISIONS.md`**

Adicionar ao final de `DECISIONS.md` (confirmar o número da próxima
decisão antes de escrever — não assumir):

```markdown

## DECISION-0XX
Data: 2026-09-08
Decisão: arena de batalha em pixel art (Bloco 2 da direção de produto) —
HUD de HP fixo no topo (estilo jogo de luta), personagens desenhados como
sprite pixel art estilo Pokémon GBA/GBC (grade de cores em código, sem
asset), fundo procedural em blocos de cor. Vale pro Modo Treino e pro
Multiplayer (componentes compartilhados).
Passos: `BattleSceneView` ganhou `leftLabel`/`rightLabel`. Novo
`BattleHudWidget` (Flutter puro, não Canvas) desenha o painel de HP no
topo — `BattleSceneWidget` virou um `Stack` com ele sobreposto ao
`GameWidget`. Novo `pixel_sprite.dart`: uma grade 20×16 de índices de cor
(dado) + uma função de desenho genérica (`drawPixelGrid`) + duas paletas
(esquerda/direita, mesmos índices, só a cor principal/sombra muda).
`BattleCharacterComponent` passou a desenhar essa grade em vez de formas
soltas, e perdeu a barra de HP/contorno de turno (migraram pro HUD) — o
mesmo `canvas.scale` já usado no pulso de preparação agora também espelha
o lado direito. Novo `PixelArenaBackground` substitui a imagem CC0 por
céu/chão em blocos de cor; `battlefield_bg.jpg` e a declaração `assets:`
correspondente foram removidos.
Como pedido explícito do usuário: "as linhas 'Jogador X: HP' em texto
simples abaixo da cena foram removidas (redundantes com o HUD novo) — o
resto do texto (estados, descobertas, combinação, campo, chips, botão)
continua igual.
Motivo: Bloco 2 da nova direção de produto (game feel) — pedido explícito
do usuário por um visual "estilo jogos de luta, bonecos de gameboy tipo
pokemon", feito em código.
Consequência (lacuna conhecida, não esquecida): a sequência de ataque
(`AttackSequencePlayer`: burst elemental, número de dano, texto de
estado) continua com o visual anterior (texto/formas simples), não em
pixel art — fora de escopo deste bloco. Sem escolha de avatar, sem
animação de idle, sem sprites por elemento — tudo já era esperado desde a
spec.
Testes: suíte completa do app (`flutter test`) e `flutter analyze`
passando depois da mudança. Verificado de ponta a ponta de verdade via
`flutter run -d web-server`: HUD, arena e personagens pixelados
renderizando corretamente no Modo Treino e no Multiplayer, sequência de
ataque continuando a funcionar por cima do novo visual.
```

- [ ] **Step 4: Atualizar `TASKS.md`**

Na seção `# DONE`, adicionar ao final:

```
- Arena de batalha em pixel art (Bloco 2 da direção de produto): HUD estilo
  jogo de luta no topo, personagens em sprite pixel art (grade de cores em
  código), fundo procedural — Modo Treino e Multiplayer (DECISION-0XX)
```

(usar o número real da decisão registrada no Step 3).

- [ ] **Step 5: Commit**

```bash
git add DECISIONS.md TASKS.md
git commit -m "Registra decisão e atualiza TASKS.md (arena de batalha em pixel art)"
```

---

## Self-Review (feito ao escrever este plano)

- **Cobertura do spec:** "HUD (mudança de arquitetura)" → Tasks 2, 3, 7;
  "Texto duplicado" → Tasks 8, 9; "Personagens em pixel art" → Tasks 1, 5;
  "Fundo (arena)" → Tasks 4, 6, 10; "Testes esperados" e "Verificação
  manual" → cobertos em cada task + Task 11. "O que NÃO está neste bloco"
  respeitado — nenhuma task toca `AttackSequencePlayer`, `battle_engine`,
  `backend`, escolha de avatar ou animação de idle.
- **Placeholders:** nenhum "TBD" — todo step tem código completo ou comando
  exato. A grade de pixels (Task 1) foi transcrita à mão a partir do
  mockup já aprovado, célula por célula, e verificada (20 linhas × 16
  colunas cada) antes de entrar no plano.
- **Consistência de tipos:** `pixelPaletteLeft`/`pixelPaletteRight`/
  `trainerSpriteGrid`/`drawPixelGrid` (Task 1) usados com essas assinaturas
  exatas em `BattleCharacterComponent` (Task 5). `BattleSceneView.leftLabel/
  rightLabel` (Task 2) usados em `BattleHudWidget` (Task 3) e nas duas
  telas (Tasks 8, 9) com os mesmos nomes.
- **Achado durante o planejamento:** a barra de HP animada do
  `TweenAnimationBuilder` (Task 3) precisa do padrão `Tween<double>(end:
  fraction)` **sem** `begin` explícito — é assim que o widget sabe
  animar do valor atual pro novo a cada rebuild, em vez de sempre
  recomeçar do zero. Já está assim no código da Task 3.
