import 'package:flutter/material.dart';

import '../game_domain/dungeon_blessings.dart';
import '../game_presentation/pixel_menu_button.dart';
import '../game_presentation/sfx_player.dart';

const _ink = Color(0xFF263D3D), _paper = Color(0xFFF8F2DA);

(IconData, String, Color) _role(BlessingRole role) => switch (role) {
  BlessingRole.offense => (
    Icons.local_fire_department,
    'OFENSIVA',
    const Color(0xFF9C543C),
  ),
  BlessingRole.defense => (Icons.shield, 'DEFENSIVA', const Color(0xFF456D69)),
  BlessingRole.energy => (Icons.bolt, 'ENERGIA', const Color(0xFF85682E)),
};

Future<void> showDungeonBlessings(
  BuildContext context,
  List<DungeonBlessing> blessings,
) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    backgroundColor: _paper,
    title: const Text('Bênçãos da expedição'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Valem só nesta tentativa. Cada sala reaplica os efeitos de abertura.',
            ),
            for (final b in blessings)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text('${b.name}\n${b.description}'),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Voltar'),
      ),
    ],
  ),
);

/// Selection is tentative until confirmation and successful persistence.
class DungeonBlessingScreen extends StatefulWidget {
  const DungeonBlessingScreen({
    super.key,
    required this.altar,
    required this.offers,
    required this.onConfirm,
    required this.busy,
    this.error,
  });
  final int altar;
  final List<DungeonBlessing> offers;
  final Future<void> Function(String id) onConfirm;
  final bool busy;
  final String? error;

  @override
  State<DungeonBlessingScreen> createState() => _DungeonBlessingScreenState();
}

class _DungeonBlessingScreenState extends State<DungeonBlessingScreen> {
  String? _selected;

  Widget _card(DungeonBlessing b) {
    final (icon, role, color) = _role(b.role);
    final selected = _selected == b.id;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? const Color(0xFFF2DB88) : _paper,
        shape: BeveledRectangleBorder(
          borderRadius: BorderRadius.circular(5),
          side: BorderSide(
            color: selected ? const Color(0xFFB38632) : color,
            width: 3,
          ),
        ),
        child: InkWell(
          key: ValueKey('blessing-${b.id}'),
          onTap: widget.busy
              ? null
              : () {
                  sfxPlayer.play(SfxId.tap);
                  setState(() => _selected = b.id);
                },
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      selected ? Icons.check_circle : icon,
                      size: 18,
                      color: color,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        role,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  b.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  b.description,
                  style: const TextStyle(fontSize: 12, color: _ink),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _ink,
    appBar: AppBar(
      toolbarHeight: 44,
      backgroundColor: _ink,
      foregroundColor: _paper,
      title: Text(
        'ALTAR · SALA ${widget.altar}',
        style: const TextStyle(fontFamily: 'monospace', fontSize: 16),
      ),
    ),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Escolha 1 bênção · dura até o fim desta expedição.',
              style: TextStyle(color: _paper, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cards = widget.offers.map(_card).toList();
                  if (constraints.maxWidth >= 480 &&
                      constraints.maxHeight < 400) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < cards.length; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          Expanded(
                            child: SingleChildScrollView(child: cards[i]),
                          ),
                        ],
                      ],
                    );
                  }
                  return ListView.separated(
                    itemCount: cards.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => cards[i],
                  );
                },
              ),
            ),
            if (widget.error != null)
              Text(
                widget.error!,
                style: const TextStyle(color: Color(0xFFFFDCA5)),
              ),
            const SizedBox(height: 6),
            PixelMenuButton(
              label: widget.busy ? 'Salvando bênção…' : 'Receber bênção',
              primary: true,
              onPressed: _selected == null || widget.busy
                  ? null
                  : () => widget.onConfirm(_selected!),
            ),
          ],
        ),
      ),
    ),
  );
}
