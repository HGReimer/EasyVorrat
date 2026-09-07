import 'package:flutter/material.dart';

import '../models/inventory_item.dart';
import '../services/database_helper.dart';
import '../theme/easy_vorrat_theme.dart';
import '../widgets/easy_vorrat_widgets.dart';

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _questionController = TextEditingController();
  String _answer =
      'Hallo, ich bin dein EasyAssistent. Was möchtest du über deinen Vorrat wissen?';
  bool _isLoading = false;

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  String _amount(InventoryItem item) {
    final quantity = item.quantity.trim();

    if (quantity.isEmpty) return 'Menge nicht angegeben';
    if (item.unit.trim().isEmpty) return quantity;

    return '$quantity ${item.unit}';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }

  String _itemLine(InventoryItem item) {
    return '${item.name}: ${_amount(item)} – ${item.location}';
  }

  String _shoppingLine(InventoryItem item) {
    final amount = item.shoppingQuantity.trim();
    final shoppingAmount = amount.isEmpty
        ? 'Menge nicht angegeben'
        : item.unit.trim().isEmpty
        ? amount
        : '$amount ${item.unit}';

    return '${item.name}: $shoppingAmount kaufen '
        '– danach nach ${item.defaultLocation}';
  }

  Future<String> _addExistingItemToShoppingList(String question) async {
    final items = await DatabaseHelper.instance.getAllInventoryItems();

    if (!mounted) return 'Die Aktion wurde abgebrochen.';

    final normalized = question.toLowerCase();
    final matches = items.where((item) {
      return normalized.contains(item.name.toLowerCase());
    }).toList();

    if (matches.isEmpty) {
      return 'Ich finde diesen Artikel nicht im Bestand. '
          'Neue Artikel kannst du direkt in der Einkaufsliste hinzufügen.';
    }

    InventoryItem? selectedItem;

    if (matches.length == 1) {
      selectedItem = matches.first;
    } else {
      final locationMatches = matches.where((item) {
        return normalized.contains(item.location.toLowerCase());
      }).toList();

      if (locationMatches.length == 1) {
        selectedItem = locationMatches.first;
      }
    }

    if (selectedItem == null) {
      return 'Ich habe mehrere passende Artikel gefunden. '
          'Nenne bitte zusätzlich den Lagerort.';
    }

    if (selectedItem.isOnShoppingList) {
      return '${selectedItem.name} steht bereits auf der Einkaufsliste.';
    }

    final item = selectedItem;
    final controller = TextEditingController(text: item.shoppingQuantity);

    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('${item.name} auf die Einkaufsliste?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Aktueller Bestand: ${_amount(item)}'),
              Text('Lagerort: ${item.location}'),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Nachkaufmenge',
                  suffixText: item.unit.isEmpty ? null : item.unit,
                  hintText: 'z. B. 6',
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (value) {
                  Navigator.pop(dialogContext, value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Abbrechen'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext, controller.text);
              },
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Bestätigen'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (!mounted || result == null) {
      return 'Die Aktion wurde abgebrochen.';
    }

    final normalizedAmount = result.trim().replaceAll(',', '.');
    final amount = double.tryParse(normalizedAmount);

    if (amount == null || amount <= 0) {
      return 'Bitte gib eine gültige Nachkaufmenge ein.';
    }

    await DatabaseHelper.instance.updateItem(
      item.copyWith(shoppingQuantity: normalizedAmount, isOnShoppingList: true),
    );

    final amountText = item.unit.trim().isEmpty
        ? normalizedAmount
        : '$normalizedAmount ${item.unit}';

    return '${item.name} wurde mit $amountText '
        'auf die Einkaufsliste gesetzt.';
  }

  Future<String> _createAnswer(String question) async {
    final items = await DatabaseHelper.instance.getAllInventoryItems();
    final shoppingItems = await DatabaseHelper.instance.getShoppingListItems();
    final normalized = question.trim().toLowerCase();

    if (normalized.contains('einkauf')) {
      if (shoppingItems.isEmpty) {
        return 'Die Einkaufsliste ist leer.';
      }

      return 'Auf der Einkaufsliste stehen:\n'
          '${shoppingItems.map(_shoppingLine).join('\n')}';
    }

    if (normalized.contains('ablauf') ||
        normalized.contains('mhd') ||
        normalized.contains('haltbar')) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final limit = today.add(const Duration(days: 7));

      final expiring = items.where((item) {
        final date = item.expiryDate;
        return date != null && !date.isAfter(limit);
      }).toList()..sort((a, b) => a.expiryDate!.compareTo(b.expiryDate!));

      if (expiring.isEmpty) {
        return 'In den nächsten sieben Tagen läuft kein Artikel ab.';
      }

      return 'Bald ablaufend oder bereits abgelaufen:\n'
          '${expiring.map((item) {
            return '${item.name}: ${_formatDate(item.expiryDate!)} '
                '– ${item.location}';
          }).join('\n')}';
    }

    final locations = items
        .map((item) => item.location)
        .where((location) => location.trim().isNotEmpty)
        .toSet();

    for (final location in locations) {
      if (normalized.contains(location.toLowerCase())) {
        final locationItems = items
            .where((item) => item.location == location)
            .toList();

        if (locationItems.isEmpty) {
          return 'Im Lagerort $location ist derzeit nichts eingetragen.';
        }

        return 'Im Lagerort $location befinden sich:\n'
            '${locationItems.map(_itemLine).join('\n')}';
      }
    }

    final matchingItems = items.where((item) {
      return normalized.contains(item.name.toLowerCase());
    }).toList();

    if (matchingItems.isNotEmpty) {
      return matchingItems.map(_itemLine).join('\n');
    }

    if (normalized.contains('bestand') ||
        normalized.contains('vorrat') ||
        normalized.contains('artikel') ||
        normalized.contains('was haben wir')) {
      if (items.isEmpty) {
        return 'Der Bestand ist derzeit leer.';
      }

      return 'Aktueller Bestand – ${items.length} Artikel:\n'
          '${items.map(_itemLine).join('\n')}';
    }

    return 'Das habe ich noch nicht verstanden. Frage mich zum Beispiel:\n'
        '• Wie viel Milch ist vorhanden?\n'
        '• Was ist im Kühlschrank?\n'
        '• Was läuft bald ab?\n'
        '• Was steht auf der Einkaufsliste?\n'
        '• Zeige meinen Bestand.';
  }

  Future<void> _ask([String? suggestedQuestion]) async {
    final question = suggestedQuestion ?? _questionController.text.trim();

    if (question.isEmpty || _isLoading) return;

    _questionController.text = question;

    setState(() {
      _isLoading = true;
      _answer = 'Ich prüfe deinen Vorrat …';
    });

    final normalized = question.toLowerCase();
    final isShoppingAction =
        normalized.contains('einkauf') &&
        (normalized.contains('setz') ||
            normalized.contains('füg') ||
            normalized.contains('pack') ||
            normalized.contains('schreib'));

    final answer = isShoppingAction
        ? await _addExistingItemToShoppingList(question)
        : await _createAnswer(question);

    if (!mounted) return;

    setState(() {
      _answer = answer;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('EasyAssistent')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(
            Icons.smart_toy_outlined,
            size: 72,
            color: EasyVorratColors.green,
          ),
          const SizedBox(height: 12),
          const Text(
            'Frag deinen Vorrat',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _questionController,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _ask(),
            decoration: const InputDecoration(
              labelText: 'Deine Frage',
              hintText: 'z. B. Wie viel Milch ist vorhanden?',
              prefixIcon: Icon(Icons.chat_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _isLoading ? null : () => _ask(),
            icon: const Icon(Icons.send),
            label: const Text('Fragen'),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                label: const Text('Gesamtbestand'),
                onPressed: () => _ask('Zeige meinen Bestand'),
              ),
              ActionChip(
                label: const Text('Bald ablaufend'),
                onPressed: () => _ask('Was läuft bald ab?'),
              ),
              ActionChip(
                label: const Text('Einkaufsliste'),
                onPressed: () => _ask('Was steht auf der Einkaufsliste?'),
              ),
            ],
          ),
          const SizedBox(height: 22),
          EasyVorratPanel(
            borderColor: EasyVorratColors.green,
            child: SelectableText(
              _answer,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
