import 'dart:io';

import 'package:sqflite/sqflite.dart' as mobile;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void initDatabaseFactory() {
  if (Platform.isIOS || Platform.isAndroid) {
    databaseFactory = mobile.databaseFactory;
    return;
  }

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}
