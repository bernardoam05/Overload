import 'dart:math' as math;

import 'progression.dart';
import 'ranks.dart';

enum AchievementCategory {
  workouts,
  streak,
  records,
  volume,
  session,
  ranks,
  variety,
  level,
}

/// Aggregated facts that achievements are evaluated against.
class AchievementFacts {
  const AchievementFacts({
    required this.workouts,
    required this.bestStreak,
    required this.recordBreaks,
    required this.totalVolumeKg,
    required this.longestWorkout,
    required this.bestSessionVolumeKg,
    required this.earlyWorkouts,
    required this.lateWorkouts,
    required this.distinctExercises,
    required this.ranks,
    required this.level,
  });

  final int workouts;
  final int bestStreak;
  final int recordBreaks;
  final double totalVolumeKg;
  final Duration longestWorkout;
  final double bestSessionVolumeKg;
  final int earlyWorkouts;
  final int lateWorkouts;
  final int distinctExercises;
  final RankSummary ranks;
  final LevelInfo level;

  int get highestTier =>
      ranks.groups.values.fold(0, (m, g) => math.max(m, g.tierIndex));
  int get lowestTier =>
      ranks.groups.values.fold(99, (m, g) => math.min(m, g.tierIndex));
}

class Achievement {
  const Achievement(
    this.id,
    this.title,
    this.description,
    this.category,
    this.target,
    this.measure,
  );

  final String id;
  final String title;
  final String description;
  final AchievementCategory category;
  final num target;
  final num Function(AchievementFacts f) measure;

  AchievementProgress evaluate(AchievementFacts facts) {
    final value = measure(facts);
    return AchievementProgress(this, value, value >= target);
  }
}

class AchievementProgress {
  const AchievementProgress(this.achievement, this.value, this.unlocked);
  final Achievement achievement;
  final num value;
  final bool unlocked;

  double get fraction => (value / achievement.target).clamp(0, 1).toDouble();
}

final achievements = <Achievement>[
  Achievement(
    'first',
    'Primeira faísca',
    'Termina o teu primeiro treino.',
    AchievementCategory.workouts,
    1,
    (f) => f.workouts,
  ),
  Achievement(
    'w10',
    'Aquecido',
    'Termina 10 treinos.',
    AchievementCategory.workouts,
    10,
    (f) => f.workouts,
  ),
  Achievement(
    'w50',
    'Rotina de aço',
    'Termina 50 treinos.',
    AchievementCategory.workouts,
    50,
    (f) => f.workouts,
  ),
  Achievement(
    'w100',
    'Centurião',
    'Termina 100 treinos.',
    AchievementCategory.workouts,
    100,
    (f) => f.workouts,
  ),
  Achievement(
    'w250',
    'Imparável',
    'Termina 250 treinos.',
    AchievementCategory.workouts,
    250,
    (f) => f.workouts,
  ),
  Achievement(
    's1',
    'Semana cumprida',
    'Cumpre o objetivo semanal.',
    AchievementCategory.streak,
    1,
    (f) => f.bestStreak,
  ),
  Achievement(
    's4',
    'Mês de ferro',
    'Streak de 4 semanas.',
    AchievementCategory.streak,
    4,
    (f) => f.bestStreak,
  ),
  Achievement(
    's12',
    'Trimestre forjado',
    'Streak de 12 semanas.',
    AchievementCategory.streak,
    12,
    (f) => f.bestStreak,
  ),
  Achievement(
    's52',
    'Ano lendário',
    'Streak de 52 semanas.',
    AchievementCategory.streak,
    52,
    (f) => f.bestStreak,
  ),
  Achievement(
    'pr1',
    'Novo máximo',
    'Bate o teu primeiro recorde pessoal.',
    AchievementCategory.records,
    1,
    (f) => f.recordBreaks,
  ),
  Achievement(
    'pr25',
    'Caçador de recordes',
    'Bate 25 recordes pessoais.',
    AchievementCategory.records,
    25,
    (f) => f.recordBreaks,
  ),
  Achievement(
    'pr100',
    'Quebra-limites',
    'Bate 100 recordes pessoais.',
    AchievementCategory.records,
    100,
    (f) => f.recordBreaks,
  ),
  Achievement(
    'v10',
    '10 toneladas',
    'Levanta 10 000 kg no total.',
    AchievementCategory.volume,
    10000,
    (f) => f.totalVolumeKg,
  ),
  Achievement(
    'v100',
    '100 toneladas',
    'Levanta 100 000 kg no total.',
    AchievementCategory.volume,
    100000,
    (f) => f.totalVolumeKg,
  ),
  Achievement(
    'v1000',
    'Mil toneladas',
    'Levanta 1 000 000 kg no total.',
    AchievementCategory.volume,
    1000000,
    (f) => f.totalVolumeKg,
  ),
  Achievement(
    'sv10',
    'Sessão pesada',
    'Levanta 10 000 kg num só treino.',
    AchievementCategory.session,
    10000,
    (f) => f.bestSessionVolumeKg,
  ),
  Achievement(
    'long',
    'Maratonista',
    'Faz um treino de 90 minutos.',
    AchievementCategory.session,
    90,
    (f) => f.longestWorkout.inMinutes,
  ),
  Achievement(
    'early',
    'Madrugador',
    'Começa 5 treinos antes das 7h.',
    AchievementCategory.session,
    5,
    (f) => f.earlyWorkouts,
  ),
  Achievement(
    'late',
    'Coruja',
    'Começa 5 treinos depois das 22h.',
    AchievementCategory.session,
    5,
    (f) => f.lateWorkouts,
  ),
  Achievement(
    'gold',
    'Toque de ouro',
    'Chega a Ouro num grupo muscular.',
    AchievementCategory.ranks,
    4,
    (f) => f.highestTier + 1,
  ),
  Achievement(
    'diamond',
    'Duro como diamante',
    'Chega a Diamante num grupo muscular.',
    AchievementCategory.ranks,
    7,
    (f) => f.highestTier + 1,
  ),
  Achievement(
    'balanced',
    'Equilibrado',
    'Todos os grupos musculares pelo menos em Prata.',
    AchievementCategory.ranks,
    3,
    (f) => f.lowestTier + 1,
  ),
  Achievement(
    'ex25',
    'Explorador',
    'Experimenta 25 exercícios diferentes.',
    AchievementCategory.variety,
    25,
    (f) => f.distinctExercises,
  ),
  Achievement(
    'l10',
    'Nível 10',
    'Chega ao nível 10.',
    AchievementCategory.level,
    10,
    (f) => f.level.level,
  ),
  Achievement(
    'l25',
    'Nível 25',
    'Chega ao nível 25.',
    AchievementCategory.level,
    25,
    (f) => f.level.level,
  ),
];
