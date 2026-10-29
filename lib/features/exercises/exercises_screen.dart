import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../data/aliases.dart';
import '../../domain/enums.dart';
import '../../domain/exercise.dart';
import '../../widgets/common.dart';

enum PickMode { none, single, multiple }

/// Lower-case, accent-free text for searching.
String normalizeSearch(String s) {
  const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const to = 'aaaaaeeeeiiiiooooouuuucn';
  final lower = s.toLowerCase();
  final buffer = StringBuffer();
  for (final ch in lower.split('')) {
    final i = from.indexOf(ch);
    buffer.write(i >= 0 ? to[i] : ch);
  }
  return buffer.toString().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ');
}

/// How well [e] matches [query]: 2 = every word is in the name, 1 = found
/// via an alternative name, 0 = no match.
List<String> _queryWords(String query) => [
  // Plurals ("squats", "raises") should still match the singular.
  for (final w in normalizeSearch(query).split(' '))
    if (w.isNotEmpty)
      w.length > 3 && w.endsWith('s') ? w.substring(0, w.length - 1) : w,
];

/// The alternative name that matched [query], to show why a result appears.
String? matchedAlias(Exercise e, String query) {
  final words = _queryWords(query);
  if (words.isEmpty) return null;
  for (final alias in exerciseAliases[e.seedKey] ?? const <String>[]) {
    final text = normalizeSearch(alias);
    if (words.every(text.contains)) return alias;
  }
  return null;
}

int searchScore(Exercise e, String query) {
  final words = _queryWords(query);
  if (words.isEmpty) return 2;
  final name = normalizeSearch(e.name);
  if (words.every(name.contains)) return 2;
  final aliases = normalizeSearch(
    [name, ...?exerciseAliases[e.seedKey]].join(' '),
  );
  return words.every(aliases.contains) ? 1 : 0;
}

class ExercisesScreen extends ConsumerStatefulWidget {
  const ExercisesScreen({super.key, this.pickMode = PickMode.none});

  final PickMode pickMode;

  @override
  ConsumerState<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends ConsumerState<ExercisesScreen> {
  String _query = '';
  Muscle? _muscle;
  Equipment? _equipment;
  final List<int> _selected = [];

  bool get _picking => widget.pickMode != PickMode.none;

  List<Exercise> _filter(List<Exercise> all) {
    final scores = <int, int>{};
    for (final e in all) {
      scores[e.id] = searchScore(e, _query);
    }
    return [
      for (final e in all)
        if (!e.archived &&
            (_muscle == null ||
                e.primaryMuscle == _muscle ||
                e.secondaryMuscles.contains(_muscle)) &&
            (_equipment == null || e.equipment == _equipment) &&
            scores[e.id]! > 0)
          e,
    ]..sort((a, b) {
      final byScore = scores[b.id]!.compareTo(scores[a.id]!);
      if (byScore != 0) return byScore;
      if (_muscle != null) {
        final pa = a.primaryMuscle == _muscle ? 0 : 1;
        final pb = b.primaryMuscle == _muscle ? 0 : 1;
        if (pa != pb) return pa - pb;
      }
      return normalizeSearch(a.name).compareTo(normalizeSearch(b.name));
    });
  }

  void _onTap(Exercise e) {
    switch (widget.pickMode) {
      case PickMode.none:
        context.push('/exercises/${e.id}');
      case PickMode.single:
        context.pop(<int>[e.id]);
      case PickMode.multiple:
        setState(
          () => _selected.contains(e.id)
              ? _selected.remove(e.id)
              : _selected.add(e.id),
        );
    }
  }

  Future<void> _create() async {
    final id = await context.push<int>('/exercises/new');
    if (id == null || !mounted) return;
    if (widget.pickMode == PickMode.single) {
      context.pop(<int>[id]);
    } else if (widget.pickMode == PickMode.multiple) {
      setState(() => _selected.add(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(exercisesProvider);
    final usage = ref.watch(_usageProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_picking ? 'Escolher exercícios' : 'Exercícios'),
        leading: _picking
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => context.pop(),
              )
            : null,
        actions: [
          IconButton(
            tooltip: 'Novo exercício',
            icon: const Icon(Icons.add_rounded),
            onPressed: _create,
          ),
          PopupMenuButton<Equipment?>(
            tooltip: 'Equipamento',
            icon: Badge(
              isLabelVisible: _equipment != null,
              child: const Icon(Icons.tune_rounded),
            ),
            onSelected: (e) => setState(() => _equipment = e),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: null,
                child: Text('Todo o equipamento'),
              ),
              for (final e in Equipment.values)
                PopupMenuItem(value: e, child: Text(e.label)),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(112),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  autofocus: false,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'Procurar exercício',
                  ),
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final m in [null, ...Muscle.values])
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(m?.label ?? 'Todos'),
                          selected: _muscle == m,
                          onSelected: (_) => setState(() => _muscle = m),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (all) {
          final list = _filter(all);
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.search_off_rounded,
              title: 'Nenhum exercício encontrado',
              action: OutlinedButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.add),
                label: const Text('Criar exercício'),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 100),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final e = list[i];
              final order = _selected.indexOf(e.id);
              final count = usage[e.id] ?? 0;
              return ListTile(
                onTap: () => _onTap(e),
                leading: MuscleAvatar(e.primaryMuscle),
                title: Text(
                  e.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  [
                    if (matchedAlias(e, _query) case final alias?
                        when searchScore(e, _query) == 1)
                      '"$alias"'
                    else ...[
                      e.primaryMuscle.label,
                      e.equipment.label,
                    ],
                    if (count > 0) '$count× feito',
                  ].join(' · '),
                ),
                trailing: widget.pickMode == PickMode.multiple
                    ? AnimatedSwitcher(
                        duration: const Duration(milliseconds: 150),
                        child: order >= 0
                            ? CircleAvatar(
                                key: const ValueKey('on'),
                                radius: 14,
                                backgroundColor: theme.colorScheme.primary,
                                child: Text(
                                  '${order + 1}',
                                  style: TextStyle(
                                    color: theme.colorScheme.onPrimary,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              )
                            : Icon(
                                Icons.add_circle_outline,
                                key: const ValueKey('off'),
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                      )
                    : (e.isCustom
                          ? const Icon(Icons.person_outline, size: 18)
                          : null),
              );
            },
          );
        },
      ),
      bottomNavigationBar:
          widget.pickMode == PickMode.multiple && _selected.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton(
                  onPressed: () => context.pop(List<int>.of(_selected)),
                  child: Text(
                    'Adicionar ${_selected.length} ${_selected.length == 1 ? 'exercício' : 'exercícios'}',
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

/// How many workouts each exercise appears in.
final _usageProvider = Provider<Map<int, int>>((ref) {
  final result = <int, int>{};
  for (final w in ref.watch(historyListProvider)) {
    for (final id in {for (final e in w.exercises) e.exerciseId}) {
      result[id] = (result[id] ?? 0) + 1;
    }
  }
  return result;
});
