import 'package:flutter/material.dart';

import 'ui/update_gate_screen.dart';
import 'settings/game_settings.dart';
import 'game_presentation/sfx_player.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await gameSettings.load();
  void updateAudio() => sfxPlayer.volume = gameSettings.effectiveVolume;
  updateAudio();
  gameSettings.addListener(updateAudio);
  runApp(const GameApp());
}

class GameApp extends StatelessWidget {
  const GameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Elementos',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: const UpdateGateScreen(),
    );
  }
}
