import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:novopharma/models/custom_page_model.dart';

class CustomPageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<CustomPageModel?> getCustomPage(String id) async {
    try {
      final doc = await _firestore.collection('customPage').doc(id).get();
      if (doc.exists) {
        return CustomPageModel.fromFirestore(doc);
      }
    } catch (e) {
      debugPrint('[CustomPageService] Error fetching custom page $id: $e');
    }
    return null;
  }
}
