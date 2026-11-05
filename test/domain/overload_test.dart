import 'package:flutter_test/flutter_test.dart';
import 'package:overload/data/repositories/routine_repository.dart';
import 'package:overload/domain/enums.dart';
import 'package:overload/domain/exercise.dart';
import 'package:overload/domain/models.dart';
import 'package:overload/domain/overload.dart';

import '../helpers.dart';

const _n = SetType.normal;
const _a = SetType.warmup;
const _d = SetType.drop;
const _f = SetType.failure;

SetEntry _s(double kg, int reps, [SetType t = _n]) =>
    SetEntry(type: t, weightKg: kg, reps: reps);

Exercise _withEquipment(Equipment equipment, {ExerciseKind? kind}) {
  final e = exercise(1, kind: kind ?? ExerciseKind.weighted);
  return Exercise(
    id: e.id,
    name: e.name,
    primaryMuscle: e.primaryMuscle,
    secondaryMuscles: e.secondaryMuscles,
    equipment: equipment,
    kind: e.kind,
    rankFactor: e.rankFactor,
    instructions: '',
    isCustom: false,
    seedKey: null,
    restSeconds: null,
    archived: false,
  );
}

List<PlannedSet> _plan(List<SetType> types, int reps, int step) {
  final targets = plannedTargets(types, reps, step);
  return [for (final (i, t) in types.indexed) PlannedSet(t, targets[i])];
}

List<(double?, int?)?> _aims(Progression p) => [
  for (final a in p.sets) a == null ? null : (a.weightKg, a.reps),
];

void main() {
  final barbell = exercise(1); // Equipment.barbell
  const kg = WeightUnit.kg;

  group('plannedTargets', () {
    test('equal reps by default', () {
      expect(plannedTargets([_n, _n, _n], 10, 0), [10, 10, 10]);
    });

    test('descending reps drop on main sets only', () {
      expect(plannedTargets([_a, _n, _n, _n, _d], 10, 1), [
        null,
        10,
        9,
        8,
        null,
      ]);
      expect(plannedTargets([_n, _n, _f], 8, 2), [8, 6, 4]);
    });

    test('never below one rep', () {
      expect(plannedTargets([_n, _n, _n], 2, 3), [2, 1, 1]);
    });

    test('describeTargets shows the descent', () {
      final item = RoutineItem(exerciseId: 1, sets: 3, reps: 10, repStep: 1);
      expect(describeTargets(item), '10 · 9 · 8 reps');
      expect(describeTargets(item.copyWith(repStep: 0)), '10 reps');
    });
  });

  group('suggestProgression', () {
    test('first time: the routine targets, set by set', () {
      final p = suggestProgression(
        plan: _plan([_n, _n, _n], 10, 1),
        recent: const [],
        exercise: barbell,
        unit: kg,
        plannedWeightKg: 40,
      );
      expect(p.advice, OverloadAdvice.start);
      expect(_aims(p), [(40.0, 10), (40.0, 9), (40.0, 8)]);
    });

    test('descending reps: each set aims at its own target, not the first', () {
      // Last time 60 kg × 10 · 9 · 7: the third set missed its target of 8.
      final p = suggestProgression(
        plan: _plan([_n, _n, _n], 10, 1),
        recent: [
          SessionLog([_s(60, 10), _s(60, 9), _s(60, 7)]),
        ],
        exercise: barbell,
        unit: kg,
      );
      expect(p.advice, OverloadAdvice.reachTargets);
      expect(_aims(p), [(60.0, 10), (60.0, 9), (60.0, 8)]);
    });

    test('descending reps all hit: more load, same descent', () {
      final p = suggestProgression(
        plan: _plan([_n, _n, _n], 10, 1),
        recent: [
          SessionLog([_s(60, 10), _s(60, 9), _s(60, 8)]),
        ],
        exercise: barbell,
        unit: kg,
      );
      expect(p.advice, OverloadAdvice.addLoad);
      expect((p.fromKg, p.toKg), (60.0, 62.5));
      expect(_aims(p), [(62.5, 10), (62.5, 9), (62.5, 8)]);
    });

    test('a miss aims one rep higher, capped at the target', () {
      final p = suggestProgression(
        plan: _plan([_n, _n, _n], 10, 0),
        recent: [
          SessionLog([_s(50, 10), _s(50, 8), _s(50, 6)]),
        ],
        exercise: barbell,
        unit: kg,
      );
      expect(_aims(p), [(50.0, 10), (50.0, 9), (50.0, 7)]);
    });

    test('warm-ups and drops get no suggestion', () {
      final p = suggestProgression(
        plan: _plan([_a, _n, _d], 8, 0),
        recent: [
          SessionLog([_s(80, 8)]),
        ],
        exercise: barbell,
        unit: kg,
      );
      expect(_aims(p), [null, (82.5, 8), null]);
    });

    test('without targets (free workout): one more rep than last time', () {
      final p = suggestProgression(
        plan: const [PlannedSet(_n), PlannedSet(_n)],
        recent: [
          SessionLog([_s(30, 12), _s(30, 11)]),
        ],
        exercise: barbell,
        unit: kg,
      );
      expect(p.advice, OverloadAdvice.addReps);
      expect(_aims(p), [(30.0, 13), (30.0, 12)]);
    });

    test('extra sets today follow the last set of last time', () {
      final p = suggestProgression(
        plan: const [PlannedSet(_n), PlannedSet(_n), PlannedSet(_n)],
        recent: [
          SessionLog([_s(30, 12)]),
        ],
        exercise: barbell,
        unit: kg,
      );
      expect(_aims(p), [(30.0, 13), (30.0, 13), (30.0, 13)]);
    });

    test('dumbbells go up 2 kg, kettlebells 4 kg, pounds 5 lb', () {
      final hit = [_s(20, 10)];
      final plan = _plan([_n], 10, 0);
      double? to(Exercise e, WeightUnit u) => suggestProgression(
        plan: plan,
        recent: [SessionLog(hit)],
        exercise: e,
        unit: u,
      ).toKg;
      expect(to(_withEquipment(Equipment.dumbbell), kg), 22);
      expect(to(_withEquipment(Equipment.kettlebell), kg), 24);
      expect(to(barbell, WeightUnit.lb), closeTo(20 + 2.268, 0.001));
    });

    test('assisted exercises progress with less assistance', () {
      final p = suggestProgression(
        plan: _plan([_n], 8, 0),
        recent: [
          SessionLog([_s(20, 8)]),
        ],
        exercise: _withEquipment(
          Equipment.machine,
          kind: ExerciseKind.assisted,
        ),
        unit: kg,
      );
      expect(p.advice, OverloadAdvice.addLoad);
      expect(_aims(p), [(17.5, 8)]);
    });

    test('pure body weight progresses in reps', () {
      final p = suggestProgression(
        plan: _plan([_n, _n], 10, 0),
        recent: [
          SessionLog([_s(0, 10), _s(0, 10)]),
        ],
        exercise: exercise(1, kind: ExerciseKind.bodyweight),
        unit: kg,
      );
      expect(p.advice, OverloadAdvice.addReps);
      expect(_aims(p), [(0.0, 11), (0.0, 11)]);
    });

    test('duration progresses in seconds', () {
      final p = suggestProgression(
        plan: _plan([_n], 60, 0),
        recent: [
          SessionLog([_s(0, 60)]),
        ],
        exercise: exercise(1, kind: ExerciseKind.duration),
        unit: kg,
      );
      expect(p.advice, OverloadAdvice.addTime);
      expect(_aims(p), [(0.0, 65)]);
    });
  });

  group('regression and form', () {
    final plan = _plan([_n, _n, _n], 10, 1);
    Progression run(List<SessionLog> recent) => suggestProgression(
      plan: plan,
      recent: recent,
      exercise: barbell,
      unit: kg,
    );
    SessionLog at(double w, List<int> reps, [FormRating? f]) =>
        SessionLog([for (final r in reps) _s(w, r)], f);

    test('one bad day changes nothing: same load, aim for the targets', () {
      final p = run([
        at(60, [8, 7, 6]),
        at(60, [10, 9, 8]),
        at(57.5, [10, 9, 8]),
      ]);
      expect(p.advice, OverloadAdvice.reachTargets);
      expect(_aims(p).first, (60.0, 9));
    });

    test('worse two sessions in a row: one step less load', () {
      final p = run([
        at(60, [8, 7, 6]),
        at(60, [9, 8, 7]),
        at(60, [10, 9, 7]),
      ]);
      expect(p.advice, OverloadAdvice.reduceLoad);
      expect((p.fromKg, p.toKg), (60.0, 57.5));
      expect(_aims(p), [(57.5, 10), (57.5, 9), (57.5, 8)]);
    });

    test('no progress in three sessions: deload about 10 %', () {
      final p = run([
        at(80, [9, 8, 7]),
        at(80, [9, 8, 7]),
        at(80, [9, 8, 7]),
        at(80, [9, 8, 7]),
      ]);
      expect(p.advice, OverloadAdvice.deload);
      expect(p.toKg, 72.5);
    });

    test('never lowers again right after the load went down', () {
      final p = run([
        at(57.5, [9, 8, 7]),
        at(60, [9, 8, 7]),
        at(60, [10, 9, 7]),
        at(60, [10, 9, 8]),
      ]);
      expect(p.advice, OverloadAdvice.reachTargets);
    });

    test('bad form: no more load even with every target hit', () {
      final p = run([
        at(60, [10, 9, 8], FormRating.bad),
      ]);
      expect(p.advice, OverloadAdvice.focusForm);
      expect(_aims(p).first, (60.0, 10));
    });

    test('bad form twice: one step less load', () {
      final p = run([
        at(60, [10, 9, 8], FormRating.bad),
        at(60, [10, 9, 8], FormRating.bad),
      ]);
      expect(p.advice, OverloadAdvice.reduceLoad);
      expect(p.byForm, isTrue);
      expect(p.toKg, 57.5);
    });

    test('good form and targets hit: more load', () {
      final p = run([
        at(60, [10, 9, 8], FormRating.good),
      ]);
      expect(p.advice, OverloadAdvice.addLoad);
    });
  });

  group('rep range (no routine targets)', () {
    const range = (min: 8, max: 12);
    const plan = [PlannedSet(_n), PlannedSet(_n)];

    test('climbs one rep at a time up to the top', () {
      final p = suggestProgression(
        plan: plan,
        recent: [
          SessionLog([_s(40, 10), _s(40, 9)]),
        ],
        exercise: barbell,
        unit: kg,
        range: range,
      );
      expect(p.advice, OverloadAdvice.reachTargets);
      expect(_aims(p), [(40.0, 11), (40.0, 10)]);
    });

    test('top of the range in every set: more load, back to the bottom', () {
      final p = suggestProgression(
        plan: plan,
        recent: [
          SessionLog([_s(40, 12), _s(40, 12)]),
        ],
        exercise: barbell,
        unit: kg,
        range: range,
      );
      expect(p.advice, OverloadAdvice.addLoad);
      expect(_aims(p), [(42.5, 8), (42.5, 8)]);
    });

    test('routine targets win over the range', () {
      final p = suggestProgression(
        plan: _plan([_n, _n], 10, 0),
        recent: [
          SessionLog([_s(40, 10), _s(40, 10)]),
        ],
        exercise: barbell,
        unit: kg,
        range: range,
      );
      expect(p.advice, OverloadAdvice.addLoad, reason: 'choice (a)');
      expect(_aims(p), [(42.5, 10), (42.5, 10)]);
    });

    test('defaults: user range, else 12–20 for high-rep, else general', () {
      final e = exercise(1);
      expect(repRangeFor(e, range), range);
      final lateral = Exercise(
        id: 2,
        name: 'Laterais',
        primaryMuscle: Muscle.sideDelts,
        secondaryMuscles: const [],
        equipment: Equipment.dumbbell,
        kind: ExerciseKind.weighted,
        rankFactor: null,
        instructions: '',
        isCustom: false,
        seedKey: null,
        restSeconds: null,
        archived: false,
        category: ExerciseCategory.highRep,
      );
      expect(repRangeFor(lateral, range), (min: 12, max: 20));
      expect(
        repRangeFor(exercise(3, kind: ExerciseKind.duration), range),
        isNull,
      );
    });
  });

  test('recentSessions prefers the same routine and keeps the form', () {
    WorkoutRecord w(int id, int? routine, int day, FormRating? f) =>
        WorkoutRecord(
          id: id,
          name: 'W',
          startedAt: DateTime(2026, 11, day),
          endedAt: DateTime(2026, 11, day, 1),
          routineId: routine,
          exercises: [
            ExerciseEntry(
              exerciseId: 1,
              form: f,
              sets: [_s(20, 5, _a), _s(50, 10)],
            ),
          ],
        );
    final history = [
      w(4, null, 4, null),
      w(3, 7, 3, FormRating.good),
      w(2, null, 2, null),
      w(1, 7, 1, FormRating.bad),
    ];
    final r = recentSessions(
      history,
      1,
      routineId: 7,
      now: DateTime(2026, 11, 5),
    );
    expect(r.map((s) => s.form), [FormRating.good, FormRating.bad]);
    expect(r.first.mainSets, hasLength(1), reason: 'warm-ups left out');
    expect(recentSessions(history, 1), hasLength(4));
  });
}
