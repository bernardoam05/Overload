import 'dart:math' as math;

import 'enums.dart';
import 'exercise.dart';
import 'models.dart';

class Tier {
  const Tier(this.name, this.color, this.glow);
  final String name;

  /// ARGB colours, kept as ints so the domain stays UI-agnostic.
  final int color;
  final int glow;
}

const tiers = <Tier>[
  Tier('Ferro', 0xFF7C8594, 0xFF4B5260),
  Tier('Bronze', 0xFFC27C46, 0xFF7A4522),
  Tier('Prata', 0xFFC9D1DC, 0xFF7D8896),
  Tier('Ouro', 0xFFF6C744, 0xFFA87A12),
  Tier('Platina', 0xFF4FD6C8, 0xFF1C7F77),
  Tier('Esmeralda', 0xFF3DDC84, 0xFF167A44),
  Tier('Diamante', 0xFF62A8FF, 0xFF2456B8),
  Tier('Mestre', 0xFFB18CFF, 0xFF5B34B5),
  Tier('Lenda', 0xFFFF4D6D, 0xFF9E1531),
];

const _divisionNames = ['III', 'II', 'I'];

/// Ratio (benchmark 1RM ÷ body weight) at which each tier starts, for male
/// lifters. Roughly follows commonly published strength standards.
const _maleStandards = <RankGroup, List<double>>{
  RankGroup.chest: [0, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.3],
  RankGroup.back: [0, 0.4, 0.6, 0.8, 1.0, 1.2, 1.4, 1.65, 1.9],
  RankGroup.shoulders: [0, 0.3, 0.45, 0.6, 0.75, 0.9, 1.05, 1.2, 1.4],
  RankGroup.biceps: [0, 0.2, 0.3, 0.4, 0.55, 0.7, 0.85, 1.0, 1.15],
  RankGroup.triceps: [0, 0.4, 0.6, 0.85, 1.1, 1.35, 1.6, 1.85, 2.1],
  RankGroup.quads: [0, 0.6, 0.9, 1.25, 1.5, 1.85, 2.2, 2.5, 2.85],
  RankGroup.posterior: [0, 0.75, 1.0, 1.4, 1.75, 2.1, 2.5, 2.85, 3.2],
};

bool _isLower(RankGroup g) => g == RankGroup.quads || g == RankGroup.posterior;

double _sexFactor(Sex sex, RankGroup group) => switch (sex) {
  Sex.male => 1.0,
  Sex.female => _isLower(group) ? 0.7 : 0.6,
  Sex.unspecified => _isLower(group) ? 0.85 : 0.8,
};

/// Tier start ratios for [group], adjusted for [sex].
List<double> standardsFor(RankGroup group, Sex sex) {
  final f = _sexFactor(sex, group);
  return [for (final r in _maleStandards[group]!) r * f];
}

/// Continuous score in `[0, 9]`: the integer part is the tier index, the
/// fractional part is the progress within the tier.
double scoreForRatio(double ratio, List<double> thresholds) {
  if (ratio <= 0) return 0;
  final last = thresholds.length - 1;
  for (var i = 0; i < last; i++) {
    if (ratio < thresholds[i + 1]) {
      return i + (ratio - thresholds[i]) / (thresholds[i + 1] - thresholds[i]);
    }
  }
  final step = thresholds[last] - thresholds[last - 1];
  return math.min(last + 1.0, last + (ratio - thresholds[last]) / step);
}

/// Inverse of [scoreForRatio].
double ratioForScore(double score, List<double> thresholds) {
  final last = thresholds.length - 1;
  final i = score.floor().clamp(0, last);
  final frac = score - i;
  if (i >= last) {
    return thresholds[last] + frac * (thresholds[last] - thresholds[last - 1]);
  }
  return thresholds[i] + frac * (thresholds[i + 1] - thresholds[i]);
}

class RankStanding {
  const RankStanding({
    required this.score,
    this.group,
    this.ratio = 0,
    this.bestExerciseId,
    this.benchmarkE1rm = 0,
    this.thresholds = const [],
  });

  /// `null` for the overall rank.
  final RankGroup? group;
  final double score;
  final double ratio;
  final int? bestExerciseId;

  /// Best estimated 1RM, converted to the benchmark lift, in kg.
  final double benchmarkE1rm;
  final List<double> thresholds;

  int get tierIndex => math.min(score.floor(), tiers.length - 1);
  Tier get tier => tiers[tierIndex];
  bool get isMaxTier => tierIndex == tiers.length - 1;

  /// 0 = III, 1 = II, 2 = I. The last tier has no divisions.
  int get division =>
      isMaxTier ? 2 : math.min(((score - tierIndex) * 3).floor(), 2);

  String get label =>
      isMaxTier ? tier.name : '${tier.name} ${_divisionNames[division]}';

  /// Score at which the next division starts, or `null` at the top.
  double? get nextScore => isMaxTier ? null : tierIndex + (division + 1) / 3;

  /// Progress through the current division, `0..1`.
  double get divisionProgress {
    if (isMaxTier) return 1;
    final start = tierIndex + division / 3;
    return ((score - start) * 3).clamp(0.0, 1.0);
  }

  String get nextLabel {
    if (isMaxTier) return tier.name;
    if (division == 2) {
      final next = tiers[tierIndex + 1];
      return tierIndex + 1 == tiers.length - 1 ? next.name : '${next.name} III';
    }
    return '${tier.name} ${_divisionNames[division + 1]}';
  }

  /// Benchmark 1RM in kg needed to reach the next division.
  double? nextE1rm(double bodyWeightKg) {
    final s = nextScore;
    if (s == null || thresholds.isEmpty) return null;
    return ratioForScore(s, thresholds) * bodyWeightKg;
  }
}

class RankSummary {
  const RankSummary(this.groups, this.overall);
  final Map<RankGroup, RankStanding> groups;
  final RankStanding overall;
}

RankSummary computeRanks({
  required Iterable<WorkoutRecord> history,
  required Map<int, Exercise> library,
  required double bodyWeightKg,
  required Sex sex,
}) {
  final best = <RankGroup, ({double e1rm, int exerciseId})>{};
  for (final workout in history) {
    final bw = workout.bodyWeightKg ?? bodyWeightKg;
    for (final entry in workout.exercises) {
      final exercise = library[entry.exerciseId];
      final group = exercise?.rankGroup;
      if (exercise == null || group == null) continue;
      for (final set in entry.workingSets) {
        final e1rm = set.e1rm(exercise.kind, bw) * exercise.rankFactor!;
        final current = best[group];
        if (current == null || e1rm > current.e1rm) {
          best[group] = (e1rm: e1rm, exerciseId: exercise.id);
        }
      }
    }
  }

  final groups = <RankGroup, RankStanding>{};
  for (final group in RankGroup.values) {
    final thresholds = standardsFor(group, sex);
    final b = best[group];
    final ratio = b == null || bodyWeightKg <= 0 ? 0.0 : b.e1rm / bodyWeightKg;
    groups[group] = RankStanding(
      group: group,
      score: scoreForRatio(ratio, thresholds),
      ratio: ratio,
      bestExerciseId: b?.exerciseId,
      benchmarkE1rm: b?.e1rm ?? 0,
      thresholds: thresholds,
    );
  }
  final mean = groups.values.fold(0.0, (s, g) => s + g.score) / groups.length;
  return RankSummary(groups, RankStanding(score: mean));
}
