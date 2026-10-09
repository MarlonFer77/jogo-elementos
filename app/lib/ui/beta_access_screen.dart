import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../game_domain/beta_session.dart';
import '../game_presentation/beta_arena_painter.dart';
import '../game_presentation/pixel_content_panel.dart';
import '../game_presentation/pixel_menu_button.dart';
import '../game_presentation/pixel_page_route.dart';
import 'beta_screen.dart';

/// A local tester gate, NOT authentication. No online privileges or saved grant.
class BetaAccessScreen extends StatefulWidget {
  const BetaAccessScreen({super.key});
  @override
  State<BetaAccessScreen> createState() => _BetaAccessScreenState();
}

class _BetaAccessScreenState extends State<BetaAccessScreen> {
  final _password = TextEditingController();
  final _backdrop = BetaSession();
  bool _opening = false;
  String? _error;
  Future<void> _enter() async {
    if (_opening) return;
    if (_password.text != '032431') {
      setState(() => _error = 'Senha incorreta. Confira os 6 dígitos.');
      return;
    }
    setState(() {
      _opening = true;
      _error = null;
    });
    _password.clear();
    FocusScope.of(context).unfocus();
    await Navigator.of(
      context,
    ).push(pixelSlideRoute((_) => const BetaScreen()));
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF243F3D),
    appBar: AppBar(
      title: const Text('BETA TEST'),
      backgroundColor: const Color(0xFF243F3D),
      foregroundColor: const Color(0xFFF1E8C9),
    ),
    body: Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: BetaArenaPainter(_backdrop)),
        const ColoredBox(color: Color(0x55213A36)),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 390),
                child: PixelContentPanel(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'RUÍNA DOS ECOS',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'RPG de ação 3D · protótipo solo\nAcesso reservado aos testadores.',
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _password,
                        enabled: !_opening,
                        obscureText: true,
                        autocorrect: false,
                        enableSuggestions: false,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.go,
                        maxLength: 6,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          labelText: 'Senha do beta',
                          errorText: _error,
                          border: const OutlineInputBorder(),
                          counterText: '',
                        ),
                        onSubmitted: (_) => _enter(),
                      ),
                      const SizedBox(height: 12),
                      PixelMenuButton(
                        label: 'Acessar BETA TEST',
                        primary: true,
                        onPressed: _opening ? null : _enter,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Experimental e offline. O progresso desta sessão não altera seus outros modos.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
