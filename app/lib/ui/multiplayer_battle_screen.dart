import 'dart:async';
import 'conjuration_seal_dialog.dart';

import 'package:flutter/material.dart';

import '../game_domain/attack_event.dart';
import '../game_domain/action_preview.dart';
import '../game_domain/battle_scene_view.dart';
import '../game_domain/combination_catalog.dart';
import '../game_domain/detect_opponent_attack.dart';
import '../game_domain/element_catalog.dart';
import '../game_domain/status_catalog.dart';
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
import 'element_starter_screen.dart';
import 'attacks_screen.dart';
import '../game_domain/attack_catalog.dart';

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
  bool _showAbilities = false;
  bool _defending = false;
  bool _previewLoading = false;
  ActionPreview? _preview;
  String? _previewError;
  int _previewRequest = 0;

  String get _previewStamp =>
      '${_match.match?.revision}/${_match.isMyTurn}/${_match.myCurrentHp}/${_match.opponentCurrentHp}/'
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
        _match.match?.seal != null ||
        (_selectedIds.isEmpty && !_defending && !_match.amIFrozen) ||
        _submitting) {
      return;
    }
    setState(() => _previewLoading = true);
    try {
      final preview = await _match
          .previewAction(
            _selectedIds.toList(),
            defending: _defending,
            thawing: _match.amIFrozen,
          )
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
              : e is MultiplayerException && e.message.contains('Silêncio')
              ? e.message
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
    final myStatusesBefore = _match.myActiveStatuses.map((s) => s.id).toSet();
    final previousFieldEffectIds = _previousFieldEffectIds;
    final previousRevision = _match.match?.lastAction?['revision'];
    await _match.refresh();
    if (mounted) {
      setState(() {
        final newFieldEffectIds = _match.activeFieldEffectIds.toSet();
        _previousFieldEffectIds = newFieldEffectIds;

        if (myHpBefore != null) {
          _attackSequenceCounter++;
          final remoteAction = _match.match?.lastAction;
          final detected =
              remoteAction != null &&
                  previousRevision != remoteAction['revision'] &&
                  remoteAction['actorId'] != _match.localPlayerId
              ? AttackEvent(
                  sequenceId: _attackSequenceCounter,
                  attackerIsLeft: false,
                  elementIds: (remoteAction['elementIds'] as List)
                      .cast<String>(),
                  comboName: const CombinationCatalog()
                      .byId(remoteAction['comboId'] as String? ?? '')
                      ?.name,
                  damage: (myHpBefore - (_match.myCurrentHp ?? myHpBefore))
                      .clamp(0, 9999),
                  isDefend: remoteAction['kind'] == 'defend',
                  isFrozenRecovery: remoteAction['kind'] == 'thaw',
                  isFizzle: remoteAction['kind'] == 'fizzle',
                  appliedStatusNames: _match.myActiveStatuses
                      .where((s) => !myStatusesBefore.contains(s.id))
                      .map((s) => _statusName(s.id))
                      .toList(),
                )
              : remoteAction != null
              ? null
              : detectOpponentAttack(
                  previousFieldEffectIds: previousFieldEffectIds,
                  newFieldEffectIds: newFieldEffectIds,
                  myHpBefore: myHpBefore,
                  myHpAfter: _match.myCurrentHp ?? myHpBefore,
                  sequenceId: _attackSequenceCounter,
                  appliedStatusNames: _match.myActiveStatuses
                      .where((status) => !myStatusesBefore.contains(status.id))
                      .map((status) => _statusName(status.id))
                      .toList(),
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
    if (_match.match?.seal != null) {
      setState(() => _error = 'Selo em andamento. Aguarde a sincronização.');
      return;
    }
    final defending = _defending;
    final thawing = _match.amIFrozen;
    _previewRequest++;
    setState(() {
      _error = null;
      _submitting = true;
      _preview = null;
      _previewLoading = false;
    });
    final playedElementIds = _selectedIds.toList();
    final discoveriesBefore = _match.discoveries.toSet();
    final opponentHpBefore = _match.opponentCurrentHp;
    final opponentStatusesBefore = _match.opponentActiveStatuses
        .map((s) => s.id)
        .toSet();
    try {
      if (!defending && !thawing && playedElementIds.length > 1) {
        final trace = await showConjurationSeal(
          context,
          elements: playedElementIds,
          onStart: () async {
            final remaining = await _match.beginSeal(playedElementIds);
            if (mounted) setState(() {});
            return remaining;
          },
        );
        if (trace == null) return;
        await _match.resolveSeal(trace);
      } else {
        await _match.playElementIds(
          thawing ? const [] : playedElementIds,
          defending: defending && !thawing,
          thawing: thawing,
        );
      }
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
            elementIds: thawing || _match.match?.lastAction?['kind'] == 'fizzle'
                ? const []
                : playedElementIds,
            comboName: combo?.name,
            damage: damage,
            appliedStatusNames: _match.opponentActiveStatuses
                .where((status) => !opponentStatusesBefore.contains(status.id))
                .map((status) => _statusName(status.id))
                .toList(),
            isDefend: defending && !thawing,
            isFrozenRecovery: thawing,
            isFizzle: _match.match?.lastAction?['kind'] == 'fizzle',
          );
        }
        _previousFieldEffectIds = _match.activeFieldEffectIds.toSet();
      });
      _maybePlayGameOverSound();
      final newId = _match.lastTriggeredCombinationId;
      if (newId != null && !discoveriesBefore.contains(newId)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _match.equippedAttacks.contains(newId)
                  ? 'Nova habilidade descoberta e equipada!'
                  : 'Nova habilidade descoberta! Troque uma das 3 na sua próxima vez.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _error =
            _match.lastError ?? 'Conexão interrompida. Sincronizando a ação…',
      );
      await _match.refresh();
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
          extraLockedHint: _match.elementUnlockHint,
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
    if (_match.needsPreparation && _match.match != null) {
      return Stack(
        children: [
          AbsorbPointer(
            absorbing: _submitting,
            child: ElementStarterScreen(
              playerLabel: _match.localPlayerId,
              modeLabel: 'MULTIPLAYER',
              onConfirm: (ids) async {
                if (_submitting) return;
                setState(() => _submitting = true);
                try {
                  await _match.configure('prepare', ids);
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(error.toString())));
                  }
                  await _match.refresh();
                } finally {
                  if (mounted) setState(() => _submitting = false);
                }
              },
            ),
          ),
          if (_submitting) const Center(child: CircularProgressIndicator()),
        ],
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
          body: _match.isInProgress && _match.bothReady
              ? _battleLayout(context)
              : SingleChildScrollView(
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
                          const Text(
                            'Aguardando o oponente escolher os elementos…',
                          ),
                        if (_match.connectionError != null)
                          Text(_match.connectionError!),
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
    final elements = const ElementCatalog()
        .all()
        .where((e) => _match.equippedElements.contains(e.id))
        .toList();

    return [
      BattleSceneWidget(
        channelingLeft: _match.channelingLeft,
        height:
            MediaQuery.of(context).size.width >
                MediaQuery.of(context).size.height
            ? MediaQuery.of(context).size.height - 110
            : 260,
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
      if (_match.match?.seal != null)
        Text(
          'Conjuração em andamento · ${_match.match!.seal!['reservedAp']} AP reservados. Aguarde.',
        ),
      Text(
        _match.isMyTurn
            ? _match.amIFrozen
                  ? 'Sua vez · CONGELADO'
                  : 'Sua vez'
            : 'Vez do oponente',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      if (_match.isMyTurn && _match.amIFrozen)
        const Text(
          'Você perde esta ação para quebrar o gelo. AP não regenera.',
          style: TextStyle(fontSize: 12),
        ),
      const Divider(height: 12),
      if (_match.connectionError != null)
        Text(
          _match.connectionError!,
          style: const TextStyle(color: Colors.red),
        ),
      if (_match.isMyTurn)
        for (final status in _match.myActiveStatuses.where(
          (s) => const ['silence', 'slow', 'shock'].contains(s.id),
        ))
          Text(
            statusDescription(status.id),
            style: const TextStyle(fontSize: 12),
          ),
      Text(_selectedElementsSummary(elements)),
      Wrap(
        children: [
          TextButton(
            onPressed: () => setState(() => _showAbilities = false),
            child: const Text('Elementos'),
          ),
          TextButton(
            onPressed: () => setState(() => _showAbilities = true),
            child: const Text('Habilidades'),
          ),
        ],
      ),
      LayoutBuilder(
        builder: (context, constraints) => Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            if (!_showAbilities)
              for (var i = 0; i < 4; i++)
                SizedBox(
                  width: (constraints.maxWidth - 6) / 2,
                  child: PixelMenuButton(
                    label: i < elements.length
                        ? '${elements[i].symbol} ${elements[i].name}'
                        : 'Vazio',
                    onPressed:
                        i < elements.length &&
                            _match.isMyTurn &&
                            !_match.amIFrozen &&
                            !_submitting
                        ? () {
                            setState(() {
                              _defending = false;
                              _selectedIds
                                ..clear()
                                ..add(elements[i].id);
                            });
                            unawaited(_requestPreview());
                          }
                        : null,
                  ),
                ),
            if (_showAbilities)
              for (var i = 0; i < 3; i++)
                SizedBox(
                  width: constraints.maxWidth,
                  child: PixelMenuButton(
                    label: i < _match.equippedAttacks.length
                        ? _attackLabel(_match.equippedAttacks[i])
                        : 'Habilidade vazia',
                    onPressed:
                        i < _match.equippedAttacks.length &&
                            _match.isMyTurn &&
                            !_submitting &&
                            !_match.amIFrozen &&
                            _attackUnavailable(_match.equippedAttacks[i]) ==
                                null
                        ? () {
                            final attack = const CombinationCatalog().byId(
                              _match.equippedAttacks[i],
                            );
                            if (attack == null) return;
                            setState(() {
                              _defending = false;
                              _selectedIds
                                ..clear()
                                ..addAll(attack.elementIds);
                            });
                            unawaited(_requestPreview());
                          }
                        : null,
                  ),
                ),
          ],
        ),
      ),
      Wrap(
        children: [
          TextButton(
            onPressed: _match.isMyTurn && !_submitting ? _manageElements : null,
            child: const Text('Trocar elementos'),
          ),
          TextButton(
            onPressed: !_submitting ? _manageAttacks : null,
            child: Text('Descobertas ${_match.discoveries.length} · Equipar'),
          ),
        ],
      ),
      const SizedBox(height: 8),
      PixelMenuButton(
        label: 'Experimentar combo',
        onPressed: _match.isMyTurn && !_match.amIFrozen && !_submitting
            ? () => _openElementPicker(elements)
            : null,
      ),
      const SizedBox(height: 16),
      PixelMenuButton(
        label: _match.amIFrozen
            ? 'Quebrar gelo'
            : _defending
            ? 'Confirmar defesa'
            : 'Jogar',
        onPressed:
            (!_submitting &&
                _match.match?.seal == null &&
                !(_selectedIds.length > 1 &&
                    !_defending &&
                    !_match.amIFrozen &&
                    _match.myActiveStatuses.any((s) => s.id == 'silence')) &&
                _match.isMyTurn &&
                (_match.amIFrozen || _selectedIds.isNotEmpty || _defending))
            ? _playTurn
            : null,
      ),
      TextButton.icon(
        icon: const Icon(Icons.shield_outlined),
        label: const Text('Defender'),
        onPressed: !_submitting && _match.isMyTurn && !_match.amIFrozen
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

  String _statusName(String id) => statusName(id);

  String _attackLabel(String id) {
    final combo = const CombinationCatalog().byId(id);
    final cost =
        (combo?.elementIds.length == 3 ? 5 : 3) +
        (_match.myActiveStatuses.any((s) => s.id == 'shock') ? 1 : 0);
    final reason = _attackUnavailable(id);
    return '${combo?.name ?? id} · $cost AP${reason == null ? '' : ' · $reason'}';
  }

  String? _attackUnavailable(String id) {
    final combo = const CombinationCatalog().byId(id);
    if (combo == null) return 'Indisponível';
    if (_match.myActiveStatuses.any((s) => s.id == 'silence')) {
      return 'Silêncio';
    }
    final cost =
        (combo.elementIds.length == 3 ? 5 : 3) +
        (_match.myActiveStatuses.any((s) => s.id == 'shock') ? 1 : 0);
    final available =
        (_match.myAp +
                (_match.myActiveStatuses.any(
                      (s) => s.id == 'slow' || s.id == 'freeze',
                    )
                    ? 0
                    : 1))
            .clamp(0, _match.myApMax);
    return available < cost ? 'AP insuficiente' : null;
  }

  Widget _battleLayout(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final widgets = _buildBattle(context);
      final commands = SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: PixelContentPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: widgets.skip(1).toList(),
          ),
        ),
      );
      if (constraints.maxWidth > constraints.maxHeight) {
        return Row(
          children: [
            Expanded(child: widgets.first),
            Expanded(child: commands),
          ],
        );
      }
      return Column(
        children: [
          widgets.first,
          Expanded(child: commands),
        ],
      );
    },
  );

  Future<void> _manageAttacks() async {
    await Navigator.of(context).push(
      pixelSlideRoute(
        (_) => AttacksScreen(
          attacks: allAttackOptions(
            unlockedIds: _match.discoveries,
            equippedIds: _match.equippedAttacks,
          ),
          onSetEquipped: (ids) async {
            try {
              await _match.configure('attacks', ids);
              return null;
            } catch (error) {
              return error.toString();
            }
          },
        ),
      ),
    );
    if (mounted) {
      setState(() {
        _selectedIds.clear();
      });
      unawaited(_requestPreview());
    }
  }

  Future<void> _manageElements() async {
    final selected = _match.equippedElements.toSet();
    var saving = false;
    String? error;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, update) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Equipe até 4 elementos'),
              Wrap(
                spacing: 8,
                children: [
                  for (final element in const ElementCatalog().all().where(
                    (e) =>
                        _match.unlockedNodeIdsForMe.contains('unlock_${e.id}'),
                  ))
                    FilterChip(
                      label: Text('${element.symbol} ${element.name}'),
                      selected: selected.contains(element.id),
                      onSelected: saving
                          ? null
                          : (value) => update(() {
                              if (!value) {
                                selected.remove(element.id);
                              } else if (selected.length < 4) {
                                selected.add(element.id);
                              }
                            }),
                    ),
                ],
              ),
              if (error != null) Text(error!),
              PixelMenuButton(
                label: saving ? 'Salvando…' : 'Confirmar',
                onPressed: saving || selected.isEmpty
                    ? null
                    : () async {
                        update(() => saving = true);
                        try {
                          await _match.configure('elements', selected.toList());
                          if (sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                        } catch (e) {
                          if (sheetContext.mounted) {
                            update(() {
                              error = e.toString();
                              saving = false;
                            });
                          }
                        }
                      },
              ),
            ],
          ),
        ),
      ),
    );
    if (mounted) {
      setState(() => _selectedIds.clear());
      unawaited(_requestPreview());
    }
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
