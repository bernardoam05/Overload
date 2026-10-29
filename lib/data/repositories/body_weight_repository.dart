import 'package:drift/drift.dart';

import '../database.dart';

class BodyWeightRepository {
  BodyWeightRepository(this._db);
  final AppDatabase _db;

  /// Entries newest first.
  Stream<List<BodyWeightEntry>> watchAll() =>
      (_db.select(_db.bodyWeights)..orderBy([
            (b) => OrderingTerm.desc(b.date),
            (b) => OrderingTerm.desc(b.id),
          ]))
          .watch();

  /// Logs a weight; a second entry on the same day replaces the first.
  Future<void> log(DateTime date, double weightKg) {
    if (weightKg < 20 || weightKg > 400) {
      throw ArgumentError('Peso fora do intervalo válido.');
    }
    final day = DateTime(date.year, date.month, date.day);
    final next = DateTime(day.year, day.month, day.day + 1);
    return _db.transaction(() async {
      await (_db.delete(_db.bodyWeights)..where(
            (b) =>
                b.date.isBiggerOrEqualValue(day) &
                b.date.isSmallerThanValue(next),
          ))
          .go();
      await _db
          .into(_db.bodyWeights)
          .insert(BodyWeightsCompanion.insert(date: day, weightKg: weightKg));
    });
  }

  Future<void> delete(int id) =>
      (_db.delete(_db.bodyWeights)..where((b) => b.id.equals(id))).go();
}
