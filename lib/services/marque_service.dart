import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:novopharma/models/marque.dart';

class MarqueService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'marques';

  Future<List<MarqueModel>> getMarques() async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .orderBy('marqueName', descending: false)
          .get();

      return querySnapshot.docs
          .map((doc) => MarqueModel.fromFirestore(doc))
          .where((m) => m.status != 'DELETED')
          .toList();
    } catch (e) {
      debugPrint('Error fetching marques: $e');
      return [];
    }
  }

  Stream<List<MarqueModel>> streamMarques() {
    return _firestore
        .collection(_collection)
        .orderBy('marqueName', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MarqueModel.fromFirestore(doc))
            .where((m) => m.status != 'DELETED')
            .toList());
  }
}
