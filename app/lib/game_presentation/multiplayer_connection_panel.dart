import 'package:flutter/material.dart';

import 'pixel_content_panel.dart';
import 'trainer_sprite_image.dart';

/// Presentation shared by the lobby, real request progress and waiting room.
class MultiplayerConnectionPanel extends StatelessWidget {
  const MultiplayerConnectionPanel({
    super.key,
    required this.title,
    required this.message,
    required this.child,
    this.connecting = false,
  });

  final String title, message;
  final Widget child;
  final bool connecting;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final wide = box.maxWidth >= 600 && box.maxWidth > box.maxHeight;
      final intro = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TickerMode(
            enabled: !MediaQuery.disableAnimationsOf(context),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TrainerSpriteImage(size: Size(48, 60)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Icon(Icons.sync_alt, color: Color(0xFFE1C778)),
                ),
                TrainerSpriteImage(size: Size(48, 60), mirror: true),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: Color(0xFFF4D782),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              color: Color(0xFFF1E8C9),
            ),
          ),
          if (connecting)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: LinearProgressIndicator(
                color: Color(0xFFE1C778),
                backgroundColor: Color(0xFF344C56),
                semanticsLabel: 'Aguardando resposta do servidor',
              ),
            ),
        ],
      );
      final panel = TextButtonTheme(
        data: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: const Color(0xFF283C36)),
        ),
        child: PixelContentPanel(
          child: DefaultTextStyle(
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              height: 1.4,
              color: Color(0xFF283C36),
            ),
            child: child,
          ),
        ),
      );
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: intro,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(flex: 6, child: panel),
                    ],
                  )
                : Column(children: [intro, const SizedBox(height: 20), panel]),
          ),
        ),
      );
    },
  );
}
