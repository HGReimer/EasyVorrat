class StorageLocation {
  const StorageLocation({this.id, required this.name, required this.iconName});

  final int? id;
  final String name;
  final String iconName;

  factory StorageLocation.fromMap(Map<String, Object?> map) {
    return StorageLocation(
      id: map['id'] as int?,
      name: map['name'] as String,
      iconName: map['iconName'] as String,
    );
  }

  Map<String, Object?> toMap() {
    return {'id': id, 'name': name, 'iconName': iconName};
  }
}
