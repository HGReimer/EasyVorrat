class InventoryItem {
  final int? id;
  final String name;
  final String quantity;
  final String unit;
  final String location;
  final String defaultLocation;
  final DateTime? expiryDate;
  final String minimumQuantity;
  final String shoppingQuantity;
  final bool autoShoppingList;
  final bool isOnShoppingList;

  const InventoryItem({
    this.id,
    required this.name,
    this.quantity = '',
    this.unit = '',
    required this.location,
    String? defaultLocation,
    this.expiryDate,
    this.minimumQuantity = '',
    this.shoppingQuantity = '',
    this.autoShoppingList = false,
    this.isOnShoppingList = false,
  }) : defaultLocation = defaultLocation ?? location;

  double? get quantityValue {
    final normalized = quantity.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  double? get minimumQuantityValue {
    final normalized = minimumQuantity.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  double? get shoppingQuantityValue {
    final normalized = shoppingQuantity.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  bool get hasReachedMinimum {
    final current = quantityValue;
    final minimum = minimumQuantityValue;

    if (current == null || minimum == null) {
      return false;
    }

    return current <= minimum;
  }

  InventoryItem copyWith({
    int? id,
    String? name,
    String? quantity,
    String? unit,
    String? location,
    String? defaultLocation,
    DateTime? expiryDate,
    String? minimumQuantity,
    String? shoppingQuantity,
    bool? autoShoppingList,
    bool? isOnShoppingList,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      location: location ?? this.location,
      defaultLocation: defaultLocation ?? this.defaultLocation,
      expiryDate: expiryDate ?? this.expiryDate,
      minimumQuantity: minimumQuantity ?? this.minimumQuantity,
      shoppingQuantity: shoppingQuantity ?? this.shoppingQuantity,
      autoShoppingList: autoShoppingList ?? this.autoShoppingList,
      isOnShoppingList: isOnShoppingList ?? this.isOnShoppingList,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'location': location,
      'defaultLocation': defaultLocation,
      'expiryDate': expiryDate?.millisecondsSinceEpoch,
      'minimumQuantity': minimumQuantity,
      'shoppingQuantity': shoppingQuantity,
      'autoShoppingList': autoShoppingList ? 1 : 0,
      'isOnShoppingList': isOnShoppingList ? 1 : 0,
    };
  }

  factory InventoryItem.fromMap(Map<String, Object?> map) {
    final location = map['location'] as String;

    return InventoryItem(
      id: map['id'] as int?,
      name: map['name'] as String,
      quantity: map['quantity'] as String? ?? '',
      unit: map['unit'] as String? ?? '',
      location: location,
      defaultLocation: map['defaultLocation'] as String? ?? location,
      expiryDate: map['expiryDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['expiryDate'] as int)
          : null,
      minimumQuantity: map['minimumQuantity'] as String? ?? '',
      shoppingQuantity: map['shoppingQuantity'] as String? ?? '',
      autoShoppingList: (map['autoShoppingList'] as int? ?? 0) == 1,
      isOnShoppingList: (map['isOnShoppingList'] as int? ?? 0) == 1,
    );
  }
}
