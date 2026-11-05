import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/format.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/enums.dart';

/// Progression settings of the Training section: rest by kind of lift,
/// suggestions, the rep range and the weekly sets per muscle.
class TrainingPrefsTiles extends ConsumerWidget {
  const TrainingPrefsTiles({super.key});

  Future<void> _update(WidgetRef ref, Profile Function(Profile) change) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.saveProfile(change(ref.read(currentProfileProvider)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(currentProfileProvider);
    String rest(ExerciseCategory c) => formatSeconds(c.restSeconds);
    return Column(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.hourglass_bottom_rounded),
          title: const Text('Descanso por tipo de exercício'),
          subtitle: Text(
            p.restByCategory
                ? 'Pesados ${rest(ExerciseCategory.heavyCompound)} · '
                      'compostos ${rest(ExerciseCategory.compound)} · '
                      'isolamento ${rest(ExerciseCategory.isolation)} · '
                      'reps altas ${rest(ExerciseCategory.highRep)}'
                : 'Usa o descanso predefinido em todos',
          ),
          value: p.restByCategory,
          onChanged: (v) => _update(ref, (x) => x.copyWith(restByCategory: v)),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.trending_up_rounded),
          title: const Text('Sugestões de progressão'),
          subtitle: const Text(
            'Subir, manter ou baixar a carga a partir dos últimos treinos',
          ),
          value: p.progressionHints,
          onChanged: (v) =>
              _update(ref, (x) => x.copyWith(progressionHints: v)),
        ),
        ListTile(
          leading: const Icon(Icons.repeat_rounded),
          title: const Text('Gama de reps'),
          subtitle: Text(
            '${p.repRangeMin}–${p.repRangeMax} · 12–20 em gémeos, abdominais, '
            'laterais, adutora e abdutora',
          ),
          onTap: () async {
            final range = await showRepRangeDialog(
              context,
              title: 'Gama de reps',
              min: p.repRangeMin,
              max: p.repRangeMax,
            );
            if (range != null) {
              await _update(
                ref,
                (x) =>
                    x.copyWith(repRangeMin: range.min, repRangeMax: range.max),
              );
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.stacked_bar_chart_rounded),
          title: const Text('Séries por músculo por semana'),
          subtitle: Text(
            p.weeklySetTarget == 0
                ? 'Sem alvo'
                : 'Alvo de ${p.weeklySetTarget} séries',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: p.weeklySetTarget > 0
                    ? () => _update(
                        ref,
                        (x) =>
                            x.copyWith(weeklySetTarget: x.weeklySetTarget - 2),
                      )
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: p.weeklySetTarget < 40
                    ? () => _update(
                        ref,
                        (x) =>
                            x.copyWith(weeklySetTarget: x.weeklySetTarget + 2),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Picks a rep range; `null` when cancelled. With [allowDefault], returns
/// `(min: 0, max: 0)` for "use the default".
Future<({int min, int max})?> showRepRangeDialog(
  BuildContext context, {
  required String title,
  required int min,
  required int max,
  bool allowDefault = false,
}) => showDialog<({int min, int max})>(
  context: context,
  builder: (_) => _RepRangeDialog(
    title: title,
    min: min,
    max: max,
    allowDefault: allowDefault,
  ),
);

class _RepRangeDialog extends StatefulWidget {
  const _RepRangeDialog({
    required this.title,
    required this.min,
    required this.max,
    required this.allowDefault,
  });

  final String title;
  final int min;
  final int max;
  final bool allowDefault;

  @override
  State<_RepRangeDialog> createState() => _RepRangeDialogState();
}

class _RepRangeDialogState extends State<_RepRangeDialog> {
  late int _min = widget.min;
  late int _max = widget.max;

  Widget _row(
    String label,
    int value,
    ValueChanged<int> onChanged,
    int lo,
    int hi,
  ) => Row(
    children: [
      Expanded(child: Text(label)),
      IconButton(
        icon: const Icon(Icons.remove_circle_outline),
        onPressed: value > lo ? () => onChanged(value - 1) : null,
      ),
      SizedBox(
        width: 32,
        child: Text(
          '$value',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      IconButton(
        icon: const Icon(Icons.add_circle_outline),
        onPressed: value < hi ? () => onChanged(value + 1) : null,
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _row('Mínimo', _min, (v) => setState(() => _min = v), 1, _max),
        _row('Máximo', _max, (v) => setState(() => _max = v), _min, 50),
        const SizedBox(height: 8),
        Text(
          'Sobes reps até ao máximo em todas as séries; depois a app sugere '
          'mais carga e voltar ao mínimo.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
    actions: [
      if (widget.allowDefault)
        TextButton(
          onPressed: () => Navigator.pop(context, (min: 0, max: 0)),
          child: const Text('Predefinida'),
        ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, (min: _min, max: _max)),
        child: const Text('Guardar'),
      ),
    ],
  );
}
