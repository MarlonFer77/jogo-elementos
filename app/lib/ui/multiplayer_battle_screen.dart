import 'dart:async';

import 'package:flutter/material.dart';

import '../game_domain/attack_event.dart';
import '../game_domain/action_preview.dart';
import '../game_domain/battle_scene_view.dart';
import '../game_domain/combination_catalog.dart';
import '../game_domain/detect_opponent_attack.dart';
import '../game_domain/element_catalog.dart';
import '../game_domain/multiplayer_exception.dart';
import '../game_domain/multiplayer_match.dart';
import '../game_presentation/battle_scene_widget.dart';
import '../game_presentation/pixel_arena_background.dart';
import '../game_presentation/pixel_content_panel.dart';
import '../game_presentation/pixel_element_chip.dart';
import '../game_presentation/pixel_menu_button.dart';
import '../game_presentation/pixel_outlined_text.dart';
import '../game_presentation/pixel_page_route.dart';
import '../game_presentation/pixel_sheet_panel.dart';
import '../game_presentation/sfx_player.dart';
import 'skill_tree_screen.dart';

/// The multiplayer battle itself — reachable only after
/// [MultiplayerLobbyScreen] created or joined a match. Polls the backend on
/// a timer to pick up the opponent's moves (no realtime push — ver
/// DECISION-016) and stops once the match is finished. The "Habilidades"
/// button on the AppBar (only shown while in progress) opens the same
/// kind of modal `TrainingScreen` has, but every unlock is a real request
/// to `POST /matches/:id/skills/unlock` — the backend is the authority on
/// what's unlockable and what it grants (ver DECISION-025).
class MultiplayerBattleScreen extends StatefulWidget {
  const MultiplayerBattleScreen({
    super.key,
    required this.match,
    Duration pollInterval = const Duration(seconds: 2),
  }) : _pollInterval = pollInterval;

  final MultiplayerMatch match;
  final Duration _pollInterval;

  @override
  State<MultiplayerBattleScreen> createState() =>
      _MultiplayerBattleScreenState();
}

class _MultiplayerBattleScreenState extends State<MultiplayerBattleScreen> {
  final Set<String> _selectedIds = {};
  Timer? _pollTimer;
  String? _error;
  bool _startingRematch = false;
  AttackEvent? _pendingAttack;
  int _attackSequenceCounter = 0;
  Set<String> _previousFieldEffectIds = {};
  bool _playedGameOverSound = false;
  bool _submitting = false;
  bool _defending = false;
  bool _previewLoading = false;
  ActionPreview? _preview;
  String? _previewError;
  int _previewRequest = 0;

  String get _previewStamp =>
      '${_match.isMyTurn}/${_match.myCurrentHp}/${_match.opponentCurrentHp}/'
      '${_match.myAp}/${_match.opponentAp}/${_match.unlockedNodeIdsForMe}/'
      '${_match.myActiveStatuses.map((s) => '${s.id}:${s.remainingTurns}').join(',')}/'
      '${_match.opponentActiveStatuses.map((s) => '${s.id}:${s.remainingTurns}').join(',')}';

  Future<void> _requestPreview() async {
    final request = ++_previewRequest;
    final stamp = _previewStamp;
    if (!mounted) return;
    setState(() {
      _preview = null;
      _previewError = null;
      _previewLoading = false;
    });
    if (!_match.isMyTurn ||
        (_selectedIds.isEmpty && !_defending) ||
        _submitting) {
      return;
    }
    setState(() => _previewLoading = true);
    try {
      final preview = await _match
          .previewAction(_selectedIds.toList(), defending: _defending)
          .timeout(const Duration(seconds: 15));
      if (mounted && request == _previewRequest && stamp == _previewStamp) {
        setState(() => _preview = preview);
      }
    } catch (e) {
      if (mounted && request == _previewRequest) {
        setState(
          () => _previewError =
              e is MultiplayerException && e.message.contains('not enough AP')
              ? 'AP insuficiente para essa combinação.'
              : 'Prévia indisponível. A ação será validada pelo servidor.',
        );
      }
    } finally {
      if (mounted && request == _previewRequest) {
        setState(() => _previewLoading = false);
      }
    }
  }

  MultiplayerMatch get _match => widget.match;

  @override
  void initState() {
    super.initState();
    _previousFieldEffectIds = _match.activeFieldEffectIds.toSet();
    _pollTimer = Timer.periodic(widget._pollInterval, (_) => _poll());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    if (_submitting) return;
    final stamp = _previewStamp;
    if (_match.isFinished) {
      _pollTimer?.cancel();
      return;
    }
    final myHpBefore = _match.myCurrentHp;
    final previousFieldEffectIds = _previousFieldEffectIds;
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
      if (stamp != _previewStamp) unawaited(_requestPreview());
    }
  }

  void _maybePlayGameOverSound() {
    if (_match.isFinished && !_playedGameOverSound) {
      _playedGameOverSound = true;
      sfxPlayer.play(_match.amIWinner ? SfxId.victory : SfxId.defeat);
    }
  }

  Future<void> _playTurn() async {
    if (_submitting || !_match.isMyTurn || _match.isFinished) return;
    final defending = _defending;
    _previewRequest++;
    setState(() {
      _error = null;
      _submitting = true;
      _preview = null;
      _previewLoading = false;
    });
    final playedElementIds = _selectedIds.toList();
    final opponentHpBefore = _match.opponentCurrentHp;
    try {
      await _match.playElementIds(playedElementIds, defending: defending);
      if (!mounted) return;
      setState(() {
        _selectedIds.clear();
        _defending = false;
        final triggeredId = _match.lastTriggeredCombinationId;
        if (opponentHpBefore != null) {
          _attackSequenceCounter++;
          final damage =
              opponentHpBefore - (_match.opponentCurrentHp ?? opponentHpBefore);
          final combo = triggeredId == null
              ? null
              : const CombinationCatalog().byId(triggeredId);
          _pendingAttack = AttackEvent(
            sequenceId: _attackSequenceCounter,
            attackerIsLeft: true,
            elementIds: playedElementIds,
            comboName: combo?.name,
            damage: damage,
            appliedStatusNames: const [],
            isDefend: defending,
          );
        }
        _previousFieldEffectIds = _match.activeFieldEffectIds.toSet();
      });
      _maybePlayGameOverSound();
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = _match.lastError ?? 'Jogada inválida.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _startRematch() async {
    setState(() {
      _startingRematch = true;
      _error = null;
    });
    try {
      final rematch = await _match.startRematch();
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        pixelSlideRoute((_) => MultiplayerBattleScreen(match: rematch)),
      );
    } on MultiplayerException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _startingRematch = false);
    }
  }

  Future<void> _openSkillTree() async {
    await Navigator.of(context).push(
      pixelSlideRoute(
        (_) => SkillTreeScreen(
          title: 'Habilidades',
          unlockedNodeIds: _match.unlockedNodeIdsForMe,
          canUnlockNow: _match.isInProgress && _match.isMyTurn,
          onUnlock: (nodeId) async {
            try {
              await _match.unlockSkill(nodeId);
              return null;
            } on MultiplayerException catch (e) {
              return e.message;
            }
          },
        ),
      ),
    );
    setState(() {});
  }

  void _toggleElement(String id) {
    setState(() {
      _defending = false;
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else if (_selectedIds.length < 3) {
        _selectedIds.add(id);
      }
    });
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
            title: PixelOutlinedText(
              'Partida ${_match.matchId ?? ""}',
              fontSize: 20,
            ),
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

  List<Widget> _buildWaiting(BuildContext context) {
    return [
      Text(
        'Aguardando oponente...',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      Text('Compartilhe o código: ${_match.matchId}'),
    ];
  }

  List<Widget> _buildGameOver(BuildContext context) {
    return [
      Text(
        _match.amIWinner ? 'Você venceu!' : 'Você perdeu.',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 16),
      PixelMenuButton(
        label: 'Revanche',
        onPressed: _startingRematch ? null : _startRematch,
      ),
      const SizedBox(height: 8),
      const Text(
        'Cria uma partida nova — compartilhe o código com seu oponente de novo.',
      ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(_error!, style: const TextStyle(color: Colors.red)),
        ),
    ];
  }

  List<Widget> _buildBattle(BuildContext context) {
    final elements = const ElementCatalog().all();

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
          leftStatuses: _match.myActiveStatuses,
          rightStatuses: _match.opponentActiveStatuses,
          fieldEffects: _match.activeFieldEffectBadges,
          leftAp: _match.myAp,
          leftApMax: _match.myApMax,
          rightAp: _match.opponentAp,
          rightApMax: _match.opponentApMax,
        ),
      ),
      const SizedBox(height: 16),
      Text(
        _match.isMyTurn ? 'Sua vez' : 'Vez do oponente',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const Divider(height: 32),
      Text(_selectedElementsSummary(elements)),
      const SizedBox(height: 8),
      PixelMenuButton(
        label: 'Escolher elementos',
        onPressed: _match.isMyTurn && !_submitting
            ? () => _openElementPicker(elements)
            : null,
      ),
      const SizedBox(height: 16),
      PixelMenuButton(
        label: _defending ? 'Confirmar defesa' : 'Jogar',
        onPressed:
            (!_submitting &&
                _match.isMyTurn &&
                (_selectedIds.isNotEmpty || _defending))
            ? _playTurn
            : null,
      ),
      TextButton.icon(
        icon: const Icon(Icons.shield_outlined),
        label: const Text('Defender'),
        onPressed: !_submitting && _match.isMyTurn
            ? () {
                setState(() {
                  _defending = true;
                  _selectedIds.clear();
                });
                unawaited(_requestPreview());
              }
            : null,
      ),
      if (_previewLoading) const Text('Calculando prévia…'),
      if (_preview != null)
        Text(_preview!.summary, style: const TextStyle(fontSize: 12)),
      if (_previewError != null)
        Text(_previewError!, style: const TextStyle(fontSize: 12)),
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
    ).then((_) {
      if (mounted) unawaited(_requestPreview());
    });
  }
}
