import 'dart:convert';

import 'package:drift/drift.dart';

import '../database.dart';
import '../seed.dart';
import 'settings_repository.dart';

class BackupFormatException implements Exception {
  BackupFormatException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Serialises the whole database to JSON and restores it.
class BackupRepository {
  BackupRepository(this._db);
  final AppDatabase _db;

  static const _format = 'overload-backup';
  static const _legacyFormat = 'apice-backup';
  static const _version = 1;

  /// Parents before children, so inserts satisfy foreign keys.
  List<TableInfo> get _tables => [
    _db.exercises,
    _db.routines,
    _db.routineExercises,
    _db.workouts,
    _db.workoutExercises,
    _db.workoutSets,
    _db.bodyWeights,
    _db.keyValues,
  ];

  Future<String> export() async {
    final tables = <String, Object?>{};
    for (final t in _tables) {
      final rows = await _db
          .customSelect('SELECT * FROM "${t.actualTableName}"', readsFrom: {t})
          .get();
      tables[t.actualTableName] = [
        for (final r in rows)
          if (!(t == _db.keyValues &&
              r.data['key'] == SettingsRepository.activeWorkoutKey))
            r.data,
      ];
    }
    return const JsonEncoder.withIndent(' ').convert({
      'format': _format,
      'version': _version,
      'exportedAt': DateTime.now().toIso8601String(),
      'tables': tables,
    });
  }

  /// Replaces all data with the contents of [json]. Validates structure and
  /// column names before touching the database.
  Future<void> import(String json) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      throw BackupFormatException('O ficheiro não é JSON válido.');
    }
    if (decoded is! Map ||
        (decoded['format'] != _format && decoded['format'] != _legacyFormat)) {
      throw BackupFormatException('Este ficheiro não é um backup do Overload.');
    }
    if ((decoded['version'] as num? ?? 0) > _version) {
      throw BackupFormatException('Backup criado por uma versão mais recente.');
    }
    final tables = decoded['tables'];
    if (tables is! Map) throw BackupFormatException('Backup sem dados.');

    final plan = <TableInfo, List<Map<String, Object?>>>{};
    for (final t in _tables) {
      final allowed = {for (final c in t.$columns) c.name};
      final rows = tables[t.actualTableName] ?? const [];
      if (rows is! List) {
        throw BackupFormatException('Tabela ${t.actualTableName} inválida.');
      }
      plan[t] = [
        for (final row in rows)
          if (row is Map)
            {
              for (final MapEntry(:key, :value) in row.entries)
                if (allowed.contains(key) &&
                    (value == null || value is num || value is String))
                  key as String: value,
            },
      ];
    }

    await _db.transaction(() async {
      for (final t in _tables.reversed) {
        await _db.customStatement('DELETE FROM "${t.actualTableName}"');
      }
      for (final MapEntry(key: t, value: rows) in plan.entries) {
        for (final row in rows) {
          if (row.isEmpty) continue;
          final cols = row.keys.map((c) => '"$c"').join(', ');
          final marks = List.filled(row.length, '?').join(', ');
          await _db.customInsert(
            'INSERT INTO "${t.actualTableName}" ($cols) VALUES ($marks)',
            variables: [for (final v in row.values) _variable(v)],
            updates: {t},
          );
        }
      }
    });
    _notifyAll();
  }

  void _notifyAll() =>
      _db.notifyUpdates({for (final t in _tables) TableUpdate.onTable(t)});

  Variable _variable(Object? v) => switch (v) {
    null => const Variable(null),
    int i => Variable.withInt(i),
    double d => Variable.withReal(d),
    String s => Variable.withString(s),
    _ => Variable(v),
  };

  /// Deletes every workout, routine, custom exercise and setting, then
  /// restores the built-in library and example routines.
  Future<void> wipe() async {
    await _db.transaction(() async {
      for (final t in _tables.reversed) {
        await _db.customStatement('DELETE FROM "${t.actualTableName}"');
      }
      await _db.customStatement('DELETE FROM sqlite_sequence');
      await seedExercises(_db);
      await seedRoutines(_db);
    });
    _notifyAll();
  }
}
