import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import 'patch_notes.dart';

const _months = [
  'jan',
  'fev',
  'mar',
  'abr',
  'mai',
  'jun',
  'jul',
  'ago',
  'set',
  'out',
  'nov',
  'dez',
];

String _date(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

(String, Color) _kindStyle(PatchNoteKind kind, ColorScheme c) => switch (kind) {
  PatchNoteKind.added => ('Novo', c.primary),
  PatchNoteKind.improved => ('Melhorado', c.tertiary),
  PatchNoteKind.fixed => ('Corrigido', c.secondary),
};

/// Full version history, opened from Settings.
class PatchNotesScreen extends ConsumerWidget {
  const PatchNotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(patchNotesProvider);
    final current = ref.watch(appVersionProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('Notas de versão')),
      body: notes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            const Center(child: Text('Não foi possível ler as notas.')),
        data: (list) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, i) => PatchNoteCard(
            note: list[i],
            isCurrent: list[i].version == current,
          ),
        ),
      ),
    );
  }
}

/// One release: version, date, title and its grouped changes.
class PatchNoteCard extends StatelessWidget {
  const PatchNoteCard({super.key, required this.note, this.isCurrent = false});

  final PatchNote note;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isCurrent
            ? BorderSide(color: c.primary.withValues(alpha: 0.6))
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  'v${note.version}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(width: 8),
                if (note.date != null)
                  Text(
                    _date(note.date!),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: c.onSurfaceVariant,
                    ),
                  ),
                const Spacer(),
                if (isCurrent) _Pill('Instalada', c.primary),
              ],
            ),
            if (note.title.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                note.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: c.onSurfaceVariant,
                ),
              ),
            ],
            for (final s in note.sections) _Section(s),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.section);
  final PatchNoteSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color) = _kindStyle(section.kind, theme.colorScheme);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Pill(label, color),
          const SizedBox(height: 8),
          for (final item in section.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(top: 7, right: 10),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
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

class _Pill extends StatelessWidget {
  const _Pill(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    ),
  );
}

/// "What's new" after an update: only the versions the user hasn't seen.
Future<void> showWhatsNew(
  BuildContext context,
  List<PatchNote> notes,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (context) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: 0.75,
    maxChildSize: 0.95,
    builder: (context, controller) {
      final theme = Theme.of(context);
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Novidades',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        notes.length == 1
                            ? 'O que mudou nesta versão'
                            : 'O que mudou nas últimas ${notes.length} versões',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              itemCount: notes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) =>
                  PatchNoteCard(note: notes[i], isCurrent: i == 0),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Continuar'),
              ),
            ),
          ),
        ],
      );
    },
  ),
);
