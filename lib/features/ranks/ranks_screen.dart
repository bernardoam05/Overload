import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/format.dart';
import '../../domain/enums.dart';
import '../../domain/ranks.dart';
import '../../widgets/common.dart';
import '../../widgets/rank_badge.dart';

class RanksScreen extends ConsumerWidget {
  const RanksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ranks = ref.watch(ranksProvider);
    final hasBw = ref.watch(hasBodyWeightProvider);
    final overall = ranks.overall;
    final color = Brand.tierColor(overall.tier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ranks'),
        actions: [
          IconButton(
            tooltip: 'Como funciona',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => _showInfo(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: RadialGradient(
                colors: [
                  color.withValues(alpha: 0.25),
                  theme.colorScheme.surfaceContainer,
                ],
                radius: 1.1,
              ),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Column(
              children: [
                RankBadge(standing: overall, size: 120),
                const SizedBox(height: 12),
                Text(
                  'RANK GERAL',
                  style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 2,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  overall.label,
                  style: theme.textTheme.headlineMedium?.copyWith(color: color),
                ),
                const SizedBox(height: 12),
                ProgressBar(value: overall.divisionProgress, color: color),
                const SizedBox(height: 6),
                Text(
                  overall.isMaxTier
                      ? 'Estás no topo. Lenda.'
                      : 'Próximo: ${overall.nextLabel}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (!hasBw) ...[
            const SizedBox(height: 12),
            Card(
              color: theme.colorScheme.secondaryContainer,
              child: ListTile(
                leading: Icon(
                  Icons.monitor_weight_outlined,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
                title: Text(
                  'Regista o teu peso corporal',
                  style: TextStyle(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
                subtitle: Text(
                  'Os ranks são relativos ao teu peso. A usar 75 kg por defeito.',
                  style: TextStyle(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
                onTap: () => context.push('/body-weight'),
              ),
            ),
          ],
          const SectionHeader('Grupos musculares'),
          for (final g in RankGroup.values) ...[
            _GroupCard(standing: ranks.groups[g]!),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  void _showInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Como funcionam os ranks',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Cada grupo muscular tem um rank calculado a partir do teu melhor 1RM estimado '
                  '(fórmula de Epley) nos exercícios desse grupo, convertido para o exercício de referência '
                  'e dividido pelo teu peso corporal.\n\n'
                  'Há 9 tiers — Ferro, Bronze, Prata, Ouro, Platina, Esmeralda, Diamante, Mestre e Lenda — '
                  'cada um com divisões III, II e I. O rank geral é a média de todos os grupos, '
                  'por isso treinar o corpo todo compensa.\n\n'
                  'Séries de aquecimento não contam. Os padrões ajustam-se ao sexo indicado no perfil.',
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (var i = 0; i < tiers.length; i++)
                      Column(
                        children: [
                          RankBadge(
                            standing: RankStanding(score: i + 0.99),
                            size: 44,
                          ),
                          Text(
                            tiers[i].name,
                            style: theme.textTheme.labelSmall,
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GroupCard extends ConsumerWidget {
  const _GroupCard({required this.standing});

  final RankStanding standing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final unit = ref.watch(currentProfileProvider).unit;
    final bw = ref.watch(bodyWeightProvider);
    final library = ref.watch(libraryProvider);
    final color = Brand.tierColor(standing.tier);
    final group = standing.group!;
    final next = standing.nextE1rm(bw);
    final empty = standing.bestExerciseId == null;

    return Card(
      child: InkWell(
        onTap: () => _showLadder(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              RankBadge(standing: standing, size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            group.label,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        Text(
                          empty ? 'Sem rank' : standing.label,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: empty ? null : color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ProgressBar(
                      value: empty ? 0 : standing.divisionProgress,
                      color: color,
                      height: 6,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      empty
                          ? 'Faz ${group.benchmark.toLowerCase()} ou outro exercício de ${group.label.toLowerCase()}'
                          : next == null
                          ? '${formatNumber(standing.ratio)}× peso corporal · ${library[standing.bestExerciseId]?.name ?? ''}'
                          : '${formatNumber(standing.ratio)}× PC · ${standing.nextLabel} com ${formatWeight(next, unit)} (${group.benchmark.toLowerCase()})',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLadder(BuildContext context, WidgetRef ref) {
    final unit = ref.read(currentProfileProvider).unit;
    final bw = ref.read(bodyWeightProvider);
    final library = ref.read(libraryProvider);
    final group = standing.group!;
    final counted =
        library.values
            .where((e) => e.rankGroup == group && !e.archived)
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final theme = Theme.of(context);
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          builder: (context, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              Text(group.label, style: theme.textTheme.headlineSmall),
              Text(
                '1RM de ${group.benchmark.toLowerCase()} necessário para cada tier, ao teu peso de ${formatWeight(bw, unit)}.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              for (var i = tiers.length - 1; i >= 0; i--)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: RankBadge(
                    standing: RankStanding(score: i + 0.99),
                    size: 40,
                  ),
                  title: Text(
                    tiers[i].name,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: i == standing.tierIndex
                          ? Brand.tierColor(tiers[i])
                          : null,
                    ),
                  ),
                  subtitle: Text(
                    '${formatNumber(standing.thresholds[i])}× peso corporal',
                  ),
                  trailing: Text(
                    i == 0
                        ? '—'
                        : formatWeight(standing.thresholds[i] * bw, unit),
                    style: theme.textTheme.titleSmall,
                  ),
                  selected: i == standing.tierIndex,
                ),
              const SizedBox(height: 12),
              Text('Exercícios que contam', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [for (final e in counted) Chip(label: Text(e.name))],
              ),
            ],
          ),
        );
      },
    );
  }
}
