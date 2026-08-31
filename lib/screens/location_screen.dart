import 'package:flutter/material.dart';

import '../models/inventory_item.dart';
import '../services/database_helper.dart';
import 'add_item_screen.dart';

class LocationScreen extends StatefulWidget {
  final String locationName;

  const LocationScreen({super.key, required this.locationName});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  List<InventoryItem> items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final loaded = await DatabaseHelper.instance.getItemsForLocation(
      widget.locationName,
    );

    if (!mounted) return;

    setState(() {
      items = loaded;
      _loading = false;
    });
  }

  Future<void> _openAddItemScreen() async {
    final item = await Navigator.push<InventoryItem>(
      context,
      MaterialPageRoute(
        builder: (_) => AddItemScreen(locationName: widget.locationName),
      ),
    );

    if (!mounted || item == null) return;

    await DatabaseHelper.instance.insertItem(item);
    await _loadItems();
  }

  Future<void> _deleteItem(InventoryItem item) async {
    if (item.id != null) {
      await DatabaseHelper.instance.deleteItem(item.id!);
    }

    await _loadItems();
  }

  Future<void> _addToShoppingList(InventoryItem item) async {
    if (item.isOnShoppingList) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.name} steht bereits auf der Einkaufsliste.'),
        ),
      );
      return;
    }

    final controller = TextEditingController(
      text: item.shoppingQuantity.isNotEmpty ? item.shoppingQuantity : '',
    );

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('${item.name} einkaufen'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Einkaufsmenge',
              suffixText: item.unit.isEmpty ? null : item.unit,
              hintText: 'z. B. 2',
            ),
            onSubmitted: (value) {
              Navigator.pop(dialogContext, value);
            },
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
              icon: const Icon(Icons.shopping_cart_outlined),
              label: const Text('Hinzufügen'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (!mounted || result == null) {
      return;
    }

    final normalized = result.trim().replaceAll(',', '.');
    final amount = double.tryParse(normalized);

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte eine gültige Einkaufsmenge eingeben.'),
        ),
      );
      return;
    }

    await DatabaseHelper.instance.updateItem(
      item.copyWith(shoppingQuantity: normalized, isOnShoppingList: true),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.name} wurde auf die Einkaufsliste gesetzt.'),
      ),
    );

    await _loadItems();
  }

  String _formatExpiryDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.locationName)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
          ? const Center(child: Text('Noch keine Artikel vorhanden.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final expiry = item.expiryDate;

                final daysLeft = expiry?.difference(DateTime.now()).inDays;

                final isExpiringSoon = daysLeft != null && daysLeft <= 3;

                return Card(
                  child: ListTile(
                    leading: Icon(
                      item.isOnShoppingList
                          ? Icons.shopping_cart
                          : Icons.inventory_2_outlined,
                      color: item.isOnShoppingList
                          ? Theme.of(context).colorScheme.primary
                          : isExpiringSoon
                          ? Colors.orangeAccent
                          : null,
                    ),
                    title: Text(item.name),
                    subtitle: Text(
                      [
                        [
                          item.quantity,
                          item.unit,
                        ].where((value) => value.isNotEmpty).join(' '),
                        if (expiry != null)
                          'MHD: ${_formatExpiryDate(expiry)}'
                              '${isExpiringSoon ? ' ⚠️' : ''}',
                        if (item.isOnShoppingList) 'Auf Einkaufsliste',
                      ].where((value) => value.isNotEmpty).join(' · '),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () {
                            _addToShoppingList(item);
                          },
                          icon: Icon(
                            item.isOnShoppingList
                                ? Icons.shopping_cart
                                : Icons.add_shopping_cart,
                          ),
                          tooltip: item.isOnShoppingList
                              ? 'Bereits auf Einkaufsliste'
                              : 'Zur Einkaufsliste',
                        ),
                        IconButton(
                          onPressed: () {
                            _deleteItem(item);
                          },
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Artikel entfernen',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddItemScreen,
        icon: const Icon(Icons.add),
        label: const Text('Artikel hinzufügen'),
      ),
    );
  }
}
