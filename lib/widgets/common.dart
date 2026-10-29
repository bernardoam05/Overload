import 'package:flutter/material.dart';

import '../domain/enums.dart';

/// Section title used across screens.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Row(
        children: [
          Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
          if (action != null)
            TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}

/// Small stat with a label underneath.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.color,
  });

  final String value;
  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: color ?? theme.colorScheme.primary),
          const SizedBox(height: 6),
        ],
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// Placeholder for empty lists.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

Color muscleColor(Muscle m) => switch (m) {
  Muscle.chest => const Color(0xFFFF6A3D),
  Muscle.back => const Color(0xFF4F9DFF),
  Muscle.shoulders => const Color(0xFFFFB547),
  Muscle.biceps => const Color(0xFFB18CFF),
  Muscle.triceps => const Color(0xFFFF5A9E),
  Muscle.forearms => const Color(0xFF9AA0AC),
  Muscle.quads => const Color(0xFF3DDC84),
  Muscle.hamstrings => const Color(0xFF2EC4B6),
  Muscle.glutes => const Color(0xFF7BD389),
  Muscle.adductors => const Color(0xFF9C8CFF),
  Muscle.calves => const Color(0xFF8FB8DE),
  Muscle.core => const Color(0xFFF6C744),
  Muscle.fullBody => const Color(0xFFFF8A65),
  Muscle.cardio => const Color(0xFFFF4D6D),
};

/// Round avatar with the muscle's initials, used in exercise lists.
class MuscleAvatar extends StatelessWidget {
  const MuscleAvatar(this.muscle, {super.key, this.size = 42});

  final Muscle muscle;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = muscleColor(muscle);
    final letters = muscle.label.length >= 2
        ? muscle.label.substring(0, 2)
        : muscle.label;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        letters.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: size * 0.32,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Thin rounded progress bar.
class ProgressBar extends StatelessWidget {
  const ProgressBar({
    super.key,
    required this.value,
    this.color,
    this.height = 8,
  });

  final double value;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1),
        minHeight: height,
        color: color,
      ),
    );
  }
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'Confirmar',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return AlertDialog(
        title: Text(title),
        content: message == null ? null : Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError,
                  )
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

Future<String?> promptText(
  BuildContext context, {
  required String title,
  String initial = '',
  String? hint,
  int maxLines = 1,
  int maxLength = 80,
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: maxLines,
        maxLength: maxLength,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: maxLines == 1 ? (v) => Navigator.pop(context, v) : null,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Snackbar with an "Anular" action that runs [onUndo].
void showUndo(BuildContext context, String message, VoidCallback onUndo) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(label: 'Anular', onPressed: onUndo),
      ),
    );
}
