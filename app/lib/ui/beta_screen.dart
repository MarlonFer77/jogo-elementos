import 'dart:ui' show FramePhase, FrameTiming;
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../game_domain/beta_session.dart';
import '../game_presentation/beta_game.dart';
import '../game_presentation/beta_arena_painter.dart' show betaElementColor;
import '../game_presentation/pixel_content_panel.dart';
import '../game_presentation/pixel_menu_button.dart';
import 'beta_controls.dart';

class BetaScreen extends StatefulWidget {
  const BetaScreen({super.key});
  @override
  State<BetaScreen> createState() => _BetaScreenState();
}

class _BetaScreenState extends State<BetaScreen> with WidgetsBindingObserver {
  final _game = BetaGame();
  final _focus = FocusNode();
  final _keys = <LogicalKeyboardKey>{};
  Size? _viewport;
  bool _collecting = false;
  bool _exitPromptOpen = false, _exitApproved = false;
  int _timingStart = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _game.hud.addListener(_syncTimings);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _game.reduceMotion = MediaQuery.disableAnimationsOf(context);
    final size = MediaQuery.sizeOf(context);
    if (_viewport != null && _viewport != size) {
      // Resize replaces the controls; don't inherit a finger from the old layout.
      _keys.clear();
      _game.session.pause();
      _game.pauseEngine();
      _syncTimings();
    }
    _viewport = size;
  }

  void _syncTimings() {
    final collect =
        _game.performance.enabled && _game.session.playing && !_game.paused;
    if (collect == _collecting) return;
    _collecting = collect;
    if (collect) {
      _timingStart =
          SchedulerBinding.instance.currentSystemFrameTimeStamp.inMicroseconds;
      SchedulerBinding.instance.addTimingsCallback(_recordTimings);
    } else {
      SchedulerBinding.instance.removeTimingsCallback(_recordTimings);
    }
  }

  void _recordTimings(List<FrameTiming> timings) {
    if (!mounted || !_collecting || !_game.session.playing || _game.paused) {
      return;
    }
    for (final frame in timings) {
      if (frame.timestampInMicroseconds(FramePhase.vsyncStart) <=
          _timingStart) {
        continue;
      }
      _game.performance.recordFrame(
        frame.buildDuration.inMicroseconds / 1000,
        frame.rasterDuration.inMicroseconds / 1000,
      );
    }
  }

  Future<void> _copyDiagnostics() async {
    final run = _game.session;
    final size = _viewport!;
    final metrics = _game.performance.report;
    final encounter = run.wave;
    final density = MediaQuery.devicePixelRatioOf(context);
    var version = 'versão indisponível';
    try {
      final info = await PackageInfo.fromPlatform();
      version = '${info.version}+${info.buildNumber}';
    } catch (_) {
      // Diagnostics still work if the platform plugin is unavailable.
    }
    if (!mounted) return;
    final mode = kReleaseMode
        ? 'release'
        : kProfileMode
        ? 'profile'
        : 'debug';
    await Clipboard.setData(
      ClipboardData(
        text:
            'Elementos BETA TEST · $version · $mode · ${defaultTargetPlatform.name}\n'
            '${size.width.round()}×${size.height.round()} lógicos · DPR $density · encontro $encounter/3\n'
            '$metrics\nInforme também modelo do celular, tempo jogado e problema percebido.',
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Diagnóstico copiado. Nenhum dado foi enviado.'),
      ),
    );
  }

  void _pause() {
    _keys.clear();
    _game.session.pause();
    _game.pauseEngine();
    _game.refresh();
  }

  void _play() {
    if (_exitPromptOpen || _exitApproved) return;
    _keys.clear();
    if (_game.session.phase == BetaPhase.ready) {
      _game.session.start();
    } else {
      _game.session.resume();
    }
    _game.resumeEngine();
    _game.refresh();
    _focus.requestFocus();
  }

  Future<void> _requestExit() async {
    if (_exitPromptOpen || _exitApproved) return;
    _pause();
    if (_game.session.phase == BetaPhase.paused) {
      _exitPromptOpen = true;
      final discard = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => Dialog(
          backgroundColor: Colors.transparent,
          child: SingleChildScrollView(
            child: PixelContentPanel(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'SAIR DA RUÍNA?',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Esta sessão não tem salvamento. Ao sair, você perde '
                    'o nível e os encontros atuais. Os outros modos não serão alterados.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  PixelMenuButton(
                    label: 'Continuar na pausa',
                    primary: true,
                    onPressed: () => Navigator.pop(dialogContext, false),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF7C3429),
                    ),
                    child: const Text('Sair e descartar sessão'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      if (!mounted) return;
      _exitPromptOpen = false;
      if (discard != true) return; // Cancel remains paused, with no held input.
    }
    if (!mounted) return;
    setState(() => _exitApproved = true);
    // Rebuild PopScope before leaving, including Android's predictive back.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _pause();
    // Resume is explicit; switching apps never leaves a held joystick running.
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_collecting) {
      SchedulerBinding.instance.removeTimingsCallback(_recordTimings);
    }
    _game.hud.removeListener(_syncTimings);
    _game.close();
    _focus.dispose();
    super.dispose();
  }

  void _key(KeyEvent event) {
    final key = event.logicalKey;
    if (event is KeyUpEvent) {
      _keys.remove(key);
    } else {
      _keys.add(key);
    }
    final run = _game.session;
    double direction(
      LogicalKeyboardKey a,
      LogicalKeyboardKey b,
      LogicalKeyboardKey c,
      LogicalKeyboardKey d,
    ) =>
        (_keys.contains(a) || _keys.contains(b) ? 1.0 : 0.0) -
        (_keys.contains(c) || _keys.contains(d) ? 1.0 : 0.0);
    run.setMovement(
      direction(
        LogicalKeyboardKey.keyD,
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.keyA,
        LogicalKeyboardKey.arrowLeft,
      ),
      direction(
        LogicalKeyboardKey.keyS,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.keyW,
        LogicalKeyboardKey.arrowUp,
      ),
    );
    if (event is! KeyDownEvent) return;
    if (key == LogicalKeyboardKey.escape) {
      _pause();
      return;
    }
    if (key == LogicalKeyboardKey.keyJ) run.request(BetaAction.sword);
    if (key == LogicalKeyboardKey.keyK) run.request(BetaAction.cast);
    if (key == LogicalKeyboardKey.space) run.request(BetaAction.dodge);
    final index = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
    ].indexOf(key);
    if (index >= 0) run.select(BetaElement.values[index]);
    _game.refresh();
  }

  @override
  Widget build(BuildContext context) => KeyboardListener(
    focusNode: _focus,
    autofocus: true,
    onKeyEvent: _key,
    child: ValueListenableBuilder<int>(
      valueListenable: _game.hud,
      builder: (context, _, _) {
        final run = _game.session;
        return PopScope(
          canPop:
              _exitApproved ||
              run.phase == BetaPhase.ready ||
              ((run.phase == BetaPhase.won || run.phase == BetaPhase.lost) &&
                  !run.settling),
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (run.playing || run.settling) {
              _pause();
            } else {
              _requestExit();
            }
          },
          child: Scaffold(
            backgroundColor: const Color(0xFF243F3D),
            body: Stack(
              fit: StackFit.expand,
              children: [
                RepaintBoundary(child: GameWidget(game: _game)),
                SafeArea(
                  child: Stack(
                    children: [
                      if (run.phase != BetaPhase.ready)
                        Positioned(
                          top: 8,
                          left: 8,
                          right: 8,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _hud(run),
                              if (run.playing &&
                                  (run.messageTime > 0 ||
                                      run.nextEncounterIn > 0))
                                _notice(run),
                            ],
                          ),
                        ),
                      if (run.playing) ...[
                        Positioned(
                          left: 12,
                          bottom: 20,
                          child: BetaJoystick(
                            onChanged: run.setMovement,
                            size: MediaQuery.sizeOf(context).width < 350
                                ? 96
                                : 112,
                          ),
                        ),
                        Positioned(
                          right: 10,
                          bottom: 10,
                          child: BetaActionPad(
                            run: run,
                            refresh: _game.refresh,
                          ),
                        ),
                      ] else if (!run.settling)
                        Positioned.fill(child: _overlay(run)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  Widget _notice(BetaSession run) => IgnorePointer(
    child: Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        color: const Color(0xE6263E35),
        child: Text(
          run.nextEncounterIn > 0
              ? 'ENCONTRO ${run.wave} CONCLUÍDO · próximo em ${run.nextEncounterIn.ceil()}s\n'
                    'Ao iniciar: recupera até 20 HP e 25 MP'
              : run.message,
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFFFFE2A3), fontSize: 11),
        ),
      ),
    ),
  );

  Widget _hud(BetaSession run) {
    final critical = run.hp > 0 && run.hp <= run.maxHp * .25;
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.orientationOf(context) == Orientation.landscape
              ? 285
              : 360,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xED263E35),
            border: Border.all(
              color: critical
                  ? const Color(0xFFE8A17E)
                  : const Color(0xFFABAE86),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BETA TEST · Nível ${run.level} · Encontro ${run.wave}/3',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFF3DFB5),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    _bar(
                      'HP ${run.hp.ceil()}/${run.maxHp.round()}',
                      run.hp / run.maxHp,
                      critical
                          ? const Color(0xFFE8A17E)
                          : const Color(0xFFB7CA86),
                      trail: _game.healthTrail,
                    ),
                    const SizedBox(height: 3),
                    _bar(
                      'MP ${run.mana.floor()}/100',
                      run.mana / 100,
                      const Color(0xFF83BCC7),
                    ),
                    Text(
                      critical
                          ? 'VIDA BAIXA · Água cura ao acertar'
                          : '${run.xp}/${run.nextLevelXp} XP · ${run.remaining} inimigos · progresso temporário',
                      style: TextStyle(
                        fontSize: 10,
                        color: critical
                            ? const Color(0xFFFFC4A1)
                            : const Color(0xFFD0D5B7),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Pausar beta',
                onPressed: run.playing ? _pause : null,
                icon: const Icon(Icons.pause, color: Color(0xFFF3DFB5)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bar(String label, double value, Color color, {double? trail}) =>
      Semantics(
        label: label,
        child: ExcludeSemantics(
          child: Row(
            children: [
              SizedBox(
                width: 78,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFFF2E9CC),
                  ),
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    if (trail != null)
                      LinearProgressIndicator(
                        value: trail.clamp(value.clamp(0, 1), 1),
                        color: const Color(0xFF8B7857),
                        backgroundColor: const Color(0xFF51624D),
                        minHeight: 5,
                      ),
                    LinearProgressIndicator(
                      value: value.clamp(0, 1),
                      color: color,
                      backgroundColor: trail == null
                          ? const Color(0xFF51624D)
                          : Colors.transparent,
                      minHeight: 5,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _overlay(BetaSession run) {
    final ready = run.phase == BetaPhase.ready,
        paused = run.phase == BetaPhase.paused;
    return ColoredBox(
      color: const Color(0x88203933),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: PixelContentPanel(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    ready
                        ? 'RUÍNA DOS ECOS'
                        : paused
                        ? 'BETA PAUSADO'
                        : run.phase == BetaPhase.won
                        ? 'GUARDIÃO DERROTADO'
                        : 'A RUÍNA RESISTIU',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ready
                        ? 'Vença três encontros e derrote o guardião.\n'
                              'Mova e mire com o joystick; ataque, conjure e desvie.\n'
                              'Progresso temporário: sair encerra esta sessão.'
                        : paused
                        ? 'O tempo está parado. Seu progresso neste beta dura somente até sair.'
                        : '${run.phase == BetaPhase.won ? 'Três encontros concluídos.' : 'Você caiu no encontro ${run.wave}/3.'}\n'
                              '${run.kills} inimigos · ${run.xp} XP · nível ${run.level}\n'
                              'Progresso desta sessão; seus outros modos não são alterados.',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  PixelMenuButton(
                    label: ready
                        ? 'Entrar na ruína'
                        : paused
                        ? 'Retomar'
                        : 'Testar novamente',
                    primary: true,
                    onPressed: () {
                      if (!ready && !paused) _game.restart();
                      _play();
                    },
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF314C40),
                    ),
                    onPressed: _requestExit,
                    child: const Text('Voltar ao menu'),
                  ),
                  _combatGuide(),
                  ExpansionTile(
                    iconColor: const Color(0xFF314C40),
                    collapsedIconColor: const Color(0xFF314C40),
                    title: const Text(
                      'Diagnóstico local',
                      style: TextStyle(fontSize: 13),
                    ),
                    tilePadding: EdgeInsets.zero,
                    children: [
                      SwitchListTile.adaptive(
                        activeThumbColor: const Color(0xFFE5D6AF),
                        activeTrackColor: const Color(0xFF3B685D),
                        inactiveThumbColor: const Color(0xFFE5D6AF),
                        inactiveTrackColor: const Color(0xFFABB193),
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Medir desempenho',
                          style: TextStyle(fontSize: 13),
                        ),
                        value: _game.performance.enabled,
                        onChanged: (value) {
                          _game.performance.enabled = value;
                          if (value) _game.performance.reset();
                          _game.refresh();
                        },
                      ),
                      const Text(
                        'Ative, jogue e pause para consultar as últimas amostras. '
                        'Para comparar fluidez, use APK release no celular. Coleta apenas local e temporária.',
                        style: TextStyle(fontSize: 11),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _game.performance.report,
                        style: const TextStyle(fontSize: 11),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF314C40),
                        ),
                        onPressed: _copyDiagnostics,
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copiar diagnóstico'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _combatGuide() => ExpansionTile(
    key: const PageStorageKey('beta-combat-guide'),
    iconColor: const Color(0xFF314C40),
    collapsedIconColor: const Color(0xFF314C40),
    tilePadding: EdgeInsets.zero,
    title: const Text('Guia de combate', style: TextStyle(fontSize: 13)),
    children: [
      const Text(
        'Alvo dourado: espada no alcance. Azul: aproxime-se ou use magia. '
        'Colunas bloqueiam golpes e disparos. Magia custa 25 MP; mana retorna sozinha.',
        style: TextStyle(fontSize: 12),
      ),
      const SizedBox(height: 8),
      for (final element in BetaElement.values)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 3, right: 8),
                color: betaElementColor(element),
              ),
              Expanded(
                child: Text(
                  '${element.label} · ${element.description}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      const SizedBox(height: 8),
      const Text(
        'Goblin: desvie de lado. Bruto: contorne a varredura. '
        'Guardião: saia do círculo. Ataque quando aparecer “Recuperando”.\n\n'
        'Teclado: WASD/setas · J espada · K magia · Espaço esquiva · 1–4 elementos.',
        style: TextStyle(fontSize: 12),
      ),
      const SizedBox(height: 8),
    ],
  );
}
