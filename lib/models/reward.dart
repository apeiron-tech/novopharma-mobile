import 'package:cloud_firestore/cloud_firestore.dart';

class Reward {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final int pointsCost;
  final int stock;
  final String? dataAiHint;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Reward({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.pointsCost,
    required this.stock,
    this.dataAiHint,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Reward.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Reward(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      pointsCost: data['pointsCost'] ?? 0,
      stock: data['stock'] ?? 0,
      dataAiHint: data['dataAiHint'],
      createdAt: _parseDate(data['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDate(data['updatedAt']) ?? DateTime.now(),
    );
  }
}

DateTime? _parseDate(dynamic dateValue) {
  if (dateValue is Timestamp) {
    return dateValue.toDate();
  } else if (dateValue is String) {
    return DateTime.tryParse(dateValue);
  }
  return null;
}
