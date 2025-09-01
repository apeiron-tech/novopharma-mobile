import 'package:cloud_firestore/cloud_firestore.dart';

class RedeemedReward {
  final String id;
  final String userId;
  final String userNameSnapshot;
  final String rewardId;
  final String rewardNameSnapshot;
  final int pointsSpent;
  final DateTime createdAt;
  final DateTime redeemedAt;

  RedeemedReward({
    required this.id,
    required this.userId,
    required this.userNameSnapshot,
    required this.rewardId,
    required this.rewardNameSnapshot,
    required this.pointsSpent,
    required this.createdAt,
    required this.redeemedAt,
  });

  factory RedeemedReward.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return RedeemedReward(
      id: doc.id,
      userId: data['userId'] ?? '',
      userNameSnapshot: data['userNameSnapshot'] ?? '',
      rewardId: data['rewardId'] ?? '',
      rewardNameSnapshot: data['rewardNameSnapshot'] ?? '',
      pointsSpent: data['pointsSpent'] ?? 0,
      createdAt: _parseDate(data['createdAt']) ?? DateTime.now(),
      redeemedAt: _parseDate(data['redeemedAt']) ?? DateTime.now(),
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
