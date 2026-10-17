import 'dart:ui' show FramePhase, FrameTiming;
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../game_domain/beta_session.dart';
import '../game_domain/cosmetics.dart';
import '../game_presentation/beta_game.dart';
import '../game_presentation/beta_arena_painter.dart' show betaElementColor;
import '../game_presentation/pixel_content_panel.dart';
import '../game_presentation/pixel_menu_button.dart';
import 'beta_controls.dart';
import 'beta_build_panel.dart';
import 'beta_status_readout.dart';

class BetaScreen extends StatefulWidget {
  const BetaScreen({
    super.key,
    this.outfit = HeroOutfit.traveler,
    this.loadout = const BetaLoadout(),
  });
  final HeroOutfit outfit;
  final BetaLoadout loadout;
  @override
  State<BetaScreen> createState() => _BetaScreenState();
}

class _BetaScreenState extends State<BetaScreen> with WidgetsBindingObserver {
  late final _game = BetaGame(outfit: widget.outfit, loadout: widget.loadout);
  final _focus = FocusNode();
  final _keys = <LogicalKeyboardKey>{};
  Size? _viewport;
  bool _collecting = false;
  bool _exitPromptOpen = false, _exitApproved = false;
  int _timingStart = 0;
  int _inputRegion = 1;
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
    if (_inputRegion != _game.session.wave) {
      _inputRegion = _game.session.wave;
      _keys.clear();
    }
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
    final region = run.region.title;
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
            '${size.width.round()}×${size.height.round()} lógicos · DPR $density · área $encounter/${BetaRegion.values.length} · $region\n'
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

  Future<void> _openBuild() async {
    _keys.clear();
    await showDialog<void>(
      context: context,
      barrierColor: const Color(0xEF14251F),
      builder: (_) => BetaBuildPanel(
        run: _game.session,
        outfit: _game.outfit,
        onChanged: _game.refresh,
      ),
    );
    if (mounted) _game.refresh();
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
    if (key == LogicalKeyboardKey.keyE) run.attune();
    if (key == LogicalKeyboardKey.keyH) run.revealPuzzleHint();
    final index = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
    ].indexOf(key);
    if (index >= 0) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        run.mix(BetaElement.values[index]);
      } else {
        run.select(BetaElement.values[index]);
      }
    }
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
                                      run.nextEncounterIn > 0 ||
                                      run.puzzleActive ||
                                      run.passageOpen))
                                _notice(run),
                            ],
                          ),
                        ),
                      if (run.playing) ...[
                        Positioned(
                          left: 12,
                          bottom: 20,
                          child: BetaJoystick(
                            key: ValueKey('beta-movement-${run.wave}'),
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
                            key: ValueKey('beta-actions-${run.wave}'),
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

  Widget _notice(BetaSession run) => Align(
    alignment: MediaQuery.orientationOf(context) == Orientation.landscape
        ? Alignment.topLeft
        : Alignment.center,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.orientationOf(context) == Orientation.landscape
            ? 285
            : double.infinity,
      ),
      child: IgnorePointer(
        child: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: const Color(0xE6263E35),
            child: Text(
              run.puzzleActive
                  ? '${run.puzzle.puzzle.title} · ${run.puzzle.completed}/${run.puzzle.puzzle.steps.length} ecos\n'
                        '${run.messageTime > 0
                            ? run.message
                            : run.puzzle.revealedHint != null
                            ? 'PISTA · ${run.puzzle.revealedHint!.hint} · siga o marcador dourado'
                            : 'Explore os selos A–D. Leia a Inscrição para restaurar a área.'}'
                  : run.passageOpen
                  ? run.finalArea
                        ? 'AURORA RESTAURADA · explore à vontade\n↑ Portal ao norte: concluir expedição'
                        : '↑ PASSAGEM ABERTA · siga a estrada até o arco\n'
                              'Ao atravessar: até +20 HP e +25 MP'
                  : run.nextEncounterIn > 0
                  ? 'ÁREA LIVRE · passagem abre em ${run.nextEncounterIn.ceil()}s\n${run.puzzle.puzzle.restoration}'
                  : run.message,
              textAlign: TextAlign.center,
              maxLines:
                  MediaQuery.orientationOf(context) == Orientation.landscape
                  ? 2
                  : 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFFFFE2A3), fontSize: 11),
            ),
          ),
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
                      '${run.region.title} · ${run.wave}/${BetaRegion.values.length}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                    BetaStatusReadout(run: run, critical: critical),
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
                        ? 'AURORA RESTAURADA'
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
                        ? 'Atravesse seis regiões e restaure seus ecos.\n'
                              'Vença os inimigos, decifre os altares e transforme o cenário.\n'
                              'Progresso temporário: sair encerra esta sessão.'
                        : paused
                        ? 'O tempo está parado. Seu progresso neste beta dura somente até sair.'
                        : '${run.phase == BetaPhase.won ? 'A estrada dos ecos foi recuperada.' : 'Você caiu em ${run.region.title}.'}\n'
                              '${run.kills} inimigos · ${run.xp} XP · nível ${run.level}\n'
                              '${run.restoredAreas}/${BetaRegion.values.length} áreas restauradas\n'
                              'Progresso desta sessão; seus outros modos não são alterados.',
                    style: const TextStyle(fontSize: 13),
                  ),
                  if (ready || paused) ...[
                    const SizedBox(height: 10),
                    _route(run),
                  ],
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
                  if (ready || paused)
                    TextButton.icon(
                      key: const ValueKey('beta-open-build'),
                      onPressed: _openBuild,
                      icon: const Icon(Icons.auto_stories, size: 18),
                      label: Text(
                        'Grimório e equipamento · ${run.skillPoints} PH',
                      ),
                    ),
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

  Widget _route(BetaSession run) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: const Color(0x18314C40),
      border: Border.all(color: const Color(0x66314C40)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final region in BetaRegion.values)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              '${region.index < run.region.index
                  ? '✓'
                  : region == run.region
                  ? '›'
                  : '·'} '
              '${region.index + 1}. ${region.title}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: region == run.region
                    ? FontWeight.bold
                    : FontWeight.normal,
                color: const Color(0xFF314C40),
              ),
            ),
          ),
        const SizedBox(height: 4),
        Text(run.region.story, style: const TextStyle(fontSize: 11)),
        Text(
          'Restauração: ${run.restoredAreas}/${BetaRegion.values.length} áreas · nesta expedição',
          style: const TextStyle(fontSize: 11),
        ),
      ],
    ),
  );

  Widget _combatGuide() => ExpansionTile(
    key: const PageStorageKey('beta-combat-guide'),
    iconColor: const Color(0xFF314C40),
    collapsedIconColor: const Color(0xFF314C40),
    tilePadding: EdgeInsets.zero,
    title: const Text('Guia de combate', style: TextStyle(fontSize: 13)),
    children: [
      const Text(
        'Alvo dourado: espada no alcance. Azul: aproxime-se ou use magia. '
        'Colunas bloqueiam golpes e disparos. Magia simples custa 25 MP; '
        'mana retorna sozinha. Em Mistura, toque no segundo elemento e conjure '
        '(35–45 MP). Acerte para descobrir; os três primeiros combos são equipados.',
        style: TextStyle(fontSize: 12),
      ),
      const SizedBox(height: 8),
      const Text(
        'Após vencer, leia a Inscrição e sintonize os selos A–D com os elementos '
        'indicados. Os enigmas avançam de elementos simples para misturas e ordens '
        'invertidas. Pistas são gratuitas; erros não removem progresso. '
        'Restaurada a área, siga até o arco ao norte e fique no selo para '
        'viajar. A passagem recupera até 20 HP e 25 MP; nível e elemento continuam. '
        'A água rasa do aqueduto pode ser atravessada. Na última área, você pode '
        'explorar o cenário restaurado antes de concluir a expedição pelo portal.',
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
        'Goblin: desvie de lado. Ogro: contorne a clava. '
        'Elfo Sombrio: recue do corte duplo; puna a recuperação. '
        'Guardião: saia do círculo. Ataque quando aparecer “Recuperando”.\n\n'
        'Rolar usa a direção do joystick. Sem Passo de Pedra, a proteção termina '
        'antes de levantar; '
        'saia da área do golpe, não apenas role parado contra a parede.\n\n'
        'Equipe até 3 combos e aprenda habilidades no grimório, antes da expedição '
        'ou após limpar a área. PH, descobertas e build duram só esta sessão.\n\n'
        'Teclado: WASD/setas · J espada · K magia · Espaço rolar · '
        '1–4 elemento · Shift + 1–4 mistura.',
        style: TextStyle(fontSize: 12),
      ),
      const SizedBox(height: 8),
    ],
  );
}
