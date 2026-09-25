import 'dart:async';
import 'package:flutter/material.dart';

import '../game_domain/multiplayer_client.dart';
import '../game_domain/multiplayer_config.dart';
import '../game_domain/multiplayer_exception.dart';
import '../game_domain/multiplayer_match.dart';
import '../game_presentation/multiplayer_connection_panel.dart';
import '../game_presentation/pixel_menu_button.dart';
import '../game_presentation/pixel_page_route.dart';
import '../game_presentation/pixel_text_field.dart';
import 'multiplayer_battle_screen.dart';

enum _LobbyAction { create, join, reconnect }

/// Identity still uses the existing installation credential and player name.
class MultiplayerLobbyScreen extends StatefulWidget {
  const MultiplayerLobbyScreen({super.key, MultiplayerClient? client})
    : _client = client;
  final MultiplayerClient? _client;
  @override
  State<MultiplayerLobbyScreen> createState() => _MultiplayerLobbyScreenState();
}

class _MultiplayerLobbyScreenState extends State<MultiplayerLobbyScreen> {
  late final MultiplayerClient _client =
      widget._client ?? MultiplayerClient(baseUrl: defaultMultiplayerBaseUrl);
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  _LobbyAction _selected = _LobbyAction.create;
  bool _loading = false;
  bool _warmingUp = false;
  String? _error;
  (String, String)? _saved;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSession());
  }

  Future<void> _loadSession() async {
    try {
      final session = await _client.lastSession();
      if (!mounted) return;
      setState(() {
        _saved = session.$1.isNotEmpty && session.$2.isNotEmpty
            ? session
            : null;
        if (_nameController.text.isEmpty) _nameController.text = session.$1;
        if (_codeController.text.isEmpty) _codeController.text = session.$2;
      });
    } catch (_) {
      /* Manual entry remains available if local storage fails. */
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _connect({_LobbyAction? action, bool saved = false}) async {
    if (_loading) return;
    final mode = action ?? _selected;
    final player = saved ? _saved!.$1 : _nameController.text.trim();
    final code = (saved ? _saved!.$2 : _codeController.text)
        .trim()
        .toUpperCase();
    String? validation;
    if (player.isEmpty) {
      validation = 'Informe seu nome.';
    } else if (mode != _LobbyAction.create &&
        !RegExp(r'^[A-Z0-9]{6}$').hasMatch(code)) {
      validation = 'Informe o código de 6 caracteres da sala.';
    }
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _warmingUp = true;
      _error = null;
      _selected = mode;
    });
    final match = MultiplayerMatch(client: _client, localPlayerId: player);
    try {
      await _client.waitUntilReady();
      if (!mounted) return;
      setState(() => _warmingUp = false);
      switch (mode) {
        case _LobbyAction.create:
          await match.create();
        case _LobbyAction.join:
          await match.join(code);
        case _LobbyAction.reconnect:
          await match.reconnect(code);
      }
      if (!mounted) return;
      await Navigator.of(
        context,
      ).push(pixelSlideRoute((_) => MultiplayerBattleScreen(match: match)));
      await _loadSession();
    } on TimeoutException {
      if (mounted) {
        setState(
          () => _error = _warmingUp
              ? 'O servidor não iniciou em até 1 minuto. Tente novamente. Nenhuma ação de partida foi enviada.'
              : 'O servidor demorou para responder. Aguarde um pouco e tente novamente. Se já tinha uma sala, use Retomar.',
        );
      }
    } on MultiplayerException catch (e) {
      if (mounted) {
        setState(
          () => _error = switch (e.statusCode ?? 0) {
            404 => 'Sala não encontrada. Confira o código com seu amigo.',
            401 || 403 =>
              'Esta identidade não tem acesso à sala. Use o mesmo nome e aparelho da partida.',
            409 =>
              'Não foi possível entrar. A sala pode estar ocupada ou já iniciada; se você já participa, use Retomar.',
            >= 500 =>
              'Servidor indisponível no momento. Tente novamente mais tarde.',
            _ => e.message,
          },
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Não foi possível conectar. Confira sua internet e tente novamente.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _warmingUp = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_loading,
    child: Scaffold(
      backgroundColor: const Color(0xFF172D2C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF172D2C),
        foregroundColor: const Color(0xFFF1E8C9),
        automaticallyImplyLeading: !_loading,
        title: const Text(
          'MULTIPLAYER',
          style: TextStyle(fontFamily: 'monospace', fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: MultiplayerConnectionPanel(
          title: _loading
              ? _warmingUp
                    ? 'INICIANDO SERVIDOR'
                    : switch (_selected) {
                        _LobbyAction.create => 'CRIANDO SALA',
                        _LobbyAction.join => 'ENTRANDO NA SALA',
                        _LobbyAction.reconnect => 'RETOMANDO PARTIDA',
                      }
              : 'DUELAR COM UM AMIGO',
          message: _loading
              ? _warmingUp
                    ? 'A primeira conexão pode levar até 1 minuto.'
                    : 'Aguardando confirmação do servidor…'
              : 'Dois aparelhos. Uma arena.\nSua próxima combinação decide o duelo.',
          connecting: _loading,
          child: _loading
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Conectando ao servidor',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'A primeira conexão pode demorar. Aguarde esta tentativa terminar antes de tentar outra vez.',
                    ),
                    SizedBox(height: 8),
                    Text('Nenhuma ação será reenviada automaticamente.'),
                  ],
                )
              : _form(),
        ),
      ),
    ),
  );

  Widget _form() => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      PixelTextField(controller: _nameController, label: 'Seu nome'),
      const SizedBox(height: 6),
      const Text('Use o mesmo nome para manter seu perfil neste aparelho.'),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        children: [
          for (final item in [
            (_LobbyAction.create, 'Criar'),
            (_LobbyAction.join, 'Entrar'),
            (_LobbyAction.reconnect, 'Retomar'),
          ])
            ChoiceChip(
              label: Text(item.$2),
              selected: _selected == item.$1,
              selectedColor: const Color(0xFFE1C778),
              backgroundColor: const Color(0xFFF1E8C9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              onSelected: (_) => setState(() {
                _selected = item.$1;
                _error = null;
              }),
            ),
        ],
      ),
      const SizedBox(height: 12),
      if (_selected == _LobbyAction.create)
        const Text('Crie uma sala e envie o código ao seu amigo.')
      else ...[
        PixelTextField(
          controller: _codeController,
          label: 'Código da sala',
          maxLength: 6,
          capitalization: TextCapitalization.characters,
        ),
        Text(
          _selected == _LobbyAction.join
              ? 'Digite o código que seu amigo enviou.'
              : 'Volte à sala usando o mesmo nome e aparelho.',
        ),
      ],
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Semantics(
            liveRegion: true,
            child: Text(
              _error!,
              style: const TextStyle(color: Color(0xFF9B302E)),
            ),
          ),
        ),
      const SizedBox(height: 14),
      PixelMenuButton(
        label: switch (_selected) {
          _LobbyAction.create => 'Criar partida',
          _LobbyAction.join => 'Entrar com código',
          _LobbyAction.reconnect => 'Reconectar',
        },
        primary: true,
        onPressed: _connect,
      ),
      if (_saved != null) ...[
        const Divider(height: 28),
        Text('Última sala: ${_saved!.$2} · ${_saved!.$1}'),
        TextButton(
          onPressed: () =>
              _connect(action: _LobbyAction.reconnect, saved: true),
          child: const Text('Retomar última sala'),
        ),
      ],
    ],
  );
}
