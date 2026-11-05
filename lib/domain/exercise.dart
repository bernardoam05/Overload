import 'enums.dart';

/// An exercise from the library (seeded or created by the user).
class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.primaryMuscle,
    required this.secondaryMuscles,
    required this.equipment,
    required this.kind,
    required this.rankFactor,
    required this.instructions,
    required this.isCustom,
    required this.seedKey,
    required this.restSeconds,
    required this.archived,
    this.loadMode = LoadMode.bilateral,
    this.setup = '',
    this.benchAngle,
  });

  final int id;
  final String name;
  final Muscle primaryMuscle;
  final List<Muscle> secondaryMuscles;
  final Equipment equipment;
  final ExerciseKind kind;

  /// Multiplier that converts this exercise's estimated 1RM into the
  /// equivalent 1RM of its rank group's benchmark lift. `null` means the
  /// exercise does not count towards ranks.
  final double? rankFactor;
  final String instructions;
  final bool isCustom;
  final String? seedKey;

  /// Rest timer override in seconds; `null` uses the global default.
  final int? restSeconds;
  final bool archived;

  /// How the load is held (see [LoadMode]).
  final LoadMode loadMode;

  /// Equipment setup to remember (seat height, pins, grip…).
  final String setup;

  /// Bench angle in degrees (negative is a decline), if one is used.
  final int? benchAngle;

  /// "Banco 30° · Assento 4", or `null` when nothing is recorded.
  String? get setupSummary {
    final parts = [
      if (benchAngle case final a?) 'Banco ${formatAngle(a)}',
      if (setup.trim().isNotEmpty) setup.trim(),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  RankGroup? get rankGroup =>
      rankFactor == null ? null : primaryMuscle.rankGroup;

  bool get usesWeight => kind != ExerciseKind.duration;

  /// Short explanation of what the logged weight means, or `null` when it is
  /// obvious (a barbell or a machine moved with both sides).
  String? get loadLabel => loadLabelFor(loadMode, equipment);
}

/// "30°", "0° (plano)" or "-15° (declinado)".
String formatAngle(int degrees) => switch (degrees) {
  0 => '0° (plano)',
  < 0 => '$degrees° (declinado)',
  _ => '$degrees°',
};

String? loadLabelFor(LoadMode mode, Equipment equipment) {
  final (one, plural) = switch (equipment) {
    Equipment.dumbbell => ('1 haltere', 'haltere'),
    Equipment.kettlebell => ('1 kettlebell', 'kettlebell'),
    _ => (null, null),
  };
  return switch (mode) {
    LoadMode.bilateral => one == null ? null : '$one seguro com as duas mãos',
    LoadMode.perHand =>
      plural == null
          ? 'Um em cada mão · peso de cada lado'
          : 'Um $plural em cada mão · peso de cada',
    LoadMode.unilateral => 'Unilateral · peso e reps por lado',
  };
}
