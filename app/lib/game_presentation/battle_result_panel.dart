import 'package:flutter/material.dart';

import '../game_domain/battle_progress.dart';
import '../game_domain/combination_catalog.dart';
import '../game_domain/skill_tree_catalog.dart';
import 'pixel_menu_button.dart';
import 'pixel_outlined_text.dart';

class BattleResultPlayer {
  const BattleResultPlayer({
    required this.label,
    required this.gains,
    required this.onReview,
  });
  final String label;
  final BattleProgress? gains;
  final VoidCallback? onReview;
}

/// Shared, scroll-parent-friendly panel; no battle or persistence mutations.
class BattleResultPanel extends StatelessWidget {
  const BattleResultPanel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.players,
    required this.onRematch,
    required this.onMenu,
    this.sharedDiscoveries,
    this.remote = false,
    this.busy = false,
    this.error,
  });

  final String title, subtitle;
  final List<BattleResultPlayer> players;
  final Iterable<String>? sharedDiscoveries;
  final VoidCallback? onRematch, onMenu;
  final bool remote, busy;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        height: 1.4,
        color: Color(0xFF283C36),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: const Color(0xFF283C36),
            child: Column(
              children: [
                Semantics(
                  liveRegion: true,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: PixelOutlinedText(
                      title,
                      fontSize: 26,
                      color: const Color(0xFFF4D782),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFF1E8C9)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: PixelMenuButton(
                  label: busy ? 'Criando sala…' : 'Revanche',
                  primary: true,
                  onPressed: busy ? null : onRematch,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 86,
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF283C36),
                  ),
                  onPressed: busy ? null : onMenu,
                  child: const Text(
                    'Voltar ao menu',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            remote
                ? 'Revanche cria outra sala: compartilhe o novo código.'
                : 'Revanche mantém o progresso e o equipamento.',
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error!, style: const TextStyle(color: Color(0xFF9B302E))),
          ],
          const SizedBox(height: 8),
          if (sharedDiscoveries != null)
            _combos(
              'Livro compartilhado · novas descobertas',
              sharedDiscoveries!,
            ),
          for (final player in players) ...[
            const Divider(color: Color(0xFFB6A16D)),
            Text(
              player.label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (player.gains == null)
              const Text(
                'Partida retomada: ganhos anteriores à reconexão não podem ser determinados.',
              )
            else ...[
              if (player.gains!.attacks.isEmpty &&
                  player.gains!.skills.isEmpty &&
                  (sharedDiscoveries != null ||
                      player.gains!.discoveries.isEmpty))
                const Text('Nenhum novo desbloqueio nesta partida.'),
              if (sharedDiscoveries == null &&
                  player.gains!.discoveries.isNotEmpty)
                _combos('Novas descobertas', player.gains!.discoveries),
              if (player.gains!.attacks.isNotEmpty)
                _combos('Habilidades aprendidas', player.gains!.attacks),
              if (player.gains!.skills.isNotEmpty)
                _skills(player.gains!.skills),
            ],
            const SizedBox(height: 8),
            PixelMenuButton(
              label: remote
                  ? 'Revisar habilidades'
                  : 'Habilidades · ${player.label}',
              onPressed: busy ? null : player.onReview,
            ),
          ],
        ],
      ),
    );
  }

  Widget _combos(String label, Iterable<String> ids) {
    final names = ids
        .map((id) => const CombinationCatalog().byId(id)?.name)
        .whereType<String>()
        .toList();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        '$label: ${names.isEmpty ? 'nenhuma nesta partida' : names.join(', ')}.',
      ),
    );
  }

  Widget _skills(Iterable<String> ids) {
    final names = allSkillTreeNodes()
        .where((n) => ids.contains(n.id))
        .map((n) => n.name)
        .toList();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        'Árvore / elementos: ${names.isEmpty ? 'nenhum desbloqueio nesta partida' : names.join(', ')}.',
      ),
    );
  }
}
