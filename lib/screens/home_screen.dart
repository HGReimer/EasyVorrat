import 'package:flutter/material.dart';

import '../models/storage_location.dart';
import '../services/database_helper.dart';
import '../theme/easy_vorrat_theme.dart';
import '../widgets/easy_vorrat_widgets.dart';
import 'add_item_screen.dart';
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
            ),
            onSubmitted: (_) => submit(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: submit,
              child: const Text('Speichern'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    return result;
  }

  bool _locationNameExists(
    String name, {
    int? exceptId,
  }) {
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
    ).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  Future<void> _addLocation() async {
    final name = await _showLocationDialog(
      title: 'Lagerort hinzufügen',
    );

    if (!mounted || name == null) {
      return;
    }

    if (_locationNameExists(name)) {
      _showMessage(
        'Dieser Lagerort ist bereits vorhanden.',
      );
      return;
    }

    await DatabaseHelper.instance.insertLocation(
      StorageLocation(
        name: name,
        iconName: 'storage',
      ),
    );

    await _loadDashboard();
  }

  Future<void> _renameLocation(
    StorageLocation location,
  ) async {
    final newName = await _showLocationDialog(
      title: 'Lagerort umbenennen',
      initialName: location.name,
    );

    if (!mounted ||
        newName == null ||
        newName == location.name) {
      return;
    }

    if (_locationNameExists(
      newName,
      exceptId: location.id,
    )) {
      _showMessage(
        'Dieser Lagerort ist bereits vorhanden.',
      );
      return;
    }

    await DatabaseHelper.instance.renameLocation(
      location: location,
      newName: newName,
    );

    await _loadDashboard();
  }

  Future<bool> _confirmDelete(
    StorageLocation location,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text(
                'Lagerort entfernen?',
              ),
              content: Text(
                'Soll „${location.name}“ wirklich entfernt werden?',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                      false,
                    );
                  },
                  child: const Text(
                    'Abbrechen',
                  ),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                      true,
                    );
                  },
                  child: const Text(
                    'Entfernen',
                  ),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<void> _deleteLocation(
    StorageLocation location,
  ) async {
    final confirmed = await _confirmDelete(
      location,
    );

    if (!mounted || !confirmed) {
      return;
    }

    final deleted =
        await DatabaseHelper.instance.deleteLocationIfEmpty(
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

  Future<void> _openLocation(
    StorageLocation location,
  ) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationScreen(
          locationName: location.name,
        ),
      ),
    );

    if (mounted) {
      await _loadDashboard();
    }
  }

  Future<void> _addItem() async {
    if (_locations.isEmpty) {
      _showMessage(
        'Bitte zuerst einen Lagerort anlegen.',
      );
      return;
    }

    final location = await showModalBottomSheet<StorageLocation>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text(
                  'Lagerort auswählen',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              for (final location in _locations)
                ListTile(
                  leading: Icon(
                    _locationIcon(
                      location.iconName,
                    ),
                  ),
                  title: Text(
                    location.name,
                  ),
                  onTap: () {
                    Navigator.pop(
                      sheetContext,
                      location,
                    );
                  },
                ),
            ],
          ),
        );
      },
    );

    if (!mounted || location == null) {
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddItemScreen(
          locationName: location.name,
        ),
      ),
    );

    if (mounted) {
      await _loadDashboard();
    }
  }

  static IconData _locationIcon(
    String iconName,
  ) {
    return switch (iconName) {
      'kitchen' => Icons.kitchen,
      'shelves' => Icons.shelves,
      'warehouse' => Icons.warehouse,
      'freezer' => Icons.ac_unit,
      _ => Icons.inventory_2_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'EasyVorrat',
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _loadDashboard,
              child: ListView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  24,
                  24,
                  24,
                  110,
                ),
                children: [
                  const SizedBox(
                    height: 8,
                  ),
                  const Icon(
                    Icons.inventory_2_outlined,
                    size: 72,
                    color: EasyVorratColors.green,
                  ),
                  const SizedBox(
                    height: 14,
                  ),
                  Text(
                    'EasyVorrat',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(
                          fontSize: 30,
                        ),
                  ),
                  const SizedBox(
                    height: 28,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _StatusCard(
                          value: '$_totalItems',
                          label: 'Artikel',
                          icon:
                              Icons.inventory_2_outlined,
                        ),
                      ),
                      const SizedBox(
                        width: 12,
                      ),
                      Expanded(
                        child: _StatusCard(
                          value: '$_expiringItems',
                          label: 'Bald ablaufend',
                          icon: Icons.schedule,
                        ),
                      ),
                      const SizedBox(
                        width: 12,
                      ),
                      const Expanded(
                        child: _StatusCard(
                          value: '0',
                          label: 'Einkaufsliste',
                          icon: Icons
                              .shopping_cart_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 32,
                  ),
                  const EasyVorratSectionHeader(
                    title: 'Lagerorte',
                    icon: Icons.storage_outlined,
                  ),
                  const SizedBox(
                    height: 8,
                  ),
                  if (_locations.isEmpty)
                    const EasyVorratPanel(
                      child: Padding(
                        padding: EdgeInsets.all(
                          12,
                        ),
                        child: Text(
                          'Noch keine Lagerorte vorhanden.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment:
                          WrapAlignment.center,
                      children: [
                        for (final location
                            in _locations)
                          _LocationCard(
                            location: location,
                            onOpen: () {
                              _openLocation(
                                location,
                              );
                            },
                            onRename: () {
                              _renameLocation(
                                location,
                              );
                            },
                            onDelete: () {
                              _deleteLocation(
                                location,
                              );
                            },
                          ),
                      ],
                    ),
                  const SizedBox(
                    height: 32,
                  ),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _addItem,
                      icon: const Icon(
                        Icons.add,
                      ),
                      label: const Text(
                        'Artikel hinzufügen',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton:
          FloatingActionButton.extended(
        onPressed: _addLocation,
        icon: const Icon(
          Icons.add_location_alt_outlined,
        ),
        label: const Text(
          'Lagerort hinzufügen',
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _StatusCard({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return EasyVorratPanel(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 16,
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: EasyVorratColors.green,
            size: 22,
          ),
          const SizedBox(
            height: 8,
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color:
                  EasyVorratColors.textPrimary,
            ),
          ),
          const SizedBox(
            height: 2,
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color:
                  EasyVorratColors.textSecondary,
            ),
          ),
        ],
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
      child: EasyVorratPanel(
        padding: EdgeInsets.zero,
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: onOpen,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 18,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _icon,
                        color:
                            EasyVorratColors.green,
                      ),
                      const SizedBox(
                        width: 12,
                      ),
                      Expanded(
                        child: Text(
                          location.name,
                          overflow:
                              TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight:
                                FontWeight.w600,
                          ),
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
                  value:
                      _LocationAction.rename,
                  child: ListTile(
                    leading:
                        Icon(Icons.edit_outlined),
                    title:
                        Text('Umbenennen'),
                  ),
                ),
                PopupMenuItem(
                  value:
                      _LocationAction.delete,
                  child: ListTile(
                    leading:
                        Icon(Icons.delete_outline),
                    title:
                        Text('Entfernen'),
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

enum _LocationAction {
  rename,
  delete,
}
