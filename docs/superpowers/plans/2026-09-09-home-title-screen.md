# Tela Inicial Estilo Jogo de Luta (Bloco 3) — Plano de Implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Substituir a `HomeScreen` placeholder (lista crua de elementos) por uma tela de título de verdade — fundo/personagens/estilo pixel art reaproveitados da batalha, título com contorno, botões blocudos pro Treino/Multiplayer.

**Architecture:** `PixelArenaBackground` (Flame) tem seu desenho extraído para uma função pura `drawArenaBackdrop`, reaproveitada por um `CustomPainter` Flutter puro na `HomeScreen`. Um novo `TrainerSpriteImage` reaproveita `drawPixelGrid` (já existente) fora do Flame, via `CustomPainter`. Um novo `PixelMenuButton` dá o estilo blocudo aos dois botões de navegação. Nenhuma mudança em `battle_engine`, `backend`, `TrainingMatch`/`MultiplayerMatch`, nem nas telas de Treino/Multiplayer além da navegação de entrada.

**Tech Stack:** Flutter + Dart. Sem dependências novas, sem asset novo.

**Spec:** [docs/superpowers/specs/2026-09-09-home-title-screen-design.md](../specs/2026-09-09-home-title-screen-design.md)

## Global Constraints

- R$ 0 de custo: nada de asset/fonte nova, nada de chamada externa.
- `battle_engine`, `backend/src/battle-rules/`, `TrainingMatch`, `MultiplayerMatch` NÃO são tocados.
- Telas de Treino/Multiplayer/Lobby/Skill Tree não mudam visualmente nesta tarefa — só a forma de chegar nelas a partir da Home.
- Cada task termina com `flutter analyze` e `flutter test` (dentro de `app/`) passando antes do commit.

---

## Task 1: Extrair `drawArenaBackdrop` de `PixelArenaBackground`

**Files:**
- Modify: `app/lib/game_presentation/pixel_arena_background.dart`
- Test: `app/test/game_presentation/pixel_arena_background_test.dart`

**Interfaces:**
- Produces: `void drawArenaBackdrop(Canvas canvas, Size size)` — função pura, sem Flame. `PixelArenaBackground` (já existente) passa a chamá-la. Consumida pela Task 4 (`HomeScreen`).

- [ ] **Step 1: Escrever o teste que falha**

```dart
// app/test/game_presentation/pixel_arena_background_test.dart
import 'dart:ui';

import 'package:app/game_presentation/pixel_arena_background.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('drawArenaBackdrop does not throw for a valid size', () {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    expect(
      () => drawArenaBackdrop(canvas, const Size(320, 200)),
      returnsNormally,
    );
  });
}
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `flutter test test/game_presentation/pixel_arena_background_test.dart` (dentro de `app/`)
Expected: FAIL — `drawArenaBackdrop` não existe.

- [ ] **Step 3: Implementar**

```dart
// app/lib/game_presentation/pixel_arena_background.dart
import 'dart:ui';

import 'package:flame/components.dart';

const _sky = Color(0xFF8FD3E8);
const _ground = Color(0xFF7CC576);
const _horizonLine = Color(0xFF5FA857);

/// Desenha o "backdrop" da arena (céu, linha de horizonte, chão) em
/// [canvas], ocupando [size]. Compartilhado entre [PixelArenaBackground]
/// (Flame, cena de batalha) e a decoração de fundo da tela inicial — ver
/// docs/superpowers/specs/2026-09-09-home-title-screen-design.md.
void drawArenaBackdrop(Canvas canvas, Size size) {
  final horizon = size.height * 0.62;

  canvas.drawRect(Rect.fromLTWH(0, 0, size.width, horizon), Paint()..color = _sky);
  canvas.drawRect(
    Rect.fromLTWH(0, horizon, size.width, size.height - horizon),
    Paint()..color = _ground,
  );
  canvas.drawRect(
    Rect.fromLTWH(0, horizon, size.width, 4),
    Paint()..color = _horizonLine,
  );
}

/// Fundo da arena de batalha (Flame) — ver
/// docs/superpowers/specs/2026-09-08-pixel-battle-arena-design.md.
class PixelArenaBackground extends PositionComponent {
  @override
  void render(Canvas canvas) {
    super.render(canvas);
    drawArenaBackdrop(canvas, Size(size.x, size.y));
  }
}
```

- [ ] **Step 4: Rodar e confirmar que passa**

Run: `flutter test test/game_presentation/pixel_arena_background_test.dart`
Expected: PASS

- [ ] **Step 5: Rodar a suíte de `BattleSceneGame`/cena de batalha (regressão)**

Run: `flutter test test/game_presentation/battle_scene_game_test.dart`
Expected: PASS (comportamento do `PixelArenaBackground` não mudou, só foi
refatorado).

- [ ] **Step 6: `flutter analyze`**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add app/lib/game_presentation/pixel_arena_background.dart app/test/game_presentation/pixel_arena_background_test.dart
git commit -m "Extrai drawArenaBackdrop de PixelArenaBackground (reaproveitável fora do Flame)"
```

---

## Task 2: `TrainerSpriteImage` (personagem decorativo, fora do Flame)

**Files:**
- Create: `app/lib/game_presentation/trainer_sprite_image.dart`
- Test: `app/test/game_presentation/trainer_sprite_image_test.dart`

**Interfaces:**
- Consumes: `drawPixelGrid`, `trainerSpriteGrid`, `pixelPaletteLeft`, `pixelPaletteRight` (`pixel_sprite.dart`, já existente).
- Produces: `class TrainerSpriteImage extends StatelessWidget` com construtor `TrainerSpriteImage({Key? key, bool mirror = false, Size size = const Size(96, 120)})`. Consumida pela Task 4 (`HomeScreen`).

- [ ] **Step 1: Escrever o teste que falha**

```dart
// app/test/game_presentation/trainer_sprite_image_test.dart
import 'package:app/game_presentation/trainer_sprite_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('builds without throwing, mirrored or not', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: TrainerSpriteImage())),
    );
    expect(find.byType(TrainerSpriteImage), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: TrainerSpriteImage(mirror: true)),
      ),
    );
    expect(find.byType(TrainerSpriteImage), findsOneWidget);
  });
}
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `flutter test test/game_presentation/trainer_sprite_image_test.dart`
Expected: FAIL — arquivo não existe.

- [ ] **Step 3: Implementar**

```dart
// app/lib/game_presentation/trainer_sprite_image.dart
import 'package:flutter/material.dart';

import 'pixel_sprite.dart';

/// Um dos dois personagens da batalha, desenhado fora do Flame — usado
/// como decoração estática (ex: tela inicial). Reaproveita [drawPixelGrid]
/// direto: `CustomPainter.paint` já entrega o mesmo `Canvas` que
/// [drawPixelGrid] espera, sem adaptação nenhuma. Ver
/// docs/superpowers/specs/2026-09-09-home-title-screen-design.md.
class TrainerSpriteImage extends StatelessWidget {
  const TrainerSpriteImage({
    super.key,
    this.mirror = false,
    this.size = const Size(96, 120),
  });

  final bool mirror;
  final Size size;

  @override
  Widget build(BuildContext context) {
    return Transform.flip(
      flipX: mirror,
      child: CustomPaint(
        size: size,
        painter: _TrainerSpritePainter(mirror ? pixelPaletteRight : pixelPaletteLeft),
      ),
    );
  }
}

class _TrainerSpritePainter extends CustomPainter {
  _TrainerSpritePainter(this.palette);

  final List<Color> palette;

  @override
  void paint(Canvas canvas, Size size) {
    final pixelSize = size.width / trainerSpriteGrid.first.length;
    drawPixelGrid(canvas, trainerSpriteGrid, palette, pixelSize: pixelSize);
  }

  @override
  bool shouldRepaint(covariant _TrainerSpritePainter oldDelegate) =>
      oldDelegate.palette != palette;
}
```

- [ ] **Step 4: Rodar e confirmar que passa**

Run: `flutter test test/game_presentation/trainer_sprite_image_test.dart`
Expected: PASS

- [ ] **Step 5: `flutter analyze`**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add app/lib/game_presentation/trainer_sprite_image.dart app/test/game_presentation/trainer_sprite_image_test.dart
git commit -m "Adiciona TrainerSpriteImage (personagem pixel art fora do Flame)"
```

---

## Task 3: `PixelMenuButton`

**Files:**
- Create: `app/lib/game_presentation/pixel_menu_button.dart`
- Test: `app/test/game_presentation/pixel_menu_button_test.dart`

**Interfaces:**
- Produces: `class PixelMenuButton extends StatelessWidget` com construtor `PixelMenuButton({Key? key, required String label, required VoidCallback onPressed, bool primary = false})`. Consumida pela Task 4 (`HomeScreen`).

- [ ] **Step 1: Escrever o teste que falha**

```dart
// app/test/game_presentation/pixel_menu_button_test.dart
import 'package:app/game_presentation/pixel_menu_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the label and calls onPressed when tapped',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PixelMenuButton(
          label: 'MODO TREINO',
          onPressed: () => tapped = true,
        ),
      ),
    ));

    expect(find.text('MODO TREINO'), findsOneWidget);

    await tester.tap(find.text('MODO TREINO'));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `flutter test test/game_presentation/pixel_menu_button_test.dart`
Expected: FAIL — arquivo não existe.

- [ ] **Step 3: Implementar**

```dart
// app/lib/game_presentation/pixel_menu_button.dart
import 'package:flutter/material.dart';

/// Botão blocudo estilo jogo de luta — mesmo espírito visual do painel
/// de HP da batalha (`BattleHudWidget`). [primary] dá um fundo mais
/// destacado (ação mais comum). Sem animação customizada: usa o feedback
/// de toque padrão do Flutter (`InkWell`). Ver
/// docs/superpowers/specs/2026-09-09-home-title-screen-design.md.
class PixelMenuButton extends StatelessWidget {
  const PixelMenuButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primary ? const Color(0xFFF4C94A) : const Color(0xFFF4F4E4),
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF2B2B2B), width: 3),
            borderRadius: BorderRadius.circular(4),
            boxShadow: const [
              BoxShadow(color: Color(0xFF2B2B2B), offset: Offset(3, 3)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 1,
                  color: Color(0xFF2B2B2B),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '▶',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2B2B2B)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Rodar e confirmar que passa**

Run: `flutter test test/game_presentation/pixel_menu_button_test.dart`
Expected: PASS

- [ ] **Step 5: `flutter analyze`**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add app/lib/game_presentation/pixel_menu_button.dart app/test/game_presentation/pixel_menu_button_test.dart
git commit -m "Adiciona PixelMenuButton (botão blocudo estilo jogo de luta)"
```

---

## Task 4: `HomeScreen` vira tela de título de verdade

**Files:**
- Modify: `app/lib/ui/home_screen.dart`
- Create: `app/test/home_screen_test.dart`
- Delete: `app/test/widget_test.dart`

**Interfaces:**
- Consumes: `drawArenaBackdrop` (Task 1), `TrainerSpriteImage` (Task 2), `PixelMenuButton` (Task 3).

O teste atual em `widget_test.dart` ("home screen lists every built-in
element") perde a premissa — os elementos saem da Home. Substituído por
`home_screen_test.dart`, seguindo o padrão de nome já usado pelas outras
telas (`training_screen_test.dart`, etc).

- [ ] **Step 1: Escrever o teste que falha**

```dart
// app/test/home_screen_test.dart
import 'package:app/ui/home_screen.dart';
import 'package:app/ui/multiplayer_lobby_screen.dart';
import 'package:app/ui/training_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the title and both menu buttons', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    expect(find.text('ELEMENTOS'), findsOneWidget);
    expect(find.text('MODO TREINO'), findsOneWidget);
    expect(find.text('MULTIPLAYER'), findsOneWidget);
  });

  testWidgets('MODO TREINO navigates to TrainingScreen', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    await tester.tap(find.text('MODO TREINO'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(TrainingScreen), findsOneWidget);
  });

  testWidgets('MULTIPLAYER navigates to MultiplayerLobbyScreen',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    await tester.tap(find.text('MULTIPLAYER'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(MultiplayerLobbyScreen), findsOneWidget);
  });
}
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `flutter test test/home_screen_test.dart` (dentro de `app/`)
Expected: FAIL — a `HomeScreen` atual não tem esse texto/esses botões.

- [ ] **Step 3: Implementar**

```dart
// app/lib/ui/home_screen.dart
import 'package:flutter/material.dart';

import '../game_presentation/pixel_arena_background.dart';
import '../game_presentation/pixel_menu_button.dart';
import '../game_presentation/trainer_sprite_image.dart';
import 'multiplayer_lobby_screen.dart';
import 'training_screen.dart';

/// Tela inicial de verdade: título + os dois personagens da batalha de
/// frente + botões pro Treino/Multiplayer, sobre o mesmo fundo pixelado
/// da arena de batalha. Ver
/// docs/superpowers/specs/2026-09-09-home-title-screen-design.md.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _BackdropPainter()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _title(),
                    const SizedBox(height: 8),
                    const Text(
                      'BATALHAS 1V1 POR COMBINAÇÃO',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        color: Color(0xFF2B2B2B),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TrainerSpriteImage(),
                        SizedBox(width: 12),
                        Text(
                          'VS',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: Color(0xFFF4C94A),
                          ),
                        ),
                        SizedBox(width: 12),
                        TrainerSpriteImage(mirror: true),
                      ],
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: 280,
                      child: PixelMenuButton(
                        label: 'MODO TREINO',
                        primary: true,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const TrainingScreen()),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: 280,
                      child: PixelMenuButton(
                        label: 'MULTIPLAYER',
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const MultiplayerLobbyScreen()),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _title() {
    const shadowColor = Color(0xFF2B2B2B);
    return Text(
      'ELEMENTOS',
      style: TextStyle(
        fontFamily: 'monospace',
        fontWeight: FontWeight.bold,
        fontSize: 40,
        letterSpacing: 4,
        color: const Color(0xFFF4F4E4),
        shadows: [
          for (final dx in [-2.0, 2.0])
            for (final dy in [-2.0, 2.0]) Shadow(offset: Offset(dx, dy), color: shadowColor),
          const Shadow(offset: Offset(3, 3), color: shadowColor),
        ],
      ),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) => drawArenaBackdrop(canvas, size);

  @override
  bool shouldRepaint(covariant _BackdropPainter oldDelegate) => false;
}
```

- [ ] **Step 4: Apagar o teste obsoleto**

```bash
git rm app/test/widget_test.dart
```

- [ ] **Step 5: Rodar e confirmar que o novo teste passa**

Run: `flutter test test/home_screen_test.dart`
Expected: PASS (3 testes)

- [ ] **Step 6: `flutter analyze`**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add app/lib/ui/home_screen.dart app/test/home_screen_test.dart
git commit -m "HomeScreen vira tela de título de verdade (era placeholder)"
```

---

## Task 5: Corrigir a navegação nos testes de `TrainingScreen`

**Files:**
- Modify: `app/test/training_screen_test.dart`

Três ocorrências de `find.byIcon(Icons.school)` (usadas pra navegar da
Home pro Treino) precisam virar `find.text('MODO TREINO')` — o ícone não
existe mais.

- [ ] **Step 1: Trocar as três ocorrências**

Nas três instâncias de:

```dart
      await tester.tap(find.byIcon(Icons.school));
```

trocar por:

```dart
      await tester.tap(find.text('MODO TREINO'));
```

(mantendo os `await tester.pump()`/`pump(const Duration(...))` logo depois
exatamente como já estão — só a linha do `tap` muda).

- [ ] **Step 2: Rodar os testes de `TrainingScreen`**

Run: `flutter test test/training_screen_test.dart`
Expected: PASS (todos os testes).

- [ ] **Step 3: `flutter analyze`**

Run: `flutter analyze`
Expected: `No issues found!` (se `Icons` ficar sem uso no arquivo depois
da troca, remover o import correspondente — rodar `flutter analyze` pra
confirmar se é o caso, não assumir).

- [ ] **Step 4: Commit**

```bash
git add app/test/training_screen_test.dart
git commit -m "Testes de TrainingScreen navegam pela Home via texto do botão novo"
```

---

## Task 6: Verificação manual, `DECISIONS.md` e `TASKS.md`

**Files:**
- Modify: `DECISIONS.md`
- Modify: `TASKS.md`

- [ ] **Step 1: Suíte completa**

Run: `flutter test` (dentro de `app/`)
Expected: PASS em todos os testes.

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 2: Rodar o app no Chrome e olhar a tela inicial de verdade**

```bash
cd app
flutter run -d web-server --web-port 5000
```

Confirmar: título "ELEMENTOS" com contorno legível, subtítulo, os dois
personagens de frente com "VS" entre eles, dois botões blocudos. Tocar em
"MODO TREINO" e confirmar que abre o Modo Treino normalmente; voltar,
tocar em "MULTIPLAYER" e confirmar que abre o Lobby normalmente. Ajustar
espaçamento/tamanho se algo ficar cortado ou desproporcional — é detalhe
de acabamento visual, não de arquitetura.

- [ ] **Step 3: Registrar a decisão em `DECISIONS.md`**

Adicionar ao final de `DECISIONS.md` (confirmar o número da próxima
decisão antes de escrever — não assumir):

```markdown

## DECISION-0XX
Data: 2026-09-09
Decisão: tela inicial de verdade (Bloco 3 da direção de produto) —
substitui a `HomeScreen` placeholder (lista crua dos 10 elementos, o
próprio código já dizia "Placeholder screen... Real screens... come in
later tasks") por uma tela de título estilo jogo de luta: fundo/
personagens pixel art reaproveitados da batalha, título com contorno,
dois botões blocudos pro Treino/Multiplayer.
Passos: `PixelArenaBackground` teve o desenho extraído pra uma função
pura `drawArenaBackdrop` (Flame e a tela inicial compartilham a mesma
fonte de verdade pro céu/chão). Novo `TrainerSpriteImage` reaproveita
`drawPixelGrid` fora do Flame, via `CustomPainter` puro (sem game loop,
decoração estática). Novo `PixelMenuButton`, mesmo espírito visual do
`BattleHudWidget`. O título usa `TextStyle.shadows` (vários `Shadow`
deslocados sem blur) pra simular contorno grosso, sem fonte nova. A
lista dos 10 elementos saiu de cena — elementos continuam sendo a
identidade do jogo dentro da batalha, não precisam de vitrine própria na
Home.
Motivo: Bloco 3 da nova direção de produto (game feel) — a Home era
literalmente o único lugar do app ainda sem nenhuma identidade visual,
sendo a primeira tela que o jogador vê.
Consequência: nenhuma lacuna nova — Treino/Multiplayer/Lobby/Skill Tree
continuam com o visual Material padrão (fora de escopo deste bloco,
prioridade "UI/UX" mais ampla fica pra um bloco futuro).
Testes: suíte completa do app (`flutter test`) e `flutter analyze`
passando depois da mudança. Verificado de ponta a ponta de verdade via
`flutter run -d web-server`: tela inicial renderizando título/
personagens/botões corretamente, navegação pros dois modos funcionando.
```

- [ ] **Step 4: Atualizar `TASKS.md`**

Na seção `# DONE`, adicionar ao final:

```
- Tela inicial de verdade (Bloco 3 da direção de produto): título com
  contorno, personagens pixel art de frente, botões blocudos pro Treino/
  Multiplayer — substitui o placeholder antigo (DECISION-0XX)
```

(usar o número real da decisão registrada no Step 3).

- [ ] **Step 5: Commit**

```bash
git add DECISIONS.md TASKS.md
git commit -m "Registra decisão e atualiza TASKS.md (tela inicial estilo jogo de luta)"
```

---

## Self-Review (feito ao escrever este plano)

- **Cobertura do spec:** "Fundo compartilhado" → Task 1; "Personagens
  decorativos" → Task 2; "Botão de menu" → Task 3; "Título em fonte
  pixel" e "HomeScreen (reescrita)" → Task 4; "Consequência nos testes
  existentes" → Tasks 4 e 5; "Testes esperados" e verificação manual →
  cobertos em cada task + Task 6. "O que NÃO está neste bloco" respeitado
  — nenhuma task toca `battle_engine`, `backend`, ou o visual das outras
  telas.
- **Placeholders:** nenhum "TBD" — todo step tem código completo ou
  comando exato.
- **Consistência de tipos:** `drawArenaBackdrop(Canvas, Size)` (Task 1)
  usado com essa assinatura exata no `_BackdropPainter` da Task 4.
  `TrainerSpriteImage`/`PixelMenuButton` (Tasks 2, 3) usados com os
  mesmos nomes de parâmetro (`mirror`, `label`, `onPressed`, `primary`)
  na `HomeScreen` (Task 4).
- **Achado durante o planejamento:** as três ocorrências de
  `find.byIcon(Icons.school)` em `training_screen_test.dart` e o teste
  inteiro de `widget_test.dart` dependiam da `HomeScreen` antiga — mapeadas
  explicitamente nas Tasks 4 e 5, não descobertas ao acaso durante a
  execução.
