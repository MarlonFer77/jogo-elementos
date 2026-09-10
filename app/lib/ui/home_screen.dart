import 'package:flutter/material.dart';

import '../game_presentation/pixel_arena_background.dart';
import '../game_presentation/pixel_menu_button.dart';
import '../game_presentation/pixel_outlined_text.dart';
import '../game_presentation/pixel_page_route.dart';
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
          CustomPaint(painter: ArenaBackdropPainter()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const PixelOutlinedText('ELEMENTOS'),
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
                            pixelSlideRoute((_) => const TrainingScreen()),
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
                            pixelSlideRoute((_) => const MultiplayerLobbyScreen()),
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
}
