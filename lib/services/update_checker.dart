import 'dart:convert';
import 'dart:io';

/// A newer release published on GitHub.
class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.url,
    this.apks = const {},
    this.checksumsUrl,
  });
  final String version;
  final String url;

  /// APK download URL per Android ABI (`arm64-v8a`, `armeabi-v7a`, `x86_64`).
  final Map<String, String> apks;
  final String? checksumsUrl;
}

/// Looks up the latest GitHub release and compares it with the running version.
/// Every failure resolves to "no update".
class UpdateChecker {
  const UpdateChecker({this.repo = 'bernardoam05/Overload'});
  final String repo;

  Future<UpdateInfo?> check(String currentVersion) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client.getUrl(Uri.https('api.github.com', '/repos/$repo/releases/latest'));
      req.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      final res = await req.close().timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      return parseRelease(jsonDecode(await res.transform(utf8.decoder).join()), currentVersion);
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// The update described by a GitHub release payload, or null if it is not newer.
  static UpdateInfo? parseRelease(Object? json, String currentVersion) {
    if (json is! Map) return null;
    final tag = json['tag_name'];
    final url = json['html_url'];
    if (tag is! String || url is! String) return null;
    final version = tag.startsWith('v') ? tag.substring(1) : tag;
    if (!isNewer(version, currentVersion)) return null;

    final apks = <String, String>{};
    String? checksums;
    final assets = json['assets'];
    if (assets is List) {
      for (final a in assets.whereType<Map>()) {
        final name = a['name'];
        final link = a['browser_download_url'];
        if (name is! String || link is! String) continue;
        final abi = RegExp(r'-([\w-]+)\.apk$').firstMatch(name)?.group(1);
        if (abi != null) apks[abi] = link;
        if (name == 'SHA256SUMS.txt') checksums = link;
      }
    }
    return UpdateInfo(version: version, url: url, apks: apks, checksumsUrl: checksums);
  }

  /// True when [latest] is a higher `major.minor.patch` than [current].
  static bool isNewer(String latest, String current) {
    final a = _parse(latest);
    final b = _parse(current);
    if (a == null || b == null) return false;
    for (var i = 0; i < 3; i++) {
      if (a[i] != b[i]) return a[i] > b[i];
    }
    return false;
  }

  static List<int>? _parse(String v) {
    final parts = v.split('+').first.split('-').first.split('.');
    if (parts.length != 3) return null;
    final nums = parts.map(int.tryParse).toList();
    return nums.contains(null) ? null : nums.cast<int>();
  }
}
