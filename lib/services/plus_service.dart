import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../models/inventory_item.dart';

class PlusService extends ChangeNotifier with WidgetsBindingObserver {
  PlusService._();
  static final PlusService instance = PlusService._();
  static const int freeItemLimit = 10;
  static const String productId = 'de.easyschmiede.easyvorrat.plus';
  static const _channel = MethodChannel('easy_vorrat/plus');
  static const String inventoryCountSql = '''
    SELECT COUNT(*) AS total FROM items
    WHERE NOT (
      isOnShoppingList = 1 AND autoShoppingList = 0
      AND CAST(REPLACE(quantity, ',', '.') AS REAL) <= 0
    )
  ''';

  Future<void>? _initialization;
  bool _isPlus = false;
  bool _loading = false;
  bool _acting = false;
  bool _pending = false;
  bool _available = false;
  String _price = '9,99 €';
  String? _message;

  bool get isPlus => _isPlus;
  bool get busy => _loading || _acting;
  bool get available => _available;
  String get price => _price;
  String? get message => _message;
  bool get supportsPurchases =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  bool get canBuy =>
      supportsPurchases && available && !busy && !_pending && !isPlus;

  static bool isShoppingOnly(InventoryItem item) =>
      item.isOnShoppingList &&
      !item.autoShoppingList &&
      (item.quantityValue ?? 0) <= 0;

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    if (!supportsPurchases) {
      _message = 'Der Kauf ist in der iPhone-App verfügbar.';
      return;
    }
    WidgetsBinding.instance.addObserver(this);
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'entitlementChanged' && call.arguments is bool) {
        _setEntitlement(call.arguments as bool);
        if (_isPlus) _message = 'EasyVorrat Plus ist freigeschaltet.';
        notifyListeners();
      } else if (call.method == 'verificationError') {
        _message =
            'Der Kauf konnte nicht bestätigt werden. '
            'Bitte versuche Käufe wiederherstellen.';
        notifyListeners();
      }
    });
    await _refreshSafely();
  }

  void _setEntitlement(bool active) {
    _isPlus = active;
    if (active) _pending = false;
  }

  Future<void> _refreshEntitlement() async {
    final active = await _channel
        .invokeMethod<bool>('hasPlus')
        .timeout(const Duration(seconds: 15));
    if (active == null) throw const FormatException('Missing entitlement');
    _setEntitlement(active);
    notifyListeners();
  }

  Future<void> _refreshSafely() async {
    try {
      await _refreshEntitlement();
    } catch (_) {
      _message =
          'Deine Plus-Freischaltung konnte gerade nicht geprüft '
          'werden. Bitte versuche Käufe wiederherstellen.';
      notifyListeners();
    }
  }

  Future<void> loadOffer() async {
    await initialize();
    if (!supportsPurchases || busy) return;
    _loading = true;
    _available = false;
    _message = null;
    notifyListeners();
    try {
      await _refreshEntitlement();
      if (!_isPlus) {
        final offer = await _channel
            .invokeMapMethod<String, dynamic>('product')
            .timeout(const Duration(seconds: 20));
        if (offer == null ||
            offer['id'] != productId ||
            offer['price'] is! String ||
            (offer['price'] as String).isEmpty) {
          throw const FormatException('Invalid offer');
        }
        _price = offer['price'] as String;
        _available = true;
      }
    } catch (_) {
      _message =
          'Das Plus-Angebot ist gerade nicht verfügbar. '
          'Bitte versuche es erneut.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> buy() async {
    await initialize();
    if (!canBuy) return;
    _acting = true;
    _message = null;
    notifyListeners();
    try {
      // No timeout: the customer may need time to confirm Apple's purchase sheet.
      final response = await _channel.invokeMapMethod<String, dynamic>('buy');
      switch (response?['status']) {
        case 'purchased':
          if (response?['isPlus'] != true) {
            throw const FormatException('Unverified purchase');
          }
          _setEntitlement(true);
          _message = 'EasyVorrat Plus ist freigeschaltet.';
          break;
        case 'pending':
          _pending = true;
          _message = 'Dein Kauf wartet auf die Bestätigung durch Apple.';
          break;
        case 'cancelled':
          _message = 'Der Kauf wurde abgebrochen.';
          break;
        default:
          throw const FormatException('Unknown purchase result');
      }
    } catch (_) {
      _message =
          'Der Kauf konnte nicht abgeschlossen werden. '
          'Falls du bereits bezahlt hast, wähle Käufe wiederherstellen.';
    } finally {
      _acting = false;
      notifyListeners();
    }
  }

  Future<void> restore() async {
    await initialize();
    if (!supportsPurchases || busy) return;
    _acting = true;
    _message = null;
    notifyListeners();
    try {
      final active = await _channel.invokeMethod<bool>('restore');
      if (active == null) throw const FormatException('Missing restore result');
      _setEntitlement(active);
      _message = active
          ? 'EasyVorrat Plus wurde wiederhergestellt.'
          : 'Für dieses Apple-Konto wurde kein Plus-Kauf gefunden.';
    } catch (_) {
      _message =
          'Die Käufe konnten gerade nicht wiederhergestellt werden. '
          'Bitte versuche es erneut.';
    } finally {
      _acting = false;
      notifyListeners();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && supportsPurchases) {
      unawaited(_refreshSafely());
    }
  }

  @override
  void dispose() {
    if (supportsPurchases) {
      WidgetsBinding.instance.removeObserver(this);
      _channel.setMethodCallHandler(null);
    }
    super.dispose();
  }
}

class InventoryLimitException implements Exception {
  const InventoryLimitException();
  String get message =>
      'Die kostenlose Version erlaubt 10 Artikel im Bestand. '
      'EasyVorrat Plus kostet einmalig 9,99 €.';
  @override
  String toString() => message;
}
