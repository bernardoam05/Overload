import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:overload/data/repositories/backup_repository.dart';
import 'package:overload/data/repositories/settings_repository.dart';
import 'package:overload/services/auto_backup.dart';

import '../helpers.dart';

void main() {
  test('file names sort chronologically', () {
    expect(
      autoBackupName(DateTime(2026, 3, 7, 9, 5)),
      'overload-auto-20260307-0905.json',
    );
  });

  test('pruning keeps the newest automatic backups only', () {
    final names = [
      for (var d = 1; d <= 7; d++) autoBackupName(DateTime(2026, 1, d)),
      'overload-backup-20260101-1000.json', // a manual one: never touched
      'notes.txt',
    ];
    final pruned = backupsToPrune(names, keep: 5);
    expect(pruned, [
      autoBackupName(DateTime(2026, 1, 2)),
      autoBackupName(DateTime(2026, 1, 1)),
    ]);
  });

  test('due when enabled and the interval has passed', () {
    final now = DateTime(2026, 11, 5, 20);
    expect(const AutoBackupConfig().isDue(now), isFalse, reason: 'off');
    expect(const AutoBackupConfig(enabled: true).isDue(now), isTrue);
    final weekly = AutoBackupConfig(
      enabled: true,
      lastAt: now.subtract(const Duration(days: 3)),
    );
    expect(weekly.isDue(now), isFalse);
    expect(weekly.copyWith(intervalDays: 1).isDue(now), isTrue);
  });

  test('config survives a JSON round trip', () {
    final c = AutoBackupConfig(
      enabled: true,
      intervalDays: 1,
      directory: '/x',
      lastAt: DateTime(2026, 11, 5),
      lastError: 'erro',
    );
    expect(AutoBackupConfig.decode(null).enabled, isFalse);
    expect(AutoBackupConfig.decode('{lixo').enabled, isFalse);
    final r = AutoBackupConfig.fromJson(c.toJson());
    expect(
      (r.enabled, r.intervalDays, r.directory, r.lastAt, r.lastError),
      (true, 1, '/x', DateTime(2026, 11, 5), 'erro'),
    );
  });

  test('runNow writes a restorable backup to the chosen folder', () async {
    final db = memoryDatabase();
    addTearDown(db.close);
    final dir = await Directory.systemTemp.createTemp('overload-backup-');
    addTearDown(() => dir.delete(recursive: true));

    final service = AutoBackupService(
      SettingsRepository(db),
      BackupRepository(db),
    );
    await service.save(AutoBackupConfig(enabled: true, directory: dir.path));
    final result = await service.runNow();

    expect(result.lastError, isNull);
    expect(result.lastAt, isNotNull);
    final file = File(result.lastPath!);
    expect(file.parent.path, dir.path);
    expect(await file.readAsString(), contains('"format": "overload-backup"'));
    expect((await service.read()).lastPath, file.path);
  });
}
