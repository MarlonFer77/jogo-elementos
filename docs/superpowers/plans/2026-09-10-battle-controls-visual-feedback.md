# Chips, campos de texto e modal de Skill Tree em pixel art (Bloco 5) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fechar o gap de "feedback visual" documentado no BACKLOG desde o Bloco 4 — os chips de seleção de elemento, os campos de texto da Lobby e o modal de Skill Tree deixam de ser Material padrão e passam a usar a mesma linguagem visual pixel art (borda 3px, sombra deslocada, paleta creme/dourado) já estabelecida pela Home e pelos Blocos 3/4.

**Architecture:** Três componentes novos e pequenos em `game_presentation/` (`PixelElementChip`, `PixelTextField`, `PixelSheetPanel`), cada um testado isoladamente, depois compostos nas três telas existentes (`TrainingScreen`, `MultiplayerBattleScreen`, `MultiplayerLobbyScreen`) substituindo `FilterChip`/`TextField`/o conteúdo cru do bottom sheet. Nenhuma mudança em `battle_engine`, `backend`, `TrainingMatch` ou `MultiplayerMatch` — puramente apresentação, mesma lógica.

**Tech Stack:** Flutter + Dart (widgets `StatelessWidget`, `flutter_test` para testes de widget).

**Spec:** [docs/superpowers/specs/2026-09-10-battle-controls-visual-feedback-design.md](../specs/2026-09-10-battle-controls-visual-feedback-design.md)

## Global Constraints

- Nenhuma mudança em `battle_engine`, `backend`, `TrainingMatch`, `MultiplayerMatch` — puramente apresentação (spec, "O que NÃO está neste bloco").
- Nenhum texto/rótulo visível muda: `'🔥 Fogo'` etc. (símbolo+nome de cada elemento), `'Desbloquear'`, `'Fechar'`, `'Seu nome'`, `'Código da partida'`, `'Habilidades'`/`'Habilidades de ${nome}'` continuam literalmente os mesmos — só o widget por trás muda.
- Paleta fixa já estabelecida nos blocos anteriores: borda/texto escuro `Color(0xFF2B2B2B)`, fundo "não selecionado"/creme `Color(0xFFF4F4E4)`, destaque/selecionado dourado `Color(0xFFF4C94A)`. Não inventar cores novas.
- `PixelTextField` precisa manter um `TextField` real internamente — `app/test/multiplayer_lobby_screen_test.dart` usa `find.byType(TextField).first`/`.last` e `tester.enterText(...)` e **não pode ser alterado** neste bloco.
- Nenhuma variante nova de botão ("outline"/"ghost") — reaproveitar `PixelMenuButton` como já existe (YAGNI, decisão do Bloco 4 reafirmada na spec).
- Lição do Bloco 3, ainda válida: `flutter run -d web-server` **não** recompila em reload de página — só um `preview_stop`+`preview_start` novo pega mudanças de código Dart. Toda verificação manual deste plano reinicia o servidor, nunca só recarrega a aba.
- Cada task termina com `flutter analyze` limpo e `flutter test` verde antes do commit.

---

## Task 1: `PixelElementChip`

**Files:**
- Create: `app/lib/game_presentation/pixel_element_chip.dart`
- Test: `app/test/game_presentation/pixel_element_chip_test.dart`

**Interfaces:**
- Consumes: nada de outras tasks.
- Produces: `PixelElementChip({required String label, required bool selected, required VoidCallback? onTap})` — usado pelas Tasks 4 e 5 no lugar de `FilterChip`.

- [ ] **Step 1: Write the failing test**

```dart
// app/test/game_presentation/pixel_element_chip_test.dart
import 'package:app/game_presentation/pixel_element_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the label and calls onTap when tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PixelElementChip(
          label: '🔥 Fogo',
          selected: false,
          onTap: () => tapped = true,
        ),
      ),
    ));

    expect(find.text('🔥 Fogo'), findsOneWidget);

    await tester.tap(find.text('🔥 Fogo'));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('does not throw and stays inert when onTap is null',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: PixelElementChip(label: '🔥 Fogo', selected: false, onTap: null),
      ),
    ));

    expect(find.text('🔥 Fogo'), findsOneWidget);

    await tester.tap(find.text('🔥 Fogo'));
    await tester.pump();
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/game_presentation/pixel_element_chip_test.dart`
Expected: FAIL — `pixel_element_chip.dart` não existe ainda (erro de import).

- [ ] **Step 3: Write minimal implementation**

```dart
// app/lib/game_presentation/pixel_element_chip.dart
import 'package:flutter/material.dart';

/// Substitui o `FilterChip` cru na seleção de elementos (Treino e
/// Multiplayer): mesma família visual do `PixelMenuButton` (borda 3px,
/// sombra deslocada). `onTap` nulo desabilita (opacidade reduzida, sem
/// resposta a toque) — mesmo espírito de `PixelMenuButton.onPressed`.
class PixelElementChip extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.4,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFF4C94A) : const Color(0xFFF4F4E4),
            border: Border.all(color: const Color(0xFF2B2B2B), width: 3),
            borderRadius: BorderRadius.circular(4),
            boxShadow: const [
              BoxShadow(color: Color(0xFF2B2B2B), offset: Offset(3, 3)),
            ],
          ),
          child: Text(
            label,
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

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/game_presentation/pixel_element_chip_test.dart`
Expected: PASS (2 testes).

- [ ] **Step 5: Commit**

```bash
git add app/lib/game_presentation/pixel_element_chip.dart app/test/game_presentation/pixel_element_chip_test.dart
git commit -m "Adiciona PixelElementChip (chip de elemento em pixel art)"
```

---

## Task 2: `PixelTextField`

**Files:**
- Create: `app/lib/game_presentation/pixel_text_field.dart`
- Test: `app/test/game_presentation/pixel_text_field_test.dart`

**Interfaces:**
- Consumes: nada de outras tasks.
- Produces: `PixelTextField({required TextEditingController controller, required String label})` — usado pela Task 6 no lugar de `TextField` na `MultiplayerLobbyScreen`.

- [ ] **Step 1: Write the failing test**

```dart
// app/test/game_presentation/pixel_text_field_test.dart
import 'package:app/game_presentation/pixel_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the label and reflects typed text in the controller',
      (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PixelTextField(controller: controller, label: 'Seu nome'),
      ),
    ));

    expect(find.text('Seu nome'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'ana');

    expect(controller.text, 'ana');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/game_presentation/pixel_text_field_test.dart`
Expected: FAIL — `pixel_text_field.dart` não existe ainda.

- [ ] **Step 3: Write minimal implementation**

```dart
// app/lib/game_presentation/pixel_text_field.dart
import 'package:flutter/material.dart';

/// Substitui o `TextField` cru da `MultiplayerLobbyScreen`. Continua sendo
/// um `TextField` real por dentro (decisivo pra `find.byType(TextField)`
/// nos testes existentes continuar funcionando sem alteração) — só a
/// decoração muda, pra combinar com a borda/sombra pixel art já usada em
/// `PixelMenuButton`/`PixelElementChip`.
class PixelTextField extends StatelessWidget {
  const PixelTextField({super.key, required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    const borderColor = Color(0xFF2B2B2B);
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(4)),
      borderSide: BorderSide(color: borderColor, width: 3),
    );
    return TextField(
      controller: controller,
      style: const TextStyle(fontFamily: 'monospace', color: borderColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontFamily: 'monospace', color: borderColor),
        filled: true,
        fillColor: const Color(0xFFF4F4E4),
        border: border,
        enabledBorder: border,
        focusedBorder: border,
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/game_presentation/pixel_text_field_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/lib/game_presentation/pixel_text_field.dart app/test/game_presentation/pixel_text_field_test.dart
git commit -m "Adiciona PixelTextField (campo de texto em pixel art)"
```

---

## Task 3: `PixelSheetPanel`

**Files:**
- Create: `app/lib/game_presentation/pixel_sheet_panel.dart`
- Test: `app/test/game_presentation/pixel_sheet_panel_test.dart`

**Interfaces:**
- Consumes: nada de outras tasks.
- Produces: `PixelSheetPanel({required Widget child})` — usado pelas Tasks 4 e 5 pra embrulhar o conteúdo do `showModalBottomSheet` de Skill Tree.

- [ ] **Step 1: Write the failing test**

```dart
// app/test/game_presentation/pixel_sheet_panel_test.dart
import 'package:app/game_presentation/pixel_sheet_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders its child', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: PixelSheetPanel(child: Text('conteúdo'))),
    ));
    expect(find.text('conteúdo'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/game_presentation/pixel_sheet_panel_test.dart`
Expected: FAIL — `pixel_sheet_panel.dart` não existe ainda.

- [ ] **Step 3: Write minimal implementation**

```dart
// app/lib/game_presentation/pixel_sheet_panel.dart
import 'package:flutter/material.dart';

/// Embrulha o conteúdo de um `showModalBottomSheet` (usado pelo modal de
/// Skill Tree em Treino e Multiplayer) num painel pixel art — fundo creme,
/// borda escura nos lados/topo (sem borda inferior, que encosta na borda
/// da tela) e cantos superiores arredondados, pra parecer um painel de
/// jogo subindo, não um bottom sheet branco genérico. O `showModalBottomSheet`
/// que usa isso precisa de `backgroundColor: Colors.transparent` pra essa
/// decoração aparecer no lugar do fundo branco padrão do Material.
class PixelSheetPanel extends StatelessWidget {
  const PixelSheetPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF4F4E4),
        border: Border(
          top: BorderSide(color: Color(0xFF2B2B2B), width: 3),
          left: BorderSide(color: Color(0xFF2B2B2B), width: 3),
          right: BorderSide(color: Color(0xFF2B2B2B), width: 3),
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      child: child,
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/game_presentation/pixel_sheet_panel_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/lib/game_presentation/pixel_sheet_panel.dart app/test/game_presentation/pixel_sheet_panel_test.dart
git commit -m "Adiciona PixelSheetPanel (painel pixel art pro bottom sheet)"
```

---

## Task 4: `TrainingScreen` usa os três componentes novos

**Files:**
- Modify: `app/lib/ui/training_screen.dart:1-11` (imports), `:85-150` (`_openSkillTree`), `:250-285` (`_buildPlayForm`)
- Test: `app/test/training_screen_test.dart` (nenhuma mudança esperada — só rodar pra confirmar)

**Interfaces:**
- Consumes: `PixelElementChip` (Task 1), `PixelSheetPanel` (Task 3), `PixelMenuButton`/`PixelOutlinedText` (já existentes, Bloco 4).
- Produces: nada consumido por outras tasks.

- [ ] **Step 1: Confirmar a suíte atual passa antes de mexer (baseline)**

Run: `cd app && flutter test test/training_screen_test.dart`
Expected: PASS (5 testes, sem nenhuma mudança ainda).

- [ ] **Step 2: Trocar os imports**

Em `app/lib/ui/training_screen.dart`, depois do import de `pixel_content_panel.dart` (linha 9), adicionar:

```dart
import '../game_presentation/pixel_element_chip.dart';
import '../game_presentation/pixel_sheet_panel.dart';
```

- [ ] **Step 3: Trocar `FilterChip` por `PixelElementChip` em `_buildPlayForm`**

Substituir o bloco `for (final element in elements) FilterChip(...)` (linhas 263-269 do arquivo original) por:

```dart
for (final element in elements)
  PixelElementChip(
    label: '${element.symbol} ${element.name}',
    selected: _selectedIds.contains(element.id),
    onTap: () => _toggleElement(element.id),
  ),
```

(Sem condição de desabilitar — igual ao `FilterChip` original, que também não tinha `onSelected: null` no Modo Treino: é hotseat, sempre a vez de quem está com o dispositivo.)

- [ ] **Step 4: Restilizar `_openSkillTree`**

Substituir o método `_openSkillTree` inteiro (linhas 85-150 do arquivo original) por:

```dart
  void _openSkillTree() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final available = _match.availableSkillNodesForCurrentPlayer;
            // Fixed height + Expanded list, so "Fechar" always stays at a
            // predictable spot regardless of how many nodes are available
            // (the list scrolls internally instead of pushing it off).
            return PixelSheetPanel(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PixelOutlinedText(
                        'Habilidades de ${_match.currentTurnName}',
                        fontSize: 18,
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: available.isEmpty
                            ? const Text('Nada novo para desbloquear agora.')
                            : ListView(
                                children: [
                                  for (final node in available)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: const Color(0xFF2B2B2B),
                                          width: 3,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                        color: const Color(0xFFF4F4E4),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '[${node.branch}] ${node.name}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(node.description),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          PixelMenuButton(
                                            label: 'Desbloquear',
                                            onPressed: () {
                                              setState(() {
                                                _match.unlockSkillForCurrentPlayer(
                                                  node.id,
                                                );
                                              });
                                              setSheetState(() {});
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: PixelMenuButton(
                          label: 'Fechar',
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
```

- [ ] **Step 5: Rodar a suíte e confirmar que continua verde sem nenhuma alteração de teste**

Run: `cd app && flutter test test/training_screen_test.dart`
Expected: PASS (5 testes) — inclusive o teste "unlocking Maestria da Brasa applies Queimadura...", que exercita `_openSkillTree` de ponta a ponta via `find.text('Desbloquear')`.

Se falhar por não encontrar `find.text('Desbloquear')` ou `find.text('Fechar')`: conferir que `PixelMenuButton` está renderizando o `label` como um `Text` alcançável (já validado no Bloco 4 pros botões "Jogar"/"Nova partida").

- [ ] **Step 6: `flutter analyze`**

Run: `cd app && flutter analyze`
Expected: "No issues found!"

- [ ] **Step 7: Commit**

```bash
git add app/lib/ui/training_screen.dart
git commit -m "TrainingScreen usa PixelElementChip e PixelSheetPanel"
```

---

## Task 5: `MultiplayerBattleScreen` usa os três componentes novos

**Files:**
- Modify: `app/lib/ui/multiplayer_battle_screen.dart:1-17` (imports), `:142-214` (`_openSkillTree`), `:337-350` (chips em `_buildBattle`)
- Test: `app/test/multiplayer_battle_screen_test.dart` (nenhuma mudança esperada — só rodar pra confirmar)

**Interfaces:**
- Consumes: `PixelElementChip` (Task 1), `PixelSheetPanel` (Task 3), `PixelMenuButton`/`PixelOutlinedText` (já existentes).
- Produces: nada consumido por outras tasks.

- [ ] **Step 1: Confirmar a suíte atual passa antes de mexer (baseline)**

Run: `cd app && flutter test test/multiplayer_battle_screen_test.dart`
Expected: PASS (3 testes).

- [ ] **Step 2: Trocar os imports**

Em `app/lib/ui/multiplayer_battle_screen.dart`, depois do import de `pixel_content_panel.dart` (linha 15), adicionar:

```dart
import '../game_presentation/pixel_element_chip.dart';
import '../game_presentation/pixel_sheet_panel.dart';
```

- [ ] **Step 3: Trocar `FilterChip` por `PixelElementChip` em `_buildBattle`**

Substituir o bloco `for (final element in elements) FilterChip(...)` (linhas 341-348 do arquivo original) por:

```dart
for (final element in elements)
  PixelElementChip(
    label: '${element.symbol} ${element.name}',
    selected: _selectedIds.contains(element.id),
    onTap: _match.isMyTurn ? () => _toggleElement(element.id) : null,
  ),
```

- [ ] **Step 4: Restilizar `_openSkillTree`**

Substituir o método `_openSkillTree` inteiro (linhas 142-214 do arquivo original) por:

```dart
  void _openSkillTree() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final canUnlockNow = _match.isInProgress && _match.isMyTurn;
            final available = canUnlockNow
                ? availableSkillNodeOptions(_match.unlockedNodeIdsForMe)
                : const <SkillNodeOption>[];

            return PixelSheetPanel(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const PixelOutlinedText('Habilidades', fontSize: 18),
                      const SizedBox(height: 8),
                      Expanded(
                        child: !canUnlockNow
                            ? const Text('Só dá pra desbloquear na sua vez.')
                            : available.isEmpty
                                ? const Text('Nada novo para desbloquear agora.')
                                : ListView(
                                    children: [
                                      for (final node in available)
                                        Container(
                                          margin: const EdgeInsets.only(bottom: 8),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: const Color(0xFF2B2B2B),
                                              width: 3,
                                            ),
                                            borderRadius: BorderRadius.circular(4),
                                            color: const Color(0xFFF4F4E4),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      '[${node.branch}] ${node.name}',
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                    Text(node.description),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              PixelMenuButton(
                                                label: 'Desbloquear',
                                                onPressed: () async {
                                                  try {
                                                    await _match.unlockSkill(node.id);
                                                    setSheetState(() {});
                                                    setState(() {});
                                                  } on MultiplayerException catch (e) {
                                                    if (!context.mounted) return;
                                                    ScaffoldMessenger.of(context)
                                                        .showSnackBar(
                                                      SnackBar(content: Text(e.message)),
                                                    );
                                                  }
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: PixelMenuButton(
                          label: 'Fechar',
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
```

- [ ] **Step 5: Rodar a suíte e confirmar que continua verde sem nenhuma alteração de teste**

Run: `cd app && flutter test test/multiplayer_battle_screen_test.dart`
Expected: PASS (3 testes) — inclusive o teste "Habilidades modal lists what can be unlocked and unlocking it updates the list live", que exercita `_openSkillTree` de ponta a ponta.

- [ ] **Step 6: `flutter analyze`**

Run: `cd app && flutter analyze`
Expected: "No issues found!"

- [ ] **Step 7: Commit**

```bash
git add app/lib/ui/multiplayer_battle_screen.dart
git commit -m "MultiplayerBattleScreen usa PixelElementChip e PixelSheetPanel"
```

---

## Task 6: `MultiplayerLobbyScreen` usa `PixelTextField`

**Files:**
- Modify: `app/lib/ui/multiplayer_lobby_screen.dart:1-10` (imports), `:117-160` (`build`, os dois `TextField`)
- Test: `app/test/multiplayer_lobby_screen_test.dart` (nenhuma mudança esperada — só rodar pra confirmar)

**Interfaces:**
- Consumes: `PixelTextField` (Task 2).
- Produces: nada consumido por outras tasks.

- [ ] **Step 1: Confirmar a suíte atual passa antes de mexer (baseline)**

Run: `cd app && flutter test test/multiplayer_lobby_screen_test.dart`
Expected: PASS (5 testes).

- [ ] **Step 2: Trocar os imports**

Em `app/lib/ui/multiplayer_lobby_screen.dart`, depois do import de `pixel_outlined_text.dart` (linha 10), adicionar:

```dart
import '../game_presentation/pixel_text_field.dart';
```

- [ ] **Step 3: Trocar os dois `TextField` por `PixelTextField`**

Em `build`, substituir:

```dart
TextField(
  controller: _nameController,
  decoration: const InputDecoration(labelText: 'Seu nome'),
),
```

por:

```dart
PixelTextField(controller: _nameController, label: 'Seu nome'),
```

E substituir:

```dart
TextField(
  controller: _codeController,
  decoration: const InputDecoration(labelText: 'Código da partida'),
),
```

por:

```dart
PixelTextField(controller: _codeController, label: 'Código da partida'),
```

- [ ] **Step 4: Rodar a suíte e confirmar que continua verde sem nenhuma alteração de teste**

Run: `cd app && flutter test test/multiplayer_lobby_screen_test.dart`
Expected: PASS (5 testes) — inclusive os que usam `find.byType(TextField).first`/`.last` e `tester.enterText(...)`, que continuam funcionando contra o `TextField` interno do `PixelTextField`.

- [ ] **Step 5: `flutter analyze`**

Run: `cd app && flutter analyze`
Expected: "No issues found!"

- [ ] **Step 6: Commit**

```bash
git add app/lib/ui/multiplayer_lobby_screen.dart
git commit -m "MultiplayerLobbyScreen usa PixelTextField"
```

---

## Task 7: Suíte completa, verificação manual e registro da decisão

**Files:**
- Modify: `DECISIONS.md` (nova `## DECISION-035`)
- Modify: `TASKS.md` (linha `DONE` nova, remover a linha do BACKLOG sobre chips/campos/modal Material — o gap foi fechado)

**Interfaces:**
- Consumes: tudo das Tasks 1-6.
- Produces: nada (última task do bloco).

- [ ] **Step 1: Rodar a suíte completa do app**

Run: `cd app && flutter test`
Expected: PASS — todos os testes (os 96 já existentes + os novos das Tasks 1-3: `PixelElementChip` ×2, `PixelTextField` ×1, `PixelSheetPanel` ×1 = 100 no total).

- [ ] **Step 2: `flutter analyze` na árvore final**

Run: `cd app && flutter analyze`
Expected: "No issues found!"

- [ ] **Step 3: Verificação manual no navegador**

Reiniciar o servidor de preview do zero (parar o processo anterior se algum estiver rodando e iniciar de novo — **não** só recarregar a aba, lição do Bloco 3):

1. Abrir a Home, ir pro Modo Treino.
2. Selecionar Fogo e Vento: confirmar visualmente que cada chip fica dourado ao selecionar e volta a creme ao desselecionar (borda escura, sombra deslocada, igual ao `PixelMenuButton`).
3. Jogar o turno (combo dispara, dano aplicado — funcionalidade inalterada).
4. Abrir "Habilidades": confirmar que o painel sobe com fundo creme/borda pixel art (cantos superiores arredondados) em vez do bottom sheet branco padrão; desbloquear um nó de verdade e confirmar que a lista atualiza.
5. Ir pro Multiplayer → Lobby: confirmar que os campos "Seu nome"/"Código da partida" têm a borda pixel art; digitar um nome e criar uma partida real (contra o backend do Render), confirmar que chega na tela "Aguardando oponente...".
6. Checar o console do navegador: zero erros.

- [ ] **Step 4: Registrar `DECISION-035` em `DECISIONS.md`**

Adicionar ao final do arquivo, seguindo o formato das decisões anteriores:

```markdown
## DECISION-035
Data: 2026-09-10
Decisão: feedback visual em pixel art pros chips de elemento, campos de
texto e modal de Skill Tree (Bloco 5 da direção de produto) — fecha o gap
documentado desde o Bloco 4 (DECISION-034). Nenhuma lógica, regra ou texto
visível mudou — só o widget por trás de cada elemento.
Passos: três componentes novos em `game_presentation/` —
`PixelElementChip` (substitui `FilterChip`, preenchimento dourado quando
selecionado/creme quando não, opacidade reduzida quando `onTap` é nulo),
`PixelTextField` (substitui `TextField` cru na Lobby, mesma borda/fundo dos
outros componentes, `TextField` real por dentro pra não quebrar os testes
existentes) e `PixelSheetPanel` (envolve o conteúdo do modal de Skill Tree
num painel com cantos superiores arredondados, pra parecer um painel de
jogo subindo em vez de um bottom sheet branco genérico). Dentro do modal, o
título virou `PixelOutlinedText`, cada nó desbloqueável ganhou um cartão
com borda pixel art (era `ListTile`), e "Desbloquear"/"Fechar" viraram
`PixelMenuButton` (eram `TextButton`).
Motivo: Bloco 5 da nova direção de produto (game feel) — esses três
elementos eram justamente os mais interagidos durante uma partida (seleção
de elemento, desbloqueio de habilidade) e o gap ficou documentado
explicitamente no BACKLOG desde a DECISION-034.
Consequência: nenhuma lacuna nova conhecida — o gap de "feedback visual"
Material padrão apontado na DECISION-034 está fechado.
Testes: suíte completa do app (`flutter test`, 100 testes) e `flutter
analyze` passando. Verificado de ponta a ponta de verdade via `flutter run
-d web-server` (servidor reiniciado, não só recarregado): Modo Treino com
seleção de elemento (chip dourado/creme) e desbloqueio real de habilidade
pelo painel novo, Lobby com campos restilizados e criação de partida real
contra o backend no Render, zero erros no console.
```

- [ ] **Step 5: Atualizar `TASKS.md`**

Adicionar ao final da seção `# DONE`:

```markdown
- Feedback visual pixel art em chips/campos/modal (Bloco 5 da direção de
  produto): `PixelElementChip`, `PixelTextField` e `PixelSheetPanel` novos,
  substituindo `FilterChip`/`TextField`/conteúdo cru do modal de Skill Tree
  em Treino e Multiplayer, sem mudar lógica nem texto (DECISION-035)
```

Na seção `# BACKLOG`, sub-seção "App Flutter (app/)", remover a linha:

```markdown
- Chips de elemento (`FilterChip`), campos de texto e o modal de Skill
  Tree continuam Material padrão — candidato a um bloco futuro de
  "feedback visual" mais focado (DECISION-034)
```

(o gap foi fechado por este bloco — não sobra nenhum item novo pra
adicionar no lugar).

- [ ] **Step 6: Commit**

```bash
git add DECISIONS.md TASKS.md
git commit -m "Registra DECISION-035 e atualiza TASKS.md (feedback visual pixel art em chips/campos/modal)"
```

- [ ] **Step 7: Finalizar o bloco**

Announce: "I'm using the finishing-a-development-branch skill to complete this work."
**REQUIRED SUB-SKILL:** Use superpowers:finishing-a-development-branch — rodar a suíte final, apresentar as opções, executar a escolha do usuário.

---

## Self-Review

**1. Cobertura da spec:** "Escopo: as três frentes juntas" → Tasks 4, 5, 6 cobrem chips (Treino+Multiplayer), campos de texto (Lobby) e modal (Treino+Multiplayer). "Estado selecionado: dourado/creme" → Task 1, Step 3. "Modal completo em pixel art" → Task 3 (`PixelSheetPanel`) + Tasks 4/5 Step 4 (`backgroundColor: Colors.transparent` + wrap). "`PixelTextField` mantém `TextField` real" → Task 2, Step 3 + constraint global. "Nenhum texto muda" → todos os literais (`'🔥 Fogo'` via `element.symbol`/`element.name` inalterados, `'Desbloquear'`, `'Fechar'`, `'Seu nome'`, `'Código da partida'`, `'Habilidades'`) preservados byte a byte em cada task. "Testes existentes sem mudança" → Tasks 4/5/6 Step 1 (baseline) e Step 5/4 (confirmação pós-mudança) tornam isso verificável, não só assumido. Nenhum requisito da spec ficou sem task.

**2. Placeholder scan:** Nenhum "TBD"/"implementar depois" — todo código é completo e colável direto. Nenhuma referência a "mesmo que a Task N" sem repetir o código (Tasks 4 e 5 repetem o `_openSkillTree` completo cada uma, mesmo sendo quase idênticos entre si, porque são arquivos diferentes).

**3. Consistência de tipos:** `PixelElementChip({label, selected, onTap})` (Task 1) usado identicamente nas Tasks 4/5. `PixelTextField({controller, label})` (Task 2) usado identicamente na Task 6. `PixelSheetPanel({child})` (Task 3) usado identicamente nas Tasks 4/5. Cores (`0xFF2B2B2B`/`0xFFF4F4E4`/`0xFFF4C94A`) idênticas em todo o plano, batendo com a Global Constraint e com os componentes já existentes do Bloco 4 (`PixelMenuButton`).
