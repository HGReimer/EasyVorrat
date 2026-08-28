import 'package:flutter/material.dart';

import '../models/storage_location.dart';
import '../services/database_helper.dart';
import 'location_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<StorageLocation> _locations = [];
  bool _isLoading = true;
  int _totalItems = 0;
  int _expiringItems = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    final locations = await DatabaseHelper.instance.getLocations();
    final overview = await DatabaseHelper.instance.getInventoryOverview();

    if (!mounted) {
      return;
    }

    setState(() {
      _locations = locations;
      _totalItems = overview['total'] ?? 0;
      _expiringItems = overview['expiring'] ?? 0;
      _isLoading = false;
    });
  }

  Future<String?> _showLocationDialog({
    required String title,
    String initialName = '',
  }) async {
    final controller = TextEditingController(text: initialName);

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        void submit() {
          final name = controller.text.trim();
          if (name.isNotEmpty) {
            Navigator.pop(dialogContext, name);
          }
        }

        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Name des Lagerorts',
              hintText: 'z. B. Vorratsschrank',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => submit(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Abbrechen'),
            ),
            FilledButton(onPressed: submit, child: const Text('Speichern')),
          ],
        );
      },
    );

    controller.dispose();
    return result;
  }

  bool _locationNameExists(String name, {int? exceptId}) {
    final normalizedName = name.trim().toLowerCase();

    return _locations.any(
      (location) =>
          location.id != exceptId &&
          location.name.trim().toLowerCase() == normalizedName,
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addLocation() async {
    final name = await _showLocationDialog(title: 'Lagerort hinzufügen');

    if (!mounted || name == null) {
      return;
    }

    if (_locationNameExists(name)) {
      _showMessage('Dieser Lagerort ist bereits vorhanden.');
      return;
    }

    await DatabaseHelper.instance.insertLocation(
      StorageLocation(name: name, iconName: 'storage'),
    );

    await _loadDashboard();
  }

  Future<void> _renameLocation(StorageLocation location) async {
    final newName = await _showLocationDialog(
      title: 'Lagerort umbenennen',
      initialName: location.name,
    );

    if (!mounted || newName == null || newName == location.name) {
      return;
    }

    if (_locationNameExists(newName, exceptId: location.id)) {
      _showMessage('Dieser Lagerort ist bereits vorhanden.');
      return;
    }

    await DatabaseHelper.instance.renameLocation(
      location: location,
      newName: newName,
    );

    await _loadDashboard();
  }

  Future<bool> _confirmDelete(StorageLocation location) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Lagerort entfernen?'),
              content: Text(
                'Soll „${location.name}“ wirklich entfernt werden?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Abbrechen'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Entfernen'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<void> _deleteLocation(StorageLocation location) async {
    final confirmed = await _confirmDelete(location);

    if (!mounted || !confirmed) {
      return;
    }

    final deleted = await DatabaseHelper.instance.deleteLocationIfEmpty(
      location,
    );

    if (!mounted) {
      return;
    }

    if (!deleted) {
      _showMessage(
        'Der Lagerort enthält noch Artikel und kann nicht entfernt werden.',
      );
      return;
    }

    await _loadDashboard();
  }

  Future<void> _openLocation(StorageLocation location) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationScreen(locationName: location.name),
      ),
    );

    if (mounted) {
      await _loadDashboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EasyVorrat'),
        backgroundColor: const Color(0xFF0D1512),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboard,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 100),
                children: [
                  const Icon(
                    Icons.inventory_2_outlined,
                    size: 80,
                    color: Color(0xFF39FF6A),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Bestand',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '$_totalItems Artikel  ·  '
                    '$_expiringItems bald ablaufend  ·  '
                    '0 auf Einkaufsliste',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF9BCFA8),
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (_locations.isEmpty)
                    const Center(
                      child: Text(
                        'Noch keine Lagerorte vorhanden.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final location in _locations)
                          _LocationCard(
                            location: location,
                            onOpen: () => _openLocation(location),
                            onRename: () => _renameLocation(location),
                            onDelete: () => _deleteLocation(location),
                          ),
                      ],
                    ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addLocation,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Lagerort hinzufügen'),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.location,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
  });

  final StorageLocation location;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  IconData get _icon {
    return switch (location.iconName) {
      'kitchen' => Icons.kitchen,
      'shelves' => Icons.shelves,
      'warehouse' => Icons.warehouse,
      'freezer' => Icons.ac_unit,
      _ => Icons.inventory_2_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: onOpen,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 18,
                  ),
                  child: Row(
                    children: [
                      Icon(_icon),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          location.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            PopupMenuButton<_LocationAction>(
              tooltip: 'Lagerort verwalten',
              onSelected: (action) {
                switch (action) {
                  case _LocationAction.rename:
                    onRename();
                  case _LocationAction.delete:
                    onDelete();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _LocationAction.rename,
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Umbenennen'),
                  ),
                ),
                PopupMenuItem(
                  value: _LocationAction.delete,
                  child: ListTile(
                    leading: Icon(Icons.delete_outline),
                    title: Text('Entfernen'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _LocationAction { rename, delete }
