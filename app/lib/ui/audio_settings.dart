import 'package:flutter/material.dart';

import '../game_presentation/sfx_player.dart';
import '../settings/game_settings.dart';

/// A direct toggle: no modal or pause during an online turn.
class MuteButton extends StatelessWidget {
  const MuteButton({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: gameSettings,
    builder: (context, _) => IconButton(
      tooltip: gameSettings.effectiveVolume == 0
          ? 'Ativar som'
          : 'Silenciar som',
      icon: Icon(
        gameSettings.effectiveVolume == 0 ? Icons.volume_off : Icons.volume_up,
      ),
      onPressed: () async {
        final silent = gameSettings.effectiveVolume == 0;
        if (silent && gameSettings.volume == 0) {
          await gameSettings.setVolume(.5);
        }
        await gameSettings.setMuted(!silent);
        if (context.mounted && gameSettings.saveFailed) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Som alterado, mas não foi possível salvar no aparelho.',
              ),
            ),
          );
        }
      },
    ),
  );
}

class AudioSettingsScreen extends StatelessWidget {
  const AudioSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF1E8C9),
    appBar: AppBar(
      title: const Text('SOM'),
      backgroundColor: const Color(0xFFF1E8C9),
    ),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListenableBuilder(
              listenable: gameSettings,
              builder: (context, _) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'EFEITOS SONOROS',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const Text(
                    'Menus, ataques e selos. Vale para todos os modos neste aparelho.',
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Mudo'),
                    value: gameSettings.muted,
                    onChanged: gameSettings.setMuted,
                  ),
                  Text('Volume · ${(gameSettings.volume * 100).round()}%'),
                  Slider(
                    value: gameSettings.volume,
                    divisions: 10,
                    label: '${(gameSettings.volume * 100).round()}%',
                    semanticFormatterCallback: (value) =>
                        '${(value * 100).round()} por cento',
                    onChanged: gameSettings.setVolume,
                  ),
                  if (gameSettings.effectiveVolume == 0)
                    const Text(
                      'Som desligado. Desative o mudo e aumente o volume para ouvir.',
                    ),
                  OutlinedButton.icon(
                    onPressed: gameSettings.effectiveVolume == 0
                        ? null
                        : () => sfxPlayer.play(SfxId.cast),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Ouvir exemplo'),
                  ),
                  Text(
                    gameSettings.saveFailed
                        ? 'Não foi possível salvar. Altere novamente para tentar; o ajuste atual continua ativo.'
                        : 'Preferências salvas automaticamente, sem alterar seu progresso.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
