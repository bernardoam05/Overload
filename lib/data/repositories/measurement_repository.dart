import 'package:drift/drift.dart';

import '../../domain/enums.dart';
import '../database.dart';

/// Body measurements (cm, or % for body fat), one per kind and day.
class MeasurementRepository {
  MeasurementRepository(this._db);
  final AppDatabase _db;

  /// Valid range per kind, to catch typos at the boundary.
  static (double, double) rangeOf(Measurement kind) =>
      kind == Measurement.bodyFat ? (2, 70) : (5, 250);

  /// Entries newest first.
  Stream<List<MeasurementEntry>> watchAll() =>
      (_db.select(_db.bodyMeasurements)..orderBy([
            (m) => OrderingTerm.desc(m.date),
            (m) => OrderingTerm.desc(m.id),
          ]))
          .watch();

  /// Logs a value; a second one of the same kind on the same day replaces it.
  Future<void> log(DateTime date, Measurement kind, double value) {
    final (lo, hi) = rangeOf(kind);
    if (value < lo || value > hi) {
      throw ArgumentError('Valor fora do intervalo válido ($lo–$hi).');
    }
    final day = DateTime(date.year, date.month, date.day);
    final next = DateTime(day.year, day.month, day.day + 1);
    return _db.transaction(() async {
      await (_db.delete(_db.bodyMeasurements)..where(
            (m) =>
                m.kind.equalsValue(kind) &
                m.date.isBiggerOrEqualValue(day) &
                m.date.isSmallerThanValue(next),
          ))
          .go();
      await _db
          .into(_db.bodyMeasurements)
          .insert(
            BodyMeasurementsCompanion.insert(
              date: day,
              kind: kind,
              value: value,
            ),
          );
    });
  }

  Future<void> delete(int id) =>
      (_db.delete(_db.bodyMeasurements)..where((m) => m.id.equals(id))).go();
}
