import 'package:flutter/material.dart';

import '../game_presentation/home_title_scene.dart';
import '../game_presentation/pixel_menu_button.dart';
import '../game_presentation/pixel_page_route.dart';
import 'multiplayer_lobby_screen.dart';
import 'training_screen.dart';

/// Menu de entrada; regras, progresso e conexão continuam nas telas de destino.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _opening = false;

  Future<void> _open(WidgetBuilder destination) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      await Navigator.of(context).push(pixelSlideRoute(destination));
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF172D2C),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide =
                constraints.maxWidth >= 560 &&
                constraints.maxWidth > constraints.maxHeight;
            final scene = TickerMode(
              enabled: !_opening && !MediaQuery.disableAnimationsOf(context),
              child: const HomeTitleScene(),
            );
            final menu = _menu(compact: wide && constraints.maxHeight < 500);
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: wide ? 1120 : 460),
                  child: wide
                      ? Row(
                          key: const ValueKey('home-landscape'),
                          children: [
                            Expanded(flex: 6, child: scene),
                            const SizedBox(width: 20),
                            Expanded(flex: 5, child: menu),
                          ],
                        )
                      : Column(
                          key: const ValueKey('home-portrait'),
                          mainAxisSize: MainAxisSize.min,
                          children: [scene, const SizedBox(height: 16), menu],
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _menu({required bool compact}) {
    const ink = Color(0xFF283C36);
    const text = TextStyle(
      fontFamily: 'monospace',
      fontSize: 12,
      height: 1.4,
      color: ink,
    );
    return Container(
      padding: EdgeInsets.all(compact ? 14 : 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF1E8C9),
        border: Border.all(color: const Color(0xFFB6A16D), width: 3),
        boxShadow: const [
          BoxShadow(color: Color(0xFF0E2022), offset: Offset(5, 5)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'ESCOLHA SEU DUELO',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              color: ink,
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: 6),
            const Text('Cada combinação abre um novo caminho.', style: text),
          ],
          SizedBox(height: compact ? 12 : 18),
          Semantics(
            button: true,
            enabled: !_opening,
            child: PixelMenuButton(
              label: 'MODO TREINO',
              primary: true,
              onPressed: _opening
                  ? null
                  : () => _open((_) => const TrainingScreen()),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: 8, bottom: compact ? 12 : 16),
            child: const Text(
              '2 jogadores neste aparelho · Offline',
              style: text,
            ),
          ),
          Semantics(
            button: true,
            enabled: !_opening,
            child: PixelMenuButton(
              label: 'MULTIPLAYER',
              onPressed: _opening
                  ? null
                  : () => _open((_) => const MultiplayerLobbyScreen()),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: 8, bottom: compact ? 0 : 14),
            child: const Text(
              'Desafie um amigo · Requer internet',
              style: text,
            ),
          ),
          if (!compact) ...[
            const Divider(color: Color(0xFFB6A16D), height: 1),
            const SizedBox(height: 12),
            const Text(
              'Descubra combos. Equipe 3 habilidades.\nTrace seu selo e domine a batalha.',
              style: text,
            ),
          ],
        ],
      ),
    );
  }
}
