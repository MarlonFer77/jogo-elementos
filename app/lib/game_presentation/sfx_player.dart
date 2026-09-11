import 'dart:async';

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
    // `FlameAudio.play` acessa bindings de plataforma (platform channels)
    // durante a preparação do player; em contexto sem binding
    // inicializado (ex: `flutter test` fora de `testWidgets`) essa falha
    // escapa do try/catch normal e do `.catchError` do Future, porque
    // surge de dentro da configuração de um listener de stream, não do
    // corpo `async` em si. `runZonedGuarded` é a única forma de garantir
    // que nenhum erro de áudio, síncrono ou assíncrono, derruba o app —
    // ou o teste.
    runZonedGuarded(() {
      // ignore: discarded_futures
      FlameAudio.play(path).catchError((_) {});
    }, (_, __) {});
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
