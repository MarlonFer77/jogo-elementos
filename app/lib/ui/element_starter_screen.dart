import 'package:flutter/material.dart';

import '../game_domain/element_catalog.dart';
import '../game_presentation/pixel_arena_background.dart';
import '../game_presentation/pixel_content_panel.dart';
import '../game_presentation/pixel_element_chip.dart';
import '../game_presentation/pixel_menu_button.dart';
import '../game_presentation/pixel_outlined_text.dart';

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
  });

  final String playerLabel;
  final ValueChanged<List<String>> onConfirm;

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

    return Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: ArenaBackdropPainter())),
        Scaffold(
          backgroundColor: Colors.transparent,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: PixelContentPanel(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PixelOutlinedText(
                    'Escolha 2 elementos iniciais — ${widget.playerLabel}',
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
                          onTap: () => _toggle(element.id),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  PixelMenuButton(
                    label: 'Confirmar',
                    onPressed: _selectedIds.length == 2
                        ? () => widget.onConfirm(_selectedIds.toList())
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
