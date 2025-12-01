import 'package:cloud_firestore/cloud_firestore.dart';

// Nested model for acquisition rules
class AcquisitionRules {
  final String metric;
  final num targetValue;
  final Scope scope;
  final Timeframe timeframe;

  AcquisitionRules({
    required this.metric,
    required this.targetValue,
    required this.scope,
    required this.timeframe,
  });

  factory AcquisitionRules.fromMap(Map<String, dynamic> map) {
    return AcquisitionRules(
      metric: map['metric'] ?? 'revenue',
      targetValue: map['targetValue'] ?? 0,
      scope: Scope.fromMap(map['scope'] as Map<String, dynamic>? ?? {}),
      timeframe:
          Timeframe.fromMap(map['timeframe'] as Map<String, dynamic>? ?? {}),
    );
  }
}

class Scope {
  final List<String> brands;
  final List<String> categories;
  final List<String> productIds;

  Scope({
    required this.brands,
    required this.categories,
    required this.productIds,
  });

  factory Scope.fromMap(Map<String, dynamic> map) {
    return Scope(
      brands: List<String>.from(map['brands'] ?? []),
      categories: List<String>.from(map['categories'] ?? []),
      productIds: List<String>.from(map['productIds'] ?? []),
    );
  }
}

class Timeframe {
  final DateTime startDate;
  final DateTime endDate;

  Timeframe({
    required this.startDate,
    required this.endDate,
  });

  factory Timeframe.fromMap(Map<String, dynamic> map) {
    return Timeframe(
      startDate: _parseDate(map['startDate']) ?? DateTime.now(),
      endDate:
          _parseDate(map['endDate']) ?? DateTime.now().add(Duration(days: 30)),
    );
  }

  static DateTime? _parseDate(dynamic date) {
    if (date is Timestamp) {
      return date.toDate();
    }
    if (date is String) {
      return DateTime.tryParse(date);
    }
    return null;
  }
}

class Badge {
  final String id;
  final String name;
  final String description;
  final String imageUrl;

  // Old structure fields
  final String? progressMetric;
  final Map<String, dynamic>? criteria;

  // New structure fields
  final bool? isActive;
  final int? maxWinners;
  final int? winnerCount;
  final AcquisitionRules? acquisitionRules;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Badge({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    // Old
    this.progressMetric,
    this.criteria,
    // New
    this.isActive,
    this.maxWinners,
    this.winnerCount,
    this.acquisitionRules,
    this.createdAt,
    this.updatedAt,
  });

  factory Badge.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // Check if it's the new structure by looking for 'acquisitionRules'
    if (data.containsKey('acquisitionRules')) {
      return Badge(
        id: doc.id,
        name: data['name'] ?? '',
        description: data['description'] ?? '',
        imageUrl: data['imageUrl'] ?? '',
        isActive: data['isActive'] ?? false,
        maxWinners: data['maxWinners'] as int?,
        winnerCount: data['winnerCount'] as int?,
        acquisitionRules: AcquisitionRules.fromMap(
          data['acquisitionRules'] as Map<String, dynamic>,
        ),
        createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
        updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
        // Set old fields to null for new structure
        progressMetric: null,
        criteria: null,
      );
    } else {
      // It's the old structure
      return Badge(
        id: doc.id,
        name: data['name'] ?? '',
        description: data['description'] ?? '',
        imageUrl: data['imageUrl'] ?? '',
        progressMetric: data['progressMetric'] ?? 'manual',
        criteria: data['criteria'] as Map<String, dynamic>? ?? {},
        // Set new fields to null for old structure
        isActive: null,
        maxWinners: null,
        winnerCount: null,
        acquisitionRules: null,
        createdAt: null,
        updatedAt: null,
      );
    }
  }
}