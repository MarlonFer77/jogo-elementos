import 'dart:async';
import 'package:flutter/material.dart';
import '../game_domain/account_auth.dart';
import '../game_domain/multiplayer_client.dart';
import '../game_domain/multiplayer_config.dart';
import '../game_domain/multiplayer_exception.dart';
import '../game_presentation/multiplayer_connection_panel.dart';
import '../game_presentation/pixel_menu_button.dart';
import '../game_presentation/pixel_text_field.dart';
import '../game_presentation/pixel_page_route.dart';
import 'multiplayer_lobby_screen.dart';

class MultiplayerLoginScreen extends StatefulWidget {
  const MultiplayerLoginScreen({super.key, this.auth});
  final AccountAuth? auth;
  @override
  State<MultiplayerLoginScreen> createState() => _MultiplayerLoginScreenState();
}

class _MultiplayerLoginScreenState extends State<MultiplayerLoginScreen> {
  late final _auth = widget.auth ?? AccountAuth();
  final _email = TextEditingController(),
      _password = TextEditingController(),
      _name = TextEditingController();
  bool _busy = false,
      _register = false,
      _profileNeeded = false,
      _importLegacy = false;
  String? _message, _legacyToken;
  (String, String) _legacy = ('', '');
  MultiplayerClient get _client => MultiplayerClient(
    baseUrl: defaultMultiplayerBaseUrl,
    accountId: _auth.uid,
    idToken: () => _auth.idToken(),
  );

  @override
  void initState() {
    super.initState();
    unawaited(
      _run(() async {
        final legacy = MultiplayerClient(baseUrl: defaultMultiplayerBaseUrl);
        _legacy = await legacy.lastSession();
        _legacyToken = await legacy.legacyToken();
        _importLegacy = _legacyToken != null && _legacy.$1.isNotEmpty;
        _name.text = _legacy.$1;
        await _auth.restore();
        _email.text = _auth.email;
        if (_auth.hasSession) await _connect();
      }),
    );
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        _message = error is MultiplayerException
            ? error.message
            : 'Não foi possível conectar ou salvar a sessão. Tente novamente.';
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connect() async {
    final client = _client;
    await client.waitUntilReady(requireAccount: true);
    await _auth.idToken(force: true);
    String player;
    try {
      player = await client.account();
    } on MultiplayerException catch (error) {
      if (error.statusCode == 404) {
        _profileNeeded = true;
        return;
      }
      rethrow;
    }
    await _openLobby(client, player);
  }

  Future<void> _openLobby(MultiplayerClient client, String player) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      pixelSlideRoute(
        (_) => MultiplayerLobbyScreen(
          client: client,
          accountName: player,
          onSignOut: () async {
            await _auth.signOut();
            _profileNeeded = false;
          },
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _authenticate() => _run(() async {
    if (!_email.text.contains('@') || _password.text.isEmpty) {
      throw MultiplayerException('Informe seu e-mail e senha.');
    }
    if (_register && _password.text.length < 8) {
      throw MultiplayerException('Use pelo menos 8 caracteres na senha.');
    }
    await _auth.signIn(_email.text, _password.text, register: _register);
    _password.clear();
    if (_register) {
      await _auth.sendVerification();
      _message =
          'Confira sua caixa de e-mail (e spam), confirme o endereço e volte aqui.';
    } else {
      await _connect();
    }
  });

  Future<void> _saveProfile() => _run(() async {
    final client = _client;
    final player = await client.account(
      playerId: _name.text.trim(),
      legacyToken: _importLegacy ? _legacyToken : null,
      matchId: _importLegacy ? _legacy.$2 : null,
    );
    if (_importLegacy && _legacy.$2.isNotEmpty) {
      await client.rememberSession(_legacy.$2, player);
    }
    _profileNeeded = false;
    await _openLobby(client, player);
  });

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      backgroundColor: const Color(0xFF172D2C),
      appBar: AppBar(
        title: const Text('CONTA DO AVENTUREIRO'),
        backgroundColor: const Color(0xFF172D2C),
        foregroundColor: const Color(0xFFF1E8C9),
      ),
      body: SafeArea(
        child: MultiplayerConnectionPanel(
          title: _profileNeeded ? 'SEU PERFIL' : 'PORTAL DO DUELO',
          message: 'Seu progresso online acompanha sua conta.',
          connecting: _busy,
          child: AutofillGroup(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Treino e Dungeon continuam offline. Esta conta recupera apenas o perfil multiplayer.',
                ),
                const SizedBox(height: 12),
                if (!_auth.configured)
                  const Text(
                    'Login aguardando configuração do Firebase neste APK.',
                  ),
                if (_profileNeeded) ...[
                  PixelTextField(
                    controller: _name,
                    label: 'Nome do aventureiro',
                    maxLength: _importLegacy ? 64 : 24,
                  ),
                  if (_legacyToken != null && _legacy.$1.isNotEmpty)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _importLegacy,
                      title: Text('Vincular perfil antigo: ${_legacy.$1}'),
                      subtitle: const Text(
                        'Mantém progresso e salas. Vincule no aparelho antigo antes de trocar de celular.',
                      ),
                      onChanged: _busy
                          ? null
                          : (value) => setState(() => _importLegacy = value!),
                    ),
                  const Text(
                    'O nome ficará vinculado à conta. Não misturamos dois perfis existentes.',
                  ),
                  PixelMenuButton(
                    label: 'Confirmar perfil',
                    primary: true,
                    onPressed: _busy ? null : _saveProfile,
                  ),
                ] else if (_auth.hasSession) ...[
                  Text('Conta: ${_auth.email}'),
                  PixelMenuButton(
                    label: 'Continuar / já confirmei o e-mail',
                    primary: true,
                    onPressed: _busy ? null : () => _run(_connect),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                            await _auth.sendVerification();
                            _message =
                                'E-mail de confirmação enviado. Confira também o spam.';
                          }),
                    child: const Text('Reenviar confirmação de e-mail'),
                  ),
                ] else ...[
                  PixelTextField(
                    controller: _email,
                    label: 'E-mail',
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                  ),
                  const SizedBox(height: 8),
                  PixelTextField(
                    controller: _password,
                    label: 'Senha',
                    obscureText: true,
                    autofillHints: [
                      _register
                          ? AutofillHints.newPassword
                          : AutofillHints.password,
                    ],
                  ),
                  const SizedBox(height: 8),
                  PixelMenuButton(
                    label: _register ? 'Criar conta' : 'Entrar',
                    primary: true,
                    onPressed: _busy || !_auth.configured
                        ? null
                        : _authenticate,
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                            _register = !_register;
                            _message = null;
                          }),
                    child: Text(
                      _register ? 'Já tenho conta' : 'Criar minha conta',
                    ),
                  ),
                  TextButton(
                    onPressed: _busy || !_auth.configured
                        ? null
                        : () => _run(() async {
                            if (!_email.text.contains('@')) {
                              throw MultiplayerException(
                                'Informe seu e-mail para recuperar a senha.',
                              );
                            }
                            await _auth.resetPassword(_email.text);
                            _message =
                                'Se houver uma conta para este e-mail, você receberá as instruções de recuperação.';
                          }),
                    child: const Text('Esqueci minha senha'),
                  ),
                ],
                if (_auth.hasSession || _message != null)
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                            await _auth.signOut();
                            _profileNeeded = false;
                          }),
                    child: const Text('Sair / usar outra conta'),
                  ),
                if (_message != null)
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _message!,
                      style: const TextStyle(color: Color(0xFF9B302E)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
