import 'enums.dart';
import 'exercise.dart';
import 'overload.dart';

/// Warm-up ramps towards the first working set: heavier lifts get more,
/// lighter steps; isolation work needs one light set.

/// One warm-up set.
typedef WarmupStep = ({double kg, int reps});

const _kgPerLb = 0.45359237;

/// Empty bar of [equipment], or 0 when there is none (or it is unknown,
/// like a Smith machine's).
double barWeightKg(Equipment equipment, WeightUnit unit) =>
    switch ((equipment, unit)) {
      (Equipment.barbell, WeightUnit.kg) => 20,
      (Equipment.barbell, WeightUnit.lb) => 45 * _kgPerLb,
      (Equipment.ezBar, WeightUnit.kg) => 10,
      (Equipment.ezBar, WeightUnit.lb) => 25 * _kgPerLb,
      _ => 0,
    };

/// Fractions of the working load and reps for each category.
List<(double, int)> _ramp(ExerciseCategory c) => switch (c) {
  ExerciseCategory.heavyCompound => const [(0.4, 8), (0.6, 5), (0.8, 3)],
  ExerciseCategory.compound => const [(0.5, 10), (0.75, 5)],
  ExerciseCategory.isolation || ExerciseCategory.highRep => const [(0.5, 12)],
};

/// Warm-up sets before working sets of [workKg]: rounded to loadable
/// weights, lighter than the working load and without repeats. Barbell lifts
/// start with the empty bar. Empty when there is nothing to load.
List<WarmupStep> warmupRamp({
  required Exercise exercise,
  required double workKg,
  required WeightUnit unit,
}) {
  if (exercise.kind != ExerciseKind.weighted || workKg <= 0) return const [];
  final inc = loadIncrementKg(exercise, unit);
  final bar = barWeightKg(exercise.equipment, unit);
  double round(double kg) => (kg / inc).round() * inc;
  // A few increments of load need no ramp.
  if (workKg <= inc * 3) return const [];

  final steps = <WarmupStep>[];
  if (bar > 0 &&
      workKg > bar * 1.5 &&
      exercise.category == ExerciseCategory.heavyCompound) {
    steps.add((kg: bar, reps: 10));
  }
  for (final (fraction, reps) in _ramp(exercise.category)) {
    var kg = round(workKg * fraction);
    if (bar > 0 && kg < bar) kg = bar;
    if (kg < inc || kg >= workKg - inc / 2) continue;
    if (steps.isNotEmpty && kg <= steps.last.kg) continue;
    steps.add((kg: kg, reps: reps));
  }
  return steps;
}
