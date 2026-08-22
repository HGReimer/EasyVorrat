import 'package:flutter/material.dart';

import 'location_screen.dart';

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
