import 'package:flutter/material.dart';

import '../game_domain/attack_event.dart';
import '../game_domain/battle_scene_view.dart';
import '../game_domain/element_catalog.dart';
import '../game_domain/training_match.dart';
import '../game_presentation/battle_scene_widget.dart';
import '../game_presentation/pixel_arena_background.dart';
import '../game_presentation/pixel_content_panel.dart';
import '../game_presentation/pixel_element_chip.dart';
import '../game_presentation/pixel_menu_button.dart';
import '../game_presentation/pixel_outlined_text.dart';
import '../game_presentation/pixel_sheet_panel.dart';

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
  AttackEvent? _pendingAttack;

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
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final available = _match.availableSkillNodesForCurrentPlayer;
            // Fixed height + Expanded list, so "Fechar" always stays at a
            // predictable spot regardless of how many nodes are available
            // (the list scrolls internally instead of pushing it off).
            return PixelSheetPanel(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PixelOutlinedText(
                        'Habilidades de ${_match.currentTurnName}',
                        fontSize: 18,
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: available.isEmpty
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
                                            onPressed: () {
                                              setState(() {
                                                _match.unlockSkillForCurrentPlayer(
                                                  node.id,
                                                );
                                              });
                                              setSheetState(() {});
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
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Vez de: ${_match.currentTurnName}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text('Jogador A: ${_statusSummary(_match.playerAStatusNames)}'),
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
                            onTap: () {
                              _toggleElement(element.id);
                              setSheetState(() {});
                            },
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

  String _statusSummary(List<String> statusNames) {
    return statusNames.isEmpty ? 'sem estados' : statusNames.join(', ');
  }
}
