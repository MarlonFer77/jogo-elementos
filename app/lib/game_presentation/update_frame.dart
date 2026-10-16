import 'package:flutter/material.dart';
import 'rpg_journal.dart';

/// Presentation only; never starts a download or interprets an OTA result.
class UpdateFrame extends StatelessWidget {
  const UpdateFrame({
    super.key,
    required this.title,
    required this.icon,
    required this.step,
    required this.body,
    required this.actions,
    this.installedVersion,
    this.latestVersion,
    this.warning = false,
  });
  final String title;
  final IconData icon;
  final int step;
  final Widget body;
  final List<Widget> actions;
  final String? installedVersion, latestVersion;
  final bool warning;

  @override
  Widget build(BuildContext context) => Theme(
    data: RpgJournal.themeFor(context),
    child: Scaffold(
      backgroundColor: const Color(0xFF142827),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const CustomPaint(painter: _UpdateBackdrop()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide =
                    constraints.maxWidth > constraints.maxHeight &&
                    constraints.maxWidth >= 540;
                final compact = constraints.maxHeight < 600;
                final mark = Semantics(
                  header: true,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        color: RpgJournal.gold,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'ELEMENTOS',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: compact ? 18 : 23,
                          color: RpgJournal.paper,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
                final panel = DecoratedBox(
                  decoration: BoxDecoration(
                    color: RpgJournal.paper,
                    border: Border.all(color: RpgJournal.gold, width: 2),
                    boxShadow: const [
                      BoxShadow(color: Color(0xFF0C1B1B), offset: Offset(4, 4)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.all(compact ? 12 : 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    icon,
                                    color: warning
                                        ? const Color(0xFF944D35)
                                        : RpgJournal.ink,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Semantics(
                                      header: true,
                                      liveRegion: true,
                                      child: Text(
                                        title,
                                        style: const TextStyle(
                                          fontSize: 21,
                                          fontWeight: FontWeight.bold,
                                          color: RpgJournal.ink,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (!wide) ...[
                                _details(),
                                const SizedBox(height: 16),
                              ],
                              DefaultTextStyle.merge(
                                style: const TextStyle(
                                  color: RpgJournal.ink,
                                  fontSize: 14,
                                ),
                                child: body,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (actions.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            12,
                            8,
                            12,
                            compact ? 8 : 14,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: actions,
                          ),
                        ),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(12, 4, 12, 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 16,
                              color: RpgJournal.ink,
                            ),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Atualize sem desinstalar para preservar seu progresso.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: RpgJournal.ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: wide ? 860 : 470,
                        maxHeight: 650,
                      ),
                      child: wide
                          ? Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: SingleChildScrollView(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        mark,
                                        const SizedBox(height: 12),
                                        const Icon(
                                          Icons.shield_outlined,
                                          size: 40,
                                          color: RpgJournal.gold,
                                        ),
                                        const SizedBox(height: 12),
                                        _details(dark: true),
                                        const SizedBox(height: 10),
                                        const Text(
                                          'Atualizações via GitHub Releases',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: RpgJournal.gold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(flex: 5, child: panel),
                              ],
                            )
                          : Column(
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(
                                    bottom: compact ? 10 : 20,
                                  ),
                                  child: mark,
                                ),
                                Expanded(child: panel),
                                const SizedBox(height: 10),
                                const Text(
                                  'ORDEM DOS ECOS · GitHub Releases',
                                  style: TextStyle(
                                    color: RpgJournal.gold,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );

  Widget _details({bool dark = false}) {
    final ink = dark ? RpgJournal.paper : RpgJournal.ink;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (installedVersion != null || latestVersion != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            color: dark ? const Color(0xFF142827) : const Color(0xFFE1D9B8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (installedVersion != null)
                  Text(
                    'Versão instalada: $installedVersion',
                    style: TextStyle(fontSize: 13, color: ink),
                  ),
                if (latestVersion != null)
                  Text(
                    'Nova versão: v$latestVersion',
                    style: TextStyle(fontWeight: FontWeight.bold, color: ink),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (step >= 0)
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              for (final (index, label) in [
                'Consultar',
                'Baixar',
                'Instalar',
              ].indexed)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      index < step
                          ? Icons.check_circle
                          : index == step
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 15,
                      color: ink,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        color: ink,
                        fontWeight: index == step
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
            ],
          ),
      ],
    );
  }
}

class _UpdateBackdrop extends CustomPainter {
  const _UpdateBackdrop();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF203B38);
    // Stone courses and a pointed arch, no animated glow behind status text.
    for (var row = 0; row < (size.height / 54).ceil(); row++) {
      for (var col = -1; col < (size.width / 100).ceil(); col++) {
        canvas.drawRect(
          Rect.fromLTWH(
            col * 100.0 + (row.isEven ? 0 : 50),
            row * 54.0,
            96,
            50,
          ),
          paint,
        );
      }
    }
    paint
      ..color = const Color(0xFF38514A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    canvas.drawPath(
      Path()
        ..moveTo(size.width * .13, size.height)
        ..lineTo(size.width * .13, size.height * .3)
        ..lineTo(size.width * .5, size.height * .03)
        ..lineTo(size.width * .87, size.height * .3)
        ..lineTo(size.width * .87, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _UpdateBackdrop oldDelegate) => false;
}
