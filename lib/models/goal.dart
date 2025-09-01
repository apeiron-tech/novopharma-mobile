import 'package:cloud_firestore/cloud_firestore.dart';

class Goal {
  final String id;
  final String title;
  final String description;
  final bool isActive;
  final String metric;
  final num targetValue;
  final int rewardPoints;
  final GoalCriteria criteria;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  Goal({
    required this.id,
    required this.title,
    required this.description,
    required this.isActive,
    required this.metric,
    required this.targetValue,
    required this.rewardPoints,
    required this.criteria,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Goal.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Goal(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      isActive: data['isActive'] ?? false,
      metric: data['metric'] ?? '',
      targetValue: data['targetValue'] ?? 0,
      rewardPoints: data['rewardPoints'] ?? 0,
      criteria: GoalCriteria.fromMap(data['criteria'] ?? {}),
      startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  String get timeRemaining {
    final now = DateTime.now();
    final difference = endDate.difference(now);
    
    if (difference.inDays > 0) {
      return 'Ends in ${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return 'Ends in ${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return 'Ends in ${difference.inMinutes}m';
    } else {
      return 'Ending soon';
    }
  }

  int get progressPercent => (targetValue > 0 ? (rewardPoints / targetValue * 100) : 0).round();

  String get rewardText => '$rewardPoints points';
}

class GoalCriteria {
  final List<String> brands;
  final List<String> categories;
  final List<String> clientCategories;
  final List<String> pharmacyIds;
  final List<String> products;
  final List<String> zones;

  GoalCriteria({
    required this.brands,
    required this.categories,
    required this.clientCategories,
    required this.pharmacyIds,
    required this.products,
    required this.zones,
  });

  factory GoalCriteria.fromMap(Map<String, dynamic> data) {
    return GoalCriteria(
      brands: List<String>.from(data['brands'] ?? []),
      categories: List<String>.from(data['categories'] ?? []),
      clientCategories: List<String>.from(data['clientCategories'] ?? []),
      pharmacyIds: List<String>.from(data['pharmacyIds'] ?? []),
      products: List<String>.from(data['products'] ?? []),
      zones: List<String>.from(data['zones'] ?? []),
    );
  }
}
