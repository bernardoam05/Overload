import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../data/repositories/backup_repository.dart';
import '../data/repositories/settings_repository.dart';

/// Automatic backups: a JSON copy of all data written to a folder on the
/// device every day or week, keeping the newest [keep] files. Pointing the
/// folder at one synced by another app (Drive, Syncthing…) takes it off the
/// phone.
class AutoBackupConfig {
  const AutoBackupConfig({
    this.enabled = false,
    this.intervalDays = 7,
    this.directory,
    this.lastAt,
    this.lastPath,
    this.lastError,
  });

  final bool enabled;

  /// 1 (daily) or 7 (weekly).
  final int intervalDays;

  /// Chosen folder; `null` uses [AutoBackupService.defaultDirectory].
  final String? directory;
  final DateTime? lastAt;
  final String? lastPath;

  /// Why the last attempt failed (or fell back to another folder).
  final String? lastError;

  static const keep = 5;

  bool isDue(DateTime now) =>
      enabled &&
      (lastAt == null ||
          now.difference(lastAt!) >=
              Duration(days: intervalDays) - const Duration(hours: 1));

  AutoBackupConfig copyWith({
    bool? enabled,
    int? intervalDays,
    String? Function()? directory,
    DateTime? Function()? lastAt,
    String? Function()? lastPath,
    String? Function()? lastError,
  }) => AutoBackupConfig(
    enabled: enabled ?? this.enabled,
    intervalDays: intervalDays ?? this.intervalDays,
    directory: directory == null ? this.directory : directory(),
    lastAt: lastAt == null ? this.lastAt : lastAt(),
    lastPath: lastPath == null ? this.lastPath : lastPath(),
    lastError: lastError == null ? this.lastError : lastError(),
  );

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'intervalDays': intervalDays,
    'directory': directory,
    'lastAt': lastAt?.toIso8601String(),
    'lastPath': lastPath,
    'lastError': lastError,
  };

  factory AutoBackupConfig.fromJson(Map<String, Object?> j) => AutoBackupConfig(
    enabled: j['enabled'] == true,
    intervalDays: j['intervalDays'] == 1 ? 1 : 7,
    directory: j['directory'] as String?,
    lastAt: DateTime.tryParse(j['lastAt'] as String? ?? ''),
    lastPath: j['lastPath'] as String?,
    lastError: j['lastError'] as String?,
  );

  static AutoBackupConfig decode(String? raw) {
    if (raw == null) return const AutoBackupConfig();
    try {
      return AutoBackupConfig.fromJson(
        (jsonDecode(raw) as Map).cast<String, Object?>(),
      );
    } on Object {
      return const AutoBackupConfig();
    }
  }
}

/// File name of an automatic backup made at [t]; sorts chronologically.
String autoBackupName(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  return 'overload-auto-${t.year}${two(t.month)}${two(t.day)}-'
      '${two(t.hour)}${two(t.minute)}.json';
}

final _autoName = RegExp(r'^overload-auto-\d{8}-\d{4}\.json$');

/// Names to delete so only the newest [keep] automatic backups remain.
List<String> backupsToPrune(Iterable<String> names, {int keep = 5}) {
  final ours = names.where(_autoName.hasMatch).toList()
    ..sort((a, b) => b.compareTo(a));
  return ours.length <= keep ? const [] : ours.sublist(keep);
}

class AutoBackupService {
  AutoBackupService(this._settings, this._backup);

  final SettingsRepository _settings;
  final BackupRepository _backup;

  static const key = 'auto_backup';

  Stream<AutoBackupConfig> watch() =>
      _settings.watch(key).distinct().map(AutoBackupConfig.decode);

  Future<AutoBackupConfig> read() async =>
      AutoBackupConfig.decode(await _settings.read(key));

  Future<void> save(AutoBackupConfig config) =>
      _settings.write(key, jsonEncode(config.toJson()));

  /// `Documents/Overload` on the shared storage (survives uninstalling the
  /// app); the app's own documents folder elsewhere.
  static Future<String> defaultDirectory() async {
    if (Platform.isAndroid) {
      final ext = await getExternalStorageDirectory();
      final root = ext?.path.split('/Android/').first;
      if (root != null) return '$root/Documents/Overload';
    }
    final docs = await getApplicationDocumentsDirectory();
    return '${docs.path}/backups';
  }

  /// Folder inside the app's storage, used when the chosen one can't be
  /// written (it is removed with the app).
  static Future<String> fallbackDirectory() async {
    final dir =
        (Platform.isAndroid ? await getExternalStorageDirectory() : null) ??
        await getApplicationDocumentsDirectory();
    return '${dir.path}/backups';
  }

  /// Makes a backup if one is due. Never throws.
  Future<void> runIfDue({DateTime? now}) async {
    try {
      final config = await read();
      if (!config.isDue(now ?? DateTime.now())) return;
      await runNow();
    } on Object {
      // Reported through lastError by runNow when it gets that far.
    }
  }

  /// Writes a backup now and returns the updated config (with its path, or
  /// the error).
  Future<AutoBackupConfig> runNow() async {
    final config = await read();
    final now = DateTime.now();
    final json = await _backup.export();
    final wanted = config.directory ?? await defaultDirectory();
    String? note;
    String path;
    try {
      path = await _write(wanted, now, json);
    } on FileSystemException catch (e) {
      final fallback = await fallbackDirectory();
      try {
        path = await _write(fallback, now, json);
        note =
            'Sem acesso a $wanted (${e.osError?.message ?? e.message}). '
            'Guardado na pasta da app, que é apagada se a desinstalares.';
      } on FileSystemException catch (e2) {
        final failed = config.copyWith(
          lastError: () =>
              'Não foi possível guardar: ${e2.osError?.message ?? e2.message}',
        );
        await save(failed);
        return failed;
      }
    }
    final next = config.copyWith(
      lastAt: () => now,
      lastPath: () => path,
      lastError: () => note,
    );
    await save(next);
    return next;
  }

  static Future<String> _write(String dir, DateTime now, String json) async {
    final folder = Directory(dir);
    await folder.create(recursive: true);
    final file = File('$dir/${autoBackupName(now)}');
    await file.writeAsString(json, flush: true);
    try {
      final names = [
        for (final f in folder.listSync().whereType<File>())
          f.uri.pathSegments.last,
      ];
      for (final name in backupsToPrune(names, keep: AutoBackupConfig.keep)) {
        await File('$dir/$name').delete();
      }
    } on FileSystemException {
      // Old files left by a previous install may not be deletable.
    }
    return file.path;
  }
}
