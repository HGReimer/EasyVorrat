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
                      Icons.inventory_2_outlined,
                      color: isExpiringSoon ? Colors.orangeAccent : null,
                    ),
                    title: Text(item.name),
                    subtitle: Text(
                      [
                        [
                          item.quantity,
                          item.unit,
                        ].where((v) => v.isNotEmpty).join(' '),
                        if (expiry != null)
                          'MHD: ${expiry.day.toString().padLeft(2, '0')}.'
                              '${expiry.month.toString().padLeft(2, '0')}.'
                              '${expiry.year}'
                              '${isExpiringSoon ? ' ⚠️' : ''}',
                      ].where((v) => v.isNotEmpty).join(' · '),
                    ),
                    trailing: IconButton(
                      onPressed: () => _deleteItem(item),
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Artikel entfernen',
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
