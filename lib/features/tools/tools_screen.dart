import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/format.dart';
import '../../domain/enums.dart';
import '../../domain/one_rm.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Calculadoras'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '1RM'),
              Tab(text: 'Discos'),
            ],
          ),
        ),
        body: const TabBarView(children: [_OneRepMaxTab(), _PlatesTab()]),
      ),
    );
  }
}

class _NumberInput extends StatelessWidget {
  const _NumberInput({
    required this.label,
    required this.controller,
    this.suffix,
    this.decimal = true,
  });

  final String label;
  final TextEditingController controller;
  final String? suffix;
  final bool decimal;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: TextInputType.numberWithOptions(decimal: decimal),
    inputFormatters: [
      FilteringTextInputFormatter.allow(
        RegExp(decimal ? r'[0-9.,]' : r'[0-9]'),
      ),
    ],
    decoration: InputDecoration(labelText: label, suffixText: suffix),
    style: Theme.of(context).textTheme.titleMedium,
  );
}

class _OneRepMaxTab extends ConsumerStatefulWidget {
  const _OneRepMaxTab();

  @override
  ConsumerState<_OneRepMaxTab> createState() => _OneRepMaxTabState();
}

class _OneRepMaxTabState extends ConsumerState<_OneRepMaxTab> {
  final _weight = TextEditingController(text: '100');
  final _reps = TextEditingController(text: '5');

  @override
  void initState() {
    super.initState();
    _weight.addListener(() => setState(() {}));
    _reps.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _weight.dispose();
    _reps.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unit = ref.watch(currentProfileProvider).unit;
    final w = parseDecimal(_weight.text) ?? 0;
    final r = int.tryParse(_reps.text) ?? 0;
    final oneRm = estimateOneRepMax(w, r);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: _NumberInput(
                label: 'Peso',
                controller: _weight,
                suffix: unit.label,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _NumberInput(
                label: 'Repetições',
                controller: _reps,
                decimal: false,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  '1RM estimado',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  '${formatNumber(oneRm, decimals: 1)} ${unit.label}',
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                if (r > maxRepsForEstimate)
                  Text(
                    'Acima de $maxRepsForEstimate repetições a estimativa perde precisão.',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              for (final pct in const [100, 95, 90, 85, 80, 75, 70, 65, 60, 50])
                ListTile(
                  dense: true,
                  leading: SizedBox(
                    width: 48,
                    child: Text('$pct%', style: theme.textTheme.titleSmall),
                  ),
                  title: Text(
                    '${formatNumber(oneRm * pct / 100, decimals: 1)} ${unit.label}',
                  ),
                  trailing: Text(
                    '≈ ${_repsAt(pct)} reps',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Inverse Epley: reps achievable at a percentage of 1RM.
  int _repsAt(int pct) => pct >= 100 ? 1 : ((100 / pct - 1) * 30).round();
}

class _PlatesTab extends ConsumerStatefulWidget {
  const _PlatesTab();

  @override
  ConsumerState<_PlatesTab> createState() => _PlatesTabState();
}

class _PlatesTabState extends ConsumerState<_PlatesTab> {
  final _target = TextEditingController(text: '100');
  double? _bar;

  static const _kgPlates = [25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 1.25];
  static const _lbPlates = [45.0, 35.0, 25.0, 10.0, 5.0, 2.5];

  @override
  void initState() {
    super.initState();
    _target.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _target.dispose();
    super.dispose();
  }

  Color _plateColor(double p, WeightUnit unit) {
    final v = unit == WeightUnit.kg ? p : p / 2.2;
    if (v >= 24) return const Color(0xFFE53935);
    if (v >= 19) return const Color(0xFF1E88E5);
    if (v >= 14) return const Color(0xFFFDD835);
    if (v >= 9) return const Color(0xFF43A047);
    if (v >= 4) return const Color(0xFFECEFF1);
    return const Color(0xFF90A4AE);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unit = ref.watch(currentProfileProvider).unit;
    final plates = unit == WeightUnit.kg ? _kgPlates : _lbPlates;
    final bars = unit == WeightUnit.kg
        ? const [20.0, 15.0, 10.0]
        : const [45.0, 35.0, 25.0];
    final bar = _bar != null && bars.contains(_bar) ? _bar! : bars.first;
    final target = parseDecimal(_target.text) ?? 0;
    final result = platesPerSide(target, bar, plates);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _NumberInput(
          label: 'Peso total',
          controller: _target,
          suffix: unit.label,
        ),
        const SizedBox(height: 12),
        SegmentedButton<double>(
          segments: [
            for (final b in bars)
              ButtonSegment(value: b, label: Text('Barra ${formatNumber(b)}')),
          ],
          selected: {bar},
          onSelectionChanged: (s) => setState(() => _bar = s.first),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  'Por lado',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 120,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 60,
                        height: 12,
                        color: theme.colorScheme.outline,
                      ),
                      for (final p in result.plates)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          width: 14,
                          height: 40 + 70 * (p / plates.first),
                          decoration: BoxDecoration(
                            color: _plateColor(p, unit),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      Container(
                        width: 18,
                        height: 12,
                        color: theme.colorScheme.outline,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (target < bar)
                  Text(
                    'O peso é inferior ao da barra.',
                    style: theme.textTheme.bodyMedium,
                  )
                else if (result.plates.isEmpty)
                  Text('Só a barra.', style: theme.textTheme.titleMedium)
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final entry in _group(result.plates).entries)
                        Chip(
                          label: Text(
                            '${entry.value} × ${formatNumber(entry.key)} ${unit.label}',
                          ),
                        ),
                    ],
                  ),
                if (result.remainder > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Faltam ${formatNumber(result.remainder)} ${unit.label} que não dá para carregar com estes discos.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Brand.amber,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Map<double, int> _group(List<double> plates) {
    final m = <double, int>{};
    for (final p in plates) {
      m[p] = (m[p] ?? 0) + 1;
    }
    return m;
  }
}
