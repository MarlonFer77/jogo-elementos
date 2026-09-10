import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

import '../game_domain/update_checker.dart';
import '../game_presentation/pixel_arena_background.dart';
import '../game_presentation/pixel_menu_button.dart';
import '../game_presentation/pixel_outlined_text.dart';
import 'home_screen.dart';

enum _GateState { checking, upToDate, updateRequired }

/// Tela raiz do app (`main.dart`'s `home:`) — checa se existe uma versão
/// nova antes de mostrar a Home, e bloqueia o jogo inteiro se estiver
/// desatualizado. Só roda a checagem de verdade em Android; Web/Windows
/// (só desenvolvimento, nunca distribuídos) pulam direto pra Home. Ver
/// docs/superpowers/specs/2026-09-10-mandatory-update-check-design.md.
class UpdateGateScreen extends StatefulWidget {
  const UpdateGateScreen({
    super.key,
    UpdateChecker? updateChecker,
    String? currentVersion,
    bool? isAndroid,
    Future<void> Function(Uri uri)? launchUrl,
  })  : _updateChecker = updateChecker,
        _currentVersion = currentVersion,
        _isAndroid = isAndroid,
        _launchUrl = launchUrl;

  final UpdateChecker? _updateChecker;
  final String? _currentVersion;
  final bool? _isAndroid;
  final Future<void> Function(Uri uri)? _launchUrl;

  @override
  State<UpdateGateScreen> createState() => _UpdateGateScreenState();
}

class _UpdateGateScreenState extends State<UpdateGateScreen> {
  _GateState _state = _GateState.checking;
  String? _latestVersion;
  String? _downloadUrl;

  bool get _runningOnAndroid => widget._isAndroid ?? (!kIsWeb && Platform.isAndroid);

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    await Future<void>.delayed(Duration.zero);

    if (!_runningOnAndroid) {
      if (mounted) setState(() => _state = _GateState.upToDate);
      return;
    }

    final currentVersion =
        widget._currentVersion ?? (await PackageInfo.fromPlatform()).version;
    final checker = widget._updateChecker ?? UpdateChecker();
    final result = await checker.checkForUpdate(currentVersion: currentVersion);

    if (!mounted) return;
    setState(() {
      if (result.updateAvailable) {
        _state = _GateState.updateRequired;
        _latestVersion = result.latestVersion;
        _downloadUrl = result.downloadUrl;
      } else {
        _state = _GateState.upToDate;
      }
    });
  }

  Future<void> _openDownload() async {
    final url = _downloadUrl;
    if (url == null) return;
    final launch = widget._launchUrl ??
        (uri) => url_launcher.launchUrl(uri, mode: url_launcher.LaunchMode.externalApplication);
    await launch(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    if (_state == _GateState.upToDate) {
      return const HomeScreen();
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: ArenaBackdropPainter()),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _state == _GateState.checking
                      ? const [
                          PixelOutlinedText('ELEMENTOS'),
                          SizedBox(height: 24),
                          Text(
                            'Verificando atualizações...',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: Color(0xFF2B2B2B),
                            ),
                          ),
                        ]
                      : [
                          const PixelOutlinedText('Atualização necessária', fontSize: 24),
                          const SizedBox(height: 16),
                          Text(
                            'Uma versão nova (v$_latestVersion) está disponível. '
                            'Atualize pra continuar jogando.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              color: Color(0xFF2B2B2B),
                            ),
                          ),
                          const SizedBox(height: 24),
                          PixelMenuButton(
                            label: 'Baixar atualização',
                            primary: true,
                            onPressed: _openDownload,
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
