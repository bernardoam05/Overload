import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../data/repositories/exercise_repository.dart';
import '../../domain/enums.dart';
import '../../widgets/common.dart';

/// Create (no id) or edit a custom exercise. Pops with the exercise id.
class ExerciseEditorScreen extends ConsumerStatefulWidget {
  const ExerciseEditorScreen({super.key, this.exerciseId});

  final int? exerciseId;

  @override
  ConsumerState<ExerciseEditorScreen> createState() =>
      _ExerciseEditorScreenState();
}

class _ExerciseEditorScreenState extends ConsumerState<ExerciseEditorScreen> {
  final _name = TextEditingController();
  final _instructions = TextEditingController();
  Muscle _primary = Muscle.chest;
  final Set<Muscle> _secondary = {};
  Equipment _equipment = Equipment.barbell;
  ExerciseKind _kind = ExerciseKind.weighted;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final existing = widget.exerciseId == null
        ? null
        : ref.read(libraryProvider)[widget.exerciseId];
    if (existing != null) {
      _name.text = existing.name;
      _instructions.text = existing.instructions;
      _primary = existing.primaryMuscle;
      _secondary.addAll(existing.secondaryMuscles);
      _equipment = existing.equipment;
      _kind = existing.kind;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _instructions.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final draft = ExerciseDraft(
      name: _name.text,
      primaryMuscle: _primary,
      secondaryMuscles: [..._secondary.where((m) => m != _primary)],
      equipment: _equipment,
      kind: _kind,
      instructions: _instructions.text,
    );
    final error = draft.validate();
    if (error != null) {
      showMessage(context, error);
      return;
    }
    final repo = ref.read(exerciseRepositoryProvider);
    final int id;
    if (widget.exerciseId == null) {
      id = await repo.create(draft);
    } else {
      id = widget.exerciseId!;
      await repo.update(id, draft);
    }
    if (mounted) context.pop(id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.exerciseId == null ? 'Novo exercício' : 'Editar exercício',
        ),
        actions: [
          TextButton(onPressed: _save, child: const Text('Guardar')),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            autofocus: widget.exerciseId == null,
            maxLength: 80,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Nome'),
          ),
          const SizedBox(height: 8),
          Text('Tipo de registo', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (k, icon, label) in const [
                (ExerciseKind.weighted, Icons.fitness_center, 'Peso'),
                (
                  ExerciseKind.bodyweight,
                  Icons.accessibility_new,
                  'Peso corporal',
                ),
                (ExerciseKind.assisted, Icons.support_rounded, 'Assistido'),
                (ExerciseKind.duration, Icons.timer_outlined, 'Tempo'),
              ])
                ChoiceChip(
                  avatar: Icon(icon, size: 18),
                  label: Text(label),
                  selected: _kind == k,
                  onSelected: (_) => setState(() => _kind = k),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            switch (_kind) {
              ExerciseKind.weighted =>
                'Registas o peso levantado e as repetições.',
              ExerciseKind.bodyweight =>
                'Elevações, flexões… Podes registar peso extra (cinto, colete).',
              ExerciseKind.assisted =>
                'Máquina com contrapeso: registas o peso de ajuda. Menos ajuda = mais forte.',
              ExerciseKind.duration => 'Registas o tempo (prancha, cardio…).',
            },
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Text('Músculo principal', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in Muscle.values)
                ChoiceChip(
                  label: Text(m.label),
                  selected: _primary == m,
                  onSelected: (_) => setState(() => _primary = m),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Músculos secundários', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in Muscle.values)
                if (m != _primary)
                  FilterChip(
                    label: Text(m.label),
                    selected: _secondary.contains(m),
                    onSelected: (v) => setState(
                      () => v ? _secondary.add(m) : _secondary.remove(m),
                    ),
                  ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Equipamento', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in Equipment.values)
                ChoiceChip(
                  label: Text(e.label),
                  selected: _equipment == e,
                  onSelected: (_) => setState(() => _equipment = e),
                ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _instructions,
            maxLines: 4,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Notas de execução (opcional)',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Exercícios personalizados não contam para os ranks, porque não têm padrões de força de referência.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
