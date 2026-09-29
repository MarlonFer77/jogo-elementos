import 'package:flutter/material.dart';

import '../game_domain/skill_tree_catalog.dart';
import '../game_presentation/rpg_journal.dart';
import '../game_presentation/pixel_menu_button.dart';
import '../game_presentation/pixel_outlined_text.dart';
import '../game_presentation/pixel_sheet_panel.dart';
import '../game_presentation/sfx_player.dart';
import '../game_presentation/skill_tree_layout.dart';
import '../game_presentation/skill_tree_node_widget.dart';

/// Responsive specialization journal shared by all modes.
/// Goals are visit-local planning; purchases remain with the authoritative owner.
class SkillTreeScreen extends StatefulWidget {
  const SkillTreeScreen({
    super.key,
    required this.title,
    required this.unlockedNodeIds,
    required this.canUnlockNow,
    required this.onUnlock,
    this.extraLockedHint,
    this.progressLabel,
    this.unlockLabel = 'Desbloquear',
  });

  final String title;
  final List<String> unlockedNodeIds;
  final bool canUnlockNow;
  final Future<String?> Function(String nodeId) onUnlock;
  final String? Function(String nodeId)? extraLockedHint;
  final String Function()? progressLabel;
  final String unlockLabel;

  @override
  State<SkillTreeScreen> createState() => _SkillTreeScreenState();
}

class _SkillTreeScreenState extends State<SkillTreeScreen> {
  late List<String> _unlockedNodeIds = List.of(widget.unlockedNodeIds);
  bool _unlockPending = false;
  String _branch = 'fogo';
  String? _goal;
  bool _availableOnly = false;

  @override
  Widget build(BuildContext context) {
    final all = allSkillTreeNodes();
    final branches = all.map((n) => n.branch).toSet().toList();
    final nodes = orderBranchNodes(
      all.where((n) => n.branch == _branch).toList(),
    );
    final visible = nodes
        .where(
          (node) =>
              !_availableOnly ||
              (skillTreeNodeState(node, _unlockedNodeIds) ==
                      SkillTreeNodeState.available &&
                  widget.canUnlockNow &&
                  widget.extraLockedHint?.call(node.id) == null),
        )
        .toList();
    final talents = all
        .where(
          (n) => n.branch != 'elementos' && _unlockedNodeIds.contains(n.id),
        )
        .length;
    return RpgJournal(
      title: widget.title,
      actions: [
        IconButton(
          tooltip: 'Minha build',
          icon: const Icon(Icons.person_outline),
          onPressed: _showBuild,
        ),
        IconButton(
          tooltip: _availableOnly ? 'Mostrar todas' : 'Somente disponíveis',
          icon: Icon(
            _availableOnly ? Icons.filter_alt : Icons.filter_alt_outlined,
          ),
          onPressed: () => setState(() => _availableOnly = !_availableOnly),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  skillBuildIdentity(_unlockedNodeIds),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$talents talentos · ${_unlockedNodeIds.where((id) => id.startsWith('unlock_')).length}/10 elementos',
                  style: const TextStyle(fontSize: 12),
                ),
                if (widget.progressLabel != null)
                  Text(
                    widget.progressLabel!(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (_goal != null)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                    ),
                    icon: const Icon(Icons.flag_outlined, size: 18),
                    label: Text(
                      'Objetivo: ${all.firstWhere((n) => n.id == _goal).name}',
                      maxLines: 2,
                    ),
                    onPressed: () =>
                        _openNodeDetail(all.firstWhere((n) => n.id == _goal)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 600;
                Widget tabs({required bool vertical}) => SingleChildScrollView(
                  scrollDirection: vertical ? Axis.vertical : Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Flex(
                    direction: vertical ? Axis.vertical : Axis.horizontal,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final branch in branches)
                        Padding(
                          padding: const EdgeInsets.only(right: 6, bottom: 4),
                          child: ChoiceChip(
                            label: Text(
                              '${skillTreeBranchDisplayName(branch)} · ${all.where((n) => n.branch == branch && _unlockedNodeIds.contains(n.id)).length}/${all.where((n) => n.branch == branch).length}',
                            ),
                            selected: _branch == branch,
                            showCheckmark: false,
                            selectedColor: skillBranchColor(branch),
                            labelStyle: TextStyle(
                              color: _branch == branch
                                  ? Colors.white
                                  : RpgJournal.ink,
                              fontWeight: FontWeight.bold,
                            ),
                            onSelected: (_) {
                              sfxPlayer.play(SfxId.tap);
                              setState(() => _branch = branch);
                            },
                          ),
                        ),
                    ],
                  ),
                );
                final tree = ListView(
                  key: ValueKey('branch-$_branch-$_availableOnly'),
                  padding: const EdgeInsets.all(10),
                  children: [
                    Text(
                      skillTreeBranchIdentity(_branch),
                      style: TextStyle(
                        color: skillBranchColor(_branch),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value:
                          nodes
                              .where((n) => _unlockedNodeIds.contains(n.id))
                              .length /
                          nodes.length,
                      color: skillBranchColor(_branch),
                      backgroundColor: const Color(0xFFD8D1B8),
                    ),
                    const SizedBox(height: 12),
                    if (visible.isEmpty)
                      const Text(
                        'Nenhuma habilidade disponível neste caminho agora. Remova o filtro para consultar os requisitos.',
                      ),
                    for (final node in visible) ...[
                      if (node.prerequisites.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 26),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width: 3,
                              height: 16,
                              color: skillBranchColor(_branch),
                            ),
                          ),
                        ),
                      SkillTreeNodeWidget(
                        key: ValueKey('talent-${node.id}'),
                        name: node.name,
                        icon: node.icon,
                        state: skillTreeNodeState(node, _unlockedNodeIds),
                        accent: skillBranchColor(_branch),
                        description: _unlockedNodeIds.contains(node.id)
                            ? node.description
                            : widget.extraLockedHint?.call(node.id) ??
                                  node.description,
                        onTap: () => _openNodeDetail(node),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                );
                return wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 175, child: tabs(vertical: true)),
                          Expanded(child: tree),
                        ],
                      )
                    : Column(
                        children: [
                          tabs(vertical: false),
                          Expanded(child: tree),
                        ],
                      );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showBuild() {
    final nodes = allSkillTreeNodes()
        .where((n) => _unlockedNodeIds.contains(n.id))
        .toList();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Theme(
        data: RpgJournal.themeFor(context),
        child: SafeArea(
          child: PixelSheetPanel(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .8,
              ),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'MINHA BUILD',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(skillBuildIdentity(_unlockedNodeIds)),
                  const Text(
                    'O estilo resume seus talentos; não concede bônus extras. Misture caminhos para criar sua estratégia.',
                    style: TextStyle(fontSize: 12),
                  ),
                  if (nodes.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Nenhum talento aprendido ainda. Explore um caminho para começar.',
                      ),
                    ),
                  for (final node in nodes)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Text(
                        node.icon,
                        style: const TextStyle(fontSize: 24),
                      ),
                      title: Text(node.name),
                      subtitle: Text(node.description),
                    ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Voltar à árvore'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
          builder: (context, updateSheet) => Theme(
            data: RpgJournal.themeFor(context),
            child: SafeArea(
              child: PixelSheetPanel(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * .85,
                  ),
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
                          const SizedBox(height: 8),
                          Text(
                            'COMO USAR',
                            style: TextStyle(
                              color: skillBranchColor(node.branch),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(skillTreeTactic(node.id)),
                          if (allSkillTreeNodes().any(
                            (n) => n.prerequisites.contains(node.id),
                          ))
                            Text(
                              'Abre caminho para: ${allSkillTreeNodes().where((n) => n.prerequisites.contains(node.id)).map((n) => n.name).join(', ')}',
                            ),
                          if (state != SkillTreeNodeState.unlocked)
                            TextButton.icon(
                              icon: const Icon(Icons.flag_outlined),
                              label: Text(
                                _goal == node.id
                                    ? 'Remover objetivo'
                                    : 'Marcar como objetivo',
                              ),
                              onPressed: _unlockPending
                                  ? null
                                  : () {
                                      setState(
                                        () => _goal = _goal == node.id
                                            ? null
                                            : node.id,
                                      );
                                      Navigator.of(sheetContext).pop();
                                    },
                            ),
                          if (state != SkillTreeNodeState.unlocked)
                            const Text(
                              'Objetivo de planejamento nesta visita; não compra a habilidade.',
                              style: TextStyle(fontSize: 11),
                            ),
                          if (skillTreeNodeCaveat(node.id)
                              case final warning?) ...[
                            const SizedBox(height: 8),
                            Text(
                              warning,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
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
                                  : widget.unlockLabel,
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
                                        if (sheetContext.mounted) {
                                          updateSheet(() {});
                                        }
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
                                      setState(() {
                                        if (_goal == node.id) _goal = null;
                                        _unlockedNodeIds = [
                                          ..._unlockedNodeIds,
                                          node.id,
                                        ];
                                      });
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
