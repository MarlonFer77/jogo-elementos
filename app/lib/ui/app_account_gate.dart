import 'dart:async';
import 'package:flutter/material.dart';
import '../game_domain/account_auth.dart';
import 'account_login_screen.dart';
import 'home_screen.dart';

/// One app identity, shared by every mode. No progress migration or cloud claim.
class AppAccountGate extends StatefulWidget {
  const AppAccountGate({super.key, this.auth});
  final AccountAuth? auth;
  @override
  State<AppAccountGate> createState() => _AppAccountGateState();
}

class _AppAccountGateState extends State<AppAccountGate> {
  late final _auth = widget.auth ?? AccountAuth();
  bool _loading = true;
  String? _error;
  bool get _identified =>
      _auth.hasSession &&
      _auth.emailVerified &&
      _auth.uid != null &&
      _auth.uid!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    unawaited(_restore());
  }

  Future<void> _restore() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _auth.restore();
    } catch (_) {
      _error = 'Não foi possível ler sua sessão. Seus dados foram preservados.';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _signOut() async {
    if (_loading) return;
    setState(() => _loading = true);
    // Keep a failed deletion visible; never silently restore the same session.
    try {
      await _auth.signOut();
      _error = null;
    } catch (_) {
      _error =
          'Não foi possível encerrar a sessão. Tente sair novamente. Seus saves não foram apagados.';
    }
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF172D2C),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'ELEMENTOS',
                    style: TextStyle(color: Color(0xFFF4D782), fontSize: 26),
                  ),
                  const SizedBox(height: 16),
                  if (_loading)
                    const CircularProgressIndicator()
                  else ...[
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFF1E8C9)),
                    ),
                    TextButton(
                      onPressed: _restore,
                      child: const Text('Tentar ler novamente'),
                    ),
                    TextButton(
                      onPressed: _signOut,
                      child: const Text('Sair e entrar novamente'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (!_identified) {
      return AccountLoginScreen(
        auth: _auth,
        accountOnly: true,
        restoreSession: false,
        onSignOut: _signOut,
        onAuthenticated: () {
          if (mounted) setState(() {});
        },
      );
    }
    return HomeScreen(
      key: ValueKey(_auth.uid),
      auth: _auth,
      onSignOut: _signOut,
    );
  }
}
