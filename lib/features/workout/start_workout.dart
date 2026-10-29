import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'active_workout_controller.dart';

/// Starts a workout via [start], asking first if one is already running.
Future<void> startWorkout(
  BuildContext context,
  WidgetRef ref,
  void Function(ActiveWorkoutController c) start,
) async {
  final current = ref.read(activeWorkoutProvider);
  if (current != null) {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          current.isEditing
              ? 'Estás a editar um treino'
              : 'Já tens um treino a decorrer',
        ),
        content: Text(
          current.isEditing
              ? 'Termina ou descarta a edição de "${current.name}" primeiro.'
              : 'Queres retomar "${current.name}" ou descartá-lo e começar um novo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('Descartar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'resume'),
            child: const Text('Retomar'),
          ),
        ],
      ),
    );
    if (!context.mounted || choice == null) return;
    if (choice == 'resume') {
      context.push('/workout');
      return;
    }
  }
  start(ref.read(activeWorkoutProvider.notifier));
  if (context.mounted) context.push('/workout');
}
