import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/format.dart';
import '../../data/database.dart';
import '../../data/repositories/measurement_repository.dart';
import '../../domain/enums.dart';
import '../../domain/stats.dart';
import '../../widgets/common.dart';
import '../../widgets/line_chart.dart';

/// Body measurements (waist, arm, thigh…) with their trend.
class MeasurementsScreen extends ConsumerWidget {
  const MeasurementsScreen({super.key});

  Future<void> _add(
    BuildContext context,
    WidgetRef ref, [
    Measurement? kind,
  ]) async {
    final result = await _askMeasurement(context, kind);
    if (result == null) return;
    try {
      await ref
          .read(measurementRepositoryProvider)
          .log(result.date, result.kind, result.value);
    } on ArgumentError catch (e) {
      if (context.mounted) showMessage(context, '${e.message}');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final entries = ref.watch(measurementsProvider).value ?? const [];
    final byKind = groupBy(entries, (MeasurementEntry e) => e.kind);
    final kinds = [
      for (final k in Measurement.values)
        if (byKind.containsKey(k)) k,
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Medidas corporais')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Registar'),
      ),
      body: kinds.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Regista a cintura, os braços, as coxas… O peso sozinho não '
                  'distingue gordura de músculo; as medidas ajudam a ver se '
                  'estás a crescer onde queres.\n\nMede sempre à mesma hora, '
                  'de manhã e antes de treinar.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                for (final k in kinds) ...[
                  _KindCard(
                    kind: k,
                    entries: byKind[k]!,
                    onAdd: () => _add(context, ref, k),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }
}

class _KindCard extends ConsumerWidget {
  const _KindCard({
    required this.kind,
    required this.entries,
    required this.onAdd,
  });

  final Measurement kind;

  /// Newest first.
  final List<MeasurementEntry> entries;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    final latest = entries.first;
    final previous = entries.length > 1 ? entries[1] : null;
    final delta = previous == null ? null : latest.value - previous.value;
    String value(double v) => '${formatNumber(v, decimals: 1)} ${kind.unit}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(kind.label, style: theme.textTheme.titleMedium),
                      Text(
                        formatRelativeDay(latest.date),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: c.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      value(latest.value),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (delta != null && delta.abs() >= 0.05)
                      Text(
                        '${delta > 0 ? '+' : ''}${formatNumber(delta, decimals: 1)} ${kind.unit}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: c.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
                IconButton(
                  tooltip: 'Registar ${kind.label.toLowerCase()}',
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            if (entries.length >= 2) ...[
              const SizedBox(height: 8),
              ProgressLineChart(
                height: 120,
                points: [
                  for (final e in entries.reversed)
                    ProgressPoint(e.date, e.value),
                ],
                valueLabel: (v) => formatNumber(v, decimals: 1),
              ),
            ],
            const SizedBox(height: 4),
            for (final e in entries.take(4))
              Row(
                children: [
                  Expanded(
                    child: Text(
                      capitalize(formatDate(e.date)),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  Text(value(e.value), style: theme.textTheme.labelLarge),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Apagar',
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    onPressed: () =>
                        ref.read(measurementRepositoryProvider).delete(e.id),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

Future<({Measurement kind, double value, DateTime date})?> _askMeasurement(
  BuildContext context,
  Measurement? initial,
) {
  final controller = TextEditingController();
  var kind = initial ?? Measurement.waist;
  var date = DateTime.now();
  return showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final (lo, hi) = MeasurementRepository.rangeOf(kind);
        return AlertDialog(
          title: const Text('Registar medida'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final k in Measurement.values)
                      ChoiceChip(
                        label: Text(k.label),
                        selected: kind == k,
                        onSelected: (_) => setState(() => kind = k),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
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
                    suffixText: kind.unit,
                    hintText: kind.label,
                    helperText:
                        'Entre ${formatNumber(lo)} e ${formatNumber(hi)} ${kind.unit}',
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
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final v = parseDecimal(controller.text);
                if (v == null || v < lo || v > hi) return;
                Navigator.pop(context, (kind: kind, value: v, date: date));
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    ),
  );
}
