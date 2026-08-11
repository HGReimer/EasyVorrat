import 'package:flutter/material.dart';

void main() {
  runApp(const EasyVorratApp());
}

class EasyVorratApp extends StatelessWidget {
  const EasyVorratApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EasyVorrat',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF39FF6A),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF07090A),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EasyVorrat'),
        backgroundColor: const Color(0xFF0D1512),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              size: 80,
              color: Color(0xFF39FF6A),
            ),
            const SizedBox(height: 20),
            const Text(
              'Kollektiv-Bestand',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              '0 Artikel  ·  0 bald ablaufend  ·  0 auf Einkaufsliste',
              style: TextStyle(fontSize: 15, color: Color(0xFF9BCFA8)),
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: const [
                _AreaButton('Kühlschrank', Icons.kitchen),
                _AreaButton('Speisekammer', Icons.shelves),
                _AreaButton('Keller', Icons.warehouse),
                _AreaButton('Gefrierschrank', Icons.ac_unit),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AreaButton extends StatelessWidget {
  final String label;
  final IconData icon;

  const _AreaButton(this.label, this.icon);

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LocationScreen(locationName: label),
          ),
        );
      },
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class LocationScreen extends StatefulWidget {
  final String locationName;

  const LocationScreen({super.key, required this.locationName});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  final List<String> items = [];

  Future<void> _openAddItemScreen() async {
    final name = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const AddItemScreen()),
    );

    if (!mounted || name == null || name.trim().isEmpty) {
      return;
    }

    setState(() {
      items.add(name.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.locationName)),
      body: items.isEmpty
          ? const Center(child: Text('Noch keine Artikel vorhanden.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.inventory_2_outlined),
                    title: Text(items[index]),
                    trailing: IconButton(
                      onPressed: () {
                        setState(() {
                          items.removeAt(index);
                        });
                      },
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

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({super.key});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final TextEditingController controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _save() {
    final name = controller.text.trim();

    if (name.isNotEmpty) {
      Navigator.pop(context, name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Artikel hinzufügen')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Artikelname',
                hintText: 'z. B. Milch',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _save(),
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
