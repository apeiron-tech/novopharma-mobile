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

    return Product(
      id: doc.id,
      name: data['name'] ?? '',
      marque: (data['marque'] ?? '').trim(),
      category: data['category'] ?? '',
      description: data['description'] ?? '',
      price: parseDouble(data['price']),
      points: parseDouble(data['points']),
      pointsPharmacie: parseDouble(data['pointsPharmacie']),
      pointsParaPharmacie: parseDouble(data['pointsParaPharmacie']),
      pointsUnified: data['pointsUnified'] ?? true, // Default to true
      sku: data['sku'] ?? '',
      stock: parseInt(data['stock']),
      protocol: data['protocol'] ?? '',
      recommendedWith: List<String>.from(data['recommendedWith'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      imageUrl: data['imageUrl'] ?? '',
      composition: data['composition'] ?? '',
      clientCode: parseInt(data['clientCode']),
      status: data['status'] ?? 'enabled', // Add status field
    );
  }

  double getPoints(String? pharmacyCategory) {
    if (pointsUnified) {
      return points;
    }

    if (pharmacyCategory == 'Para-Pharmacie') {
      return pointsParaPharmacie;
    }

    // Default to Pharmacie points if category is Pharmacie or unknown
    return pointsPharmacie;
  }
}
