import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';

typedef _Tip = (IconData icon, String title, String body);

const _tips = <_Tip>[
  (
    Icons.looks_one_outlined,
    'Tipo de série',
    'Toca no número da série (ou mantém a série premida) para a marcar como aquecimento, drop set ou até à falha.',
  ),
  (
    Icons.swipe_left_rounded,
    'Apagar série',
    'Desliza a série para a esquerda. Aparece "Anular" se te enganares.',
  ),
  (
    Icons.check_circle_outline_rounded,
    'Repetir a última vez',
    'Toca no ✓ sem escrever nada para usar o peso e as repetições da coluna Anterior.',
  ),
  (
    Icons.more_horiz_rounded,
    'Mais opções do exercício',
    'Em ⋯ tens notas, tempo de descanso, substituir, reordenar e remover.',
  ),
  (
    Icons.notifications_active_outlined,
    'Descanso fora da app',
    'Podes sair da app: a notificação mostra a contagem e avisa quando o descanso acaba.',
  ),
];

class _TipsList extends StatelessWidget {
  const _TipsList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (final (icon, title, body) in _tips)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        body,
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
      ],
    );
  }
}

/// Shown at the top of the workout until dismissed.
class WorkoutTipsCard extends ConsumerWidget {
  const WorkoutTipsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Brand.ember.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lightbulb_outline_rounded, color: Brand.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Dicas rápidas',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const _TipsList(),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  final repo = ref.read(settingsRepositoryProvider);
                  repo.saveProfile(
                    ref
                        .read(currentProfileProvider)
                        .copyWith(seenWorkoutTips: true),
                  );
                },
                child: const Text('Percebi'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Same tips, on demand from the workout menu.
Future<void> showWorkoutTips(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dicas e atalhos',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const _TipsList(),
            ],
          ),
        ),
      ),
    );
