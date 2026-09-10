# Animações + painel de seleção de elementos (Bloco 6) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dar "vida" ao jogo com três animações (sprites respirando, botões afundando ao toque, transição de tela em slide) e resolver a rolagem da tela de batalha movendo a lista de elementos pra um painel que sobe de baixo, reaproveitando o `PixelSheetPanel` do Bloco 5.

**Architecture:** Cada animação é uma peça isolada e pequena (um novo helper de rota, dois widgets que ganham estado de pressionado, um widget que ganha um `AnimationController`, um componente Flame que ganha um deslocamento senoidal), compostas depois nas telas existentes. O painel de seleção reaproveita `PixelSheetPanel`/`PixelElementChip`/`PixelMenuButton` já existentes — só muda onde e como são exibidos, não a lógica de seleção (`_toggleElement`).

**Tech Stack:** Flutter + Dart (`AnimatedContainer`, `AnimationController`, `PageRouteBuilder`), Flame (`update`/`render` do `BattleCharacterComponent`).

**Spec:** [docs/superpowers/specs/2026-09-10-animation-and-element-picker-design.md](../specs/2026-09-10-animation-and-element-picker-design.md)

## Global Constraints

- Nenhuma mudança em `battle_engine`, `backend`, `TrainingMatch`, `MultiplayerMatch` — puramente apresentação.
- Paleta fixa já estabelecida: borda/texto escuro `Color(0xFF2B2B2B)`, fundo "não selecionado"/creme `Color(0xFFF4F4E4)`, destaque/selecionado dourado `Color(0xFFF4C94A)`. Sem cores novas.
- Textos novos visíveis, exatamente estes: `'Escolher elementos'`, `'Confirmar'`, e o resumo (`'Elementos: 🔥 Fogo, 🌪️ Vento'` ou `'Nenhum elemento escolhido'`, gerado por `_selectedElementsSummary`).
- **Nunca usar `pumpAndSettle()` em teste que monta um widget com animação que repete infinitamente** (`TrainerSpriteImage`, `HomeScreen`) — trava esperando frames que nunca param de ser agendados. Usar sempre `pump()` + `pump(Duration(...))` manual.
- Todo teste que deixa montado um `TrainerSpriteImage` (direto ou via `HomeScreen`) até o fim precisa de `await tester.pumpWidget(const SizedBox());` como última linha, pra descartar o `AnimationController` — mesmo padrão já usado pros `Timer` de polling do Multiplayer (comentário `// dispose the poll Timer` já existente no código).
- Lição do Bloco 3, ainda válida: `flutter run -d web-server` **não** recompila em reload de página — só um `preview_stop`+`preview_start` novo pega mudanças de código Dart. Toda verificação manual deste plano reinicia o servidor, nunca só recarrega a aba.
- Cada task termina com `flutter analyze` limpo e `flutter test` verde antes do commit.

---

## Task 1: `pixelSlideRoute` (transição de tela em slide de baixo pra cima)

**Files:**
- Create: `app/lib/game_presentation/pixel_page_route.dart`
- Test: `app/test/game_presentation/pixel_page_route_test.dart`

**Interfaces:**
- Consumes: nada de outras tasks.
- Produces: `PageRouteBuilder<T> pixelSlideRoute<T>(WidgetBuilder builder)` — usado pela Task 6 nos 4 pontos de navegação.

- [ ] **Step 1: Write the failing test**

```dart
// app/test/game_presentation/pixel_page_route_test.dart
import 'package:app/game_presentation/pixel_page_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('pushes the built widget onto the navigator', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () {
            Navigator.of(context).push(
              pixelSlideRoute((_) => const Text('tela nova')),
            );
          },
          child: const Text('abrir'),
        ),
      ),
    ));

    await tester.tap(find.text('abrir'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('tela nova'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/game_presentation/pixel_page_route_test.dart`
Expected: FAIL — `pixel_page_route.dart` não existe ainda.

- [ ] **Step 3: Write minimal implementation**

```dart
// app/lib/game_presentation/pixel_page_route.dart
import 'package:flutter/material.dart';

/// Transição compartilhada por toda a navegação principal do jogo (Home →
/// Treino/Multiplayer, Lobby → Batalha, Revanche): a tela nova sobe de
/// baixo pra cima, mesmo espírito visual do `PixelSheetPanel` (um painel
/// de jogo entrando), em vez da transição genérica do `MaterialPageRoute`.
PageRouteBuilder<T> pixelSlideRoute<T>(WidgetBuilder builder) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final offsetAnimation = Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
      return SlideTransition(position: offsetAnimation, child: child);
    },
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/game_presentation/pixel_page_route_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/lib/game_presentation/pixel_page_route.dart app/test/game_presentation/pixel_page_route_test.dart
git commit -m "Adiciona pixelSlideRoute (transicao de tela em slide de baixo pra cima)"
```

---

## Task 2: `PixelMenuButton` afunda ao ser pressionado

**Files:**
- Modify: `app/lib/game_presentation/pixel_menu_button.dart` (arquivo inteiro)
- Test: `app/test/game_presentation/pixel_menu_button_test.dart`

**Interfaces:**
- Consumes: nada de outras tasks.
- Produces: `PixelMenuButton` continua com a mesma API pública (`label`, `onPressed`, `primary`) — nenhuma task depende de mudança de assinatura.

- [ ] **Step 1: Confirmar a suíte atual passa antes de mexer (baseline)**

Run: `cd app && flutter test test/game_presentation/pixel_menu_button_test.dart`
Expected: PASS (2 testes).

- [ ] **Step 2: Write the failing test**

Adicionar ao final de `app/test/game_presentation/pixel_menu_button_test.dart` (dentro do `main()`, depois dos dois testes existentes):

```dart
  testWidgets(
      'shows a pressed-in offset while held down, and releases it back',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PixelMenuButton(label: 'Jogar', onPressed: () {}),
      ),
    ));

    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Jogar')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    final pressed =
        tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
    expect(pressed.transform, Matrix4.translationValues(3, 3, 0));

    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    final released =
        tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
    expect(released.transform, Matrix4.translationValues(0, 0, 0));
  });
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd app && flutter test test/game_presentation/pixel_menu_button_test.dart`
Expected: FAIL — não existe nenhum `AnimatedContainer` no widget ainda (o `Container` atual não anima).

- [ ] **Step 4: Reescrever `PixelMenuButton` como `StatefulWidget` com feedback de toque**

Substituir todo o conteúdo de `app/lib/game_presentation/pixel_menu_button.dart` por:

```dart
import 'package:flutter/material.dart';

class PixelMenuButton extends StatefulWidget {
  const PixelMenuButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  State<PixelMenuButton> createState() => _PixelMenuButtonState();
}

class _PixelMenuButtonState extends State<PixelMenuButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onPressed == null) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null;
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.4,
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          transform: Matrix4.translationValues(
            _pressed ? 3 : 0,
            _pressed ? 3 : 0,
            0,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: widget.primary
                ? const Color(0xFFF4C94A)
                : const Color(0xFFF4F4E4),
            border: Border.all(color: const Color(0xFF2B2B2B), width: 3),
            borderRadius: BorderRadius.circular(4),
            boxShadow: _pressed
                ? const []
                : const [
                    BoxShadow(color: Color(0xFF2B2B2B), offset: Offset(3, 3)),
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.label,
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
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2B2B2B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd app && flutter test test/game_presentation/pixel_menu_button_test.dart`
Expected: PASS (3 testes) — os 2 testes antigos continuam passando porque `tester.tap` simula um gesto completo (down+up), disparando `onTap` normalmente.

- [ ] **Step 6: `flutter analyze`**

Run: `cd app && flutter analyze`
Expected: "No issues found!"

- [ ] **Step 7: Commit**

```bash
git add app/lib/game_presentation/pixel_menu_button.dart app/test/game_presentation/pixel_menu_button_test.dart
git commit -m "PixelMenuButton afunda visualmente ao ser pressionado"
```

---

## Task 3: `PixelElementChip` afunda ao ser pressionado

**Files:**
- Modify: `app/lib/game_presentation/pixel_element_chip.dart` (arquivo inteiro)
- Test: `app/test/game_presentation/pixel_element_chip_test.dart`

**Interfaces:**
- Consumes: nada de outras tasks.
- Produces: `PixelElementChip` continua com a mesma API pública (`label`, `selected`, `onTap`).

- [ ] **Step 1: Confirmar a suíte atual passa antes de mexer (baseline)**

Run: `cd app && flutter test test/game_presentation/pixel_element_chip_test.dart`
Expected: PASS (2 testes).

- [ ] **Step 2: Write the failing test**

Adicionar ao final de `app/test/game_presentation/pixel_element_chip_test.dart`:

```dart
  testWidgets(
      'shows a pressed-in offset while held down, and releases it back',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PixelElementChip(
          label: '🔥 Fogo',
          selected: false,
          onTap: () {},
        ),
      ),
    ));

    final gesture =
        await tester.startGesture(tester.getCenter(find.text('🔥 Fogo')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    final pressed =
        tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
    expect(pressed.transform, Matrix4.translationValues(3, 3, 0));

    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    final released =
        tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
    expect(released.transform, Matrix4.translationValues(0, 0, 0));
  });
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd app && flutter test test/game_presentation/pixel_element_chip_test.dart`
Expected: FAIL — não existe `AnimatedContainer` ainda.

- [ ] **Step 4: Reescrever `PixelElementChip` como `StatefulWidget` com feedback de toque**

Substituir todo o conteúdo de `app/lib/game_presentation/pixel_element_chip.dart` por:

```dart
import 'package:flutter/material.dart';

class PixelElementChip extends StatefulWidget {
  const PixelElementChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  State<PixelElementChip> createState() => _PixelElementChipState();
}

class _PixelElementChipState extends State<PixelElementChip> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onTap == null) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onTap != null;
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.4,
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          transform: Matrix4.translationValues(
            _pressed ? 3 : 0,
            _pressed ? 3 : 0,
            0,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.selected
                ? const Color(0xFFF4C94A)
                : const Color(0xFFF4F4E4),
            border: Border.all(color: const Color(0xFF2B2B2B), width: 3),
            borderRadius: BorderRadius.circular(4),
            boxShadow: _pressed
                ? const []
                : const [
                    BoxShadow(color: Color(0xFF2B2B2B), offset: Offset(3, 3)),
                  ],
          ),
          child: Text(
            widget.label,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF2B2B2B),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd app && flutter test test/game_presentation/pixel_element_chip_test.dart`
Expected: PASS (3 testes).

- [ ] **Step 6: `flutter analyze`**

Run: `cd app && flutter analyze`
Expected: "No issues found!"

- [ ] **Step 7: Commit**

```bash
git add app/lib/game_presentation/pixel_element_chip.dart app/test/game_presentation/pixel_element_chip_test.dart
git commit -m "PixelElementChip afunda visualmente ao ser pressionado"
```

---

## Task 4: `TrainerSpriteImage` ganha idle (balanço vertical sutil)

**Files:**
- Modify: `app/lib/game_presentation/trainer_sprite_image.dart` (arquivo inteiro)
- Modify: `app/test/game_presentation/trainer_sprite_image_test.dart`
- Modify: `app/test/home_screen_test.dart`

**Interfaces:**
- Consumes: nada de outras tasks.
- Produces: `TrainerSpriteImage` continua com a mesma API pública (`mirror`, `size`).

- [ ] **Step 1: Confirmar a suíte atual passa antes de mexer (baseline)**

Run: `cd app && flutter test test/game_presentation/trainer_sprite_image_test.dart test/home_screen_test.dart`
Expected: PASS (1 + 3 = 4 testes).

- [ ] **Step 2: Reescrever `TrainerSpriteImage` como `StatefulWidget` com idle**

Substituir todo o conteúdo de `app/lib/game_presentation/trainer_sprite_image.dart` por:

```dart
import 'package:flutter/material.dart';

import 'pixel_sprite.dart';

/// Um dos dois personagens da batalha, desenhado fora do Flame — usado
/// como decoração estática (ex: tela inicial). Reaproveita [drawPixelGrid]
/// direto: `CustomPainter.paint` já entrega o mesmo `Canvas` que
/// [drawPixelGrid] espera, sem adaptação nenhuma. Balança sutilmente no
/// eixo Y (idle) pra parecer vivo — ver
/// docs/superpowers/specs/2026-09-10-animation-and-element-picker-design.md.
class TrainerSpriteImage extends StatefulWidget {
  const TrainerSpriteImage({
    super.key,
    this.mirror = false,
    this.size = const Size(96, 120),
  });

  final bool mirror;
  final Size size;

  @override
  State<TrainerSpriteImage> createState() => _TrainerSpriteImageState();
}

class _TrainerSpriteImageState extends State<TrainerSpriteImage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);
  late final Animation<double> _idleOffset = Tween<double>(begin: -2, end: 2)
      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _idleOffset,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _idleOffset.value),
          child: child,
        );
      },
      child: Transform.flip(
        flipX: widget.mirror,
        child: CustomPaint(
          size: widget.size,
          painter: _TrainerSpritePainter(
            widget.mirror ? pixelPaletteRight : pixelPaletteLeft,
          ),
        ),
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

- [ ] **Step 3: Run test to verify it fails (timer/ticker pendente)**

Run: `cd app && flutter test test/game_presentation/trainer_sprite_image_test.dart test/home_screen_test.dart`
Expected: FAIL — os 4 testes passam na asserção em si, mas o `test` framework reporta erro de "A Timer is still pending" (ou ticker não descartado) porque agora existe um `AnimationController` repetindo que nenhum teste descarta.

- [ ] **Step 4: Adicionar a linha de dispose no teste de `TrainerSpriteImage`**

Em `app/test/game_presentation/trainer_sprite_image_test.dart`, adicionar uma linha ao final do `testWidgets`:

```dart
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

    await tester.pumpWidget(const SizedBox()); // dispose the idle AnimationController
  });
}
```

- [ ] **Step 5: Adicionar a linha de dispose nos 3 testes de `home_screen_test.dart`**

Substituir todo o conteúdo de `app/test/home_screen_test.dart` por:

```dart
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

    await tester.pumpWidget(const SizedBox()); // dispose the idle AnimationControllers
  });

  testWidgets('MODO TREINO navigates to TrainingScreen', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    await tester.tap(find.text('MODO TREINO'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(TrainingScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox()); // dispose the idle AnimationControllers
  });

  testWidgets('MULTIPLAYER navigates to MultiplayerLobbyScreen',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    await tester.tap(find.text('MULTIPLAYER'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(MultiplayerLobbyScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox()); // dispose the idle AnimationControllers
  });
}
```

- [ ] **Step 6: Run test to verify it passes**

Run: `cd app && flutter test test/game_presentation/trainer_sprite_image_test.dart test/home_screen_test.dart`
Expected: PASS (4 testes), sem erro de timer/ticker pendente.

- [ ] **Step 7: `flutter analyze`**

Run: `cd app && flutter analyze`
Expected: "No issues found!"

- [ ] **Step 8: Commit**

```bash
git add app/lib/game_presentation/trainer_sprite_image.dart app/test/game_presentation/trainer_sprite_image_test.dart app/test/home_screen_test.dart
git commit -m "TrainerSpriteImage balanca sutilmente (idle)"
```

---

## Task 5: `BattleCharacterComponent` ganha idle bob (Flame)

**Files:**
- Modify: `app/lib/game_presentation/battle_character_component.dart:19-96`
- Test: `app/test/game_presentation/battle_character_component_test.dart`

**Interfaces:**
- Consumes: nada de outras tasks.
- Produces: nenhuma API pública nova — `BattleCharacterComponent` continua com a mesma interface (`side`, `position`, `playHitEffect()`, `playPreparationPulse()`, `isPlayingHitEffect`, `isPlayingPreparationPulse`).

- [ ] **Step 1: Confirmar a suíte atual passa antes de mexer (baseline)**

Run: `cd app && flutter test test/game_presentation/battle_character_component_test.dart`
Expected: PASS (5 testes).

- [ ] **Step 2: Ajustar o teste de shake e adicionar o teste de idle bob**

Substituir todo o conteúdo de `app/test/game_presentation/battle_character_component_test.dart` por:

```dart
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

    test('the shake offsets position.x during the effect and restores it after',
        () {
      final basePosition = Vector2(100, 200);
      final component = BattleCharacterComponent(
        side: BattleSide.left,
        position: basePosition.clone(),
      );

      component.playHitEffect();
      component.update(0.07);
      expect(component.position.x, isNot(equals(basePosition.x)));

      component.update(0.5);
      expect(component.position.x, equals(basePosition.x));
    });

    test(
        'the idle bob moves position.y sinusoidally around the base '
        'position, independent of the shake', () {
      final basePosition = Vector2(100, 200);
      final component = BattleCharacterComponent(
        side: BattleSide.left,
        position: basePosition.clone(),
      );

      component.update(0.4); // 1/4 do ciclo de 1.6s: seno no pico (+1)
      expect(component.position.y, closeTo(202.0, 0.0001));

      component.update(0.4); // 1/2 do ciclo: seno de volta a 0
      expect(component.position.y, closeTo(200.0, 0.0001));

      component.update(0.4); // 3/4 do ciclo: seno no fundo (-1)
      expect(component.position.y, closeTo(198.0, 0.0001));
    });

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
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd app && flutter test test/game_presentation/battle_character_component_test.dart`
Expected: FAIL — o teste de idle bob espera `position.y` variando, mas `update` ainda não produz nenhum deslocamento em Y fora do efeito de dano.

- [ ] **Step 4: Adicionar o idle bob em `update`**

Em `app/lib/game_presentation/battle_character_component.dart`, substituir:

```dart
  static const double _hitEffectDuration = 0.3;
  static const double _prepPulseDuration = 0.15;

  double _hitEffectRemaining = 0;
  double _prepPulseRemaining = 0;
```

por:

```dart
  static const double _hitEffectDuration = 0.3;
  static const double _prepPulseDuration = 0.15;
  static const double _idleBobAmplitude = 2.0;
  static const double _idleBobPeriodSeconds = 1.6;

  double _hitEffectRemaining = 0;
  double _prepPulseRemaining = 0;
  double _idleTime = 0;
```

E substituir todo o método `update`:

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
  }
```

por:

```dart
  @override
  void update(double dt) {
    super.update(dt);
    _idleTime += dt;
    final idleBobY = math.sin(_idleTime / _idleBobPeriodSeconds * 2 * math.pi) *
        _idleBobAmplitude;

    if (_hitEffectRemaining <= 0) {
      position.setValues(_basePosition.x, _basePosition.y + idleBobY);
    } else {
      _hitEffectRemaining = (_hitEffectRemaining - dt).clamp(0, _hitEffectDuration);
      final progress = _hitEffectRemaining / _hitEffectDuration;
      final shakeX = math.sin(progress * math.pi * 6) * 4 * progress;
      position.setValues(_basePosition.x + shakeX, _basePosition.y + idleBobY);
    }

    if (_prepPulseRemaining > 0) {
      _prepPulseRemaining = (_prepPulseRemaining - dt).clamp(0, _prepPulseDuration);
    }
  }
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd app && flutter test test/game_presentation/battle_character_component_test.dart`
Expected: PASS (6 testes).

- [ ] **Step 6: `flutter analyze`**

Run: `cd app && flutter analyze`
Expected: "No issues found!"

- [ ] **Step 7: Commit**

```bash
git add app/lib/game_presentation/battle_character_component.dart app/test/game_presentation/battle_character_component_test.dart
git commit -m "BattleCharacterComponent ganha idle bob (balanco sutil em Y)"
```

---

## Task 6: Navegação principal usa `pixelSlideRoute`

**Files:**
- Modify: `app/lib/ui/home_screen.dart:1-8` (imports), `:67-83` (os dois `Navigator.push`)
- Modify: `app/lib/ui/multiplayer_lobby_screen.dart:1-11` (imports), `:95-98` (`_run`)
- Modify: `app/lib/ui/multiplayer_battle_screen.dart:1-18` (imports), `:132-135` (`_startRematch`)
- Test: nenhum arquivo de teste muda (ver spec, seção 3 — `find.text`/`find.byType` não dependem da transição).

**Interfaces:**
- Consumes: `pixelSlideRoute<T>(WidgetBuilder builder)` (Task 1).
- Produces: nada consumido por outras tasks.

- [ ] **Step 1: Confirmar a suíte atual passa antes de mexer (baseline)**

Run: `cd app && flutter test test/home_screen_test.dart test/multiplayer_lobby_screen_test.dart test/multiplayer_battle_screen_test.dart`
Expected: PASS (4 + 5 + 3 = 12 testes).

- [ ] **Step 2: `home_screen.dart` — import e os dois `Navigator.push`**

Em `app/lib/ui/home_screen.dart`, adicionar o import (ordem alfabética, entre `pixel_outlined_text.dart` e `trainer_sprite_image.dart`):

```dart
import '../game_presentation/pixel_arena_background.dart';
import '../game_presentation/pixel_menu_button.dart';
import '../game_presentation/pixel_outlined_text.dart';
import '../game_presentation/pixel_page_route.dart';
import '../game_presentation/trainer_sprite_image.dart';
```

Substituir:

```dart
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const TrainingScreen()),
                          );
                        },
```

por:

```dart
                        onPressed: () {
                          Navigator.of(context).push(
                            pixelSlideRoute((_) => const TrainingScreen()),
                          );
                        },
```

E substituir:

```dart
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const MultiplayerLobbyScreen()),
                          );
                        },
```

por:

```dart
                        onPressed: () {
                          Navigator.of(context).push(
                            pixelSlideRoute((_) => const MultiplayerLobbyScreen()),
                          );
                        },
```

- [ ] **Step 3: `multiplayer_lobby_screen.dart` — import e `_run`**

Em `app/lib/ui/multiplayer_lobby_screen.dart`, adicionar o import (ordem alfabética, entre `pixel_outlined_text.dart` e `pixel_text_field.dart`):

```dart
import '../game_presentation/pixel_arena_background.dart';
import '../game_presentation/pixel_content_panel.dart';
import '../game_presentation/pixel_menu_button.dart';
import '../game_presentation/pixel_outlined_text.dart';
import '../game_presentation/pixel_page_route.dart';
import '../game_presentation/pixel_text_field.dart';
```

Substituir:

```dart
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => MultiplayerBattleScreen(match: match)),
      );
```

por:

```dart
      await Navigator.of(context).push(
        pixelSlideRoute((_) => MultiplayerBattleScreen(match: match)),
      );
```

- [ ] **Step 4: `multiplayer_battle_screen.dart` — import e `_startRematch`**

Em `app/lib/ui/multiplayer_battle_screen.dart`, adicionar o import (ordem alfabética, entre `pixel_outlined_text.dart` e `pixel_sheet_panel.dart`):

```dart
import '../game_presentation/pixel_content_panel.dart';
import '../game_presentation/pixel_element_chip.dart';
import '../game_presentation/pixel_menu_button.dart';
import '../game_presentation/pixel_outlined_text.dart';
import '../game_presentation/pixel_page_route.dart';
import '../game_presentation/pixel_sheet_panel.dart';
```

Substituir:

```dart
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => MultiplayerBattleScreen(match: rematch)),
      );
```

por:

```dart
      await Navigator.of(context).pushReplacement(
        pixelSlideRoute((_) => MultiplayerBattleScreen(match: rematch)),
      );
```

- [ ] **Step 5: Rodar a suíte e confirmar que continua verde sem nenhuma alteração de teste**

Run: `cd app && flutter test test/home_screen_test.dart test/multiplayer_lobby_screen_test.dart test/multiplayer_battle_screen_test.dart`
Expected: PASS (12 testes) — nenhum teste precisou mudar.

- [ ] **Step 6: `flutter analyze`**

Run: `cd app && flutter analyze`
Expected: "No issues found!"

- [ ] **Step 7: Commit**

```bash
git add app/lib/ui/home_screen.dart app/lib/ui/multiplayer_lobby_screen.dart app/lib/ui/multiplayer_battle_screen.dart
git commit -m "Navegacao principal usa pixelSlideRoute (slide de baixo pra cima)"
```

---

## Task 7: `TrainingScreen` — seletor de elementos vira painel

**Files:**
- Modify: `app/lib/ui/training_screen.dart:250-285` (`_buildPlayForm`, e dois métodos novos logo depois)
- Test: `app/test/training_screen_test.dart`

**Interfaces:**
- Consumes: `PixelSheetPanel` (já importado, Bloco 5), `PixelOutlinedText`/`PixelMenuButton`/`PixelElementChip` (já importados).
- Produces: nada consumido por outras tasks.

- [ ] **Step 1: Confirmar a suíte atual passa antes de mexer (baseline)**

Run: `cd app && flutter test test/training_screen_test.dart`
Expected: PASS (5 testes).

- [ ] **Step 2: Substituir `_buildPlayForm` e adicionar os dois métodos novos**

Em `app/lib/ui/training_screen.dart`, substituir o método `_buildPlayForm` inteiro:

```dart
  List<Widget> _buildPlayForm(BuildContext context) {
    final elements = const ElementCatalog().all();

    return [
      Text(
        'Escolha de 1 a 3 elementos:',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final element in elements)
            PixelElementChip(
              label: '${element.symbol} ${element.name}',
              selected: _selectedIds.contains(element.id),
              onTap: () => _toggleElement(element.id),
            ),
        ],
      ),
      const SizedBox(height: 16),
      PixelMenuButton(
        label: 'Jogar',
        onPressed: _selectedIds.isEmpty ? null : _playTurn,
      ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            _error!,
            style: const TextStyle(color: Colors.red),
          ),
        ),
    ];
  }
```

por:

```dart
  List<Widget> _buildPlayForm(BuildContext context) {
    final elements = const ElementCatalog().all();

    return [
      Text(_selectedElementsSummary(elements)),
      const SizedBox(height: 8),
      PixelMenuButton(
        label: 'Escolher elementos',
        onPressed: () => _openElementPicker(elements),
      ),
      const SizedBox(height: 16),
      PixelMenuButton(
        label: 'Jogar',
        onPressed: _selectedIds.isEmpty ? null : _playTurn,
      ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            _error!,
            style: const TextStyle(color: Colors.red),
          ),
        ),
    ];
  }

  String _selectedElementsSummary(List<ElementOption> elements) {
    final selected = elements.where((e) => _selectedIds.contains(e.id));
    if (selected.isEmpty) return 'Nenhum elemento escolhido';
    return 'Elementos: ${selected.map((e) => '${e.symbol} ${e.name}').join(', ')}';
  }

  void _openElementPicker(List<ElementOption> elements) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return PixelSheetPanel(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PixelOutlinedText(
                      'Escolha de 1 a 3 elementos',
                      fontSize: 18,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final element in elements)
                          PixelElementChip(
                            label: '${element.symbol} ${element.name}',
                            selected: _selectedIds.contains(element.id),
                            onTap: () {
                              _toggleElement(element.id);
                              setSheetState(() {});
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: PixelMenuButton(
                        label: 'Confirmar',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
```

- [ ] **Step 3: Ajustar `training_screen_test.dart` pros dois pontos que tocam chips**

Substituir todo o conteúdo de `app/test/training_screen_test.dart` por:

```dart
import 'package:app/game_domain/training_match.dart';
import 'package:app/game_presentation/pixel_menu_button.dart';
import 'package:app/main.dart';
import 'package:app/ui/training_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'selecting fire and wind then playing triggers Tempestade Ígnea and '
    'passes the turn to Jogador B',
    (WidgetTester tester) async {
      await tester.pumpWidget(const GameApp());

      await tester.tap(find.text('MODO TREINO'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Vez de: Jogador A'), findsOneWidget);

      await tester.tap(find.text('Escolher elementos'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('🔥 Fogo'));
      await tester.pump();
      await tester.tap(find.text('🌪️ Vento'));
      await tester.pump();

      await tester.tap(find.text('Confirmar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.ensureVisible(find.text('Jogar'));
      await tester.tap(find.text('Jogar'));
      await tester.pump();

      expect(find.text('Vez de: Jogador B'), findsOneWidget);
      expect(
        find.text('Última combinação: Tempestade Ígnea'),
        findsOneWidget,
      );
      expect(find.text('Descobertas: 1/3'), findsOneWidget);
      expect(find.textContaining('80/100 HP'), findsOneWidget);
    },
  );

  testWidgets('the play button is disabled until an element is selected',
      (WidgetTester tester) async {
    await tester.pumpWidget(const GameApp());

    await tester.tap(find.text('MODO TREINO'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final button = tester.widget<PixelMenuButton>(
      find.widgetWithText(PixelMenuButton, 'Jogar'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets(
    'unlocking Maestria da Brasa applies Queimadura to the opponent on the '
    'next action',
    (WidgetTester tester) async {
      await tester.pumpWidget(const GameApp());

      await tester.tap(find.text('MODO TREINO'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.byIcon(Icons.auto_awesome));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('Desbloquear').first);
      await tester.pump();

      await tester.tap(find.text('Fechar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('Escolher elementos'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('🔥 Fogo'));
      await tester.pump();

      await tester.tap(find.text('Confirmar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.ensureVisible(find.text('Jogar'));
      await tester.tap(find.text('Jogar'));
      await tester.pump();

      expect(
        find.text('Efeitos aplicados: Queimadura'),
        findsOneWidget,
      );
      expect(find.textContaining('Jogador B: Queimadura'), findsOneWidget);
    },
  );

  testWidgets(
    'shows the winner and a rematch button once the battle ends, hiding '
    'the play form',
    (WidgetTester tester) async {
      final match = TrainingMatch();
      for (var i = 0; i < 4; i++) {
        match.playElementIds(['fire', 'wind']); // Jogador A
        match.playElementIds(['ice']); // Jogador B, no damage
      }
      match.playElementIds(['fire', 'wind']); // 5th hit: defeats Jogador B
      expect(match.isOver, isTrue); // sanity check on the setup itself

      await tester.pumpWidget(
        MaterialApp(home: TrainingScreen(initialMatch: match)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('Vencedor: Jogador A'), findsOneWidget);
      expect(find.text('Nova partida'), findsOneWidget);
      expect(find.text('Jogar'), findsNothing);
    },
  );

  testWidgets('Nova partida starts a fresh match', (WidgetTester tester) async {
    final match = TrainingMatch();
    for (var i = 0; i < 4; i++) {
      match.playElementIds(['fire', 'wind']);
      match.playElementIds(['ice']);
    }
    match.playElementIds(['fire', 'wind']);

    await tester.pumpWidget(
      MaterialApp(home: TrainingScreen(initialMatch: match)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.ensureVisible(find.text('Nova partida'));
    await tester.tap(find.text('Nova partida'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Vez de: Jogador A'), findsOneWidget);
    expect(find.text('Jogar'), findsOneWidget);
  });
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/training_screen_test.dart`
Expected: PASS (5 testes).

- [ ] **Step 5: `flutter analyze`**

Run: `cd app && flutter analyze`
Expected: "No issues found!"

- [ ] **Step 6: Commit**

```bash
git add app/lib/ui/training_screen.dart app/test/training_screen_test.dart
git commit -m "TrainingScreen: selecao de elementos vira painel (PixelSheetPanel)"
```

---

## Task 8: `MultiplayerBattleScreen` — seletor de elementos vira painel

**Files:**
- Modify: `app/lib/ui/multiplayer_battle_screen.dart:301-362` (`_buildBattle`, e dois métodos novos logo depois)
- Test: `app/test/multiplayer_battle_screen_test.dart`

**Interfaces:**
- Consumes: `PixelSheetPanel`/`PixelOutlinedText`/`PixelMenuButton`/`PixelElementChip` (já importados).
- Produces: nada consumido por outras tasks.

- [ ] **Step 1: Confirmar a suíte atual passa antes de mexer (baseline)**

Run: `cd app && flutter test test/multiplayer_battle_screen_test.dart`
Expected: PASS (3 testes).

- [ ] **Step 2: Substituir `_buildBattle` e adicionar os dois métodos novos**

Em `app/lib/ui/multiplayer_battle_screen.dart`, substituir o método `_buildBattle` inteiro:

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
          lastAttack: _pendingAttack,
          leftLabel: 'Você',
          rightLabel: 'Oponente',
        ),
      ),
      const SizedBox(height: 16),
      Text(
        _match.isMyTurn ? 'Sua vez' : 'Vez do oponente',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 4),
      if (_match.activeFieldEffectIds.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Campo: ${_match.activeFieldEffectIds.map((id) => combinationCatalog.byId(id)?.name ?? id).join(", ")}',
          ),
        ),
      const Divider(height: 32),
      Text(
        'Escolha de 1 a 3 elementos:',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final element in elements)
            PixelElementChip(
              label: '${element.symbol} ${element.name}',
              selected: _selectedIds.contains(element.id),
              onTap: _match.isMyTurn ? () => _toggleElement(element.id) : null,
            ),
        ],
      ),
      const SizedBox(height: 16),
      PixelMenuButton(
        label: 'Jogar',
        onPressed: (_match.isMyTurn && _selectedIds.isNotEmpty) ? _playTurn : null,
      ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(_error!, style: const TextStyle(color: Colors.red)),
        ),
    ];
  }
```

por:

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
          lastAttack: _pendingAttack,
          leftLabel: 'Você',
          rightLabel: 'Oponente',
        ),
      ),
      const SizedBox(height: 16),
      Text(
        _match.isMyTurn ? 'Sua vez' : 'Vez do oponente',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 4),
      if (_match.activeFieldEffectIds.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Campo: ${_match.activeFieldEffectIds.map((id) => combinationCatalog.byId(id)?.name ?? id).join(", ")}',
          ),
        ),
      const Divider(height: 32),
      Text(_selectedElementsSummary(elements)),
      const SizedBox(height: 8),
      PixelMenuButton(
        label: 'Escolher elementos',
        onPressed: _match.isMyTurn ? () => _openElementPicker(elements) : null,
      ),
      const SizedBox(height: 16),
      PixelMenuButton(
        label: 'Jogar',
        onPressed: (_match.isMyTurn && _selectedIds.isNotEmpty) ? _playTurn : null,
      ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(_error!, style: const TextStyle(color: Colors.red)),
        ),
    ];
  }

  String _selectedElementsSummary(List<ElementOption> elements) {
    final selected = elements.where((e) => _selectedIds.contains(e.id));
    if (selected.isEmpty) return 'Nenhum elemento escolhido';
    return 'Elementos: ${selected.map((e) => '${e.symbol} ${e.name}').join(', ')}';
  }

  void _openElementPicker(List<ElementOption> elements) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return PixelSheetPanel(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PixelOutlinedText(
                      'Escolha de 1 a 3 elementos',
                      fontSize: 18,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final element in elements)
                          PixelElementChip(
                            label: '${element.symbol} ${element.name}',
                            selected: _selectedIds.contains(element.id),
                            onTap: _match.isMyTurn
                                ? () {
                                    _toggleElement(element.id);
                                    setSheetState(() {});
                                  }
                                : null,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: PixelMenuButton(
                        label: 'Confirmar',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
```

- [ ] **Step 3: Ajustar `multiplayer_battle_screen_test.dart` pro teste que tenta jogar fora da vez**

Em `app/test/multiplayer_battle_screen_test.dart`, substituir:

```dart
      // beto plays out of turn (ana's turn) — the backend mock above only
      // answers /turns with a state where it's ana's turn again, mimicking
      // ana having just played fire+wind against beto.
      await tester.tap(find.text('🔥 Fogo'));
      await tester.pump();
      await tester.tap(find.text('🌪️ Vento'));
      await tester.pump();

      // Play button is disabled: it's not beto's turn.
      final playButton = tester.widget<PixelMenuButton>(
        find.widgetWithText(PixelMenuButton, 'Jogar'),
      );
      expect(playButton.onPressed, isNull);
```

por:

```dart
      // beto can't even open the element picker out of turn (ana's turn) —
      // "Escolher elementos" is disabled, same as "Jogar".
      final pickerButton = tester.widget<PixelMenuButton>(
        find.widgetWithText(PixelMenuButton, 'Escolher elementos'),
      );
      expect(pickerButton.onPressed, isNull);

      // Play button is disabled: it's not beto's turn.
      final playButton = tester.widget<PixelMenuButton>(
        find.widgetWithText(PixelMenuButton, 'Jogar'),
      );
      expect(playButton.onPressed, isNull);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/multiplayer_battle_screen_test.dart`
Expected: PASS (3 testes).

- [ ] **Step 5: `flutter analyze`**

Run: `cd app && flutter analyze`
Expected: "No issues found!"

- [ ] **Step 6: Commit**

```bash
git add app/lib/ui/multiplayer_battle_screen.dart app/test/multiplayer_battle_screen_test.dart
git commit -m "MultiplayerBattleScreen: selecao de elementos vira painel (PixelSheetPanel)"
```

---

## Task 9: Suíte completa, verificação manual e registro da decisão

**Files:**
- Modify: `DECISIONS.md` (nova `## DECISION-036`)
- Modify: `TASKS.md` (linha `DONE` nova)

**Interfaces:**
- Consumes: tudo das Tasks 1-8.
- Produces: nada (última task do bloco).

- [ ] **Step 1: Rodar a suíte completa do app**

Run: `cd app && flutter test`
Expected: PASS — 104 testes no total (100 já existentes + 1 `pixelSlideRoute` + 1 `PixelMenuButton` pressionado + 1 `PixelElementChip` pressionado + 1 idle bob do `BattleCharacterComponent`).

- [ ] **Step 2: `flutter analyze` na árvore final**

Run: `cd app && flutter analyze`
Expected: "No issues found!"

- [ ] **Step 3: Verificação manual no navegador**

Reiniciar o servidor de preview do zero (parar o processo anterior se algum
estiver rodando e iniciar de novo — **não** só recarregar a aba, lição do
Bloco 3):

1. Abrir a Home: observar os dois personagens balançando sutilmente
   (idle). Tocar em "MODO TREINO": a tela desliza de baixo pra cima.
2. Segurar o clique num botão (ex: "Escolher elementos") e observar a
   sombra sumir e o conteúdo deslocar enquanto pressionado, voltando ao
   soltar.
3. Tocar "Escolher elementos": o painel sobe de baixo mostrando os 10
   elementos. Selecionar Fogo e Vento (dourado ao selecionar), tocar
   "Confirmar" — o painel desce e a tela principal mostra "Elementos: 🔥
   Fogo, 🌪️ Vento".
4. Jogar o turno: confirmar que a sequência de ataque (Bloco 1) ainda
   funciona normalmente, com os personagens continuando a balançar (idle)
   por cima do shake/pulso da sequência.
5. Ir pro Multiplayer → Lobby → criar uma partida real contra o backend do
   Render, confirmar que a navegação Lobby → Batalha também desliza de
   baixo pra cima e que o painel de elementos funciona igual lá.
6. Checar o console do navegador: zero erros.

- [ ] **Step 4: Registrar `DECISION-036` em `DECISIONS.md`**

Adicionar ao final do arquivo, seguindo o formato das decisões anteriores:

```markdown
## DECISION-036
Data: 2026-09-10
Decisão: animações (Bloco 6 da direção de produto) — sprites com idle
(balanço vertical sutil na Home e na cena de batalha), botões/chips
afundando ao toque, transição de tela em slide de baixo pra cima — mais a
lista de elementos saindo do corpo da tela e virando um painel que sobe de
baixo (`PixelSheetPanel`, mesmo do Bloco 5), resolvendo a rolagem que a
lista sempre visível causava em Treino e Multiplayer.
Passos: `TrainerSpriteImage` e `BattleCharacterComponent` ganharam um
deslocamento senoidal em Y (2px de amplitude, ciclo de 1.6s) — o primeiro
via `AnimationController`/`AnimatedBuilder`, o segundo somado direto no
`update()` do componente Flame, sem conflitar com o shake de dano (só X) ou
o pulso de preparação (só escala) que já existiam. `PixelMenuButton` e
`PixelElementChip` viraram `StatefulWidget`, com `AnimatedContainer`
reagindo a `onTapDown`/`onTapUp`/`onTapCancel` (sombra some, conteúdo
desloca 3px). Novo `pixelSlideRoute` (`PageRouteBuilder` com
`SlideTransition`, 300ms) substitui `MaterialPageRoute` nas 4 navegações
principais. `TrainingScreen`/`MultiplayerBattleScreen` ganharam
`_openElementPicker`/`_selectedElementsSummary` — a lista de chips agora só
aparece dentro do painel, aberto por um botão "Escolher elementos"
(desabilitado fora da vez no Multiplayer, mesma condição que os chips já
tinham); a tela principal mostra só o resumo do que foi escolhido.
Motivo: Bloco 6 da nova direção de produto (game feel) — "animações" era o
próximo item sem bloco dedicado na ordem de prioridade; o painel de
elementos entrou no mesmo bloco por resolver, com a mesma peça visual
(painel subindo), um problema de UX real apontado pelo usuário (rolagem
causada pela lista de elementos sempre visível).
Consequência: nenhuma lacuna nova conhecida. Testes que montam
`TrainerSpriteImage`/`HomeScreen` agora precisam descartar o
`AnimationController` explicitamente no final (`pumpWidget(SizedBox())`) —
documentado como constraint pra blocos futuros que touch essas telas.
Testes: suíte completa do app (`flutter test`, 104 testes) e `flutter
analyze` passando. Verificado de ponta a ponta de verdade via `flutter run
-d web-server` (servidor reiniciado, não só recarregado): idle nos
personagens da Home e da batalha, "afundar" ao segurar um botão, painel de
elementos abrindo/fechando com seleção e confirmação reais, jogada completa
com a sequência de ataque do Bloco 1 ainda funcionando, transição em slide
entre Home/Treino/Multiplayer/Lobby, criação de partida real no Multiplayer
contra o backend no Render, zero erros no console.
```

- [ ] **Step 5: Atualizar `TASKS.md`**

Adicionar ao final da seção `# DONE`:

```markdown
- Animações + painel de seleção de elementos (Bloco 6 da direção de
  produto): idle nos sprites (Home e batalha), botões/chips afundando ao
  toque, transição de tela em slide de baixo pra cima, e a lista de
  elementos virando um painel (`PixelSheetPanel`) em vez de ficar sempre
  visível — resolve a rolagem em Treino e Multiplayer (DECISION-036)
```

- [ ] **Step 6: Commit**

```bash
git add DECISIONS.md TASKS.md
git commit -m "Registra DECISION-036 e atualiza TASKS.md (animacoes e painel de elementos)"
```

- [ ] **Step 7: Finalizar o bloco**

Announce: "I'm using the finishing-a-development-branch skill to complete this work."
**REQUIRED SUB-SKILL:** Use superpowers:finishing-a-development-branch — rodar a suíte final, apresentar as opções, executar a escolha do usuário.

---

## Self-Review

**1. Cobertura da spec:** Seção "1. Sprites vivos" → Tasks 4 (`TrainerSpriteImage`) e 5 (`BattleCharacterComponent`), incluindo o ajuste do teste de shake pra `.x` e o novo teste de idle bob determinístico (valores exatos calculados a partir de amplitude 2.0/período 1.6s). Seção "2. Botões afundando" → Tasks 2 e 3, com teste de `startGesture`/`AnimatedContainer.transform` em ambos. Seção "3. Transições de tela" → Tasks 1 (helper) e 6 (os 4 pontos de uso), com a justificativa explícita de por que nenhum teste muda. Seção "4. Seletor de elementos vira painel" → Tasks 7 e 8, com os ajustes exatos de `training_screen_test.dart` (2 pontos) e `multiplayer_battle_screen_test.dart` (1 ponto, virando uma checagem de botão desabilitado em vez de taps inertes). Nenhuma decisão da spec ficou sem task.

**2. Placeholder scan:** Nenhum "TBD"/"implementar depois" — todo código é completo e colável direto, inclusive os arquivos de teste inteiros reescritos (Tasks 4, 7) pra evitar ambiguidade sobre onde cada linha nova entra.

**3. Consistência de tipos:** `pixelSlideRoute<T>(WidgetBuilder builder)` (Task 1) usado identicamente nos 4 call sites da Task 6. `_selectedElementsSummary(List<ElementOption> elements)`/`_openElementPicker(List<ElementOption> elements)` (Tasks 7/8) — mesma assinatura nas duas telas, mesmo texto de retorno (`'Elementos: ...'`/`'Nenhum elemento escolhido'`), mesmo padrão de `PixelSheetPanel`/`StatefulBuilder`/`setSheetState` já estabelecido pelo modal de Skill Tree (Bloco 5). Cores/durações (3px de deslocamento, sombra vazia ao pressionar, 80ms) idênticas entre `PixelMenuButton` e `PixelElementChip` (Tasks 2/3). Amplitude/período do idle (2px/1.6s) idênticos entre `TrainerSpriteImage` (Task 4) e `BattleCharacterComponent` (Task 5), conforme a spec pediu explicitamente.
