import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/format.dart';
import '../../domain/enums.dart';
import '../../domain/stats.dart';
import '../../widgets/common.dart';
import '../../widgets/line_chart.dart';

/// Dialog asking for a body weight in the user's unit; returns kg.
Future<({double kg, DateTime date})?> askBodyWeight(
  BuildContext context,
  WeightUnit unit, {
  double? initialKg,
}) {
  final controller = TextEditingController(
    text: initialKg == null
        ? ''
        : editableNumber(toDisplayWeight(initialKg, unit)),
  );
  var date = DateTime.now();
  return showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Registar peso'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                suffixText: unit.label,
                hintText: 'Peso',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.event_outlined),
              label: Text(capitalize(formatDate(date))),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => date = picked);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final v = parseDecimal(controller.text);
              if (v == null) return;
              final kg = fromDisplayWeight(v, unit);
              if (kg < 20 || kg > 400) return;
              Navigator.pop(context, (kg: kg, date: date));
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );
}

class BodyWeightScreen extends ConsumerWidget {
  const BodyWeightScreen({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final unit = ref.read(currentProfileProvider).unit;
    final entries = ref.read(bodyWeightsProvider).value ?? const [];
    final result = await askBodyWeight(
      context,
      unit,
      initialKg: entries.isEmpty ? null : entries.first.weightKg,
    );
    if (result == null) return;
    await ref.read(bodyWeightRepositoryProvider).log(result.date, result.kg);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final unit = ref.watch(currentProfileProvider).unit;
    final entries = ref.watch(bodyWeightsProvider).value ?? const [];
    final points = [
      for (final e in entries.reversed)
        ProgressPoint(e.date, toDisplayWeight(e.weightKg, unit)),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Peso corporal')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Registar'),
      ),
      body: entries.isEmpty
          ? const EmptyState(
              icon: Icons.monitor_weight_outlined,
              title: 'Sem registos de peso',
              message:
                  'O peso corporal é usado para calcular os teus ranks e exercícios com peso corporal.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Row(
                            children: [
                              Text(
                                formatWeight(entries.first.weightKg, unit),
                                style: theme.textTheme.headlineSmall,
                              ),
                              const SizedBox(width: 12),
                              if (entries.length > 1)
                                Builder(
                                  builder: (context) {
                                    final diff =
                                        entries.first.weightKg -
                                        entries.last.weightKg;
                                    return Text(
                                      '${diff >= 0 ? '+' : '−'}${formatWeight(diff.abs(), unit)} desde ${formatDateShort(entries.last.date)}',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        ProgressLineChart(
                          points: points,
                          valueLabel: (v) => formatNumber(v, decimals: 1),
                          color: theme.colorScheme.tertiary,
                        ),
                      ],
                    ),
                  ),
                ),
                const SectionHeader('Registos'),
                Card(
                  child: Column(
                    children: [
                      for (final e in entries)
                        ListTile(
                          title: Text(formatWeight(e.weightKg, unit)),
                          subtitle: Text(capitalize(formatDate(e.date))),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              final repo = ref.read(
                                bodyWeightRepositoryProvider,
                              );
                              await repo.delete(e.id);
                              if (context.mounted) {
                                showUndo(
                                  context,
                                  'Registo apagado',
                                  () => repo.log(e.date, e.weightKg),
                                );
                              }
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
