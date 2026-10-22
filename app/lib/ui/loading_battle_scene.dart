import 'package:flutter/material.dart';

import '../game_presentation/beta_arena_painter.dart';
import '../game_presentation/pixel_outlined_text.dart';
import '../game_presentation/sfx_player.dart';
import '../settings/game_settings.dart';

/// Startup illustration only. UpdateGate remains the authority for navigation.
class LoadingBattleScene extends StatefulWidget {
  const LoadingBattleScene({
    super.key,
    required this.ready,
    required this.onPresented,
    required this.onEnter,
    this.audio,
  });
  final bool ready;
  final VoidCallback onPresented, onEnter;
  final SfxPlayer? audio;

  @override
  State<LoadingBattleScene> createState() => _LoadingBattleSceneState();
}

class _LoadingBattleSceneState extends State<LoadingBattleScene>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _clock;
  late final LoadingBattlePainter _art;
  late final _audio = widget.audio ?? SfxPlayer();
  bool _presented = false, _active = true, _reduced = false, _visible = true;
  double _previous = 0;
  static const _sounds = [
    (.78, SfxId.defend),
    (1.55, SfxId.swing),
    (1.71, SfxId.impact),
    (3.05, SfxId.wings),
    (4.65, SfxId.cast),
    (5.0, SfxId.light),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _active =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _clock = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..addListener(_tick);
    _art = LoadingBattlePainter(_clock);
    gameSettings.addListener(_syncAudio);
  }

  void _syncAudio() => _audio.volume = _active && _visible && !_reduced
      ? gameSettings.effectiveVolume * .45
      : 0;

  void _tick() {
    final seconds = _clock.value * 8;
    if (seconds < _previous) _previous = 0;
    if (_active && _visible && !_reduced) {
      for (final cue in _sounds) {
        if (_previous < cue.$1 &&
            seconds >= cue.$1 &&
            seconds - _previous < .3) {
          _audio.play(cue.$2);
        }
      }
    }
    _previous = seconds;
    if (!_presented && seconds >= 3 && _active && _visible) {
      _presented = true;
      widget.onPresented();
    }
  }

  void _syncMotion() {
    _syncAudio();
    if (_active && _visible && !_reduced) {
      if (!_clock.isAnimating) _clock.repeat();
    } else {
      _clock.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    _visible = TickerMode.valuesOf(context).enabled;
    _syncMotion();
    if (_reduced && !_presented) {
      _presented = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onPresented();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() => _active = state == AppLifecycleState.resumed);
    _syncMotion();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    gameSettings.removeListener(_syncAudio);
    _audio.volume = 0;
    _clock.dispose();
    _art.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF142B2C),
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth > constraints.maxHeight;
          final footer = Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.ready
                      ? 'Pronto para a aventura'
                      : 'Verificando atualização…',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFF4E9CC),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 10),
                Semantics(
                  label: widget.ready
                      ? 'Preparação concluída'
                      : 'Preferências carregadas. Consultando versão.',
                  child: ExcludeSemantics(
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF102122),
                        border: Border.all(
                          color: const Color(0xFFB9A270),
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: LinearProgressIndicator(
                              value: 1,
                              minHeight: 8,
                              color: Color(0xFFE2C37D),
                              backgroundColor: Color(0xFF354C46),
                            ),
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: LinearProgressIndicator(
                              value: widget.ready
                                  ? 1
                                  : _reduced || !_active
                                  ? 0
                                  : null,
                              minHeight: 8,
                              color: const Color(0xFFE2C37D),
                              backgroundColor: const Color(0xFF354C46),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'PREFERÊNCIAS  ·  VERSÃO',
                  style: TextStyle(
                    color: Color(0xFFBDBB9E),
                    fontSize: 10,
                    letterSpacing: 1,
                  ),
                ),
                TextButton(
                  onPressed: widget.ready ? widget.onEnter : null,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFF4D782),
                    disabledForegroundColor: const Color(0xFF9BADA2),
                  ),
                  child: Text(
                    widget.ready
                        ? 'Toque para entrar'
                        : 'Preparando sua jornada',
                  ),
                ),
              ],
            ),
          );
          final title = Padding(
            padding: const EdgeInsets.all(12),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const PixelOutlinedText(
                    'ELEMENTOS',
                    fontSize: 34,
                    color: Color(0xFFF4D782),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'ANJO DA AURORA',
                    style: TextStyle(
                      color: Color(0xFFD1D5B6),
                      fontSize: 11,
                      letterSpacing: 3,
                    ),
                  ),
                ],
              ),
            ),
          );
          final battle = Expanded(
            child: Semantics(
              image: true,
              label: 'Anjo da Aurora enfrentando três goblins nas ruínas.',
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _art,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          );
          if (wide) {
            return Row(
              children: [
                battle,
                SizedBox(
                  width: constraints.maxWidth * .4,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(child: title),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: SizedBox(
                            width: constraints.maxWidth * .4,
                            child: footer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
          return Column(children: [title, battle, footer]);
        },
      ),
    ),
  );
}
