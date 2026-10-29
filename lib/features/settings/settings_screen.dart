import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/providers.dart';
import '../../core/format.dart';
import '../../data/repositories/backup_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/enums.dart';
import '../../widgets/common.dart';
import '../workout/active_workout_controller.dart';
import '../workout/exercise_card.dart';
import 'notification_settings.dart';
import 'update_dialog.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _update(
    WidgetRef ref,
    Profile Function(Profile p) change,
  ) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.saveProfile(change(ref.read(currentProfileProvider)));
  }

  String _backupName() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return 'overload-backup-${now.year}${two(now.month)}${two(now.day)}-${two(now.hour)}${two(now.minute)}.json';
  }

  Future<void> _export(
    BuildContext context,
    WidgetRef ref, {
    required bool share,
  }) async {
    try {
      final json = await ref.read(backupRepositoryProvider).export();
      final bytes = Uint8List.fromList(utf8.encode(json));
      if (share) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/${_backupName()}');
        await file.writeAsBytes(bytes);
        await SharePlus.instance.share(
          ShareParams(files: [XFile(file.path)], subject: 'Backup Overload'),
        );
      } else {
        final uri = await FilePicker.saveFile(
          dialogTitle: 'Guardar backup',
          fileName: _backupName(),
          bytes: bytes,
          mimeType: 'application/json',
          type: FileType.custom,
          allowedExtensions: const ['json'],
        );
        if (uri != null && context.mounted) {
          showMessage(context, 'Backup guardado.');
        }
      }
    } on Object catch (e) {
      if (context.mounted) {
        showMessage(context, 'Não foi possível exportar: $e');
      }
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final files = await FilePicker.pickFiles(
      dialogTitle: 'Escolher backup',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (files.isEmpty || !context.mounted) return;
    final path = files.first.path;
    if (path == null) return;
    final ok = await confirm(
      context,
      title: 'Restaurar backup?',
      message: 'Todos os dados atuais serão substituídos pelos do ficheiro.',
      confirmLabel: 'Restaurar',
      destructive: true,
    );
    if (!ok) return;
    try {
      final content = await File(path).readAsString();
      ref.read(activeWorkoutProvider.notifier).discard();
      await ref.read(backupRepositoryProvider).import(content);
      if (context.mounted) showMessage(context, 'Backup restaurado.');
    } on BackupFormatException catch (e) {
      if (context.mounted) showMessage(context, e.message);
    } on Object catch (e) {
      if (context.mounted) showMessage(context, 'Falha ao restaurar: $e');
    }
  }

  Future<void> _wipe(BuildContext context, WidgetRef ref) async {
    final ok = await confirm(
      context,
      title: 'Apagar todos os dados?',
      message:
          'Treinos, rotinas, pesos e definições serão apagados. Esta ação não pode ser desfeita.',
      confirmLabel: 'Apagar tudo',
      destructive: true,
    );
    if (!ok) return;
    ref.read(activeWorkoutProvider.notifier).discard();
    await ref.read(backupRepositoryProvider).wipe();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final p = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Definições')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          const SectionHeader('Perfil'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: const Text('Nome'),
                  subtitle: Text(p.name.isEmpty ? 'Sem nome' : p.name),
                  onTap: () async {
                    final name = await promptText(
                      context,
                      title: 'O teu nome',
                      initial: p.name,
                      maxLength: 40,
                    );
                    if (name != null) {
                      await _update(ref, (x) => x.copyWith(name: name.trim()));
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.wc_outlined),
                  title: const Text('Padrões de força'),
                  subtitle: Text(p.sex.label),
                  onTap: () async {
                    final sex = await showModalBottomSheet<Sex>(
                      context: context,
                      builder: (context) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final s in Sex.values)
                              ListTile(
                                title: Text(s.label),
                                trailing: s == p.sex
                                    ? const Icon(Icons.check)
                                    : null,
                                onTap: () => Navigator.pop(context, s),
                              ),
                          ],
                        ),
                      ),
                    );
                    if (sex != null) {
                      await _update(ref, (x) => x.copyWith(sex: sex));
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: const Text('Objetivo semanal'),
                  subtitle: Text(
                    '${p.weeklyGoal} ${p.weeklyGoal == 1 ? 'treino' : 'treinos'} por semana',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: p.weeklyGoal > 1
                            ? () => _update(
                                ref,
                                (x) => x.copyWith(weeklyGoal: x.weeklyGoal - 1),
                              )
                            : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: p.weeklyGoal < 7
                            ? () => _update(
                                ref,
                                (x) => x.copyWith(weeklyGoal: x.weeklyGoal + 1),
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SectionHeader('Treino'),
          Card(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.straighten_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 16),
                      const Expanded(child: Text('Unidades')),
                      SegmentedButton<WeightUnit>(
                        segments: const [
                          ButtonSegment(
                            value: WeightUnit.kg,
                            label: Text('kg'),
                          ),
                          ButtonSegment(
                            value: WeightUnit.lb,
                            label: Text('lb'),
                          ),
                        ],
                        selected: {p.unit},
                        onSelectionChanged: (s) =>
                            _update(ref, (x) => x.copyWith(unit: s.first)),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.timer_outlined),
                  title: const Text('Descanso predefinido'),
                  subtitle: Text(
                    p.defaultRestSeconds == 0
                        ? 'Desligado'
                        : formatSeconds(p.defaultRestSeconds),
                  ),
                  onTap: () async {
                    final s = await pickRestSeconds(
                      context,
                      p.defaultRestSeconds,
                    );
                    if (s != null && s >= 0) {
                      await _update(
                        ref,
                        (x) => x.copyWith(defaultRestSeconds: s),
                      );
                    }
                  },
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.alarm_on_outlined),
                  title: const Text('Iniciar descanso automaticamente'),
                  subtitle: const Text('Ao completar uma série'),
                  value: p.autoRestTimer,
                  onChanged: (v) =>
                      _update(ref, (x) => x.copyWith(autoRestTimer: v)),
                ),
              ],
            ),
          ),
          const SectionHeader('Notificações'),
          const NotificationSettings(),
          const SectionHeader('Aparência'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SegmentedButton<AppThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: AppThemeMode.dark,
                    label: Text('Escuro'),
                    icon: Icon(Icons.dark_mode_outlined),
                  ),
                  ButtonSegment(
                    value: AppThemeMode.light,
                    label: Text('Claro'),
                    icon: Icon(Icons.light_mode_outlined),
                  ),
                  ButtonSegment(
                    value: AppThemeMode.system,
                    label: Text('Sistema'),
                    icon: Icon(Icons.brightness_auto_outlined),
                  ),
                ],
                selected: {p.themeMode},
                onSelectionChanged: (s) =>
                    _update(ref, (x) => x.copyWith(themeMode: s.first)),
              ),
            ),
          ),
          const SectionHeader('Dados'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.save_alt_rounded),
                  title: const Text('Exportar backup'),
                  subtitle: const Text(
                    'Guardar um ficheiro JSON com todos os dados',
                  ),
                  onTap: () => _export(context, ref, share: false),
                ),
                ListTile(
                  leading: const Icon(Icons.ios_share_rounded),
                  title: const Text('Partilhar backup'),
                  onTap: () => _export(context, ref, share: true),
                ),
                ListTile(
                  leading: const Icon(Icons.restore_rounded),
                  title: const Text('Restaurar backup'),
                  onTap: () => _import(context, ref),
                ),
                ListTile(
                  leading: Icon(
                    Icons.delete_forever_outlined,
                    color: theme.colorScheme.error,
                  ),
                  title: Text(
                    'Apagar todos os dados',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  onTap: () => _wipe(context, ref),
                ),
              ],
            ),
          ),
          const SectionHeader('Sobre'),
          Card(
            child: Builder(
              builder: (context) {
                final update = ref.watch(updateProvider);
                final info = update.value;
                return ListTile(
                  leading: Icon(
                    info != null
                        ? Icons.system_update_rounded
                        : Icons.update_rounded,
                    color: info != null ? theme.colorScheme.primary : null,
                  ),
                  title: Text(
                    info != null
                        ? 'Nova versão ${info.version} disponível'
                        : 'Procurar atualizações',
                  ),
                  subtitle: Text(
                    update.isLoading
                        ? 'A verificar…'
                        : info != null
                        ? 'Toca para descarregar e instalar'
                        : 'Estás na versão mais recente',
                  ),
                  onTap: info != null
                      ? () => showUpdateDialog(context, info)
                      : () => ref.invalidate(updateProvider),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Overload ${ref.watch(appVersionProvider).value ?? ''} · Todos os dados ficam apenas neste dispositivo.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
