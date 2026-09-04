import 'package:flutter/material.dart';

import '../game_domain/element_catalog.dart';
import '../game_domain/training_match.dart';

/// Modo treino: batalha local, offline, hotseat — os dois lados jogados no
/// mesmo aparelho. Sem backend, sem multiplayer, sem IA. Cada jogador pode
/// desbloquear habilidades da Skill Tree na própria vez; o que já
/// desbloqueou se aplica automaticamente em toda ação que jogar depois (e,
/// no caso de bônus de HP, imediatamente). A partida termina quando o HP
/// de alguém chega a 0.
class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key, TrainingMatch? initialMatch})
      : _initialMatch = initialMatch;

  final TrainingMatch? _initialMatch;

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  late TrainingMatch _match = widget._initialMatch ?? TrainingMatch();
  final Set<String> _selectedIds = {};
  String? _error;

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
      try {
        _match.playElementIds(_selectedIds.toList());
        _selectedIds.clear();
      } on ArgumentError {
        _error = 'Jogada inválida.';
      }
    });
  }

  void _startNewMatch() {
    setState(() {
      _match = TrainingMatch();
      _selectedIds.clear();
      _error = null;
    });
  }

  void _openSkillTree() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final available = _match.availableSkillNodesForCurrentPlayer;
            // Fixed height + Expanded list, so "Fechar" always stays at a
            // predictable spot regardless of how many nodes are available
            // (the list scrolls internally instead of pushing it off).
            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Habilidades de ${_match.currentTurnName}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: available.isEmpty
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
                                      onPressed: () {
                                        setState(() {
                                          _match.unlockSkillForCurrentPlayer(
                                            node.id,
                                          );
                                        });
                                        setSheetState(() {});
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modo Treino'),
        actions: [
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
            Text(
              'Vez de: ${_match.currentTurnName}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Jogador A: ${_match.playerACurrentHp}/${_match.playerAMaxHp} HP',
            ),
            Text('Jogador A: ${_statusSummary(_match.playerAStatusNames)}'),
            Text(
              'Jogador B: ${_match.playerBCurrentHp}/${_match.playerBMaxHp} HP',
            ),
            Text('Jogador B: ${_statusSummary(_match.playerBStatusNames)}'),
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
            if (_match.activeFieldEffectNames.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Campo: ${_match.activeFieldEffectNames.join(", ")}',
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
    );
  }

  List<Widget> _buildGameOver(BuildContext context) {
    return [
      Text(
        'Fim de partida! Vencedor: ${_match.winnerName}',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 16),
      ElevatedButton(
        onPressed: _startNewMatch,
        child: const Text('Nova partida'),
      ),
    ];
  }

  List<Widget> _buildPlayForm(BuildContext context) {
    final elements = const ElementCatalog().all();

    return [
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
              onSelected: (_) => _toggleElement(element.id),
            ),
        ],
      ),
      const SizedBox(height: 16),
      ElevatedButton(
        onPressed: _selectedIds.isEmpty ? null : _playTurn,
        child: const Text('Jogar'),
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

  String _statusSummary(List<String> statusNames) {
    return statusNames.isEmpty ? 'sem estados' : statusNames.join(', ');
  }
}
