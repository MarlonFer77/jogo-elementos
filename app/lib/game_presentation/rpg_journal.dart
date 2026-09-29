import 'package:flutter/material.dart';

/// Shared journal palette, scoped to progression screens (not the battle HUD).
class RpgJournal extends StatelessWidget {
  const RpgJournal({
    super.key,
    required this.title,
    required this.child,
    this.actions,
  });
  static const ink = Color(0xFF283C36);
  static const paper = Color(0xFFF1E8C9);
  static const gold = Color(0xFFB6A16D);
  final String title;
  final Widget child;
  final List<Widget>? actions;

  static ThemeData themeFor(BuildContext context) => Theme.of(context).copyWith(
    colorScheme: ColorScheme.fromSeed(seedColor: ink).copyWith(
      primary: ink,
      surface: paper,
      onSurface: ink,
      secondary: const Color(0xFF886D49),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Color(0xFFFFF8DF),
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.zero),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: paper,
      selectedColor: const Color(0xFFD6DDBA),
      side: const BorderSide(color: gold),
      shape: const RoundedRectangleBorder(),
    ),
  );

  @override
  Widget build(BuildContext context) => Theme(
    data: themeFor(context),
    child: Scaffold(
      backgroundColor: const Color(0xFF172D2C),
      appBar: AppBar(
        toolbarHeight: 44,
        backgroundColor: const Color(0xFF172D2C),
        foregroundColor: paper,
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: actions,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Container(
            decoration: BoxDecoration(
              color: paper,
              border: Border.all(color: gold, width: 3),
              boxShadow: const [
                BoxShadow(color: Color(0xFF0E2022), offset: Offset(3, 3)),
              ],
            ),
            child: child,
          ),
        ),
      ),
    ),
  );
}

Color skillBranchColor(String branch) => switch (branch) {
  'fogo' => const Color(0xFF99462D),
  'precisao' => const Color(0xFF665080),
  'elemental' => const Color(0xFF366D85),
  'vitalidade' => const Color(0xFF537345),
  'defesa' => const Color(0xFF786137),
  _ => RpgJournal.ink,
};
