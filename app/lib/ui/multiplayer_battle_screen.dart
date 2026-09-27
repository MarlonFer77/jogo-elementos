import 'dart:async';
import 'conjuration_seal_dialog.dart';
import 'discovery_book_screen.dart';
import '../game_domain/discovery_catalog.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
import '../game_presentation/battle_command_panel.dart';
import '../game_presentation/battle_result_panel.dart';
import '../game_presentation/multiplayer_connection_panel.dart';
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
  bool _preparing = false;
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
    final theirHpBefore = _match.opponentCurrentHp;
    final myApBefore = _match.myAp;
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
                  healing:
                      ((_match.opponentCurrentHp ?? 0) - (theirHpBefore ?? 0))
                          .clamp(0, 9999),
                  apDrained: (myApBefore - _match.myAp).clamp(0, 9999),
                  purified:
                      const CombinationCatalog()
                          .byId(remoteAction['comboId'] as String? ?? '')
                          ?.cleanses ??
                      false,
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
    if (_match.isFinished && _pendingAttack == null && !_playedGameOverSound) {
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
    final actorHpBefore = _match.myCurrentHp;
    final targetApBefore = _match.opponentAp;
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
            healing: ((_match.myCurrentHp ?? 0) - (actorHpBefore ?? 0)).clamp(
              0,
              9999,
            ),
            apDrained: (targetApBefore - _match.opponentAp).clamp(0, 9999),
            purified: combo?.cleanses ?? false,
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
    if (_startingRematch || !_match.isFinished) return;
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
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Não foi possível criar a revanche. Tente novamente.',
        );
      }
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

  Future<void> _prepareElements() async {
    if (_preparing || _submitting || !_match.needsPreparation) return;
    setState(() => _preparing = true);
    var saving = false;
    try {
      await Navigator.of(context).push(
        pixelSlideRoute(
          (routeContext) => StatefulBuilder(
            builder: (context, update) => PopScope(
              canPop: !saving,
              child: Stack(
                children: [
                  AbsorbPointer(
                    absorbing: saving,
                    child: ElementStarterScreen(
                      playerLabel: _match.localPlayerId,
                      modeLabel: 'MULTIPLAYER',
                      onConfirm: (ids) async {
                        if (saving) return;
                        update(() => saving = true);
                        setState(() => _submitting = true);
                        var success = false;
                        try {
                          await _match.configure('prepare', ids);
                          success = true;
                        } catch (_) {
                          await _match.refresh();
                          success = !_match.needsPreparation;
                          if (!success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Não foi possível confirmar os elementos. Confira a conexão e tente novamente.',
                                ),
                              ),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _submitting = false);
                          if (context.mounted) update(() => saving = false);
                        }
                        if (success && routeContext.mounted) {
                          Navigator.of(routeContext).pop();
                        }
                      },
                    ),
                  ),
                  if (saving) const Center(child: CircularProgressIndicator()),
                ],
              ),
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: (_match.isInProgress && _match.bothReady) || _match.isFinished
              ? CustomPaint(painter: ArenaBackdropPainter())
              : const ColoredBox(color: Color(0xFF172D2C)),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            toolbarHeight: 44,
            backgroundColor: Colors.transparent,
            foregroundColor: _match.bothReady
                ? const Color(0xFF283C36)
                : const Color(0xFFF1E8C9),
            elevation: 0,
            title: PixelOutlinedText(
              'Partida ${_match.matchId ?? ""}',
              fontSize: 20,
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.menu_book),
                tooltip: 'Livro de Descobertas',
                onPressed: _submitting ? null : _openDiscoveryBook,
              ),
              if (_match.isInProgress)
                IconButton(
                  icon: const Icon(Icons.auto_awesome),
                  tooltip: 'Habilidades',
                  onPressed: _openSkillTree,
                ),
            ],
          ),
          body: (_match.isInProgress && _match.bothReady) || _match.isFinished
              ? SafeArea(child: _battleLayout(context))
              : SafeArea(child: _waitingRoom()),
        ),
      ],
    );
  }

  Widget _waitingRoom() => MultiplayerConnectionPanel(
    title: _match.connectionError != null ? 'RECONECTANDO' : 'SALA DO DUELO',
    message: _match.isWaitingForOpponent
        ? 'Aguardando seu amigo entrar.'
        : 'Os dois jogadores precisam preparar seus elementos.',
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'CÓDIGO DA SALA',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        SelectableText(
          _match.matchId ?? '—',
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 28,
            letterSpacing: 4,
            fontWeight: FontWeight.bold,
          ),
        ),
        TextButton.icon(
          icon: const Icon(Icons.copy),
          label: const Text('Copiar código'),
          onPressed: _match.matchId == null
              ? null
              : () async {
                  try {
                    await Clipboard.setData(
                      ClipboardData(text: _match.matchId!),
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Código copiado. Envie ao seu amigo.'),
                        ),
                      );
                    }
                  } catch (_) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Não foi possível copiar. Selecione o código acima.',
                          ),
                        ),
                      );
                    }
                  }
                },
        ),
        const Divider(),
        for (final id in [_match.match?.playerAId, _match.match?.playerBId])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              id == null
                  ? 'Oponente · aguardando entrada'
                  : '$id${id == _match.localPlayerId ? ' (você)' : ''} · ${_match.match?.players[id]?['ready'] == true ? 'Elementos prontos' : 'Preparando elementos'}',
            ),
          ),
        const SizedBox(height: 12),
        if (_match.connectionError != null)
          Semantics(
            liveRegion: true,
            child: Text(
              _match.connectionError!,
              style: const TextStyle(color: Color(0xFF9B302E)),
            ),
          ),
        if (_match.needsPreparation)
          PixelMenuButton(
            label: 'Preparar elementos',
            primary: true,
            onPressed:
                _preparing || _submitting || _match.connectionError != null
                ? null
                : _prepareElements,
          )
        else
          const Text(
            'Tudo pronto do seu lado. A batalha abrirá quando ambos estiverem prontos.',
          ),
        const SizedBox(height: 12),
        const Text(
          'Pode compartilhar o código enquanto escolhe seus elementos. Voltar ao lobby não apaga esta sala.',
        ),
      ],
    ),
  );

  List<Widget> _buildGameOver(BuildContext context) {
    return [
      BattleResultPanel(
        title: _match.amIWinner ? 'VITÓRIA' : 'DERROTA',
        subtitle: _match.amIWinner
            ? 'Você venceu o duelo!'
            : 'Outra combinação pode mudar a próxima batalha.',
        players: [
          BattleResultPlayer(
            label: 'Você',
            gains: _match.battleGains,
            onReview: _manageAttacks,
          ),
        ],
        remote: true,
        busy: _startingRematch,
        onRematch: _startRematch,
        onMenu: () => Navigator.of(context).popUntil((route) => route.isFirst),
        error: _error ?? _match.connectionError,
      ),
    ];
  }

  Widget _arena(double height) => BattleSceneWidget(
    height: height,
    channelingLeft: _match.channelingLeft,
    onAttackComplete: () {
      if (!mounted) return;
      setState(() => _pendingAttack = null);
      _maybePlayGameOverSound();
    },
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
  );

  String _statusName(String id) => statusName(id);

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

  bool get _canSelect =>
      _match.isMyTurn &&
      !_submitting &&
      !_match.amIFrozen &&
      _match.match?.seal == null;

  void _selectElements(List<String> ids) {
    setState(() {
      _defending = false;
      _error = null;
      _selectedIds
        ..clear()
        ..addAll(ids);
    });
    unawaited(_requestPreview());
  }

  List<Widget> _compactCommands() {
    final elements = const ElementCatalog()
        .all()
        .where((e) => _match.equippedElements.contains(e.id))
        .toList();
    return [
      if (_match.amIFrozen)
        const Text(
          'Congelado: use Quebrar gelo. AP não regenera.',
          style: TextStyle(fontSize: 12),
        )
      else ...[
        BattleCommandGrid(
          children: [
            if (_showAbilities) ...[
              for (var i = 0; i < 3; i++)
                if (i < _match.equippedAttacks.length)
                  Builder(
                    builder: (context) {
                      final id = _match.equippedAttacks[i];
                      final attack = const CombinationCatalog().byId(id);
                      final reason = _attackUnavailable(id);
                      return BattleCommandButton(
                        title: attack?.name ?? 'Indisponível',
                        detail:
                            reason ??
                            '${attack?.elementIds.length == 3 ? 5 : 3} AP base',
                        selected:
                            !_defending &&
                            attack != null &&
                            _selectedIds.length == attack.elementIds.length &&
                            _selectedIds.containsAll(attack.elementIds),
                        unavailable: reason != null,
                        onPressed:
                            _canSelect && reason == null && attack != null
                            ? () => _selectElements(attack.elementIds)
                            : null,
                      );
                    },
                  )
                else
                  const BattleCommandButton(
                    title: 'Habilidade vazia',
                    unavailable: true,
                  ),
              BattleCommandButton(
                title: 'Equipar',
                detail: 'Até 3 habilidades',
                onPressed: !_submitting ? _manageAttacks : null,
              ),
            ] else
              for (var i = 0; i < 4; i++)
                BattleCommandButton(
                  title: i < elements.length ? elements[i].name : 'Vazio',
                  detail: i < elements.length ? '0 AP' : 'Equipar',
                  selected:
                      i < elements.length &&
                      !_defending &&
                      _selectedIds.length == 1 &&
                      _selectedIds.contains(elements[i].id),
                  onPressed: !_canSelect
                      ? null
                      : i < elements.length
                      ? () => _selectElements([elements[i].id])
                      : _manageElements,
                ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: _canSelect
                    ? () => _openElementPicker(elements)
                    : null,
                child: const Text('Combinar'),
              ),
            ),
            Expanded(
              child: TextButton(
                onPressed: _canSelect
                    ? (_showAbilities ? _manageAttacks : _manageElements)
                    : null,
                child: const Text('Equipar'),
              ),
            ),
            Expanded(
              child: TextButton(
                onPressed: _canSelect
                    ? () {
                        setState(() {
                          _defending = true;
                          _selectedIds.clear();
                        });
                        unawaited(_requestPreview());
                      }
                    : null,
                child: Text(_defending ? 'Defesa ✓' : 'Defender'),
              ),
            ),
          ],
        ),
      ],
      if (_match.connectionError != null ||
          _error != null ||
          _previewError != null)
        Text(
          _match.connectionError ?? _error ?? _previewError!,
          style: const TextStyle(fontSize: 12, color: Color(0xFF9B302E)),
        ),
    ];
  }

  Widget _onlineAction() {
    final blockedBySilence =
        _selectedIds.length > 1 &&
        !_defending &&
        !_match.amIFrozen &&
        _match.myActiveStatuses.any((s) => s.id == 'silence');
    final preview = _previewLoading
        ? 'Calculando prévia…'
        : _preview?.summary ??
              (_match.match?.seal != null
                  ? 'Selo em andamento. Aguarde.'
                  : _match.isMyTurn
                  ? 'Escolha uma ação.'
                  : 'Aguarde seu oponente.');
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Tooltip(
          message: preview,
          child: Text(
            preview.replaceAll('\n', ' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11),
          ),
        ),
        const SizedBox(height: 4),
        PixelMenuButton(
          label: _match.amIFrozen
              ? 'Quebrar gelo'
              : _defending
              ? 'Confirmar defesa'
              : 'Jogar',
          primary: true,
          onPressed:
              !_submitting &&
                  _match.match?.seal == null &&
                  !blockedBySilence &&
                  _match.isMyTurn &&
                  (_match.amIFrozen || _selectedIds.isNotEmpty || _defending)
              ? _playTurn
              : null,
        ),
      ],
    );
  }

  Widget _battleLayout(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final horizontal = constraints.maxWidth > constraints.maxHeight;
      final arenaHeight = horizontal
          ? constraints.maxHeight
          : (constraints.maxHeight -
                    350 *
                        MediaQuery.textScalerOf(
                          context,
                        ).scale(1).clamp(1.0, 1.4))
                .clamp(
                  constraints.maxHeight * .25,
                  constraints.maxHeight * .48,
                );
      return Flex(
        direction: horizontal ? Axis.horizontal : Axis.vertical,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: horizontal ? constraints.maxWidth * .41 : null,
            height: arenaHeight,
            child: _arena(arenaHeight),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: PixelContentPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _match.isFinished
                          ? 'Batalha encerrada'
                          : _match.isMyTurn
                          ? 'Sua vez'
                          : 'Vez do oponente',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    if (!_match.isFinished)
                      Row(
                        children: [
                          for (final abilities in [false, true])
                            Expanded(
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  backgroundColor: _showAbilities == abilities
                                      ? const Color(0xFFF2DB88)
                                      : null,
                                  foregroundColor: const Color(0xFF283C36),
                                ),
                                onPressed: _submitting
                                    ? null
                                    : () => setState(
                                        () => _showAbilities = abilities,
                                      ),
                                child: Text(
                                  abilities ? 'Habilidades' : 'Elementos',
                                ),
                              ),
                            ),
                          const SizedBox(width: 6),
                          Text(
                            '${_match.myAp} AP',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    Expanded(
                      child: SingleChildScrollView(
                        key: const ValueKey('online-command-scroll'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: _match.isFinished
                              ? [
                                  if (_pendingAttack != null)
                                    const Text('Último ataque em execução…')
                                  else
                                    ..._buildGameOver(context),
                                ]
                              : _compactCommands(),
                        ),
                      ),
                    ),
                    if (!_match.isFinished) _onlineAction(),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    },
  );

  Future<void> _manageAttacks() async {
    await Navigator.of(context).push(
      pixelSlideRoute(
        (_) => AttacksScreen(
          readOnly: _match.isFinished,
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

  Future<void> _openDiscoveryBook() async {
    await Navigator.of(context).push(
      pixelSlideRoute(
        (_) => DiscoveryBookScreen(
          playerLabel: _match.localPlayerId,
          entries: () => const DiscoveryCatalog().entries(
            discoveredIds: _match.discoveries,
            learnedIds: _match.discoveries,
            equippedIds: _match.equippedAttacks,
            unavailableReason: (id) => _match.isFinished
                ? 'Partida encerrada'
                : !_match.bothReady
                ? 'Aguarde a preparação'
                : !_match.isMyTurn
                ? 'Aguarde sua vez'
                : _match.match?.seal != null
                ? 'Selo em andamento'
                : _match.amIFrozen
                ? 'Congelado: quebre o gelo primeiro'
                : _attackUnavailable(id),
          ),
          onManage: _manageAttacks,
        ),
      ),
    );
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
