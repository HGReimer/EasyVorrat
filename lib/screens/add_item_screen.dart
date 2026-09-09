import 'package:flutter/material.dart';

import '../models/inventory_item.dart';
import '../services/product_lookup_service.dart';
import 'barcode_scanner_screen.dart';

class AddItemScreen extends StatefulWidget {
  final String locationName;
  final bool shoppingMode;
  final InventoryItem? existingItem;

  const AddItemScreen({
    super.key,
    required this.locationName,
    this.shoppingMode = false,
    this.existingItem,
  });

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final nameController = TextEditingController();
  final quantityController = TextEditingController();
  final unitController = TextEditingController();
  final minimumQuantityController = TextEditingController();
  final shoppingQuantityController = TextEditingController();
  bool _autoShoppingList = false;
  DateTime? _expiryDate;
  String? _scannedCode;
  String? _productImageUrl;
  bool _isLookingUpProduct = false;

  @override
  void initState() {
    super.initState();

    final item = widget.existingItem;
    if (item == null) return;

    nameController.text = item.name;
    quantityController.text = item.quantity;
    unitController.text = item.unit;
    minimumQuantityController.text = item.minimumQuantity;
    shoppingQuantityController.text = item.shoppingQuantity;
    _autoShoppingList = item.autoShoppingList;
    _expiryDate = item.expiryDate;
  }

  @override
  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    unitController.dispose();
    minimumQuantityController.dispose();
    shoppingQuantityController.dispose();
    super.dispose();
  }

  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() => _expiryDate = picked);
    }
  }

  void _applyPackageQuantity(String packageQuantity) {
    final match = RegExp(
      r'^(\d+(?:[.,]\d+)?)\s*(ml|cl|dl|l|g|kg|stück)$',
      caseSensitive: false,
    ).firstMatch(packageQuantity.trim());

    if (match == null) return;

    if (quantityController.text.trim().isEmpty) {
      quantityController.text = match.group(1)!.replaceAll(',', '.');
    }

    if (unitController.text.trim().isEmpty) {
      final unit = match.group(2)!;
      unitController.text = unit.toLowerCase() == 'stück'
          ? 'Stück'
          : unit.toLowerCase();
    }
  }

  Future<void> _scanBarcode() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );

    if (!mounted || code == null) return;

    setState(() {
      _scannedCode = code;
      _productImageUrl = null;
      _isLookingUpProduct = true;
    });

    try {
      final product = await ProductLookupService.findByBarcode(code);

      if (!mounted) return;

      if (product == null) {
        if (nameController.text.trim().isEmpty) {
          nameController.text = code;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Produkt nicht gefunden. Bitte die Daten selbst eintragen.',
            ),
          ),
        );
        return;
      }

      setState(() {
        nameController.text = product.displayName;
        _applyPackageQuantity(product.packageQuantity);
        _productImageUrl = product.imageUrl.isEmpty ? null : product.imageUrl;
      });

      final packageText = product.packageQuantity.isEmpty
          ? ''
          : ' (${product.packageQuantity})';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${product.displayName}$packageText erkannt.')),
      );
    } catch (_) {
      if (!mounted) return;

      if (nameController.text.trim().isEmpty) {
        nameController.text = code;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Produktdaten konnten nicht geladen werden. '
            'Bitte Internetverbindung prüfen.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLookingUpProduct = false;
        });
      }
    }
  }

  void _save() {
    final name = nameController.text.trim();
    final quantity = quantityController.text.trim();
    final unit = unitController.text.trim();

    if (name.isEmpty) return;

    if (widget.shoppingMode) {
      final shoppingAmount = double.tryParse(quantity.replaceAll(',', '.'));
      if (shoppingAmount == null || shoppingAmount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bitte eine gültige Einkaufsmenge eingeben.'),
          ),
        );
        return;
      }
    }

    if (!widget.shoppingMode && _autoShoppingList) {
      final currentAmount = double.tryParse(quantity.replaceAll(',', '.'));
      final minimumAmount = double.tryParse(
        minimumQuantityController.text.trim().replaceAll(',', '.'),
      );
      final shoppingAmount = double.tryParse(
        shoppingQuantityController.text.trim().replaceAll(',', '.'),
      );

      if (currentAmount == null || currentAmount < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bitte eine gültige Menge eingeben.')),
        );
        return;
      }

      if (minimumAmount == null || minimumAmount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Der Mindestbestand muss größer als 0 sein.'),
          ),
        );
        return;
      }

      if (shoppingAmount == null || shoppingAmount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Die Nachkaufmenge muss größer als 0 sein.'),
          ),
        );
        return;
      }
    }

    Navigator.pop(
      context,
      InventoryItem(
        id: widget.existingItem?.id,
        name: name,
        quantity: widget.shoppingMode ? '0' : quantity,
        unit: unit,
        location: widget.locationName,
        defaultLocation: widget.existingItem?.defaultLocation,
        expiryDate: _expiryDate,
        minimumQuantity: widget.shoppingMode
            ? ''
            : minimumQuantityController.text.trim(),
        shoppingQuantity: widget.shoppingMode
            ? quantity
            : shoppingQuantityController.text.trim(),
        autoShoppingList: !widget.shoppingMode && _autoShoppingList,
        isOnShoppingList: widget.shoppingMode
            ? true
            : widget.existingItem?.isOnShoppingList ?? false,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.shoppingMode
              ? 'Einkaufsartikel hinzufügen'
              : widget.existingItem == null
              ? 'Artikel hinzufügen'
              : 'Artikel bearbeiten',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            OutlinedButton.icon(
              onPressed: _isLookingUpProduct ? null : _scanBarcode,
              icon: _isLookingUpProduct
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.qr_code_scanner),
              label: Text(
                _isLookingUpProduct
                    ? 'Produkt wird gesucht …'
                    : _scannedCode == null
                    ? 'Barcode scannen'
                    : 'Gescannt: $_scannedCode',
              ),
            ),
            if (_productImageUrl != null) ...[
              const SizedBox(height: 16),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    _productImageUrl!,
                    height: 140,
                    width: 180,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const SizedBox(
                      height: 80,
                      child: Icon(Icons.image_not_supported_outlined, size: 42),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Artikelname',
                hintText: 'z. B. Milch',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: quantityController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: widget.shoppingMode ? 'Einkaufsmenge' : 'Menge',
                hintText: widget.shoppingMode ? 'z. B. 2' : 'z. B. 2 × 1',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: unitController,
              decoration: const InputDecoration(
                labelText: 'Einheit',
                hintText: 'z. B. Liter, kg, Stück oder Packungen',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickExpiryDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Mindesthaltbarkeitsdatum (optional)',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text(
                  _expiryDate == null
                      ? 'Kein Datum gewählt'
                      : _formatDate(_expiryDate!),
                ),
              ),
            ),
            if (!widget.shoppingMode) ...[
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Automatisch auf die Einkaufsliste'),
                subtitle: const Text('Sobald der Mindestbestand erreicht ist'),
                value: _autoShoppingList,
                onChanged: (value) {
                  setState(() => _autoShoppingList = value);
                },
              ),
              if (_autoShoppingList) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: minimumQuantityController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Mindestbestand',
                    hintText: 'z. B. 2',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: shoppingQuantityController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Nachkaufmenge',
                    hintText: 'z. B. 6',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _save,
              icon: Icon(
                widget.existingItem == null ? Icons.add : Icons.save_outlined,
              ),
              label: Text(
                widget.existingItem == null ? 'Hinzufügen' : 'Speichern',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
