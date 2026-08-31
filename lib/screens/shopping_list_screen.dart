import 'package:flutter/material.dart';

import '../models/inventory_item.dart';
import '../services/database_helper.dart';
import '../theme/easy_vorrat_theme.dart';
import '../widgets/easy_vorrat_widgets.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  List<InventoryItem> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final items = await DatabaseHelper.instance.getShoppingListItems();

    if (!mounted) {
      return;
    }

    setState(() {
      _items = items;
      _isLoading = false;
    });
  }

  Future<void> _markPurchased(InventoryItem item) async {
    final purchased = item.shoppingQuantityValue;

    if (purchased == null || purchased <= 0) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Für diesen Artikel ist noch keine Einkaufsmenge festgelegt.',
          ),
        ),
      );
      return;
    }

    await DatabaseHelper.instance.markItemAsPurchased(item);

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${item.name}: Einkauf zum Bestand hinzugefügt.')),
    );

    await _loadItems();
  }

  String _shoppingAmount(InventoryItem item) {
    final amount = item.shoppingQuantity.trim();

    if (amount.isEmpty) {
      return 'Einkaufsmenge noch nicht festgelegt';
    }

    if (item.unit.trim().isEmpty) {
      return amount;
    }

    return '$amount ${item.unit}';
  }

  String _currentAmount(InventoryItem item) {
    final amount = item.quantity.trim();

    if (amount.isEmpty) {
      return 'kein Bestand';
    }

    if (item.unit.trim().isEmpty) {
      return amount;
    }

    return '$amount ${item.unit}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Einkaufsliste')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadItems,
              child: _items.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(24),
                      children: const [
                        SizedBox(height: 80),
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 72,
                          color: EasyVorratColors.green,
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Die Einkaufsliste ist leer.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Alles ausreichend vorhanden.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: EasyVorratColors.textSecondary,
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = _items[index];

                        return EasyVorratPanel(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.shopping_basket_outlined,
                                color: EasyVorratColors.green,
                                size: 30,
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
                                    Text(
                                      'Kaufen: ${_shoppingAmount(item)}',
                                      style: const TextStyle(
                                        color: EasyVorratColors.green,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Bestand: ${_currentAmount(item)}',
                                      style: const TextStyle(
                                        color: EasyVorratColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Lagerort: ${item.defaultLocation}',
                                      style: const TextStyle(
                                        color: EasyVorratColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              FilledButton.icon(
                                onPressed: () => _markPurchased(item),
                                icon: const Icon(Icons.check),
                                label: const Text('Gekauft'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
