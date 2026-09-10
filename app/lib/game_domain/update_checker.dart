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
