class InventoryItem {
  final int? id;
  final String name;
  final String quantity;
  final String unit;
  final String location;
  final DateTime? expiryDate;

  const InventoryItem({
    this.id,
    required this.name,
    this.quantity = '',
    this.unit = '',
    required this.location,
    this.expiryDate,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'location': location,
      'expiryDate': expiryDate?.millisecondsSinceEpoch,
    };
  }

  factory InventoryItem.fromMap(Map<String, Object?> map) {
    return InventoryItem(
      id: map['id'] as int?,
      name: map['name'] as String,
      quantity: map['quantity'] as String? ?? '',
      unit: map['unit'] as String? ?? '',
      location: map['location'] as String,
      expiryDate: map['expiryDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['expiryDate'] as int)
          : null,
    );
  }
}
