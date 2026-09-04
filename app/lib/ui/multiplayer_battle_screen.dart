import 'dart:async';

import 'package:flutter/material.dart';

import '../game_domain/combination_catalog.dart';
import '../game_domain/element_catalog.dart';
import '../game_domain/multiplayer_exception.dart';
import '../game_domain/multiplayer_match.dart';
import '../game_domain/skill_tree_catalog.dart';

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

  MultiplayerMatch get _match => widget.match;

  @override
  void initState() {
    super.initState();
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
    await _match.refresh();
    if (mounted) setState(() {});
  }

  Future<void> _playTurn() async {
    setState(() => _error = null);
    try {
      await _match.playElementIds(_selectedIds.toList());
      setState(() => _selectedIds.clear());
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
        MaterialPageRoute(builder: (_) => MultiplayerBattleScreen(match: rematch)),
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
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final canUnlockNow = _match.isInProgress && _match.isMyTurn;
            final available = canUnlockNow
                ? availableSkillNodeOptions(_match.unlockedNodeIdsForMe)
                : const <SkillNodeOption>[];

            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Habilidades',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: !canUnlockNow
                          ? const Text('Só dá pra desbloquear na sua vez.')
                          : available.isEmpty
                              ? const Text('Nada novo para desbloquear agora.')
                              : ListView(
                                  children: [
                                    for (final node in available)
                                      ListTile(
                                        title: Text(
                                          '[${node.branch}] ${node.name}',
                                        ),
                                        subtitle: Text(node.description),
                                        trailing: TextButton(
                                          onPressed: () async {
                                            try {
                                              await _match.unlockSkill(node.id);
                                              setSheetState(() {});
                                              setState(() {});
                                            } on MultiplayerException catch (e) {
                                              if (!context.mounted) return;
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text(e.message)),
                                              );
                                            }
                                          },
                                          child: const Text('Desbloquear'),
                                        ),
                                      ),
                                  ],
                                ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Fechar'),
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Partida ${_match.matchId ?? ""}'),
        actions: [
          if (_match.isInProgress)
            IconButton(
              icon: const Icon(Icons.auto_awesome),
              tooltip: 'Habilidades',
              onPressed: _openSkillTree,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
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
      ElevatedButton(
        onPressed: _startingRematch ? null : _startRematch,
        child: const Text('Revanche'),
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
      Text(
        _match.isMyTurn ? 'Sua vez' : 'Vez do oponente',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 4),
      Text('Você: ${_match.myCurrentHp}/${_match.myMaxHp} HP'),
      Text('Oponente: ${_match.opponentCurrentHp}/${_match.opponentMaxHp} HP'),
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
            FilterChip(
              label: Text('${element.symbol} ${element.name}'),
              selected: _selectedIds.contains(element.id),
              onSelected: _match.isMyTurn
                  ? (_) => _toggleElement(element.id)
                  : null,
            ),
        ],
      ),
      const SizedBox(height: 16),
      ElevatedButton(
        onPressed: (_match.isMyTurn && _selectedIds.isNotEmpty) ? _playTurn : null,
        child: const Text('Jogar'),
      ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(_error!, style: const TextStyle(color: Colors.red)),
        ),
    ];
  }
}
