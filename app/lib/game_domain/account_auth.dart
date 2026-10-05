import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'multiplayer_exception.dart';

/// Firebase Auth owns passwords and recovery. Only its refresh token is stored
/// on-device, encrypted by the platform; never in SharedPreferences or logs.
class AccountAuth {
  AccountAuth({
    this.apiKey = const String.fromEnvironment('FIREBASE_API_KEY'),
    http.Client? httpClient,
    FlutterSecureStorage? storage,
  }) : _http = httpClient ?? http.Client(),
       _storage = storage ?? const FlutterSecureStorage();
  final String apiKey;
  final http.Client _http;
  final FlutterSecureStorage _storage;
  String? _refreshToken, _idToken, uid;
  String email = '';
  DateTime _expires = DateTime(1970);
  Future<String>? _refreshing;
  int _generation = 0;
  String get _key => 'elementos.firebase.session.$apiKey';
  bool get configured => apiKey.isNotEmpty;
  bool get hasSession => _refreshToken != null;

  Future<void> restore() async {
    final saved = await _storage.read(key: _key);
    if (saved == null) return;
    try {
      final data = jsonDecode(saved) as Map<String, dynamic>;
      if (data['refresh'] is! String || data['uid'] is! String) {
        throw const FormatException();
      }
      _refreshToken = data['refresh'] as String;
      uid = data['uid'] as String;
      email = data['email'] as String? ?? '';
    } catch (_) {
      throw MultiplayerException(
        'Sessão salva inválida. Saia e entre novamente; seu perfil online não foi apagado.',
      );
    }
  }

  void _checkConfig() {
    if (!configured) {
      throw MultiplayerException(
        'Login não configurado neste APK. Falta FIREBASE_API_KEY no build.',
      );
    }
  }

  Map<String, dynamic> _decode(
    http.Response response, {
    bool passwordReset = false,
  }) {
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      final code = (data['error'] as Map?)?['message']?.toString() ?? '';
      if (passwordReset && code == 'EMAIL_NOT_FOUND') return {};
      final message = switch (code.split(' : ').first) {
        'EMAIL_EXISTS' =>
          'Este e-mail já possui conta. Entre ou recupere a senha.',
        'INVALID_EMAIL' => 'Confira o endereço de e-mail.',
        'WEAK_PASSWORD' =>
          'Escolha uma senha mais forte (mínimo 8 caracteres).',
        'TOO_MANY_ATTEMPTS_TRY_LATER' =>
          'Muitas tentativas. Aguarde antes de tentar novamente.',
        'OPERATION_NOT_ALLOWED' || 'CONFIGURATION_NOT_FOUND' =>
          'Login por e-mail ainda não ativado no Firebase.',
        'USER_DISABLED' =>
          'Conta desativada. Entre em contato com o responsável pelo jogo.',
        'TOKEN_EXPIRED' ||
        'INVALID_REFRESH_TOKEN' ||
        'USER_NOT_FOUND' => 'Sessão expirada. Saia e entre novamente.',
        _ =>
          'Não foi possível autenticar. Confira e-mail/senha ou use a recuperação.',
      };
      throw MultiplayerException(message, statusCode: response.statusCode);
    }
    return data;
  }

  Future<Map<String, dynamic>> _request(
    String method,
    Map<String, dynamic> body,
  ) async {
    _checkConfig();
    final response = await _http
        .post(
          Uri.https('identitytoolkit.googleapis.com', '/v1/accounts:$method', {
            'key': apiKey,
          }),
          headers: {
            'Content-Type': 'application/json',
            'X-Firebase-Locale': 'pt-BR',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));
    return _decode(
      response,
      passwordReset: body['requestType'] == 'PASSWORD_RESET',
    );
  }

  Future<void> signIn(
    String address,
    String password, {
    bool register = false,
  }) async {
    final data = await _request(register ? 'signUp' : 'signInWithPassword', {
      'email': address.trim(),
      'password': password,
      'returnSecureToken': true,
    });
    await _accept(data, address.trim());
  }

  Future<void> _accept(Map<String, dynamic> data, String address) async {
    final refresh = data['refreshToken'] as String;
    final user = data['localId'] as String;
    final token = data['idToken'] as String;
    await _storage.write(
      key: _key,
      value: jsonEncode({'refresh': refresh, 'uid': user, 'email': address}),
    );
    _refreshToken = refresh;
    uid = user;
    email = address;
    _idToken = token;
    _expires = DateTime.now().add(
      Duration(seconds: int.parse('${data['expiresIn']}') - 60),
    );
  }

  Future<String> idToken({bool force = false}) async {
    if (!hasSession) {
      throw MultiplayerException(
        'Entre na sua conta para jogar online.',
        statusCode: 401,
      );
    }
    if (!force && _idToken != null && DateTime.now().isBefore(_expires)) {
      return _idToken!;
    }
    return _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
  }

  Future<String> _refresh() async {
    _checkConfig();
    final generation = _generation;
    final response = await _http
        .post(
          Uri.https('securetoken.googleapis.com', '/v1/token', {'key': apiKey}),
          body: {
            'grant_type': 'refresh_token',
            'refresh_token': _refreshToken!,
          },
        )
        .timeout(const Duration(seconds: 20));
    final data = _decode(response);
    if (generation != _generation) {
      throw MultiplayerException('Sessão encerrada.', statusCode: 401);
    }
    if (data['user_id'] != uid) {
      throw MultiplayerException(
        'Identidade inconsistente. Entre novamente.',
        statusCode: 401,
      );
    }
    await _accept({
      'refreshToken': data['refresh_token'],
      'localId': data['user_id'],
      'idToken': data['id_token'],
      'expiresIn': data['expires_in'],
    }, email);
    return _idToken!;
  }

  Future<void> sendVerification() async => _request('sendOobCode', {
    'requestType': 'VERIFY_EMAIL',
    'idToken': await idToken(),
  });

  Future<void> resetPassword(String address) async {
    await _request('sendOobCode', {
      'requestType': 'PASSWORD_RESET',
      'email': address.trim(),
    });
  }

  Future<void> signOut() async {
    _generation++;
    _refreshToken = null;
    _idToken = null;
    // Drain a refresh already writing storage before deleting the session.
    try {
      await _refreshing;
    } catch (_) {
      /* Sign-out must still clear storage. */
    }
    await _storage.delete(key: _key);
    _refreshToken = null;
    _idToken = null;
    uid = null;
    email = '';
  }
}
