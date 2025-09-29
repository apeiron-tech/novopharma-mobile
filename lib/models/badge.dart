import 'package:cloud_firestore/cloud_firestore.dart';

class Badge {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final String progressMetric; // e.g., 'sales_booster', 'brand_champion'
  final Map<String, dynamic> criteria;

  Badge({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.progressMetric,
    required this.criteria,
  });

  factory Badge.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Badge(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      progressMetric: data['progressMetric'] ?? 'manual',
      criteria: data['criteria'] as Map<String, dynamic>? ?? {},
    );
  }
}
