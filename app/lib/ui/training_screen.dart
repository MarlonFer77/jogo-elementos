import 'dart:async';
import 'conjuration_seal_dialog.dart';
import 'discovery_book_screen.dart';
import 'dungeon_blessing_screen.dart';
import '../game_domain/discovery_catalog.dart';

import 'package:flutter/material.dart';
import 'audio_settings.dart';

import '../game_domain/attack_catalog.dart';
import '../game_domain/attack_event.dart';
import '../game_domain/battle_scene_view.dart';
import '../game_domain/element_catalog.dart';
import '../game_domain/training_match.dart';
import '../game_domain/training_progress_store.dart';
import '../game_domain/dungeon_campaign.dart';
import '../game_domain/combatant_appearance.dart';
import '../game_domain/combination_catalog.dart';
import '../game_presentation/battle_scene_widget.dart';
import '../game_presentation/dungeon_intent_banner.dart';
import '../game_presentation/battle_result_panel.dart';
import '../game_presentation/battle_command_panel.dart';
import '../game_presentation/pixel_element_chip.dart';
import '../game_presentation/pixel_menu_button.dart';
import '../game_presentation/pixel_outlined_text.dart';
import '../game_presentation/pixel_page_route.dart';
import '../game_presentation/pixel_sheet_panel.dart';
import '../game_presentation/sfx_player.dart';
import 'attacks_screen.dart';
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
  const TrainingScreen({
    super.key,
    TrainingMatch? initialMatch,
    this.dungeon,
    this.encounter,
  }) : assert((dungeon == null) == (encounter == null)),
       _initialMatch = initialMatch;

  final TrainingMatch? _initialMatch;
  final DungeonCampaign? dungeon;
  final DungeonEncounter? encounter;

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  final TrainingProgressStore _progressStore = TrainingProgressStore();
  late TrainingMatch _match;
  bool _loading = true;
  String? _loadError;
  String? _pendingOnboardingSlot;
  List<String> _unlockedA = [];
  List<String> _unlockedB = [];
  List<String> _discovered = [];
  int _turnsPlayedA = 0;
  int _turnsPlayedB = 0;
  List<String> _unlockedAttacksA = [];
  List<String> _equippedAttacksA = [];
  List<String> _unlockedAttacksB = [];
  List<String> _equippedAttacksB = [];
  final Set<String> _selectedIds = {};
  String? _error;
  String? _lastUnlockedAttackText;
  AttackEvent? _pendingAttack;
  String? _selectedAttackId;
  bool _executing = false;
  bool _showAbilities = false;
  bool _defending = false;
  List<String>? _equippedElementsA;
  List<String>? _equippedElementsB;
  bool? _pendingEquipChoicePlayerA;
  String? _actionText;
  bool _aiThinking = false, _savingReward = false;
  String? _dungeonReward, _rewardError;
  bool get _enemyTurn =>
      widget.dungeon != null && !_match.isPlayerATurn && !_match.isOver;
  bool get _controlsLocked => _executing || _enemyTurn;

  @override
  void initState() {
    super.initState();
    final initial = widget.encounter?.match ?? widget._initialMatch;
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
    try {
      await _readPersistedMatch();
      if (mounted && _progressStore.recovered) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Progresso recuperado da cópia local anterior.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError =
              'Não foi possível recuperar o progresso. Seus dados foram preservados.';
        });
      }
    }
  }

  void _persist(Future<void> save) {
    unawaited(
      save.catchError((Object _) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Esta ação não foi salva. Verifique o armazenamento antes de sair.',
              ),
            ),
          );
        }
      }),
    );
  }

  Future<void> _readPersistedMatch() async {
    _unlockedA = await _progressStore.loadUnlockedNodeIds('a');
    _unlockedB = await _progressStore.loadUnlockedNodeIds('b');
    _discovered = await _progressStore.loadDiscoveredCombinationIds();
    _turnsPlayedA = await _progressStore.loadTurnsPlayed('a');
    _turnsPlayedB = await _progressStore.loadTurnsPlayed('b');
    _unlockedAttacksA = await _progressStore.loadUnlockedAttackIds('a');
    _equippedAttacksA = await _progressStore.loadEquippedAttackIds('a');
    _unlockedAttacksB = await _progressStore.loadUnlockedAttackIds('b');
    _equippedAttacksB = await _progressStore.loadEquippedAttackIds('b');
    _equippedElementsA = await _progressStore.loadEquippedElementIds('a');
    _equippedElementsB = await _progressStore.loadEquippedElementIds('b');
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
        unlockedAttackIdsA: _unlockedAttacksA,
        equippedAttackIdsA: _equippedAttacksA,
        unlockedAttackIdsB: _unlockedAttacksB,
        equippedAttackIdsB: _equippedAttacksB,
        equippedElementIdsA: _equippedElementsA,
        equippedElementIdsB: _equippedElementsB,
      );
      _pendingOnboardingSlot = null;
      _loading = false;
    });
  }

  Future<void> _confirmStartingElements(List<String> elementIds) async {
    final slot = _pendingOnboardingSlot!;
    final nodeIds = elementIds.map((id) => 'unlock_$id').toList();
    if (slot == 'a') {
      final next = {..._unlockedA, ...nodeIds}.toList();
      await _progressStore.saveUnlockedNodeIds('a', next);
      _unlockedA = next;
      if (!mounted) return;
      if (!_hasChosenStartingElements(_unlockedB)) {
        setState(() => _pendingOnboardingSlot = 'b');
        return;
      }
    } else {
      final next = {..._unlockedB, ...nodeIds}.toList();
      await _progressStore.saveUnlockedNodeIds('b', next);
      _unlockedB = next;
      if (!mounted) return;
    }
    _buildMatchFromLoadedProgress();
  }

  bool? _channelingLeft;

  Future<void> _playTurn({bool automated = false}) async {
    if (_executing || _match.isOver || (_enemyTurn && !automated)) return;
    final wasPlayerATurn = _match.isPlayerATurn;
    final actorName = widget.dungeon == null
        ? _match.currentTurnName
        : wasPlayerATurn
        ? 'Você'
        : widget.encounter!.room.name;
    final defending = _defending;
    final thawing = _match.currentPlayerIsFrozen;
    List<Map<String, num>>? sealTrace;
    final sealIds = _selectedAttackId == null
        ? _selectedIds.toList()
        : _match.equippedAttacksForCurrentPlayer
              .firstWhere((a) => a.id == _selectedAttackId)
              .elementIds;
    if (!automated && !defending && !thawing && sealIds.length > 1) {
      try {
        _match.previewAction(sealIds, attackId: _selectedAttackId);
        setState(() => _executing = true);
        sealTrace = await showConjurationSeal(
          context,
          elements: sealIds,
          onStart: () async {
            final duration = _match.beginSeal(
              sealIds,
              attackId: _selectedAttackId,
            );
            setState(() => _channelingLeft = wasPlayerATurn);
            return duration;
          },
        );
      } catch (e) {
        if (mounted) setState(() => _error = e.toString());
        return;
      } finally {
        if (mounted) {
          setState(() {
            _executing = false;
            _channelingLeft = null;
          });
        }
      }
      if (!mounted || sealTrace == null) return;
    }
    var fizzled = false;
    setState(() {
      _error = null;
      _lastUnlockedAttackText = null;
      final attackId = _selectedAttackId;
      var playedElementIds = _selectedIds.toList();
      final hpABefore = _match.playerACurrentHp;
      final hpBBefore = _match.playerBCurrentHp;
      final targetApBefore = wasPlayerATurn
          ? _match.playerBAp
          : _match.playerAAp;
      final discoveredCountBefore = _match.discoveredCombinationIds.length;
      try {
        if (!thawing && attackId != null) {
          final reason = _match.attackUnavailableReason(attackId);
          if (reason != null) throw StateError(reason);
          playedElementIds = _match.equippedAttacksForCurrentPlayer
              .firstWhere((a) => a.id == attackId)
              .elementIds;
        }
        if (sealTrace != null) {
          fizzled = !_match.resolveSeal(sealTrace);
          if (fizzled) playedElementIds = [];
        } else if (thawing) {
          playedElementIds = [];
          _match.thaw();
        } else if (defending) {
          playedElementIds = [];
          _match.defend();
        } else if (attackId == null) {
          _match.playElementIds(playedElementIds);
        } else {
          _match.playEquippedAttack(attackId);
        }
        _executing = true;
        final actionName = fizzled
            ? 'Selo interrompido · −1 AP'
            : thawing
            ? 'Quebrar o gelo'
            : (defending ? 'Defender' : _match.lastTriggeredCombinationName) ??
                  const ElementCatalog()
                      .all()
                      .where((e) => playedElementIds.contains(e.id))
                      .map((e) => e.name)
                      .join(' + ');
        _actionText = '$actorName usou $actionName!';
        _selectedAttackId = null;
        _selectedIds.clear();
        _defending = false;

        final damage = wasPlayerATurn
            ? hpBBefore - _match.playerBCurrentHp
            : hpABefore - _match.playerACurrentHp;
        _pendingAttack = AttackEvent(
          sequenceId: _match.turnsPlayed,
          attackerIsLeft: wasPlayerATurn,
          elementIds: playedElementIds,
          comboName: _match.lastTriggeredCombinationName,
          damage: damage,
          healing:
              (wasPlayerATurn
                      ? _match.playerACurrentHp - hpABefore
                      : _match.playerBCurrentHp - hpBBefore)
                  .clamp(0, 9999),
          apDrained:
              (targetApBefore -
                      (wasPlayerATurn ? _match.playerBAp : _match.playerAAp))
                  .clamp(0, 9999),
          purified:
              const CombinationCatalog()
                  .byElements(playedElementIds)
                  ?.cleanses ??
              false,
          appliedStatusNames: _match.lastAppliedStatusNames,
          isDefend: defending,
          isFrozenRecovery: thawing,
          isFizzle: fizzled,
        );
        if (widget.dungeon != null &&
            wasPlayerATurn &&
            _match.lastUnlockedAttackName != null) {
          _actionText =
              '$_actionText\nNova habilidade: ${_match.lastUnlockedAttackName}!';
        }
        if (widget.dungeon == null) {
          if (_match.discoveredCombinationIds.length != discoveredCountBefore) {
            _persist(
              _progressStore.saveDiscoveredCombinationIds(
                _match.discoveredCombinationIds,
              ),
            );
          }
          if (wasPlayerATurn) {
            _persist(
              _progressStore.saveTurnsPlayed(
                'a',
                _match.cumulativeTurnsPlayedA,
              ),
            );
          } else {
            _persist(
              _progressStore.saveTurnsPlayed(
                'b',
                _match.cumulativeTurnsPlayedB,
              ),
            );
          }
          if (_match.lastUnlockedAttackName != null) {
            final slot = wasPlayerATurn ? 'a' : 'b';
            final unlockedIds = wasPlayerATurn
                ? _match.unlockedAttackIdsForPlayerA
                : _match.unlockedAttackIdsForPlayerB;
            final equippedIds = wasPlayerATurn
                ? _match.equippedAttackIdsForPlayerA
                : _match.equippedAttackIdsForPlayerB;
            _persist(_progressStore.saveUnlockedAttackIds(slot, unlockedIds));
            _persist(_progressStore.saveEquippedAttackIds(slot, equippedIds));
            if (!_match.lastUnlockedAttackNeededEquipChoice) {
              _lastUnlockedAttackText =
                  'Novo ataque desbloqueado: ${_match.lastUnlockedAttackName}! '
                  '(equipado automaticamente)';
            }
          }
        }
        if (_match.lastUnlockedAttackNeededEquipChoice &&
            (widget.dungeon == null || wasPlayerATurn)) {
          _pendingEquipChoicePlayerA = wasPlayerATurn;
        }
      } on ArgumentError {
        _error = 'Jogada inválida.';
      } on StateError catch (e) {
        _error = e.message.contains('Not enough AP')
            ? 'AP insuficiente para essa combinação.'
            : e.message;
      }
    });
  }

  Future<void> _finishAttack() async {
    if (!mounted || !_executing) return;
    final equipPlayerA = _pendingEquipChoicePlayerA;
    setState(() {
      _executing = false;
      _showAbilities = false;
      _actionText = null;
      _pendingEquipChoicePlayerA = null;
    });
    if (_match.isOver) {
      sfxPlayer.play(
        widget.dungeon != null && !_match.playerAWon
            ? SfxId.defeat
            : SfxId.victory,
      );
      if (widget.dungeon != null) {
        await _saveDungeonResult();
        return;
      }
    }
    if (equipPlayerA != null) {
      await _openAttacksScreen(
        forPlayerA: equipPlayerA,
        highlightComboId: _match.lastUnlockedAttackId,
      );
    }
    if (mounted && _enemyTurn) unawaited(_runEnemy());
  }

  Future<void> _runEnemy() async {
    if (!_enemyTurn || _aiThinking || _executing) return;
    final choice = widget.encounter!.chooseAction();
    setState(() {
      _aiThinking = true;
      _channelingLeft = choice.elements.length > 1 ? false : null;
      _actionText =
          '${choice.interruption == null ? '' : '${choice.interruption}\n'}'
          '${widget.encounter!.room.name}: ${choice.name}…';
    });
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    setState(() {
      _aiThinking = false;
      _channelingLeft = null;
      _selectedIds
        ..clear()
        ..addAll(choice.elements);
      _selectedAttackId = choice.attackId;
      _defending = choice.defending;
    });
    await _playTurn(automated: true);
  }

  Future<void> _saveDungeonResult() async {
    if (_savingReward || _dungeonReward != null) return;
    setState(() {
      _savingReward = true;
      _rewardError = null;
    });
    try {
      final reward = await widget.dungeon!.complete(widget.encounter!);
      if (mounted) setState(() => _dungeonReward = reward);
    } catch (_) {
      if (mounted) {
        setState(
          () => _rewardError =
              'Não foi possível salvar a recompensa. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _savingReward = false);
    }
  }

  @override
  void dispose() {
    if (widget.encounter != null) widget.dungeon!.leave(widget.encounter!);
    super.dispose();
  }

  void _startNewMatch() {
    if (_executing || !_match.isOver) return;
    setState(() {
      _match = _match.startNewBattleKeepingProgress();
      _selectedIds.clear();
      _selectedAttackId = null;
      _pendingAttack = null;
      _lastUnlockedAttackText = null;
      _showAbilities = false;
      _error = null;
    });
  }

  Future<void> _openSkillTree() async {
    if (widget.dungeon != null) return;
    await Navigator.of(context).push(
      pixelSlideRoute(
        (_) => SkillTreeScreen(
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
              await _progressStore.saveUnlockedNodeIds(slot, unlockedNodeIds);
              await _progressStore.saveEquippedElementIds(
                slot,
                _match.equippedElementIdsForCurrentPlayer,
              );
              return null;
            } on StateError catch (e) {
              return e.message;
            }
          },
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openAttacksScreen({
    required bool forPlayerA,
    String? highlightComboId,
  }) async {
    setState(() => _selectedAttackId = null);
    final unlockedIds = forPlayerA
        ? _match.unlockedAttackIdsForPlayerA
        : _match.unlockedAttackIdsForPlayerB;
    final equippedIds = forPlayerA
        ? _match.equippedAttackIdsForPlayerA
        : _match.equippedAttackIdsForPlayerB;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .65,
        child: AttacksScreen(
          asSheet: true,
          attacks: allAttackOptions(
            unlockedIds: unlockedIds,
            equippedIds: equippedIds,
          ),
          highlightComboId: highlightComboId,
          onSetEquipped: (ids) async {
            try {
              _match.setEquippedAttacks(
                forPlayerA: forPlayerA,
                combinationIds: ids,
              );
              final slot = forPlayerA ? 'a' : 'b';
              if (widget.dungeon == null) {
                _persist(_progressStore.saveEquippedAttackIds(slot, ids));
              }
              return null;
            } on ArgumentError catch (e) {
              return e.message;
            }
          },
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openDiscoveryBook() async {
    final forPlayerA = _match.isPlayerATurn;
    await Navigator.of(context).push(
      pixelSlideRoute(
        (_) => DiscoveryBookScreen(
          playerLabel: widget.dungeon == null
              ? 'Treino · ${_match.currentTurnName} · registro compartilhado'
              : 'Dungeon · suas descobertas',
          entries: () => const DiscoveryCatalog().entries(
            discoveredIds: widget.dungeon == null
                ? _match.discoveredCombinationIds
                : _match.unlockedAttackIdsForPlayerA,
            learnedIds: forPlayerA
                ? _match.unlockedAttackIdsForPlayerA
                : _match.unlockedAttackIdsForPlayerB,
            equippedIds: forPlayerA
                ? _match.equippedAttackIdsForPlayerA
                : _match.equippedAttackIdsForPlayerB,
            unavailableReason: (id) => _match.isOver
                ? 'Partida encerrada'
                : _match.currentPlayerIsFrozen
                ? 'Congelado: quebre o gelo primeiro'
                : _match.attackUnavailableReason(id),
          ),
          onManage: () => _openAttacksScreen(forPlayerA: forPlayerA),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Progresso preservado')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_loadError!),
                const SizedBox(height: 16),
                PixelMenuButton(
                  label: 'Tentar novamente',
                  onPressed: () {
                    setState(() {
                      _loadError = null;
                      _loading = true;
                    });
                    unawaited(_loadPersistedMatch());
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_pendingOnboardingSlot != null) {
      return ElementStarterScreen(
        key: ValueKey(_pendingOnboardingSlot),
        playerLabel: _pendingOnboardingSlot == 'a' ? 'Jogador A' : 'Jogador B',
        step: _pendingOnboardingSlot == 'a' ? 1 : 2,
        confirmLabel:
            _pendingOnboardingSlot == 'a' &&
                !_hasChosenStartingElements(_unlockedB)
            ? 'Preparar Jogador B'
            : 'Entrar na batalha',
        onConfirm: (ids) => _persist(_confirmStartingElements(ids)),
      );
    }
    return PopScope(
      canPop:
          widget.dungeon == null ||
          (!_savingReward &&
              !_executing &&
              !_aiThinking &&
              (!_match.isOver || _dungeonReward != null)),
      child: Scaffold(
        backgroundColor: const Color(0xFF344C56),
        appBar: AppBar(
          backgroundColor: const Color(0xFF344C56),
          foregroundColor: const Color(0xFFF8F2DA),
          toolbarHeight: 44,
          title: Text(
            widget.encounter == null
                ? 'ELEMENTOS'
                : 'RUÍNA · SALA ${widget.encounter!.index + 1}/${DungeonRoom.all.length}',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 17,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          actions: [
            const MuteButton(),
            IconButton(
              icon: const Icon(Icons.menu_book),
              tooltip: 'Livro de Descobertas',
              onPressed:
                  _controlsLocked || (widget.dungeon != null && _match.isOver)
                  ? null
                  : _openDiscoveryBook,
            ),
            IconButton(
              icon: Icon(
                widget.dungeon == null
                    ? Icons.account_tree_outlined
                    : Icons.auto_awesome,
              ),
              tooltip: widget.dungeon == null
                  ? 'Árvore'
                  : 'Bênçãos da expedição',
              onPressed: _controlsLocked || _match.isOver
                  ? null
                  : widget.dungeon == null
                  ? _openSkillTree
                  : widget.dungeon!.progress.activeBlessings.isEmpty
                  ? null
                  : () => showDungeonBlessings(
                      context,
                      widget.dungeon!.progress.activeBlessings,
                    ),
            ),
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'Resumo da batalha',
              onPressed: _openBattleSummary,
            ),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontal =
                  constraints.maxWidth >= 480 &&
                  constraints.maxWidth > constraints.maxHeight;
              final arenaHeight =
                  (constraints.maxHeight -
                          330 *
                              MediaQuery.textScalerOf(
                                context,
                              ).scale(1).clamp(1.0, 1.4))
                      .clamp(
                        constraints.maxHeight * .25,
                        constraints.maxHeight * .48,
                      );
              // Keep the same widget tree when rotating so Flame and the
              // active animation are not disposed/replayed.
              return Flex(
                direction: horizontal ? Axis.horizontal : Axis.vertical,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: horizontal
                        ? constraints.maxWidth -
                              (constraints.maxWidth * .59).clamp(310.0, 600.0)
                        : null,
                    height: horizontal ? constraints.maxHeight : arenaHeight,
                    child: BattleSceneWidget(
                      channelingLeft: _channelingLeft,
                      height: horizontal ? constraints.maxHeight : arenaHeight,
                      onAttackComplete: _finishAttack,
                      view: BattleSceneView(
                        arena:
                            widget.encounter?.room.arena ?? ArenaTheme.training,
                        leftCurrentHp: _match.playerACurrentHp,
                        leftMaxHp: _match.playerAMaxHp,
                        rightCurrentHp: _match.playerBCurrentHp,
                        rightMaxHp: _match.playerBMaxHp,
                        isLeftTurn: _match.isPlayerATurn,
                        lastAttack: _pendingAttack,
                        leftLabel: widget.dungeon == null
                            ? 'Jogador A'
                            : 'Você',
                        rightLabel: widget.encounter?.room.name ?? 'Jogador B',
                        rightAppearance:
                            widget.encounter?.room.appearance ??
                            CombatantAppearance.adventurer,
                        leftStatuses: _match.playerAActiveStatuses,
                        rightStatuses: _match.playerBActiveStatuses,
                        fieldEffects: _match.activeFieldEffectBadges,
                        leftAp: _match.playerAAp,
                        leftApMax: _match.playerAApMax,
                        rightAp: _match.playerBAp,
                        rightApMax: _match.playerBApMax,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      key: const ValueKey('battle-commands'),
                      margin: const EdgeInsets.fromLTRB(6, 0, 6, 6),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F2DA),
                        border: Border.all(
                          color: const Color(0xFFACB7A1),
                          width: 4,
                        ),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (widget.encounter != null &&
                              !_match.isOver &&
                              !_controlsLocked)
                            DungeonIntentBanner(
                              intent: widget.encounter!.intent,
                              tactic: widget.encounter!.room.tactic,
                            ),
                          Text(
                            _controlsLocked
                                ? 'Ataque em execução…'
                                : _match.isOver
                                ? 'Batalha encerrada'
                                : widget.dungeon == null
                                ? 'Vez de: ${_match.currentTurnName}'
                                : 'Sua vez',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          if (!_controlsLocked && !_match.isOver)
                            _commandTabs(),
                          Expanded(
                            child: SingleChildScrollView(
                              key: const ValueKey('command-scroll'),
                              child: AbsorbPointer(
                                absorbing: _controlsLocked,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: _controlsLocked
                                      ? [
                                          const SizedBox(height: 20),
                                          Text(
                                            _actionText ?? 'Resolvendo ataque…',
                                            style: const TextStyle(
                                              fontFamily: 'monospace',
                                              fontSize: 18,
                                            ),
                                          ),
                                        ]
                                      : _match.isOver
                                      ? _gameOverCommands()
                                      : _battleCommands(),
                                ),
                              ),
                            ),
                          ),
                          if (!_controlsLocked && !_match.isOver)
                            _actionCommand(),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _gameOverCommands() => widget.dungeon != null
      ? [
          PixelOutlinedText(
            _match.playerAWon ? 'VITÓRIA' : 'DERROTA',
            fontSize: 20,
          ),
          const SizedBox(height: 8),
          Text(_dungeonReward ?? _rewardError ?? 'Salvando progresso…'),
          const SizedBox(height: 8),
          if (_rewardError != null)
            PixelMenuButton(
              label: 'Tentar salvar novamente',
              onPressed: _savingReward ? null : _saveDungeonResult,
            ),
          PixelMenuButton(
            label: 'Voltar ao acampamento',
            primary: true,
            onPressed: _dungeonReward == null
                ? null
                : () => Navigator.pop(context),
          ),
        ]
      : [
          BattleResultPanel(
            title: 'VITÓRIA',
            subtitle: '${_match.winnerName} venceu o duelo!',
            sharedDiscoveries: _match.gainsForPlayer(true).discoveries,
            players: [
              for (final isA in [true, false])
                BattleResultPlayer(
                  label: isA ? 'Jogador A' : 'Jogador B',
                  gains: _match.gainsForPlayer(isA),
                  onReview: () => _openAttacksScreen(forPlayerA: isA),
                ),
            ],
            onRematch: _startNewMatch,
            onMenu: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ];

  List<Widget> _battleCommands() {
    if (_match.currentPlayerIsFrozen) {
      return const [
        PixelOutlinedText('CONGELADO', fontSize: 18),
        SizedBox(height: 6),
        Text(
          'Este jogador perde a ação para quebrar o gelo. AP não regenera.',
          style: TextStyle(fontSize: 12),
        ),
      ];
    }
    final elements = const ElementCatalog().all();
    final equipped = _match.equippedElementIdsForCurrentPlayer;
    final attacks = _match.equippedAttacksForCurrentPlayer;
    final selectedAttack = attacks
        .where((a) => a.id == _selectedAttackId)
        .firstOrNull;
    return [
      if (_match.currentActionWarning != null)
        Text(
          _match.currentActionWarning!,
          style: const TextStyle(fontSize: 12),
        ),
      BattleCommandGrid(
        children: _showAbilities
            ? [
                for (var i = 0; i < 3; i++)
                  if (i < attacks.length)
                    BattleCommandButton(
                      key: ValueKey('attack-${attacks[i].id}'),
                      title: attacks[i].name,
                      detail:
                          _match.attackUnavailableReason(attacks[i].id) ??
                          '${_match.attackApCost(attacks[i].elementIds.length)} AP',
                      unavailable:
                          _match.attackUnavailableReason(attacks[i].id) != null,
                      selected: selectedAttack?.id == attacks[i].id,
                      onPressed: _executing
                          ? null
                          : () => setState(() {
                              _selectedAttackId = attacks[i].id;
                              _defending = false;
                              _selectedIds.clear();
                              _error = null;
                            }),
                    )
                  else
                    const BattleCommandButton(
                      title: 'Não aprendido',
                      detail: 'Descubra um combo',
                      unavailable: true,
                    ),
                BattleCommandButton(
                  title: 'Trocar',
                  detail: 'Até 3 habilidades',
                  onPressed: _executing
                      ? null
                      : () => _openAttacksScreen(
                          forPlayerA: _match.isPlayerATurn,
                        ),
                ),
              ]
            : [
                for (var i = 0; i < 4; i++)
                  if (i < equipped.length)
                    BattleCommandButton(
                      key: ValueKey('element-slot-$i'),
                      title: elements
                          .firstWhere((e) => e.id == equipped[i])
                          .name,
                      detail: basicActionDetail(
                        equipped[i],
                        (_match.isPlayerATurn
                                ? _match.playerAActiveStatuses
                                : _match.playerBActiveStatuses)
                            .map((s) => s.id),
                      ),
                      selected:
                          _selectedIds.length == 1 &&
                          _selectedIds.contains(equipped[i]),
                      onPressed: _executing
                          ? null
                          : () => setState(() {
                              _selectedAttackId = null;
                              _defending = false;
                              _selectedIds
                                ..clear()
                                ..add(equipped[i]);
                              _error = null;
                            }),
                    )
                  else
                    BattleCommandButton(
                      key: ValueKey('element-slot-$i'),
                      title: 'Espaço livre',
                      detail: 'Equipar elemento',
                      onPressed: _executing ? null : _openElementLoadout,
                    ),
              ],
      ),
      Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: _executing ? null : () => _openElementPicker(elements),
              child: const Text(
                'Combinar',
                semanticsLabel: 'Combinar elementos',
              ),
            ),
          ),
          Expanded(
            child: TextButton(
              onPressed: _executing
                  ? null
                  : _showAbilities
                  ? () => _openAttacksScreen(forPlayerA: _match.isPlayerATurn)
                  : _openElementLoadout,
              child: const Text('Equipar'),
            ),
          ),
          Expanded(
            child: TextButton(
              onPressed: _executing
                  ? null
                  : () => setState(() {
                      _defending = true;
                      _selectedIds.clear();
                      _selectedAttackId = null;
                      _error = null;
                    }),
              child: Text(_defending ? 'Defesa ✓' : 'Defender'),
            ),
          ),
        ],
      ),
      if (_error != null)
        Text(_error!, style: const TextStyle(color: Color(0xFF9D322E))),
    ];
  }

  Widget _commandTabs() => Row(
    children: [
      _tab('Elementos', !_showAbilities, () => _setCommandTab(false)),
      _tab('Habilidades', _showAbilities, () => _setCommandTab(true)),
      Expanded(
        child: Text(
          '${_match.availableApForAction} AP',
          textAlign: TextAlign.right,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ],
  );

  Widget _actionCommand() {
    if (_match.currentPlayerIsFrozen) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _previewText().split('\n').take(2).join(' · '),
              key: const ValueKey('freeze-preview-compact'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
            PixelMenuButton(
              label: 'Quebrar gelo',
              primary: true,
              onPressed: _executing ? null : _playTurn,
            ),
          ],
        ),
      );
    }
    final attack = _match.equippedAttacksForCurrentPlayer
        .where((a) => a.id == _selectedAttackId)
        .firstOrNull;
    if (!_defending && _selectedIds.isEmpty && attack == null) {
      return Text(
        _match.currentActionWarning ?? 'Escolha uma ação. +1 AP ao agir.',
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: Color(0xFF646653),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error == null)
            Tooltip(
              message: _previewText(),
              child: Text(
                _previewText().split('\n').take(2).join(' · '),
                key: const ValueKey('action-preview-compact'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11),
              ),
            ),
          PixelMenuButton(
            label: _defending
                ? 'Confirmar defesa'
                : attack == null
                ? 'Jogar'
                : 'Usar habilidade · ${_match.attackApCost(attack.elementIds.length)} AP',
            primary: true,
            onPressed:
                _executing ||
                    (!_defending &&
                        _selectedIds.length > 1 &&
                        _match.currentPlayerIsSilenced) ||
                    (attack != null &&
                        _match.attackUnavailableReason(attack.id) != null)
                ? null
                : _playTurn,
          ),
        ],
      ),
    );
  }

  Widget _tab(String title, bool selected, VoidCallback onTap) => Expanded(
    flex: 3,
    child: TextButton(
      onPressed: _executing ? null : onTap,
      style: TextButton.styleFrom(
        backgroundColor: selected ? const Color(0xFFF2DB88) : null,
        foregroundColor: selected
            ? const Color(0xFF253843)
            : const Color(0xFF77766C),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        textStyle: TextStyle(
          fontFamily: 'monospace',
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      child: Text(title, textAlign: TextAlign.center),
    ),
  );

  void _setCommandTab(bool abilities) => setState(() {
    _defending = false;
    _showAbilities = abilities;
    _selectedAttackId = null;
    _selectedIds.clear();
    _error = null;
  });

  String _previewText() {
    try {
      return _match
          .previewAction(
            _selectedIds.toList(),
            defending: _defending,
            thawing: _match.currentPlayerIsFrozen,
            attackId: _selectedAttackId,
          )
          .summary;
    } on StateError catch (e) {
      return e.message.contains('Not enough AP')
          ? 'AP insuficiente para essa combinação.'
          : e.message;
    } on ArgumentError {
      return 'Jogada inválida.';
    }
  }

  Future<T?> _sheet<T>(Widget Function(BuildContext) builder) =>
      showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (context) => PixelSheetPanel(
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: builder(context),
            ),
          ),
        ),
      );

  void _openBattleSummary() {
    _sheet<void>(
      (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PixelOutlinedText('Batalha', fontSize: 18),
          if (_lastUnlockedAttackText != null) Text(_lastUnlockedAttackText!),
          Text(
            'Descobertas: ${widget.dungeon == null ? _match.discoveredCount : _match.unlockedAttackIdsForPlayerA.length}/${_match.totalCombinationsCount}',
          ),
          if (_match.lastTriggeredCombinationName != null)
            Text('Última combinação: ${_match.lastTriggeredCombinationName}'),
          if (_match.lastAppliedStatusNames.isNotEmpty)
            Text(
              'Efeitos aplicados: ${_match.lastAppliedStatusNames.join(", ")}',
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Future<void> _openElementLoadout() async {
    final selected = _match.equippedElementIdsForCurrentPlayer.toList();
    final elements = const ElementCatalog().all();
    final chosen = await _sheet<List<String>>(
      (context) => StatefulBuilder(
        builder: (context, updateSheet) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PixelOutlinedText('Quatro elementos', fontSize: 18),
            Text('${selected.length}/4 equipados. Retire um para trocar.'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final element in elements)
                  PixelElementChip(
                    label:
                        _match.availableElementIdsForCurrentPlayer.contains(
                          element.id,
                        )
                        ? '${element.symbol} ${element.name}'
                        : '🔒 ${element.name}',
                    selected: selected.contains(element.id),
                    onTap:
                        !_match.availableElementIdsForCurrentPlayer.contains(
                              element.id,
                            ) ||
                            (!selected.contains(element.id) &&
                                selected.length >= 4)
                        ? null
                        : () => updateSheet(() {
                            selected.contains(element.id)
                                ? selected.remove(element.id)
                                : selected.add(element.id);
                          }),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            PixelMenuButton(
              label: 'Salvar elementos',
              onPressed: selected.isEmpty
                  ? null
                  : () => Navigator.pop(context, selected),
            ),
          ],
        ),
      ),
    );
    if (chosen == null || !mounted) return;
    _match.setEquippedElements(chosen);
    setState(() {
      _selectedIds.clear();
      _selectedAttackId = null;
      _error = null;
    });
    if (widget.dungeon == null) {
      await _progressStore.saveEquippedElementIds(
        _match.isPlayerATurn ? 'a' : 'b',
        chosen,
      );
    }
  }

  Future<void> _openElementPicker(List<ElementOption> elements) async {
    final selected = _selectedIds.toSet();
    final chosen = await _sheet<List<String>>(
      (context) => StatefulBuilder(
        builder: (context, updateSheet) {
          final equipped = _match.equippedElementIdsForCurrentPlayer;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PixelOutlinedText('Experimente', fontSize: 18),
              const Text('Combine 2 ou 3 elementos equipados.'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final element in elements)
                    if (equipped.contains(element.id))
                      PixelElementChip(
                        label: '${element.symbol} ${element.name}',
                        selected: selected.contains(element.id),
                        onTap: () => updateSheet(() {
                          if (selected.contains(element.id)) {
                            selected.remove(element.id);
                          } else if (selected.length < 3) {
                            selected.add(element.id);
                          }
                        }),
                      ),
                ],
              ),
              const SizedBox(height: 12),
              PixelMenuButton(
                label: 'Confirmar',
                onPressed: selected.isEmpty
                    ? null
                    : () => Navigator.pop(context, selected.toList()),
              ),
            ],
          );
        },
      ),
    );
    if (chosen == null || !mounted) return;
    setState(() {
      _defending = false;
      _selectedAttackId = null;
      _selectedIds
        ..clear()
        ..addAll(chosen);
      _error = null;
    });
  }
}
