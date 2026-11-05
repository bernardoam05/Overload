import 'package:flutter_test/flutter_test.dart';
import 'package:overload/data/repositories/backup_repository.dart';
import 'package:overload/data/repositories/measurement_repository.dart';
import 'package:overload/domain/enums.dart';

import '../helpers.dart';

void main() {
  test('one value per kind and day; other kinds untouched', () async {
    final db = memoryDatabase();
    addTearDown(db.close);
    final repo = MeasurementRepository(db);
    final day = DateTime(2026, 11, 5, 8);
    await repo.log(day, Measurement.waist, 82);
    await repo.log(day.add(const Duration(hours: 4)), Measurement.waist, 81.5);
    await repo.log(day, Measurement.arm, 38);
    final all = await repo.watchAll().first;
    expect(all.map((e) => (e.kind, e.value)).toSet(), {
      (Measurement.waist, 81.5),
      (Measurement.arm, 38.0),
    });
  });

  test('rejects values out of range', () async {
    final db = memoryDatabase();
    addTearDown(db.close);
    final repo = MeasurementRepository(db);
    expect(
      () => repo.log(DateTime(2026), Measurement.arm, 500),
      throwsArgumentError,
    );
    expect(
      () => repo.log(DateTime(2026), Measurement.bodyFat, 90),
      throwsArgumentError,
    );
  });

  test('measurements survive a backup round trip', () async {
    final db = memoryDatabase();
    addTearDown(db.close);
    await MeasurementRepository(
      db,
    ).log(DateTime(2026, 11, 5), Measurement.thigh, 58);
    final json = await BackupRepository(db).export();

    final other = memoryDatabase();
    addTearDown(other.close);
    await BackupRepository(other).import(json);
    final restored = await MeasurementRepository(other).watchAll().first;
    expect(restored.single.kind, Measurement.thigh);
    expect(restored.single.value, 58);
  });
}
