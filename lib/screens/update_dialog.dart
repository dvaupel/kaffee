import 'package:flutter/material.dart';

import '../updater.dart';

/// Fragt nach Updates. Beim Start still ([silent]), sonst mit Rückmeldung.
Future<void> runUpdateCheck(BuildContext context, {bool silent = true}) async {
  final messenger = ScaffoldMessenger.of(context);
  UpdateInfo? info;
  try {
    info = await checkForUpdate();
  } catch (e) {
    if (!silent) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Update-Suche fehlgeschlagen. Internet prüfen.')));
    }
    return;
  }
  if (!context.mounted) return;
  if (info == null) {
    if (!silent) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Die App ist auf dem neuesten Stand.')));
    }
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (_) => _UpdateDialog(info: info!),
  );
}

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({required this.info});
  final UpdateInfo info;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _busy = false;
  double? _progress;
  String? _error;

  Future<void> _install() async {
    setState(() {
      _busy = true;
      _error = null;
      _progress = 0;
    });
    try {
      await downloadAndInstall(widget.info, onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      });
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Das hat nicht geklappt: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.info;
    final mb =
        u.size > 0 ? ' (${(u.size / 1048576).toStringAsFixed(1)} MB)' : '';
    return AlertDialog(
      title: Text('Version ${u.version} verfügbar'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Neue Version herunterladen und installieren$mb?'),
            if (u.notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(u.notes, style: Theme.of(context).textTheme.bodySmall),
            ],
            if (_busy) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _progress),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Später'),
        ),
        FilledButton(
          onPressed: _busy ? null : _install,
          child: const Text('Aktualisieren'),
        ),
      ],
    );
  }
}
