import 'package:flutter_test/flutter_test.dart';

import 'package:easy_vorrat/main.dart';

void main() {
  testWidgets('EasyVorrat startet mit Lagerorten', (tester) async {
    await tester.pumpWidget(const EasyVorratApp());

    expect(find.text('EasyVorrat'), findsOneWidget);
    expect(find.text('Bestand'), findsOneWidget);
    expect(find.text('Kühlschrank'), findsOneWidget);
    expect(find.text('Speisekammer'), findsOneWidget);
    expect(find.text('Keller'), findsOneWidget);
    expect(find.text('Gefrierschrank'), findsOneWidget);
  });
}
