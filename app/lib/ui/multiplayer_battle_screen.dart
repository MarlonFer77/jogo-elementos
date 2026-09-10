import 'dart:async';

import 'package:flutter/material.dart';

import '../game_domain/attack_event.dart';
import '../game_domain/battle_scene_view.dart';
import '../game_domain/combination_catalog.dart';
import '../game_domain/detect_opponent_attack.dart';
import '../game_domain/element_catalog.dart';
import '../game_domain/multiplayer_exception.dart';
import '../game_domain/multiplayer_match.dart';
import '../game_domain/skill_tree_catalog.dart';
import '../game_presentation/battle_scene_widget.dart';
import '../game_presentation/pixel_arena_background.dart';
import '../game_presentation/pixel_content_panel.dart';
import '../game_presentation/pixel_element_chip.dart';
import '../game_presentation/pixel_menu_button.dart';
import '../game_presentation/pixel_outlined_text.dart';
import '../game_presentation/pixel_page_route.dart';
import '../game_presentation/pixel_sheet_panel.dart';

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
  State<MultiplayerBattleScreen> createState() => _MultiplayerBattleScreenState();
}

class _MultiplayerBattleScreenState extends State<MultiplayerBattleScreen> {
  final Set<String> _selectedIds = {};
  Timer? _pollTimer;
  String? _error;
  bool _startingRematch = false;
  AttackEvent? _pendingAttack;
  int _attackSequenceCounter = 0;
  Set<String> _previousFieldEffectIds = {};

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
    }
  }

  Future<void> _playTurn() async {
    setState(() => _error = null);
    final playedElementIds = _selectedIds.toList();
    final opponentHpBefore = _match.opponentCurrentHp;
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
    } catch (_) {
      setState(() => _error = _match.lastError ?? 'Jogada inválida.');
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

  void _toggleElement(String id) {
    setState(() {
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
}
