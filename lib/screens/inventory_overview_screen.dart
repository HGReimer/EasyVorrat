import 'package:flutter/material.dart';

import '../models/inventory_item.dart';
import '../services/database_helper.dart';
import '../theme/easy_vorrat_theme.dart';
import '../widgets/easy_vorrat_widgets.dart';

class InventoryOverviewScreen extends StatefulWidget {
  const InventoryOverviewScreen({super.key});

  @override
  State<InventoryOverviewScreen> createState() =>
      _InventoryOverviewScreenState();
}

class _InventoryOverviewScreenState extends State<InventoryOverviewScreen> {
  List<InventoryItem> _items = [];
  bool _isLoading = true;
  String _query = '';
  String _selectedLocation = 'Alle Lagerorte';

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final items = await DatabaseHelper.instance.getAllInventoryItems();

    if (!mounted) return;

    setState(() {
      _items = items;
      _isLoading = false;
    });
  }

  List<String> get _locations {
    final locations =
        _items
            .map((item) => item.location.trim())
            .where((location) => location.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return ['Alle Lagerorte', ...locations];
  }

  List<InventoryItem> get _visibleItems {
    final query = _query.trim().toLowerCase();

    return _items.where((item) {
      final matchesLocation =
          _selectedLocation == 'Alle Lagerorte' ||
          item.location == _selectedLocation;
      final searchableText = '${item.name} ${item.unit} ${item.location}'
          .toLowerCase();
      final matchesQuery = query.isEmpty || searchableText.contains(query);

      return matchesLocation && matchesQuery;
    }).toList();
  }

  String _amount(InventoryItem item) {
    final quantity = item.quantity.trim();

    if (quantity.isEmpty) return 'nicht angegeben';
    if (item.unit.trim().isEmpty) return quantity;

    return '$quantity ${item.unit}';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final visibleItems = _visibleItems;

    return Scaffold(
      appBar: AppBar(title: const Text('Bestandsliste')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadItems,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  TextField(
                    onChanged: (value) {
                      setState(() => _query = value);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Bestand durchsuchen',
                      hintText: 'z. B. Milch',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    key: ValueKey(_selectedLocation),
                    initialValue: _selectedLocation,
                    decoration: const InputDecoration(
                      labelText: 'Lagerort',
                      prefixIcon: Icon(Icons.storage_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final location in _locations)
                        DropdownMenuItem(
                          value: location,
                          child: Text(location),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedLocation = value);
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  EasyVorratSectionHeader(
                    title: '${visibleItems.length} Artikel',
                    icon: Icons.inventory_2_outlined,
                  ),
                  const SizedBox(height: 10),
                  if (visibleItems.isEmpty)
                    const EasyVorratPanel(
                      child: Text(
                        'Keine passenden Vorräte gefunden.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    for (final item in visibleItems) ...[
                      EasyVorratPanel(
                        borderColor: item.hasReachedMinimum
                            ? EasyVorratColors.warning
                            : null,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              item.hasReachedMinimum
                                  ? Icons.warning_amber_rounded
                                  : Icons.inventory_2_outlined,
                              color: item.hasReachedMinimum
                                  ? EasyVorratColors.warning
                                  : EasyVorratColors.green,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text('Bestand: ${_amount(item)}'),
                                  Text(
                                    'Lagerort: ${item.location}',
                                    style: const TextStyle(
                                      color: EasyVorratColors.textSecondary,
                                    ),
                                  ),
                                  if (item.expiryDate != null)
                                    Text(
                                      'MHD: ${_formatDate(item.expiryDate!)}',
                                      style: const TextStyle(
                                        color: EasyVorratColors.textSecondary,
                                      ),
                                    ),
                                  if (item.isOnShoppingList)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 5),
                                      child: Text(
                                        'Auf der Einkaufsliste',
                                        style: TextStyle(
                                          color: EasyVorratColors.warning,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                ],
              ),
            ),
    );
  }
}
