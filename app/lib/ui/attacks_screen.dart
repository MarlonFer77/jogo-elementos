import 'package:flutter/material.dart';

import '../game_domain/attack_catalog.dart';
import '../game_presentation/pixel_arena_background.dart';
import '../game_presentation/pixel_content_panel.dart';
import '../game_presentation/pixel_menu_button.dart';
import '../game_presentation/pixel_outlined_text.dart';
import '../game_presentation/pixel_sheet_panel.dart';

/// Tela cheia listando os ataques (combinações) que o jogador da vez já
/// desbloqueou, com os até 3 equipados em destaque — permite equipar,
/// desequipar e trocar (Bloco 2c, DECISION-048). A tela não muda estado
/// de `TrainingMatch` sozinha — chama [onSetEquipped] (o chamador decide
/// como aplicar e persistir), mesmo padrão de `SkillTreeScreen.onUnlock`.
/// Ver docs/superpowers/specs/2026-09-15-equippable-attacks-design.md.
class AttacksScreen extends StatefulWidget {
  const AttacksScreen({
    super.key,
    required this.attacks,
    required this.onSetEquipped,
    this.highlightComboId,
    this.asSheet = false,
    this.readOnly = false,
  });

  final List<AttackOption> attacks;
  final Future<String?> Function(List<String> combinationIds) onSetEquipped;
  final String? highlightComboId;
  final bool asSheet;
  final bool readOnly;

  @override
  State<AttacksScreen> createState() => _AttacksScreenState();
}

class _AttacksScreenState extends State<AttacksScreen> {
  late List<AttackOption> _attacks = widget.attacks;
  bool _sheetOpen = false;

  List<AttackOption> get _unlockedAttacks =>
      _attacks.where((a) => a.unlocked).toList();

  List<String> get _equippedIds =>
      _attacks.where((a) => a.equipped).map((a) => a.id).toList();

  @override
  void initState() {
    super.initState();
    final highlightId = widget.highlightComboId;
    if (highlightId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final highlighted = _attacks.firstWhere((a) => a.id == highlightId);
        _openAttackAction(highlighted);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = _unlockedAttacks;
    return Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: ArenaBackdropPainter())),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: widget.asSheet
                ? IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Fechar habilidades',
                    onPressed: () => Navigator.pop(context),
                  )
                : null,
            title: PixelOutlinedText(
              widget.asSheet ? 'Habilidades · 3 slots' : 'Ataques Combinados',
              fontSize: 18,
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: PixelContentPanel(
              child: _sheetOpen
                  ? const SizedBox.shrink()
                  : unlocked.isEmpty
                  ? const Text('Nenhum ataque desbloqueado ainda.')
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.readOnly)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: Text(
                                'Partida encerrada · apenas consulta. Altere seu equipamento na próxima partida.',
                              ),
                            ),
                          for (final attack in unlocked)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _AttackTile(
                                attack: attack,
                                onTap: () => _openAttackAction(attack),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  void _openAttackAction(AttackOption attack) {
    if (widget.readOnly) {
      showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (context) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                attack.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '${attack.apCost} AP base · ${attack.equipped ? 'Equipada' : 'Não equipada'}',
              ),
              Text(attack.description),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fechar'),
              ),
            ],
          ),
        ),
      );
      return;
    }
    if (attack.equipped) {
      _showUnequipSheet(attack);
    } else if (_equippedIds.length < 3) {
      _setEquipped([..._equippedIds, attack.id]);
    } else {
      _showSwapSheet(attack);
    }
  }

  void _showUnequipSheet(AttackOption attack) {
    setState(() => _sheetOpen = true);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return PixelSheetPanel(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PixelOutlinedText(attack.name, fontSize: 18),
                const SizedBox(height: 8),
                Text(attack.description),
                const SizedBox(height: 12),
                PixelMenuButton(
                  label: 'Desequipar',
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    _setEquipped(
                      _equippedIds.where((id) => id != attack.id).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(() {
      if (mounted) setState(() => _sheetOpen = false);
    });
  }

  void _showSwapSheet(AttackOption newAttack) {
    setState(() => _sheetOpen = true);
    final equippedIds = _equippedIds;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return PixelSheetPanel(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PixelOutlinedText(
                  'Escolha um ataque pra substituir por ${newAttack.name}',
                  fontSize: 16,
                ),
                const SizedBox(height: 12),
                for (final equippedId in equippedIds)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: PixelMenuButton(
                      label: _attacks
                          .firstWhere((a) => a.id == equippedId)
                          .name,
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _setEquipped([
                          for (final id in equippedIds)
                            if (id != equippedId) id,
                          newAttack.id,
                        ]);
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(() {
      if (mounted) setState(() => _sheetOpen = false);
    });
  }

  Future<void> _setEquipped(List<String> ids) async {
    final error = await widget.onSetEquipped(ids);
    if (error != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    if (!mounted) return;
    setState(() {
      _attacks = [
        for (final attack in _attacks)
          AttackOption(
            id: attack.id,
            name: attack.name,
            description: attack.description,
            unlocked: attack.unlocked,
            equipped: ids.contains(attack.id),
            elementIds: attack.elementIds,
            apCost: attack.apCost,
          ),
      ];
    });
  }
}

class _AttackTile extends StatelessWidget {
  const _AttackTile({required this.attack, required this.onTap});

  final AttackOption attack;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: attack.equipped
              ? const Color(0xFFF4C94A)
              : const Color(0xFFF4F4E4),
          border: Border.all(color: const Color(0xFF2B2B2B), width: 3),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                attack.name,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  color: Color(0xFF2B2B2B),
                ),
              ),
            ),
            if (attack.equipped) ...[
              const SizedBox(width: 6),
              const Icon(
                Icons.check_circle,
                size: 16,
                color: Color(0xFF2B2B2B),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
