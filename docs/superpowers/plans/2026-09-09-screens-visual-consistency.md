# Vestir Treino/Multiplayer/Lobby no Estilo Pixel Art (Bloco 4) — Plano de Implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dar à `TrainingScreen`, `MultiplayerLobbyScreen` e `MultiplayerBattleScreen` a mesma identidade visual da Home (fundo pixelado, título com contorno, botões blocudos) sem mudar nenhuma lógica, regra ou texto existente.

**Architecture:** Duas peças novas reutilizáveis (`PixelOutlinedText`, `PixelContentPanel`) mais duas extrações do que já existe (`ArenaBackdropPainter` público, `PixelMenuButton` com estado desabilitado). Cada tela vira um `Stack` (fundo pixelado atrás, `Scaffold` transparente na frente — mesmo padrão já usado pela Home desde o Bloco 3) com o conteúdo existente envolto num painel "cartão" pra continuar legível. Nenhuma mudança em `battle_engine`, `backend`, `TrainingMatch`/`MultiplayerMatch`, nem nos widgets fora de escopo (`FilterChip`, `TextField`, conteúdo do modal de Skill Tree).

**Tech Stack:** Flutter + Dart. Sem dependências novas, sem asset novo.

**Spec:** [docs/superpowers/specs/2026-09-09-screens-visual-consistency-design.md](../specs/2026-09-09-screens-visual-consistency-design.md)

## Global Constraints

- R$ 0 de custo: nada de asset/fonte nova, nada de chamada externa.
- `battle_engine`, `backend/src/battle-rules/`, `TrainingMatch`,
  `MultiplayerMatch` NÃO são tocados.
- `FilterChip`, `TextField`, o conteúdo do modal de Skill Tree
  (`ListTile`/`TextButton` de "Desbloquear"/"Fechar") NÃO mudam — continuam
  Material padrão.
- **Nenhum texto/rótulo visível muda** — só o widget por trás de cada um
  (isso preserva testes existentes que procuram texto exato, ex.:
  `find.text('Multiplayer')`).
- Lição da verificação manual do Bloco 3: um `flutter run -d web-server`
  já aberto NÃO recompila sozinho num simples reload de página — sempre
  reiniciar o servidor (`preview_stop` + `preview_start`) antes de
  verificar uma mudança nova, não só recarregar a aba.
- Cada task termina com `flutter analyze` e `flutter test` (dentro de
  `app/`) passando antes do commit.

---

## Task 1: `ArenaBackdropPainter` pública

**Files:**
- Modify: `app/lib/game_presentation/pixel_arena_background.dart`
- Modify: `app/test/game_presentation/pixel_arena_background_test.dart`
- Modify: `app/lib/ui/home_screen.dart`

**Interfaces:**
- Produces: `class ArenaBackdropPainter extends CustomPainter` (chama
  `drawArenaBackdrop`, já existente). Consumida pelas Tasks 5, 6, 7.

- [ ] **Step 1: Escrever o teste que falha**

Adicionar ao `main()` existente de `pixel_arena_background_test.dart`:

```dart
  test('ArenaBackdropPainter never requests a repaint', () {
    final painter = ArenaBackdropPainter();
    expect(painter.shouldRepaint(painter), isFalse);
  });
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `flutter test test/game_presentation/pixel_arena_background_test.dart` (dentro de `app/`)
Expected: FAIL — `ArenaBackdropPainter` não existe.

- [ ] **Step 3: Implementar**

Em `app/lib/game_presentation/pixel_arena_background.dart`, adicionar o
import e a classe nova (entre `drawArenaBackdrop` e `PixelArenaBackground`):

```dart
import 'package:flutter/rendering.dart' show CustomPainter;
```

```dart
/// `CustomPainter` que desenha [drawArenaBackdrop] — reaproveitado como
/// fundo de qualquer tela Flutter fora do Flame (Home, Treino,
/// Multiplayer). Ver
/// docs/superpowers/specs/2026-09-09-screens-visual-consistency-design.md.
class ArenaBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) => drawArenaBackdrop(canvas, size);

  @override
  bool shouldRepaint(covariant ArenaBackdropPainter oldDelegate) => false;
}
```

Em `app/lib/ui/home_screen.dart`, trocar `CustomPaint(painter:
_BackdropPainter())` por `CustomPaint(painter: ArenaBackdropPainter())`, e
apagar a classe `_BackdropPainter` inteira (fica no arquivo compartilhado
agora). Adicionar o import (`../game_presentation/pixel_arena_background.dart`
já está importado nesse arquivo — nenhum import novo necessário).

- [ ] **Step 4: Rodar e confirmar que passa**

Run: `flutter test test/game_presentation/pixel_arena_background_test.dart`
Expected: PASS (2 testes)

Run: `flutter test test/home_screen_test.dart`
Expected: PASS (sem alteração de comportamento, só a origem da classe).

- [ ] **Step 5: `flutter analyze`**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add app/lib/game_presentation/pixel_arena_background.dart app/test/game_presentation/pixel_arena_background_test.dart app/lib/ui/home_screen.dart
git commit -m "ArenaBackdropPainter vira pública e reaproveitável fora da Home"
```

---

## Task 2: `PixelOutlinedText`

**Files:**
- Create: `app/lib/game_presentation/pixel_outlined_text.dart`
- Test: `app/test/game_presentation/pixel_outlined_text_test.dart`
- Modify: `app/lib/ui/home_screen.dart`

**Interfaces:**
- Produces: `class PixelOutlinedText extends StatelessWidget` com
  construtor `PixelOutlinedText(String text, {Key? key, double fontSize =
  40, Color color = const Color(0xFFF4F4E4)})`. Consumida pelas Tasks 5, 6,
  7 (títulos das telas).

- [ ] **Step 1: Escrever o teste que falha**

```dart
// app/test/game_presentation/pixel_outlined_text_test.dart
import 'package:app/game_presentation/pixel_outlined_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the given text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PixelOutlinedText('TESTE'))),
    );
    expect(find.text('TESTE'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `flutter test test/game_presentation/pixel_outlined_text_test.dart`
Expected: FAIL — arquivo não existe.

- [ ] **Step 3: Implementar**

```dart
// app/lib/game_presentation/pixel_outlined_text.dart
import 'package:flutter/material.dart';

/// Texto com contorno grosso simulado via `TextStyle.shadows` (vários
/// `Shadow`s deslocados, sem blur) — sem fonte pixel de verdade, sem asset
/// novo. Usado no título da Home (`fontSize` grande) e nos títulos das
/// outras telas (menor). Ver
/// docs/superpowers/specs/2026-09-09-screens-visual-consistency-design.md.
class PixelOutlinedText extends StatelessWidget {
  const PixelOutlinedText(
    this.text, {
    super.key,
    this.fontSize = 40,
    this.color = const Color(0xFFF4F4E4),
  });

  final String text;
  final double fontSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    const shadowColor = Color(0xFF2B2B2B);
    final outlineOffset = fontSize > 24 ? 2.0 : 1.5;
    final dropOffset = fontSize > 24 ? 3.0 : 2.0;
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'monospace',
        fontWeight: FontWeight.bold,
        fontSize: fontSize,
        letterSpacing: fontSize > 24 ? 4 : 1,
        color: color,
        shadows: [
          for (final dx in [-outlineOffset, outlineOffset])
            for (final dy in [-outlineOffset, outlineOffset])
              Shadow(offset: Offset(dx, dy), color: shadowColor),
          Shadow(offset: Offset(dropOffset, dropOffset), color: shadowColor),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Rodar e confirmar que passa**

Run: `flutter test test/game_presentation/pixel_outlined_text_test.dart`
Expected: PASS

- [ ] **Step 5: Trocar o título da Home pelo widget novo**

Em `app/lib/ui/home_screen.dart`: adicionar
`import '../game_presentation/pixel_outlined_text.dart';`, trocar a
chamada `_title()` no `build()` por `const PixelOutlinedText('ELEMENTOS')`,
e apagar o método privado `_title()` inteiro (não é mais usado).

- [ ] **Step 6: Rodar e confirmar que a Home continua passando**

Run: `flutter test test/home_screen_test.dart`
Expected: PASS (3 testes, sem alteração de comportamento).

- [ ] **Step 7: `flutter analyze`**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add app/lib/game_presentation/pixel_outlined_text.dart app/test/game_presentation/pixel_outlined_text_test.dart app/lib/ui/home_screen.dart
git commit -m "Adiciona PixelOutlinedText, reaproveitado pelo título da Home"
```

---

## Task 3: `PixelMenuButton` ganha estado desabilitado

**Files:**
- Modify: `app/lib/game_presentation/pixel_menu_button.dart`
- Modify: `app/test/game_presentation/pixel_menu_button_test.dart`

**Interfaces:**
- Produces: `PixelMenuButton.onPressed` passa de `VoidCallback` pra
  `VoidCallback?`. Consumida pelas Tasks 5, 6, 7 (botões condicionalmente
  desabilitados: "Jogar", "Revanche").

- [ ] **Step 1: Escrever o teste que falha**

Adicionar ao `main()` existente:

```dart
  testWidgets('does not throw and stays inert when onPressed is null',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: PixelMenuButton(label: 'Jogar', onPressed: null)),
    ));

    expect(find.text('Jogar'), findsOneWidget);

    await tester.tap(find.text('Jogar'));
    await tester.pump();
  });
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `flutter test test/game_presentation/pixel_menu_button_test.dart`
Expected: FAIL — `onPressed: null` não compila (`VoidCallback` não é
nullable ainda).

- [ ] **Step 3: Implementar**

```dart
// app/lib/game_presentation/pixel_menu_button.dart
class PixelMenuButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.4,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: primary ? const Color(0xFFF4C94A) : const Color(0xFFF4F4E4),
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

(o resto do arquivo — doc comment da classe — continua igual, só o tipo de
`onPressed` e o `Opacity` novo envolvendo o `GestureDetector` mudam).

- [ ] **Step 4: Rodar e confirmar que passa**

Run: `flutter test test/game_presentation/pixel_menu_button_test.dart`
Expected: PASS (2 testes)

- [ ] **Step 5: `flutter analyze`**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add app/lib/game_presentation/pixel_menu_button.dart app/test/game_presentation/pixel_menu_button_test.dart
git commit -m "PixelMenuButton aceita onPressed nulo (estado desabilitado)"
```

---

## Task 4: `PixelContentPanel`

**Files:**
- Create: `app/lib/game_presentation/pixel_content_panel.dart`
- Test: `app/test/game_presentation/pixel_content_panel_test.dart`

**Interfaces:**
- Produces: `class PixelContentPanel extends StatelessWidget` com
  construtor `PixelContentPanel({Key? key, required Widget child})`.
  Consumida pelas Tasks 5, 6, 7.

- [ ] **Step 1: Escrever o teste que falha**

```dart
// app/test/game_presentation/pixel_content_panel_test.dart
import 'package:app/game_presentation/pixel_content_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders its child', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: PixelContentPanel(child: Text('conteúdo'))),
    ));
    expect(find.text('conteúdo'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `flutter test test/game_presentation/pixel_content_panel_test.dart`
Expected: FAIL — arquivo não existe.

- [ ] **Step 3: Implementar**

```dart
// app/lib/game_presentation/pixel_content_panel.dart
import 'package:flutter/material.dart';

/// Painel "cartão" — fundo quase opaco, borda escura — pra manter o
/// conteúdo (texto, chips, campos) legível por cima do fundo pixelado da
/// arena. Mesmo espírito visual do `BattleHudWidget`/`PixelMenuButton`.
/// Ver docs/superpowers/specs/2026-09-09-screens-visual-consistency-design.md.
class PixelContentPanel extends StatelessWidget {
  const PixelContentPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xF2F4F4E4),
        border: Border.all(color: const Color(0xFF2B2B2B), width: 3),
        borderRadius: BorderRadius.circular(6),
      ),
      child: child,
    );
  }
}
```

- [ ] **Step 4: Rodar e confirmar que passa**

Run: `flutter test test/game_presentation/pixel_content_panel_test.dart`
Expected: PASS

- [ ] **Step 5: `flutter analyze`**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add app/lib/game_presentation/pixel_content_panel.dart app/test/game_presentation/pixel_content_panel_test.dart
git commit -m "Adiciona PixelContentPanel (painel cartão pro conteúdo existente)"
```

---

## Task 5: Vestir `TrainingScreen`

**Files:**
- Modify: `app/lib/ui/training_screen.dart`
- Modify: `app/test/training_screen_test.dart`

**Interfaces:**
- Consumes: `ArenaBackdropPainter` (Task 1), `PixelOutlinedText` (Task 2),
  `PixelMenuButton` (Task 3), `PixelContentPanel` (Task 4).

- [ ] **Step 1: Reescrever o arquivo**

```dart
// app/lib/ui/training_screen.dart
import 'package:flutter/material.dart';

import '../game_domain/attack_event.dart';
import '../game_domain/battle_scene_view.dart';
import '../game_domain/element_catalog.dart';
import '../game_domain/training_match.dart';
import '../game_presentation/battle_scene_widget.dart';
import '../game_presentation/pixel_arena_background.dart';
import '../game_presentation/pixel_content_panel.dart';
import '../game_presentation/pixel_menu_button.dart';
import '../game_presentation/pixel_outlined_text.dart';

/// Modo treino: batalha local, offline, hotseat — os dois lados jogados no
/// mesmo aparelho. Sem backend, sem multiplayer, sem IA. Cada jogador pode
/// desbloquear habilidades da Skill Tree na própria vez; o que já
/// desbloqueou se aplica automaticamente em toda ação que jogar depois (e,
/// no caso de bônus de HP, imediatamente). A partida termina quando o HP
/// de alguém chega a 0.
class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key, TrainingMatch? initialMatch})
      : _initialMatch = initialMatch;

  final TrainingMatch? _initialMatch;

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  late TrainingMatch _match = widget._initialMatch ?? TrainingMatch();
  final Set<String> _selectedIds = {};
  String? _error;
  AttackEvent? _pendingAttack;

  void _toggleElement(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else if (_selectedIds.length < 3) {
        _selectedIds.add(id);
      }
    });
  }

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

  void _startNewMatch() {
    setState(() {
      _match = TrainingMatch();
      _selectedIds.clear();
      _error = null;
    });
  }

  void _openSkillTree() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final available = _match.availableSkillNodesForCurrentPlayer;
            // Fixed height + Expanded list, so "Fechar" always stays at a
            // predictable spot regardless of how many nodes are available
            // (the list scrolls internally instead of pushing it off).
            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Habilidades de ${_match.currentTurnName}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: available.isEmpty
                          ? const Text('Nada novo para desbloquear agora.')
                          : ListView(
                              children: [
                                for (final node in available)
                                  ListTile(
                                    title: Text(
                                      '[${node.branch}] ${node.name}',
                                    ),
                                    subtitle: Text(node.description),
                                    trailing: TextButton(
                                      onPressed: () {
                                        setState(() {
                                          _match.unlockSkillForCurrentPlayer(
                                            node.id,
                                          );
                                        });
                                        setSheetState(() {});
                                      },
                                      child: const Text('Desbloquear'),
                                    ),
                                  ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Fechar'),
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: ArenaBackdropPainter())),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const PixelOutlinedText('Modo Treino', fontSize: 20),
            actions: [
              IconButton(
                icon: const Icon(Icons.auto_awesome),
                tooltip: 'Habilidades',
                onPressed: _openSkillTree,
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: PixelContentPanel(
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
                      lastAttack: _pendingAttack,
                      leftLabel: 'Jogador A',
                      rightLabel: 'Jogador B',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Vez de: ${_match.currentTurnName}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text('Jogador A: ${_statusSummary(_match.playerAStatusNames)}'),
                  Text('Jogador B: ${_statusSummary(_match.playerBStatusNames)}'),
                  const SizedBox(height: 4),
                  Text(
                    'Descobertas: ${_match.discoveredCount}/${_match.totalCombinationsCount}',
                  ),
                  if (_match.lastTriggeredCombinationName != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Última combinação: ${_match.lastTriggeredCombinationName}',
                      ),
                    ),
                  if (_match.lastAppliedStatusNames.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Efeitos aplicados: ${_match.lastAppliedStatusNames.join(", ")}',
                      ),
                    ),
                  if (_match.activeFieldEffectNames.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Campo: ${_match.activeFieldEffectNames.join(", ")}',
                      ),
                    ),
                  const Divider(height: 32),
                  if (_match.isOver)
                    ..._buildGameOver(context)
                  else
                    ..._buildPlayForm(context),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildGameOver(BuildContext context) {
    return [
      Text(
        'Fim de partida! Vencedor: ${_match.winnerName}',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 16),
      PixelMenuButton(
        label: 'Nova partida',
        onPressed: _startNewMatch,
      ),
    ];
  }

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
            FilterChip(
              label: Text('${element.symbol} ${element.name}'),
              selected: _selectedIds.contains(element.id),
              onSelected: (_) => _toggleElement(element.id),
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

  String _statusSummary(List<String> statusNames) {
    return statusNames.isEmpty ? 'sem estados' : statusNames.join(', ');
  }
}
```

- [ ] **Step 2: Corrigir o teste que procurava `ElevatedButton`**

Em `app/test/training_screen_test.dart`, adicionar o import:

```dart
import 'package:app/game_presentation/pixel_menu_button.dart';
```

E trocar, no teste `'the play button is disabled until an element is selected'`:

```dart
    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Jogar'),
    );
    expect(button.onPressed, isNull);
```

por:

```dart
    final button = tester.widget<PixelMenuButton>(
      find.widgetWithText(PixelMenuButton, 'Jogar'),
    );
    expect(button.onPressed, isNull);
```

- [ ] **Step 3: Rodar os testes de `TrainingScreen`**

Run: `flutter test test/training_screen_test.dart` (dentro de `app/`)
Expected: PASS (todos os 5 testes) — os demais já usam `find.text(...)`,
que não muda.

- [ ] **Step 4: `flutter analyze`**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add app/lib/ui/training_screen.dart app/test/training_screen_test.dart
git commit -m "Veste TrainingScreen no estilo pixel art (fundo, título, botões)"
```

---

## Task 6: Vestir `MultiplayerBattleScreen`

**Files:**
- Modify: `app/lib/ui/multiplayer_battle_screen.dart`
- Modify: `app/test/multiplayer_battle_screen_test.dart`

**Interfaces:**
- Consumes: `ArenaBackdropPainter` (Task 1), `PixelOutlinedText` (Task 2),
  `PixelMenuButton` (Task 3), `PixelContentPanel` (Task 4).

- [ ] **Step 1: Adicionar os imports**

```dart
import '../game_presentation/pixel_arena_background.dart';
import '../game_presentation/pixel_content_panel.dart';
import '../game_presentation/pixel_menu_button.dart';
import '../game_presentation/pixel_outlined_text.dart';
```

- [ ] **Step 2: Envolver o `Scaffold` num `Stack` com fundo pixelado**

Trocar:

```dart
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Partida ${_match.matchId ?? ""}'),
        actions: [
          if (_match.isInProgress)
            IconButton(
              icon: const Icon(Icons.auto_awesome),
              tooltip: 'Habilidades',
              onPressed: _openSkillTree,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_match.isWaitingForOpponent)
              ..._buildWaiting(context)
            else if (_match.isFinished)
              ..._buildGameOver(context)
            else
              ..._buildBattle(context),
          ],
        ),
      ),
    );
  }
```

por:

```dart
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: ArenaBackdropPainter())),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: PixelOutlinedText('Partida ${_match.matchId ?? ""}', fontSize: 20),
            actions: [
              if (_match.isInProgress)
                IconButton(
                  icon: const Icon(Icons.auto_awesome),
                  tooltip: 'Habilidades',
                  onPressed: _openSkillTree,
                ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: PixelContentPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_match.isWaitingForOpponent)
                    ..._buildWaiting(context)
                  else if (_match.isFinished)
                    ..._buildGameOver(context)
                  else
                    ..._buildBattle(context),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
```

- [ ] **Step 3: Trocar os dois `ElevatedButton` por `PixelMenuButton`**

Em `_buildGameOver`:

```dart
      ElevatedButton(
        onPressed: _startingRematch ? null : _startRematch,
        child: const Text('Revanche'),
      ),
```

vira:

```dart
      PixelMenuButton(
        label: 'Revanche',
        onPressed: _startingRematch ? null : _startRematch,
      ),
```

Em `_buildBattle`:

```dart
      ElevatedButton(
        onPressed: (_match.isMyTurn && _selectedIds.isNotEmpty) ? _playTurn : null,
        child: const Text('Jogar'),
      ),
```

vira:

```dart
      PixelMenuButton(
        label: 'Jogar',
        onPressed: (_match.isMyTurn && _selectedIds.isNotEmpty) ? _playTurn : null,
      ),
```

- [ ] **Step 4: Corrigir o teste que procurava `ElevatedButton`**

Em `app/test/multiplayer_battle_screen_test.dart`, adicionar o import
`import 'package:app/game_presentation/pixel_menu_button.dart';` e trocar:

```dart
      final playButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Jogar'),
      );
      expect(playButton.onPressed, isNull);
```

por:

```dart
      final playButton = tester.widget<PixelMenuButton>(
        find.widgetWithText(PixelMenuButton, 'Jogar'),
      );
      expect(playButton.onPressed, isNull);
```

- [ ] **Step 5: Rodar os testes**

Run: `flutter test test/multiplayer_battle_screen_test.dart`
Expected: PASS (todos os 3 testes).

- [ ] **Step 6: `flutter analyze`**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add app/lib/ui/multiplayer_battle_screen.dart app/test/multiplayer_battle_screen_test.dart
git commit -m "Veste MultiplayerBattleScreen no estilo pixel art (fundo, título, botões)"
```

---

## Task 7: Vestir `MultiplayerLobbyScreen`

**Files:**
- Modify: `app/lib/ui/multiplayer_lobby_screen.dart`

**Interfaces:**
- Consumes: `ArenaBackdropPainter` (Task 1), `PixelOutlinedText` (Task 2),
  `PixelMenuButton` (Task 3), `PixelContentPanel` (Task 4).

Sem mudança de teste esperada aqui — `multiplayer_lobby_screen_test.dart`
já foi conferido: usa só `find.byType(TextField)` e `find.text(...)`, nada
que dependa do tipo concreto dos botões.

- [ ] **Step 1: Adicionar os imports**

```dart
import '../game_presentation/pixel_arena_background.dart';
import '../game_presentation/pixel_content_panel.dart';
import '../game_presentation/pixel_menu_button.dart';
import '../game_presentation/pixel_outlined_text.dart';
```

- [ ] **Step 2: Reescrever o `build`**

Trocar:

```dart
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Multiplayer')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Seu nome'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : _create,
              child: const Text('Criar partida'),
            ),
            const Divider(height: 32),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(labelText: 'Código da partida'),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _loading ? null : _join,
                  child: const Text('Entrar com código'),
                ),
                OutlinedButton(
                  onPressed: _loading ? null : _reconnect,
                  child: const Text('Reconectar'),
                ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    );
  }
```

por:

```dart
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: ArenaBackdropPainter())),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const PixelOutlinedText('Multiplayer', fontSize: 20),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: PixelContentPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Seu nome'),
                  ),
                  const SizedBox(height: 16),
                  PixelMenuButton(
                    label: 'Criar partida',
                    primary: true,
                    onPressed: _loading ? null : _create,
                  ),
                  const Divider(height: 32),
                  TextField(
                    controller: _codeController,
                    decoration: const InputDecoration(labelText: 'Código da partida'),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      PixelMenuButton(
                        label: 'Entrar com código',
                        onPressed: _loading ? null : _join,
                      ),
                      PixelMenuButton(
                        label: 'Reconectar',
                        onPressed: _loading ? null : _reconnect,
                      ),
                    ],
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(_error!, style: const TextStyle(color: Colors.red)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
```

- [ ] **Step 3: Rodar os testes**

Run: `flutter test test/multiplayer_lobby_screen_test.dart`
Expected: PASS (todos os 5 testes, sem nenhuma alteração no arquivo de
teste).

- [ ] **Step 4: `flutter analyze`**

Run: `flutter analyze`
Expected: `No issues found!` (se `OutlinedButton`/`ElevatedButton` não
forem mais usados em lugar nenhum do arquivo e isso gerar algum aviso de
import não utilizado — não deveria, pois `material.dart` continua usado
por outros widgets — confirmar rodando, não assumir).

- [ ] **Step 5: Commit**

```bash
git add app/lib/ui/multiplayer_lobby_screen.dart
git commit -m "Veste MultiplayerLobbyScreen no estilo pixel art (fundo, título, botões)"
```

---

## Task 8: Verificação manual, `DECISIONS.md` e `TASKS.md`

**Files:**
- Modify: `DECISIONS.md`
- Modify: `TASKS.md`

- [ ] **Step 1: Suíte completa**

Run: `flutter test` (dentro de `app/`)
Expected: PASS em todos os testes.

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 2: Rodar o app no Chrome — servidor NOVO, não reload**

```bash
cd app
flutter run -d web-server --web-port 5000
```

**Importante** (lição do Bloco 3): se já houver um servidor rodando de uma
verificação anterior, pará-lo e iniciar um novo — um reload de página
sozinho não recompila código Dart alterado.

Navegar Home → Modo Treino (confirmar fundo pixelado, título com
contorno, painel legível, botão "Jogar" desabilitado até selecionar,
jogar uma combinação de verdade) → voltar → Multiplayer → Lobby (confirmar
fundo/título/botões, criar uma partida de verdade) → tela de batalha
(confirmar fundo/título/botões, jogar um turno). Ajustar espaçamento/
opacidade do painel se algo ficar difícil de ler — é acabamento visual,
não arquitetura.

- [ ] **Step 3: Registrar a decisão em `DECISIONS.md`**

Adicionar ao final de `DECISIONS.md` (confirmar o número da próxima
decisão antes de escrever — não assumir):

```markdown

## DECISION-0XX
Data: 2026-09-09
Decisão: consistência visual pixel art (Bloco 4 da direção de produto) —
`TrainingScreen`, `MultiplayerLobbyScreen` e `MultiplayerBattleScreen`
ganham o mesmo fundo/título/botões da Home (DECISION-033), fechando o
choque visual entre a Home e as telas de jogo. Nenhuma lógica, regra ou
texto visível mudou — só o widget por trás de cada elemento.
Passos: `ArenaBackdropPainter` (antes privada da Home) virou pública,
reaproveitada nas três telas via `Stack` + `Scaffold` transparente (mesmo
padrão da Home). Novo `PixelOutlinedText` (título com contorno,
parametrizado) e `PixelContentPanel` (painel "cartão" que mantém o
conteúdo existente — texto, chips, campos — legível por cima do fundo
colorido). `PixelMenuButton` ganhou suporte a `onPressed` nulo (estado
desabilitado, opacidade reduzida) pra poder substituir todo `ElevatedButton`/
`OutlinedButton` de ação principal: "Jogar" (Treino e Multiplayer), "Nova
partida", "Criar partida", "Entrar com código", "Reconectar", "Revanche".
Motivo: Bloco 4 da nova direção de produto (game feel) — a Home (Bloco 3)
deixou evidente que sair dela pras telas de jogo era um tombo visual pro
Material puro; "sem mexer na lógica" foi pedido explícito do usuário.
Consequência (lacuna conhecida, não esquecida): `FilterChip`, `TextField`
e o conteúdo do modal de Skill Tree continuam Material padrão — fora de
escopo deste bloco, ficam pra um bloco futuro de "feedback visual" mais
focado nesses elementos especificamente.
Testes: suíte completa do app (`flutter test`) e `flutter analyze`
passando depois da mudança. Verificado de ponta a ponta de verdade via
`flutter run -d web-server` (servidor reiniciado, não só recarregado):
Modo Treino, Lobby e batalha Multiplayer com fundo/título/botões
consistentes com a Home, navegação e uma jogada de verdade funcionando
nos três.
```

- [ ] **Step 4: Atualizar `TASKS.md`**

Na seção `# DONE`, adicionar ao final:

```
- Consistência visual pixel art (Bloco 4 da direção de produto): Treino,
  Lobby e batalha Multiplayer ganham o mesmo fundo/título/botões da Home,
  sem mudar lógica nem texto (DECISION-0XX)
```

Na seção `# BACKLOG`, sub-seção **App Flutter (app/)**, adicionar:

```
- Chips de elemento (`FilterChip`), campos de texto e o modal de Skill
  Tree continuam Material padrão — candidato a um bloco futuro de
  "feedback visual" mais focado (DECISION-0XX)
```

(usar o número real da decisão registrada no Step 3 nos dois lugares).

- [ ] **Step 5: Commit**

```bash
git add DECISIONS.md TASKS.md
git commit -m "Registra decisão e atualiza TASKS.md (consistência visual pixel art)"
```

---

## Self-Review (feito ao escrever este plano)

- **Cobertura do spec:** "Peças reaproveitáveis novas" → Tasks 1, 2;
  "PixelMenuButton ganha estado desabilitado" → Task 3; "Fundo + painel de
  conteúdo" → Task 4 (peça) + Tasks 5-7 (aplicação); "Botões trocados" →
  Tasks 5-7; "Consequência nos testes existentes" → Tasks 5, 6 (7
  confirmado sem necessidade de mudança); verificação manual → Task 8. "O
  que NÃO está neste bloco" respeitado — nenhuma task toca `FilterChip`,
  `TextField`, o modal de Skill Tree, ou qualquer lógica/regra/texto
  visível.
- **Placeholders:** nenhum "TBD" — todo step tem código completo ou
  comando exato, incluindo os arquivos inteiros reescritos (Task 5) e os
  blocos de `build()` inteiros trocados (Tasks 6, 7).
- **Consistência de tipos:** `ArenaBackdropPainter`/`PixelOutlinedText`/
  `PixelMenuButton`/`PixelContentPanel` (Tasks 1-4) usados com as mesmas
  assinaturas exatas nas Tasks 5-7. `PixelMenuButton.onPressed` nulo
  (Task 3) é exatamente o que as Tasks 5-6 passam nos casos condicionais
  ("Jogar", "Revanche").
- **Achado durante o planejamento:** todo texto/rótulo visível foi mantido
  idêntico ao atual (ex.: "Multiplayer", não "MULTIPLAYER") de propósito —
  `multiplayer_lobby_screen_test.dart` tem `expect(find.text('Multiplayer'),
  findsOneWidget)`, que quebraria se o título virasse caixa alta como os
  botões da Home. Confirmado achando esse teste antes de escrever o plano,
  não descoberto por acidente na execução.
