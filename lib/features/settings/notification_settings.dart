import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/repositories/settings_repository.dart';
import '../../services/notification_bridge.dart';
import '../notifications/notification_sync.dart';

/// Notification permission status and per-type toggles.
class NotificationSettings extends ConsumerStatefulWidget {
  const NotificationSettings({super.key});

  @override
  ConsumerState<NotificationSettings> createState() =>
      _NotificationSettingsState();
}

class _NotificationSettingsState extends ConsumerState<NotificationSettings>
    with WidgetsBindingObserver {
  NotificationStatus? _status;

  NotificationBridge get _bridge => ref.read(notificationBridgeProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// The user may change permissions in system settings and come back.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final status = await _bridge.status();
    if (mounted) setState(() => _status = status);
  }

  Future<void> _enable() async {
    final granted = await _bridge.requestPermission();
    if (!granted) await _bridge.openSettings();
    await _refresh();
  }

  Future<void> _update(Profile Function(Profile p) change) => ref
      .read(settingsRepositoryProvider)
      .saveProfile(change(ref.read(currentProfileProvider)));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = ref.watch(currentProfileProvider);
    final status = _status;
    final blocked = status != null && !status.notifications;

    return Card(
      child: Column(
        children: [
          if (!_bridge.enabled)
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text(
                'Notificações do sistema só estão disponíveis no Android.',
              ),
            ),
          if (blocked)
            ListTile(
              leading: Icon(
                Icons.notifications_off_outlined,
                color: theme.colorScheme.error,
              ),
              title: const Text('Notificações desativadas'),
              subtitle: const Text(
                'Sem elas não sabes quando o descanso acaba com a app em segundo plano.',
              ),
              trailing: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                onPressed: _enable,
                child: const Text('Ativar'),
              ),
            ),
          if (status != null && status.notifications && status.promoted != null)
            ListTile(
              leading: Icon(
                status.promoted! ? Icons.bolt_rounded : Icons.bolt_outlined,
                color: status.promoted!
                    ? Brand.success
                    : theme.colorScheme.onSurfaceVariant,
              ),
              title: const Text('Live Updates'),
              subtitle: Text(
                status.promoted!
                    ? 'O treino e o descanso aparecem na barra de estado e no ecrã bloqueado.'
                    : 'Desligadas. Ativa para ver o descanso na barra de estado.',
              ),
              trailing: status.promoted!
                  ? null
                  : const Icon(Icons.open_in_new_rounded),
              onTap: () => _bridge.openSettings('promotion'),
            ),
          if (status != null && !status.exactAlarms)
            ListTile(
              leading: Icon(
                Icons.alarm_off_rounded,
                color: theme.colorScheme.error,
              ),
              title: const Text('Alarmes exatos bloqueados'),
              subtitle: const Text(
                'O aviso de fim de descanso pode chegar atrasado.',
              ),
              trailing: const Icon(Icons.open_in_new_rounded),
              onTap: () => _bridge.openSettings('exactAlarms'),
            ),
          SwitchListTile(
            secondary: const Icon(Icons.timer_outlined),
            title: const Text('Treino em curso'),
            subtitle: const Text(
              'Cronómetro, séries e descanso em tempo real, com botões ±15 s e saltar',
            ),
            value: p.liveNotification,
            onChanged: _bridge.enabled
                ? (v) => _update((x) => x.copyWith(liveNotification: v))
                : null,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_outlined),
            title: const Text('Fim do descanso'),
            subtitle: const Text('Som e vibração, mesmo com o ecrã bloqueado'),
            value: p.restAlerts,
            onChanged: (v) => _update((x) => x.copyWith(restAlerts: v)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.local_fire_department_outlined),
            title: const Text('Lembretes'),
            subtitle: const Text(
              'Streak semanal em risco e treinos esquecidos abertos',
            ),
            value: p.reminders,
            onChanged: _bridge.enabled
                ? (v) => _update((x) => x.copyWith(reminders: v))
                : null,
          ),
          if (_bridge.enabled)
            ListTile(
              leading: const Icon(Icons.tune_rounded),
              title: const Text('Definições de notificação do sistema'),
              subtitle: const Text('Som, vibração e prioridade de cada tipo'),
              trailing: const Icon(Icons.open_in_new_rounded),
              onTap: () => _bridge.openSettings(),
            ),
        ],
      ),
    );
  }
}
