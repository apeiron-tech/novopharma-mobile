import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:novopharma/models/badge.dart';

class BadgeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'badges';

  Future<List<Badge>> getAllBadges() async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .orderBy('name')
          .get();
      return querySnapshot.docs.map((doc) => Badge.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error fetching all badges: $e');
      return [];
    }
  }
}
