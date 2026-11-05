import 'package:flutter_test/flutter_test.dart';
import 'package:overload/domain/enums.dart';
import 'package:overload/domain/exercise.dart';
import 'package:overload/domain/warmup.dart';

Exercise _ex(
  ExerciseCategory category,
  Equipment equipment, {
  ExerciseKind kind = ExerciseKind.weighted,
}) => Exercise(
  id: 1,
  name: 'E',
  primaryMuscle: Muscle.chest,
  secondaryMuscles: const [],
  equipment: equipment,
  kind: kind,
  rankFactor: null,
  instructions: '',
  isCustom: false,
  seedKey: null,
  restSeconds: null,
  archived: false,
  category: category,
);

List<(double, int)> _steps(
  Exercise e,
  double kg, [
  WeightUnit u = WeightUnit.kg,
]) => [
  for (final s in warmupRamp(exercise: e, workKg: kg, unit: u)) (s.kg, s.reps),
];

void main() {
  test('heavy barbell lift: empty bar, then 40 / 60 / 80 %', () {
    expect(
      _steps(_ex(ExerciseCategory.heavyCompound, Equipment.barbell), 100),
      [(20.0, 10), (40.0, 8), (60.0, 5), (80.0, 3)],
    );
  });

  test('steps are rounded to loadable weights and never repeat', () {
    expect(
      _steps(_ex(ExerciseCategory.heavyCompound, Equipment.barbell), 47.5),
      [(20.0, 10), (27.5, 5), (37.5, 3)],
    );
  });

  test('compound with dumbbells: two steps, 2 kg increments', () {
    expect(_steps(_ex(ExerciseCategory.compound, Equipment.dumbbell), 30), [
      (16.0, 10),
      (22.0, 5),
    ]);
  });

  test('isolation: one light set', () {
    expect(_steps(_ex(ExerciseCategory.isolation, Equipment.cable), 50), [
      (25.0, 12),
    ]);
  });

  test('nothing to warm up with tiny loads or without load', () {
    expect(
      _steps(_ex(ExerciseCategory.isolation, Equipment.dumbbell), 4),
      isEmpty,
    );
    expect(
      _steps(
        _ex(
          ExerciseCategory.compound,
          Equipment.bodyweight,
          kind: ExerciseKind.bodyweight,
        ),
        10,
      ),
      isEmpty,
    );
  });
}
