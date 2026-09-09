import 'package:flutter/material.dart';

import '../game_presentation/pixel_arena_background.dart';
import '../game_presentation/pixel_menu_button.dart';
import '../game_presentation/trainer_sprite_image.dart';
import 'multiplayer_lobby_screen.dart';
import 'training_screen.dart';

/// Tela inicial de verdade: título + os dois personagens da batalha de
/// frente + botões pro Treino/Multiplayer, sobre o mesmo fundo pixelado
/// da arena de batalha. Ver
/// docs/superpowers/specs/2026-09-09-home-title-screen-design.md.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _BackdropPainter()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _title(),
                    const SizedBox(height: 8),
                    const Text(
                      'BATALHAS 1V1 POR COMBINAÇÃO',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        color: Color(0xFF2B2B2B),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TrainerSpriteImage(),
                        SizedBox(width: 12),
                        Text(
                          'VS',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: Color(0xFFF4C94A),
                          ),
                        ),
                        SizedBox(width: 12),
                        TrainerSpriteImage(mirror: true),
                      ],
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: 280,
                      child: PixelMenuButton(
                        label: 'MODO TREINO',
                        primary: true,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const TrainingScreen()),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: 280,
                      child: PixelMenuButton(
                        label: 'MULTIPLAYER',
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const MultiplayerLobbyScreen()),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _title() {
    const shadowColor = Color(0xFF2B2B2B);
    return Text(
      'ELEMENTOS',
      style: TextStyle(
        fontFamily: 'monospace',
        fontWeight: FontWeight.bold,
        fontSize: 40,
        letterSpacing: 4,
        color: const Color(0xFFF4F4E4),
        shadows: [
          for (final dx in [-2.0, 2.0])
            for (final dy in [-2.0, 2.0]) Shadow(offset: Offset(dx, dy), color: shadowColor),
          const Shadow(offset: Offset(3, 3), color: shadowColor),
        ],
      ),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) => drawArenaBackdrop(canvas, size);

  @override
  bool shouldRepaint(covariant _BackdropPainter oldDelegate) => false;
}
