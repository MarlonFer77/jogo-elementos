import 'dart:convert';

import 'package:http/http.dart' as http;

List<int> _versionParts(String version) =>
    version.split('.').map((p) => int.tryParse(p) ?? 0).toList();

/// Compara duas strings de versão `major.minor.patch` (ou qualquer número
/// de segmentos — os que faltam contam como zero). `true` se [remote] for
/// mais nova que [local].
bool isNewerVersion(String remote, String local) {
  final remoteParts = _versionParts(remote);
  final localParts = _versionParts(local);
  final length =
      remoteParts.length > localParts.length ? remoteParts.length : localParts.length;
  for (var i = 0; i < length; i++) {
    final r = i < remoteParts.length ? remoteParts[i] : 0;
    final l = i < localParts.length ? localParts[i] : 0;
    if (r != l) return r > l;
  }
  return false;
}

/// Resultado de [UpdateChecker.checkForUpdate].
class UpdateCheckResult {
  const UpdateCheckResult({
    required this.updateAvailable,
    this.latestVersion,
    this.downloadUrl,
  });
  const UpdateCheckResult.upToDate() : this(updateAvailable: false);
  const UpdateCheckResult.updateAvailable({
    required String latestVersion,
    required String downloadUrl,
  }) : this(updateAvailable: true, latestVersion: latestVersion, downloadUrl: downloadUrl);

  final bool updateAvailable;
  final String? latestVersion;
  final String? downloadUrl;
}

/// Consulta a API pública do GitHub Releases pra saber se existe uma
/// versão mais nova do que [currentVersion] instalada. Sem retry, sem
/// cache — quem chama decide quando chamar de novo (mesmo espírito do
/// `MultiplayerClient`). Qualquer falha (rede, timeout, resposta
/// inesperada) devolve `upToDate` — nunca bloqueia o jogo por causa de um
/// problema de rede transitório.
class UpdateChecker {
  UpdateChecker({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;

  static const _releasesUrl =
      'https://api.github.com/repos/MarlonFer77/jogo-elementos/releases/latest';
  static const _apkAssetName = 'app-release.apk';

  Future<UpdateCheckResult> checkForUpdate({required String currentVersion}) async {
    try {
      final response = await _http
          .get(
            Uri.parse(_releasesUrl),
            headers: const {'User-Agent': 'jogo-elementos-app'},
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return const UpdateCheckResult.upToDate();

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final tagName = body['tag_name'] as String?;
      if (tagName == null) return const UpdateCheckResult.upToDate();

      final latestVersion = tagName.startsWith('v') ? tagName.substring(1) : tagName;
      if (!isNewerVersion(latestVersion, currentVersion)) {
        return const UpdateCheckResult.upToDate();
      }

      final assets = (body['assets'] as List<dynamic>?) ?? const [];
      String? downloadUrl;
      for (final asset in assets) {
        final map = asset as Map<String, dynamic>;
        if (map['name'] == _apkAssetName) {
          downloadUrl = map['browser_download_url'] as String?;
          break;
        }
      }
      if (downloadUrl == null) return const UpdateCheckResult.upToDate();

      return UpdateCheckResult.updateAvailable(
        latestVersion: latestVersion,
        downloadUrl: downloadUrl,
      );
    } catch (_) {
      return const UpdateCheckResult.upToDate();
    }
  }
}
