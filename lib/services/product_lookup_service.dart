import 'dart:convert';

import 'package:http/http.dart' as http;

class ProductLookupResult {
  final String name;
  final String brand;
  final String packageQuantity;
  final String imageUrl;

  const ProductLookupResult({
    required this.name,
    required this.brand,
    required this.packageQuantity,
    required this.imageUrl,
  });

  String get displayName {
    if (brand.isEmpty || name.toLowerCase().contains(brand.toLowerCase())) {
      return name;
    }

    return '$brand $name';
  }
}

class ProductLookupService {
  ProductLookupService._();

  static Future<ProductLookupResult?> findByBarcode(String barcode) async {
    final uri = Uri.https(
      'world.openfoodfacts.org',
      '/api/v2/product/$barcode',
      {
        'fields':
            'product_name_de,product_name,brands,quantity,image_front_url',
      },
    );

    final response = await http
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      throw Exception(
        'Produktdatenbank antwortet mit Status ${response.statusCode}.',
      );
    }

    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

    if (data['status'] != 1 || data['product'] is! Map<String, dynamic>) {
      return null;
    }

    final product = data['product'] as Map<String, dynamic>;
    final germanName = _text(product['product_name_de']);
    final generalName = _text(product['product_name']);
    final name = germanName.isNotEmpty ? germanName : generalName;

    if (name.isEmpty) {
      return null;
    }

    return ProductLookupResult(
      name: name,
      brand: _text(product['brands']),
      packageQuantity: _text(product['quantity']),
      imageUrl: _text(product['image_front_url']),
    );
  }

  static String _text(Object? value) {
    return value is String ? value.trim() : '';
  }
}
