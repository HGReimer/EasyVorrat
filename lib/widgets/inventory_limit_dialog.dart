import 'dart:async';

import 'package:flutter/material.dart';

import '../services/database_helper.dart';
import '../services/plus_service.dart';

Future<bool> ensureInventorySlot(BuildContext context) async {
  await PlusService.instance.initialize();
  if (!context.mounted) return false;
  if (PlusService.instance.isPlus) return true;
  final items = await DatabaseHelper.instance.getAllInventoryItems();
  if (!context.mounted) return false;
  if (PlusService.instance.isPlus || items.length < PlusService.freeItemLimit) {
    return true;
  }
  return showEasyVorratPlusDialog(context);
}

Future<bool> showEasyVorratPlusDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => const _PlusDialog(),
  );
  return result == true && PlusService.instance.isPlus;
}

class _PlusDialog extends StatefulWidget {
  const _PlusDialog();
  @override
  State<_PlusDialog> createState() => _PlusDialogState();
}

class _PlusDialogState extends State<_PlusDialog> {
  final service = PlusService.instance;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    service.addListener(_onPlusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _onPlusChanged();
      unawaited(service.loadOffer());
    });
  }

  void _onPlusChanged() {
    if (!service.isPlus || _closing) return;
    _closing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context, true);
    });
  }

  @override
  void dispose() {
    service.removeListener(_onPlusChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: service,
    builder: (context, _) => AlertDialog(
      title: const Text('EasyVorrat Plus'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Deine 10 kostenlosen Bestandsartikel sind erreicht. '
              'Mit Plus kannst du beliebig viele Artikel verwalten.',
            ),
            const SizedBox(height: 16),
            Text(
              '${service.price} einmalig · kein Abo',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Deine vorhandenen Artikel bleiben erhalten '
              'und können weiterhin bearbeitet werden.',
            ),
            const SizedBox(height: 16),
            if (service.busy) const LinearProgressIndicator(),
            if (service.message != null) ...[
              const SizedBox(height: 12),
              Text(service.message!),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: service.canBuy ? service.buy : null,
              icon: const Icon(Icons.workspace_premium_outlined),
              label: Text('Für ${service.price} freischalten'),
            ),
            TextButton(
              onPressed: service.supportsPurchases && !service.busy
                  ? service.restore
                  : null,
              child: const Text('Käufe wiederherstellen'),
            ),
            if (service.supportsPurchases && !service.available)
              TextButton(
                onPressed: service.busy ? null : service.loadOffer,
                child: const Text('Erneut laden'),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Später'),
        ),
      ],
    ),
  );
}
