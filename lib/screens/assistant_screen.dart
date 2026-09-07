import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

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
  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;

  String _answer =
      'Hallo, ich bin dein EasyAssistent. Was möchtest du über deinen Vorrat wissen?';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
  }

  Future<void> _initializeSpeech() async {
    final available = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) return;

        setState(() {
          _isListening = status == 'listening';
        });
      },
      onError: (error) {
        if (!mounted) return;

        setState(() {
          _isListening = false;
          _answer = 'Spracherkennung: ${error.errorMsg}';
        });
      },
    );

    if (!mounted) return;

    setState(() {
      _speechAvailable = available;
    });
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (_speech.isListening) {
      await _speech.stop();

      if (!mounted) return;

      setState(() {
        _isListening = false;
      });
      return;
    }

    if (!_speechAvailable) {
      setState(() {
        _answer = 'Die Spracherkennung ist in diesem Browser nicht verfügbar.';
      });
      return;
    }

    final locales = await _speech.locales();
    String? germanLocale;

    for (final locale in locales) {
      if (locale.localeId.toLowerCase().startsWith('de')) {
        germanLocale = locale.localeId;
        break;
      }
    }

    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;

        setState(() {
          _questionController.text = result.recognizedWords;
          _questionController.selection = TextSelection.collapsed(
            offset: _questionController.text.length,
          );
        });
      },
      listenOptions: SpeechListenOptions(localeId: germanLocale),
    );

    if (!mounted) return;

    setState(() {
      _isListening = _speech.isListening;
    });
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

  Future<String> _consumeExistingItem(String question) async {
    final items = await DatabaseHelper.instance.getAllInventoryItems();

    if (!mounted) return 'Die Aktion wurde abgebrochen.';

    final normalized = question.toLowerCase();
    final matches = items.where((item) {
      return normalized.contains(item.name.toLowerCase());
    }).toList();

    if (matches.isEmpty) {
      return 'Ich finde diesen Artikel nicht im Bestand.';
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

    final numberMatch = RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(normalized);
    final amountText = numberMatch?.group(1);

    if (amountText == null) {
      return 'Nenne bitte auch die verbrauchte Menge.';
    }

    final amount = double.tryParse(amountText.replaceAll(',', '.'));
    final current = selectedItem.quantityValue;

    if (amount == null || amount <= 0) {
      return 'Die Verbrauchsmenge muss größer als 0 sein.';
    }

    if (current == null) {
      return 'Die vorhandene Menge von ${selectedItem.name} '
          'ist keine gültige Zahl.';
    }

    if (amount > current) {
      return 'Es sind nur ${_amount(selectedItem)} vorhanden. '
          'Du kannst nicht mehr verbrauchen als im Bestand ist.';
    }

    String formatNumber(double value) {
      if (value == value.roundToDouble()) {
        return value.toInt().toString();
      }

      return value
          .toStringAsFixed(3)
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');
    }

    final remaining = current - amount;
    final unit = selectedItem.unit.trim();
    final suffix = unit.isEmpty ? '' : ' $unit';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Verbrauch bestätigen'),
          content: Text(
            '${selectedItem!.name}\n\n'
            'Bisher: ${formatNumber(current)}$suffix\n'
            'Verbrauch: ${formatNumber(amount)}$suffix\n'
            'Danach: ${formatNumber(remaining)}$suffix',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Abbrechen'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              icon: const Icon(Icons.remove_circle_outline),
              label: const Text('Verbrauch buchen'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) {
      return 'Die Aktion wurde abgebrochen.';
    }

    await DatabaseHelper.instance.consumeItem(
      item: selectedItem,
      amount: amount,
    );

    if (remaining <= 0) {
      if (selectedItem.autoShoppingList) {
        return '${selectedItem.name}: Bestand ist jetzt 0$suffix. '
            'Der Artikel steht auf der Einkaufsliste.';
      }

      return '${selectedItem.name} wurde vollständig verbraucht '
          'und aus dem Bestand entfernt.';
    }

    final minimum = selectedItem.minimumQuantityValue;

    if (selectedItem.autoShoppingList &&
        minimum != null &&
        remaining <= minimum) {
      return '${selectedItem.name}: Neuer Bestand '
          '${formatNumber(remaining)}$suffix. '
          'Der Mindestbestand ist erreicht; der Artikel steht jetzt '
          'auf der Einkaufsliste.';
    }

    return '${selectedItem.name}: Neuer Bestand '
        '${formatNumber(remaining)}$suffix.';
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

    final isConsumptionAction =
        normalized.contains('verbrauch') ||
        normalized.contains('entnomm') ||
        normalized.contains('genommen') ||
        normalized.contains('getrunken') ||
        normalized.contains('benutzt');

    final String answer;

    if (isShoppingAction) {
      answer = await _addExistingItemToShoppingList(question);
    } else if (isConsumptionAction) {
      answer = await _consumeExistingItem(question);
    } else {
      answer = await _createAnswer(question);
    }

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
            decoration: InputDecoration(
              labelText: _isListening ? 'Ich höre zu …' : 'Deine Frage',
              hintText: 'z. B. Wie viel Milch ist vorhanden?',
              prefixIcon: const Icon(Icons.chat_outlined),
              suffixIcon: IconButton(
                onPressed: _toggleListening,
                tooltip: _isListening ? 'Zuhören beenden' : 'Spracheingabe',
                icon: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  color: _isListening
                      ? EasyVorratColors.danger
                      : EasyVorratColors.green,
                ),
              ),
              border: const OutlineInputBorder(),
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
