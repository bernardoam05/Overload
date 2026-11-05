import 'enums.dart';
import 'exercise.dart';
import 'models.dart';
import 'one_rm.dart';

/// Progressive overload: what to aim for in each set today, from the last
/// sessions, the routine's targets (or the rep range) and the form.
///
/// In order of priority:
/// 1. Bad form twice in a row: one step less load.
/// 2. Bad form last time: same load, focus on the technique.
/// 3. Worse two sessions in a row, or no progress in three: less load (one
///    step, or a ~10 % deload). One bad day alone changes nothing, and
///    nothing is lowered again right after the load was already lowered.
/// 4. Every main set hit its target (or the top of the rep range): more
///    load, same targets (or back to the bottom of the range).
/// 5. Otherwise: same load, one rep more on the sets that fell short.
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

/// A past session of the exercise: its main sets (normal and to failure, in
/// order) and how the form felt.
class SessionLog {
  const SessionLog(this.mainSets, [this.form]);
  final List<SetEntry> mainSets;
  final FormRating? form;
}

/// Inclusive rep range used when the routine sets no targets.
typedef RepRange = ({int min, int max});

enum OverloadAdvice {
  /// First time: start with the routine's targets (or the rep range).
  start,

  /// Targets hit: more load (less assistance), same reps.
  addLoad,

  /// Same load, one rep more (no targets, or pure body weight).
  addReps,

  /// Same load, closing in on the targets that were missed.
  reachTargets,

  /// Duration work: a few seconds more.
  addTime,

  /// Worse two sessions in a row, or bad form twice: one step less load.
  reduceLoad,

  /// No progress in three sessions: about 10 % less load to build back up.
  deload,

  /// Bad form last time: same load, technique first.
  focusForm,
}

class Progression {
  const Progression({
    this.advice,
    required this.sets,
    this.fromKg,
    this.toKg,
    this.byForm = false,
  });

  /// `null` when there is nothing to suggest.
  final OverloadAdvice? advice;

  /// One entry per planned set; `null` for sets without a suggestion.
  final List<SetAim?> sets;

  /// Heaviest load last time and the suggested one, when the load changes.
  final double? fromKg;
  final double? toKg;

  /// The load goes down because of the form, not the numbers.
  final bool byForm;

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

/// Share of the load taken off by a deload.
const deloadFraction = 0.10;

/// Rep range of an exercise: the user's choice, else 12–20 for high-rep
/// exercises, else [general]. `null` for duration exercises.
RepRange? repRangeFor(Exercise exercise, RepRange general) {
  if (exercise.kind == ExerciseKind.duration) return null;
  if (exercise.repMin != null && exercise.repMax != null) {
    return (min: exercise.repMin!, max: exercise.repMax!);
  }
  if (exercise.category == ExerciseCategory.highRep) return (min: 12, max: 20);
  return general;
}

/// Single number for a session: its best estimated 1RM (body weight
/// included where it applies), or the longest hold.
double sessionStrength(
  SessionLog s,
  ExerciseKind kind, {
  double bodyWeightKg = 0,
}) {
  var best = 0.0;
  for (final set in s.mainSets) {
    final v = switch (kind) {
      ExerciseKind.duration => set.reps.toDouble(),
      ExerciseKind.weighted => estimateOneRepMax(set.weightKg, set.reps),
      ExerciseKind.bodyweight => estimateOneRepMax(
        bodyWeightKg + set.weightKg,
        set.reps,
      ),
      // Less assistance is more strength.
      ExerciseKind.assisted => estimateOneRepMax(
        (bodyWeightKg - set.weightKg).clamp(1, double.infinity).toDouble(),
        set.reps,
      ),
    };
    if (v > best) best = v;
  }
  return best;
}

bool _lower(double a, double b) => b > 0 && a / b < 0.995;

/// Suggestion for each set in [plan], from [recent] sessions (newest first).
Progression suggestProgression({
  required List<PlannedSet> plan,
  required List<SessionLog> recent,
  required Exercise exercise,
  required WeightUnit unit,
  double? plannedWeightKg,
  RepRange? range,
  double bodyWeightKg = 0,
}) {
  final mainCount = plan.where((p) => p.isMain).length;
  if (mainCount == 0) return Progression(sets: [for (final _ in plan) null]);

  final sessions = [
    for (final s in recent)
      if (s.mainSets.isNotEmpty) s,
  ];
  final hasTargets = plan.any((p) => p.isMain && p.targetReps != null);
  final kind = exercise.kind;
  // The range only matters without targets (the routine decides otherwise).
  final r = hasTargets || kind == ExerciseKind.duration ? null : range;

  if (sessions.isEmpty) {
    if (!hasTargets && r == null && plannedWeightKg == null) {
      return Progression(sets: [for (final _ in plan) null]);
    }
    return Progression(
      advice: hasTargets || r != null ? OverloadAdvice.start : null,
      sets: [
        for (final p in plan)
          p.isMain
              ? SetAim(weightKg: plannedWeightKg, reps: p.targetReps ?? r?.min)
              : null,
      ],
    );
  }

  final latest = sessions.first;
  final previousMain = latest.mainSets;
  SetEntry prev(int k) =>
      previousMain[k < previousMain.length ? k : previousMain.length - 1];

  // What each main set had to reach: its target, or the top of the range.
  int? goal(PlannedSet p) => p.targetReps ?? r?.max;
  var compared = 0;
  var allHit = hasTargets || r != null;
  var k = 0;
  for (final p in plan) {
    if (!p.isMain) continue;
    final before = k < previousMain.length ? previousMain[k] : null;
    k++;
    final g = goal(p);
    if (before == null || g == null) continue;
    compared++;
    if (before.reps < g) allHit = false;
  }
  if (compared == 0) allHit = false;

  final topKg = previousMain
      .map((s) => s.weightKg)
      .reduce((a, b) => a > b ? a : b);
  final pureBodyweight = kind == ExerciseKind.bodyweight && topKg <= 0;
  final loadable = kind != ExerciseKind.duration && !pureBodyweight;
  final inc = loadIncrementKg(exercise, unit);

  // Trend over the last sessions.
  double strength(SessionLog s) =>
      sessionStrength(s, kind, bodyWeightKg: bodyWeightKg);
  final formBad = latest.form == FormRating.bad;
  final formBadTwice =
      formBad && sessions.length > 1 && sessions[1].form == FormRating.bad;
  double topOf(SessionLog s) =>
      s.mainSets.map((x) => x.weightKg).reduce((a, b) => a > b ? a : b);
  // The load already went down last time (for assisted: the help went up).
  final alreadyLowered =
      sessions.length > 1 &&
      (kind == ExerciseKind.assisted
          ? topOf(latest) > topOf(sessions[1])
          : topOf(latest) < topOf(sessions[1]));
  final declining =
      sessions.length >= 3 &&
      _lower(strength(sessions[0]), strength(sessions[1])) &&
      _lower(strength(sessions[1]), strength(sessions[2]));
  final stalled =
      sessions.length >= 4 &&
      !allHit &&
      [
            for (final s in sessions.take(3)) strength(s),
          ].reduce((a, b) => a > b ? a : b) <=
          strength(sessions[3]) * 1.005;

  OverloadAdvice advice;
  if (loadable && formBadTwice) {
    advice = OverloadAdvice.reduceLoad;
  } else if (formBad) {
    advice = OverloadAdvice.focusForm;
  } else if (loadable && !alreadyLowered && declining) {
    advice = OverloadAdvice.reduceLoad;
  } else if (loadable && !alreadyLowered && stalled) {
    advice = OverloadAdvice.deload;
  } else if (kind == ExerciseKind.duration) {
    advice = allHit || !hasTargets
        ? OverloadAdvice.addTime
        : OverloadAdvice.reachTargets;
  } else if (pureBodyweight) {
    advice = allHit || (!hasTargets && r == null)
        ? OverloadAdvice.addReps
        : OverloadAdvice.reachTargets;
  } else if (allHit) {
    advice = OverloadAdvice.addLoad;
  } else {
    advice = hasTargets || r != null
        ? OverloadAdvice.reachTargets
        : OverloadAdvice.addReps;
  }

  final assisted = kind == ExerciseKind.assisted;
  // Positive delta = more load (for assisted, less help).
  double shift(double kg, double delta) => assisted
      ? (kg - delta).clamp(0, double.infinity).toDouble()
      : (kg + delta).clamp(0, double.infinity).toDouble();
  final double delta = switch (advice) {
    OverloadAdvice.addLoad => inc,
    OverloadAdvice.reduceLoad => -inc,
    OverloadAdvice.deload =>
      -((topKg * deloadFraction / inc).round().clamp(1, 1000) * inc),
    _ => 0,
  };

  final step = kind == ExerciseKind.duration ? timeIncrementSeconds : 1;
  k = 0;
  final sets = <SetAim?>[];
  for (final p in plan) {
    if (!p.isMain) {
      sets.add(null);
      continue;
    }
    final before = prev(k++);
    final target = p.targetReps;
    final int reps;
    switch (advice) {
      case OverloadAdvice.addLoad:
        reps = target ?? r?.min ?? before.reps;
      case OverloadAdvice.reduceLoad || OverloadAdvice.deload:
        // Lighter: aim at the goal again (and the range's middle if none).
        reps = target ?? (r == null ? before.reps : (r.min + r.max) ~/ 2);
      case OverloadAdvice.focusForm:
        reps = target ?? before.reps;
      case OverloadAdvice.reachTargets:
        final g = goal(p);
        reps = g == null ? before.reps : (before.reps + step).clamp(1, g);
      case OverloadAdvice.addReps || OverloadAdvice.addTime:
        // Past the target already (or no target): one step beyond last time.
        reps = p.type == SetType.failure && target != null
            ? target
            : before.reps + step;
      case OverloadAdvice.start:
        reps = target ?? before.reps;
    }
    sets.add(
      SetAim(
        weightKg: kind == ExerciseKind.duration
            ? 0
            : shift(before.weightKg, delta),
        reps: reps,
      ),
    );
  }

  final changesLoad = delta != 0;
  return Progression(
    advice: advice,
    sets: sets,
    fromKg: changesLoad ? topKg : null,
    toKg: changesLoad ? shift(topKg, delta) : null,
    byForm: loadable && formBadTwice,
  );
}

/// The last [limit] sessions of [exerciseId], newest first. Sessions of the
/// same routine (within [routineWindow]) come first when there are any, as
/// in `previousPerformances`.
List<SessionLog> recentSessions(
  List<WorkoutRecord> newestFirst,
  int exerciseId, {
  int? routineId,
  int? excludeWorkoutId,
  int limit = 4,
  DateTime? now,
  Duration routineWindow = const Duration(days: 56),
}) {
  final cutoff = (now ?? DateTime.now()).subtract(routineWindow);
  List<SessionLog> collect(bool sameRoutine) {
    final out = <SessionLog>[];
    for (final w in newestFirst) {
      if (w.id == excludeWorkoutId) continue;
      if (sameRoutine &&
          (w.routineId != routineId || !w.startedAt.isAfter(cutoff))) {
        continue;
      }
      for (final e in w.exercises) {
        if (e.exerciseId != exerciseId) continue;
        final main = [
          for (final s in e.sets)
            if (s.type == SetType.normal || s.type == SetType.failure) s,
        ];
        if (main.isEmpty) continue;
        out.add(SessionLog(main, e.form));
        break;
      }
      if (out.length >= limit) break;
    }
    return out;
  }

  final routine = routineId == null ? const <SessionLog>[] : collect(true);
  return routine.isNotEmpty ? routine : collect(false);
}
