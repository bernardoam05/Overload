import 'package:drift/drift.dart' hide isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:overload/data/aliases.dart';
import 'package:overload/data/database.dart';
import 'package:overload/data/seed.dart';
import 'package:overload/domain/exercise.dart';
import 'package:overload/features/exercises/exercises_screen.dart';

import '../helpers.dart';

/// The names a real user wrote in their notes, and the exercise they meant.
const _userNames = <String, String>{
  'Supino haltere 30⁰': 'db_incline',
  'Shoulder press': 'machine_shoulder_press',
  'Chest press': 'chest_press',
  'Peck deck': 'pec_deck',
  'Lateral raises polia': 'cable_lateral',
  'Lateral raises': 'lateral_raise',
  'Skullcrushers haltere': 'db_skull_crusher',
  'Tricep polia': 'pushdown',
  'Pull up': 'pull_up',
  'Remada baixa': 'cable_row',
  'Remada unilateral': 'kneeling_cable_row',
  'Remada unilateral polia': 'kneeling_cable_row',
  'Deadlift': 'deadlift',
  'RDL': 'rdl',
  'OHP': 'ohp',
  'Lat pulldown': 'lat_pulldown',
  'Hip thrust': 'hip_thrust',
  'Reverse fly': 'reverse_pec_deck',
  'Bíceps banco 45': 'incline_db_curl',
  'Shrugs': 'shrug',
  'Rosca martelo': 'hammer_curl',
  'Flexora deitado': 'leg_curl',
  'Stiff': 'stiff',
  'Flexora em pé': 'standing_leg_curl',
  'Addutora': 'hip_adduction',
  'Gemeos prensa': 'leg_press_calf',
  'Extensora': 'leg_extension',
  'Extensora unilateral': 'leg_extension_single',
  'Prensa': 'leg_press',
  'Bulgarian split squats': 'bulgarian_split',
  'Agachamento': 'squat',
  'Abdutora': 'hip_abduction',
  'Elevação de gémeos sentado': 'seated_calf',
};

void main() {
  late AppDatabase db;
  late List<Exercise> library;

  setUp(() async {
    db = memoryDatabase();
    library = await db.select(db.exercises).get();
  });
  tearDown(() => db.close());

  test('seed keys are unique and every alias points to a real exercise', () {
    final keys = [for (final s in librarySeed) s.$1];
    expect(keys.toSet(), hasLength(keys.length));
    expect(exerciseAliases.keys.where((k) => !keys.contains(k)), isEmpty);
  });

  for (final MapEntry(key: query, value: key) in _userNames.entries) {
    test('"$query" finds ${key.replaceAll('_', ' ')}', () {
      final matches = library.where((e) => searchScore(e, query) > 0).toList()
        ..sort(
          (a, b) => searchScore(b, query).compareTo(searchScore(a, query)),
        );
      expect(matches.map((e) => e.seedKey), contains(key));
    });
  }

  test('seeding refreshes built-in names but keeps user settings', () async {
    await (db.update(
      db.exercises,
    )..where((e) => e.seedKey.equals('leg_curl'))).write(
      const ExercisesCompanion(
        name: Value('Flexão de pernas'),
        restSeconds: Value(75),
      ),
    );
    await seedExercises(db);
    final row = await (db.select(
      db.exercises,
    )..where((e) => e.seedKey.equals('leg_curl'))).getSingle();
    expect(row.name, 'Flexão de pernas deitado');
    expect(row.restSeconds, 75);
    expect(await db.select(db.exercises).get(), hasLength(librarySeed.length));
  });
}
