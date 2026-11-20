import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String name;
  final String marque;
  final String category;
  final String description;
  final double price;
  final double points;
  final double pointsPharmacie;
  final double pointsParaPharmacie;
  final double pointsDermoConseiller;
  final bool pointsUnified;
  final String sku;
  final int stock;
  final String protocol;
  final List<String> recommendedWith;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String imageUrl;
  final String composition;
  final int clientCode;
  final String status; // 'enabled' or 'disabled'

  Product({
    required this.id,
    required this.name,
    required this.marque,
    required this.category,
    required this.description,
    required this.price,
    required this.points,
    required this.pointsPharmacie,
    required this.pointsParaPharmacie,
    this.pointsDermoConseiller = 0.0,
    required this.pointsUnified,
    required this.sku,
    required this.stock,
    required this.protocol,
    required this.recommendedWith,
    required this.createdAt,
    required this.updatedAt,
    required this.imageUrl,
    required this.composition,
    required this.clientCode,
    this.status = 'enabled', // Default to enabled for backward compatibility
  });

  // Helper getters for status checking
  bool get isEnabled => status == 'enabled';
  bool get isDisabled => status == 'disabled';

  static final RegExp _digitsOnly = RegExp(r'^\d+$');

  /// Canonical form of a barcode for comparison: trimmed, lower-cased, and
  /// for purely numeric codes, without leading zeros (so "0123", "123" and an
  /// EAN-13 "0012345678905" vs UPC-A "012345678905" compare equal).
  static String normalizeSku(String raw) {
    final s = raw.trim().toLowerCase();
    if (_digitsOnly.hasMatch(s)) {
      final stripped = s.replaceFirst(RegExp(r'^0+'), '');
      return stripped.isEmpty ? '0' : stripped;
    }
    return s;
  }

  /// Whether a scanned barcode refers to this product's SKU.
  bool matchesSku(String scanned) =>
      sku.trim().isNotEmpty && normalizeSku(sku) == normalizeSku(scanned);

  /// All stored spellings a scanned barcode could match in Firestore
  /// (for a `whereIn` query, max 30 values).
  static List<Object> skuLookupCandidates(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return const [];
    final Set<Object> out = {trimmed};
    if (_digitsOnly.hasMatch(trimmed)) {
      final stripped = normalizeSku(trimmed);
      out.add(stripped);
      // Zero-padded to the common GTIN lengths (EAN-8, UPC-A, EAN-13, GTIN-14).
      for (final len in const [8, 12, 13, 14]) {
        if (stripped.length < len) out.add(stripped.padLeft(len, '0'));
      }
      // Legacy products where the SKU was saved as a number.
      final asInt = int.tryParse(stripped);
      if (asInt != null) out.add(asInt);
    }
    return out.take(30).toList();
  }

  factory Product.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // Helper function to safely parse int
    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    // Helper function to safely parse double
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    // Helper to safely read a string (some imported fields are numbers).
    String parseString(dynamic value) => value?.toString() ?? '';

    bool parseBool(dynamic value, bool fallback) {
      if (value is bool) return value;
      if (value is String) {
        if (value.toLowerCase() == 'true') return true;
        if (value.toLowerCase() == 'false') return false;
      }
      return fallback;
    }

    return Product(
      id: doc.id,
      name: parseString(data['name']),
      marque: parseString(data['marque']).trim(),
      category: parseString(data['category']),
      description: parseString(data['description']),
      price: parseDouble(data['price']),
      points: parseDouble(data['points']),
      pointsPharmacie: parseDouble(data['pointsPharmacie']),
      pointsParaPharmacie: parseDouble(data['pointsParaPharmacie']),
      pointsDermoConseiller: parseDouble(data['pointsDermoConseiller']),
      pointsUnified: parseBool(data['pointsUnified'], true), // Default to true
      sku: parseString(data['sku']).trim(),
      stock: parseInt(data['stock']),
      protocol: parseString(data['protocol']),
      recommendedWith: (data['recommendedWith'] is List)
          ? (data['recommendedWith'] as List)
              .where((e) => e != null && e.toString().isNotEmpty)
              .map((e) => e.toString())
              .toList()
          : <String>[],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      imageUrl: parseString(data['imageUrl']).trim(),
      composition: parseString(data['composition']),
      clientCode: parseInt(data['clientCode']),
      status: data['status'] is String ? data['status'] : 'enabled',
    );
  }

  double getPoints(String? pharmacyCategory, {String? userRole}) {
    if (pointsUnified) {
      return points;
    }

    if (userRole == 'Dermo-conseiller') {
      return pointsDermoConseiller > 0 ? pointsDermoConseiller : (pharmacyCategory == 'Para-Pharmacie' ? pointsParaPharmacie : pointsPharmacie);
    }

    if (pharmacyCategory == 'Para-Pharmacie') {
      return pointsParaPharmacie;
    }

    // Default to Pharmacie points if category is Pharmacie or unknown
    return pointsPharmacie;
  }
}

