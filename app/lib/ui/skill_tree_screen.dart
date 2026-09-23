import 'package:flutter/material.dart';

import '../game_domain/skill_tree_catalog.dart';
import '../game_presentation/pixel_arena_background.dart';
import '../game_presentation/pixel_content_panel.dart';
import '../game_presentation/pixel_menu_button.dart';
import '../game_presentation/pixel_outlined_text.dart';
import '../game_presentation/pixel_sheet_panel.dart';
import '../game_presentation/sfx_player.dart';
import '../game_presentation/skill_tree_layout.dart';
import '../game_presentation/skill_tree_node_widget.dart';

/// Tela cheia com a Skill Tree inteira — travados/disponíveis/
/// desbloqueados juntos, uma coluna por branch, roláveis
/// horizontalmente. Compartilhada por Treino e Multiplayer (Bloco 7) —
/// substitui os dois modais quase idênticos que existiam antes. Ver
/// docs/superpowers/specs/2026-09-10-skill-tree-screen-design.md.
class SkillTreeScreen extends StatefulWidget {
  const SkillTreeScreen({
    super.key,
    required this.title,
    required this.unlockedNodeIds,
    required this.canUnlockNow,
    required this.onUnlock,
    this.extraLockedHint,
  });

  final String title;
  final List<String> unlockedNodeIds;
  final bool canUnlockNow;
  final Future<String?> Function(String nodeId) onUnlock;
  final String? Function(String nodeId)? extraLockedHint;

  @override
  State<SkillTreeScreen> createState() => _SkillTreeScreenState();
}

class _SkillTreeScreenState extends State<SkillTreeScreen> {
  late List<String> _unlockedNodeIds = List.of(widget.unlockedNodeIds);
  bool _unlockPending = false;

  @override
  Widget build(BuildContext context) {
    final allNodes = allSkillTreeNodes();
    final branches = allNodes.map((n) => n.branch).toSet().toList();

    return Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: ArenaBackdropPainter())),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: PixelOutlinedText(widget.title, fontSize: 20),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: PixelContentPanel(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final branch in branches)
                      Padding(
                        padding: const EdgeInsets.only(right: 24),
                        child: _BranchColumn(
                          branch: branch,
                          nodes: orderBranchNodes(
                            allNodes.where((n) => n.branch == branch).toList(),
                          ),
                          unlockedNodeIds: _unlockedNodeIds,
                          onNodeTap: _openNodeDetail,
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

  void _openNodeDetail(SkillTreeNodeOption node) {
    final state = skillTreeNodeState(node, _unlockedNodeIds);
    final hint = state == SkillTreeNodeState.available
        ? widget.extraLockedHint?.call(node.id)
        : null;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, updateSheet) => PixelSheetPanel(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PixelOutlinedText(node.name, fontSize: 18),
                    const SizedBox(height: 8),
                    Text(node.description),
                    if (skillTreeNodeCaveat(node.id) case final warning?) ...[
                      const SizedBox(height: 8),
                      Text(
                        warning,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                    if (state == SkillTreeNodeState.unlocked)
                      const Text('Desbloqueada • progresso salvo'),
                    const SizedBox(height: 12),
                    if (state == SkillTreeNodeState.locked)
                      Text('Requer: ${_prerequisiteNames(node)}')
                    else if (state == SkillTreeNodeState.available &&
                        hint != null)
                      Text(hint)
                    else if (state == SkillTreeNodeState.available &&
                        !widget.canUnlockNow)
                      const Text('Só dá pra desbloquear na sua vez.')
                    else if (state == SkillTreeNodeState.available)
                      PixelMenuButton(
                        label: _unlockPending
                            ? 'Desbloqueando…'
                            : 'Desbloquear',
                        onPressed: _unlockPending
                            ? null
                            : () async {
                                if (_unlockPending) return;
                                updateSheet(() => _unlockPending = true);
                                String? error;
                                try {
                                  error = await widget.onUnlock(node.id);
                                } catch (_) {
                                  error =
                                      'Não foi possível desbloquear. Tente novamente.';
                                } finally {
                                  _unlockPending = false;
                                  if (sheetContext.mounted) updateSheet(() {});
                                }
                                if (!mounted) return;
                                if (error != null) {
                                  if (!sheetContext.mounted) return;
                                  ScaffoldMessenger.of(
                                    sheetContext,
                                  ).showSnackBar(
                                    SnackBar(content: Text(error)),
                                  );
                                  return;
                                }
                                setState(
                                  () => _unlockedNodeIds = [
                                    ..._unlockedNodeIds,
                                    node.id,
                                  ],
                                );
                                sfxPlayer.play(SfxId.unlock);
                                if (!sheetContext.mounted) return;
                                Navigator.of(sheetContext).pop();
                              },
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _prerequisiteNames(SkillTreeNodeOption node) {
    final all = allSkillTreeNodes();
    return node.prerequisites
        .map((id) => all.firstWhere((n) => n.id == id).name)
        .join(', ');
  }
}

class _BranchColumn extends StatelessWidget {
  const _BranchColumn({
    required this.branch,
    required this.nodes,
    required this.unlockedNodeIds,
    required this.onNodeTap,
  });

  final String branch;
  final List<SkillTreeNodeOption> nodes;
  final List<String> unlockedNodeIds;
  final void Function(SkillTreeNodeOption node) onNodeTap;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Text(
            skillTreeBranchDisplayName(branch),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              color: Color(0xFF2B2B2B),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 150,
            child: Text(
              skillTreeBranchIdentity(branch),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11),
            ),
          ),
          Text(
            '${nodes.where((n) => unlockedNodeIds.contains(n.id)).length}/${nodes.length} desbloqueadas',
            style: const TextStyle(fontSize: 11),
          ),
          const SizedBox(height: 12),
          for (final node in nodes) ...[
            if (node.prerequisites.isNotEmpty)
              Container(width: 3, height: 16, color: const Color(0xFF2B2B2B)),
            SkillTreeNodeWidget(
              name: node.name,
              icon: node.icon,
              state: skillTreeNodeState(node, unlockedNodeIds),
              onTap: () => onNodeTap(node),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
