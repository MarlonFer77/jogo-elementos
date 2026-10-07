import 'dart:io' show Platform;
import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../game_domain/update_checker.dart';
import '../game_presentation/pixel_arena_background.dart';
import '../game_presentation/pixel_menu_button.dart';
import '../game_presentation/pixel_outlined_text.dart';
import 'home_screen.dart';

enum _GateState { checking, upToDate, updateRequired, failed }

enum _DownloadState { idle, downloading, installing, error }

/// Tela raiz do app (`main.dart`'s `home:`) — checa se existe uma versão
/// nova antes de mostrar a Home. Falhas oferecem nova tentativa sem afirmar
/// que a versão está atualizada. Só roda automaticamente em Android; Web/Windows
/// (só desenvolvimento, nunca distribuídos) pulam direto pra Home. O
/// download da atualização acontece dentro do próprio app (pacote
/// `ota_update`), com barra de progresso, terminando em abrir o
/// instalador nativo do Android. Ver
/// docs/superpowers/specs/2026-09-10-in-app-update-download-design.md.
class UpdateGateScreen extends StatefulWidget {
  const UpdateGateScreen({
    super.key,
    this.manual = false,
    UpdateChecker? updateChecker,
    String? currentVersion,
    bool? isAndroid,
    Stream<OtaEvent> Function(String url)? startDownload,
  }) : _updateChecker = updateChecker,
       _currentVersion = currentVersion,
       _isAndroid = isAndroid,
       _startDownload = startDownload;

  final UpdateChecker? _updateChecker;
  final bool manual;
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
  String? _checksum, _checkError, _installedVersion;
  StreamSubscription<OtaEvent>? _subscription;
  int _downloadGeneration = 0;

  _DownloadState _downloadState = _DownloadState.idle;
  double _downloadProgress = 0;
  String? _downloadErrorMessage;

  bool get _runningOnAndroid =>
      widget._isAndroid ?? (!kIsWeb && Platform.isAndroid);

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() => _state = _GateState.checking);
    await Future<void>.delayed(Duration.zero);

    if (!_runningOnAndroid && !widget.manual) {
      if (mounted) setState(() => _state = _GateState.upToDate);
      return;
    }

    try {
      final currentVersion =
          widget._currentVersion ?? (await PackageInfo.fromPlatform()).version;
      _installedVersion = currentVersion;
      final checker = widget._updateChecker ?? UpdateChecker();
      final result = await checker.checkForUpdate(
        currentVersion: currentVersion,
      );

      if (!mounted) return;
      setState(() {
        if (result.error != null) {
          _state = _GateState.failed;
          _checkError = result.error;
        } else if (result.updateAvailable) {
          _state = _GateState.updateRequired;
          _latestVersion = result.latestVersion;
          _downloadUrl = result.downloadUrl;
          _checksum = result.checksum;
        } else {
          _state = _GateState.upToDate;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _state = _GateState.failed;
          _checkError =
              'Não foi possível identificar ou consultar a versão. Tente novamente.';
        });
      }
    }
  }

  Future<void> _startDownload() async {
    final url = _downloadUrl;
    if (url == null || _downloadState == _DownloadState.downloading) return;
    if (!_runningOnAndroid) {
      _handleError(
        'A instalação automática está disponível somente no Android.',
      );
      return;
    }
    final generation = ++_downloadGeneration;
    setState(() {
      _downloadState = _DownloadState.downloading;
      _downloadProgress = 0;
      _downloadErrorMessage = null;
    });
    try {
      await _subscription?.cancel();
      if (!mounted || generation != _downloadGeneration) return;
      final stream =
          widget._startDownload?.call(url) ??
          OtaUpdate().execute(
            url,
            destinationFilename: 'app-release.apk',
            sha256checksum: _checksum,
          );
      _subscription = stream.listen(
        (event) {
          if (generation == _downloadGeneration) _handleOtaEvent(event);
        },
        onError: (Object _) {
          if (generation == _downloadGeneration) {
            _handleError('Falha ao baixar a atualização.');
          }
        },
        onDone: () {
          if (generation == _downloadGeneration) {
            _subscription = null;
            if (_downloadState == _DownloadState.downloading) {
              _handleError('Download interrompido. Tente novamente.');
            }
          }
        },
      );
    } catch (_) {
      _handleError('Não foi possível iniciar o instalador. Tente novamente.');
    }
  }

  @override
  void dispose() {
    _downloadGeneration++;
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  void _handleOtaEvent(OtaEvent event) {
    if (!mounted || _downloadState == _DownloadState.error) return;
    switch (event.status) {
      case OtaStatus.DOWNLOADING:
        final progress = double.tryParse(event.value ?? '');
        if (!mounted) return;
        setState(() {
          _downloadState = _DownloadState.downloading;
          if (progress != null && progress.isFinite) {
            _downloadProgress = progress.clamp(0, 100);
          }
        });
      case OtaStatus.INSTALLING:
      case OtaStatus.INSTALLATION_DONE:
        if (!mounted) return;
        setState(() => _downloadState = _DownloadState.installing);
      case OtaStatus.ALREADY_RUNNING_ERROR:
        _handleError(
          'Já existe uma atualização em andamento. Aguarde e tente novamente.',
        );
      case OtaStatus.INSTALLATION_ERROR:
        _handleError(
          'Instalação não concluída. Confira o espaço e a assinatura. Não desinstale o jogo.',
        );
      case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
        _handleError(
          'Autorize a instalação de atualizações deste app nas configurações do Android e tente novamente.',
        );
      case OtaStatus.INTERNAL_ERROR:
      case OtaStatus.DOWNLOAD_ERROR:
        _handleError('Falha ao baixar a atualização.');
      case OtaStatus.CHECKSUM_ERROR:
        _handleError(
          'O APK não passou na verificação de integridade. Baixe novamente.',
        );
      case OtaStatus.CANCELED:
        _handleError(
          'Instalação ou download cancelado. Você pode tentar novamente.',
        );
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
    if (_state == _GateState.upToDate && !widget.manual) {
      return const HomeScreen();
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: ArenaBackdropPainter()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
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
                        : _state == _GateState.failed
                        ? [
                            const PixelOutlinedText(
                              'Atualização não verificada',
                              fontSize: 22,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _checkError ?? 'Falha na consulta.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            PixelMenuButton(
                              label: 'Verificar novamente',
                              onPressed: _check,
                            ),
                            TextButton(
                              onPressed: () {
                                if (widget.manual) {
                                  Navigator.of(context).pop();
                                } else {
                                  setState(() => _state = _GateState.upToDate);
                                }
                              },
                              child: Text(
                                widget.manual
                                    ? 'Voltar'
                                    : 'Continuar sem verificar',
                              ),
                            ),
                          ]
                        : _state == _GateState.upToDate
                        ? [
                            const PixelOutlinedText(
                              'Você está atualizado',
                              fontSize: 24,
                            ),
                            const SizedBox(height: 16),
                            Text('Versão instalada: $_installedVersion'),
                            PixelMenuButton(
                              label: 'Voltar',
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ]
                        : [
                            const PixelOutlinedText(
                              'Atualização necessária',
                              fontSize: 24,
                            ),
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
                            const SizedBox(height: 12),
                            const Text(
                              'Atualize sem desinstalar para preservar seu progresso.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                  ),
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
            style: const TextStyle(
              fontFamily: 'monospace',
              color: Color(0xFF2B2B2B),
            ),
          ),
        ];
      case _DownloadState.installing:
        return [
          const Text(
            'Abrindo instalador...',
            style: TextStyle(fontFamily: 'monospace', color: Color(0xFF2B2B2B)),
          ),
          const SizedBox(height: 12),
          PixelMenuButton(label: 'Verificar instalação', onPressed: _check),
          TextButton(
            onPressed: _startDownload,
            child: const Text('Reabrir instalador'),
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
