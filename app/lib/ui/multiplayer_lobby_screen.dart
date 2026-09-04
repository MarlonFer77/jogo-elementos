import 'package:flutter/material.dart';

import '../game_domain/multiplayer_client.dart';
import '../game_domain/multiplayer_config.dart';
import '../game_domain/multiplayer_exception.dart';
import '../game_domain/multiplayer_match.dart';
import 'multiplayer_battle_screen.dart';

/// Entry point for Multiplayer (seção 11): create a match and share the
/// code, join one a friend shared, or reconnect to one already in progress
/// (e.g. after closing/reloading the tab — the app has no other way back
/// into a match than the code, since there's no account/session to resume
/// from). Player identity is just the name typed here — no accounts/login
/// (ver DECISION-016).
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
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final playerId = _nameController.text.trim();
    if (playerId.isEmpty) {
      setState(() => _error = 'Informe seu nome.');
      return;
    }
    final match = MultiplayerMatch(client: _client, localPlayerId: playerId);
    await _run(match.create, match);
  }

  Future<void> _join() async {
    final playerId = _nameController.text.trim();
    final code = _codeController.text.trim().toUpperCase();
    if (playerId.isEmpty) {
      setState(() => _error = 'Informe seu nome.');
      return;
    }
    if (code.isEmpty) {
      setState(() => _error = 'Informe o código da partida.');
      return;
    }
    final match = MultiplayerMatch(client: _client, localPlayerId: playerId);
    await _run(() => match.join(code), match);
  }

  Future<void> _reconnect() async {
    final playerId = _nameController.text.trim();
    final code = _codeController.text.trim().toUpperCase();
    if (playerId.isEmpty) {
      setState(() => _error = 'Informe seu nome.');
      return;
    }
    if (code.isEmpty) {
      setState(() => _error = 'Informe o código da partida.');
      return;
    }
    final match = MultiplayerMatch(client: _client, localPlayerId: playerId);
    await _run(() => match.reconnect(code), match);
  }

  Future<void> _run(
    Future<void> Function() action,
    MultiplayerMatch match,
  ) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await action();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => MultiplayerBattleScreen(match: match)),
      );
    } on MultiplayerException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Multiplayer')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Seu nome'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : _create,
              child: const Text('Criar partida'),
            ),
            const Divider(height: 32),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(labelText: 'Código da partida'),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _loading ? null : _join,
                  child: const Text('Entrar com código'),
                ),
                OutlinedButton(
                  onPressed: _loading ? null : _reconnect,
                  child: const Text('Reconectar'),
                ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    );
  }
}
