import 'enums.dart';
import 'exercise.dart';
import 'models.dart';

/// Progressive overload: what to aim for in each set today, from the last
/// session and the routine's targets.
///
/// - Every main set (normal or to failure) hit its target last time: add
///   load (or time, or a rep for pure body-weight work), same targets.
/// - Some set fell short: same load, one rep more on the sets that missed,
///   never beyond the target.
/// - No targets (a free workout): same load, one rep more than last time.
///
/// Warm-ups and drops get no suggestion; last time's values still apply.

/// One planned set: its type and target reps (or seconds), if any.
class PlannedSet {
  const PlannedSet(this.type, [this.targetReps]);
  final SetType type;
  final int? targetReps;

  bool get isMain => type == SetType.normal || type == SetType.failure;
}

/// What to aim for in a set. [weightKg] is `null` when unknown.
class SetAim {
  const SetAim({this.weightKg, this.reps});
  final double? weightKg;
  final int? reps;
}

enum OverloadAdvice {
  /// First time: start with the routine's targets.
  start,

  /// Targets hit: more load (less assistance), same reps.
  addLoad,

  /// Same load, one rep more (no targets, or pure body weight).
  addReps,

  /// Same load, closing in on the targets that were missed.
  reachTargets,

  /// Duration work: a few seconds more.
  addTime,
}

class Progression {
  const Progression({this.advice, required this.sets, this.fromKg, this.toKg});

  /// `null` when there is nothing to suggest.
  final OverloadAdvice? advice;

  /// One entry per planned set; `null` for sets without a suggestion.
  final List<SetAim?> sets;

  /// Heaviest load last time and the suggested one, for [OverloadAdvice.addLoad].
  final double? fromKg;
  final double? toKg;

  static const none = Progression(sets: []);
}

const _kgPerLb = 0.45359237;

/// Smallest sensible load jump: 2.5 kg (barbell, machine, cable), 2 kg per
/// dumbbell, 4 kg per kettlebell; 5 lb in pounds.
double loadIncrementKg(Exercise exercise, WeightUnit unit) {
  if (unit == WeightUnit.lb) return 5 * _kgPerLb;
  return switch (exercise.equipment) {
    Equipment.dumbbell => 2,
    Equipment.kettlebell => 4,
    _ => 2.5,
  };
}

/// Seconds added to duration sets once their targets are hit.
const timeIncrementSeconds = 5;

/// Suggestion for each set in [plan], from [previousMain] (last session's
/// normal and to-failure sets, in order).
Progression suggestProgression({
  required List<PlannedSet> plan,
  required List<SetEntry> previousMain,
  required Exercise exercise,
  required WeightUnit unit,
  double? plannedWeightKg,
}) {
  final mainCount = plan.where((p) => p.isMain).length;
  if (mainCount == 0) return Progression(sets: [for (final _ in plan) null]);

  // Main set k of today against main set k of last time (or the last one).
  SetEntry? prev(int k) => previousMain.isEmpty
      ? null
      : previousMain[k < previousMain.length ? k : previousMain.length - 1];

  final hasTargets = plan.any((p) => p.isMain && p.targetReps != null);

  if (previousMain.isEmpty) {
    if (!hasTargets && plannedWeightKg == null) {
      return Progression(sets: [for (final _ in plan) null]);
    }
    return Progression(
      advice: hasTargets ? OverloadAdvice.start : null,
      sets: [
        for (final p in plan)
          p.isMain
              ? SetAim(weightKg: plannedWeightKg, reps: p.targetReps)
              : null,
      ],
    );
  }

  // Did every main set that has a counterpart last time reach its target?
  var compared = 0;
  var allHit = hasTargets;
  var k = 0;
  for (final p in plan) {
    if (!p.isMain) continue;
    final before = k < previousMain.length ? previousMain[k] : null;
    k++;
    if (before == null || p.targetReps == null) continue;
    compared++;
    if (before.reps < p.targetReps!) allHit = false;
  }
  if (compared == 0) allHit = false;

  final kind = exercise.kind;
  final topKg = previousMain
      .map((s) => s.weightKg)
      .reduce((a, b) => a > b ? a : b);
  final pureBodyweight = kind == ExerciseKind.bodyweight && topKg <= 0;
  final inc = loadIncrementKg(exercise, unit);

  final OverloadAdvice advice;
  if (kind == ExerciseKind.duration) {
    advice = allHit || !hasTargets
        ? OverloadAdvice.addTime
        : OverloadAdvice.reachTargets;
  } else if (pureBodyweight) {
    advice = allHit || !hasTargets
        ? OverloadAdvice.addReps
        : OverloadAdvice.reachTargets;
  } else if (allHit) {
    advice = OverloadAdvice.addLoad;
  } else {
    advice = hasTargets ? OverloadAdvice.reachTargets : OverloadAdvice.addReps;
  }

  final step = kind == ExerciseKind.duration ? timeIncrementSeconds : 1;
  double nextLoad(double kg) => kind == ExerciseKind.assisted
      ? (kg - inc).clamp(0, double.infinity).toDouble()
      : kg + inc;

  k = 0;
  final sets = <SetAim?>[];
  for (final p in plan) {
    if (!p.isMain) {
      sets.add(null);
      continue;
    }
    final before = prev(k++)!;
    final target = p.targetReps;
    final int reps;
    var kg = before.weightKg;
    switch (advice) {
      case OverloadAdvice.addLoad:
        kg = nextLoad(kg);
        reps = target ?? before.reps;
      case OverloadAdvice.reachTargets:
        reps = target == null
            ? before.reps
            : (before.reps + step).clamp(1, target);
      case OverloadAdvice.addReps || OverloadAdvice.addTime:
        // Past the target already (or no target): one step beyond last time.
        reps = p.type == SetType.failure && target != null
            ? target
            : before.reps + step;
      case OverloadAdvice.start:
        reps = target ?? before.reps;
    }
    sets.add(
      SetAim(weightKg: kind == ExerciseKind.duration ? 0 : kg, reps: reps),
    );
  }

  return Progression(
    advice: advice,
    sets: sets,
    fromKg: advice == OverloadAdvice.addLoad ? topKg : null,
    toKg: advice == OverloadAdvice.addLoad ? nextLoad(topKg) : null,
  );
}
