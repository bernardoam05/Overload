import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/update_checker.dart';
import '../../services/update_installer.dart';

/// Offers to download and install [info]; falls back to the release page when
/// in-app installation is not available.
Future<void> showUpdateDialog(BuildContext context, UpdateInfo info) async {
  if (!UpdateInstaller.supported || info.apks.isEmpty) {
    await launchUrl(Uri.parse(info.url), mode: LaunchMode.externalApplication);
    return;
  }
  await showDialog<void>(context: context, builder: (_) => _UpdateDialog(info));
}

enum _Stage { ask, needsPermission, downloading, installing, error }

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog(this.info);
  final UpdateInfo info;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  _Stage _stage = _Stage.ask;
  double _progress = 0;
  String _error = '';

  Future<void> _start() async {
    try {
      final url = await UpdateInstaller.apkFor(widget.info);
      if (url == null) {
        await launchUrl(Uri.parse(widget.info.url), mode: LaunchMode.externalApplication);
        if (mounted) Navigator.pop(context);
        return;
      }
      if (!await UpdateInstaller.canInstall()) {
        if (mounted) setState(() => _stage = _Stage.needsPermission);
        return;
      }
      setState(() {
        _stage = _Stage.downloading;
        _progress = 0;
      });
      final apk = await UpdateInstaller.download(widget.info, url, (p) {
        if (mounted) setState(() => _progress = p);
      });
      if (!mounted) return;
      setState(() => _stage = _Stage.installing);
      await UpdateInstaller.install(apk);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _stage = _Stage.error;
          _error = e is FormatException ? e.message : 'Não foi possível atualizar. Verifica a ligação.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _stage == _Stage.downloading || _stage == _Stage.installing;
    return AlertDialog(
      title: Text('Overload ${widget.info.version}'),
      content: switch (_stage) {
        _Stage.ask => const Text('Há uma versão nova. Queres descarregar e instalar agora?'),
        _Stage.needsPermission => const Text(
            'Para instalar a atualização, permite que o Overload instale aplicações. '
            'Ativa a opção no ecrã seguinte, volta atrás e toca em Atualizar.'),
        _Stage.downloading => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('A descarregar…'),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: _progress > 0 ? _progress : null),
            ],
          ),
        _Stage.installing => const Text('A abrir o instalador…'),
        _Stage.error => Text(_error),
      },
      actions: [
        if (!busy) TextButton(onPressed: () => Navigator.pop(context), child: const Text('Agora não')),
        if (_stage == _Stage.needsPermission)
          FilledButton(
            onPressed: () async {
              await UpdateInstaller.openInstallSettings();
              if (mounted) setState(() => _stage = _Stage.ask);
            },
            child: const Text('Abrir definições'),
          )
        else if (!busy)
          FilledButton(onPressed: _start, child: Text(_stage == _Stage.error ? 'Tentar de novo' : 'Atualizar')),
      ],
    );
  }
}
