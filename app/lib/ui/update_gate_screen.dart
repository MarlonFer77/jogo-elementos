import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../game_domain/update_checker.dart';
import '../game_presentation/pixel_arena_background.dart';
import '../game_presentation/pixel_menu_button.dart';
import '../game_presentation/pixel_outlined_text.dart';
import 'home_screen.dart';

enum _GateState { checking, upToDate, updateRequired }

enum _DownloadState { idle, downloading, installing, error }

/// Tela raiz do app (`main.dart`'s `home:`) — checa se existe uma versão
/// nova antes de mostrar a Home, e bloqueia o jogo inteiro se estiver
/// desatualizado. Só roda a checagem de verdade em Android; Web/Windows
/// (só desenvolvimento, nunca distribuídos) pulam direto pra Home. O
/// download da atualização acontece dentro do próprio app (pacote
/// `ota_update`), com barra de progresso, terminando em abrir o
/// instalador nativo do Android. Ver
/// docs/superpowers/specs/2026-09-10-in-app-update-download-design.md.
class UpdateGateScreen extends StatefulWidget {
  const UpdateGateScreen({
    super.key,
    UpdateChecker? updateChecker,
    String? currentVersion,
    bool? isAndroid,
    Stream<OtaEvent> Function(String url)? startDownload,
  })  : _updateChecker = updateChecker,
        _currentVersion = currentVersion,
        _isAndroid = isAndroid,
        _startDownload = startDownload;

  final UpdateChecker? _updateChecker;
  final String? _currentVersion;
  final bool? _isAndroid;
  final Stream<OtaEvent> Function(String url)? _startDownload;

  @override
  State<UpdateGateScreen> createState() => _UpdateGateScreenState();
}

class _UpdateGateScreenState extends State<UpdateGateScreen> {
  _GateState _state = _GateState.checking;
  String? _latestVersion;
  String? _downloadUrl;

  _DownloadState _downloadState = _DownloadState.idle;
  double _downloadProgress = 0;
  String? _downloadErrorMessage;

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

  void _startDownload() {
    final url = _downloadUrl;
    if (url == null) return;
    setState(() {
      _downloadState = _DownloadState.downloading;
      _downloadProgress = 0;
      _downloadErrorMessage = null;
    });
    final stream = widget._startDownload?.call(url) ??
        OtaUpdate().execute(url, destinationFilename: 'app-release.apk');
    stream.listen(
      _handleOtaEvent,
      onError: (Object _) => _handleError('Falha ao baixar a atualização.'),
    );
  }

  void _handleOtaEvent(OtaEvent event) {
    switch (event.status) {
      case OtaStatus.DOWNLOADING:
        final progress = double.tryParse(event.value ?? '');
        if (!mounted) return;
        setState(() {
          _downloadState = _DownloadState.downloading;
          if (progress != null) _downloadProgress = progress;
        });
      case OtaStatus.INSTALLING:
      case OtaStatus.INSTALLATION_DONE:
        if (!mounted) return;
        setState(() => _downloadState = _DownloadState.installing);
      case OtaStatus.ALREADY_RUNNING_ERROR:
      case OtaStatus.INSTALLATION_ERROR:
      case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
      case OtaStatus.INTERNAL_ERROR:
      case OtaStatus.DOWNLOAD_ERROR:
      case OtaStatus.CHECKSUM_ERROR:
      case OtaStatus.CANCELED:
        _handleError('Falha ao baixar a atualização.');
    }
  }

  void _handleError(String message) {
    if (!mounted) return;
    setState(() {
      _downloadState = _DownloadState.error;
      _downloadErrorMessage = message;
    });
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
                          ..._buildDownloadSection(),
                        ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDownloadSection() {
    switch (_downloadState) {
      case _DownloadState.idle:
        return [
          PixelMenuButton(
            label: 'Baixar atualização',
            primary: true,
            onPressed: _startDownload,
          ),
        ];
      case _DownloadState.downloading:
        final progress = (_downloadProgress / 100).clamp(0.0, 1.0);
        return [
          Container(
            width: 240,
            height: 20,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF2B2B2B), width: 3),
              color: const Color(0xFFF4F4E4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: Container(color: const Color(0xFFF4C94A)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Baixando... ${_downloadProgress.round()}%',
            style: const TextStyle(fontFamily: 'monospace', color: Color(0xFF2B2B2B)),
          ),
        ];
      case _DownloadState.installing:
        return [
          const Text(
            'Abrindo instalador...',
            style: TextStyle(fontFamily: 'monospace', color: Color(0xFF2B2B2B)),
          ),
        ];
      case _DownloadState.error:
        return [
          Text(
            _downloadErrorMessage ?? 'Falha ao baixar a atualização.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'monospace', color: Colors.red),
          ),
          const SizedBox(height: 16),
          PixelMenuButton(
            label: 'Tentar de novo',
            primary: true,
            onPressed: _startDownload,
          ),
        ];
    }
  }
}
