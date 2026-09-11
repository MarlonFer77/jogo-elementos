# Efeitos sonoros (Bloco 8) — design

Data: 2026-09-11
Status: aprovado pelo usuário, pronto para virar plano de implementação.

## Contexto

O jogo hoje não tem nenhum som — sem efeito de ataque/dano/vitória/derrota,
sem feedback sonoro em botões. Próximo item sem bloco dedicado na ordem de
prioridade do CLAUDE.md ("Direção de produto (game feel)"): áudio.

Diferente da arte pixel art (gerada em código), som não dá pra "desenhar"
— precisa de arquivos de verdade. Confirmado com o usuário: eu busco sons
livres (CC0) na internet; escopo deste bloco é só efeitos sonoros (SFX),
sem música de fundo (fica pra um bloco futuro — complexidade própria de
loop/fade/mixagem); sem botão de mutar (sem tela de configurações hoje,
fica registrado no BACKLOG).

**Limitação importante**: não consigo ouvir áudio. Os arquivos abaixo
foram escolhidos por nome/categoria/tamanho dos pacotes CC0, não por
audição — o usuário pode precisar trocar algum depois de ouvir no app de
verdade. Isso é esperado, não um defeito do processo.

## Sons escolhidos e fonte (baixados e validados de verdade — não é suposição)

Todos vêm de pacotes CC0 do Kenney (kenney.nl), via dois espelhos
confiáveis já testados com `curl` real durante o brainstorming (arquivo
baixado, formato de áudio confirmado com `file`):

| Evento | Arquivo final | Fonte |
|---|---|---|
| Toque de botão/chip | `assets/audio/tap.wav` | `https://raw.githubusercontent.com/Calinou/kenney-ui-audio/master/addons/kenney_ui_audio/click1.wav` |
| Ataque disparado (preparação) | `assets/audio/cast.ogg` | `https://gamesounds.xyz/Kenney's%20Sound%20Pack/Sci-Fi%20Sounds/laserRetro_000.ogg` |
| Impacto/dano | `assets/audio/impact.ogg` | `https://gamesounds.xyz/Kenney's%20Sound%20Pack/Impact%20Sounds/impactPunch_heavy_000.ogg` |
| Habilidade desbloqueada | `assets/audio/unlock.ogg` | `https://gamesounds.xyz/Kenney's%20Sound%20Pack/Music%20Jingles/Audio%20(Retro)/jingles-retro_00.ogg` |
| Vitória | `assets/audio/victory.ogg` | `https://gamesounds.xyz/Kenney's%20Sound%20Pack/Music%20Jingles/Audio%20(Retro)/jingles-retro_12.ogg` |
| Derrota | `assets/audio/defeat.ogg` | `https://gamesounds.xyz/Kenney's%20Sound%20Pack/Music%20Jingles/Audio%20(Retro)/jingles-retro_08.ogg` |

Licença CC0 (domínio público) em ambos os espelhos — confirmado durante o
brainstorming. `gamesounds.xyz` exige as aspas/parênteses do nome da pasta
escapados na URL (`%20`, `%27`, `%28`/`%29`) — os links acima já estão
corretos, prontos pra `curl -sL "<url>" -o <destino>`.

## O que NÃO está neste bloco

- Sem música de fundo (loop/fade/mixagem — bloco futuro).
- Sem botão de mutar/desmutar (sem tela de configurações hoje — registrado
  no BACKLOG).
- Sem volumes individuais ajustáveis por som — todos tocam no volume
  padrão do `flame_audio`.
- Nenhuma mudança em `battle_engine`/backend — puramente apresentação.

## Dependência e assets

`flame_audio` (v2.12.2, pacote oficial do Flame, ativo). Convenção do
próprio pacote: arquivos em `assets/audio/`, declarados em
`pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/audio/
```

## `SfxPlayer` (`game_presentation/sfx_player.dart`, novo)

```dart
enum SfxId { tap, cast, impact, unlock, victory, defeat }

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
    // Áudio nunca deve derrubar o jogo — qualquer falha (sem player
    // disponível, ex: rodando em teste, ou plataforma sem suporte)
    // é silenciosamente ignorada.
    try {
      // ignore: discarded_futures
      FlameAudio.play(path).catchError((_) {});
    } catch (_) {
      // ignore
    }
  }

  void play(SfxId id) => _play(_paths[id]!);
}

/// Instância única — chamada direto de qualquer lugar do app
/// (`sfxPlayer.play(SfxId.tap)`), sem precisar injetar em cada widget.
/// Segura em teste (nenhum handler de platform channel registrado)
/// porque `_defaultPlay` ignora qualquer erro. **Não é `final`** — de
/// propósito: testes de `PixelMenuButton`/`PixelElementChip` (Bloco 8)
/// substituem por uma instância com `play` injetado, sem precisar mudar
/// a API pública desses dois widgets. Único lugar do código que
/// reatribui essa variável.
SfxPlayer sfxPlayer = SfxPlayer();
```

O construtor com `play` injetável serve pra dois usos: testar `SfxPlayer`
isoladamente (verificar que `play(id)` resolve pro caminho certo), e
substituir a instância global `sfxPlayer` nos testes de
`PixelMenuButton`/`PixelElementChip` — só nesses dois arquivos de teste,
com `setUp`/`tearDown`:

```dart
setUp(() {
  sfxPlayer = SfxPlayer(play: (path) => playedPaths.add(path));
});
tearDown(() {
  sfxPlayer = SfxPlayer(); // restaura a instância real (segura, ignora erro)
});
```

Todo o resto do app (e todos os outros arquivos de teste — telas que já
usam `PixelMenuButton`/`PixelElementChip` sem se importar com áudio)
continua usando a instância global real sem nenhuma mudança, porque ela
já é segura de chamar em qualquer contexto.

## Pontos de integração

**Toque de botão/chip** — `PixelMenuButton`/`PixelElementChip`
(`game_presentation/`): o `GestureDetector.onTap` de cada um passa a
chamar `sfxPlayer.play(SfxId.tap)` antes de repassar pro callback
original, só quando o widget está habilitado (`onPressed`/`onTap` não
nulo — mesma condição que já decide se o toque faz algo). Como fica
dentro dos dois componentes compartilhados, **todo botão do app ganha som
automaticamente** — nenhuma das ~20 telas/usos precisa mudar.

**Ataque/impacto** — `AttackSequencePlayer`
(`game_presentation/attack_sequence_player.dart`, já existente do
Bloco 1): `sfxPlayer.play(SfxId.cast)` no mesmo `if` que já dispara
`attacker.playPreparationPulse()` (início do passo de preparação);
`sfxPlayer.play(SfxId.impact)` no mesmo `if` que já chama
`target.playHitEffect()` (transição pro passo de impacto). Afeta Treino e
Multiplayer igual, já que os dois usam o mesmo componente.

**Habilidade desbloqueada** — `SkillTreeScreen`
(`ui/skill_tree_screen.dart`, já existente do Bloco 7): dentro do botão
"Desbloquear" do painel de detalhe, `sfxPlayer.play(SfxId.unlock)` logo
após `widget.onUnlock(node.id)` devolver sucesso (`error == null`), antes
de fechar o painel.

**Vitória/derrota**:
- `TrainingScreen` (`_playTurn`): hotseat, sem "você" — toca
  `SfxId.victory` (genérico, "fim de partida") uma vez, logo depois que
  `_match.playElementIds(...)` resulta em `_match.isOver == true`. Não
  precisa de flag de controle: `playElementIds` já rejeita jogar de novo
  depois que a partida acabou, então esse ponto só é alcançado uma vez.
- `MultiplayerBattleScreen`: tem "você" de verdade
  (`_match.amIWinner`) — toca `SfxId.victory` ou `SfxId.defeat` conforme
  o caso, exatamente uma vez quando `_match.isFinished` vira `true` pela
  primeira vez. Precisa de uma flag nova (`bool _playedGameOverSound`,
  inicia `false`) checada/setada tanto no fim de `_poll()` quanto no fim
  de `_playTurn()` bem-sucedido (as duas formas da partida terminar:
  você jogou o golpe final, ou o oponente jogou e o polling percebeu).

## Testes esperados

- `sfx_player_test.dart` (novo): `SfxPlayer` com `play` injetado —
  `play(SfxId.tap)` chama a função injetada com `'tap.wav'`; um teste por
  `SfxId` confirmando o caminho certo (ou um `for` sobre `SfxId.values`
  com uma tabela esperada).
- `pixel_menu_button_test.dart`/`pixel_element_chip_test.dart`: um teste
  novo em cada, substituindo `sfxPlayer` por uma instância com `play`
  injetado (`setUp`/`tearDown` como descrito acima), confirmando que
  tocar no widget habilitado chama `sfxPlayer.play` com `'tap.wav'`, e
  que tocar no widget desabilitado (`onPressed`/`onTap` nulo) não chama
  nada.
- Nenhum teste existente deveria quebrar — `sfxPlayer` real é seguro de
  chamar em qualquer ambiente de teste (erro sempre ignorado).
- Verificação manual: como esta máquina não builda Android, a real
  confirmação de "o som toca e soa bem" fica pro usuário no próximo APK —
  mas dá pra rodar `flutter run -d web-server` e confirmar que os sons
  tocam no navegador também (Web tem suporte de áudio), o que já valida
  a integração sem precisar esperar o Android.

## Fora de escopo, mas não esquecido

- Música de fundo — bloco futuro.
- Botão de mutar/desmutar — precisa de uma tela de configurações que não
  existe ainda; registrar no BACKLOG.
- Volumes individuais por som — YAGNI, não pedido.
