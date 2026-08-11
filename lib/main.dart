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

class LocationScreen extends StatelessWidget {
  final String locationName;

  const LocationScreen({super.key, required this.locationName});

  void _showAddItemDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Artikel hinzufügen'),
        content: const TextField(
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Artikelname',
            hintText: 'z. B. Milch',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hinzufügen'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(locationName)),
      body: Center(
        child: FilledButton.icon(
          onPressed: () => _showAddItemDialog(context),
          icon: const Icon(Icons.add),
          label: const Text('Artikel hinzufügen'),
        ),
      ),
    );
  }
}
