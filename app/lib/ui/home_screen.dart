import 'package:flutter/material.dart';

import '../game_domain/element_catalog.dart';
import 'battle_screen.dart';
import 'multiplayer_lobby_screen.dart';
import 'training_screen.dart';

/// Placeholder screen: lists the built-in elements to prove the app is
/// wired to the Battle Engine through the Game Domain layer. Real screens
/// (menu, skill tree...) come in later tasks.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final elements = const ElementCatalog().all();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Elementos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sports_kabaddi),
            tooltip: 'Batalha (demo)',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BattleScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.school),
            tooltip: 'Modo Treino',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TrainingScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.people),
            tooltip: 'Multiplayer',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MultiplayerLobbyScreen()),
              );
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: elements.length,
        itemBuilder: (context, index) {
          final element = elements[index];
          return ListTile(
            leading: Text(
              element.symbol,
              style: const TextStyle(fontSize: 24),
            ),
            title: Text(element.name),
          );
        },
      ),
    );
  }
}
