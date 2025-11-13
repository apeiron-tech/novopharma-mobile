import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:novopharma/models/user_model.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'users';

  Stream<UserModel?> getUserProfile(String uid) {
    try {
      return _firestore.collection(_collection).doc(uid).snapshots().map((
        docSnapshot,
      ) {
        if (docSnapshot.exists) {
          return UserModel.fromFirestore(docSnapshot);
        }
        return null;
      });
    } catch (e) {
      print('Error fetching user profile stream: $e');
      return Stream.value(null);
    }
  }

  Future<void> createUserProfile({
    required User user,
    required String name,
    required DateTime dateOfBirth,
    required String pharmacyId,
    required String pharmacyName,
    required String phone,
    required String avatarUrl,
    required String position,
  }) async {
    try {
      await _firestore.collection(_collection).doc(user.uid).set({
        'name': name,
        'email': user.email,
        'avatarUrl': avatarUrl,
        'dateOfBirth': Timestamp.fromDate(dateOfBirth),
        'phone': phone,
        'role': 'user',
        'pharmacy': pharmacyName,
        'pharmacyId': pharmacyId,
        'position': position,
        'points': 0,
        'status': 'pending', // Set initial status to pending
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error creating user profile: $e');
      rethrow;
    }
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    try {
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore.collection(_collection).doc(uid).update(data);
    } catch (e) {
      print('Error updating user profile: $e');
      rethrow;
    }
  }

  Future<UserModel?> getUser(String uid) async {
    try {
      final docSnapshot = await _firestore
          .collection(_collection)
          .doc(uid)
          .get();
      if (docSnapshot.exists) {
        return UserModel.fromFirestore(docSnapshot);
      }
      return null;
    } catch (e) {
      print('Error fetching user: $e');
      return null;
    }
  }
}
