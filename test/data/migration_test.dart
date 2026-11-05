import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:overload/data/database.dart';
import 'package:overload/data/repositories/routine_repository.dart';
import 'package:overload/domain/enums.dart';

import '../helpers.dart';

/// The tables of schema version 1 that the v2 and v3 migrations touch.
const _v1 = [
  '''CREATE TABLE exercises (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL, primary_muscle TEXT NOT NULL,
    secondary_muscles TEXT NOT NULL DEFAULT '', equipment TEXT NOT NULL,
    kind TEXT NOT NULL, rank_factor REAL NULL,
    instructions TEXT NOT NULL DEFAULT '',
    is_custom INTEGER NOT NULL DEFAULT 0 CHECK ("is_custom" IN (0, 1)),
    seed_key TEXT NULL UNIQUE, rest_seconds INTEGER NULL,
    archived INTEGER NOT NULL DEFAULT 0 CHECK ("archived" IN (0, 1)))''',
  '''CREATE TABLE routines (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL,
    notes TEXT NOT NULL DEFAULT '', position INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL, last_used_at INTEGER NULL)''',
  '''CREATE TABLE routine_exercises (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    routine_id INTEGER NOT NULL REFERENCES routines (id) ON DELETE CASCADE,
    exercise_id INTEGER NOT NULL REFERENCES exercises (id),
    position INTEGER NOT NULL, sets INTEGER NOT NULL DEFAULT 3,
    reps INTEGER NOT NULL DEFAULT 10, weight_kg REAL NULL)''',
  '''CREATE TABLE workouts (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL,
    started_at INTEGER NOT NULL, ended_at INTEGER NOT NULL,
    notes TEXT NOT NULL DEFAULT '', xp INTEGER NOT NULL DEFAULT 0,
    routine_id INTEGER NULL REFERENCES routines (id) ON DELETE SET NULL,
    body_weight_kg REAL NULL)''',
  '''CREATE TABLE workout_exercises (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    workout_id INTEGER NOT NULL REFERENCES workouts (id) ON DELETE CASCADE,
    exercise_id INTEGER NOT NULL REFERENCES exercises (id),
    position INTEGER NOT NULL, notes TEXT NOT NULL DEFAULT '')''',
  '''INSERT INTO exercises (id, name, primary_muscle, equipment, kind, seed_key)
    VALUES (1, 'Curl com halteres', 'biceps', 'dumbbell', 'weighted', 'db_curl')''',
  "INSERT INTO routines (id, name, created_at) VALUES (1, 'Braços', 0)",
  '''INSERT INTO routine_exercises (routine_id, exercise_id, position, sets, reps)
    VALUES (1, 1, 0, 4, 12)''',
  'PRAGMA user_version = 1',
];

void main() {
  test('v1 databases gain set plans, pinned notes and load modes', () async {
    memoryDatabase().close(); // sets the multiple-databases flag
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          for (final sql in _v1) {
            raw.execute(sql);
          }
        },
      ),
    );
    addTearDown(db.close);

    final routine = (await RoutineRepository(db).watchAll().first).single;
    final item = routine.items.single;
    expect(item.setTypes, List.filled(4, SetType.normal));
    expect(item.reps, 12);
    expect(item.notes, '');
    expect(item.repStep, 0);
    expect(item.supersetNext, isFalse);

    final curl = await (db.select(
      db.exercises,
    )..where((e) => e.seedKey.equals('db_curl'))).getSingle();
    expect(curl.loadMode, LoadMode.perHand);
    expect(curl.setup, '');
    expect(curl.benchAngle, isNull);
    expect(curl.category, ExerciseCategory.isolation, reason: 'from its guide');
    expect(curl.cues, isNotEmpty);
    expect(await db.select(db.bodyMeasurements).get(), isEmpty);
    final ext = await (db.select(
      db.exercises,
    )..where((e) => e.seedKey.equals('overhead_ext'))).getSingle();
    expect(ext.loadMode, LoadMode.bilateral);
    expect(ext.name, contains('1 halter'));
  });
}
