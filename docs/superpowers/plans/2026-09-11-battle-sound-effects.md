# Efeitos sonoros (Bloco 8) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dar ao jogo seu primeiro feedback sonoro — toque de botão, ataque disparado, impacto, habilidade desbloqueada, vitória e derrota — usando 6 arquivos CC0 já baixados/validados e um player global seguro de chamar em qualquer contexto (inclusive testes).

**Architecture:** Um componente novo e isolado, `SfxPlayer` (`game_presentation/sfx_player.dart`), expõe `sfxPlayer.play(SfxId.x)` como instância global mutável. Ele envolve `FlameAudio.play` com try/catch, então nunca derruba o app nem quebra teste nenhum — os ~20 testes de tela existentes continuam passando sem nenhuma mudança. Os pontos de integração (botões, ataque, skill tree, fim de partida) ganham uma linha cada, chamando a instância global. Só `SfxPlayer`, `PixelMenuButton` e `PixelElementChip` trocam a instância global por uma injetada em teste, para conseguir *assert* no som tocado.

**Tech Stack:** `flame_audio: ^2.12.2` (pacote oficial do Flame), 6 arquivos de áudio CC0 (Kenney, via `raw.githubusercontent.com/Calinou/kenney-ui-audio` e `gamesounds.xyz`), Flutter/Dart, `flutter_test`.

**Spec:** [docs/superpowers/specs/2026-09-11-battle-sound-effects-design.md](../specs/2026-09-11-battle-sound-effects-design.md)

## Global Constraints

- R$ 0 de custo: `flame_audio` é gratuito/open-source; os 6 sons são CC0 (domínio público), sem licenciamento pago.
- Escopo deste bloco é só efeitos sonoros (SFX). Sem música de fundo, sem botão de mutar/desmutar, sem volume individual por som — todos ficam registrados no BACKLOG, não implementar aqui.
- `flame_audio` versão `^2.12.2`.
- Convenção do pacote: arquivos em `assets/audio/`, declarados em `pubspec.yaml` (`flutter: assets: - assets/audio/`).
- A instância global `sfxPlayer` (tipo `SfxPlayer`) é a ÚNICA variável global mutável (não-`final`) do código-base — de propósito, para permitir troca em teste via `setUp`/`tearDown` sem mudar a API pública de nenhum widget.
- `SfxPlayer._defaultPlay` deve sempre ignorar qualquer erro (try/catch + `.catchError`) — áudio nunca pode derrubar o jogo nem quebrar um teste que não se importa com som.
- Este bloco não toca `battle_engine` nem `backend/src/battle-rules/` — é puramente apresentação, nenhuma sincronização manual necessária (ver CLAUDE.md).
- **Lição de teste (padrão desta sessão):** nunca chamar `pumpAndSettle()` numa árvore de widget que contenha um `AnimationController` repetindo (ex: a animação idle de `TrainerSpriteImage`) — trava/expira. Usar `tester.pump(const Duration(milliseconds: N))` em vez disso.
- **Lição de teste:** `tester.pump()` puro (sem duração) não garante liberar um `Future.delayed(Duration.zero)`/evento de stream — sempre usar `tester.pump(const Duration(milliseconds: N))` quando algo assíncrono estiver envolvido.
- **Lição de teste:** qualquer teste que deixe montada uma tela com `TrainerSpriteImage` (ex: `HomeScreen`) precisa terminar com `await tester.pumpWidget(const SizedBox());` pra desmontar o `AnimationController` idle. (Não se aplica às telas tocadas neste bloco, mas vale se algum teste futuro passar por `HomeScreen`.)
- `flutter run -d web-server` nunca recompila sozinho ao recarregar o navegador — sempre reiniciar com `preview_stop` + `preview_start` completo antes de verificar manualmente.

---

## Arquivos afetados

**Novos:**
- `app/assets/audio/tap.wav`, `cast.ogg`, `impact.ogg`, `unlock.ogg`, `victory.ogg`, `defeat.ogg` — os 6 sons CC0.
- `app/lib/game_presentation/sfx_player.dart` — `SfxPlayer`, `SfxId`, instância global `sfxPlayer`.
- `app/test/game_presentation/sfx_player_test.dart` — testes de `SfxPlayer` isolado.

**Modificados:**
- `app/pubspec.yaml` — dependência `flame_audio` + declaração de assets.
- `app/lib/game_presentation/pixel_menu_button.dart` / `app/test/game_presentation/pixel_menu_button_test.dart` — som de toque.
- `app/lib/game_presentation/pixel_element_chip.dart` / `app/test/game_presentation/pixel_element_chip_test.dart` — som de toque.
- `app/lib/game_presentation/attack_sequence_player.dart` / `app/test/game_presentation/attack_sequence_player_test.dart` — som de disparo (cast) e impacto.
- `app/lib/ui/skill_tree_screen.dart` — som de habilidade desbloqueada.
- `app/lib/ui/training_screen.dart` — som de fim de partida (Treino).
- `app/lib/ui/multiplayer_battle_screen.dart` — som de vitória/derrota (Multiplayer).
- `DECISIONS.md` — nova entrada DECISION-042.
- `TASKS.md` — marca o bloco como DONE, registra BACKLOG (mute toggle, música de fundo).

---

### Task 1: Dependência, assets de áudio e `SfxPlayer`

**Files:**
- Modify: `app/pubspec.yaml`
- Create: `app/assets/audio/tap.wav`, `app/assets/audio/cast.ogg`, `app/assets/audio/impact.ogg`, `app/assets/audio/unlock.ogg`, `app/assets/audio/victory.ogg`, `app/assets/audio/defeat.ogg`
- Create: `app/lib/game_presentation/sfx_player.dart`
- Test: `app/test/game_presentation/sfx_player_test.dart`

**Interfaces:**
- Produces: `enum SfxId { tap, cast, impact, unlock, victory, defeat }`; `class SfxPlayer { SfxPlayer({void Function(String path)? play}); void play(SfxId id); }`; global mutável `SfxPlayer sfxPlayer`. Todas as tasks seguintes consomem isso.

- [ ] **Step 1: Adicionar a dependência `flame_audio` no pubspec**

Em `app/pubspec.yaml`, na seção `dependencies:`, logo depois da linha `flame: ^1.38.2`:

```yaml
  flame: ^1.38.2
  flame_audio: ^2.12.2
  http: ^1.2.2
```

**Step 2: Declarar a pasta de assets**

Ainda em `app/pubspec.yaml`, na seção `flutter:`, logo depois de `uses-material-design: true`:

```yaml
  uses-material-design: true

  assets:
    - assets/audio/
```

(Deixe os comentários de exemplo já existentes depois dessa linha como estão — não apagar.)

- [ ] **Step 3: Instalar as dependências**

Run: `cd app && flutter pub get`
Expected: conclui sem erro, `flame_audio` aparece em `app/pubspec.lock`.

- [ ] **Step 4: Baixar os 6 arquivos de áudio CC0**

Run (na raiz do repo):

```bash
mkdir -p app/assets/audio
curl -sL "https://raw.githubusercontent.com/Calinou/kenney-ui-audio/master/addons/kenney_ui_audio/click1.wav" -o app/assets/audio/tap.wav
curl -sL "https://gamesounds.xyz/Kenney's%20Sound%20Pack/Sci-Fi%20Sounds/laserRetro_000.ogg" -o app/assets/audio/cast.ogg
curl -sL "https://gamesounds.xyz/Kenney's%20Sound%20Pack/Impact%20Sounds/impactPunch_heavy_000.ogg" -o app/assets/audio/impact.ogg
curl -sL "https://gamesounds.xyz/Kenney's%20Sound%20Pack/Music%20Jingles/Audio%20(Retro)/jingles-retro_00.ogg" -o app/assets/audio/unlock.ogg
curl -sL "https://gamesounds.xyz/Kenney's%20Sound%20Pack/Music%20Jingles/Audio%20(Retro)/jingles-retro_12.ogg" -o app/assets/audio/victory.ogg
curl -sL "https://gamesounds.xyz/Kenney's%20Sound%20Pack/Music%20Jingles/Audio%20(Retro)/jingles-retro_08.ogg" -o app/assets/audio/defeat.ogg
file app/assets/audio/*
```

Expected: todos os 6 arquivos existem, com tamanho > 0, e `file` reconhece cada um como áudio válido (`WAVE audio` para `tap.wav`, `Ogg data` para os outros 5). Se algum vier vazio ou `file` não reconhecer, a URL mudou — parar e avisar antes de seguir.

- [ ] **Step 5: Escrever o teste falho de `SfxPlayer`**

Criar `app/test/game_presentation/sfx_player_test.dart`:

```dart
import 'package:app/game_presentation/sfx_player.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resolves each SfxId to its expected asset path', () {
    final playedPaths = <String>[];
    final player = SfxPlayer(play: playedPaths.add);

    const expected = {
      SfxId.tap: 'tap.wav',
      SfxId.cast: 'cast.ogg',
      SfxId.impact: 'impact.ogg',
      SfxId.unlock: 'unlock.ogg',
      SfxId.victory: 'victory.ogg',
      SfxId.defeat: 'defeat.ogg',
    };

    for (final entry in expected.entries) {
      player.play(entry.key);
      expect(playedPaths.last, entry.value);
    }
  });

  test('the default SfxPlayer() never throws, even without a real audio '
      'backend (safe to call from any widget test)', () {
    final player = SfxPlayer();
    expect(() => player.play(SfxId.tap), returnsNormally);
  });
}
```

- [ ] **Step 6: Rodar o teste e confirmar que falha**

Run: `cd app && flutter test test/game_presentation/sfx_player_test.dart`
Expected: FAIL — `sfx_player.dart` ainda não existe (`Error: Error when reading 'lib/game_presentation/sfx_player.dart'` ou similar).

- [ ] **Step 7: Implementar `SfxPlayer`**

Criar `app/lib/game_presentation/sfx_player.dart`:

```dart
import 'package:flame_audio/flame_audio.dart';

enum SfxId { tap, cast, impact, unlock, victory, defeat }

/// Toca efeitos sonoros curtos via `flame_audio`. Nunca deve derrubar o
/// jogo — qualquer falha (sem player disponível, ex: rodando em teste, ou
/// plataforma sem suporte) é silenciosamente ignorada por
/// [_defaultPlay]. O construtor com `play` injetável serve só para os
/// testes que precisam confirmar que um som tocou (ver [sfxPlayer]).
class SfxPlayer {
  SfxPlayer({void Function(String path)? play}) : _play = play ?? _defaultPlay;

  final void Function(String path) _play;

  static const _paths = {
    SfxId.tap: 'tap.wav',
    SfxId.cast: 'cast.ogg',
    SfxId.impact: 'impact.ogg',
    SfxId.unlock: 'unlock.ogg',
    SfxId.victory: 'victory.ogg',
    SfxId.defeat: 'defeat.ogg',
  };

  static void _defaultPlay(String path) {
    try {
      // ignore: discarded_futures
      FlameAudio.play(path).catchError((_) {});
    } catch (_) {
      // ignore
    }
  }

  void play(SfxId id) => _play(_paths[id]!);
}

/// Instância única, chamada direto de qualquer lugar do app
/// (`sfxPlayer.play(SfxId.tap)`), sem precisar injetar em cada widget.
/// Segura em teste porque `_defaultPlay` ignora qualquer erro.
/// **Não é `final`** — de propósito: `SfxPlayer`, `PixelMenuButton` e
/// `PixelElementChip` a substituem em teste por uma instância com `play`
/// injetado, sem precisar mudar a API pública desses widgets. Único
/// lugar do código-base que reatribui uma variável global.
SfxPlayer sfxPlayer = SfxPlayer();
```

- [ ] **Step 8: Rodar o teste e confirmar que passa**

Run: `cd app && flutter test test/game_presentation/sfx_player_test.dart`
Expected: PASS (2 testes).

- [ ] **Step 9: Commit**

```bash
git add app/pubspec.yaml app/pubspec.lock app/assets/audio app/lib/game_presentation/sfx_player.dart app/test/game_presentation/sfx_player_test.dart
git commit -m "$(cat <<'EOF'
Adiciona flame_audio e SfxPlayer (Bloco 8, efeitos sonoros)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Som de toque em `PixelMenuButton`

**Files:**
- Modify: `app/lib/game_presentation/pixel_menu_button.dart`
- Test: `app/test/game_presentation/pixel_menu_button_test.dart`

**Interfaces:**
- Consumes: `SfxId.tap` de `SfxId`; `sfxPlayer.play(SfxId)`; construtor `SfxPlayer({play})` pra trocar a instância global em teste (Task 1).

- [ ] **Step 1: Escrever os testes falhos**

Em `app/test/game_presentation/pixel_menu_button_test.dart`, adicionar o import e os dois testes novos ao final do `main()` (antes do `}` de fechamento):

```dart
import 'package:app/game_presentation/pixel_menu_button.dart';
import 'package:app/game_presentation/sfx_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
```

```dart
  testWidgets('plays a tap sound when pressed while enabled',
      (tester) async {
    final playedPaths = <String>[];
    sfxPlayer = SfxPlayer(play: playedPaths.add);
    addTearDown(() => sfxPlayer = SfxPlayer());

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PixelMenuButton(label: 'Jogar', onPressed: () {}),
      ),
    ));

    await tester.tap(find.text('Jogar'));
    await tester.pump();

    expect(playedPaths, ['tap.wav']);
  });

  testWidgets('does not play a sound when disabled', (tester) async {
    final playedPaths = <String>[];
    sfxPlayer = SfxPlayer(play: playedPaths.add);
    addTearDown(() => sfxPlayer = SfxPlayer());

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: PixelMenuButton(label: 'Jogar', onPressed: null)),
    ));

    await tester.tap(find.text('Jogar'));
    await tester.pump();

    expect(playedPaths, isEmpty);
  });
```

- [ ] **Step 2: Rodar os testes e confirmar que os dois novos falham**

Run: `cd app && flutter test test/game_presentation/pixel_menu_button_test.dart`
Expected: 2 testes antigos PASS, 2 novos FAIL (`playedPaths` continua vazio — nenhum som toca ainda).

- [ ] **Step 3: Implementar o toque de som**

Em `app/lib/game_presentation/pixel_menu_button.dart`, adicionar o import:

```dart
import 'package:flutter/material.dart';

import 'sfx_player.dart';
```

Adicionar o método `_handleTap` na classe `_PixelMenuButtonState`, logo depois de `_setPressed`:

```dart
  void _handleTap() {
    sfxPlayer.play(SfxId.tap);
    widget.onPressed?.call();
  }
```

E trocar a linha `onTap: widget.onPressed,` dentro do `GestureDetector` por:

```dart
        onTap: isEnabled ? _handleTap : null,
```

- [ ] **Step 4: Rodar os testes e confirmar que passam**

Run: `cd app && flutter test test/game_presentation/pixel_menu_button_test.dart`
Expected: PASS (4 testes).

- [ ] **Step 5: Commit**

```bash
git add app/lib/game_presentation/pixel_menu_button.dart app/test/game_presentation/pixel_menu_button_test.dart
git commit -m "$(cat <<'EOF'
Toca som ao pressionar PixelMenuButton (Bloco 8)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Som de toque em `PixelElementChip`

**Files:**
- Modify: `app/lib/game_presentation/pixel_element_chip.dart`
- Test: `app/test/game_presentation/pixel_element_chip_test.dart`

**Interfaces:**
- Consumes: mesmos de Task 2 (`SfxId.tap`, `sfxPlayer`, `SfxPlayer({play})`).

- [ ] **Step 1: Escrever os testes falhos**

Em `app/test/game_presentation/pixel_element_chip_test.dart`, adicionar o import:

```dart
import 'package:app/game_presentation/pixel_element_chip.dart';
import 'package:app/game_presentation/sfx_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
```

E os dois testes novos ao final do `main()`:

```dart
  testWidgets('plays a tap sound when tapped while enabled', (tester) async {
    final playedPaths = <String>[];
    sfxPlayer = SfxPlayer(play: playedPaths.add);
    addTearDown(() => sfxPlayer = SfxPlayer());

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PixelElementChip(
          label: '🔥 Fogo',
          selected: false,
          onTap: () {},
        ),
      ),
    ));

    await tester.tap(find.text('🔥 Fogo'));
    await tester.pump();

    expect(playedPaths, ['tap.wav']);
  });

  testWidgets('does not play a sound when disabled', (tester) async {
    final playedPaths = <String>[];
    sfxPlayer = SfxPlayer(play: playedPaths.add);
    addTearDown(() => sfxPlayer = SfxPlayer());

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: PixelElementChip(label: '🔥 Fogo', selected: false, onTap: null),
      ),
    ));

    await tester.tap(find.text('🔥 Fogo'));
    await tester.pump();

    expect(playedPaths, isEmpty);
  });
```

- [ ] **Step 2: Rodar os testes e confirmar que os dois novos falham**

Run: `cd app && flutter test test/game_presentation/pixel_element_chip_test.dart`
Expected: 2 testes antigos PASS, 2 novos FAIL.

- [ ] **Step 3: Implementar o toque de som**

Em `app/lib/game_presentation/pixel_element_chip.dart`, adicionar o import:

```dart
import 'package:flutter/material.dart';

import 'sfx_player.dart';
```

Adicionar o método `_handleTap` na classe `_PixelElementChipState`, logo depois de `_setPressed`:

```dart
  void _handleTap() {
    sfxPlayer.play(SfxId.tap);
    widget.onTap?.call();
  }
```

E trocar a linha `onTap: widget.onTap,` dentro do `GestureDetector` por:

```dart
        onTap: isEnabled ? _handleTap : null,
```

- [ ] **Step 4: Rodar os testes e confirmar que passam**

Run: `cd app && flutter test test/game_presentation/pixel_element_chip_test.dart`
Expected: PASS (4 testes).

- [ ] **Step 5: Commit**

```bash
git add app/lib/game_presentation/pixel_element_chip.dart app/test/game_presentation/pixel_element_chip_test.dart
git commit -m "$(cat <<'EOF'
Toca som ao tocar PixelElementChip (Bloco 8)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Sons de ataque (cast/impacto) em `AttackSequencePlayer`

**Files:**
- Modify: `app/lib/game_presentation/attack_sequence_player.dart:80-109`
- Test: `app/test/game_presentation/attack_sequence_player_test.dart`

**Interfaces:**
- Consumes: `SfxId.cast`, `SfxId.impact`, `sfxPlayer`, `SfxPlayer({play})`.

- [ ] **Step 1: Escrever os testes falhos**

Em `app/test/game_presentation/attack_sequence_player_test.dart`, adicionar o import:

```dart
import 'package:app/game_domain/attack_event.dart';
import 'package:app/game_presentation/attack_sequence_player.dart';
import 'package:app/game_presentation/battle_character_component.dart';
import 'package:app/game_presentation/sfx_player.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
```

E os dois testes novos ao final do `main()` (depois do teste `'a single large update() call...'`):

```dart
  test('plays the cast sound at the start of the preparation step', () {
    final playedPaths = <String>[];
    sfxPlayer = SfxPlayer(play: playedPaths.add);
    addTearDown(() => sfxPlayer = SfxPlayer());

    final player = _buildPlayer();
    player.update(0.01);

    expect(playedPaths, contains('cast.ogg'));
  });

  test('plays the impact sound when the impact step resolves', () {
    final playedPaths = <String>[];
    sfxPlayer = SfxPlayer(play: playedPaths.add);
    addTearDown(() => sfxPlayer = SfxPlayer());

    final player = _buildPlayer();
    player.update(0.56);

    expect(playedPaths, contains('impact.ogg'));
  });
```

- [ ] **Step 2: Rodar os testes e confirmar que os dois novos falham**

Run: `cd app && flutter test test/game_presentation/attack_sequence_player_test.dart`
Expected: 5 testes antigos PASS, 2 novos FAIL.

- [ ] **Step 3: Implementar os sons de cast e impacto**

Em `app/lib/game_presentation/attack_sequence_player.dart`, adicionar o import:

```dart
import '../game_domain/attack_event.dart';
import 'battle_character_component.dart';
import 'element_visuals.dart';
import 'sfx_player.dart';
```

Editar o método `update` (linhas 80-109) — duas inserções, uma linha cada:

```dart
  @override
  void update(double dt) {
    super.update(dt);

    var remaining = dt;
    while (remaining > 0 && _step != _AttackStep.done) {
      if (_step == _AttackStep.preparation && !_preparationStarted) {
        _preparationStarted = true;
        attacker.playPreparationPulse();
        sfxPlayer.play(SfxId.cast);
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
          sfxPlayer.play(SfxId.impact);
        }
      }
    }

    if (_step == _AttackStep.done && parent != null) {
      removeFromParent();
    }
  }
```

- [ ] **Step 4: Rodar os testes e confirmar que passam**

Run: `cd app && flutter test test/game_presentation/attack_sequence_player_test.dart`
Expected: PASS (7 testes).

- [ ] **Step 5: Commit**

```bash
git add app/lib/game_presentation/attack_sequence_player.dart app/test/game_presentation/attack_sequence_player_test.dart
git commit -m "$(cat <<'EOF'
Toca sons de cast e impacto em AttackSequencePlayer (Bloco 8)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Som de habilidade desbloqueada em `SkillTreeScreen`

**Files:**
- Modify: `app/lib/ui/skill_tree_screen.dart`

**Interfaces:**
- Consumes: `SfxId.unlock`, `sfxPlayer`.

Sem teste dedicado nesta task — o spec ([Testes esperados](../specs/2026-09-11-battle-sound-effects-design.md)) só pede testes para `SfxPlayer`, `PixelMenuButton` e `PixelElementChip`; `sfxPlayer` real já é seguro de chamar em qualquer teste (Task 1), então os testes de `SkillTreeScreen` que já existem continuam passando sem mudança. A confirmação de que o som certo toca fica pela verificação manual da Task 8.

- [ ] **Step 1: Adicionar o import**

Em `app/lib/ui/skill_tree_screen.dart`, junto aos outros imports de `game_presentation/`:

```dart
import '../game_presentation/pixel_sheet_panel.dart';
import '../game_presentation/sfx_player.dart';
import '../game_presentation/skill_tree_layout.dart';
```

- [ ] **Step 2: Tocar o som ao desbloquear com sucesso**

Dentro de `_openNodeDetail`, no `onPressed` do botão "Desbloquear", inserir a chamada logo após o `setState` que adiciona o nó à lista de desbloqueados, antes de fechar o painel:

```dart
                  PixelMenuButton(
                    label: 'Desbloquear',
                    onPressed: () async {
                      final error = await widget.onUnlock(node.id);
                      if (error != null) {
                        if (!sheetContext.mounted) return;
                        ScaffoldMessenger.of(sheetContext).showSnackBar(
                          SnackBar(content: Text(error)),
                        );
                        return;
                      }
                      setState(() => _unlockedNodeIds = [..._unlockedNodeIds, node.id]);
                      sfxPlayer.play(SfxId.unlock);
                      if (!sheetContext.mounted) return;
                      Navigator.of(sheetContext).pop();
                    },
                  ),
```

- [ ] **Step 3: Rodar a suíte de testes de `SkillTreeScreen` e confirmar que nada quebrou**

Run: `cd app && flutter test test/skill_tree_screen_test.dart`
Expected: PASS, sem nenhuma mudança na contagem de testes existente.

- [ ] **Step 4: Rodar `flutter analyze` no app**

Run: `cd app && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add app/lib/ui/skill_tree_screen.dart
git commit -m "$(cat <<'EOF'
Toca som ao desbloquear habilidade na Skill Tree (Bloco 8)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: Som de fim de partida no Treino

**Files:**
- Modify: `app/lib/ui/training_screen.dart`

**Interfaces:**
- Consumes: `SfxId.victory`, `sfxPlayer`.

Sem teste dedicado, mesmo racional da Task 5: `_match.playElementIds(...)` já rejeita jogadas depois que a partida acabou (`training_match_test.dart` cobre isso), então este ponto só é alcançado uma vez por partida — não há novo comportamento condicional pra testar isoladamente, só uma chamada extra e segura.

- [ ] **Step 1: Adicionar o import**

Em `app/lib/ui/training_screen.dart`, junto aos outros imports de `game_presentation/`:

```dart
import '../game_presentation/pixel_sheet_panel.dart';
import '../game_presentation/sfx_player.dart';
import 'skill_tree_screen.dart';
```

- [ ] **Step 2: Tocar o som quando a partida termina**

Dentro de `_playTurn`, no bloco `try`, inserir a chamada logo depois do `if (triggered || appliedStatus.isNotEmpty) { ... }` já existente:

```dart
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
        if (_match.isOver) {
          sfxPlayer.play(SfxId.victory);
        }
```

- [ ] **Step 3: Rodar a suíte de testes de `TrainingScreen` e confirmar que nada quebrou**

Run: `cd app && flutter test test/training_screen_test.dart`
Expected: PASS, sem nenhuma mudança na contagem de testes existente.

- [ ] **Step 4: Rodar `flutter analyze` no app**

Run: `cd app && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add app/lib/ui/training_screen.dart
git commit -m "$(cat <<'EOF'
Toca som de fim de partida no Modo Treino (Bloco 8)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: Sons de vitória/derrota no Multiplayer

**Files:**
- Modify: `app/lib/ui/multiplayer_battle_screen.dart`

**Interfaces:**
- Consumes: `SfxId.victory`, `SfxId.defeat`, `sfxPlayer`, `MultiplayerMatch.isFinished`, `MultiplayerMatch.amIWinner` (já existentes).

Sem teste dedicado, mesmo racional das Tasks 5/6 — `_match.isFinished`/`_match.amIWinner` já são cobertos por `multiplayer_match_test.dart`; a flag nova só evita tocar o som mais de uma vez, comportamento que a verificação manual (Task 8) confirma.

- [ ] **Step 1: Adicionar o import**

Em `app/lib/ui/multiplayer_battle_screen.dart`, junto aos outros imports de `game_presentation/`:

```dart
import '../game_presentation/pixel_sheet_panel.dart';
import '../game_presentation/sfx_player.dart';
import 'skill_tree_screen.dart';
```

- [ ] **Step 2: Adicionar a flag e o método que decide o som**

Na classe `_MultiplayerBattleScreenState`, junto aos outros campos:

```dart
  final Set<String> _selectedIds = {};
  Timer? _pollTimer;
  String? _error;
  bool _startingRematch = false;
  AttackEvent? _pendingAttack;
  int _attackSequenceCounter = 0;
  Set<String> _previousFieldEffectIds = {};
  bool _playedGameOverSound = false;
```

E o método novo, logo depois de `_poll`:

```dart
  void _maybePlayGameOverSound() {
    if (_match.isFinished && !_playedGameOverSound) {
      _playedGameOverSound = true;
      sfxPlayer.play(_match.amIWinner ? SfxId.victory : SfxId.defeat);
    }
  }
```

- [ ] **Step 3: Chamar o método nas duas formas da partida terminar**

Em `_poll`, depois do `setState` existente:

```dart
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
      _maybePlayGameOverSound();
    }
  }
```

Em `_playTurn`, depois do `setState` do caminho de sucesso:

```dart
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
      _maybePlayGameOverSound();
    } catch (_) {
      setState(() => _error = _match.lastError ?? 'Jogada inválida.');
    }
  }
```

- [ ] **Step 4: Rodar a suíte de testes de `MultiplayerBattleScreen` e confirmar que nada quebrou**

Run: `cd app && flutter test test/multiplayer_battle_screen_test.dart`
Expected: PASS, sem nenhuma mudança na contagem de testes existente.

- [ ] **Step 5: Rodar `flutter analyze` no app**

Run: `cd app && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add app/lib/ui/multiplayer_battle_screen.dart
git commit -m "$(cat <<'EOF'
Toca som de vitória/derrota no fim de partida Multiplayer (Bloco 8)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: Suíte completa, verificação manual e documentação

**Files:**
- Modify: `DECISIONS.md`
- Modify: `TASKS.md`

**Interfaces:**
- Nenhuma — task de fechamento, sem código novo.

- [ ] **Step 1: Rodar a suíte completa do app**

Run: `cd app && flutter test`
Expected: todos os testes PASS (os existentes + os novos de `sfx_player_test.dart`, `pixel_menu_button_test.dart`, `pixel_element_chip_test.dart`, `attack_sequence_player_test.dart`).

- [ ] **Step 2: Rodar `flutter analyze` uma última vez no app**

Run: `cd app && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Verificar manualmente via `flutter run -d web-server`**

Abrir o app (reiniciar o preview com `preview_stop` + `preview_start` — nunca só recarregar, ver Global Constraints), e confirmar:
- Tocar qualquer `PixelMenuButton`/`PixelElementChip` (ex: "Modo Treino" na Home, escolher um elemento no Treino) dispara som no navegador.
- Jogar um turno que dispare combinação no Treino toca o som de cast e, ao avançar a sequência de ataque, o som de impacto.
- Desbloquear um nó na Skill Tree toca o som de unlock.
- Terminar uma partida de Treino toca o som de vitória.
- Não há erros no console do navegador (`read_console_messages`) nem requisições de áudio falhando (`read_network_requests`).

(Multiplayer real depende de duas sessões simultâneas — não é praticamente verificável nesta máquina; fica coberto pela suíte automatizada da Task 7 e pela mesma limitação já registrada para o resto do fluxo multiplayer.)

- [ ] **Step 4: Registrar DECISION-042 em `DECISIONS.md`**

Ler `DECISIONS.md`, localizar a última entrada (`DECISION-041`), e adicionar uma nova entrada `DECISION-042` logo depois, seguindo o formato já usado pelas entradas anteriores (contexto/decisão/motivo), cobrindo:
- Bloco 8 (áudio) adicionado — primeiro som do jogo, via `flame_audio` + `SfxPlayer` global.
- 6 sons CC0 (Kenney) escolhidos sem audição — sujeitos a troca futura pelo usuário.
- Escopo explícito: só SFX; música de fundo e mute/unmute ficam pra depois.
- `sfxPlayer` é a única variável global mutável do código-base, por design, pra permitir troca em teste.

- [ ] **Step 5: Atualizar `TASKS.md`**

Ler `TASKS.md` e:
- Mover a entrada do Bloco 8 (áudio) para DONE, referenciando DECISION-042.
- Adicionar ao BACKLOG (se ainda não estiverem lá): "Botão de mutar/desmutar — precisa de tela de configurações (ainda não existe)." e "Música de fundo (loop/fade/mixagem) — bloco futuro."

- [ ] **Step 6: Commit**

```bash
git add DECISIONS.md TASKS.md
git commit -m "$(cat <<'EOF'
Registra DECISION-042 e atualiza TASKS.md (efeitos sonoros)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review

**Cobertura do spec:**
- Sons escolhidos/fontes → Task 1 (download + validação com `file`).
- Dependência + convenção de assets → Task 1.
- `SfxPlayer`/`SfxId`/`sfxPlayer` global → Task 1.
- Toque de botão/chip → Tasks 2 e 3.
- Ataque (cast) e impacto → Task 4.
- Habilidade desbloqueada → Task 5.
- Vitória (Treino) → Task 6.
- Vitória/derrota (Multiplayer) → Task 7.
- Testes esperados (`sfx_player_test`, `pixel_menu_button_test`, `pixel_element_chip_test`) → Tasks 1-3; testes extras de `attack_sequence_player_test` (não exigidos pelo spec, mas consistentes com "toda lógica importante precisa de teste" do CLAUDE.md, e simples de fazer com o mesmo padrão de troca de `sfxPlayer`) → Task 4.
- "Nenhum teste existente deveria quebrar" → confirmado a cada task (roda a suíte da tela tocada) e na suíte completa (Task 8).
- Verificação manual via web-server → Task 8.
- Fora de escopo (música, mute, volumes) → registrado no BACKLOG na Task 8, não implementado em nenhuma task.

**Placeholder scan:** nenhum "TBD"/"depois"/passo sem código real — todo Step de código tem o trecho exato a escrever; os únicos steps sem bloco de código são leituras/commits/comandos de verificação, que são ações diretas, não lacunas.

**Consistência de tipos:** `SfxId` (tap/cast/impact/unlock/victory/defeat), `SfxPlayer({play})`, `sfxPlayer.play(SfxId)` usados identicamente em todas as tasks (2-7); nomes de arquivo (`tap.wav`, `cast.ogg`, etc.) idênticos entre o mapa `_paths` da Task 1, os downloads da Task 1 e as expectativas dos testes das Tasks 2-4.
