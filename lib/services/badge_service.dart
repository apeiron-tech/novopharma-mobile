import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:novopharma/models/badge.dart';

class BadgeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'badges';

  Stream<List<Badge>> streamAllBadges() {
    try {
      return _firestore
          .collection(_collection)
          .orderBy('name')
          .snapshots()
          .map((querySnapshot) {
        return querySnapshot.docs
            .map((doc) => Badge.fromFirestore(doc))
            .toList();
      });
    } catch (e) {
      print('Error streaming all badges: $e');
      return Stream.value([]);
    }
  }
}