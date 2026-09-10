import 'package:easy_vorrat/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  testWidgets('EasyVorrat startet mit gespeicherten Lagerorten', (
    tester,
  ) async {
    await tester.pumpWidget(const EasyVorratApp());

    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump();

    expect(find.text('EasyVorrat'), findsOneWidget);
    expect(find.text('Artikel'), findsOneWidget);
    expect(find.text('Kühlschrank'), findsOneWidget);
    expect(find.text('Speisekammer'), findsOneWidget);
    expect(find.text('Keller'), findsOneWidget);
    expect(find.text('Gefrierschrank'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('Lagerort hinzufügen'), findsOneWidget);
  });
}
