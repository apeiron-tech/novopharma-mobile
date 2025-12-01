import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:novopharma/models/user_badge.dart';

class UserBadgeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'user_badges';

  Stream<List<UserBadge>> streamUserBadges(String userId) {
    try {
      return _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .orderBy('awardedAt', descending: true)
          .snapshots()
          .map((querySnapshot) {
        return querySnapshot.docs
            .map((doc) => UserBadge.fromFirestore(doc))
            .toList();
      });
    } catch (e) {
      print('Error streaming user badges: $e');
      return Stream.value([]);
    }
  }

  Future<List<UserBadge>> getUserBadges(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .orderBy('awardedAt', descending: true)
          .get();
      final List<UserBadge> userBadges = querySnapshot.docs
          .map((doc) => UserBadge.fromFirestore(doc))
          .toList();
      return userBadges;
    } catch (e) {
      print('Error fetching user badges: $e');
      return [];
    }
  }
}