import 'package:flutter_test/flutter_test.dart';
import 'package:overload/domain/enums.dart';
import 'package:overload/domain/models.dart';
import 'package:overload/domain/one_rm.dart';
import 'package:overload/domain/progression.dart';
import 'package:overload/domain/ranks.dart';
import 'package:overload/domain/records.dart';
import 'package:overload/domain/stats.dart';

import '../helpers.dart';

void main() {
  group('one rep max', () {
    test('single rep is the weight itself', () {
      expect(estimateOneRepMax(100, 1), 100);
    });

    test('Epley estimate and inverse agree', () {
      final e = estimateOneRepMax(100, 10);
      expect(e, closeTo(133.33, 0.01));
      expect(weightForReps(e, 10), closeTo(100, 0.001));
    });

    test('reps are capped for very high rep sets', () {
      expect(
        estimateOneRepMax(50, 40),
        estimateOneRepMax(50, maxRepsForEstimate),
      );
    });

    test('invalid input yields zero', () {
      expect(estimateOneRepMax(0, 5), 0);
      expect(estimateOneRepMax(80, 0), 0);
    });

    test('plate calculator loads greedily and reports remainder', () {
      final r = platesPerSide(100, 20, [25, 20, 15, 10, 5, 2.5, 1.25]);
      expect(r.plates, [25, 15]);
      expect(r.remainder, 0);

      final odd = platesPerSide(21, 20, [25, 20, 1.25]);
      expect(odd.plates, isEmpty);
      expect(odd.remainder, closeTo(1, 1e-9));
    });
  });

  group('ranks', () {
    final library = {1: exercise(1, muscle: Muscle.chest)};

    test('score interpolates between thresholds', () {
      final t = standardsFor(RankGroup.chest, Sex.male);
      expect(scoreForRatio(0, t), 0);
      expect(scoreForRatio(1.0, t), closeTo(3, 1e-9)); // Ouro starts at 1.0×
      expect(scoreForRatio(1.125, t), closeTo(3.5, 1e-9));
      expect(ratioForScore(3.5, t), closeTo(1.125, 1e-9));
    });

    test('score is capped at the top tier', () {
      final t = standardsFor(RankGroup.chest, Sex.male);
      expect(scoreForRatio(10, t), tiers.length.toDouble());
    });

    test('best working set defines the group rank', () {
      final history = [
        workout(1, DateTime(2026, 1, 1), {
          1: [(80, 1)],
        }),
        workout(2, DateTime(2026, 1, 8), {
          1: [(100, 1)],
        }),
      ];
      final ranks = computeRanks(
        history: history,
        library: library,
        bodyWeightKg: 100,
        sex: Sex.male,
      );
      final chest = ranks.groups[RankGroup.chest]!;
      expect(chest.ratio, closeTo(1.0, 1e-9));
      expect(chest.tier.name, 'Ouro');
      expect(chest.label, 'Ouro III');
      expect(chest.bestExerciseId, 1);
    });

    test('warm-up sets do not count', () {
      final history = [
        workout(1, DateTime(2026, 1, 1), {
          1: [(200, 1)],
        }, type: SetType.warmup),
      ];
      final ranks = computeRanks(
        history: history,
        library: library,
        bodyWeightKg: 80,
        sex: Sex.male,
      );
      expect(ranks.groups[RankGroup.chest]!.score, 0);
    });

    test('female standards are lower', () {
      final history = [
        workout(1, DateTime(2026, 1, 1), {
          1: [(60, 1)],
        }),
      ];
      double score(Sex s) => computeRanks(
        history: history,
        library: library,
        bodyWeightKg: 60,
        sex: s,
      ).groups[RankGroup.chest]!.score;
      expect(score(Sex.female), greaterThan(score(Sex.male)));
    });

    test('divisions and next label', () {
      const s = RankStanding(score: 3.7);
      expect(s.label, 'Ouro I');
      expect(s.nextLabel, 'Platina III');
      expect(s.divisionProgress, closeTo(0.1, 1e-9));
      const top = RankStanding(score: 8.5);
      expect(top.label, 'Lenda');
      expect(top.nextScore, isNull);
    });

    test('overall is the mean of all groups', () {
      final history = [
        workout(1, DateTime(2026, 1, 1), {
          1: [(100, 1)],
        }),
      ];
      final ranks = computeRanks(
        history: history,
        library: library,
        bodyWeightKg: 100,
        sex: Sex.male,
      );
      expect(ranks.overall.score, closeTo(3 / RankGroup.values.length, 1e-9));
    });
  });

  group('progression', () {
    test('levels accumulate xp', () {
      expect(levelForXp(0).level, 1);
      expect(levelForXp(99).level, 1);
      expect(levelForXp(100).level, 2);
      final l = levelForXp(100 + 125 + 10);
      expect(l.level, 3);
      expect(l.xpIntoLevel, 10);
      expect(l.xpForLevel, 150);
    });

    test('xp rewards sets, time and records', () {
      expect(
        workoutXp(
          workingSets: 0,
          duration: const Duration(hours: 1),
          personalRecords: 0,
        ),
        0,
      );
      expect(
        workoutXp(
          workingSets: 10,
          duration: const Duration(minutes: 45),
          personalRecords: 2,
        ),
        40 + 40 + 45 + 60,
      );
    });

    test('week starts on monday', () {
      expect(weekStart(DateTime(2026, 10, 21, 18)), DateTime(2026, 10, 19));
      expect(weekStart(DateTime(2026, 10, 19)), DateTime(2026, 10, 19));
      expect(weekStart(DateTime(2026, 10, 25, 23)), DateTime(2026, 10, 19));
    });

    test('streak counts consecutive weeks meeting the goal', () {
      final now = DateTime(2026, 10, 21); // Wednesday
      final history = [
        // Two weeks ago: 2 days
        workout(1, DateTime(2026, 10, 6), {}),
        workout(2, DateTime(2026, 10, 8), {}),
        // Last week: 2 days
        workout(3, DateTime(2026, 10, 13), {}),
        workout(4, DateTime(2026, 10, 15), {}),
        // This week: 1 day so far (goal not met yet, streak not broken)
        workout(5, DateTime(2026, 10, 20), {}),
      ];
      final s = computeStreak(history, weeklyGoal: 2, now: now);
      expect(s.current, 2);
      expect(s.daysThisWeek, 1);
      expect(s.goalMetThisWeek, isFalse);
      expect(s.best, 2);
    });

    test('a missed week breaks the streak', () {
      final now = DateTime(2026, 10, 21);
      final history = [
        workout(1, DateTime(2026, 10, 6), {}),
        workout(2, DateTime(2026, 10, 20), {}),
      ];
      final s = computeStreak(history, weeklyGoal: 1, now: now);
      expect(s.current, 1);
      expect(s.best, 1);
    });

    test('several workouts on one day count as one day', () {
      final now = DateTime(2026, 10, 21);
      final history = [
        workout(1, DateTime(2026, 10, 20, 8), {}),
        workout(2, DateTime(2026, 10, 20, 19), {}),
      ];
      expect(computeStreak(history, weeklyGoal: 2, now: now).daysThisWeek, 1);
    });
  });

  group('records', () {
    final library = {
      1: exercise(1),
      2: exercise(2, kind: ExerciseKind.bodyweight, muscle: Muscle.back),
    };

    test('first time doing an exercise is not a record', () {
      final w = workout(1, DateTime(2026, 1, 1), {
        1: [(100, 5)],
      });
      expect(newRecords(w, const [], library, bodyWeightKg: 80), isEmpty);
    });

    test('detects improved weight, e1rm and volume', () {
      final old = workout(1, DateTime(2026, 1, 1), {
        1: [(100, 5)],
      });
      final now = workout(2, DateTime(2026, 1, 8), {
        1: [(105, 5)],
      });
      final prs = newRecords(now, [old], library, bodyWeightKg: 80);
      expect(prs.map((p) => p.type).toSet(), {
        RecordType.e1rm,
        RecordType.weight,
        RecordType.volume,
      });
    });

    test('more reps at lower weight can be an e1rm record only', () {
      final old = workout(1, DateTime(2026, 1, 1), {
        1: [(100, 3)],
      });
      final now = workout(2, DateTime(2026, 1, 8), {
        1: [(90, 10)],
      });
      final types = newRecords(
        now,
        [old],
        library,
        bodyWeightKg: 80,
      ).map((p) => p.type).toSet();
      expect(types, {RecordType.e1rm, RecordType.volume});
    });

    test('body-weight exercises track reps', () {
      final old = workout(1, DateTime(2026, 1, 1), {
        2: [(0, 8)],
      });
      final now = workout(2, DateTime(2026, 1, 8), {
        2: [(0, 10)],
      });
      final prs = newRecords(now, [old], library, bodyWeightKg: 80);
      expect(prs.single.type, RecordType.reps);
    });

    test('counts record breaks chronologically', () {
      final history = [
        workout(1, DateTime(2026, 1, 1), {
          1: [(100, 5)],
        }),
        workout(2, DateTime(2026, 1, 8), {
          1: [(110, 5)],
        }),
        workout(3, DateTime(2026, 1, 15), {
          1: [(105, 5)],
        }),
      ];
      expect(countRecordBreaks(history, library, bodyWeightKg: 80), 3);
    });
  });

  group('stats', () {
    final library = {1: exercise(1, muscle: Muscle.chest)};

    test('weekly buckets include empty weeks', () {
      final now = DateTime(2026, 10, 21);
      final buckets = weeklyBuckets(
        [
          workout(1, DateTime(2026, 10, 20), {
            1: [(100, 10)],
          }),
        ],
        library,
        weeks: 4,
        now: now,
      );
      expect(buckets, hasLength(4));
      expect(buckets.last.volume, 1000);
      expect(buckets.first.volume, 0);
    });

    test('progress series is oldest first', () {
      final series = progressSeries(
        [
          workout(2, DateTime(2026, 2, 1), {
            1: [(110, 1)],
          }),
          workout(1, DateTime(2026, 1, 1), {
            1: [(100, 1)],
          }),
        ],
        library[1]!,
        bodyWeightKg: 80,
      );
      expect(series.map((p) => p.value), [100, 110]);
    });

    test('volume excludes warm-ups', () {
      const set = SetEntry(type: SetType.warmup, weightKg: 60, reps: 10);
      expect(set.volume(ExerciseKind.weighted), 0);
    });
  });
}
