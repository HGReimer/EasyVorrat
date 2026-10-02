import '../widgets/inventory_limit_dialog.dart';
import '../services/plus_service.dart';
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
    if (!await ensureInventorySlot(context) || !mounted) return;

    final item = await Navigator.push<InventoryItem>(
      context,
      MaterialPageRoute(
        builder: (_) => AddItemScreen(locationName: widget.locationName),
      ),
    );

    if (!mounted || item == null) return;

    try {
      await DatabaseHelper.instance.insertItem(item);
    } on InventoryLimitException {
      if (!mounted) return;
      await showEasyVorratPlusDialog(context);
      return;
    }
    await _loadItems();
  }

  Future<void> _editItem(InventoryItem item) async {
    final updatedItem = await Navigator.push<InventoryItem>(
      context,
      MaterialPageRoute<InventoryItem>(
        builder: (_) => AddItemScreen(
          locationName: widget.locationName,
          existingItem: item,
        ),
      ),
    );

    if (!mounted || updatedItem == null) return;

    await DatabaseHelper.instance.updateItem(updatedItem);

    if (!mounted) return;

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

  Future<void> _moveItem(InventoryItem item) async {
    final locations = await DatabaseHelper.instance.getLocations();
    final availableLocations = locations
        .where((location) => location.name != item.location)
        .toList();

    if (!mounted) return;

    if (availableLocations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Es ist kein anderer Lagerort vorhanden.'),
        ),
      );
      return;
    }

    var targetLocation = availableLocations.first.name;
    var moveAll = true;
    String? errorText;
    final amountController = TextEditingController();

    final result = await showDialog<({String location, double? amount})>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('${item.name} umlagern'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vorhanden: ${item.quantity}'
                      '${item.unit.isEmpty ? '' : ' ${item.unit}'}',
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: targetLocation,
                      decoration: const InputDecoration(
                        labelText: 'Neuer Lagerort',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final location in availableLocations)
                          DropdownMenuItem(
                            value: location.name,
                            child: Text(location.name),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            targetLocation = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: moveAll,
                      title: const Text('Gesamten Bestand umlagern'),
                      onChanged: (value) {
                        setDialogState(() {
                          moveAll = value ?? true;
                          errorText = null;
                        });
                      },
                    ),
                    if (!moveAll) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: amountController,
                        autofocus: true,
                        keyboardType: TextInputType.text,
                        decoration: InputDecoration(
                          labelText: 'Teilmenge',
                          hintText: 'z. B. 1 oder 2 x 1',
                          suffixText: item.unit.isEmpty ? null : item.unit,
                          errorText: errorText,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ],
                ),
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
                    double? amount;

                    if (!moveAll) {
                      amount = item
                          .copyWith(quantity: amountController.text)
                          .quantityValue;
                      final current = item.quantityValue;

                      if (amount == null ||
                          current == null ||
                          amount <= 0 ||
                          amount > current) {
                        setDialogState(() {
                          errorText = 'Bitte eine gültige Teilmenge eingeben.';
                        });
                        return;
                      }
                    }

                    Navigator.pop(dialogContext, (
                      location: targetLocation,
                      amount: moveAll ? null : amount,
                    ));
                  },
                  icon: const Icon(Icons.drive_file_move_outline),
                  label: const Text('Umlagern'),
                ),
              ],
            );
          },
        );
      },
    );

    amountController.dispose();

    if (!mounted || result == null) return;

    try {
      await DatabaseHelper.instance.moveItem(
        item: item,
        newLocation: result.location,
        amount: result.amount,
      );
    } on InventoryLimitException {
      if (!mounted) return;
      await showEasyVorratPlusDialog(context);
      return;
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.name} wurde nach ${result.location} umgelagert.'),
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
                    trailing: PopupMenuButton<_ItemAction>(
                      tooltip: 'Artikel verwalten',
                      onSelected: (action) async {
                        switch (action) {
                          case _ItemAction.edit:
                            await _editItem(item);
                          case _ItemAction.move:
                            await _moveItem(item);
                          case _ItemAction.shopping:
                            await _addToShoppingList(item);
                          case _ItemAction.delete:
                            await _deleteItem(item);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: _ItemAction.edit,
                          child: ListTile(
                            leading: Icon(Icons.edit_outlined),
                            title: Text('Bearbeiten'),
                          ),
                        ),
                        const PopupMenuItem(
                          value: _ItemAction.move,
                          child: ListTile(
                            leading: Icon(Icons.drive_file_move_outline),
                            title: Text('Umlagern'),
                          ),
                        ),
                        PopupMenuItem(
                          value: _ItemAction.shopping,
                          enabled: !item.isOnShoppingList,
                          child: ListTile(
                            leading: Icon(
                              item.isOnShoppingList
                                  ? Icons.shopping_cart
                                  : Icons.add_shopping_cart,
                            ),
                            title: Text(
                              item.isOnShoppingList
                                  ? 'Bereits auf Einkaufsliste'
                                  : 'Zur Einkaufsliste',
                            ),
                          ),
                        ),
                        const PopupMenuItem(
                          value: _ItemAction.delete,
                          child: ListTile(
                            leading: Icon(Icons.delete_outline),
                            title: Text('Entfernen'),
                          ),
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

enum _ItemAction { edit, move, shopping, delete }
