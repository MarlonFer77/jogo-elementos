import 'dart:io' show Platform;
import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../game_domain/update_checker.dart';
import '../game_presentation/pixel_menu_button.dart';
import '../game_presentation/update_frame.dart';
import 'home_screen.dart';
import 'loading_battle_scene.dart';

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
  bool _introComplete = false;
  String? _latestVersion;
  String? _downloadUrl;
  String? _checksum, _checkError, _installedVersion;
  StreamSubscription<OtaEvent>? _subscription;
  int _downloadGeneration = 0;
  int _checkGeneration = 0;

  _DownloadState _downloadState = _DownloadState.idle;
  double _downloadProgress = 0;
  bool _hasProgress = false;
  String? _downloadErrorMessage;

  bool get _runningOnAndroid =>
      widget._isAndroid ?? (!kIsWeb && Platform.isAndroid);

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final generation = ++_checkGeneration;
    _downloadGeneration++;
    unawaited(_subscription?.cancel());
    _subscription = null;
    setState(() {
      _state = _GateState.checking;
      _downloadState = _DownloadState.idle;
      _latestVersion = _downloadUrl = _checksum = _checkError = null;
      _downloadErrorMessage = null;
    });
    await Future<void>.delayed(Duration.zero);
    if (!mounted || generation != _checkGeneration) return;

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

      if (!mounted || generation != _checkGeneration) return;
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
      if (mounted && generation == _checkGeneration) {
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
      _hasProgress = false;
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
    _checkGeneration++;
    _downloadGeneration++;
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  void _handleOtaEvent(OtaEvent event) {
    if (!mounted || _downloadState == _DownloadState.error) return;
    switch (event.status) {
      case OtaStatus.DOWNLOADING:
        if (_downloadState == _DownloadState.installing) return;
        final progress = double.tryParse(event.value ?? '');
        if (!mounted) return;
        setState(() {
          _downloadState = _DownloadState.downloading;
          if (progress != null && progress.isFinite) {
            _downloadProgress = progress.clamp(0, 100);
            _hasProgress = true;
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
    if (!widget.manual &&
        (_state == _GateState.checking ||
            (_state == _GateState.upToDate && !_introComplete))) {
      return LoadingBattleScene(
        ready: _state == _GateState.upToDate,
        onPresented: () {
          if (mounted && !_introComplete) setState(() => _introComplete = true);
        },
        onEnter: () {
          if (_state == _GateState.upToDate) {
            setState(() => _introComplete = true);
          }
        },
      );
    }
    if (_state == _GateState.upToDate && !widget.manual) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(
          milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 240,
        ),
        builder: (_, opacity, child) => ColoredBox(
          color: const Color(0xFF142B2C),
          child: Opacity(opacity: opacity, child: child),
        ),
        child: const HomeScreen(),
      );
    }

    final downloading = _downloadState == _DownloadState.downloading;
    final installing = _downloadState == _DownloadState.installing;
    final error =
        _state == _GateState.failed || _downloadState == _DownloadState.error;
    return UpdateFrame(
      title: switch (_state) {
        _GateState.checking => 'Preparando sua jornada',
        _GateState.failed => 'Atualização não verificada',
        _GateState.upToDate => 'Você está atualizado',
        _GateState.updateRequired =>
          error
              ? 'O download precisa de atenção'
              : installing
              ? 'Confirme no Android'
              : downloading
              ? 'Recebendo atualização'
              : 'Atualização necessária',
      },
      icon: error
          ? Icons.error_outline
          : installing
          ? Icons.install_mobile
          : downloading
          ? Icons.downloading
          : _state == _GateState.upToDate
          ? Icons.verified_outlined
          : Icons.system_update,
      step: _state == _GateState.upToDate
          ? -1
          : _state == _GateState.updateRequired
          ? (installing ? 2 : 1)
          : 0,
      warning: error,
      installedVersion: _installedVersion,
      latestVersion: _latestVersion,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_state == _GateState.checking) ...[
            const Text('Verificando atualizações...'),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: MediaQuery.disableAnimationsOf(context) ? 0 : null,
            ),
            const SizedBox(height: 12),
            const Text(
              'Consultando a versão publicada do jogo.',
              style: TextStyle(fontSize: 12),
            ),
          ] else if (_state == _GateState.failed) ...[
            Text(_checkError ?? 'Falha na consulta.'),
            const SizedBox(height: 10),
            const Text(
              'Sem confirmação da versão mais recente. Você pode tentar novamente.',
              style: TextStyle(fontSize: 12),
            ),
          ] else if (_state == _GateState.upToDate)
            const Text('Tudo pronto. Sua próxima aventura espera por você.')
          else ...[
            if (_downloadState == _DownloadState.idle)
              const Text(
                'Uma nova versão está disponível. Atualize para continuar sua jornada.',
              ),
            if (downloading || installing || error) ..._buildDownloadStatus(),
            if (_checksum != null && !installing && !error) ...[
              const SizedBox(height: 12),
              const Text(
                'Origem: GitHub Releases · Verificação SHA-256 no download.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ],
        ],
      ),
      actions: switch (_state) {
        _GateState.checking => const [],
        _GateState.failed => [
          PixelMenuButton(
            label: 'Verificar novamente',
            onPressed: _check,
            primary: true,
          ),
          TextButton(
            onPressed: () {
              if (widget.manual) {
                Navigator.of(context).pop();
              } else {
                setState(() {
                  _introComplete = true;
                  _state = _GateState.upToDate;
                });
              }
            },
            child: Text(widget.manual ? 'Voltar' : 'Continuar sem verificar'),
          ),
        ],
        _GateState.upToDate => [
          PixelMenuButton(
            label: 'Voltar',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
        _GateState.updateRequired => _buildDownloadActions(),
      },
    );
  }

  List<Widget> _buildDownloadActions() => switch (_downloadState) {
    _DownloadState.idle => [
      PixelMenuButton(
        label: 'Baixar atualização',
        primary: true,
        onPressed: _startDownload,
      ),
    ],
    _DownloadState.downloading => const [],
    _DownloadState.installing => [
      PixelMenuButton(label: 'Verificar instalação', onPressed: _check),
      TextButton(
        onPressed: _startDownload,
        child: const Text('Baixar novamente'),
      ),
    ],
    _DownloadState.error => [
      PixelMenuButton(
        label: 'Tentar de novo',
        primary: true,
        onPressed: _startDownload,
      ),
    ],
  };

  List<Widget> _buildDownloadStatus() {
    switch (_downloadState) {
      case _DownloadState.idle:
        return [];
      case _DownloadState.downloading:
        final progress = (_downloadProgress / 100).clamp(0.0, 1.0);
        return [
          LinearProgressIndicator(
            minHeight: 12,
            value: _hasProgress
                ? progress
                : MediaQuery.disableAnimationsOf(context)
                ? 0
                : null,
            semanticsLabel: 'Progresso do download',
            color: const Color(0xFF517D69),
            backgroundColor: const Color(0xFFD8CCAA),
          ),
          const SizedBox(height: 8),
          Text(
            _hasProgress
                ? 'Baixando... ${_downloadProgress.round()}%'
                : 'Conectando ao download...',
            style: const TextStyle(
              fontFamily: 'monospace',
              color: Color(0xFF2B2B2B),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Mantenha o jogo aberto. Ao terminar, confirme a instalação no Android.',
            style: TextStyle(fontSize: 12),
          ),
        ];
      case _DownloadState.installing:
        return [
          const Text(
            'Abrindo instalador...',
            style: TextStyle(fontFamily: 'monospace', color: Color(0xFF2B2B2B)),
          ),
          const SizedBox(height: 12),
          const Text(
            'Confirme a atualização na janela do Android. Se voltar sem instalar, você pode verificar ou baixar novamente.',
            style: TextStyle(fontSize: 12),
          ),
        ];
      case _DownloadState.error:
        return [
          Text(
            _downloadErrorMessage ?? 'Falha ao baixar a atualização.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF8B422E)),
          ),
        ];
    }
  }
}
