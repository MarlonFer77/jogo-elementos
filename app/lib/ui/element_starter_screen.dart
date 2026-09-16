import 'package:flutter/material.dart';

import '../game_domain/element_catalog.dart';
import '../game_presentation/battle_command_panel.dart';
import '../game_presentation/pixel_menu_button.dart';

/// Tela cheia e bloqueante (mesmo padrão do `UpdateGateScreen`, só que
/// local ao Modo Treino): escolhe os 2 elementos iniciais de um jogador,
/// uma vez só (Bloco 2b, DECISION-047). Os outros 8 elementos começam
/// bloqueados e se desbloqueiam depois via Skill Tree. `TrainingScreen`
/// decide quando mostrar isso (uma vez por slot `'a'`/`'b'`) e o que
/// fazer com os 2 ids escolhidos — esta tela só coleta a escolha.
class ElementStarterScreen extends StatefulWidget {
  const ElementStarterScreen({
    super.key,
    required this.playerLabel,
    required this.onConfirm,
    this.step = 1,
    this.confirmLabel = 'Confirmar',
  });

  final String playerLabel;
  final ValueChanged<List<String>> onConfirm;
  final int step;
  final String confirmLabel;

  @override
  State<ElementStarterScreen> createState() => _ElementStarterScreenState();
}

class _ElementStarterScreenState extends State<ElementStarterScreen> {
  final Set<String> _selectedIds = {};

  void _toggle(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else if (_selectedIds.length < 2) {
        _selectedIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final elements = const ElementCatalog().all();

    return Scaffold(
      backgroundColor: const Color(0xFF344C56),
      appBar: AppBar(
        backgroundColor: const Color(0xFF344C56),
        foregroundColor: const Color(0xFFF8F2DA),
        toolbarHeight: 44,
        title: const Text(
          'TREINO · PREPARAÇÃO',
          style: TextStyle(fontFamily: 'monospace', fontSize: 16),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontal =
                constraints.maxWidth >= 480 &&
                constraints.maxWidth > constraints.maxHeight;
            final intro = SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ETAPA ${widget.step}/2 · ${widget.playerLabel}',
                      style: const TextStyle(
                        color: Color(0xFFF2DB88),
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Escolha seus 2 elementos',
                      style: TextStyle(
                        color: Color(0xFFF8F2DA),
                        fontSize: 21,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Comece com 2. Desbloqueie os demais jogando e equipe até 4 na batalha.',
                      style: TextStyle(color: Color(0xFFF8F2DA), fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final (index, label) in [
                          'Jogador A',
                          'Jogador B',
                          'Batalha',
                        ].indexed)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: index + 1 == widget.step
                                  ? const Color(0xFFF2DB88)
                                  : null,
                              border: Border.all(
                                color: const Color(0xFFACB7A1),
                              ),
                            ),
                            child: Text(
                              '${index + 1} · $label',
                              style: TextStyle(
                                fontSize: 11,
                                color: index + 1 == widget.step
                                    ? const Color(0xFF253843)
                                    : const Color(0xFFF8F2DA),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
            final choices = Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F2DA),
                border: Border.all(color: const Color(0xFFACB7A1), width: 3),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      key: const ValueKey('starter-elements'),
                      child: BattleCommandGrid(
                        children: [
                          for (final element in elements)
                            ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 48),
                              child: BattleCommandButton(
                                title: '${element.symbol} ${element.name}',
                                selected: _selectedIds.contains(element.id),
                                unavailable:
                                    _selectedIds.length == 2 &&
                                    !_selectedIds.contains(element.id),
                                onPressed:
                                    _selectedIds.length == 2 &&
                                        !_selectedIds.contains(element.id)
                                    ? null
                                    : () => _toggle(element.id),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_selectedIds.length}/2 · ${elements.where((e) => _selectedIds.contains(e.id)).map((e) => e.name).join(' + ')}',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _selectedIds.length == 2
                        ? 'Toque em um selecionado para trocar.'
                        : 'Selecione dois elementos para continuar.',
                    style: const TextStyle(fontSize: 11),
                  ),
                  const SizedBox(height: 6),
                  PixelMenuButton(
                    label: widget.confirmLabel,
                    primary: true,
                    onPressed: _selectedIds.length == 2
                        ? () => widget.onConfirm(_selectedIds.toList())
                        : null,
                  ),
                ],
              ),
            );
            return Flex(
              direction: horizontal ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: horizontal ? constraints.maxWidth * .38 : null,
                  height: horizontal
                      ? null
                      : (constraints.maxHeight * .38).clamp(200.0, 220.0),
                  child: intro,
                ),
                Expanded(child: choices),
              ],
            );
          },
        ),
      ),
    );
  }
}
