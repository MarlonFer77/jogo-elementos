import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../game_domain/account_auth.dart';
import '../game_domain/beta_adventure_store.dart';
import '../game_domain/beta_session.dart';
import '../game_domain/cosmetic_store.dart';
import '../game_domain/cosmetics.dart';
import '../game_presentation/beta_arena_painter.dart';
import '../game_presentation/pixel_content_panel.dart';
import '../game_presentation/pixel_menu_button.dart';
import '../game_presentation/pixel_page_route.dart';
import 'beta_screen.dart';

/// Module gate only: the app supplies the already identified account.
class BetaAccessScreen extends StatefulWidget {
  const BetaAccessScreen({super.key, this.auth});
  final AccountAuth? auth;
  @override
  State<BetaAccessScreen> createState() => _BetaAccessScreenState();
}

class _BetaAccessScreenState extends State<BetaAccessScreen> {
  final _password = TextEditingController();
  final _backdrop = BetaSession();
  late final _backdropPainter = BetaArenaPainter(_backdrop);
  late final _auth = widget.auth ?? AccountAuth();
  BetaAdventureStore? _store;
  BetaCheckpoint? _saved;
  bool _opening = true, _unlocked = false, _dataError = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      if (widget.auth == null) await _auth.restore();
      _store = _auth.hasSession && _auth.emailVerified && _auth.uid != null
          ? BetaAdventureStore(_auth.uid!)
          : null;
      _saved = await _store?.load();
      _dataError = false;
      _error = _store?.recovered == true
          ? 'Aventura recuperada pela cópia de segurança local. Pode haver progresso recente não recuperado.'
          : null;
    } catch (_) {
      _dataError = true;
      _error =
          'Não foi possível ler a conta ou aventura. Dados preservados; tente novamente.';
    }
    if (mounted) setState(() => _opening = false);
  }

  Future<void> _enter({bool fresh = false}) async {
    if (_opening ||
        _dataError ||
        _store == null ||
        !_auth.hasSession ||
        !_auth.emailVerified ||
        _auth.uid != _store!.uid) {
      return;
    }
    if (!_unlocked && _password.text != '032431') {
      setState(() => _error = 'Senha do beta incorreta. Confira os 6 dígitos.');
      return;
    }
    setState(() {
      _opening = true;
      _error = null;
    });
    if (fresh && _saved != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Começar nova aventura?'),
          content: const Text(
            'Substitui o checkpoint desta conta neste aparelho. Nível, habilidades, combos e puzzles recomeçam. As compras da loja permanecem.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Nova aventura'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (confirmed != true) {
        setState(() => _opening = false);
        return;
      }
    }
    _unlocked = true;
    _password.clear();
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    var inventory = CosmeticInventory();
    try {
      inventory = await CosmeticStore().load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Inventário indisponível: equipamento original. Compras preservadas.',
            ),
          ),
        );
      }
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      pixelSlideRoute(
        (_) => BetaScreen(
          outfit: inventory.equipped,
          loadout: inventory.loadout,
          checkpoint: fresh ? null : _saved,
          adventureStore: _store,
        ),
      ),
    );
    if (mounted) await _load();
  }

  @override
  void dispose() {
    _password.dispose();
    _backdropPainter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_opening,
    child: Scaffold(
      backgroundColor: const Color(0xFF243F3D),
      appBar: AppBar(
        title: const Text('BETA TEST'),
        backgroundColor: const Color(0xFF243F3D),
        foregroundColor: const Color(0xFFF1E8C9),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _backdropPainter),
          const ColoredBox(color: Color(0x55213A36)),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
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
                          'Seis regiões. Enigmas elementais. Um mundo para restaurar.',
                        ),
                        if (_opening) const LinearProgressIndicator(),
                        const SizedBox(height: 12),
                        if (_store == null) ...[
                          const Text(
                            'Entre na conta do Elementos pela entrada do aplicativo. O BETA é apenas um dos modos e usa a mesma conta.',
                          ),
                          PixelMenuButton(
                            label: 'Voltar ao menu',
                            primary: true,
                            onPressed: _opening
                                ? null
                                : () => Navigator.of(context).maybePop(),
                          ),
                        ] else ...[
                          const Text(
                            'Usando sua conta do Elementos.',
                            style: TextStyle(fontSize: 12),
                          ),
                          if (!_unlocked)
                            TextField(
                              controller: _password,
                              enabled: !_opening,
                              obscureText: true,
                              autocorrect: false,
                              enableSuggestions: false,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Senha do beta',
                                border: OutlineInputBorder(),
                                counterText: '',
                              ),
                              onSubmitted: (_) => _enter(),
                            ),
                          const SizedBox(height: 10),
                          if (_saved != null)
                            Text(
                              '${_saved!.region.title} · Nível ${_saved!.level}\n${_saved!.completed
                                  ? 'Expedição concluída'
                                  : _saved!.cleared
                                  ? 'Combate concluído · explore os selos'
                                  : 'Checkpoint: início do combate'}',
                            ),
                          PixelMenuButton(
                            label: _saved == null
                                ? 'Iniciar aventura'
                                : _saved!.completed
                                ? 'Ver aventura concluída'
                                : 'Continuar aventura',
                            primary: true,
                            onPressed: _opening || _dataError ? null : _enter,
                          ),
                          if (_saved != null)
                            TextButton(
                              onPressed: _opening || _dataError
                                  ? null
                                  : () => _enter(fresh: true),
                              child: const Text('Nova aventura'),
                            ),
                          const Text(
                            'Save automático por checkpoint. Fechar durante a luta retoma o início dela. Salvo apenas neste aparelho, sem backup online.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                        if (_error != null)
                          Text(
                            _error!,
                            style: const TextStyle(color: Color(0xFF9B302E)),
                          ),
                        if (_dataError)
                          TextButton(
                            onPressed: _opening
                                ? null
                                : () {
                                    setState(() => _opening = true);
                                    unawaited(_load());
                                  },
                            child: const Text('Tentar carregar novamente'),
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
    ),
  );
}
