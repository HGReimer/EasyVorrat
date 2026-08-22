import 'package:flutter/material.dart';

import '../models/inventory_item.dart';
import 'barcode_scanner_screen.dart';

class AddItemScreen extends StatefulWidget {
  final String locationName;

  const AddItemScreen({super.key, required this.locationName});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final nameController = TextEditingController();
  final quantityController = TextEditingController();
  final unitController = TextEditingController();
  DateTime? _expiryDate;
  String? _scannedCode;

  @override
  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    unitController.dispose();
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

  Future<void> _scanBarcode() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (code == null) return;

    setState(() {
      _scannedCode = code;
      if (nameController.text.trim().isEmpty) {
        nameController.text = code;
      }
    });
  }

  void _save() {
    final name = nameController.text.trim();
    final quantity = quantityController.text.trim();
    final unit = unitController.text.trim();

    if (name.isEmpty) return;

    Navigator.pop(
      context,
      InventoryItem(
        name: name,
        quantity: quantity,
        unit: unit,
        location: widget.locationName,
        expiryDate: _expiryDate,
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
      appBar: AppBar(title: const Text('Artikel hinzufügen')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            OutlinedButton.icon(
              onPressed: _scanBarcode,
              icon: const Icon(Icons.qr_code_scanner),
              label: Text(
                _scannedCode == null
                    ? 'Barcode scannen'
                    : 'Gescannt: $_scannedCode',
              ),
            ),
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
              decoration: const InputDecoration(
                labelText: 'Menge',
                hintText: 'z. B. 2 × 1',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: unitController,
              decoration: const InputDecoration(
                labelText: 'Einheit',
                hintText: 'z. B. l, kg, Stück',
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
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.add),
              label: const Text('Hinzufügen'),
            ),
          ],
        ),
      ),
    );
  }
}
