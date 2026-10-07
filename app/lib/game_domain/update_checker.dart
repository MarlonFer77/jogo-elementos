import 'dart:convert';
import 'package:http/http.dart' as http;

List<int>? _versionParts(String version) {
  if (!RegExp(r'^\d+(\.\d+){1,3}(\+\d+)?$').hasMatch(version)) return null;
  return version.split('+').first.split('.').map(int.parse).toList();
}

bool isNewerVersion(String remote, String local) {
  final r = _versionParts(remote), l = _versionParts(local);
  if (r == null || l == null) return false;
  for (var i = 0; i < (r.length > l.length ? r.length : l.length); i++) {
    final a = i < r.length ? r[i] : 0, b = i < l.length ? l[i] : 0;
    if (a != b) return a > b;
  }
  return false;
}

class UpdateCheckResult {
  const UpdateCheckResult({
    required this.updateAvailable,
    this.latestVersion,
    this.downloadUrl,
    this.checksum,
    this.error,
  });
  const UpdateCheckResult.upToDate() : this(updateAvailable: false);
  const UpdateCheckResult.failed(String message)
    : this(updateAvailable: false, error: message);
  const UpdateCheckResult.updateAvailable({
    required String latestVersion,
    required String downloadUrl,
    String? checksum,
  }) : this(
         updateAvailable: true,
         latestVersion: latestVersion,
         downloadUrl: downloadUrl,
         checksum: checksum,
       );

  final bool updateAvailable;
  final String? latestVersion, downloadUrl, checksum, error;
}

/// A failed check is not evidence that the installed app is current.
/// No credentials, background polling or automatic installation.
class UpdateChecker {
  UpdateChecker({
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 10),
  }) : _http = httpClient,
       _timeout = timeout;
  final http.Client? _http;
  final Duration _timeout;
  static const _repo = 'MarlonFer77/jogo-elementos';

  Future<UpdateCheckResult> checkForUpdate({
    required String currentVersion,
  }) async {
    final client = _http ?? http.Client();
    try {
      if (_versionParts(currentVersion) == null) {
        return const UpdateCheckResult.failed(
          'Não foi possível identificar a versão instalada.',
        );
      }
      final response = await client
          .get(
            Uri.parse('https://api.github.com/repos/$_repo/releases/latest'),
            headers: const {
              'User-Agent': 'jogo-elementos-app',
              'Accept': 'application/vnd.github+json',
            },
          )
          .timeout(_timeout);
      if (response.statusCode == 403 || response.statusCode == 429) {
        return const UpdateCheckResult.failed(
          'Limite de consultas atingido. Aguarde alguns minutos.',
        );
      }
      if (response.statusCode != 200) {
        return const UpdateCheckResult.failed(
          'Não foi possível consultar a release. Tente novamente mais tarde.',
        );
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final tag = body['tag_name'] as String;
      final version = tag.startsWith('v') ? tag.substring(1) : tag;
      if (body['draft'] == true ||
          body['prerelease'] == true ||
          _versionParts(version) == null) {
        return const UpdateCheckResult.failed(
          'A release não é uma versão estável válida.',
        );
      }
      if (!isNewerVersion(version, currentVersion)) {
        return const UpdateCheckResult.upToDate();
      }
      final assets = (body['assets'] as List).whereType<Map<String, dynamic>>();
      final matches = assets
          .where((a) => a['name'] == 'app-release.apk')
          .toList();
      if (matches.length != 1 ||
          matches.single['state'] != 'uploaded' ||
          matches.single['size'] is! int ||
          (matches.single['size'] as int) <= 0) {
        return const UpdateCheckResult.failed(
          'A nova release ainda não tem um APK pronto. Tente mais tarde.',
        );
      }
      final asset = matches.single;
      final url = Uri.parse(asset['browser_download_url'] as String);
      final expected = Uri.https(
        'github.com',
        '/$_repo/releases/download/$tag/app-release.apk',
      );
      final digest = asset['digest'];
      if (url != expected ||
          digest is! String ||
          !RegExp(r'^sha256:[a-fA-F0-9]{64}$').hasMatch(digest)) {
        return const UpdateCheckResult.failed(
          'Não foi possível validar a origem e a integridade do APK.',
        );
      }
      return UpdateCheckResult.updateAvailable(
        latestVersion: version,
        downloadUrl: url.toString(),
        checksum: digest.substring(7).toLowerCase(),
      );
    } catch (_) {
      return const UpdateCheckResult.failed(
        'Não foi possível verificar a atualização. Confira a conexão e tente novamente.',
      );
    } finally {
      if (_http == null) client.close();
    }
  }
}
