import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:novopharma/generated/l10n/app_localizations.dart';
import 'package:novopharma/models/user_goal_progress.dart';

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
  final UserGoalProgress? userProgress;

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
    this.userProgress,
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

  factory Goal.fromMap(Map<String, dynamic> data) {
    return Goal(
      id: data['id'] ?? '',
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
      userProgress: data['userProgress'] != null
          ? UserGoalProgress.fromMap(data['id'], data['userProgress'])
          : null,
    );
  }

  String getTimeRemaining(AppLocalizations l10n) {
    final now = DateTime.now();
    final difference = endDate.difference(now);

    if (difference.inDays > 0) {
      return l10n.endsInDays(difference.inDays);
    } else if (difference.inHours > 0) {
      return l10n.endsInHours(difference.inHours);
    } else if (difference.inMinutes > 0) {
      return l10n.endsInMinutes(difference.inMinutes);
    } else {
      return l10n.endingSoon;
    }
  }

  String get rewardText => '$rewardPoints points';

  Goal copyWith({UserGoalProgress? userProgress}) {
    return Goal(
      id: id,
      title: title,
      description: description,
      isActive: isActive,
      metric: metric,
      targetValue: targetValue,
      rewardPoints: rewardPoints,
      criteria: criteria,
      startDate: startDate,
      endDate: endDate,
      createdAt: createdAt,
      updatedAt: updatedAt,
      userProgress: userProgress ?? this.userProgress,
    );
  }
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
