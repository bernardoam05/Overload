import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/format.dart';
import '../../services/auto_backup.dart';
import '../../widgets/common.dart';

/// "Backup automático" row of the Data section; opens its options.
class AutoBackupTile extends ConsumerWidget {
  const AutoBackupTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final config =
        ref.watch(autoBackupConfigProvider).value ?? const AutoBackupConfig();
    final service = ref.read(autoBackupProvider);
    final String subtitle;
    if (!config.enabled) {
      subtitle = 'Desligado';
    } else {
      final every = config.intervalDays == 1 ? 'Diário' : 'Semanal';
      final last = config.lastAt == null
          ? 'ainda nenhum'
          : 'último ${formatRelativeDay(config.lastAt!).toLowerCase()}';
      subtitle = '$every · $last';
    }
    return ListTile(
      leading: Icon(
        config.lastError != null && config.enabled
            ? Icons.sync_problem_rounded
            : Icons.backup_outlined,
        color: config.lastError != null && config.enabled
            ? theme.colorScheme.error
            : null,
      ),
      title: const Text('Backup automático'),
      subtitle: Text(subtitle),
      trailing: Switch(
        value: config.enabled,
        onChanged: (v) async {
          await service.save(config.copyWith(enabled: v));
          if (v) await service.runIfDue();
        },
      ),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => const _AutoBackupSheet(),
      ),
    );
  }
}

class _AutoBackupSheet extends ConsumerStatefulWidget {
  const _AutoBackupSheet();

  @override
  ConsumerState<_AutoBackupSheet> createState() => _AutoBackupSheetState();
}

class _AutoBackupSheetState extends ConsumerState<_AutoBackupSheet> {
  String? _defaultDir;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    AutoBackupService.defaultDirectory().then((d) {
      if (mounted) setState(() => _defaultDir = d);
    });
  }

  Future<void> _pickFolder(AutoBackupConfig config) async {
    final dir = await FilePicker.getDirectoryPath(
      dialogTitle: 'Pasta dos backups automáticos',
    );
    if (dir == null) return;
    await ref
        .read(autoBackupProvider)
        .save(config.copyWith(directory: () => dir));
  }

  Future<void> _runNow() async {
    setState(() => _running = true);
    try {
      final result = await ref.read(autoBackupProvider).runNow();
      if (!mounted) return;
      showMessage(
        context,
        result.lastError ?? 'Backup guardado em ${result.lastPath}',
      );
    } on Object catch (e) {
      if (mounted) showMessage(context, 'Não foi possível fazer o backup: $e');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    final service = ref.read(autoBackupProvider);
    final config =
        ref.watch(autoBackupConfigProvider).value ?? const AutoBackupConfig();
    final folder = config.directory ?? _defaultDir ?? '…';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Backup automático',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Guarda uma cópia de todos os dados numa pasta do telemóvel, ao '
              'abrir a app ou ao terminar um treino. Ficam os '
              '${AutoBackupConfig.keep} mais recentes. Para os teres fora do '
              'telemóvel, sincroniza essa pasta com a Google Drive ou outra app.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: c.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ligado'),
              value: config.enabled,
              onChanged: (v) => service.save(config.copyWith(enabled: v)),
            ),
            const SizedBox(height: 4),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 1, label: Text('Diário')),
                ButtonSegment(value: 7, label: Text('Semanal')),
              ],
              selected: {config.intervalDays},
              showSelectedIcon: false,
              onSelectionChanged: (s) =>
                  service.save(config.copyWith(intervalDays: s.first)),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.folder_outlined),
              title: const Text('Pasta'),
              subtitle: Text(folder),
              trailing: config.directory == null
                  ? null
                  : IconButton(
                      tooltip: 'Usar a pasta predefinida',
                      icon: const Icon(Icons.restart_alt_rounded),
                      onPressed: () =>
                          service.save(config.copyWith(directory: () => null)),
                    ),
              onTap: () => _pickFolder(config),
            ),
            if (config.lastAt != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history_rounded),
                title: Text(
                  'Último: ${formatDateLong(config.lastAt!)}, ${formatTime(config.lastAt!)}',
                ),
                subtitle: config.lastPath == null
                    ? null
                    : Text(config.lastPath!),
              ),
            if (config.lastError case final error?)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  error,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: c.onErrorContainer,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _running ? null : _runNow,
              icon: _running
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.backup_rounded),
              label: const Text('Fazer backup agora'),
            ),
          ],
        ),
      ),
    );
  }
}
