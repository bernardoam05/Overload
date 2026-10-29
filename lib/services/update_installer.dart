import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'update_checker.dart';

/// Downloads a release APK, checks its SHA-256 and hands it to the Android installer.
class UpdateInstaller {
  static const _channel = MethodChannel('overload/installer');

  static bool get supported => Platform.isAndroid;

  /// The download URL matching this device's ABI, or null if the release has none.
  static Future<String?> apkFor(UpdateInfo info) async {
    final abis = (await _channel.invokeListMethod<String>('abis')) ?? const [];
    for (final abi in abis) {
      final url = info.apks[abi];
      if (url != null) return url;
    }
    return null;
  }

  static Future<bool> canInstall() async => (await _channel.invokeMethod<bool>('canInstall')) ?? false;

  static Future<void> openInstallSettings() => _channel.invokeMethod('openInstallSettings');

  /// Downloads [url] reporting progress in 0..1, and verifies it against the release checksums.
  static Future<File> download(UpdateInfo info, String url, void Function(double) onProgress) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/overload-update.apk');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final res = await (await client.getUrl(Uri.parse(url))).close();
      if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}');
      final total = res.contentLength;
      var received = 0;
      final sink = file.openWrite();
      try {
        await for (final chunk in res) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) onProgress(received / total);
        }
      } finally {
        await sink.close();
      }

      final sums = info.checksumsUrl;
      if (sums != null) {
        final text = await _fetchText(client, sums);
        final name = Uri.parse(url).pathSegments.last;
        final expected = RegExp('^([0-9a-f]{64})\\s+\\*?${RegExp.escape(name)}\$', multiLine: true)
            .firstMatch(text)
            ?.group(1);
        if (expected == null) throw const FormatException('Checksum em falta.');
        final actual = (await sha256.bind(file.openRead()).first).toString();
        if (actual != expected) {
          await file.delete();
          throw const FormatException('O ficheiro descarregado está corrompido.');
        }
      }
      return file;
    } finally {
      client.close(force: true);
    }
  }

  static Future<String> _fetchText(HttpClient client, String url) async {
    final res = await (await client.getUrl(Uri.parse(url))).close();
    if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}');
    return res.transform(const SystemEncoding().decoder).join();
  }

  static Future<void> install(File apk) => _channel.invokeMethod('install', apk.path);
}
