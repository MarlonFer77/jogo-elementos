import 'dart:async';

import 'package:flutter/material.dart';

import '../game_domain/attack_event.dart';
import '../game_domain/battle_scene_view.dart';
import '../game_domain/element_catalog.dart';
import '../game_domain/training_match.dart';
import '../game_domain/training_progress_store.dart';
import '../game_presentation/battle_scene_widget.dart';
import '../game_presentation/pixel_arena_background.dart';
import '../game_presentation/pixel_content_panel.dart';
import '../game_presentation/pixel_element_chip.dart';
import '../game_presentation/pixel_menu_button.dart';
import '../game_presentation/pixel_outlined_text.dart';
import '../game_presentation/pixel_page_route.dart';
import '../game_presentation/pixel_sheet_panel.dart';
import '../game_presentation/sfx_player.dart';
import 'element_starter_screen.dart';
import 'skill_tree_screen.dart';

/// Modo treino: batalha local, offline, hotseat — os dois lados jogados no
/// mesmo aparelho. Sem backend, sem multiplayer, sem IA. Cada jogador pode
/// desbloquear habilidades da Skill Tree na própria vez; o que já
/// desbloqueou se aplica automaticamente em toda ação que jogar depois (e,
/// no caso de bônus de HP, imediatamente). A partida termina quando o HP
/// de alguém chega a 0.
///
/// Bloco 2b: antes da primeira partida, cada jogador (Jogador A, depois
/// Jogador B) escolhe 2 elementos iniciais via [ElementStarterScreen] —
/// só acontece uma vez por slot, nunca de novo depois de salvo.
class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key, TrainingMatch? initialMatch})
      : _initialMatch = initialMatch;

  final TrainingMatch? _initialMatch;

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  final TrainingProgressStore _progressStore = TrainingProgressStore();
  late TrainingMatch _match;
  bool _loading = true;
  String? _pendingOnboardingSlot;
  List<String> _unlockedA = [];
  List<String> _unlockedB = [];
  List<String> _discovered = [];
  int _turnsPlayedA = 0;
  int _turnsPlayedB = 0;
  final Set<String> _selectedIds = {};
  String? _error;
  AttackEvent? _pendingAttack;

  @override
  void initState() {
    super.initState();
    final initial = widget._initialMatch;
    if (initial != null) {
      _match = initial;
      _loading = false;
    } else {
      unawaited(_loadPersistedMatch());
    }
  }

  /// Todo nó da branch "elementos" tem id `'unlock_<elementId>'` (ver
  /// `ElementUnlocks` em `battle_engine`) — checar o prefixo evita a UI
  /// precisar importar aquele tipo (DECISION-011/017).
  bool _hasChosenStartingElements(List<String> unlockedNodeIds) {
    return unlockedNodeIds.any((id) => id.startsWith('unlock_'));
  }

  Future<void> _loadPersistedMatch() async {
    _unlockedA = await _progressStore.loadUnlockedNodeIds('a');
    _unlockedB = await _progressStore.loadUnlockedNodeIds('b');
    _discovered = await _progressStore.loadDiscoveredCombinationIds();
    _turnsPlayedA = await _progressStore.loadTurnsPlayed('a');
    _turnsPlayedB = await _progressStore.loadTurnsPlayed('b');
    if (!mounted) return;
    if (!_hasChosenStartingElements(_unlockedA)) {
      setState(() {
        _pendingOnboardingSlot = 'a';
        _loading = false;
      });
      return;
    }
    if (!_hasChosenStartingElements(_unlockedB)) {
      setState(() {
        _pendingOnboardingSlot = 'b';
        _loading = false;
      });
      return;
    }
    _buildMatchFromLoadedProgress();
  }

  void _buildMatchFromLoadedProgress() {
    setState(() {
      _match = TrainingMatch.fromPersistedProgress(
        unlockedNodeIdsA: _unlockedA,
        unlockedNodeIdsB: _unlockedB,
        discoveredCombinationIds: _discovered,
        turnsPlayedA: _turnsPlayedA,
        turnsPlayedB: _turnsPlayedB,
      );
      _pendingOnboardingSlot = null;
      _loading = false;
    });
  }

  Future<void> _confirmStartingElements(List<String> elementIds) async {
    final slot = _pendingOnboardingSlot!;
    final nodeIds = elementIds.map((id) => 'unlock_$id').toList();
    if (slot == 'a') {
      _unlockedA = [..._unlockedA, ...nodeIds];
      await _progressStore.saveUnlockedNodeIds('a', _unlockedA);
      if (!mounted) return;
      if (!_hasChosenStartingElements(_unlockedB)) {
        setState(() => _pendingOnboardingSlot = 'b');
        return;
      }
    } else {
      _unlockedB = [..._unlockedB, ...nodeIds];
      await _progressStore.saveUnlockedNodeIds('b', _unlockedB);
      if (!mounted) return;
    }
    _buildMatchFromLoadedProgress();
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

  void _playTurn() {
    setState(() {
      _error = null;
      final playedElementIds = _selectedIds.toList();
      final wasPlayerATurn = _match.isPlayerATurn;
      final hpABefore = _match.playerACurrentHp;
      final hpBBefore = _match.playerBCurrentHp;
      final discoveredCountBefore = _match.discoveredCombinationIds.length;
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
        if (_match.discoveredCombinationIds.length != discoveredCountBefore) {
          unawaited(
            _progressStore.saveDiscoveredCombinationIds(_match.discoveredCombinationIds),
          );
        }
        if (wasPlayerATurn) {
          unawaited(_progressStore.saveTurnsPlayed('a', _match.cumulativeTurnsPlayedA));
        } else {
          unawaited(_progressStore.saveTurnsPlayed('b', _match.cumulativeTurnsPlayedB));
        }
        if (_match.isOver) {
          sfxPlayer.play(SfxId.victory);
        }
      } on ArgumentError {
        _error = 'Jogada inválida.';
      } on StateError {
        _error = 'AP insuficiente para essa combinação.';
      }
    });
  }

  void _startNewMatch() {
    setState(() {
      _match = _match.startNewBattleKeepingProgress();
      _selectedIds.clear();
      _error = null;
    });
  }

  Future<void> _openSkillTree() async {
    await Navigator.of(context).push(pixelSlideRoute((_) => SkillTreeScreen(
      title: 'Habilidades de ${_match.currentTurnName}',
      unlockedNodeIds: _match.unlockedNodeIdsForCurrentPlayer,
      canUnlockNow: true,
      extraLockedHint: (nodeId) {
        final remaining = _match.turnsRemainingToUnlock(nodeId);
        return remaining != null ? 'Faltam $remaining turnos.' : null;
      },
      onUnlock: (nodeId) async {
        try {
          _match.unlockSkillForCurrentPlayer(nodeId);
          final slot = _match.isPlayerATurn ? 'a' : 'b';
          final unlockedNodeIds = _match.isPlayerATurn
              ? _match.unlockedNodeIdsForPlayerA
              : _match.unlockedNodeIdsForPlayerB;
          unawaited(_progressStore.saveUnlockedNodeIds(slot, unlockedNodeIds));
          return null;
        } on StateError catch (e) {
          return e.message;
        }
      },
    )));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_pendingOnboardingSlot != null) {
      return ElementStarterScreen(
        key: ValueKey(_pendingOnboardingSlot),
        playerLabel: _pendingOnboardingSlot == 'a' ? 'Jogador A' : 'Jogador B',
        onConfirm: (ids) => unawaited(_confirmStartingElements(ids)),
      );
    }
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
                      leftStatuses: _match.playerAActiveStatuses,
                      rightStatuses: _match.playerBActiveStatuses,
                      fieldEffects: _match.activeFieldEffectBadges,
                      leftAp: _match.playerAAp,
                      leftApMax: _match.playerAApMax,
                      rightAp: _match.playerBAp,
                      rightApMax: _match.playerBApMax,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Vez de: ${_match.currentTurnName}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
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
      Text(_selectedElementsSummary(elements)),
      const SizedBox(height: 8),
      PixelMenuButton(
        label: 'Escolher elementos',
        onPressed: () => _openElementPicker(elements),
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
            final availableIds = _match.availableElementIdsForCurrentPlayer;
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
                          if (availableIds.contains(element.id))
                            PixelElementChip(
                              label: '${element.symbol} ${element.name}',
                              selected: _selectedIds.contains(element.id),
                              onTap: () {
                                _toggleElement(element.id);
                                setSheetState(() {});
                              },
                            )
                          else
                            PixelElementChip(
                              label: '🔒 ${element.name}',
                              selected: false,
                              onTap: null,
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
    );
  }
}
