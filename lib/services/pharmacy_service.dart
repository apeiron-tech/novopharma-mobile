import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:novopharma/models/pharmacy.dart';

class PharmacyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Pharmacy>> getPharmacies() async {
    try {
      final snapshot = await _firestore.collection('pharmacies').orderBy('name').get();
      if (snapshot.docs.isEmpty) {
        return [];
      }
      return snapshot.docs.map((doc) => Pharmacy.fromFirestore(doc)).toList();
    } catch (e) {
      // In a real app, you'd want to log this error
      print('Error fetching pharmacies: $e');
      rethrow; // Rethrow the error to be handled by the UI/Provider
    }
  }

  Future<List<Pharmacy>> getPharmaciesByIds(List<String> ids) async {
    if (ids.isEmpty) {
      return [];
    }
    try {
      final snapshot = await _firestore
          .collection('pharmacies')
          .where(FieldPath.documentId, whereIn: ids)
          .get();
      if (snapshot.docs.isEmpty) {
        return [];
      }
      return snapshot.docs.map((doc) => Pharmacy.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error fetching pharmacies by ids: $e');
      return [];
    }
  }
}
