import 'package:flutter/material.dart';

import '../game_presentation/home_title_scene.dart';
import '../game_presentation/pixel_menu_button.dart';
import '../game_presentation/pixel_page_route.dart';
import 'multiplayer_login_screen.dart';
import 'training_screen.dart';
import 'dungeon_screen.dart';
import 'audio_settings.dart';
import 'quick_tutorial_screen.dart';
import 'update_gate_screen.dart';
import '../settings/game_settings.dart';

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
              child: SizedBox(
                height: (constraints.maxHeight * (wide ? .8 : .34)).clamp(
                  110.0,
                  330.0,
                ),
                child: const HomeTitleScene(),
              ),
            );
            final menu = _menu(compact: constraints.maxHeight < 740);
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(10),
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
          if (!compact)
            const Text(
              'ESCOLHA SUA JORNADA',
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
          ListenableBuilder(
            listenable: gameSettings,
            builder: (context, _) => Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: ink),
                    icon: const Icon(Icons.help_outline),
                    label: Text(
                      gameSettings.tutorialSeen ? 'Como jogar' : 'Comece aqui',
                    ),
                    onPressed: _opening
                        ? null
                        : () => _open((_) => const QuickTutorialScreen()),
                  ),
                ),
                IconButton(
                  tooltip: 'Configurações de som',
                  color: ink,
                  icon: Icon(
                    gameSettings.effectiveVolume == 0
                        ? Icons.volume_off
                        : Icons.volume_up,
                  ),
                  onPressed: _opening
                      ? null
                      : () => _open((_) => const AudioSettingsScreen()),
                ),
                IconButton(
                  tooltip: 'Verificar atualizações',
                  color: ink,
                  icon: const Icon(Icons.system_update),
                  onPressed: _opening
                      ? null
                      : () =>
                            _open((_) => const UpdateGateScreen(manual: true)),
                ),
              ],
            ),
          ),
          SizedBox(height: compact ? 12 : 18),
          PixelMenuButton(
            label: 'DUNGEON · SOLO',
            primary: true,
            onPressed: _opening
                ? null
                : () => _open((_) => const DungeonScreen()),
          ),
          if (!compact)
            const Padding(
              padding: EdgeInsets.only(top: 6, bottom: 8),
              child: Text(
                'Explore ruínas · Ganhe XP e habilidades',
                style: text,
              ),
            ),
          const SizedBox(height: 8),
          Semantics(
            button: true,
            enabled: !_opening,
            child: PixelMenuButton(
              label: 'MODO TREINO',
              primary: false,
              onPressed: _opening
                  ? null
                  : () => _open((_) => const TrainingScreen()),
            ),
          ),
          if (!compact)
            Padding(
              padding: EdgeInsets.only(top: 8, bottom: compact ? 12 : 16),
              child: const Text(
                '2 jogadores neste aparelho · Offline',
                style: text,
              ),
            ),
          if (compact) const SizedBox(height: 8),
          Semantics(
            button: true,
            enabled: !_opening,
            child: PixelMenuButton(
              label: 'MULTIPLAYER',
              onPressed: _opening
                  ? null
                  : () => _open((_) => const MultiplayerLoginScreen()),
            ),
          ),
          if (!compact)
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
