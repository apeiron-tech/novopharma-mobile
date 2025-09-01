import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String name;
  final String marque;
  final String category;
  final String description;
  final double price;
  final int points;
  final String sku;
  final int stock;
  final String protocol;
  final List<String> recommendedWith;
  final DateTime createdAt;
  final DateTime updatedAt;

  Product({
    required this.id,
    required this.name,
    required this.marque,
    required this.category,
    required this.description,
    required this.price,
    required this.points,
    required this.sku,
    required this.stock,
    required this.protocol,
    required this.recommendedWith,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Product.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Product(
      id: doc.id,
      name: data['name'] ?? '',
      marque: data['marque'] ?? '',
      category: data['category'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      points: data['points'] ?? 0,
      sku: data['sku'] ?? '',
      stock: data['stock'] ?? 0,
      protocol: data['protocol'] ?? '',
      recommendedWith: List<String>.from(data['recommendedWith'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
